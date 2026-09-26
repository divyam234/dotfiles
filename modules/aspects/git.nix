{ den, ... }:
{
  den.aspects.git = { user, ... }: {
    homeSecrets = [ "github/token" ];

    homeManager =
      {
        config,
        lib,
        pkgs,
        secrets,
        ...
      }:
      let
        signingKey =
          if lib.hasPrefix "/" user.signingKey then
            user.signingKey
          else
            "${config.home.homeDirectory}/${user.signingKey}";
        ghWithToken = pkgs.writeShellScriptBin "gh" ''
          token_file=${lib.escapeShellArg secrets.github.token.path}
          if [ -r "$token_file" ]; then
            token="$(${pkgs.coreutils}/bin/tr -d '[:space:]' < "$token_file")"
            if [ -n "$token" ]; then
              export GH_TOKEN="$token"
            fi
            unset token
          fi
          exec ${lib.getExe pkgs.gh} "$@"
        '';
      in
      {
        home.packages = with pkgs; [
          git-lfs
          lazygit
          ghWithToken
        ];

        programs.git = {
          enable = true;
          lfs.enable = true;
          signing = {
            key = signingKey;
            format = "ssh";
            signByDefault = true;
          };
          settings = {
            user = {
              inherit (user) email;
              name = user.gitName;
            };
            init.defaultBranch = "main";
            pull.ff = "only";
            push.autoSetupRemote = true;
            tag.forceSignAnnotated = false;
            core = {
              editor = "nvim";
              pager = "delta";
            };
            color.ui = true;
            gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
            url."ssh://git@github.com/".insteadOf = "https://github.com/";

            alias = {
              s = "status --short --branch";
              br = "branch";
              branches = "branch --sort=-committerdate";
              co = "checkout";
              sw = "switch";
              swc = "switch -c";
              st = "status --short --branch";

              aa = "add --all";
              ap = "add --patch";
              rs = "restore";
              rss = "restore --staged";
              unstage = "restore --staged";

              c = "commit";
              ci = "commit";
              ls = "log --pretty=format:\"%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]\" --decorate";
              ll = "log --pretty=format:\"%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]\" --decorate --numstat";
              lg = "log --graph --decorate --oneline --all";
              last = "log -1 HEAD --stat";
              lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
              cm = "commit -m";
              ca = "commit -am";
              d = "diff";
              ds = "diff --stat";
              dw = "diff --word-diff";
              dc = "diff --cached";
              dcs = "diff --cached --stat";
              amend = "commit --amend -m";
              cam = "commit --amend";
              can = "commit --amend --no-edit";

              rb = "rebase";
              rbc = "rebase --continue";
              rba = "rebase --abort";
              cp = "cherry-pick";
              cpc = "cherry-pick --continue";
              cpa = "cherry-pick --abort";

              root = "rev-parse --show-toplevel";
              remotes = "remote -v";
              tags = "tag --sort=-creatordate";
              who = "shortlog -sn";
              contributors = "shortlog -sne --all";

              merged = "branch --merged";
              unmerged = "branch --no-merged";
              nonexist = "remote prune origin --dry-run";
              delmerged = ''! git branch --merged | egrep -v "(^\*|main|master|dev|staging)" | xargs git branch -d'';
              delnonexist = "remote prune origin";
              update = "submodule update --init --recursive";
              foreach = "submodule foreach";
            };
          };
        };

        programs.delta = {
          enable = true;
          enableGitIntegration = true;
          options = {
            navigate = true;
            light = false;
            side-by-side = false;
          };
        };
      };
  };
}
