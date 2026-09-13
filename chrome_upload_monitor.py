#!/usr/bin/env python3
"""
Chrome Upload Monitor
Tracks active file uploads from Google Chrome (including Flatpak and native)
to web services like Apple Podcasts Connect, YouTube, Google Drive, etc.
"""

import os
import sys
import time
import re
import subprocess
import json

# ANSI Styling
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"
C_CYAN = "\033[1;36m"
C_MAGENTA = "\033[1;35m"
C_GREEN = "\033[1;32m"
C_YELLOW = "\033[1;33m"
C_RED = "\033[1;31m"
C_BLUE = "\033[1;34m"

def fmt_size(b):
    if b is None or b < 0:
        return "0.0 B"
    for u in ['B', 'KB', 'MB', 'GB', 'TB']:
        if b < 1024.0:
            return f"{b:.2f} {u}"
        b /= 1024.0
    return f"{b:.2f} PB"

def fmt_duration(secs):
    if secs is None or secs < 0:
        return "--:--:--"
    secs = int(secs)
    mins, s = divmod(secs, 60)
    hrs, m = divmod(mins, 60)
    if hrs > 0:
        return f"{hrs:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"

def get_doc_portal_mappings():
    """Extract flatpak document portal mappings (doc_id -> real host path)"""
    mappings = {}
    try:
        out = subprocess.check_output(
            ["flatpak", "permission-show", "com.google.Chrome"],
            stderr=subprocess.DEVNULL,
            timeout=2
        ).decode("utf-8", errors="ignore")
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[0] == "documents":
                doc_id = parts[1]
                m = re.search(r"\(b'([^']+)'", line) or re.search(r"\(b\"([^\"]+)\"", line)
                if m:
                    mappings[doc_id] = m.group(1)
                else:
                    m2 = re.search(r"(/[^,'\"]+\.[a-zA-Z0-9]+)", line)
                    if m2:
                        mappings[doc_id] = m2.group(1)
    except Exception:
        pass
    return mappings

def find_chrome_pids():
    """Find all Chrome/Chromium related process IDs"""
    pids = []
    for p in os.listdir('/proc'):
        if not p.isdigit():
            continue
        try:
            with open(f'/proc/{p}/cmdline', 'rb') as f:
                cmd = f.read().lower()
                if b'chrome' in cmd or b'chromium' in cmd or b'brave' in cmd:
                    pids.append(p)
        except Exception:
            pass
    return pids

def detect_service_destination():
    """Detect if Chrome is connected to Apple Podcasts Connect or other services"""
    services = []
    try:
        out = subprocess.check_output(
            ["ss", "-tp", "-u", "-a", "-n"],
            stderr=subprocess.DEVNULL,
            timeout=2
        ).decode("utf-8", errors="ignore")
        
        has_apple = False
        has_akamai = False
        for line in out.splitlines():
            if "chrome" in line and ("ESTAB" in line or "SYN" in line):
                parts = line.split()
                if len(parts) >= 5:
                    remote = parts[4]
                    ip = remote.rsplit(":", 1)[0].strip("[]")
                    if ip.startswith("17.") or "aaplimg" in line:
                        has_apple = True
                    elif ip.startswith("23.36.") or ip.startswith("23.62."):
                        has_akamai = True
        if has_apple:
            services.append("Apple Podcasts Connect (podcastsconnect.apple.com)")
        elif has_akamai:
            services.append("Apple Podcasts Connect / Akamai Edge")
    except Exception:
        pass
    return services

class UploadTracker:
    def __init__(self, filter_term=None):
        self.filter_term = filter_term.lower() if filter_term else None
        self.doc_mappings = get_doc_portal_mappings()
        self.transfers = {}
        self.last_mapping_refresh = time.time()

    def resolve_path_and_size(self, target):
        clean = re.sub(r"\s*\(deleted\)$", "", target)
        basename = os.path.basename(clean)
        
        # Check if it's a portal document
        doc_id = None
        m = re.search(r"/doc/([a-zA-Z0-9_\-]+)/", clean)
        if m:
            doc_id = m.group(1)

        real_path = None
        if doc_id and doc_id in self.doc_mappings:
            real_path = self.doc_mappings[doc_id]

        # Check host portal path
        uid = os.getuid()
        host_doc_path = clean.replace("/run/flatpak/doc/", f"/run/user/{uid}/doc/")
        
        # Find file size
        size = 0
        if real_path and os.path.isfile(real_path):
            size = os.path.getsize(real_path)
        elif os.path.isfile(host_doc_path):
            size = os.path.getsize(host_doc_path)
            if not real_path:
                real_path = host_doc_path
        elif os.path.isfile(clean):
            size = os.path.getsize(clean)
            if not real_path:
                real_path = clean

        # Search WD BLACK B archive if real_path not found
        if not real_path or size == 0:
            archive_base = "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE"
            faint_path = os.path.join(archive_base, "MARATHON_MIXES", "Faint", basename)
            if os.path.isfile(faint_path):
                real_path = faint_path
                size = os.path.getsize(faint_path)
            elif os.path.isfile(os.path.join(archive_base, basename)):
                real_path = os.path.join(archive_base, basename)
                size = os.path.getsize(real_path)

        return real_path or clean, basename, size

    def scan_burst(self, duration=0.8, interval=0.03):
        """Perform rapid sampling to catch Chrome's chunked file reads"""
        chrome_pids = find_chrome_pids()
        if not chrome_pids:
            return

        if time.time() - self.last_mapping_refresh > 30:
            self.doc_mappings = get_doc_portal_mappings()
            self.last_mapping_refresh = time.time()

        end_time = time.time() + duration
        while time.time() < end_time:
            now = time.time()
            for p in chrome_pids:
                fddir = f"/proc/{p}/fd"
                if not os.path.exists(fddir):
                    continue
                try:
                    for fd in os.listdir(fddir):
                        try:
                            target = os.readlink(f"{fddir}/{fd}")
                            if (
                                "/dev/" in target or
                                "/proc/" in target or
                                "/sys/" in target or
                                "/app/" in target or
                                "/usr/" in target or
                                "socket:" in target or
                                "pipe:" in target or
                                "anon_inode:" in target or
                                ".var/app/com.google.Chrome" in target or
                                target.endswith((".pak", ".dat", ".bin", ".ldb", ".log", ".so", ".toc"))
                            ):
                                continue

                            if not (
                                "/doc/" in target or
                                "/MIX_ARCHIVE/" in target or
                                "/MARATHON_MIXES/" in target or
                                target.endswith((".flac", ".wav", ".mp3", ".m4a", ".mp4", ".zip", ".tar", ".gz"))
                            ):
                                continue

                            if self.filter_term and self.filter_term not in target.lower():
                                continue

                            pos = None
                            try:
                                with open(f"/proc/{p}/fdinfo/{fd}", "r") as info:
                                    for line in info:
                                        if line.startswith("pos:"):
                                            pos = int(line.split()[1])
                                            break
                            except Exception:
                                pass

                            if pos is None:
                                continue

                            real_path, basename, size = self.resolve_path_and_size(target)
                            key = basename

                            if key not in self.transfers:
                                self.transfers[key] = {
                                    'basename': basename,
                                    'real_path': real_path,
                                    'target': target,
                                    'size': size,
                                    'pid': p,
                                    'start_time': now,
                                    'start_pos': pos,
                                    'last_seen': now,
                                    'current_pos': pos,
                                    'history': [(now, pos)],
                                    'completed': False
                                }
                            else:
                                t = self.transfers[key]
                                t['pid'] = p
                                t['last_seen'] = now
                                if real_path and not t['real_path'].startswith('/run/flatpak'):
                                    t['real_path'] = real_path
                                if size > 0 and t['size'] == 0:
                                    t['size'] = size
                                if pos > t['current_pos']:
                                    t['current_pos'] = pos
                                    t['history'].append((now, pos))
                                    if len(t['history']) > 15:
                                        t['history'].pop(0)
                        except Exception:
                            pass
                except Exception:
                    pass
            time.sleep(interval)

        now = time.time()
        for key, t in list(self.transfers.items()):
            size = t['size']
            pos = t['current_pos']
            if size > 0 and pos >= size:
                t['completed'] = True

            speed = 0.0
            if len(t['history']) >= 2:
                t_old, pos_old = t['history'][0]
                dt = now - t_old
                dp = pos - pos_old
                if dt > 0 and dp > 0:
                    speed = dp / dt
            t['speed'] = speed

            total_dt = now - t['start_time']
            total_dp = pos - t['start_pos']
            t['avg_speed'] = (total_dp / total_dt) if total_dt > 0 and total_dp > 0 else 0.0

            remaining = size - pos if size > pos else 0
            calc_speed = speed if speed > 1024 * 100 else t['avg_speed']
            t['eta'] = (remaining / calc_speed) if calc_speed > 0 and remaining > 0 else None

    def render_cli(self):
        services = detect_service_destination()
        service_label = services[0] if services else "Apple Podcasts Connect / Web Service"

        lines = []
        lines.append(f"{C_BOLD}{C_MAGENTA}================================================================================{C_RESET}")
        lines.append(f"{C_BOLD}{C_MAGENTA}         LIVE CHROME PODCAST CONNECT / WEB UPLOAD MONITOR                       {C_RESET}")
        lines.append(f"{C_BOLD}{C_MAGENTA}================================================================================{C_RESET}")
        lines.append(f"  {C_BOLD}Target Service:{C_RESET} {C_CYAN}{service_label}{C_RESET}")
        lines.append(f"  {C_BOLD}Active Browser:{C_RESET} Google Chrome (Flatpak / Host)")
        lines.append("")

        if not self.transfers:
            lines.append(f"  {C_YELLOW}Scanning for active Chrome file uploads...{C_RESET}")
            lines.append(f"  {C_DIM}(Waiting for Chrome to open upload streams or start chunk transfers){C_RESET}")
            lines.append("")
            lines.append(f"  {C_BOLD}Hint:{C_RESET} If an upload is queued or running in Podcasts Connect,")
            lines.append(f"        it will appear automatically with real-time speed & progress.")
        else:
            now = time.time()
            for idx, (key, t) in enumerate(self.transfers.items(), 1):
                pos = t['current_pos']
                size = t['size']
                pct = (pos / size * 100.0) if size > 0 else 0.0
                if pct > 100.0:
                    pct = 100.0

                time_since_seen = now - t['last_seen']
                if t['completed']:
                    status = f"{C_BOLD}{C_GREEN}✓ UPLOAD COMPLETED (100%){C_RESET}"
                elif time_since_seen < 3.0:
                    status = f"{C_BOLD}{C_GREEN}🟢 Active Reading / Streaming to Network{C_RESET}"
                elif time_since_seen < 12.0:
                    status = f"{C_BOLD}{C_YELLOW}🟡 Processing Chunks / Awaiting Network Ack{C_RESET}"
                else:
                    status = f"{C_BOLD}{C_BLUE}⏸ Transfer Idle / Finished{C_RESET}"

                bar_len = 30
                filled = int(bar_len * (pct / 100.0))
                bar = "█" * filled + "░" * (bar_len - filled)

                speed_str = f"⚡ {fmt_size(t['speed'])}/s" if t['speed'] > 0 else "⚡ Buffering..."
                avg_str = f"Avg: {fmt_size(t['avg_speed'])}/s" if t['avg_speed'] > 0 else ""
                eta_str = f"⏳ ETA: {fmt_duration(t['eta'])}" if t['eta'] is not None else "⏳ ETA: Calculating..."
                elapsed = fmt_duration(now - t['start_time'])

                lines.append(f"  {C_BOLD}{C_CYAN}[{idx}] 📦 {t['basename']}{C_RESET}")
                lines.append(f"      {C_BOLD}Source File:{C_RESET} {t['real_path']}")
                lines.append(f"      {C_BOLD}File Size:{C_RESET}   {fmt_size(size)} ({size:,} bytes)")
                lines.append(f"      {C_BOLD}Status:{C_RESET}      {status}")
                lines.append(f"      {C_BOLD}Progress:{C_RESET}    [{C_GREEN}{bar}{C_RESET}] {C_BOLD}{pct:5.2f}%{C_RESET}  ({fmt_size(pos)} / {fmt_size(size)})")
                lines.append(f"      {C_BOLD}Speed:{C_RESET}       {speed_str}   |   {avg_str}   |   {eta_str}")
                lines.append(f"      {C_BOLD}Session:{C_RESET}     Uploaded {fmt_size(pos - t['start_pos'])} in {elapsed} (Chrome PID {t['pid']})")
                lines.append("")

        lines.append(f"{C_BOLD}{C_MAGENTA}================================================================================{C_RESET}")
        lines.append(f"  Press {C_BOLD}[Ctrl+C]{C_RESET} to exit monitor and return to menu.")
        return "\n".join(lines)

def main():
    filter_arg = None
    once_mode = False
    check_mode = False
    json_mode = False

    args = sys.argv[1:]
    for a in args:
        if a in ("--once", "-1"):
            once_mode = True
        elif a in ("--check", "-c"):
            check_mode = True
        elif a in ("--json", "-j"):
            json_mode = True
        elif not a.startswith("-"):
            filter_arg = a

    tracker = UploadTracker(filter_term=filter_arg)

    if check_mode:
        tracker.scan_burst(duration=0.9)
        if tracker.transfers:
            for t in tracker.transfers.values():
                pct = (t['current_pos'] / t['size'] * 100) if t['size'] else 0
                print(f"{t['basename']} ({pct:.1f}% - {fmt_size(t['current_pos'])}/{fmt_size(t['size'])})")
            sys.exit(0)
        sys.exit(1)

    if once_mode:
        tracker.scan_burst(duration=1.2)
        if json_mode:
            print(json.dumps(tracker.transfers, indent=2, default=str))
        else:
            print(tracker.render_cli())
        sys.exit(0)

    try:
        while True:
            tracker.scan_burst(duration=0.9, interval=0.03)
            os.system("clear")
            print(tracker.render_cli())
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("\n\nMonitor closed. Exiting gracefully...\n")
        sys.exit(0)

if __name__ == "__main__":
    main()
