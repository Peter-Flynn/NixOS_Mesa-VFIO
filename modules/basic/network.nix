{ ... }:

{
  networking = {
    nameservers = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
    firewall.allowPing = true;
    hostId = "076816e1";
  };
}
