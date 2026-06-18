{ den, ... }:
{
  den.aspects.restic = {
    nixos =
      {
        config,
        containers,
        host,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (host) secretsFile;
        backupName = host.hostName;
        postgresDumpDir = "/var/backup/postgres";
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

        systemd.tmpfiles.rules = [
          "d ${postgresDumpDir} 0750 root root -"
        ];

        services.restic.backups.${backupName} = {
          initialize = true;
          paths = [
            containers.dataRoot
            postgresDumpDir
          ];
          exclude = [
            "${containers.dataRoot}/hermes"
          ];
          passwordFile = config.sops.secrets."restic/password".path;
          repositoryFile = config.sops.secrets."restic/repository".path;
          rcloneConfigFile = config.sops.secrets."restic/rclone_conf".path;
          backupPrepareCommand = ''
            set -Eeuo pipefail

            dump_file=${postgresDumpDir}/postgres.sql
            temporary_file="$dump_file.tmp"

            install -d -m 0750 ${postgresDumpDir}
            rm -f "$temporary_file"

            ${pkgs.podman}/bin/podman container exists postgres
            ${pkgs.podman}/bin/podman exec postgres \
              pg_dumpall \
                --username=postgres \
                --no-role-passwords \
                > "$temporary_file"

            test -s "$temporary_file"
            chmod 0600 "$temporary_file"
            mv "$temporary_file" "$dump_file"
          '';
          timerConfig = {
            OnCalendar = "03:30";
            Persistent = true;
          };
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 6"
          ];
          checkOpts = [ "--read-data-subset=1G" ];
        };

        systemd.services."restic-backups-${backupName}".unitConfig.OnFailure = [
          "restic-backups-${backupName}-failure.service"
        ];

        systemd.services."restic-backups-${backupName}-failure" = {
          description = "Report failed ${backupName} Restic backup";
          serviceConfig.Type = "oneshot";
          script = ''
            ${pkgs.systemd}/bin/journalctl -u restic-backups-${backupName}.service -n 100 --no-pager >&2
          '';
        };
      };
  };
}
