{
  inputs,
  lib,
  den,
  ...
}:
let
  dotBootstrap = import ../../../lib/bootstrap.nix { inherit inputs lib; };
in
{
  den.aspects.integrated-home-manager =
    { host, user, ... }:
    {
      nixos.home-manager = {
        sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
        useGlobalPkgs = false;
        useUserPackages = true;
        backupFileExtension = "hm-bak";
        extraSpecialArgs = { inherit inputs; };
        users.${user.userName} = {
          _module.args.host = host;
          _module.args.user = user;
          nixpkgs = {
            config.allowUnfree = true;
            inherit (dotBootstrap) overlays;
          };
        };
      };
    };
}
