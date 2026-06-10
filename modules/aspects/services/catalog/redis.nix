{ den, ... }:
{
  den.aspects.redis = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { config, lib, ... }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        dot.oci.secrets.redis.enable = true;
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "redis" ];
        virtualisation.quadlet.containers.redis = {
          autoStart = true;
          containerConfig = {
            image = "bitnami/redis";
            networks = [ quadlet.networks.${lib.dot.containerNetwork}.ref ];
            environmentFiles = [ (lib.dot.containerEnvFile "redis") ];
            volumes = [ "${lib.dot.containerDataDir "redis"}:/bitnami/redis/data" ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
  };
}
