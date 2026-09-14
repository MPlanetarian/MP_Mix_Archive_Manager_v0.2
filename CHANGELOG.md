# Changelog

All notable changes to the **Mix Archive Manager** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.2.0] - 2026-09-14

### 🚀 Major Highlights & New Features

- **Dual-Window Startup Mix Experience & Dedicated Tracklist Viewer**:
  - Automatically loads and opens the playing mix's cover art in an image viewer window (`xdg-open` / Gwenview / Preview / Photos) **and** spawns the complete mix tracklist in a dedicated text editor window (KWrite, Kate, Gedit, TextEdit, Notepad, or Konsole).
  - Added `open_tracklist_window()` cross-platform launcher with auto-detection and user-configurable viewer preference (`TRACKLIST_VIEWER` in `config.env`).
  - Added archive-wide deep discovery (`find_mix_tracklist` & `find_mix_cover`) locating episode tracklists and cover artwork even within nested series subdirectories (e.g., `Stream of Frequency/070/`).
  - Enhanced startup autoplay sorting to select the true newest mix by modification time (`mtime`) rather than alphabetical sorting.

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

- **Menu Expansion**: Expanded master operations menu from 62 to **69 operations** across 7 logical sections with 1:1 case-dispatch synchronization.
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
