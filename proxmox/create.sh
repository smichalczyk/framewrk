#!/usr/bin/env bash
# Framewrk's standalone host-console wizard. Inspired by community-scripts.org's
# default/advanced workflow; not affiliated with or dependent on their framework.
set -Eeuo pipefail
APP_VERSION=1.3.0
INSTALLER_SHA256=9b4c3054fb088374591b74ff13228fb734dcb04151e7624ba3a98f4d5e9bf95b
INSTALLER_URL=https://raw.githubusercontent.com/smichalczyk/framewrk/main/proxmox/framewrk-lxc
created=false
work=
log=
ctid=
fail() { printf '\nError: %s\n' "$*" >&2; exit 1; }
cleanup() {
 local status=$?
 [[ -z $work ]] || rm -rf "$work"
 if (( status != 0 )); then
   [[ -z $log ]] || printf '\nInstallation log: %s\n' "$log" >&2
   if [[ $created == true ]]; then
     printf 'Container %s was kept for inspection. Enter it with: pct enter %s\nRetry setup inside it with: bash /root/framewrk-lxc %s\n' "$ctid" "$ctid" "$version" >&2
   fi
 fi
}
trap cleanup EXIT
trap 'printf "\nFailed at line %s (exit %s).\n" "$LINENO" "$?" >&2' ERR
[[ $EUID == 0 ]] || fail 'Run this in the Proxmox host Shell as root.'
for tool in pct pveversion pveam pvesm pvesh whiptail curl python3 ip sha256sum; do
 command -v "$tool" >/dev/null || fail "Required host command is missing: $tool"
done
[[ $(uname -m) == x86_64 ]] || fail 'This preview targets amd64 Proxmox hosts.'
pve=$(pveversion | cut -d/ -f2 | cut -d- -f1)
dpkg --compare-versions "$pve" ge 8.4 || fail 'Proxmox VE 8.4 or later is required.'
# Read interaction from the console even when the script itself was fetched by curl.
exec 3<>/dev/tty
export NEWT_COLORS='root=,blue'
ui() { whiptail --backtitle 'Framewrk • Debian LXC installer' "$@" <&3 3>&1 1>&2 2>&3; }
choose() {
 local title=$1 content=$2 default=$3
 local -a options=()
 local name
 while read -r name; do [[ -z $name ]] || options+=("$name" "$content storage"); done < <(pvesm status --content "$content" | awk 'NR>1 && $3=="active" {print $1}')
 ((${#options[@]})) || fail "No active $content storage is available on this node."
 if ((${#options[@]} == 2)); then printf '%s' "${options[0]}"; else
   ui --title "$title" --default-item "$default" --menu "Choose storage for $title" 18 70 8 "${options[@]}"
 fi
}
input() { ui --title "$1" --inputbox "$2" 10 72 "$3"; }
number() { [[ $1 =~ ^[0-9]+$ ]] && (( 10#$1 >= $2 && 10#$1 <= $3 )); }
printf '\nFramewrk — Debian 12 LXC\n'
mode=$(ui --title 'Create Framewrk' --menu 'Creates a new unprivileged Debian container and installs Framewrk. Preview: awaiting real Proxmox testing.' 14 78 3 default 'Default: 2 cores / 1 GB RAM / 8 GB disk / DHCP' advanced 'Customize resources and networking' cancel 'Exit') || exit 0
[[ $mode != cancel ]] || exit 0
ctid=$(pvesh get /cluster/nextid)
hostname=framewrk
cores=2
memory=1024
disk=8
version=$APP_VERSION
network=dhcp
gateway=
vlan=
root_storage=$(choose 'Container disk' rootdir local-lvm) || exit 1
template_storage=$(choose 'Debian template' vztmpl local) || exit 1
bridges=()
while read -r bridge_name; do bridges+=("$bridge_name" 'Network bridge'); done < <(ip -o link show type bridge | awk -F': ' '{print $2}' | cut -d@ -f1)
((${#bridges[@]})) || fail 'No Linux network bridge was found on this host.'
if ((${#bridges[@]} == 2)); then bridge=${bridges[0]}; else
 bridge=$(ui --title Network --default-item vmbr0 --menu 'Choose the container network bridge' 16 70 8 "${bridges[@]}") || exit 0
fi
if [[ $mode == advanced ]]; then
 ctid=$(input 'Container ID' 'Choose an unused CTID' "$ctid") || exit 0
 hostname=$(input Hostname 'Container hostname' "$hostname") || exit 0
 cores=$(input CPU 'CPU cores (1–64)' "$cores") || exit 0
 memory=$(input Memory 'Memory in MB (512–65536)' "$memory") || exit 0
 disk=$(input Disk 'Container disk in GB (8–1024)' "$disk") || exit 0
 network=$(input 'IPv4 address' 'Enter dhcp, or a static address with prefix (for example 192.168.1.50/24)' "$network") || exit 0
 if [[ $network != dhcp ]]; then gateway=$(input Gateway 'IPv4 gateway (for example 192.168.1.1)' '') || exit 0; fi
 vlan=$(input VLAN 'Optional VLAN tag (leave blank for an untagged network)' '') || exit 0
 version=$(input 'Framewrk version' 'Published Framewrk version to install' "$version") || exit 0
fi
number "$ctid" 100 999999999 || fail 'Invalid CTID.'
number "$cores" 1 64 || fail 'Invalid CPU count.'
number "$memory" 512 65536 || fail 'Invalid memory allocation.'
number "$disk" 8 1024 || fail 'Invalid disk size.'
[[ $hostname =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{0,62}$ ]] || fail 'Invalid hostname.'
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]] || fail 'Use an explicit published version such as 1.3.0.'
[[ -z $vlan ]] || number "$vlan" 1 4094 || fail 'Invalid VLAN tag.'
if [[ $network != dhcp ]]; then
 python3 - "$network" "$gateway" <<'PY'
import ipaddress,sys
assert '/' in sys.argv[1], 'Static IP requires a prefix'
interface=ipaddress.IPv4Interface(sys.argv[1])
gateway=ipaddress.IPv4Address(sys.argv[2])
assert gateway in interface.network, 'Gateway must be in the configured subnet'
PY
fi
# Checks both VM and CT IDs cluster-wide, without changing existing guests.
pvesh get /cluster/nextid --vmid "$ctid" >/dev/null || fail "ID $ctid is already in use."
summary="Debian 12 · unprivileged\nCTID: $ctid   Hostname: $hostname\nCPU: $cores   RAM: $memory MB   Disk: $disk GB\nDisk storage: $root_storage   Templates: $template_storage\nBridge: $bridge   IPv4: $network   VLAN: ${vlan:-none}\nFramewrk: $version\n\nCreate this container and install Framewrk?"
ui --title 'Confirm installation' --yesno "$summary" 18 78 || exit 0
work=$(mktemp -d)
log=/var/log/framewrk-lxc-$(date -u +%Y%m%dT%H%M%S)-$$.log
umask 077
touch "$log"
exec > >(tee -a "$log") 2>&1
printf '\n[1/5] Downloading and verifying the Framewrk installer…\n'
curl --fail --location --retry 3 "$INSTALLER_URL" -o "$work/framewrk-lxc"
printf '%s  %s\n' "$INSTALLER_SHA256" "$work/framewrk-lxc" | sha256sum --check --status
printf '\n[2/5] Finding and downloading Debian 12…\n'
pveam update
template=$(pveam available --section system | awk '$2 ~ /^debian-12-standard_.*_amd64\.tar\.(zst|gz|xz)$/ {print $2}' | sort -V | tail -1)
[[ -n $template ]] || fail 'No official Debian 12 amd64 template is available in the Proxmox catalog.'
volume="$template_storage:vztmpl/$template"
if ! pveam list "$template_storage" | awk '{print $1}' | grep -Fx "$volume" >/dev/null; then pveam download "$template_storage" "$template"; fi
printf '\n[3/5] Creating container %s…\n' "$ctid"
net="name=eth0,bridge=$bridge,ip=$network,type=veth,firewall=1"
[[ -z $gateway ]] || net+=",gw=$gateway"
[[ -z $vlan ]] || net+=",tag=$vlan"
pct create "$ctid" "$volume" --hostname "$hostname" --unprivileged 1 --cores "$cores" --memory "$memory" --swap 512 --rootfs "$root_storage:$disk" --net0 "$net" --onboot 1 --ostype debian --tags framewrk --description "Framewrk $version | http://IP:8770 | https://hangframewrk.io"
created=true
pct start "$ctid"
pct push "$ctid" "$work/framewrk-lxc" /root/framewrk-lxc --perms 0755
printf '\n[4/5] Waiting for container networking…\n'
ready=false
for _ in {1..60}; do
 if pct exec "$ctid" -- getent hosts ghcr.io >/dev/null 2>&1; then ready=true; break; fi
 sleep 2
done
[[ $ready == true ]] || fail 'Container DNS/network did not become ready. Check bridge, DHCP/static IP and firewall.'
printf '\n[5/5] Installing Framewrk (this can take several minutes)…\n'
pct exec "$ctid" -- bash /root/framewrk-lxc "$version"
address=$(pct exec "$ctid" -- hostname -I | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\./) {print $i; exit}}')
printf '\nFramewrk is ready: http://%s:8770\nContainer: %s\nOpen its console: pct enter %s\nShow the initial app password: pct exec %s -- journalctl -u framewrk\nLog: %s\n' "${address:-CONTAINER_IP}" "$ctid" "$ctid" "$ctid" "$log"
ui --title 'Framewrk is ready' --msgbox "Open http://${address:-CONTAINER_IP}:8770\n\nContainer: $ctid\nGet your initial password:\npct exec $ctid -- journalctl -u framewrk\n\nUse your HTTPS reverse proxy for iOS access." 16 78 || true
