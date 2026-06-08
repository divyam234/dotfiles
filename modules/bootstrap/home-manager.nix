{ inputs, ... }:
{
  den.schema.user.includes = [
    (
      { host, user, ... }:
      {
        nixos.home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "hm-bak";
          extraSpecialArgs = {
            inherit inputs host user;
          };
          users.${user.userName}._module.args = {
            inherit inputs host user;
          };
        };
      }
    )
  ];
}
