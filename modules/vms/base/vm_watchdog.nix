{ pkgs, ... }:

let 
  inherit (pkgs) bash libvirt gnugrep gawk coreutils writeScript;

  fName = "qemu-watchdog";
in {
  systemd.services."${fName}" = {
    description = "QEMU Monitor Watchdog";
    after = [ "libvirtd.service" ];
    requires = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "10s";
      ExecStart = writeScript "${fName}" ''
        #!${bash}/bin/bash
        set -e
        trap 'exit 0' SIGINT SIGTERM SIGQUIT SIGABRT

        while true; do
          vm=$(${libvirt}/bin/virsh list | ${gnugrep}/bin/grep running | ${gawk}/bin/awk '{print $2}')
          if [ ! -z "$vm" ]; then
            ${coreutils}/bin/timeout 60 ${libvirt}/bin/virsh qemu-monitor-command --hmp "$vm" info > /dev/null || ${libvirt}/bin/virsh destroy "$vm"
          fi
          ${coreutils}/bin/sleep 15
        done
        exit 1
      '';
    };
  };
}
