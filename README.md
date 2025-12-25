# Dockerized Transmission with VPN Sidecar

A secure Docker setup for running Transmission BitTorrent client behind a VPN connection.

## Overview

This repository contains configuration files to run Transmission daemon in a two-container setup:

1. **VPN Sidecar**: A container that establishes and maintains a VPN connection
2. **Transmission Daemon**: A BitTorrent client that routes all traffic through the VPN

This architecture ensures that torrent traffic only flows through the VPN connection, providing privacy and security.

## Repository Structure

```
.
├── .github
│   └── workflows
│       └── docker-build.yml  # CI/CD workflow for building container images
├── scripts
│   ├── atd-start.sh         # Transmission startup script
│   └── vpn-entrypoint.sh    # VPN container entrypoint script
├── .dockerignore
├── .gitignore
├── docker-compose.yml       # Configuration for running both containers
├── dockerfile.atd           # Dockerfile for Transmission container
├── dockerfile.vpn           # Dockerfile for VPN sidecar container
└── readme.md
```

## Prerequisites

- Docker
- Docker Compose
- VPN subscription with OpenVPN configuration

## How It Works

### VPN Sidecar Architecture

The setup uses a "sidecar" pattern where:

1. The VPN container establishes the secure connection
2. The Transmission container shares the VPN container's network namespace
3. All Transmission traffic is forced through the VPN tunnel

This approach ensures that if the VPN connection drops, Transmission traffic cannot leak outside the secure tunnel.

### Container Details

#### VPN Sidecar Container

- Based on Ubuntu 24.10
- Runs OpenVPN client
- Configures iptables for proper traffic routing
- Manages DNS settings to prevent leaks
- Exposes port 9091 for Transmission web interface

#### Transmission Container

- Based on Debian Stable Slim
- Configured with specific UID/GID (1005:1001)
- Mounts host directories for downloads
- Shares network namespace with VPN container

## Configuration

### Environment Variables

Create a `.env` file in the repository root with the following variables:

```
VPN_USERNAME=your_vpn_username
VPN_PASSWORD=your_vpn_password
VPN_CONFIG=your_openvpn_config_content
```

The `VPN_CONFIG` variable should contain the entire content of your OpenVPN configuration file.

### Volumes

The docker-compose.yml file configures two volume mounts:

- `./media-cache/complete`: Directory for completed downloads
- `./media-cache/incomplete`: Directory for incomplete downloads

Make sure these directories exist on your host system with proper permissions.

## Usage

### Building and Running

To build and start both containers:

```bash
# Build and start both containers
docker compose up -d

# Build containers without using cache
docker compose build --no-cache
docker compose up -d
```

### Verifying VPN Connection

To verify that traffic is routing through the VPN:

```bash
# Check IP address from VPN container
docker exec -it vpn-sidecar curl ifconfig.me

# Check IP address from Transmission container
docker exec -it atd curl ifconfig.me
```

Both commands should return the same IP address, which should be your VPN provider's IP, not your actual public IP.

### Managing Containers

```bash
# View container logs
docker logs vpn-sidecar
docker logs atd

# Access container shell
docker exec -it vpn-sidecar /bin/bash
docker exec -it atd /bin/bash

# Stop containers
docker compose down
```

### Full Rebuild

If you need to completely rebuild the containers:

```bash
# Stop, rebuild without cache, and restart
docker compose down && docker compose build --no-cache && docker compose up -d
```

## CI/CD Pipeline

This repository includes GitHub Actions workflows that automatically build and push Docker images when changes are pushed to the `main`, `dev`, or `stg` branches. The workflow:

1. Builds both Docker images (ATD and VPN)
2. Pushes the images to GitHub Container Registry (GHCR)
3. Tags images with branch name and latest (for main branch)

## Troubleshooting

### VPN Connection Issues

If the VPN connection fails to establish:

1. Check the VPN container logs: `docker logs vpn-sidecar`
2. Verify your VPN credentials in the `.env` file
3. Ensure your OpenVPN config is valid and complete

### Transmission Access Issues

If you can't access the Transmission web interface:

1. Verify that the VPN connection is established
2. Check that port 9091 is correctly forwarded
3. Ensure iptables rules in the VPN container are correctly configured

### Network Connectivity Issues

If containers can't access the internet:

1. Check DNS configuration in the VPN container
2. Verify that routing is properly configured
3. Make sure `NET_ADMIN` capability is granted to the VPN container

## License

This project is licensed under the MIT License