{ den, ... }:
{
  den.aspects.security-base = {
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

  den.aspects.security-workstation = {
    nixos = {
      security.sudo.wheelNeedsPassword = false;
      services.openssh.settings.PermitRootLogin = "prohibit-password";
    };
  };

  den.aspects.security-server = {
    nixos = {
      security.sudo.wheelNeedsPassword = true;
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
}
