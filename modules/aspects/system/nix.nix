{
  den,
  inputs,
  ...
}:
{
  den.aspects.nix = { user, ... }: {
    nixos =
      { ... }:
      {
        imports = [ inputs.nix-cache.nixosModules.default ];
        services.nix-cache.enable = true;

        programs.nix-ld.enable = true;

        time.timeZone = "Asia/Calcutta";
        i18n.defaultLocale = "en_US.UTF-8";
        services.timesyncd.enable = true;

        nix = {
          channel.enable = false;
          registry.nixpkgs.flake = inputs.nixpkgs;
          settings = {
            nix-path = [ "nixpkgs=flake:nixpkgs" ];
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            trusted-users = [
              "@wheel"
              user.userName
            ];
            auto-optimise-store = true;
            warn-dirty = false;
            use-xdg-base-directories = true;
          };
          gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 14d";
          };
          optimise = {
            automatic = true;
            dates = [ "weekly" ];
          };
        };
      };
  };
}
