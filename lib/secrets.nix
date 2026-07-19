{ lib }:
let
  root = ../.;
  commonSopsFile = root + /secrets/common.yaml;

  commonPaths = [
    [
      "users"
      "bhunter"
      "password"
    ]
    [
      "cloudflare"
      "api_token"
    ]
    [
      "tailscale"
      "oauth_client_secret"
    ]
    [
      "nordvpn"
      "private_key"
    ]
    [
      "nordvpn"
      "token"
    ]
    [
      "github"
      "token"
    ]
    [
      "codeforge"
      "token"
    ]
    [
      "ssh"
      "private_key"
    ]
    [
      "postgres"
      "user"
    ]
    [
      "postgres"
      "password"
    ]
  ];

  hostPaths = {
    homelab = [ ];
    laptop = [ ];
    netcup = [
      [
        "redis"
        "password"
      ]
      [
        "vaultwarden"
        "admin_token"
      ]
      [
        "restic"
        "password"
      ]
      [
        "restic"
        "repository"
      ]
      [
        "restic"
        "rclone_conf"
      ]
      [
        "gproxy"
        "admin_password"
      ]
      [
        "gproxy"
        "master_key"
      ]
    ];
  };

  isSecret = value: builtins.isAttrs value && (value.__secret or false);

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
      hostName = if host != null then host.name else null;
      hostSopsFile = if host != null then host.secretsFile or null else null;
      selectedHostPaths =
        if hostName == null then
          [ ]
        else if builtins.hasAttr hostName hostPaths then
          hostPaths.${hostName}
        else
          throw "No explicit secret contract defined for host ${hostName}.";
      commonTree = treeFromPaths {
        inherit config;
        source = "common";
        sopsFile = commonSopsFile;
        paths = commonPaths;
      };
      hostTree =
        if selectedHostPaths == [ ] then
          { }
        else if hostSopsFile == null then
          throw "Host ${hostName} declares host secrets but has no secretsFile."
        else
          treeFromPaths {
            inherit config;
            source = "host";
            sopsFile = hostSopsFile;
            paths = selectedHostPaths;
          };
      mergedTree = lib.recursiveUpdate commonTree hostTree;
      helpers = {
        inherit commonSopsFile collectLeaves hostSopsFile;
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
