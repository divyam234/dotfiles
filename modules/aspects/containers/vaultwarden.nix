{ den, ... }:
{
  den.aspects.vaultwarden = {
    includes = [
      den.aspects.oci-base
      den.aspects.container-network
      den.aspects.container-secrets
      den.aspects.postgres
    ];

    nixos = { lib, host, ... }: {
      systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "vaultwarden" ];

      virtualisation.oci-containers.containers.vaultwarden = lib.dot.mkOci "vaultwarden" {
        image = "vaultwarden/server:latest-alpine";
        environmentFiles = [ (lib.dot.containerEnvFile "vaultwarden") ];
        dependsOn = [ "postgres" ];
        volumes = [ "${lib.dot.containerDataDir "vaultwarden"}:/data" ];
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

      systemd.services.podman-vaultwarden = lib.dot.mkContainerDeps "vaultwarden" // {
        after = [ "podman-network-${lib.dot.containerNetwork}.service" "podman-postgres.service" ];
        requires = [ "podman-network-${lib.dot.containerNetwork}.service" "podman-postgres.service" ];
      };
    };
  };
}
