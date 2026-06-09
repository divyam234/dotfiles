{ den, ... }:
{
  # Standalone Home Manager targets must select the same home-relevant aspect
  # tree as their matching host. Do not rely only on host -> user forwarding
  # here: `home-manager switch --flake .#bhunter@laptop` evaluates a home
  # output directly, so the expected .config writers must be reachable from
  # the home entity itself.
  den.homes.x86_64-linux."bhunter@laptop" = {
    includes = [
      den.aspects.bhunter
      den.aspects.laptop
      den.aspects.workstation
      den.aspects.btrfs
      den.aspects.oci-base
      den.aspects.gaming
      den.aspects.tailscale
    ];
  };

  den.homes.aarch64-linux."bhunter@netcup" = {
    includes = [
      den.aspects.bhunter
      den.aspects.netcup
      den.aspects.server
      den.aspects.oci-base
      den.aspects.tailscale
      den.aspects.netcup-services
    ];
  };
}
