{ den, ... }:
{
  den.aspects = {
    security-base = {
      nixos = _: {
        security = {
          rtkit.enable = true;
        };
        services.openssh = {
          enable = true;
          ports = [
            2222
          ];
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            StreamLocalBindUnlink = "yes";
          };
        };
      };
    };

    security-workstation = {
      nixos = {
        security.sudo.wheelNeedsPassword = false;
        services.openssh.settings.PermitRootLogin = "prohibit-password";
      };
    };

    security-server = {
      nixos = {
        security.sudo.wheelNeedsPassword = false;
        services.openssh = {
          openFirewall = true;
          settings = {
            PermitRootLogin = "no";
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
          };
        };
      };
    };
  };
}
