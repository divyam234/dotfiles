{ den, ... }:
{
  den.aspects.starship = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.starship ];
        programs.starship = {
          enable = true;
          enableFishIntegration = true;
          settings = {
            format = ''
              [](bg:transparent fg:bright-purple)$os[](fg:bright-purple bg:cyan)$directory$git_branch$git_status$git_metrics[](fg:cyan bg:transparent)$status
              $character
            '';

            status = {
              disabled = false;
              symbol = "✘";
              style = "fg:red bg:transparent";
              format = "[ $status$symbol]($style)";
            };

            os = {
              disabled = false;
              format = "[$symbol ]($style)";
              style = "bg:bright-purple fg:black";
              symbols = {
                Alpine = "";
                Arch = "";
                CachyOS = "";
                Debian = "";
                EndeavourOS = "";
                Fedora = "";
                Gentoo = "";
                Macos = "";
                Manjaro = "";
                Mint = "";
                NixOS = "";
                openSUSE = "";
                Pop = "";
                Raspbian = "";
                Redhat = "";
                RedHatEnterprise = "";
                RockyLinux = "";
                Ubuntu = "";
                Void = "";
                Linux = "";
              };
            };

            time = {
              disabled = true;
              time_format = "%R";
              style = "bg:white fg:black";
              format = "[ 󱑍 $time ]($style)";
            };

            directory = {
              format = "[ $path ]($style)";
              style = "fg:black bg:cyan";
              home_symbol = "~";
              truncation_symbol = "…/";
              truncate_to_repo = false;
              read_only = "";
            };

            git_branch = {
              format = "[| $symbol$branch]($style)";
              symbol = "  ";
              style = "fg:black bg:cyan";
            };

            git_status = {
              format = "([$all_status]($style))";
              style = "fg:black bg:cyan";
            };

            git_metrics = {
              format = "([ +$added]($added_style))([ -$deleted]($deleted_style))";
              only_nonzero_diffs = true;
              added_style = "fg:black bg:cyan";
              deleted_style = "fg:black bg:cyan";
              disabled = false;
            };
          };
        };
      };
  };
}
