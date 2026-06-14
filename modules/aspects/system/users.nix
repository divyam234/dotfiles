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
        passwordSecret = "users/${user.userName}_password";
      in
      {
        sops.secrets = lib.mkIf (secretsFile != null) {
          ${passwordSecret} = {
            sopsFile = secretsFile;
            neededForUsers = true;
          };
        };

        users.users.${user.userName} = {
          description = user.fullName or user.userName;
          openssh.authorizedKeys.keys = user.authorizedKeys;
          hashedPasswordFile = lib.mkIf (secretsFile != null) config.sops.secrets.${passwordSecret}.path;
        };
      };
  };
}
