{ den, ... }:
{
  den.aspects.fail2ban = {
    nixos = _: {
      services.fail2ban = {
        enable = true;
        bantime = "1h";
        maxretry = 5;
      };
    };
  };
}
