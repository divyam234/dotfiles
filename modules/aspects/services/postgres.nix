{ den, ... }:
{
  den.aspects.postgres = _: {
    nixosSecrets = [
      "postgres/user"
      "postgres/password"
    ];

    nixos =
      {
        containers,
        dotfiles,
        lib,
        pkgs,
        postgresDatabases,
        postgresSchemas,
        secrets,
        ...
      }:
      let
        databases = lib.pipe postgresDatabases [ (lib.foldl' lib.recursiveUpdate { }) ];
        schemas = lib.pipe postgresSchemas [ (lib.foldl' lib.recursiveUpdate { }) ];
        duplicateDatabaseNames = lib.pipe postgresDatabases [
          (lib.concatMap builtins.attrNames)
          dotfiles.findDuplicates
        ];
        duplicateSchemaNames = lib.pipe postgresSchemas [
          (lib.concatMap builtins.attrNames)
          dotfiles.findDuplicates
        ];
        mkIdentifier = name: ''"${lib.replaceStrings [ ''"'' ] [ ''""'' ] name}"'';
        mkLiteral = name: "'${lib.replaceStrings [ "'" ] [ "''" ] name}'";
        schemaSql = lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: _: "CREATE SCHEMA IF NOT EXISTS ${mkIdentifier name};") schemas
        );
        databaseSql = lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: _:
            ''SELECT 'CREATE DATABASE ${mkIdentifier name}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = ${mkLiteral name})\gexec''
          ) databases
        );
        provisionSql = pkgs.writeText "postgres-provision.sql" ''
          ${databaseSql}
          ${schemaSql}
        '';
      in
      {
        assertions = [
          {
            assertion = duplicateDatabaseNames == [ ];
            message = "Duplicate postgresDatabases quirk names: ${lib.concatStringsSep ", " duplicateDatabaseNames}";
          }
          {
            assertion = duplicateSchemaNames == [ ];
            message = "Duplicate postgresSchemas quirk names: ${lib.concatStringsSep ", " duplicateSchemaNames}";
          }
        ];

        sops.templates."postgres.env" = secrets.mkTemplate {
          name = "postgres.env";
          content = ''
            POSTGRES_USER=${secrets.postgres.user}
            POSTGRES_PASSWORD=${secrets.postgres.password}
            POSTGRES_DB=postgres
          '';
        };

        virtualisation.quadlet.containers.postgres = {
          containerConfig = {
            image = "ghcr.io/tgdrive/postgres:18";
            networkAliases = [ "postgres" ];
            environmentFiles = [ "${containers.secretDir}/postgres.env" ];
            volumes = [ "${containers.dataRoot}/postgres:/var/lib/postgresql" ];
            healthCmd = "pg_isready -U $POSTGRES_USER -d postgres || exit 1";
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o 999 -g 999 ${containers.dataRoot}/postgres";
            MemoryMax = "2G";
            CPUQuota = "200%";
          };
        };

        systemd.services.postgres-provision = {
          description = "Provision PostgreSQL databases and schemas";
          after = [ "postgres.service" ];
          requires = [ "postgres.service" ];
          wantedBy = [ "multi-user.target" ];
          path = [
            pkgs.coreutils
            pkgs.podman
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            for _ in {1..60}; do
              if podman exec postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d postgres'; then
                break
              fi
              sleep 2
            done

            podman exec postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d postgres'
            podman exec -i postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres' < ${provisionSql}
          '';
        };
      };
  };
}
