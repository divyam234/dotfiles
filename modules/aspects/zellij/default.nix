{ inputs, den, ... }:
{
  flake-file.inputs.zjstatus.url = "github:dj95/zjstatus";
  flake-file.inputs.gsesh = {
    url = "gitlab:hmajid2301/gsesh";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.zellij = {
    homeManager =
      { pkgs, ... }:
      let
        sesh = pkgs.writeScriptBin "sesh" ''
          #! /usr/bin/env bash

          # Taken from https://github.com/zellij-org/zellij/issues/884#issuecomment-1851136980
          # Modified to handle being called from inside zellij and to support layout selection

          # If a directory is passed as an argument, use it; otherwise use zoxide interactive
          if [[ -n "$1" ]]; then
            ZOXIDE_RESULT="$1"
          else
            # select a directory using zoxide
            ZOXIDE_RESULT=$(zoxide query --interactive)
          fi

          # checks whether a directory has been selected
          if [[ -z "$ZOXIDE_RESULT" ]]; then
          	# if there was no directory, select returns without executing
          	exit 0
          fi

          # extracts the directory name from the absolute path
          SESSION_TITLE=$(echo "$ZOXIDE_RESULT" | sed 's#.*/##')

          # get the list of sessions
          SESSION_LIST=$(zellij list-sessions -n 2>/dev/null | awk '{print $1}')

          # Check if session already exists
          SESSION_EXISTS=$(echo "$SESSION_LIST" | grep -q "^$SESSION_TITLE$" && echo "yes" || echo "no")

          # If session doesn't exist, ask for layout
          if [[ "$SESSION_EXISTS" == "no" ]]; then
            # Available layouts
            LAYOUT=$(${pkgs.gum}/bin/gum choose "default" "dev" "dev-simple" --header "Choose a layout for new session:")

            # If user cancelled, exit
            if [[ -z "$LAYOUT" ]]; then
              echo "No layout selected, aborting"
              exit 0
            fi
          fi

          # Check if we're already inside a zellij session
          if [[ -n "$ZELLIJ" ]]; then
            # We're inside zellij, so use zellij action to switch sessions
            if [[ "$SESSION_EXISTS" == "yes" ]]; then
              # Session exists, switch to it
              zellij action switch-mode normal
              zellij action go-to-tab-name "$SESSION_TITLE" 2>/dev/null || {
                # If session exists but we can't switch tabs, try session switching
                echo "Switching to existing session: $SESSION_TITLE"
                zellij action detach
                zellij attach "$SESSION_TITLE"
              }
            else
              # Session doesn't exist, we need to detach and create new session
              echo "Creating new session $SESSION_TITLE at $ZOXIDE_RESULT with layout $LAYOUT"
              zellij action detach
              cd "$ZOXIDE_RESULT"
              zellij --layout "$LAYOUT" attach -c "$SESSION_TITLE"
            fi
          else
            # We're outside zellij, original behavior
            if [[ "$SESSION_EXISTS" == "yes" ]]; then
            	# if so, attach to existing session
            	zellij attach "$SESSION_TITLE"
            else
            	# if not, create a new session with selected layout
            	echo "Creating new session $SESSION_TITLE at $ZOXIDE_RESULT with layout $LAYOUT"
            	cd "$ZOXIDE_RESULT"
            	zellij --layout "$LAYOUT" attach -c "$SESSION_TITLE"
            fi
          fi
        '';

        statusbar = ''
          default_tab_template {
              pane size=2 borderless=true {
                  plugin location="file://${pkgs.zjstatus}/bin/zjstatus.wasm" {
                      format_left   "{mode}#[bg=#111318] {tabs}"
                      format_center ""
                      format_right  "#[bg=#111318,fg=#517bac]#[bg=#517bac,fg=#e54d45,bold] #[bg=#6fd66e,fg=#8e9dbf,bold] {session} #[bg=#dbd27b,fg=#8e9dbf,bold]"
                      format_space  ""
                      format_hide_on_overlength "true"
                      format_precedence "crl"

                      border_enabled  "false"
                      border_char     "─"
                      border_format   "#[fg=#6C7086]{char}"
                      border_position "top"

                      mode_normal        "#[bg=#e8e197,fg=#6fd66e,bold] NORMAL#[bg=#dbd27b,fg=#e8e197]█"
                      mode_locked        "#[bg=#6180d1,fg=#6fd66e,bold] LOCKED #[bg=#dbd27b,fg=#6180d1]█"
                      mode_resize        "#[bg=#5c6370,fg=#6fd66e,bold] RESIZE#[bg=#dbd27b,fg=#5c6370]█"
                      mode_pane          "#[bg=#517bac,fg=#6fd66e,bold] PANE#[bg=#dbd27b,fg=#517bac]█"
                      mode_tab           "#[bg=#abb2bf,fg=#6fd66e,bold] TAB#[bg=#dbd27b,fg=#abb2bf]█"
                      mode_scroll        "#[bg=#86e086,fg=#6fd66e,bold] SCROLL#[bg=#dbd27b,fg=#86e086]█"
                      mode_enter_search  "#[bg=#517bac,fg=#6fd66e,bold] ENT-SEARCH#[bg=#dbd27b,fg=#517bac]█"
                      mode_search        "#[bg=#517bac,fg=#6fd66e,bold] SEARCHARCH#[bg=#dbd27b,fg=#517bac]█"
                      mode_rename_tab    "#[bg=#abb2bf,fg=#6fd66e,bold] RENAME-TAB#[bg=#dbd27b,fg=#abb2bf]█"
                      mode_rename_pane   "#[bg=#517bac,fg=#6fd66e,bold] RENAME-PANE#[bg=#dbd27b,fg=#517bac]█"
                      mode_session       "#[bg=#6b75b3,fg=#6fd66e,bold] SESSION#[bg=#dbd27b,fg=#6b75b3]█"
                      mode_move          "#[bg=#ffffff,fg=#6fd66e,bold] MOVE#[bg=#dbd27b,fg=#ffffff]█"
                      mode_prompt        "#[bg=#517bac,fg=#6fd66e,bold] PROMPT#[bg=#dbd27b,fg=#517bac]█"
                      mode_tmux          "#[bg=#e0605f,fg=#6fd66e,bold] TMUX#[bg=#dbd27b,fg=#e0605f]█"

                      tab_normal              "#[bg=#dbd27b,fg=#517bac]█#[bg=#517bac,fg=#6fd66e,bold]{index} #[bg=#6fd66e,fg=#8e9dbf,bold] {name}{floating_indicator}#[bg=#dbd27b,fg=#6fd66e,bold]█"
                      tab_normal_fullscreen   "#[bg=#dbd27b,fg=#517bac]█#[bg=#517bac,fg=#6fd66e,bold]{index} #[bg=#6fd66e,fg=#8e9dbf,bold] {name}{fullscreen_indicator}#[bg=#dbd27b,fg=#6fd66e,bold]█"
                      tab_normal_sync         "#[bg=#dbd27b,fg=#517bac]█#[bg=#517bac,fg=#6fd66e,bold]{index} #[bg=#6fd66e,fg=#8e9dbf,bold] {name}{sync_indicator}#[bg=#dbd27b,fg=#6fd66e,bold]█"

                      tab_active              "#[bg=#dbd27b,fg=#e0605f]█#[bg=#e0605f,fg=#6fd66e,bold]{index} #[bg=#6fd66e,fg=#8e9dbf,bold] {name}{floating_indicator}#[bg=#dbd27b,fg=#6fd66e,bold]█"
                      tab_active_fullscreen   "#[bg=#dbd27b,fg=#e0605f]█#[bg=#e0605f,fg=#6fd66e,bold]{index} #[bg=#6fd66e,fg=#8e9dbf,bold] {name}{fullscreen_indicator}#[bg=#dbd27b,fg=#6fd66e,bold]█"
                      tab_active_sync         "#[bg=#dbd27b,fg=#e0605f]█#[bg=#e0605f,fg=#6fd66e,bold]{index} #[bg=#6fd66e,fg=#8e9dbf,bold] {name}{sync_indicator}#[bg=#dbd27b,fg=#6fd66e,bold]█"

                      tab_separator           "#[bg=#111318] "

                      tab_sync_indicator       " "
                      tab_fullscreen_indicator " 󰊓"
                      tab_floating_indicator   " 󰹙"

                      command_git_branch_command     "git rev-parse --abbrev-ref HEAD"
                      command_git_branch_format      "#[fg=blue] {stdout} "
                      command_git_branch_interval    "10"
                      command_git_branch_rendermode  "static"

                      datetime        "#[fg=#6C7086,bold] {format} "
                      datetime_format "%A, %d %b %Y %H:%M"
                      datetime_timezone "Asia/Kolkata"
                  }
              }
              children
          }
        '';

        theme = ''
          themes {
            stylix {
              bg "#e54d45"
              fg "#8e9dbf"
              red "#5c6370"
              green "#6b75b3"
              blue "#517bac"
              yellow "#86e086"
              magenta "#6b75b3"
              orange "#e0605f"
              cyan "#b9d4ff"
              black "#111318"
              white "#abb2bf"
            }
          }
        '';

        layoutDev = ''
          layout {
              tab name="code" focus=true {
                  pane {
                      command "nvim"
                      args "."
                  }
              }

              tab name="exec" {
                  pane split_direction="vertical" {
                      pane {
                          name "main"
                      }
                  }
              }

              tab name="ai" {
                  pane {
                      name "ai-assistant"
                      command "fish"
                      args "-c" "set ai_tool (string lower $GSESH_AI_TOOL); if test \"$ai_tool\" = \"claude\"; claude -c; else; opencode -c; end; exec fish"
                  }
              }

              ${statusbar}
          }
        '';

        layoutDefault = ''
          layout {
              ${statusbar}

              tab {
                  pane
              }
          }
        '';
      in
      {
        home.packages = [
          pkgs.tmate
          sesh
          inputs.gsesh.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];

        xdg.configFile = {
          "zellij/config.kdl".text = ''
            ${theme}

            ${builtins.readFile ./config.kdl}
          '';
          "zellij/layouts/dev.kdl".text = layoutDev;
          "zellij/layouts/default.kdl".text = layoutDefault;
        };
        programs.zellij.enable = true;
      };
  };
}
