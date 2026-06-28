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
      ++ map aspectFor baseAspectNames
      ++ map aspectFor resolved.resolvedAspects;

      provides.to-users = {
        homeManager =
          { user, ... }:
          {
            _module.args.user = user;
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
      includes = [
        den.batteries.host-aspects
        den.aspects.user-signing
      ];
      provides = mkStandaloneUserProvides userName;
    });
}
