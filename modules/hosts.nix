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
    (_final: prev: {
      zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
    })
    (final: prev: {
      local = extendedLib.dot.importPackages final ../packages;
    })
  ];

  mkNixos = system: { modules }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system modules;
      specialArgs = {
        inherit inputs;
        lib = extendedLib;
      };
    };

  mkHome = system: { modules, ... }:
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

  killerUser = {
    userName = "killer";
    fullName = "Killer Crock";
    email = "killercrock234@gmail.com";
    signingKey = "~/.ssh/id_ed25519.pub";
    authorizedKeys = [
      "ssh-ed25519 CHANGE_ME_killer_public_key"
    ];
  };
in
{
  den.hosts.x86_64-linux.homepc = {
    instantiate = mkNixos "x86_64-linux";
    users.killer = killerUser;
    isServer = false;
    autologin = false;
    domain = "home.example.com";
    caddyEmail = killerUser.email;
  };

  den.hosts.aarch64-linux.netcup = {
    instantiate = mkNixos "aarch64-linux";
    users.killer = killerUser;
    isServer = true;
    autologin = false;
    domain = "example.com";
    caddyEmail = killerUser.email;
  };

  den.homes.x86_64-linux."killer@homepc" = {
    instantiate = mkHome "x86_64-linux";
  };
}
