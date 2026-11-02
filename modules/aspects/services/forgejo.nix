{ den, ... }:
{
  den.aspects.forgejo = { user, host, ... }: {
    nixosSecrets = [
      "postgres/user"
      "postgres/password"
    ];

    caddyRoutes = {
      forgejo = {
        host = "git.${host.domain}";
        access = "tailnet";
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
        virtualisation.quadlet.containers.forgejo = {
          secretEnvironment = {
            FORGEJO__database__USER = secrets.postgres.user;
            FORGEJO__database__PASSWD = secrets.postgres.password;
          };
          containerConfig = {
            image = "codeberg.org/forgejo/forgejo:16";
            networkAliases = [ "forgejo" ];
            environments = {
              FORGEJO__database__DB_TYPE = "postgres";
              FORGEJO__database__HOST = "pgdog:6432";
              FORGEJO__database__NAME = "postgres";
              FORGEJO__database__SCHEMA = "forgejo";
            };
            volumes = [
              "${containers.dataRoot}/forgejo:/data:rw"
              # "/etc/localtime:/etc/localtime:ro"
            ];
          };
          unitConfig = {
            After = [ quadlet.containers.pgdog.ref ];
            Requires = [ quadlet.containers.pgdog.ref ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/forgejo";
            MemoryMax = "1G";
            CPUQuota = "150%";
          };
        };
      };
  };
}
