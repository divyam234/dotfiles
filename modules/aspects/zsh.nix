{ den, ... }:
{
  den.aspects.zsh = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          zsh
        ];
      };
  };
}
