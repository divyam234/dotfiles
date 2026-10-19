{ den, ... }:
{
  den.aspects.container-tools = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          buildah
          crane
          dive
          docker-client
          docker-compose
          lazydocker
          podman
          podman-compose
          podman-tui
          skopeo
        ];
      };
  };
}
