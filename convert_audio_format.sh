#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - Universal Audio Format & Bit Depth Converter
# Converts WAV (and other audio) to MP3, Ogg Vorbis, Apple AAC/ALAC, Opus,
# FLAC, and WAV to WAV with custom bit depths (32-bit, 24-bit, 16-bit).
# ==============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Find matching cover art
find_cover_art() {
    local base_name="$1"
    local search_dirs=("./COVERS" "$PARENT_DIR/COVERS" "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/COVERS" "/Volumes/WD BLACK B/MIX_ARCHIVE/COVERS" "D:/MIX_ARCHIVE/COVERS")
    
    # Try show number match (e.g. 033)
    local show_num=""
    local re_show='(Frequency|Mix|SOF)[_ -]+([0-9]{3})'
    local re_num='([0-9]{3})'
    if [[ "$base_name" =~ $re_show ]]; then
        show_num="${BASH_REMATCH[2]}"
    elif [[ "$base_name" =~ $re_num ]]; then
        show_num="${BASH_REMATCH[1]}"
    fi

    if [ -n "$show_num" ]; then
        for cd in "${search_dirs[@]}"; do
            if [ -d "$cd" ]; then
                shopt -s nullglob nocaseglob
                local matches=("$cd"/*"$show_num"*.jpg "$cd"/*"$show_num"*.jpeg "$cd"/*"$show_num"*.png)
                shopt -u nullglob nocaseglob
                if [ ${#matches[@]} -gt 0 ] && [ -f "${matches[0]}" ]; then
                    echo "${matches[0]}"
                    return 0
                fi
            fi
        done
    fi

    # Fallback to Cover.png
    if [ -f "./Cover.png" ]; then
        echo "./Cover.png"
        return 0
    elif [ -f "$PARENT_DIR/Cover.png" ]; then
        echo "$PARENT_DIR/Cover.png"
        return 0
    fi

    return 1
}

convert_file() {
    local in_file="$1"
    local out_format="$2"
    local out_dir="$3"
    local custom_opts="$4"
    local out_ext="$5"

    local base_name
    base_name=$(basename "$in_file")
    base_name="${base_name%.*}"

    mkdir -p "$out_dir"
    local out_file="$out_dir/${base_name}.${out_ext}"

    echo -e "  Converting: ${BOLD}${CYAN}$(basename "$in_file")${NC}"
    echo -e "  Format:     ${YELLOW}${out_format}${NC} -> ${GREEN}$(basename "$out_file")${NC}"

    local cover_art=""
    cover_art=$(find_cover_art "$base_name" 2>/dev/null || true)

    local ffmpeg_args=(-y -i "$in_file")
    
    # Cover art embedding for formats that support ID3/MP4/FLAC covers
    if [ -n "$cover_art" ] && [ -f "$cover_art" ]; then
        if [ "$out_ext" = "mp3" ]; then
            ffmpeg_args+=(-i "$cover_art" -map 0:a -map 1:v -c:v mjpeg -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)")
        elif [ "$out_ext" = "m4a" ]; then
            ffmpeg_args+=(-i "$cover_art" -map 0:a -map 1:v -c:v mjpeg -disposition:v:0 attached_pic)
        elif [ "$out_ext" = "flac" ]; then
            ffmpeg_args+=(-i "$cover_art" -map 0:a -map 1:v -c:v copy -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)")
        else
            ffmpeg_args+=(-map 0:a)
        fi
    else
        ffmpeg_args+=(-map 0:a)
    fi

    # Append codec and encoding parameters
    # shellcheck disable=SC2206
    ffmpeg_args+=($custom_opts "$out_file")

    if ffmpeg "${ffmpeg_args[@]}" >/dev/null 2>&1; then
        local sz
        sz=$(ls -lh "$out_file" 2>/dev/null | awk '{print $5}')
        echo -e "  ${GREEN}✓ Done:${NC} $out_file (${CYAN}${sz}${NC})\n"
        return 0
    else
        # Fallback without artwork embedding if muxing failed
        if ffmpeg -y -i "$in_file" $custom_opts "$out_file" >/dev/null 2>&1; then
            local sz
            sz=$(ls -lh "$out_file" 2>/dev/null | awk '{print $5}')
            echo -e "  ${GREEN}✓ Done (audio only):${NC} $out_file (${CYAN}${sz}${NC})\n"
            return 0
        else
            echo -e "  ${RED}✗ Error converting $in_file!${NC}\n"
            return 1
        fi
    fi
}

echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo -e "${BOLD}${MAGENTA}       UNIVERSAL AUDIO FORMAT & BIT DEPTH CONVERTER                   ${NC}"
echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

echo -e "${BOLD}Select Target Output Format:${NC}"
echo -e "  ${BOLD}${BLUE}── [ MP3 FORMATS ] ───────────────────────────────────────────${NC}"
echo -e "  ${BOLD}${CYAN} 1)${NC} MP3 320 kbps CBR (Highest Constant Bitrate MP3)"
echo -e "  ${BOLD}${CYAN} 2)${NC} MP3 V0 VBR (~245 kbps Optimal Variable Bitrate)"
echo -e "  ${BOLD}${CYAN} 3)${NC} MP3 256 kbps CBR"
echo -e "  ${BOLD}${CYAN} 4)${NC} MP3 192 kbps CBR"
echo -e "  ${BOLD}${BLUE}── [ OGG VORBIS & OPUS FORMATS ] ─────────────────────────────${NC}"
echo -e "  ${BOLD}${CYAN} 5)${NC} Ogg Vorbis Quality 10 (~500 kbps Ultra Quality .ogg)"
echo -e "  ${BOLD}${CYAN} 6)${NC} Ogg Vorbis Quality 8 (~256 kbps Standard .ogg)"
echo -e "  ${BOLD}${CYAN} 7)${NC} Opus 160 kbps (High-Efficiency Broadcast / Streaming)"
echo -e "  ${BOLD}${CYAN} 8)${NC} Opus 128 kbps"
echo -e "  ${BOLD}${BLUE}── [ APPLE FORMATS (AAC & ALAC) ] ────────────────────────────${NC}"
echo -e "  ${BOLD}${CYAN} 9)${NC} Apple AAC 320 kbps (.m4a)"
echo -e "  ${BOLD}${CYAN}10)${NC} Apple AAC 256 kbps (iTunes / Apple Podcasts Standard .m4a)"
echo -e "  ${BOLD}${CYAN}11)${NC} Apple ALAC Lossless (.m4a Apple Lossless Audio Codec)"
echo -e "  ${BOLD}${BLUE}── [ WAV TO WAV (BIT DEPTH CONVERSION) ] ─────────────────────${NC}"
echo -e "  ${BOLD}${CYAN}12)${NC} WAV 32-bit Float PCM (Master Studio Floating Point)"
echo -e "  ${BOLD}${CYAN}13)${NC} WAV 24-bit Signed PCM (24-bit Studio Lossless WAV)"
echo -e "  ${BOLD}${CYAN}14)${NC} WAV 16-bit Signed PCM (CD Standard 44.1 kHz, 16-bit)"
echo -e "  ${BOLD}${CYAN}15)${NC} WAV 16-bit Signed PCM (Native Sample Rate, 16-bit)"
echo -e "  ${BOLD}${BLUE}── [ FLAC LOSSLESS ] ─────────────────────────────────────────${NC}"
echo -e "  ${BOLD}${CYAN}16)${NC} FLAC 24-bit Lossless"
echo -e "  ${BOLD}${CYAN}17)${NC} FLAC 16-bit CD Standard Lossless"
echo -e "  ${BOLD}${CYAN} 0)${NC} Cancel and Return"
echo ""

read -r -p "Enter choice [1-17]: " fmt_choice

case "$fmt_choice" in
    1)  FMT_NAME="MP3 320k CBR";        OPTS="-c:a libmp3lame -b:a 320k";                     EXT="mp3"; SUB_DIR="MP3_320K" ;;
    2)  FMT_NAME="MP3 V0 VBR";          OPTS="-c:a libmp3lame -q:a 0";                        EXT="mp3"; SUB_DIR="MP3_V0" ;;
    3)  FMT_NAME="MP3 256k CBR";        OPTS="-c:a libmp3lame -b:a 256k";                     EXT="mp3"; SUB_DIR="MP3_256K" ;;
    4)  FMT_NAME="MP3 192k CBR";        OPTS="-c:a libmp3lame -b:a 192k";                     EXT="mp3"; SUB_DIR="MP3_192K" ;;
    5)  FMT_NAME="Ogg Vorbis Q10";      OPTS="-c:a libvorbis -q:a 10";                        EXT="ogg"; SUB_DIR="OGG_Q10" ;;
    6)  FMT_NAME="Ogg Vorbis Q8";       OPTS="-c:a libvorbis -q:a 8";                         EXT="ogg"; SUB_DIR="OGG_Q8" ;;
    7)  FMT_NAME="Opus 160k";           OPTS="-c:a libopus -b:a 160k";                        EXT="opus"; SUB_DIR="OPUS_160K" ;;
    8)  FMT_NAME="Opus 128k";           OPTS="-c:a libopus -b:a 128k";                        EXT="opus"; SUB_DIR="OPUS_128K" ;;
    9)  FMT_NAME="Apple AAC 320k";      OPTS="-c:a aac -b:a 320k";                            EXT="m4a"; SUB_DIR="AAC_320K" ;;
    10) FMT_NAME="Apple AAC 256k";      OPTS="-c:a aac -b:a 256k";                            EXT="m4a"; SUB_DIR="AAC_256K" ;;
    11) FMT_NAME="Apple ALAC Lossless"; OPTS="-c:a alac";                                     EXT="m4a"; SUB_DIR="ALAC_LOSSLESS" ;;
    12) FMT_NAME="WAV 32-bit Float";    OPTS="-c:a pcm_f32le";                                EXT="wav"; SUB_DIR="WAV_32BIT_FLOAT" ;;
    13) FMT_NAME="WAV 24-bit PCM";      OPTS="-c:a pcm_s24le";                                EXT="wav"; SUB_DIR="WAV_24BIT" ;;
    14) FMT_NAME="WAV 16-bit 44.1kHz";  OPTS="-c:a pcm_s16le -ar 44100";                      EXT="wav"; SUB_DIR="WAV_16BIT_44K" ;;
    15) FMT_NAME="WAV 16-bit PCM";      OPTS="-c:a pcm_s16le";                                EXT="wav"; SUB_DIR="WAV_16BIT" ;;
    16) FMT_NAME="FLAC 24-bit";         OPTS="-sample_fmt s32 -c:a flac -compression_level 8"; EXT="flac"; SUB_DIR="FLAC_24BIT" ;;
    17) FMT_NAME="FLAC 16-bit";         OPTS="-sample_fmt s16 -c:a flac -compression_level 8"; EXT="flac"; SUB_DIR="FLAC_16BIT" ;;
    0|q|Q) echo "Conversion cancelled."; exit 0 ;;
    *) echo -e "${RED}Invalid choice!${NC}"; exit 1 ;;
esac

echo -e "\n${BOLD}Select Input Scope:${NC}"
echo -e "  ${BOLD}${CYAN}1)${NC} Single Audio File (Search & Pick or Enter Path)"
echo -e "  ${BOLD}${CYAN}2)${NC} All WAV Files in Staging / Current Directory"
echo -e "  ${BOLD}${CYAN}3)${NC} All Converted WAV Archive Files (CONVERTED_WAV_FILES)"
echo -e "  ${BOLD}${CYAN}4)${NC} All FLAC Outputs (FLAC_CONVERTED_OUTPUTS)"
echo ""
read -r -p "Enter choice [1-4]: " scope_choice

DEFAULT_OUT_DIR="CONVERTED_AUDIO_OUTPUTS/$SUB_DIR"

case "$scope_choice" in
    1)
        read -r -e -p "Enter path to audio file (or search keyword): " user_input
        user_input=$(echo "$user_input" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        
        target_file=""
        if [ -f "$user_input" ]; then
            target_file="$user_input"
        else
            # Search for keyword
            shopt -s nullglob nocaseglob
            candidates=(*"$user_input"*.[wW][aA][vV] *"$user_input"*.[fF][lL][aA][cC] "FLAC_CONVERTED_OUTPUTS"/*"$user_input"*.[fF][lL][aA][cC] "CONVERTED_WAV_FILES"/*"$user_input"*.[wW][aA][vV])
            shopt -u nullglob nocaseglob
            if [ ${#candidates[@]} -eq 0 ]; then
                echo -e "${RED}No audio files found matching '$user_input'!${NC}"
                exit 1
            elif [ ${#candidates[@]} -eq 1 ]; then
                target_file="${candidates[0]}"
            else
                echo -e "\nMultiple matching files found:"
                for i in "${!candidates[@]}"; do
                    echo "  $((i+1))) ${candidates[$i]}"
                done
                read -r -p "Select file [1-${#candidates[@]}]: " pick
                target_file="${candidates[$((pick-1))]}"
            fi
        fi

        echo ""
        read -r -e -p "Enter output directory [default: $DEFAULT_OUT_DIR]: " custom_out
        final_out="${custom_out:-$DEFAULT_OUT_DIR}"

        echo -e "\n${BOLD}${GREEN}=== STARTING CONVERSION ===${NC}\n"
        convert_file "$target_file" "$FMT_NAME" "$final_out" "$OPTS" "$EXT"
        ;;
    2)
        shopt -s nullglob nocaseglob
        wav_files=(*.[wW][aA][vV])
        shopt -u nullglob nocaseglob
        if [ ${#wav_files[@]} -eq 0 ]; then
            echo -e "${RED}No WAV files found in current directory!${NC}"
            exit 1
        fi
        echo -e "\nFound ${#wav_files[@]} WAV file(s)."
        read -r -e -p "Enter output directory [default: $DEFAULT_OUT_DIR]: " custom_out
        final_out="${custom_out:-$DEFAULT_OUT_DIR}"

        echo -e "\n${BOLD}${GREEN}=== BATCH CONVERSION STARTED (${#wav_files[@]} files) ===${NC}\n"
        success=0
        for wf in "${wav_files[@]}"; do
            if convert_file "$wf" "$FMT_NAME" "$final_out" "$OPTS" "$EXT"; then
                ((success++))
            fi
        done
        echo -e "${BOLD}${GREEN}✓ Batch conversion completed: $success / ${#wav_files[@]} succeeded!${NC}\n"
        ;;
    3)
        wav_dir="CONVERTED_WAV_FILES"
        if [ ! -d "$wav_dir" ] && [ -d "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES" ]; then
            wav_dir="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES"
        fi
        shopt -s nullglob nocaseglob
        wav_files=("$wav_dir"/*.[wW][aA][vV])
        shopt -u nullglob nocaseglob
        if [ ${#wav_files[@]} -eq 0 ]; then
            echo -e "${RED}No WAV files found in $wav_dir!${NC}"
            exit 1
        fi
        echo -e "\nFound ${#wav_files[@]} WAV file(s) in $wav_dir."
        read -r -e -p "Enter output directory [default: $DEFAULT_OUT_DIR]: " custom_out
        final_out="${custom_out:-$DEFAULT_OUT_DIR}"

        echo -e "\n${BOLD}${GREEN}=== BATCH CONVERSION STARTED (${#wav_files[@]} files) ===${NC}\n"
        success=0
        for wf in "${wav_files[@]}"; do
            if convert_file "$wf" "$FMT_NAME" "$final_out" "$OPTS" "$EXT"; then
                ((success++))
            fi
        done
        echo -e "${BOLD}${GREEN}✓ Batch conversion completed: $success / ${#wav_files[@]} succeeded!${NC}\n"
        ;;
    4)
        flac_dir="FLAC_CONVERTED_OUTPUTS"
        if [ ! -d "$flac_dir" ] && [ -d "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS" ]; then
            flac_dir="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"
        fi
        shopt -s nullglob nocaseglob
        flac_files=("$flac_dir"/*.[fF][lL][aA][cC])
        shopt -u nullglob nocaseglob
        if [ ${#flac_files[@]} -eq 0 ]; then
            echo -e "${RED}No FLAC files found in $flac_dir!${NC}"
            exit 1
        fi
        echo -e "\nFound ${#flac_files[@]} FLAC file(s) in $flac_dir."
        read -r -e -p "Enter output directory [default: $DEFAULT_OUT_DIR]: " custom_out
        final_out="${custom_out:-$DEFAULT_OUT_DIR}"

        echo -e "\n${BOLD}${GREEN}=== BATCH CONVERSION STARTED (${#flac_files[@]} files) ===${NC}\n"
        success=0
        for ff in "${flac_files[@]}"; do
            if convert_file "$ff" "$FMT_NAME" "$final_out" "$OPTS" "$EXT"; then
                ((success++))
            fi
        done
        echo -e "${BOLD}${GREEN}✓ Batch conversion completed: $success / ${#flac_files[@]} succeeded!${NC}\n"
        ;;
    *)
        echo -e "${RED}Invalid scope!${NC}"
        exit 1
        ;;
esac
