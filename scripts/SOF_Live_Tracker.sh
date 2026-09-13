#!/usr/bin/env bash

# ================================
# CONFIGURATION & PATHS
# ================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_DIR="FLAC_CONVERTED_OUTPUTS"
PLAYLIST_NAME="Stream of Frequency"
CLIAMP_BIN="${HOME}/.local/bin/cliamp"
[ -x "$CLIAMP_BIN" ] || CLIAMP_BIN="$(command -v cliamp 2>/dev/null || true)"
LOCAL_HISTORY_DIR="$SCRIPT_DIR/Traktor 3.11.1/History"

# ANSI Color Codes & Formatting Styles
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_CYAN="\033[1;36m"
C_MAGENTA="\033[1;35m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_BLUE="\033[1;34m"

format_hms() {
    local secs="${1%.*}"
    [[ "$secs" =~ ^[0-9]+$ ]] || { echo "--:--:--"; return; }
    printf "%d:%02d:%02d" $((secs / 3600)) $(((secs % 3600) / 60)) $((secs % 60))
}

# Prints: state<TAB>path<TAB>title<TAB>playlist<TAB>position<TAB>duration
get_strawberry_status() {
    python3 -c '
import subprocess, re, urllib.parse, sys

try:
    status = subprocess.check_output(["qdbus", "org.mpris.MediaPlayer2.strawberry", "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player.PlaybackStatus"], stderr=subprocess.DEVNULL).decode().strip()
except Exception:
    sys.exit(1)

try:
    meta_raw = subprocess.check_output(["qdbus", "org.mpris.MediaPlayer2.strawberry", "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player.Metadata"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
except Exception:
    meta_raw = ""

meta = {}
for line in meta_raw.splitlines():
    if ": " in line:
        k, v = line.split(": ", 1)
        meta[k.strip()] = v.strip()

track_url = meta.get("xesam:url", "")
if track_url.startswith("file://"):
    track_url = track_url[7:]
elif track_url.startswith("file:/"):
    track_url = track_url[6:]
track_url = urllib.parse.unquote(track_url)

title = meta.get("xesam:title", "")
if not title and track_url:
    import os
    title = os.path.splitext(os.path.basename(track_url))[0]

dur_us = meta.get("mpris:length", "0")
try:
    dur_s = int(dur_us) // 1000000
except Exception:
    dur_s = 0

try:
    pos_raw = subprocess.check_output(["qdbus", "org.mpris.MediaPlayer2.strawberry", "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player.Position"], stderr=subprocess.DEVNULL).decode().strip()
    pos_s = int(pos_raw) // 1000000
except Exception:
    pos_s = 0

playlist = ""
try:
    pl_raw = subprocess.check_output(["qdbus", "--literal", "org.mpris.MediaPlayer2.strawberry", "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Playlists.ActivePlaylist"], stderr=subprocess.DEVNULL).decode().strip()
    m = re.search(r"\[Argument: \(oss\) \[ObjectPath: [^\]]+\], \"([^\"]*)\"", pl_raw)
    if m:
        playlist = m.group(1)
except Exception:
    pass

print("\t".join([
    str(status.lower()),
    str(track_url),
    str(title),
    str(playlist),
    str(pos_s),
    str(dur_s)
]))
' 2>/dev/null
}

# Prints: state<TAB>path<TAB>title<TAB>playlist<TAB>position<TAB>duration
get_cliamp_status() {
    [ -n "$CLIAMP_BIN" ] || return 1
    "$CLIAMP_BIN" status --json 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if not data.get("ok"):
    sys.exit(1)
track = data.get("track") or {}
print("\t".join([
    str(data.get("state") or ""),
    str(track.get("path") or ""),
    str(track.get("title") or ""),
    str(data.get("playlist") or ""),
    str(data.get("position") or ""),
    str(data.get("duration") or data.get("track", {}).get("duration_secs") or ""),
]))
'
}

start_random_sof_mix() {
    echo -e "${C_YELLOW}[!] No audio currently playing. Instructing Strawberry to launch Stream of Frequency...${C_RESET}"
    qdbus org.mpris.MediaPlayer2.strawberry /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Play 2>/dev/null
}

clear_screen_header() {
    clear
    echo -e "${C_CYAN}======================================================${C_RESET}"
    echo -e "${C_MAGENTA}${C_BOLD}     STREAM OF FREQUENCY - LIVE TRACKLIST MONITOR     ${C_RESET}"
    echo -e "${C_CYAN}======================================================${C_RESET}"
}

stem_variants() {
    local stem="$1"
    local v="$stem"
    echo "$v"
    v="$(echo "$v" | sed -E 's/_tracklist$//I')"
    echo "$v"
    # Strip split duration / timestamp suffix (handles 1-digit or 2-digit hour like _0h52m07 or _11h44m49)
    v="$(echo "$v" | sed -E 's/_[0-9]{1,2}h[0-9]{2}m[0-9]{2}(_[0-9]{1,2}h[0-9]{2}m[0-9]{2})*$//')"
    echo "$v"
    # Strip PART suffix
    v="$(echo "$v" | sed -E 's/_PART_?[0-9]+$//I')"
    echo "$v"
    # Strip date suffix at end if present
    v="$(echo "$v" | sed -E 's/_[0-9]{4}-[0-9]{2}-[0-9]{2}$//')"
    echo "$v"
    # Strip trailing date+time
    local stripped
    stripped="$(echo "$stem" | sed -E 's/_[0-9]{4}-[0-9]{2}-[0-9]{2}.*$//')"
    echo "$stripped"
    # Strip common prefix variations
    echo "${v#MPlanetarian_-_Stream_of_Frequency_}"
    echo "${v#MPlanetarian - Stream of Frequency - }"
    echo "${stripped#MPlanetarian_-_Stream_of_Frequency_}"
    echo "${stripped#MPlanetarian - Stream of Frequency - }"
    # Space-separated versions
    echo "${stem//_/ }"
    echo "${v//_/ }"
    echo "${stripped//_/ }"
}

try_generate_from_traktor() {
    local file_path="$1"
    local stem="$2"
    [ -d "$LOCAL_HISTORY_DIR" ] || return 1

    python3 - "$LOCAL_HISTORY_DIR" "$OUTPUT_DIR" "$SCRIPT_DIR" "$file_path" "$stem" << 'PY_EOF'
import sys, os, re, datetime, xml.etree.ElementTree as ET

history_dir = sys.argv[1]
output_dir = sys.argv[2]
script_dir = sys.argv[3]
file_path = sys.argv[4]
stem = sys.argv[5]

m_date = re.search(r"(\d{4})-(\d{2})-(\d{2})", stem)
year, month, day = m_date.groups() if m_date else ("", "", "")

m_artist = re.search(r"WMI_([A-Za-z0-9_]+?)(?:_\d{4}|$)", stem)
artist_kw = m_artist.group(1).replace("_", " ").lower() if m_artist else ""

matched_file = None

if os.path.isdir(history_dir):
    if year and month and day:
        m_time = re.search(r"(\d{1,2})h(\d{2})m", stem)
        if m_time:
            hour, minute = m_time.groups()
            time_pat = f"history_{year}y{month}m{day}d_{int(hour):02d}h{minute}"
            time_candidates = [os.path.join(history_dir, f) for f in os.listdir(history_dir) if f.startswith(time_pat) and f.endswith(".nml")]
            if time_candidates:
                matched_file = sorted(time_candidates)[-1]

        if not matched_file:
            date_pat = f"history_{year}y{month}m{day}d"
            candidates = [os.path.join(history_dir, f) for f in os.listdir(history_dir) if f.startswith(date_pat) and f.endswith(".nml")]
            if candidates:
                matched_file = sorted(candidates)[-1]

    if not matched_file and year and month and day:
        try:
            target_dt = datetime.date(int(year), int(month), int(day))
            surrounding_dates = [
                target_dt.strftime("%Yy%mm%dd"),
                (target_dt + datetime.timedelta(days=1)).strftime("%Yy%mm%dd"),
                (target_dt - datetime.timedelta(days=1)).strftime("%Yy%mm%dd"),
                (target_dt + datetime.timedelta(days=2)).strftime("%Yy%mm%dd")
            ]
            date_slash = f"{year}/{int(month)}/{int(day)}"
            for s_date in surrounding_dates:
                pat = f"history_{s_date}"
                for f in sorted(os.listdir(history_dir)):
                    if f.startswith(pat) and f.endswith(".nml"):
                        full_p = os.path.join(history_dir, f)
                        try:
                            with open(full_p, "r", encoding="utf-8", errors="ignore") as nml_f:
                                content = nml_f.read()
                                if date_slash in content:
                                    if not artist_kw or (artist_kw in content.lower()):
                                        matched_file = full_p
                                        break
                        except Exception:
                            continue
                if matched_file:
                    break
        except Exception:
            pass

if not matched_file or not os.path.exists(matched_file):
    sys.exit(1)

try:
    tree = ET.parse(matched_file)
    root = tree.getroot()
    collection_tracks = {}
    for entry in root.findall(".//ENTRY"):
        location = entry.find("LOCATION")
        vol = location.get("VOLUME", "") if location is not None else ""
        dir_p = location.get("DIR", "") if location is not None else ""
        file_n = location.get("FILE", "") if location is not None else ""
        full_key = vol + dir_p + file_n
        artist = entry.get("ARTIST", "")
        title = entry.get("TITLE", "")
        track_info = f"{artist} - {title}".strip()
        if track_info != "-":
            if full_key:
                collection_tracks[full_key] = track_info
            if file_n:
                collection_tracks[file_n] = track_info

    extracted_tracks = []
    seen = set()
    playlist_node = root.find(".//PLAYLIST")
    search_scope = playlist_node if playlist_node is not None else root
    for entry in search_scope.findall(".//ENTRY"):
        pkey = entry.find("PRIMARYKEY")
        if pkey is not None:
            key_val = pkey.get("KEY", "")
            track = collection_tracks.get(key_val)
            if not track:
                for k, v in collection_tracks.items():
                    if k and k in key_val:
                        track = v
                        break
            if not track:
                parts = key_val.split("/")
                if parts:
                    track = parts[-1].replace(".flac", "").replace(".wav", "").replace(".mp3", "")
            if track and track != "-" and track not in seen:
                seen.add(track)
                extracted_tracks.append(track)

    if not extracted_tracks:
        sys.exit(1)

    clean_base = re.sub(r"_[0-9]{1,2}h[0-9]{2}m[0-9]{2}(_[0-9]{1,2}h[0-9]{2}m[0-9]{2})*$", "", stem)
    target_name = f"{clean_base}.txt"
    out_path = os.path.join(output_dir, target_name)
    dir_path = os.path.join(os.path.dirname(file_path), target_name)
    stem_path = os.path.join(os.path.dirname(file_path), f"{stem}.txt")

    content_lines = [
        "==================================================",
        "RELEASE INFO & SOURCE MANIFEST",
        "==================================================",
        "Artist:        MPlanetarian",
        "Album:         Stream of Frequency",
        f"Title:         {clean_base.replace('_', ' ')}",
        f"Conversion Date: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "--------------------------------------------------",
        "Source Files Merged/Converted (1 file(s)):",
        f" - {os.path.basename(file_path)}",
        "==================================================",
        "TRACKLIST (Extracted from Traktor Database)",
        "=================================================="
    ]
    for idx, t in enumerate(extracted_tracks, start=1):
        content_lines.append(f"{idx:02d}. {t}")
    content_lines.append("")

    full_text = "\n".join(content_lines)
    os.makedirs(output_dir, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(full_text)
    try:
        with open(dir_path, "w", encoding="utf-8") as f:
            f.write(full_text)
        if stem_path != dir_path:
            with open(stem_path, "w", encoding="utf-8") as f:
                f.write(full_text)
    except Exception:
        pass

    print(out_path)
    sys.exit(0)
except Exception:
    sys.exit(1)
PY_EOF
}

find_tracklist() {
    local file_path="$1"
    local title="$2"
    local playlist="$3"
    local filename stem dir candidate
    local -A seen=()
    local -a checks=()

    filename="$(basename "$file_path")"
    stem="${filename%.*}"
    dir="$(dirname "$file_path")"

    while IFS= read -r v; do
        [ -n "$v" ] || continue
        checks+=("$v")
    done < <(stem_variants "$stem" | awk 'NF && !seen[$0]++')

    # 1. Check direct paths
    for v in "${checks[@]}"; do
        for candidate in \
            "$dir/${v}.txt" \
            "$dir/${v}_tracklist.txt" \
            "${OUTPUT_DIR}/${v}.txt" \
            "${OUTPUT_DIR}/${v}_tracklist.txt" \
            "$SCRIPT_DIR/${v}.txt" \
            "$SCRIPT_DIR/${v}_tracklist.txt"
        do
            if [ -f "$candidate" ] && [ -z "${seen[$candidate]:-}" ]; then
                echo "$candidate"
                return 0
            fi
            seen["$candidate"]=1
        done
    done

    # 2. Case-insensitive lookup in known directories
    for v in "${checks[@]}"; do
        for sdir in "$dir" "${OUTPUT_DIR}" "$SCRIPT_DIR"; do
            [ -d "$sdir" ] || continue
            while IFS= read -r candidate; do
                [ -n "$candidate" ] && [ -f "$candidate" ] || continue
                echo "$candidate"
                return 0
            done < <(find "$sdir" -maxdepth 2 \( -iname "${v}.txt" -o -iname "${v}_tracklist.txt" \) 2>/dev/null | head -n 1)
        done
    done

    # 3. Match by episode number if present (e.g. 114)
    local ep_num
    ep_num="$(echo "$stem" | grep -oE '([0-9]{3})' | head -n 1)"
    if [ -n "$ep_num" ]; then
        while IFS= read -r candidate; do
            [ -n "$candidate" ] && [ -f "$candidate" ] || continue
            local cbase
            cbase="$(basename "$candidate")"
            if [[ "$cbase" =~ (^|[^0-9])"${ep_num}"([^0-9]|$) ]]; then
                echo "$candidate"
                return 0
            fi
        done < <(find "${OUTPUT_DIR}" "$dir" "$SCRIPT_DIR" -maxdepth 2 -name "*${ep_num}*.txt" 2>/dev/null | head -n 1)
    fi

    # 4. Try extracting from Traktor History database
    local generated
    generated="$(try_generate_from_traktor "$file_path" "$stem" 2>/dev/null || true)"
    if [ -n "$generated" ] && [ -f "$generated" ]; then
        echo "$generated"
        return 0
    fi

    return 1
}

print_tracklist() {
    local tracklist_path="$1"
    echo -e "${C_BLUE}${C_BOLD}--- AVAILABLE TRACKLIST ---${C_RESET}"
    echo -e "${C_DIM}$tracklist_path${C_RESET}"
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line#$'\ufeff'}"
        if [[ "$line" =~ ^[0-9]+\. ]]; then
            track_num="${line%%.*}"
            track_title="${line#*.}"
            echo -e " ${C_YELLOW}${track_num}.${C_RESET}${C_CYAN}${track_title}${C_RESET}"
        elif [[ "$line" =~ == ]] || [[ "$line" =~ -- ]]; then
            echo -e "${C_DIM}$line${C_RESET}"
        else
            echo -e "${C_MAGENTA}$line${C_RESET}"
        fi
    done < "$tracklist_path"
}

# Ensure output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

last_played_file=""
last_tracklist_shown=""

while true; do
    player=""
    playback_status=""
    current_file_path=""
    current_title=""
    current_playlist=""
    current_pos=""
    current_dur=""

    cliamp_line="$(get_cliamp_status || true)"
    if [ -n "$cliamp_line" ]; then
        IFS=$'\t' read -r c_state c_path c_title c_playlist c_pos c_dur <<<"$cliamp_line"
        if [ "$c_state" = "playing" ] && [ -n "$c_path" ]; then
            player="cliamp"
            playback_status="Playing"
            current_file_path="$c_path"
            current_title="$c_title"
            current_playlist="$c_playlist"
            current_pos="$c_pos"
            current_dur="$c_dur"
        fi
    fi

    strawberry_line="$(get_strawberry_status || true)"
    if [ -n "$strawberry_line" ]; then
        IFS=$'\t' read -r s_state s_path s_title s_playlist s_pos s_dur <<<"$strawberry_line"
        if [ -z "$player" ] && [ "$s_state" = "playing" ] && [ -n "$s_path" ]; then
            player="strawberry"
            playback_status="Playing"
            current_file_path="$s_path"
            current_title="$s_title"
            current_playlist="$s_playlist"
            current_pos="$s_pos"
            current_dur="$s_dur"
        fi
    fi

    # Paused-but-loaded: prefer cliamp, then strawberry
    if [ -z "$player" ] && [ -n "$c_path" ]; then
        player="cliamp"
        playback_status="$(echo "$c_state" | sed 's/.*/\u&/')"
        [ "$c_state" = "paused" ] && playback_status="Paused"
        [ "$c_state" = "stopped" ] && playback_status="Stopped"
        current_file_path="$c_path"
        current_title="$c_title"
        current_playlist="$c_playlist"
        current_pos="$c_pos"
        current_dur="$c_dur"
    fi

    if [ -z "$player" ] && [ -n "$s_path" ]; then
        player="strawberry"
        playback_status="$(echo "$s_state" | sed 's/.*/\u&/')"
        [ "$s_state" = "paused" ] && playback_status="Paused"
        [ "$s_state" = "stopped" ] && playback_status="Stopped"
        current_file_path="$s_path"
        current_title="$s_title"
        current_playlist="$s_playlist"
        current_pos="$s_pos"
        current_dur="$s_dur"
    fi

    if [ -z "$player" ]; then
        clear_screen_header
        echo -e "${C_RED}[-] No supported player is reporting a track.${C_RESET}"
        echo -e "${C_DIM}    Start cliamp or Strawberry, then this monitor will pick it up.${C_RESET}"
        sleep 3
        continue
    fi

    if [ "$player" = "strawberry" ] && { [ -z "$current_file_path" ] || [ "$playback_status" = "Stopped" ]; }; then
        start_random_sof_mix
        sleep 3
        continue
    fi

    filename="$(basename "$current_file_path")"

    # Refresh when the playing file changes
    if [ "$filename" != "$last_played_file" ]; then
        last_played_file="$filename"
        clear_screen_header

        echo -e "${C_GREEN}[PLAYER]${C_RESET} ${C_BOLD}$player${C_RESET}   ${C_DIM}${playback_status}${C_RESET}"
        if [ -n "$current_playlist" ]; then
            echo -e "${C_GREEN}[PLAYLIST]${C_RESET} $current_playlist"
        fi
        if [ -n "$current_title" ]; then
            echo -e "${C_GREEN}[TITLE]${C_RESET}    $current_title"
        fi
        echo -e "${C_GREEN}[NOW PLAYING]${C_RESET} ${C_BOLD}$filename${C_RESET}"
        if [ -n "$current_pos" ] || [ -n "$current_dur" ]; then
            echo -e "${C_GREEN}[TIME]${C_RESET}     $(format_hms "$current_pos") / $(format_hms "$current_dur")"
        fi
        echo

        tracklist_path="$(find_tracklist "$current_file_path" "$current_title" "$current_playlist" || true)"

        if [ -n "$tracklist_path" ] && [ -f "$tracklist_path" ]; then
            print_tracklist "$tracklist_path"
            last_tracklist_shown="$tracklist_path"
        else
            echo -e "${C_RED}no tracklist currently available for this mix: ${C_BOLD}$filename${C_RESET}"
            last_tracklist_shown=""
        fi

        echo -e "\n${C_DIM}(Monitoring live playback from cliamp and Strawberry... Press Ctrl+C to exit)${C_RESET}"
    fi

    sleep 2
done
