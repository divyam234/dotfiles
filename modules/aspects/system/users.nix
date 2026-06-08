{ den, ... }:
{
  den.aspects.users = {
    includes = [
      den._.primary-user
      (den._.user-shell "fish")
    ];

    nixos =
      { user, ... }:
      {
        users.users.${user.userName} = {
          description = user.fullName or user.userName;
          openssh.authorizedKeys.keys = user.authorizedKeys;
        };
      };
  };
}
