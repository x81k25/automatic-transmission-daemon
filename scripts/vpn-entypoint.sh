#!/bin/bash
set -e

# Enable IP forwarding at runtime
sysctl -w net.ipv4.ip_forward=1

# Start OpenVPN
echo "Starting OpenVPN..."
openvpn --config /etc/openvpn/config.ovpn --auth-user-pass /etc/openvpn/auth.txt &

# Wait for VPN to connect
while ! ip link show tun0 >/dev/null 2>&1; do
  echo "Waiting for VPN connection..."
  sleep 2
done

echo "VPN connection established"

# Keep container running
echo "VPN Gateway is running"
tail -f /dev/null