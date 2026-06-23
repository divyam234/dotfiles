{ den, ... }:
{
  den.aspects.caddy = { user, ... }: {
    includes = [ den.aspects.oci-service ];
    ociSecrets = [ "caddy" ];
    containerDataDirs = {
      caddy = {
        user = user.userName;
        group = "users";
      };
      "caddy-config" = {
        user = user.userName;
        group = "users";
      };
    };

    nixos =
      {
        config,
        caddyLayer4Routes,
        caddyRoutes,
        containers,
        lib,
        host,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
        global = {
          email = acmeEmail;
          admin = "off";
          debug = false;
          extraGlobalConfig = [ ];
          layer4Routes = lib.flatten caddyLayer4Routes;
        };
        routes = lib.foldl' lib.recursiveUpdate { } caddyRoutes;
        acmeEmail = if (host.caddyEmail or null) != null then host.caddyEmail else "admin@${host.domain}";
      in
      {
        config = {
          environment.etc."caddy/Caddyfile".text = lib.denful.mkCaddyfile {
            inherit global routes;
          };

          systemd.services.caddy.restartTriggers = [
            config.environment.etc."caddy/Caddyfile".source
          ];

          virtualisation.quadlet.containers.caddy = {
            autoStart = true;
            containerConfig = {
              name = "caddy";
              image = "ghcr.io/tgdrive/caddy";
              networks = [ quadlet.networks.${containers.networkName}.ref ];
              networkAliases = [ "caddy" ];
              environmentFiles = [ "${containers.secretDir}/caddy.env" ];
              publishPorts = [
                "80:80"
                "443:443"
                "443:443/udp"
              ];
              volumes = [
                "/etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro"
                "${containers.dataRoot}/caddy:/data"
                "${containers.dataRoot}/caddy-config:/config"
              ];
              healthCmd = "caddy version >/dev/null || exit 1";
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
  };
}
