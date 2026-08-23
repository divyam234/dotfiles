{ den, ... }:
{
  den.aspects.nix = {
    nixos =
      {
        host,
        inputs,
        ...
      }:
      {
        programs.nix-ld.enable = true;

        time.timeZone = "Asia/Calcutta";
        i18n.defaultLocale = "en_US.UTF-8";
        services.timesyncd.enable = true;

        nix = {
          channel.enable = false;
          nixPath = [ "nixpkgs=flake:nixpkgs" ];
          registry.nixpkgs.flake = inputs.nixpkgs;
          settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            trusted-users = [
              "@wheel"
              host.user
            ];
            auto-optimise-store = true;
            warn-dirty = false;
            use-xdg-base-directories = true;
            substituters = [
              "https://cache.nixos.org"
              "https://attic.xuyh0120.win/lantian"
            ];
            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
            ];
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
