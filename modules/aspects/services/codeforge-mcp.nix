{ den, ... }:
{
  den.aspects.codeforge-mcp =
    { user, host, ... }:
    {
      includes = [ den.aspects.oci-service ];
      containerDataDirs.codeforge-mcp = {
        user = user.userName;
        group = "users";
      };
      caddyRoutes = {
        codeforge-mcp = {
          host = "codeforge.${host.domain}";
          upstreams = [ "codeforge-mcp:8080" ];
          tls = "internal";
        };
      };

      nixos =
        {
          config,
          containers,
          secrets,
          ...
        }:
        let
          quadlet = config.virtualisation.quadlet;
        in
        {
          sops.templates."codeforge-mcp.env" = {
            path = "${containers.secretDir}/codeforge-mcp.env";
            mode = "0440";
            content = ''
              CODEFORGE_API_KEY=${secrets."codeforge-mcp".api_key}
            '';
          };

          virtualisation.quadlet.containers.codeforge-mcp = {
            autoStart = true;
            containerConfig = {
              name = "codeforge-mcp";
              image = "ghcr.io/divyam234/codeforge-mcp:latest";
              networks = [ quadlet.networks.${containers.networkName}.ref ];
              networkAliases = [ "codeforge-mcp" ];
              environmentFiles = [ "${containers.secretDir}/codeforge-mcp.env" ];
              environments = {
                CODEFORGE_WORKSPACE_ROOT = "/workspace";
                CODEFORGE_STATE_DIR = "/state";
                CODEFORGE_HTTP_ADDRESS = ":8080";
                CODEFORGE_COMMAND_POLICY = "unrestricted";
                CODEFORGE_ALLOW_DELETE = "true";
                CODEFORGE_FOREGROUND_YIELD_MS = "10000";
                CODEFORGE_MAX_CONCURRENT_PROCESSES = "8";
                CODEFORGE_PROCESS_TIMEOUT_SECONDS = "1800";
              };
              volumes = [
                "${containers.dataRoot}/codeforge-mcp/state:/state"
                "/home/${user.userName}/repos/github:/workspace"
                "/home/${user.userName}/.gitconfig:/home/dev/.gitconfig:ro"
                "/home/${user.userName}/go/pkg/mod:/home/dev/go/pkg/mod"
                "/home/${user.userName}/.cache/go-build:/home/dev/.cache/go-build"
                "/home/${user.userName}/.cargo:/home/dev/.cargo"
                "/home/${user.userName}/.cache/bun:/home/dev/.cache/bun"
                "/home/${user.userName}/.cache/uv:/home/dev/.cache/uv"
                "/home/${user.userName}/.cache/pip:/home/dev/.cache/pip"
                "/home/${user.userName}/.cache/npm:/home/dev/.cache/npm"
                "/home/${user.userName}/.local/share/pnpm:/home/dev/.local/share/pnpm"
              ];
              healthCmd = "pgrep -x codeforge-mcp";
              autoUpdate = "registry";
            };
            serviceConfig = {
              Restart = "always";
              RestartSec = "10s";
              NoNewPrivileges = true;
              MemoryMax = "4G";
              CPUQuota = "200%";
            };
          };
        };
    };
}
