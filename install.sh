#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PJSIP_CONF="$REPO_DIR/config/pjsip.conf"

echo
echo "Riedel Lab SIP Server - Basic Install"
echo "====================================="
echo

if ! command -v apt-get >/dev/null 2>&1; then
    echo "ERROR: This installer currently supports Debian/Ubuntu systems."
    exit 1
fi

echo "Installing Asterisk..."
sudo apt-get update
sudo apt-get install -y asterisk

echo
echo "Available IPv4 interfaces:"
echo

mapfile -t INTERFACES < <(
    ip -o -4 addr show scope global |
    awk '{split($4,a,"/"); print $2 "|" a[1]}'
)

if [[ ${#INTERFACES[@]} -eq 0 ]]; then
    echo "ERROR: No IPv4 interfaces found."
    exit 1
fi

for i in "${!INTERFACES[@]}"; do
    IFS='|' read -r IFACE IP <<< "${INTERFACES[$i]}"
    printf "  %d) %-15s %s\n" "$((i+1))" "$IFACE" "$IP"
done

echo
read -rp "Select SIP interface [1]: " SELECTION
SELECTION="${SELECTION:-1}"

if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] ||
   (( SELECTION < 1 || SELECTION > ${#INTERFACES[@]} )); then
    echo "ERROR: Invalid interface selection."
    exit 1
fi

IFS='|' read -r SIP_INTERFACE SIP_IP <<< "${INTERFACES[$((SELECTION-1))]}"

echo
echo "Selected:"
echo "  Interface: $SIP_INTERFACE"
echo "  SIP IP:    $SIP_IP"
echo "  SIP Port:  5060"
echo

if [[ ! -f "$PJSIP_CONF" ]]; then
    echo "WARNING: $PJSIP_CONF not found."
    echo "Asterisk was installed, but the PJSIP bind address was not updated."
    exit 0
fi

read -rp "Update config/pjsip.conf bind address to ${SIP_IP}:5060? [Y/n]: " CONFIRM
CONFIRM="${CONFIRM:-Y}"

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    sed -i -E \
        "s|^bind=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:5060$|bind=${SIP_IP}:5060|" \
        "$PJSIP_CONF"

    echo
    echo "Updated:"
    grep '^bind=' "$PJSIP_CONF"
else
    echo "Bind address left unchanged."
fi

echo
echo "Basic installation complete."
echo
echo "Next steps:"
echo "  Follow README.md for Asterisk/PJSIP deployment."
echo "  Follow G2.md for Artist G2 VoIP-108 configuration."
