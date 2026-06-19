{ lib }:
let
  concatMapStringsSep =
    sep: f: xs:
    lib.concatStringsSep sep (map f xs);

  indent =
    prefix: text:
    concatMapStringsSep "\n" (line: if line == "" then "" else "${prefix}${line}") (
      lib.splitString "\n" text
    );

  mkStaticCache = ''
    @static path *.css *.js *.mjs *.map *.png *.jpg *.jpeg *.gif *.webp *.svg *.ico *.woff *.woff2 *.ttf *.otf
    header @static Cache-Control "public, max-age=31536000, immutable"
  '';
in
rec {
  mkCaddyTls =
    tls:
    if tls == "cloudflare" then
      ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
      ''
    else if tls == "internal" then
      ''
        tls internal
      ''
    else if tls == "off" then
      ''
        tls off
      ''
    else
      "";

  mkCaddySecurityHeaders = ''
    header {
      Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      X-Content-Type-Options "nosniff"
      X-Frame-Options "SAMEORIGIN"
      Referrer-Policy "strict-origin-when-cross-origin"
    }
  '';

  mkCaddyRoute =
    _name: route:
    let
      normalized = {
        enable = true;
        encode = true;
        cacheStatic = false;
        securityHeaders = true;
        tls = "cloudflare";
        extraConfig = "";
      }
      // route;
      tlsBlock = mkCaddyTls normalized.tls;
      cacheBlock = if normalized.cacheStatic then mkStaticCache else "";
      headersBlock = if normalized.securityHeaders then mkCaddySecurityHeaders else "";
      encodeBlock = if normalized.encode then "encode zstd gzip" else "";
      upstreams = lib.concatStringsSep " " normalized.upstreams;
      inherit (normalized) extraConfig;
    in
    ''
      ${normalized.host} {
        ${encodeBlock}
        ${tlsBlock}
        ${headersBlock}
        ${cacheBlock}
        ${extraConfig}
        reverse_proxy ${upstreams}
      }
    '';

  mkCaddyfile =
    { global, routes }:
    let
      enabledRoutes = lib.filterAttrs (_: route: route.enable or true) routes;
      renderedRoutes = lib.mapAttrsToList mkCaddyRoute enabledRoutes;
      layer4Block =
        if global.layer4Routes == [ ] then
          ""
        else
          ''
              servers {
                listener_wrappers {
                  layer4 {
            ${indent "        " (lib.concatStringsSep "\n\n" global.layer4Routes)}
                  }
                  tls
                }
              }
          '';
      globalOptions = lib.concatStringsSep "\n" (
        [
          "email ${global.email}"
          "admin ${global.admin}"
        ]
        ++ lib.optional global.debug "debug"
        ++ lib.optional (layer4Block != "") layer4Block
        ++ global.extraGlobalConfig
      );
    in
    ''
      {
      ${indent "  " globalOptions}
      }

      ${lib.concatStringsSep "\n\n" renderedRoutes}
    '';
}
