{ den, ... }:
{
  den.aspects.netcup = {
    nixos =
      { host, pkgs, ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./boot.nix
        ];

        networking.domain = host.domain;
        system.stateVersion = "25.11";
      };
  };
}
