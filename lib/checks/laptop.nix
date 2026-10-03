{ laptop, home }:
let
  userName = home.home.username;
  groups = laptop.users.users.${userName}.extraGroups;
  niriConfig = home.xdg.configFile."niri/config.kdl".text;
  contains = needle: builtins.replaceStrings [ needle ] [ "" ] niriConfig != niriConfig;
  umbrielSettings = home.programs.umbriel.settings;
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
assert home.programs.umbriel.enable;
assert builtins.hasAttr "umbriel/config.toml" home.xdg.configFile;
assert umbrielSettings.general.autostart == [ "noctalia" ];
assert umbrielSettings.output."eDP-1".enabled == false;
assert umbrielSettings.output."HDMI-A-1".mode == "1920x1080@74.973";
assert umbrielSettings.output."HDMI-A-2".mode == "1920x1080@74.973";
assert umbrielSettings.output."HDMI-A-1".scale == 1.25;
assert umbrielSettings.output."HDMI-A-2".scale == 1.25;
assert
  umbrielSettings.output."HDMI-A-2".position == [
    0
    0
  ];
assert
  umbrielSettings.output."HDMI-A-1".position == [
    1536
    0
  ];
assert umbrielSettings.keybinds."Mod+Space" == "spawn:noctalia msg panel-toggle launcher";
assert umbrielSettings.layout.gap == 12;
assert home.programs.bunGlobalCli.cachePruneScopes == [ "@oh-my-pi" ];
assert !(builtins.hasAttr "rclone-serve-webdav" home.systemd.user.services);
true
