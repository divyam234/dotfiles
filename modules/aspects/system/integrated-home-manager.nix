{
  inputs,
  den,
  ...
}:
{
  den.aspects.home-manager-policy.nixos = {
    home-manager = {
      sharedModules = [
        (
          { lib, ... }:
          {
            sops.age.keyFile = lib.mkForce "/var/lib/sops-nix/key.txt";
          }
        )
      ];
      useGlobalPkgs = false;
      useUserPackages = true;
      backupFileExtension = "hm-bak";
      extraSpecialArgs = { inherit inputs; };
    };
  };
}
