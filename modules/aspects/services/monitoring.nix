{ den, ... }:
{
  den.aspects.monitoring = {
    homeManager =
      { pkgs, ... }:
      {
        programs.btop.enable = true;
      };
  };
}
