#!/usr/bin/env bash
#
# build-tunnel-rat-image.sh
# Bake a ready-to-flash Tunnel R.A.T. image for the NanoPi Zero2 from a stock
# Armbian image, so end users can download ONE file and flash it — no installer
# run, no imaging app required (flash with dd or ./flash-tunnel-rat.sh).
#
# It does NOT rebuild an OS. It takes a stock Armbian image you downloaded,
# drops the Tunnel R.A.T. files in, and adds a one-time "first boot" service
# that runs the installer automatically the first time the device boots online.
#
# Run this on a Linux PC (or the NanoPi itself) with root:
#   sudo ./build-tunnel-rat-image.sh  Armbian_xx_Nanopi-zero2_bookworm.img.xz
#   sudo ./build-tunnel-rat-image.sh  base.img  tunnel-rat-nanopi.img
#
# Output: tunnel-rat-nanopi.img.xz  (+ .sha256) ready to host and flash.
#
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${1:-}"
OUT="${2:-tunnel-rat-nanopi.img}"
WORK=""
LOOP=""
MNT=""

c_grn=$'\e[32m'; c_cyn=$'\e[36m'; c_yel=$'\e[33m'; c_red=$'\e[31m'; c_rst=$'\e[0m'
log()  { echo "${c_cyn}[*]${c_rst} $*"; }
ok()   { echo "${c_grn}[✓]${c_rst} $*"; }
warn() { echo "${c_yel}[!]${c_rst} $*"; }
die()  { echo "${c_red}[x]${c_rst} $*" >&2; exit 1; }

cleanup() {
  set +e
  [ -n "$MNT" ] && mountpoint -q "$MNT" && umount "$MNT"
  [ -n "$MNT" ] && rmdir "$MNT" 2>/dev/null
  [ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null
}
trap cleanup EXIT

[ "${EUID}" -eq 0 ] || die "Run as root: sudo ./build-tunnel-rat-image.sh <base-image>"
[ -n "$BASE" ] || die "Give the stock Armbian image as the first argument (.img or .img.xz)."
[ -f "$BASE" ] || die "File not found: $BASE"
for t in losetup xz; do command -v "$t" >/dev/null || die "Missing tool: $t (install util-linux / xz-utils)"; done

# 1. Decompress (if needed) into a working copy we can modify.
log "Preparing working copy…"
case "$BASE" in
  *.xz) xz -dkc "$BASE" > "$OUT" ;;
  *.gz) gzip -dkc "$BASE" > "$OUT" ;;
  *)    cp --reflink=auto "$BASE" "$OUT" ;;
esac
WORK="$OUT"
ok "working image: $WORK ($(du -h "$WORK" | cut -f1))"

# 2. Attach loop device with partition scanning.
log "Attaching loop device…"
LOOP="$(losetup --show -Pf "$WORK")"
sleep 1
ok "loop: $LOOP"

# 3. Find the Linux root partition (largest partition that contains /etc).
log "Locating root partition…"
MNT="$(mktemp -d)"
ROOTPART=""
# Try partitions largest-first.
for part in $(lsblk -nro NAME,SIZE -b "$LOOP" | awk 'NR>1{print $1" "$2}' | sort -k2 -nr | awk '{print $1}'); do
  dev="/dev/$part"
  if mount "$dev" "$MNT" 2>/dev/null; then
    if [ -d "$MNT/etc" ] && [ -d "$MNT/opt" -o -d "$MNT/usr" ]; then
      ROOTPART="$dev"; break
    fi
    umount "$MNT"
  fi
done
[ -n "$ROOTPART" ] || die "Could not find the root filesystem in the image."
ok "root filesystem: $ROOTPART"

# 4. Inject Tunnel R.A.T. files + first-boot auto-installer.
log "Injecting Tunnel R.A.T. setup files…"
SETUP="$MNT/opt/tunnel-rat-setup"
mkdir -p "$SETUP"
for f in install-tunnel-rat.sh tunnel-rat-dashboard.py tunnel-rat.conf \
         tunnel-rat.cap tunnel-rat.sh README.md LICENSE; do
  [ -f "${REPO_DIR}/$f" ] && cp "${REPO_DIR}/$f" "$SETUP/"
done
chmod +x "$SETUP/install-tunnel-rat.sh" 2>/dev/null || true

cat > "$SETUP/firstboot.sh" <<'FB'
#!/usr/bin/env bash
# Runs once, the first time the device boots with a network, then disables itself.
set -u
LOG=/var/log/tunnel-rat-firstboot.log
echo "first-boot setup starting $(date -u)" >>"$LOG" 2>&1
cd /opt/tunnel-rat-setup || exit 0
bash ./install-tunnel-rat.sh all >>"$LOG" 2>&1
systemctl disable tunnel-rat-firstboot.service >>"$LOG" 2>&1
echo "first-boot setup done $(date -u)" >>"$LOG" 2>&1
FB
chmod +x "$SETUP/firstboot.sh"

cat > "$MNT/etc/systemd/system/tunnel-rat-firstboot.service" <<'UNIT'
[Unit]
Description=Tunnel R.A.T. first-boot setup (runs installer once)
After=network-online.target
Wants=network-online.target
ConditionPathExists=/opt/tunnel-rat-setup/firstboot.sh

[Service]
Type=oneshot
ExecStart=/opt/tunnel-rat-setup/firstboot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

# Enable the unit by linking it into multi-user.target (works offline, no chroot).
mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sf ../tunnel-rat-firstboot.service \
  "$MNT/etc/systemd/system/multi-user.target.wants/tunnel-rat-firstboot.service"
ok "first-boot auto-installer enabled"

sync
umount "$MNT"; rmdir "$MNT"; MNT=""
losetup -d "$LOOP"; LOOP=""

# 5. Compress + checksum for distribution.
log "Compressing (this takes a minute)…"
xz -T0 -f "$WORK"
ok "image: ${WORK}.xz ($(du -h "${WORK}.xz" | cut -f1))"
sha256sum "${WORK}.xz" > "${WORK}.xz.sha256"
ok "checksum: ${WORK}.xz.sha256"

cat <<EOF

${c_grn}Done.${c_rst} Flashable image ready:
  ${WORK}.xz

On first boot (with the device online), it auto-runs the installer, then the
dashboard comes up on port 8080. Host ${WORK}.xz on GitHub Releases and link it
from your page — see docs/IMAGE-AND-FLASHING.md.
EOF
