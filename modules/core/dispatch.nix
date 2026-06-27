{ lib, den, ... }:
let
  registry = import ../../registry;
  users = import ../../inventory/users.nix;
  hosts = import ../../inventory/hosts.nix;
  inherit ((import ../../lib/registry/resolve.nix { inherit lib; })) resolveHost;

  userNames = lib.unique (builtins.attrValues (builtins.mapAttrs (_: host: host.user) hosts));

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

  mkUserProvides =
    userName:
    lib.mapAttrs (
      name: host:
      let
        hostAspect = mkHostAspect name host;
      in
      {
        inherit (hostAspect) includes homeManager;
      }
    ) (lib.filterAttrs (_name: host: host.user == userName) hosts);
in
{
  den.aspects =
    lib.mapAttrs mkHostAspect hosts
    // lib.genAttrs userNames (userName: {
      provides = mkUserProvides userName;
    });
}
