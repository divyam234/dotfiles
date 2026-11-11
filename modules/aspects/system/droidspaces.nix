{ den, ... }:
{
  # Adapted from Droidspaces-OSS nix/nixos.nix (GPL-3.0).
  # https://github.com/ravindu644/Droidspaces-OSS/blob/main/nix/nixos.nix
  # Deliberately supports NAT mode only; Android owns the kernel and hardware.
  den.aspects.droidspaces.nixos =
    {
      lib,
      modulesPath,
      pkgs,
      ...
    }:
    {
      imports = [ "${modulesPath}/virtualisation/lxc-container.nix" ];

      boot = {
        kernelModules = lib.mkForce [ ];
        # Only container-network sysctls; Android owns host kernel tuning.
        kernel.sysctl = lib.mkForce {
          "net.ipv4.ip_forward" = 1;
          "net.ipv6.conf.all.forwarding" = 1;
        };
      };
      networking = {
        useDHCP = lib.mkDefault true;
        useHostResolvConf = false;
        nftables.enable = false;
        # Upstream disables the NixOS firewall because of Android compatibility.
        # Use the isolated Droidspaces NAT network, not shared host networking.
        firewall = {
          enable = lib.mkForce false;
          package = pkgs.iptables-legacy;
        };
      };
      environment.systemPackages = [ pkgs.iptables-legacy ];
      # Android applies app-UID network policy to the default 30001+ range.
      # Keep distinct, unprivileged build users below AID_APP_START (10000).
      ids.uids.nixbld = lib.mkForce 9000;

      systemd = {
        network.enable = lib.mkForce false;
        services = {
          firewall.enable = false;
          nix-channel-init.enable = false;
          wpa_supplicant.enable = false;
          systemd-networkd-wait-online.enable = false;
          # hidepid mount options used by ProtectProc=invisible fail on
          # capri's 4.19 kernel. Keep the rest of DHCP's sandbox intact.
          dhcpcd.serviceConfig.ProtectProc = lib.mkForce "default";
          # ImportCredential triggers credential mounts unsupported by this
          # runtime. These units use no supplied credentials on capri.
          systemd-journald.serviceConfig.ImportCredential = lib.mkForce [ "" ];
          systemd-resolved.serviceConfig.ImportCredential = lib.mkForce [ "" ];
          systemd-tmpfiles-setup.serviceConfig.ImportCredential = lib.mkForce [ "" ];
          systemd-tmpfiles-setup-dev.serviceConfig.ImportCredential = lib.mkForce [ "" ];
          systemd-tmpfiles-setup-dev-early.serviceConfig.ImportCredential = lib.mkForce [ "" ];
          systemd-tmpfiles-clean.serviceConfig.ImportCredential = lib.mkForce [ "" ];
          systemd-udev-trigger = {
            serviceConfig.ExecStart = lib.mkForce [
              ""
              "-udevadm trigger --subsystem-match=usb --subsystem-match=block --subsystem-match=input --subsystem-match=tty --subsystem-match=net"
            ];
            unitConfig.ConditionPathIsReadWrite = lib.mkForce [ ];
          };
          systemd-udevd.unitConfig.ConditionPathIsReadWrite = lib.mkForce [ ];
          systemd-udev-settle.unitConfig.ConditionPathIsReadWrite = lib.mkForce [ ];
        };
        sockets = {
          systemd-journald-audit.enable = false;
          systemd-udevd-kernel.unitConfig.ConditionPathIsReadWrite = lib.mkForce [ ];
          systemd-udevd-control.unitConfig.ConditionPathIsReadWrite = lib.mkForce [ ];
        };
      };

      services = {
        tailscale.package = lib.mkForce (pkgs.tailscale.override { iptables = pkgs.iptables-legacy; });
        logind.settings.Login = {
          HandlePowerKey = "ignore";
          HandleSuspendKey = "ignore";
          HandleHibernateKey = "ignore";
          HandlePowerKeyLongPress = "ignore";
        };
        journald.settings.Journal = {
          ReadKMsg = "no";
          Audit = "no";
          Storage = "volatile";
          RuntimeMaxUse = "10M";
        };
        timesyncd.enable = lib.mkForce false;
        # fail2ban requires the firewall that upstream cannot support here.
        fail2ban.enable = lib.mkForce false;
      };
      security = {
        rtkit.enable = lib.mkForce false;
        audit.enable = false;
      };

      users = {
        groups = {
          aid_inet.gid = 3003;
          aid_net_raw.gid = 3004;
          aid_net_admin.gid = 3005;
        };
        users = {
          root.extraGroups = [
            "aid_inet"
            "aid_net_raw"
            "aid_net_admin"
          ];
          bhunter.extraGroups = [ "aid_inet" ];
        };
      };
    };
}
