{ inputs, dotBootstrap, ... }:
{
  den.default.nixos =
    { ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        inputs.disko.nixosModules.disko
      ];

      config = {
        _module.args.lib = dotBootstrap.extendedLib;

        nixpkgs = {
          config.allowUnfree = true;
          inherit (dotBootstrap) overlays;
        };
      };
    };
}
