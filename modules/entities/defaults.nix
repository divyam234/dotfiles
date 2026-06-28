{
  inputs,
  lib,
  ...
}:
let
  dotBootstrap = import ../../lib/bootstrap.nix { inherit inputs lib; };

  mkNixos =
    system:
    { modules, ... }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit modules system;
      specialArgs = {
        inherit inputs;
        lib = dotBootstrap.extendedLib;
      };
    };

  mkHome =
    system:
    { modules, ... }:
    let
      hmLib = inputs.home-manager.lib.hm;
      hmExtendedLib = dotBootstrap.extendedLib.extend (_self: _super: { hm = hmLib; });
      pkgs = import inputs.nixpkgs {
        inherit system;
        inherit (dotBootstrap) overlays;
        config.allowUnfree = true;
      };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ inputs.sops-nix.homeManagerModules.sops ] ++ modules;
      extraSpecialArgs = {
        inherit inputs;
        lib = hmExtendedLib;
      };
    };
in
{
  _module.args.entityLib = {
    inherit mkHome mkNixos;
  };
}
