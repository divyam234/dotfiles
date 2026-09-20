{ den, inputs, ... }:
{
  flake-file.inputs.sonora = {
    url = "github:sonorahq/sonora";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.rust-overlay.follows = "rust-overlay";
  };

  den.aspects.sonora.homeManager =
    { pkgs, ... }:
    {
      imports = [ inputs.sonora.homeManagerModules.default ];
      programs.sonora = {
        enable = true;
        package = inputs.sonora.packages.${pkgs.stdenv.hostPlatform.system}.sonora-bin;
      };
    };
}
