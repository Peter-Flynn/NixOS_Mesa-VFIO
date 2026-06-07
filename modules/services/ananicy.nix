{ pkgs, ... }:

{
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
    settings = {
      check_freq = 1;
      apply_cgroup = false;
    };
    extraTypes = [
      { type = "Custom_VM"; nice = -20; ioclass = "realtime"; latency_nice = -20; }
    ];
    extraRules = [
      { name = "qemu-system-x86_64"; type = "Custom_VM"; }
    ];
  };
}
