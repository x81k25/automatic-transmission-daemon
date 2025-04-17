#!/bin/bash
set -e

# Setup paths
CONFIG_DIR="/etc/openvpn/sensitive"
CONFIG_FILE="/etc/openvpn/config.ovpn"
CREDS_PATH="${CONFIG_DIR}/creds.txt"

# Make sure the directory exists
mkdir -p ${CONFIG_DIR}

# Write credentials from environment variables
echo "Setting up VPN credentials from environment variables"
echo "$VPN_USERNAME" > "${CREDS_PATH}"
echo "$VPN_PASSWORD" >> "${CREDS_PATH}"

# Write config from environment variable
echo "Writing VPN config from environment variable"
echo "$VPN_CONFIG" > "${CONFIG_FILE}"

# Set DNS servers
echo "Setting DNS servers"
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Start DNS monitor in background
echo "Starting DNS configuration monitor"
(
  while true; do
    if ! grep -q "nameserver 8.8.8.8" /etc/resolv.conf; then
      echo "Resetting resolv.conf..."
      echo "nameserver 8.8.8.8" > /etc/resolv.conf
      echo "nameserver 8.8.4.4" >> /etc/resolv.conf
    fi
    sleep 5
  done
) &

# Setup iptables for forwarding
setup_forwarding() {
  # Enable IP forwarding at runtime
  sysctl -w net.ipv4.ip_forward=1 || echo "Could not set IP forwarding, but continuing anyway"
  
  # Clear existing rules
  iptables -F
  iptables -t nat -F
  
  # Allow established connections
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  
  # Allow loopback
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A OUTPUT -o lo -j ACCEPT
  
  # Allow DNS
  iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
  
  # Allow OpenVPN (to both common ports and the one from your logs)
  iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT
  iptables -A OUTPUT -p udp --dport 1195 -j ACCEPT
  iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
  
  # Allow specifically to the VPN server IP from logs
  iptables -A OUTPUT -d 45.80.159.182 -j ACCEPT
  
  echo "iptables forwarding rules have been set up"
}

# Start OpenVPN
start_openvpn() {
  echo "Starting OpenVPN..."
  openvpn --config "${CONFIG_FILE}" --auth-user-pass "${CREDS_PATH}" &
  VPN_PID=$!
  
  # Wait for VPN to connect
  echo "Waiting for VPN connection..."
  for i in {1..30}; do
    if ip link show tun0 >/dev/null 2>&1; then
      echo "VPN connection established!"
      
      # Get the VPN interface
      VPN_INTERFACE="tun0"
      
      # Set up masquerading once connected
      iptables -t nat -A POSTROUTING -o $VPN_INTERFACE -j MASQUERADE
      
      # Allow traffic through VPN
      iptables -A INPUT -i $VPN_INTERFACE -j ACCEPT
      iptables -A OUTPUT -o $VPN_INTERFACE -j ACCEPT
      
      # Keep the script running
      wait $VPN_PID
      return 0
    fi
    sleep 2
  done
  
  echo "VPN connection failed after 60 seconds!"
  exit 1
}

# Main execution
setup_forwarding
start_openvpn