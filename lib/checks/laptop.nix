{ laptop, home }:
let
  userName = home.home.username;
  groups = laptop.users.users.${userName}.extraGroups;
  niriConfig = home.xdg.configFile."niri/config.kdl".text;
  contains = needle: builtins.replaceStrings [ needle ] [ "" ] niriConfig != niriConfig;
  uniqueGroups = builtins.attrNames (
    builtins.listToAttrs (
      map (group: {
        name = group;
        value = true;
      }) groups
    )
  );
in
assert
  laptop.services.displayManager.noctalia-greeter.extraArgs == [
    "--session"
    "niri"
    "--user"
    userName
  ];
assert builtins.length groups == builtins.length uniqueGroups;
assert builtins.hasAttr "niri/config.kdl" home.xdg.configFile;
assert contains ''
  output "eDP-1" {
      off'';
assert contains ''output "HDMI-A-1" {'';
assert contains ''output "HDMI-A-2" {'';
assert contains ''mode "1920x1080@74.973"'';
assert contains "scale 1.250000";
assert contains "position x=0 y=0";
assert contains "position x=1536 y=0";
assert home.programs.bunGlobalCli.cachePruneScopes == [ "@oh-my-pi" ];
assert builtins.elem "@oh-my-pi/pi-coding-agent" home.programs.bunGlobalCli.packages;
assert builtins.elem "@askjo/camofox-browser-mcp" home.programs.bunGlobalCli.packages;
assert builtins.hasAttr ".omp/agent/config.yml" home.home.file;
assert builtins.hasAttr ".omp/agent/models.yml" home.home.file;
assert builtins.hasAttr ".omp/agent/mcp.json" home.home.file;
assert builtins.hasAttr ".omp/agent/themes/stylix.json" home.home.file;
assert home.sops.templates."omp.env".path == "${home.home.homeDirectory}/.omp/agent/.env";
assert home.sops.templates."omp.env".mode == "0400";
assert
  builtins.substring 0 (builtins.stringLength
    home.sops.templates."opencode.env".content
  ) home.sops.templates."omp.env".content == home.sops.templates."opencode.env".content;
assert !(builtins.hasAttr "rclone-serve-webdav" home.systemd.user.services);
true
