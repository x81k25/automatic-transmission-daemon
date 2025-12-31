# Dockerized Transmission with WireGuard VPN

A secure Docker setup for running Transmission BitTorrent client behind a WireGuard VPN connection.

## Overview

This repository runs Transmission daemon in a two-container setup:

1. **gluetun**: WireGuard VPN client with built-in kill switch
2. **transmission**: BitTorrent client routing all traffic through the VPN

This architecture ensures torrent traffic only flows through the VPN tunnel. If the VPN drops, traffic cannot leak.

## Repository Structure

```
.
├── .github/workflows/
│   └── docker-build.yml            # CI/CD with lint, tests, and builds
├── scripts/
│   └── apply-transmission-settings.sh  # Init script for settings injection
├── tests/
│   ├── unit/                       # BATS unit tests
│   │   ├── test-apply-settings.bats
│   │   └── fixtures/settings.json
│   ├── test-wireguard-configs.sh   # Validate WireGuard .conf files
│   └── load-sample-torrents.sh     # Load test torrents via RPC
├── docker-compose.yml              # Container orchestration
├── dockerfile.atd                  # Wrapper around linuxserver/transmission
├── dockerfile.vpn                  # Wrapper around gluetun
├── .env                            # WireGuard + transmission settings (not committed)
└── README.md
```

## Prerequisites

- Docker & Docker Compose
- WireGuard configuration from your VPN provider

## Configuration

### Environment Variables

Create a `.env` file with your WireGuard credentials:

```bash
# Interface
WIREGUARD_PRIVATE_KEY=<your-private-key>
WIREGUARD_ADDRESS=10.x.x.x/32,fc00::/128
WIREGUARD_DNS=10.64.0.1
WIREGUARD_MTU=1200

# Peer
WIREGUARD_PUBLIC_KEY=<server-public-key>
WIREGUARD_ALLOWED_IPS=0.0.0.0/0,::0/0
WIREGUARD_ENDPOINT=<server-ip>:51820

# Gluetun remapped values
WIREGUARD_ADDRESS_IPV4=10.x.x.x/32
WIREGUARD_ENDPOINT_IP=<server-ip>
WIREGUARD_ENDPOINT_PORT=51820

# Transmission settings (optional - injected into settings.json)
TRANSMISSION_CACHE_SIZE_MB=4
TRANSMISSION_DOWNLOAD_QUEUE_ENABLED=true
TRANSMISSION_DOWNLOAD_QUEUE_SIZE=3
TRANSMISSION_PEER_LIMIT_GLOBAL=100
TRANSMISSION_PEER_LIMIT_PER_TORRENT=30
TRANSMISSION_PREALLOCATION=1
TRANSMISSION_QUEUE_STALLED_ENABLED=true
TRANSMISSION_QUEUE_STALLED_MINUTES=30
TRANSMISSION_SEED_QUEUE_ENABLED=true
TRANSMISSION_SEED_QUEUE_SIZE=5
TRANSMISSION_SPEED_LIMIT_DOWN=5000
TRANSMISSION_SPEED_LIMIT_DOWN_ENABLED=true
TRANSMISSION_SPEED_LIMIT_UP=1000
TRANSMISSION_SPEED_LIMIT_UP_ENABLED=true
```

### Transmission Settings Injection

The `apply-transmission-settings.sh` init script automatically converts `TRANSMISSION_*` environment variables to `settings.json` entries on container startup. This allows configuration via:
- `.env` file for local development
- Kubernetes ConfigMaps for production environments

### Volumes

The docker-compose.yml configures:
- `./config`: Transmission configuration
- `./media-cache/complete`: Completed downloads
- `./media-cache/incomplete`: In-progress downloads

## Usage

### Start Containers

```bash
docker compose up -d
```

### Verify VPN Connection

```bash
# Check VPN IP
docker exec gluetun wget -q -O- https://ipinfo.io/ip

# Should return VPN provider's IP, not your real IP
```

### Test WireGuard Configs

```bash
# Validate .conf files in .dev/wireguard-configs/
./tests/test-wireguard-configs.sh
```

### Load Test Torrents

```bash
./tests/load-sample-torrents.sh

# For k8s environments, specify host/port
TRANSMISSION_HOST=192.168.50.2 TRANSMISSION_PORT=30093 ./tests/load-sample-torrents.sh
```

### Run Unit Tests

```bash
# Via Docker (no local dependencies)
docker run --rm -v $(pwd):/workdir -w /workdir ubuntu:22.04 \
  bash -c "apt-get update -qq && apt-get install -qq -y bats jq >/dev/null && bats tests/unit/"
```

### View Logs

```bash
docker logs gluetun
docker logs transmission
```

### Access Transmission

Web UI: http://localhost:9091

## CI/CD Pipeline

GitHub Actions runs on push to `main`, `dev`, or `stg` branches:

```
[lint] ─────────────────┬──→ [build-and-push-vpn]
                        │
[unit-tests] ───────────┴──→ [build-and-push-atd] → (verify init script)
```

### Jobs

| Job | Description |
|-----|-------------|
| **lint** | shellcheck on scripts, hadolint on Dockerfiles |
| **unit-tests** | BATS tests for settings injection logic |
| **build-and-push-vpn** | Build and push VPN image to GHCR |
| **build-and-push-atd** | Build, verify init script, push ATD image to GHCR |

Images are tagged with branch name and pushed to GitHub Container Registry.

## Troubleshooting

### VPN Connection Issues

1. Check logs: `docker logs gluetun`
2. Verify credentials in `.env`
3. Test config: `./scripts/test-wireguard-configs.sh`

### Transmission Access Issues

1. Verify VPN is healthy: `docker ps` (should show "healthy")
2. Check port 9091 is exposed
3. Verify transmission container started: `docker logs transmission`

## License

MIT License
