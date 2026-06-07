{ den, ... }:
{
  den.aspects.uptime-kuma = {
    includes = [ den.aspects.oci-base den.aspects.container-network ];

    nixos = { lib, host, ... }: {
      systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "uptime-kuma" ];

      virtualisation.oci-containers.containers.uptime-kuma = lib.dot.mkOci "uptime-kuma" {
        image = "louislam/uptime-kuma:1";
        volumes = [ "${lib.dot.containerDataDir "uptime-kuma"}:/app/data" ];
      };

      dot.caddy.routes.uptime-kuma = {
        host = "status.${host.domain}";
        upstreams = [ "uptime-kuma:3001" ];
        cacheStatic = false;
      };

      systemd.services.podman-uptime-kuma = lib.dot.mkContainerDeps "uptime-kuma";
    };
  };
}
