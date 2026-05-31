{ pkgs, ... }:

{
  programs = {
    htop = {
      enable = true;
      settings = {
        "screen:Main" = "PID PROCESSOR USER PRIORITY NICE M_VIRT M_RESIDENT M_SHARE STATE PERCENT_CPU PERCENT_MEM TIME Command";
      };
    };
    nano.enable = true;
  };

  environment.systemPackages = with pkgs; [
    file
    pciutils
    wget
    killall
    tree
  ];
}
