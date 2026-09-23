#!/usr/bin/env bash

# ================================
# USER CONFIGURATION & SETUP
# ================================
OUTPUT_DIR="FLAC_CONVERTED_OUTPUTS"
ARCHIVE_DIR="CONVERTED_WAV_FILES"
SPEK_DIR="SPEK_OUTPUTS"
LOG_FILE="FLAC_CONVERSION_SOF.log"
COVER_ART="Cover.png"

# Direct Local Traktor History Directory (Auto-detected across Linux, macOS, and Windows)
LOCAL_HISTORY_DIR="${TRAKTOR_HISTORY_DIR:-}"
if [ -z "$LOCAL_HISTORY_DIR" ] || [ ! -d "$LOCAL_HISTORY_DIR" ]; then
    for cand in \
        "${MIX_ARCHIVE_DIR:-$PWD}/Traktor 3.11.1/History" \
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

# Start timer and log start time
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
START_SECONDS=$(date +%s)

mkdir -p "$OUTPUT_DIR"
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$SPEK_DIR"
: > "$LOG_FILE"

# Tee all output to both terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo "FLAC Conversion Started at: $START_TIME"
echo "=================================================="

# Check History Directory Availability
if [ -d "$LOCAL_HISTORY_DIR" ]; then
    echo " -> Traktor History directory located successfully at: $LOCAL_HISTORY_DIR"
else
    echo " -> WARNING: Traktor History directory not found at specified path!"
fi

# Mandatory Cover Art Check
if [ ! -f "$COVER_ART" ]; then
    echo "ERROR: Required artwork file '$COVER_ART' not found in the current directory!"
    echo "Please place 'Cover.png' in this directory and restart the script manually."
    exit 1
fi
echo "Cover art found ($COVER_ART)."

# Cover art will be dynamically evaluated and optimized per group inside the loop.

# Enable globstar and nullglob for robust file matching
shopt -s nullglob nocaseglob

# Check for explicit file arguments (supports single or multiple files, cleans hidden line breaks)
declare -a TARGET_FILES=()
if [ $# -gt 0 ]; then
    for arg in "$@"; do
        clean_arg=$(echo "$arg" | tr -d '\r' | tr -d '\n')
        if [ -f "$clean_arg" ]; then
            TARGET_FILES+=("$(realpath "$clean_arg")")
            echo "Target file added: $(basename "$clean_arg")"
        else
            echo "ERROR: Specified file '$clean_arg' not found!"
            rm -f "$OPTIMIZED_COVER"
            exit 1
        fi
    done
    echo "Multi-file/Explicit target mode enabled. Total targets: ${#TARGET_FILES[@]}"
fi

# 1. Discover and group WAV files cleanly
declare -A file_groups
declare -A processed_files

if [ ${#TARGET_FILES[@]} -gt 0 ]; then
    search_list=("${TARGET_FILES[@]}")
else
    search_list=(./*.wav)
fi

for file in "${search_list[@]}"; do
    [ -e "$file" ] || continue
    abs_file=$(realpath "$file")
    
    if [[ -n "${processed_files[$abs_file]}" ]]; then
        continue
    fi
    processed_files["$abs_file"]=1

    filename=$(basename "$file")
    # Cleanly strip only the trailing split duration suffix (e.g., _03h02m02 or _0h52m07) if present
    base_name=$(echo "$filename" | sed -E 's/_[0-9]{1,2}h[0-9]{2}m[0-9]{2}\.[Ww][Aa][Vv]$//' | sed -E 's/\.[Ww][Aa][Vv]$//')
    
    file_groups["$base_name"]+="$abs_file"$'\n'
done

group_keys=("${!file_groups[@]}")
total_groups=${#group_keys[@]}

if [ "$total_groups" -eq 0 ]; then
    echo "Error: No matching .wav files found to process."
    rm -f "$OPTIMIZED_COVER"
    exit 1
fi

echo "Found $total_groups unique audio session group(s) to process."

# 2. Calculate Total Source Size & Check Available Disk Space
total_size_bytes=0
for base in "${group_keys[@]}"; do
    while read wav; do
        [ -z "$wav" ] && continue
        size=$(wc -c < "$wav" 2>/dev/null || stat -c %s "$wav" 2>/dev/null || stat -f %z "$wav" 2>/dev/null || echo 0)
        total_size_bytes=$((total_size_bytes + size))
    done <<< "${file_groups[$base]}"
done

available_space_bytes=$(df -B1 "$OUTPUT_DIR" | awk 'NR==2 {print $4}')

if [ "$available_space_bytes" -lt "$total_size_bytes" ]; then
    echo "--------------------------------------------------"
    echo "ERROR: Insufficient disk space!"
    echo " -> Total WAV source size:  $((total_size_bytes / 1024 / 1024)) MB"
    echo " -> Available disk space:   $((available_space_bytes / 1024 / 1024)) MB"
    rm -f "$OPTIMIZED_COVER"
    exit 1
else
    echo "Disk space check passed: $((available_space_bytes / 1024 / 1024)) MB available."
fi

# 3. Estimate processing time
estimated_seconds=$((total_size_bytes / 50000000))
if [ "$estimated_seconds" -lt 10 ]; then estimated_seconds=10; fi

if date -u -d "@$estimated_seconds" +'%Hh %Mm %Ss' >/dev/null 2>&1; then
    formatted_est=$(date -u -d "@$estimated_seconds" +'%Hh %Mm %Ss')
else
    formatted_est="$estimated_seconds seconds"
fi
echo "Estimated processing time: ~$formatted_est"
echo "--------------------------------------------------"

# Track all successfully processed WAV files for archiving later
declare -a successfully_processed_wavs=()
declare -a newly_exported_flacs=()
all_groups_successful=true

# 4. Process, Merge, Convert, Tag Groups, Write Tracklist, and Generate Spectrogram
counter=1
for base in "${group_keys[@]}"; do
    declare -a current_wavs=()
    while read line; do
        [[ -n "$line" ]] && current_wavs+=("$line")
    done < <(printf '%s\n' "${file_groups[$base]}" | grep -v '^$' | sort)
    
    # Format output filenames cleanly with Artist, Show Name, and Datestamp intact
    clean_base=$(echo "$base" | sed 's/__/_/g')
    if [[ "$clean_base" != *"MPlanetarian"* ]]; then
        normalized_name="MPlanetarian - Stream of Frequency - ${clean_base}"
    else
        normalized_name="$clean_base"
    fi

    output_filename="${normalized_name}.flac"
    output_path="${OUTPUT_DIR}/${output_filename}"
    
    tracklist_filename="${normalized_name}.txt"
    tracklist_path="${OUTPUT_DIR}/${tracklist_filename}"

    if [ -f "$output_path" ] && [ -s "$output_path" ]; then
        echo "Processing Group [$counter/$total_groups]: Session ID '$base'"
        echo " -> Output FLAC file already exists ($output_filename). Skipping conversion."
        # Move source WAVs to Archive if they exist
        for w in "${current_wavs[@]}"; do
            if [ -f "$w" ]; then
                mv "$w" "$ARCHIVE_DIR/"
            fi
            successfully_processed_wavs+=("$w")
        done
        ((counter++))
        echo "--------------------------------------------------"
        continue
    fi
    
    spek_image="${SPEK_DIR}/${normalized_name}_spectrogram.png"
    
    readable_title=$(echo "$base" | sed 's/_/ /g')

    echo "Processing Group [$counter/$total_groups]: Session ID '$base'"
    echo " -> Standardized Output Name: '$normalized_name'"

    # Extract date components robustly from WAV filename (handles variable year/month positions)
    session_year=$(echo "$base" | grep -oE '20[0-9]{2}' | head -n 1)
    session_month=$(echo "$base" | grep -oE '20[0-9]{2}-[0-9]{2}' | awk -F'-' '{print $2}')
    if [ -z "$session_month" ]; then
        session_month=$(echo "$base" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | awk -F'-' '{print $2}')
    fi
    session_day=$(echo "$base" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | awk -F'-' '{print $3}')
    session_hour=$(echo "$base" | grep -oE '[0-9]{1,2}h' | head -n 1 | tr -d 'h')
    if [ -n "$session_hour" ] && [ ${#session_hour} -eq 1 ]; then
        session_hour="0${session_hour}"
    fi
    session_min=$(echo "$base" | grep -oE '[0-9]{2}m' | head -n 1 | tr -d 'm')
    
    traktor_pattern="history_${session_year}y${session_month}m${session_day}d_${session_hour}h${session_min}"
    fallback_pattern="history_${session_year}y${session_month}m${session_day}d"
    session_date="${session_year}-${session_month}-${session_day}"

    tracklist_found=false
    matched_history=""

    if [ -d "$LOCAL_HISTORY_DIR" ]; then
        matched_history=$(find "$LOCAL_HISTORY_DIR" -maxdepth 2 -type f \( -name "*.nml" -o -name "*.xml" -o -name "*.txt" \) 2>/dev/null | grep -i "$traktor_pattern" | head -n 1)
        
        if [ -z "$matched_history" ]; then
            matched_history=$(find "$LOCAL_HISTORY_DIR" -maxdepth 2 -type f \( -name "*.nml" -o -name "*.xml" -o -name "*.txt" \) 2>/dev/null | grep -i "$fallback_pattern" | sort | tail -n 1)
        fi
        
        if [ -z "$matched_history" ] && [ -n "$session_date" ]; then
            matched_history=$(find "$LOCAL_HISTORY_DIR" -maxdepth 2 -type f \( -name "*.nml" -o -name "*.xml" -o -name "*.txt" \) 2>/dev/null | grep -i "$session_date" | sort | tail -n 1)
        fi

        if [ -n "$matched_history" ] && [ -f "$matched_history" ]; then
            echo " -> Matched Traktor history file: $(basename "$matched_history")"
            {
                echo "=================================================="
                echo "RELEASE INFO & SOURCE MANIFEST"
                echo "=================================================="
                echo "Artist:        MPlanetarian"
                echo "Album:         Stream of Frequency"
                echo "Title:         $readable_title"
                echo "Conversion Date: $START_TIME"
                echo "--------------------------------------------------"
                echo "Source Files Merged/Converted (${#current_wavs[@]} file(s)):"
                for w in "${current_wavs[@]}"; do
                    echo " - $(basename "$w")"
                done
                echo "=================================================="
                echo "TRACKLIST (Extracted from Traktor Database)"
                echo "=================================================="
            } > "$tracklist_path"

            temp_py=$(mktemp --suffix=.py)
            cat << 'PY_PARSER' > "$temp_py"
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

            python3 "$temp_py" "$matched_history" >> "$tracklist_path"
            rm -f "$temp_py"

            if [ -s "$tracklist_path" ] && [ $(wc -l < "$tracklist_path") -gt 10 ]; then
                tracklist_found=true
            fi
        fi
    fi

    # Non-blocking fallback: if no matching history file is found, automatically generate a clean placeholder tracklist and continue batch execution
    if [ "$tracklist_found" = false ]; then
        echo " -> NOTICE: No matching Traktor history file found for session '$base'. Generating standalone tracklist..."
        {
            echo "=================================================="
            echo "RELEASE INFO & SOURCE MANIFEST"
            echo "=================================================="
            echo "Artist:        MPlanetarian"
            echo "Album:         Stream of Frequency"
            echo "Title:         $readable_title"
            echo "Conversion Date: $START_TIME"
            echo "--------------------------------------------------"
            echo "Source Files Merged/Converted (${#current_wavs[@]} file(s)):"
            for w in "${current_wavs[@]}"; do
                echo " - $(basename "$w")"
            done
            echo "=================================================="
            echo "TRACKLIST (Automatic Fallback)"
            echo "=================================================="
            echo "01. Live Mix Session - $readable_title"
        } > "$tracklist_path"
    else
        echo " -> Tracklist verified successfully ($tracklist_filename)."
    fi

    # Determine cover art to use: specific WAV cover (.png matching first WAV filename) or fallback to Cover.png
    first_wav="${current_wavs[0]}"
    wav_dir=$(dirname "$first_wav")
    wav_name=$(basename "$first_wav")
    wav_base="${wav_name%.*}"
    specific_cover="${wav_dir}/${wav_base}.png"
    
    selected_cover="$COVER_ART"
    if [ -f "$specific_cover" ]; then
        echo " -> Specific cover art found: $(basename "$specific_cover")"
        selected_cover="$specific_cover"
    else
        echo " -> Using default cover art fallback ($COVER_ART)."
    fi
    
    # Prepare a safely resized/optimized temporary cover art to avoid FLAC 16MB metadata limits
    OPTIMIZED_COVER=$(mktemp --suffix=.png)
    ffmpeg -y -i "$selected_cover" -vf "scale='min(1400,iw)':-1" "$OPTIMIZED_COVER" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "WARNING: Failed to optimize cover art. Using original '$(basename "$selected_cover")'."
        cp "$selected_cover" "$OPTIMIZED_COVER"
    fi

    if [ ${#current_wavs[@]} -gt 1 ]; then
        echo " -> Merging ${#current_wavs[@]} split WAV files into single FLAC with cover art..."
        concat_list=$(mktemp)
        for w in "${current_wavs[@]}"; do
            echo "file '$w'" >> "$concat_list"
        done

        ffmpeg -y -f concat -safe 0 -i "$concat_list" -i "$OPTIMIZED_COVER" \
          -c:a flac -sample_fmt s32 -compression_level 12 \
          -map 0:a -map 1:v \
          -metadata artist="MPlanetarian" \
          -metadata album="Stream of Frequency" \
          -metadata title="$readable_title" \
          -disposition:v:0 attached_pic \
          "$output_path"
        conversion_status=$?
        rm "$concat_list"
    else
        echo " -> Converting single WAV file to FLAC with cover art..."
        ffmpeg -y -i "${current_wavs[0]}" -i "$OPTIMIZED_COVER" \
          -c:a flac -sample_fmt s32 -compression_level 12 \
          -map 0:a -map 1:v \
          -metadata artist="MPlanetarian" \
          -metadata album="Stream of Frequency" \
          -metadata title="$readable_title" \
          -disposition:v:0 attached_pic \
          "$output_path"
        conversion_status=$?
    fi

    if [ $conversion_status -ne 0 ]; then
        echo "ERROR: FFmpeg conversion failed for group '$base'!"
        all_groups_successful=false
        rm -f "$OPTIMIZED_COVER"
        exit 1
    fi

    newly_exported_flacs+=("$output_path")

    if [ ! -f "$spek_image" ]; then
        echo " -> Generating spectrogram..."
        ffmpeg -y -i "$output_path" \
          -lavfi "showspectrumpic=s=1920x1080:mode=combined:color=intensity:scale=log" \
          -frames:v 1 \
          "$spek_image" > /dev/null 2>&1
    fi

    echo " -> Moving successfully processed WAV files to '$ARCHIVE_DIR'..."
    for w in "${current_wavs[@]}"; do
        if [ -f "$w" ]; then
            mv "$w" "$ARCHIVE_DIR/"
        fi
        successfully_processed_wavs+=("$w")
    done

    rm -f "$OPTIMIZED_COVER"
    ((counter++))
    echo "--------------------------------------------------"
done

if [ "$all_groups_successful" = true ] && [ ${#successfully_processed_wavs[@]} -gt 0 ]; then
    echo "All conversions completed successfully. All source WAV files archived."
fi

# Generate playlist for the new exports
PLAYLIST_NAME="SOF_Batch_Export_$(date +%Y-%m-%d).m3u"
if [ ${#newly_exported_flacs[@]} -gt 0 ]; then
    echo "Generating M3U playlist: $PLAYLIST_NAME..."
    : > "$PLAYLIST_NAME"
    for f in "${newly_exported_flacs[@]}"; do
        # Output the path relative to this script's directory
        echo "FLAC_CONVERTED_OUTPUTS/$(basename "$f")" >> "$PLAYLIST_NAME"
    done
    echo "Playlist generated successfully at: $PLAYLIST_NAME"
fi

echo "=================================================="
echo "CONVERSION COMPLETE"
echo "=================================================="
