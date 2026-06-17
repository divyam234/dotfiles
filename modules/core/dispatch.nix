{ lib, den, ... }:
let
  registry = import ../../registry;
  users = import ../../inventory/users.nix;
  hosts = import ../../inventory/hosts.nix;
  inherit ((import ../../lib/registry/resolve.nix { inherit lib; })) resolveHost;

  baseAspects = [
    den.aspects.common
    den.aspects.users
    den.aspects.sops
    den.aspects.security-base
  ];

  mkHostAspect =
    name: host:
    let
      resolved = resolveHost { inherit registry users host; };
    in
    {
      includes = [
        den.aspects.${name}
      ]
      ++ baseAspects
      ++ map (
        featureName: den.aspects.${registry.features.${featureName}.aspect}
      ) resolved.resolvedFeatures
      ++ map (
        serviceName: den.aspects.${registry.services.${serviceName}.aspect}
      ) resolved.resolvedServices;

      nixos =
        { lib, ... }:
        {
          options.dot.inventory = lib.mkOption {
            type = lib.types.attrs;
            readOnly = true;
            description = "Resolved inventory plan for this host.";
          };

          config.dot.inventory = resolved;
        };

      homeManager =
        { user, ... }:
        {
          home = {
            username = user.userName;
            homeDirectory = "/home/${user.userName}";
            stateVersion = "26.05";
          };
        };
    };

  mkUserProvides =
    userName: lib.mapAttrs mkHostAspect (lib.filterAttrs (_name: host: host.user == userName) hosts);
in
{
  den.aspects.bhunter.provides = mkUserProvides "bhunter";
}
