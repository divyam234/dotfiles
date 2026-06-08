{ den, ... }:
{
  den.aspects.restic = {
    nixos =
      { config, lib, ... }:
      {
        sops.secrets."restic/password".sopsFile = ../../../hosts/netcup/secrets.yaml;
        sops.secrets."restic/repository".sopsFile = ../../../hosts/netcup/secrets.yaml;
        sops.secrets."restic/rclone_conf".sopsFile = ../../../hosts/netcup/secrets.yaml;

        services.restic.backups.netcup = {
          initialize = true;
          paths = [ lib.dot.containerDataRoot ];
          passwordFile = config.sops.secrets."restic/password".path;
          repository = config.sops.secrets."restic/repository".path;
          rcloneConfigFile = config.sops.secrets."restic/rclone_conf".path;
          timerConfig = {
            OnCalendar = "03:30";
            Persistent = true;
          };
          pruneOpts = [
            "--keep-daily 3"
            "--keep-weekly 2"
          ];
        };
      };
  };
}
