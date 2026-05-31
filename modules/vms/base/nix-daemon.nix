{ lib, ... }:

{
  nix.settings = {
    use-cgroups = true;
    experimental-features = [ "cgroups" ];
    cores = 7;
    max-jobs = 14;
  };

  environment.sessionVariables = {
    NIX_REMOTE = "daemon";
  };

  systemd.slices.nix-idle = {
    description = "Low-priority, full-CPU slice for the Nix daemon";
    sliceConfig = {
      CPUAccounting = true;
      Nice = 19;
      CPUWeight = "idle";
      IOWeight = 1;
    };
  };

  systemd.services.nix-daemon = {
    serviceConfig = lib.mkForce {
      Slice = "nix-idle.slice";
    };
  };
}
