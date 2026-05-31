{ ... }:

{
  networking.useNetworkd = true;

  systemd.network = {
    enable = true;
    netdevs = {
      "30-br0" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br0";
          MACAddress = "none";
        };
      };
    };
    networks = {
      "20-wired" = {
        name = "enp*";
        bridge = ["br0"];
      };
      "30-br0" = {
        name = "br0";
        DHCP = "yes";
      };
    };
    links = {
      "30-br0" = {
        matchConfig = {
          OriginalName = "br0";
        };
        linkConfig = {
          MACAddressPolicy = "none";
        };
      };
    };
  };
}
