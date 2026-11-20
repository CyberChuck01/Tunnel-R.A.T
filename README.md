# Tunnel R.A.T.

**A build-it-yourself network security testing and learning platform for the NanoPi Zero2.**

Tunnel R.A.T. turns an inexpensive NanoPi Zero2 single-board computer into a
compact, self-contained toolkit for **learning how networks are attacked and
defended**, and for running **authorized assessments** on networks you own or
have written permission to test — a home lab, your own equipment, or a
permission-based engagement.

It bundles well-known, open-source security tools (Bettercap, nmap, tcpdump,
Suricata, Kismet and friends) behind one installer and one web dashboard, so you
can stand up a practice-and-assessment rig from a fresh flash in minutes. It's a
learning project and a portable lab — not a product, and not a clone of anyone
else's device.

> ### ⚠️ Authorized use only
> This project is for education and for testing systems you own or are
> **explicitly authorized** to assess. Intercepting, scanning, or disrupting
> networks you don't have permission to touch is illegal in most places
> (in the US, see the Computer Fraud and Abuse Act). You are responsible for
> staying inside the law and inside your agreed scope. If you can't point to
> permission for a target, it's out of scope. See
> [Authorized use & legal](#authorized-use--legal).

---

## What it is

- **Hardware:** NanoPi Zero2 (Rockchip RK3528A, ARM64), microSD, USB ethernet,
  optional USB Wi-Fi adapter, GPS, and RTL-SDR.
- **OS:** Armbian (Debian).
- **Interface:** a web dashboard plus the usual command-line tools.
- **Organized into five areas:** Offensive, Defensive, Bluetooth, SDR, and
  Wardriving — so the same box can be used both to *test* a network and to
  *monitor and defend* one.

The point is to understand both sides. Every offensive technique here exists so
you can see what it looks like on the wire and learn to detect and defend
against it on your own network.

---

## Capabilities

### Offensive (authorized testing)

Techniques for assessing a network you're permitted to test, and for generating
realistic traffic to practice detection against.

- **Host & service discovery (nmap)** — inventory devices, open ports, services
  and versions on your scope. The foundation of any assessment.
- **Traffic capture (PCAP)** — record to standard PCAP files (Wireshark /
  tcpdump) to study protocols and spot weaknesses like plaintext services.
- **ARP / MITM positioning (Bettercap)** — the classic man-in-the-middle
  technique, for demonstrating on a lab network why unencrypted traffic is
  risky and how to detect spoofing.
- **DNS redirection (lab)** — point a chosen hostname at a host you control
  (e.g. a honeypot or lab web server) to practice phishing-awareness and
  redirection-detection exercises within your own range.
- **Local HTTP inspection** — proxy and inspect **your own** lab HTTP traffic to
  see what plaintext protocols expose.

### Defensive (blue team)

Monitoring and detection you can leave running on your own network.

- **Suricata** IDS/IPS and **Zeek** network analysis for traffic monitoring.
- **ClamAV** scanning, **fail2ban**, **ufw**, **rkhunter** for host hardening.
- **Regex isolation** — block or flag traffic matching patterns (e.g. known-bad
  domains / C2 indicators) to practice network segmentation and detection.
- **Connection control** — close connections on a given port or host, to test
  how your services and monitoring react to disruption.

### Bluetooth

- BLE device survey to inventory nearby Bluetooth devices during an authorized
  wireless assessment (timestamped, and GPS-tagged when wardriving).

### SDR (software-defined radio)

- With an RTL-SDR dongle: **ADS-B** aircraft tracking, spectrum/signal survey
  during an assessment, and general radio experimentation.

### Wardriving

- **Kismet** Wi-Fi survey with **GPS tagging**, live and historical map views,
  and an optional ADS-B overlay — for mapping *your own* survey of the RF
  environment.

### Control & management

- **Web dashboard** — start/stop tools, watch live output, browse and download
  captures, all from a phone browser (reflows for portrait or landscape).
- **Remote management** — manage *your own* device remotely over a reverse SSH
  tunnel to a server you control.
- **VPN (WireGuard / OpenVPN)** — encrypted remote access to your lab.
- **Evidence export** — bundle an engagement's captures and logs for your
  report.
- **Secure wipe / lab reset** — cleanly wipe captures and config to reset the
  device between lab exercises.

---

## Hardware

| Part | Notes |
|------|-------|
| NanoPi Zero2 | RK3528A, ARM64 — the brain |
| microSD | 32 GB recommended |
| USB → ethernet | wired testing / inline use |
| USB Wi-Fi adapter | external antenna recommended for wireless survey |
| USB GPS | wardriving / geo-tagging (optional) |
| RTL-SDR | ADS-B & spectrum (optional) |
| USB-C power | 5V/2A minimum |

---

## Install

Flash Armbian, then run the installer. Full steps in
**[docs/INSTALL.md](docs/INSTALL.md)**.

**One command:**

```bash
git clone https://github.com/CyberChuck01/Tunnel-R.A.T.git
cd Tunnel-R.A.T
sudo ./install-tunnel-rat.sh
```

**Or in stages** (re-runnable, so a failed download is easy to resume):

```bash
sudo ./install-tunnel-rat.sh base        # core + Bettercap + base tools
sudo ./install-tunnel-rat.sh defense     # monitoring / detection
sudo ./install-tunnel-rat.sh offense     # assessment tooling
sudo ./install-tunnel-rat.sh recon       # recon / wireless / OSINT
sudo ./install-tunnel-rat.sh dashboard   # web dashboard
```

```bash
sudo ./install-tunnel-rat.sh status      # what's done
sudo ./install-tunnel-rat.sh all         # resume the rest
```

Finished stages are marked and skipped, so re-running `all` safely picks up
where it left off.

---

## Ready-to-flash image

Prefer to download one file and flash it, with no installer step and **no Balena
or imaging app**? Build a pre-baked image that sets itself up on first boot,
host it, and flash it with `dd` or the included flasher. Full guide in
**[docs/IMAGE-AND-FLASHING.md](docs/IMAGE-AND-FLASHING.md)**.

```bash
# Build a flashable image from a stock Armbian image:
sudo ./build-tunnel-rat-image.sh Armbian_xx_Nanopi-zero2_bookworm.img.xz
#  -> tunnel-rat-nanopi.img.xz  (host on GitHub Releases, link from your page)

# Flash it (Linux/macOS, no imaging app):
sudo ./flash-tunnel-rat.sh tunnel-rat-nanopi.img.xz
```

> SBC images are raw SD-card images (`.img.xz`), not `.iso`. The docs explain
> hosting (the file is too big for Squarespace uploads — put it on GitHub
> Releases and link it from your page) and flashing on Linux, macOS and Windows
> without Balena.

---

## Dashboard

After the `dashboard` stage, open `http://<device-ip>:8080`. The installer
prints a generated admin password and saves it to
`/opt/tunnel-rat/config/dashboard.conf`. Change it there and restart:

```bash
sudo systemctl restart tunnel-rat-dashboard
```

The dashboard sticks to discovery, capture and monitoring actions and runs only
a fixed set of whitelisted commands — it won't run arbitrary input from the
browser.

---

## Repository layout

```
Tunnel-R.A.T/
├── README.md
├── LICENSE
├── install-tunnel-rat.sh        # staged installer (one command or step-by-step)
├── tunnel-rat-dashboard.py      # Flask web dashboard
├── tunnel-rat.sh                # CLI launcher (Bettercap + config)
├── tunnel-rat.conf              # interface / scope / options
├── tunnel-rat.cap               # Bettercap caplet (safe defaults)
├── build-tunnel-rat-image.sh    # bake a ready-to-flash image
├── flash-tunnel-rat.sh          # write an image to SD (no imaging app)
└── docs/
    ├── INSTALL.md
    └── IMAGE-AND-FLASHING.md
```

---

## Troubleshooting

| Symptom | Try |
|--------|-----|
| A stage failed partway | Re-run just that stage: `sudo ./install-tunnel-rat.sh <stage>`. Log: `/var/log/tunnel-rat-install.log` |
| `bettercap: command not found` | `sudo ./install-tunnel-rat.sh base` (it builds from source) |
| A package "not available" warning | Your Armbian release doesn't carry it; install by hand — the stage still completes |
| Dashboard won't load | `journalctl -u tunnel-rat-dashboard -f`; check the port in `dashboard.conf` |
| Can't find the device | `nmap -sn <your-subnet>` or check your router's DHCP list |
| Wrong network interface | Set `INTERFACE=` in `tunnel-rat.conf`, or check `ip link show` |

---

## Authorized use & legal

Tunnel R.A.T. is intended for **education** and for **authorized security
testing** only.

- Use it only on networks and devices you **own** or have **explicit written
  permission** to test.
- Agree the scope before you start, and stay inside it.
- Unauthorized access to, interception of, or interference with computer
  networks is illegal under laws such as the U.S. Computer Fraud and Abuse Act
  (CFAA) and equivalents worldwide.
- The offensive techniques are included so you can learn to **recognize and
  defend against** them. Don't use them against people or networks that haven't
  consented to testing.

You are solely responsible for how you use this project. The authors provide it
as-is, for lawful, authorized purposes, and accept no liability for misuse.

---

## License

MIT — see [LICENSE](LICENSE).

**Built by CyberChuck01** for hands-on network security learning and authorized testing.
