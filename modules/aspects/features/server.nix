{ den, ... }:
{
  den.aspects.server = {
    includes = [
      den.aspects.common
      den.aspects.users
      den.aspects.security
      den.aspects.sops
      den.aspects.development
      den.aspects.firewall
      den.aspects.fail2ban
    ];
  };

  # Backwards-compatible name for hosts that still think in "minimal" terms.
  den.aspects.minimal = {
    includes = [ den.aspects.server ];
  };
}
