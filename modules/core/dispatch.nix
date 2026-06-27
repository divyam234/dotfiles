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
    den.batteries.host-aspects
  ];

  mkHostAspect =
    name: host:
    let
      scopedHost = host // {
        inherit name;
      };
      resolved = resolveHost { inherit registry users host; };
      aspectFor = aspectName: withHost den.aspects.${aspectName};
      withHost =
        aspect:
        aspect
        // {
          __scopeHandlers =
            (aspect.__scopeHandlers or { })
            // den.lib.aspects.fx.handlers.constantHandler { host = scopedHost; };
        };
    in
    {
      includes = [
        (aspectFor name)
      ]
      ++ baseAspects
      ++ map aspectFor resolved.resolvedAspects;

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

in
{
  den.aspects = lib.mapAttrs mkHostAspect hosts;
}
