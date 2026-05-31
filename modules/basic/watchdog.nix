{ ... }:

{
  systemd.settings.Manager = {
    RuntimeWatchdogSec = 120;
    RebootWatchdogSec = 120;
  };
}
