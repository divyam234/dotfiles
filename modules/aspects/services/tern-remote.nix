_: {
  den.aspects.tern-remote = {
    homeManager =
      { lib, pkgs, ... }:
      {
        home.packages = [ pkgs.tern-headless ];

        systemd.user.services.tern-remote = {
          Unit.Description = "Tern remote sessions";
          Install.WantedBy = [ "default.target" ];
          Service = {
            Type = "exec";
            ExecStart = "${lib.getExe pkgs.tern-headless} remote serve --user --relay none --authorized-keys /etc/ssh/authorized_keys.d/%u";
            Restart = "on-failure";
            RestartSec = 2;
            RestartPreventExitStatus = 2;
            KillMode = "process";
          };
        };
      };
  };
}
