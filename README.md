# Raspberry Pi Nextcloud relay on Render

This setup keeps Nextcloud and its data on the Raspberry Pi. A pinned Chisel
client on the Pi opens an authenticated outbound WebSocket tunnel to a Render
web service, so no inbound router port or public IPv4 address is required.

## Traffic path

`browser/app -> Render HTTPS -> Chisel reverse tunnel -> 127.0.0.1:11000 -> Nextcloud AIO`

## Render service

- Source: `https://github.com/jpillora/chisel`
- Version: `v1.11.5`
- Runtime: Go
- Build command: `go build -ldflags="-s -w" -o chisel .`
- Start command: `./chisel server --host 0.0.0.0 --port $PORT --reverse --backend http://127.0.0.1:8081 --keepalive 10s`
- Secret environment variables: `AUTH` and `KEY`

The `AUTH` value is a randomly generated `username:password`. `KEY` keeps the
server identity stable across Render restarts. Neither secret belongs in Git.

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

