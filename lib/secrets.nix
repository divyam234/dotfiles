{ lib }:
let
  root = ../.;
  commonSopsFile = root + /secrets/common.yaml;

  splitLines = text: lib.splitString "\n" text;
  indentLevel = spaces: builtins.stringLength (builtins.replaceStrings [ "    " ] [ "x" ] spaces);
  isSecret = value: builtins.isAttrs value && (value.__secret or false);

  scanSopsYaml =
    file:
    if !(builtins.pathExists file) then
      [ ]
    else
      let
        step =
          state: line:
          let
            match = builtins.match "^( *)([A-Za-z0-9_-]+):(.*)$" line;
          in
          if match == null || state.skip then
            state
          else
            let
              spaces = builtins.elemAt match 0;
              key = builtins.elemAt match 1;
              rest = builtins.elemAt match 2;
              level = indentLevel spaces;
              parent = lib.take level state.stack;
              path = parent ++ [ key ];
            in
            if level == 0 && key == "sops" then
              state // { skip = true; }
            else if lib.hasInfix "ENC[" rest then
              {
                inherit (state) skip;
                stack = parent;
                paths = state.paths ++ [ path ];
              }
            else
              {
                inherit (state) paths skip;
                stack = path;
              };
      in
      (builtins.foldl' step {
        stack = [ ];
        paths = [ ];
        skip = false;
      } (splitLines (builtins.readFile file))).paths;

  mkSecret =
    {
      config,
      source,
      sopsFile,
      path,
    }:
    let
      name = lib.concatStringsSep "/" path;
      placeholder =
        if config != null then
          config.sops.placeholder.${name}
        else
          throw "Secret ${name} placeholder requested without module config.";
    in
    {
      __secret = true;
      inherit name source;
      __toString = _: placeholder;
      sops = { inherit sopsFile; };
      path =
        if config != null then
          config.sops.secrets.${name}.path
        else
          throw "Secret ${name} path requested without module config.";
      inherit placeholder;
    };

  treeFromPaths =
    {
      config,
      source,
      sopsFile,
      paths,
    }:
    builtins.foldl' (
      acc: path:
      lib.recursiveUpdate acc (
        lib.setAttrByPath path (mkSecret {
          inherit
            config
            source
            sopsFile
            path
            ;
        })
      )
    ) { } paths;

  collectLeaves =
    value:
    if isSecret value then
      [ value ]
    else if builtins.isAttrs value then
      lib.flatten (map collectLeaves (builtins.attrValues value))
    else
      [ ];

  groupsFrom = tree: lib.mapAttrs (_: collectLeaves) tree;

  mkSecrets =
    {
      config ? null,
      host ? null,
    }:
    let
      hostSopsFile = if host != null then host.secretsFile or null else null;
      commonTree = treeFromPaths {
        inherit config;
        source = "common";
        sopsFile = commonSopsFile;
        paths = scanSopsYaml commonSopsFile;
      };
      hostTree =
        if hostSopsFile != null then
          treeFromPaths {
            inherit config;
            source = "host";
            sopsFile = hostSopsFile;
            paths = scanSopsYaml hostSopsFile;
          }
        else
          { };
      mergedTree = lib.recursiveUpdate commonTree hostTree;
      helpers = {
        inherit commonSopsFile collectLeaves;
        inherit hostSopsFile;
        common = commonTree;
        host = hostTree;
        all = collectLeaves mergedTree;
        declare =
          secrets:
          builtins.listToAttrs (
            map (secret: {
              inherit (secret) name;
              value = secret.sops;
            }) (lib.flatten secrets)
          );
        groups = groupsFrom mergedTree;
      };
    in
    mergedTree // helpers;
in
{
  secrets = mkSecrets { } // {
    for = mkSecrets;
  };
}
