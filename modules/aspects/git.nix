
{ den, ... }:
{
  den.aspects.git = {
    homeManager = { pkgs, user, ... }: {
      home.packages = with pkgs; [ git-lfs delta lazygit gh ];
      programs.git = {
        enable = true;
        userName = user.fullName;
        userEmail = user.email;
        lfs.enable = true;
        delta.enable = true;
        signing = {
          key = user.signingKey;
          signByDefault = true;
        };
        extraConfig = {
          init.defaultBranch = "main";
          pull.ff = "only";
          push.autoSetupRemote = true;
          core.editor = "nvim";
          gpg.format = "ssh";
          url."ssh://git@github.com/".insteadOf = "https://github.com/";
        };
      };
    };
  };
}
