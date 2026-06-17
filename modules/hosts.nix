{
  inputs,
  lib,
  den,
  ...
}:
let
  dotBootstrap = import ../lib/bootstrap.nix { inherit inputs lib; };

  mkInstantiate =
    system:
    { modules, ... }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit modules system;
      specialArgs = {
        inherit inputs;
        lib = dotBootstrap.extendedLib;
      };
    };

  mkHomeInstantiate =
    system:
    { modules, ... }:
    let
      hmLib = inputs.home-manager.lib.hm;
      hmExtendedLib = dotBootstrap.extendedLib.extend (_self: _super: { hm = hmLib; });
      pkgs = import inputs.nixpkgs {
        inherit system;
        inherit (dotBootstrap) overlays;
        config.allowUnfree = true;
      };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        inputs.sops-nix.homeManagerModules.sops
      ]
      ++ modules;
      extraSpecialArgs = {
        inherit inputs;
        lib = hmExtendedLib;
      };
    };

  bhunterUser = {
    userName = "bhunter";
    fullName = "Bhunter";
    email = "bhunter@localhost";
    signingKey = "~/.ssh/id_ed25519.pub";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWt7MJWVbCBzlYidynsuu9kP5kB5/gcUBFO+K6ciyCC"
    ];
  };

  hosts = {
    laptop = {
      system = "x86_64-linux";
      hostName = "laptop";
      user = "bhunter";
      secretsFile = ../hosts/laptop/secrets.yaml;
      profiles = [ "desktop" ];
      features = [
        "btrfs"
        "containers"
        "gaming"
        "tailscale"
      ];
    };

    netcup = {
      system = "aarch64-linux";
      hostName = "netcup";
      user = "bhunter";
      domain = "bhunter.tech";
      secretsFile = ../hosts/netcup/secrets.yaml;
      profiles = [ "server" ];
      features = [
        "containers"
        "tailscale"
      ];
      services = {
        adguard.enable = true;
        caddy.enable = true;
        camofox.enable = true;
        databasus.enable = true;
        forgejo.enable = true;
        gluetun.enable = true;
        hermes.enable = true;
        openchamber.enable = true;
        pgdog.enable = true;
        postgres.enable = true;
        redis.enable = true;
        restic.enable = true;
        siyuan.enable = true;
        vaultwarden.enable = true;
      };
    };
  };

  users = {
    bhunter = bhunterUser;
  };

  profileAspects = {
    desktop = [
      den.aspects.common
      den.aspects.users
      den.aspects.security
      den.aspects.sops
      den.aspects.desktop
      den.aspects.dms
      den.aspects.kde
    ];

    server = [
      den.aspects.common
      den.aspects.users
      den.aspects.security
      den.aspects.sops
      den.aspects.development
      den.aspects.firewall
      den.aspects.fail2ban
    ];
  };

  featureAspects = {
    btrfs = [ den.aspects.btrfs ];
    containers = [ den.aspects.oci-base ];
    gaming = [ den.aspects.gaming ];
    tailscale = [ den.aspects.tailscale ];
  };

  serviceAspects = {
    adguard = den.aspects.adguard;
    caddy = den.aspects.caddy;
    camofox = den.aspects.camofox;
    databasus = den.aspects.databasus;
    forgejo = den.aspects.forgejo;
    gluetun = den.aspects.gluetun;
    hermes = den.aspects.hermes;
    openchamber = den.aspects.openchamber;
    pgdog = den.aspects.pgdog;
    postgres = den.aspects.postgres;
    redis = den.aspects.redis;
    restic = den.aspects.restic;
    siyuan = den.aspects.siyuan;
    vaultwarden = den.aspects.vaultwarden;
  };

  enabled = value: value.enable or false;
  pickMany = names: mapping: lib.concatMap (name: mapping.${name}) names;

  mkHost = _name: host: {
    inherit (host)
      hostName
      profiles
      features
      secretsFile
      ;
    domain = host.domain or "example.com";
    services = host.services or { };
    instantiate = mkInstantiate host.system;
    users.${host.user} = users.${host.user};
  };

  mkHostAspect = _name: host: {
    includes =
      pickMany host.profiles profileAspects
      ++ pickMany host.features featureAspects
      ++ lib.mapAttrsToList (serviceName: _value: serviceAspects.${serviceName}) (
        lib.filterAttrs (_name: enabled) (host.services or { })
      );

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

  mkSystemHosts =
    system: lib.mapAttrs mkHost (lib.filterAttrs (_name: host: host.system == system) hosts);

  mkUserProvides =
    userName: lib.mapAttrs mkHostAspect (lib.filterAttrs (_name: host: host.user == userName) hosts);
in
{
  den.hosts = {
    x86_64-linux = mkSystemHosts "x86_64-linux";
    aarch64-linux = mkSystemHosts "aarch64-linux";
  };

  den.aspects.bhunter.provides = mkUserProvides "bhunter";

  den.homes = {
    x86_64-linux."bhunter@laptop" = {
      instantiate = mkHomeInstantiate "x86_64-linux";
    };
  };
}
