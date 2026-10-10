#!/bin/bash

# Tunnel R.A.T. Installer Script
# Automated setup for NanoPi Zero2 (Armbian)

set -e  # Exit on error

echo "==============================================="
echo "Tunnel R.A.T. - Installer"
echo "==============================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    echo "Run: sudo bash install-tunnel-rat.sh"
    exit 1
fi

echo "[1/6] Updating system packages..."
apt update
apt upgrade -y

echo "[2/6] Installing dependencies..."
apt install -y \
    git \
    golang-go \
    libpcap-dev \
    libnetfilter-queue-dev \
    libusb-1.0-0-dev \
    nmap \
    dnsmasq \
    tcpdump \
    openssh-server \
    build-essential

echo "[3/6] Creating project directory..."
mkdir -p /opt/tunnel-rat/{scripts,config,caplets,captures,docs}
cd /opt/tunnel-rat

echo "[4/6] Compiling Bettercap from source..."
if [ ! -d "bettercap" ]; then
    git clone https://github.com/bettercap/bettercap.git
fi
cd bettercap
go build -o /usr/local/bin/bettercap .
cd /opt/tunnel-rat

echo "[5/6] Setting permissions..."
chmod +x /opt/tunnel-rat/scripts/*.sh
chmod 755 /opt/tunnel-rat

echo "[6/6] Verifying installation..."
bettercap -v

echo ""
echo "==============================================="
echo "✓ Installation complete!"
echo "==============================================="
echo ""
echo "Next steps:"
echo "1. Copy config files to /opt/tunnel-rat/config/"
echo "2. Copy caplets to /opt/tunnel-rat/caplets/"
echo "3. Start Tunnel R.A.T:"
echo "   sudo /opt/tunnel-rat/scripts/tunnel-rat.sh"
echo ""
