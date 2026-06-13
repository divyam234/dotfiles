{ den, ... }:

{
  den.aspects.ai = {
    homeManager =
      { lib, pkgs, ... }:

      let
        json = pkgs.formats.json { };

        mkLocalMcp =
          {
            package,
            args ? [ ],
            enabled ? false,
            environment ? null,
          }:
          {
            type = "local";
            command = [
              "bun"
              "x"
              "${package}@latest"
            ]
            ++ args;
            inherit enabled;
          }
          // lib.optionalAttrs (environment != null) {
            inherit environment;
          };

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
          openaiStrong = "openai/gpt-5.5";
          openaiFast = "openai/gpt-5.4-mini";
          opencodeFree = "opencode/deepseek-v4-flash-free";
        };

        opencodeConfig = {
          "$schema" = "https://opencode.ai/config.json";
          autoupdate = false;
          tools = {
            task = false;
          };

          mcp = {
            react-aria = mkLocalMcp {
              package = "@react-aria/mcp";
            };

            heroui = mkLocalMcp {
              package = "@heroui/react-mcp";
            };

            shadcn = mkLocalMcp {
              package = "shadcn";
              args = [ "mcp" ];
            };

            browser = mkLocalMcp {
              package = "camofox-mcp";
              enabled = true;
              environment = {
                CAMOFOX_URL = "http://localhost:9377";
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
          preset = "opencode";

          presets = {
            openai = {
              orchestrator = mkAgent {
                model = models.openaiStrong;
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
                model = models.openaiFast;
                variant = "low";
              };
            };

            opencode = {
              orchestrator = mkAgent {
                model = models.opencodeFree;
                skills = [ "*" ];
                mcps = [
                  "*"
                  "!context7"
                ];
              };

              oracle = mkAgent {
                model = models.opencodeFree;
                variant = "high";
                skills = [ "simplify" ];
              };

              council = mkAgent {
                model = models.opencodeFree;
                variant = "high";
              };

              librarian = mkAgent {
                model = models.opencodeFree;
                mcps = [
                  "websearch"
                  "context7"
                  "grep_app"
                ];
              };

              explorer = mkAgent {
                model = models.opencodeFree;
              };

              designer = mkAgent {
                model = models.opencodeFree;
                variant = "medium";
                skills = [ "agent-browser" ];
              };

              fixer = mkAgent {
                model = models.opencodeFree;
                variant = "high";
              };
            };
          };

          balanceProviderUsage = false;

          fallback = {
            enabled = false;
            timeoutMs = 15000;
          };
        };
      in
      {
        home.packages = [
          pkgs.opencode
        ];
        programs.bunGlobalCli = {
          enable = true;
          packages = lib.mkAfter [
            "@oh-my-pi/pi-coding-agent"
          ];
          timer = {
            enable = true;
            calendar = "daily";
          };
        };

        home.file.".config/opencode/opencode.json".source = json.generate "opencode.json" opencodeConfig;

        home.file.".config/opencode/oh-my-opencode-slim.json".source =
          json.generate "oh-my-opencode-slim.json" omoSlimConfig;
      };
  };
}
