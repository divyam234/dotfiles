{ laptop, home }:
let
  userName = home.home.username;
  groups = laptop.users.users.${userName}.extraGroups;
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
true
