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
│   └── docker-build.yml        # CI/CD builds images to GHCR
├── scripts/
│   ├── test-wireguard-configs.sh   # Validate WireGuard .conf files
│   └── load-sample-torrents.sh     # Load test torrents via RPC
├── docker-compose.yml          # Container orchestration
├── dockerfile.atd              # Wrapper around linuxserver/transmission
├── dockerfile.vpn              # Wrapper around gluetun
├── .env                        # WireGuard credentials (not committed)
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
```

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
./scripts/test-wireguard-configs.sh
```

### Load Test Torrents

```bash
./scripts/load-sample-torrents.sh
```

### View Logs

```bash
docker logs gluetun
docker logs transmission
```

### Access Transmission

Web UI: http://localhost:9091

## CI/CD Pipeline

GitHub Actions automatically builds and pushes Docker images on push to `main`, `dev`, or `stg` branches:

- Images pushed to GitHub Container Registry (GHCR)
- Tagged with branch name
- Thin wrappers around upstream images for version control

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
