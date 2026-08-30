<p align="center">
  <img src="icon.png" width="96" alt="">
</p>

<h1 align="center">Framewrk</h1>

<p align="center">
  Keeps your digital photo frames filled from your own PhotoPrism and/or Immich library.<br>
  <a href="https://smichalczyk.github.io/framewrk/">Website</a> ·
  <a href="docs/install.md">Install guides</a> ·
  <a href="https://github.com/smichalczyk/framewrk/discussions">Discussions</a>
</p>

---

Framewrk watches PhotoPrism and Immich, picks the photos that match your rules,
and pushes them to Aura and Nixplay frames at the right size and shape for each one. It
remembers what it has already sent, so nothing is uploaded twice, and it takes
photos back off a frame when they no longer qualify.

It runs as one small container with a web console for setup, monitoring and
logs. Free to use.

---

## Getting started

Nothing to configure before it starts. There is no config file to write and no
environment to set — one container, one folder, then everything else happens in
the console.

```bash
mkdir framewrk && cd framewrk
curl -O https://raw.githubusercontent.com/smichalczyk/framewrk/main/compose.yaml
docker compose up -d
```

Open `http://<host>:8770`.

On first start Framewrk prints an admin password to the container log:

```bash
docker compose logs | grep -A2 "Admin password"
```

Sign in with it and you are asked to choose your own. Set
`FRAMEWRK_ADMIN_PASSWORD` beforehand if you would rather pick it yourself —
either way the first sign-in requires a change.

Then, in the console:

1. **Source** — connect PhotoPrism, Immich, or both, then press *Test
   connection*. For Immich, create an API key with asset read/download and
   album read access. Add your Aura and/or Nixplay account the same way.
2. **Frames** — press *Add*. Framewrk lists the frames actually on your
   account; pick one, choose an image size that matches its screen, and choose
   whether it should get landscape photos, portrait, or anything. Each frame can
   also draw from its own slice of the library instead of the household rule.
3. **The wall** — press *Sync now*, or wait for the schedule.

### Photo sources

Use PhotoPrism, Immich, or both. Immich **3.1 or newer** is required; create
an API key with asset read/download and album read access.

The shared **Quality** setting uses Immich's optional star rating. `0` disables
the rating filter; `1` through `5` select that rating and above. Enable ratings
in Immich at **User Settings → Features → Rating** before assigning stars.

### Where you are running it

Step-by-step guides, each with the one thing that catches people out on that
platform:

| | |
|---|---|
| [Linux](docs/install.md#linux) | [macOS](docs/install.md#macos) · [Windows](docs/install.md#windows) |
| [Synology](docs/install.md#synology) | [QNAP](docs/install.md#qnap) |
| [Unraid](docs/install.md#unraid) | [TrueNAS SCALE](docs/install.md#truenas-scale) |

Images are published for `linux/amd64` and `linux/arm64`, on
[GHCR](https://github.com/users/smichalczyk/packages/container/package/framewrk) and
[Docker Hub](https://hub.docker.com/r/smichalczyk/framewrk).

### Updating

```bash
docker compose pull && docker compose up -d
```

Migrations run on boot. **Back up `sync.db` first** if you are crossing a
version that mentions one — and use `sqlite3 sync.db ".backup out.db"` rather
than `cp`, which silently misses anything still in the write-ahead log.

The whole of Framewrk's state is that one file. Copy it and you have copied the
installation.

---

## The console

| Screen | What it is for |
|---|---|
| **The wall** | Every frame with the photo currently on it, a 30-day activity chart, and recent runs. Sync now and stop live here. |
| **Frames** | One card per screen on your walls. Add, pause, configure and remove them across both services. |
| **Source** | PhotoPrism and Immich connections, which photos qualify, how often to check, and your frame accounts. |
| **Logs** | Everything Framewrk has done, kept across restarts. Filter by level, search, follow live, download. |
| **Settings** | Password, sign-in cookie and proxy behaviour, how long to keep logs, and which version you are running. |

### Nixplay works differently, and the console shows that

For Aura, a frame is a frame: Framewrk uploads straight to it.

Nixplay puts an **album** in between. You upload into an album, and an album is
played by zero or more frames. Framewrk still shows you frames, and says which
album feeds each one:

```
Hallway Frame
1280px · Landscape only · 645 photos · synced 11 hours ago
Photos land in  PhotoPrism Sync    also playing on Landing Frame
```

From there you can **Change** which album a frame's photos land in, and see
**what else this frame plays**. An album shown on two frames appears under both,
because both screens exist. An album on no frame gets its own section, since
nothing you sync into it will reach a screen.

Nixplay's self-filling albums — Favourites, and the one fed by your frame's
email address — are not listed. They are not places a library can be synced
into.

The Frames screen lists frames you have added, and nothing else. Everything on
your accounts is offered under *Add*, where you can also **Hide** one you never
want to see again — someone else's frame, or one in a room you do not sync.
*Check accounts* asks both vendors what is on them now; that never happens on
page load, because logging in again can invalidate the token a running sync is
using.

### Names come from Aura and Nixplay

You cannot rename a frame in Framewrk. Renaming it in the Aura or Nixplay app is
picked up on the next sync. A name typed here would be a name the vendor has
never heard of, and the next run would overwrite it anyway.

### Removing a frame

You are asked what should happen to the photos already on it:

- **Stop syncing, leave the photos** — they stay where they are, and the record
  of what was sent is kept. Add the frame back later and Framewrk resumes
  instead of re-uploading everything.
- **Stop syncing and delete the photos** — Aura removes every photo Framewrk put
  there. Nixplay has no per-photo delete, so the equivalent is deleting the
  album, which takes every photo in it on every frame playing it. Either way you
  type the name first.

---

## Configuration

Configuration lives in the database (`/data/sync.db`) and is edited in the
console. These are the only settings read from the environment:

| Variable | Default | What it does |
|---|---|---|
| `PUID` / `PGID` | unset | Own the data folder as this user instead of root |
| `TZ` | `UTC` | Otherwise every timestamp is UTC |
| `DB_PATH` | `/data/sync.db` | Database location |
| `FRAMEWRK_PORT` | `8770` | Console port |
| `FRAMEWRK_BIND` | `0.0.0.0` | Interface to listen on. `127.0.0.1` if only a local tunnel should reach it |
| `FRAMEWRK_ADMIN_PASSWORD` | — | Sets the first-run password instead of generating one |
| `FRAMEWRK_TRUST_PROXY` | off | Believe `X-Forwarded-*`. Turn on **only** behind a reverse proxy |

### Running behind a reverse proxy

Point the proxy at `http://<host>:8770` and turn on the reverse-proxy option in
**Settings → Access**. Leave it off otherwise: on a plain network, trusting
those headers would let anyone claim any address and slip past the sign-in
limit.

That setting governs two layers at once, and both matter:

- Flask gets `ProxyFix`, so `X-Forwarded-For` and `X-Forwarded-Proto` are
  believed — the sign-in limit counts per real client, and the session cookie
  is marked `Secure` on HTTPS.
- Waitress stops clearing `X-Forwarded-*`. With it clearing them, ProxyFix
  sees nothing, every request looks like it came from the proxy, and the
  sign-in limit locks out everyone at once instead of one attacker.

`ProxyFix` is configured for **exactly one** proxy hop. One nginx in front is
right. Add a second hop that appends to `X-Forwarded-For` — Cloudflare's proxy,
for instance — and Framewrk would read the CDN as the client.

A worked example, with Nginx Proxy Manager:

| Setting | Value |
|---|---|
| Domain | `framewrk.example.com` |
| Scheme / host / port | `http` · the Docker host · `8770` |
| Block common exploits | on |
| Cache assets | **off** — Framewrk sets its own headers, and caching on top serves a stale app after an update |
| Websockets | off (the console polls) |
| SSL | request a certificate, Force SSL on |

Nothing is needed in the Advanced tab: NPM's default already sends `Host`,
`X-Forwarded-For` and `X-Forwarded-Proto`.

DNS must resolve publicly **before** requesting a certificate. Let's Encrypt
allows only 5 failed validations per hostname per hour, and an NXDOMAIN burns
one each time — Nginx Proxy Manager reports every certbot failure as the same
opaque "Internal Error", so check the real reason with:

```bash
docker exec <npm-container> sh -c 'tail -40 /tmp/letsencrypt-log/letsencrypt.log'
```

Do not write into the proxy's ACME webroot by hand to test it. Certbot runs as
the proxy's own user (`PUID`/`PGID`), and a directory left behind by root makes
every future request fail with `PermissionError` — which looks identical from
the outside.

---

## How it works

```
PhotoPrism / Immich ──▶ scheduler ──▶ worker ──▶ Aura / Nixplay
                            │            │
                            └── SQLite ──┘   settings · frames · what was sent · runs · logs
```

One process, a few threads: a scheduler that decides when to run, a single
worker so two syncs can never overlap, a log writer that batches to SQLite, and
the web server. State is one SQLite file in `/data`.

Photos are matched on their source-specific ID, and destinations are tracked by
the vendor's own ID, so renaming a frame or an album in the Aura or Nixplay app
is safe — Framewrk just adopts the new name.

---

## Notes

- Uploads are deliberately paced (a short pause per photo) so a large first sync
  does not overwhelm the photo source. Set a batch size under **Source** to spread it
  further.
- Service passwords are stored in the database in plain text, and the file is
  restricted to its owner. Encrypting them would not help: the container has to
  be able to read them to log in, so the key would sit next to the ciphertext.
  Keep `/data` as private as the rest of your application data.
- The Aura and Nixplay integrations use those companies' private app APIs, which
  they can change without warning.
- Framewrk is not a backup. The copies on your frames are not a backup either.

---

## Support

Questions and "how do I" go in
[Discussions](https://github.com/smichalczyk/framewrk/discussions). Bugs go in
[Issues](https://github.com/smichalczyk/framewrk/issues) — include the version
from **Settings → About** and the relevant lines from **Logs**.

## Licence

Free to use, for as long as you like, on as many machines as you like. Not open
source: no resale, no redistribution, no modified copies passed on. See
[LICENSE](LICENSE).

This repository holds the documentation. The source is not public.

Framewrk is not affiliated with, endorsed by, or connected to Aura, Nixplay,
PhotoPrism or Immich.
