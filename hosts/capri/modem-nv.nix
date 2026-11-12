{
  lib,
  pkgs,
  ...
}:
let
  nvDir = "/run/capri-rmtfs/by-partlabel";
  wifi = import ../../packages/capri/wifi-tools.nix { inherit pkgs; };
  firmware = pkgs.callPackage ../../packages/capri/firmware { };
  startModem = pkgs.writeShellApplication {
    name = "capri-start-wifi-modem";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.kmod
    ];
    text = ''
      set -euo pipefail
      # Wait until the RMTFS (14), PD Mapper (64), and TFTP (4096)
      # QRTR endpoints are published; Type=simple alone is insufficient.
      for service in 14 64 4096; do
        ready=0
        for _ in $(seq 1 20); do
          if qrtr-lookup "$service" 2>/dev/null | grep -Eq "^[[:space:]]*''${service}[[:space:]]"; then
            ready=1
            break
          fi
          sleep 1
        done
        if [ "$ready" != 1 ]; then
          echo "Qualcomm QRTR service $service not ready" >&2
          exit 1
        fi
      done
      modprobe qcom_q6v5_pas
      state=/sys/class/remoteproc/remoteproc0/state
      test -e "$state" || { echo "Capri modem remoteproc0 missing" >&2; exit 1; }
      case "$(cat "$state")" in
        running) exit 0 ;;
        offline) echo start > "$state" ;;
        *) echo "Unexpected modem remoteproc state: $(cat "$state")" >&2; exit 1 ;;
      esac
      for _ in $(seq 1 40); do
        test "$(cat "$state")" = running && exit 0
        sleep 1
      done
      echo "Capri modem failed to reach running state" >&2
      exit 1
    '';
  };
  # The Motorola backup partition is fsg_b, not the generic fsg.
  prepare = pkgs.writeShellApplication {
    name = "capri-prepare-readonly-modem-nv";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail
      install -d -m 0700 ${nvDir}

      for part in modemst1 modemst2 fsg_b fsc; do
        dev="/dev/disk/by-partlabel/$part"
        test -b "$dev" || {
          echo "Capri modem NV partition missing: $part" >&2
          exit 1
        }
      done

      # Runtime block-device read-only flag. Never modify on-disk GPT
      # attributes, Android persist or NV data.
      for part in modemst1 modemst2 fsg_b fsc; do
        dev="/dev/disk/by-partlabel/$part"
        blockdev --setro "$dev"
        if [ "$(blockdev --getro "$dev")" != 1 ]; then
          echo "Unable to protect $part; refusing modem startup" >&2
          exit 1
        fi
      done

      ln -sfn /dev/disk/by-partlabel/modemst1 ${nvDir}/modemst1
      ln -sfn /dev/disk/by-partlabel/modemst2 ${nvDir}/modemst2
      ln -sfn /dev/disk/by-partlabel/fsg_b ${nvDir}/fsg
      ln -sfn /dev/disk/by-partlabel/fsc ${nvDir}/fsc
    '';
  };
in
{
  config = {
    hardware.firmware = [ firmware ];
    # Qualcomm userspace servers require uncompressed .jsn and firmware blobs.
    hardware.firmwareCompression = "none";
    environment.etc."wifi/WCNSS_qcom_cfg.ini".source = "${firmware}/etc/wifi/WCNSS_qcom_cfg.ini";
    networking.networkmanager.enable = true;
    networking.modemmanager.enable = false;
    networking.usePredictableInterfaceNames = false;
    environment.systemPackages = [
      pkgs.iw
      pkgs.qrtr
    ];

    systemd.services.capri-qrtr-ns = {
      description = "Qualcomm QRTR name service for Capri";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.qrtr}/bin/qrtr-ns -f 1";
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };
    systemd.services.capri-pd-mapper = {
      description = "Qualcomm protection-domain service mapper";
      wantedBy = [ "multi-user.target" ];
      requires = [ "capri-qrtr-ns.service" ];
      after = [ "capri-qrtr-ns.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${wifi.pdMapper}/bin/pd-mapper";
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };
    systemd.services.capri-tqftpserv = {
      description = "Qualcomm firmware file server with tested Capri fallback";
      wantedBy = [ "multi-user.target" ];
      requires = [ "capri-qrtr-ns.service" ];
      after = [ "capri-qrtr-ns.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${wifi.tqftpserv}/bin/tqftpserv";
        Restart = "on-failure";
        RestartSec = "2s";
        StateDirectory = "tqftpserv";
        StateDirectoryMode = "0700";
      };
    };
    # Wi-Fi uses the modem remote processor but does not require a cellular
    # data connection, ModemManager, or a SIM card.
    systemd.services.capri-modem-start = {
      description = "Start Capri Qualcomm modem remoteproc for WLAN";
      wantedBy = [ "multi-user.target" ];
      requires = [
        "capri-rmtfs.service"
        "capri-pd-mapper.service"
        "capri-tqftpserv.service"
      ];
      after = [
        "capri-rmtfs.service"
        "capri-pd-mapper.service"
        "capri-tqftpserv.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${startModem}/bin/capri-start-wifi-modem";
      };
    };
    systemd.services.capri-wifi-driver = {
      description = "Load Capri WCN3990 WLAN driver after modem startup";
      wantedBy = [ "multi-user.target" ];
      requires = [ "capri-modem-start.service" ];
      after = [ "capri-modem-start.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.kmod}/bin/modprobe ath10k_snoc";
      };
    };
    # RMTFS -r reads raw NV with O_RDONLY and shadows requested writes in
    # daemon RAM. It never opens the partitions read-write.
    systemd.services.capri-modem-nv-readonly = {
      description = "Protect Motorola modem NV partitions from writes";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      wants = [ "systemd-udev-settle.service" ];
      before = [ "capri-rmtfs.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${prepare}/bin/capri-prepare-readonly-modem-nv";
      };
    };
    systemd.services.capri-rmtfs = {
      description = "Capri RMTFS using read-only raw NV partitions";
      wantedBy = [ "multi-user.target" ];
      requires = [
        "capri-modem-nv-readonly.service"
        "capri-qrtr-ns.service"
      ];
      after = [
        "capri-modem-nv-readonly.service"
        "capri-qrtr-ns.service"
      ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.rmtfs}/bin/rmtfs -P -r -o ${nvDir}";
        Restart = "on-failure";
        RestartSec = "3s";
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };
  };
}
