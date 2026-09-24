# Mix Archive Manager (`MP_Mix_Archive_Manager_v0.2`)

[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20FreeBSD-blue.svg)](README.md)
[![macOS](https://img.shields.io/badge/macOS-Sonoma%20%7C%20Sequoia%20%7C%20Apple%20Silicon%20%26%20Intel-silver.svg)]()
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011%20%7C%20Git%20Bash%20%7C%20WSL2-0078D6.svg)]()
[![FreeBSD](https://img.shields.io/badge/FreeBSD-14.x%20%7C%2015--CURRENT%20%7C%20Ports%20%26%20Pkg-red.svg)]()
[![Shell](https://img.shields.io/badge/Language-Bash%20%7C%20Python%20%7C%20PowerShell-orange.svg)]()
[![Audio](https://img.shields.io/badge/Audio-32bit%20Lossless%20FLAC-green.svg)]()
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

An enterprise-grade workstation orchestration console and media management suite designed for high-resolution audio production, multi-hour DJ mix archiving, automated FLAC mastering, Traktor Pro playlist extraction, live tracklist tracking, YouTube video synthesis, system maintenance, and AI workflow control across **Linux (Bazzite / SteamOS / Fedora / Ubuntu)**, **macOS (Latest Sequoia / Sonoma, Apple Silicon M1-M4 & Intel)**, **Microsoft Windows 10 & 11**, and **FreeBSD (14.x / 15-CURRENT)**.

---

## ⚡ Spotlight Feature: Traktor History to Harmonically Sorted Playlist & Stage Setup (macOS Native)

> [!IMPORTANT]
> **DJing on macOS with Native Instruments Traktor Pro?** You can now convert past live gig recordings and rehearsal history logs into clean, harmonically organized playlists and launch straight into your next mix with a single keypress.

Whether you've just wrapped a 4-hour live session or want to revisit and rebuild your best transitions from last month, **Mix Archive Manager** eliminates tedious set reconstruction:

```mermaid
flowchart LR
    A["📜 Traktor History (.nml)"] --> B["🔎 Terminal Session Browser"]
    B --> C["👁️ Console Tracklist Preview"]
    C --> D["🎹 Harmonic Key Sorter (Ascending)"]
    D --> E["📁 Root Playlists Collection"]
    E --> F["🖥️ Full-Screen Traktor Pro Launch"]
    F --> G["🎛️ Auto-Load Decks A, B, C & D"]
```

### 🎧 Why Every Traktor DJ on Mac/Windows Needs This:
- 🔍 **Auto-Detection Across Traktor Versions**: Automatically detects your installed Traktor Pro release (Traktor 3, Traktor Pro 3.11+, Traktor Pro 4) and instantly discovers your session History `.nml` archives without needing any manual path configuration.
- 📜 **Interactive Session History Browser**: Lists all your past performance sessions with session dates, start timestamps, and total tracks played.
- 👁️ **Console Tracklist Preview**: Inspect the full played setlist (Artist, Title, Duration, Key, BPM) in your terminal *before* committing to generate.
- 🎹 **Harmonic Key Ascending Order**: Tracks are automatically sorted in ascending musical / Camelot key order (1A–12B), ensuring harmonic mixing compatibility right from the first transition!
- 📁 **Native Traktor Playlist Injection**: Generates a standard Traktor playlist `.nml` directly inside Traktor's default Root Playlists directory (`$ROOT`), appearing immediately in Traktor's browser tree.
- 🚀 **Instant Full-Screen Stage Dispatch**:
  - Automatically brings Traktor Pro to the front in **Full Screen** mode.
> [!TIP]
> **Ready to level up your workflow?** Clone or download the repository, launch `./manager_macos.command` (or select Option 33 on macOS) -   
33) Generate Playlist from History Files on Traktor 3 (v3.11.1 Key Sorted / Decks Ready)
, and experience effortless set reconstruction and instant stage prep. Star the repo to follow new updates!

### 🕹️ How It Works in 3 Quick Steps:
1. **Launch the Manager on macOS**:
   ```bash
   ./manager_macos.command
   # or press Option 33 on the Main Menu, or Option 21 -> 12 in the DAWs Menu
   ```
2. **Select & Preview Your Session**:
   Choose any past DJ session from the interactive list. Instantly review the entire setlist in the terminal, including musical keys and tempo.
3. **Hit Enter & Start Mixing!**:
   The manager backs up `collection.nml`, inserts your harmonic playlist into Traktor's root library, opens Traktor in true full-screen mode, and loads Decks A, B, C, and D with the first four tracks. You are instantly ready to mix!

---

## 🎧 Overview

The **Stream of Frequency Mix Archive Manager** provides an interactive, terminal-driven control center (**77 operations** across **7 logical relational sections**) that automates the entire lifecycle of professional DJ mixes and audio recordings:

1. **Ingestion & Concatenation**: Auto-detects split multi-hour WAV recordings (e.g. 3-hour chunks from Traktor / external recorders), normalizes filenames, and concatenates them into single pristine tracks.
2. **Lossless FLAC Mastering & Acoustic Spectrograms**: Encodes to 32-bit sample depth FLAC (`-sample_fmt s32 -compression_level 12`), optimizes and embeds cover art (`scale='min(1400,iw)':-1`), and outputs high-resolution 1080p acoustic spectrograms across an expanded acoustic suite (Spek, Sonic Visualiser, SoX 24-bit multi-colormap spectrograms, Praat, Kwave, Audacity).
3. **Traktor Pro History Integration, Harmonic Playlists & Studio Setup**: Scans Traktor history XML archives (`collection.nml`), maps played tracks to exact session timestamps, generates ready-to-publish timestamped tracklists with HTML/PDF document exports, and features **macOS Native Automated Traktor Playlist Generation** that sorts history by musical key, injects playlists into Traktor root, and opens Traktor in full-screen with Decks A–D pre-loaded ready to mix.
4. **Mix Publishing Schedule & Multi-Platform Syndication**: Integrated multi-platform release calendar and syndication scheduler (`publish_calendar_scheduler.sh`) supporting Apple Podcasts, Spotify for Podcasters, YouTube, SoundCloud, Mixcloud, DI.FM, Proton Radio, Bandcamp, custom RSS feed generation (`podcast_feed.xml`), and standard iCalendar (`.ics`) exports.
5. **Promotional & Publisher Outreach Email Suite**: Dedicated outreach and pitch system for podcast publishers, syndicators, club promoters, festival bookers, radio stations, and record labels (`send_promo_email.py`). Sends rich HTML and plaintext emails with automatic episode cover art attachments, cue tracklists, and streaming links via SMTP or native desktop email clients (`mailto:` in Apple Mail, Thunderbird, Outlook).
6. **Digital Audio Workstations (DAWs) & Studio Diagnostics**: Unified launch hub and package installer for REAPER, Logic Pro (macOS), FL Studio (macOS, Windows, Linux via Wine/Bottles), Traktor Pro (macOS & Windows), GarageBand (macOS), Ardour, LMMS, Bitwig Studio, Bespoke Synth, Audacity, and MusicBrainz Picard. Includes deep **Studio Hardware & Software Inspector** (`inspect_audio_studio.sh`) mapping PipeWire, ALSA audio sinks/sources, MIDI hardware controllers (AKAI MPKmini2, Arturia MiniLab mkII, Valve), and installed studio DAWs.
7. **Audio Specification Inspector & Stream Metadata**: Comprehensive technical stream analysis (`inspect_playing_audio.sh` & `bin/view-mix-specs`) inspecting currently playing audio or archive mixes: Container/Format (`WAV`, `FLAC`), Bit Depth (`24-Bit`, `16-Bit`, `32-Bit`), Sampling Rate (`48,000 Hz / 48.0 kHz`), File Path, File Name, Duration, Size, Title, Artist, Codec, Bitrate, Compression Ratio, Drive Free Space, and Companion Assets (Covers, Tracklist, Spectrogram, Video).
8. **Active Audio Interface & Latency Display**: Real-time probe of default audio output device and hardware buffer latency (`scripts/get_audio_interface.py`) across PipeWire, ALSA, PulseAudio, macOS CoreAudio, Windows WASAPI, and FreeBSD OSS, displayed on boot and in live status.
9. **Master Audio Control & Retro Playback**: Instant live master audio mute/unmute toggle directly from the manager menu, custom `.m3u8` / `.xspf` playlist suite (`manage_playlists.sh`), live MPRIS and retro console audio player with real-time playback progress, track metadata, active filesystem paths, and instant cross-platform clipboard copy (`pbcopy` on macOS, `clip.exe` on Windows, `wl-copy`/`xclip` on Linux). Launches cliamp, Strawberry, VLC, foobar2000 (macOS & Windows), Winamp (Windows), Apple Music (macOS), Apple Podcasts (macOS), Haruna, and Kodi.
10. **Video Production & Procedural Netpbm Art**: Generates 4K UHD, 1080p Full HD, and 720p HD YouTube videos with NVENC/Hardware/VideoToolbox acceleration, 320kbps AAC, and smooth 5s audio fading (`generate_youtube_video.sh`), looping MP4-to-MP4 video production with segment fades and intro/outro thumbnail title cards (`Make_SOF_Episode_From_MP4_Audio_Output_MP4_1080p_Video.sh`), synchronized mix-video companion daemon (`sync_video_companion.sh`), procedural gradient binary Netpbm P6 `.PPM` cover art generator with mathematical palettes and typography overlays (`generate_ppm_cover.sh`), video clip cutter (`Cut_Video.sh`), and Electric Sheep screensaver.
11. **Dynamic System MOTD & Diagnostics**: Auto-updating Message Of The Day banner generator (`update_system_motd.sh`) highlighting the last 3 mixes, dates, times, sizes, formats, full file names, and audio specs. Automated rclone mirroring to Google Drive, SMB network share ingestion, multi-platform network services manager (SSH, Samba, FTP), real-time file transfer monitors, and comprehensive archive statistics.
12. **Multi-Platform System Maintenance**: OS-tailored system cleaning (Bazzite `ujust`, macOS Homebrew caches & RAM purge, Windows `winget` update & TRIM, FreeBSD `pkg` cleanup & audit), display configuration, reboot control, and live manager & system uptime tracking.
13. **Themes & CLI Engine**: 9 custom retro terminal color themes (Cyberpunk, Dracula, Nord, Matrix, Solarized, Tokyo Night, Monokai, Gruvbox, Emerald) and an integrated interactive Bash CLI runner.

---

## 🚀 Quick Start

### 1. Linux (Bazzite / SteamOS / Fedora / Ubuntu)
For a fresh, step-by-step guide from a clean Bazzite installation, see **[INSTALL_BAZZITE.md](INSTALL_BAZZITE.md)**.

```bash
cd ~/MP_Mix_Manager_v0.2
chmod +x install.sh
./install.sh
```
**Launch:**
```bash
manager
# or:
~/manager.sh
```
Or launch **Mix Archive Manager** from your application menu or desktop shortcut.

---

### 2. Apple macOS (Sonoma, Sequoia, Apple Silicon & Intel)

#### Prerequisites
Install [Homebrew](https://brew.sh) (if not already installed):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Install command-line tools:
```bash
brew install ffmpeg sox flac rclone jq btop
```

*(Optional) Install audio/video GUI tools:*
```bash
brew install --cask vlc audacity strawberry musicbrainz-picard gimp reaper foobar2000
```

#### Running on macOS
1. Run the installer to configure directory structure and desktop launcher:
   ```bash
   cd ~/MP_Mix_Manager_v0.2
   chmod +x install.sh
   ./install.sh
   ```
2. **Double-click** `~/Desktop/Mix Archive Manager.command` in Finder, or execute:
   ```bash
   ./manager_macos.command
   # or:
   ./Mix_Archive_Manager.sh
   ```
3. **One-Click Traktor Prep:** Press **`33`** on the main menu (or **`21`** ➔ **`12`** under the DAWs menu) to convert any past session into an ascending musical key playlist, inject it into Traktor, and auto-load all 4 decks ready to mix!

---

### 3. Microsoft Windows 10 & 11

#### Prerequisites
Mix Archive Manager runs natively on Windows using **Git Bash** or **WSL2**:
- **Git for Windows (Recommended)**: Download from [https://git-scm.com/download/win](https://git-scm.com/download/win).
- **Windows Terminal**: Built-in on Windows 11; available via Microsoft Store on Windows 10.

Install recommended utilities using `winget` in PowerShell / Windows Terminal:
```powershell
winget install Gyan.FFmpeg Rclone.Rclone jqlang.jq
winget install VideoLAN.VLC Audacity.Audacity MusicBrainz.Picard GIMP.GIMP Cockos.REAPER foobar2000.foobar2000
```

#### Running on Windows
- **Double-click** `manager.bat` or `manager.ps1` from Windows File Explorer.
- Or run inside Git Bash:
  ```bash
  ./Mix_Archive_Manager.sh
  ```

---

### 4. FreeBSD (14.x / 15-CURRENT)

#### Prerequisites
Install dependencies using `pkg`:
```bash
pkg install -y bash python3 ffmpeg sox flac rclone jq btop git py311-mutagen py311-reportlab py311-pillow
```

*(Optional) Install audio/video GUI tools:*
```bash
pkg install -y audacity vlc strawberry-music-player gimp reaper
```

#### Running on FreeBSD
```bash
cd ~/MP_Mix_Manager_v0.2
chmod +x manager_freebsd.sh install.sh
./manager_freebsd.sh
# or:
./Mix_Archive_Manager.sh
```

---

## 📂 Repository & Codebase Layout

```
MP_Mix_Manager_v0.2/
├── Mix_Archive_Manager.sh       # Authoritative master interactive console (71 operations)
├── manager.sh                   # Linux bash wrapper
├── manager_macos.command        # macOS double-clickable Finder launcher
├── manager_freebsd.sh           # FreeBSD shell launcher
├── manager.bat                  # Windows native Command Prompt / Batch launcher
├── manager.ps1                  # Windows PowerShell launcher
├── publish_calendar_scheduler.py# Mix publishing calendar & syndication schedule engine
├── publish_calendar_scheduler.sh# Mix publishing calendar shell launcher
├── inspect_audio_studio.py      # Studio hardware (PipeWire/ALSA/MIDI) & DAW diagnostic inspector
├── inspect_audio_studio.sh      # Studio inspector shell launcher
├── generate_ppm_cover.py        # Procedural Netpbm P6 binary PPM cover art generator
├── generate_ppm_cover.sh        # Procedural PPM generator shell launcher
├── sync_video_companion.py      # Synchronized mix-video companion playback daemon
├── sync_video_companion.sh      # Mix-video companion shell launcher
├── manage_playlists.py          # Custom playlist suite (.m3u8 / .xspf creator & launcher)
├── manage_playlists.sh          # Custom playlist shell launcher
├── manage_motd.py               # Dynamic System MOTD generator (Recent 3 mixes & full file names)
├── update_system_motd.sh        # System MOTD update shell launcher
├── generate_spek.sh             # Dedicated CLI/GUI acoustic spectrogram suite (Spek, SoX, Praat, Sonic Visualiser)
├── send_promo_email.py          # Promotional & publisher outreach email system
├── search_and_import_mixes.py   # Universal mix search & importer (Local Drives & SMB)
├── search_and_import_mixes.sh   # Universal mix search shell launcher
├── manage_installation_config.sh# Installation migration & configuration backup/export/import suite
├── install.sh                   # Cross-platform automated environment installer
├── manage_checksums.sh          # SHA-256 audio archive integrity manifest & verification
├── Check_Find_Tracklists.sh     # Traktor Pro history XML parser & tracklist generator
├── MOVE_NOT_CONVERTED_WAVS.sh   # Unconverted WAV retrieval engine
├── SOF_Live_Tracker.sh          # Live tracklist monitor (Strawberry / cliamp)
├── SOF_Archive_Stats.sh         # Archive statistics and duration accumulator
├── backup_to_gdrive.sh          # Rclone Google Drive backup
├── Verify_FLAC_Files.sh         # Multi-threaded FLAC bitstream corruption scanner
├── import_new_mixes.sh          # Automated SMB network mix ingest
├── import_new_mixes.py          # Network archive deduplicator
├── Generate_Master_Tracklist.sh # Master HTML index generator
├── generate_master_tracklist.py # HTML generator logic
├── generate_tracklist_docs.py   # Styled HTML & printable vector PDF tracklist exporter
├── generate_youtube_video.sh    # Hardware-accelerated 4K/1080p/720p YouTube video creator
├── Cut_Video.sh                 # Start/End timestamp video cutter
├── Get_All_Drive_Space.sh       # Comprehensive system-wide drive space reporter
├── play_defasten_4screens.sh    # Multi-monitor 4-screen Defasten video launcher
├── switch-to-plasma-wayland.sh  # Desktop session switcher to Plasma Wayland
├── switch-to-plasma-x11.sh      # Desktop session switcher to Plasma X11
├── close_allapps.sh             # Graceful desktop application closer
├── clear-wan2gp-logs.sh         # WAN2GP AI server log cleaner
├── install.sh                   # Cross-platform installer & environment setup
├── config.env                   # User configuration overrides
├── config.env.example           # Configuration template
├── README.md                    # System documentation and feature matrix
└── CHANGELOG.md                 # Version release history and audit log
│
├── bin/                         # Compiled binaries & CLI helpers (symlinked to ~/.local/bin)
│   ├── cliamp                   # Custom retro terminal music player (v2.0.1)
│   ├── mix-archive-manager      # Desktop / background launch wrapper
│   ├── launch-manager-fullscreen# Dedicated full-screen terminal wrapper
│   ├── traktor-monitor          # Traktor Pro Live Monitor & Audio Recorder CLI
│   ├── view-mix-specs           # Dedicated audio specification & stream inspector CLI
│   ├── view-tracklist           # Borderless console tracklist viewer
│   ├── split-flac               # Interactive lossless FLAC splitter CLI
│   ├── split-video              # Interactive YouTube MP4 video splitter CLI
│   ├── beszel                   # Beszel server monitoring hub & agent controller CLI
│   ├── manage-ollama            # Ollama server controller & local model manager CLI
│   ├── dsh-mobile               # DeepSeek Harness mobile web server CLI
│   ├── manage-dsh-mobile        # DeepSeek Harness controller & manager CLI
│   ├── transfer-monitor         # Live file write and transfer inspector
│   ├── chrome-upload-monitor    # Real-time web / Podcast Connect upload monitor
│   ├── update-nft-playlist      # M3U / XSPF video playlist builder
│   ├── watch-nft-copy-and-update.sh # Background file write watcher
│   ├── list-midi-devices        # USB MIDI hardware inspector
│   ├── block-internet           # Isolated LAN-only firewall toggle
│   └── unblock-internet         # Firewall restore toggle
│
├── scripts/                     # Modular sub-operation scripts
│   ├── get_audio_interface.py   # Active default sound output device & latency calculator
│   ├── inspect_playing_audio.py # Advanced audio specification & stream properties inspector
│   ├── inspect_playing_audio.sh # Audio specification inspector launcher
│   ├── align_mix_windows.py     # Cross-platform window alignment (KWin DBus / X11 / macOS)
│   ├── get_weather.sh           # Meteorological weather fetcher & cache manager
│   ├── launch_specific_video.sh # Dedicated video launcher & dispatcher (VLC / mpv / Haruna)
│   ├── shop_music.sh            # Music store browser tab quick-launcher (Beatport / Apple / Bandcamp)
│   ├── publish_calendar_scheduler.py# Mix publishing calendar & syndication schedule engine
│   ├── publish_calendar_scheduler.sh# Mix publishing calendar shell launcher
│   ├── inspect_audio_studio.py  # Studio hardware & software inspector
│   ├── inspect_audio_studio.sh  # Studio inspector launcher
│   ├── generate_ppm_cover.py    # Netpbm P6 PPM procedural gradient art generator
│   ├── generate_ppm_cover.sh    # PPM generator launcher
│   ├── sync_video_companion.py  # Synchronized video playback companion daemon
│   ├── sync_video_companion.sh  # Video companion launcher
│   ├── manage_playlists.py      # Custom playlist creator & dispatcher
│   ├── manage_playlists.sh      # Playlist launcher
│   ├── manage_motd.py           # Dynamic system MOTD generator
│   ├── update_system_motd.sh    # System MOTD launcher
│   ├── Make_SOF_FLAC_CONVERSION.sh  # 32-bit FLAC conversion & spectrogram generation
│   ├── generate_spek.sh         # Acoustic spectrogram generation engine
│   ├── send_promo_email.py      # Promotional & publisher outreach email system
│   ├── search_and_import_mixes.py # Universal mix search & importer (Local Drives & SMB)
│   ├── search_and_import_mixes.sh # Universal mix search shell launcher
│   ├── manage_installation_config.sh# Installation migration & configuration management
│   ├── update_manager.sh        # System updater & version checker (mix-archive-manager update)
│   ├── Check_Find_Tracklists.sh # Traktor Pro history XML parser
│   ├── generate_traktor_playlist_from_history.py # Traktor Pro history parser, harmonic key sorter & 4-deck full-screen stage loader (macOS)
│   ├── generate_traktor_playlist_from_history.sh # Traktor history playlist generator shell launcher
│   ├── schedule_mix_playback.py # DJ mix & playlist playback scheduler (date/time in future)
│   ├── schedule_mix_playback.sh # Mix playback scheduler shell launcher
│   ├── MOVE_NOT_CONVERTED_WAVS.sh # Unconverted WAV retrieval engine
│   ├── SOF_Live_Tracker.sh      # Live tracklist monitor (Strawberry / cliamp)
│   ├── SOF_Archive_Stats.sh     # Archive statistics and duration accumulator
│   ├── backup_to_gdrive.sh      # Rclone Google Drive backup
│   ├── Verify_FLAC_Files.sh     # Multi-threaded FLAC bitstream corruption scanner
│   ├── import_new_mixes.sh      # Automated SMB network mix ingest
│   ├── import_new_mixes.py      # Network archive deduplicator
│   ├── Generate_Master_Tracklist.sh # Master HTML index generator
│   ├── generate_master_tracklist.py # HTML generator logic
│   ├── Make_SOF_Episode_From_PNG_FLAC_Output_MP4_1080p_Video.sh # 1080p YouTube video creator
│   ├── Make_SOF_Episode_From_PNG_FLAC_Output_MP4_4K_Video.sh     # 4K NVENC YouTube video creator
│   ├── Make_SOF_Episode_From_PNG_FLAC_Output_MP4_720p_Video.sh  # 720p YouTube video creator
│   ├── generate_youtube_video.sh# Unified YouTube video generation engine
│   ├── Cut_Video.sh             # Precision start/end video cutter
│   ├── Split_FLAC_File.sh       # Sample-accurate lossless FLAC audio splitter
│   ├── Split_Video_File.sh      # Precision YouTube MP4 video splitter (lossless / re-encode)
│   ├── merge_playlist_flac.sh   # Concat M3U playlist to FLAC
│   ├── process_trance_roots.py  # Audio processing helper
│   ├── switch-to-plasma-wayland.sh # Plasma Wayland HDR display switcher
│   ├── switch-to-plasma-x11.sh  # Plasma X11 session switcher
│   ├── play_defasten_4screens.sh# Multi-screen video display orchestrator
│   ├── close_allapps.sh         # Window manager cleaner (protects active manager)
│   ├── wan2gp.sh                # WAN2GP AI Video server runner
│   ├── beszel.sh                # Beszel server monitoring hub & hardware agent runner
│   ├── manage_ollama.sh         # Ollama server (distrobox) controller, status & model chat runner
│   ├── dsh_mobile.sh            # DeepSeek Harness (dsh-mobile) web server & mobile access manager
│   ├── wan2gp_flux_batch.py     # Flux Klein 9B batch generation
│   ├── wan2gp_ltx_batch.py      # LTX Video 2B/13B batch generation
│   ├── clear-wan2gp-logs.sh     # AI generation log pruner
│   └── remove_duplicate_images.py # Byte-for-byte duplicate image remover
│
├── desktop/
│   └── Mix_Archive_Manager.desktop # FreeDesktop Application Entry
│
└── assets/
    ├── Cover.png                # Default cover art template
    ├── promo_contacts.json      # Outreach contacts book (promoters, publishers, labels)
    ├── promo_logs/              # Sent email history & delivery logs
    ├── publishing_calendar.json # Mix publishing schedule & platform targets
    ├── mix_publishing_calendar.ics # Standard iCalendar calendar export
    └── scaffolds/               # Working directories (.gitkeep)
        ├── FLAC_CONVERTED_OUTPUTS/  # Master FLAC outputs & text tracklists
        ├── CONVERTED_WAV_FILES/ # Archived source WAV files
        ├── SPEK_OUTPUTS/        # Generated audio spectrograms
        ├── BACKUP_LOGS/         # Cloud backup reports
        ├── VERIFY_LOGS/         # FLAC integrity test reports
        ├── IMPORT_LOGS/         # SMB import reports
        ├── config_backups/      # Local timestamped configuration snapshots
        ├── exported_configs/    # Portable exported configuration bundles (.tar.gz)
        └── COVERS/              # Episode and album artwork library
```

---

## 🎛️ Feature Matrix (77 Core Operations in 7 Logical Sections)

### ─── [ SECTION 1: MIX ARCHIVE WORKFLOW & INGESTION ] ──────────
| # | Operation | Description |
|---|---|---|
| **1** | **Run FLAC Conversion Process** | Batch concatenates split WAVs, encodes to 32-bit FLAC (`Make_SOF_FLAC_CONVERSION.sh`), embeds artwork, and outputs spectrograms. |
| **2** | **Convert Audio Formats, Bit Depths & Split FLACs** | Converts audio between MP3 (320k, V0, 256k), Ogg Vorbis, Opus, Apple AAC, Apple ALAC lossless, FLAC, and WAV-to-WAV bit depths (32-bit float, 32-bit int, 24-bit PCM, 16-bit PCM). Includes sample-accurate lossless FLAC file splitting into equal parts (`Split_FLAC_File.sh` / `--split-flac`). |
| **3** | **Retrieve Unconverted WAVs** | Scans archive and quarantines/moves WAVs lacking a corresponding FLAC back to staging (`MOVE_NOT_CONVERTED_WAVS.sh`). |
| **4** | **Search & Import Mixes (Local Drives & SMB)** | Auto-discovers local storage volumes, USB drives, common music directories, and SMB shares. Scans and filters by mix size (>=100MB) and audio extensions, checks for duplicates against the archive, and executes transfers with live progress and audit logs (`search_and_import_mixes.sh` / `import_new_mixes.sh`). |
| **5** | **Rename Mix and Associated Assets** | Atomically renames FLAC file, `.txt` tracklist, and Spek `.png` across all archive subdirectories. |
| **6** | **Find & Remove Duplicate Audio Files** | Fast chunk-content hashing & episode duplicate detector; supports safe reporting, quarantine to `DUPLICATES_QUARANTINE/`, or permanent deletion (`find_duplicate_mixes.py`). |
| **7** | **Export / Copy Mixes to Specified Path** | Copies complete mix packages (FLAC + Covers + Tracklists TXT/HTML/PDF + Spek) or filtered assets to USB drives or external paths. |
| **8** | **Manage Audio Integrity Checksums** | Generates and verifies SHA-256 integrity manifests (`checksums.sha256`) to ensure mixes are never corrupted or damaged (`manage_checksums.sh`). |
| **9** | **Verify FLAC Files for Integrity** | Multi-threaded decode pass across CPU cores; isolates corrupt FLAC bitstreams to quarantine (`Verify_FLAC_Files.sh`). |
| **10**| **Back up FLAC Outputs to Google Drive** | Automated `rclone` sync to cloud storage with bandwidth throttle and timestamped logging (`backup_to_gdrive.sh`). |
| **11**| **Show Mix Storage Drive Space Remaining** | Displays detailed filesystem capacity, mount point, free space progress bar, and hosted audio file counts for **only the mix storage disk**. |
| **12**| **Refresh Archive Status & File Counts** | Clears cache and performs a full recount of pending WAVs, converted WAVs, FLACs, and missing tracklists. |
| **13**| **Configure Default Mix Archive Storage Folder** | Configures user's primary mix storage path override (defaults to `/run/media/$USER/WD BLACK B/MIX_ARCHIVE/` or root `MIX_ARCHIVE/`). Displays warning on boot if unconfigured. |

### ─── [ SECTION 2: TRACKLIST, METADATA & PROMOTION ] ──────────
| # | Operation | Description |
|---|---|---|
| **14**| **Tracklist Management Suite** | Complete metadata suite: browse all archive tracklists, keyword search, view active tracklist, and export to styled HTML and printable vector PDF (`generate_tracklist_docs.py`). |
| **15**| **Search for Mix & Auto-Play with Live Tracklist View** | Searches mix catalog, automatically queues and starts playback in `cliamp` (in a separate console window), then returns to manager and loads the live tracklist (skipped if playback doesn't start). |
| **16**| **Scan & Generate Missing Tracklists** | Extracts Traktor Pro history XML logs to generate matching timestamped `.txt` tracklists (`Check_Find_Tracklists.sh`). |
| **17**| **Generate Master Tracklist HTML Index** | Compiles all individual mix tracklists into a single, searchable HTML reference index (`Generate_Master_Tracklist.sh`). |
| **18**| **Launch MusicBrainz Picard Meta Tag Editor** | Opens Picard audio tagger (auto-installs on system if missing). |
| **19**| **Promotional & Publisher Outreach Emails** | Professional email pitch and enquiry suite (`send_promo_email.py`). Sends tailored HTML and Plaintext outreach to podcast publishers (Apple Podcasts, DI.FM, Proton), club/festival promoters, radio syndicators, record labels, and dance music media. Auto-attaches episode cover artwork, cue tracklists, and streaming links via direct SMTP or desktop email clients (`mailto:`). Includes address book and delivery logging. |
| **20**| **Mix Publishing Schedule & Multi-Platform Syndication** | Release calendar and syndication scheduler (`publish_calendar_scheduler.sh`). Manages release dates, platforms (Apple Podcasts, Spotify, YouTube, SoundCloud, Mixcloud, DI.FM, Proton Radio, Bandcamp), custom RSS feed publishing (`podcast_feed.xml`), and standard iCalendar (`.ics`) export. |
| **21**| **Go Shopping for New Music** | Quick-launches curated music store browser tabs in parallel for **Beatport**, **Apple Music**, and **Bandcamp** (`shop_music.sh`). |

### ─── [ SECTION 3: AUDIO PLAYBACK, DAWS & SOUND SUITE ] ────────
| # | Operation | Description |
|---|---|---|
| **22**| **Digital Audio Workstations (DAWs) Menu** | Unified launch hub and package installer for REAPER, Logic Pro (macOS), FL Studio (macOS, Windows, Linux), Traktor Pro (macOS & Windows), GarageBand (macOS), Ardour, LMMS, Bitwig Studio, and Bespoke Synth. On macOS, includes **Option 12: Generate Playlist from Traktor History Files & 4-Deck Setup**. |
| **23**| **Open Mix WAV/FLAC Audio File in DAW** | Direct dispatch: prompts user to search by episode/keyword or select from archive mixes, then automatically opens the mix audio file in REAPER, Logic Pro, GarageBand, FL Studio, Audacity, Ardour, or Bitwig. |
| **24**| **Generate Spectrograms using Spek & Analysis Suite** | In-place acoustic spectrogram generator (`generate_spek.sh`): single-file interactive generation with instant preview viewer prompt, and batch directory processing for WAV, MP3, and FLAC files. Includes Sonic Visualiser, SoX 24-bit multi-colormap spectrograms, Praat, and Audacity analysis. |
| **25**| **Launch Audacity Audio Editor** | Launches Audacity audio editor or installs via Homebrew / winget / Flatpak / native packages. |
| **26**| **Launch Audio Players Menu** | Quick launch hub for cliamp, Strawberry, VLC, foobar2000 (macOS & Windows), Winamp (Windows), Apple Music (macOS), Haruna, and Kodi. |
| **27**| **Configure Default Audio Player & Startup Autoplay** | User preferences suite: choose default audio player (cliamp, Strawberry, VLC, foobar2000, Winamp, Apple Music, Haruna, Kodi, Audacity, custom), default video player (VLC, mpv, Haruna, Kodi), toggle startup mix autoplay, toggle startup YouTube autoplay (only when mix audio plays), configure live weather banner location, toggle auto-opening cover art, toggle auto-displaying tracklists in borderless console, and configure tracklist viewer preference (`TRACKLIST_VIEWER`). |
| **28**| **cliamp Music Player & Track Control** | Built-in retro terminal player: now-playing path display, cross-platform clipboard copy, folder open, and playback controls. |
| **29**| **View Playing Mix Audio Specifications & Stream Metadata** | Inspects currently playing mix (or selected archive mix) and displays deep technical audio stream specifications: Container/Format (`WAV`, `FLAC`), Bit Depth (`24-Bit`, `16-Bit`, `32-Bit`), Sampling Rate (`48,000 Hz / 48.0 kHz`), File Path, File Name, Duration, Size, Title, Artist, Codec, Bitrate, Compression Ratio, and Companion Assets (`inspect_playing_audio.sh`). |
| **30**| **Custom Mix Playlists Suite (.m3u8 / .xspf)** | Comprehensive archive playlist manager (`manage_playlists.sh`): build custom playlists from archive mixes, search and add tracks, reorder, export `.m3u8` / `.xspf`, and dispatch to `cliamp`, `strawberry`, `vlc`, or `mpv`. |
| **31**| **Launch Strawberry Music Player** | Opens Strawberry Music Player in a separate desktop window. |
| **32**| **Launch VLC Media Player** | Launches VLC audio/video media player. |
| **33**| **Generate Playlist from Traktor History (macOS Native)** / **Haruna (Linux)** | **macOS Native Spotlight Feature:** Scans Traktor Pro 3/4 history files, displays session tracklists in console, sorts tracks in Key Field Ascending order (1A–12B), injects playlist into Traktor root collection (`$ROOT`), and launches Traktor in full screen with Decks A, B, C, & D pre-loaded ready to mix! On Linux: launches Haruna (`org.kde.haruna`). |
| **34**| **Launch Kodi Entertainment Center** | Launches Kodi Media Center. |
| **35**| **Show Connected USB MIDI Devices** | Inspects connected synthesizers, DJ controllers, and keyboards (`list-midi-devices`). |
| **36**| **Studio Hardware & Software Inspector** | Deep audio diagnostic inspector (`inspect_audio_studio.sh`): surveys active PipeWire / PulseAudio / ALSA soundcards, sinks, sample rates, latencies, connected MIDI controllers & control surfaces (AKAI MPKmini2, Arturia MiniLab mkII, Valve), and installed studio DAWs. |
| **37**| **Toggle Audio Mute / Unmute & Master Volume Control** | Instant live audio mute toggle via PipeWire (`wpctl`), PulseAudio (`pactl`), ALSA, or macOS AppleScript without leaving the manager. |
| **38**| **Schedule DJ Mix or Multiple DJ Mixes to Play Loudly** | Mix playback scheduler (`scripts/schedule_mix_playback.py`): schedules single audio files (WAV/MP3/FLAC), custom M3U playlists, or selection from the last 10 recorded mixes to play at any exact date and time in the future using the user's default audio player. |

### ─── [ SECTION 4: VIDEO PRODUCTION, ART & VISUAL MEDIA ] ──────
| # | Operation | Description |
|---|---|---|
| **39**| **Generate YouTube Video (4K UHD, 1080p, 720p)** | Encodes pristine YouTube MP4 videos in 4K UHD (3840x2160), 1080p Full HD (1920x1080), or 720p HD (1280x720) with NVENC/Hardware acceleration, 320kbps AAC audio, and smooth 5s audio fading (`generate_youtube_video.sh`). |
| **40**| **Cut or Split Video File (.mp4 / .mkv)** | Precision video editing and splitting suite: cut video clips by start/end timestamps (`Cut_Video.sh`) or split YouTube .mp4 video files into equal parts with lossless stream copy or frame-accurate re-encode (`Split_Video_File.sh` / `--split-video`). |
| **41**| **Launch Video Playlists** | Plays Defasten or NFT video playlists in VLC, or regenerates `.m3u`/`.xspf` files. |
| **42**| **Launch Specific Video in Default Video Player** | Launches specific video files or streaming URLs in user's default video player (VLC default, mpv, Haruna, Kodi) (`launch_specific_video.sh`). |
| **43**| **Launch GIMP Image Editor** | Launches GIMP image editor or installs via package manager. |
| **44**| **Convert Cover Art & Resize / Byte Target** | Converts covers between JPEG, WebP, PNG, and TIFF with preset resolutions (3000x3000, 1400x1400, 1080x1080) and binary-search byte targeting (e.g. strict <= 1MB podcast standard). |
| **45**| **View Cover Art by Mix Number** | Searches `COVERS/` directory by episode or mix number and opens in system image viewer. |
| **46**| **Procedural Gradient .PPM Cover Art Generator** | Pure mathematical Netpbm P6 binary `.PPM` cover art generator (`generate_ppm_cover.sh`): renders linear, radial, plasma, and angular gradients, composites typography overlays (Artist, Title, Episode, Tags), and exports high-res lossless PNGs. |
| **47**| **Launch Electric Sheep Screensaver** | Launches Electric Sheep generative screensaver. |
| **48**| **Synchronized Mix-Video Companion Player Daemon** | Intelligent background watcher (`sync_video_companion.sh`): automatically discovers matching companion video for the currently playing mix and launches it in VLC / Haruna / MPV, closing the player when audio stops. |

### ─── [ SECTION 5: LIVE MONITORS & SYSTEM DIAGNOSTICS ] ────────
| # | Operation | Description |
|---|---|---|
| **49**| **Launch Live Tracklist Monitor** | Real-time CLI display connecting to Strawberry MPRIS and `cliamp` with live progress and track info (`SOF_Live_Tracker.sh`). |
| **50**| **Launch Traktor Live Monitor & Audio Recorder** | Cross-platform live terminal dashboard (`scripts/traktor_monitor.py` / `traktor_monitor.sh`): monitors Traktor CPU %, RSS RAM, deck playback/loaded tracks, active WAV recording locks, real-time file size growth, and audio interface hardware. Features direct recording controls (start, stop, toggle) via AppleScript and Windows Automation. |
| **51**| **Launch Live File Transfer Monitor** | Inspects transfer speeds, byte positions, and percentage for huge files (`transfer-monitor`). |
| **52**| **Launch Chrome Upload Monitor** | Monitors web uploads (e.g. Apple Podcasts Connect, YouTube Studio) in real-time (`chrome_upload_monitor.py`). |
| **53**| **View Advanced Archive Statistics** | Deep inventory scan calculating total duration, file sizes, GB footprint, and tracklist completeness (`SOF_Archive_Stats.sh`). |
| **54**| **View Running Background Tasks** | Scans process table for active encoding, syncing, or AI batch jobs. |
| **55**| **Launch Resource Monitor** | Launches `btop` for deep multi-core CPU and memory profiling. |
| **56**| **Launch GPU Process Monitor** | Launches `nvtop` for real-time monitoring of NVIDIA GPU clock, VRAM, and power draw. |
| **57**| **Launch System Process Monitor** | Quick-launches `top` inside manager session. |

### ─── [ SECTION 6: SYSTEM, NETWORK & HARDWARE MANAGEMENT ] ─────
| # | Operation | Description |
|---|---|---|
| **58**| **Manage WAN2GP Server** | Controls WAN2GP AI video server (Profile 2 / 4.5, Flux Klein 9B batch, LTX Video 2B/13B). Accessible via KDE Connect shortcuts, desktop entries, and CLI (`--wan2gp-start-4.5` / `--wan2gp-stop` / `58 2` / `58 3`). |
| **59**| **Manage Beszel Monitoring Suite** | Controls Beszel server monitoring hub (Web Dashboard on port 8090) and hardware/NVIDIA GPU/Podman agent. Supports starting Hub, Agent, or both, live status, logs, browser dashboard dispatch, and CLI (`--beszel-start` / `--beszel-hub` / `--beszel-agent` / `--beszel-stop` / `59 1` / `59 2` / `59 3`). |
| **60**| **Manage Ollama Server** | Controls Ollama LLM server (`ollama serve` inside distrobox container `ollama-container` on port 11434). Supports background daemon mode, interactive terminal window mode (live logs), server stop/restart, hardware acceleration status (NVIDIA RTX CUDA), local models listing (`qwen2.5`, `llama3.1`, `nemotron`, etc.), and interactive CLI chat. Accessible via CLI (`--ollama-serve`, `--ollama-start`, `--ollama-stop`, `--ollama-status`, `60 1`, `60 2`, `60 3`, `60 4`, `60 5`, `60 6`). |
| **61**| **Manage DeepSeek Harness Server (`dsh-mobile`)** | Controls DeepSeek Harness web server (`pnpm dsh web` with `--trusted-host 192.168.1.11:3080 --trusted-host 192.168.1.11 --no-open` on port 3080). Supports launching in a dedicated terminal window or background daemon, one-click browser opening (`http://192.168.1.11:3080`), server stop/restart, process inspection, and live server logs (`/tmp/dsh-mobile.log`). Accessible via CLI (`--dsh-mobile`, `--dsh`, `--dsh-start`, `--dsh-bg`, `--dsh-web`, `--dsh-stop`, `--dsh-status`, `61 1`, `61 2`, `61 3`, `61 4`, `61 5`, `61 6`). |
| **62**| **Manage Network Services** | Bulk and individual start, stop, restart, and status for SSH (`sshd`), Samba (`smb`), and FTP (`vsftpd`) across Linux (`systemctl`), FreeBSD (`service`), macOS (`launchctl`/`systemsetup`), and Windows (PowerShell). |
| **63**| **Block Internet Access (LAN Only)** | Activates an isolated firewall table blocking WAN while keeping LAN open (`block-internet`). |
| **64**| **Restore / Unblock Internet Access** | Restores immediate full internet connectivity (`unblock-internet`). |
| **65**| **Display Settings (OS Tailored)** | Opens Plasma Wayland on Linux, macOS Display Settings, or Windows Display Settings (`ms-settings:display`). |
| **66**| **Audio / Sound Settings (OS Tailored)** | Opens Plasma X11 on Linux, Audio MIDI Setup on macOS, or Windows Sound Panel (`control.exe mmsys.cpl`). |
| **67**| **Close All Desktop Applications** | Gracefully closes external desktop windows using AppleScript (macOS), PowerShell (Windows), or `wmctrl` (Linux) while shielding the manager. |
| **68**| **System Maintenance & Cleanup** | Executes platform maintenance (Linux `ujust clean-system`, macOS `brew cleanup` & RAM purge, Windows `winget upgrade` & temp cleanup, FreeBSD `pkg clean`, `pkg upgrade`, `pkg autoremove`). |
| **69**| **Launch GeeXLab Demo Launcher** | Runs 3D/OpenGL shader demos and GPU stress tests via GeeXLab/FurMark. |
| **70**| **Burn ISO Image to USB Drive** | Writes bootable ISO files directly to removable USB storage with safety checks and dd progress (macOS `diskutil` / Linux `lsblk`). |
| **71**| **Dynamic System MOTD Banner Manager** | Dynamic Message Of The Day generator (`update_system_motd.sh`): renders stylized ANSI MOTD table summarizing the last 3 created mixes, dates, times, sizes, formats, and full file names. |

### ─── [ SECTION 7: AI, SHELL CLI & SETTINGS ] ───────────────────
| # | Operation | Description |
|---|---|---|
| **72**| **Launch AI Assistant / Models (AGY)** | Starts Antigravity CLI AI sessions (Claude Sonnet, Claude Opus, GPT-OSS, Gemini), manages local Ollama models, or launches DeepSeek Harness (`dsh-mobile`). |
| **73**| **Run Bash CLI Commands** | Built-in interactive Bash shell and direct command execution runner. |
| **74**| **Manager Themes & Color Palette Switcher** | Switch between 9 terminal themes (Cyberpunk, Dracula, Nord, Matrix, Solarized, Tokyo Night, Monokai, Gruvbox, Emerald, Classic). |
| **75**| **Manage Installation & Configuration** | Comprehensive installation migration wizard (relocates codebase path and auto-repoints all CLI wrappers and desktop entries), instant timestamped config backups, portable `.tar.gz` config bundle export, safe bundle import, rollback/restore of historical snapshots, and automated system update (`mix-archive-manager update` / `update_manager.sh`). |
| **76**| **Reboot System** | Cross-platform system reboot with safety confirmation dialog (`systemctl reboot`, macOS `osascript`, Windows `shutdown.exe /r`, FreeBSD `shutdown -r now`). |
| **77**| **Exit Manager** | Cleans up and exits the console session. |

---

## ⚙️ Configuration (`config.env`)

Mix Archive Manager automatically loads `config.env` from the codebase directory or `~/.config/mix-manager/config.env`.

```bash
# Target storage path for music and mix archives
# Auto-detected across platforms:
#   Linux:   /run/media/$USER/WD BLACK B/MIX_ARCHIVE
#   macOS:   /Volumes/WD BLACK B/MIX_ARCHIVE
#   Windows: D:/MIX_ARCHIVE
MIX_ARCHIVE_DIR="/run/media/$USER/WD BLACK B/MIX_ARCHIVE"

# Traktor History folder containing session collection.nml files
TRAKTOR_HISTORY_DIR="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/Traktor 3.11.1/History"

# Rclone remote endpoint for offsite cloud backup
GDRIVE_REMOTE="gdrive:MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"

# Promotional & Publisher Outreach Settings
PROMO_SENDER_NAME="MPlanetarian"
PROMO_SENDER_EMAIL="mplanetarian@example.com"
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="mplanetarian@example.com"
SMTP_USE_TLS="true"
PROMO_PODCAST_URL="https://podcasts.apple.com"
PROMO_SOUNDCLOUD_URL="https://soundcloud.com/mplanetarian"
PROMO_YOUTUBE_URL="https://youtube.com/@mplanetarian"
PROMO_WEBSITE_URL="https://mplanetarian.com"

# Video Player & Startup Custom YouTube Video Settings
DEFAULT_VIDEO_PLAYER="vlc"
AUTO_PLAY_YOUTUBE_ON_STARTUP="false"
STARTUP_YOUTUBE_URL=""

# Meteorological & Planetary Ephemeris Settings (Banner Display)
WEATHER_ENABLED="true"
WEATHER_LOCATION="Swansea, UK"
PLANETS_ENABLED="true"
```

---

## 📜 License

Licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

