{ den, ... }:
{
  den.aspects.forgejo = {
    includes = [ den.aspects.oci-service ];

    nixos =
      {
        config,
        lib,
        host,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
        containers = config.dot.containers;
      in
      {
        dot.oci.secrets.forgejo.enable = true;
        dot.containers.dataDirs.forgejo = {
          inherit (containers.owners.home) user group;
        };

        # dot.caddy.global.layer4Routes = [
        #   ''
        #     @ssh ssh
        #     route @ssh {
        #       proxy forgejo:2240
        #     }
        #   ''
        # ];

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

        dot.caddy.routes.forgejo = {
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
  };
}
