{ den, ... }:
{
  den.aspects = {
    workstation.includes = [
      den.aspects.desktop
      den.aspects.security-workstation
    ];

    server.includes = [
      den.aspects.development
      den.aspects.fail2ban
      den.aspects.security-server
    ];
  };
}
