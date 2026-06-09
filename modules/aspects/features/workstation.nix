{ den, ... }:
{
  den.aspects.workstation = {
    includes = [
      den.aspects.common
      den.aspects.users
      den.aspects.security
      den.aspects.sops
      den.aspects.desktop

      # Explicit desktop shell / app layer. These files existed before but were
      # not reachable from the workstation role.
      den.aspects.dms
      den.aspects.kde
    ];
  };
}
