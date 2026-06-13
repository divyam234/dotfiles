{ inputs, lib, ... }:
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
in
{
  den.hosts = {
    x86_64-linux.laptop = {
      instantiate = mkInstantiate "x86_64-linux";
      hostName = "laptop";
      users.bhunter = bhunterUser;
      secretsFile = ../hosts/laptop/secrets.yaml;
    };

    aarch64-linux.netcup = {
      instantiate = mkInstantiate "aarch64-linux";
      hostName = "netcup";
      users.bhunter = bhunterUser;
      domain = "bhunter.tech";
      secretsFile = ../hosts/netcup/secrets.yaml;
    };
  };

  den.homes = {
    x86_64-linux."bhunter@laptop" = {
      instantiate = mkHomeInstantiate "x86_64-linux";
    };
  };
}
