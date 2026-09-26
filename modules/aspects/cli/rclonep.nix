{ den, ... }:
{
  den.aspects.rclonep = {
    homeSecrets = [
      "postgres/password"
      "postgres/user"
    ];

    homeManager =
      {
        host,
        lib,
        pkgs,
        secrets,
        ...
      }:
      let
        endpoint =
          if host.name == "netcup" then
            "127.0.0.1:6432/postgres?schema=rclone&init_schema=false"
          else
            "postgres.buunter.tech:443/postgres?schema=rclone&init_schema=false&sslnegotiation=direct";
        rclonep = pkgs.writeShellScriptBin "rclonep" ''
          user_file=${lib.escapeShellArg secrets.postgres.user.path}
          password_file=${lib.escapeShellArg secrets.postgres.password.path}
          if [ ! -r "$user_file" ] || [ ! -r "$password_file" ]; then
            echo "rclonep: postgres credentials are unavailable" >&2
            exit 1
          fi
          db_user="$(${pkgs.coreutils}/bin/cat "$user_file")"
          db_password="$(${pkgs.coreutils}/bin/cat "$password_file")"
          if [ -z "$db_user" ] || [ -z "$db_password" ]; then
            echo "rclonep: postgres credentials are empty" >&2
            exit 1
          fi
          export RCLONE_CONFIG="postgres://$db_user:$db_password@${endpoint}"
          unset db_user db_password
          exec ${lib.getExe pkgs.rclone} "$@"
        '';
      in
      {
        home.packages = [ rclonep ];
        programs.fish.interactiveShellInit = ''
          complete -c rclonep -w rclone
        '';
      };
  };
}
