{ den, ... }:
{
  den.aspects.siyuan = { user, host, ... }: {
    containerDataDirs.siyuan = {
      user = user.userName;
      group = "users";
    };
    caddyRoutes = {
      siyuan = {
        host = "notes.${host.domain}";
        upstreams = [ "siyuan:6806" ];
      };
    };

    nixos =
      {
        config,
        containers,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        virtualisation.quadlet.containers.siyuan = {
          autoStart = true;
          containerConfig = {
            name = "siyuan";
            image = "docker.io/b3log/siyuan";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "siyuan" ];
            exec = [ "--workspace=/siyuan/workspace" ];
            environments = {
              RUN_IN_CONTAINER = "true";
              SIYUAN_ACCESS_AUTH_CODE_BYPASS = "true";
              TZ = "UTC";
            };
            volumes = [ "${containers.dataRoot}/siyuan:/siyuan/workspace" ];
            autoUpdate = "registry";
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "1G";
            CPUQuota = "100%";
          };
        };
      };
  };
}
