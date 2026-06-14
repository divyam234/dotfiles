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

    homeManager =
      { user, ... }:
      {
        home = {
          username = user.userName;
          homeDirectory = "/home/${user.userName}";
          stateVersion = "26.05";
        };
      };
  };

  den.aspects.laptop = {
    nixos = _: {
      imports = [
        ./hardware-configuration.nix
        ./boot.nix
      ];

      system.stateVersion = "26.05";
    };
  };
}
