{ pkgs, ... }:
{
  # Keep NetworkManager on Wi-Fi; the USB gadget's address is set below.
  networking.networkmanager.unmanaged = [ "interface-name:usb*" ];

  # Replicate the tested RAMUI ECM gadget on the real NixOS root filesystem.
  # The normal key-authenticated SSH daemon serves USB and Wi-Fi on port 2222.
  systemd.services.capri-usb-ecm = {
    description = "Capri USB ECM networking for SSH";
    wantedBy = [ "multi-user.target" ];
    after = [
      "systemd-udev-trigger.service"
      "sys-kernel-config.mount"
    ];
    path = with pkgs; [
      coreutils
      iproute2
      util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "5s";
    };
    script = ''
      set -eu

      if ! mountpoint -q /sys/kernel/config; then
        mount -t configfs -o nosuid,nodev,noexec configfs /sys/kernel/config
      fi

      # A missing UDC is transient during boot: let systemd retry.
      udc=""
      for candidate in /sys/class/udc/*; do
        [ -e "$candidate" ] || continue
        udc="''${candidate##*/}"
        break
      done
      if [ -z "$udc" ]; then
        echo "Capri USB device controller not available yet" >&2
        exit 1
      fi

      gadget=/sys/kernel/config/usb_gadget/capri_ecm
      mkdir -p "$gadget"
      bound_udc=""
      if [ -r "$gadget/UDC" ]; then
        IFS= read -r bound_udc < "$gadget/UDC" || true
      fi
      if [ -z "$bound_udc" ]; then
        # Match the working RAMUI diagnostic gadget identifiers.
        printf '%s\n' 0x18d1 > "$gadget/idVendor"
        printf '%s\n' 0xd001 > "$gadget/idProduct"
        mkdir -p "$gadget/strings/0x409"
        printf '%s\n' Motorola > "$gadget/strings/0x409/manufacturer"
        printf '%s\n' 'Capri NixOS USB networking' > "$gadget/strings/0x409/product"
        printf '%s\n' capri-nixos > "$gadget/strings/0x409/serialnumber"

        mkdir -p "$gadget/functions/ecm.usb0"
        # The ECM ifname configfs attribute requires a pattern with exactly
        # one %d, not a literal interface name. The kernel resolves it on bind.
        printf '%s\n' 'usb%d' > "$gadget/functions/ecm.usb0/ifname"
        mkdir -p "$gadget/configs/c.1/strings/0x409"
        printf '%s\n' 'USB ECM SSH' > "$gadget/configs/c.1/strings/0x409/configuration"
        if [ ! -L "$gadget/configs/c.1/ecm.usb0" ]; then
          ln -s "$gadget/functions/ecm.usb0" "$gadget/configs/c.1/ecm.usb0"
        fi
      fi

      # The ECM netdev is registered when the gadget binds to its UDC.
      # Configure IP only after binding, when usb%d has become usb0 (or usbN).
      if [ -z "$bound_udc" ]; then
        printf '%s\n' "$udc" > "$gadget/UDC"
      fi

      # DWC3 can remain halted after gadget rebinding. Reinitialize only the
      # data controller; leave the Type-C power role and charging untouched.
      role=/sys/class/usb_role/"$udc"-role-switch/role
      if [ -r "$role" ]; then
        IFS= read -r data_role < "$role"
        IFS= read -r state < "/sys/class/udc/$udc/state"
        if [ "$data_role" = device ] && [ "$state" != configured ]; then
          printf '%s\n' none > "$role"
          printf '%s\n' device > "$role"
        fi
      fi

      iface=""
      IFS= read -r iface < "$gadget/functions/ecm.usb0/ifname" || true
      case "$iface" in
        usb[0-9]*) ;;
        *)
          echo "Invalid or unavailable Capri USB ECM interface: $iface" >&2
          exit 1
          ;;
      esac
      ip address replace 172.16.42.1/24 dev "$iface"
      ip link set dev "$iface" up
      echo "Capri USB ECM: $iface at 172.16.42.1/24; SSH 2222 (keys)"
    '';
    preStop = ''
      gadget=/sys/kernel/config/usb_gadget/capri_ecm
      if [ -e "$gadget/UDC" ]; then
        printf '%s\n' "" > "$gadget/UDC"
      fi
    '';
  };
}
