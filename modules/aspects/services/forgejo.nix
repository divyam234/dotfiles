{ den, ... }:
{
  den.aspects.forgejo = { user, host, ... }: {
    caddyRoutes = {
      forgejo = {
        host = "git.${host.domain}";
        upstreams = [ "forgejo:3000" ];
        cacheStatic = true;
        extraConfig = ''
          request_body {
            max_size 512MB
          }
        '';
      };
    };

    nixos =
      {
        config,
        containers,
        pkgs,
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        sops.templates."forgejo.env" = {
          path = "${containers.secretDir}/forgejo.env";
          mode = "0440";
          content = ''
            FORGEJO__database__DB_TYPE=postgres
            FORGEJO__database__HOST=pgdog:6432
            FORGEJO__database__NAME=postgres
            FORGEJO__database__USER=${secrets.postgres.user}
            FORGEJO__database__PASSWD=${secrets.postgres.password}
            FORGEJO__database__SCHEMA=forgejo
            # FORGEJO__database__SSL_MODE=disable
            # FORGEJO__server__DISABLE_SSH=false
            # FORGEJO__server__START_SSH_SERVER=true
            # FORGEJO__server__SSH_SERVER_USE_PROXY_PROTOCOL=false
            # FORGEJO__server__SSH_PORT=443
            # FORGEJO__server__SSH_LISTEN_PORT=2240
          '';
        };

        virtualisation.quadlet.containers.forgejo = {
          autoStart = true;
          containerConfig = {
            name = "forgejo";
            image = "codeberg.org/forgejo/forgejo:15";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "forgejo" ];
            environmentFiles = [ "${containers.secretDir}/forgejo.env" ];
            volumes = [
              "${containers.dataRoot}/forgejo:/data:rw"
              # "/etc/localtime:/etc/localtime:ro"
            ];
            autoUpdate = "registry";
          };
          unitConfig = {
            After = [ quadlet.containers.pgdog.ref ];
            Requires = [ quadlet.containers.pgdog.ref ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/forgejo";
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "1G";
            CPUQuota = "150%";
          };
        };
      };
  };
}
