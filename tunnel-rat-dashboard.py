#!/usr/bin/env python3
"""
Tunnel R.A.T. — NanoPi Zero2 control dashboard (public baseline)

A small Flask dashboard for operating the Tunnel R.A.T. toolkit on a network
you own or are explicitly authorized to test. It groups controls into five
sections — Offensive, Defensive, Bluetooth, SDR and Wardriving — and sticks to
discovery, capture and monitoring actions. It does not automate attacks on, or
collect data from, people who have not consented to testing.

Config is read from /opt/tunnel-rat/config/dashboard.conf (written by the
installer) or from environment variables:
    DASHBOARD_USER       (default: admin)
    DASHBOARD_PASSWORD   (required; installer generates one)
    DASHBOARD_PORT       (default: 8080)

Layout is orientation-responsive, so it reflows between portrait and landscape
on a phone browser.
"""

import os
import re
import shlex
import signal
import subprocess
import time
from pathlib import Path
from functools import wraps

try:
    import psutil
except Exception:  # psutil is optional; status tiles degrade gracefully
    psutil = None

from flask import (
    Flask, Response, request, session, redirect, url_for,
    jsonify, send_file, abort,
)

# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------
INSTALL_ROOT = Path(os.environ.get("TUNNEL_RAT_ROOT", "/opt/tunnel-rat"))
CAPTURES_DIR = INSTALL_ROOT / "captures"
LOGS_DIR = INSTALL_ROOT / "logs"
CONF_FILE = INSTALL_ROOT / "config" / "dashboard.conf"


def _load_conf():
    cfg = {}
    if CONF_FILE.exists():
        for line in CONF_FILE.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
    # Environment overrides the file.
    for k in ("DASHBOARD_USER", "DASHBOARD_PASSWORD", "DASHBOARD_PORT"):
        if os.environ.get(k):
            cfg[k] = os.environ[k]
    return cfg


CONF = _load_conf()
USER = CONF.get("DASHBOARD_USER", "admin")
PASSWORD = CONF.get("DASHBOARD_PASSWORD", "")
PORT = int(CONF.get("DASHBOARD_PORT", "8080"))

CAPTURES_DIR.mkdir(parents=True, exist_ok=True)
LOGS_DIR.mkdir(parents=True, exist_ok=True)

app = Flask(__name__)
app.secret_key = os.urandom(32)

# --------------------------------------------------------------------------
# Whitelisted actions.
#
# Every button maps to an id here. The backend never runs text typed by the
# browser — only these fixed commands, each with a short description. Keeping
# it to a whitelist is what makes the dashboard safe to expose on the device.
# `svc` entries start/stop a systemd unit; `run` entries launch a command and
# write output under captures/ or logs/.
# --------------------------------------------------------------------------
LOCAL_SUBNET = os.environ.get("TUNNEL_RAT_SUBNET", "192.168.50.0/24")

ACTIONS = {
    # ---- Offensive (discovery + capture only) ----------------------------
    "host_discovery": {
        "section": "offensive",
        "label": "Host discovery (ping sweep)",
        "run": f"nmap -sn {LOCAL_SUBNET} -oN {LOGS_DIR}/host-discovery.txt",
    },
    "service_scan": {
        "section": "offensive",
        "label": "Service / version scan",
        "run": f"nmap -sV {LOCAL_SUBNET} -oN {LOGS_DIR}/service-scan.txt",
    },
    "capture_start": {
        "section": "offensive",
        "label": "Start packet capture",
        "run": f"tcpdump -i any -w {CAPTURES_DIR}/capture-$(date +%Y%m%d-%H%M%S).pcap",
        "background": True,
    },
    "capture_stop": {
        "section": "offensive",
        "label": "Stop packet capture",
        "stop": "tcpdump",
    },
    # ---- Defensive -------------------------------------------------------
    "suricata_start": {"section": "defensive", "label": "Start Suricata IDS", "svc": ("suricata", "start")},
    "suricata_stop":  {"section": "defensive", "label": "Stop Suricata IDS",  "svc": ("suricata", "stop")},
    "fail2ban_start": {"section": "defensive", "label": "Start fail2ban",     "svc": ("fail2ban", "start")},
    "clamscan":       {"section": "defensive", "label": "ClamAV scan (home)",
                        "run": f"clamscan -r -i /root --log={LOGS_DIR}/clamav.log", "background": True},
    # ---- Bluetooth -------------------------------------------------------
    "ble_scan": {
        "section": "bluetooth",
        "label": "BLE device survey (10s)",
        "run": f"timeout 10 hcitool lescan >{LOGS_DIR}/ble-scan.txt 2>&1 || true",
    },
    # ---- SDR -------------------------------------------------------------
    "sdr_test": {
        "section": "sdr",
        "label": "RTL-SDR connectivity test",
        "run": f"rtl_test -t >{LOGS_DIR}/sdr-test.txt 2>&1 || true",
    },
    # ---- Wardriving ------------------------------------------------------
    "gpsd_start": {"section": "wardriving", "label": "Start GPS daemon", "svc": ("gpsd", "start")},
    "kismet_start": {
        "section": "wardriving",
        "label": "Start Kismet (survey)",
        "run": f"kismet --no-ncurses -c any --log-prefix {CAPTURES_DIR}",
        "background": True,
    },
    "kismet_stop": {"section": "wardriving", "label": "Stop Kismet", "stop": "kismet"},
}

SECTIONS = [
    ("offensive",  "Offensive",  "Discovery & capture on authorized targets"),
    ("defensive",  "Defensive",  "Monitoring & detection on your own network"),
    ("bluetooth",  "Bluetooth",  "BLE survey"),
    ("sdr",        "SDR",        "Software-defined radio"),
    ("wardriving", "Wardriving", "GPS-tagged wireless survey"),
]

_BG = {}  # action_id -> Popen for background jobs


# --------------------------------------------------------------------------
# Auth
# --------------------------------------------------------------------------
def login_required(f):
    @wraps(f)
    def wrapper(*a, **kw):
        if not session.get("auth"):
            if request.path.startswith("/api/"):
                abort(401)
            return redirect(url_for("login"))
        return f(*a, **kw)
    return wrapper


@app.route("/login", methods=["GET", "POST"])
def login():
    error = ""
    if request.method == "POST":
        if not PASSWORD:
            error = "No password set. Set DASHBOARD_PASSWORD in dashboard.conf."
        elif request.form.get("user") == USER and request.form.get("password") == PASSWORD:
            session["auth"] = True
            return redirect(url_for("index"))
        else:
            error = "Invalid credentials."
    return Response(LOGIN_HTML.replace("{{error}}", error), mimetype="text/html")


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


# --------------------------------------------------------------------------
# Pages / API
# --------------------------------------------------------------------------
@app.route("/")
@login_required
def index():
    return Response(INDEX_HTML, mimetype="text/html")


@app.route("/api/status")
@login_required
def api_status():
    data = {"time": time.strftime("%Y-%m-%d %H:%M:%S")}
    if psutil:
        data["cpu"] = psutil.cpu_percent(interval=0.2)
        vm = psutil.virtual_memory()
        data["mem"] = vm.percent
        du = psutil.disk_usage("/")
        data["disk"] = du.percent
        temps = getattr(psutil, "sensors_temperatures", lambda: {})() or {}
        for _, entries in temps.items():
            if entries:
                data["temp"] = round(entries[0].current, 1)
                break
    return jsonify(data)


@app.route("/api/actions")
@login_required
def api_actions():
    out = {sec[0]: [] for sec in SECTIONS}
    for aid, meta in ACTIONS.items():
        out[meta["section"]].append({"id": aid, "label": meta["label"]})
    return jsonify({"sections": SECTIONS, "actions": out})


@app.route("/api/run/<action_id>", methods=["POST"])
@login_required
def api_run(action_id):
    meta = ACTIONS.get(action_id)
    if not meta:
        abort(404)
    try:
        if "svc" in meta:
            unit, verb = meta["svc"]
            subprocess.run(["systemctl", verb, unit], check=False,
                           capture_output=True, timeout=20)
            return jsonify({"ok": True, "msg": f"{verb} {unit}"})

        if "stop" in meta:
            subprocess.run(["pkill", "-f", meta["stop"]], check=False)
            job = _BG.pop(meta["stop"], None)
            if job:
                job.terminate()
            return jsonify({"ok": True, "msg": f"stopped {meta['stop']}"})

        cmd = meta["run"]
        if meta.get("background"):
            proc = subprocess.Popen(["bash", "-c", cmd], preexec_fn=os.setsid)
            _BG[action_id] = proc
            return jsonify({"ok": True, "msg": "started (background)", "pid": proc.pid})
        else:
            res = subprocess.run(["bash", "-c", cmd], capture_output=True,
                                 text=True, timeout=120)
            return jsonify({"ok": res.returncode == 0,
                            "msg": (res.stdout or res.stderr or "done")[-800:]})
    except subprocess.TimeoutExpired:
        return jsonify({"ok": False, "msg": "timed out (still running in background?)"})
    except Exception as e:  # noqa: BLE001 — surface the error to the operator
        return jsonify({"ok": False, "msg": str(e)})


@app.route("/api/captures")
@login_required
def api_captures():
    files = []
    for base in (CAPTURES_DIR, LOGS_DIR):
        for p in sorted(base.glob("*"), key=lambda x: x.stat().st_mtime, reverse=True):
            if p.is_file():
                files.append({"name": f"{base.name}/{p.name}",
                              "size": p.stat().st_size,
                              "mtime": time.strftime("%Y-%m-%d %H:%M",
                                                     time.localtime(p.stat().st_mtime))})
    return jsonify(files[:100])


@app.route("/api/download")
@login_required
def api_download():
    name = request.args.get("name", "")
    # Only allow files inside captures/ or logs/.
    if not re.fullmatch(r"(captures|logs)/[A-Za-z0-9._-]+", name or ""):
        abort(400)
    path = INSTALL_ROOT / name
    if not path.is_file():
        abort(404)
    return send_file(path, as_attachment=True)


@app.route("/api/stream")
@login_required
def api_stream():
    """Server-sent events: tail a whitelisted log file live."""
    name = request.args.get("name", "")
    if not re.fullmatch(r"(captures|logs)/[A-Za-z0-9._-]+", name or ""):
        abort(400)
    path = INSTALL_ROOT / name
    if not path.is_file():
        abort(404)

    def gen():
        with path.open("r", errors="replace") as fh:
            fh.seek(0, os.SEEK_END)
            idle = 0
            while idle < 600:  # auto-close after ~10 min idle
                line = fh.readline()
                if line:
                    idle = 0
                    yield f"data: {line.rstrip()}\n\n"
                else:
                    idle += 1
                    time.sleep(1)
                    yield ": keepalive\n\n"
    return Response(gen(), mimetype="text/event-stream")


# --------------------------------------------------------------------------
# Templates (inline — single-file deploy)
# --------------------------------------------------------------------------
LOGIN_HTML = """<!doctype html><html lang=en><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>Tunnel R.A.T. — Login</title><style>
:root{--bg:#0b0f0c;--fg:#b6f7c1;--accent:#27c93f;--panel:#121a14}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);
font-family:ui-monospace,Menlo,Consolas,monospace;display:grid;place-items:center;min-height:100vh}
form{background:var(--panel);padding:2rem;border:1px solid #1f3a26;border-radius:12px;width:min(92vw,340px)}
h1{font-size:1.1rem;margin:0 0 1rem;color:var(--accent)}
input{width:100%;padding:.7rem;margin:.35rem 0;background:#0b0f0c;border:1px solid #1f3a26;
color:var(--fg);border-radius:8px;font:inherit}
button{width:100%;padding:.7rem;margin-top:.6rem;background:var(--accent);color:#06240d;
border:0;border-radius:8px;font:inherit;font-weight:700}
.err{color:#ff6b6b;min-height:1.2em;font-size:.85rem}</style></head>
<body><form method=post><h1>&#9654; Tunnel R.A.T.</h1>
<input name=user placeholder=user autocomplete=username value=admin>
<input name=password type=password placeholder=password autocomplete=current-password>
<div class=err>{{error}}</div><button type=submit>Enter</button></form></body></html>"""

INDEX_HTML = """<!doctype html><html lang=en><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>Tunnel R.A.T.</title><style>
:root{--bg:#0b0f0c;--fg:#cfeedd;--accent:#27c93f;--panel:#121a14;--line:#1f3a26}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);
font-family:ui-monospace,Menlo,Consolas,monospace}
header{display:flex;align-items:center;justify-content:space-between;gap:1rem;
padding:.7rem 1rem;border-bottom:1px solid var(--line);position:sticky;top:0;background:var(--bg)}
header h1{font-size:1rem;margin:0;color:var(--accent)}
a.logout{color:var(--fg);opacity:.7;text-decoration:none;font-size:.8rem}
.tiles{display:flex;flex-wrap:wrap;gap:.5rem;padding:.7rem 1rem}
.tile{background:var(--panel);border:1px solid var(--line);border-radius:10px;
padding:.5rem .8rem;min-width:84px;flex:1 1 84px}
.tile b{display:block;font-size:1.2rem;color:var(--accent)}
.tile span{font-size:.7rem;opacity:.7}
main{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:1rem;padding:1rem}
section{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:1rem}
section h2{margin:0 0 .2rem;font-size:.95rem;color:var(--accent)}
section p{margin:0 0 .7rem;font-size:.72rem;opacity:.65}
button.act{display:block;width:100%;text-align:left;margin:.3rem 0;padding:.6rem .7rem;
background:#0b0f0c;border:1px solid var(--line);color:var(--fg);border-radius:8px;font:inherit;font-size:.82rem}
button.act:active{background:#15251a}
#log{grid-column:1/-1;background:#06090700;border:1px solid var(--line);border-radius:12px;
padding:.6rem 1rem;min-height:3rem;white-space:pre-wrap;font-size:.76rem;max-height:30vh;overflow:auto}
.files a{color:var(--accent);text-decoration:none;font-size:.78rem;display:block;padding:.15rem 0}
footer{padding:1rem;text-align:center;font-size:.68rem;opacity:.5}
@media(orientation:portrait){main{grid-template-columns:1fr}}
</style></head><body>
<header><h1>&#9654; Tunnel R.A.T.</h1>
<div style="display:flex;gap:1rem;align-items:center">
<span id=clock style="font-size:.75rem;opacity:.6"></span>
<a class=logout href=/logout>logout</a></div></header>
<div class=tiles id=tiles></div>
<main id=main></main>
<script>
async function j(u,o){const r=await fetch(u,o);if(r.status===401){location='/login';return{}}return r.json()}
function tile(l,v){return `<div class=tile><b id=t_${l}>${v}</b><span>${l}</span></div>`}
async function status(){const d=await j('/api/status');
 document.getElementById('clock').textContent=d.time||'';
 const t=document.getElementById('tiles');
 t.innerHTML=tile('cpu%',d.cpu??'—')+tile('mem%',d.mem??'—')+tile('disk%',d.disk??'—')+tile('temp',d.temp??'—')}
async function build(){const d=await j('/api/actions');const m=document.getElementById('main');let h='';
 for(const [id,name,desc] of d.sections){h+=`<section><h2>${name}</h2><p>${desc}</p>`;
  for(const a of (d.actions[id]||[])){h+=`<button class=act onclick="run('${a.id}',this)">${a.label}</button>`}
  h+='</section>'}
 h+='<section class=files><h2>Captures &amp; logs</h2><p>Download or tail output</p><div id=files></div></section>';
 h+='<div id=log>ready.</div>';m.innerHTML=h;files()}
async function run(id,btn){const o=btn.textContent;btn.textContent='… '+o;
 const r=await j('/api/run/'+id,{method:'POST'});
 logline((r.ok?'[ok] ':'[!] ')+id+(r.msg?'  '+r.msg:''));btn.textContent=o;files()}
function logline(s){const l=document.getElementById('log');l.textContent=(s+'\\n'+l.textContent).slice(0,4000)}
async function files(){const f=await j('/api/captures');const d=document.getElementById('files');
 d.innerHTML=f.map(x=>`<a href="/api/download?name=${encodeURIComponent(x.name)}">${x.name} <span style=opacity:.5>(${x.size}b, ${x.mtime})</span></a>`).join('')||'<span style=opacity:.5>none yet</span>'}
status();build();setInterval(status,5000)
</script>
<footer>Tunnel R.A.T. &mdash; authorized testing only. Use on networks you own or are permitted to assess.</footer>
</body></html>"""


if __name__ == "__main__":
    if not PASSWORD:
        print("[!] No DASHBOARD_PASSWORD set — set one in", CONF_FILE, "or the environment.")
    # 0.0.0.0 so it is reachable over the device's own AP / LAN.
    app.run(host="0.0.0.0", port=PORT, threaded=True)
