{ den, ... }:
{
  den.aspects.openchamber = { host, user, ... }: {
    homeSecrets = [ "opencode/server_password" ];
    caddyRoutes = {
      openchamber = {
        host = "ai.${host.domain}";
        access = "tailnet";
        upstreams = [ "host.containers.internal:39173" ];
      };
    };

    homeManager =
      {
        lib,
        pkgs,
        config,
        secrets,
        ...
      }:
      {
        programs.bunGlobalCli.packages = lib.mkAfter [ "@openchamber/web" ];

        sops.templates."opencode-server.env" = secrets.mkTemplate {
          name = "opencode-server.env";
          path = "${config.xdg.configHome}/opencode/opencode-server.env";
          mode = "0400";
          content = ''
            OPENCODE_SERVER_PASSWORD=${secrets.opencode.server_password}
          '';
        };

        systemd.user.services = {
          opencode = {
            Unit = {
              Description = "OpenCode Server";
            };

            Service = {
              Type = "simple";
              EnvironmentFile = [
                "%h/.config/opencode/opencode.env"
                "%h/.config/opencode/opencode-server.env"
              ];
              ExecStart = "${pkgs.opencode}/bin/opencode serve --port 4095";
              Restart = "on-failure";
              RestartSec = "5s";
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };

          openchamber = {
            Unit = {
              Description = "OpenChamber Web Server";
              After = [ "opencode.service" ];
              Wants = [ "opencode.service" ];
            };

            Service = {
              Type = "simple";
              EnvironmentFile = [
                "%h/.config/opencode/opencode.env"
                "%h/.config/opencode/opencode-server.env"
              ];
              ExecStart = "%h/.bun/bin/openchamber serve --port 39173 --host 0.0.0.0 --foreground";
              Environment = [
                "OPENCODE_HOST=http://localhost:4095"
                "OPENCODE_SKIP_START=true"
                "OPENCHAMBER_ALLOW_UNAUTHENTICATED_LAN=true"
              ];
              Restart = "on-failure";
              RestartSec = "5s";
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };
        };
      };

    nixos =
      { containers, ... }:
      {
        users.users.${user.userName}.linger = true;

        networking.firewall.interfaces."br-${containers.networkName}".allowedTCPPorts = [
          39173
        ];
      };
  };
}
