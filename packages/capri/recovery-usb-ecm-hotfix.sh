#!/nix/store/xl3n26zm1kv1zhj3mma2x929f4sx3dlh-bash-5.3p20/bin/bash
# Temporary recovery override for Capri ECM. Permanent fix lives in usb-ecm.nix.
set -euo pipefail

if ! mountpoint -q /sys/kernel/config; then
  mount -t configfs -o nosuid,nodev,noexec configfs /sys/kernel/config
fi

udc=""
for candidate in /sys/class/udc/*; do
  [ -e "$candidate" ] || continue
  udc="${candidate##*/}"
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
  printf '%s\n' 0x18d1 > "$gadget/idVendor"
  printf '%s\n' 0xd001 > "$gadget/idProduct"
  mkdir -p "$gadget/strings/0x409"
  printf '%s\n' Motorola > "$gadget/strings/0x409/manufacturer"
  printf '%s\n' 'Capri NixOS USB networking' > "$gadget/strings/0x409/product"
  printf '%s\n' capri-nixos > "$gadget/strings/0x409/serialnumber"

  mkdir -p "$gadget/functions/ecm.usb0"
  # Kernel requires a pattern with exactly one %d, rather than literal usb0.
  if [ ! -L "$gadget/configs/c.1/ecm.usb0" ]; then
    printf '%s\n' 'usb%d' > "$gadget/functions/ecm.usb0/ifname"
  fi
  mkdir -p "$gadget/configs/c.1/strings/0x409"
  printf '%s\n' 'USB ECM SSH' > "$gadget/configs/c.1/strings/0x409/configuration"
  if [ ! -L "$gadget/configs/c.1/ecm.usb0" ]; then
    ln -s "$gadget/functions/ecm.usb0" "$gadget/configs/c.1/ecm.usb0"
  fi

  # The ECM network interface only exists once the gadget is bound.
  printf '%s\n' "$udc" > "$gadget/UDC"
fi

iface=""
IFS= read -r iface < "$gadget/functions/ecm.usb0/ifname" || true
case "$iface" in
  usb[0-9]*) ;;
  *)
    echo "Unexpected Capri ECM interface after binding: '$iface'" >&2
    exit 1
    ;;
esac

ip address replace 172.16.42.1/24 dev "$iface"
ip link set "$iface" up
echo "Capri USB ECM: $iface at 172.16.42.1/24, SSH port 2222 (key only)"
