{ den, ... }:
{
  den.aspects.iets = {
    nixos =
      { pkgs, ... }:
      {
        nix.package = pkgs.callPackage (pkgs.iets.src + "/nix/classic.nix") {
          iets = pkgs.iets;
          nix = pkgs.nix;
        };
        environment.systemPackages = [ pkgs.iets ];
      };

    homeManager =
      { lib, osConfig, ... }:
      {
        nix.package = lib.mkForce osConfig.nix.package;
      };
  };
}
