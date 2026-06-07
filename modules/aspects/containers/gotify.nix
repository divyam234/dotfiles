{ den, ... }:
{
  den.aspects.gotify = {
    includes = [
      den.aspects.oci-base
      den.aspects.container-network
      den.aspects.container-secrets
    ];

    nixos = { lib, host, ... }: {
      systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "gotify" ];

      virtualisation.oci-containers.containers.gotify = lib.dot.mkOci "gotify" {
        image = "gotify/server:latest";
        environmentFiles = [ (lib.dot.containerEnvFile "gotify") ];
        volumes = [ "${lib.dot.containerDataDir "gotify"}:/app/data" ];
      };

      dot.caddy.routes.gotify = {
        host = "push.${host.domain}";
        upstreams = [ "gotify:80" ];
        cacheStatic = false;
      };

      systemd.services.podman-gotify = lib.dot.mkContainerDeps "gotify";
    };
  };
}
