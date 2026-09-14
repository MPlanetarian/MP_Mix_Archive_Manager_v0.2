# Mix Archive Manager (`MP_Mix_Manager_v0.1`)

[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20FreeBSD-blue.svg)](README.md)
[![macOS](https://img.shields.io/badge/macOS-Sonoma%20%7C%20Sequoia%20%7C%20Apple%20Silicon%20%26%20Intel-silver.svg)]()
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011%20%7C%20Git%20Bash%20%7C%20WSL2-0078D6.svg)]()
[![FreeBSD](https://img.shields.io/badge/FreeBSD-14.x%20%7C%2015--CURRENT%20%7C%20Ports%20%26%20Pkg-red.svg)]()
[![Shell](https://img.shields.io/badge/Language-Bash%20%7C%20Python%20%7C%20PowerShell-orange.svg)]()
[![Audio](https://img.shields.io/badge/Audio-32bit%20Lossless%20FLAC-green.svg)]()
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

An enterprise-grade workstation orchestration console and media management suite designed for high-resolution audio production, multi-hour DJ mix archiving, automated FLAC mastering, Traktor Pro playlist extraction, live tracklist tracking, YouTube video synthesis, system maintenance, and AI workflow control across **Linux (Bazzite / SteamOS / Fedora / Ubuntu)**, **macOS (Latest Sequoia / Sonoma, Apple Silicon M1-M4 & Intel)**, **Microsoft Windows 10 & 11**, and **FreeBSD (14.x / 15-CURRENT)**.

---

## 🎧 Overview

The **Stream of Frequency Mix Archive Manager** provides an interactive, terminal-driven control center (**60 operations** across **7 logical relational sections**) that automates the entire lifecycle of professional DJ mixes and audio recordings:

1. **Ingestion & Concatenation**: Auto-detects split multi-hour WAV recordings (e.g. 3-hour chunks from Traktor / external recorders), normalizes filenames, and concatenates them into single pristine tracks.
2. **Lossless FLAC Mastering & Acoustic Spectrograms**: Encodes to 32-bit sample depth FLAC (`-sample_fmt s32 -compression_level 12`), optimizes and embeds cover art (`scale='min(1400,iw)':-1`), and outputs high-resolution 1080p acoustic spectrograms (`generate_spek.sh` / `SPEK_OUTPUTS`).
3. **Traktor Pro History Integration**: Scans Traktor history XML archives (`collection.nml`), maps played tracks to exact session timestamps, and generates ready-to-publish timestamped tracklists.
4. **Digital Audio Workstations (DAWs) & Audio Editors**: Unified launch hub and package installer for REAPER, Logic Pro (macOS), FL Studio (macOS, Windows, Linux via Wine/Bottles), Traktor Pro (macOS & Windows), GarageBand (macOS), Ardour, LMMS, Bitwig Studio, Bespoke Synth, Audacity, and MusicBrainz Picard. Includes direct **"Open Mix Audio File in DAW"** with keyword search and catalog selection.
5. **Playback Suite & cliamp Retro Player**: Live MPRIS and retro console audio player with real-time playback progress, track metadata, active filesystem paths, and instant cross-platform clipboard copy (`pbcopy` on macOS, `clip.exe` on Windows, `wl-copy`/`xclip` on Linux). Launches cliamp, Strawberry, VLC, foobar2000 (macOS & Windows), Winamp (Windows), Apple Music (macOS), Apple Podcasts (macOS), Haruna, and Kodi.
6. **Video Production & Generative Art**: Generates 4K UHD, 1080p Full HD, and 720p HD YouTube videos with NVENC/Hardware acceleration, 320kbps AAC, and smooth 5s audio fading (`generate_youtube_video.sh`), video clip cutter (`Cut_Video.sh`), VLC playback, GIMP image editing, and Electric Sheep generative screensaver.
7. **Cloud, Network & Diagnostics**: Automated rclone mirroring to Google Drive, SMB network share ingestion, multi-platform network services manager (SSH, Samba, FTP), real-time file transfer monitors, and comprehensive archive statistics.
8. **Multi-Platform System Maintenance**: OS-tailored system cleaning (Bazzite `ujust`, macOS Homebrew caches & RAM purge, Windows `winget` update & TRIM, FreeBSD `pkg` cleanup & audit), display configuration, and reboot control.
9. **Themes & CLI Engine**: 9 custom retro terminal color themes (Cyberpunk, Dracula, Nord, Matrix, Solarized, Tokyo Night, Monokai, Gruvbox, Emerald) and an integrated interactive Bash CLI runner.

---

## 🚀 Quick Start

### 1. Linux (Bazzite / SteamOS / Fedora / Ubuntu)
For a fresh, step-by-step guide from a clean Bazzite installation, see **[INSTALL_BAZZITE.md](INSTALL_BAZZITE.md)**.

```bash
cd ~/MP_Mix_Manager_v0.1
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
   cd ~/MP_Mix_Manager_v0.1
   chmod +x install.sh
   ./install.sh
   ```
2. **Double-click** `~/Desktop/Mix Archive Manager.command` in Finder, or execute:
   ```bash
   ./manager_macos.command
   # or:
   ./Mix_Archive_Manager.sh
   ```

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
cd ~/MP_Mix_Manager_v0.1
chmod +x manager_freebsd.sh install.sh
./manager_freebsd.sh
# or:
./Mix_Archive_Manager.sh
```

---

## 📂 Repository & Codebase Layout

```
MP_Mix_Manager_v0.1/
├── Mix_Archive_Manager.sh       # Authoritative master interactive console (60 operations)
├── manager.sh                   # Linux bash wrapper
├── manager_macos.command        # macOS double-clickable Finder launcher
├── manager_freebsd.sh           # FreeBSD shell launcher
├── manager.bat                  # Windows native Command Prompt / Batch launcher
├── manager.ps1                  # Windows PowerShell launcher
├── generate_spek.sh             # Dedicated CLI/GUI acoustic spectrogram generator
├── install.sh                   # Cross-platform automated environment installer
├── INSTALL_BAZZITE.md           # Step-by-step Bazzite installation guide
├── README.md                    # Project documentation & reference
├── LICENSE                      # MIT Open-Source License
├── config.env.example           # Cross-platform configuration template
├── config.env                   # Active user configuration
├── requirements.txt             # Python dependencies
│
├── bin/                         # Compiled binaries & CLI helpers (symlinked to ~/.local/bin)
│   ├── cliamp                   # Custom retro terminal music player (v2.0.1)
│   ├── mix-archive-manager      # Desktop / background launch wrapper
│   ├── launch-manager-fullscreen# Dedicated full-screen terminal wrapper
│   ├── transfer-monitor         # Live file write and transfer inspector
│   ├── chrome-upload-monitor    # Real-time web / Podcast Connect upload monitor
│   ├── update-nft-playlist      # M3U / XSPF video playlist builder
│   ├── watch-nft-copy-and-update.sh # Background file write watcher
│   ├── list-midi-devices        # USB MIDI hardware inspector
│   ├── block-internet           # Isolated LAN-only firewall toggle
│   └── unblock-internet         # Firewall restore toggle
│
├── scripts/                     # Modular sub-operation scripts
│   ├── Make_SOF_FLAC_CONVERSION.sh  # 32-bit FLAC conversion & spectrogram generation
│   ├── generate_spek.sh             # Acoustic spectrogram generation engine
│   ├── Check_Find_Tracklists.sh     # Traktor Pro history XML parser
│   ├── MOVE_NOT_CONVERTED_WAVS.sh   # Unconverted WAV retrieval engine
│   ├── SOF_Live_Tracker.sh          # Live tracklist monitor (Strawberry / cliamp)
│   ├── SOF_Archive_Stats.sh         # Archive statistics and duration accumulator
│   ├── backup_to_gdrive.sh          # Rclone Google Drive backup
│   ├── Verify_FLAC_Files.sh         # Multi-threaded FLAC bitstream corruption scanner
│   ├── import_new_mixes.sh          # Automated SMB network mix ingest
│   ├── import_new_mixes.py          # Network archive deduplicator
│   ├── Generate_Master_Tracklist.sh # Master HTML index generator
│   ├── generate_master_tracklist.py # HTML generator logic
│   ├── Make_SOF_Episode_From_PNG_FLAC_Output_MP4_1080p_Video.sh # 1080p YouTube video creator
│   ├── Make_SOF_Episode_From_PNG_FLAC_Output_MP4_4K_Video.sh     # 4K NVENC YouTube video creator
│   ├── Make_SOF_Episode_From_PNG_FLAC_Output_MP4_720p_Video.sh  # 720p YouTube video creator
│   ├── generate_youtube_video.sh    # Unified YouTube video generation engine
│   ├── Cut_Video.sh                 # Precision start/end video cutter
│   ├── merge_playlist_flac.sh       # Concat M3U playlist to FLAC
│   ├── process_trance_roots.py      # Audio processing helper
│   ├── switch-to-plasma-wayland.sh  # Plasma Wayland HDR display switcher
│   ├── switch-to-plasma-x11.sh      # Plasma X11 session switcher
│   ├── play_defasten_4screens.sh    # Multi-screen video display orchestrator
│   ├── close_allapps.sh             # Window manager cleaner (protects active manager)
│   ├── wan2gp.sh                    # WAN2GP AI Video server runner
│   ├── wan2gp_flux_batch.py         # Flux Klein 9B batch generation
│   ├── wan2gp_ltx_batch.py          # LTX Video 2B/13B batch generation
│   ├── clear-wan2gp-logs.sh         # AI generation log pruner
│   ├── detect_and_move_people.py    # YOLOv8 human presence detection
│   └── remove_duplicate_images.py   # Byte-for-byte duplicate image remover
│
├── desktop/
│   └── Mix_Archive_Manager.desktop  # FreeDesktop Application Entry
│
└── assets/
    ├── Cover.png                    # Default cover art template
    └── scaffolds/                   # Working directories (.gitkeep)
        ├── FLAC_CONVERTED_OUTPUTS/  # Master FLAC outputs & text tracklists
        ├── CONVERTED_WAV_FILES/     # Archived source WAV files
        ├── SPEK_OUTPUTS/            # Generated audio spectrograms
        ├── BACKUP_LOGS/             # Cloud backup reports
        ├── VERIFY_LOGS/             # FLAC integrity test reports
        ├── IMPORT_LOGS/             # SMB import reports
        └── COVERS/                  # Episode and album artwork library
```

---

## 🎛️ Feature Matrix (60 Core Operations in 7 Logical Sections)

### ─── [ SECTION 1: MIX ARCHIVE WORKFLOW & INGESTION ] ──────────
| # | Operation | Description |
|---|---|---|
| **1** | **Run FLAC Conversion Process** | Batch concatenates split WAVs, encodes to 32-bit FLAC (`Make_SOF_FLAC_CONVERSION.sh`), embeds artwork, and outputs spectrograms. |
| **2** | **Convert Audio Formats & Bit Depths** | Converts audio between MP3 (320k, V0, 256k), Ogg Vorbis, Opus, Apple AAC, Apple ALAC lossless, FLAC, and WAV-to-WAV bit depths (32-bit float, 32-bit int, 24-bit PCM, 16-bit PCM). |
| **3** | **Retrieve Unconverted WAVs** | Scans archive and quarantines/moves WAVs lacking a corresponding FLAC back to staging (`MOVE_NOT_CONVERTED_WAVS.sh`). |
| **4** | **Import New Mixes from SMB Share** | Connects to remote network studio shares, checks local inventory, and transfers new audio files (`import_new_mixes.sh`). |
| **5** | **Rename Mix and Associated Assets** | Atomically renames FLAC file, `.txt` tracklist, and Spek `.png` across all archive subdirectories. |
| **6** | **Find & Remove Duplicate Audio Files** | Fast chunk-content hashing & episode duplicate detector; supports safe reporting, quarantine to `DUPLICATES_QUARANTINE/`, or permanent deletion (`find_duplicate_mixes.py`). |
| **7** | **Export / Copy Mixes to Specified Path** | Copies complete mix packages (FLAC + Covers + Tracklists TXT/HTML/PDF + Spek) or filtered assets to USB drives or external paths. |
| **8** | **Manage Audio Integrity Checksums** | Generates and verifies SHA-256 integrity manifests (`checksums.sha256`) to ensure mixes are never corrupted or damaged (`manage_checksums.sh`). |
| **9** | **Verify FLAC Files for Integrity** | Multi-threaded decode pass across CPU cores; isolates corrupt FLAC bitstreams to quarantine (`Verify_FLAC_Files.sh`). |
| **10**| **Back up FLAC Outputs to Google Drive** | Automated `rclone` sync to cloud storage with bandwidth throttle and timestamped logging (`backup_to_gdrive.sh`). |
| **11**| **Show Mix Storage Drive Space Remaining** | Displays detailed filesystem capacity, mount point, free space progress bar, and hosted audio file counts for **only the mix storage disk**. |
| **12**| **Refresh Archive Status & File Counts** | Clears cache and performs a full recount of pending WAVs, converted WAVs, FLACs, and missing tracklists. |

### ─── [ SECTION 2: TRACKLIST & METADATA MANAGEMENT ] ───────────
| # | Operation | Description |
|---|---|---|
| **13**| **Tracklist Management Suite** | Complete metadata suite: browse all archive tracklists, keyword search, view active tracklist, and export to styled HTML and printable vector PDF (`generate_tracklist_docs.py`). |
| **14**| **Search for Mix & Auto-Play with Live Tracklist View** | Searches mix catalog, automatically queues and starts playback in `cliamp` (in a separate console window), then returns to manager and loads the live tracklist (skipped if playback doesn't start). |
| **15**| **Scan & Generate Missing Tracklists** | Extracts Traktor Pro history XML logs to generate matching timestamped `.txt` tracklists (`Check_Find_Tracklists.sh`). |
| **16**| **Generate Master Tracklist HTML Index** | Compiles all individual mix tracklists into a single, searchable HTML reference index (`Generate_Master_Tracklist.sh`). |
| **17**| **Launch MusicBrainz Picard Meta Tag Editor** | Opens Picard audio tagger (auto-installs on system if missing). |

### ─── [ SECTION 3: AUDIO PLAYBACK, DAWS & SOUND SUITE ] ────────
| # | Operation | Description |
|---|---|---|
| **18**| **Digital Audio Workstations (DAWs) Menu** | Unified launch hub and package installer for REAPER, Logic Pro (macOS), FL Studio (macOS, Windows, Linux), Traktor Pro (macOS & Windows), GarageBand (macOS), Ardour, LMMS, Bitwig Studio, and Bespoke Synth. |
| **19**| **Open Mix WAV/FLAC Audio File in DAW** | Direct dispatch: prompts user to search by episode/keyword or select from archive mixes, then automatically opens the mix audio file in REAPER, Logic Pro, GarageBand, FL Studio, Audacity, Ardour, or Bitwig. |
| **20**| **Generate Acoustic Spectrograms (Spek)** | Generates 1080p full-spectrum acoustic spectrograms with lossless verification via FFmpeg or launches native Spek GUI (`generate_spek.sh`). Supports batch scans across archive folders. |
| **21**| **Launch Audacity Audio Editor** | Launches Audacity audio editor or installs via Homebrew / winget / Flatpak / native packages. |
| **22**| **Launch Audio Players Menu** | Quick launch hub for cliamp, Strawberry, VLC, foobar2000 (macOS & Windows), Winamp (Windows), Apple Music (macOS), Haruna, and Kodi. |
| **23**| **Configure Default Audio Player & Startup Autoplay** | User preferences suite: choose default player (cliamp, Strawberry, VLC, foobar2000, Winamp, Apple Music, Haruna, Kodi, Audacity, custom), toggle startup mix autoplay, toggle auto-opening cover art, and toggle auto-displaying tracklists. |
| **24**| **cliamp Music Player & Track Control** | Built-in retro terminal player: now-playing path display, cross-platform clipboard copy, folder open, and playback controls. |
| **25**| **Launch Strawberry Music Player** | Opens Strawberry Music Player in a separate desktop window. |
| **26**| **Launch VLC Media Player** | Launches VLC audio/video media player. |
| **27**| **Launch Haruna Media Player** | Opens Haruna Media Player (KDE / mpv / IINA). |
| **28**| **Launch Kodi Entertainment Center** | Launches Kodi Media Center. |
| **29**| **Show Connected USB MIDI Devices** | Inspects connected synthesizers, DJ controllers, and keyboards. |

### ─── [ SECTION 4: VIDEO PRODUCTION, ART & VISUAL MEDIA ] ──────
| # | Operation | Description |
|---|---|---|
| **30**| **Generate YouTube Video (4K UHD, 1080p, 720p)** | Encodes pristine YouTube MP4 videos in 4K UHD (3840x2160), 1080p Full HD (1920x1080), or 720p HD (1280x720) with NVENC/Hardware acceleration, 320kbps AAC audio, and smooth 5s audio fading (`generate_youtube_video.sh`). |
| **31**| **Cut Video File (.mp4 / .mkv)** | Precision video clipping utility based on start/end timestamps with cross-platform folder launch (`Cut_Video.sh`). |
| **32**| **Launch Video Playlists** | Plays Defasten or NFT video playlists in VLC, or regenerates `.m3u`/`.xspf` files. |
| **33**| **Launch VLC Video Player** | Launches VLC Video Player directly. |
| **34**| **Launch GIMP Image Editor** | Launches GIMP image editor or installs via package manager. |
| **35**| **Convert Cover Art & Resize / Byte Target** | Converts covers between JPEG, WebP, PNG, and TIFF with preset resolutions (3000x3000, 1400x1400, 1080x1080) and binary-search byte targeting (e.g. strict <= 1MB podcast standard). |
| **36**| **View Cover Art by Mix Number** | Searches `COVERS/` directory by episode or mix number and opens in system image viewer. |
| **37**| **Launch Electric Sheep Screensaver** | Launches Electric Sheep generative screensaver. |

### ─── [ SECTION 5: LIVE MONITORS & SYSTEM DIAGNOSTICS ] ────────
| # | Operation | Description |
|---|---|---|
| **38**| **Launch Live Tracklist Monitor** | Real-time CLI display connecting to Strawberry MPRIS and `cliamp` with live progress and track info (`SOF_Live_Tracker.sh`). |
| **39**| **Launch Live File Transfer Monitor** | Inspects transfer speeds, byte positions, and percentage for huge files (`transfer-monitor`). |
| **40**| **Launch Chrome Upload Monitor** | Monitors web uploads (e.g. Apple Podcasts Connect, YouTube Studio) in real-time (`chrome_upload_monitor.py`). |
| **41**| **View Advanced Archive Statistics** | Deep inventory scan calculating total duration, file sizes, GB footprint, and tracklist completeness (`SOF_Archive_Stats.sh`). |
| **42**| **View Running Background Tasks** | Scans process table for active encoding, syncing, or AI batch jobs. |
| **43**| **Launch Resource Monitor** | Launches `btop` for deep multi-core CPU and memory profiling. |
| **44**| **Launch GPU Process Monitor** | Launches `nvtop` for real-time monitoring of NVIDIA GPU clock, VRAM, and power draw. |
| **45**| **Launch System Process Monitor** | Quick-launches `top` inside manager session. |

### ─── [ SECTION 6: SYSTEM, NETWORK & HARDWARE MANAGEMENT ] ─────
| # | Operation | Description |
|---|---|---|
| **46**| **Manage WAN2GP Server** | Controls WAN2GP AI video server (Profile 2 / 4.5, Flux Klein 9B batch, LTX Video 2B/13B). |
| **47**| **Manage Network Services** | Bulk and individual start, stop, restart, and status for SSH (`sshd`), Samba (`smb`), and FTP (`vsftpd`) across Linux (`systemctl`), FreeBSD (`service`), macOS (`launchctl`/`systemsetup`), and Windows (PowerShell). |
| **48**| **Block Internet Access (LAN Only)** | Activates an isolated firewall table blocking WAN while keeping LAN open (`block-internet`). |
| **49**| **Restore / Unblock Internet Access** | Restores immediate full internet connectivity (`unblock-internet`). |
| **50**| **Display Settings (OS Tailored)** | Opens Plasma Wayland on Linux, macOS Display Settings, or Windows Display Settings (`ms-settings:display`). |
| **51**| **Audio / Sound Settings (OS Tailored)** | Opens Plasma X11 on Linux, Audio MIDI Setup on macOS, or Windows Sound Panel (`control.exe mmsys.cpl`). |
| **52**| **Close All Desktop Applications** | Gracefully closes external desktop windows using AppleScript (macOS), PowerShell (Windows), or `wmctrl` (Linux) while shielding the manager. |
| **53**| **System Maintenance & Cleanup** | Executes platform maintenance (Linux `ujust clean-system`, macOS `brew cleanup` & RAM purge, Windows `winget upgrade` & temp cleanup, FreeBSD `pkg clean`, `pkg upgrade`, `pkg autoremove`). |
| **54**| **Launch GeeXLab Demo Launcher** | Runs 3D/OpenGL shader demos and GPU stress tests via GeeXLab/FurMark. |
| **55**| **Burn ISO Image to USB Drive** | Writes bootable ISO files directly to removable USB storage with safety checks and dd progress (macOS `diskutil` / Linux `lsblk`). |

### ─── [ SECTION 7: AI, SHELL CLI & SETTINGS ] ───────────────────
| # | Operation | Description |
|---|---|---|
| **56**| **Launch AI Assistant / Models (AGY)** | Starts Antigravity CLI AI sessions (Claude Sonnet, Claude Opus, GPT-OSS, Gemini). |
| **57**| **Run Bash CLI Commands** | Built-in interactive Bash shell and direct command execution runner. |
| **58**| **Manager Themes & Color Palette Switcher** | Switch between 9 terminal themes (Cyberpunk, Dracula, Nord, Matrix, Solarized, Tokyo Night, Monokai, Gruvbox, Emerald, Classic). |
| **59**| **Reboot System** | Cross-platform system reboot with safety confirmation dialog (`systemctl reboot`, macOS `osascript`, Windows `shutdown.exe /r`, FreeBSD `shutdown -r now`). |
| **60**| **Exit Manager** | Cleans up and exits the console session. |

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
```

---

## 📜 License

Licensed under the **MIT License**. See [LICENSE](LICENSE) for details.
