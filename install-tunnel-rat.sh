#!/usr/bin/env bash
#
# Tunnel R.A.T. — NanoPi Zero2 network security & testing platform
# Installer / restore script for a fresh Armbian (Debian) flash.
#
# Tunnel R.A.T. is a self-contained toolkit for learning network security
# and for running assessments on networks you own or are explicitly
# authorized to test (home lab, your own equipment, written-permission
# engagements). See AUTHORIZED USE in the README before you run it.
#
# ---------------------------------------------------------------------------
# USAGE
#
#   One command (does everything, in order):
#       sudo ./install-tunnel-rat.sh
#       sudo ./install-tunnel-rat.sh all
#
#   Or run it in stages, so a failed step is easy to re-run on its own
#   without repeating the whole thing:
#       sudo ./install-tunnel-rat.sh base         # 1. core + base tooling
#       sudo ./install-tunnel-rat.sh defense      # 2. monitoring / blue team
#       sudo ./install-tunnel-rat.sh offense      # 3. assessment tooling
#       sudo ./install-tunnel-rat.sh recon        # 4. recon / OSINT / wireless
#       sudo ./install-tunnel-rat.sh dashboard    # 5. web dashboard
#
#   Stages are idempotent: finished stages are marked and skipped on a
#   re-run, so you can safely re-run `all` to resume after a failure.
#       sudo ./install-tunnel-rat.sh status       # show what is done
#       sudo FORCE=1 ./install-tunnel-rat.sh base # re-run a done stage
# ---------------------------------------------------------------------------

set -Eeuo pipefail

DEVICE="Tunnel R.A.T. (NanoPi Zero2)"
INSTALL_ROOT="/opt/tunnel-rat"
STATE_DIR="${INSTALL_ROOT}/.install-state"
LOG_FILE="/var/log/tunnel-rat-install.log"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- pretty output --------------------------------------------------------
c_reset=$'\e[0m'; c_grn=$'\e[32m'; c_cyn=$'\e[36m'; c_yel=$'\e[33m'; c_red=$'\e[31m'
log()  { echo "${c_cyn}[*]${c_reset} $*" | tee -a "$LOG_FILE" >&2; }
ok()   { echo "${c_grn}[✓]${c_reset} $*" | tee -a "$LOG_FILE" >&2; }
warn() { echo "${c_yel}[!]${c_reset} $*" | tee -a "$LOG_FILE" >&2; }
die()  { echo "${c_red}[x]${c_reset} $*" | tee -a "$LOG_FILE" >&2; exit 1; }

on_err() {
  local stage="${CURRENT_STAGE:-?}"
  echo >&2
  warn "Stage '${stage}' did not finish. Nothing destructive was done."
  warn "Fix the issue above, then re-run just this stage:"
  echo  "    sudo ./install-tunnel-rat.sh ${stage}" >&2
  warn "Full log: ${LOG_FILE}"
}
trap on_err ERR

[ "${EUID}" -eq 0 ] || die "Run as root:  sudo ./install-tunnel-rat.sh"

mkdir -p "$INSTALL_ROOT" "$STATE_DIR" "$INSTALL_ROOT"/{scripts,config,caplets,captures,logs,docs}
touch "$LOG_FILE"
echo "===== $(date -u +%FT%TZ)  install run: ${*:-all} =====" >>"$LOG_FILE"

stage_done() { [ -f "${STATE_DIR}/$1.done" ] && [ -z "${FORCE:-}" ]; }
mark_done()  { date -u +%FT%TZ >"${STATE_DIR}/$1.done"; ok "Stage '$1' complete."; }

# apt helpers: install what exists, warn (don't abort) on packages the
# running release doesn't carry, so one missing package never kills a stage.
APT_UPDATED=0
apt_refresh() { [ "$APT_UPDATED" -eq 1 ] || { log "Refreshing package lists…"; apt-get update -y >>"$LOG_FILE" 2>&1; APT_UPDATED=1; }; }
apt_try() {
  apt_refresh
  local pkg
  for pkg in "$@"; do
    if apt-get install -y --no-install-recommends "$pkg" >>"$LOG_FILE" 2>&1; then
      ok "installed ${pkg}"
    else
      warn "package '${pkg}' not available on this release — skipped (install manually if you need it)"
    fi
  done
}
pip_try() {
  local pkg
  for pkg in "$@"; do
    if pip3 install --break-system-packages --quiet "$pkg" >>"$LOG_FILE" 2>&1; then
      ok "pip ${pkg}"
    else
      warn "pip package '${pkg}' failed — skipped"
    fi
  done
}

# ===========================================================================
# STAGE: base  — core system + base networking/assessment tooling + Bettercap
# ===========================================================================
stage_base() {
  CURRENT_STAGE=base
  stage_done base && { ok "base already done (FORCE=1 to redo)"; return 0; }

  log "Updating base system…"
  apt_refresh
  apt-get upgrade -y >>"$LOG_FILE" 2>&1 || warn "upgrade had warnings (continuing)"

  log "Installing build tools and libraries…"
  apt_try git curl wget ca-certificates build-essential pkg-config \
          golang-go libpcap-dev libnetfilter-queue-dev libusb-1.0-0-dev \
          python3 python3-pip python3-venv

  log "Installing base networking / capture tools…"
  apt_try nmap tcpdump tshark dnsutils dnsmasq hostapd iproute2 net-tools \
          wireless-tools iw macchanger openssh-server \
          wireguard wireguard-tools openvpn openssl \
          zip unzip xz-utils jq cron

  log "Building Bettercap from source…"
  if command -v bettercap >/dev/null 2>&1; then
    ok "bettercap already present ($(bettercap -version 2>/dev/null | head -n1 || echo installed))"
  else
    local b="${INSTALL_ROOT}/src/bettercap"
    mkdir -p "${INSTALL_ROOT}/src"
    [ -d "$b" ] || git clone --depth 1 https://github.com/bettercap/bettercap.git "$b" >>"$LOG_FILE" 2>&1
    ( cd "$b" && go build -o /usr/local/bin/bettercap . ) >>"$LOG_FILE" 2>&1 \
      && ok "bettercap built -> /usr/local/bin/bettercap" \
      || warn "bettercap build failed — see ${LOG_FILE}; you can retry 'base' later"
  fi

  log "Installing project files and config…"
  install -m 0644 "${REPO_DIR}/tunnel-rat.conf" "${INSTALL_ROOT}/config/tunnel-rat.conf" 2>/dev/null || true
  install -m 0644 "${REPO_DIR}/tunnel-rat.cap"  "${INSTALL_ROOT}/caplets/tunnel-rat.cap"  2>/dev/null || true
  install -m 0755 "${REPO_DIR}/tunnel-rat.sh"   "${INSTALL_ROOT}/scripts/tunnel-rat.sh"   2>/dev/null || true
  chown -R root:root "$INSTALL_ROOT"

  install_banner
  mark_done base
}

# Login banner / MOTD — cosmetic, identifies the device on SSH login.
install_banner() {
  cat >/etc/update-motd.d/00-tunnel-rat <<'MOTD'
#!/bin/sh
printf '\033[32m'
cat <<'ART'
  _____                       _   ___   _  _____
 |_   _|  _ _ _  _ _  ___ _ | | | _ \ /_\|_   _|
   | || || | ' \| ' \/ -_) || | |   // _ \ | |
   |_| \_,_|_||_|_||_\___|_||_| |_|_\/_/ \_\|_|
ART
printf '\033[0m'
echo " Tunnel R.A.T. — authorized network testing platform"
echo " Use only on networks you own or are permitted to test."
echo
MOTD
  chmod +x /etc/update-motd.d/00-tunnel-rat
  ok "login banner installed"
}

# ===========================================================================
# STAGE: defense — monitoring / detection / blue-team tooling
# ===========================================================================
stage_defense() {
  CURRENT_STAGE=defense
  stage_done defense && { ok "defense already done"; return 0; }
  log "Installing monitoring / detection tools…"
  apt_try suricata clamav clamav-daemon fail2ban ufw rkhunter chkrootkit \
          zeek ntopng
  # Keep ClamAV signatures current (don't fail the stage if offline).
  freshclam >>"$LOG_FILE" 2>&1 || warn "freshclam skipped (offline?) — run it later"
  mark_done defense
}

# ===========================================================================
# STAGE: offense — assessment tooling for authorized testing
# ===========================================================================
stage_offense() {
  CURRENT_STAGE=offense
  stage_done offense && { ok "offense already done"; return 0; }
  log "Installing assessment / analysis tools…"
  apt_try aircrack-ng hcxtools hcxdumptool hashcat yara ettercap-text-only \
          mitmproxy responder
  # mitmproxy / Responder fall back to pip / git if not packaged.
  command -v mitmproxy >/dev/null 2>&1 || pip_try mitmproxy
  if ! command -v responder >/dev/null 2>&1 && [ ! -d "${INSTALL_ROOT}/src/Responder" ]; then
    git clone --depth 1 https://github.com/lgandx/Responder.git \
      "${INSTALL_ROOT}/src/Responder" >>"$LOG_FILE" 2>&1 \
      && ok "Responder cloned to ${INSTALL_ROOT}/src/Responder" \
      || warn "Responder clone skipped"
  fi
  mark_done offense
}

# ===========================================================================
# STAGE: recon — discovery / OSINT / wireless survey
# ===========================================================================
stage_recon() {
  CURRENT_STAGE=recon
  stage_done recon && { ok "recon already done"; return 0; }
  log "Installing recon / wireless / OSINT tools…"
  apt_try kismet wifite reaver bully whatweb theharvester \
          gpsd gpsd-clients rtl-sdr
  mark_done recon
}

# ===========================================================================
# STAGE: dashboard — Flask web dashboard + service + generated password
# ===========================================================================
stage_dashboard() {
  CURRENT_STAGE=dashboard
  stage_done dashboard && { ok "dashboard already done"; return 0; }

  log "Installing dashboard dependencies…"
  apt_try python3 python3-pip
  pip_try flask psutil requests

  install -m 0644 "${REPO_DIR}/tunnel-rat-dashboard.py" \
          "${INSTALL_ROOT}/tunnel-rat-dashboard.py" \
    || die "tunnel-rat-dashboard.py not found next to the installer"

  # Generate a one-time admin password if the operator hasn't set one.
  local conf="${INSTALL_ROOT}/config/dashboard.conf"
  if [ ! -f "$conf" ]; then
    local pw; pw="$(head -c 12 /dev/urandom | base64 | tr -d '/+=' | head -c 16)"
    cat >"$conf" <<EOF
# Tunnel R.A.T. dashboard — edit then restart: systemctl restart tunnel-rat-dashboard
DASHBOARD_USER=admin
DASHBOARD_PASSWORD=${pw}
DASHBOARD_PORT=8080
EOF
    chmod 600 "$conf"
    DASH_PW="$pw"
  fi

  cat >/etc/systemd/system/tunnel-rat-dashboard.service <<EOF
[Unit]
Description=Tunnel R.A.T. Dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_ROOT}
EnvironmentFile=${INSTALL_ROOT}/config/dashboard.conf
ExecStart=/usr/bin/python3 ${INSTALL_ROOT}/tunnel-rat-dashboard.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now tunnel-rat-dashboard.service >>"$LOG_FILE" 2>&1 \
    && ok "dashboard service started" \
    || warn "dashboard service failed to start — check: journalctl -u tunnel-rat-dashboard"
  mark_done dashboard
}

print_summary() {
  local ip; ip="$(ip -4 addr show scope global 2>/dev/null | awk '/inet/{print $2}' | cut -d/ -f1 | head -n1)"
  echo
  ok "${DEVICE} setup finished."
  echo "    Dashboard:  http://${ip:-<device-ip>}:${DASHBOARD_PORT:-8080}"
  [ -n "${DASH_PW:-}" ] && echo "    Login:      admin / ${DASH_PW}   (saved in ${INSTALL_ROOT}/config/dashboard.conf)"
  echo "    Launcher:   sudo ${INSTALL_ROOT}/scripts/tunnel-rat.sh"
  echo "    Reminder:   use only on networks you own or are authorized to test."
  echo
}

show_status() {
  echo "Install state for ${DEVICE}:"
  for s in base defense offense recon dashboard; do
    if [ -f "${STATE_DIR}/${s}.done" ]; then
      echo "  ${c_grn}done${c_reset}    ${s}  ($(cat "${STATE_DIR}/${s}.done"))"
    else
      echo "  ${c_yel}pending${c_reset} ${s}"
    fi
  done
}

main() {
  case "${1:-all}" in
    base)      stage_base ;;
    defense)   stage_defense ;;
    offense)   stage_offense ;;
    recon)     stage_recon ;;
    dashboard) stage_dashboard; print_summary ;;
    status)    show_status ;;
    all|full)
      stage_base
      stage_defense
      stage_offense
      stage_recon
      stage_dashboard
      print_summary
      ;;
    *) die "Unknown stage '$1'. Use: all | base | defense | offense | recon | dashboard | status" ;;
  esac
}
main "$@"
