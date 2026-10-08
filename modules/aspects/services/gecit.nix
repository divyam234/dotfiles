{ den, ... }:
{
  den.aspects.gecit = {
    nixos =
      { pkgs, lib, ... }:
      {
        config = {
          # Don't double-mangle with zapret: gecit replaces it.
          services.zapret.enable = lib.mkForce false;

          environment.systemPackages = [ pkgs.gecit ];

          # Split DNS: strict DoT for public names (ISP poisons plaintext DNS),
          # Tailscale registers ~ts.net per-link routes with resolved itself.
          services.resolved = {
            enable = true;
            dnssec = "false";
            dnsovertls = "true";
            fallbackDns = [
              "1.1.1.1#cloudflare-dns.com"
              "8.8.8.8#dns.google"
            ];
          };
          networking.nameservers = [
            "1.1.1.1"
            "8.8.8.8"
          ];

          systemd.services.gecit = {
            description = "gecit DPI bypass";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.gecit}/bin/gecit run --panel=false --doh=false";
              Restart = "always";
              RestartSec = 5;
              AmbientCapabilities = [
                "CAP_BPF"
                "CAP_NET_ADMIN"
                "CAP_NET_RAW"
              ];
            };
          };
        };
      };
  };
}
