{ den, ... }:
{
  den.aspects.database-tools = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          pgcli
          sqlite
        ];
      };
  };
}
