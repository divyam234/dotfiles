{ den, ... }:
{
  den.aspects.camoflare = _: {
    nixosSecrets = [
      "camofox/access_key"
      "camofox/api_key"
    ];

    nixos =
      {
        containers,
        pkgs,
        secrets,
        ...
      }:
      let
        port = 8191;
        envFile = "${containers.secretDir}/camoflare.env";
      in
      {
        sops.templates."camoflare.env" = secrets.mkTemplate {
          name = "camoflare.env";
          content = ''
            CAMOFOX_URL=http://localhost:9377
            CAMOFOX_ACCESS_KEY=${secrets.camofox.access_key}
            CAMOFOX_API_KEY=${secrets.camofox.api_key}
            CAMOFLARE_LISTEN=:${toString port}
          '';
        };

        systemd.services.camoflare = {
          description = "Camoflare FlareSolverr-compatible shim over Camofox";
          after = [
            "camofox-browser.service"
            "network-online.target"
          ];
          wants = [
            "camofox-browser.service"
            "network-online.target"
          ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            EnvironmentFile = envFile;
            ExecStart = "${pkgs.local.camoflare}/bin/camoflare";
            Restart = "always";
            RestartSec = "10s";
          };
        };

        networking.firewall.interfaces."br-${containers.networkName}".allowedTCPPorts = [
          port
        ];
      };
  };
}
