# Pre-baked image, hosting, and flashing without Balena

This covers building a one-file, ready-to-flash Tunnel R.A.T. image, hosting it
on your page, and writing it to a microSD card **without Balena Etcher or any
imaging app**.

> **A note on "ISO":** SBCs like the NanoPi Zero2 don't boot from `.iso` files
> (those are for PCs/optical media). They boot from a raw **SD-card image**,
> distributed as `.img` — compressed to **`.img.xz`**. Everything below uses
> that. It's the same idea you had, just the right file type for this board.

---

## Option A — no image at all (simplest "no imaging app" path)

If the goal is "flash once, no Balena," the cleanest route is the one you
already use: flash **stock Armbian** with the Armbian imager, then run the
one-command installer (see [INSTALL.md](INSTALL.md)). Nothing else to download,
and you can `curl` the installer straight onto the device. Use Option B when you
want users to flash a single finished file with the toolkit already baked in.

---

## Option B — build a ready-to-flash image

`build-tunnel-rat-image.sh` takes a stock Armbian image and bakes in the Tunnel
R.A.T. files plus a **first-boot auto-installer**. The first time the device
boots online, it runs the installer itself, then the dashboard comes up on
`:8080`. No installer step for the end user.

On a Linux PC (or the NanoPi itself), with the repo files alongside the script:

```bash
# 1. Download the current stock Armbian image for the NanoPi Zero2.
# 2. Bake the image:
sudo ./build-tunnel-rat-image.sh Armbian_xx_Nanopi-zero2_bookworm.img.xz

# Output:
#   tunnel-rat-nanopi.img.xz          <- the file you distribute
#   tunnel-rat-nanopi.img.xz.sha256   <- checksum
```

The script loop-mounts the image, drops the files into `/opt/tunnel-rat-setup`,
enables a one-time `tunnel-rat-firstboot` service, and recompresses. It never
touches your real disks — writing to an SD card is a separate, confirmed step
(Option D).

---

## Option C — host it on your page

A full OS image is a few hundred MB. **Squarespace file uploads are size-capped
(around 20 MB on most plans), so the image itself won't upload there.** Host the
big file where large binaries belong and link it from your page:

1. Create a **GitHub Release** on `CyberChuck01/Tunnel-R.A.T` and attach
   `tunnel-rat-nanopi.img.xz` + its `.sha256` as release assets
   (GitHub allows up to 2 GB per file — plenty).
   Direct link pattern:
   ```
   https://github.com/CyberChuck01/Tunnel-R.A.T/releases/latest/download/tunnel-rat-nanopi.img.xz
   ```
2. On your Squarespace page, add a **Button** (or text link) pointing at that
   URL — "Download Tunnel R.A.T. image." The download comes from GitHub; your
   page is just the front door. Put the one-line flashing instructions and the
   SHA-256 right next to the button.

(If you'd rather not use GitHub Releases, any large-file host with a direct
download link works the same way — Cloudflare R2, Backblaze B2, a release on a
mirror, etc. The point is: big file off-site, link on the page.)

---

## Option D — flash it without Balena

Always verify the download first:

```bash
sha256sum -c tunnel-rat-nanopi.img.xz.sha256
```

### Linux / macOS — the included flasher (recommended)

```bash
sudo ./flash-tunnel-rat.sh tunnel-rat-nanopi.img.xz
```

It lists removable disks, has you pick the SD card, makes you type `ERASE` to
confirm, then writes and syncs. No GUI app involved.

### Linux / macOS — plain `dd` one-liner

If you'd rather do it by hand (replace `/dev/sdX` with your card — **not** your
system disk; macOS uses `/dev/rdiskN`):

```bash
# Linux
xzcat tunnel-rat-nanopi.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress

# macOS
xzcat tunnel-rat-nanopi.img.xz | sudo dd of=/dev/rdiskN bs=4m
```

### Windows — without Balena

Windows has no built-in GUI writer, but you don't need Balena:

- **USBImager** — a ~1 MB portable app, no install, writes `.img.xz` directly.
  The lightest "not Balena" option.
- **`dd` in WSL or Git Bash** — same one-liner as Linux above, targeting the
  card (e.g. `/dev/sdX` under WSL).

> **Why not flash from a browser?** Browser flashers (ESP Web Tools and similar)
> talk to microcontrollers over USB serial — they can't write a full SD-card OS
> image. For an SD card you need `dd`, the flasher script, or a tiny writer like
> USBImager. There's no reliable one-click web flash for this board.

---

## First boot

Insert the card, connect **ethernet + power**, and give it a few minutes the
first time — it resizes, runs the installer, and starts the dashboard. Then:

```
http://<device-ip>:8080
```

First-boot log on the device: `/var/log/tunnel-rat-firstboot.log`.
