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
      withHost =
        aspect:
        aspect
        // {
          __scopeHandlers =
            (aspect.__scopeHandlers or { }) // den.lib.aspects.fx.handlers.constantHandler { inherit host; };
        };
    in
    {
      includes = [
        (withHost den.aspects.${name})
      ]
      ++ baseAspects
      ++ map (
        featureName: withHost den.aspects.${registry.features.${featureName}.aspect}
      ) resolved.resolvedFeatures
      ++ map (
        serviceName: withHost den.aspects.${registry.services.${serviceName}.aspect}
      ) resolved.resolvedServices;

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
