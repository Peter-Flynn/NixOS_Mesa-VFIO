{ config, lib, ... }:

with lib;

let
  cfg = config.virtualisation.libvirtd;
  opt = cfg.qemu.ovmfOverride;
in {
  options.virtualisation.libvirtd.qemu.ovmfOverride = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "The custom OVMF package";
  };

  config = mkIf (cfg.enable && (lib.versionOlder config.system.nixos.release "25.11")) {
    virtualisation.libvirtd.qemu.ovmf.packages =
      optionals (opt != null && cfg.qemu.ovmf.enable) [ opt.fd ];
  };
}
