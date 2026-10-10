#!/bin/bash

# Tunnel R.A.T. - Main Startup Script
# Starts Bettercap with MITM configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUNNEL_RAT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$TUNNEL_RAT_DIR/config"
CAPLETS_DIR="$TUNNEL_RAT_DIR/caplets"
CAPTURES_DIR="$TUNNEL_RAT_DIR/captures"

# Create captures directory if it doesn't exist
mkdir -p "$CAPTURES_DIR"

echo "=========================================="
echo "Tunnel R.A.T. - Starting MITM Service"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Config Dir: $CONFIG_DIR"
echo "  Caplets Dir: $CAPLETS_DIR"
echo "  Captures Dir: $CAPTURES_DIR"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    echo "Run: sudo $0"
    exit 1
fi

# Check if Bettercap is installed
if ! command -v bettercap &> /dev/null; then
    echo "Error: Bettercap not found. Run installer first:"
    echo "  sudo bash install-tunnel-rat.sh"
    exit 1
fi

# Verify Bettercap can run
bettercap -v

echo ""
echo "=========================================="
echo "Starting Bettercap interactive mode..."
echo "=========================================="
echo ""
echo "Common commands:"
echo "  set arp.spoof.targets 192.168.1.100"
echo "  arp.spoof on"
echo "  dns.spoof on"
echo "  http.proxy on"
echo "  exit (to quit)"
echo ""

# Start Bettercap in interactive mode with default interface
# Automatically detect primary network interface
INTERFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)

if [ -z "$INTERFACE" ]; then
    echo "Could not detect network interface. Using eth0."
    INTERFACE="eth0"
fi

echo "Using interface: $INTERFACE"
echo ""

# Start Bettercap
sudo bettercap -iface "$INTERFACE"
