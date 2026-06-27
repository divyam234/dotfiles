let
  normalize = import ../lib/registry/normalize.nix { };
in
{
  services = normalize.services (import ./services.nix);
}
