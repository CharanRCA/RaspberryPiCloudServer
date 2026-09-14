# Raspberry Pi Nextcloud relay on Render

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> [!WARNING]
> Render's public web-service ingress is not compatible with Nextcloud WebDAV.
> A live test on 2026-09-14 showed `PROPFIND` returning HTTP `405` through the
> Render URL while the same request returned `207` directly from Nextcloud on
> the Pi. The Files web interface consequently displays "Folder not found",
> and official sync clients cannot list folders reliably. This repository's
> Render configuration is retained as an experimental HTTP tunnel, not as a
> production-ready Nextcloud endpoint.

This setup keeps Nextcloud and its data on the Raspberry Pi. A pinned Chisel
client on the Pi opens an authenticated outbound WebSocket tunnel to a Render
web service, so no inbound router port or public IPv4 address is required.

## Traffic path

`browser/app -> Render HTTPS -> Chisel reverse tunnel -> 127.0.0.1:11000 -> Nextcloud AIO`

## Render service

- Source: this repository; the build downloads the pinned upstream release
- Version: `v1.11.5`
- Runtime: Go
- Build command: `GOBIN=$PWD/bin go install github.com/jpillora/chisel@v1.11.5`
- Start command: `./bin/chisel server --host 0.0.0.0 --port $PORT --reverse --backend http://127.0.0.1:8081 --keepalive 10s`
- Secret environment variables: `AUTH` and `KEY`

The `AUTH` value is a randomly generated `username:password`. `KEY` keeps the
server identity stable across Render restarts. Neither secret belongs in Git.
Copy `pi/nextcloud-render-relay.env.example` outside the repository and replace
its placeholders; never edit the tracked example with real values.

## Pi service

The systemd unit is in `pi/nextcloud-render-relay.service`. Its root-only
environment file contains:

```text
CHISEL_SERVER=https://SERVICE-NAME.onrender.com
CHISEL_AUTH=USERNAME:PASSWORD
CHISEL_FINGERPRINT=SERVER_FINGERPRINT
```

The tunnel binds its Render-side backend only to `127.0.0.1:8081`; it is not a
second public port. Chisel's authenticated public listener is the Render
service's normal HTTPS endpoint.

## Operational limits

Render's free service is intended for testing and hobby use, not production.
The active Chisel WebSocket sends keepalive messages, which normally prevents
idle spin-down. Render can still restart or suspend a free service, and relay
traffic counts toward bandwidth limits. The Pi service automatically reconnects
after interruptions.

The existing Tailscale endpoint should remain configured until the Render URL
has passed browser, WebDAV, upload, and download tests. Changing the primary AIO
domain is the final cutover step and should be backed up first.

Run `pi/check-nextcloud-endpoint.sh` before making any endpoint the primary AIO
domain. A valid Nextcloud endpoint must pass the WebDAV `PROPFIND` check; loading
the login page or uploading a single file is not sufficient.

## Why the Files page can show "Folder not found"

Nextcloud loads directory contents with WebDAV methods such as `PROPFIND`. The
Render endpoint currently responds with an empty HTTP `405` before the request
reaches the Pi. Normal `GET` and `PUT` requests can still succeed, which makes a
partial relay look healthy even though the web and mobile file browsers are
broken.

For a complete public deployment without Tailscale, use an ingress path that
passes all WebDAV methods unchanged. Practical choices are:

- a domain plus router port-forwarding to a TLS reverse proxy on the Pi, when
  the internet connection has a reachable public address; or
- an outbound tunnel designed for publishing HTTP origins and verified with
  the included endpoint check (for example, a named Cloudflare Tunnel with a
  domain); or
- a small VPS with a raw TCP tunnel when the home connection is behind CGNAT.

Do not expose the AIO management port (`8080`) publicly. Only the Nextcloud HTTPS
endpoint should be published.

## Host firewall

The Pi can receive unsolicited traffic over globally routed IPv6 even when the
router has no IPv4 port-forward. The sample nftables policy therefore keeps SSH
(`22`) and the AIO management console (`8080`) reachable from the local
`192.168.1.0/24` LAN and Tailscale, while dropping those ports from every other
source.

Install `pi/cloudstorage-security.nft` as `/etc/cloudstorage-security.nft` and
`pi/cloudstorage-firewall.service` as
`/etc/systemd/system/cloudstorage-firewall.service`, then enable the service.
Adjust the LAN subnet in the nftables file before installation if your network
does not use `192.168.1.0/24`.

This policy intentionally does not open a public Nextcloud port. Public HTTPS
should only be added after selecting and validating the final ingress method.

## SSH authentication

Use an Ed25519 key for the `cloud` account and verify a second key-only SSH
connection before disabling passwords. The sample
`pi/00-cloud-storage.conf` disables password and keyboard-interactive login,
blocks direct root login, and restricts SSH to the `cloud` account.

The private key belongs on the administrator's computer only. Store it outside
the repository with restrictive filesystem permissions and keep a protected
offline backup. Never copy it to the Pi or GitHub.

