{ den, ... }:
{
  den.aspects.redis = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { config, ... }:
      let
        quadlet = config.virtualisation.quadlet;
        containers = config.dot.containers;
      in
      {
        dot.oci.secrets.redis.enable = true;
        dot.containers.dataDirs.redis = {
          inherit (containers.owners.bitnami) user group;
        };
        virtualisation.quadlet.containers.redis = {
          autoStart = true;
          containerConfig = {
            name = "redis";
            image = "docker.io/bitnami/redis";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "redis" ];
            environmentFiles = [ "${containers.secretDir}/redis.env" ];
            volumes = [ "${containers.dataRoot}/redis:/bitnami/redis/data" ];
            healthCmd = "redis-cli -a $REDIS_PASSWORD ping | grep -q PONG";
            autoUpdate = "registry";
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}
