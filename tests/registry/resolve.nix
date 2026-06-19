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
    roles = {
      workstation = {
        features = [ "desktop" ];
        supportedSystems = [ "x86_64-linux" ];
      };
      server = {
        features = [
          "firewall"
          "security-server"
        ];
        supportedSystems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
      };
    };
    features = normalize.features {
      ai = { };
      containers = { };
      desktop.supportedSystems = [ "x86_64-linux" ];
      firewall = { };
      gaming = {
        requires = [ "desktop" ];
      };
      security-server = { };
      child = {
        requires = [ "parent" ];
      };
      parent = { };
      conflict-a.conflicts = [ "conflict-b" ];
      conflict-b = { };
      x86-only.supportedSystems = [ "x86_64-linux" ];
    };
    services = normalize.services {
      caddy = {
        public = true;
        requires = {
          features = [ "containers" ];
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
        features = [ "containers" ];
        secrets = true;
      };
      cache.requires.features = [ "containers" ];
      x86-service.supportedSystems = [ "x86_64-linux" ];
    };
  };

  host =
    overrides:
    {
      system = "x86_64-linux";
      hostName = "test";
      user = "alice";
      role = "server";
      features = [ ];
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

  featureCycleRegistry = baseRegistry // {
    features = baseRegistry.features // {
      fa = baseRegistry.features.ai // {
        requires = [ "fb" ];
      };
      fb = baseRegistry.features.ai // {
        requires = [ "fc" ];
      };
      fc = baseRegistry.features.ai // {
        requires = [ "fa" ];
      };
    };
  };
in
builtins.all (x: x) [
  (eq "valid workstation resolution"
    (resolve baseRegistry (host {
      role = "workstation";
    })).resolvedFeatures
    [ "desktop" ]
  )
  (eq "valid server resolution" (resolve baseRegistry (host { })).role "server")
  (expect "unknown role" (
    fails (
      resolve baseRegistry (host {
        role = "missing";
      })
    )
  ))
  (expect "unknown feature" (
    fails (
      resolve baseRegistry (host {
        features = [ "missing" ];
      })
    )
  ))
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
  (eq "direct feature dependency"
    (resolve baseRegistry (host {
      features = [ "gaming" ];
    })).resolvedFeatures
    [
      "firewall"
      "security-server"
      "desktop"
      "gaming"
    ]
  )
  (eq "transitive feature dependency"
    (resolve baseRegistry (host {
      features = [ "child" ];
    })).resolvedFeatures
    [
      "firewall"
      "security-server"
      "parent"
      "child"
    ]
  )
  (expect "service dependency cycle" (
    fails (
      resolve serviceCycleRegistry (host {
        services = [ "a" ];
      })
    )
  ))
  (expect "feature dependency cycle" (
    fails (
      resolve featureCycleRegistry (host {
        features = [ "fa" ];
      })
    )
  ))
  (expect "feature conflicts" (
    fails (
      resolve baseRegistry (host {
        features = [
          "conflict-a"
          "conflict-b"
        ];
      })
    )
  ))
  (expect "unsupported role/system" (
    fails (
      resolve baseRegistry (host {
        role = "workstation";
        system = "aarch64-linux";
      })
    )
  ))
  (expect "unsupported feature/system" (
    fails (
      resolve baseRegistry (host {
        features = [ "x86-only" ];
        system = "aarch64-linux";
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
  (expect "container service resolving containers feature" (
    builtins.elem "containers"
      (resolve baseRegistry (host {
        services = [ "cache" ];
      })).resolvedFeatures
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
