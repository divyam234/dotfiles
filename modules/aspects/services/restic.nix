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
        secrets,
        ...
      }:
      let
        backupName = host.hostName;
        postgresDumpDir = "/var/backup/postgres";
      in
      {
        services.restic.backups.${backupName} = {
          initialize = true;
          paths = [
            containers.dataRoot
            postgresDumpDir
          ];
          passwordFile = secrets.restic.password.path;
          repositoryFile = secrets.restic.repository.path;
          rcloneConfigFile = secrets.restic.rclone_conf.path;
          backupPrepareCommand = ''
            set -Eeuo pipefail

            dump_file=${postgresDumpDir}/postgres.sql
            temporary_file="$dump_file.tmp"

            install -d -m 0750 ${postgresDumpDir}
            rm -f "$temporary_file"

            ${pkgs.podman}/bin/podman container exists postgres
            ${pkgs.podman}/bin/podman exec postgres \
              sh -c 'pg_dumpall --username="$POSTGRES_USER" --no-role-passwords' \
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
      };
  };
}
