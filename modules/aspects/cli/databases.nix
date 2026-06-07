
{ den, ... }:
{
  den.aspects.database-tools = {
    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        pgcli
        postgresql
        redis
        termdbms
        usql
        sqlite
        litecli
      ];
    };
  };
}
