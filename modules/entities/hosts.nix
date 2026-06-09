{ den, dotUsers, ... }:
let
  bhunter = dotUsers.bhunter // {
    includes = [ den.aspects.bhunter ];
  };
in
{
  den.hosts.x86_64-linux.laptop = {
    hostName = "laptop";

    users.bhunter = bhunter;

    selectedAspects = [
      den.aspects.laptop
      den.aspects.workstation
      den.aspects.btrfs
      den.aspects.oci-base
      den.aspects.gaming
      den.aspects.tailscale
    ];

    secretsFile = ../../hosts/laptop/secrets.yaml;
  };

  den.hosts.aarch64-linux.netcup = {
    hostName = "netcup";

    users.bhunter = bhunter;

    selectedAspects = [
      den.aspects.netcup
      den.aspects.server
      den.aspects.oci-base
      den.aspects.tailscale
      den.aspects.netcup-services
    ];

    domain = "bhunter.tech";
    secretsFile = ../../hosts/netcup/secrets.yaml;
  };
}
