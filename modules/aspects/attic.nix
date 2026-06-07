
{ den, ... }:
{
  den.aspects.attic = {
    nixos = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.attic-client ];
    };
    homeManager = { pkgs, ... }: {
      home.packages = [ pkgs.attic-client ];
    };
  };
}
