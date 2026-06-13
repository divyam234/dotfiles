{ den, ... }:
{
  den.aspects.restic = {
    nixos =
      {
        config,
        host,
        lib,
        ...
      }:
      let
        secretsFile = host.secretsFile;
      in
      {
        assertions = [
          {
            assertion = secretsFile != null;
            message = "Host ${host.name} enables restic but does not set host.secretsFile.";
          }
        ];

        sops.secrets = lib.mkIf (secretsFile != null) {
          "restic/password".sopsFile = secretsFile;
          "restic/repository".sopsFile = secretsFile;
          "restic/rclone_conf".sopsFile = secretsFile;
        };

        services.restic.backups.netcup = {
          initialize = true;
          paths = [ config.dot.containers.dataRoot ];
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
