{ den, ... }:
{
  den.aspects.users = {
    includes = [
      den._.primary-user
      (den._.user-shell "fish")
    ];

    nixos =
      {
        config,
        user,
        host,
        lib,
        ...
      }:
      let
        secretsFile = host.secretsFile;
      in
      {
        sops.secrets = lib.mkIf (secretsFile != null) {
          "users/bhunter_password" = {
            sopsFile = secretsFile;
            neededForUsers = true;
          };
        };

        users.users.${user.userName} = {
          description = user.fullName or user.userName;
          openssh.authorizedKeys.keys = user.authorizedKeys;
          hashedPasswordFile = lib.mkIf (secretsFile != null) config.sops.secrets."users/bhunter_password".path;
        };
      };
  };
}
