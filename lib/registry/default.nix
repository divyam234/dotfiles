{
  lib ? import <nixpkgs/lib>,
}:
{
  normalize = import ./normalize.nix { };
  inherit (import ./resolve.nix { inherit lib; }) resolveHost;
}
