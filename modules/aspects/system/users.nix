{ den, ... }:
{
  den.aspects.users = {
    includes = [
      den.batteries.primary-user
      (den.batteries.user-shell "fish")
    ];

    nixos =
      {
        config,
        user,
        lib,
        secrets,
        ...
      }:
      let
        passwordSecret = "users/${user.userName}/password";
      in
      {
        sops.secrets.${passwordSecret} = secrets.common passwordSecret // {
          neededForUsers = true;
        };

        users.users.${user.userName} = {
          description = user.fullName or user.userName;
          openssh.authorizedKeys.keys = user.authorizedKeys;
          hashedPasswordFile = config.sops.secrets.${passwordSecret}.path;
        };
      };
  };
}
