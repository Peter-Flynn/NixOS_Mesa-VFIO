{ pkgs, ... }:

let
  inherit (pkgs) coreutils systemd procps bash gnugrep gawk python3Packages writeScriptBin writeScript;

  vfio-isolate = python3Packages.vfio-isolate;

  log-rotate = writeScriptBin "custom_log-rotate" ''
    #!${bash}/bin/bash
    [ $# -ne 2 ] && exit 1
    [ -r "$1" ] || exit 2
    [ -w "$1" ] || exit 3
    [ "$2" -gt 0 ] || exit 4
    ${coreutils}/bin/cat "$1" | ${coreutils}/bin/tail -n "$2" > "$1.tmp"
    ${coreutils}/bin/mv "$1.tmp" "$1"
  '';

  fName = "00-vfio-isolate";
in {
  virtualisation.libvirtd.hooks.qemu = {
    "${fName}.sh" = writeScript "${fName}" ''
      #!${bash}/bin/bash
      ${log-rotate}/bin/custom_log-rotate /var/log/custom-vm.log 100
      ${coreutils}/bin/echo -e "$(${coreutils}/bin/date)\n\t$1 issued: $2" >> /var/log/custom-vm.log

      UNDOFILE=/var/run/libvirt/qemu/vfio-isolate-undo.bin

      disable_isolation () {
        ${vfio-isolate}/bin/.vfio-isolate-wrapped restore $UNDOFILE
      }

      enable_isolation () {
        ${vfio-isolate}/bin/.vfio-isolate-wrapped \
          -u $UNDOFILE \
          drop-caches \
          compact-memory
      }

      case "$2" in
      "prepare")
        enable_isolation
        ;;
      "started")
        ${procps}/sbin/sysctl -w kernel.sched_rt_runtime_us=-1
        ;;
      "release")
        disable_isolation
        ;;
      esac

      if [[ $(${systemd}/bin/systemctl list-jobs shutdown.target reboot.target | ${coreutils}/bin/wc -l) == 1 && $2 == "stopped" ]]; then
        if ${systemd}/bin/journalctl --since "5 minutes ago" | ${gnugrep}/bin/grep "systemd\[1\]: Startup finished in" | ${coreutils}/bin/wc -l | ${gawk}/bin/awk '$1 >= 3 {exit 0} {exit 1}'; then
          ${coreutils}/bin/echo -e "\tBoot loop detected! Stalling." >> /var/log/custom-vm.log
          exit 0
        fi
        ${coreutils}/bin/echo -e "\tRebooting..." >> /var/log/custom-vm.log
        ${systemd}/bin/systemctl reboot
      fi
    '';
  };
}
