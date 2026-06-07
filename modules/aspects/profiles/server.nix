{ den, ... }:
{
  den.aspects.server = {
    includes = [
      # Servers should still be pleasant to work on: Fish, Git/SSH,
      # Zellij, Neovim, Nix/Go/dev tooling, container/db/network tools.
      # Desktop-only apps stay in the desktop profile.
      den.aspects.development
    ];

    nixos = { ... }: {
      documentation = {
        enable = false;
        man.enable = false;
        nixos.enable = false;
      };
      environment.defaultPackages = [ ];
      services.qemuGuest.enable = true;
      boot.kernelParams = [ "console=ttyS0" ];
    };
  };
}
