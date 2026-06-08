{ den, ... }:
{
  den.aspects.ai = {
    homeManager =
      { pkgs, ... }:
      let
        json = pkgs.formats.json { };

        opencodeConfig = {
          "$schema" = "https://opencode.ai/config.json";

          tools.task = false;

          mcp.browser = {
            type = "local";
            enabled = true;
            command = [
              "bun"
              "x"
              "camofox-mcp@latest"
            ];
            environment.CAMOFOX_URL = "http://localhost:9377";
          };
        };
      in
      {
        home.packages = [ pkgs.opencode ];

        programs.bunGlobalCli = {
          enable = true;
          packages = [ "@oh-my-pi/pi-coding-agent" ];
          timer = {
            enable = true;
            calendar = "daily";
          };
        };

        home.file.".config/opencode/opencode.json".source = json.generate "opencode.json" opencodeConfig;
      };
  };
}
