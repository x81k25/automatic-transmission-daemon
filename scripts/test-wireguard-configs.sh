#!/bin/bash
# Test WireGuard configs for connectivity
# Tests each .conf file in .dev/wireguard-configs/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/.dev/wireguard-configs"
TEST_CONTAINER="wg-test"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_fail()  { echo -e "${RED}[FAIL]${NC} $1"; }

cleanup() {
    log_info "Cleaning up test container..."
    docker rm -f "$TEST_CONTAINER" 2>/dev/null || true
}

validate_config() {
    local conf_file="$1"
    local name=$(basename "$conf_file")

    log_info "Validating $name..."

    # Check required fields (use sed to get value after first =, preserving base64 padding)
    local private_key=$(grep -E "^PrivateKey\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')
    local address=$(grep -E "^Address\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')
    local dns=$(grep -E "^DNS\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')
    local public_key=$(grep -E "^PublicKey\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')
    local endpoint=$(grep -E "^Endpoint\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')
    local allowed_ips=$(grep -E "^AllowedIPs\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')

    local valid=true

    if [[ -z "$private_key" ]]; then
        log_fail "  Missing PrivateKey"
        valid=false
    elif [[ ${#private_key} -ne 44 ]]; then
        log_fail "  PrivateKey invalid length (expected 44, got ${#private_key})"
        valid=false
    else
        log_ok "  PrivateKey: present (${private_key:0:8}...)"
    fi

    if [[ -z "$address" ]]; then
        log_fail "  Missing Address"
        valid=false
    else
        log_ok "  Address: $address"
    fi

    if [[ -z "$dns" ]]; then
        log_warn "  Missing DNS (optional)"
    else
        log_ok "  DNS: $dns"
    fi

    if [[ -z "$public_key" ]]; then
        log_fail "  Missing PublicKey"
        valid=false
    elif [[ ${#public_key} -ne 44 ]]; then
        log_fail "  PublicKey invalid length (expected 44, got ${#public_key})"
        valid=false
    else
        log_ok "  PublicKey: ${public_key:0:8}..."
    fi

    if [[ -z "$endpoint" ]]; then
        log_fail "  Missing Endpoint"
        valid=false
    else
        log_ok "  Endpoint: $endpoint"
    fi

    if [[ -z "$allowed_ips" ]]; then
        log_fail "  Missing AllowedIPs"
        valid=false
    else
        log_ok "  AllowedIPs: $allowed_ips"
    fi

    $valid && return 0 || return 1
}

test_endpoint_reachable() {
    local conf_file="$1"
    local endpoint=$(grep -E "^Endpoint\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')
    local host=$(echo "$endpoint" | cut -d: -f1)
    local port=$(echo "$endpoint" | cut -d: -f2)

    log_info "Testing UDP reachability: $host:$port"

    # Use nc to check if UDP port is open (basic reachability)
    if nc -zuv -w 3 "$host" "$port" 2>&1 | grep -q "succeeded\|open"; then
        log_ok "  Endpoint reachable"
        return 0
    else
        log_warn "  Endpoint may not be reachable (UDP is hard to verify)"
        return 0  # Don't fail on this - UDP checks are unreliable
    fi
}

test_wireguard_connection() {
    local conf_file="$1"
    local name=$(basename "$conf_file" .conf)

    log_info "Testing WireGuard handshake: $name"

    # Extract values for gluetun (use sed to preserve base64 padding in keys)
    local private_key=$(grep -E "^PrivateKey\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')
    local address=$(grep -E "^Address\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')
    local address_ipv4=$(echo "$address" | cut -d, -f1 | cut -d/ -f1)
    local dns=$(grep -E "^DNS\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')
    local public_key=$(grep -E "^PublicKey\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')
    local endpoint=$(grep -E "^Endpoint\s*=" "$conf_file" | sed 's/^[^=]*=\s*//')
    local endpoint_ip=$(echo "$endpoint" | cut -d: -f1)
    local endpoint_port=$(echo "$endpoint" | cut -d: -f2)

    # Remove any existing test container
    docker rm -f "$TEST_CONTAINER" 2>/dev/null || true

    # Run gluetun container with this config
    log_info "  Starting gluetun container..."
    docker run -d \
        --name "$TEST_CONTAINER" \
        --cap-add NET_ADMIN \
        -p 8000:8000 \
        -e VPN_SERVICE_PROVIDER=custom \
        -e VPN_TYPE=wireguard \
        -e WIREGUARD_PRIVATE_KEY="$private_key" \
        -e WIREGUARD_ADDRESSES="$address_ipv4/32" \
        -e WIREGUARD_PUBLIC_KEY="$public_key" \
        -e WIREGUARD_ENDPOINT_IP="$endpoint_ip" \
        -e WIREGUARD_ENDPOINT_PORT="$endpoint_port" \
        -e DNS_ADDRESS="$dns" \
        -e HEALTH_VPN_DURATION_INITIAL=10s \
        -e HTTP_CONTROL_SERVER_ADDRESS=:8000 \
        -e LOG_LEVEL=debug \
        qmcgaw/gluetun:latest >/dev/null 2>&1

    # Wait for connection attempt
    log_info "  Waiting for VPN connection (max 30s)..."
    local waited=0
    local connected=false

    while [[ $waited -lt 30 ]]; do
        sleep 3
        waited=$((waited + 3))

        # Check logs for success or failure
        local logs=$(docker logs "$TEST_CONTAINER" 2>&1)

        if echo "$logs" | grep -q "healthy!"; then
            connected=true
            break
        fi

        # Check for actual fatal errors (not informational messages)
        if echo "$logs" | grep -qi "handshake did not complete\|UAPI error\|invalid private key\|invalid public key"; then
            log_fail "  WireGuard error detected in logs"
            echo "$logs" | grep -i "error\|invalid\|fail" | tail -5
            docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
            return 1
        fi

        echo -n "."
    done
    echo ""

    # If not explicitly healthy, try to verify connectivity via gluetun's HTTP API
    if ! $connected; then
        log_info "  Checking actual connectivity via gluetun API..."
        sleep 2  # Give HTTP server time to start

        # Query gluetun's public IP endpoint (returns JSON like {"public_ip":"1.2.3.4",...})
        local api_response=$(curl -s --max-time 10 http://localhost:8000/v1/publicip/ip 2>/dev/null)
        local vpn_ip=$(echo "$api_response" | grep -oP '"public_ip"\s*:\s*"\K[^"]+' || echo "")
        local my_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)

        if [[ -n "$vpn_ip" && "$vpn_ip" != "$my_ip" && "$vpn_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            connected=true
            log_ok "  VPN working! Public IP: $vpn_ip (local: $my_ip)"
        fi
    fi

    if $connected; then
        # Get full location info from gluetun API
        local api_response=$(curl -s --max-time 5 http://localhost:8000/v1/publicip/ip 2>/dev/null)
        local vpn_ip=$(echo "$api_response" | grep -oP '"public_ip"\s*:\s*"\K[^"]+' || echo "unknown")
        local city=$(echo "$api_response" | grep -oP '"city"\s*:\s*"\K[^"]+' || echo "")
        local country=$(echo "$api_response" | grep -oP '"country"\s*:\s*"\K[^"]+' || echo "")
        log_ok "  VPN connected! Public IP: $vpn_ip ($city, $country)"

        docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
        return 0
    else
        log_fail "  Connection timed out - VPN handshake likely failed"
        log_info "  Last logs:"
        docker logs "$TEST_CONTAINER" 2>&1 | tail -20 | sed 's/^/    /'
        docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
        return 1
    fi
}

main() {
    echo "========================================"
    echo "  WireGuard Config Tester"
    echo "========================================"
    echo ""

    trap cleanup EXIT

    if [[ ! -d "$CONFIG_DIR" ]]; then
        log_fail "Config directory not found: $CONFIG_DIR"
        exit 1
    fi

    local configs=("$CONFIG_DIR"/*.conf)
    if [[ ${#configs[@]} -eq 0 ]]; then
        log_fail "No .conf files found in $CONFIG_DIR"
        exit 1
    fi

    log_info "Found ${#configs[@]} config file(s)"
    echo ""

    local results=()

    for conf in "${configs[@]}"; do
        local name=$(basename "$conf")
        echo "----------------------------------------"
        echo "Testing: $name"
        echo "----------------------------------------"

        # Step 1: Validate config format
        if ! validate_config "$conf"; then
            results+=("$name: INVALID CONFIG")
            echo ""
            continue
        fi
        echo ""

        # Step 2: Test endpoint reachability
        test_endpoint_reachable "$conf"
        echo ""

        # Step 3: Test actual WireGuard connection
        if test_wireguard_connection "$conf"; then
            results+=("$name: SUCCESS")
        else
            results+=("$name: FAILED")
        fi
        echo ""
    done

    echo "========================================"
    echo "  Summary"
    echo "========================================"
    for result in "${results[@]}"; do
        if [[ "$result" == *"SUCCESS"* ]]; then
            log_ok "$result"
        else
            log_fail "$result"
        fi
    done
    echo ""
}

main "$@"
