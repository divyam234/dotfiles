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
