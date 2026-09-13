# Installing Mix Archive Manager on Bazzite Linux (From Scratch)

This document provides an exhaustive, step-by-step guide to installing and configuring the **Mix Archive Manager (`MP_Mix_Manager_v0.1`)** on a brand new, clean installation of **Bazzite Linux** (KDE Plasma Edition).

---

## 1. Understanding Bazzite Linux Architecture

Bazzite is an immutable, gaming- and workstation-optimized Linux distribution built on Fedora Atomic Desktop (Silverblue/Kinoite) using `rpm-ostree`.

Key characteristics you need to keep in mind:
- **Root Filesystem Immutability**: The system directories (`/usr`, `/bin`, `/lib`) are read-only ostree images. You do **not** use `dnf` or compile directly into `/usr/local`.
- **User Writable Areas**: Everything user-level lives under `/var/home/<username>` (symlinked to `/home/<username>`) and `~/.local/bin`.
- **Package Management Hierarchy**:
  1. **Homebrew (`brew`)**: The recommended tool on Bazzite for command-line utilities (`ffmpeg`, `sox`, `rclone`, `jq`, `btop`, `nvtop`, `wmctrl`).
  2. **Flatpak**: The standard format for GUI applications (Strawberry Music Player, VLC, Audacity).
  3. **ujust**: Bazzite's built-in system task runner (`ujust update`, `ujust clean-system`).
  4. **Python**: Managed using user-level virtual environments, `uv`, or `pip install --user`.

---

## 2. Step 1: Initial System Update & Homebrew Verification

Open **Konsole** on your fresh Bazzite install and ensure system packages and Homebrew are initialized:

```bash
# 1. Update the operating system deployment and flatpaks
ujust update

# 2. Ensure Homebrew is initialized in your PATH
test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Verify brew is available
brew --version
```

If Homebrew was not automatically installed during Bazzite setup, install it with:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Add Homebrew to your `~/.bashrc` if not already present:
```bash
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc
```

---

## 3. Step 2: Install CLI Dependencies via Homebrew

Mix Archive Manager requires high-performance audio, video, and system monitoring CLI tools. Run:

```bash
brew install \
  ffmpeg \
  flac \
  sox \
  rclone \
  jq \
  wmctrl \
  btop \
  nvtop
```

### Dependency Breakdown:
| Package | Role in Mix Manager |
| :--- | :--- |
| **`ffmpeg` / `ffprobe`** | Batch 32-bit FLAC encoding, multi-threaded decode integrity checks, audio duration extraction, and 1080p/4K YouTube video rendering. |
| **`flac`** | Native FLAC validation, tagging, and stream analysis. |
| **`sox`** | High-precision spectrogram generation and audio analysis. |
| **`rclone`** | Automated high-speed Google Drive and SMB network backup syncing. |
| **`jq`** | JSON parsing engine for `cliamp` track state, playback positions, and IPC responses. |
| **`wmctrl`** | Window management engine for Option 23 ("Close All Desktop Applications") to close external windows while safeguarding the active manager terminal. |
| **`btop`** | Advanced CPU/RAM/Drive live monitoring (Option 19). |
| **`nvtop`** | Real-time GPU utilization, VRAM, and temperature monitoring (Option 18). |

---

## 4. Step 3: Install Desktop Media Applications via Flatpak

Install Strawberry Music Player (for live MPRIS tracklist syncing), VLC, and Audacity:

```bash
flatpak install -y flathub org.strawberrymusicplayer.strawberry
flatpak install -y flathub org.videolan.VLC
flatpak install -y flathub org.audacityteam.Audacity
```

> **Tip**: Strawberry Music Player exposes MPRIS D-Bus interfaces. Mix Manager's **Live Tracklist Monitor** (`SOF_Live_Tracker.sh`) hooks directly into Strawberry via `qdbus` to display live timestamps and tracks as they play.

---

## 5. Step 4: Python Environment & Vision AI Dependencies

Mix Archive Manager utilizes Python 3 for Traktor history XML parsing, YouTube video generation, file transfer monitoring, and YOLOv8 object detection.

Install required Python dependencies:

```bash
# Ensure pip is up to date
python3 -m pip install --upgrade pip --user

# Install Pillow and Ultralytics (YOLOv8)
python3 -m pip install --user pillow ultralytics
```

Or, if using a virtual environment:
```bash
cd ~/MP_Mix_Manager_v0.1
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

## 6. Step 5: Deploy the Mix Manager Codebase

Clone or copy the codebase into your home directory under `MP_Mix_Manager_v0.1`:

```bash
cd ~
git clone https://github.com/<your-username>/MP_Mix_Manager_v0.1.git
# OR copy directory to:
# /var/home/<username>/MP_Mix_Manager_v0.1
```

Enter the codebase directory:
```bash
cd ~/MP_Mix_Manager_v0.1
```

---

## 7. Step 6: Run the Automated Installer

Run the included installer to configure permissions, generate folder scaffolds, install binary symlinks to `~/.local/bin`, set up `~/manager.sh`, and install the desktop icon:

```bash
chmod +x install.sh
./install.sh
```

### What `install.sh` Does:
1. **Validates OS**: Confirms Bazzite / Atomic Linux environment.
2. **Permission Setting**: Sets executable flags (`chmod +x`) on all bash scripts, Python tools, and `bin/cliamp`.
3. **Folder Scaffolds**: Creates working directories (`FLAC_CONVERTED_OUTPUTS`, `CONVERTED_WAV_FILES`, `SPEK_OUTPUTS`, `BACKUP_LOGS`, `VERIFY_LOGS`, `IMPORT_LOGS`, `COVERS`) with `.gitkeep` markers.
4. **Symlinks**: Installs helper commands into `~/.local/bin`:
   - `cliamp` (Retro terminal audio player)
   - `mix-archive-manager` (CLI launcher)
   - `manager` (Short alias)
   - `launch-manager-fullscreen` (Full-screen Konsole wrapper)
   - `transfer-monitor` (Live file write inspector)
   - `chrome-upload-monitor` (Web/Podcast upload tracker)
   - `list-midi-devices` (USB MIDI device enumerator)
   - `cut-video` (Precision start/end video cutter)
   - `~/manager.sh` (Home directory direct launcher)
5. **Desktop Entry**: Installs `Mix_Archive_Manager.desktop` into `~/.local/share/applications/` and onto your Desktop.

---

## 8. Step 7: Configure Environment Paths (`config.env`)

Copy the template configuration and customize it for your storage layout:

```bash
cp config.env.example config.env
nano config.env
```

### Key Configuration Variables:
```bash
# Path to your external SSD / HDD archive mount
# Defaults to current directory if not found
MIX_ARCHIVE_DIR="/run/media/$USER/WD BLACK B/MIX_ARCHIVE"

# Directory where Traktor saves session playlists
TRAKTOR_HISTORY_DIR="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/Traktor 3.11.1/History"

# Google Drive remote configured in rclone
GDRIVE_REMOTE="gdrive:MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"

# Video directory for auto-generating playlists
NFT_VIDEOS_DIR="/run/media/$USER/DATA/NFT_VIDEOS"
```

---

## 9. Step 8: Sudoers Configuration for Firewall & Maintenance

Options 24/25 (**Block/Unblock Internet Access**) require root privileges to load and purge an isolated nftables table (`inet lanonly`).

To allow running this without entering your password each time, configure a sudoers drop-in:

```bash
sudo visudo -f /etc/sudoers.d/mix-manager
```

Add the following lines (replace `<username>` with your Bazzite username):
```sudoers
<username> ALL=(ALL) NOPASSWD: /usr/sbin/nft
<username> ALL=(ALL) NOPASSWD: /usr/sbin/fstrim
<username> ALL=(ALL) NOPASSWD: /usr/bin/systemctl start sshd, /usr/bin/systemctl stop sshd, /usr/bin/systemctl restart sshd
<username> ALL=(ALL) NOPASSWD: /usr/bin/systemctl start smb, /usr/bin/systemctl stop smb, /usr/bin/systemctl restart smb
<username> ALL=(ALL) NOPASSWD: /usr/bin/systemctl start vsftpd, /usr/bin/systemctl stop vsftpd, /usr/bin/systemctl restart vsftpd
```

---

## 10. Step 9: Launching & Verification

You can now launch the Mix Archive Manager in three ways:

### Method A: From Terminal Anywhere
```bash
manager
# or:
~/manager.sh
```

### Method B: From Codebase Directory
```bash
cd ~/MP_Mix_Manager_v0.1
./Mix_Archive_Manager.sh
```

### Method C: Graphical Desktop / Application Menu
- Click the **Mix Archive Manager** icon on your Desktop.
- Or open Application Launcher -> **Multimedia** -> **Mix Archive Manager**.

---

## 11. Testing Core Features on First Launch

1. **Top Dashboard**: Verify WAV and FLAC counts display accurately in the header.
2. **`cliamp` Music Player (Option 20)**: Launch cliamp to test playback, then exit with `q` or leave playing in background. Verify the header displays live track and position information.
3. **Live Tracklist Monitor (Option 4)**: Play a track in Strawberry or cliamp and ensure the live progress bar and tracklist sync in real time.
4. **Integrity Check (Option 8)**: Run `Verify_FLAC_Files.sh` across your FLAC directory to test multi-core FFmpeg validation.
5. **Video Trimming (Option 35)**: Run `Cut_Video.sh` on an `.mp4` or `.mkv` file to verify FFmpeg cutting and automatic file manager folder opening.
6. **System Maintenance (Option 32)**: Test `ujust clean-system` and SSD trim via submenu 32.
