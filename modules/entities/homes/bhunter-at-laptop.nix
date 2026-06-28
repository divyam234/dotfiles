{
  bhunterUser,
  entityLib,
  ...
}:
{
  den.homes.x86_64-linux."bhunter@laptop" = {
    instantiate = entityLib.mkHome "x86_64-linux";
    user = bhunterUser // {
      name = "bhunter";
      classes = [ "homeManager" ];
    };
  };
}
