{ lib, pkgs, config, nix-cachyos-kernel, ... }:

let
  inherit (lib) mkOption;
  inherit (lib.types) str;
  inherit (builtins) replaceStrings;
  cfg = replaceStrings [ "linux-" ] [ "linuxPackages-" ] config.custom.cachyosKernelVersion;
in {
  options.custom.cachyosKernelVersion = mkOption {
    type = str;
    default = "linux-cachyos-lts";
  };
  config = {
    boot.kernelPackages = pkgs.cachyosKernels.${cfg};
    boot.zfs.package = config.boot.kernelPackages.zfs_cachyos;

    nix.settings = {
      substituters = [ "https://attic.xuyh0120.win/lantian" ];
      trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
    };

    nixpkgs.overlays = [ nix-cachyos-kernel.overlays.pinned ];
  };
}
