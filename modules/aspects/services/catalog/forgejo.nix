{ den, ... }:
{
  den.aspects.forgejo = {
    includes = [
      den.aspects.oci-service
      den.aspects.pgdog
    ];

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
            autoUpdate = "registry";
          };
          unitConfig = {
            After = [ quadlet.containers.pgdog.ref ];
            Requires = [ quadlet.containers.pgdog.ref ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
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
