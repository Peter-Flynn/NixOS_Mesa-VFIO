{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ nil direnv nix-direnv ];

  programs.nix-ld.enable = true;
}
