{ system, ... }:

{
  nix.settings.system-features = [ "benchmark" "big-parallel" "kvm" "nixos-test" ];
  nixpkgs.hostPlatform = { inherit system; };

  security.pam.loginLimits = [{
    domain = "*";
    type = "soft";
    item = "nofile";
    value = "8192";
  }];
}
