{ den, ... }:
{
  den.aspects.siyuan = { user, host, ... }: {
    caddyRoutes = {
      siyuan = {
        host = "notes.${host.domain}";
        access = "tailnet";
        upstreams = [ "siyuan:6806" ];
      };
    };

    nixos =
      {
        config,
        containers,
        pkgs,
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
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/siyuan";
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
