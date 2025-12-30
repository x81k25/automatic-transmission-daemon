#!/usr/bin/env bats
# Unit tests for apply-transmission-settings.sh logic
# Tests the jq filter building and application without requiring container environment

FIXTURES_DIR="$BATS_TEST_DIRNAME/fixtures"

setup() {
    # Create temp directory for each test
    TEST_DIR=$(mktemp -d)
    cp "$FIXTURES_DIR/settings.json" "$TEST_DIR/settings.json"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Helper function that mimics the script's jq filter building logic
build_and_apply_filter() {
    local settings_file="$TEST_DIR/settings.json"
    local jq_filter="."

    # Same mapping as the actual script
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

    for env_var in "${!SETTINGS_MAP[@]}"; do
        value="${!env_var}"
        if [[ -n "$value" ]]; then
            mapping="${SETTINGS_MAP[$env_var]}"
            key="${mapping%%:*}"
            type="${mapping##*:}"

            case "$type" in
                number)
                    jq_filter="$jq_filter | .[\"$key\"] = $value"
                    ;;
                bool)
                    if [[ "$value" == "true" ]]; then
                        jq_filter="$jq_filter | .[\"$key\"] = true"
                    else
                        jq_filter="$jq_filter | .[\"$key\"] = false"
                    fi
                    ;;
                *)
                    jq_filter="$jq_filter | .[\"$key\"] = \"$value\""
                    ;;
            esac
        fi
    done

    if [[ "$jq_filter" != "." ]]; then
        jq "$jq_filter" "$settings_file" > "$TEST_DIR/settings.tmp" && \
            mv "$TEST_DIR/settings.tmp" "$settings_file"
    fi
}

@test "applies number setting correctly" {
    export TRANSMISSION_CACHE_SIZE_MB=4
    build_and_apply_filter

    result=$(jq '."cache-size-mb"' "$TEST_DIR/settings.json")
    [ "$result" = "4" ]
}

@test "applies bool true correctly" {
    export TRANSMISSION_DOWNLOAD_QUEUE_ENABLED=true
    build_and_apply_filter

    result=$(jq '."download-queue-enabled"' "$TEST_DIR/settings.json")
    [ "$result" = "true" ]
}

@test "applies bool false correctly" {
    export TRANSMISSION_SPEED_LIMIT_DOWN_ENABLED=false
    build_and_apply_filter

    result=$(jq '."speed-limit-down-enabled"' "$TEST_DIR/settings.json")
    [ "$result" = "false" ]
}

@test "applies multiple settings at once" {
    export TRANSMISSION_CACHE_SIZE_MB=32
    export TRANSMISSION_PEER_LIMIT_GLOBAL=300
    export TRANSMISSION_DOWNLOAD_QUEUE_ENABLED=true
    export TRANSMISSION_SPEED_LIMIT_DOWN=5000
    build_and_apply_filter

    [ "$(jq '."cache-size-mb"' "$TEST_DIR/settings.json")" = "32" ]
    [ "$(jq '."peer-limit-global"' "$TEST_DIR/settings.json")" = "300" ]
    [ "$(jq '."download-queue-enabled"' "$TEST_DIR/settings.json")" = "true" ]
    [ "$(jq '."speed-limit-down"' "$TEST_DIR/settings.json")" = "5000" ]
}

@test "skips empty env vars" {
    export TRANSMISSION_CACHE_SIZE_MB=""
    build_and_apply_filter

    # Should remain at original value (1024)
    result=$(jq '."cache-size-mb"' "$TEST_DIR/settings.json")
    [ "$result" = "1024" ]
}

@test "preserves unmodified settings" {
    export TRANSMISSION_CACHE_SIZE_MB=4
    build_and_apply_filter

    # Check that other settings are unchanged
    [ "$(jq '."peer-limit-global"' "$TEST_DIR/settings.json")" = "200" ]
    [ "$(jq '."preallocation"' "$TEST_DIR/settings.json")" = "0" ]
}

@test "handles all 14 settings" {
    export TRANSMISSION_CACHE_SIZE_MB=4
    export TRANSMISSION_DOWNLOAD_QUEUE_ENABLED=true
    export TRANSMISSION_DOWNLOAD_QUEUE_SIZE=3
    export TRANSMISSION_PEER_LIMIT_GLOBAL=100
    export TRANSMISSION_PEER_LIMIT_PER_TORRENT=30
    export TRANSMISSION_PREALLOCATION=1
    export TRANSMISSION_QUEUE_STALLED_ENABLED=true
    export TRANSMISSION_QUEUE_STALLED_MINUTES=30
    export TRANSMISSION_SEED_QUEUE_ENABLED=true
    export TRANSMISSION_SEED_QUEUE_SIZE=5
    export TRANSMISSION_SPEED_LIMIT_DOWN=5000
    export TRANSMISSION_SPEED_LIMIT_DOWN_ENABLED=true
    export TRANSMISSION_SPEED_LIMIT_UP=1000
    export TRANSMISSION_SPEED_LIMIT_UP_ENABLED=true
    build_and_apply_filter

    [ "$(jq '."cache-size-mb"' "$TEST_DIR/settings.json")" = "4" ]
    [ "$(jq '."download-queue-enabled"' "$TEST_DIR/settings.json")" = "true" ]
    [ "$(jq '."download-queue-size"' "$TEST_DIR/settings.json")" = "3" ]
    [ "$(jq '."peer-limit-global"' "$TEST_DIR/settings.json")" = "100" ]
    [ "$(jq '."peer-limit-per-torrent"' "$TEST_DIR/settings.json")" = "30" ]
    [ "$(jq '."preallocation"' "$TEST_DIR/settings.json")" = "1" ]
    [ "$(jq '."queue-stalled-enabled"' "$TEST_DIR/settings.json")" = "true" ]
    [ "$(jq '."queue-stalled-minutes"' "$TEST_DIR/settings.json")" = "30" ]
    [ "$(jq '."seed-queue-enabled"' "$TEST_DIR/settings.json")" = "true" ]
    [ "$(jq '."seed-queue-size"' "$TEST_DIR/settings.json")" = "5" ]
    [ "$(jq '."speed-limit-down"' "$TEST_DIR/settings.json")" = "5000" ]
    [ "$(jq '."speed-limit-down-enabled"' "$TEST_DIR/settings.json")" = "true" ]
    [ "$(jq '."speed-limit-up"' "$TEST_DIR/settings.json")" = "1000" ]
    [ "$(jq '."speed-limit-up-enabled"' "$TEST_DIR/settings.json")" = "true" ]
}
