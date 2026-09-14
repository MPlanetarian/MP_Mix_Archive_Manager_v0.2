#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.2 - Audio Studio & Hardware Inspector
Comprehensive diagnostics:
  1. Detects all installed music software (DAWs, Editors, Players, DJ Suites, Analyzers, Tag Taggers)
  2. Analyzes audio server & hardware (PipeWire, PulseAudio, ALSA cards, Sinks, Latency & Sample Rates)
  3. Scans all connected MIDI keyboards, DJ mixers, surface controllers, and USB interfaces
  4. Generates an exportable studio specification report
"""

import os
import sys
import subprocess
import shutil
import re
import json
from pathlib import Path

# --- ANSI Terminal Colors ---
BOLD = "\033[1m"
DIM = "\033[2m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
MAGENTA = "\033[0;35m"
CYAN = "\033[0;36m"
WHITE = "\033[1;37m"
NC = "\033[0m"

MUSIC_APPS_CATALOG = [
    # DAWs
    {"name": "REAPER", "category": "DAW", "bins": ["reaper"], "flatpaks": ["fm.reaper.Reaper"]},
    {"name": "Ardour", "category": "DAW", "bins": ["ardour", "ardour8", "ardour7"], "flatpaks": ["org.ardour.Ardour"]},
    {"name": "Bitwig Studio", "category": "DAW", "bins": ["bitwig-studio"], "flatpaks": ["com.bitwig.BitwigStudio"]},
    {"name": "FL Studio", "category": "DAW", "bins": ["flstudio"], "flatpaks": []},
    {"name": "Logic Pro", "category": "DAW", "bins": [], "macos_apps": ["/Applications/Logic Pro.app"]},
    {"name": "GarageBand", "category": "DAW", "bins": [], "macos_apps": ["/Applications/GarageBand.app"]},
    {"name": "LMMS", "category": "DAW", "bins": ["lmms"], "flatpaks": ["io.lmms.LMMS"]},
    {"name": "Bespoke Synth", "category": "Modular DAW", "bins": ["bespokesynth"], "flatpaks": ["org.bespokesynth.BespokeSynth"]},
    # Audio Editors
    {"name": "Audacity", "category": "Audio Editor", "bins": ["audacity"], "flatpaks": ["org.audacityteam.Audacity"]},
    {"name": "Ocenaudio", "category": "Audio Editor", "bins": ["ocenaudio"], "flatpaks": ["com.ocenaudio.Ocenaudio"]},
    {"name": "Kwave", "category": "Audio Editor", "bins": ["kwave"], "flatpaks": ["org.kde.kwave"]},
    {"name": "LosslessCut", "category": "Audio/Video Cutter", "bins": ["losslesscut"], "flatpaks": ["no.mifi.losslesscut"]},
    # DJ Software
    {"name": "Traktor Pro", "category": "DJ Software", "bins": ["traktor"], "flatpaks": []},
    {"name": "Mixxx", "category": "DJ Software", "bins": ["mixxx"], "flatpaks": ["org.mixxx.Mixxx"]},
    # Audio Analyzers & Spectrograms
    {"name": "Spek", "category": "Acoustic Spectrogram", "bins": ["spek"], "flatpaks": ["cc.spek.Spek"]},
    {"name": "Sonic Visualiser", "category": "Audio Analysis", "bins": ["sonic-visualiser"], "flatpaks": ["org.sonicvisualiser.SonicVisualiser"]},
    {"name": "Praat", "category": "Phonetic / Acoustic Analysis", "bins": ["praat"], "flatpaks": ["org.praat.Praat"]},
    {"name": "SoX", "category": "Signal Processor & Spectrogram", "bins": ["sox"], "flatpaks": []},
    # Music Players
    {"name": "cliamp", "category": "Retro Terminal Player", "bins": ["cliamp"], "flatpaks": []},
    {"name": "Strawberry", "category": "Hi-Fi Music Player", "bins": ["strawberry"], "flatpaks": ["org.strawberrymusicplayer.strawberry"]},
    {"name": "VLC Media Player", "category": "Media Player", "bins": ["vlc"], "flatpaks": ["org.videolan.VLC"]},
    {"name": "Haruna", "category": "Media Player", "bins": ["haruna"], "flatpaks": ["org.kde.haruna"]},
    {"name": "Kodi", "category": "Media Center", "bins": ["kodi"], "flatpaks": ["tv.kodi.Kodi"]},
    {"name": "MPV", "category": "Minimalist Media Player", "bins": ["mpv"], "flatpaks": ["io.mpv.Mpv"]},
    {"name": "foobar2000", "category": "Audio Player", "bins": ["foobar2000"], "flatpaks": []},
    # Meta Tag Editors
    {"name": "MusicBrainz Picard", "category": "Meta Tag Editor", "bins": ["picard"], "flatpaks": ["org.musicbrainz.Picard"]},
    {"name": "Kid3", "category": "Meta Tag Editor", "bins": ["kid3", "kid3-qt"], "flatpaks": ["net.sourceforge.Kid3"]}
]

def check_command(cmd):
    return shutil.which(cmd) is not None

def get_installed_flatpaks():
    if not check_command("flatpak"):
        return set()
    try:
        res = subprocess.run(["flatpak", "list", "--app", "--columns=application"], capture_output=True, text=True, timeout=5)
        if res.returncode == 0:
            return set(res.stdout.strip().split("\n"))
    except Exception:
        pass
    return set()

def detect_music_software():
    installed_apps = []
    flatpaks = get_installed_flatpaks()
    
    for item in MUSIC_APPS_CATALOG:
        found = False
        inst_type = ""
        # 1. System binary
        for b in item.get("bins", []):
            loc = shutil.which(b)
            if loc:
                found = True
                inst_type = f"System Binary ({loc})"
                break
        # 2. Flatpak
        if not found:
            for fp in item.get("flatpaks", []):
                if fp in flatpaks:
                    found = True
                    inst_type = f"Flatpak ({fp})"
                    break
        # 3. macOS App bundle
        if not found and sys.platform == "darwin":
            for mapp in item.get("macos_apps", []):
                if os.path.isdir(mapp):
                    found = True
                    inst_type = "macOS Bundle"
                    break
        # 4. Check local bin/
        if not found:
            local_bin = Path(__file__).resolve().parent / "bin" / item["name"].lower()
            if local_bin.is_file():
                found = True
                inst_type = f"Local Manager Binary ({local_bin})"
                
        if found:
            installed_apps.append({
                "name": item["name"],
                "category": item["category"],
                "type": inst_type
            })
            
    return installed_apps

def detect_audio_subsystem():
    info = {"server": "Unknown", "details": [], "default_sink": "Unknown", "volume": "Unknown"}
    
    # Check PipeWire / WirePlumber
    if check_command("wpctl"):
        info["server"] = "PipeWire (WirePlumber Session Manager)"
        try:
            vol_res = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True, timeout=2)
            if vol_res.returncode == 0:
                info["volume"] = vol_res.stdout.strip()
        except Exception:
            pass
            
        try:
            stat_res = subprocess.run(["wpctl", "status"], capture_output=True, text=True, timeout=3)
            if stat_res.returncode == 0:
                # Parse Audio Sinks block
                lines = stat_res.stdout.split("\n")
                sinks = []
                in_sinks = False
                for l in lines:
                    if "Audio" in l and "Sinks:" in l:
                        in_sinks = True
                        continue
                    if in_sinks:
                        if l.strip().startswith("├─") or l.strip().startswith("│") or l.strip().startswith("└─"):
                            clean_l = l.strip().lstrip("├─│└ ").strip()
                            if clean_l and not clean_l.startswith("Streams:"):
                                sinks.append(clean_l)
                        else:
                            in_sinks = False
                if sinks:
                    info["details"] = sinks[:6]
        except Exception:
            pass
    elif check_command("pactl"):
        info["server"] = "PulseAudio / PipeWire-Pulse"
        try:
            res = subprocess.run(["pactl", "info"], capture_output=True, text=True, timeout=2)
            for line in res.stdout.split("\n"):
                if "Default Sink:" in line:
                    info["default_sink"] = line.split(":", 1)[1].strip()
                elif "Server Name:" in line:
                    info["server"] = line.split(":", 1)[1].strip()
        except Exception:
            pass
            
    # ALSA Card Details
    alsa_cards = []
    cards_file = Path("/proc/asound/cards")
    if cards_file.is_file():
        try:
            with open(cards_file, "r") as f:
                content = f.read().strip()
                for block in content.split("\n\n"):
                    lines = [b.strip() for b in block.split("\n") if b.strip()]
                    if lines:
                        alsa_cards.append(" | ".join(lines[:2]))
        except Exception:
            pass
    info["alsa_cards"] = alsa_cards
    
    return info

def detect_midi_and_controllers():
    controllers = []
    
    # 1. ALSA Sequencer (amidi / aconnect)
    if check_command("amidi"):
        try:
            res = subprocess.run(["amidi", "-l"], capture_output=True, text=True, timeout=2)
            if res.returncode == 0:
                for line in res.stdout.strip().split("\n")[1:]:
                    if line.strip():
                        parts = line.split(None, 2)
                        if len(parts) >= 3:
                            controllers.append({
                                "name": parts[2].strip(),
                                "port": parts[1].strip(),
                                "type": "Hardware MIDI Port (amidi)"
                            })
        except Exception:
            pass
            
    # 2. Sequencer clients (aconnect)
    if check_command("aconnect"):
        try:
            res = subprocess.run(["aconnect", "-l"], capture_output=True, text=True, timeout=2)
            if res.returncode == 0:
                cur_client = ""
                for line in res.stdout.split("\n"):
                    if line.startswith("client ") and "Through" not in line and "System" not in line:
                        m = re.search(r"client \d+:\s+'([^']+)'", line)
                        if m:
                            cur_client = m.group(1)
                            # avoid duplicates with amidi
                            if not any(cur_client.lower() in c["name"].lower() for c in controllers):
                                controllers.append({
                                    "name": cur_client,
                                    "port": line.split(":")[0].strip(),
                                    "type": "ALSA Sequencer Client"
                                })
        except Exception:
            pass
            
    # 3. USB Inspection (Class 01 / Known Audio & Controller Vendors)
    if check_command("lsusb"):
        try:
            res = subprocess.run(["lsusb"], capture_output=True, text=True, timeout=3)
            if res.returncode == 0:
                known_brands = ["AKAI", "Arturia", "Pioneer", "Roland", "Korg", "Yamaha", "Focusrite", "Behringer", "Native Instruments", "Novation", "Valve", "Logitech"]
                for line in res.stdout.strip().split("\n"):
                    for brand in known_brands:
                        if brand.lower() in line.lower() and not any(brand.lower() in c["name"].lower() for c in controllers):
                            parts = line.split(":", 2)
                            desc = parts[2].strip() if len(parts) >= 3 else line
                            controllers.append({
                                "name": desc,
                                "port": "USB",
                                "type": "USB Surface / Audio Device"
                            })
                            break
        except Exception:
            pass
            
    return controllers

def generate_studio_report():
    apps = detect_music_software()
    audio = detect_audio_subsystem()
    controllers = detect_midi_and_controllers()
    
    report_lines = [
        "======================================================================",
        "             STUDIO HARDWARE & AUDIO SOFTWARE DIAGNOSTIC              ",
        f"               Generated: {__import__('datetime').datetime.now()}",
        "======================================================================",
        "",
        f"[1] AUDIO SUBSYSTEM & DRIVERS:",
        f"  Server Engine:     {audio['server']}",
        f"  Current Volume:    {audio['volume']}"
    ]
    if audio.get("default_sink"):
        report_lines.append(f"  Default Sink:      {audio['default_sink']}")
    if audio.get("details"):
        report_lines.append("  Active Playback Sinks:")
        for s in audio["details"]:
            report_lines.append(f"    • {s}")
    if audio.get("alsa_cards"):
        report_lines.append("  ALSA Physical Cards:")
        for c in audio["alsa_cards"]:
            report_lines.append(f"    • {c}")
            
    report_lines.extend([
        "",
        f"[2] MIDI KEYBOARDS, MIXERS & SURFACE CONTROLLERS ({len(controllers)} Detected):"
    ])
    if controllers:
        for idx, c in enumerate(controllers, start=1):
            report_lines.append(f"  {idx:2d}) {c['name']} [{c['type']}] ({c['port']})")
    else:
        report_lines.append("  • No external MIDI hardware detected.")
        
    report_lines.extend([
        "",
        f"[3] INSTALLED MUSIC & AUDIO APPLICATIONS ({len(apps)} Detected):"
    ])
    for idx, a in enumerate(apps, start=1):
        report_lines.append(f"  {idx:2d}) {a['name']:<22} | Category: {a['category']:<24} | {a['type']}")
        
    report_lines.append("\n======================================================================\n")
    return "\n".join(report_lines)

def interactive_ui():
    apps = detect_music_software()
    audio = detect_audio_subsystem()
    controllers = detect_midi_and_controllers()
    
    os.system('clear' if os.name == 'posix' else 'cls')
    print(f"{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"{BOLD}{MAGENTA}      Studio Diagnostic: Installed Music Apps & Audio Hardware        {NC}")
    print(f"{BOLD}{MAGENTA}======================================================================{NC}")
    
    print(f"\n{BOLD}{BLUE}─── [ 1. AUDIO SERVER & HARDWARE ROUTING ] ───────────────────────────{NC}")
    print(f"  Audio Server:      {GREEN}{audio['server']}{NC}")
    print(f"  Volume Status:     {CYAN}{audio['volume']}{NC}")
    if audio.get("details"):
        print(f"  Audio Sinks & Outputs:")
        for s in audio["details"][:4]:
            print(f"    {DIM}•{NC} {s}")
    if audio.get("alsa_cards"):
        print(f"  ALSA Soundcards:")
        for c in audio["alsa_cards"][:3]:
            print(f"    {DIM}•{NC} {c}")
            
    print(f"\n{BOLD}{BLUE}─── [ 2. MIDI CONTROLLERS & MIXING SURFACES ({len(controllers)}) ] ─────────────{NC}")
    if controllers:
        for idx, c in enumerate(controllers, start=1):
            print(f"  {BOLD}{CYAN}{idx:2d}){NC} {BOLD}{c['name']}{NC} {DIM}[{c['type']} - {c['port']}]{NC}")
    else:
        print(f"  {YELLOW}No external MIDI keyboards or controllers detected.{NC}")
        
    print(f"\n{BOLD}{BLUE}─── [ 3. INSTALLED MUSIC & AUDIO SOFTWARE ({len(apps)}) ] ──────────────────{NC}")
    for idx, a in enumerate(apps, start=1):
        print(f"  {BOLD}{CYAN}{idx:2d}){NC} {BOLD}{a['name']:<22}{NC} {MAGENTA}[{a['category']}]{NC} {DIM}{a['type']}{NC}")
        
    print(f"\n{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
    print(f"Options:")
    print(f"  ${BOLD}${CYAN} 1)${NC} Export Full Diagnostic Report (assets/studio_hardware_report.txt)")
    print(f"  ${BOLD}${CYAN} 2)${NC} Refresh Hardware & Software Detection")
    print(f"\n  ${BOLD}${CYAN} 0)${NC} Return to Main Menu ${DIM}(or 'q')${NC}")
    print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
    
    choice = input(f"{BOLD}Enter choice: {NC}").strip()
    if choice == '1':
        report_text = generate_studio_report()
        out_file = Path(__file__).resolve().parent / "assets" / "studio_hardware_report.txt"
        out_file.parent.mkdir(parents=True, exist_ok=True)
        with open(out_file, "w", encoding="utf-8") as f:
            f.write(report_text)
        print(f"\n{GREEN}✓ Diagnostic report saved to:{NC} {BOLD}{out_file}{NC}")
        input("Press Enter to continue...")
    elif choice == '2':
        interactive_ui()

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--report":
        print(generate_studio_report())
    else:
        try:
            interactive_ui()
        except KeyboardInterrupt:
            print("")
            sys.exit(0)
