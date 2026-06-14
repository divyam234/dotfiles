{ den, ... }:
{
  # Nixicle pattern: attach the netcup server/user stack through the bhunter
  # user aspect. This keeps NixOS user config and integrated Home Manager
  # activation on the same path.
  den.aspects.bhunter.provides.netcup = {
    includes = [
      den.aspects.server
      den.aspects.oci-base
      den.aspects.tailscale
      den.aspects.netcup-services
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

  den.aspects.netcup = {
    nixos =
      { host, ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./boot.nix
          ./networking.nix
        ];

        services.qemuGuest.enable = true;
        networking.domain = host.domain;
        system.stateVersion = "26.05";
      };
  };
}
