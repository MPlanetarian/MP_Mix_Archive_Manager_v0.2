# Mix Archive Manager (`MP_Mix_Manager_v0.1`)

[![Platform](https://img.shields.io/badge/Platform-Bazzite%20Linux%20%7C%20SteamOS%20%7C%20Fedora-blue.svg)](https://bazzite.gg)
[![Shell](https://img.shields.io/badge/Language-Bash%20%7C%20Python-orange.svg)]()
[![Audio](https://img.shields.io/badge/Audio-32bit%20Lossless%20FLAC-green.svg)]()
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

An enterprise-grade workstation orchestration console and media management suite designed for high-resolution audio production, multi-hour DJ mix archiving, automated FLAC mastering, Traktor Pro playlist extraction, live tracklist tracking, YouTube video synthesis, system maintenance, and AI workflow control on **Bazzite Linux**.

---

## 🎧 Overview

The **Stream of Frequency Mix Archive Manager** provides an interactive, terminal-driven control center (36 operations) that automates the entire lifecycle of professional DJ mixes and audio recordings:

1. **Ingestion & Concatenation**: Auto-detects split multi-hour WAV recordings (e.g. 3-hour chunks from Traktor / external recorders), normalizes filenames, and concatenates them into single pristine tracks.
2. **Lossless FLAC Mastering**: Encodes to 32-bit sample depth FLAC (`-sample_fmt s32 -compression_level 12`), optimizes and embeds cover art (`scale='min(1400,iw)':-1`), and outputs matching high-resolution spectrograms (`SPEK_OUTPUTS`).
3. **Traktor Pro History Integration**: Automatically scans Traktor history XML collection archives, maps played tracks to exact session timestamps, and generates ready-to-publish timestamped tracklists.
4. **Live Now-Playing Monitor**: Bridges Strawberry Music Player (via MPRIS D-Bus) and the custom `cliamp` retro terminal music player to show real-time progress bars, track IDs, active filesystem paths, and clipboard copy shortcuts.
5. **Video & Social Production**: Generates 1080p and 4K NVENC-accelerated YouTube videos directly from cover art and FLAC master audio, complete with 5-second audio fade-ins and fade-outs.
6. **Cloud & Network Sync**: Automated rclone mirroring to Google Drive and SMB network share ingestion with deduplication.
7. **System & AI Operations**: Desktop environment switcher (Plasma Wayland HDR vs. X11 Workstation), WAN2GP AI server and batch processing (Flux Klein 9B / LTX Video), YOLOv8 vision AI, and Bazzite atomic system maintenance.

---

## 🚀 Quick Start

### 1. Installation on Bazzite Linux
For a fresh, step-by-step guide from a clean Bazzite installation, see **[INSTALL_BAZZITE.md](INSTALL_BAZZITE.md)**.

To install quickly on an existing Bazzite machine:
```bash
cd ~/MP_Mix_Manager_v0.1
chmod +x install.sh
./install.sh
```

### 2. Launching the Manager
From anywhere in your terminal:
```bash
manager
# or:
~/manager.sh
```
Or launch **Mix Archive Manager** from your KDE Plasma application launcher or desktop shortcut.

---

## 📂 Repository & Codebase Layout

```
MP_Mix_Manager_v0.1/
├── Mix_Archive_Manager.sh       # Authoritative master interactive console (36 operations)
├── manager.sh                   # Local runner shortcut
├── install.sh                   # Automated Bazzite Linux environment installer
├── INSTALL_BAZZITE.md           # Step-by-step fresh client installation guide
├── README.md                    # Project documentation & reference
├── LICENSE                      # MIT Open-Source License
├── config.env.example           # Configuration template
├── config.env                   # Active user configuration
├── requirements.txt             # Python dependencies (Pillow, Ultralytics)
│
├── bin/                         # Compiled binaries & CLI helpers (symlinked to ~/.local/bin)
│   ├── cliamp                   # Custom retro terminal music player (v2.0.1)
│   ├── mix-archive-manager      # Desktop / background launch wrapper
│   ├── launch-manager-fullscreen# Dedicated full-screen Konsole wrapper
│   ├── transfer-monitor         # Live /proc file write and transfer inspector
│   ├── chrome-upload-monitor    # Real-time web / Podcast Connect upload monitor
│   ├── update-nft-playlist      # M3U / XSPF video playlist builder
│   ├── watch-nft-copy-and-update.sh # Background file write watcher
│   ├── list-midi-devices        # USB MIDI hardware inspector
│   ├── block-internet           # Isolated nftables LAN-only firewall toggle
│   └── unblock-internet         # Nftables restore firewall toggle
│
├── scripts/                     # Modular sub-operation scripts
│   ├── Make_SOF_FLAC_CONVERSION.sh  # 32-bit FLAC conversion & spectrogram generation
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

## 🎛️ Feature Matrix (36 Core Operations)

| # | Operation | Description |
|---|---|---|
| **1** | **Run FLAC Conversion Process** | Batch concatenates split WAVs, encodes to 32-bit FLAC, embeds artwork, and outputs spectrograms. |
| **2** | **Scan & Generate Missing Tracklists** | Extracts Traktor Pro history XML logs to generate matching timestamped `.txt` tracklists. |
| **3** | **Retrieve Unconverted WAVs** | Scans archive and quarantines/moves WAVs lacking a corresponding FLAC back to staging. |
| **4** | **Launch Live Tracklist Monitor** | Real-time CLI display connecting to Strawberry MPRIS and `cliamp` with live progress and track info. |
| **5** | **View Advanced Archive Statistics** | Deep inventory scan calculating total duration, file sizes, GB footprint, and tracklist completeness. |
| **6** | **Rename Mix and Associated Assets** | Atomically renames FLAC file, `.txt` tracklist, and Spek `.png` across all archive subdirectories. |
| **7** | **Back up FLAC Outputs to Google Drive** | Automated `rclone` sync to cloud storage with bandwidth throttle and timestamped logging. |
| **8** | **Verify FLAC Files for Integrity** | Multi-threaded FFmpeg decode pass across all CPU cores; automatically isolates corrupt files to quarantine. |
| **9** | **Import New Mixes from SMB Share** | Connects to remote network studio shares, checks local inventory, and transfers new audio files. |
| **10**| **View Running Background Tasks** | Scans process table and systemd units for active encoding, syncing, or AI batch jobs. |
| **11**| **View Cover Art by Mix Number** | Searches `COVERS/` directory by episode or mix number and opens in the system image viewer. |
| **12**| **Generate Master Tracklist HTML Index** | Compiles all individual mix tracklists into a single, searchable HTML reference index. |
| **13**| **Generate 1080p YouTube Video** | Synthesizes a high-definition 1080p MP4 with libx264, 320kbps AAC audio, and automatic 5s audio fading. |
| **14**| **Launch Live File Transfer Monitor** | Inspects `/proc/<pid>/fdinfo` to show active transfer speeds, byte positions, and percentage for huge files. |
| **15**| **Launch Chrome Upload Monitor** | Monitors web uploads (e.g. Apple Podcasts Connect, YouTube Studio) in real-time. |
| **16**| **Refresh Archive Status & File Counts** | Clears terminal cache and performs a full recount of WAVs, FLACs, and missing tracklists. |
| **17**| **Launch System Process Monitor** | Quick-launches `top` inside the manager session. |
| **18**| **Launch GPU Process Monitor** | Launches `nvtop` for real-time monitoring of NVIDIA GPU clock, VRAM, and power draw. |
| **19**| **Launch Resource Monitor** | Launches `btop` for deep multi-core CPU and memory profiling. |
| **20**| **cliamp Music Player & Track Manager** | Submenu for the built-in retro player: now-playing path display, clipboard copy, folder open, and playback controls. |
| **21**| **Launch Strawberry Music Player** | Opens Strawberry Music Player in a separate desktop window. |
| **22**| **Launch Video Playlists** | Plays Defasten or NFT video playlists in VLC, or regenerates desktop `.m3u`/`.xspf` files. |
| **23**| **Close All Desktop Applications** | Gracefully closes all external desktop windows using `wmctrl` while protecting the active manager. |
| **24**| **Block Internet Access (LAN Only)** | Activates an isolated `nftables` firewall table blocking WAN while keeping LAN and local subnets open. |
| **25**| **Restore / Unblock Internet Access** | Flushes and removes the `lanonly` nftables table to restore immediate full internet connectivity. |
| **26**| **Launch GeeXLab Demo Launcher** | Runs 3D/OpenGL shader demos and GPU stress tests via GeeXLab/FurMark. |
| **27**| **Show Connected USB MIDI Devices** | Inspects connected synthesizers, DJ controllers, and keyboards via ALSA Sequencer and RawMIDI nodes. |
| **28**| **Switch Desktop to Plasma Wayland** | Configures KScreen Doctor and HDMI digital audio for 4K HDR TV gaming and Steam Big Picture Mode. |
| **29**| **Switch Desktop to Plasma X11** | Preselects Plasma X11 in SDDM for multi-monitor workstation setups. |
| **30**| **Manage WAN2GP Server** | Controls WAN2GP AI video server (Profile 2 / 4.5, Flux Klein 9B batch, LTX Video 2B/13B). |
| **31**| **Manage Network Services** | Bulk start, stop, and restart for SSH (`sshd`), Samba (`smb`), and FTP (`vsftpd`). |
| **32**| **Bazzite System Maintenance & Cleanup** | Executes `ujust clean-system`, `ujust update`, journal log vacuuming, and SSD `fstrim`. |
| **33**| **Launch AI Assistant / Models (AGY)** | Starts Antigravity CLI AI sessions (Claude Sonnet 4.6, Claude Opus, GPT-OSS, Gemini). |
| **34**| **Burn ISO Image to USB Drive** | Writes bootable ISO files directly to removable USB storage with sanity checks and `dd` progress. |
| **35**| **Cut Video File (.mp4 / .mkv)** | Precision video clipping utility based on start/end seconds with automatic folder launch. |
| **36**| **Exit Manager** | Cleans up and exits the console session. |

---

## ⚙️ Configuration (`config.env`)

Mix Archive Manager automatically loads `config.env` from the codebase directory or `~/.config/mix-manager/config.env`.

```bash
# Target storage path for music and mix archives
MIX_ARCHIVE_DIR="/run/media/$USER/WD BLACK B/MIX_ARCHIVE"

# Traktor History folder containing session collection.nml files
TRAKTOR_HISTORY_DIR="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/Traktor 3.11.1/History"

# Rclone remote endpoint for offsite cloud backup
GDRIVE_REMOTE="gdrive:MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"
```

---

## 📜 License

Licensed under the **MIT License**. See [LICENSE](LICENSE) for details.
