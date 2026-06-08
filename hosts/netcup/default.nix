{ den, ... }:
{
  den.aspects.netcup = {
    nixos =
      { ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./networking.nix
        ];

        boot.kernelParams = [ "console=ttyS0" ];

        documentation = {
          enable = false;
          man.enable = false;
          nixos.enable = false;
        };
        environment.defaultPackages = [ ];
        services.qemuGuest.enable = true;
        system.stateVersion = "25.11";
      };
  };
}
