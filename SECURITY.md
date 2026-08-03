# Reporting a security issue

Please don't open a public issue for anything security-related. Use GitHub's
private reporting instead:

**[Report a vulnerability](https://github.com/smichalczyk/framewrk/security/advisories/new)**

That reaches me directly and stays private until there's a fix to talk about.

Include what you did, what happened, and the version from **Settings → About**.
A proof of concept helps but isn't required.

## What is in scope

Framewrk holds the credentials for your PhotoPrism, Aura and Nixplay accounts,
and its console is often the only thing between a home network and those
accounts. Anything that undermines that is worth reporting:

- Signing in, sessions, CSRF, or the sign-in throttle
- Getting at stored service credentials without authenticating
- Anything that lets one install reach another person's frames or library
- The container running as, or escalating to, more than it should

## What is not

- **Service passwords are stored in the database in plain text.** This is
  known and documented. The container has to be able to read them to log in to
  PhotoPrism, Aura and Nixplay, so any key would have to sit next to the
  ciphertext. Keep `/data` as private as the rest of your application data.
- Findings that need an attacker to already have the admin password, or shell
  on the host.
- Anything about Aura's, Nixplay's or PhotoPrism's own services. Report those
  to them — Framewrk is an unaffiliated client.

## Versions

Fixes go into the current release. There are no long-term support branches:
if you are behind, the fix is to pull the current tag.
