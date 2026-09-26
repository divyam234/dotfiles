{ den, ... }:
{
  den.aspects.ida-mcp = { host, ... }: {
    caddyRoutes.ida-mcp = {
      host = "ida.${host.domain}";
      access = "tailnet";
      upstreams = [ "host.containers.internal:8745" ];
    };

    homeManager =
      { pkgs, ... }:
      let
        idaDir = "${pkgs.ida-pro}/opt/ida-pro-${pkgs.ida-pro.version}";
        acceptEula = pkgs.writeShellScript "ida-accept-eula" ''
          exec ${pkgs.python314}/bin/python3.14 -c 'import idapro, ida_registry; ida_registry.reg_write_int("EULA 90", 1)'
        '';
      in
      {
        systemd.user.services.ida-mcp = {
          Unit.Description = "IDA Headless MCP Server";
          Service = {
            Type = "simple";
            Environment = [
              "IDADIR=${idaDir}"
              "PYTHONPATH=${idaDir}/idalib/python"
              "LD_LIBRARY_PATH=${pkgs.ida-pro}/lib"
            ];
            ExecStartPre = acceptEula;
            ExecStart = "${pkgs.uv}/bin/uvx --python ${pkgs.python314}/bin/python3.14 --from git+https://github.com/mrexodia/ida-pro-mcp@fab3505ee2405ef4e87dcd370418ea7d661f5bdf idalib-mcp --host 0.0.0.0 --port 8745";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };

    nixos =
      { containers, ... }:
      {
        networking.firewall.interfaces."br-${containers.networkName}".allowedTCPPorts = [ 8745 ];
      };
  };
}
