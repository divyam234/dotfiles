{ den, ... }:
{
  den.schema.host =
    { lib, ... }:
    {
      options = {
        caddyEmail = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ACME contact email. Defaults to admin@domain when unset.";
        };

        caddy = lib.mkOption {
          type = lib.types.submodule {
            options.cacheDir = lib.mkOption {
              type = lib.types.str;
              default = "/var/cache/caddy";
              description = "Host directory mounted as the Caddy cache.";
            };
          };
          default = { };
          description = "Host-specific Caddy settings.";
        };
      };
    };

  den.aspects.caddy = { user, ... }: {
    nixosSecrets = [ "cloudflare/api_token" ];

    nixos =
      {
        config,
        caddyLayer4Routes,
        caddyRoutes,
        containers,
        lib,
        dotfiles,
        host,
        pkgs,
        secrets,
        ...
      }:
      let
        routes = lib.pipe caddyRoutes [ (lib.foldl' lib.recursiveUpdate { }) ];
        routeList = lib.pipe routes [
          (lib.mapAttrsToList (name: route: route // { inherit name; }))
        ];
        duplicateRouteNames = lib.pipe caddyRoutes [
          (lib.concatMap builtins.attrNames)
          dotfiles.findDuplicates
        ];
        duplicateRouteHosts = lib.pipe routeList [
          (map (route: route.host))
          dotfiles.findDuplicates
        ];
        duplicateLayer4Routes = lib.pipe caddyLayer4Routes [
          lib.flatten
          dotfiles.findDuplicates
        ];
        cacheDir = host.caddy.cacheDir;
        publicRoutes = lib.pipe routeList [
          (lib.filter (route: (route.access or null) == "public"))
        ];
        tailnetRoutes = lib.pipe routeList [
          (lib.filter (route: (route.access or null) == "tailnet"))
        ];
        invalidAccessRoutes = lib.pipe routeList [
          (lib.filter (
            route:
            !(builtins.elem (route.access or null) [
              "public"
              "tailnet"
            ])
          ))
        ];
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
              assertion = duplicateLayer4Routes == [ ];
              message = "Duplicate Caddy layer4 route snippets: ${lib.concatStringsSep ", " duplicateLayer4Routes}";
            }
            {
              assertion = lib.all (route: builtins.hasAttr "access" route) routeList;
              message = "Every Caddy route must declare access = public or tailnet.";
            }
            {
              assertion = invalidAccessRoutes == [ ];
              message = "Caddy route access must be public or tailnet: ${
                lib.concatStringsSep ", " (map (r: r.name or r.host or "unknown") invalidAccessRoutes)
              }";
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

          environment.etc."caddy/Caddyfile".text = dotfiles.mkCaddyfile {
            inherit global routes;
          };

          sops.templates."caddy.env" = secrets.mkTemplate {
            name = "caddy.env";
            content = ''
              CLOUDFLARE_API_TOKEN=${secrets.cloudflare.api_token}
            '';
          };

          systemd.services.caddy.restartTriggers = [
            config.environment.etc."caddy/Caddyfile".source
          ];

          virtualisation.quadlet.containers.caddy = {
            containerConfig = {
              image = "ghcr.io/tgdrive/caddy";
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
                "${cacheDir}:/var/cache/caddy"
              ];
            };
            unitConfig.RequiresMountsFor = [ cacheDir ];
            serviceConfig = {
              ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/caddy ${containers.dataRoot}/caddy-config ${cacheDir}";
              MemoryMax = "2G";
              CPUQuota = "100%";
            };
          };
        };
      };
  };
}
