{ den, ... }:
{
  den.aspects.fastfetch = {
    homeManager =
      { config, ... }:
      let
        colors = config.lib.stylix.colors.withHashtag;
        # Real ESC char: the JSON generator emits it as \u001b (single
        # backslash), which fastfetch decodes back to ESC. A literal
        # "\\u001b" in the Nix string would be double-escaped to "\\u001b"
        # in the file and printed as visible text.
        esc = builtins.fromJSON ''"\u001b"'';
        # 10-step Nord frost gradient (blue -> purple) for section dividers.
        gradient = [
          "${esc}[38;2;136;192;208m${esc}[1m"
          "${esc}[38;2;141;186;204m${esc}[1m"
          "${esc}[38;2;146;181;200m${esc}[1m"
          "${esc}[38;2;151;175;196m${esc}[1m"
          "${esc}[38;2;156;170;192m${esc}[1m"
          "${esc}[38;2;160;164;189m${esc}[1m"
          "${esc}[38;2;165;159;185m${esc}[1m"
          "${esc}[38;2;170;153;181m${esc}[1m"
          "${esc}[38;2;175;148;177m${esc}[1m"
          "${esc}[38;2;180;142;173m${esc}[1m"
        ];
        # Icons by codepoint (ASCII-safe): every glyph below is Font Awesome
        # in the BMP private-use area, so terminals measure it as exactly 1
        # cell wide. Supplementary-plane (>U+FFFF) icons measure 2 cells on
        # some terminals and break column alignment.
        j = builtins.fromJSON;
        icon = {
          pc = j ''"\uf109"'';
          cpu = j ''"\uf2db"'';
          gpu = j ''"\uf11b"'';
          mem = j ''"\uf538"'';
          swap = j ''"\uf0ec"'';
          disk = j ''"\uf0a0"'';
          nixos = j ''"\uf313"'';
          gear = j ''"\uf013"'';
          pkg = j ''"\uf187"'';
          kbd = j ''"\uf11c"'';
          term = j ''"\uf120"'';
          linux = j ''"\uf17c"'';
          win = j ''"\uf17a"'';
          cal = j ''"\uf133"'';
          power = j ''"\uf011"'';
        };
      in
      {
        programs.fastfetch = {
          enable = true;
          settings = {
            "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
            logo = {
              type = "small";
              source = "nixos_small";
              padding = {
                top = 2;
                left = 1;
                right = 2;
              };
              color = {
                "1" = colors.base0D;
                "2" = colors.base0C;
              };
            };
            display = {
              separator = " ";
              constants = gradient ++ [
                "┌──────"
                "───────"
                "──────┐"
              ];
              percent = {
                type = 9;
                color = {
                  green = colors.base0B;
                  yellow = colors.base0A;
                  red = colors.base08;
                };
              };
            };
            modules = [
              "break"
              {
                type = "version";
                color = {
                  keys = "";
                };
                key = "{$4}${icon.nixos} Fastfetch ";
                format = "{$6}{2}";
              }
              {
                type = "custom";
                format = "{$1}{$11}{$2}{$12}{$3}{$12}{$4}{$12}{$5}{$12}{$6}{$12}{$7}{$12}{$8}{$12}{$9}{$12}{$10}{$13} Hardware ";
              }
              {
                type = "host";
                key = "{$1}├ ${icon.pc} PC      ";
              }
              {
                type = "cpu";
                key = "{$2}├ ${icon.cpu} CPU     ";
              }
              {
                type = "gpu";
                key = "{$3}├ ${icon.gpu} GPU     ";
              }
              {
                type = "memory";
                key = "{$4}├ ${icon.mem} Memory  ";
                percent = {
                  type = 3;
                  green = 30;
                  yellow = 70;
                };
              }
              {
                type = "swap";
                key = "{$5}├ ${icon.swap} Swap    ";
                percent = {
                  type = 3;
                  green = 30;
                  yellow = 70;
                };
              }
              {
                type = "disk";
                key = "{$6}├ ${icon.disk} NixOS   ";
                folders = [ "/" ];
                percent = {
                  type = 3;
                  green = 30;
                  yellow = 70;
                };
              }
              {
                type = "disk";
                key = "{$7}└ ${icon.disk} Home    ";
                folders = [ "/home" ];
                percent = {
                  type = 3;
                  green = 30;
                  yellow = 70;
                };
              }
              {
                type = "custom";
                format = "{$10}{$11}{$9}{$12}{$8}{$12}{$7}{$12}{$6}{$12}{$5}{$12}{$4}{$12}{$3}{$12}{$2}{$12}{$1}{$13} Software ";
              }
              {
                type = "os";
                key = "{$10}├ ${icon.linux} Distro  ";
              }
              {
                type = "kernel";
                key = "{$9}├ ${icon.gear} Kernel  ";
              }
              {
                type = "packages";
                key = "{$8}├ ${icon.pkg} Packages";
              }
              {
                type = "shell";
                key = "{$7}├ ${icon.kbd} Shell   ";
              }
              {
                type = "terminal";
                key = "{$6}├ ${icon.term} Terminal";
              }
              {
                type = "de";
                key = "{$5}├ ${icon.linux} Desktop ";
              }
              {
                type = "wm";
                key = "{$4}└ ${icon.win} Window  ";
              }
              {
                type = "custom";
                format = "{$1}{$11}{$2}{$12}{$3}{$12}{$4}{$12}{$5}{$12}{$6}{$12}{$7}{$12}{$8}{$12}{$9}{$12}{$10}{$13} Time ";
              }
              {
                type = "datetime";
                key = "{$3}├ ${icon.cal} Date    ";
                format = "{1}-{3}-{11} {14}:{17}";
              }
              {
                type = "uptime";
                key = "{$2}└ ${icon.power} Uptime  ";
              }
              {
                type = "custom";
                format = "          {$10}${icon.nixos} {$9}${icon.nixos} {$8}${icon.nixos} {$7}${icon.nixos} {$6}${icon.nixos} {$5}${icon.nixos} {$4}${icon.nixos} {$3}${icon.nixos} {$2}${icon.nixos} {$1}${icon.nixos}";
              }
            ];
          };
        };
      };
  };
}
