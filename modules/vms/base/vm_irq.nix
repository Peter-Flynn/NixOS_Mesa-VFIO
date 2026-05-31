{ pkgs, lib, config, ... }:

let
  inherit (pkgs) bash coreutils gnugrep writeScript;
  inherit (lib) mkOption mkIf types;
  cfg = config.services.vfio-irq-balance;
in {
  options.services.vfio-irq-balance.affinityMask = mkOption {
    type = types.nullOr types.str;
    default = null;
    example = "fcfc";
    description = "SMP affinity bitmask for vfio IRQs. Setting this enables the service.";
  };

  config = mkIf (cfg.affinityMask != null) {
    systemd.services.vfio-irq-balance = {
      description = "IRQ Balance VM";
      after = [ "libvirtd.service" ];
      requires = [ "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        StandardOutput = "journal";
        ExecStart = writeScript "vfio-irq-balance" ''
          #!${bash}/bin/bash
          while true; do
            ${gnugrep}/bin/grep vfio /proc/interrupts | ${coreutils}/bin/cut -d ":" -f 1 | while read -r i; do
              ${coreutils}/bin/echo "${cfg.affinityMask}" > /proc/irq/$i/smp_affinity
            done
            ${coreutils}/bin/sleep 10
          done
        '';
      };
    };
  };
}