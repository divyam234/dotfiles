{ ... }:
{
  den.aspects.tern = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.tern ];

        xdg.configFile."tern/settings.json".text = builtins.toJSON {
          auto_update = false;
        };
      };
  };
}
