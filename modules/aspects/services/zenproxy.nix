{ den, ... }:
{
  den.aspects.zenproxy = { host, ... }: {
    nixosSecrets = [
      "nordvpn/service_username"
      "nordvpn/service_password"
    ];

    caddyRoutes.zenproxy = {
      host = "zen.${host.domain}";
      access = "tailnet";
      upstreams = [ "host.containers.internal:39174" ];
    };

    nixos =
      {
        config,
        containers,
        pkgs,
        secrets,
        ...
      }:
      {
        sops.templates."zenproxy.env" =
          (secrets.mkTemplate {
            name = "zenproxy.env";
            path = "/run/secrets/zenproxy.env";
            mode = "0400";
            content = ''
              NORDVPN_SERVICE_USERNAME=${secrets.nordvpn.service_username}
              NORDVPN_SERVICE_PASSWORD=${secrets.nordvpn.service_password}
            '';
          })
          // {
            restartUnits = [ "zenproxy.service" ];
          };

        systemd.services.zenproxy = {
          description = "OpenCode Zen proxy with NordVPN egress rotation";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            EnvironmentFile = config.sops.templates."zenproxy.env".path;
            Environment = "ZENPROXY_LISTEN_ADDR=0.0.0.0:39174";
            ExecStart = "${pkgs.local.zenproxy}/bin/zenproxy";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        networking.firewall.interfaces."br-${containers.networkName}".allowedTCPPorts = [ 39174 ];
      };
  };
}
