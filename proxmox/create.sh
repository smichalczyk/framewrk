#!/usr/bin/env bash
# Run on the Proxmox host. All storage/network choices must be explicit.
set -Eeuo pipefail
if [[ $# != 5 || ! $1 =~ ^[0-9]+$ || ! $5 =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]]; then
 echo 'Usage: create.sh CTID TEMPLATE_VOLUME ROOTFS_STORAGE BRIDGE VERSION' >&2
 echo 'Example: create.sh 120 local:vztmpl/ubuntu-24.04-standard_....tar.zst local-lvm vmbr0 1.3.0' >&2
 exit 1
fi
[[ $EUID == 0 ]] || { echo 'Run on the Proxmox host as root.' >&2; exit 1; }
command -v pct >/dev/null
case "$2" in
 *ubuntu-24.04*) ostype=ubuntu ;;
 *debian-13*) ostype=debian ;;
 *) echo 'Select Ubuntu 24.04 (recommended for Proxmox 8.4) or Debian 13.' >&2; exit 1 ;;
esac
script=$(cd -- "$(dirname -- "$0")" && pwd)/framewrk-lxc
[[ -f $script ]]
if pct config "$1" >/dev/null 2>&1; then echo 'Container ID already exists; refusing to modify it.' >&2; exit 1; fi
pct create "$1" "$2" --hostname framewrk --unprivileged 1 --cores 2 --memory 1024 --swap 512 --rootfs "$3:8" --net0 "name=eth0,bridge=$4,ip=dhcp,type=veth,firewall=1" --onboot 1 --ostype "$ostype"
# On failure leave the container intact for inspection; never destroy user data.
pct start "$1"
for _ in {1..30}; do
 if pct exec "$1" -- getent hosts ghcr.io >/dev/null 2>&1; then break; fi
 sleep 2
done
pct push "$1" "$script" /root/framewrk-lxc --perms 0755
pct exec "$1" -- /root/framewrk-lxc "$5"
pct exec "$1" -- hostname -I
echo 'Open http://CONTAINER_IP:8770. Retrieve the password with: pct exec CTID -- journalctl -u framewrk'
