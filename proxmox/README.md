# Framewrk on Proxmox LXC (preview)

This installer is available for friend testing. It has not yet been validated on
an actual Proxmox host. Use a new container and report results before relying on
it for production. No Docker daemon, privileged container, nesting, host bind
mount, or disabled AppArmor profile is required.

Target for the first external test: **Proxmox VE 8.4.21 with Ubuntu 24.04 LTS**.

## Requirements

- A Proxmox host supporting the official Ubuntu 24.04 amd64 template.
- An unused container ID, container storage with at least 8 GB free, and a network
  bridge with DHCP. Defaults: 2 CPU cores, 1 GB RAM, 512 MB swap; increase memory
  for large images or concurrent uploads. These are starting allocations, not
  measured minimums.
- Internet access to Ubuntu/Debian, GHCR and PyPI, plus access to your photo libraries
  and frame services. Allow incoming TCP 8770 from your LAN/reverse proxy.
- Root shell on the Proxmox host. The application runs as the `framewrk` user
  inside an unprivileged container. Python 3.12 comes from Ubuntu 24.04. Debian 13 is also accepted on hosts supporting that template.

The scripts contain no application source. Installation extracts the application
and built console from the existing public versioned GHCR image using skopeo and
umoci, then installs its Python dependencies at the image's recorded versions.
Image layers are verified by the registry tooling; release checksums below verify
the packaging download. The application remains subject to its existing license.

## Install

Download `framewrk-proxmox.tar.gz` and `framewrk-proxmox.sha256` from the
[Framewrk 1.3.0 release](https://github.com/smichalczyk/framewrk/releases/tag/v1.3.0)
to a new directory on your Proxmox host:

```bash
curl -fLO https://github.com/smichalczyk/framewrk/releases/download/v1.3.0/framewrk-proxmox.tar.gz
curl -fLO https://github.com/smichalczyk/framewrk/releases/download/v1.3.0/framewrk-proxmox.sha256
sha256sum -c framewrk-proxmox.sha256
tar -xzf framewrk-proxmox.tar.gz
```

Read the included scripts before executing them. In Proxmox, download the official
Ubuntu 24.04 template under your storage's **CT Templates** tab. `pveam list local`
shows template volume IDs. Replace all placeholders below with your actual choices:

```bash
bash proxmox/create.sh CTID TEMPLATE_VOLUME ROOTFS_STORAGE BRIDGE 1.3.0
# Example shape (use your actual template filename):
# bash proxmox/create.sh 120 local:vztmpl/ubuntu-24.04-standard_VERSION_amd64.tar.zst local-lvm vmbr0 1.3.0
```

The script refuses an existing CTID. On failure it leaves the new container in
place for inspection. After correcting networking/package issues, retry installation
inside it using `/root/framewrk-lxc 1.3.0`; do not rerun container creation.

For an existing **dedicated Ubuntu 24.04 container**, copy `proxmox/framewrk-lxc`
inside and run `bash framewrk-lxc 1.3.0` as root. Do not run it on the Proxmox host
itself or in a container used by another application.

Open `http://CONTAINER_IP:8770`. Get the generated password:

```bash
pct exec CTID -- journalctl -u framewrk
```

For iOS access, configure your reverse proxy with HTTPS pointing to this address.
Use the same proxy settings described in the main Framewrk installation guide.
Do not expose port 8770 directly to the internet.

## Update and rollback

Take a Proxmox backup first. Download the installer archive from the new release
when it includes packaging changes; its `framewrk-lxc` script can be run directly
to update both the application and installed updater. Otherwise, inside the
container select an explicit release:

```bash
framewrk-lxc 1.3.0  # replace with the desired published version
```

The updater prepares a new release before stopping Framewrk. It then stops the
service and copies **all** `/var/lib/framewrk` data, including SQLite WAL files
and uploads, to `/var/backups/framewrk/TIMESTAMP`. It changes the current symlink,
starts the service, and checks `/api/health` for up to 60 seconds. A failed health
check restores the prior data and code automatically. Review logs after any error;
power loss or an interrupted installer may require the manual recovery below.

For manual rollback, stop the service first. Use the printed backup directory;
`previous-release` contains the matching old application directory. Do not simply
install an older version over a migrated database.

```bash
systemctl stop framewrk
backup=/var/backups/framewrk/REPLACE_WITH_TIMESTAMP
previous=$(cat "$backup/previous-release")
test -d "$previous" || exit 1
mv /var/lib/framewrk /var/lib/framewrk.failed-$(date +%s)
cp -a "$backup/data" /var/lib/framewrk
ln -sfn "$previous" /opt/framewrk/current
cp -a "$backup/service" /etc/systemd/system/framewrk.service
systemctl daemon-reload
systemctl start framewrk
curl -f http://127.0.0.1:8770/api/health
```

Code is under `/opt/framewrk/releases`; `current` selects the active release.
Backups and old releases are retained deliberately. After confirming an upgrade,
remove older backups/releases you no longer need, keeping the active release and
at least the previous matching code/data pair. Backups contain credentials and
photos: keep them private. Normal application upload cleanup still applies, but
backup copies remain until you remove them. Include the container disk in Proxmox
backups. Uninstall by removing this dedicated CT through Proxmox after saving data.

## Friend testing checklist

1. Record Proxmox version, Ubuntu template, storage type and networking.
2. Install in a fresh unprivileged container without nesting. Confirm the console
   loads and `systemctl status framewrk` reports active; verify the process user.
3. Reboot the CT and verify automatic startup and persisted login/settings.
4. Connect a test frame and library; verify a scheduled sync and orientation rules.
5. Send photos through iOS over HTTPS; verify receipt, processing and cleanup.
6. Reinstall the same version; verify backup creation and unchanged settings,
   frames and sync history. Test manual rollback with the matching backup.
7. Restore a Proxmox backup into an isolated network before testing it, so the
   restored instance cannot send duplicate photos to live frames.
8. Report failures via GitHub Discussions with redacted logs. Never include
   passwords, device tokens, frame account details or photo contents.

Host/LXC integration, shutdown behavior, network access and resource sizing remain
unverified until this checklist has been completed on Proxmox.
