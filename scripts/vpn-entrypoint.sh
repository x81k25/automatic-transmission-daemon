#!/bin/bash
set -e

CONFIG_FILE="/etc/wireguard/wg0.conf"

# Validate required environment variables
echo "Validating WireGuard configuration..."
required_vars=(
    "WIREGUARD_PRIVATE_KEY"
    "WIREGUARD_ADDRESS"
    "WIREGUARD_PUBLIC_KEY"
    "WIREGUARD_ENDPOINT"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "ERROR: Required environment variable $var is not set"
        exit 1
    fi
done

# Create WireGuard config directory
mkdir -p /etc/wireguard

# Generate WireGuard configuration from environment variables
echo "Generating WireGuard configuration..."
cat > "${CONFIG_FILE}" << EOF
[Interface]
PrivateKey = ${WIREGUARD_PRIVATE_KEY}

[Peer]
PublicKey = ${WIREGUARD_PUBLIC_KEY}
AllowedIPs = ${WIREGUARD_ALLOWED_IPS:-0.0.0.0/0,::/0}
Endpoint = ${WIREGUARD_ENDPOINT}
PersistentKeepalive = 25
EOF

chmod 600 "${CONFIG_FILE}"

# Set DNS servers
echo "Setting DNS servers..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Start DNS monitor in background
echo "Starting DNS configuration monitor..."
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

    # Allow WireGuard UDP traffic
    iptables -A OUTPUT -p udp --dport 51820 -j ACCEPT

    # Allow all incoming traffic to port 9091 regardless of interface
    iptables -I INPUT -p tcp --dport 9091 -j ACCEPT

    # Allow all outgoing traffic from port 9091
    iptables -I OUTPUT -p tcp --sport 9091 -j ACCEPT

    # Ensure the traffic can flow through any filtering chains
    iptables -I FORWARD -p tcp --dport 9091 -j ACCEPT
    iptables -I FORWARD -p tcp --sport 9091 -j ACCEPT

    echo "iptables forwarding rules have been set up"
}

# Start WireGuard manually (without wg-quick to avoid resolvconf issues)
start_wireguard() {
    echo "Starting WireGuard..."

    # Create the WireGuard interface
    ip link add wg0 type wireguard

    # Apply the configuration
    wg setconf wg0 "${CONFIG_FILE}"

    # Parse and add addresses
    IFS=',' read -ra ADDRESSES <<< "${WIREGUARD_ADDRESS}"
    for addr in "${ADDRESSES[@]}"; do
        addr=$(echo "$addr" | xargs)  # trim whitespace
        if [[ "$addr" == *":"* ]]; then
            # IPv6 address
            ip -6 address add "$addr" dev wg0
        else
            # IPv4 address
            ip -4 address add "$addr" dev wg0
        fi
    done

    # Bring up the interface
    ip link set mtu 1420 up dev wg0

    # Add default route through WireGuard
    # First, save the current default gateway for VPN endpoint routing
    DEFAULT_GW=$(ip route | grep default | head -1 | awk '{print $3}')
    DEFAULT_IF=$(ip route | grep default | head -1 | awk '{print $5}')
    ENDPOINT_IP=$(echo "${WIREGUARD_ENDPOINT}" | cut -d: -f1)

    echo "Default gateway: $DEFAULT_GW via $DEFAULT_IF"
    echo "VPN endpoint: $ENDPOINT_IP"

    # Add route to VPN endpoint via original gateway
    ip route add "$ENDPOINT_IP" via "$DEFAULT_GW" dev "$DEFAULT_IF" 2>/dev/null || true

    # Add route for local network to bypass VPN
    ip route add 192.168.50.0/24 via "$DEFAULT_GW" dev "$DEFAULT_IF" 2>/dev/null || echo "Local bypass route may already exist"

    # Replace default route with WireGuard
    ip route del default 2>/dev/null || true
    ip route add default dev wg0

    # Verify connection
    echo "Waiting for WireGuard connection..."
    sleep 3

    if ip link show wg0 >/dev/null 2>&1; then
        echo "WireGuard interface is up!"

        # Show connection info
        echo "WireGuard status:"
        wg show wg0

        # Set up masquerading for WireGuard interface
        iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE

        # Allow traffic through WireGuard
        iptables -A INPUT -i wg0 -j ACCEPT
        iptables -A OUTPUT -o wg0 -j ACCEPT

        echo "VPN connection established successfully!"

        # Verify external IP
        echo "Checking external IP..."
        EXT_IP=$(curl -s --connect-timeout 10 https://api.ipify.org || echo "Could not determine")
        echo "External IP: $EXT_IP"

        # Keep the container running
        echo "WireGuard is running. Monitoring connection..."
        while true; do
            if ! ip link show wg0 >/dev/null 2>&1; then
                echo "WireGuard interface down! Exiting..."
                exit 1
            fi
            sleep 30
        done
    else
        echo "ERROR: WireGuard interface failed to come up!"
        exit 1
    fi
}

# Main execution
setup_forwarding
start_wireguard
