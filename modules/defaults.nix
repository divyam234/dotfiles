{ inputs, lib, den, ... }:
let
  extendedLib = lib.extend (
    self: _super: {
      dot = import ../lib {
        inherit inputs;
        lib = self;
      };
    }
  );

  caddyRouteType = lib.types.submodule ({ name, ... }: {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to render this Caddy route.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname for the route.";
      };

      upstreams = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "One or more Caddy reverse_proxy upstreams.";
      };

      encode = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable zstd/gzip encoding.";
      };

      cacheStatic = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to add long-lived caching headers for static assets.";
      };

      securityHeaders = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to add a small secure-header baseline.";
      };

      tls = lib.mkOption {
        type = lib.types.enum [ "cloudflare" "internal" "auto" "off" ];
        default = "cloudflare";
        description = "TLS mode. cloudflare uses the Caddy Cloudflare DNS plugin and CLOUDFLARE_API_TOKEN.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra raw Caddyfile directives inserted before reverse_proxy.";
      };
    };
  });
in
{
  den = {
    schema.user.classes = lib.mkDefault [ "homeManager" ];

    schema.user.includes = [
      den._.mutual-provider
      ({ host, user, ... }: {
        nixos.home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "hm-bak";
          extraSpecialArgs = {
            inherit inputs host user;
          };
          users.${user.userName}._module.args = {
            inherit host user inputs;
          };
        };
      })
    ];

    schema.host = { lib, ... }: {
      options = {
        isLaptop = lib.mkOption { type = lib.types.bool; default = false; };
        isServer = lib.mkOption { type = lib.types.bool; default = false; };
        autologin = lib.mkOption { type = lib.types.bool; default = false; };
        domain = lib.mkOption {
          type = lib.types.str;
          default = "example.com";
          description = "Primary public domain used by service aspects to derive hostnames.";
        };
        caddyEmail = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ACME contact email. Defaults to the primary user's email when unset.";
        };
        primaryDisplay = lib.mkOption { type = lib.types.attrsOf lib.types.anything; default = { }; };
      };
    };

    default.includes = [
      den._.define-user
      den._.hostname
    ];

    default.homeManager.home.stateVersion = "25.11";
  };

  den.default.nixos = { pkgs, lib, ... }: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      inputs.disko.nixosModules.disko
    ];

    options.dot = {
      caddy = {
        global = {
          email = lib.mkOption {
            type = lib.types.str;
            default = "admin@example.com";
            description = "ACME contact email used in the generated Caddyfile.";
          };

          admin = lib.mkOption {
            type = lib.types.str;
            default = "off";
            description = "Caddy admin endpoint value.";
          };

          debug = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable Caddy debug logging.";
          };

          extraGlobalConfig = lib.mkOption {
            type = lib.types.listOf lib.types.lines;
            default = [ ];
            description = "Extra global Caddyfile directives.";
          };
        };

        routes = lib.mkOption {
          type = lib.types.attrsOf caddyRouteType;
          default = { };
          description = "Routes collected from service aspects and rendered by the Caddy container aspect.";
        };
      };
    };

    config = {
      _module.args = {
        lib = extendedLib;
      };

      nixpkgs = {
        config.allowUnfree = true;
        overlays = [
          inputs.nur.overlays.default
          (final: prev: {
            dot = extendedLib.dot;
            local = extendedLib.dot.importPackages final ../packages;
          })
        ];
      };
    };
  };
}
