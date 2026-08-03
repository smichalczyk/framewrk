---
layout: doc
title: Installing Framewrk
description: Step-by-step Framewrk install guides for Linux, macOS, Windows, Synology, QNAP, Unraid and TrueNAS SCALE.
---

One container, one folder for its database, port 8770. Everything else is set up
in the console after it starts — there is nothing to configure first.

Pick your platform. Each section ends with the thing that actually catches
people out there.

- [Linux](#linux)
- [macOS](#macos)
- [Windows](#windows)
- [Synology](#synology)
- [QNAP](#qnap)
- [Unraid](#unraid)
- [TrueNAS SCALE](#truenas-scale)

**Before you start**, you need a PhotoPrism instance Framewrk can reach, and an
Aura and/or Nixplay account with at least one frame on it.

**After it starts**, on every platform: open `http://<host>:8770`, find the
one-time admin password in the container log, sign in, and choose your own
password when asked.

---

## Linux

```bash
mkdir framewrk && cd framewrk
curl -O https://raw.githubusercontent.com/smichalczyk/framewrk/main/compose.yaml
```

Set `PUID` and `PGID` in `compose.yaml` to your own user, and `TZ` to your
timezone:

```bash
id -u    # -> PUID
id -g    # -> PGID
```

Then:

```bash
docker compose up -d
docker compose logs | grep -A2 "Admin password"
```

**Reaching PhotoPrism.** If PhotoPrism is a container on the same host, put both
on one network and address it by name (`http://photoprism:2342`) rather than a
LAN address that can change. Uncomment the `networks` block at the bottom of
`compose.yaml`. If Framewrk still cannot see it, `network_mode: host` usually
settles it — Linux only, and it ignores `ports`, so the console lands on the
host's 8770 directly.

**The catch:** leave `PUID`/`PGID` unset and everything in `data/` ends up owned
by root. It works, right up until the day you want to read your own backup.

---

## macOS

Needs [Docker Desktop](https://www.docker.com/products/docker-desktop/) or
Colima.

```bash
mkdir framewrk && cd framewrk
curl -O https://raw.githubusercontent.com/smichalczyk/framewrk/main/compose.yaml
```

**Delete the `PUID` and `PGID` lines.** Docker Desktop's VM maps ownership for
you, and setting them here causes the mismatch it is meant to prevent. Set `TZ`.

```bash
docker compose up -d
docker compose logs | grep -A2 "Admin password"
```

**The catch:** a Mac that sleeps stops syncing. Framewrk catches up on the next
run rather than losing anything, but if the frames matter, run it somewhere that
stays awake.

---

## Windows

Needs [Docker Desktop](https://www.docker.com/products/docker-desktop/) with the
WSL 2 backend.

In PowerShell:

```powershell
mkdir framewrk; cd framewrk
curl.exe -O https://raw.githubusercontent.com/smichalczyk/framewrk/main/compose.yaml
```

Delete the `PUID` and `PGID` lines, set `TZ`, and **change the volume to a named
volume**:

```yaml
    volumes:
      - framewrk-data:/data

volumes:
  framewrk-data:
```

```powershell
docker compose up -d
docker compose logs | Select-String -Context 0,2 "Admin password"
```

**The catch, and it is a real one:** do not bind-mount a Windows path such as
`C:\Users\you\framewrk\data` into `/data`. SQLite's write-ahead log needs file
locking that does not work reliably across the Windows/WSL filesystem bridge,
and the failure does not look like a filesystem problem — it looks like a
corrupted database, three weeks later. A named volume lives inside the Linux VM
and has none of that. To get a backup out:

```powershell
docker exec framewrk sqlite3 /data/sync.db ".backup /data/backup.db"
docker cp framewrk:/data/backup.db .
```

---

## Synology

DSM 7.2 or newer, with **Container Manager** installed from Package Center.

### 1. Find your user's numbers

This is the step everyone skips, and it is why most Synology support threads
exist. Synology's first user account is **1026**, not 1000, and the primary
group `users` is **100**.

Enable SSH (Control Panel → Terminal & SNMP → Enable SSH service), then:

```bash
ssh you@your-nas
id
# uid=1026(you) gid=100(users) ...
```

Note both numbers and turn SSH back off if you had it off.

### 2. Make the folders

In **File Station**, inside the `docker` shared folder (Container Manager
creates it), make `framewrk`, and inside that, `data`.

### 3. Create the project

**Container Manager → Project → Create.**

- **Project name:** `framewrk`
- **Path:** browse to `/docker/framewrk`
- **Source:** *Create docker-compose.yml*

Paste this, with your two numbers and your timezone:

```yaml
services:
  framewrk:
    image: ghcr.io/smichalczyk/framewrk:latest
    container_name: framewrk
    restart: unless-stopped
    ports:
      - "8770:8770"
    environment:
      - PUID=1026
      - PGID=100
      - TZ=Europe/London
    volumes:
      - /volume1/docker/framewrk/data:/data
```

**Next → Next → Done.** Container Manager pulls the image and starts it.

### 4. Sign in

**Container Manager → Container → framewrk → Log**, find the admin password,
then open `http://<nas-ip>:8770`.

**The catches:**

- Volume paths must be **absolute** (`/volume1/docker/...`). A relative `./data`
  works but DSM's own volume view renders it confusingly.
- Do not add a `version:` key. Container Manager uses Compose v2, where it is
  deprecated, and the warning reads like an error.
- "Cannot access the folder" means the `docker` shared folder's permissions, not
  the container. The folder has to exist before the project is created.
- If you are on a Value or J-series box it is arm64; Plus and XS are amd64.
  Both are published, so this does not change anything — but it is why you
  should not build the image yourself.

---

## QNAP

QTS or QuTS hero with **Container Station 3**.

### 1. Find your user's numbers

Do **not** use `admin` — it is uid 0. Use a normal share user. Over SSH:

```bash
id your-user
# uid=1000(your-user) gid=100(everyone) ...
```

### 2. Make the folders

In **File Station**, inside the `Container` share (Container Station creates
it), make `framewrk`, and inside that, `data`.

Check the real path in File Station's properties — it is usually
`/share/Container/...` but on some models `/share/CACHEDEV1_DATA/Container/...`.
Getting this wrong silently creates an empty directory, and the database starts
fresh on every boot.

### 3. Create the application

**Container Station → Applications → Create.** Name it `framewrk` and paste:

```yaml
services:
  framewrk:
    image: ghcr.io/smichalczyk/framewrk:latest
    container_name: framewrk
    restart: unless-stopped
    ports:
      - "8770:8770"
    environment:
      - PUID=1000
      - PGID=100
      - TZ=Europe/London
    volumes:
      - /share/Container/framewrk/data:/data
```

Click **Validate**, then **Create**.

### 4. Sign in

**Containers → framewrk → Logs** for the password, then
`http://<nas-ip>:8770`.

**The catches:**

- **Paste the YAML; do not type it in the browser.** Container Station's parser
  rejects tabs and inconsistent indentation outright, with an unhelpful message.
- **Port conflicts are the number one failure here.** QTS holds 8080 and 443,
  and Web Server or QuMagie may hold others. 8770 is not a QNAP default, but if
  the container will not start, check that before assuming the image is broken —
  and remap the host side (`"8771:8770"`) rather than moving QTS.
- If PhotoPrism is on another VLAN, Container Station's **qnet** driver gives
  Framewrk its own LAN address. Bridge is fine otherwise.

---

## Unraid

### From Community Applications

Search **Apps** for `Framewrk` and install. The template fills in the port, the
`/data` path, `PUID`, `PGID` and `TZ` for you — set your timezone and press
Apply.

### By hand

**Docker → Add Container**, then:

| Field | Value |
|---|---|
| Name | `framewrk` |
| Repository | `ghcr.io/smichalczyk/framewrk:latest` |
| Network Type | `bridge` |
| WebUI | `http://[IP]:[PORT:8770]` |
| Port | container `8770` → host `8770` |
| Path | container `/data` → host `/mnt/user/appdata/framewrk` |
| Variable | `PUID` = `99` |
| Variable | `PGID` = `100` |
| Variable | `TZ` = your timezone |

### Sign in

Click the container → **Logs** for the admin password, then the **WebUI** link.

**The catch:** `99`/`100` is Unraid's `nobody`/`users`, which is what the rest of
your appdata uses. Leaving them unset makes everything in the folder root-owned,
and Unraid's own backup plugins then cannot read it.

---

## TrueNAS SCALE

24.10 (Electric Eel) or newer, where the apps engine is plain Docker.

### 1. Make a dataset

**Storage → Datasets** → select your pool → **Add Dataset**, named `framewrk`.
Note the path it gives you, e.g. `/mnt/tank/apps/framewrk`.

Then **Datasets → framewrk → Permissions → Edit**: set Owner **apps** and Group
**apps** (both UID/GID **568**), and apply recursively.

### 2. Install

**Apps → Discover Apps** → the **⋮** menu at the top right → **Install via
YAML**.

- **Name:** `framewrk` — lowercase and alphanumeric only; the form rejects
  capitals and underscores.
- **Custom Config:**

```yaml
services:
  framewrk:
    image: ghcr.io/smichalczyk/framewrk:latest
    container_name: framewrk
    restart: unless-stopped
    ports:
      - "8770:8770"
    environment:
      - PUID=568
      - PGID=568
      - TZ=America/New_York
    volumes:
      - /mnt/tank/apps/framewrk:/data
```

**Save.**

### 3. Sign in

**Apps → Installed → framewrk → Logs** for the password, then
`http://<truenas-ip>:8770`.

**The catches:**

- **Do not add a `user:` key**, even though TrueNAS examples often suggest
  `user: "568:568"`. It bypasses the container's entrypoint, so `/data` never
  gets its ownership fixed and the database cannot be written. `PUID`/`PGID` do
  the same job correctly — the entrypoint handles them as root and then drops
  privileges.
- **Bind-mount the dataset; do not use a Docker named volume.** Named volumes
  live outside your datasets, so snapshots and replication do not cover them —
  which defeats the whole "back up one file" story.
- The YAML must begin with a top-level key (`services:`). The editor accepts
  anything and only fails at deploy.
- TrueNAS does not proxy the app, so port 8770 has to be free on the host.

---

## Something went wrong

- **The page will not load.** Check the container is running and healthy, and
  that nothing else holds port 8770. Remap the host side if it does.
- **No admin password in the log.** It is only printed on the *first* start with
  an empty database. If you have restarted since, and did not write it down,
  stop the container, delete `sync.db`, and start again — you lose the
  configuration, not the photos on your frames.
- **"Cannot reach PhotoPrism".** Press *Test connection* under **Source** for
  the actual reason. From another container, a LAN address often will not work
  where a container name will.
- **Timestamps are all wrong.** `TZ` is not set.

Still stuck? [Open a discussion](https://github.com/smichalczyk/framewrk/discussions)
with your platform, the version from **Settings → About**, and the relevant
lines from **Logs**.
