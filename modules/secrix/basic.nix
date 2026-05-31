{ lib, config, ... }:

let
  inherit (lib) mkOption mkIf;
  inherit (lib.types) bool;
  inherit (builtins) readFile;
  cfg = config.secrix.custom.enable;
in {
  options.secrix.custom.enable = mkOption {
    type = bool;
    default = false;
  };
  config = mkIf cfg {
    secrix = {
      hostPubKey = readFile ./crypt/mesa.pubkey;
      hostIdentityFile = "/etc/nixos/private.key";
    };
  };
}
