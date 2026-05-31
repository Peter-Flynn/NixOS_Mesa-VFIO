{ lib, config, ... }:

let
  inherit (lib) mkOption mkIf;
  inherit (lib.types) bool str int;
  cfg = config.custom.sshTunnel;
  secrets = config.secrix.services.autossh-tunnel.secrets;
  user = "tunnel";
in {
  options.custom.sshTunnel = {
    enable = mkOption {
      type = bool;
      default = false;
    };
    server = mkOption {
      type = str;
    };
    port = mkOption {
      type = int;
    };
    remotePort = mkOption {
      type = int;
    };
  };
  config = mkIf cfg.enable {
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      home = "/var/lib/tunnel";
      createHome = true;
    };
    users.groups.${user} = {};
    services.autossh.sessions = [
      {
        name = "tunnel";
        user = user;
        group = user;
        extraArguments = "-o \"ServerAliveInterval 30\" -o \"ServerAliveCountMax 3\" -o StrictHostKeyChecking=accept-new -i ${secrets.automationKey.decrypted.path} -p ${toString cfg.remotePort} -R ${toString cfg.port}:localhost:22 -N tunnel@${cfg.server}";
      }
    ];
    secrix = {
      custom.enable = true;
      services.autossh-tunnel.secrets.automationKey.encrypted.file =
        ../secrix/crypt/sshTunnel/automation_key;
    };
  };
}
