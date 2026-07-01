# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  outputs =
    inputs:
    builtins.removeAttrs
      (inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules))
      [
        "modules"
        "denful"
      ];

  inputs = {
    burpsuite-pro = {
      url = "gitlab:_VX3r/burpsuite-pro-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    den.url = "github:denful/den";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-pkgs = {
      url = "github:divyam234/nix-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    noctalia.url = "github:noctalia-dev/noctalia";
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur.url = "github:nix-community/NUR";
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tinted-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };
    tinted-sublime-text = {
      url = "github:tinted-theming/tinted-sublime-text";
      flake = false;
    };
  };
}
