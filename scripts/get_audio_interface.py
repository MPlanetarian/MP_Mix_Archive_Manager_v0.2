#!/usr/bin/env python3
"""
scripts/get_audio_interface.py - Active Audio Interface & Latency Inspector
Cross-Platform detection of active default sound output device and buffer latency:
- Linux (PipeWire / WirePlumber / PulseAudio / ALSA)
- macOS (CoreAudio / system_profiler)
- Windows / WSL (PowerShell Win32_SoundDevice / Windows CoreAudio)
- FreeBSD (/dev/sndstat)
"""

import sys
import os
import re
import json
import platform
import subprocess

def get_audio_info():
    info = {
        "interface": "Default Audio Output",
        "latency_ms": None,
        "latency_str": "N/A",
        "rate": 48000,
        "quantum": 1024,
        "sound_system": "Audio",
        "details": ""
    }

    sys_name = platform.system().lower()

    if sys_name == 'linux':
        _probe_linux(info)
    elif sys_name == 'darwin':
        _probe_macos(info)
    elif sys_name in ('windows', 'cygwin') or 'microsoft' in platform.release().lower():
        _probe_windows(info)
    elif 'bsd' in sys_name:
        _probe_freebsd(info)

    # Format latency string if ms is calculated
    if info["latency_ms"] is not None and info["latency_str"] == "N/A":
        rate_khz = f"{info['rate']//1000}kHz" if info['rate'] % 1000 == 0 else f"{info['rate']/1000:.1f}kHz"
        info["latency_str"] = f"{info['latency_ms']:.1f}ms ({info['quantum']} spls @ {rate_khz})"

    return info

def _probe_linux(info):
    # 1. Probe PipeWire / WirePlumber via wpctl
    wpctl_found = False
    try:
        p = subprocess.run(['wpctl', 'inspect', '@DEFAULT_AUDIO_SINK@'], capture_output=True, text=True, timeout=0.35)
        if p.returncode == 0 and p.stdout:
            wpctl_found = True
            info["sound_system"] = "PipeWire"
            for line in p.stdout.splitlines():
                if 'node.description =' in line:
                    m = re.search(r'node\.description\s*=\s*\"([^\"]+)\"', line)
                    if m:
                        info["interface"] = m.group(1).strip()
                        break
                elif 'media.name =' in line and info["interface"] == "Default Audio Output":
                    m = re.search(r'media\.name\s*=\s*\"([^\"]+)\"', line)
                    if m:
                        info["interface"] = m.group(1).strip()
                elif 'api.bluez5.codec =' in line:
                    m = re.search(r'api\.bluez5\.codec\s*=\s*\"([^\"]+)\"', line)
                    if m:
                        info["details"] = f"Bluetooth {m.group(1).upper()}"
    except Exception:
        pass

    # Fallback to wpctl status if inspect didn't catch description
    if info["interface"] == "Default Audio Output":
        try:
            p = subprocess.run(['wpctl', 'status'], capture_output=True, text=True, timeout=0.35)
            if p.returncode == 0:
                in_sinks = False
                for line in p.stdout.splitlines():
                    if 'Sinks:' in line:
                        in_sinks = True
                        continue
                    if in_sinks:
                        if line.strip().startswith('Sources:') or line.strip().startswith('Filters:'):
                            break
                        if '*' in line:
                            cleaned = re.sub(r'^\s*\*\s*\d+\.\s*', '', line)
                            cleaned = re.sub(r'\[.*\]', '', cleaned).strip()
                            if cleaned:
                                info["interface"] = cleaned
                                info["sound_system"] = "PipeWire"
                                wpctl_found = True
                                break
        except Exception:
            pass

    # Probe PipeWire quantum and clock rate via pw-metadata
    pw_meta_found = False
    try:
        p2 = subprocess.run(['pw-metadata', '-n', 'settings'], capture_output=True, text=True, timeout=0.35)
        if p2.returncode == 0:
            pw_meta_found = True
            info["sound_system"] = "PipeWire"
            rate = 48000
            quantum = 1024
            for line in p2.stdout.splitlines():
                if "key:'clock.rate'" in line:
                    m = re.search(r"value:'(\d+)'", line)
                    if m: rate = int(m.group(1))
                elif "key:'clock.quantum'" in line:
                    m = re.search(r"value:'(\d+)'", line)
                    if m: quantum = int(m.group(1))
            info["rate"] = rate
            info["quantum"] = quantum
            info["latency_ms"] = (quantum / rate) * 1000.0
            khz = f"{rate//1000}kHz" if rate % 1000 == 0 else f"{rate/1000:.1f}kHz"
            info["latency_str"] = f"{info['latency_ms']:.1f}ms ({quantum} @ {khz})"
    except Exception:
        pass

    # 2. Check ALSA hardware buffer parameters if pw-metadata not available or for direct ALSA
    if not pw_meta_found or info["interface"] == "Default Audio Output":
        try:
            import glob
            hw_files = glob.glob('/proc/asound/card*/pcm*p/sub*/hw_params')
            for hf in hw_files:
                try:
                    with open(hf, 'r', encoding='utf-8', errors='ignore') as f:
                        c = f.read()
                    if 'rate:' in c and 'period_size:' in c:
                        m_rate = re.search(r'rate:\s*(\d+)', c)
                        m_period = re.search(r'period_size:\s*(\d+)', c)
                        if m_rate and m_period:
                            rate = int(m_rate.group(1))
                            period = int(m_period.group(1))
                            if rate > 0 and period > 0 and not pw_meta_found:
                                info["rate"] = rate
                                info["quantum"] = period
                                info["latency_ms"] = (period / rate) * 1000.0
                                khz = f"{rate//1000}kHz" if rate % 1000 == 0 else f"{rate/1000:.1f}kHz"
                                info["latency_str"] = f"{info['latency_ms']:.1f}ms ({period} @ {khz})"
                                break
                except Exception:
                    pass
        except Exception:
            pass

    # 3. PulseAudio fallback (pactl)
    if info["interface"] == "Default Audio Output":
        try:
            p3 = subprocess.run(['pactl', 'info'], capture_output=True, text=True, timeout=0.35)
            if p3.returncode == 0:
                for line in p3.stdout.splitlines():
                    if 'Default Sink:' in line:
                        sink_name = line.split(':', 1)[1].strip()
                        info["interface"] = sink_name.replace('alsa_output.', '').replace('bluez_output.', '')
                        if 'PipeWire' in p3.stdout:
                            info["sound_system"] = "PipeWire"
                        else:
                            info["sound_system"] = "PulseAudio"
                        break
        except Exception:
            pass

    # 4. ALSA cards fallback
    if info["interface"] == "Default Audio Output" and os.path.exists('/proc/asound/cards'):
        try:
            with open('/proc/asound/cards', 'r', encoding='utf-8', errors='ignore') as f:
                cards = f.read()
            # Look for non-loopback soundcards
            for line in cards.splitlines():
                if ' - ' in line and not line.strip().startswith('0 [Loopback'):
                    info["interface"] = line.split(' - ', 1)[1].strip()
                    info["sound_system"] = "ALSA"
                    break
        except Exception:
            pass

def _probe_macos(info):
    info["sound_system"] = "CoreAudio"
    try:
        # Query default audio output via AppleScript or system_profiler
        ascript = '''
        tell application "System Events"
            try
                return name of current audio output device
            end try
        end tell
        '''
        p = subprocess.run(['osascript', '-e', ascript], capture_output=True, text=True, timeout=0.6)
        if p.returncode == 0 and p.stdout.strip():
            info["interface"] = p.stdout.strip()
        else:
            # Fallback to system_profiler
            p2 = subprocess.run(['system_profiler', 'SPAudioDataType'], capture_output=True, text=True, timeout=0.8)
            if p2.returncode == 0:
                in_output = False
                for line in p2.stdout.splitlines():
                    if 'Default Output Device: Yes' in line:
                        in_output = True
                    elif in_output and ':' in line and not line.strip().startswith('Default'):
                        info["interface"] = line.split(':', 1)[0].strip()
                        break
        info["rate"] = 48000
        info["quantum"] = 512
        info["latency_ms"] = (512 / 48000) * 1000.0
        info["latency_str"] = "10.7ms (512 @ 48kHz)"
    except Exception:
        info["interface"] = "macOS Built-in Output"

def _probe_windows(info):
    info["sound_system"] = "WASAPI"
    try:
        cmd = ['powershell.exe', '-NoProfile', '-Command', 
               'Get-CimInstance Win32_SoundDevice | Select-Object -First 1 -ExpandProperty Name']
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=1.0)
        if p.returncode == 0 and p.stdout.strip():
            info["interface"] = p.stdout.strip().splitlines()[0].strip()
        info["rate"] = 48000
        info["quantum"] = 480
        info["latency_ms"] = 10.0
        info["latency_str"] = "10.0ms (480 @ 48kHz)"
    except Exception:
        info["interface"] = "Windows Audio Endpoint"

def _probe_freebsd(info):
    info["sound_system"] = "OSS"
    if os.path.exists('/dev/sndstat'):
        try:
            with open('/dev/sndstat', 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            for line in content.splitlines():
                if 'default' in line.lower() or line.startswith('pcm'):
                    info["interface"] = line.strip()
                    break
        except Exception:
            info["interface"] = "FreeBSD OSS Audio"

def main():
    info = get_audio_info()

    if '--json' in sys.argv:
        print(json.dumps(info, indent=2))
        return

    if '--latency' in sys.argv:
        print(info["latency_str"])
        return

    if '--interface' in sys.argv or '--name' in sys.argv:
        print(info["interface"])
        return

    if '--system' in sys.argv:
        print(info["sound_system"])
        return

    if '--full' in sys.argv:
        # Full formatted one-liner
        print(f"{info['interface']}  │  Latency: {info['latency_str']}  │  Mode: {info['sound_system']}")
        return

    # Default output
    print(f"{info['interface']}|{info['latency_str']}|{info['sound_system']}")

if __name__ == '__main__':
    main()
