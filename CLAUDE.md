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
- **vpn-sidecar container**: Establishes VPN connection, handles network isolation
- **atd container**: Transmission daemon using vpn-sidecar's network namespace
- Traffic only flows through VPN tunnel; if VPN drops, torrent traffic cannot leak

## key files
```
dockerfile.vpn          # VPN sidecar container (WireGuard)
dockerfile.atd          # Transmission daemon container
docker-compose.yml      # Local dev orchestration
scripts/
  vpn-entrypoint.sh     # VPN startup and iptables configuration
  atd-start.sh          # Transmission startup script
.env                    # WireGuard credentials (not committed)
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
# Build and run locally
docker compose up -d --build

# Rebuild without cache
docker compose build --no-cache && docker compose up -d

# Verify VPN connection
docker exec vpn-sidecar curl ifconfig.me

# View logs
docker logs vpn-sidecar
docker logs atd

# Full rebuild
docker compose down && docker compose build --no-cache && docker compose up -d
```

## network details
- Transmission web UI: port 9091
- VPN container requires NET_ADMIN capability
- Uses bridge network with atd using `network_mode: service:vpn-sidecar`

---

# long-term-storage

---

# instructions-of-the-day

- migrate from open vpn to wireguard
- succesfully deploy both containers locally
- push to git (dev branch, your current branch)
- make sure build has completed 

---

# short-term-memory - add all temporary notes about your current task here

