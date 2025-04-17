#!/bin/bash
envsubst < /settings-template.json > $HOME/.config/transmission-daemon/settings.json
exec transmission-daemon --foreground --config-dir=$HOME/.config/transmission-daemon