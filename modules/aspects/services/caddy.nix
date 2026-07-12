{ den, ... }:
{
  den.aspects.caddy = { user, ... }: {
    nixos =
      {
        config,
        caddyLayer4Routes,
        caddyRoutes,
        containers,
        lib,
        host,
        pkgs,
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
        routeNames = lib.concatMap builtins.attrNames caddyRoutes;
        duplicateRouteNames = lib.filter (
          name: builtins.length (lib.filter (candidate: candidate == name) routeNames) > 1
        ) (lib.unique routeNames);
        routes = lib.foldl' lib.recursiveUpdate { } caddyRoutes;
        routeList = lib.mapAttrsToList (name: route: route // { inherit name; }) routes;
        routeHosts = map (route: route.host) routeList;
        duplicateRouteHosts = lib.filter (
          name: builtins.length (lib.filter (candidate: candidate == name) routeHosts) > 1
        ) (lib.unique routeHosts);
        publicRoutes = lib.filter (route: (route.access or null) == "public") routeList;
        tailnetRoutes = lib.filter (route: (route.access or null) == "tailnet") routeList;
        acmeEmail = if (host.caddyEmail or null) != null then host.caddyEmail else "admin@${host.domain}";
        global = {
          email = acmeEmail;
          admin = "off";
          debug = false;
          extraGlobalConfig = [ ];
          layer4Routes = lib.flatten caddyLayer4Routes;
        };
      in
      {
        config = {
          assertions = [
            {
              assertion = duplicateRouteNames == [ ];
              message = "Duplicate Caddy route quirk names: ${lib.concatStringsSep ", " duplicateRouteNames}";
            }
            {
              assertion = lib.all (route: builtins.hasAttr "access" route) routeList;
              message = "Every Caddy route must declare access = public or tailnet.";
            }
            {
              assertion = lib.all (
                route:
                builtins.elem (route.access or null) [
                  "public"
                  "tailnet"
                ]
              ) routeList;
              message = "Caddy route access must be public or tailnet.";
            }
            {
              assertion = duplicateRouteHosts == [ ];
              message = "Duplicate Caddy route hosts: ${lib.concatStringsSep ", " duplicateRouteHosts}";
            }
            {
              assertion =
                publicRoutes == [ ] || host.dns.publicTarget.ipv4.enable || host.dns.publicTarget.ipv6.enable;
              message = "Public Caddy routes require at least one enabled public DNS address family.";
            }
            {
              assertion =
                !host.dns.publicTarget.ipv4.enable
                || host.dns.publicTarget.ipv4.source != "static"
                || host.dns.publicTarget.ipv4.address != null;
              message = "Static public IPv4 DNS requires host.dns.publicTarget.ipv4.address.";
            }
            {
              assertion =
                !host.dns.publicTarget.ipv6.enable
                || host.dns.publicTarget.ipv6.source != "static"
                || host.dns.publicTarget.ipv6.address != null;
              message = "Static public IPv6 DNS requires host.dns.publicTarget.ipv6.address.";
            }
            {
              assertion = tailnetRoutes == [ ] || config.services.tailscale.enable;
              message = "Tailnet Caddy routes require the Tailscale service.";
            }
            {
              assertion = lib.all (route: !(route.proxied or false)) tailnetRoutes;
              message = "Tailnet Caddy routes cannot use the Cloudflare proxy.";
            }
          ];

          environment.etc."caddy/Caddyfile".text = lib.denful.mkCaddyfile {
            inherit global routes;
          };

          sops.templates."caddy.env" = {
            path = "${containers.secretDir}/caddy.env";
            mode = "0440";
            content = ''
              CLOUDFLARE_API_TOKEN=${secrets.cloudflare.api_token}
            '';
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
              healthCmd = "caddy version > /dev/null || exit 1";
              autoUpdate = "registry";
            };
            serviceConfig = {
              ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/caddy ${containers.dataRoot}/caddy-config";
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
