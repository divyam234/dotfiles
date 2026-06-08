{ den, ... }:
{
  den.aspects.caddy = {
    includes = [
      den.aspects.oci-base
      den.aspects.container-network
      den.aspects.container-secrets
    ];

    nixos = { config, lib, host, user, ... }:
      let
        acmeEmail = if host.caddyEmail != null then host.caddyEmail else user.email;
      in
      {
        dot.caddy.global.email = lib.mkDefault acmeEmail;

        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "caddy" "caddy-config" ];

        environment.etc."caddy/Caddyfile".text = lib.dot.mkCaddyfile {
          global = config.dot.caddy.global;
          routes = config.dot.caddy.routes;
        };

        virtualisation.oci-containers.containers.caddy = lib.dot.mkOci "caddy" {
          image = "ghcr.io/tgdrive/caddy";
          environmentFiles = [ (lib.dot.containerEnvFile "caddy") ];
          ports = [ "80:80" "443:443" "443:443/udp" ];
          volumes = [
            "/etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro"
            "${lib.dot.containerDataDir "caddy"}:/data"
            "${lib.dot.containerDataDir "caddy-config"}:/config"
          ];
        };

        systemd.services.podman-caddy = lib.dot.mkContainerDeps "caddy";

        networking.firewall.allowedTCPPorts = [ 80 443 ];
        networking.firewall.allowedUDPPorts = [ 443 ];
      };
  };
}
