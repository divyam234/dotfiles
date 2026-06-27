{
  inputs,
  lib,
  den,
  ...
}:
let
  dotBootstrap = import ../../lib/bootstrap.nix { inherit inputs lib; };
  hosts = import ../../inventory/hosts.nix;
  users = import ../../inventory/users.nix;

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
      modules = [ inputs.sops-nix.homeManagerModules.sops ] ++ modules;
      extraSpecialArgs = {
        inherit inputs;
        lib = hmExtendedLib;
      };
    };

  mkHost =
    _name: host:
    let
      hmMode = host.homeManagerMode or "integrated";
      userWithClasses =
        users.${host.user}
        // lib.optionalAttrs (hmMode == "standalone") {
          classes = [ ];
        };
    in
    {
      inherit (host)
        hostName
        services
        secretsFile
        ;
      homeManagerMode = host.homeManagerMode or "integrated";
      domain = host.domain or null;
      caddyEmail = host.caddyEmail or null;
      tailscale = host.tailscale or { };
      greeter = host.greeter or { };
      outputs = host.outputs or [ ];
      instantiate = mkInstantiate host.system;
      users.${host.user} = userWithClasses;
    };

  mkSystemHosts =
    system: lib.mapAttrs mkHost (lib.filterAttrs (_name: host: host.system == system) hosts);
in
{
  den.hosts = {
    x86_64-linux = mkSystemHosts "x86_64-linux";
    aarch64-linux = mkSystemHosts "aarch64-linux";
  };

  den.homes = {
    x86_64-linux."bhunter@laptop" = {
      instantiate = mkHomeInstantiate "x86_64-linux";
    };
  };
}
