{ config, lib, ... }:

with lib;

let
  cfg = config.hardware.vfio;
in {
  options.hardware.vfio.pciIds = mkOption {
    type = types.listOf types.str;
    default = [];
    example = [ "10de:1234" "1234:5678" ];
    description = mdDoc ''
      List of PCI vendor:device IDs to bind to vfio-pci driver.
      IDs should be in the format "vendor:device".
    '';
  };

  config = mkIf (cfg.pciIds != []) {
    boot.kernelParams = [ 
      "vfio-pci.ids=${concatStringsSep "," (unique cfg.pciIds)}" "rd.driver.pre=vfio-pci"
    ];
  };
}