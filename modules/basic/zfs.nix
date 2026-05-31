{ pkgs, lib, ... }:

{
  boot = {
    supportedFilesystems = [ "zfs" ];
    zfs = {
      package = lib.mkDefault pkgs.zfs_unstable;
      devNodes = "/dev/disk/by-id";
      forceImportRoot = true;
    };
  };

  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "monthly";
    };
    trim = {
      enable = true;
      interval = "monthly";
    };
    autoSnapshot = {
      enable = true;
      weekly = 2;
      monthly = 3;
    };
  };
}
