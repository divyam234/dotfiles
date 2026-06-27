{
  lib ? import <nixpkgs/lib>,
  root ? ../..,
}:
let
  resolver = import (root + /lib/registry/resolve.nix) { inherit lib; };
  normalize = import (root + /lib/registry/normalize.nix) { };
  users = {
    alice = {
      userName = "alice";
      authorizedKeys = [ ];
    };
  };
  baseRegistry = {
    services = normalize.services {
      caddy = {
        public = true;
        requires = {
          aspects = [ "oci-runtime" ];
          domain = true;
        };
      };
      app = {
        public = true;
        requires = {
          services = [ "caddy" ];
          domain = true;
        };
      };
      platform.requires.services = [ "database" ];
      database.requires = {
        aspects = [ "oci-runtime" ];
        secrets = true;
      };
      cache.requires.aspects = [ "oci-runtime" ];
      x86-service.supportedSystems = [ "x86_64-linux" ];
    };
  };

  host =
    overrides:
    {
      system = "x86_64-linux";
      hostName = "test";
      user = "alice";
      services = [ ];
      domain = "test.invalid";
      secretsFile = /dev/null;
    }
    // overrides;

  resolve =
    registry: h:
    resolver.resolveHost {
      inherit registry users;
      host = h;
    };
  ok = expr: (builtins.tryEval (builtins.deepSeq expr true)).success;
  fails = expr: !(ok expr);
  expect = name: cond: if cond then true else builtins.throw "registry resolver test failed: ${name}";
  eq =
    name: actual: expected:
    expect name (actual == expected);

  serviceCycleRegistry = baseRegistry // {
    services = baseRegistry.services // {
      a = baseRegistry.services.app // {
        requires.services = [ "b" ];
      };
      b = baseRegistry.services.app // {
        requires.services = [ "c" ];
      };
      c = baseRegistry.services.app // {
        requires.services = [ "a" ];
      };
    };
  };

in
builtins.all (x: x) [
  (eq "empty service resolution" (resolve baseRegistry (host { })).resolvedAspects [ ])
  (expect "unknown service" (
    fails (
      resolve baseRegistry (host {
        services = [ "missing" ];
      })
    )
  ))
  (eq "direct service dependency"
    (resolve baseRegistry (host {
      services = [ "app" ];
    })).resolvedServices
    [
      "caddy"
      "app"
    ]
  )
  (eq "transitive service dependency"
    (resolve baseRegistry (host {
      services = [ "platform" ];
    })).resolvedServices
    [
      "database"
      "platform"
    ]
  )
  (expect "service dependency cycle" (
    fails (
      resolve serviceCycleRegistry (host {
        services = [ "a" ];
      })
    )
  ))
  (expect "unsupported service/system" (
    fails (
      resolve baseRegistry (host {
        services = [ "x86-service" ];
        system = "aarch64-linux";
      })
    )
  ))
  (expect "missing user" (
    fails (
      resolve baseRegistry (host {
        user = "nobody";
      })
    )
  ))
  (expect "missing secrets file" (
    fails (
      resolve baseRegistry (builtins.removeAttrs (host { services = [ "database" ]; }) [ "secretsFile" ])
    )
  ))
  (expect "missing domain" (
    fails (resolve baseRegistry (builtins.removeAttrs (host { services = [ "app" ]; }) [ "domain" ]))
  ))
  (expect "placeholder domain" (
    fails (
      resolve baseRegistry (host {
        services = [ "app" ];
        domain = "example.com";
      })
    )
  ))
  (expect "public service resolving Caddy" (
    builtins.elem "caddy"
      (resolve baseRegistry (host {
        services = [ "app" ];
      })).resolvedServices
  ))
  (expect "container service resolving OCI runtime aspect" (
    builtins.elem "oci-runtime"
      (resolve baseRegistry (host {
        services = [ "cache" ];
      })).resolvedAspects
  ))
  (eq "deterministic output"
    (resolve baseRegistry (host {
      services = [
        "app"
        "platform"
      ];
    })).resolvedServices
    [
      "caddy"
      "app"
      "database"
      "platform"
    ]
  )
]
