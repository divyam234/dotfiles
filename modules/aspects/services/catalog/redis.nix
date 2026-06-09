{ den, ... }:
{
  den.aspects.redis = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { lib, ... }:
      {
        dot.oci.secrets.redis.enable = true;
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "redis" ];
        virtualisation.oci-containers.containers.redis = lib.dot.mkOci "redis" {
          image = "bitnami/redis";
          environmentFiles = [ (lib.dot.containerEnvFile "redis") ];
          volumes = [ "${lib.dot.containerDataDir "redis"}:/bitnami/redis/data" ];
        };
        systemd.services.podman-redis = lib.dot.mkContainerSecretDeps "redis" [ ];
      };
  };
}
