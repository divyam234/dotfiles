{ den, ... }:
{
  den.aspects.forgejo = { user, host, ... }: {
    includes = [ den.aspects.oci-service ];
    ociSecrets = [ "forgejo" ];
    containerDataDirs.forgejo = {
      user = user.userName;
      group = "users";
    };
    caddyRoutes = {
      forgejo = {
        host = "git.${host.domain}";
        upstreams = [ "forgejo:3000" ];
        cacheStatic = true;
        extraConfig = ''
          request_body {
            max_size 512MB
          }
        '';
      };
    };

    nixos =
      {
        config,
        containers,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        virtualisation.quadlet.containers.forgejo = {
          autoStart = true;
          containerConfig = {
            name = "forgejo";
            image = "codeberg.org/forgejo/forgejo:15";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "forgejo" ];
            environmentFiles = [ "${containers.secretDir}/forgejo.env" ];
            volumes = [
              "${containers.dataRoot}/forgejo:/data:rw"
              # "/etc/localtime:/etc/localtime:ro"
            ];
            healthCmd = "wget --spider -q http://127.0.0.1:3000/api/healthz || exit 1";
            autoUpdate = "registry";
          };
          unitConfig = {
            After = [ quadlet.containers.pgdog.ref ];
            Requires = [ quadlet.containers.pgdog.ref ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "1G";
            CPUQuota = "150%";
          };
        };
      };
  };
}
