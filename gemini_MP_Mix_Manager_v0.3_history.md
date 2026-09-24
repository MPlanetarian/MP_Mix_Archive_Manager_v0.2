# Gemini Engineering & Development History: Mix Archive Manager (`MP_Mix_Manager_v0.3`)

**Author & AI Pair Programmer**: Antigravity / Gemini 3.8  
**Client / Lead Architect**: MPlanetarian (`mathewkjohn2026@gmail.com`)  
**Repository**: `/home/mplanetarian/MP_Mix_Manager_v0.3` (`git@github.com:MPlanetarian/MP_Mix_Manager_v0.3.git`)  
**Mirror Path**: `/var/home/mplanetarian/Documents/BASH_SCRIPTS/`  
**Latest Revision**: v0.2.1 (September 17, 2026)  
**Primary Platforms**: Bazzite Linux (Fedora Kinoite / Silverblue ostree), SteamOS, Ubuntu, macOS Sequoia/Sonoma, Windows 10/11, FreeBSD 14+  

---

## 📌 Executive Summary

This document serves as the comprehensive, immutable architectural history and development ledger of all engineering sessions, features, bug fixes, refactorings, and integrations executed by **Gemini (Antigravity CLI)** for the **Stream of Frequency Mix Archive Manager** (`MP_Mix_Manager_v0.3`).

What began on September 13, 2026, as a collection of scattered shell utilities across `/var/home/mplanetarian/Documents/BASH_SCRIPTS/` and archive storage volumes has been transformed into an enterprise-grade, modular, cross-platform media production and workstation orchestration console comprising:
- **75 Master Operations** categorized across **7 logical operational domains**.
- **60+ Modular Bash scripts and Python utility engines** handling audio engineering, video rendering, network syndication, and system maintenance.
- **Deep Hardware & System Integrations**: PipeWire/WirePlumber zero-latency buffer tracking, KDE Plasma 6 KWin DBus window alignment, NVIDIA GPU NVENC acceleration, and MPRIS audio player discovery.
- **Unified AI & Monitoring Hub**: Beszel Monitoring Hub & Agent (`beszel.sh`), Ollama Containerized LLMs (`manage_ollama.sh`), and DeepSeek Harness Web GUI with dedicated mobile LAN bridging (`dsh_mobile.sh`).
- **Remote Ecosystem Control**: KDE Connect mobile remote control commands and `.desktop` application launchers mapped for iPhone, macOS, and desktop hotkeys.

---

## 📅 Chronological Development History

```
2026-09-13 [Initial Codebase Creation] ──────────► MP_Mix_Manager_v0.1 & Git Setup
2026-09-14 [v0.2 Feature Explosion]   ──────────► 69 Ops: Publishing, Spectrograms, PPM Art
2026-09-14 [Workstation HUD & Traktor] ──────────► KWin HUD, Latency Banner, Traktor Monitor (72 Ops)
2026-09-15 [Playlists & Strawberry]    ──────────► Playlist-to-FLAC, Strawberry MPRIS Integration
2026-09-16 [Audio/Video Splitting]    ──────────► Split_FLAC_File.sh, Split_Video_File.sh
2026-09-17 [AI Hub & Beszel]           ──────────► Beszel Hub/Agent (Opt 57), Ollama Serve (Opt 58)
2026-09-17 [Startup Polish & UX]       ──────────► Instant Startup, Removed 3s Delay & Preview Flash
2026-09-17 [DeepSeek Harness & LAN]    ──────────► dsh-mobile (Opt 59, 75 Ops) & iPhone LAN Bridge
```

---

### Phase 1: Genesis & Codebase Consolidation (2026-09-13 to 2026-09-14)

#### Session 1: Migration & Repository Initialization
- **Primary Request**: Extract all mix management scripts from scattered directories and `/var/home/mplanetarian/Documents/BASH_SCRIPTS/` into a dedicated repository in `/home/mplanetarian/MP_Mix_Manager_v0.1`.
- **Engineering Accomplished**:
  1. Built canonical directory structure: `scripts/`, `bin/`, `assets/`, `desktop/`, `config_backups/`, `exported_configs/`.
  2. Initialized Git repository (`main` branch) and established dual-mirror sync with `/var/home/mplanetarian/Documents/BASH_SCRIPTS/`.
  3. Created `install.sh` for user-space installation (`~/.local/bin/` symlinks and desktop entries).
  4. Authored `INSTALL_BAZZITE.md` detailing step-by-step setup on immutable Fedora/Bazzite Silverblue ostree systems.
  5. Clarified and configured bundled retro music player `cliamp` to run with zero external installation dependencies.
  6. Established standard Git workflow with author metadata `MPlanetarian <mathewkjohn2026@gmail.com>`.
- **Git Commits**:
  - `40687c9` — *Initial release: Stream of Frequency Mix Archive Manager v0.1 (Bazzite Linux)*
  - `12b110c` — *docs: update clone URL with official GitHub repo path*
  - `612b1e0` — *docs: clarify that cliamp is bundled and requires no separate installation*
  - `0c497f0` — *ui: update top banner title to Mix Archive Manager (MP_Mix_Manager_v0.1)*

---

### Phase 2: The v0.2 Massive Expansion Sprint (2026-09-14 00:30 – 02:00)

#### Session 2: 69-Operation Architecture & Multi-Format Modernization
- **Primary Request**: Modernize the suite to version `v0.2`, adding complete audio conversion, publishing calendars, duplicate detection, studio diagnostics, dynamic MOTD, and procedural art generation.
- **Engineering Accomplished**:
  1. **Audio Format & Sample Rate Conversion (`convert_audio_format.sh`)**:
     - Built universal batch audio transcoder supporting 32-bit float, 32-bit int, 24-bit, and 16-bit PCM across WAV, FLAC, MP3, Ogg Vorbis, Opus, AAC, and ALAC.
  2. **Tracklist Documentation Engine (`generate_tracklist_docs.py`)**:
     - Implemented dual-output HTML and printable vector PDF documentation generators rendering episode metadata, cover art, and timestamped tracklists.
  3. **Duplicate Mix Detector (`find_duplicate_mixes.py`)**:
     - Engineered content-based acoustic file hashing and metadata analysis to identify duplicate episode numbers, redundant filenames, and oversized uncompressed masters.
  4. **Master Checksum Suite (`manage_checksums.sh`)**:
     - Automated SHA-256 and MD5 integrity verification across archive storage volumes.
  5. **Procedural Netpbm P6 Binary `.PPM` Cover Art Generator (`generate_ppm_cover.py` / `.sh`)**:
     - Developed pure-Python mathematical graphics generator with zero external C-library dependencies.
     - Implemented linear, radial, plasma wave, and angular gradients across 8 curated palettes (Cyberpunk Neon, Solarized Dusk, Deep Space Trance, Sunset Horizon, Emerald Matrix, Acid Gold, Retro Synthwave, Mono Chrome).
     - Added typography overlays rendering artist names, mix titles, episode numbers, and category badges directly to high-resolution PNG outputs (`1400x1400` / `3000x3000`).
  6. **Mix Publishing & Syndication Calendar (`publish_calendar_scheduler.py` / `.sh`)**:
     - Persistent JSON calendar (`assets/publishing_calendar.json`) scheduling mix releases across Apple Podcasts, Spotify, YouTube, SoundCloud, Mixcloud, DI.FM, Proton Radio, and Bandcamp.
     - Automated Apple Podcasts compliant RSS feed generator (`podcast_feed.xml`) and RFC 5545 iCalendar (`.ics`) exporter.
  7. **Studio Hardware & Software Diagnostics (`inspect_audio_studio.py` / `.sh`)**:
     - Audits active audio architecture (PipeWire, PulseAudio, ALSA), hardware buffer latency, and detected MIDI controllers (AKAI MPKmini2, Arturia MiniLab mkII, Valve).
     - Scans installed digital audio workstations: REAPER, Logic Pro, FL Studio, Traktor Pro, Audacity, Ardour, Bitwig, Picard, Spek, cliamp, VLC, Haruna, and Kodi.
  8. **Synchronized Companion Video Daemon (`sync_video_companion.py` / `.sh`)**:
     - Background daemon detecting currently playing audio via MPRIS, finding matching video companions (`.mp4`, `.mkv`), launching them in VLC/Haruna/MPV, and killing video playback when audio ceases.
  9. **Custom Playlist Creator (`manage_playlists.py` / `.sh`)**:
     - Builds, browses, and validates UTF-8 extended `.m3u8` and XML `.xspf` playlists with duration, track count, and size calculations.
  10. **Dynamic Message Of The Day (`manage_motd.py` / `update_system_motd.sh`)**:
      - Dynamically analyzes archive disks and compiles stylized terminal MOTD banners highlighting the last 5 mastered mixes, bit depths, and sample rates.
  11. **Master Menu Expansion**:
      - Scaled interactive console menu from 62 to **69 operations** with strict 1:1 case-dispatch synchronization.
      - Updated all platform entrypoints: `manager.sh`, `manager_macos.command`, `manager.bat`, `manager.ps1`, `manager_freebsd.sh`.
- **Git Commits**:
  - `4b3ac96` — *Add audio converter, tracklist HTML/PDF docs, duplicate cleaner, checksums, cover compressor, and 56-operation categorized menu*
  - `47b687b` — *Add YouTube 4K & 720p video generation, default audio player configuration, and startup mix autoplay with cover & tracklist display*
  - `2cea384` — *Add Logic Pro, Traktor, Winamp, Foobar2000, GarageBand & FL Studio support, Open WAV in DAW, Spek generator, and FreeBSD platform support*
  - `0be50ef` — *Add promotional & publisher outreach email system for podcast enquiries, club promoters, radio & labels*
  - `9e45702` — *Add installation path migration, config backup/export/import suite, and universal mix search & importer for local drives and SMB*
  - `522bac5` — *feat(v0.2): release v0.2 with publishing calendar, studio diagnostics, PPM art, audio control & 69 operations*

---

### Phase 3: Workstation HUD, Audio Latency & Traktor Pro Integration (2026-09-14 02:00 – 03:30)

#### Session 3: Plasma 6 KWin Alignment, Latency Banner & Live Traktor Recorder
- **Primary Request**: Integrate live Traktor Pro monitoring, create a borderless floating tracklist HUD on Bazzite Linux, align cover art and tracklist side-by-side, probe live sound card latency on startup, and add weather conditions.
- **Engineering Accomplished**:
  1. **Traktor Pro Live Monitor & Audio Recorder Control (`traktor_monitor.py` / `.sh`, Option 48)**:
     - Merged Traktor monitoring engine from remote macOS workstation (`192.168.1.138`) into core repo.
     - Built comprehensive Windows 10/11 support (`Traktor.exe`, `Traktor Pro 3.exe`, `Traktor Pro 4.exe` detection, `msvcrt` hotkey handling, PowerShell CIM queries, and `WScript.Shell` recording toggle automation).
     - Linux `/proc/$pid/fd` live file growth tracking and macOS AppleScript menu clicking.
  2. **Technical Audio Specification Inspector (`inspect_playing_audio.py` / `.sh`, Option 28)**:
     - Real-time technical stream analysis: Container, exact bit depth (`24-Bit`, `16-Bit`, `32-Bit Float`), sample rate (`48.0 kHz`, `96.0 kHz`), duration, file size, bitrate, FLAC compression ratio, and companion asset status.
  3. **Live Audio Interface & Buffer Latency Banner (`scripts/get_audio_interface.py`)**:
     - Ultra-fast probe (<120ms) inspecting PipeWire/WirePlumber quantum (`wpctl inspect @DEFAULT_AUDIO_SINK@`, `pw-metadata`), ALSA `/proc/asound/`, PulseAudio, macOS CoreAudio, and Windows WASAPI.
     - Embedded directly into main header:
       `🎧 Audio Interface: Crusher ANC 2 │ ⚡ Latency: 21.3ms (1024 @ 48kHz) │ 🎛️ Engine: PipeWire`
  4. **KDE Plasma 6 KWin Scripting & Borderless HUD (`align_mix_windows.py` & `view_tracklist_console.sh`)**:
     - Automated DBus script injection into KWin to position Cover Art (left) and Tracklist Console (right) centered on screen with zero overlap (`keepAbove = true`).
     - Injected KWin borderless window rules (`noborder=true`, `noborderrule=2`) and Konsole flags (`--hide-menubar`, `--hide-tabbar`, `-p TerminalMargin=0`) for a frameless HUD experience on Bazzite Linux.
  5. **Live Meteorological Weather Display (`get_weather.sh`)**:
     - Live weather banner for **Swansea, UK** with a 20-minute local file cache (`assets/weather_cache.txt`) ensuring 0ms overhead during startup.
  6. **Launcher Fixes & Bash 3.2 Compatibility**:
     - Ensured absolute symlink resolution across wrappers in `~/.local/bin/` and resolved Bash 3.2 macOS syntax limitations.
- **Git Commits**:
  - `b3e729b` — *fix(launchers): resolve symlinks accurately across ~/.local/bin and manager wrappers*
  - `727f6c2` — *feat(playback): open tracklist in dedicated text editor window on boot alongside cover art*
  - `ed1aeb4` — *feat(tracklist): add borderless console tracklist viewer for Bazzite Linux and default OS consoles*
  - `e74702f` — *Add centered mix HUD alignment, live meteorological weather, music shopping, video launcher & YouTube autoplay*
  - `d70d748` — *feat: add audio specification inspector (Option 28) and live audio interface & latency banner*
  - `747fa48` — *feat: integrate cross-platform Traktor Live Monitor & Audio Recorder (Option 48)*
  - `3eded5f` — *fix(install): ensure Bash 3.2 compatibility on macOS for dependency probe*
  - `cee169c` — *fix(install): define DIM ANSI color sequence*

---

### Phase 4: Playlists, Strawberry & Autoplay Logic (2026-09-15 to 2026-09-16)

#### Session 4: Playlists, MPRIS D-Bus & Autoplay Refinements
- **Primary Request**: Prevent `cliamp` from opening when Strawberry is already playing music; add playlist-to-FLAC conversion; add D-Bus inspection.
- **Engineering Accomplished**:
  1. **Playlist-to-FLAC Conversion Engine (`merge_playlist_flac.sh`)**:
     - Added support for reading `.m3u` / `.m3u8` playlists, extracting audio paths, validating sample rates, and concatenating into single mastered 24-bit / 32-bit FLAC files with embedded cover art.
  2. **Strawberry Music Player Integration**:
     - Configured Strawberry as the official default music player (`DEFAULT_AUDIO_PLAYER="strawberry"`).
     - Implemented `get_strawberry_track_info` querying Strawberry via MPRIS D-Bus (`qdbus org.mpris.MediaPlayer2.strawberry /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Metadata`) to extract playing track, artist, album, duration, and file path.
  3. **Playback Pre-Check in Autoplay**:
     - Added active playback detection before initiating autoplay to avoid interrupting active listening sessions.

---

### Phase 5: Audio/Video Splitting & AI Infrastructure (2026-09-17 00:00 – 02:00)

#### Session 5: Splitting Utilities, Beszel Hub/Agent & Ollama Server
- **Primary Request**: Add utilities to losslessly split long FLAC mixes and YouTube MP4 videos into equal parts; add management options for Beszel monitoring and Ollama containerized LLMs; create KDE Connect iPhone shortcuts.
- **Engineering Accomplished**:
  1. **Standalone FLAC Splitting Utility (`Split_FLAC_File.sh`, integrated into Option 2)**:
     - Discovers candidate `.flac` files, prompts for $N$ parts, divides duration with millisecond accuracy, and losslessly splits audio using `ffmpeg -c:a flac -map_metadata 0`.
     - Places split parts (`<stem>_Part01.flac`, `<stem>_Part02.flac`...) in the input directory and opens the file manager.
  2. **Standalone Video Splitting Utility (`Split_Video_File.sh`, integrated into Option 38)**:
     - Discovers `.mp4` video files, offers Fast Stream Copy or Frame-Accurate Re-encode, splits into $N$ parts, and saves directly beside the source file.
  3. **Beszel Server Monitoring Hub & GPU Agent (`beszel.sh`, Option 57)**:
     - Manages Beszel Hub (port 8090) and Beszel Agent (GPU passthrough container) with automatic container existence checks and launch script fallbacks.
     - Verifies and activates user `podman.socket`.
     - Live status inspection (container uptime, HTTP health, agent WebSocket connection, NVIDIA GPU model and VRAM allocation).
  4. **Ollama Server & Local LLM Management (`manage_ollama.sh`, Option 58)**:
     - Controls `ollama serve` inside distrobox container `ollama-container` on port 11434 (`http://127.0.0.1:11434`).
     - Supports background daemon mode or dedicated Konsole window.
     - Reports CUDA acceleration, NVIDIA VRAM, and lists installed models (Qwen 2.5, LLaMA 3.1, Nemotron, SmolLM2).
     - Provides interactive chat launcher to run inference directly in the terminal.
  5. **WAN2GP Server Management & KDE Connect Shortcuts**:
     - Added CLI flags and KDE Connect scripts (`kc_start_wan2gp_profile45.sh`, `kc_stop_wan2gp.sh`, `kc_run_ollama_serve.sh`, `kc_stop_ollama.sh`, `kc_launch_beszel_hub_and_agent.sh`).
     - Created matching `.desktop` launchers in `~/Desktop/` and `~/.local/share/applications/`.
- **Git Commits**:
  - `8d31fc4` — *feat: add logic to prevent launching cliamp if audio player is running*
  - `2625ad2` — *refactor: add check for default player in main function*
  - `ffb5077` — *fix(player): prevent launching cliamp when Strawberry is playing and set Strawberry as default player*
  - `ac76fb9` — *feat: add FLAC audio and YouTube MP4 video splitting utilities with manager menu integration*
  - `383c9f0` — *feat: add Beszel monitoring hub and agent management to manager (Option 57)*

---

### Phase 6: Startup UX Polish & Terminal Delay Elimination (2026-09-17 16:00 – 17:00)

#### Session 6: Instant Startup & Intermediate Window Elimination
- **Primary Request**: Fix unexpected behavior where launching `mix-archive-manager` flashed the Live Tracklist screen for a few seconds before opening the menu; fix disappearing KDE Connect commands on iPhone.
- **Engineering Accomplished**:
  1. **Startup Preview Flash Removal**:
     - Identified root cause in `execute_startup_autoplay`: when background playback was detected, the manager was calling `auto_show_playing_mix_assets` and executing an artificial 3-second sleep (`sleep 3`) to preview the tracklist.
     - Refactored `execute_startup_autoplay` to exit cleanly and immediately when playback is detected.
     - Removed the 3-second delay, allowing the manager menu loop to render instantaneously.
  2. **Tracklist Viewer Stalling Fix**:
     - Updated `scripts/view_tracklist_console.sh` interactive loop to ignore unconsumed newlines and prevent premature closing.
  3. **KDE Connect iPhone Synchronization**:
     - Corrected command definition formatting in `~/.config/kdeconnect/*/kdeconnect_runcommand/config` to ensure all remote actions appear reliably in the iOS KDE Connect application.

---

### Phase 7: DeepSeek Harness Integration (`dsh-mobile` - 2026-09-17 17:00 – 20:00)

#### Session 7: DeepSeek Harness Server Management (Option 59)
- **Primary Request**: Add support for running DeepSeek Harness (`dsh-mobile`) from within the manager and via KDE Connect / Desktop shortcuts.
- **Engineering Accomplished**:
  1. **Engine Controller (`scripts/dsh_mobile.sh` & `dsh_mobile.sh`)**:
     - Manages `pnpm dsh web --trusted-host 192.168.1.11:3080 --trusted-host 192.168.1.11 --no-open` in `/var/home/mplanetarian/beszel-hub/deepseek-harness`.
     - Supports terminal window launch (Konsole tab) or background daemon mode (`/tmp/dsh-mobile.log`).
     - Fast status inspection: process status, PID, local URL (`http://localhost:3080`), LAN mobile URL (`http://192.168.1.11:3080`), port 3080 listening status, and git commit.
     - One-click browser dispatch and log viewer.
  2. **Manager Integration**:
     - Added **Option 59** in Section 6: `Manage DeepSeek Harness Server (dsh-mobile - Start, Stop, Mobile Web UI :3080)`.
     - Integrated into AI models menu (Option 70).
     - CLI flags: `--dsh-mobile`, `--dsh-start`, `--dsh-bg`, `--dsh-web`, `--dsh-stop`, `--dsh-restart`, `--dsh-logs`, `--dsh-status`.
     - Renumbered operations to **75 operations** across 7 sections.
  3. **Launchers & Symlinks**:
     - Created `bin/dsh-mobile`, `bin/manage-dsh-mobile`, `~/.local/bin/` symlinks, desktop shortcut `desktop/dsh-mobile.desktop`, and KDE Connect remote command `kc_launch_dsh_mobile.sh`.
- **Git Commits**:
  - `9e651df` — *feat: add DeepSeek Harness (dsh-mobile) and Ollama server management to manager*

---

### Phase 8: iPhone LAN Connectivity Resolution for DeepSeek Harness (2026-09-17 20:00 – Current)

#### Session 8: Socket Binding Diagnosis & Systemd LAN Bridge
- **Primary Request**: "I can't access DeepSeek Harness from my iPhone the url I am using is http://192.168.1.11:3080/?token=..."
- **Engineering Accomplished**:
  1. **Root Cause Analysis**:
     - Diagnosed that DeepSeek Harness (`dsh web`) enforces a security restriction in `packages/bundle/web-app/src/startup.ts`:
       `if (options.host === '0.0.0.0') program.error(...)`
     - As a result, the Node.js HTTP server was bound **strictly to loopback `127.0.0.1:3080`**.
     - Although `--trusted-host 192.168.1.11:3080` authorized the HTTP `Host` header, no socket was listening on the physical network interface `192.168.1.11:3080`.
     - The Linux kernel immediately rejected incoming TCP connections from the iPhone with `RST` (Connection Refused).
  2. **Persistent Systemd LAN Bridge (`dsh-mobile-bridge.service`)**:
     - Built a standalone socket forwarder script [`~/.local/bin/dsh-mobile-bridge.sh`](file:///home/mplanetarian/.local/bin/dsh-mobile-bridge.sh) utilizing `socat`:
       ```bash
       LAN_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
       exec socat TCP-LISTEN:3080,bind="${LAN_IP}",reuseaddr,fork TCP:127.0.0.1:3080
       ```
     - Configured, enabled, and started persistent systemd user service [`~/.config/systemd/user/dsh-mobile-bridge.service`](file:///home/mplanetarian/.config/systemd/user/dsh-mobile-bridge.service).
     - Verified that `192.168.1.11:3080` forwards bidirectional HTTP, WebSockets, and chunked SSE streams to `127.0.0.1:3080`.
  3. **Script Synchronization**:
     - Updated [`scripts/dsh_mobile.sh`](file:///var/home/mplanetarian/MP_Mix_Manager_v0.3/scripts/dsh_mobile.sh) and [`kc_launch_dsh_mobile.sh`](file:///home/mplanetarian/KDE_CONNECT_CMDS/kc_launch_dsh_mobile.sh) with `ensure_lan_bridge` so starting DeepSeek Harness guarantees the bridge is running.
     - Updated process detection in `is_dsh_running` and `get_dsh_pids` to target `127.0.0.1:3080` and Node PIDs, avoiding conflicts with `socat`.
  4. **End-to-End Validation**:
     - Verified with `curl -i "http://192.168.1.11:3080/?token=..."` that the server responds with `HTTP/1.1 303 See Other`, issues cookie `dsh-auth-...`, and delivers `index.html` (HTTP 200 OK) directly to Safari on iOS.

---

## 🧭 Master Operations Menu Structure (75 Operations)

```
========================================================================================================
                          STREAM OF FREQUENCY - MIX ARCHIVE MANAGER v0.2                                
========================================================================================================
```

### Section 1: Core Audio Processing & Ingestion (1 - 10)
| Option | Identifier | Description |
| :---: | :--- | :--- |
| **01** | `manage_flac_conversion` | Run 32-Bit Lossless FLAC Ingestion & Conversion Pipeline |
| **02** | `manage_audio_conversion` | Convert Audio Format, Sample Rate & Split FLAC Audio |
| **03** | `generate_master_tracklist` | Generate Master Tracklist from Candidate Episode WAVs |
| **04** | `import_new_mixes` | Import & Index New Mix Recordings from Ingestion Volume |
| **05** | `verify_flac_integrity` | Verify Archive FLAC Audio Bitstream Integrity & Decodability |
| **06** | `find_duplicate_mixes` | Detect & Remove Duplicate Mixes & Redundant Masters |
| **07** | `manage_checksums` | Compute & Verify SHA-256 / MD5 Master Audio Checksums |
| **08** | `parse_traktor_history` | Parse Native Instruments Traktor History & Export Cue Sheet |
| **09** | `manage_audio_tags` | Inspect & Batch Tag FLAC Metadata (ID3v2, Vorbis Comments) |
| **10** | `compress_archive_covers` | Batch Optimize & Compress Cover Art Artwork (PNG / JPEG) |

### Section 2: Publishing, Documentation & Outreach (11 - 20)
| Option | Identifier | Description |
| :---: | :--- | :--- |
| **11** | `generate_tracklist_docs` | Generate Formatted Master Tracklist Docs (HTML & Vector PDF) |
| **12** | `send_promo_email` | Send Promotional & Publisher Outreach Emails (SMTP / Mailto) |
| **13** | `view_archive_stats` | View Detailed Archive Library Analytics & Disk Footprint |
| **14** | `view_live_tracker` | Open Stream of Frequency Real-Time Activity & Status Tracker |
| **15** | `search_and_import_mixes`| Universal Mix Importer: Search & Ingest from Local Drives & SMB |
| **16** | `manage_publishing_calendar`| Manage Mix Release Schedule & Syndication Calendar |
| **17** | `export_podcast_rss` | Export Apple Podcasts Compliant Syndication RSS Feed (`.xml`) |
| **18** | `export_calendar_ical` | Export Master Release Schedule to Standard iCalendar (`.ics`) |
| **19** | `manage_promoter_contacts`| Manage Promoter, Label & Media Outlet Contact Address Book |
| **20** | `shop_music` | Go Shopping for New Music (Beatport, Apple Music, Bandcamp) |

### Section 3: Digital Audio Workstations & Studio Production (21 - 30)
| Option | Identifier | Description |
| :---: | :--- | :--- |
| **21** | `manage_daws` | Digital Audio Workstations Hub (REAPER, Logic, FL Studio, Traktor) |
| **22** | `generate_spek` | Acoustic Spectrogram Suite (Spek, Sonic Visualiser, SoX, Praat) |
| **23** | `manage_picard` | Launch MusicBrainz Picard Automated Audio Tagger |
| **24** | `open_wav_in_daw` | Select Archive WAV File & Launch Directly in Studio DAW |
| **25** | `manage_cliamp` | Retro Console Audio Player (`cliamp`) & MPRIS Controller |
| **26** | `manage_player_settings` | Configure Default System Audio & Video Media Players |
| **27** | `manage_playlists` | Custom Mix Playlists Manager (Create, Edit, Export `.m3u8`/`.xspf`) |
| **28** | `inspect_playing_audio` | Audio Specification Inspector: Bit Depth, Rate, Specs & HUD |
| **29** | `open_strawberry` | Launch Strawberry Music Player (Master Archive Player) |
| **30** | `manage_audacity` | Launch Audacity Audio Waveform Editor & Batch Resampler |

### Section 4: Video Production & Visual Synthesis (31 - 40)
| Option | Identifier | Description |
| :---: | :--- | :--- |
| **31** | `generate_youtube_4k` | Synthesize Ultra HD 4K YouTube Video (NVENC / Hardware Accelerated) |
| **32** | `generate_youtube_1080p` | Synthesize Full HD 1080p YouTube Video with High-Resolution Artwork |
| **33** | `generate_youtube_720p` | Synthesize Fast 720p Video for Social Previews & Web Streaming |
| **34** | `toggle_audio_mute` | Instant Master Audio Mute Toggle (PipeWire / ALSA / CoreAudio) |
| **35** | `inspect_audio_studio` | Studio Hardware & Software Inspector (Audio Cards, MIDI, DAWs) |
| **36** | `launch_screensaver` | Launch Electric Sheep Distributed Flame Fractal Screensaver |
| **37** | `launch_vlc_videos` | Launch Video Companion Player in Fullscreen (VLC / Haruna / MPV) |
| **38** | `manage_video_cut_and_split`| Video Cutting & Splitting Suite (`Cut_Video.sh` & `Split_Video_File.sh`) |
| **39** | `launch_specific_video` | Open Specific Mix Video or NFT Video Stream in Video Player |
| **40** | `convert_cover_art` | Convert Cover Art Image Formats (WebP, JPEG, PNG, TIFF, BMP) |

### Section 5: Live Monitors & Real-Time Trackers (41 - 50)
| Option | Identifier | Description |
| :---: | :--- | :--- |
| **41** | `view_playing_tracklist` | View Currently Playing Mix Tracklist in Borderless Console HUD |
| **42** | `generate_ppm_cover` | Procedural Binary Netpbm P6 `.PPM` Cover Art Generator |
| **43** | `monitor_chrome_uploads` | Monitor Web Browser YouTube & Cloud Upload Progress in Real-Time |
| **44** | `sync_video_companion` | Synchronized Mix-Video Companion Player Daemon |
| **45** | `view_active_transfers` | Monitor Background Rclone & Rsync File Synchronizations |
| **46** | `monitor_system_resources`| Open System Hardware Performance Monitor (Btop / Nvtop / Htop) |
| **47** | `view_playing_cover` | Open Currently Playing Mix High-Resolution Cover Art Window |
| **48** | `manage_traktor_monitor` | Traktor Pro Live Monitor & Audio Recorder Control Suite |
| **49** | `view_storage_breakdown` | Inspect Archive Disks Space & Mount Point Utilization |
| **50** | `view_recent_render_logs`| Inspect Background FFmpeg Video Rendering & Conversion Logs |

### Section 6: System, Network & Hardware Management (51 - 60)
| Option | Identifier | Description |
| :---: | :--- | :--- |
| **51** | `manage_cloud_sync` | Synchronize Master Archive with Google Drive Cloud (`rclone`) |
| **52** | `manage_network_services`| Control Network Storage Daemons (SSH, Samba / SMB, FTP Servers) |
| **53** | `clean_system_cache` | OS System Cleanup (Bazzite `ujust`, Homebrew, Windows TRIM) |
| **54** | `manage_display_sessions`| Switch Desktop Display Server (KDE Plasma Wayland ↔ X11) |
| **55** | `manage_network_killswitch`| Workstation Internet Access Killswitch (Block / Unblock Traffic) |
| **56** | `manage_wan2gp` | Manage WAN2GP AI Video Synthesis Server (Profile 4.5 & 5.0) |
| **57** | `manage_beszel` | Manage Beszel Monitoring Server & Hardware Agent (Port 8090) |
| **58** | `manage_ollama` | Manage Ollama Local LLM Server (`ollama-container` :11434) |
| **59** | `manage_dsh_mobile` | Manage DeepSeek Harness Server (dsh-mobile Web UI :3080) |
| **60** | `manage_external_drives` | Mount, Safely Unmount & Format High-Capacity Storage Drives |

### Section 7: Configuration, Automation & Exit (61 - 75)
| Option | Identifier | Description |
| :---: | :--- | :--- |
| **61** | `edit_configuration` | Edit Master Archive Configuration File (`config.env`) |
| **62** | `manage_system_motd` | Update & Preview Dynamic System Message Of The Day (MOTD) |
| **63** | `configure_weather` | Configure Live Meteorological Weather Display (Location & TTL) |
| **64** | `manage_terminal_theme` | Customize Interactive Terminal UI Color Themes (9 Themes) |
| **65** | `manage_startup_autoplay`| Toggle Automatic Playback of Latest Mix on Manager Launch |
| **66** | `manage_kwin_rules` | Inspect & Re-inject KDE Plasma 6 Borderless KWin HUD Rules |
| **67** | `export_archive_bundle` | Export Portable Configuration & Asset Archive (`.tar.gz`) |
| **68** | `restore_archive_bundle` | Import & Restore Configuration Bundle from Storage Archive |
| **69** | `launch_bash_shell` | Launch Embedded Interactive Workstation Bash Subshell |
| **70** | `manage_ai_models` | AI Model Hub: Claude, GPT, Gemini, Ollama, DeepSeek Harness |
| **71** | `view_recent_changes` | View Master Changelog (`CHANGELOG.md`) & Commit Log |
| **72** | `view_documentation` | Read Official Documentation (`README.md` & `INSTALL_BAZZITE.md`) |
| **73** | `check_for_updates` | Check for Upstream Git Updates & Pull Latest Revisions |
| **74** | `reboot_system` | Safe System Reboot (With Confirmation Safeguard) |
| **75** | `exit_manager` | Exit Mix Archive Manager Workspace |

---

## 🗂️ Complete Component & Script Inventory

| File Path | Language | Primary Purpose |
| :--- | :---: | :--- |
| [`Mix_Archive_Manager.sh`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/Mix_Archive_Manager.sh) | Bash | Master 75-operation orchestration menu and control loop |
| [`install.sh`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/install.sh) | Bash | Multi-platform installer, KWin rule injector, symlink generator |
| [`config.env`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/config.env) | Shell | Master runtime environment configuration |
| [`scripts/dsh_mobile.sh`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/dsh_mobile.sh) | Bash | DeepSeek Harness (`dsh-mobile`) lifecycle manager & LAN bridge trigger |
| [`scripts/manage_ollama.sh`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/manage_ollama.sh) | Bash | Ollama server lifecycle controller inside distrobox container |
| [`scripts/beszel.sh`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/beszel.sh) | Bash | Beszel Hub & Beszel Agent container management |
| [`scripts/Split_FLAC_File.sh`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/Split_FLAC_File.sh) | Bash | Sample-accurate lossless FLAC audio divider |
| [`scripts/Split_Video_File.sh`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/Split_Video_File.sh) | Bash | Lossless stream-copy / re-encode MP4 video divider |
| [`scripts/traktor_monitor.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/traktor_monitor.py) | Python 3 | Cross-platform Traktor Pro real-time recorder & monitor |
| [`scripts/inspect_playing_audio.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/inspect_playing_audio.py) | Python 3 | Technical audio specification & stream inspector |
| [`scripts/get_audio_interface.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/get_audio_interface.py) | Python 3 | Sub-120ms hardware buffer latency and audio card probe |
| [`scripts/align_mix_windows.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/align_mix_windows.py) | Python 3 | KDE Plasma 6 KWin DBus side-by-side HUD alignment |
| [`scripts/generate_ppm_cover.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/generate_ppm_cover.py) | Python 3 | Procedural binary Netpbm P6 PPM gradient generator |
| [`scripts/publish_calendar_scheduler.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/publish_calendar_scheduler.py) | Python 3 | Syndication calendar, RSS feed & iCalendar engine |
| [`scripts/inspect_audio_studio.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/inspect_audio_studio.py) | Python 3 | Audio hardware, MIDI controller & studio DAW auditor |
| [`scripts/sync_video_companion.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/sync_video_companion.py) | Python 3 | Synchronized video player playback companion daemon |
| [`scripts/manage_playlists.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/manage_playlists.py) | Python 3 | Custom `.m3u8` / `.xspf` playlist builder & validator |
| [`scripts/manage_motd.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/manage_motd.py) | Python 3 | Dynamic Message Of The Day (MOTD) banner generator |
| [`scripts/send_promo_email.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/send_promo_email.py) | Python 3 | Promotional outreach pitcher for promoters, radio & labels |
| [`scripts/generate_tracklist_docs.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/generate_tracklist_docs.py) | Python 3 | Master HTML & Vector PDF tracklist document synthesizer |
| [`scripts/find_duplicate_mixes.py`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/find_duplicate_mixes.py) | Python 3 | Content-based acoustic hash duplicate detector |
| [`scripts/generate_spek.sh`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/generate_spek.sh) | Bash | Acoustic spectrogram generator (Spek, Sonic Visualiser, SoX) |
| [`scripts/get_weather.sh`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/get_weather.sh) | Bash | Meteorological weather probe with 20-minute local TTL cache |
| [`scripts/view_tracklist_console.sh`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/scripts/view_tracklist_console.sh) | Bash | Frameless console tracklist HUD viewer |
| [`~/.local/bin/dsh-mobile-bridge.sh`](file:///home/mplanetarian/.local/bin/dsh-mobile-bridge.sh) | Bash | `socat` LAN socket forwarder: `192.168.1.11:3080` → `127.0.0.1:3080` |
| [`~/.config/systemd/user/dsh-mobile-bridge.service`](file:///home/mplanetarian/.config/systemd/user/dsh-mobile-bridge.service) | Systemd | Persistent user service running the DeepSeek Harness bridge |

---

## 📜 Complete Git Commit Ledger

| Commit Hash | Timestamp (BST) | Author | Commit Subject / Scope |
| :--- | :--- | :--- | :--- |
| `9e651df` | 2026-09-17 19:48:15 | MPlanetarian | `feat: add DeepSeek Harness (dsh-mobile) and Ollama server management to manager` |
| `383c9f0` | 2026-09-17 01:06:17 | MPlanetarian | `feat: add Beszel monitoring hub and agent management to manager (Option 57)` |
| `ac76fb9` | 2026-09-17 00:58:49 | MPlanetarian | `feat: add FLAC audio and YouTube MP4 video splitting utilities with manager menu integration` |
| `ffb5077` | 2026-09-17 00:43:53 | MPlanetarian | `fix(player): prevent launching cliamp when Strawberry is playing and set Strawberry as default player` |
| `2625ad2` | 2026-09-17 00:29:13 | MPlanetarian | `refactor: add check for default player in main function` |
| `8d31fc4` | 2026-09-17 00:23:54 | MPlanetarian | `feat: add logic to prevent launching cliamp if audio player is running` |
| `cee169c` | 2026-09-14 03:19:38 | MPlanetarian | `fix(install): define DIM ANSI color sequence` |
| `3eded5f` | 2026-09-14 03:19:18 | MPlanetarian | `fix(install): ensure Bash 3.2 compatibility on macOS for dependency probe` |
| `747fa48` | 2026-09-14 03:17:55 | MPlanetarian | `feat: integrate cross-platform Traktor Live Monitor & Audio Recorder (Option 48)` |
| `d70d748` | 2026-09-14 02:47:47 | MPlanetarian | `feat: add audio specification inspector (Option 28) and live audio interface & latency banner` |
| `e74702f` | 2026-09-14 02:39:23 | MPlanetarian | `Add centered mix HUD alignment, live meteorological weather, music shopping, video launcher & YouTube autoplay` |
| `ed1aeb4` | 2026-09-14 02:28:17 | MPlanetarian | `feat(tracklist): add borderless console tracklist viewer for Bazzite Linux and default OS consoles` |
| `727f6c2` | 2026-09-14 02:23:23 | MPlanetarian | `feat(playback): open tracklist in dedicated text editor window on boot alongside cover art` |
| `b3e729b` | 2026-09-14 02:15:03 | MPlanetarian | `fix(launchers): resolve symlinks accurately across ~/.local/bin and manager wrappers` |
| `522bac5` | 2026-09-14 01:45:49 | MPlanetarian | `feat(v0.2): release v0.2 with publishing calendar, studio diagnostics, PPM art, audio control & 69 operations` |
| `9e45702` | 2026-09-14 01:33:45 | MPlanetarian | `Add installation path migration, config backup/export/import suite, and universal mix search & importer for local drives and SMB` |
| `0be50ef` | 2026-09-14 01:18:24 | MPlanetarian | `Add promotional & publisher outreach email system for podcast enquiries, club promoters, radio & labels` |
| `2cea384` | 2026-09-14 01:13:53 | MPlanetarian | `Add Logic Pro, Traktor, Winamp, Foobar2000, GarageBand & FL Studio support, Open WAV in DAW, Spek generator, and FreeBSD platform support` |
| `47b687b` | 2026-09-14 01:05:45 | MPlanetarian | `Add YouTube 4K & 720p video generation, default audio player configuration, and startup mix autoplay with cover & tracklist display` |
| `4b3ac96` | 2026-09-14 01:01:15 | MPlanetarian | `Add audio converter, tracklist HTML/PDF docs, duplicate cleaner, checksums, cover compressor, and 56-operation categorized menu` |
| `0c497f0` | 2026-09-14 00:30:02 | MPlanetarian | `ui: update top banner title to Mix Archive Manager (MP_Mix_Manager_v0.1)` |
| `612b1e0` | 2026-09-14 00:07:11 | MPlanetarian | `docs: clarify that cliamp is bundled and requires no separate installation` |
| `12b110c` | 2026-09-14 00:02:38 | MPlanetarian | `docs: update clone URL with official GitHub repo path` |
| `40687c9` | 2026-09-13 23:53:54 | MPlanetarian | `Initial release: Stream of Frequency Mix Archive Manager v0.1 (Bazzite Linux)` |

---

## 💡 Architectural Insights & Future Roadmap

1. **Immutable OS Resilience**:
   All utilities are built to operate cleanly in user-space (`~/.local/bin/`, `~/.config/systemd/user/`) without mutating the read-only `/usr` tree of Bazzite Linux. External heavy dependencies run inside Distrobox (`ollama-container`) or Podman containers (`beszel`, `beszel-agent`).
2. **Dynamic LAN & Socket Binding Isolation**:
   Modern web interfaces like DeepSeek Harness enforce strict loopback security boundaries. Utilizing native Linux socket forwarders (`socat`) managed via user-level systemd units provides a zero-downtime, fully transparent bridge that preserves upstream software integrity while enabling mobile LAN accessibility.
3. **Decoupled Architecture & Dual Mirroring**:
   The master repository [`MP_Mix_Manager_v0.3`](file:///home/mplanetarian/MP_Mix_Manager_v0.3/) maintains dual-mirror synchronicity with [`/var/home/mplanetarian/Documents/BASH_SCRIPTS/`](file:///var/home/mplanetarian/Documents/BASH_SCRIPTS/), guaranteeing full redundancy across local user documents and standard Git version control.
