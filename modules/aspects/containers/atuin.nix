{ den, ... }:
{
  den.aspects.atuin = {
    includes = [
      den.aspects.oci-base
      den.aspects.container-network
      den.aspects.container-secrets
      den.aspects.postgres
    ];

    nixos = { lib, host, ... }: {
      systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "atuin" ];

      virtualisation.oci-containers.containers.atuin = lib.dot.mkOci "atuin" {
        image = "ghcr.io/atuinsh/atuin:latest";
        environmentFiles = [ (lib.dot.containerEnvFile "atuin") ];
        cmd = [ "server" "start" ];
        dependsOn = [ "postgres" ];
        volumes = [ "${lib.dot.containerDataDir "atuin"}:/config" ];
      };

      dot.caddy.routes.atuin = {
        host = "atuin.${host.domain}";
        upstreams = [ "atuin:8888" ];
        cacheStatic = false;
      };

      systemd.services.podman-atuin = lib.dot.mkContainerDeps "atuin" // {
        after = [ "podman-network-${lib.dot.containerNetwork}.service" "podman-postgres.service" ];
        requires = [ "podman-network-${lib.dot.containerNetwork}.service" "podman-postgres.service" ];
      };
    };
  };
}
