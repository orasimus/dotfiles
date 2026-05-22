usage() {
    cat <<'EOF'
Usage:
  vpn-hop                 Show current peer, handshake age, and exit IP.
  vpn-hop <country-code>  Switch to lowest-load server in that country.
                          country-code: 2-letter ISO code (fi, us, gb, jp, ...)
  vpn-hop reset           Restart wg-quick-nordlynx (reverts to declared peer).
EOF
}

show_status() {
    echo "=== wg show nordlynx ==="
    sudo wg show nordlynx
    echo
    echo "=== exit IP ==="
    curl -sS --max-time 10 https://ipv4.icanhazip.com || echo "(check failed)"
}

wait_for_handshake() {
    local n hsage
    for n in 1 2 3 4 5; do
        sleep 1
        hsage=$(sudo wg show nordlynx latest-handshakes | awk 'NR==1 {print $2}')
        if [ -n "$hsage" ] && [ "$hsage" -gt 0 ]; then
            echo "Handshake established after $n s."
            curl -sS --max-time 10 https://ipv4.icanhazip.com || true
            return 0
        fi
    done
    echo "No handshake after 5s. Run 'sudo wg show nordlynx' to diagnose." >&2
    return 1
}

if [ $# -eq 0 ]; then
    show_status
    exit 0
fi

case "$1" in
    -h|--help|help) usage; exit 0 ;;
    reset)
        echo "Restarting wg-quick-nordlynx..."
        sudo systemctl restart wg-quick-nordlynx
        wait_for_handshake
        exit $?
        ;;
esac

code=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
if ! [[ "$code" =~ ^[A-Z][A-Z]$ ]]; then
    echo "Expected a 2-letter country code (got '$1')." >&2
    usage >&2
    exit 2
fi

if ! ip link show nordlynx >/dev/null 2>&1; then
    echo "nordlynx interface not present. Run: sudo systemctl start wg-quick-nordlynx" >&2
    exit 1
fi

country_id=$(curl -fsS --max-time 10 \
    'https://api.nordvpn.com/v1/servers/countries' \
    | jq --arg code "$code" -r '.[] | select(.code == $code) | .id' \
    | head -n1)
if [ -z "$country_id" ]; then
    echo "Unknown country code: $code" >&2
    exit 1
fi

rec=$(curl -fsS --max-time 10 \
    "https://api.nordvpn.com/v1/servers/recommendations?filters%5Bcountry_id%5D=$country_id&filters%5Bservers_technologies%5D%5Bidentifier%5D=wireguard_udp&limit=1")

endpoint=$(printf '%s' "$rec" | jq -r '.[0].station')
hostname=$(printf '%s' "$rec" | jq -r '.[0].hostname')
load=$(printf '%s' "$rec" | jq -r '.[0].load')
pubkey=$(printf '%s' "$rec" | jq -r '.[0].technologies[] | select(.identifier=="wireguard_udp") | .metadata[] | select(.name=="public_key") | .value')

if [ -z "$endpoint" ] || [ "$endpoint" = "null" ] || [ -z "$pubkey" ] || [ "$pubkey" = "null" ]; then
    echo "API returned no usable server for $code." >&2
    exit 1
fi

old_peer=$(sudo wg show nordlynx peers | head -n1 || true)

echo "Switching to $hostname ($endpoint, load $load%)..."

sudo wg set nordlynx peer "$pubkey" \
    allowed-ips 0.0.0.0/0,::/0 \
    endpoint "$endpoint:$NORDLYNX_PORT" \
    persistent-keepalive 25

if [ -n "$old_peer" ] && [ "$old_peer" != "$pubkey" ]; then
    sudo wg set nordlynx peer "$old_peer" remove
fi

wait_for_handshake
