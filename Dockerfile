FROM debian:12-slim@sha256:40b107342c492725bc7aacbe93a49945445191ae364184a6d24fedb28172f6f7

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    transmission-daemon \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# configure home for user
ENV HOME=/home/transmission
RUN mkdir -p /home/transmission/.config/transmission-daemon && \
    chown -R 1005:1001 /home/transmission

# create download directories and assign to user
RUN mkdir -p  \
    /media-cache/complete  \  
    /media-cache/incomplete \
    && chown -R 1005:1001 \
    /media-cache/complete  \  
    /media-cache/incomplete \
    && chmod 770 \
    /media-cache/complete  \  
    /media-cache/incomplete 

# set transmission dirs to be own by assigned users
RUN mkdir -p \
    /var/lib/transmission \
    /etc/transmission-daemon \
    /usr/share/transmission \
    && chown -R 1005:1001 \
    /var/lib/transmission \
    /etc/transmission-daemon \
    /usr/share/transmission \
    && chown 770 \
    /var/lib/transmission \
    /etc/transmission-daemon \
    /usr/share/transmission

# Configure transmission settings
#COPY config/transmission-settings.json /etc/transmission-daemon/settings.json
#RUN chown 1005:1001 /etc/transmission-daemon/settings.json

# Configure transmission settings to user profile
COPY config/transmission-settings.json /home/transmission/.config/transmission-daemon/settings.json
RUN chown 1005:1001 /home/transmission/.config/transmission-daemon/settings.json

# Expose transmission web interface port
EXPOSE 9091

# Create startup script
COPY scripts/start.sh /start.sh
RUN chmod +x /start.sh

USER 1005:1001

# Set the entrypoint
ENTRYPOINT ["/start.sh"]