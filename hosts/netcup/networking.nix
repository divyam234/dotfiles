_:

{
  networking = {
    useDHCP = false;

    interfaces.eth0.ipv4.addresses = [
      {
        address = "152.53.106.166";
        prefixLength = 22;
      }
    ];

    interfaces.eth0.ipv6.addresses = [
      {
        address = "2a0a:4cc0:40:715:38bf:ebff:fe94:649";
        prefixLength = 64;
      }
    ];

    defaultGateway = {
      address = "152.53.104.1";
      interface = "eth0";
    };

    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };

    nameservers = [
      "1.1.1.1"
      "2606:4700:4700::1111"
      "8.8.8.8"
      "2001:4860:4860::8888"
    ];

    nftables = {
      enable = true;
      tables.container-ingress = {
        family = "inet";
        content = ''
          chain forward {
            type filter hook forward priority -10; policy accept;

            iifname "eth0" ct status dnat tcp dport { 80, 443 } accept
            iifname "eth0" ct status dnat udp dport 443 accept
            iifname "eth0" ct status dnat drop
          }
        '';
      };
    };
  };
}
