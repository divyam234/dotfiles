
{ den, ... }:
{
  den.aspects.monitoring = {
    nixos = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.btop ];
    };
  };
}
