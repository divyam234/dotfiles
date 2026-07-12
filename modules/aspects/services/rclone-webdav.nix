{ den, ... }:
{
  den.aspects.rclone-webdav = { host, user, ... }: {
    caddyRoutes.rclone-webdav = {
      host = "media.${host.domain}";
      access = "tailnet";
      proxied = false;
      upstreams = [ "host.containers.internal:${toString host.rcloneWebdav.port}" ];
    };

    nixos =
      {
        containers,
        host,
        lib,
        pkgs,
        secrets,
        user,
        ...
      }:
      let
        cfg = host.rcloneWebdav;
        environmentFile = "/run/secrets/rclone-webdav.env";
      in
      {
        sops.templates."rclone-webdav.env" = {
          path = environmentFile;
          mode = "0400";
          content = ''
            RCLONE_CONFIG="${secrets.rclone.postgres_url}&config_name=${host.name}"
          '';
        };

        networking.firewall.interfaces."br-${containers.networkName}".allowedTCPPorts = [ cfg.port ];

        systemd.services.rclone-webdav = {
          description = "Rclone WebDAV server";
          after = [
            "network-online.target"
            "tailscale-autoconnect.service"
          ];
          wants = [
            "network-online.target"
            "tailscale-autoconnect.service"
          ];
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ cfg.cacheDir ];
          serviceConfig = {
            Type = "simple";
            User = user.userName;
            Group = "users";
            EnvironmentFile = environmentFile;
            ExecStartPre = "+${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${lib.escapeShellArg cfg.cacheDir}";
            Restart = "on-failure";
            RestartSec = "10s";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
            ReadWritePaths = [ cfg.cacheDir ];
            MemoryMax = "2G";
            CPUQuota = "200%";
          };
          script = ''
            exec ${pkgs.rclone}/bin/rclone serve webdav ${lib.escapeShellArg cfg.remote} \
              --addr ${lib.escapeShellArg "0.0.0.0:${toString cfg.port}"} \
              --vfs-cache-mode full \
              --vfs-read-chunk-size 128Mi \
              --vfs-read-chunk-size-limit 128Mi \
              --vfs-read-ahead 384Mi \
              --buffer-size 32Mi \
              --cache-dir ${lib.escapeShellArg cfg.cacheDir} \
              --vfs-cache-max-age ${lib.escapeShellArg cfg.cacheMaxAge} \
              --vfs-cache-max-size ${lib.escapeShellArg cfg.cacheMaxSize}
          '';
        };
      };
  };
}
