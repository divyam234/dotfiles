{ den, ... }:
{
  den.aspects.vaultwarden = { user, host, ... }: {
    nixosSecrets = [
      "vaultwarden/admin_token"
      "postgres/user"
      "postgres/password"
    ];

    caddyRoutes = {
      vaultwarden = {
        host = "vault.${host.domain}";
        access = "public";
        proxied = true;
        upstreams = [ "vaultwarden:80" ];
        encode = false;
        cacheStatic = false;
        extraConfig = ''
          request_body {
            max_size 128MB
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
        virtualisation.quadlet.containers.vaultwarden = {
          secretEnvironment = {
            ADMIN_TOKEN = secrets.vaultwarden.admin_token;
            DATABASE_URL = "postgres://${secrets.postgres.user}:${secrets.postgres.password}@postgres/postgres?application_name=bitwarden&options=-c%20search_path%3Dbitwarden";
          };
          containerConfig = {
            image = "docker.io/vaultwarden/server:latest-alpine";
            networkAliases = [ "vaultwarden" ];
            environments.DOMAIN = "https://vault.${host.domain}";
            volumes = [ "${containers.dataRoot}/vaultwarden:/data" ];
          };
          unitConfig = {
            After = [ quadlet.containers.postgres.ref ];
            Requires = [ quadlet.containers.postgres.ref ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/vaultwarden";
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}
