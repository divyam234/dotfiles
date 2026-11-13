{ pkgs, ... }:
{
  # Keep NetworkManager on Wi-Fi; the USB gadget's address is set below.
  networking.networkmanager.unmanaged = [ "interface-name:usb*" ];

  # Replicate the tested RAMUI ECM gadget on the real NixOS root filesystem.
  # The normal SSH daemon stays key-only on 2222; an independent SSH daemon
  # permits unauthenticated logins on the USB-only port 2223.
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
        # Name the link predictably so firewall rules can restrict by input interface.
        printf '%s\n' usb0 > "$gadget/functions/ecm.usb0/ifname"
        mkdir -p "$gadget/configs/c.1/strings/0x409"
        printf '%s\n' 'USB ECM SSH' > "$gadget/configs/c.1/strings/0x409/configuration"
        if [ ! -L "$gadget/configs/c.1/ecm.usb0" ]; then
          ln -s "$gadget/functions/ecm.usb0" "$gadget/configs/c.1/ecm.usb0"
        fi
      fi

      # The USB function determines its actual interface name.
      # ConfigFS attributes can be readable even when they report zero size.
      iface=""
      IFS= read -r iface < "$gadget/functions/ecm.usb0/ifname" || true
      if [ -z "$iface" ]; then
        echo "Capri USB ECM interface name is empty" >&2
        exit 1
      fi
      if [ "$iface" != usb0 ]; then
        echo "Expected usb0 for interface-specific SSH firewall, got $iface" >&2
        exit 1
      fi
      ip address replace 172.16.42.1/24 dev "$iface"
      ip link set dev "$iface" up

      if [ -z "$bound_udc" ]; then
        printf '%s\n' "$udc" > "$gadget/UDC"
      fi
      echo "Capri USB ECM: $iface at 172.16.42.1/24; SSH 2222 (keys), SSH 2223 (no auth)"
    '';
    preStop = ''
      gadget=/sys/kernel/config/usb_gadget/capri_ecm
      if [ -e "$gadget/UDC" ]; then
        printf '%s\n' "" > "$gadget/UDC"
      fi
    '';
  };
}
