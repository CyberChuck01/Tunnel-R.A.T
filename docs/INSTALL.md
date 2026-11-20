# Installing Tunnel R.A.T.

Two ways to end up with a working device:

1. **Flash stock Armbian once, then run the installer** (most reliable — recommended).
2. **Flash a pre-baked image** that installs itself on first boot — see
   [IMAGE-AND-FLASHING.md](IMAGE-AND-FLASHING.md).

This page covers the installer.

> **Authorized use only.** Tunnel R.A.T. is for learning and for testing
> networks you own or have explicit written permission to assess. Don't run it
> against anyone else's network.

---

## 1. Flash Armbian

Flash the current **Armbian** image for the NanoPi Zero2 to a microSD card
(32 GB recommended) with the Armbian imager, then boot the device with ethernet
attached and SSH in:

```bash
ssh root@<device-ip>      # Armbian walks you through first-login setup
```

## 2. Get the files on the device

```bash
git clone https://github.com/CyberChuck01/Tunnel-R.A.T.git
cd Tunnel-R.A.T
```

(No git on the device? `scp` the folder over from your PC, or flash the
pre-baked image instead.)

## 3. Install

### One command (does everything)

```bash
sudo ./install-tunnel-rat.sh
```

### Or in stages (easier to recover if a step errors)

Each stage is independent and can be re-run on its own. This is the way to go
if a package download fails partway — just re-run the stage that stopped.

```bash
sudo ./install-tunnel-rat.sh base        # 1. core system + Bettercap + base tools
sudo ./install-tunnel-rat.sh defense     # 2. monitoring / detection (Suricata, ClamAV, …)
sudo ./install-tunnel-rat.sh offense     # 3. assessment tools (aircrack-ng, mitmproxy, …)
sudo ./install-tunnel-rat.sh recon       # 4. recon / wireless / OSINT (Kismet, theHarvester, …)
sudo ./install-tunnel-rat.sh dashboard   # 5. web dashboard + service
```

Finished stages are marked and skipped, so re-running `all` safely resumes:

```bash
sudo ./install-tunnel-rat.sh status      # see which stages are done
sudo ./install-tunnel-rat.sh all         # resume anything not finished
sudo FORCE=1 ./install-tunnel-rat.sh base # force a finished stage to re-run
```

| Stage | What it sets up |
|-------|-----------------|
| `base` | build tools, Bettercap (from source), nmap, tcpdump, tshark, dnsmasq, hostapd, WireGuard, OpenVPN, login banner, project layout |
| `defense` | Suricata, ClamAV, fail2ban, ufw, rkhunter, Zeek (where packaged) |
| `offense` | aircrack-ng, hcxdumptool/hcxtools, hashcat, YARA, mitmproxy, Responder |
| `recon` | Kismet, wifite, reaver/bully, theHarvester, whatweb, gpsd, rtl-sdr |
| `dashboard` | Flask dashboard, systemd service, generated admin password |

A package your Armbian release doesn't carry is skipped with a warning instead
of failing the whole run — install those by hand later if you need them.

## 4. Open the dashboard

The installer prints the URL and a generated password at the end:

```
http://<device-ip>:8080     login: admin / <generated>
```

The password lives in `/opt/tunnel-rat/config/dashboard.conf`. Change it there
and `sudo systemctl restart tunnel-rat-dashboard`.

## 5. Launch the toolkit (CLI)

```bash
sudo /opt/tunnel-rat/scripts/tunnel-rat.sh
```

Edit your interface and **authorized test scope** first in
`/opt/tunnel-rat/config/tunnel-rat.conf`.

---

### Logs / troubleshooting

- Install log: `/var/log/tunnel-rat-install.log`
- Dashboard logs: `journalctl -u tunnel-rat-dashboard -f`
- A failed stage tells you exactly which command to re-run.
