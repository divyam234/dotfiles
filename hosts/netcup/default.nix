{ den, ... }:
{
  den.aspects.netcup = {
      nixos =
        { host, ... }:
        {
          imports = [
            ./hardware-configuration.nix
          ];

          networking.domain = host.domain;
          boot.kernelParams = [ "console=ttyS0" ];
          system.stateVersion = "25.11";
        };
  };
}
