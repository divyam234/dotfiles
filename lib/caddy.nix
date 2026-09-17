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

  mkCaddyAuth = global: ''
    request_header -X-Auth-*

    reverse_proxy ${global.authUpstream} {
      method GET
      rewrite /api/verify?application=default-app
      header_up X-Forwarded-Method {http.request.method}
      header_up X-Forwarded-Uri {http.request.uri}

      @authorized status 2xx
      handle_response @authorized {
        request_header X-Auth-User-Id {rp.header.X-Auth-User-Id}
        request_header X-Auth-User-Email {rp.header.X-Auth-User-Email}
        request_header X-Auth-User-Name {rp.header.X-Auth-User-Name}
        request_header X-Auth-User-Role {rp.header.X-Auth-User-Role}
        request_header X-Auth-MFA {rp.header.X-Auth-MFA}
        request_header X-Auth-Method {rp.header.X-Auth-Method}
        request_header X-Auth-Application-Id {rp.header.X-Auth-Application-Id}
        request_header X-Auth-Application-Slug {rp.header.X-Auth-Application-Slug}
        request_header X-Auth-Public {rp.header.X-Auth-Public}
      }

      @unauthenticated status 401
      handle_response @unauthenticated {
        redir ${global.authLoginUrl}?redirect=https://{http.request.host}{http.request.uri} 302
      }
    }
  '';

  mkCaddyRoute =
    global: _name: route:
    let
      normalized = {
        enable = true;
        encode = true;
        cacheStatic = false;
        securityHeaders = true;
        auth = false;
        access = null;
        proxied = false;
        upstreams = [ ];
        extraConfig = "";
      }
      // route;
      tlsBlock = mkCaddyTls (if normalized.proxied then "internal" else "cloudflare");
      cacheBlock = if normalized.cacheStatic then mkStaticCache else "";
      headersBlock = if normalized.securityHeaders then mkCaddySecurityHeaders else "";
      encodeBlock = if normalized.encode then "encode zstd gzip" else "";
      authBlock = if normalized.auth then mkCaddyAuth global else "";
      upstreams = lib.concatStringsSep " " normalized.upstreams;
      inherit (normalized) extraConfig;
      proxyBlock = if normalized.upstreams == [ ] then "" else "reverse_proxy ${upstreams}";
    in
    ''
      ${normalized.host} {
        ${encodeBlock}
        ${tlsBlock}
        ${headersBlock}
        ${cacheBlock}
        ${extraConfig}
        ${authBlock}
        ${proxyBlock}
      }
    '';

  mkCaddyfile =
    { global, routes }:
    let
      renderedRoutes = lib.pipe routes [
        (lib.filterAttrs (_: route: route.enable or true))
        (lib.mapAttrsToList (mkCaddyRoute global))
      ];
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
