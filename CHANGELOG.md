# Changelog

All notable changes to the **Mix Archive Manager** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.2.1] - 2026-09-17

- **Strawberry Music Player Integration & Startup Autoplay Fix**:
  - Configured Strawberry as default audio player (`DEFAULT_AUDIO_PLAYER="strawberry"`) across `Mix_Archive_Manager.sh`, `config.env`, and `config.env.example`.
  - Resolved issue where launching the manager automatically opened `cliamp` even when Strawberry was already playing.
  - Added active playback pre-check in `execute_startup_autoplay`: detects if Strawberry or any other player is currently playing before initiating playback or launching external windows.
  - Implemented `get_strawberry_track_info` via MPRIS D-Bus (`qdbus`, `dbus-send`, and `playerctl` fallbacks) to report live playback status, track title, artist, album, elapsed time, total duration, progress percentage, and resolved file path.
  - Integrated Strawberry real-time status display into the manager's Live Status Box (`show_stats`), active background tasks list (`show_active_tasks`), and command-line flags (`--strawberry-info`, `--track`, `--current-track`, `-p`).
  - Removed unused experimental Javascript binary artifact (`bin/mix-archive-manager.js`).
- **FLAC & YouTube MP4 Video Splitting Utilities**:
  - Implemented standalone interactive utility `Split_FLAC_File.sh` (mirrored to `scripts/Split_FLAC_File.sh`, symlinked to `bin/split-flac` and `~/.local/bin/split-flac`):
    - Discovers candidate `.flac` files in `FLAC_CONVERTED_OUTPUTS` and allows manual entry/pasting of custom full paths.
    - Prompts user for the number of parts $N$ and calculates duration per part with sample-accurate division.
    - Losslessly splits FLAC audio using `ffmpeg` (`-c:a flac -map_metadata 0`) with the final part capturing to the exact end without truncation.
    - Always outputs split parts (`<stem>_Part01.flac`, `<stem>_Part02.flac`...) into the exact directory of the input file and opens the file manager.
  - Implemented standalone interactive utility `Split_Video_File.sh` (mirrored to `scripts/Split_Video_File.sh`, symlinked to `bin/split-video` and `~/.local/bin/split-video`):
    - Discovers candidate `.mp4` video files across archive directories (`downloaded_videos`, `RENDERED_SOF_EPISODES`, etc.) and allows manual entry/pasting of custom full paths.
    - Prompts user for number of parts $N$ and split mode (Fast Lossless Stream Copy or Frame-Accurate Re-encode).
    - Divides video files into equal parts, naming them `<stem>_Part01.mp4`, `<stem>_Part02.mp4`... directly in the input video's directory and opens the file manager.
  - Integrated into `Mix_Archive_Manager.sh`:
    - **Option 2 (manage_audio_conversion)**: Added Option 6 to launch `Split_FLAC_File.sh`.
    - **Option 38 (manage_video_cut_and_split)**: Upgraded Option 38 to a Video Cutting & Splitting Suite (`Cut_Video.sh` & `Split_Video_File.sh`).
    - Added CLI flags `--split-flac`, `--split-video`, `--split-mp4`, and `--cut-video`.
    - Added direct console menu keyword triggers `split-flac` and `split-video`.
- **Beszel Server Monitoring Hub & Hardware/GPU Agent (Option 57)**:
  - Added standalone management script `scripts/beszel.sh` (mirrored to `beszel.sh`, symlinked to `bin/beszel` and `~/.local/bin/beszel`):
    - Controls Beszel Hub (`beszel` container on port 8090) and Beszel Agent (`beszel-agent` container with NVIDIA GPU passthrough and Podman socket access).
    - Features starting Hub, Agent, or both simultaneously with automatic container existence checks and launch script fallbacks (`launch_beszel_hub_replace.sh`, `launch_beszel_agent_replace.sh`).
    - Verifies user `podman.socket` service status and activates it automatically when starting the agent.
    - Includes live status inspection (container health, uptime, web dashboard HTTP health, agent-to-hub WebSocket status, NVIDIA GPU model/VRAM).
    - Added direct browser dispatch to open Beszel Web Dashboard (`http://localhost:8090`).
    - Added live container log viewer and streaming log follower for both Hub and Agent.
  - Integrated into `Mix_Archive_Manager.sh`:
    - **Option 57**: `Manage Beszel Server & Monitoring Agent` in Section 6 (System, Network & Hardware Management).
    - Added CLI flags `--beszel`, `--beszel-start`, `--beszel-hub`, `--beszel-agent`, `--beszel-dashboard`, `--beszel-stop`, and `--beszel-status`.
    - Added direct sub-option dispatch arguments (`57 1` to start both, `57 2` for Hub, `57 3` for Agent, `57 4` for Dashboard, `57 5` to stop).
    - Added direct console menu keyword triggers `beszel`, `beszel-start`, `beszel-hub`, and `beszel-agent`.
  - Registered into `install.sh` for automatic symlink and desktop entry management.
- **KDE Connect & Desktop Shortcuts for WAN2GP Server Management**:
  - Created dedicated KDE Connect remote commands and scripts (`kc_start_wan2gp_profile45.sh`, `kc_stop_wan2gp.sh`):
    - **Option 56 / 2**: `Start WAN2GP (Profile 4.5 - Low VRAM)` launches WAN2GP in Profile 4.5 in a new Konsole tab/window with active-process pre-check and desktop notification feedback.
    - **Option 56 / 3**: `Stop WAN2GP Server` safely terminates the active WAN2GP server with status notifications.
  - Registered remote commands into KDE Connect device configuration (`~/.config/kdeconnect/*/kdeconnect_runcommand/config`) and deployed to `~/KDE_CONNECT_CMDS/`.
  - Added direct command-line arguments to `Mix_Archive_Manager.sh` and `bin/mix-archive-manager`: `--wan2gp-start-4.5`, `--wan2gp-stop`, `56 2`, and `56 3`.
  - Created `.desktop` application entries (`wan2gp-start-profile45.desktop`, `wan2gp-stop.desktop`) in `desktop/`, `~/.local/share/applications/`, and `~/Desktop/` for KRunner/application menu launcher and global shortcut integration.
  - Added symlinks `wan2gp-start-profile45` and `wan2gp-stop` into `bin/` and `~/.local/bin/`.
  - Updated `install.sh` to install all desktop shortcuts, KDE Connect scripts, and symlinks automatically.
- **KDE Connect & Desktop Shortcuts for Ollama Server (distrobox: ollama-container)**:
  - Created dedicated KDE Connect remote commands and scripts (`kc_run_ollama_serve.sh`, `kc_stop_ollama.sh`):
    - `Run Ollama Server (distrobox)` enters `ollama-container` via `distrobox enter ollama-container -- ollama serve`, with active endpoint pre-check on port 11434, container auto-start, and desktop notifications.
    - `Stop Ollama Server` terminates active `ollama serve` processes with notification confirmation.
  - Registered remote commands into KDE Connect device configuration (`~/.config/kdeconnect/*/kdeconnect_runcommand/config`) and deployed to `~/KDE_CONNECT_CMDS/`.
  - Created `.desktop` application entries (`ollama-serve.desktop`, `ollama-stop.desktop`) in `desktop/`, `~/.local/share/applications/`, and `~/Desktop/`.
  - Added symlinks `ollama-serve` and `ollama-stop` into `bin/` and `~/.local/bin/`.
- **KDE Connect & Desktop Shortcuts for Beszel Hub & Agent and dsh-mobile**:
  - Created dedicated KDE Connect remote commands and scripts:
    - `Launch Beszel Hub & Agent` (`kc_launch_beszel_hub_and_agent.sh`): Verifies and starts both `beszel` (hub on port 8090) and `beszel-agent` (GPU/system metrics agent) containers with notifications.
    - `Launch dsh-mobile (DeepSeek Harness)` (`kc_launch_dsh_mobile.sh`): Boots DeepSeek Harness web UI with LAN mobile trust (`--trusted-host 192.168.1.11:3080 --trusted-host 192.168.1.11 --no-open`) in a dedicated Konsole session with port 3080 pre-check and notifications.
  - Registered remote commands into KDE Connect device configuration (`~/.config/kdeconnect/*/kdeconnect_runcommand/config`) and deployed to `~/KDE_CONNECT_CMDS/`.
  - Created `.desktop` application entries (`beszel-hub-and-agent.desktop`, `dsh-mobile.desktop`) in `desktop/`, `~/.local/share/applications/`, and `~/Desktop/`.
  - Added symlinks `beszel-hub-and-agent` and `dsh-mobile` into `bin/` and `~/.local/bin/`.

## [0.2.0] - 2026-09-14

- **Cross-Platform Traktor Pro Live Monitor & Audio Recorder Control (Option 48)**:
  - Downloaded and upgraded Traktor monitor suite from remote macOS host (`192.168.1.138`) into core repository (`scripts/traktor_monitor.py`, `scripts/traktor_monitor.sh`, `traktor_monitor.sh`, `bin/traktor-monitor`).
  - Upgraded engine with comprehensive **Microsoft Windows 10 & 11** native support:
    - Multi-process detection for `Traktor.exe`, `Traktor Pro 3.exe`, and `Traktor Pro 4.exe` via `tasklist` and PowerShell CIM/WMI queries.
    - Real-time CPU % load and RSS RAM memory footprint profiling.
    - Native Windows console non-blocking hotkey input using `msvcrt.kbhit()` and `msvcrt.getch()`.
    - Active deck audio tracking via Traktor session history XML (`history_*.nml`) parsing and file handle inspection.
    - Real-time recording file status and multi-directory file size growth detector (`RECORDING_DIRS`) to identify active mix recordings and standby files.
    - Traktor recording control via Windows `WScript.Shell` / `AppActivate("Traktor")` automation and keyboard shortcuts.
    - Native double-clickable Windows launchers: `traktor_monitor.bat` and `traktor_monitor.ps1`.
  - Maintained full macOS support (`traktor_monitor_macos.command`) with AppleScript System Events menu clicking and CoreAudio queries.
  - Native Linux support with `/proc/$pid/fd` inspection, PipeWire audio endpoint probe, and Wine/Proton path detection.
  - Interactive hotkeys: `[S]` Start Recording, `[X]` Stop Recording, `[T]` Toggle Recording, `[R]` Refresh, `[Q]` Quit.
  - Integrated into `Mix_Archive_Manager.sh` as dedicated **Option 48** in Section 5 (Live Monitors) launching in a new terminal window (`launch_in_terminal` in Konsole, Terminal.app, Windows Terminal `wt.exe`, Alacritty, Foot, XTerm).
  - Added companion launch option in Section 3 Digital Audio Workstations (`manage_daws`).
  - Added process tracking in `view_tasks` for `traktor_monitor` and `Traktor`.
  - Expanded master operations to **72 operations** across 7 logical sections.

- **Advanced Audio File Specification & Stream Inspector (Option 28)**:
  - Added dedicated audio inspector engine (`scripts/inspect_playing_audio.py`, `scripts/inspect_playing_audio.sh`, `bin/view-mix-specs`, and `view_playing_specs.sh`).
  - Probes and displays deep technical stream specifications of currently playing audio (or selected archive mix):
    - Container & Encoded Format (e.g. `WAV`, `FLAC`, `MP3`, `AAC`, `OGG`)
    - Exact Bit Depth (`24-Bit`, `16-Bit`, `32-Bit Float/Int`)
    - Sampling Frequency / Rate (`48,000 Hz / 48.0 kHz`, `44.1 kHz`, `96.0 kHz`, etc.)
    - Full File Path & File Name
    - Duration (`HH:MM:SS.ms`) & Audio File Size (Bytes, MB, GB)
    - Track Title, Artist, Album, and Encoded Metadata
    - Audio Codec long name, Bitrate (`kbps`), Channels (`Stereo`), and Total PCM Samples
    - Storage Drive mount point, filesystem, and remaining free space
    - FLAC Compression Ratio (`% of raw PCM`) and exact MBs saved
    - Associated Companion Assets (Embedded Artwork, High-Res Cover Art, Tracklist with track count, Spectrogram, and Companion Video)
  - Interactive Terminal HUD with hotkeys: `[T]` View tracklist in console, `[C]` View cover art, `[S]` View spectrogram, `[Y]` Copy path to clipboard, `[D]` Open in DAW, `[F]` Open containing folder in file manager, `[R]` Refresh playback position, `[Q]` Return to menu.
  - Real-time stream summary displayed in the Live Status Box (`show_stats`), startup autoplay playback HUD (`execute_startup_autoplay`), now-playing asset HUD (`auto_show_playing_mix_assets`), and `cliamp` track control menu (`manage_cliamp`).

- **Active Audio Interface & Latency Display on Boot**:
  - Real-time detection of active default sound output device and hardware buffer latency (`scripts/get_audio_interface.py`).
  - High-performance probe (<120ms):
    - Linux PipeWire & WirePlumber via `wpctl inspect @DEFAULT_AUDIO_SINK@` and `pw-metadata -n settings` (calculates `(quantum / clock_rate) * 1000` ms)
    - ALSA hardware buffer parameters via `/proc/asound/card*/pcm*p/sub*/hw_params`
    - PulseAudio fallback via `pactl`
    - macOS CoreAudio via AppleScript / `system_profiler`
    - Windows WASAPI via PowerShell `Win32_SoundDevice`
    - FreeBSD OSS via `/dev/sndstat`
  - Integrated directly into the main application banner:
    `🎧 Audio Interface: Crusher ANC 2  │  ⚡ Latency: 21.3ms (1024 @ 48kHz)  │  🎛️ Engine: PipeWire`
  - Also displayed in the startup playback and now-playing HUDs.

- **Centered & Vertically Aligned Cover Art & Borderless Tracklist HUD**:
  - Positions the Cover Art Viewer and Tracklist Console side-by-side in the middle of the screen floating directly on top of the manager window (`keepAbove = true`).
  - Seamlessly integrates with KDE Plasma 6 KWin Scripting DBus API on Bazzite Linux Wayland (`scripts/align_mix_windows.py`), with automatic fallbacks for X11 (`wmctrl`/`xdotool`) and macOS AppleScript.
  - Zero window overlap: cover art positioned on the left and tracklist console on the right with matching vertical alignment and identical height.
  - Automatically loads and displays the playing mix's cover art in an image viewer window (`open_cover_art_window` via Gwenview / Loupe / Preview / Photos) **and** spawns the complete mix tracklist in a dedicated window on the operating system's default console.
  - **Entirely Borderless on Bazzite Linux**: Seamlessly leverages KDE Plasma 6 KWin rules (`noborder=true`, `noborderrule=2`, `above=true`, `aboverule=2`) and Konsole flags (`--hide-menubar`, `--hide-tabbar`, `-p TerminalMargin=0`) to present tracklists in a clean, frameless, titlebar-free floating HUD window.
  - Interactive console viewer (`scripts/view_tracklist_console.sh` & `bin/view-tracklist`):
    - Syntax-highlighted track entries with artist, title, remix/version tags, and metadata headers.
    - Hotkey controls: `[Q]` close/exit, `[C]` copy tracklist to system clipboard (`wl-copy` / `xclip` / `pbcopy`), `[S]` full interactive paging via `less`, and `[R]` reload tracklist from disk.
  - Cross-platform console integration: Konsole / foot / alacritty / xterm on Linux & FreeBSD, Terminal.app on macOS, and Windows Terminal (`wt.exe`) / CMD on Windows 10 & 11.
  - Automated KWin rule injection during `./install.sh` and runtime fallback via `ensure_bazzite_borderless_kwin_rule`.
  - Added archive-wide deep discovery (`find_mix_tracklist` & `find_mix_cover`) locating episode tracklists and cover artwork even within nested series subdirectories (e.g., `Stream of Frequency/070/`).
  - Enhanced startup autoplay sorting to select the true newest mix by modification time (`mtime`) rather than alphabetical sorting.

- **Live Meteorological Weather Display**:
  - Displays live weather conditions below the main startup banner (`scripts/get_weather.sh`).
  - Default configured location: **Swansea, UK**.
  - Meteorological cache with 20-minute TTL (`assets/weather_cache.txt`) ensures 0ms latency during banner startup renders.
  - Complete configuration menu (`manage_weather_menu`) to toggle weather display, change location, force live refresh, or clear location and disable completely.

- **Go Shopping for New Music (Option 20)**:
  - Added `scripts/shop_music.sh` to quickly launch browser tabs for **Beatport** (`https://www.beatport.com`), **Apple Music** (`https://music.apple.com`), and **Bandcamp** (`https://bandcamp.com`).
  - Native browser tab integration with Flatpak Google Chrome / Firefox, native browsers, or `xdg-open` / `open` / `cmd.exe`.

- **Dedicated Video Player Launcher & Video Dispatcher (Option 39)**:
  - Added `scripts/launch_specific_video.sh` to launch specific mix videos or streams in user's default video player (VLC default, mpv, Haruna, Kodi).
  - Allows selecting from archive videos, NFT video library, custom file paths, or streaming/YouTube URLs.

- **Startup Custom YouTube Video URL Autoplay**:
  - Automatically plays custom YouTube video URL on manager start **only if a mix is playing already** in a music player.
  - Configurable via `config.env` (`DEFAULT_VIDEO_PLAYER="vlc"`, `AUTO_PLAY_YOUTUBE_ON_STARTUP="false"`, `STARTUP_YOUTUBE_URL=""`) and interactive settings menu (Option 26 > 18 & 19).

- **Mix Publishing Schedule Calendar & Multi-Platform Syndication**:
  - Added `publish_calendar_scheduler.py` and `publish_calendar_scheduler.sh` (Option 19).
  - Enables release scheduling across all major music and podcast platforms: Apple Podcasts, Spotify for Podcasters, YouTube, SoundCloud, Mixcloud, DI.FM, Proton Radio, and Bandcamp.
  - Persistent schedule database in `assets/publishing_calendar.json`.
  - Automated Apple Podcasts compliant RSS feed generator (`podcast_feed.xml`).
  - Standard RFC 5545 iCalendar (`.ics`) file export with mix URLs, artwork, and descriptions for Google Calendar, Apple Calendar, and Outlook.

- **Expanded Acoustic Spectrogram Suite**:
  - Expanded acoustic analysis beyond Spek in `generate_spek.sh` (Option 22).
  - Added **Sonic Visualiser** launcher and profile inspection for deep frequency analysis.
  - Added **SoX** high-resolution 24-bit multi-colormap spectrogram rendering (`sox -n -p synth spectrogram`) with channel separation and custom frequency scales.
  - Added support for **Praat** phonetic and acoustic sonagram analysis, **Kwave**, and **Audacity** spectrogram mode.

- **Studio Diagnostics & Hardware/Software Inspector**:
  - Added `inspect_audio_studio.py` and `inspect_audio_studio.sh` (Option 33).
  - Complete audio architecture detection: PipeWire, PulseAudio, and ALSA cards, sinks, sources, active sample rates, and buffer latencies.
  - Hardware MIDI surface and controller detection (AKAI MPKmini2, Arturia MiniLab mkII, Valve controllers, synthesizers).
  - Software audit scanning installed DAWs and audio software (REAPER, Logic Pro, FL Studio, Traktor, Audacity, Ardour, Bitwig, Picard, Spek, cliamp, VLC, Haruna, Kodi).

- **Master Audio Control & Instant Mute Toggle**:
  - Added `toggle_audio_mute` and `get_audio_volume_and_mute` (Option 34).
  - Instant hardware-level mute toggle via PipeWire (`wpctl`), PulseAudio (`pactl`), ALSA (`amixer`), and AppleScript on macOS.
  - Real-time master volume and mute state displayed live in the manager loop prompt bar.

- **Procedural Netpbm P6 Binary .PPM Cover Art Generator**:
  - Added `generate_ppm_cover.py` and `generate_ppm_cover.sh` (Option 42).
  - Pure Python mathematical generator emitting 24-bit binary Netpbm P6 PPM files without heavy external dependencies.
  - Linear, radial, plasma wave, and angular gradient algorithms.
  - 8 curated color palettes: Cyberpunk Neon, Solarized Dusk, Deep Space Trance, Sunset Horizon, Emerald Matrix, Acid Gold, Retro Synthwave, and Mono Chrome.
  - High-res composited typography overlays (Artist, Title, Episode Number, Subtitle, Category Tags).
  - Automated conversion to anti-aliased high-res PNG (`1400x1400` / `3000x3000`).

- **Synchronized Mix-Video Companion Player Daemon**:
  - Added `sync_video_companion.py` and `sync_video_companion.sh` (Option 44).
  - Intelligent background daemon that detects the currently playing mix via `cliamp` or MPRIS.
  - Discovers matching companion video files (`.mp4`, `.mkv`, `.webm`) in the archive.
  - Launches companion video in VLC, Haruna, MPV, or Kodi, keeping video playback aligned with audio.
  - Automatically terminates video playback when audio playback stops.

- **Custom Mix Playlists Suite (.m3u8 / .xspf)**:
  - Added `manage_playlists.py` and `manage_playlists.sh` (Option 27).
  - Build, browse, search, and edit custom playlists from archive mixes.
  - Calculates total playlist duration, track count, and disk size.
  - Exports standard UTF-8 extended `.m3u8` and XML `.xspf` playlists.
  - Direct one-click launcher into `cliamp`, `strawberry`, `vlc`, or `mpv`.

- **Dynamic System MOTD Banner Manager**:
  - Added `manage_motd.py` and `update_system_motd.sh` (Option 63).
  - Scans the archive and generates a dynamic Message Of The Day summarizing the last 5 created mixes with dates, times, file sizes, formats, and sample rates.
  - Installs to `/etc/motd` or prints on demand in stylized ANSI format.

- **Exact Distro Name & Version Detection**:
  - Upgraded `get_os_badge()` in `Mix_Archive_Manager.sh` to read `/etc/os-release`.
  - Accurately displays full distribution name and version (e.g., `Bazzite Linux 44.20260902.0 (Kinoite)`) alongside kernel and architecture.

- **Live Manager & System Uptime Display**:
  - Added `get_manager_uptime()` tracking manager session uptime and host system uptime.
  - Displayed live at the bottom of the menu loop right above the user choice prompt.

- **Startup Autoplay & Now Playing Asset Discovery**:
  - Added `detect_currently_playing_mix()`, `auto_show_playing_mix_assets()`, and `check_and_show_currently_playing_mix()`.
  - If a mix is already playing when the manager launches or begins playing in an audio player, matching cover artwork and tracklists are automatically opened and displayed.

### 🛠️ Improvements & Enhancements

- **Menu Expansion**: Expanded master operations menu to **71 operations** across 7 logical sections with 1:1 case-dispatch synchronization.
- **Cross-Platform Launchers**: Updated all native platform launchers (`manager.sh`, `manager_macos.command`, `manager.bat`, `manager.ps1`, `manager_freebsd.sh`, `desktop/Mix_Archive_Manager.desktop`) to version `v0.2`.
- **Dual-Mirror Sync**: Maintained full synchronization between working directory and `/var/home/mplanetarian/Documents/BASH_SCRIPTS/`.

---

## [0.1.0] - 2026-09-13

### 🎧 Initial Release

- **Master Interactive Console**: 62 core operations organized in 7 logical sections.
- **Audio Ingestion & 32-bit FLAC Conversion**: Multi-part WAV concatenation, 32-bit sample depth FLAC encoding (`Make_SOF_FLAC_CONVERSION.sh`), embedded artwork, and 1080p spectrogram generation.
- **Audio Format & Bit Depth Conversion**: Universal conversion between WAV, MP3, Ogg Vorbis, Opus, AAC, ALAC, and bit depths (32-bit float, 32-bit int, 24-bit, 16-bit).
- **Duplicate Audio Finder**: Content-based hashing and episode duplicate detection (`find_duplicate_mixes.py`).
- **Traktor Pro History Integration**: Automatic parsing of Traktor history XML (`collection.nml`) to generate timestamped cue tracklists.
- **HTML & PDF Tracklist Documentation**: Master HTML index and printable vector PDF tracklists (`generate_tracklist_docs.py`).
- **Promotional Outreach Suite**: HTML and Plaintext email pitcher for promoters, publishers, radio stations, and record labels (`send_promo_email.py`).
- **DAW Integration**: One-click dispatch to REAPER, Logic Pro, FL Studio, Traktor Pro, GarageBand, Audacity, Ardour, and Bitwig.
- **cliamp Terminal Music Player**: Integrated retro music player with MPRIS monitoring, clipboard copy, and real-time path resolution.
- **YouTube Video Synthesis**: Hardware-accelerated 4K UHD, 1080p Full HD, and 720p HD video generation with audio fading.
- **Cloud & Network Sync**: Google Drive rclone synchronization and SMB network share importer (`search_and_import_mixes.sh`).
- **Installation & Config Migration**: Full migration wizard, snapshot backups, portable `.tar.gz` bundle export and import with SHA-256 validation.
- **Terminal Theme Engine**: 9 color themes (Cyberpunk, Dracula, Nord, Matrix, Solarized, Tokyo Night, Monokai, Gruvbox, Emerald, Classic).
- **Cross-Platform Compatibility**: Full validation on Linux (Bazzite / SteamOS / Fedora / Ubuntu), macOS, Windows 10/11, and FreeBSD.
