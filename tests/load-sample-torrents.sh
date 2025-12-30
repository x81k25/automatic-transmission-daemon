#!/bin/bash
# Load sample magnet links into local transmission instance

set -euo pipefail

TRANSMISSION_HOST="${TRANSMISSION_HOST:-localhost}"
TRANSMISSION_PORT="${TRANSMISSION_PORT:-9091}"
TRANSMISSION_URL="http://${TRANSMISSION_HOST}:${TRANSMISSION_PORT}/transmission/rpc"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# Get session ID (required for transmission RPC)
get_session_id() {
    curl -s -i "$TRANSMISSION_URL" 2>/dev/null | grep -i "X-Transmission-Session-Id:" | head -1 | cut -d: -f2 | tr -d ' \r\n'
}

main() {
    echo "========================================"
    echo "  Load Sample Torrents"
    echo "========================================"
    echo ""

    # Check transmission is accessible
    log_info "Connecting to transmission at $TRANSMISSION_URL"

    local session_id
    session_id=$(get_session_id)
    if [[ -z "$session_id" ]]; then
        log_fail "Could not get session ID - is transmission running?"
        exit 1
    fi
    log_ok "Connected (session: ${session_id:0:8}...)"
    echo ""

    # Define magnets in python to avoid shell escaping issues
    log_info "Adding torrents via python..."
    echo ""

    python3 << PYEOF
import json
import urllib.request
import urllib.error

url = "$TRANSMISSION_URL"
session_id = "$session_id"

magnets = [
    ("Zootopia 2 2025", "magnet:?xt=urn:btih:D745D479E6CD56D5F7DDB2F35970EF7FE1311788&dn=Zootopia+2+2025"),
    ("Pluribus S01E09", "magnet:?xt=urn:btih:8391B1CE79FEE52DB93D80E7C992949111DB3D36&dn=Pluribus.S01E09"),
    ("Jackie Brown 1997", "magnet:?xt=urn:btih:993DDE46D2F0210D5D5E9F195CBB6C069039C093&dn=Jackie+Brown+1997"),
]

added = 0
for name, magnet in magnets:
    print(f"\033[0;34m[INFO]\033[0m Adding: {name}")

    payload = json.dumps({
        "method": "torrent-add",
        "arguments": {"filename": magnet}
    }).encode('utf-8')

    req = urllib.request.Request(url, data=payload, method='POST')
    req.add_header('X-Transmission-Session-Id', session_id)
    req.add_header('Content-Type', 'application/json')

    try:
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read().decode('utf-8'))
            if result.get('result') == 'success':
                if 'torrent-added' in result.get('arguments', {}):
                    print(f"\033[0;32m[OK]\033[0m   Added successfully")
                    added += 1
                elif 'torrent-duplicate' in result.get('arguments', {}):
                    print(f"\033[0;32m[OK]\033[0m   Already exists (skipped)")
                    added += 1
            else:
                print(f"\033[0;31m[FAIL]\033[0m   {result}")
    except urllib.error.HTTPError as e:
        print(f"\033[0;31m[FAIL]\033[0m   HTTP {e.code}: {e.reason}")
    except Exception as e:
        print(f"\033[0;31m[FAIL]\033[0m   {e}")

print()
print(f"\033[0;34m[INFO]\033[0m Added {added}/{len(magnets)} torrents")
print()

# List current torrents
print("\033[0;34m[INFO]\033[0m Current torrents:")
payload = json.dumps({
    "method": "torrent-get",
    "arguments": {"fields": ["id", "name", "status", "percentDone"]}
}).encode('utf-8')

req = urllib.request.Request(url, data=payload, method='POST')
req.add_header('X-Transmission-Session-Id', session_id)
req.add_header('Content-Type', 'application/json')

try:
    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read().decode('utf-8'))
        torrents = result.get('arguments', {}).get('torrents', [])
        if not torrents:
            print("  No torrents")
        else:
            status_map = {0: 'Stopped', 1: 'Check Wait', 2: 'Checking', 3: 'DL Wait', 4: 'Downloading', 5: 'Seed Wait', 6: 'Seeding'}
            for t in torrents:
                status = status_map.get(t.get('status', 0), 'Unknown')
                pct = t.get('percentDone', 0) * 100
                name = t.get('name', 'unknown')[:50]
                print(f"  [{t['id']}] {name:<50} {pct:5.1f}% {status}")
except Exception as e:
    print(f"  Error: {e}")

PYEOF

    echo ""
    log_info "VPN IP check:"
    local vpn_ip
    vpn_ip=$(docker exec gluetun wget -q -O- https://ipinfo.io/ip 2>/dev/null || echo "unknown")
    log_ok "  Public IP: $vpn_ip"
}

main "$@"
