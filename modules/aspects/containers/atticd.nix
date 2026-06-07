{ den, ... }:
{
  den.aspects.atticd = {
    includes = [
      den.aspects.oci-base
      den.aspects.container-network
      den.aspects.container-secrets
    ];

    nixos = { lib, host, ... }: {
      systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "atticd" ];

      environment.etc."attic/server.toml".text = ''
        listen = "0.0.0.0:8080"
        api-endpoint = "https://cache.${host.domain}/"
        database.url = "sqlite:///data/server.db?mode=rwc"
        storage.type = "local"
        storage.path = "/data/storage"
        chunking.nar-size-threshold = 65536
      '';

      virtualisation.oci-containers.containers.atticd = lib.dot.mkOci "atticd" {
        image = "ghcr.io/zhaofengli/attic:latest";
        environmentFiles = [ (lib.dot.containerEnvFile "atticd") ];
        cmd = [ "atticd" "--config" "/etc/attic/server.toml" ];
        volumes = [
          "/etc/attic/server.toml:/etc/attic/server.toml:ro"
          "${lib.dot.containerDataDir "atticd"}:/data"
        ];
      };

      dot.caddy.routes.atticd = {
        host = "cache.${host.domain}";
        upstreams = [ "atticd:8080" ];
        cacheStatic = false;
      };

      systemd.services.podman-atticd = lib.dot.mkContainerDeps "atticd";
    };
  };
}
