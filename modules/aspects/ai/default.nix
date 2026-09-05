{ den, ... }:

{
  den.aspects.ai = { host, ... }: {
    homeManager =
      {
        lib,
        pkgs,
        config,
        secrets,
        ...
      }:

      let
        json = pkgs.formats.json { };

        gproxyBaseUrl = "https://gproxy.${host.domain}/codex/v1";
        opencodeEnvFile = "${config.xdg.configHome}/opencode/opencode.env";

        mkAgent =
          {
            model,
            variant ? null,
            skills ? [ ],
            mcps ? [ ],
          }:
          {
            inherit model skills mcps;
          }
          // lib.optionalAttrs (variant != null) {
            inherit variant;
          };

        models = {
          openaiStrong = "openai/gpt-6-astra";
          openaiFast = "openai/gpt-5.6-luna";
          opencode = "opencode/muse-spark-1.3-contributor-free";
        };

        opencodeConfig = {
          "$schema" = "https://opencode.ai/config.json";
          autoupdate = false;
          compaction = {
            auto = true;
            prune = true;
          };
          tools = {
            task = false;
          };
          provider = {
            openai = {
              npm = "@ai-sdk/openai";
              options = {
                baseURL = gproxyBaseUrl;
                apiKey = "{env:OPENAI_API_KEY}";
              };
            };
          };

          plugin = [
            "oh-my-opencode-slim"
          ];

          agent = {
            explore.disable = true;
            general.disable = true;
          };
        };

        omoSlimConfig = {
          preset = "openai";
          presets = {
            openai = {
              orchestrator = mkAgent {
                model = models.openaiStrong;
                variant = "high";
                skills = [ "*" ];
                mcps = [
                  "*"
                  "!context7"
                ];
              };
              oracle = mkAgent {
                model = models.openaiStrong;
                variant = "high";
                skills = [ "simplify" ];
              };

              librarian = mkAgent {
                model = models.openaiFast;
                variant = "low";
                mcps = [
                  "websearch"
                  "context7"
                  "grep_app"
                ];
              };

              explorer = mkAgent {
                model = models.openaiFast;
                variant = "low";
              };

              designer = mkAgent {
                model = models.openaiFast;
                variant = "medium";
              };

              fixer = mkAgent {
                model = models.openaiStrong;
                variant = "medium";
              };
            };

            opencode = {
              orchestrator = mkAgent {
                model = models.opencode;
                skills = [ "*" ];
                mcps = [
                  "*"
                  "!context7"
                ];
              };

              oracle = mkAgent {
                model = models.opencode;
                variant = "high";
                skills = [ "simplify" ];
              };

              council = mkAgent {
                model = models.opencode;
                variant = "high";
              };

              librarian = mkAgent {
                model = models.opencode;
                mcps = [
                  "websearch"
                  "context7"
                  "grep_app"
                ];
              };

              explorer = mkAgent {
                model = models.opencode;
              };

              designer = mkAgent {
                model = models.opencode;
                variant = "medium";
              };

              fixer = mkAgent {
                model = models.opencode;
                variant = "high";
              };
            };
          };
          balanceProviderUsage = false;
          # multiplexer = {
          #   type = "zellij";
          # };
        };
      in
      {
        programs = {
          opencode = {
            enable = true;
            package = pkgs.opencode;
            settings = opencodeConfig;
          };

          fish.interactiveShellInit = lib.mkAfter ''
            if test -f "${opencodeEnvFile}"
              envsource "${opencodeEnvFile}"
            end
          '';

          bash.initExtra = lib.mkAfter ''
            if [ -f "${opencodeEnvFile}" ]; then
              set -a
              . "${opencodeEnvFile}"
              set +a
            fi
          '';

          bunGlobalCli = {
            enable = true;
            cachePruneScopes = [ "@oh-my-pi" ];
            packages = lib.mkAfter [
              "@oh-my-pi/pi-coding-agent"
            ];
            timer = {
              enable = true;
              calendar = "daily";
            };
          };
        };

        stylix.targets.opencode.enable = true;

        sops.templates."opencode.env" = secrets.mkTemplate {
          name = "opencode.env";
          path = opencodeEnvFile;
          mode = "0400";
          content = ''
            OPENAI_API_KEY=${secrets.openai.api_key}
          '';
        };

        home.packages = [ pkgs.codeforge ];

        home.file.".config/opencode/oh-my-opencode-slim.json".source =
          json.generate "oh-my-opencode-slim.json" omoSlimConfig;
      };
  };
}
