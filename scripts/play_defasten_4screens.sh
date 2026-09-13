#!/usr/bin/env bash
# ==============================================================================
# Script: play_defasten_4screens.sh
# Purpose: Open the Defasten VLC playlist on the Desktop in fullscreen mode across
#          all 4 connected displays in VLC with infinite playlist looping.
# ==============================================================================

set -euo pipefail

# Configuration
DEFAULT_PLAYLIST_DIR="$HOME/Desktop/DESKTOP"
[ ! -d "$DEFAULT_PLAYLIST_DIR" ] && DEFAULT_PLAYLIST_DIR="$HOME/Desktop"
DEFAULT_PLAYLIST_XSPF="$DEFAULT_PLAYLIST_DIR/Defasten.xspf"
DEFAULT_PLAYLIST_M3U="$DEFAULT_PLAYLIST_DIR/Defasten.m3u"
MUTE_SECONDARY="${MUTE_SECONDARY:-true}" # Set to false if you want audio on all 4 screens
SHUFFLE=true                             # Shuffle playlist order on each run without modifying source
DETACH=false
ONLY_4K="${ONLY_4K:-false}"

# Helper: Show usage
usage() {
    cat << 'EOF'
Usage: play_defasten_4screens.sh [OPTIONS] [PLAYLIST_PATH]

Options:
  --stop            Terminate all currently running VLC instances
  --detach, -d      Launch VLC instances in background and exit immediately
  --4k-only         Only launch on the 4K display (HDMI-0)
  --all-audio       Enable audio on all displays (can cause echo)
  --mute-all        Mute audio on all displays
  --no-shuffle      Do not shuffle the playlist (play in original order)
  --help, -h        Show this help message

Default playlist:
  ~/Desktop/DESKTOP/Defasten.xspf (or Defasten.m3u)
EOF
    exit 0
}

# Helper: Stop running VLC instances
stop_vlc() {
    echo "Stopping all VLC instances..."
    pkill -x vlc 2>/dev/null || true
    rm -f /tmp/defasten_shuffled_*.xspf /tmp/defasten_shuffled_*.m3u 2>/dev/null || true
    sleep 0.5
    echo "VLC instances stopped."
}

# Parse command line arguments
PLAYLIST=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --stop)
            stop_vlc
            exit 0
            ;;
        --detach|-d)
            DETACH=true
            shift
            ;;
        --4k-only|--only-4k)
            ONLY_4K=true
            shift
            ;;
        --all-audio)
            MUTE_SECONDARY=false
            shift
            ;;
        --mute-all)
            MUTE_SECONDARY="all"
            shift
            ;;
        --no-shuffle)
            SHUFFLE=false
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            if [ -z "$PLAYLIST" ]; then
                PLAYLIST="$1"
            fi
            shift
            ;;
    esac
done

# Resolve playlist file
if [ -z "$PLAYLIST" ]; then
    if [ -f "$DEFAULT_PLAYLIST_XSPF" ]; then
        PLAYLIST="$DEFAULT_PLAYLIST_XSPF"
    elif [ -f "$DEFAULT_PLAYLIST_M3U" ]; then
        PLAYLIST="$DEFAULT_PLAYLIST_M3U"
    elif [ -f "$HOME/Desktop/Defasten.xspf" ]; then
        PLAYLIST="$HOME/Desktop/Defasten.xspf"
    elif [ -f "$HOME/Desktop/Defasten.m3u" ]; then
        PLAYLIST="$HOME/Desktop/Defasten.m3u"
    else
        echo "Error: Defasten playlist not found!"
        echo "Expected either: $DEFAULT_PLAYLIST_XSPF or $DEFAULT_PLAYLIST_M3U"
        exit 1
    fi
fi

if [ ! -f "$PLAYLIST" ]; then
    echo "Error: Playlist file '$PLAYLIST' does not exist."
    exit 1
fi

# Prepare playlist (shuffle without modifying original playlist file)
PLAYLIST_TO_PLAY="$PLAYLIST"
SHUFFLED_PLAYLIST=""
if [ "$SHUFFLE" = true ]; then
    EXT="${PLAYLIST##*.}"
    SHUFFLED_PLAYLIST=$(mktemp "/tmp/defasten_shuffled_XXXXXX.${EXT}")
    echo "Generating randomized session playlist: $SHUFFLED_PLAYLIST"
    echo "Source playlist file is kept completely unchanged."

    python3 -c "
import os, sys, random
import xml.etree.ElementTree as ET

input_path = '$PLAYLIST'
output_path = '$SHUFFLED_PLAYLIST'
ext = os.path.splitext(input_path)[1].lower()

if ext == '.xspf':
    ET.register_namespace('', 'http://xspf.org/ns/0/')
    tree = ET.parse(input_path)
    root = tree.getroot()
    ns = {'ns': 'http://xspf.org/ns/0/'} if '}' in root.tag else {}
    tracklist = root.find('ns:trackList' if ns else 'trackList', ns)
    if tracklist is not None:
        tracks = list(tracklist)
        for t in tracks:
            tracklist.remove(t)
        random.shuffle(tracks)
        for t in tracks:
            tracklist.append(t)
    tree.write(output_path, encoding='utf-8', xml_declaration=True)
else:
    with open(input_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = [l.strip() for l in f if l.strip()]
    header = lines[0] if lines and lines[0].startswith('#EXTM3U') else '#EXTM3U'
    items = []
    i = 1 if lines and lines[0].startswith('#EXTM3U') else 0
    while i < len(lines):
        if lines[i].startswith('#EXTINF:'):
            extinf = lines[i]
            path = lines[i+1] if i+1 < len(lines) else ''
            items.append((extinf, path))
            i += 2
        else:
            items.append(('', lines[i]))
            i += 1
    random.shuffle(items)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(header + '\n')
        for extinf, path in items:
            if extinf:
                f.write(extinf + '\n')
            if path:
                f.write(path + '\n')
"
    PLAYLIST_TO_PLAY="$SHUFFLED_PLAYLIST"
fi

echo "=========================================================="
echo " Starting Defasten 4-Screen Fullscreen VLC Playback"
echo " Source:   $PLAYLIST"
echo " Session:  $PLAYLIST_TO_PLAY (shuffled: $SHUFFLE)"
echo "=========================================================="

# Check for qdbus for KWin window management
QDBUS_BIN=$(command -v qdbus-qt6 || command -v qdbus || true)
if [ -z "$QDBUS_BIN" ]; then
    echo "Error: qdbus/qdbus-qt6 not found. Required for KDE Plasma window positioning."
    exit 1
fi

# Clean up any previously running VLC instances to ensure clean placement
if pgrep -x vlc >/dev/null 2>&1; then
    echo "Detected existing VLC process(es). Restarting clean session..."
    pkill -x vlc 2>/dev/null || true
    sleep 1
fi

# Determine number of connected outputs/screens
if [ "$ONLY_4K" = true ]; then
    NUM_DISPLAYS=1
    echo "Launching 1 VLC instance targeted for 4K display in loop mode..."
else
    NUM_DISPLAYS=4
    echo "Launching $NUM_DISPLAYS VLC instances across all screens in loop mode..."
fi
pids=()

for ((i = 0; i < NUM_DISPLAYS; i++)); do
    audio_flags=()
    if [ "$MUTE_SECONDARY" = "all" ]; then
        audio_flags=("--no-audio")
    elif [ "$MUTE_SECONDARY" = "true" ] && [ "$i" -ne 0 ]; then
        # Primary display (i=0) keeps audio; secondary displays are muted to avoid audio echo
        audio_flags=("--no-audio")
    fi

    # Launch VLC instance with native fullscreen and loop mode
    vlc --no-one-instance \
        --fullscreen \
        --loop \
        --no-video-title-show \
        --mouse-hide-timeout=1000 \
        --disable-screensaver \
        "${audio_flags[@]}" \
        "$PLAYLIST_TO_PLAY" >/dev/null 2>&1 &

    pids+=($!)
done

echo "Spawned VLC PIDs: ${pids[*]}"

# Wait for VLC windows to be created and mapped
echo "Waiting for VLC window(s) to map..."
timeout=10
start_time=$(date +%s)
while true; do
    ready_count=0
    win_list=$(wmctrl -l -p 2>/dev/null || true)
    for pid in "${pids[@]}"; do
        if echo "$win_list" | awk '{print $3}' | grep -qw "$pid"; then
            ready_count=$((ready_count + 1))
        fi
    done

    if [ "$ready_count" -ge "${#pids[@]}" ]; then
        break
    fi

    now=$(date +%s)
    if [ $((now - start_time)) -ge $timeout ]; then
        echo "Timeout waiting for windows. Proceeding with mapping..."
        break
    fi
    sleep 0.15
done

# Brief pause to ensure all window surfaces are fully initialized by Qt/Xwayland
sleep 0.5

# Distribute VLC instance(s) onto dedicated display(s) in fullscreen via KWin Scripting
SCRIPT_PATH=$(mktemp /tmp/kwin_vlc_position_XXXXXX.js)
SCRIPT_NAME="vlc_multiscreen_$RANDOM"

PID_LIST=$(IFS=,; echo "${pids[*]}")

cat << JSEOF > "$SCRIPT_PATH"
let wins = workspace.windowList();
let screens = workspace.screens;
let vlcPids = [${PID_LIST}];
let targetWindow = null;

// Find 4K / HDMI screen if available
let screen4k = screens[0];
for (let s = 0; s < screens.length; s++) {
    let sc = screens[s];
    if ((sc.name && sc.name.indexOf("HDMI") !== -1) || (sc.geometry && sc.geometry.width >= 3840)) {
        screen4k = sc;
        break;
    }
}

if (${ONLY_4K}) {
    for (let j = 0; j < wins.length; j++) {
        let w = wins[j];
        if (w.pid === vlcPids[0]) {
            workspace.sendClientToScreen(w, screen4k);
            w.fullScreen = true;
            targetWindow = w;
            break;
        }
    }
} else {
    for (let i = 0; i < vlcPids.length; i++) {
        let pid = vlcPids[i];
        let screen = (i < screens.length) ? screens[i] : screens[screens.length - 1];
        for (let j = 0; j < wins.length; j++) {
            let w = wins[j];
            if (w.pid === pid) {
                workspace.sendClientToScreen(w, screen);
                w.fullScreen = true;
                if (i === 0 || (screen.name && screen.name.indexOf("HDMI") !== -1)) {
                    targetWindow = w;
                }
                break;
            }
        }
    }
}

if (targetWindow) {
    workspace.raiseWindow(targetWindow);
    workspace.activeWindow = targetWindow;
}
JSEOF

"$QDBUS_BIN" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$SCRIPT_PATH" "$SCRIPT_NAME" >/dev/null
"$QDBUS_BIN" org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
sleep 0.8
"$QDBUS_BIN" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$SCRIPT_NAME" >/dev/null 2>&1 || true
rm -f "$SCRIPT_PATH"

# Explicitly activate the target window to force KDE Plasma taskbar to hide
if [ -n "${pids[0]:-}" ]; then
    active_win=$(wmctrl -l -p 2>/dev/null | awk -v pid="${pids[0]}" '$3 == pid {print $1}')
    if [ -n "$active_win" ]; then
        wmctrl -i -a "$active_win" 2>/dev/null || true
        if command -v xdotool >/dev/null 2>&1; then
            xdotool windowactivate "$active_win" 2>/dev/null || true
        fi
    fi
fi

if [ "$ONLY_4K" = true ]; then
    echo "1 VLC window mapped to 4K display in fullscreen mode and looping indefinitely."
else
    echo "All 4 VLC windows mapped to displays in fullscreen mode and looping indefinitely."
fi

if [ "$DETACH" = true ]; then
    echo "Detached mode: VLC instances are running in the background."
    echo "Run '$0 --stop' or ~/Desktop/DESKTOP/close_allapps.sh to stop playback."
    exit 0
fi

# Interactive mode: Keep running and handle cleanup gracefully
cleanup() {
    echo ""
    echo "Terminating VLC instance(s)..."
    for pid in "${pids[@]}"; do
        kill -9 "$pid" 2>/dev/null || true
    done
    pkill -x vlc 2>/dev/null || true
    if [ -n "${SHUFFLED_PLAYLIST:-}" ] && [ -f "$SHUFFLED_PLAYLIST" ]; then
        rm -f "$SHUFFLED_PLAYLIST" 2>/dev/null || true
    fi
    echo "Playback terminated."
    exit 0
}

trap cleanup SIGINT SIGTERM

echo ""
if [ "$ONLY_4K" = true ]; then
    echo "Playback is active on 4K display."
    echo "Press Ctrl+C in this terminal to stop playback (or run '$0 --stop')."
else
    echo "Playback is active across all 4 displays."
    echo "Press Ctrl+C in this terminal to stop all 4 displays (or run '$0 --stop')."
fi

# Wait on all processes
wait
