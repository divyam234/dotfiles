{ config, pkgs, ... }:
let
  usbSshConfig = pkgs.writeText "capri-usb-sshd_config" ''
    # Deliberately unauthenticated: reachable only through the USB ECM interface.
    Port 2223
    AddressFamily inet
    ListenAddress 172.16.42.1
    HostKey /etc/ssh/ssh_host_ed25519_key
    UsePAM no
    PermitEmptyPasswords yes
    PasswordAuthentication yes
    KbdInteractiveAuthentication no
    PubkeyAuthentication no
    HostbasedAuthentication no
    PermitRootLogin no
    AllowUsers capriusb
    PermitTTY yes
    AllowTcpForwarding no
    AllowStreamLocalForwarding no
    AllowAgentForwarding no
    X11Forwarding no
    PermitTunnel no
    PermitUserEnvironment no
    PermitUserRC no
    GatewayPorts no
    PermitOpen none
    PermitListen none
    PidFile none
  '';
in
{
  # Dedicated non-wheel account: USB SSH has no client authentication.
  # The explicit sudo rule below intentionally grants root on this dev phone.
  users.users.capriusb = {
    isNormalUser = true;
    description = "Local USB diagnostic SSH access";
    home = "/home/capriusb";
    createHome = true;
    password = "";
    shell = pkgs.bashInteractive;
  };

  # Dedicated account rule; wheel membership is not required. Anyone who
  # can access the unauthenticated USB SSH service can become root.
  security.sudo.extraRules = [
    {
      users = [ "capriusb" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Only packets that arrive over usb0 may reach the unauthenticated daemon.
  # Never add 2223 to networking.firewall.allowedTCPPorts globally.
  networking.firewall.interfaces.usb0.allowedTCPPorts = [ 2223 ];

  systemd.services.capri-usb-sshd = {
    description = "Capri USB-only SSH (no client authentication)";
    wantedBy = [ "multi-user.target" ];
    requires = [ "capri-usb-ecm.service" ];
    after = [
      "capri-usb-ecm.service"
      "sshd-keygen.service"
    ];
    wants = [ "sshd-keygen.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${config.services.openssh.package}/bin/sshd -D -e -f ${usbSshConfig}";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
