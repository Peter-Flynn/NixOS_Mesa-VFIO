{ pkgs, config, nixvirt, ... }:

let
  inherit (pkgs) bash coreutils gnused runCommand;

  uuid = builtins.readFile(
    runCommand "net-uuid" {} ''
      #!${bash}/bin/bash

      ${coreutils}/bin/echo -n "${config.networking.hostName}_host-guest" | ${coreutils}/bin/sha256sum \
        | ${coreutils}/bin/cut -d' ' -f1 | ${coreutils}/bin/cut -c1-32 \
        | ${gnused}/bin/sed 's/\([0-9a-f]\{8\}\)\([0-9a-f]\{4\}\)\([0-9a-f]\{4\}\)\([0-9a-f]\{4\}\)\([0-9a-f]\{12\}\)/\1-\2-\3-\4-\5/' \
        | tr -d '\n' > $out
    ''
  );
in {
  virtualisation.libvirt.connections."qemu:///system".networks = [
    {
      definition = nixvirt.lib.network.writeXML {
        inherit uuid;
        name = "host-guest";
        bridge = {
          name = "virbr1";
          stp = true;
          delay = 0;
        };
        mtu.size = 9000;
        ip = {
          address = "192.168.100.1";
          netmask = "255.255.255.0";
          dhcp = { range = { start = "192.168.100.2"; end = "192.168.100.254"; }; };
        };
      };
      active = true;
    }
  ];
}
