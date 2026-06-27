{
  lib ? import <nixpkgs/lib>,
}:
let
  concat = builtins.concatStringsSep;
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
      _known = requireKnown kind table name;
      entry = table.${name};
    in
    builtins.seq _known (
      if elem system entry.supportedSystems then
        name
      else
        fail "${kind} ${name} does not support system ${system}"
    );

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
            fail "Service dependency cycle detected:\n${concat " -> " cycle}"
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
      inherit (host) system;
      userName = host.user;

      requestedServices = host.services or [ ];

      _userKnown =
        if has userName users then
          userName
        else
          fail "Host ${host.hostName} references unknown user: ${userName}";
      resolvedServices = resolveClosure {
        kind = "service";
        table = registry.services;
        requested = requestedServices;
        depsOf = name: registry.services.${name}.requires.services;
      };

      serviceAspects = lib.concatMap (name: registry.services.${name}.requires.aspects) resolvedServices;

      resolvedServiceAspects = map (name: registry.services.${name}.aspect) resolvedServices;
      resolvedAspects = unique (serviceAspects ++ resolvedServiceAspects);

      _serviceSystems = builtins.deepSeq (map (requireSystem "Service" registry.services
        system
      ) resolvedServices) true;

      secretServices = lib.filter (name: registry.services.${name}.requires.secrets) resolvedServices;
      domainServices = lib.filter (name: registry.services.${name}.requires.domain) resolvedServices;
      publicWithoutCaddy = lib.filter (
        name: registry.services.${name}.public && name != "caddy" && !(elem "caddy" resolvedServices)
      ) resolvedServices;
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
      validations = [
        _userKnown
        _serviceSystems
        _secrets
        _domain
        _public
      ];
    in
    builtins.deepSeq validations {
      inherit
        requestedServices
        resolvedAspects
        resolvedServiceAspects
        resolvedServices
        ;
    };
}
