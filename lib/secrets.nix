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
      "stash"
      "secret_key"
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
    [
      "teldrive"
      "signing_key"
    ]
    [
      "teldrive"
      "data_key"
    ]
    [
      "teldrive"
      "encryption_key"
    ]
    [
      "teldrive"
      "api_key"
    ]
    [
      "mtproxy"
      "secret"
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
    lib.pipe paths [
      (lib.foldl' (
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
      ) { })
    ];

  collectLeaves =
    value:
    if isSecret value then
      [ value ]
    else if builtins.isAttrs value then
      lib.pipe value [
        builtins.attrValues
        (map collectLeaves)
        lib.flatten
      ]
    else
      [ ];

  groupsFrom = tree: lib.pipe tree [ (lib.mapAttrs (_: collectLeaves)) ];

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
          throw "No explicit secret contract defined for host ${hostName}. Add it to hostPaths in lib/secrets.nix.";
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
          throw "Host ${hostName} declares host secrets but has no secretsFile. Set host.secretsFile or add hostPaths entry in lib/secrets.nix."
        else
          treeFromPaths {
            inherit config;
            source = "host";
            sopsFile = hostSopsFile;
            paths = selectedHostPaths;
          };
      mergedTree = lib.pipe [ commonTree hostTree ] [ (lib.foldl' lib.recursiveUpdate { }) ];
      helpers = {
        inherit commonSopsFile collectLeaves hostSopsFile;
        common = commonTree;
        host = hostTree;
        all = lib.pipe mergedTree [ collectLeaves ];
        declare =
          secrets:
          lib.pipe secrets [
            lib.flatten
            (map (secret: {
              inherit (secret) name;
              value = secret.sops;
            }))
            builtins.listToAttrs
          ];
        groups = lib.pipe mergedTree [ groupsFrom ];
        mkTemplate =
          {
            name,
            content,
            mode ? "0440",
            path ? "/run/secrets/container-env/${name}",
          }:
          {
            inherit path mode content;
          };
      };
    in
    mergedTree // helpers;
in
{
  secrets = mkSecrets { } // {
    for = mkSecrets;
  };
}
