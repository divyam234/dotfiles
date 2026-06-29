{
  bhunterUser,
  den,
  entityLib,
  ...
}:
{
  den.homes.x86_64-linux."bhunter@laptop" = {
    aspect.includes = [
      den.aspects.bhunter
      den.aspects.laptop
    ];
    instantiate = entityLib.mkHome "x86_64-linux";
    user = bhunterUser // {
      name = "bhunter";
      classes = [ "homeManager" ];
    };
  };
}
