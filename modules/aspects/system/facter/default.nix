{ den, inputs, ... }:
{
  flake-file.inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

  den.aspects.facter.nixos = {
    imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
  };
}
