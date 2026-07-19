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
assert laptop.programs.noctalia-greeter.greeter-args == "--session niri --user ${userName}";
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
assert !(builtins.hasAttr "container-update-webhook" laptop.systemd.services);
true
