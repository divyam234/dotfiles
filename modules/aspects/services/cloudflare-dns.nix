{ den, ... }:
{
  den.aspects.cloudflare-dns = {
    nixos =
      {
        caddyRoutes,
        config,
        host,
        lib,
        pkgs,
        secrets,
        ...
      }:
      let
        routes = lib.foldl' lib.recursiveUpdate { } caddyRoutes;
        enabledRoutes = lib.filterAttrs (_: route: route.enable or true) routes;
        routeList = lib.mapAttrsToList (_: route: route) enabledRoutes;
        publicRoutes = lib.filter (route: route.access == "public") routeList;
        tailnetRoutes = lib.filter (route: route.access == "tailnet") routeList;
        owner = "managed-by=nixos-dns:${host.name}";
        publicTarget = host.dns.publicTarget;
        mkPublicRecords =
          route:
          lib.optional publicTarget.ipv4.enable {
            name = route.host;
            proxied = route.proxied or false;
            type = "A";
            target = "public-ipv4";
          }
          ++ lib.optional publicTarget.ipv6.enable {
            name = route.host;
            proxied = route.proxied or false;
            type = "AAAA";
            target = "public-ipv6";
          };
        mkTailnetRecord = route: {
          name = route.host;
          proxied = false;
          type = "A";
          target = "tailscale-ipv4";
        };
        manifest = pkgs.writeText "cloudflare-dns-manifest.json" (
          builtins.toJSON {
            zone = host.domain;
            ttl = 300;
            inherit owner;
            inherit publicTarget;
            records = lib.concatMap mkPublicRecords publicRoutes ++ map mkTailnetRecord tailnetRoutes;
          }
        );
        hasTailnetRoutes = tailnetRoutes != [ ];
      in
      {
        assertions = [
          {
            assertion = lib.all (route: lib.hasSuffix ".${host.domain}" route.host) routeList;
            message = "Cloudflare DNS routes must be subdomains of ${host.domain}.";
          }
        ];

        environment.etc."cloudflare-dns/manifest.json".source = manifest;

        sops.templates."cloudflare-dns.env" = {
          path = "/run/secrets/cloudflare-dns.env";
          mode = "0400";
          content = ''
            CLOUDFLARE_API_TOKEN=${secrets.cloudflare.api_token}
          '';
        };

        systemd.services.cloudflare-dns-sync = {
          description = "Reconcile route DNS records with Cloudflare";
          after = [
            "network-online.target"
            "sops-install-secrets.service"
          ]
          ++ lib.optional hasTailnetRoutes "tailscale-autoconnect.service";
          requires = [ "sops-install-secrets.service" ];
          wants = [
            "network-online.target"
          ]
          ++ lib.optional hasTailnetRoutes "tailscale-autoconnect.service";
          wantedBy = [ "multi-user.target" ];
          restartTriggers = [ manifest ];
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = config.sops.templates."cloudflare-dns.env".path;
          };
          path = [
            pkgs.curl
            pkgs.coreutils
            pkgs.iproute2
            pkgs.jq
            pkgs.tailscale
          ];
          script = ''
            set -euo pipefail

            manifest='${manifest}'
            api='https://api.cloudflare.com/client/v4'

            cloudflare() {
              local response
              response="$(curl --fail-with-body --silent --show-error \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H 'Content-Type: application/json' \
                "$@")"
              jq -e '.success == true' <<<"$response" >/dev/null || {
                jq -c '.errors // .' <<<"$response" >&2
                return 1
              }
              printf '%s' "$response"
            }

            zone="$(jq -r '.zone' "$manifest")"
            owner="$(jq -r '.owner' "$manifest")"
            ttl="$(jq -r '.ttl' "$manifest")"
            public_ipv4_source="$(jq -r '.publicTarget.ipv4.source' "$manifest")"
            public_ipv6_source="$(jq -r '.publicTarget.ipv6.source' "$manifest")"
            public_ipv4="$(jq -r '.publicTarget.ipv4.address // empty' "$manifest")"
            public_ipv6="$(jq -r '.publicTarget.ipv6.address // empty' "$manifest")"

            discover_address() {
              local family="$1"
              curl "-$family" --fail --location --silent --show-error https://one.one.one.one/cdn-cgi/trace \
                | while IFS='=' read -r key value; do
                    if [ "$key" = ip ]; then
                      printf '%s' "$value"
                      break
                    fi
                  done
            }

            local_address() {
              local family="$1"
              local destination
              if [ "$family" = 4 ]; then
                destination=1.1.1.1
              else
                destination=2606:4700:4700::1111
              fi
              ip -j "-$family" route get "$destination" \
                | jq -er '.[0].prefsrc // .[0].src'
            }

            zone_response="$(cloudflare --get --data-urlencode "name=$zone" --data-urlencode 'status=active' "$api/zones")"
            zone_id="$(jq -er '.result | if length == 1 then .[0].id else error("expected exactly one active zone") end' <<<"$zone_response")"
            tailscale_ipv4=""

            jq -c '.records[]' "$manifest" | while IFS= read -r record; do
              name="$(jq -r '.name' <<<"$record")"
              type="$(jq -r '.type' <<<"$record")"
              target="$(jq -r '.target' <<<"$record")"
              proxied="$(jq -r '.proxied' <<<"$record")"

              case "$target" in
                public-ipv4)
                  if [ -z "$public_ipv4" ]; then
                    case "$public_ipv4_source" in
                      local) public_ipv4="$(local_address 4)" ;;
                      external) public_ipv4="$(discover_address 4)" ;;
                    esac
                  fi
                  content="$public_ipv4"
                  ;;
                public-ipv6)
                  if [ -z "$public_ipv6" ]; then
                    case "$public_ipv6_source" in
                      local) public_ipv6="$(local_address 6)" ;;
                      external) public_ipv6="$(discover_address 6)" ;;
                    esac
                  fi
                  content="$public_ipv6"
                  ;;
                tailscale-ipv4)
                  if [ -z "$tailscale_ipv4" ]; then
                    tailscale_ipv4="$(tailscale ip -4 | head -n1)"
                  fi
                  content="$tailscale_ipv4"
                  ;;
                *)
                  printf 'Unsupported DNS target %s for %s\n' "$target" "$name" >&2
                  exit 1
                  ;;
              esac

              [ -n "$content" ] || {
                printf 'No address available for %s\n' "$name" >&2
                exit 1
              }

              payload="$(jq -cn \
                --arg type "$type" \
                --arg name "$name" \
                --arg content "$content" \
                --arg owner "$owner" \
                --argjson ttl "$ttl" \
                --argjson proxied "$proxied" \
                '{type: $type, name: $name, content: $content, ttl: $ttl, proxied: $proxied, comment: $owner}')"
              records_response="$(cloudflare --get \
                --data-urlencode "type=$type" \
                --data-urlencode "name=$name" \
                "$api/zones/$zone_id/dns_records")"
              record_count="$(jq '.result | length' <<<"$records_response")"

              if [ "$record_count" -eq 0 ]; then
                cloudflare -X POST --data "$payload" "$api/zones/$zone_id/dns_records" >/dev/null
                printf 'Created %s %s\n' "$type" "$name"
                continue
              fi

              [ "$record_count" -eq 1 ] || {
                printf 'Refusing to adopt multiple %s records for %s\n' "$type" "$name" >&2
                exit 1
              }

              record_id="$(jq -r '.result[0].id' <<<"$records_response")"
              current_owner="$(jq -r '.result[0].comment // empty' <<<"$records_response")"
              if [ -n "$current_owner" ] && [ "$current_owner" != "$owner" ]; then
                printf 'Refusing to overwrite %s %s owned by %s\n' "$type" "$name" "$current_owner" >&2
                exit 1
              fi
              current="$(jq -c '.result[0] | {content, ttl, proxied, comment}' <<<"$records_response")"
              desired="$(jq -c '{content, ttl, proxied, comment}' <<<"$payload")"

              if [ "$current" = "$desired" ]; then
                printf 'Unchanged %s %s\n' "$type" "$name"
              else
                cloudflare -X PUT --data "$payload" "$api/zones/$zone_id/dns_records/$record_id" >/dev/null
                printf 'Updated %s %s\n' "$type" "$name"
              fi
            done
          '';
        };

        systemd.timers.cloudflare-dns-sync = lib.mkIf (host.dns.refreshInterval != null) {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5m";
            OnUnitActiveSec = host.dns.refreshInterval;
            Persistent = true;
          };
        };
      };
  };
}
