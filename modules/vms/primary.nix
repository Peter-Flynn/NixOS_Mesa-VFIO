{ lib, config, ... }:

let 
  inherit (lib) mkOption mkIf toLower;
  inherit (lib.types) bool nullOr str package listOf path submodule int attrsOf;
  inherit (lib.custom) mkVm;
  cfg = config.custom.vm;
in {
  options.custom.vm = {
    enable = mkOption {
      type = bool;
      default = false;
    };
    title = mkOption {
      type = str;
    };
    qemuPackage = mkOption {
      type = package;
      default = config.virtualisation.libvirtd.qemu.package;
    };
    cdIso = mkOption {
      type = listOf path;
      default = [];
    };
    cpu = mkOption {
      type = submodule { options = {
        hostReserve   = mkOption { type = int; default = 2;  };
        hugeThreshold = mkOption { type = int; default = 32; };
      }; };
      default = {};
    };
    drives = mkOption {
      type = attrsOf (submodule {
        options = {
          enable = mkOption {
            type = nullOr bool;
            default = null;
          };
          location = mkOption {
            type = nullOr path;
            default = null;
          };
          largeBlk = mkOption {
            type = nullOr bool;
            default = null;
          };
        };
      });
      default = {};
    };
    devices = mkOption {
      type = str;
      default = "USB|Audio|VGA|Wi-Fi";
    };
    machine = mkOption {
      type = str;
      default = "q35";
    };
  };
  config = mkIf cfg.enable (let
    vmTitle = cfg.title or "System-VM";
    vmName = toLower vmTitle;
    qemu = "${cfg.qemuPackage}/bin/qemu-system-x86_64";
    vm = mkVm  { inherit vmName vmTitle qemu config; inherit (cfg) cdIso cpu drives devices machine; };
  in {
    hardware.vfio.pciIds = vm.params;

    boot.kernelParams = let
      # Roughly 1/3 of host-reserved RAM in bytes, in 512MB chunks.
      zfsArcMax = builtins.toString (vm.ramGb.host * 2 / 3 * 536870912);
      # Roughly 1/6 of host-reserved RAM in bytes, in 512MB chunks.
      zfsDirty = builtins.toString (vm.ramGb.host * 2 / 6 * 536870912);
    in [
      "hugepages=${vm.ramGb.vm}" "nohz_full=${vm.coreInfo.vmCores.list}" "rcu_nocbs=${vm.coreInfo.vmCores.list}"
      "zfs.zfs_arc_max=${zfsArcMax}" "zfs_dirty_data_max=${zfsDirty}"
    ];

    # Roughly 1/6 of host-reserved RAM in bytes, in 512MB chunks.
    zramSwap.memoryMax = vm.ramGb.host * 2 / 6 * 536870912;

    virtualisation.libvirt.connections."qemu:///system".domains = [
      { active = true; definition = vm.xml; }
    ];

    systemd.settings.Manager.CPUAffinity = vm.coreInfo.hostCoresList;
    systemd.slices.nix-idle.sliceConfig.AllowedCPUs = vm.coreInfo.vmCores.list;
    services.vfio-irq-balance.affinityMask = vm.coreInfo.vmCores.mask;
  });
}
