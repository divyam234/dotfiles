
{ den, ... }:
{
  den.aspects.fail2ban = {
    nixos = { ... }: {
      services.fail2ban = {
        enable = true;
        bantime = "1h";
        maxretry = 5;
      };
    };
  };
}
