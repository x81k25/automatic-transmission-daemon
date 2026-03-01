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
SERVER_NAME="$(echo "$WIREGUARD_SERVERS" | jq -r 'keys[]' | shuf -n1)"
echo "Selected WireGuard server: $SERVER_NAME"

# Extract server details
WIREGUARD_PUBLIC_KEY="$(echo "$WIREGUARD_SERVERS" | jq -r --arg s "$SERVER_NAME" '.[$s].public_key')"
export WIREGUARD_PUBLIC_KEY
WIREGUARD_ENDPOINT_IP="$(echo "$WIREGUARD_SERVERS" | jq -r --arg s "$SERVER_NAME" '.[$s].endpoint | split(":")[0]')"
export WIREGUARD_ENDPOINT_IP
WIREGUARD_ENDPOINT_PORT="$(echo "$WIREGUARD_SERVERS" | jq -r --arg s "$SERVER_NAME" '.[$s].endpoint | split(":")[1]')"
export WIREGUARD_ENDPOINT_PORT

# Extract IPv4-only values (gluetun expects IPv4 when VPN_IPV6=off)
WIREGUARD_ADDRESSES="$(echo "$WIREGUARD_ADDRESS" | cut -d',' -f1)"
export WIREGUARD_ADDRESSES
unset WIREGUARD_ADDRESS
# Strip IPv6 from allowed IPs if present
WIREGUARD_ALLOWED_IPS="$(echo "$WIREGUARD_ALLOWED_IPS" | sed 's/,::0\/0//' | sed 's/,::\///')"
export WIREGUARD_ALLOWED_IPS

echo "  endpoint: ${WIREGUARD_ENDPOINT_IP}:${WIREGUARD_ENDPOINT_PORT}"
echo "  public_key: $(echo "$WIREGUARD_PUBLIC_KEY" | cut -c1-20)..."
echo "  address: ${WIREGUARD_ADDRESSES}"

# Hand off to gluetun entrypoint
exec /gluetun-entrypoint
