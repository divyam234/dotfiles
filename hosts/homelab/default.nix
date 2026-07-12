{ den, inputs, ... }:
{
  flake-file.inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

  den.aspects.homelab = {
    includes = [
      den.aspects.common
      den.aspects.sops
      den.aspects.security-base
      den.aspects.server
      den.aspects.tailscale
      den.aspects.integrated-home-manager
      den.aspects.oci-service
    ];

    nixos =
      { pkgs, ... }:
      {
        imports = [
          inputs.nixos-facter-modules.nixosModules.facter
          ./disko.nix
          ./networking.nix
        ];
        boot.loader = {
          systemd-boot.enable = true;
          systemd-boot.configurationLimit = 3;
          efi.canTouchEfiVariables = true;
          timeout = 3;
        };
        hardware.graphics.enable = true;
        facter.reportPath = ./facter.json;
        system.stateVersion = "26.05";
      };
  };
}
