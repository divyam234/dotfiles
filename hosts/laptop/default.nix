{ den, ... }:
{
  # Nixicle pattern: host-specific user/home stack lives on the user aspect via
  # provides.<host>. The host aspect itself only owns host hardware/system facts.
  den.aspects.bhunter.provides.laptop = {
    includes = [
      den.aspects.workstation
      den.aspects.btrfs
      den.aspects.oci-base
      den.aspects.gaming
      den.aspects.tailscale
    ];

    homeManager = _: {
      home = {
        username = "bhunter";
        homeDirectory = "/home/bhunter";
        stateVersion = "25.11";
      };
    };
  };

  den.aspects.laptop = {
    nixos = _: {
      imports = [
        ./hardware-configuration.nix
        ./boot.nix
      ];

      system.stateVersion = "25.11";
    };
  };
}
