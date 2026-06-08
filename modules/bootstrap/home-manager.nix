{ inputs, dotBootstrap, ... }:
{
  den.schema.user.includes = [
    (
      { host, user, ... }:
      {
        nixos.home-manager = {
          sharedModules = [
            inputs.sops-nix.homeManagerModules.sops
          ];
          useUserPackages = true;
          backupFileExtension = "hm-bak";
          extraSpecialArgs = {
            inherit inputs;
          };
          users.${user.userName}.nixpkgs = {
            config.allowUnfree = true;
            inherit (dotBootstrap) overlays;
          };
        };
      }
    )
  ];
}
