
{ den, ... }:
{
  den.aspects.matugen = {
    homeManager = { pkgs, ... }: {
      home.packages = [ pkgs.matugen ];
      xdg.configFile."matugen/config.toml".source = ../../../theme/matugen/config.toml;
    };
  };
}
