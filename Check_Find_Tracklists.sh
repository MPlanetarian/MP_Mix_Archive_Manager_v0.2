#!/usr/bin/env bash

# ================================
# PATHS & CONFIGURATION
# ================================
OUTPUT_DIR="FLAC_CONVERTED_OUTPUTS"
ARCHIVE_DIR="CONVERTED_WAV_FILES"
# Direct Local Traktor History Directory (Auto-detected across Linux, macOS, and Windows)
LOCAL_HISTORY_DIR="${TRAKTOR_HISTORY_DIR:-}"
if [ -z "$LOCAL_HISTORY_DIR" ] || [ ! -d "$LOCAL_HISTORY_DIR" ]; then
    for cand in \
        "./Traktor 3.11.1/History" \
        "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "/Volumes/WD BLACK B/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "/Volumes/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "/d/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "D:/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "/mnt/d/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "$HOME/Documents/Native Instruments/Traktor 3.11.1/History" \
        "$HOME/Native Instruments/Traktor 3.11.1/History"
    do
        if [ -d "$cand" ]; then
            LOCAL_HISTORY_DIR="$cand"
            break
        fi
    done
fi

START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
NEW_TRACKLISTS_COUNT=0

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "ERROR: Output directory '$OUTPUT_DIR' not found!"
    exit 1
fi

shopt -s nullglob nocaseglob

flac_files=("${OUTPUT_DIR}"/*.flac)

if [ ${#flac_files[@]} -eq 0 ]; then
    echo "No FLAC files found in '$OUTPUT_DIR'."
    exit 0
fi

echo "Scanning FLAC files for missing tracklists..."
echo "=================================================="

# Embedded python script for XML parsing
PY_PARSER_CONTENT=$(cat << 'PY_PARSER'
import sys
import xml.etree.ElementTree as ET

xml_file = sys.argv[1]
try:
    tree = ET.parse(xml_file)
    root = tree.getroot()

    collection_tracks = {}
    for entry in root.findall(".//ENTRY"):
        location = entry.find("LOCATION")
        if location is not None:
            dir_path = location.get("DIR", "")
            file_name = location.get("FILE", "")
            full_key = f"{location.get('VOLUME', '')}{dir_path}{file_name}"
        else:
            full_key = ""
        
        artist = entry.get("ARTIST", "")
        title = entry.get("TITLE", "")
        
        track_info = f"{artist} - {title}".strip()
        if track_info != "-":
            if full_key:
                collection_tracks[full_key] = track_info
            if file_name:
                collection_tracks[file_name] = track_info

    extracted_tracks = []
    seen = set()

    playlist_node = root.find(".//PLAYLIST")
    search_scope = playlist_node if playlist_node is not None else root

    for entry in search_scope.findall(".//ENTRY"):
        pkey = entry.find("PRIMARYKEY")
        if pkey is not None:
            key_val = pkey.get("KEY", "")
            track = None
            if key_val in collection_tracks:
                track = collection_tracks[key_val]
            else:
                for k, v in collection_tracks.items():
                    if k and k in key_val:
                        track = v
                        break
                if not track:
                    parts = key_val.split('/')
                    if parts:
                        track = parts[-1].replace('.flac', '').replace('.wav', '').replace('.mp3', '')
            
            if track and track != "-" and track not in seen:
                seen.add(track)
                extracted_tracks.append(track)

    if not extracted_tracks:
        for k, v in collection_tracks.items():
            if v != "-" and v not in seen:
                seen.add(v)
                extracted_tracks.append(v)

    gai_index = -1
    for idx, t in enumerate(extracted_tracks):
        if "Gai Barone" in t:
            gai_index = idx
            break

    if gai_index != -1:
        gai_track = extracted_tracks.pop(gai_index)
        if len(extracted_tracks) >= 13:
            extracted_tracks.insert(13, gai_track)
        else:
            extracted_tracks.append(gai_track)

    for idx, t in enumerate(extracted_tracks, start=1):
        print(f"{idx:02d}. {t}")
except Exception:
    sys.exit(1)
PY_PARSER
)

for flac in "${flac_files[@]}"; do
    flac_base=$(basename "$flac" .flac)
    tracklist_path="${OUTPUT_DIR}/${flac_base}.txt"
    
    if [ -f "$tracklist_path" ]; then
        continue
    fi
    
    echo "Found FLAC without tracklist: $flac_base"
    
    # Try to extract base name matching the session ID pattern
    # Remove standard prefix if present
    session_id=$(echo "$flac_base" | sed 's/^MPlanetarian - Stream of Frequency - //')
    readable_title=$(echo "$session_id" | sed 's/_/ /g')
    
    # Extract date/time components for Traktor history matching
    session_year=$(echo "$session_id" | grep -oE '20[0-9]{2}' | head -n 1)
    session_month=$(echo "$session_id" | grep -oE '20[0-9]{2}-[0-9]{2}' | awk -F'-' '{print $2}')
    if [ -z "$session_month" ]; then
        session_month=$(echo "$session_id" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | awk -F'-' '{print $2}')
    fi
    session_day=$(echo "$session_id" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | awk -F'-' '{print $3}')
    session_hour=$(echo "$session_id" | grep -oE '[0-9]{1,2}h' | head -n 1 | tr -d 'h')
    if [ -n "$session_hour" ] && [ ${#session_hour} -eq 1 ]; then
        session_hour="0${session_hour}"
    fi
    session_min=$(echo "$session_id" | grep -oE '[0-9]{2}m' | head -n 1 | tr -d 'm')
    
    traktor_pattern="history_${session_year}y${session_month}m${session_day}d_${session_hour}h${session_min}"
    fallback_pattern="history_${session_year}y${session_month}m${session_day}d"
    session_date="${session_year}-${session_month}-${session_day}"
    
    tracklist_found=false
    matched_history=""
    
    if [ -d "$LOCAL_HISTORY_DIR" ]; then
        if [ -n "$session_year" ] && [ -n "$session_month" ] && [ -n "$session_day" ] && [ -n "$session_hour" ] && [ -n "$session_min" ]; then
            matched_history=$(find "$LOCAL_HISTORY_DIR" -maxdepth 2 -type f \( -name "*.nml" -o -name "*.xml" -o -name "*.txt" \) 2>/dev/null | grep -i "$traktor_pattern" | head -n 1)
        fi
        
        if [ -z "$matched_history" ] && [ -n "$session_year" ] && [ -n "$session_month" ] && [ -n "$session_day" ]; then
            matched_history=$(find "$LOCAL_HISTORY_DIR" -maxdepth 2 -type f \( -name "*.nml" -o -name "*.xml" -o -name "*.txt" \) 2>/dev/null | grep -i "$fallback_pattern" | sort | tail -n 1)
        fi
        
        if [ -z "$matched_history" ] && [ -n "$session_date" ]; then
            matched_history=$(find "$LOCAL_HISTORY_DIR" -maxdepth 2 -type f \( -name "*.nml" -o -name "*.xml" -o -name "*.txt" \) 2>/dev/null | grep -i "$session_date" | sort | tail -n 1)
        fi
    fi
    
    # Locate any source WAV files that match this session ID (checking archive and root)
    declare -a source_wavs=()
    for wav_path in "$ARCHIVE_DIR"/*"$session_id"*.wav ./*"$session_id"*.wav; do
        if [ -f "$wav_path" ]; then
            source_wavs+=("$(basename "$wav_path")")
        fi
    done
    
    # Generate the tracklist header
    {
        echo "=================================================="
        echo "RELEASE INFO & SOURCE MANIFEST"
        echo "=================================================="
        echo "Artist:        MPlanetarian"
        echo "Album:         Stream of Frequency"
        echo "Title:         $readable_title"
        echo "Conversion Date: $START_TIME"
        echo "--------------------------------------------------"
        echo "Source Files Merged/Converted (${#source_wavs[@]} file(s)):"
        for w in "${source_wavs[@]}"; do
            echo " - $w"
        done
        echo "=================================================="
    } > "$tracklist_path"
    
    if [ -n "$matched_history" ] && [ -f "$matched_history" ]; then
        echo " -> Matched Traktor history file: $(basename "$matched_history")"
        echo "TRACKLIST (Extracted from Traktor Database)" >> "$tracklist_path"
        echo "==================================================" >> "$tracklist_path"
        
        temp_py=$(mktemp --suffix=.py)
        echo "$PY_PARSER_CONTENT" > "$temp_py"
        python3 "$temp_py" "$matched_history" >> "$tracklist_path"
        status=$?
        rm -f "$temp_py"
        
        if [ $status -eq 0 ] && [ -s "$tracklist_path" ] && [ $(wc -l < "$tracklist_path") -gt 10 ]; then
            tracklist_found=true
            echo " -> Tracklist generated successfully."
        fi
    fi
    
    if [ "$tracklist_found" = false ]; then
        echo " -> Generating fallback standalone tracklist..."
        echo "TRACKLIST (Automatic Fallback)" >> "$tracklist_path"
        echo "==================================================" >> "$tracklist_path"
        echo "01. Live Mix Session - $readable_title" >> "$tracklist_path"
    fi
    
    ((NEW_TRACKLISTS_COUNT++))
done

echo "=================================================="
echo "Tracklist search complete."
echo "New tracklists found and added: $NEW_TRACKLISTS_COUNT"
echo "=================================================="
