{ den, ... }:
{
  den.aspects.vaultwarden = { user, host, ... }: {
    containerDataDirs.vaultwarden = {
      user = user.userName;
      group = "users";
    };
    caddyRoutes = {
      vaultwarden = {
        host = "vault.${host.domain}";
        upstreams = [ "vaultwarden:80" ];
        encode = false;
        cacheStatic = false;
        tls = "internal";
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
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        sops.templates."vaultwarden.env" = {
          path = "${containers.secretDir}/vaultwarden.env";
          mode = "0440";
          content = ''
            DOMAIN=https://vault.${host.domain}
            ADMIN_TOKEN=${secrets.vaultwarden.admin_token}
            DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@postgres/postgres?application_name=bitwarden&options=-c%20search_path%3Dbitwarden
          '';
        };

        virtualisation.quadlet.containers.vaultwarden = {
          autoStart = true;
          containerConfig = {
            name = "vaultwarden";
            image = "docker.io/vaultwarden/server:latest-alpine";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "vaultwarden" ];
            environmentFiles = [ "${containers.secretDir}/vaultwarden.env" ];
            volumes = [ "${containers.dataRoot}/vaultwarden:/data" ];
            healthCmd = "wget --spider -q http://127.0.0.1/alive || exit 1";
            autoUpdate = "registry";
          };
          unitConfig = {
            After = [ quadlet.containers.postgres.ref ];
            Requires = [ quadlet.containers.postgres.ref ];
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
