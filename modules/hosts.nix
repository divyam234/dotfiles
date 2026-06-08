{ inputs, lib, ... }:
let
  extendedLib = lib.extend (
    self: _super: {
      dot = import ../lib {
        inherit inputs;
        lib = self;
      };
    }
  );

  overlays = [
    inputs.nur.overlays.default
    inputs.rust-overlay.overlays.default
    (_final: prev: {
      zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
    })
    (final: prev: {
      local = extendedLib.dot.importPackages final ../packages;
    })
  ];

  mkNixos =
    system:
    { modules }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system modules;
      specialArgs = {
        inherit inputs;
        lib = extendedLib;
      };
    };

  mkHome =
    system:
    { modules, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs modules;
      extraSpecialArgs = {
        inherit inputs;
        dotLib = extendedLib;
      };
    };

  bhunterUser = {
    userName = "bhunter";
    email = "47589864+divyam234@users.noreply.github.com";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWt7MJWVbCBzlYidynsuu9kP5kB5/gcUBFO+K6ciyCC"
    ];
  };
in
{
  den.hosts.x86_64-linux.homepc = {
    instantiate = mkNixos "x86_64-linux";
    users.bhunter = bhunterUser;
    isServer = false;
    autologin = false;
  };

  den.hosts.aarch64-linux.netcup = {
    instantiate = mkNixos "aarch64-linux";
    users.bhunter = bhunterUser;
    isServer = true;
    autologin = false;
    domain = "example.com";
    caddyEmail = bhunterUser.email;
  };

  den.homes.x86_64-linux."bhunter@homepc" = {
    instantiate = mkHome "x86_64-linux";
  };
}
