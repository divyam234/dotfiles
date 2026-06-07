{ den, ... }:
{
  den.aspects.restic = {
    nixos = { config, lib, ... }: {
      sops.secrets."restic/password".sopsFile = ../../../hosts/netcup/secrets.yaml;
      sops.secrets."restic/repository".sopsFile = ../../../hosts/netcup/secrets.yaml;
      sops.secrets."restic/rclone_conf".sopsFile = ../../../hosts/netcup/secrets.yaml;

      sops.templates."restic-env" = {
        path = lib.dot.containerEnvFile "restic";
        mode = "0400";
        content = ''
          RESTIC_REPOSITORY=${config.sops.placeholder."restic/repository"}
          RCLONE_CONFIG=${config.sops.placeholder."restic/rclone_conf"}
        '';
      };

      services.restic.backups.netcup = {
        initialize = true;
        paths = [ lib.dot.containerDataRoot "/etc/caddy" ];
        passwordFile = config.sops.secrets."restic/password".path;
        repositoryFile = config.sops.secrets."restic/repository".path;
        rcloneConfigFile = config.sops.secrets."restic/rclone_conf".path;
        timerConfig = {
          OnCalendar = "03:30";
          Persistent = true;
        };
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
      };
    };
  };
}
