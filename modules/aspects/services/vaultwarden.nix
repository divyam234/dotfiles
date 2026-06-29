{ den, ... }:
{
  den.aspects.vaultwarden = { user, host, ... }: {
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
        pkgs,
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
            autoUpdate = "registry";
          };
          unitConfig = {
            After = [ quadlet.containers.postgres.ref ];
            Requires = [ quadlet.containers.postgres.ref ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/vaultwarden";
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
