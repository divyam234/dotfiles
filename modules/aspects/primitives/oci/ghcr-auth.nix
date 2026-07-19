{ den, ... }:
let
  ghcrUser = "divyam234";
  mkAuthWriter =
    {
      authFile,
      pkgs,
      tokenFile,
    }:
    pkgs.writeShellScript "write-ghcr-auth" ''
      set -eu

      auth_file=${authFile}
      auth_dir="$(${pkgs.coreutils}/bin/dirname "$auth_file")"
      ${pkgs.coreutils}/bin/install -d -m 0700 "$auth_dir"

      token="$(${pkgs.coreutils}/bin/tr -d '[:space:]' < ${tokenFile})"
      auth="$(${pkgs.coreutils}/bin/printf '%s:%s' ${ghcrUser} "$token" | ${pkgs.coreutils}/bin/base64 --wrap=0)"
      tmp="$auth_file.tmp.$$"
      trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
      ${pkgs.coreutils}/bin/printf '{"auths":{"ghcr.io":{"auth":"%s"}}}\n' "$auth" > "$tmp"
      ${pkgs.coreutils}/bin/chmod 0600 "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$auth_file"
      trap - EXIT
    '';
in
{
  den.aspects.ghcr-auth = {
    nixos =
      { pkgs, secrets, ... }:
      let
        authFile = "/run/containers/0/auth.json";
        writer = mkAuthWriter {
          inherit authFile pkgs;
          tokenFile = secrets.github.token.path;
        };
      in
      {
        systemd.services.ghcr-auth = {
          description = "Generate rootful Podman authentication for GHCR";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = writer;
            RemainAfterExit = true;
          };
        };
      };

    homeManager =
      { pkgs, secrets, ... }:
      let
        writer = mkAuthWriter {
          authFile = "\"$XDG_RUNTIME_DIR/containers/auth.json\"";
          inherit pkgs;
          tokenFile = secrets.github.token.path;
        };
      in
      {
        systemd.user.services.ghcr-auth = {
          Unit = {
            Description = "Generate rootless Podman authentication for GHCR";
          };
          Service = {
            Type = "oneshot";
            ExecStart = writer;
            RemainAfterExit = true;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
  };
}
