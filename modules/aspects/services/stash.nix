{ den, ... }:
let
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

  authTemplateName = "stash-auth.json";
  authFile = containers: "${containers.secretDir}/${authTemplateName}";
  authEnv = containers: "REGISTRY_AUTH_FILE=${authFile containers}";

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
      serviceConfig = {
        Environment = [ (authEnv containers) ];
      }
      // serviceExtra;
    };
in
{
  den.aspects.stash-ghcr-auth = _: {
    nixosSecrets = [ "ghcr/auth" ];

    nixos =
      { containers, secrets, ... }:
      {
        sops.templates.${authTemplateName} = secrets.mkTemplate {
          name = authTemplateName;
          content = ''{"auths":{"ghcr.io":{"auth":"${secrets.ghcr.auth}"}}}'' + "\n";
        };

        systemd.services.podman-auto-update.serviceConfig.Environment = [
          (authEnv containers)
        ];
      };
  };

  den.aspects.stash = { user, host, ... }: {
    includes = [ den.aspects.stash-ghcr-auth ];

    nixosSecrets = stashSecrets;

    caddyRoutes.stash = {
      host = "stash.${host.domain}";
      access = "public";
      proxied = true;
      auth = true;
      upstreams = [ "stash:8080" ];
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
              STASH_IMAGE_CACHE_DIR = "/var/cache/images";
              STASH_IMAGE_CACHE_MAX_SIZE = "30G";
              GOMAXPROCS = "4";
            };
            volumes = [
              "/var/cache/rclone:/var/cache/rclone"
              "/var/cache/images:/var/cache/images"
            ];
          };
          serviceExtra = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -dm750 -o ${user.userName} -g users /var/cache/rclone /var/cache/images";
            MemoryMax = "2G";
            CPUQuota = "400%";
          };
        } { inherit containers; };
      };
  };

  den.aspects.stash-worker = { user, ... }: {
    includes = [ den.aspects.stash-ghcr-auth ];

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
