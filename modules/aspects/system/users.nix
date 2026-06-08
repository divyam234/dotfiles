{ den, ... }:
{
  den.aspects.users = {
    nixos = { pkgs, user, ... }: {
      users.users.${user.userName} = {
        isNormalUser = true;
        description = user.fullName;
        shell = pkgs.fish;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = user.authorizedKeys;
      };
    };

    # homeManager = { user, ... }: {
    #   home = {
    #     username = user.userName;
    #     homeDirectory = "/home/${user.userName}";
    #     stateVersion = "25.11";
    #   };
    # };
  };
}
