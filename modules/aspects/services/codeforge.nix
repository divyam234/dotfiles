{ den, ... }:
{
  den.aspects.codeforge =
    { user, host, ... }:
    {
      caddyRoutes = {
        codeforge = {
          host = "codeforge.${host.domain}";
          upstreams = [ "host.containers.internal:18473" ];
          tls = "internal";
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
          sops.templates."codeforge.env" = {
            path = codeforgeEnv;
            mode = "0400";
            content = ''
              CODEFORGE_API_KEY=${secrets.codeforge.token}
            '';
          };

          systemd.user.services.codeforge = {
            Unit = {
              Description = "Codeforge Server";
              After = [ "sops-nix.service" ];
              Requires = [ "sops-nix.service" ];
            };

            Service = {
              Type = "simple";
              EnvironmentFile = codeforgeEnv;
              Environment = [
                "CODEFORGE_WORKSPACE_ROOT=${workspaceRoot}"
                "CODEFORGE_HTTP_ADDRESS=:18473"
                "CODEFORGE_COMMAND_POLICY=unrestricted"
                "CODEFORGE_FOREGROUND_YIELD_MS=10000"
              ];
              ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${workspaceRoot}";
              ExecStart = "${pkgs.codeforge}/bin/codeforge";
              Restart = "always";
              RestartSec = "10s";
              NoNewPrivileges = true;
              MemoryMax = "4G";
              CPUQuota = "200%";
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
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

  den.aspects.codeforge-cli = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.codeforge ];
      };
  };
}
