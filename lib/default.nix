{
  lib,
  inputs ? { },
}:
let
  importPart = path: import path { inherit lib; };
in
importPart ./packages.nix // importPart ./oci.nix // importPart ./caddy.nix
