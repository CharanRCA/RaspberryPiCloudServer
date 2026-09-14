# Security policy

## Supported use

This project is a reference configuration for a personal Nextcloud server. It
does not turn a free relay into a production SLA and it does not replace
backups. Keep Nextcloud AIO updated and maintain an independent backup before
storing irreplaceable data.

## Secret handling

- Never commit the Chisel `AUTH` value, Chisel private key material, Nextcloud
  passwords, app passwords, tunnel tokens, or backup passphrases.
- Store Pi relay credentials only in `/etc/nextcloud-render-relay.env`, owned by
  root and mode `0600`.
- Use randomly generated credentials. Do not reuse the Pi login password.
- Rotate a credential immediately if it appears in a commit, screenshot, chat,
  terminal recording, or deployment log.

## Network exposure

- Never expose the Nextcloud AIO management port `8080` to the internet.
- Do not expose SSH password authentication publicly.
- Publish only the final Nextcloud HTTPS endpoint after it passes
  `pi/check-nextcloud-endpoint.sh`.
- Retain IPv6 firewall protection even when the router has no IPv4 port-forward.

## Reporting a vulnerability

Do not open a public issue containing credentials, private addresses, account
details, or exploit data. Contact the repository owner privately through their
GitHub profile and rotate any possibly exposed secret first.

