{ pkgs, ... }:

let
  update-mesa = pkgs.writeShellApplication {
    name = "update-mesa";
    runtimeInputs = with pkgs; [ nix jq coreutils ];
    text = ''
      set -euo pipefail
      flake_dir="''${1:-/etc/nixos}"
      cd "$flake_dir" || exit 1

      cp flake.lock flake.lock.bak
      restore() { mv -f flake.lock.bak flake.lock; rm -f flake.lock.new; }
      trap restore ERR

      nix flake update mesa

      new_locked="$(jq -c '.nodes[(.nodes[.root].inputs.mesa)].locked' flake.lock)"
      jq --argjson m "$new_locked" \
         '.nodes[(.nodes[.root].inputs.mesa)].locked = $m' \
         flake.lock.bak > flake.lock.new

      mv -f flake.lock.new flake.lock
      rm -f flake.lock.bak
      trap - ERR
    '';
  };
in {
  environment.systemPackages = [ update-mesa ];
}