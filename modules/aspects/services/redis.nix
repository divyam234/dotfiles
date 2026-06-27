{ den, ... }:
{
  den.aspects.redis = _: {
    includes = [ den.aspects.oci-service ];
    containerDataDirs.redis = {
      user = "1001";
      group = "0";
    };

    nixos =
      {
        config,
        containers,
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        sops.templates."redis.env" = {
          path = "${containers.secretDir}/redis.env";
          mode = "0440";
          content = ''
            REDIS_PASSWORD=${secrets.redis.password}
          '';
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
