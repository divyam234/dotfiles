{ den, ... }:
{
  den.aspects.users = {
    includes = [
      den.batteries.primary-user
      (den.batteries.user-shell "fish")
    ];

    nixos =
      { user, secrets, ... }:
      let
        passwordSecret = secrets.users.${user.userName}.password;
      in
      {
        sops.secrets = secrets.declare [
          (
            passwordSecret
            // {
              sops = passwordSecret.sops // {
                neededForUsers = true;
              };
            }
          )
        ];

        users.users.${user.userName} = {
          description = user.fullName or user.userName;
          openssh.authorizedKeys.keys = user.authorizedKeys;
          hashedPasswordFile = passwordSecret.path;
        };
      };
  };

  den.aspects.user-signing = {
    homeManager =
      { user, ... }:
      {
        home.file.".ssh/id_ed25519.pub".text = user.signingPublicKey + "\n";
        home.file.".ssh/allowed_signers".text = "* ${user.signingPublicKey}\n";
      };
  };
}
