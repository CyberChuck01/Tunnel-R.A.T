#!/usr/bin/env bash
#
# Tunnel R.A.T. — launcher
# Starts Bettercap against the interface/scope defined in tunnel-rat.conf.
# For authorized testing only: run this only on networks you own or are
# explicitly permitted to assess.

set -euo pipefail

ROOT="/opt/tunnel-rat"
CONF="${ROOT}/config/tunnel-rat.conf"
CAPLET="${ROOT}/caplets/tunnel-rat.cap"

# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF"

echo "=========================================="
echo " Tunnel R.A.T. — authorized network testing"
echo "=========================================="
echo " Scope (from config): ${TEST_SCOPE:-unset}"
echo " Run only on networks you own or are permitted to test."
echo

[ "${EUID}" -eq 0 ] || { echo "Run as root:  sudo $0"; exit 1; }

command -v bettercap >/dev/null 2>&1 || {
  echo "Bettercap not found. Run the installer first:"
  echo "  sudo ./install-tunnel-rat.sh base"
  exit 1
}

# Pick the interface: config value, else the default-route interface, else eth0.
IFACE="${INTERFACE:-}"
if [ -z "$IFACE" ]; then
  IFACE="$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')"
fi
IFACE="${IFACE:-eth0}"
echo "Using interface: ${IFACE}"
echo

mkdir -p "${CAPTURE_DIR:-$ROOT/captures}" "${LOG_DIR:-$ROOT/logs}"

if [ -f "$CAPLET" ]; then
  exec bettercap -iface "$IFACE" -caplet "$CAPLET"
else
  exec bettercap -iface "$IFACE"
fi
