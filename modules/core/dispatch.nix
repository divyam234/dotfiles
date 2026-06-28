{ lib, den, ... }:
let
  registry = import ../../registry;
  users = import ../../inventory/users.nix;
  hosts = import ../../inventory/hosts.nix;
  inherit ((import ../../lib/registry/resolve.nix { inherit lib; })) resolveHost;

  userNames = lib.unique (builtins.attrValues (builtins.mapAttrs (_: host: host.user) hosts));

  baseAspectNames = [
    "common"
    "sops"
    "security-base"
  ];

  mkHostAspect =
    name: host:
    let
      scopedHost = host // {
        inherit name;
      };
      scopedUser = users.${host.user};
      resolved = resolveHost { inherit registry users host; };
      aspectFor = aspectName: withScope den.aspects.${aspectName};
      withScope =
        aspect:
        aspect
        // {
          __scopeHandlers =
            (aspect.__scopeHandlers or { })
            // den.lib.aspects.fx.handlers.constantHandler {
              host = scopedHost;
              user = scopedUser;
            };
        };
    in
    {
      includes = [
        (aspectFor name)
      ]
      ++ map aspectFor baseAspectNames
      ++ [ den.batteries.host-aspects ]
      ++ map aspectFor resolved.resolvedAspects;

      provides.to-users = {
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
    };

  mkStandaloneUserProvides =
    userName:
    lib.mapAttrs
      (
        name: host:
        let
          hostAspect = mkHostAspect name host;
        in
        {
          inherit (hostAspect) includes;
        }
      )
      (
        lib.filterAttrs (
          _name: host: host.user == userName && (host.homeManagerMode or "integrated") == "standalone"
        ) hosts
      );

in
{
  den.aspects =
    lib.mapAttrs mkHostAspect hosts
    // lib.genAttrs userNames (userName: {
      provides = mkStandaloneUserProvides userName;
    });
}
