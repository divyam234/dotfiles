{ den, ... }:
{
  den.aspects.git = {
    includes = [ den.aspects.sops ];

    homeManager =
      { config, lib, pkgs, secrets, ... }@args:
      let
        user = args.user or { };
      in
      {
        home.packages = with pkgs; [
          git-lfs
          lazygit
          gh
        ];

        sops.secrets."github/token" = secrets.common "github/token";

        home.activation.ghToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          token_file="${config.sops.secrets."github/token".path}"
          if [ -f "$token_file" ]; then
            token=$(cat "$token_file" | tr -d '[:space:]')
            mkdir -p "${config.xdg.configHome}/gh"
            cat > "${config.xdg.configHome}/gh/hosts.yml" <<EOF
        github.com:
            oauth_token: $token
            git_protocol: ssh
        EOF
            chmod 600 "${config.xdg.configHome}/gh/hosts.yml"
          fi
        '';
        programs.git = {
          enable = true;
          lfs.enable = true;
          signing = {
            key = user.signingKey or "~/.ssh/id_ed25519.pub";
            format = "ssh";
            signByDefault = true;
          };
          settings = {
            user = {
              name = "Divyam";
              email = "47589864+divyam234@users.noreply.github.com";
            };
            init.defaultBranch = "main";
            pull.ff = "only";
            push.autoSetupRemote = true;
            core = {
              editor = "nvim";
              pager = "delta";
            };
            color.ui = true;
            gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
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
