{ den, ... }:
{
  den.aspects.nix = {
    nixos =
      {
        inputs,
        lib,
        user,
        ...
      }:
      {
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
              "root"
              "@wheel"
              user.userName
            ];
            auto-optimise-store = true;
            warn-dirty = false;
            use-xdg-base-directories = true;
            substituters = [
              "https://cache.nixos.org"
              "https://nix-community.cachix.org"
              "https://numtide.cachix.org"
              "https://noctalia.cachix.org"
              "https://cache.xinux.uz"
            ];
            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
              "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
              "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
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
