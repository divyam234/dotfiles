{ den, ... }:
{
  den.homes.x86_64-linux."bhunter@laptop".aspect.includes = [
    den.aspects.bhunter
    den.aspects.laptop
  ];
}
