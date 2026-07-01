{ inputs, den, ... }:
{
  flake-file.inputs.spicetify-nix = {
    url = "github:Gerg-L/spicetify-nix";
  };
  den.aspects.spicetify = {
    homeManager =
      { pkgs, ... }:
      {
        imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];
        programs.spicetify = {
          enable = true;
        };
      };
  };
}
