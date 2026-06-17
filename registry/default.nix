let
  normalize = import ../lib/registry/normalize.nix { };
in
{
  roles = import ./roles.nix;
  features = normalize.features (import ./features.nix);
  services = normalize.services (import ./services.nix);
}
