{ lib, ... }:

let 
  inherit (lib) mkDefault;
in {
  time.timeZone = mkDefault "America/Los_Angeles";
  i18n.defaultLocale = mkDefault "en_US.UTF-8";
}
