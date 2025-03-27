FROM debian:12-slim@sha256:40b107342c492725bc7aacbe93a49945445191ae364184a6d24fedb28172f6f7

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    transmission-daemon \
    netcat-openbsd \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Configure directories and permissions
ENV HOME=/home/transmission
RUN mkdir -p /home/transmission/.config/transmission-daemon && \
    mkdir -p /media-cache/complete /media-cache/incomplete && \
    mkdir -p /var/lib/transmission /etc/transmission-daemon /usr/share/transmission && \
    chown -R 1005:1001 /home/transmission /media-cache/complete /media-cache/incomplete \
        /var/lib/transmission /etc/transmission-daemon /usr/share/transmission && \
    chmod 770 /media-cache/complete /media-cache/incomplete \
        /var/lib/transmission /etc/transmission-daemon /usr/share/transmission

# Configure transmission settings
# Create settings file template with environment variables
RUN echo '{\n\
    "alt-speed-enabled": false,\n\
    "cache-size-mb": 1024,\n\
    "download-dir": "/media-cache/complete",\n\
    "download-queue-enabled": false,\n\
    "incomplete-dir": "/media-cache/incomplete",\n\
    "incomplete-dir-enabled": true,\n\
    "peer-limit-global": 100,\n\
    "peer-limit-per-torrent": 100,\n\
    "ratio-limit-enabled": false,\n\
    "rpc-authentication-required": false,\n\
    "rpc-bind-address": "0.0.0.0",\n\
    "rpc-host-whitelist-enabled": false,\n\
    "rpc-whitelist-enabled": false,\n\
    "seed-queue-enabled": false,\n\
    "speed-limit-down-enabled": false,\n\
    "speed-limit-up-enabled": false,\n\
    "umask": 2\n\
}' > /settings-template.json

# Configure transmission settings to user profile
COPY config/transmission-settings.json /home/transmission/.config/transmission-daemon/settings.json
RUN chown 1005:1001 /home/transmission/.config/transmission-daemon/settings.json

# Create startup script
COPY scripts/start.sh /start.sh
RUN chmod +x /start.sh

# Expose transmission web interface port
EXPOSE 9091

# user mask
USER 1005:1001

# Set the entrypoint
ENTRYPOINT ["/start.sh"]