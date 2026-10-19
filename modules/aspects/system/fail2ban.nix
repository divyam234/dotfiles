{ den, ... }:
{
  den.aspects.fail2ban = {
    includes = [ den.aspects.firewall ];

    nixos = _: {
      services.fail2ban = {
        enable = true;
        bantime = "1h";
        maxretry = 5;
      };
    };
  };
}
