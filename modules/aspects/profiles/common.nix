{ den, ... }:
{
  den.aspects.common = {
    includes = [
      den.aspects.nix
      den.aspects.fish
      den.aspects.git
      den.aspects.ssh
      den.aspects.starship
    ];
  };
}
