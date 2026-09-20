{
  den,
  inputs,
  ...
}:
{
  den.aspects.nix = { user, ... }: {
    nixos =
      { lib, pkgs, ... }:
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
              user.userName
            ];
            auto-optimise-store = true;
            warn-dirty = false;
            use-xdg-base-directories = true;
            substituters = [
              "http://127.0.0.1:7745"
            ];
            trusted-public-keys = [
              "nix-cache-1:833kjCWb6yhgpaUIez65hOJBJUZDkns+ybXW/WJMsYI="
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

        systemd.services.nix-cache-proxy = {
          description = "GitHub Releases-backed Nix binary cache proxy";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            CacheDirectory = "nix-cache-proxy";
            DynamicUser = true;
            ExecStart = ''
              ${inputs.nix-cache.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/nix-cache serve \
                --index-url https://github.com/divyam234/nix-cache/releases/latest/download/index.json \
                --index-cache /var/cache/nix-cache-proxy/index.json \
                --asset-url-prefix https://github.com/divyam234/nix-cache/releases/download/ \
                --public-key nix-cache-1:833kjCWb6yhgpaUIez65hOJBJUZDkns+ybXW/WJMsYI= \
                --block-cache /var/cache/nix-cache-proxy/blocks \
                --block-size 33554432 \
                --max-cache-size 21474836480 \
                --max-downloads 8
            '';
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            Restart = "on-failure";
            RestartSec = 30;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
            ];
          };
        };
      };
  };
}
