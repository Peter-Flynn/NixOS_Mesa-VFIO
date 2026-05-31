{ ... }:

{
  boot.kernel.sysctl = {
    "vm.swappiness" = 200;
  };

  swapDevices = [ {
    device = "/dev/disk/by-partlabel/Swap";
    options = [ "nofail" ];
    randomEncryption = {
      enable = true;
      allowDiscards = true;
    };
    discardPolicy = "both";
  } ];

  zramSwap = let
    dev = "/dev/disk/by-partlabel/ZRAM";
  in {
    enable = true;
    writebackDevice = if builtins.pathExists dev then dev else null;
  };
}
