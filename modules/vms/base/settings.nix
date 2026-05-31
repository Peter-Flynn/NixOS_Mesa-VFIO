{ pkgs, lib, config, ... }:

let
  cfgFd = "${config.virtualisation.libvirtd.qemu.ovmfOverride.fd}/FV";
in {
  boot = {
    kernelParams = [
      "panic=1" "clocksource=tsc" "tsc=reliable" "vfio_pci.disable_idle_d3=1"
      "video=efifb:off" "nomodeset" "modprobe.blacklist=amdgpu" "disable_vga=1"
      "iommu=pt" "pci=noaer" "pci=realloc" "initcall_blacklist=sysfb_init" "pcie_aspm=off"
      "kvm_amd.nested=0" "kvm_amd.npt=1" "kvm_amd.sev=0" "kvm_amd.avic=1" "kvm_amd.force_avic=1"
      "amd_pstate=active" "kvm.ignore_msrs=1" "vfio_iommu_type1.allow_unsafe_interrupts=1"
      "rcu_nocb_poll" "transparent_hugepage=never" "default_hugepagesz=1G" "hugepagesz=1G"
    ];
  
    initrd.kernelModules = [ "vfio_pci" "vfio" "vfio-iommu_type1" "kvm_amd" ];
  };

  # Temporarily enable with `--option extra-sandbox-paths /sys/devices/system/cpu`
  nix.settings.extra-sandbox-paths = [ "/sys/devices/system/cpu" ];

  systemd = let
    stopBefore = [ "multi-user.target" "sshd.service" "libvirtd.service" "samba.target" ];
    deps = { after = stopBefore; upholds = stopBefore; };
  in {
    services.libvirt-guests = deps;
    targets.virt-guest-shutdown = deps;
    enableEmergencyMode = false;
    sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
    '';
  };

  virtualisation = {
    libvirt = {
      enable = true;
      swtpm.enable = true;
    };
    libvirtd = {
      enable = true;
      onBoot = "ignore";
      shutdownTimeout = 600;
      onShutdown = "shutdown";
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
        ovmfOverride = (pkgs.OVMF.override {
          secureBoot = true;
          tpmSupport = true;
          msVarsTemplate = true;
          httpSupport = false;
        });
      };
    };
  };

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  powerManagement.cpuFreqGovernor = "performance";

  environment = {
    sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];
    etc = {
      "qemu/firmware/99-custom-x86_64-secure.json" = {
        text = ''
{
    "description": "OVMF/* with SecureBoot, TPM support, and MS certificates enrolled*/",
    "interface-types": [
        "uefi"
    ],
    "mapping": {
        "device": "flash",
        "mode": "split",
        "executable": {
            "filename": "${cfgFd}/OVMF_CODE.fd",
            "format": "raw"
        },
        "nvram-template": {
            "filename": "${cfgFd}/OVMF_VARS.fd",
            "format": "raw"
        }
    },
    "targets": [
        {
            "architecture": "x86_64",
            "machines": [
                "pc-q35-*"
            ]
        }
    ],
    "features": [
        "acpi-s3",
        "acpi-s4",
        "amd-sev",
        "enrolled-keys",
        "requires-smm",
        "secure-boot",
        "verbose-dynamic"
    ],
    "tags": [
        "-D SECURE_BOOT_ENABLE=TRUE",
        "-D SMM_REQUIRE=TRUE",
        "-D TPM_ENABLE=TRUE",
        "-D TPM2_ENABLE=TRUE",
        "-D TPM2_CONFIG_ENABLE=TRUE",
        "-D FD_SIZE_4MB"
    ]
}
        '';
        mode = "0777";
        user = "root";
        group = "root";
      };
    };
  };
}
