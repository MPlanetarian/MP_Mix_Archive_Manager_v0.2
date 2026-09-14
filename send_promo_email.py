#!/usr/bin/env python3
"""
send_promo_email.py - Promotional & Publisher Outreach Email System
Part of Mix Archive Manager (MP_Mix_Manager_v0.2)

Automates professional outreach to promoters, event organizers, podcast publishers,
radio syndicators, record labels, and dance music media with rich HTML & Plaintext
emails, episode artwork, tracklists, and streaming media links.
"""

import os
import sys
import re
import json
import csv
import time
import ssl
import smtplib
import mimetypes
import tempfile
import argparse
import subprocess
import urllib.parse
from datetime import datetime
from email import utils as email_utils
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email.mime.image import MIMEImage
from email import encoders

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = SCRIPT_DIR
CONTACTS_FILE = os.path.join(PROJECT_ROOT, "assets", "promo_contacts.json")
LOGS_DIR = os.path.join(PROJECT_ROOT, "assets", "promo_logs")
SENT_LOG_JSON = os.path.join(LOGS_DIR, "sent_promo_emails.json")
SENT_LOG_TXT = os.path.join(LOGS_DIR, "sent_promo_emails.log")


# ==============================================================================
# CONFIGURATION LOADER
# ==============================================================================
def load_config():
    """Loads configuration from config.env or environment variables."""
    cfg = {
        "MIX_ARCHIVE_DIR": "/run/media/{user}/WD BLACK B/MIX_ARCHIVE".format(user=os.environ.get("USER", "mplanetarian")),
        "OUTPUT_DIR": "FLAC_CONVERTED_OUTPUTS",
        "COVERS_DIR": "COVERS",
        "SPEK_DIR": "SPEK_OUTPUTS",
        "SMTP_HOST": os.environ.get("SMTP_HOST", ""),
        "SMTP_PORT": int(os.environ.get("SMTP_PORT", "587")),
        "SMTP_USER": os.environ.get("SMTP_USER", ""),
        "SMTP_PASSWORD": os.environ.get("SMTP_PASSWORD", ""),
        "SMTP_USE_TLS": os.environ.get("SMTP_USE_TLS", "true").lower() in ("true", "1", "yes"),
        "SMTP_USE_SSL": os.environ.get("SMTP_USE_SSL", "false").lower() in ("true", "1", "yes"),
        "PROMO_SENDER_NAME": os.environ.get("PROMO_SENDER_NAME", "MPlanetarian"),
        "PROMO_SENDER_EMAIL": os.environ.get("PROMO_SENDER_EMAIL", ""),
        "PROMO_REPLY_TO": os.environ.get("PROMO_REPLY_TO", ""),
        "PROMO_PODCAST_URL": os.environ.get("PROMO_PODCAST_URL", "https://podcasts.apple.com"),
        "PROMO_SOUNDCLOUD_URL": os.environ.get("PROMO_SOUNDCLOUD_URL", "https://soundcloud.com/mplanetarian"),
        "PROMO_YOUTUBE_URL": os.environ.get("PROMO_YOUTUBE_URL", "https://youtube.com/@mplanetarian"),
        "PROMO_MIXCLOUD_URL": os.environ.get("PROMO_MIXCLOUD_URL", "https://mixcloud.com/mplanetarian"),
        "PROMO_WEBSITE_URL": os.environ.get("PROMO_WEBSITE_URL", "https://mplanetarian.com"),
        "PROMO_BIO": (
            "MPlanetarian is an electronic music producer, DJ, and sound designer curating the 'Stream of Frequency' "
            "audiophile mix series. Spanning deep progressive, melodic journey trance, and driving uplifting sounds, "
            "each episode is mastered in pristine 32-bit lossless audio accompanied by comprehensive tracklists and 4K visuals."
        ),
        "PROMO_TECH_RIDER": (
            "Standard Rider: 3x Pioneer CDJ-3000 / CDJ-2000NXS2 + 1x Pioneer DJM-A9 / DJM-900NXS2 mixer linked via Ethernet hub; "
            "or Traktor Pro 3/4 setup with Native Instruments Traktor Kontrol X1/Z2 + stereo audio interface. High-grade booth monitors."
        )
    }

    env_paths = [
        os.path.join(PROJECT_ROOT, "config.env"),
        os.path.join(os.path.dirname(PROJECT_ROOT), "config.env"),
        os.path.expanduser("~/.config/mix-manager/config.env")
    ]

    for p in env_paths:
        if os.path.isfile(p):
            try:
                with open(p, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#") or "=" not in line:
                            continue
                        k, v = line.split("=", 1)
                        k = k.strip()
                        v = v.strip().strip('"').strip("'")
                        if k in cfg:
                            if k == "SMTP_PORT":
                                try:
                                    cfg[k] = int(v)
                                except ValueError:
                                    pass
                            elif k in ("SMTP_USE_TLS", "SMTP_USE_SSL"):
                                cfg[k] = v.lower() in ("true", "1", "yes")
                            else:
                                cfg[k] = v
            except Exception:
                pass
            break

    # Fallback sender email
    if not cfg["PROMO_SENDER_EMAIL"] and cfg["SMTP_USER"] and "@" in cfg["SMTP_USER"]:
        cfg["PROMO_SENDER_EMAIL"] = cfg["SMTP_USER"]
    if not cfg["PROMO_REPLY_TO"]:
        cfg["PROMO_REPLY_TO"] = cfg["PROMO_SENDER_EMAIL"]

    return cfg


# ==============================================================================
# CONTACT BOOK MANAGEMENT
# ==============================================================================
DEFAULT_SEED_CONTACTS = [
    {
        "id": "pub-001",
        "name": "Apple Podcasts Editorial & Curation Team",
        "email": "podcast_curation@apple.com",
        "organization": "Apple Podcasts",
        "category": "publisher",
        "notes": "Feature requests for electronic / music podcast editorial placement",
        "last_contacted": ""
    },
    {
        "id": "pub-002",
        "name": "DI.FM Programming & Channel Directors",
        "email": "programming@di.fm",
        "organization": "Digitally Imported Radio (DI.FM)",
        "category": "publisher",
        "notes": "Syndication submissions for Trance, Progressive, and Vocal Chillout channels",
        "last_contacted": ""
    },
    {
        "id": "pub-003",
        "name": "Proton Radio Curations",
        "email": "curators@protonradio.com",
        "organization": "Proton Radio Network",
        "category": "publisher",
        "notes": "Electronic podcast syndication and featured resident guest mix channel",
        "last_contacted": ""
    },
    {
        "id": "pro-001",
        "name": "Talent & Booking Department",
        "email": "bookings@clubspace.com",
        "organization": "Club Space Miami",
        "category": "promoter",
        "notes": "Terrace & Club bookings; progressive / melodic journey trance sets",
        "last_contacted": ""
    },
    {
        "id": "pro-002",
        "name": "Luminosity Events Artist Coordination",
        "email": "info@luminosity-events.nl",
        "organization": "Luminosity Beach Festival",
        "category": "promoter",
        "notes": "Pure trance & progressive festival stages; Netherlands",
        "last_contacted": ""
    },
    {
        "id": "pro-003",
        "name": "Ministry of Sound Events Team",
        "email": "events@ministryofsound.com",
        "organization": "Ministry of Sound London",
        "category": "promoter",
        "notes": "Main room & The Box guest mixes and event support",
        "last_contacted": ""
    },
    {
        "id": "rad-001",
        "name": "A State of Trance Guest Mix Desk",
        "email": "promos@astateoftrance.com",
        "organization": "Armada Music / ASOT Radio",
        "category": "radio",
        "notes": "Track features and service mix submissions",
        "last_contacted": ""
    },
    {
        "id": "lbl-001",
        "name": "Anjunabeats A&R & Radio Desk",
        "email": "contact@anjunabeats.com",
        "organization": "Anjunabeats / Involved Group",
        "category": "label",
        "notes": "Track support feedback and Anjunabeats Worldwide guest mix pitch",
        "last_contacted": ""
    },
    {
        "id": "prs-001",
        "name": "DJ Mag Reviews & Podcasts Editor",
        "email": "editorial@djmag.com",
        "organization": "DJ Magazine",
        "category": "press",
        "notes": "Podcast of the month submissions and feature interviews",
        "last_contacted": ""
    }
]


def load_contacts(contacts_file=CONTACTS_FILE):
    """Loads contacts from JSON file, initializing with seeds if not present."""
    if not os.path.isfile(contacts_file):
        os.makedirs(os.path.dirname(contacts_file), exist_ok=True)
        try:
            with open(contacts_file, "w", encoding="utf-8") as f:
                json.dump(DEFAULT_SEED_CONTACTS, f, indent=2)
            return list(DEFAULT_SEED_CONTACTS)
        except Exception:
            return list(DEFAULT_SEED_CONTACTS)

    try:
        with open(contacts_file, "r", encoding="utf-8", errors="ignore") as f:
            data = json.load(f)
            if isinstance(data, list):
                return data
            return list(DEFAULT_SEED_CONTACTS)
    except Exception:
        return list(DEFAULT_SEED_CONTACTS)


def save_contacts(contacts, contacts_file=CONTACTS_FILE):
    """Saves contacts list to JSON file."""
    os.makedirs(os.path.dirname(contacts_file), exist_ok=True)
    with open(contacts_file, "w", encoding="utf-8") as f:
        json.dump(contacts, f, indent=2)


def add_contact(name, email, organization="", category="promoter", notes="", contacts_file=CONTACTS_FILE):
    """Adds a new contact to the address book."""
    contacts = load_contacts(contacts_file)
    contact_id = f"{category[:3]}-{len(contacts)+1:03d}"
    new_contact = {
        "id": contact_id,
        "name": name.strip(),
        "email": email.strip(),
        "organization": organization.strip(),
        "category": category.strip().lower(),
        "notes": notes.strip(),
        "last_contacted": ""
    }
    contacts.append(new_contact)
    save_contacts(contacts, contacts_file)
    return new_contact


def find_contacts(query=None, category=None, contacts_file=CONTACTS_FILE):
    """Filters contacts by keyword query and/or category."""
    contacts = load_contacts(contacts_file)
    filtered = []
    q = (query or "").lower().strip()
    cat = (category or "").lower().strip()

    for c in contacts:
        if cat and cat != "all" and c.get("category", "").lower() != cat:
            continue
        if q:
            searchable = " ".join([
                c.get("name", ""),
                c.get("email", ""),
                c.get("organization", ""),
                c.get("notes", ""),
                c.get("category", "")
            ]).lower()
            if q not in searchable:
                continue
        filtered.append(c)
    return filtered


def update_contact_timestamp(email_addr, contacts_file=CONTACTS_FILE):
    """Updates last_contacted ISO timestamp for an email address."""
    contacts = load_contacts(contacts_file)
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    updated = False
    for c in contacts:
        if c.get("email", "").lower().strip() == email_addr.lower().strip():
            c["last_contacted"] = now_str
            updated = True
    if updated:
        save_contacts(contacts, contacts_file)


# ==============================================================================
# EPISODE & ASSET RESOLVER
# ==============================================================================
def resolve_episode_assets(query, config=None):
    """
    Searches for an episode and locates its FLAC, WAV, tracklist .txt,
    cover art (including 1MB version), and Spek spectrogram.
    """
    if config is None:
        config = load_config()

    archive_dir = config["MIX_ARCHIVE_DIR"]
    flac_dir = os.path.join(archive_dir, config["OUTPUT_DIR"])
    covers_dir = os.path.join(archive_dir, config["COVERS_DIR"])
    spek_dir = os.path.join(archive_dir, config["SPEK_DIR"])

    # Fallback to local working directories if archive drive isn't mounted
    if not os.path.isdir(archive_dir):
        flac_dir = os.path.join(PROJECT_ROOT, "FLAC_CONVERTED_OUTPUTS")
        covers_dir = os.path.join(PROJECT_ROOT, "COVERS")
        spek_dir = os.path.join(PROJECT_ROOT, "SPEK_OUTPUTS")

    info = {
        "episode_number": "",
        "episode_title": "",
        "full_title": "",
        "tracklist_file": "",
        "flac_file": "",
        "cover_file": "",
        "spek_file": "",
        "tracks": [],
        "track_count": 0,
        "duration_str": "Approx 1 to 2 Hours",
        "artist": config["PROMO_SENDER_NAME"],
        "show": "Stream of Frequency"
    }

    q_str = str(query).strip()

    # Look for candidate tracklist or flac files
    candidates = []
    if os.path.isdir(flac_dir):
        for f in os.listdir(flac_dir):
            if f.endswith(".txt") or f.endswith(".flac"):
                candidates.append(os.path.join(flac_dir, f))

    # Match candidate
    match_file = None
    if os.path.isfile(q_str):
        match_file = q_str
    elif q_str:
        num_clean = re.sub(r"[^\d]", "", q_str)
        # 1. Exact regex search for episode number
        if num_clean:
            pat = re.compile(r'(?:Stream[_\s]+of[_\s]+Frequency|SOF)[_\s]+0*' + re.escape(str(int(num_clean))) + r'(?:[_\s\.\-]|$)|\b0*' + re.escape(str(int(num_clean))) + r'\b', re.IGNORECASE)
            for c in sorted(candidates, reverse=True):
                if pat.search(os.path.basename(c)):
                    match_file = c
                    break

        # 2. Substring search if no exact regex match
        if not match_file:
            for c in sorted(candidates, reverse=True):
                b = os.path.basename(c)
                if q_str.lower() in b.lower():
                    match_file = c
                    break

    if not match_file and candidates:
        match_file = candidates[0]

    if match_file:
        base_no_ext = os.path.splitext(match_file)[0]
        base_name = os.path.basename(base_no_ext)

        # Look for tracklist
        txt_path = base_no_ext + ".txt"
        if os.path.isfile(txt_path):
            info["tracklist_file"] = txt_path
            parse_tracklist_into_info(txt_path, info)

        # Look for FLAC
        flac_path = base_no_ext + ".flac"
        if os.path.isfile(flac_path):
            info["flac_file"] = flac_path

        # Parse episode number and title from basename if not yet set
        m = re.search(r'(?:Stream[_\s]+of[_\s]+Frequency|SOF)[_\s]+(\d+)(?:[_\s]+|\s*[-–]\s*)(.+)?', base_name, re.IGNORECASE)
        if m:
            info["episode_number"] = m.group(1).zfill(3)
            raw_title = m.group(2) or ""
            raw_title = re.sub(r'^[_\-\s]+|[_\-\s]+$', '', raw_title).replace('_', ' ')
            info["episode_title"] = raw_title
        elif not info["episode_number"]:
            m_num = re.search(r'(\d{2,3})', base_name)
            if m_num:
                info["episode_number"] = m_num.group(1).zfill(3)

        if not info["episode_title"]:
            info["episode_title"] = base_name.replace('_', ' ')

        info["full_title"] = f"Stream of Frequency {info['episode_number']} - {info['episode_title']}"

    # Search for matching cover art
    if os.path.isdir(covers_dir):
        cover_candidates = os.listdir(covers_dir)
        ep_num = info["episode_number"]
        chosen_cover = None
        if ep_num:
            ep_int = int(ep_num)
            cover_pat = re.compile(r'(?:^|[_\s\-\(])0*' + re.escape(str(ep_int)) + r'(?:[_\s\-\)]|$)', re.IGNORECASE)
            for cv in cover_candidates:
                if not cv.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
                    continue
                if cover_pat.search(cv):
                    if "1mb" in cv.lower():
                        chosen_cover = os.path.join(covers_dir, cv)
                        break
                    elif not chosen_cover:
                        chosen_cover = os.path.join(covers_dir, cv)

        if not chosen_cover and cover_candidates:
            for cv in cover_candidates:
                if cv.lower().endswith((".jpg", ".jpeg", ".png")):
                    chosen_cover = os.path.join(covers_dir, cv)
                    break

        if chosen_cover:
            info["cover_file"] = chosen_cover

    # Search for matching Spek
    if os.path.isdir(spek_dir):
        for sp in os.listdir(spek_dir):
            if sp.lower().endswith(".png"):
                if info["episode_number"] and info["episode_number"] in sp:
                    info["spek_file"] = os.path.join(spek_dir, sp)
                    break

    return info


def parse_tracklist_into_info(txt_path, info):
    """Parses .txt tracklist lines into tracks array and summary."""
    tracks = []
    try:
        with open(txt_path, "r", encoding="utf-8", errors="ignore") as f:
            in_tracklist = False
            for line in f:
                s = line.strip()
                if not s or s.startswith("=") or s.startswith("---"):
                    continue
                if "TRACKLIST" in s.upper() or "TRACK LIST" in s.upper():
                    in_tracklist = True
                    continue
                if s.startswith("Artist:") or s.startswith("Album:") or s.startswith("Title:") or s.startswith("Conversion Date:"):
                    continue
                if in_tracklist or re.match(r'^\d+[\.\-\)]', s):
                    m = re.match(r'^(\d+)[\.\-\)]\s*(?:\[([\d:]+)\])?\s*(.*)$', s)
                    if m:
                        num = m.group(1).zfill(2)
                        time_stamp = m.group(2) or ""
                        track_name = m.group(3).strip()
                        if track_name and not track_name.startswith("="):
                            tracks.append({
                                "number": num,
                                "time": time_stamp,
                                "title": track_name
                            })
                    elif not s.startswith("="):
                        tracks.append({
                            "number": f"{len(tracks)+1:02d}",
                            "time": "",
                            "title": s
                        })
    except Exception:
        pass

    info["tracks"] = tracks
    info["track_count"] = len(tracks)


# ==============================================================================
# TEMPLATE ENGINE (HTML + PLAINTEXT)
# ==============================================================================
TEMPLATES = {
    "podcast_publisher": {
        "name": "Podcast Network & Syndication Pitch",
        "description": "Pitch 'Stream of Frequency' to podcast publishers, syndicators, and aggregators (Apple Podcasts, DI.FM, Spotify, Proton).",
        "default_subject": "Podcast Syndication Enquiry: Stream of Frequency with MPlanetarian [EP {episode_number}]",
        "target_category": "publisher"
    },
    "promoter_booking": {
        "name": "Promoter & Club / Festival Booking Enquiry",
        "description": "DJ booking enquiry and guest mix showcase for club promoters, event coordinators, and festival scouts.",
        "default_subject": "DJ Booking & Guest Mix Enquiry: MPlanetarian [Stream of Frequency {episode_number}]",
        "target_category": "promoter"
    },
    "episode_promo": {
        "name": "New Episode Promotional Release & Press Blast",
        "description": "Announce the latest episode to dance music journalists, reviewers, curators, and subscribers.",
        "default_subject": "PROMO RELEASE: Stream of Frequency {episode_number} - {episode_title} [Mixed by MPlanetarian]",
        "target_category": "press"
    },
    "track_support": {
        "name": "Producer & Record Label Track Support Courtesy",
        "description": "Notify artists and record labels that their track was featured in the latest mix with timestamps and cues.",
        "default_subject": "Track Support Notification: Your release featured in Stream of Frequency {episode_number}",
        "target_category": "label"
    },
    "radio_guestmix": {
        "name": "Radio Station Guest Mix & Syndication Submission",
        "description": "Submit a broadcast-ready guest mix or regular syndicated show proposal to FM/DAB/Internet radio stations.",
        "default_subject": "Radio Guest Mix Submission: Stream of Frequency {episode_number} - MPlanetarian",
        "target_category": "radio"
    },
    "custom": {
        "name": "Custom / Blank Outreach Email",
        "description": "Full interactive blank canvas with dynamic macro substitutions.",
        "default_subject": "Enquiry regarding Stream of Frequency - MPlanetarian",
        "target_category": "all"
    }
}


def build_tracklist_html(tracks):
    """Generates an HTML table representing the tracklist."""
    if not tracks:
        return "<p style='color: #94a3b8; font-style: italic;'>Full tracklist available upon request or in the attached documentation.</p>"

    html_rows = []
    for t in tracks:
        time_badge = f"<span style='color: #38bdf8; font-family: monospace; font-size: 11px; background: #0f172a; padding: 2px 6px; border-radius: 4px; margin-right: 8px;'>{t['time']}</span>" if t['time'] else ""
        html_rows.append(
            f"<tr>"
            f"<td style='padding: 6px 10px; border-bottom: 1px solid #334155; color: #94a3b8; width: 30px; font-family: monospace;'>{t['number']}</td>"
            f"<td style='padding: 6px 10px; border-bottom: 1px solid #334155; color: #f1f5f9;'>{time_badge}{t['title']}</td>"
            f"</tr>"
        )
    return (
        "<table style='width: 100%; border-collapse: collapse; font-size: 13px; margin: 12px 0; background: #1e293b; border-radius: 6px; overflow: hidden;'>"
        + "".join(html_rows)
        + "</table>"
    )


def build_tracklist_plaintext(tracks):
    """Generates a clean plaintext tracklist."""
    if not tracks:
        return "Full tracklist available upon request or in the attached file."
    lines = []
    for t in tracks:
        ts = f"[{t['time']}] " if t['time'] else ""
        lines.append(f"{t['number']}. {ts}{t['title']}")
    return "\n".join(lines)


def render_email_content(template_id, context):
    """
    Renders both Plaintext and HTML email bodies for a specified template.
    Returns: (subject, text_body, html_body)
    """
    cfg = context.get("config", {})
    t_info = TEMPLATES.get(template_id, TEMPLATES["custom"])

    # Extract tokens
    recip_name = context.get("recipient_name", "Friend")
    recip_org = context.get("organization", "your team")
    sender_name = cfg.get("PROMO_SENDER_NAME", "MPlanetarian")
    sender_email = cfg.get("PROMO_SENDER_EMAIL", "")
    ep_num = context.get("episode_number", "041")
    ep_title = context.get("episode_title", "Cosmic Dreamworlds")
    stream_url = context.get("stream_url") or cfg.get("PROMO_SOUNDCLOUD_URL", "")
    podcast_url = cfg.get("PROMO_PODCAST_URL", "")
    youtube_url = cfg.get("PROMO_YOUTUBE_URL", "")
    soundcloud_url = cfg.get("PROMO_SOUNDCLOUD_URL", "")
    bio = cfg.get("PROMO_BIO", "")
    rider = cfg.get("PROMO_TECH_RIDER", "")
    tracks = context.get("tracks", [])
    custom_msg = context.get("custom_message", "").strip()
    date_str = datetime.now().strftime("%B %d, %Y")

    tl_plain = build_tracklist_plaintext(tracks)
    tl_html = build_tracklist_html(tracks)
    track_count = len(tracks)

    subject_pattern = context.get("subject") or t_info["default_subject"]
    subject = subject_pattern.format(
        recipient_name=recip_name,
        organization=recip_org,
        sender_name=sender_name,
        episode_number=ep_num,
        episode_title=ep_title
    )

    # --------------------------------------------------------------------------
    # 1. PODCAST NETWORK & SYNDICATION PITCH
    # --------------------------------------------------------------------------
    if template_id == "podcast_publisher":
        text_body = f"""Dear {recip_name} and the {recip_org} editorial team,

I hope this email finds you well.

My name is {sender_name}, and I am reaching out to introduce our audiophile electronic music podcast series, 'Stream of Frequency', for consideration regarding syndication, distribution, or featured editorial placement on {recip_org}.

ABOUT THE SERIES:
'Stream of Frequency' is a masterfully curated journey bridging melodic progressive house, deep organic grooves, and driving uplifting trance. Each episode is engineered with meticulous attention to transitions and mastered at high resolution (32-bit lossless FLAC), accompanied by comprehensive cue tracklists, acoustic spectrograms, and 4K visual accompaniments.

LATEST SHOWCASE:
Episode: Stream of Frequency {ep_num} - {ep_title}
Selection: {track_count} Curated Works
Streaming Link: {stream_url}
Podcast Feed: {podcast_url}
YouTube 4K: {youtube_url}

TRACKLIST HIGHLIGHTS:
{tl_plain}

WHY IT FITS {recip_org.upper()}:
- Consistent, dependable delivery and verified high audio quality standards.
- Dedicated listener engagement across progressive, melodic, and trance demographics.
- Full rights clarity and complete track attribution for all featured artists and labels.

{f"NOTE:\n{custom_msg}\n\n" if custom_msg else ""}We would be thrilled to provide a dedicated syndication package, bespoke station IDs, or exclusive guest editions tailored to {recip_org}.

Thank you very much for your time and consideration.

Warm regards,

{sender_name}
Creator & DJ, Stream of Frequency
Email: {sender_email}
SoundCloud: {soundcloud_url}
Podcast: {podcast_url}
"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0b0f19; color: #e2e8f0; margin: 0; padding: 24px; }}
    .container {{ max-width: 680px; margin: 0 auto; background-color: #1e293b; border-radius: 12px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }}
    .header {{ background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 50%, #0369a1 100%); padding: 32px 28px; text-align: left; border-bottom: 2px solid #38bdf8; }}
    .header h1 {{ margin: 0 0 8px 0; font-size: 24px; color: #ffffff; letter-spacing: 0.5px; }}
    .header .subtitle {{ margin: 0; color: #94a3b8; font-size: 14px; font-weight: 500; text-transform: uppercase; letter-spacing: 1.5px; }}
    .content {{ padding: 28px; line-height: 1.6; font-size: 15px; }}
    .badge {{ display: inline-block; background: #0284c7; color: white; padding: 3px 10px; border-radius: 20px; font-size: 12px; font-weight: bold; margin-right: 6px; }}
    .btn {{ display: inline-block; background: #0284c7; color: #ffffff !important; text-decoration: none; padding: 12px 22px; border-radius: 8px; font-weight: 600; font-size: 14px; margin: 8px 8px 8px 0; transition: background 0.2s; }}
    .card {{ background: #0f172a; border-left: 4px solid #38bdf8; padding: 16px 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }}
    .footer {{ background: #0f172a; padding: 20px 28px; font-size: 13px; color: #64748b; border-top: 1px solid #334155; }}
    a {{ color: #38bdf8; text-decoration: none; }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <p class="subtitle">Stream of Frequency &bull; Podcast Syndication Enquiry</p>
      <h1>Stream of Frequency with {sender_name}</h1>
    </div>
    <div class="content">
      <p>Dear <strong>{recip_name}</strong> and the <strong>{recip_org}</strong> editorial team,</p>
      <p>I hope this email finds you well.</p>
      <p>My name is <strong>{sender_name}</strong>, and I am reaching out to introduce our audiophile electronic music podcast series, <em>Stream of Frequency</em>, for consideration regarding syndication, distribution, or featured placement on <strong>{recip_org}</strong>.</p>
      
      <div class="card">
        <h3 style="margin: 0 0 10px 0; color: #38bdf8; font-size: 16px;">Latest Showcase: Episode {ep_num} &mdash; {ep_title}</h3>
        <p style="margin: 0 0 6px 0; font-size: 14px; color: #cbd5e1;">Mastered in 32-bit Audiophile Lossless FLAC &bull; {track_count} Curated Works</p>
        <div style="margin-top: 14px;">
          <a class="btn" href="{stream_url}">🎧 Listen to Showcase Mix</a>
          <a class="btn" style="background: #475569;" href="{podcast_url}">🎙 Apple Podcasts Feed</a>
          <a class="btn" style="background: #991b1b;" href="{youtube_url}">📺 YouTube 4K Video</a>
        </div>
      </div>

      <h3 style="color: #f1f5f9; margin-top: 24px; font-size: 16px;">Tracklist &amp; Featured Artists:</h3>
      {tl_html}

      {f"<div class='card' style='border-left-color: #f59e0b;'><p style='margin:0;'><strong>Special Note:</strong> {custom_msg}</p></div>" if custom_msg else ""}

      <h3 style="color: #f1f5f9; margin-top: 24px; font-size: 16px;">Why Stream of Frequency Fits {recip_org}:</h3>
      <ul>
        <li><strong>Uncompromising Quality:</strong> Lossless 32-bit mastering and clean transitions crafted for audiophile listeners.</li>
        <li><strong>Editorial Integrity:</strong> Full tracklist transparency with complete attribution for all producers and labels.</li>
        <li><strong>Reliability:</strong> Consistent production cadence and bespoke station drops/intros available on demand.</li>
      </ul>

      <p>We would love to discuss syndication options or providing custom guest mixes for your network. Looking forward to hearing your thoughts.</p>
      <p>Warm regards,<br><strong>{sender_name}</strong><br><span style="color: #94a3b8; font-size: 13px;">Creator &amp; Host, Stream of Frequency</span></p>
    </div>
    <div class="footer">
      <p style="margin: 0;">Sent on {date_str} to {recip_name} ({recip_org}) &bull; Inquiries: <a href="mailto:{sender_email}">{sender_email}</a></p>
      <p style="margin: 6px 0 0 0;"><a href="{soundcloud_url}">SoundCloud</a> &bull; <a href="{youtube_url}">YouTube</a> &bull; <a href="{podcast_url}">Apple Podcasts</a></p>
    </div>
  </div>
</body>
</html>
"""

    # --------------------------------------------------------------------------
    # 2. PROMOTER & CLUB / FESTIVAL BOOKING ENQUIRY
    # --------------------------------------------------------------------------
    elif template_id == "promoter_booking":
        text_body = f"""Hi {recip_name},

I hope you are having a fantastic week.

I am writing to you on behalf of {sender_name} to inquire about upcoming booking opportunities and guest DJ slots at {recip_org}.

ARTIST OVERVIEW:
{bio}

SOUND & SELECTION:
Specializing in melodic journey trance, progressive house, and euphoric peak-time energy. Sets are dynamic, emotive, and tailored to build an electric atmosphere on the dance floor.

LIVE SHOWCASE MIX:
Mix: Stream of Frequency {ep_num} - {ep_title}
Listen: {stream_url}
Tracklist ({track_count} tracks):
{tl_plain}

TECHNICAL SETUP & RIDER:
{rider}

{f"NOTE FOR {recip_org.upper()}:\n{custom_msg}\n\n" if custom_msg else ""}High-resolution press photos, logos, and technical documentation are attached or available at:
{cfg.get("PROMO_WEBSITE_URL", "")}

We would love to collaborate for an upcoming date or guest mix session. Please let us know if you need any additional promotional assets or schedule availability.

Thank you for your consideration!

Best regards,

{sender_name}
Direct Email: {sender_email}
SoundCloud: {soundcloud_url}
YouTube: {youtube_url}
"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0b0f19; color: #e2e8f0; margin: 0; padding: 24px; }}
    .container {{ max-width: 680px; margin: 0 auto; background-color: #1e293b; border-radius: 12px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }}
    .header {{ background: linear-gradient(135deg, #1e1b4b 0%, #4338ca 50%, #7c3aed 100%); padding: 32px 28px; text-align: left; border-bottom: 2px solid #a855f7; }}
    .header h1 {{ margin: 0 0 8px 0; font-size: 24px; color: #ffffff; }}
    .header .subtitle {{ margin: 0; color: #cbd5e1; font-size: 13px; font-weight: bold; text-transform: uppercase; letter-spacing: 1.5px; }}
    .content {{ padding: 28px; line-height: 1.6; font-size: 15px; }}
    .btn {{ display: inline-block; background: #7c3aed; color: #ffffff !important; text-decoration: none; padding: 12px 22px; border-radius: 8px; font-weight: 600; font-size: 14px; margin: 8px 8px 8px 0; }}
    .card {{ background: #0f172a; border-left: 4px solid #a855f7; padding: 16px 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }}
    .footer {{ background: #0f172a; padding: 20px 28px; font-size: 13px; color: #64748b; border-top: 1px solid #334155; }}
    a {{ color: #c084fc; text-decoration: none; }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <p class="subtitle">DJ Booking &amp; Event Enquiry &bull; {recip_org}</p>
      <h1>{sender_name} [Stream of Frequency]</h1>
    </div>
    <div class="content">
      <p>Hi <strong>{recip_name}</strong>,</p>
      <p>I hope you're doing well! I'm reaching out to introduce <strong>{sender_name}</strong> and explore potential booking opportunities, guest DJ slots, or event support at <strong>{recip_org}</strong>.</p>

      <div class="card">
        <h3 style="margin: 0 0 8px 0; color: #c084fc; font-size: 16px;">Sound &amp; Artist Profile</h3>
        <p style="margin: 0; font-size: 14px; color: #cbd5e1;">{bio}</p>
      </div>

      <div class="card" style="border-left-color: #38bdf8;">
        <h3 style="margin: 0 0 8px 0; color: #38bdf8; font-size: 16px;">Live Showcase: Episode {ep_num} &mdash; {ep_title}</h3>
        <p style="margin: 0 0 12px 0; font-size: 14px; color: #cbd5e1;">A seamless 32-bit high-resolution journey crafted to demonstrate programming and dance floor pacing.</p>
        <div>
          <a class="btn" style="background: #0284c7;" href="{stream_url}">▶ Stream Mix Sample</a>
          <a class="btn" style="background: #991b1b;" href="{youtube_url}">📺 4K Video Set</a>
        </div>
      </div>

      <h3 style="color: #f1f5f9; margin-top: 24px; font-size: 16px;">Selected Tracklist ({track_count} Tracks):</h3>
      {tl_html}

      <div class="card" style="border-left-color: #10b981;">
        <h4 style="margin: 0 0 6px 0; color: #34d399; font-size: 14px;">Technical Rider Overview:</h4>
        <p style="margin: 0; font-size: 13px; color: #cbd5e1;">{rider}</p>
      </div>

      {f"<div class='card' style='border-left-color: #f59e0b;'><p style='margin:0;'><strong>Note for {recip_org}:</strong> {custom_msg}</p></div>" if custom_msg else ""}

      <p>Press kit photos, logos, and full audio files are attached or ready to download. We would love to discuss dates and availability with you.</p>
      <p>Thank you for your time,<br><strong>{sender_name}</strong></p>
    </div>
    <div class="footer">
      <p style="margin: 0;">Sent to {recip_name} &bull; {recip_org} &bull; Booking contact: <a href="mailto:{sender_email}">{sender_email}</a></p>
      <p style="margin: 6px 0 0 0;"><a href="{soundcloud_url}">SoundCloud</a> &bull; <a href="{youtube_url}">YouTube</a> &bull; <a href="{podcast_url}">Podcast</a></p>
    </div>
  </div>
</body>
</html>
"""

    # --------------------------------------------------------------------------
    # 3. NEW EPISODE PROMO RELEASE & PRESS BLAST
    # --------------------------------------------------------------------------
    elif template_id == "episode_promo":
        text_body = f"""Hello {recip_name},

We are thrilled to announce the brand new episode of 'Stream of Frequency':

==================================================
STREAM OF FREQUENCY {ep_num} - {ep_title}
Mixed by {sender_name}
==================================================

Listen on SoundCloud: {stream_url}
Listen on Apple Podcasts: {podcast_url}
Watch in 4K UHD on YouTube: {youtube_url}

ABOUT THIS EPISODE:
Featuring {track_count} handpicked progressive and trance records, seamlessly mixed and mastered at audiophile 32-bit sample depth.

TRACKLIST:
{tl_plain}

{f"EDITORIAL NOTE:\n{custom_msg}\n\n" if custom_msg else ""}Artwork, promotional assets, and lossless downloads are available upon request. Feel free to include this release in your upcoming charts, blog roundups, and playlists.

Thank you for your continued support!

Musically yours,

{sender_name}
Stream of Frequency
Email: {sender_email}
"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0b0f19; color: #e2e8f0; margin: 0; padding: 24px; }}
    .container {{ max-width: 680px; margin: 0 auto; background-color: #1e293b; border-radius: 12px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }}
    .header {{ background: linear-gradient(135deg, #065f46 0%, #047857 50%, #0d9488 100%); padding: 32px 28px; text-align: left; border-bottom: 2px solid #2dd4bf; }}
    .header h1 {{ margin: 0 0 8px 0; font-size: 24px; color: #ffffff; }}
    .header .subtitle {{ margin: 0; color: #a7f3d0; font-size: 13px; font-weight: bold; text-transform: uppercase; letter-spacing: 1.5px; }}
    .content {{ padding: 28px; line-height: 1.6; font-size: 15px; }}
    .btn {{ display: inline-block; background: #0d9488; color: #ffffff !important; text-decoration: none; padding: 12px 22px; border-radius: 8px; font-weight: 600; font-size: 14px; margin: 8px 8px 8px 0; }}
    .card {{ background: #0f172a; border-left: 4px solid #2dd4bf; padding: 16px 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }}
    .footer {{ background: #0f172a; padding: 20px 28px; font-size: 13px; color: #64748b; border-top: 1px solid #334155; }}
    a {{ color: #2dd4bf; text-decoration: none; }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <p class="subtitle">Official Promo Release &bull; Out Now</p>
      <h1>Stream of Frequency {ep_num} &mdash; {ep_title}</h1>
    </div>
    <div class="content">
      <p>Hello <strong>{recip_name}</strong>,</p>
      <p>We are delighted to share the newest installment of <em>Stream of Frequency</em>, curated and mixed by <strong>{sender_name}</strong>.</p>

      <div class="card">
        <h3 style="margin: 0 0 10px 0; color: #2dd4bf; font-size: 16px;">Stream &amp; Download Episode {ep_num}</h3>
        <p style="margin: 0 0 12px 0; font-size: 14px; color: #cbd5e1;">Available in 32-bit Lossless FLAC, Apple Podcasts feed, and 4K YouTube visualizer.</p>
        <div>
          <a class="btn" href="{stream_url}">🎧 SoundCloud Stream</a>
          <a class="btn" style="background: #0284c7;" href="{podcast_url}">🎙 Apple Podcasts</a>
          <a class="btn" style="background: #991b1b;" href="{youtube_url}">📺 YouTube 4K</a>
        </div>
      </div>

      <h3 style="color: #f1f5f9; margin-top: 24px; font-size: 16px;">Full Tracklist ({track_count} Selections):</h3>
      {tl_html}

      {f"<div class='card' style='border-left-color: #f59e0b;'><p style='margin:0;'><strong>Editorial Note:</strong> {custom_msg}</p></div>" if custom_msg else ""}

      <p>Cover artwork, cue metadata, and promo one-sheets are attached. Feel free to incorporate into your radio playlists, reviews, or charts!</p>
      <p>Musically yours,<br><strong>{sender_name}</strong></p>
    </div>
    <div class="footer">
      <p style="margin: 0;">Sent to {recip_name} &bull; Stream of Frequency &bull; Inquiries: <a href="mailto:{sender_email}">{sender_email}</a></p>
    </div>
  </div>
</body>
</html>
"""

    # --------------------------------------------------------------------------
    # 4. TRACK SUPPORT COURTESY NOTIFICATION
    # --------------------------------------------------------------------------
    elif template_id == "track_support":
        text_body = f"""Dear {recip_name} ({recip_org}),

Just a quick note of appreciation!

Your music was featured in the latest edition of 'Stream of Frequency' ({ep_num} - {ep_title}), mixed by {sender_name}.

You can listen to the mix here:
{stream_url}

Thank you for releasing exceptional electronic music and inspiring our sets. Full tracklist and episode details are included below:

{tl_plain}

Keep up the outstanding work!

Best regards,

{sender_name}
Stream of Frequency
Email: {sender_email}
"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0b0f19; color: #e2e8f0; margin: 0; padding: 24px; }}
    .container {{ max-width: 680px; margin: 0 auto; background-color: #1e293b; border-radius: 12px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }}
    .header {{ background: linear-gradient(135deg, #831843 0%, #be185d 50%, #db2777 100%); padding: 28px; border-bottom: 2px solid #f472b6; }}
    .header h1 {{ margin: 0 0 6px 0; font-size: 22px; color: #ffffff; }}
    .content {{ padding: 28px; line-height: 1.6; font-size: 15px; }}
    .btn {{ display: inline-block; background: #db2777; color: #ffffff !important; text-decoration: none; padding: 10px 20px; border-radius: 6px; font-weight: 600; font-size: 14px; margin: 8px 0; }}
    .card {{ background: #0f172a; border-left: 4px solid #f472b6; padding: 16px 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }}
    .footer {{ background: #0f172a; padding: 20px 28px; font-size: 13px; color: #64748b; border-top: 1px solid #334155; }}
    a {{ color: #f472b6; text-decoration: none; }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <p style="margin:0; color:#fbcfe8; font-size:12px; font-weight:bold; text-transform:uppercase; letter-spacing:1px;">Artist &amp; Label Support Notice</p>
      <h1>Track Feature in Stream of Frequency {ep_num}</h1>
    </div>
    <div class="content">
      <p>Dear <strong>{recip_name}</strong> ({recip_org}),</p>
      <p>Just a quick note of gratitude! Your release was featured in the latest edition of <em>Stream of Frequency</em> (Episode {ep_num} &mdash; {ep_title}), mixed by <strong>{sender_name}</strong>.</p>
      <div class="card">
        <h3 style="margin:0 0 8px 0; color:#f472b6; font-size:15px;">Listen to the Full Mix:</h3>
        <a class="btn" href="{stream_url}">▶ Stream on SoundCloud</a>
      </div>
      <h3 style="color:#f1f5f9; margin-top:20px; font-size:15px;">Episode Tracklist:</h3>
      {tl_html}
      <p>Thank you for continuing to create and release phenomenal music. Keep up the amazing work!</p>
      <p>Best regards,<br><strong>{sender_name}</strong></p>
    </div>
    <div class="footer">
      <p style="margin:0;">Stream of Frequency &bull; <a href="mailto:{sender_email}">{sender_email}</a></p>
    </div>
  </div>
</body>
</html>
"""

    # --------------------------------------------------------------------------
    # 5. RADIO GUEST MIX & SYNDICATION SUBMISSION
    # --------------------------------------------------------------------------
    elif template_id == "radio_guestmix":
        text_body = f"""Dear {recip_name} and {recip_org} Programming Team,

I am pleased to submit a guest mix edition of 'Stream of Frequency' for airplay consideration on your station.

EPISODE DETAILS:
Title: Stream of Frequency {ep_num} - {ep_title}
Host / DJ: {sender_name}
Format: Broadcast-Ready 32-bit Lossless FLAC / 320kbps MP3
Cue Sheet: Attached
Stream Preview: {stream_url}

TRACKLIST:
{tl_plain}

STATION COMPLIANCE:
- Broadcast standards compliant (no spoken profanity, clean radio master).
- Complete cue times and track-by-track attribution provided.
- Voiceover intros or custom station id drops available on request.

{f"SPECIAL NOTE:\n{custom_msg}\n\n" if custom_msg else ""}Please let us know if you would like to include this in your upcoming weekly schedule.

Warm regards,

{sender_name}
Email: {sender_email}
"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0b0f19; color: #e2e8f0; margin: 0; padding: 24px; }}
    .container {{ max-width: 680px; margin: 0 auto; background-color: #1e293b; border-radius: 12px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }}
    .header {{ background: linear-gradient(135deg, #1e3a8a 0%, #1d4ed8 50%, #2563eb 100%); padding: 28px; border-bottom: 2px solid #60a5fa; }}
    .header h1 {{ margin: 0 0 6px 0; font-size: 22px; color: #ffffff; }}
    .content {{ padding: 28px; line-height: 1.6; font-size: 15px; }}
    .btn {{ display: inline-block; background: #2563eb; color: #ffffff !important; text-decoration: none; padding: 10px 20px; border-radius: 6px; font-weight: 600; font-size: 14px; margin: 8px 0; }}
    .card {{ background: #0f172a; border-left: 4px solid #60a5fa; padding: 16px 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }}
    .footer {{ background: #0f172a; padding: 20px 28px; font-size: 13px; color: #64748b; border-top: 1px solid #334155; }}
    a {{ color: #60a5fa; text-decoration: none; }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <p style="margin:0; color:#bfdbfe; font-size:12px; font-weight:bold; text-transform:uppercase; letter-spacing:1px;">Radio Syndication &amp; Guest Mix Submission</p>
      <h1>Stream of Frequency {ep_num} &bull; {sender_name}</h1>
    </div>
    <div class="content">
      <p>Dear <strong>{recip_name}</strong> and the <strong>{recip_org}</strong> programming team,</p>
      <p>I am pleased to submit a broadcast-grade guest mix from <em>Stream of Frequency</em> for your programming schedule.</p>
      <div class="card">
        <h3 style="margin:0 0 6px 0; color:#60a5fa; font-size:15px;">Broadcast Master: Episode {ep_num}</h3>
        <p style="margin:0 0 10px 0; font-size:13px; color:#cbd5e1;">Pristine 32-bit audiophile master &bull; Compliant radio cues &bull; {track_count} tracks</p>
        <a class="btn" href="{stream_url}">🎧 Stream Audio Preview</a>
      </div>
      <h3 style="color:#f1f5f9; margin-top:20px; font-size:15px;">Cue Sheet &amp; Tracklist:</h3>
      {tl_html}
      <p>Custom station voiceovers and uncompressed WAV/FLAC delivery are available upon request.</p>
      <p>Thank you for considering our submission,<br><strong>{sender_name}</strong></p>
    </div>
    <div class="footer">
      <p style="margin:0;">Stream of Frequency &bull; Inquiries: <a href="mailto:{sender_email}">{sender_email}</a></p>
    </div>
  </div>
</body>
</html>
"""

    # --------------------------------------------------------------------------
    # 6. CUSTOM OUTREACH
    # --------------------------------------------------------------------------
    else:
        text_body = f"""Dear {recip_name},

{custom_msg or f"I am writing to you regarding 'Stream of Frequency' {ep_num} - {ep_title}."}

Episode Information:
Title: Stream of Frequency {ep_num} - {ep_title}
Curated by: {sender_name}
Streaming URL: {stream_url}

Tracklist ({track_count} tracks):
{tl_plain}

Best regards,

{sender_name}
Email: {sender_email}
"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0b0f19; color: #e2e8f0; margin: 0; padding: 24px; }}
    .container {{ max-width: 680px; margin: 0 auto; background-color: #1e293b; border-radius: 12px; padding: 28px; border: 1px solid #334155; }}
    a {{ color: #38bdf8; }}
  </style>
</head>
<body>
  <div class="container">
    <p>Dear <strong>{recip_name}</strong>,</p>
    <p>{custom_msg or f"I am writing to you regarding <em>Stream of Frequency {ep_num} &mdash; {ep_title}</em>."}</p>
    <div style="background:#0f172a; padding:14px; border-radius:8px; margin:16px 0;">
      <p style="margin:0 0 6px 0;"><strong>Episode:</strong> Stream of Frequency {ep_num} &mdash; {ep_title}</p>
      <p style="margin:0;"><strong>Listen:</strong> <a href="{stream_url}">{stream_url}</a></p>
    </div>
    {tl_html}
    <p>Best regards,<br><strong>{sender_name}</strong><br><a href="mailto:{sender_email}">{sender_email}</a></p>
  </div>
</body>
</html>
"""

    return subject, text_body, html_body


# ==============================================================================
# MIME BUILDER & ATTACHMENT HANDLER
# ==============================================================================
def build_mime_message(from_addr, from_name, to_addr, to_name, subject, text_body, html_body, attachments=None, reply_to=None):
    """Constructs a standard MIME multipart email with Plaintext and HTML bodies plus attachments."""
    msg = MIMEMultipart("mixed")
    msg["From"] = f"{from_name} <{from_addr}>" if from_name else from_addr
    msg["To"] = f"{to_name} <{to_addr}>" if to_name else to_addr
    msg["Subject"] = subject
    msg["Date"] = email_utils.formatdate(localtime=True)
    msg["Message-ID"] = email_utils.make_msgid(domain=from_addr.split("@")[-1] if "@" in from_addr else "mixmanager.local")
    if reply_to:
        msg["Reply-To"] = reply_to

    # Alternative container for text and html
    alt_part = MIMEMultipart("alternative")
    part_text = MIMEText(text_body, "plain", "utf-8")
    part_html = MIMEText(html_body, "html", "utf-8")
    alt_part.attach(part_text)
    alt_part.attach(part_html)
    msg.attach(alt_part)

    # Attachments
    if attachments:
        for filepath in attachments:
            if not os.path.isfile(filepath):
                continue
            filename = os.path.basename(filepath)
            ctype, encoding = mimetypes.guess_type(filepath)
            if ctype is None or encoding is not None:
                ctype = "application/octet-stream"
            maintype, subtype = ctype.split("/", 1)

            try:
                with open(filepath, "rb") as f:
                    file_data = f.read()

                if maintype == "image":
                    part = MIMEImage(file_data, _subtype=subtype)
                else:
                    part = MIMEBase(maintype, subtype)
                    part.set_payload(file_data)
                    encoders.encode_base64(part)

                part.add_header("Content-Disposition", "attachment", filename=filename)
                msg.attach(part)
            except Exception as e:
                print(f"[Warning] Failed to attach {filepath}: {e}", file=sys.stderr)

    return msg


# ==============================================================================
# DELIVERY ENGINES: SMTP, MAILTO & BROWSER PREVIEW
# ==============================================================================
def send_smtp_email(mime_msg, host, port, user, password, use_tls=True, use_ssl=False):
    """Sends MIME message via configured SMTP server."""
    if not host:
        raise ValueError("SMTP host is not configured. Please set SMTP_HOST in config.env.")

    from_addr = email_utils.parseaddr(mime_msg["From"])[1]
    to_addrs = [email_utils.parseaddr(mime_msg["To"])[1]]

    if use_ssl or port == 465:
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL(host, port, context=context) as server:
            if user and password:
                server.login(user, password)
            server.send_message(mime_msg, from_addr=from_addr, to_addrs=to_addrs)
    else:
        with smtplib.SMTP(host, port, timeout=30) as server:
            if use_tls:
                context = ssl.create_default_context()
                server.starttls(context=context)
            if user and password:
                server.login(user, password)
            server.send_message(mime_msg, from_addr=from_addr, to_addrs=to_addrs)

    return True


def open_in_mail_client(to_addr, subject, body):
    """Constructs a mailto URI and launches it in the system's default email client."""
    params = {
        "subject": subject,
        "body": body
    }
    query_str = urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
    mailto_url = f"mailto:{to_addr}?{query_str}"

    # Platform specific opener
    if sys.platform == "darwin":
        subprocess.run(["open", mailto_url], check=False)
    elif sys.platform.startswith("win"):
        # Windows URL command length limitation safe fallback
        if len(mailto_url) > 2000:
            mailto_url = f"mailto:{to_addr}?subject={urllib.parse.quote(subject)}"
        os.startfile(mailto_url)
    else:
        subprocess.run(["xdg-open", mailto_url], check=False)


def preview_in_browser(html_content, title="Email Preview"):
    """Saves HTML content to temporary file and launches in default web browser."""
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as f:
        f.write(html_content)
        temp_path = f.name

    if sys.platform == "darwin":
        subprocess.run(["open", temp_path], check=False)
    elif sys.platform.startswith("win"):
        os.startfile(temp_path)
    else:
        subprocess.run(["xdg-open", temp_path], check=False)

    return temp_path


# ==============================================================================
# SENT EMAIL LOG RECORDER
# ==============================================================================
def log_sent_email(to_addr, to_name, subject, template_name, delivery_mode, success, error_msg=""):
    """Records sent emails and drafts in JSON and text log files."""
    os.makedirs(LOGS_DIR, exist_ok=True)
    entry = {
        "timestamp": datetime.now().isoformat(),
        "date_human": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "to_email": to_addr,
        "to_name": to_name,
        "subject": subject,
        "template": template_name,
        "delivery_mode": delivery_mode,
        "success": success,
        "error": error_msg
    }

    # Update JSON log
    log_data = []
    if os.path.isfile(SENT_LOG_JSON):
        try:
            with open(SENT_LOG_JSON, "r", encoding="utf-8", errors="ignore") as f:
                log_data = json.load(f)
                if not isinstance(log_data, list):
                    log_data = []
        except Exception:
            log_data = []

    log_data.insert(0, entry)
    try:
        with open(SENT_LOG_JSON, "w", encoding="utf-8") as f:
            json.dump(log_data[:500], f, indent=2)
    except Exception:
        pass

    # Append to text log
    status_str = "SUCCESS" if success else f"FAILED ({error_msg})"
    log_line = f"[{entry['date_human']}] [{delivery_mode.upper()}] [{status_str}] To: {to_name} <{to_addr}> | Subject: {subject} | Template: {template_name}\n"
    try:
        with open(SENT_LOG_TXT, "a", encoding="utf-8") as f:
            f.write(log_line)
    except Exception:
        pass


# ==============================================================================
# INTERACTIVE CLI WIZARD
# ==============================================================================
def run_interactive_wizard():
    """Provides a terminal-driven interactive workflow for sending promo emails."""
    cfg = load_config()

    print("\033[1;36m==================================================\033[0m")
    print("\033[1;36m     PROMOTIONAL & PUBLISHER OUTREACH SYSTEM      \033[0m")
    print("\033[1;36m  (Promoters, Podcast Publishers, Radio & Labels) \033[0m")
    print("\033[1;36m==================================================\033[0m\n")

    # Step 1: Select Template
    print("\033[1mSelect Outreach Template:\033[0m")
    template_keys = list(TEMPLATES.keys())
    for idx, key in enumerate(template_keys, start=1):
        t = TEMPLATES[key]
        print(f"  \033[1;32m{idx})\033[0m \033[1m{t['name']}\033[0m")
        print(f"      \033[2m{t['description']}\033[0m")
    print()

    t_choice = input("Enter template choice [1-6, default 1]: ").strip()
    try:
        t_idx = int(t_choice) - 1 if t_choice else 0
        if not (0 <= t_idx < len(template_keys)):
            t_idx = 0
    except ValueError:
        t_idx = 0
    selected_template = template_keys[t_idx]
    target_cat = TEMPLATES[selected_template]["target_category"]

    # Step 2: Choose Recipient
    print(f"\n\033[1mRecipient Selection (Filtered for: {target_cat.upper()}):\033[0m")
    contacts = find_contacts(category=target_cat if target_cat != "all" else None)
    if not contacts:
        contacts = load_contacts()

    print("  \033[1;32m 0)\033[0m Enter custom recipient manually")
    for idx, c in enumerate(contacts[:15], start=1):
        last_str = f" [Last sent: {c.get('last_contacted')}]" if c.get('last_contacted') else ""
        print(f"  \033[1;32m{idx:2d})\033[0m {c.get('name')} \033[2m({c.get('organization')})\033[0m &lt;{c.get('email')}&gt;{last_str}")

    recip_choice = input(f"\nSelect contact [0-{min(len(contacts), 15)}, default 1]: ").strip()
    recip_name = "Team"
    recip_email = ""
    recip_org = ""

    try:
        r_idx = int(recip_choice) if recip_choice else 1
        if r_idx == 0:
            recip_email = input("Enter recipient email address: ").strip()
            recip_name = input("Enter recipient contact name: ").strip() or "Team"
            recip_org = input("Enter organization / venue name: ").strip() or "Organization"
            # Offer to save contact
            save_prompt = input("Save to contact book? (y/n) [y]: ").strip().lower()
            if save_prompt != "n":
                add_contact(recip_name, recip_email, recip_org, category=target_cat if target_cat != "all" else "promoter")
        elif 1 <= r_idx <= len(contacts):
            c = contacts[r_idx - 1]
            recip_name = c.get("name", "Team")
            recip_email = c.get("email", "")
            recip_org = c.get("organization", "")
    except ValueError:
        recip_email = input("Enter recipient email address: ").strip()

    if not recip_email or "@" not in recip_email:
        print("\033[1;31mError: Valid recipient email is required!\033[0m")
        return 1

    # Step 3: Choose Episode
    print("\n\033[1mSelect Episode to Feature:\033[0m")
    ep_input = input("Enter mix number, episode keyword, or press ENTER for latest: ").strip()
    ep_info = resolve_episode_assets(ep_input, cfg)
    print(f"\033[1;32m✔ Resolved Episode:\033[0m {ep_info['full_title']}")
    print(f"  Track count: {ep_info['track_count']} tracks")
    if ep_info['cover_file']:
        print(f"  Cover Art:   {os.path.basename(ep_info['cover_file'])}")
    if ep_info['spek_file']:
        print(f"  Spectrogram: {os.path.basename(ep_info['spek_file'])}")

    # Step 4: Streaming URL
    custom_stream = input(f"\nStreaming URL [default: {cfg.get('PROMO_SOUNDCLOUD_URL')}]: ").strip()
    stream_url = custom_stream if custom_stream else cfg.get("PROMO_SOUNDCLOUD_URL")

    # Step 5: Optional Note
    custom_msg = input("\nOptional personalized message or note for this recipient (or press ENTER): ").strip()

    # Build Context
    context = {
        "config": cfg,
        "recipient_name": recip_name,
        "organization": recip_org,
        "episode_number": ep_info["episode_number"],
        "episode_title": ep_info["episode_title"],
        "stream_url": stream_url,
        "tracks": ep_info["tracks"],
        "custom_message": custom_msg
    }

    subject, text_body, html_body = render_email_content(selected_template, context)

    # Attachments
    attachments = []
    if ep_info["cover_file"] and os.path.isfile(ep_info["cover_file"]):
        attachments.append(ep_info["cover_file"])
    if ep_info["tracklist_file"] and os.path.isfile(ep_info["tracklist_file"]):
        attachments.append(ep_info["tracklist_file"])

    # Step 6: Action Menu
    while True:
        print("\n\033[1;36m--------------------------------------------------\033[0m")
        print("\033[1;36m             READY TO DISPATCH OUTREACH           \033[0m")
        print("\033[1;36m--------------------------------------------------\033[0m")
        print(f"  To:          \033[1m{recip_name}\033[0m &lt;{recip_email}&gt; ({recip_org})")
        print(f"  Subject:     \033[1m{subject}\033[0m")
        print(f"  Template:    {TEMPLATES[selected_template]['name']}")
        print(f"  Attachments: {len(attachments)} file(s) ({', '.join([os.path.basename(a) for a in attachments]) or 'None'})")
        print()
        print("  \033[1;32m1)\033[0m \033[1mSend via SMTP Server\033[0m" + (f" ({cfg['SMTP_HOST']})" if cfg['SMTP_HOST'] else " \033[1;33m[SMTP Not Configured]\033[0m"))
        print("  \033[1;32m2)\033[0m \033[1mOpen in Default Desktop Email Client (Thunderbird / Apple Mail / Outlook)\033[0m")
        print("  \033[1;32m3)\033[0m \033[1mPreview Rendered HTML Email in Web Browser\033[0m")
        print("  \033[1;32m4)\033[0m \033[1mPreview Plaintext Email in Console\033[0m")
        print("  \033[1;32m5)\033[0m Add/Remove Attachments")
        print("  \033[1;32m6)\033[0m Cancel & Return")
        print()

        act = input("Choose action [1-6]: ").strip()

        if act == "1":
            if not cfg["SMTP_HOST"]:
                print("\n\033[1;33mSMTP host is not configured.\033[0m")
                smtp_host = input("Enter SMTP Host (e.g. smtp.gmail.com): ").strip()
                smtp_user = input("Enter SMTP Username / Email: ").strip()
                import getpass
                smtp_pass = getpass.getpass("Enter SMTP Password / App Password: ")
                cfg["SMTP_HOST"] = smtp_host
                cfg["SMTP_USER"] = smtp_user
                cfg["SMTP_PASSWORD"] = smtp_pass

            from_name = cfg["PROMO_SENDER_NAME"]
            from_email = cfg["PROMO_SENDER_EMAIL"] or cfg["SMTP_USER"]
            mime_msg = build_mime_message(
                from_addr=from_email,
                from_name=from_name,
                to_addr=recip_email,
                to_name=recip_name,
                subject=subject,
                text_body=text_body,
                html_body=html_body,
                attachments=attachments,
                reply_to=cfg.get("PROMO_REPLY_TO", from_email)
            )

            print("\n\033[1;33mConnecting to SMTP server and dispatching email...\033[0m")
            try:
                send_smtp_email(
                    mime_msg=mime_msg,
                    host=cfg["SMTP_HOST"],
                    port=cfg["SMTP_PORT"],
                    user=cfg["SMTP_USER"],
                    password=cfg["SMTP_PASSWORD"],
                    use_tls=cfg["SMTP_USE_TLS"],
                    use_ssl=cfg["SMTP_USE_SSL"]
                )
                print(f"\033[1;32m✔ Email successfully sent to {recip_name} <{recip_email}>!\033[0m")
                update_contact_timestamp(recip_email)
                log_sent_email(recip_email, recip_name, subject, selected_template, "smtp", True)
                break
            except Exception as e:
                print(f"\033[1;31m✖ Failed to send email via SMTP: {e}\033[0m")
                log_sent_email(recip_email, recip_name, subject, selected_template, "smtp", False, str(e))
                print("Tip: You can use Option 2 to open this email directly in your system email client.")

        elif act == "2":
            print("\n\033[1;32mOpening draft in default desktop email client...\033[0m")
            open_in_mail_client(recip_email, subject, text_body)
            update_contact_timestamp(recip_email)
            log_sent_email(recip_email, recip_name, subject, selected_template, "mailto", True)
            print("\033[1;32m✔ Draft launched in email client.\033[0m")
            break

        elif act == "3":
            print("\n\033[1;33mLaunching browser preview...\033[0m")
            p_file = preview_in_browser(html_body, title=subject)
            print(f"\033[1;32m✔ Preview opened in browser ({p_file})\033[0m")

        elif act == "4":
            print("\n\033[1;36m=== PLAINTEXT EMAIL PREVIEW ===\033[0m")
            print(f"Subject: {subject}\n")
            print(text_body)
            print("\033[1;36m================================\033[0m")

        elif act == "5":
            print(f"\nCurrent attachments: {attachments}")
            add_p = input("Enter full path of file to add (or press ENTER): ").strip()
            if add_p and os.path.isfile(add_p):
                attachments.append(add_p)
                print(f"Added {add_p}")

        elif act == "6":
            print("\nOutreach wizard cancelled.")
            return 0

    return 0


# ==============================================================================
# MAIN ENTRYPOINT
# ==============================================================================
def main():
    parser = argparse.ArgumentParser(description="Promotional & Publisher Outreach Email System")
    parser.add_argument("-i", "--interactive", action="store_true", help="Launch interactive terminal wizard")
    parser.add_argument("-t", "--template", default="podcast_publisher", choices=list(TEMPLATES.keys()), help="Template ID")
    parser.add_argument("--to", help="Recipient email address")
    parser.add_argument("--name", default="", help="Recipient contact name")
    parser.add_argument("--org", default="", help="Recipient organization / venue / label")
    parser.add_argument("--category", choices=["promoter", "publisher", "radio", "label", "press", "all"], help="Filter category")
    parser.add_argument("--episode", default="", help="Episode number, keyword or file path")
    parser.add_argument("--subject", default="", help="Custom subject line")
    parser.add_argument("--stream-url", default="", help="Streaming link")
    parser.add_argument("--attach", nargs="*", default=[], help="File paths to attach")
    parser.add_argument("--note", default="", help="Custom personalized note")
    parser.add_argument("--send", action="store_true", help="Send email directly via SMTP")
    parser.add_argument("--mailto", action="store_true", help="Launch draft in system email client")
    parser.add_argument("--preview", action="store_true", help="Preview HTML email in web browser")
    parser.add_argument("--dry-run", action="store_true", help="Print email details to console without sending")
    parser.add_argument("--list-contacts", action="store_true", help="List all saved outreach contacts")
    parser.add_argument("--add-contact", action="store_true", help="Add a new contact to the address book")
    parser.add_argument("--list-templates", action="store_true", help="Display available outreach email templates")

    args = parser.parse_args()

    # List templates
    if args.list_templates:
        print("\033[1;36m=== AVAILABLE OUTREACH EMAIL TEMPLATES ===\033[0m\n")
        for k, v in TEMPLATES.items():
            print(f"  \033[1;32m{k:18s}\033[0m : \033[1m{v['name']}\033[0m")
            print(f"                     \033[2m{v['description']}\033[0m")
            print(f"                     \033[2mDefault Subject: {v['default_subject']}\033[0m\n")
        return 0

    # List contacts
    if args.list_contacts:
        contacts = find_contacts(category=args.category)
        print(f"\033[1;36m=== OUTREACH CONTACTS ({len(contacts)} saved) ===\033[0m\n")
        for c in contacts:
            cat_badge = f"[{c.get('category', 'other').upper()}]"
            last_c = f" (Contacted: {c.get('last_contacted')})" if c.get('last_contacted') else ""
            print(f"  \033[1m{c.get('name', 'N/A')}\033[0m \033[2m<{c.get('email')}> {cat_badge}\033[0m")
            print(f"    Org: {c.get('organization', 'N/A')} | Notes: {c.get('notes', 'None')}{last_c}\n")
        return 0

    # Add contact
    if args.add_contact:
        name = input("Contact Name: ").strip()
        email = input("Email Address: ").strip()
        org = input("Organization / Venue / Network: ").strip()
        cat = input("Category (promoter/publisher/radio/label/press) [promoter]: ").strip().lower() or "promoter"
        notes = input("Notes: ").strip()
        c = add_contact(name, email, org, cat, notes)
        print(f"\033[1;32m✔ Added contact {c['name']} ({c['id']})\033[0m")
        return 0

    # If no specific arguments or interactive flag
    if args.interactive or (not args.to and not args.send and not args.mailto and not args.preview and not args.dry_run):
        return run_interactive_wizard()

    # Non-interactive CLI invocation
    cfg = load_config()
    ep_info = resolve_episode_assets(args.episode, cfg)

    context = {
        "config": cfg,
        "recipient_name": args.name or "Team",
        "organization": args.org or "Organization",
        "episode_number": ep_info["episode_number"],
        "episode_title": ep_info["episode_title"],
        "stream_url": args.stream_url or cfg.get("PROMO_SOUNDCLOUD_URL", ""),
        "tracks": ep_info["tracks"],
        "custom_message": args.note,
        "subject": args.subject
    }

    subject, text_body, html_body = render_email_content(args.template, context)

    # Attachments
    attachments = list(args.attach)
    if ep_info["cover_file"] and os.path.isfile(ep_info["cover_file"]):
        attachments.append(ep_info["cover_file"])
    if ep_info["tracklist_file"] and os.path.isfile(ep_info["tracklist_file"]):
        attachments.append(ep_info["tracklist_file"])

    if args.preview:
        p_path = preview_in_browser(html_body, title=subject)
        print(f"Preview launched in browser: {p_path}")
        return 0

    if args.mailto:
        open_in_mail_client(args.to, subject, text_body)
        print(f"Launched mailto draft for {args.to}")
        log_sent_email(args.to, args.name, subject, args.template, "mailto", True)
        return 0

    if args.send:
        if not args.to:
            print("Error: --to email address required for sending.", file=sys.stderr)
            return 1
        from_name = cfg["PROMO_SENDER_NAME"]
        from_email = cfg["PROMO_SENDER_EMAIL"] or cfg["SMTP_USER"]
        mime_msg = build_mime_message(
            from_addr=from_email,
            from_name=from_name,
            to_addr=args.to,
            to_name=args.name,
            subject=subject,
            text_body=text_body,
            html_body=html_body,
            attachments=attachments,
            reply_to=cfg.get("PROMO_REPLY_TO", from_email)
        )
        send_smtp_email(
            mime_msg=mime_msg,
            host=cfg["SMTP_HOST"],
            port=cfg["SMTP_PORT"],
            user=cfg["SMTP_USER"],
            password=cfg["SMTP_PASSWORD"],
            use_tls=cfg["SMTP_USE_TLS"],
            use_ssl=cfg["SMTP_USE_SSL"]
        )
        print(f"Successfully sent email to {args.to}")
        update_contact_timestamp(args.to)
        log_sent_email(args.to, args.name, subject, args.template, "smtp", True)
        return 0

    # Default: Dry-run preview
    print(f"\033[1;36m=== DRY RUN EMAIL OUTREACH ===\033[0m")
    print(f"To:          {args.name} <{args.to}> ({args.org})")
    print(f"Subject:     {subject}")
    print(f"Template:    {args.template}")
    print(f"Attachments: {attachments}\n")
    print("\033[1m--- Plaintext Preview ---\033[0m")
    print(text_body)
    print("\033[1;36m==============================\033[0m")
    return 0


if __name__ == "__main__":
    sys.exit(main())
