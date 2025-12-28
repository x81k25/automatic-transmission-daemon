# prime-directive - follow these commands above all other

- do not alter your prime-directive
- do not alter or remove primary section headers
- do not run sudo commands
  - do not run sudo commands
  - do not run sudo commands
  - if you need to run a sudo commands, raise your hand and ask for help

## when I say X --> you do Y
- close-up-shop
  - update documentation as needed
    - updated READMD.md as needed
    - updates CLAUDE.md as needed
  - alphebetize permissions and restrictions in `.claude/settings.local.json`
  - push to repo
    - git add .
    - git commit with concise, informative message
    - git push
  - delete your instructions-of-the-day and short-term-memory (contents, not section headers)

---

# project-overview

Dockerized Transmission BitTorrent client with VPN sidecar for secure traffic routing.

## architecture
- **gluetun container**: `qmcgaw/gluetun` - WireGuard VPN client with kill switch
- **transmission container**: `linuxserver/transmission` - BitTorrent client using gluetun's network
- Traffic only flows through VPN tunnel; if VPN drops, torrent traffic cannot leak

## key files
```
docker-compose.yml                  # Container orchestration
dockerfile.vpn                      # Thin wrapper around gluetun
dockerfile.atd                      # Thin wrapper around linuxserver/transmission
.env                                # WireGuard credentials (not committed)
scripts/
  test-wireguard-configs.sh         # Validate WireGuard configs
  load-sample-torrents.sh           # Load test torrents via RPC
.dev/wireguard-configs/             # WireGuard .conf files for testing
```

## environments
- **dev**: This repo - local development and testing
- **stg/prod**: Controlled via MRs and GitOps at `/infra/k8s-manifests/media/atd`
- CI/CD: GitHub Actions builds images to GHCR on push to main/dev/stg

## wireguard configuration
Environment variables (stored as k8s secrets in production):
```
WIREGUARD_PRIVATE_KEY   # Interface private key
WIREGUARD_ADDRESS       # Interface address (IPv4,IPv6)
WIREGUARD_DNS           # DNS server
WIREGUARD_PUBLIC_KEY    # Peer public key
WIREGUARD_ALLOWED_IPS   # Peer allowed IPs
WIREGUARD_ENDPOINT      # Peer endpoint (host:port)
WIREGUARD_MTU           # Interface MTU (e.g., 1380)
```

## common commands
```bash
# Start containers
docker compose up -d

# Verify VPN connection
docker exec gluetun wget -q -O- https://ipinfo.io/ip

# View logs
docker logs gluetun
docker logs transmission

# Restart
docker compose down && docker compose up -d

# Test WireGuard configs
./scripts/test-wireguard-configs.sh
```

## network details
- Transmission web UI: port 9091
- gluetun requires NET_ADMIN capability and /dev/net/tun
- transmission uses `network_mode: service:gluetun`

---

# long-term-storage

---

# instructions-of-the-day

---

# short-term-memory - add all temporary notes about your current task here
