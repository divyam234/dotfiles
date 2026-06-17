{
  lib ? import <nixpkgs/lib>,
}:
let
  resolver = import ./resolve.nix { inherit lib; };
in
{
  inherit (resolver) resolveHost;
}
