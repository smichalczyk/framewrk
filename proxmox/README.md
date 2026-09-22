# Framewrk for Proxmox

In the **Proxmox host → Shell**, paste:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/smichalczyk/framewrk/main/proxmox/create.sh)"
```

Choose **Default**, select storage and a network bridge if asked, then confirm.
The script downloads Debian, creates the LXC, installs Framewrk, and prints its
web address. There are no template filenames or command arguments to work out.

**Default:** Debian 12, unprivileged, 2 CPU cores, 1 GB RAM, 8 GB disk, DHCP,
automatic startup. **Advanced** lets you change the CTID, hostname, CPU, memory,
disk size, IP/gateway, VLAN and Framewrk version. Storage and bridge choices come
from your host. The script will never overwrite an existing VM or container.

Open the displayed address and get the initial app password with the command
shown at the end. Use `pct enter CTID` to open a root shell in the container.
For iOS, point your HTTPS reverse proxy to the container's port 8770.

## Status and requirements

Preview targeting **Proxmox VE 8.4.21**, amd64. Real Proxmox testing is still
pending. The installer runs Framewrk natively under systemd with its own service
user. Docker, nesting and privileged LXC are not needed. Debian's system Python
is unchanged; a separate Python 3.12 runtime is installed with pinned uv tooling.

The host needs internet access to GitHub and Proxmox template servers. The
container needs Debian mirrors, GHCR, PyPI and GitHub, plus your library/frame
services. Allow TCP 8770 from your LAN/reverse proxy. Ensure enough storage for
the template, the container disk and later backups. Large photo batches may need
more RAM than the default allocation.

This is Framewrk's own script, inspired by the default/advanced host-console flow
at [Community Scripts](https://community-scripts.org/). It is not a Community
Scripts listing and does not load their remote framework.

## Updates

Take a Proxmox backup. Inside the container, run:

```bash
framewrk-lxc 1.3.0  # replace with the published version you want
```

The updater prepares the new code, stops Framewrk, backs up all application data,
and starts the new version. A failed health check restores the previous code and
data automatically. Old releases and backups remain until you remove them.
For newer installer revisions, download the installer archive and checksum from
[GitHub Releases](https://github.com/smichalczyk/framewrk/releases), verify with
`sha256sum -c framewrk-proxmox.sha256`, extract it, and run its `framewrk-lxc`
script inside the container.

## Troubleshooting and recovery

The host log is `/var/log/framewrk-lxc-TIMESTAMP.log`. Application logs are
`journalctl -u framewrk` inside the container. A failed creation/install keeps
the container for inspection; the host script prints the retry command.

Data: `/var/lib/framewrk`. Code: `/opt/framewrk/releases`. Current release:
`/opt/framewrk/current`. Update backups: `/var/backups/framewrk/TIMESTAMP`.
Backups contain private photos/settings; keep them private and prune old ones.
Do not downgrade code alone over a migrated database. For manual rollback inside
the container, select the backup printed by the update:

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

## First tester checklist

- Run the one-line installer on Proxmox 8.4.21 with **Default** settings.
- Verify login, then reboot the CT and confirm automatic startup and saved settings.
- Connect a test frame/library and verify sync, orientation rules and iOS uploads.
- Reinstall the same version; check the backup and retained sync history.
- Test rollback and Proxmox backup restoration in isolation so a restored copy
  cannot send duplicate photos to live frames.
- Report Proxmox version, storage, network settings and redacted failures via
  [Discussions](https://github.com/smichalczyk/framewrk/discussions).
