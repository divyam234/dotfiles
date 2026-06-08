{ lib }:
{
  importPackages =
    pkgs: directory:
    if builtins.pathExists directory then
      let
        entries = builtins.readDir directory;
        names = builtins.filter (
          name: entries.${name} == "directory" && builtins.pathExists (directory + "/${name}/default.nix")
        ) (builtins.attrNames entries);
      in
      builtins.listToAttrs (
        map (name: {
          inherit name;
          value = pkgs.callPackage (directory + "/${name}") { };
        }) names
      )
    else
      { };
}
