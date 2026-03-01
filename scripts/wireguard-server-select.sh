#!/bin/sh
# wireguard-server-select.sh
# Selects a random WireGuard server from WIREGUARD_SERVERS JSON,
# exports the connection variables, and hands off to gluetun entrypoint.

set -e

if [ -z "$WIREGUARD_SERVERS" ]; then
  echo "ERROR: WIREGUARD_SERVERS env var not set"
  exit 1
fi

if [ -z "$WIREGUARD_ADDRESS" ]; then
  echo "ERROR: WIREGUARD_ADDRESS env var not set"
  exit 1
fi

# Pick a random server from the JSON blob
SERVER_NAME=$(echo "$WIREGUARD_SERVERS" | jq -r 'keys[]' | shuf -n1)
echo "Selected WireGuard server: $SERVER_NAME"

# Extract server details
export WIREGUARD_PUBLIC_KEY=$(echo "$WIREGUARD_SERVERS" | jq -r --arg s "$SERVER_NAME" '.[$s].public_key')
export WIREGUARD_ENDPOINT_IP=$(echo "$WIREGUARD_SERVERS" | jq -r --arg s "$SERVER_NAME" '.[$s].endpoint | split(":")[0]')
export WIREGUARD_ENDPOINT_PORT=$(echo "$WIREGUARD_SERVERS" | jq -r --arg s "$SERVER_NAME" '.[$s].endpoint | split(":")[1]')

# Extract IPv4-only address (gluetun expects IPv4 when VPN_IPV6=off)
export WIREGUARD_ADDRESSES=$(echo "$WIREGUARD_ADDRESS" | cut -d',' -f1)
# Unset WIREGUARD_ADDRESS so gluetun doesn't also try to use IPv6 from it
unset WIREGUARD_ADDRESS

echo "  endpoint: ${WIREGUARD_ENDPOINT_IP}:${WIREGUARD_ENDPOINT_PORT}"
echo "  public_key: ${WIREGUARD_PUBLIC_KEY:0:20}..."
echo "  address: ${WIREGUARD_ADDRESSES}"

# Hand off to gluetun entrypoint
exec /gluetun-entrypoint
