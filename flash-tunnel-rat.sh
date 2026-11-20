#!/usr/bin/env bash
#
# flash-tunnel-rat.sh
# Write a Tunnel R.A.T. image to a microSD card from the terminal — no Balena,
# no imaging app. Works on Linux and macOS (uses dd).
#
#   Linux:  sudo ./flash-tunnel-rat.sh tunnel-rat-nanopi.img.xz
#   macOS:  sudo ./flash-tunnel-rat.sh tunnel-rat-nanopi.img.xz
#
# It lists disks, asks you to pick the SD card, shows a big confirmation, then
# writes and verifies. Picking the wrong disk erases it — read the prompt.
#
set -Eeuo pipefail

IMG="${1:-}"
c_grn=$'\e[32m'; c_cyn=$'\e[36m'; c_yel=$'\e[33m'; c_red=$'\e[31m'; c_rst=$'\e[0m'
die(){ echo "${c_red}[x]${c_rst} $*" >&2; exit 1; }

[ "${EUID}" -eq 0 ] || die "Run with sudo: sudo ./flash-tunnel-rat.sh <image>"
[ -n "$IMG" ] || die "Usage: sudo ./flash-tunnel-rat.sh <image.img[.xz|.gz]>"
[ -f "$IMG" ] || die "File not found: $IMG"

OS="$(uname -s)"

echo "${c_cyn}Removable disks:${c_rst}"
if [ "$OS" = "Darwin" ]; then
  diskutil list external physical 2>/dev/null || diskutil list
  echo
  echo "Enter the disk id of your SD card (e.g. disk4 — NOT disk0):"
  read -r DISK
  TARGET="/dev/r${DISK}"          # raw device is much faster on macOS
  [ -e "/dev/${DISK}" ] || die "No such disk: /dev/${DISK}"
  diskutil unmountDisk "/dev/${DISK}" || die "Could not unmount /dev/${DISK}"
else
  lsblk -dno NAME,SIZE,TYPE,TRAN,MODEL | grep -Ei 'usb|mmc' || lsblk -dno NAME,SIZE,TYPE,MODEL
  echo
  echo "Enter the SD card device name (e.g. sdb or mmcblk0 — NOT your system disk):"
  read -r DEV
  TARGET="/dev/${DEV}"
  [ -b "$TARGET" ] || die "No such block device: $TARGET"
  # Unmount any mounted partitions of the target.
  for p in $(lsblk -nro NAME "$TARGET" | tail -n +2); do umount "/dev/$p" 2>/dev/null || true; done
fi

SIZE="$( [ "$OS" = "Darwin" ] && echo "?" || lsblk -dno SIZE "$TARGET" 2>/dev/null )"
echo
echo "${c_yel}About to ERASE and write:${c_rst}"
echo "    image : $IMG"
echo "    target: $TARGET   (size: ${SIZE})"
echo
echo "${c_red}Everything on $TARGET will be destroyed.${c_rst}"
read -r -p "Type ERASE to continue: " CONFIRM
[ "$CONFIRM" = "ERASE" ] || die "Aborted."

echo "${c_cyn}Writing… (this can take several minutes, do not remove the card)${c_rst}"
case "$IMG" in
  *.xz) DECOMP="xz -dc" ;;
  *.gz) DECOMP="gzip -dc" ;;
  *)    DECOMP="cat" ;;
esac

# status=progress on Linux; macOS dd is quieter but works.
if [ "$OS" = "Darwin" ]; then
  $DECOMP "$IMG" | dd of="$TARGET" bs=4m
else
  $DECOMP "$IMG" | dd of="$TARGET" bs=4M conv=fsync status=progress
fi
sync

echo "${c_grn}[✓] Write complete.${c_rst}"
[ "$OS" = "Darwin" ] && diskutil eject "/dev/${DISK}" 2>/dev/null || true
echo "Insert the card into the NanoPi Zero2, connect ethernet + power, and give it"
echo "a few minutes on first boot (it sets itself up, then the dashboard comes up on :8080)."
