{ den, ... }:
{
  den.aspects.rclone = {
    homeSecrets = [
      "postgres/password"
      "postgres/user"
    ];

    homeManager =
      {
        lib,
        pkgs,
        secrets,
        ...
      }:
      let
        endpoint = "netcup:6432/postgres?schema=rclone&init_schema=false";
        rclone = pkgs.writeShellScriptBin "rclone" ''
          # Commands that never touch the config backend run without it, so
          # they stay instant and work while the tailnet is down.
          needs_config=1
          for arg in "$@"; do
            case "$arg" in
              --config=*|--config) needs_config=0 ;;
            esac
          done
          case "''${1-}" in
            version|--version|-V|help|--help|-h|genautocomplete) needs_config=0 ;;
          esac
          if [ "$needs_config" -eq 1 ]; then
            user_file=${lib.escapeShellArg secrets.postgres.user.path}
            password_file=${lib.escapeShellArg secrets.postgres.password.path}
            if [ ! -r "$user_file" ] || [ ! -r "$password_file" ]; then
              echo "rclone: postgres credentials are unavailable" >&2
              exit 1
            fi
            db_user="$(${pkgs.coreutils}/bin/cat "$user_file")"
            db_password="$(${pkgs.coreutils}/bin/cat "$password_file")"
            if [ -z "$db_user" ] || [ -z "$db_password" ]; then
              echo "rclone: postgres credentials are empty" >&2
              exit 1
            fi
            export RCLONE_CONFIG="postgres://$db_user:$db_password@${endpoint}"
            unset db_user db_password
          fi
          exec ${lib.getExe pkgs.rclone} "$@"
        '';
      in
      {
        home.packages = [ (lib.hiPrio rclone) ];
      };
  };
}
