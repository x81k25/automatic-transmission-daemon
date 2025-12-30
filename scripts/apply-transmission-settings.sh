#!/bin/bash
# Apply transmission settings from environment variables to settings.json
# This script runs during container initialization (s6-overlay)

SETTINGS_FILE="/config/settings.json"

# Wait for settings.json to exist (transmission creates it on first run)
# If it doesn't exist after 30s, exit and let transmission create defaults
for i in {1..30}; do
    if [[ -f "$SETTINGS_FILE" ]]; then
        break
    fi
    sleep 1
done

if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "[apply-transmission-settings] settings.json not found, skipping"
    exit 0
fi

echo "[apply-transmission-settings] Applying environment variable overrides to settings.json"

# Map env vars to settings.json keys and apply with jq
# Format: ENV_VAR_NAME -> settings.json key -> value type (string/number/bool)
declare -A SETTINGS_MAP=(
    ["TRANSMISSION_CACHE_SIZE_MB"]="cache-size-mb:number"
    ["TRANSMISSION_DOWNLOAD_QUEUE_ENABLED"]="download-queue-enabled:bool"
    ["TRANSMISSION_DOWNLOAD_QUEUE_SIZE"]="download-queue-size:number"
    ["TRANSMISSION_PEER_LIMIT_GLOBAL"]="peer-limit-global:number"
    ["TRANSMISSION_PEER_LIMIT_PER_TORRENT"]="peer-limit-per-torrent:number"
    ["TRANSMISSION_PREALLOCATION"]="preallocation:number"
    ["TRANSMISSION_QUEUE_STALLED_ENABLED"]="queue-stalled-enabled:bool"
    ["TRANSMISSION_QUEUE_STALLED_MINUTES"]="queue-stalled-minutes:number"
    ["TRANSMISSION_SEED_QUEUE_ENABLED"]="seed-queue-enabled:bool"
    ["TRANSMISSION_SEED_QUEUE_SIZE"]="seed-queue-size:number"
    ["TRANSMISSION_SPEED_LIMIT_DOWN"]="speed-limit-down:number"
    ["TRANSMISSION_SPEED_LIMIT_DOWN_ENABLED"]="speed-limit-down-enabled:bool"
    ["TRANSMISSION_SPEED_LIMIT_UP"]="speed-limit-up:number"
    ["TRANSMISSION_SPEED_LIMIT_UP_ENABLED"]="speed-limit-up-enabled:bool"
)

# Build jq filter from env vars
JQ_FILTER="."
for env_var in "${!SETTINGS_MAP[@]}"; do
    value="${!env_var}"
    if [[ -n "$value" ]]; then
        mapping="${SETTINGS_MAP[$env_var]}"
        key="${mapping%%:*}"
        type="${mapping##*:}"

        case "$type" in
            number)
                JQ_FILTER="$JQ_FILTER | .[\"$key\"] = $value"
                ;;
            bool)
                # Convert string to boolean
                if [[ "$value" == "true" ]]; then
                    JQ_FILTER="$JQ_FILTER | .[\"$key\"] = true"
                else
                    JQ_FILTER="$JQ_FILTER | .[\"$key\"] = false"
                fi
                ;;
            *)
                JQ_FILTER="$JQ_FILTER | .[\"$key\"] = \"$value\""
                ;;
        esac
        echo "[apply-transmission-settings] Setting $key = $value"
    fi
done

# Apply the changes
if [[ "$JQ_FILTER" != "." ]]; then
    tmp_file=$(mktemp)
    if jq "$JQ_FILTER" "$SETTINGS_FILE" > "$tmp_file"; then
        mv "$tmp_file" "$SETTINGS_FILE"
        chown abc:abc "$SETTINGS_FILE"
        echo "[apply-transmission-settings] Settings applied successfully"
    else
        echo "[apply-transmission-settings] ERROR: Failed to apply settings"
        rm -f "$tmp_file"
        exit 1
    fi
else
    echo "[apply-transmission-settings] No settings to apply"
fi
