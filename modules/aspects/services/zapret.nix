{ den, ... }:
{
  den.aspects.zapret = {
    nixos =
      { ... }:
      {
        config = {
          services.zapret = {
            enable = true;
            configureFirewall = false;
            params = [
              "--dpi-desync=fake,disorder2"
              "--dpi-desync-ttl=1"
              "--dpi-desync-autottl=2"
            ];
          };

          networking.firewall.extraCommands = ''
            ip46tables -t mangle -A POSTROUTING -o nordlynx -j ACCEPT
            ip46tables -t mangle -A POSTROUTING -o tailscale0 -j ACCEPT
            ip46tables -t mangle -A POSTROUTING -p tcp --dport 443 -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:6 -m mark ! --mark 0x40000000/0x40000000 -j NFQUEUE --queue-num 200 --queue-bypass
            ip46tables -t mangle -A POSTROUTING -p tcp --dport 80 -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:6 -m mark ! --mark 0x40000000/0x40000000 -j NFQUEUE --queue-num 200 --queue-bypass
          '';

          services.resolved = {
            enable = true;
            settings.Resolve = {
              DNSSEC = "false";
              DNSOverTLS = "opportunistic";
              FallbackDNS = [
                "1.1.1.1#cloudflare-dns.com"
                "8.8.8.8#dns.google"
              ];
            };
          };
          networking.nameservers = [
            "1.1.1.1"
            "8.8.8.8"
          ];
        };
      };
  };
}
