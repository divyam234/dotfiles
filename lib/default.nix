{
  lib,
  inputs ? { },
}:
let
  concatMapStringsSep =
    sep: f: xs:
    lib.concatStringsSep sep (map f xs);

  containerNetwork = "svc";
  containerDataRoot = "/var/lib/containers";
  containerSecretDir = "/run/secrets/container-env";

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
  inherit containerNetwork containerDataRoot containerSecretDir;

  importPackages =
    pkgs: directory:
    if builtins.pathExists directory then
      let
        entries = builtins.readDir directory;
        names = builtins.filter (
          name: entries.${name} == "directory" && builtins.pathExists (directory + "/${name}/default.nix")
        ) (builtins.attrNames entries);
      in
      builtins.listToAttrs (
        map (name: {
          inherit name;
          value = pkgs.callPackage (directory + "/${name}") { };
        }) names
      )
    else
      { };

  containerName = name: name;
  containerDataDir = name: "${containerDataRoot}/${name}";
  containerEnvFile = name: "${containerSecretDir}/${name}.env";

  mkContainerDeps =
    name: dependencies:
    let
      networkUnit = "podman-network-${containerNetwork}.service";
      dependencyUnits = map (dependency: "podman-${dependency}.service") dependencies;
      units = [ networkUnit ] ++ dependencyUnits;
    in
    {
      after = units;
      requires = units;
      wantedBy = [ "multi-user.target" ];
    };

  mkServiceDirRules =
    names:
    [ "d ${containerDataRoot} 0750 root root -" ]
    ++ map (name: "d ${containerDataRoot}/${name} 0750 root root -") names;

  mkOci =
    name: args:
    let
      networkMode = args.networkMode or containerNetwork;
    in
    {
      image = args.image;
      autoStart = args.autoStart or true;
      extraOptions = (args.extraOptions or [ ]) ++ [ "--network=${networkMode}" ];
    }
    // lib.optionalAttrs (args ? environment) { inherit (args) environment; }
    // lib.optionalAttrs (args ? environmentFiles) { inherit (args) environmentFiles; }
    // lib.optionalAttrs (args ? command) { inherit (args) command; }
    // lib.optionalAttrs (args ? entrypoint) { inherit (args) entrypoint; }
    // lib.optionalAttrs (args ? volumes) { inherit (args) volumes; }
    // lib.optionalAttrs (args ? ports) { inherit (args) ports; }
    // lib.optionalAttrs (args ? dependsOn) { inherit (args) dependsOn; }
    // lib.optionalAttrs (args ? labels) { inherit (args) labels; };

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
    name: route:
    let
      tlsBlock = mkCaddyTls route.tls;
      cacheBlock = if route.cacheStatic then mkStaticCache else "";
      headersBlock = if route.securityHeaders then mkCaddySecurityHeaders else "";
      encodeBlock = if route.encode then "encode zstd gzip" else "";
      upstreams = lib.concatStringsSep " " route.upstreams;
      extraConfig = route.extraConfig or "";
    in
    ''
      ${route.host} {
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
      enabledRoutes = lib.filterAttrs (_: route: route.enable) routes;
      renderedRoutes = lib.mapAttrsToList mkCaddyRoute enabledRoutes;
      globalOptions = lib.concatStringsSep "\n" (
        [
          "email ${global.email}"
          "admin ${global.admin}"
        ]
        ++ lib.optional global.debug "debug"
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
