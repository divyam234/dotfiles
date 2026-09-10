{ den, ... }:
{
  den.aspects.codeforge =
    { user, host, ... }:
    {
      caddyRoutes = {
        codeforge = {
          host = "codeforge.${host.domain}";
          access = "public";
          proxied = true;
          upstreams = [ "host.containers.internal:18473" ];
        };
      };

      homeManager =
        {
          config,
          pkgs,
          secrets,
          ...
        }:
        let
          codeforgeEnv = "${config.xdg.configHome}/codeforge/codeforge.env";
          workspaceRoot = "${config.home.homeDirectory}/repos/github";
        in
        {
          sops.templates."codeforge.env" = secrets.mkTemplate {
            name = "codeforge.env";
            path = codeforgeEnv;
            mode = "0400";
            content = ''
              CODEFORGE_API_KEY=${secrets.codeforge.token}
              CODEFORGE_CAMOFOX_ACCESS_KEY=${secrets.camofox.access_key}
              CODEFORGE_CAMOFOX_ADMIN_KEY=${secrets.camofox.admin_key}
              CODEFORGE_CAMOFOX_API_KEY=${secrets.camofox.api_key}
            '';
          };

          systemd.user.services.codeforge = {
            Unit.Description = "Codeforge Server";
            Service = {
              Type = "simple";
              EnvironmentFile = codeforgeEnv;
              Environment = [
                "CODEFORGE_WORKSPACE_ROOT=${workspaceRoot}"
                "CODEFORGE_HTTP_ADDRESS=:18473"
                "CODEFORGE_COMMAND_POLICY=unrestricted"
                "CODEFORGE_CAMOFOX_URL=http://localhost:9377"
                "CODEFORGE_FOREGROUND_YIELD_MS=10000"
                "CODEFORGE_CAMOFOX_TIMEOUT_SECONDS=60"
                "CODEFORGE_PUBLIC_URL=https://codeforge.${host.domain}"
              ];
              ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${workspaceRoot}";
              ExecStart = "${pkgs.codeforge}/bin/codeforge";
              Restart = "always";
              RestartSec = "10s";
              MemoryMax = "4G";
              CPUQuota = "200%";
            };
            Install.WantedBy = [ "default.target" ];
          };
        };

      nixos =
        {
          containers,
          ...
        }:
        {
          networking.firewall.interfaces."br-${containers.networkName}".allowedTCPPorts = [
            18473
          ];
        };
    };
}
