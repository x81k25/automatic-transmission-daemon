# Dockerized Transmission BitTorrent Client

A lightweight Docker container for running Transmission BitTorrent client based on Debian 12 slim.

## Overview

This repository contains configuration files to build and run Transmission daemon in a Docker container with custom settings. The container is designed to run with specific user permissions and configured download directories.

## Repository Structure

```
.
├── .github
├── config
│   └── transmission-settings.json
├── scripts
├── .dockerignore
├── .gitignore
├── docker-compose.yml
├── Dockerfile
└── readme.md
```

## Prerequisites

- Docker
- Docker Compose (for using the docker-compose.yml configuration)

## Configuration

### Dockerfile

The Dockerfile:
- Uses Debian 12 slim as the base image
- Installs Transmission daemon and netcat
- Configures user permissions
- Sets up download directories in `/media-cache/`
- Configures Transmission settings

### Transmission Settings

The container uses custom Transmission settings located in `config/transmission-settings.json`. You can modify these settings to adjust download behavior, connection limits, and web interface configuration. The file will need to be created, as it may contain secure information and is not included in this repository. 

### .github/workflows

This repository is currently configured to build a container image via GitHub actions when a pull request or direct commit is made to the main branch. This can be configured in the `docker-build.yml` 

## Usage

### Building the Image

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

This repository uses multiple docker-compose files to support different environments (development, staging, production) without configuration conflicts. Each environment uses different ports and volume mappings.

#### Base Configuration (`docker-compose.yml`)

```yaml
services:
  automatic-transmission-daemon:
    build: .
    environment:
      - DEBIAN_FRONTEND=noninteractive
    volumes:
      - /media-cache/complete:/media-cache/complete
      - /media-cache/incomplete:/media-cache/incomplete
```

#### Environment-specific Configurations

**Development** (`docker-compose.dev.yml`):
```yaml
services:
  automatic-transmission-daemon:
    container_name: automatic-transmission-daemon-dev
    ports:
      - "9093:9091"
    volumes:
      - /d/media-cache/dev/complete:/media-cache/complete
      - /d/media-cache/dev/incomplete:/media-cache/incomplete
```

**Staging** (`docker-compose.stg.yml`):
```yaml
services:
  automatic-transmission-daemon:
    container_name: automatic-transmission-daemon-stg
    ports:
      - "9092:9091"
    volumes:
      - /d/media-cache/stg/complete:/media-cache/complete
      - /d/media-cache/stg/incomplete:/media-cache/incomplete
```

**Production** (`docker-compose.prod.yml`):
```yaml
services:
  automatic-transmission-daemon:
    container_name: automatic-transmission-daemon-prod
    ports:
      - "9091:9091"
    volumes:
      - /d/media-cache/prod/complete:/media-cache/complete
      - /d/media-cache/prod/incomplete:/media-cache/incomplete
```

#### Running Specific Environments

To launch a specific environment:

```bash
# Development
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Staging
docker-compose -f docker-compose.yml -f docker-compose.stg.yml up -d

# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

This approach allows you to:
- Run multiple environments simultaneously without conflicts
- Keep all configuration files in version control
- Clearly separate environment-specific settings
- Share common configuration across environments

## Ports

- **9091**: Transmission web interface; default transmission port

## Volumes

- **/media-cache/complete**: Directory for completed downloads
- **/media-cache/incomplete**: Directory for incomplete downloads

## User/Group Permissions

The container runs with:
- UID: 1005
- GID: 1001

Ensure these IDs have proper permissions on your host system if mapping volumes.

## License

This project is licensed under the MIT License