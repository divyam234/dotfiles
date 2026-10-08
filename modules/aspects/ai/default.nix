{ den, ... }:

{
  den.aspects.ai = {
    homeSecrets = [
      "openai/api_key"
      "camofox/access_key"
      "camofox/api_key"
    ];

    homeManager =
      {
        lib,
        pkgs,
        config,
        secrets,
        host,
        ...
      }:

      let
        json = pkgs.formats.json { };
        yaml = pkgs.formats.yaml { };

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
          openaiStrong = "openai/gpt-6.1-sol";
          openaiFast = "openai/gpt-6-luna";
          opencode = "opencode/muse-spark-1.3-contributor-free";
        };

        ompModels = {
          providers.openai-codex = {
            baseUrl = gproxyBaseUrl;
            api = "openai-responses";
            apiKey = "OPENAI_API_KEY";
            modelOverrides = builtins.listToAttrs (
              map
                (model: {
                  name = lib.removePrefix "openai/" model;
                  value = {
                    remoteCompaction = {
                      api = "openai-responses";
                      v2StreamingEnabled = true;
                    };
                  };
                })
                [
                  models.openaiStrong
                  models.openaiFast
                ]
            );
          };
        };

        ompMcp = {
          mcpServers.camofox = {
            type = "stdio";
            command = "${pkgs.bun}/bin/bun";
            args = [
              "run"
              "${config.home.homeDirectory}/.bun/bin/camofox-browser-mcp"
            ];
            env.CAMOFOX_BASE_URL = "http://netcup:9377";
          };
        };

        ompTheme =
          let
            colors = config.lib.stylix.colors.withHashtag;
          in
          {
            name = "stylix";
            colors = {
              accent = colors.base0D;
              border = colors.base03;
              borderAccent = colors.base0D;
              borderMuted = colors.base02;
              success = colors.base0B;
              error = colors.base08;
              warning = colors.base0A;
              muted = colors.base04;
              dim = colors.base03;
              text = colors.base05;
              thinkingText = colors.base04;
              selectedBg = colors.base02;
              userMessageBg = colors.base01;
              userMessageText = colors.base05;
              customMessageBg = colors.base01;
              customMessageText = colors.base05;
              customMessageLabel = colors.base0E;
              toolPendingBg = colors.base01;
              toolSuccessBg = colors.base01;
              toolErrorBg = colors.base01;
              toolTitle = colors.base05;
              toolOutput = colors.base05;
              mdHeading = colors.base0D;
              mdLink = colors.base0D;
              mdLinkUrl = colors.base04;
              mdCode = colors.base0B;
              mdCodeBlock = colors.base05;
              mdCodeBlockBorder = colors.base03;
              mdQuote = colors.base04;
              mdQuoteBorder = colors.base03;
              mdHr = colors.base03;
              mdListBullet = colors.base0D;
              toolDiffAdded = colors.base0B;
              toolDiffRemoved = colors.base08;
              toolDiffContext = colors.base04;
              syntaxComment = colors.base03;
              syntaxKeyword = colors.base0E;
              syntaxFunction = colors.base0D;
              syntaxVariable = colors.base05;
              syntaxString = colors.base0B;
              syntaxNumber = colors.base09;
              syntaxType = colors.base0A;
              syntaxOperator = colors.base0C;
              syntaxPunctuation = colors.base05;
              thinkingOff = colors.base03;
              thinkingMinimal = colors.base04;
              thinkingLow = colors.base0D;
              thinkingMedium = colors.base0C;
              thinkingHigh = colors.base0E;
              thinkingXhigh = colors.base09;
              thinkingMax = colors.base08;
              bashMode = colors.base0C;
              pythonMode = colors.base0E;
              statusLineBg = colors.base00;
              statusLineSep = colors.base03;
              statusLineModel = colors.base0E;
              statusLinePath = colors.base0D;
              statusLineGitClean = colors.base0B;
              statusLineGitDirty = colors.base0A;
              statusLineContext = colors.base0C;
              statusLineSpend = colors.base0C;
              statusLineStaged = colors.base0B;
              statusLineDirty = colors.base0A;
              statusLineUntracked = colors.base08;
              statusLineOutput = colors.base05;
              statusLineCost = colors.base09;
              statusLineSubagents = colors.base0E;
            };
          };

        ompConfig = {
          symbolPreset = "nerd";
          completion.notify = "off";
          error.notify = "off";
          ask.notify = "off";
          theme = {
            dark = "stylix";
            light = "stylix";
          };
          enabledModels = [
            "openai-codex/gpt-6.1-sol"
            "openai-codex/gpt-6-luna"
          ];
          modelRoles = {
            default = "openai-codex/gpt-6.1-sol:low";
            smol = "openai-codex/gpt-6-luna:low";
            slow = "openai-codex/gpt-6.1-sol:medium";
            plan = "@slow";
          };
          defaultThinkingLevel = "medium";
          hideThinkingBlock = false;
          statusLine.compactThinkingLevel = false;
          tui.renderMermaid = true;
          display = {
            hideToolActivity = true;
            showTokenUsage = true;
            showTurnTime = true;
            subagentLivePreview = true;
          };
          readLineNumbers = true;
          compaction.enabled = true;
          memory.backend = "local";
          browser.enabled = false;
          providers.openai-codex.codeMode = "on";
          startup = {
            quiet = true;
            showSplash = false;
            setupWizard = false;
            # bunGlobalCli already checks for updates daily.
            checkUpdate = false;
          };
        };

        opencodeConfig = {
          "$schema" = "https://opencode.ai/config.json";
          update = "disable";
          compaction = {
            auto = true;
          };
          providers = {
            openai = {
              package = "aisdk:@ai-sdk/openai";
              settings = {
                baseURL = gproxyBaseUrl;
                apiKey = "{env:OPENAI_API_KEY}";
              };
            };
          };

          mcp.servers.ida = {
            type = "remote";
            url = "https://ida.${host.domain}/mcp";
            disabled = true;
          };

          plugins = [
            "oh-my-opencode-slim"
          ];

          agents = {
            explore.disabled = true;
            general.disabled = true;
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
                  "context7"
                  "gh_grep"
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
                variant = "high";
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
        cliConfig = {
          "$schema" = "https://opencode.ai/v2/cli.json";
          theme = {
            name = "stylix";
            mode = "system";
          };
          session = {
            sidebar = "hide";
          };
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
              "@askjo/camofox-browser-mcp"
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

        # OMP loads this natively, including outside interactive shells.
        sops.templates."omp.env" = secrets.mkTemplate {
          name = "omp.env";
          path = "${config.home.homeDirectory}/.omp/agent/.env";
          mode = "0400";
          content = ''
            OPENAI_API_KEY=${secrets.openai.api_key}
            CAMOFOX_ACCESS_KEY=${secrets.camofox.access_key}
            CAMOFOX_API_KEY=${secrets.camofox.api_key}
          '';
        };

        home.packages = [
          pkgs.codeforge
        ];

        # Declarative settings: use project config or --config for overrides.
        home.file.".omp/agent/config.yml".source = yaml.generate "omp-config.yml" ompConfig;
        home.file.".omp/agent/models.yml".source = yaml.generate "omp-models.yml" ompModels;
        home.file.".omp/agent/extensions/gproxy-codex.ts".text =
          builtins.replaceStrings [ "@GPROXY_BASE_URL@" ] [ gproxyBaseUrl ]
            (builtins.readFile ./gproxy-codex.ts);
        home.file.".omp/agent/mcp.json".source = json.generate "omp-mcp.json" ompMcp;
        home.file.".omp/agent/themes/stylix.json".source = json.generate "omp-stylix.json" ompTheme;

        home.file.".config/opencode/oh-my-opencode-slim.json".source =
          json.generate "oh-my-opencode-slim.json" omoSlimConfig;

        xdg.configFile."opencode/cli.json" = {
          text = builtins.toJSON cliConfig;
          force = true;
        };
      };
  };
}
