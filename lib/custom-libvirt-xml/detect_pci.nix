{ pkgs, ... }:

let
  inherit (builtins) fromJSON readFile currentTime;
  inherit (pkgs) runCommand bash pciutils coreutils gnugrep gnused jq;
in {
  detectPci = { devices ? "USB|Audio|VGA|Wi-Fi" }:
    fromJSON(
      readFile(
        runCommand "vm-pci" {
          time = currentTime;
          preferLocalBuild = true;
          allowSubstitutes = false;
        } ''
          #!${bash}/bin/bash
          KERNEL_FILE=$(mktemp)
          LIBVIRT_FILE=$(mktemp)

          NEXT_SLOT=0x10
          LSPCI_OUTPUT=$(${pciutils}/bin/lspci -nn)
          DEVICE_TYPES='${devices}'

          if ! ${coreutils}/bin/echo "$LSPCI_OUTPUT" | ${gnugrep}/bin/grep -qP "$DEVICE_TYPES"; then
              ${coreutils}/bin/printf '{"params":"","xml":"","error":"No devices found which match your pattern."}' > "$out"
              exit 0
          fi

          LAST_DEV=""
          ${coreutils}/bin/echo "$LSPCI_OUTPUT" | ${gnugrep}/bin/grep -P "$DEVICE_TYPES" | \
            ${coreutils}/bin/cut -d' ' -f1 | \
            ${coreutils}/bin/sort -u | while read -r BASE; do
              NO_FUNC=$(${coreutils}/bin/echo "$BASE" | ${coreutils}/bin/cut -d. -f1)
              [[ $LAST_DEV = $NO_FUNC ]] && continue; LAST_DEV="$NO_FUNC"
              FUNCTIONS=$(${coreutils}/bin/echo "$LSPCI_OUTPUT" | ${gnugrep}/bin/grep "^''${NO_FUNC}" | ${gnugrep}/bin/grep -P "$DEVICE_TYPES")
              ${coreutils}/bin/echo "$FUNCTIONS" | ${gnugrep}/bin/grep -o '\[....:....\]' | ${coreutils}/bin/tr -d '[]' >> "$KERNEL_FILE"
              FUNCTION_COUNT=$(${coreutils}/bin/echo "$FUNCTIONS" | ${coreutils}/bin/wc -l)

              ${coreutils}/bin/cat >> "$LIBVIRT_FILE" << EOL
    <controller type='pci' index='$((NEXT_SLOT))' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis=''\'''\${NEXT_SLOT}' port=''\'''\${NEXT_SLOT}' hotplug='off'/>
      <address type='pci' domain='0x0000' bus='0x00' slot=''\'''\${NEXT_SLOT}' function='0x0'/>
    </controller>
EOL

              if [ "$FUNCTION_COUNT" -eq 1 ]; then
                  BUS=$(${coreutils}/bin/echo "$BASE" | ${coreutils}/bin/cut -d: -f1)
                  SLOT=$(${coreutils}/bin/echo "$BASE" | ${coreutils}/bin/cut -d: -f2 | ${coreutils}/bin/cut -d. -f1)
                  FUNC=$(${coreutils}/bin/echo "$BASE" | ${coreutils}/bin/cut -d. -f2)
                  ${coreutils}/bin/cat >> "$LIBVIRT_FILE" << EOL
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x''${BUS}' slot='0x''${SLOT}' function='0x''${FUNC}'/>
      </source>
      <address type='pci' domain='0x0000' bus=''\'''\${NEXT_SLOT}' slot='0x00' function='0x0'/>
    </hostdev>
EOL
              else
                  FIRST=true
                  FUNC=0
                  ${coreutils}/bin/echo "$FUNCTIONS" | ${coreutils}/bin/cut -d' ' -f1 | while read -r ADDR; do
                      BUS=$(${coreutils}/bin/echo "$ADDR" | ${coreutils}/bin/cut -d: -f1)
                      SLOT=$(${coreutils}/bin/echo "$ADDR" | ${coreutils}/bin/cut -d: -f2 | ${coreutils}/bin/cut -d. -f1)
                      FUNC_ORIG=$(${coreutils}/bin/echo "$ADDR" | ${coreutils}/bin/cut -d. -f2)
                      if [ "$FIRST" = true ]; then
                          MULTIFUNCTION="multifunction='on'"
                          FIRST=false
                      else
                          MULTIFUNCTION=""
                      fi
                      ${coreutils}/bin/cat >> "$LIBVIRT_FILE" << EOL
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x''${BUS}' slot='0x''${SLOT}' function='0x''${FUNC_ORIG}'/>
      </source>
      <address type='pci' domain='0x0000' bus=''\'''\${NEXT_SLOT}' slot='0x00' function='0x''${FUNC}' ''${MULTIFUNCTION}/>
    </hostdev>
EOL
                      FUNC=$((FUNC + 1))
                  done
              fi

              NEXT_SLOT=$(${coreutils}/bin/printf "0x%x" $((''${NEXT_SLOT}+1)))
          done

          SORTED=$(${coreutils}/bin/sort -u "$KERNEL_FILE" | ${coreutils}/bin/tr '\n' ',' | ${gnused}/bin/sed 's/,$//')
          ${coreutils}/bin/echo -n "$SORTED" > "$KERNEL_FILE"

          ${coreutils}/bin/printf '{"params":"%s","xml":%s}' \
            "$(${coreutils}/bin/cat $KERNEL_FILE)" \
            "$(${coreutils}/bin/cat $LIBVIRT_FILE | ${jq}/bin/jq -R -s .)" > $out
        ''
      )
    );
}