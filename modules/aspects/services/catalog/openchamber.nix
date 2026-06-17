{ den, ... }:
{
  den.aspects.openchamber = {
    includes = [
      den.aspects.ai
      den.aspects.caddy
    ];

    homeManager =
      { lib, pkgs, ... }:
      {
        programs.bunGlobalCli.packages = lib.mkAfter [ "@openchamber/web" ];

        systemd.user.services = {
          opencode = {
            Unit = {
              Description = "OpenCode Server";
            };

            Service = {
              Type = "simple";
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
              Requires = [ "opencode.service" ];
            };

            Service = {
              Type = "simple";
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
      { config, host, ... }:
      {
        networking.firewall.interfaces."br-${config.dot.containers.networkName}".allowedTCPPorts = [
          39173
        ];

        dot.caddy.routes.openchamber = {
          host = "ai.${host.domain}";
          upstreams = [ "host.containers.internal:39173" ];
        };
      };
  };
}
