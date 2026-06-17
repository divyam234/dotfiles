{
  lib ? import <nixpkgs/lib>,
}:
let
  concat = builtins.concatStringsSep;
  names = builtins.attrNames;
  has = builtins.hasAttr;
  inherit (builtins) elem;
  inherit (lib) unique;

  fail = builtins.throw;

  requireKnown =
    kind: table: name:
    if has name table then name else fail "Unknown ${kind}: ${name}";

  requireSystem =
    kind: table: system: name:
    let
      entry = table.${name};
    in
    if elem system entry.supportedSystems then
      name
    else
      fail "${kind} ${name} does not support system ${system}";

  resolveClosure =
    {
      kind,
      table,
      depsOf,
      requested,
    }:
    let
      visit =
        stack: acc: name:
        let
          _known = requireKnown kind table name;
          cycleIndex = lib.lists.findFirstIndex (entry: entry == name) null stack;
        in
        builtins.seq _known (
          if cycleIndex != null then
            let
              cycle = (lib.drop cycleIndex stack) ++ [ name ];
            in
            fail "${
              if kind == "service" then "Service" else "Feature"
            } dependency cycle detected:\n${concat " -> " cycle}"
          else if elem name acc then
            acc
          else
            let
              withDeps = builtins.foldl' (visit (stack ++ [ name ])) acc (depsOf name);
            in
            withDeps ++ [ name ]
        );
    in
    unique (builtins.foldl' (visit [ ]) [ ] requested);

  placeholderDomains = [
    "example.com"
    "example.org"
    "example.net"
    "localhost"
  ];
in
{
  resolveHost =
    {
      registry,
      users ? import ../../inventory/users.nix,
      host,
    }:
    let
      roleName = host.role or (fail "Host ${host.hostName or "<unknown>"} is missing required role");
      _roleKnown = requireKnown "role" registry.roles roleName;
      role = registry.roles.${roleName};
      inherit (host) system;
      userName = host.user;

      requestedFeatures = host.features or [ ];
      requestedServices = host.services or [ ];

      _userKnown =
        if has userName users then
          userName
        else
          fail "Host ${host.hostName} references unknown user: ${userName}";
      _roleSystem =
        if elem system role.supportedSystems then
          roleName
        else
          fail "Role ${roleName} does not support system ${system}";

      roleFeatures = role.features or [ ];

      resolvedServices = resolveClosure {
        kind = "service";
        table = registry.services;
        requested = requestedServices;
        depsOf = name: registry.services.${name}.requires.services;
      };

      serviceFeatures = lib.concatMap (
        name: registry.services.${name}.requires.features
      ) resolvedServices;

      resolvedFeatures = resolveClosure {
        kind = "feature";
        table = registry.features;
        requested = roleFeatures ++ requestedFeatures ++ serviceFeatures;
        depsOf = name: registry.features.${name}.requires;
      };

      _featureSystems = builtins.deepSeq (map (requireSystem "Feature" registry.features
        system
      ) resolvedFeatures) true;
      _serviceSystems = builtins.deepSeq (map (requireSystem "Service" registry.services
        system
      ) resolvedServices) true;

      featureConflicts = lib.concatMap (
        name:
        map (other: {
          inherit name other;
        }) (lib.filter (other: elem other resolvedFeatures) registry.features.${name}.conflicts)
      ) resolvedFeatures;

      secretServices = lib.filter (name: registry.services.${name}.requires.secrets) resolvedServices;
      domainServices = lib.filter (name: registry.services.${name}.requires.domain) resolvedServices;
      publicWithoutCaddy = lib.filter (
        name: registry.services.${name}.public && name != "caddy" && !(elem "caddy" resolvedServices)
      ) resolvedServices;
      quadletWithoutContainers = lib.filter (
        name:
        elem "containers" registry.services.${name}.requires.features
        && !(elem "containers" resolvedFeatures)
      ) resolvedServices;

      _conflicts =
        if featureConflicts == [ ] then
          true
        else
          fail "Conflicting features selected: ${
            concat ", " (map (c: "${c.name} conflicts with ${c.other}") featureConflicts)
          }";
      _secrets =
        if secretServices == [ ] || host ? secretsFile then
          true
        else
          fail "Host ${host.hostName} resolves secret-backed services but has no secretsFile: ${concat ", " secretServices}";
      _domain =
        if domainServices == [ ] || (host ? domain && !(elem host.domain placeholderDomains)) then
          true
        else
          fail "Host ${host.hostName} resolves domain-backed services but has no real domain: ${concat ", " domainServices}";
      _public =
        if publicWithoutCaddy == [ ] then
          true
        else
          fail "Public services must resolve caddy: ${concat ", " publicWithoutCaddy}";
      _quadlet =
        if quadletWithoutContainers == [ ] then
          true
        else
          fail "Quadlet services must resolve the containers feature: ${concat ", " quadletWithoutContainers}";
    in
    builtins.seq _roleKnown (
      builtins.seq _userKnown (
        builtins.seq _roleSystem (
          builtins.seq _featureSystems (
            builtins.seq _serviceSystems (
              builtins.seq _conflicts (
                builtins.seq _secrets (
                  builtins.seq _domain (
                    builtins.seq _public (
                      builtins.seq _quadlet {
                        role = roleName;
                        inherit
                          requestedFeatures
                          requestedServices
                          resolvedFeatures
                          resolvedServices
                          ;
                      }
                    )
                  )
                )
              )
            )
          )
        )
      )
    );
}
