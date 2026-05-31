{ ... }:

{
  services = {
    samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          workgroup = "FLYNNNET";
          "server string" = "Linux";
          "netbios name" = "Linux";
          security = "user";
          "invalid users" = [];
          "guest account" = "nobody";
          "map to guest" = "Bad Password";
          "follow symlinks" = "yes";
          "unix extensions" = "no";
          "wide links" = "yes";
          "allow insecure wide links" = "yes";
          "server multi channel support" = "yes";
          deadtime = 30;
          "use sendfile" = "yes";
          "min receivefile size" = 16384;
          "aio read size" = 1;
          "aio write size" = 1;
          "socket options" = "IPTOS_LOWDELAY TCP_NODELAY SO_RCVBUF=131072 SO_SNDBUF=131072";
          "server min protocol" = "SMB3";
          "client min protocol" = "SMB3";
          "strict locking" = "no";
          "read raw" = "yes";
          "write raw" = "yes";
          "large readwrite" = "yes";
          "max xmit" = 65535;
          "getwd cache" = "yes";
          "acl allow execute always" = true;
          "acl map full control" = "yes";
          "strict sync" = "no";
          "sync always" = "no";
          "hosts allow" = "192.168.100.";
          "bind interfaces only" = "yes";
          "interfaces" = "virbr1";
        };
        "share" = {
          path = "/share";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "create mask" = "777";
          "directory mask"= "777";
          "force user" = "nobody";
          "force group" = "nogroup";
        };
      };
    };
    samba-wsdd = {
      enable = true;
      openFirewall = true;
      workgroup = "FLYNNNET";
      extraOptions = [
        "--shortlog"
        "--ipv4only"
      ];
    };
  };
}
