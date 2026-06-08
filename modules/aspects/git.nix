{ den, ... }:
{
  den.aspects.git = {
    homeManager =
      { pkgs, user, ... }:
      {
        home.packages = with pkgs; [
          git-lfs
          lazygit
          gh
        ];
        programs.git = {
          enable = true;
          lfs.enable = true;
          signing = {
            key = user.signingKey;
            signByDefault = true;
          };
          user = {
            name = "Divyam";
            email = "47589864+divyam234@users.noreply.github.com";
            signingkey = "~/.ssh/id_ed25519.pub";
          };
          gpg = {
            format = "ssh";
            ssh.allowedSignersFile = "~/.ssh/allowed_signers";
          };
          commit.gpgsign = true;
          core = {
            editor = "nvim";
            pager = "delta";
          };
          color.ui = true;
          interactive.diffFitler = "delta --color-only";
          delta = {
            enable = true;
            navigate = true;
            light = false;
            side-by-side = false;
          };
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
