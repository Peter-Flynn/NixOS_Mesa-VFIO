{ pkgs, ... }:

let 
  lspci = pkgs.runCommand "lspci-devices" {
    time = builtins.currentTime;
    preferLocalBuild = true;
    allowSubstitutes = false;
  } ''
    ${pkgs.pciutils}/bin/lspci -nn > $out
  '';
  pciHash = builtins.hashString "sha256" (builtins.readFile lspci);
in {
  environment.etc."pci-built-hash".text = pciHash;
  systemd.services.pci-monitor = {
    description = "PCIe Mismatch Detector Service";
    wantedBy = [ "multi-user.target" ];
    before = [ "nixvirt.service" ];
    requiredBy = [ "nixvirt.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "no";
      ExecStart = pkgs.writeShellScript "pci-monitor" ''
        #!${pkgs.bash}/bin/bash
        if [[ "$(${pkgs.pciutils}/bin/lspci -nn | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)" != "$(${pkgs.coreutils}/bin/cat /etc/pci-built-hash)" ]]; then
          echo PCIe mismatch! Rebuilding...
          ${pkgs.nixos-rebuild}/bin/nixos-rebuild --impure --no-net boot
          reboot
          exit 1
        fi
        exit 0
      '';
    };
  };
}
