#!/usr/bin/env bash
# ==============================================================================
# generate_spek.sh - High-Resolution Acoustic Spectrogram Generator
# Cross-Platform: Linux • macOS • Windows 10/11 • FreeBSD
# Generates lossless audio frequency spectrum analyses (Spek style) via FFmpeg
# and supports launching native Spek GUI on macOS, Windows, Linux, and FreeBSD.
# ==============================================================================

set -euo pipefail

# Styling colors
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# OS Platform Detection
OS_TYPE="linux"
case "$(uname -s)" in
    Darwin*)  OS_TYPE="macos" ;;
    CYGWIN*|MINGW*|MSYS*) OS_TYPE="windows" ;;
    FreeBSD*) OS_TYPE="freebsd" ;;
    Linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            OS_TYPE="wsl"
        else
            OS_TYPE="linux"
        fi
        ;;
    *) OS_TYPE="linux" ;;
esac

# Cross-Platform Open Path Helper
open_image_viewer() {
    local target="$1"
    [ -z "$target" ] || [ ! -f "$target" ] && return 0
    if [ "$OS_TYPE" = "macos" ]; then
        open "$target" >/dev/null 2>&1 &
    elif [ "$OS_TYPE" = "windows" ]; then
        if command -v cygpath >/dev/null 2>&1; then
            cmd.exe /c start "" "$(cygpath -w "$target")" >/dev/null 2>&1 &
        else
            explorer.exe "$target" >/dev/null 2>&1 &
        fi
    elif [ "$OS_TYPE" = "wsl" ]; then
        if command -v wslview >/dev/null 2>&1; then
            wslview "$target" >/dev/null 2>&1 &
        elif command -v explorer.exe >/dev/null 2>&1; then
            explorer.exe "$(wslpath -w "$target")" >/dev/null 2>&1 &
        fi
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$target" >/dev/null 2>&1 &
    fi
}

# Cross-Platform Native Spek GUI Launcher
launch_native_spek_gui() {
    local target_audio="${1:-}"
    echo -e "${BOLD}${CYAN}Checking for native Spek Acoustic Spectrum Analyser GUI...${NC}"
    
    if [ "$OS_TYPE" = "macos" ]; then
        if [ -d "/Applications/Spek.app" ] || [ -d "$HOME/Applications/Spek.app" ] || osascript -e 'id of application "Spek"' >/dev/null 2>&1; then
            if [ -n "$target_audio" ]; then
                open -a Spek "$target_audio" >/dev/null 2>&1 &
            else
                open -a Spek >/dev/null 2>&1 &
            fi
            echo -e "${GREEN}✓ Launched native Spek.app on macOS.${NC}"
            return 0
        elif command -v spek >/dev/null 2>&1; then
            nohup spek "$target_audio" >/dev/null 2>&1 &
            echo -e "${GREEN}✓ Launched native spek binary on macOS.${NC}"
            return 0
        else
            echo -e "${YELLOW}Native Spek GUI is not installed on macOS.${NC}"
            echo -e "You can install it with Homebrew: ${CYAN}brew install spek${NC}"
            return 1
        fi
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        local spek_win_paths=(
            "/c/Program Files/Spek/spek.exe"
            "/c/Program Files (x86)/Spek/spek.exe"
            "$LOCALAPPDATA/Spek/spek.exe"
        )
        for p in "${spek_win_paths[@]}"; do
            if [ -f "$p" ]; then
                local win_target=""
                [ -n "$target_audio" ] && win_target="$(cygpath -w "$target_audio" 2>/dev/null || wslpath -w "$target_audio" 2>/dev/null || echo "$target_audio")"
                cmd.exe /c start "" "$(cygpath -w "$p" 2>/dev/null || echo "$p")" "$win_target" >/dev/null 2>&1 &
                echo -e "${GREEN}✓ Launched native Spek on Windows.${NC}"
                return 0
            fi
        done
        if command -v cmd.exe >/dev/null 2>&1 && cmd.exe /c "where spek.exe" >/dev/null 2>&1; then
            local win_target=""
            [ -n "$target_audio" ] && win_target="$(cygpath -w "$target_audio" 2>/dev/null || wslpath -w "$target_audio" 2>/dev/null || echo "$target_audio")"
            cmd.exe /c start "" "spek.exe" "$win_target" >/dev/null 2>&1 &
            echo -e "${GREEN}✓ Launched native spek.exe on Windows.${NC}"
            return 0
        fi
        echo -e "${YELLOW}Native Spek is not installed on Windows.${NC}"
        echo -e "You can install it using winget or chocolatey: ${CYAN}winget install Spek.Spek${NC}"
        return 1
    elif [ "$OS_TYPE" = "freebsd" ]; then
        if command -v spek >/dev/null 2>&1; then
            nohup spek "$target_audio" >/dev/null 2>&1 &
            echo -e "${GREEN}✓ Launched native spek on FreeBSD.${NC}"
            return 0
        else
            echo -e "${YELLOW}Native Spek is not installed on FreeBSD.${NC}"
            echo -e "You can install it with pkg: ${CYAN}pkg install -y spek${NC}"
            return 1
        fi
    else
        # Linux
        if command -v spek >/dev/null 2>&1; then
            nohup spek "$target_audio" >/dev/null 2>&1 &
            echo -e "${GREEN}✓ Launched native spek on Linux.${NC}"
            return 0
        elif command -v flatpak >/dev/null 2>&1 && flatpak info org.spek.Spek >/dev/null 2>&1; then
            nohup flatpak run org.spek.Spek "$target_audio" >/dev/null 2>&1 &
            echo -e "${GREEN}✓ Launched Spek (Flatpak) on Linux.${NC}"
            return 0
        else
            echo -e "${YELLOW}Native Spek is not installed on Linux.${NC}"
            echo -e "Install with: ${CYAN}sudo dnf/apt install spek${NC} or ${CYAN}flatpak install flathub org.spek.Spek${NC}"
            return 1
        fi
    fi
}

launch_sonic_visualiser() {
    local target_audio="${1:-}"
    echo -e "${BOLD}${CYAN}Checking for Sonic Visualiser...${NC}"
    if command -v sonic-visualiser >/dev/null 2>&1; then
        nohup sonic-visualiser "$target_audio" >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Launched Sonic Visualiser.${NC}"
        return 0
    elif command -v flatpak >/dev/null 2>&1 && flatpak list | grep -qi "sonicvisualiser"; then
        flatpak run org.sonicvisualiser.SonicVisualiser "$target_audio" >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Launched Sonic Visualiser (Flatpak).${NC}"
        return 0
    elif [ "$OS_TYPE" = "macos" ] && [ -d "/Applications/Sonic Visualiser.app" ]; then
        open -a "Sonic Visualiser" "$target_audio" >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Launched Sonic Visualiser.app on macOS.${NC}"
        return 0
    else
        echo -e "${YELLOW}Sonic Visualiser is not currently installed.${NC}"
        echo -e "Install via Flatpak: ${CYAN}flatpak install flathub org.sonicvisualiser.SonicVisualiser${NC}"
        echo -e "or macOS Homebrew:  ${CYAN}brew install --cask sonic-visualiser${NC}"
        return 1
    fi
}

generate_sox_spectrogram() {
    local audio_file="$1"
    local out_dir="${2:-SPEK_OUTPUTS}"
    local colormap="${3:-magma}" # viridis, magma, rainbow, mono
    mkdir -p "$out_dir"
    local base_name
    base_name="$(basename "$audio_file")"
    local out_png="$out_dir/${base_name%.*}.sox_${colormap}_spek.png"
    
    echo -e "${BOLD}${CYAN}Generating SoX High-Resolution Spectrogram (${colormap})...${NC}"
    if command -v sox >/dev/null 2>&1; then
        local p_flag=""
        [ "$colormap" = "mono" ] && p_flag="-m"
        sox "$audio_file" -n rate 48k spectrogram -X 200 -y 1024 -z 120 -q 1 -w Hann $p_flag -t "$base_name" -o "$out_png"
        echo -e "${GREEN}✓ Generated SoX spectrogram: $out_png${NC}"
        open_image_viewer "$out_png"
        return 0
    else
        echo -e "${DIM}SoX not in PATH, using FFmpeg high-res acoustic renderer (${colormap})...${NC}"
        local color_filter="color=$colormap:scale=log:legend=1:s=1920x1080"
        ffmpeg -y -i "$audio_file" -filter_complex "showspectrumpic=$color_filter" -frames:v 1 "$out_png" >/dev/null 2>&1
        echo -e "${GREEN}✓ Generated High-Resolution Spectrogram: $out_png${NC}"
        open_image_viewer "$out_png"
        return 0
    fi
}

launch_praat_or_kwave() {
    local target_audio="${1:-}"
    echo -e "${BOLD}${CYAN}Checking for Praat / Kwave / Audacity...${NC}"
    if command -v flatpak >/dev/null 2>&1 && flatpak list | grep -qi "org.praat.Praat"; then
        flatpak run org.praat.Praat "$target_audio" >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Launched Praat Acoustic Analyzer (Flatpak).${NC}"
        return 0
    elif command -v flatpak >/dev/null 2>&1 && flatpak list | grep -qi "org.kde.kwave"; then
        flatpak run org.kde.kwave "$target_audio" >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Launched Kwave Sonagram Editor (Flatpak).${NC}"
        return 0
    elif command -v audacity >/dev/null 2>&1 || (command -v flatpak >/dev/null 2>&1 && flatpak list | grep -qi "Audacity"); then
        if command -v audacity >/dev/null 2>&1; then
            audacity "$target_audio" >/dev/null 2>&1 &
        else
            flatpak run org.audacityteam.Audacity "$target_audio" >/dev/null 2>&1 &
        fi
        echo -e "${GREEN}✓ Launched Audacity with Spectral View.${NC}"
        return 0
    else
        echo -e "${YELLOW}Praat/Kwave is not installed.${NC}"
        echo -e "Install with: ${CYAN}flatpak install flathub org.praat.Praat org.kde.kwave${NC}"
        return 1
    fi
}

show_help() {
    cat <<EOF
Usage: $(basename "$0") [options]

High-Resolution Acoustic Spectrogram Generator (Cross-Platform)

Options:
  -i, --input <file>        Single input audio file (WAV, FLAC, MP3, AAC, etc.)
  --single-file <file>      Generate Spek in-place in same directory as audio file (<name>.spek)
  -d, --dir <dir>           Directory containing audio files to batch process
  --multiple-dir <dir>      Scan directory and generate Speks in-place (<name>.spek)
  --in-place                Save spectrogram in same folder as audio file with .spek extension
  -o, --output-dir <dir>    Destination directory for PNG spectrograms (default: SPEK_OUTPUTS)
  -r, --res <WxH>           Spectrogram resolution (default: 1920x1080)
  -s, --scale <log|lin>     Frequency scale: 'log' (default) or 'lin'
  -c, --color <scheme>      Color scheme: intensity (default), rainbow, fire, magma, viridis
  -g, --gui                 Launch native Spek GUI application if installed
  -a, --all                 Batch process all WAVs & FLACs in standard archive directories
  --open                    Automatically open the generated spectrogram in the default image viewer
  --no-view                 Do not prompt to view generated Spek file
  -h, --help                Show this help message and exit

Examples:
  $(basename "$0") -i "mix.flac"
  $(basename "$0") --single-file "/path/to/mix.flac"
  $(basename "$0") --multiple-dir "/path/to/music_folder"
  $(basename "$0") -i "mix.wav" --open
  $(basename "$0") -d "FLAC_CONVERTED_OUTPUTS" -o "SPEK_OUTPUTS"
  $(basename "$0") -i "mix.flac" -g
EOF
}

# Parse Command Line Arguments
INPUT_FILE=""
INPUT_DIR=""
OUTPUT_DIR="SPEK_OUTPUTS"
RESOLUTION="1920x1080"
SCALE="log"
COLOR_SCHEME="intensity"
LAUNCH_GUI=0
PROCESS_ALL=0
AUTO_OPEN=0
IN_PLACE=0
PROMPT_VIEW=1

while [ $# -gt 0 ]; do
    case "$1" in
        --single-file|--single)
            INPUT_FILE="$2"
            IN_PLACE=1
            shift 2
            ;;
        --multiple-dir|--multiple)
            INPUT_DIR="$2"
            IN_PLACE=1
            shift 2
            ;;
        --in-place)
            IN_PLACE=1
            shift
            ;;
        --no-view)
            PROMPT_VIEW=0
            shift
            ;;
        --view)
            PROMPT_VIEW=1
            shift
            ;;
        -i|--input)
            INPUT_FILE="$2"
            shift 2
            ;;
        -d|--dir)
            INPUT_DIR="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -r|--res|--resolution)
            RESOLUTION="$2"
            shift 2
            ;;
        -s|--scale)
            SCALE="$2"
            shift 2
            ;;
        -c|--color)
            COLOR_SCHEME="$2"
            shift 2
            ;;
        -g|--gui)
            LAUNCH_GUI=1
            shift
            ;;
        -a|--all)
            PROCESS_ALL=1
            shift
            ;;
        --open)
            AUTO_OPEN=1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [ -z "$INPUT_FILE" ] && [ -f "$1" ]; then
                INPUT_FILE="$1"
                shift
            else
                echo -e "${RED}Unknown argument: $1${NC}" >&2
                show_help
                exit 1
            fi
            ;;
    esac
done

# If GUI requested directly
if [ "$LAUNCH_GUI" -eq 1 ]; then
    launch_native_spek_gui "$INPUT_FILE" || true
    [ -z "$INPUT_FILE" ] && exit 0
fi

# Ensure FFmpeg is available
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo -e "${RED}Error: ffmpeg is required to generate high-resolution spectrograms.${NC}" >&2
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "Install with: ${CYAN}brew install ffmpeg${NC}" >&2
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "Install with: ${CYAN}winget install Gyan.FFmpeg${NC}" >&2
    elif [ "$OS_TYPE" = "freebsd" ]; then
        echo -e "Install with: ${CYAN}pkg install -y ffmpeg${NC}" >&2
    else
        echo -e "Install with your Linux package manager (e.g., sudo dnf install ffmpeg / sudo apt install ffmpeg)." >&2
    fi
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

generate_single_spek() {
    local in_file="$1"
    local out_dir="${2:-$OUTPUT_DIR}"
    local should_open="${3:-$AUTO_OPEN}"

    if [ ! -f "$in_file" ]; then
        echo -e "${RED}Error: File '$in_file' does not exist!${NC}" >&2
        return 1
    fi

    local base
    base="$(basename "$in_file")"
    local stem="${base%.*}"
    local out_png="${out_dir}/${stem}_spectrogram.png"

    echo -e "  ${BOLD}${BLUE}Analyzing:${NC} ${GREEN}${base}${NC}"

    # Extract audio stream info via ffprobe if available
    local sample_rate="Unknown"
    local channels="Stereo"
    local duration_fmt="Unknown"
    if command -v ffprobe >/dev/null 2>&1; then
        sample_rate=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$in_file" 2>/dev/null || echo "Unknown")
        local dur_sec
        dur_sec=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$in_file" 2>/dev/null || echo "0")
        if [ "$(echo "$dur_sec > 0" | bc 2>/dev/null || echo "0")" -eq 1 ]; then
            local dur_int=${dur_sec%.*}
            local h=$((dur_int / 3600))
            local m=$(( (dur_int % 3600) / 60 ))
            local s=$((dur_int % 60))
            if [ $h -gt 0 ]; then
                duration_fmt=$(printf "%02d:%02d:%02d" $h $m $s)
            else
                duration_fmt=$(printf "%02d:%02d" $m $s)
            fi
        fi
    fi

    echo -e "  • ${BOLD}Sample Rate:${NC} ${CYAN}${sample_rate} Hz${NC} (Nyquist Limit: $(( ${sample_rate% *} / 2000 )) kHz)  • ${BOLD}Duration:${NC} ${CYAN}${duration_fmt}${NC}"
    echo -e "  • ${BOLD}Rendering:${NC}   Resolution ${CYAN}${RESOLUTION}${NC} | Scale: ${CYAN}${SCALE}${NC} | Palette: ${CYAN}${COLOR_SCHEME}${NC}"

    local start_time
    start_time=$(date +%s)

    # High-precision FFmpeg spectrogram generation
    ffmpeg -hide_banner -loglevel error -y -i "$in_file" \
        -lavfi "showspectrumpic=s=${RESOLUTION}:mode=combined:color=${COLOR_SCHEME}:scale=${SCALE}:legend=1:saturation=1.2" \
        -frames:v 1 "$out_png"

    local exit_code=$?
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    if [ $exit_code -eq 0 ] && [ -f "$out_png" ]; then
        local out_size
        out_size=$(du -h "$out_png" | cut -f1)
        echo -e "  ${GREEN}✓ Generated:${NC} ${BOLD}${out_png}${NC} (${out_size}, completed in ${elapsed}s)"
        if [ "$should_open" -eq 1 ]; then
            echo -e "  ${CYAN}Displaying spectrogram in image viewer...${NC}"
            open_image_viewer "$out_png"
        fi
        return 0
    else
        echo -e "  ${RED}✗ Failed to generate spectrogram for '$base'${NC}" >&2
        return 1
    fi
}

generate_single_spek_in_place() {
    local in_file="$1"
    local prompt_view="${2:-1}"

    # Strip quotes and spaces
    in_file="$(echo "$in_file" | sed -e "s/^['\"]//" -e "s/['\"]$//" | xargs 2>/dev/null || echo "$in_file")"
    if [[ "$in_file" == "~"* ]]; then
        in_file="${HOME}${in_file:1}"
    fi

    if [ ! -f "$in_file" ]; then
        echo -e "${RED}Error: File '$in_file' does not exist!${NC}" >&2
        return 1
    fi

    local dir_path
    dir_path="$(cd "$(dirname "$in_file")" 2>/dev/null && pwd || dirname "$in_file")"
    local base
    base="$(basename "$in_file")"
    local stem="${base%.*}"
    local out_spek="${dir_path}/${stem}.spek"
    local out_spek_png="${dir_path}/${stem}.spek.png"

    echo -e "  ${BOLD}${BLUE}Analyzing:${NC} ${GREEN}${base}${NC}"
    echo -e "  • ${BOLD}Location:${NC}     ${CYAN}${dir_path}${NC}"
    echo -e "  • ${BOLD}Output File:${NC}  ${GREEN}${stem}.spek${NC}"

    local start_time
    start_time=$(date +%s)

    ffmpeg -hide_banner -loglevel error -y -i "$in_file" \
        -lavfi "showspectrumpic=s=${RESOLUTION}:mode=combined:color=${COLOR_SCHEME}:scale=${SCALE}:legend=1:saturation=1.2" \
        -frames:v 1 "$out_spek_png"

    local exit_code=$?
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    if [ $exit_code -eq 0 ] && [ -f "$out_spek_png" ]; then
        cp -f "$out_spek_png" "$out_spek"
        local out_size
        out_size=$(du -h "$out_spek_png" | cut -f1)
        echo -e "\n${BOLD}${GREEN}======================================================================${NC}"
        echo -e "${BOLD}${GREEN}✓ Spek Spectrogram Generated Successfully!${NC}"
        echo -e "  • ${BOLD}Spek File:${NC}      ${GREEN}${out_spek}${NC}"
        echo -e "  • ${BOLD}Image File:${NC}     ${GREEN}${out_spek_png}${NC}"
        echo -e "  • ${BOLD}Saved to:${NC}       ${dir_path}"
        echo -e "  • ${BOLD}Size / Time:${NC}    ${out_size} (completed in ${elapsed}s)"
        echo -e "${BOLD}${GREEN}======================================================================${NC}\n"

        if [ "$prompt_view" -eq 1 ]; then
            read -r -p "Do you want to view the Spek file after it has been fully generated? [Y/n]: " view_ask
            if [[ "$view_ask" =~ ^[Yy]?$ ]] || [ -z "$view_ask" ]; then
                echo -e "${CYAN}Displaying Spek file in image viewer...${NC}"
                open_image_viewer "$out_spek_png"
            fi
        fi
        return 0
    else
        echo -e "\n${RED}✗ Failed to generate Spek spectrogram for '$base'${NC}" >&2
        return 1
    fi
}

generate_multiple_speks_in_place() {
    local target_dir="$1"

    # Strip quotes and spaces
    target_dir="$(echo "$target_dir" | sed -e "s/^['\"]//" -e "s/['\"]$//" | xargs 2>/dev/null || echo "$target_dir")"
    if [[ "$target_dir" == "~"* ]]; then
        target_dir="${HOME}${target_dir:1}"
    fi

    if [ ! -d "$target_dir" ]; then
        echo -e "${RED}Error: Directory '$target_dir' does not exist!${NC}" >&2
        return 1
    fi

    target_dir="$(cd "$target_dir" 2>/dev/null && pwd || echo "$target_dir")"

    shopt -s nullglob nocaseglob
    local targets=("$target_dir"/*.flac "$target_dir"/*.wav "$target_dir"/*.mp3 "$target_dir"/*.m4a "$target_dir"/*.ogg "$target_dir"/*.aiff "$target_dir"/*.aif)
    shopt -u nullglob nocaseglob

    if [ ${#targets[@]} -eq 0 ]; then
        echo -e "${YELLOW}No WAV, MP3, or FLAC audio files found in '$target_dir'.${NC}"
        return 0
    fi

    echo -e "${CYAN}Found ${#targets[@]} audio file(s) in '$target_dir'. Starting in-place Spek generation...${NC}\n"
    local count=0
    local success_count=0
    local total=${#targets[@]}

    for f in "${targets[@]}"; do
        count=$((count + 1))
        local base
        base="$(basename "$f")"
        local stem="${base%.*}"
        local file_dir
        file_dir="$(dirname "$f")"
        local out_spek="${file_dir}/${stem}.spek"
        local out_spek_png="${file_dir}/${stem}.spek.png"

        echo -e "  ${BOLD}[${count}/${total}]${NC} ${CYAN}Analyzing:${NC} ${base}"

        ffmpeg -hide_banner -loglevel error -y -i "$f" \
            -lavfi "showspectrumpic=s=${RESOLUTION}:mode=combined:color=${COLOR_SCHEME}:scale=${SCALE}:legend=1:saturation=1.2" \
            -frames:v 1 "$out_spek_png"

        if [ $? -eq 0 ] && [ -f "$out_spek_png" ]; then
            cp -f "$out_spek_png" "$out_spek"
            local sz
            sz=$(du -h "$out_spek_png" | cut -f1)
            echo -e "      ${GREEN}✓ Generated:${NC} ${stem}.spek (${sz})"
            success_count=$((success_count + 1))
        else
            echo -e "      ${RED}✗ Failed generating Spek for: ${base}${NC}"
        fi
    done

    echo -e "\n${BOLD}${GREEN}======================================================================${NC}"
    echo -e "${BOLD}${GREEN}✓ Batch Spek Generation Complete!${NC}"
    echo -e "  • ${BOLD}Success:${NC}        ${success_count} / ${total} Spek files generated"
    echo -e "  • ${BOLD}Location:${NC}       ${target_dir}"
    echo -e "  • ${BOLD}File Format:${NC}    <filename>.spek & <filename>.spek.png"
    echo -e "${BOLD}${GREEN}======================================================================${NC}\n"
    return 0
}

echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo -e "${BOLD}${MAGENTA}      ACOUSTIC SPECTRUM ANALYSER & SPECTROGRAM GENERATOR (SPEK)       ${NC}"
echo -e "${BOLD}${MAGENTA}         Cross-Platform: Linux • macOS • Windows • FreeBSD            ${NC}"
echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

# In-Place Single File
if [ -n "$INPUT_FILE" ] && [ "$IN_PLACE" -eq 1 ]; then
    generate_single_spek_in_place "$INPUT_FILE" "$PROMPT_VIEW"
    exit $?
fi

# In-Place Directory
if [ -n "$INPUT_DIR" ] && [ "$IN_PLACE" -eq 1 ]; then
    generate_multiple_speks_in_place "$INPUT_DIR"
    exit $?
fi

# Mode 1: Single input file (Output to OUTPUT_DIR)
if [ -n "$INPUT_FILE" ]; then
    generate_single_spek "$INPUT_FILE" "$OUTPUT_DIR" "$AUTO_OPEN"
    exit $?
fi

# Mode 2: Specified Directory
if [ -n "$INPUT_DIR" ]; then
    if [ ! -d "$INPUT_DIR" ]; then
        echo -e "${RED}Error: Directory '$INPUT_DIR' does not exist!${NC}" >&2
        exit 1
    fi
    shopt -s nullglob nocaseglob
    targets=("$INPUT_DIR"/*.flac "$INPUT_DIR"/*.wav "$INPUT_DIR"/*.mp3 "$INPUT_DIR"/*.m4a "$INPUT_DIR"/*.ogg)
    shopt -u nullglob nocaseglob

    if [ ${#targets[@]} -eq 0 ]; then
        echo -e "${YELLOW}No supported audio files found in '$INPUT_DIR'.${NC}"
        exit 0
    fi

    echo -e "${CYAN}Found ${#targets[@]} audio file(s) in '$INPUT_DIR'. Starting batch generation...${NC}\n"
    success_count=0
    for f in "${targets[@]}"; do
        if generate_single_spek "$f" "$OUTPUT_DIR" 0; then
            ((success_count++))
        fi
        echo ""
    done
    echo -e "${BOLD}${GREEN}Batch complete: Successfully generated ${success_count}/${#targets[@]} spectrograms in '$OUTPUT_DIR'.${NC}"
    exit 0
fi

# Mode 3: Process All Archives
if [ "$PROCESS_ALL" -eq 1 ]; then
    shopt -s nullglob nocaseglob
    targets=(
        "FLAC_CONVERTED_OUTPUTS"/*.flac
        "CONVERTED_WAV_FILES"/*.wav
        "$PWD"/*.wav
        "$PWD"/*.flac
    )
    shopt -u nullglob nocaseglob

    if [ ${#targets[@]} -eq 0 ]; then
        echo -e "${YELLOW}No audio files found in archive folders.${NC}"
        exit 0
    fi

    echo -e "${CYAN}Found ${#targets[@]} candidate audio file(s) in archives. Generating spectrograms...${NC}\n"
    success_count=0
    for f in "${targets[@]}"; do
        if generate_single_spek "$f" "$OUTPUT_DIR" 0; then
            ((success_count++))
        fi
        echo ""
    done
    echo -e "${BOLD}${GREEN}Archive batch complete: Successfully generated ${success_count}/${#targets[@]} spectrograms in '$OUTPUT_DIR'.${NC}"
    exit 0
fi

# Interactive Mode if no arguments provided
echo -e "${BOLD}Select a Spectrogram Generation Mode:${NC}"
echo -e "  ${BOLD}${CYAN} 1)${NC} ${BOLD}${GREEN}Generate Spectrogram using Spek for WAV/MP3/FLAC (Single File)${NC}"
echo -e "  ${BOLD}${CYAN} 2)${NC} ${BOLD}${GREEN}Generate Speks for Multiple WAV/MP3/FLAC Files (Scan Directory Path)${NC}"
echo -e "  ${BOLD}${BLUE}──────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}${CYAN} 3)${NC} Generate Spek for Single Mix from Archive (Search or Select & Auto-Open)"
echo -e "  ${BOLD}${CYAN} 4)${NC} Batch Generate Speks for all FLACs in ${BOLD}FLAC_CONVERTED_OUTPUTS/${NC}"
echo -e "  ${BOLD}${CYAN} 5)${NC} Batch Generate Speks for all WAVs in ${BOLD}CONVERTED_WAV_FILES/${NC}"
echo -e "  ${BOLD}${CYAN} 6)${NC} Batch Generate Speks for WAV/FLAC files in Current Directory ($PWD)"
echo -e "  ${BOLD}${CYAN} 7)${NC} Launch Native Spek GUI Application (macOS / Windows / Linux / FreeBSD)"
echo -e "  ${BOLD}${CYAN} 8)${NC} Open Spectrograms Output Folder (${BOLD}${OUTPUT_DIR}/${NC})"
echo -e "  ${BOLD}${CYAN} 9)${NC} Launch Sonic Visualiser (Open mix in Sonic Visualiser Spectrogram pane)"
echo -e "  ${BOLD}${CYAN}10)${NC} Generate SoX High-Resolution Spectrogram (Viridis, Magma, Rainbow, Mono)"
echo -e "  ${BOLD}${CYAN}11)${NC} Launch Praat / Kwave / Audacity Spectral Analyzer"
echo -e "  ${BOLD}${CYAN} 0)${NC} Exit\n"

read -r -p "Enter choice [0-11]: " choice

case "$choice" in
    1)
        echo -e "\n${BOLD}${MAGENTA}=== GENERATE SPECTROGRAM USING SPEK FOR WAV/MP3/FLAC (SINGLE FILE) ===${NC}\n"
        echo -e "${CYAN}Please enter the path to the .FLAC, MP3 or WAV audio mix file:${NC}"
        read -e -r -p "Audio File Path: " raw_path
        local s_path
        s_path="$(echo "$raw_path" | sed -e "s/^['\"]//" -e "s/['\"]$//" | xargs 2>/dev/null || echo "$raw_path")"
        if [ -n "$s_path" ]; then
            if [[ "$s_path" == "~"* ]]; then
                s_path="${HOME}${s_path:1}"
            fi
            generate_single_spek_in_place "$s_path" 1
        else
            echo -e "${YELLOW}No path provided. Returning...${NC}"
        fi
        ;;
    2)
        echo -e "\n${BOLD}${MAGENTA}=== GENERATE SPEKS FOR MULTIPLE WAV/MP3/FLAC FILES ===${NC}\n"
        echo -e "${CYAN}Please enter a path where one or more audio files exist:${NC}"
        read -e -r -p "Directory Path: " raw_dir
        local s_dir
        s_dir="$(echo "$raw_dir" | sed -e "s/^['\"]//" -e "s/['\"]$//" | xargs 2>/dev/null || echo "$raw_dir")"
        if [ -n "$s_dir" ]; then
            if [[ "$s_dir" == "~"* ]]; then
                s_dir="${HOME}${s_dir:1}"
            fi
            generate_multiple_speks_in_place "$s_dir"
        else
            echo -e "${YELLOW}No path provided. Returning...${NC}"
        fi
        ;;
    3)
        shopt -s nullglob nocaseglob
        audio_list=(
            "FLAC_CONVERTED_OUTPUTS"/*.flac
            "CONVERTED_WAV_FILES"/*.wav
            "$PWD"/*.wav
            "$PWD"/*.flac
        )
        shopt -u nullglob nocaseglob

        if [ ${#audio_list[@]} -eq 0 ]; then
            echo -e "\n${YELLOW}No audio files found in standard directories.${NC}"
            read -r -p "Enter path to an audio file manually: " manual_file
            if [ -f "$manual_file" ]; then
                generate_single_spek "$manual_file" "$OUTPUT_DIR" 1
            else
                echo -e "${RED}File not found.${NC}"
            fi
            exit 0
        fi

        echo -e "\n${BOLD}Choose selection method:${NC}"
        echo -e "  ${CYAN}1)${NC} Search for mix by keyword or episode number"
        echo -e "  ${CYAN}2)${NC} Select from list of recent mixes (${#audio_list[@]} available)"
        read -r -p "Enter selection [1-2]: " smode

        sel_file=""
        if [ "$smode" = "1" ]; then
            read -r -p "Enter search query (e.g. 033, 041, Who am I): " query
            matched=()
            for a in "${audio_list[@]}"; do
                if echo "$(basename "$a")" | grep -qi "$query"; then
                    matched+=("$a")
                fi
            done
            if [ ${#matched[@]} -eq 0 ]; then
                echo -e "${RED}No audio files matched '${query}'.${NC}"
                exit 1
            fi
            echo -e "\n${BOLD}Matching Mixes:${NC}"
            for i in "${!matched[@]}"; do
                echo -e "  ${CYAN}$((i + 1)))${NC} $(basename "${matched[$i]}")"
            done
            read -r -p "Select mix number [1-${#matched[@]}]: " pick
            if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#matched[@]}" ]; then
                sel_file="${matched[$((pick - 1))]}"
            fi
        else
            echo -e "\n${BOLD}Recent Mixes in Archive:${NC}"
            max_show=25
            for i in "${!audio_list[@]}"; do
                [ "$i" -ge "$max_show" ] && break
                echo -e "  ${CYAN}$((i + 1)))${NC} $(basename "${audio_list[$i]}")"
            done
            read -r -p "Select mix number [1-${#audio_list[@]}]: " pick
            if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#audio_list[@]}" ]; then
                sel_file="${audio_list[$((pick - 1))]}"
            fi
        fi

        if [ -n "$sel_file" ] && [ -f "$sel_file" ]; then
            echo ""
            generate_single_spek "$sel_file" "$OUTPUT_DIR" 1
        else
            echo -e "${RED}Invalid selection.${NC}"
        fi
        ;;
    4)
        echo ""
        "$0" -d "FLAC_CONVERTED_OUTPUTS" -o "$OUTPUT_DIR"
        ;;
    5)
        echo ""
        "$0" -d "CONVERTED_WAV_FILES" -o "$OUTPUT_DIR"
        ;;
    6)
        echo ""
        "$0" -d "$PWD" -o "$OUTPUT_DIR"
        ;;
    7)
        echo ""
        launch_native_spek_gui "" || true
        ;;
    8)
        echo -e "\n${CYAN}Opening ${OUTPUT_DIR}/...${NC}"
        open_image_viewer "$OUTPUT_DIR"
        ;;
    9)
        echo ""
        read -r -p "Enter path to audio mix (or press Enter to select recent): " sfile
        if [ -z "$sfile" ]; then
            sfile="$(find FLAC_CONVERTED_OUTPUTS CONVERTED_WAV_FILES -name "*.flac" -o -name "*.wav" 2>/dev/null | head -n 1 || true)"
        fi
        launch_sonic_visualiser "$sfile" || true
        ;;
    10)
        echo ""
        read -r -p "Enter path to audio mix (or press Enter for newest): " sxfile
        if [ -z "$sxfile" ]; then
            sxfile="$(find FLAC_CONVERTED_OUTPUTS CONVERTED_WAV_FILES -name "*.flac" -o -name "*.wav" 2>/dev/null | head -n 1 || true)"
        fi
        echo "Select colormap: 1) Magma/Fire  2) Viridis  3) Rainbow  4) Monochrome"
        read -r -p "Choice [1-4, default 1]: " cmap_choice
        cmap="magma"
        [ "$cmap_choice" = "2" ] && cmap="viridis"
        [ "$cmap_choice" = "3" ] && cmap="rainbow"
        [ "$cmap_choice" = "4" ] && cmap="mono"
        generate_sox_spectrogram "$sxfile" "$OUTPUT_DIR" "$cmap"
        ;;
    11)
        echo ""
        read -r -p "Enter path to audio mix (or press Enter for newest): " prfile
        if [ -z "$prfile" ]; then
            prfile="$(find FLAC_CONVERTED_OUTPUTS CONVERTED_WAV_FILES -name "*.flac" -o -name "*.wav" 2>/dev/null | head -n 1 || true)"
        fi
        launch_praat_or_kwave "$prfile" || true
        ;;
    0|[qQ])
        exit 0
        ;;
    *)
        echo -e "\n${RED}Invalid choice!${NC}"
        exit 1
        ;;
esac
