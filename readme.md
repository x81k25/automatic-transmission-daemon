# Dockerized Transmission BitTorrent Client

A lightweight Docker container for running Transmission BitTorrent client based on Debian 12 slim.

## Overview

This repository contains configuration files to build and run Transmission daemon in a Docker container with custom settings. The container is designed to run with specific user permissions and configured download directories.

## Repository Structure

```
.
├── .github
│   └── workflows
│       └── docker-build.yml
├── scripts
│   └── start.sh
├── .dockerignore
├── .gitignore
├── docker-compose.dev.yml
├── docker-compose.prod.yml
├── docker-compose.stg.yml
├── Dockerfile
└── readme.md
```

## Prerequisites

- Docker
- Docker Compose (for using the docker-compose configuration files)

## Configuration

### Dockerfile

The Dockerfile:
- Uses Debian 12 slim as the base image
- Installs Transmission daemon and necessary utilities
- Configures user permissions (UID: 1005, GID: 1001)
- Sets up download directories in `/media-cache/`
- Contains a built-in settings template that is processed at startup

### Transmission Settings

The configuration for Transmission is now directly embedded in the Dockerfile as a template (`/settings-template.json`), which is processed by the start script at container launch. This approach eliminates the need for a separate configuration file.

Default settings include:
- Download directories for complete and incomplete files
- RPC interface configuration (no authentication required by default)
- Network and performance tuning
- Cache size, peer limits, and other BitTorrent-specific settings

The start script (`scripts/start.sh`) processes this template using environment variables and starts the Transmission daemon with the generated configuration.

### CI/CD Pipeline

This repository includes GitHub Actions workflows that automatically build and push Docker images when changes are pushed to the `main`, `dev`, or `stg` branches. The workflow:

1. Builds the Docker image
2. Pushes the image to GitHub Container Registry (GHCR)
3. Tags images with branch name and latest (for main branch)

## Usage
  
## Usage

### Building and Running

#### Build Images
```bash
# Build with specific Dockerfiles
docker-compose build --build-arg DOCKERFILE=Dockerfile.atd atd
docker-compose build --build-arg DOCKERFILE=Dockerfile.vpn vpn-sidecar

# Alternative build with docker command
## atd image
docker build -f Dockerfile.atd -t atd-image .
## vpn-sidecar image

# Run both services in background
docker-compose up -d

# full restart
docker-compose down && docker-compose build --no-cache vpn-sidecar && docker-compose up -d

# test vpn-sidecar status
docker exec -it vpn-sidecar curl ifconfig.me
docker exec -it atd curl ifconfig.me

# exec into conatiner
docker exec -it vpn-sidecar /bin/bash

# get container logs
docker logs vpn-sidecar
docker logs atd

# command for vpn-sidecar container only
## build
docker build -t dockerfile.vpn-sidecar -f dockerfile.vpn .

## build without cache
docker build -t dockerfile.vpn -f dockerfile.vpn --no-cache .

## run container
docker compose up -d vpn-sidecar

## whole thing
docker compose down vpn-sidecar && docker compose build --no-cache vpn-sidecar && docker compose up -d vpn-sidecar

# clean slate
docker stop $(docker ps -aq) && docker rm $(docker ps -aq) && docker rmi $(docker images -q) --force && docker system prune -af --volumes

```







## Usage

### Building the Image Locally

```bash
docker build -t transmission-bt .
```

### Running with Docker

```bash
docker run -d \
  --name transmission \
  -p 9091:9091 \
  -v /path/to/downloads:/media-cache/complete \
  -v /path/to/incomplete:/media-cache/incomplete \
  transmission-bt
```

### Running with Docker Compose

This repository uses multiple docker compose files to support different environments (development, staging, production) with environment-specific configurations.

#### Running Specific Environments

To launch a specific environment:

```bash
# run container
docker compose -f docker compose.dev.yml up -d
docker compose -f docker compose.stg.yml up -d
docker compose -f docker compose.prod.yml up -d

# tear down
docker compose -f docker compose.dev.yml down
docker compose -f docker compose.stg.yml down
docker compose -f docker compose.prod.yml down

# exec into container
sudo docker exec -it automatic-transmission-daemon-dev /bin/bash
sudo docker exec -it automatic-transmission-daemon-stg /bin/bash
sudo docker exec -it automatic-transmission-daemon-prod /bin/bash
```

This approach allows you to:
- Run multiple environments simultaneously without conflicts
- Keep all configuration files in version control
- Clearly separate environment-specific settings

## Environment Configurations

| Environment | Container Name | Port Mapping | Volume Paths |
|-------------|----------------|--------------|--------------|
| Development | automatic-transmission-daemon-dev | 9093:9091 | /d/media-cache/dev/* |
| Staging | automatic-transmission-daemon-stg | 9092:9091 | /d/media-cache/stg/* |
| Production | automatic-transmission-daemon | 9091:9091 | /d/media-cache/prod/* |

## Ports

- **9091**: Transmission web interface (default)

## Volumes

- **/media-cache/complete**: Directory for completed downloads
- **/media-cache/incomplete**: Directory for incomplete downloads

## User/Group Permissions

The container runs with:
- UID: 1005
- GID: 1001

Ensure these IDs have proper permissions on your host system if mapping volumes.

## GitHub Container Registry

You can also pull the pre-built image from GitHub Container Registry:

```bash
docker pull ghcr.io/yourusername/automatic-transmission:latest
```

Replace `yourusername` with your actual GitHub username/organization.

## License

This project is licensed under the MIT License