{ den, ... }:
let
  resizeParam = variable: params:
    builtins.concatStringsSep "\n" (
      map (param:
        let
          query = "{http.request.uri.query.${param}}";
          condition = if variable == "format" then '' && !${query}.matches("(?i)^auto$")'' else "";
        in
        ''
          @stash_${param} expression ${query} != ""${condition}
          vars @stash_${param} resize_${variable} ${query}
        ''
      ) params
    );

  stashSecrets = [
    "postgres/user"
    "postgres/password"
    "stash/secret_key"
  ];

  stashEnv = secrets: ''
    STASH_DATABASE_URL=postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres
    STASH_SECRET_KEY=${secrets.stash.secret_key}
    RCLONE_CONFIG=postgres://${secrets.postgres.user}:${secrets.postgres.password}@pgdog:6432/postgres?schema=rclone&init_schema=false
  '';

  mkEnvTemplate =
    name: secrets:
    secrets.mkTemplate {
      inherit name;
      content = stashEnv secrets;
    };

  mkStashContainer =
    {
      exec,
      envTemplate,
      unitAfter ? [ ],
      unitRequires ? [ ],
      unitWants ? [ ],
      containerExtra ? { },
      serviceExtra ? { },
    }:
    { containers }:
    {
      containerConfig = {
        image = "ghcr.io/elevatedai/stash";
        inherit exec;
        environmentFiles = [ "${containers.secretDir}/${envTemplate}" ];
      }
      // containerExtra;
      unitConfig = {
        After = unitAfter;
        Requires = unitRequires;
        Wants = unitWants;
      };
      serviceConfig = serviceExtra;
    };
in
{
  den.aspects.stash = { user, host, ... }: {
    includes = [ den.aspects.imgresize ];

    nixosSecrets = stashSecrets;

    caddyRoutes.stash = {
      host = "stash.${host.domain}";
      access = "public";
      proxied = true;
      auth = true;
      upstreams = [ "stash:8080" ];
      extraConfig = ''
        @stashResize {
          method GET HEAD
          path /api/assets/* /api/gallery-images/*
          expression {http.request.uri.query.w} != "" || {http.request.uri.query.width} != "" || {http.request.uri.query.h} != "" || {http.request.uri.query.height} != ""
        }
        handle @stashResize {
          route {
            vars {
              resize_width 0
              resize_height 0
              resize_fit inside
              resize_quality 82
              resize_format jpeg
            }
            @stashPng header Accept *image/png*
            vars @stashPng resize_format png
            @stashWebp header Accept *image/webp*
            vars @stashWebp resize_format webp
            ${resizeParam "width" [ "width" "w" ]}
            ${resizeParam "height" [ "height" "h" ]}
            ${resizeParam "fit" [ "fit" ]}
            ${resizeParam "quality" [ "quality" "q" ]}
            ${resizeParam "format" [ "f" "format" ]}
            header Vary Accept
            reverse_proxy imgresize:8080 {
              method GET
              rewrite /resize?url=http://stash:8080{http.request.uri.path}&w={http.vars.resize_width}&h={http.vars.resize_height}&fit={http.vars.resize_fit}&q={http.vars.resize_quality}&format={http.vars.resize_format}
            }
          }
        }
      '';
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
        sops.templates."stash.env" = mkEnvTemplate "stash.env" secrets;

        virtualisation.quadlet.containers.stash = mkStashContainer {
          exec = "serve";
          envTemplate = "stash.env";
          unitAfter = [
            "tailscale-autoconnect.service"
            quadlet.containers.postgres.ref
            "postgres-provision.service"
          ];
          unitRequires = [
            quadlet.containers.postgres.ref
            "postgres-provision.service"
          ];
          unitWants = [ "tailscale-autoconnect.service" ];
          containerExtra = {
            networkAliases = [ "stash" ];
            environments = {
              RCLONE_CACHE_DIR = "/var/cache/rclone";
              RCLONE_VFS_CACHE_MODE = "full";
              RCLONE_VFS_CACHE_MAX_AGE = "8670h";
              RCLONE_VFS_CACHE_MAX_SIZE = "300GiB";
              RCLONE_DIR_CACHE_TIME = "8670h";
              RCLONE_POLL_INTERVAL = "1s";
            };
            volumes = [
              "/var/cache/rclone:/var/cache/rclone"
            ];
          };
          serviceExtra = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -dm750 -o ${user.userName} -g users /var/cache/rclone";
            MemoryMax = "4G";
          };
        } { inherit containers; };
      };
  };

  den.aspects.stash-worker = { user, ... }: {
    nixosSecrets = stashSecrets;

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
        sops.templates."stash-worker.env" = mkEnvTemplate "stash-worker.env" secrets;

        virtualisation.quadlet.containers.stash-worker = mkStashContainer {
          exec = "worker";
          envTemplate = "stash-worker.env";
          unitAfter = [
            quadlet.containers.postgres.ref
            "postgres-provision.service"
          ];
          unitRequires = [
            quadlet.containers.postgres.ref
            "postgres-provision.service"
          ];
          containerExtra = {
            volumes = [ "/home/${user.userName}/downloads:/downloads" ];
            environments = {
              STASH_CAMOFLARE_URL = "http://host.containers.internal:8191";
            };
          };
          serviceExtra = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -dm750 -o ${user.userName} -g users /home/${user.userName}/downloads";
            TimeoutStopSec = "70s";
          };
        } { inherit containers; };
      };
  };
}
