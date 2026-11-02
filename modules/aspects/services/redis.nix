{ den, ... }:
{
  den.aspects.redis = _: {
    nixosSecrets = [ "redis/password" ];

    nixos =
      {
        containers,
        pkgs,
        secrets,
        ...
      }:
      {
        virtualisation.quadlet.containers.redis = {
          secretEnvironment.REDIS_PASSWORD = secrets.redis.password;
          containerConfig = {
            image = "docker.io/bitnami/redis";
            networkAliases = [ "redis" ];
            volumes = [ "${containers.dataRoot}/redis:/bitnami/redis/data" ];
            healthCmd = "redis-cli -a $REDIS_PASSWORD ping | grep -q PONG";
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o 1001 -g 0 ${containers.dataRoot}/redis";
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}
