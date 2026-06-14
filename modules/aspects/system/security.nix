{ den, ... }:
{
  den.aspects.security = {
    nixos =
      { ... }:
      {
        security = {
          sudo.wheelNeedsPassword = false;
          rtkit.enable = true;
        };
        services.openssh = {
          enable = true;
          ports = [
            2222
          ];
          settings = {
            PasswordAuthentication = false;
            PermitRootLogin = "prohibit-password";
            KbdInteractiveAuthentication = false;
            StreamLocalBindUnlink = "yes";
          };
        };
      };
  };
}
