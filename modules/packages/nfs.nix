{ pkgs, ... }:

{
  boot.supportedFilesystems = [ "nfs" ];
  environment.systemPackages = with pkgs; [
    nfs-utils
  ];
}
