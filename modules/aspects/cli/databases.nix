{ den, ... }:
{
  den.aspects.database-tools = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          postgresql_18
          sqlite
        ];
      };
  };
}
