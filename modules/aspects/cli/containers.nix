{ den, ... }:
{
  den.aspects.container-tools = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          buildah
          crane
          docker-client
          docker-compose
          lazydocker
        ];
      };
  };
}
