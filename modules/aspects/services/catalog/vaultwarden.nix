{ den, ... }:
{
  den.aspects.vaultwarden = {
    includes = [
      den.aspects.oci-service
      den.aspects.postgres
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
        dot.oci.secrets.vaultwarden.enable = true;
        dot.containers.dataDirs.vaultwarden = {
          inherit (containers.owners.home) user group;
        };

        virtualisation.quadlet.containers.vaultwarden = {
          autoStart = true;
          containerConfig = {
            name = "vaultwarden";
            image = "docker.io/vaultwarden/server:latest-alpine";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "vaultwarden" ];
            environmentFiles = [ "${containers.secretDir}/vaultwarden.env" ];
            volumes = [ "${containers.dataRoot}/vaultwarden:/data" ];
            autoUpdate = "registry";
          };
          unitConfig = {
            After = [ quadlet.containers.postgres.ref ];
            Requires = [ quadlet.containers.postgres.ref ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };

        dot.caddy.routes.vaultwarden = {
          host = "vault.${host.domain}";
          upstreams = [ "vaultwarden:80" ];
          cacheStatic = false;
          extraConfig = ''
            request_body {
              max_size 128MB
            }
          '';
        };
      };
  };
}
