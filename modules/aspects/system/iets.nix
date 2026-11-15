{ den, ... }:
{
  den.aspects.iets = {
    nixos =
      { pkgs, ... }:
      {
        nix.package = pkgs.callPackage (pkgs.local.iets.src + "/nix/classic.nix") {
          iets = pkgs.local.iets;
          nix = pkgs.nix;
        };
        environment.systemPackages = [ pkgs.local.iets ];
      };

    homeManager =
      { lib, osConfig, ... }:
      {
        nix.package = lib.mkForce osConfig.nix.package;
      };
  };
}
