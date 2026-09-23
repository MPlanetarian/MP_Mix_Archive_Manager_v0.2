#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.2 - Mix Publishing Calendar & Multi-Platform Scheduler
Allows artists & DJs to:
  - Schedule mix and podcast episode releases on an interactive ANSI monthly calendar
  - Target multiple distribution platforms:
      • Apple Podcasts (Podcasts Connect)
      • Spotify for Podcasters
      • SoundCloud
      • YouTube (Video Releases)
      • Mixcloud (Cloudcasts)
      • DI.FM & Proton Radio (Guestmix syndication)
      • Bandcamp
      • Custom Podcast RSS Feed (podcast_feed.xml)
  - Manage release cadences (Once, Weekly, Bi-Weekly, Monthly)
  - Export schedules to standard iCalendar (.ics) format (Apple/Google Calendar/Outlook)
  - Build automated multi-platform publication bundles (audio, metadata, show notes, covers)
"""

import os
import sys
import json
import datetime
import calendar
import re
import argparse
from pathlib import Path

# --- ANSI Terminal Colors ---
BOLD = "\033[1m"
DIM = "\033[2m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
MAGENTA = "\033[0;35m"
CYAN = "\033[0;36m"
WHITE = "\033[1;37m"
NC = "\033[0m"

PLATFORMS = [
    {"id": "apple_podcasts", "name": "Apple Podcasts", "url": "https://podcastsconnect.apple.com"},
    {"id": "spotify", "name": "Spotify for Podcasters", "url": "https://podcasters.spotify.com"},
    {"id": "soundcloud", "name": "SoundCloud", "url": "https://soundcloud.com/upload"},
    {"id": "youtube", "name": "YouTube Studio", "url": "https://studio.youtube.com"},
    {"id": "mixcloud", "name": "Mixcloud Cloudcast", "url": "https://mixcloud.com/upload"},
    {"id": "difm", "name": "DI.FM Radio Syndication", "url": "https://di.fm"},
    {"id": "proton", "name": "Proton Radio", "url": "https://protonradio.com"},
    {"id": "bandcamp", "name": "Bandcamp", "url": "https://bandcamp.com"},
    {"id": "rss_feed", "name": "Custom Podcast RSS Feed", "url": "podcast_feed.xml"}
]

def get_base_dir():
    return Path(__file__).resolve().parent

def get_calendar_db_path():
    db_dir = get_base_dir() / "assets"
    db_dir.mkdir(parents=True, exist_ok=True)
    return db_dir / "publishing_calendar.json"

def load_schedule_db():
    db_path = get_calendar_db_path()
    if db_path.is_file():
        try:
            with open(db_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "version": "MP_Mix_Manager_v0.2",
        "last_updated": datetime.datetime.now().isoformat(),
        "schedules": []
    }

def save_schedule_db(data):
    db_path = get_calendar_db_path()
    data["last_updated"] = datetime.datetime.now().isoformat()
    with open(db_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

def export_to_ical(data, output_path=None):
    """Export schedule entries to RFC 5545 iCalendar (.ics) format."""
    if output_path is None:
        output_path = get_base_dir() / "assets" / "mix_publishing_calendar.ics"
        
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//MPlanetarian//Mix Archive Manager v0.2//EN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        "X-WR-CALNAME:Mix Publishing Schedule",
        "X-WR-TIMEZONE:UTC"
    ]
    
    for item in data.get("schedules", []):
        dt_str = item.get("publish_date", "")
        tm_str = item.get("publish_time", "12:00")
        try:
            dt = datetime.datetime.strptime(f"{dt_str} {tm_str}", "%Y-%m-%d %H:%M")
            dt_start = dt.strftime("%Y%m%dT%H%M00Z")
            dt_end = (dt + datetime.timedelta(hours=1)).strftime("%Y%m%dT%H%M00Z")
        except ValueError:
            continue
            
        uid = f"mix-publish-{item.get('id', 'item')}@mplanetarian.com"
        title = item.get("mix_title") or item.get("title") or "Scheduled Mix"
        ep = item.get("episode_number", "")
        summary = f"Publish: {title}" + (f" ({ep})" if ep else "")
        platforms = ", ".join(item.get("platforms", []))
        desc = f"Platforms: {platforms}\\nNotes: {item.get('notes', '')}"
        
        lines.extend([
            "BEGIN:VEVENT",
            f"UID:{uid}",
            f"DTSTAMP:{datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M00Z')}",
            f"DTSTART:{dt_start}",
            f"DTEND:{dt_end}",
            f"SUMMARY:{summary}",
            f"DESCRIPTION:{desc}",
            f"STATUS:{'CONFIRMED' if item.get('status') != 'PUBLISHED' else 'COMPLETED'}",
            "END:VEVENT"
        ])
        
    lines.append("END:VCALENDAR")
    
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\r\n".join(lines) + "\r\n")
        
    return output_path

def generate_podcast_rss_snippet(schedule_item):
    """Generate RSS item XML block for self-hosted podcast feeds."""
    title = schedule_item.get("mix_title", "Stream of Frequency")
    ep = schedule_item.get("episode_number", "")
    desc = schedule_item.get("notes", "New Stream of Frequency mix episode.")
    dt_str = schedule_item.get("publish_date", datetime.date.today().isoformat())
    tm_str = schedule_item.get("publish_time", "12:00")
    try:
        dt = datetime.datetime.strptime(f"{dt_str} {tm_str}", "%Y-%m-%d %H:%M")
        pub_date = dt.strftime("%a, %d %b %Y %H:%M:%S +0000")
    except Exception:
        pub_date = datetime.datetime.now().strftime("%a, %d %b %Y %H:%M:%S +0000")
        
    xml = f"""    <item>
      <title>{title} {('(' + ep + ')') if ep else ''}</title>
      <description><![CDATA[{desc}]]></description>
      <pubDate>{pub_date}</pubDate>
      <itunes:episode>{ep.replace('Episode', '').strip() if ep else '1'}</itunes:episode>
      <itunes:season>1</itunes:season>
      <itunes:explicit>no</itunes:explicit>
      <itunes:episodeType>full</itunes:episodeType>
      <enclosure url="https://mplanetarian.com/audio/{re.sub(r'[^a-zA-Z0-9_-]', '_', title)}.mp3" length="250000000" type="audio/mpeg" />
      <guid isPermaLink="false">{schedule_item.get('id', 'guid')}</guid>
    </item>"""
    return xml

def render_month_calendar(year, month, scheduled_by_date):
    """Render an ANSI terminal monthly calendar with scheduled release markers."""
    month_name = calendar.month_name[month]
    cal = calendar.Calendar(firstweekday=0) # Monday first
    weeks = cal.monthdayscalendar(year, month)
    
    today = datetime.date.today()
    
    print(f"\n      {BOLD}{MAGENTA}{month_name} {year}{NC}")
    print(f"  {DIM}Mo   Tu   We   Th   Fr   Sa   Su{NC}")
    print(f"  {BLUE}──────────────────────────────{NC}")
    
    for week in weeks:
        row_str = "  "
        for day in week:
            if day == 0:
                row_str += "     "
            else:
                d_obj = datetime.date(year, month, day)
                d_str = d_obj.strftime("%Y-%m-%d")
                has_event = d_str in scheduled_by_date
                is_today = (d_obj == today)
                
                if has_event and is_today:
                    row_str += f"{BOLD}{GREEN}[{day:2d}]{NC} "
                elif has_event:
                    row_str += f"{BOLD}{YELLOW}*{day:2d}*{NC} "
                elif is_today:
                    row_str += f"{BOLD}{CYAN}<{day:2d}>{NC} "
                else:
                    row_str += f"{day:2d}   "
        print(row_str)
    print(f"  {BLUE}──────────────────────────────{NC}")
    print(f"  {DIM}Legend: {BOLD}{YELLOW}*Day*{NC} Scheduled Mix | {BOLD}{CYAN}<Day>{NC} Today | {BOLD}{GREEN}[Day]{NC} Today's Release{NC}\n")

def list_archive_mixes():
    """Discover mixes in archive to suggest for scheduling."""
    base_dir = get_base_dir()
    env_dir = os.environ.get("MIX_ARCHIVE_DIR")
    arch_dir = Path(env_dir) if env_dir and Path(env_dir).is_dir() else (base_dir / "MIX_ARCHIVE")
    archive_paths = [
        arch_dir / "FLAC_CONVERTED_OUTPUTS",
        arch_dir,
        base_dir / "MIX_ARCHIVE" / "FLAC_CONVERTED_OUTPUTS",
        base_dir / "FLAC_CONVERTED_OUTPUTS",
        base_dir / "CONVERTED_WAV_FILES"
    ]
    mixes = []
    seen = set()
    for p in archive_paths:
        if p.is_dir():
            for f in sorted(p.iterdir()):
                if f.is_file() and f.suffix.lower() in ('.flac', '.wav', '.mp3'):
                    if f.name not in seen:
                        seen.add(f.name)
                        mixes.append(f.name)
    return mixes

def interactive_calendar_ui():
    """Main interactive terminal loop for the Publishing Calendar & Multi-Platform Scheduler."""
    now = datetime.datetime.now()
    cur_year = now.year
    cur_month = now.month
    
    while True:
        data = load_schedule_db()
        schedules = data.get("schedules", [])
        
        # Map dates to schedules
        by_date = {}
        for s in schedules:
            d = s.get("publish_date")
            if d:
                by_date.setdefault(d, []).append(s)
                
        os.system('clear' if os.name == 'posix' else 'cls')
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"{BOLD}{MAGENTA}      Mix Publishing Schedule Calendar & Multi-Platform Suite         {NC}")
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        
        render_month_calendar(cur_year, cur_month, by_date)
        
        # Show upcoming scheduled releases
        print(f"{BOLD}Upcoming Scheduled Mix Releases:{NC}")
        today_date = datetime.date.today()
        upcoming = []
        for s in schedules:
            try:
                p_date = datetime.datetime.strptime(s.get("publish_date", ""), "%Y-%m-%d").date()
                upcoming.append((p_date, s))
            except ValueError:
                pass
        upcoming.sort(key=lambda x: x[0])
        
        if not upcoming:
            print(f"  {DIM}No mix releases currently scheduled. Use option [1] to schedule one.{NC}")
        else:
            for idx, (p_date, item) in enumerate(upcoming[:8], start=1):
                days_left = (p_date - today_date).days
                if days_left == 0:
                    badge = f"{BOLD}{GREEN}TODAY!{NC}    "
                elif days_left > 0:
                    badge = f"{CYAN}In {days_left:2d}d{NC}   "
                else:
                    badge = f"{DIM}Passed{NC}   "
                    
                plat_names = ", ".join(item.get("platforms", []))
                if len(plat_names) > 30:
                    plat_names = plat_names[:27] + "..."
                st_icon = f"{GREEN}✓{NC}" if item.get("status") == "PUBLISHED" else f"{YELLOW}⏳{NC}"
                print(f"  {idx:2d}) {item.get('publish_date')} [{item.get('publish_time', '12:00')}] {badge} {st_icon} {BOLD}{item.get('mix_title', 'Mix')}{NC} ({item.get('episode_number', '')}) - {DIM}{plat_names}{NC}")
                
        print(f"\n{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        print(f"Calendar Navigation & Actions:")
        print(f"  ${BOLD}${CYAN} 1)${NC} Schedule a New Mix Release (Multi-Platform Wizard)")
        print(f"  ${BOLD}${CYAN} 2)${NC} View / Edit / Delete Scheduled Release")
        print(f"  ${BOLD}${CYAN} 3)${NC} Generate Platform Release Bundle (Audio, Artwork, Show Notes, Tags)")
        print(f"  ${BOLD}${CYAN} 4)${NC} Export Calendar to iCal (.ics for Apple/Google Calendar/Outlook)")
        print(f"  ${BOLD}${CYAN} 5)${NC} Generate Master Podcast RSS Feed (podcast_feed.xml)")
        print(f"  ${BOLD}${CYAN} n)${NC} Next Month  |  ${BOLD}${CYAN}p)${NC} Previous Month  |  ${BOLD}${CYAN}t)${NC} Jump to Today")
        print(f"\n  ${BOLD}${CYAN} 0)${NC} Return to Main Menu ${DIM}(or 'q')${NC}")
        print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        
        cmd = input(f"{BOLD}Enter choice: {NC}").strip()
        if cmd in ('0', 'q', 'exit', 'quit', 'back'):
            break
        elif cmd.lower() == 'n':
            if cur_month == 12:
                cur_month = 1
                cur_year += 1
            else:
                cur_month += 1
        elif cmd.lower() == 'p':
            if cur_month == 1:
                cur_month = 12
                cur_year -= 1
            else:
                cur_month -= 1
        elif cmd.lower() == 't':
            cur_year = now.year
            cur_month = now.month
        elif cmd == '1':
            # Schedule new mix release
            schedule_mix_wizard(data)
        elif cmd == '2':
            # Edit or remove
            manage_scheduled_items_wizard(data)
        elif cmd == '3':
            # Build release bundle
            build_platform_bundle_wizard(data)
        elif cmd == '4':
            # Export iCal
            ics_path = export_to_ical(data)
            print(f"\n{GREEN}✓ Calendar exported successfully to:{NC} {BOLD}{ics_path}{NC}")
            input("Press Enter to continue...")
        elif cmd == '5':
            # Generate RSS
            feed_path = get_base_dir() / "podcast_feed.xml"
            items_xml = "\n".join([generate_podcast_rss_snippet(s) for s in data.get("schedules", [])])
            full_rss = f"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>Stream of Frequency Podcast</title>
    <link>https://mplanetarian.com</link>
    <language>en-us</language>
    <description>MPlanetarian Stream of Frequency DJ Mixes and Live Sets.</description>
    <itunes:author>MPlanetarian</itunes:author>
    <itunes:category text="Music" />
{items_xml}
  </channel>
</rss>"""
            with open(feed_path, "w", encoding="utf-8") as f:
                f.write(full_rss)
            print(f"\n{GREEN}✓ Generated Podcast RSS Feed at:{NC} {BOLD}{feed_path}{NC}")
            input("Press Enter to continue...")

def schedule_mix_wizard(data):
    """Wizard to add a new mix to the publishing calendar."""
    print(f"\n{BOLD}{MAGENTA}--- Schedule a New Mix Release ---{NC}")
    archive_mixes = list_archive_mixes()
    mix_title = ""
    ep_number = ""
    
    if archive_mixes:
        print(f"\nRecent mixes found in archive:")
        for i, m in enumerate(archive_mixes[:10], start=1):
            print(f"  {i:2d}) {m}")
        print(f"   C) Enter custom title")
        choice = input(f"Select mix [1-{min(10, len(archive_mixes))} or C]: ").strip()
        if choice.isdigit() and 1 <= int(choice) <= min(10, len(archive_mixes)):
            chosen_file = archive_mixes[int(choice) - 1]
            mix_title = Path(chosen_file).stem
            # Extract episode number if present
            m = re.search(r'(?:Episode|SOF|No\.?)\s*(\d+)', chosen_file, re.I) or re.search(r'(\d{3})', chosen_file)
            if m:
                ep_number = f"Episode {m.group(1)}"
        else:
            mix_title = input("Enter Mix Title: ").strip()
    else:
        mix_title = input("Enter Mix Title: ").strip()
        
    if not mix_title:
        print(f"{YELLOW}Title required. Aborting.{NC}")
        return
        
    if not ep_number:
        ep_number = input("Enter Episode Number (e.g. Episode 041, or leave blank): ").strip()
        
    # Date & Time
    default_date = datetime.date.today().strftime("%Y-%m-%d")
    pub_date = input(f"Enter publication date (YYYY-MM-DD) [{default_date}]: ").strip() or default_date
    pub_time = input(f"Enter publication time (HH:MM) [12:00]: ").strip() or "12:00"
    
    # Target Platforms Selection
    print(f"\n{BOLD}Select Target Publishing Platforms:{NC}")
    selected_platforms = []
    for idx, plat in enumerate(PLATFORMS, start=1):
        print(f"  {idx}) {plat['name']}")
    plat_input = input("Enter platform numbers (e.g. 1,2,3,4 or 'all') [1,2,3,4]: ").strip() or "1,2,3,4"
    
    if plat_input.lower() in ('all', '*'):
        selected_platforms = [p['name'] for p in PLATFORMS]
    else:
        for p in plat_input.split(','):
            p = p.strip()
            if p.isdigit() and 1 <= int(p) <= len(PLATFORMS):
                selected_platforms.append(PLATFORMS[int(p) - 1]['name'])
                
    if not selected_platforms:
        selected_platforms = ["Apple Podcasts", "SoundCloud", "YouTube"]
        
    cadence = input("Recurrence Cadence (once/weekly/bi-weekly/monthly) [once]: ").strip().lower() or "once"
    notes = input("Enter show notes / description: ").strip()
    
    new_entry = {
        "id": f"sched_{int(datetime.datetime.now().timestamp())}",
        "mix_title": mix_title,
        "episode_number": ep_number,
        "publish_date": pub_date,
        "publish_time": pub_time,
        "cadence": cadence,
        "platforms": selected_platforms,
        "notes": notes,
        "status": "SCHEDULED",
        "created_at": datetime.datetime.now().isoformat()
    }
    
    data.setdefault("schedules", []).append(new_entry)
    save_schedule_db(data)
    export_to_ical(data)
    
    print(f"\n{BOLD}{GREEN}✓ Mix release successfully scheduled for {pub_date} at {pub_time}!{NC}")
    input("Press Enter to continue...")

def manage_scheduled_items_wizard(data):
    """View, mark published, or remove scheduled items."""
    schedules = data.get("schedules", [])
    if not schedules:
        print(f"\n{YELLOW}No items in schedule.{NC}")
        input("Press Enter to return...")
        return
        
    print(f"\n{BOLD}{MAGENTA}--- Manage Scheduled Releases ---{NC}")
    for idx, s in enumerate(schedules, start=1):
        st = f"{GREEN}[PUBLISHED]{NC}" if s.get("status") == "PUBLISHED" else f"{YELLOW}[SCHEDULED]{NC}"
        print(f"  {idx:2d}) {s.get('publish_date')} {st} {BOLD}{s.get('mix_title')}{NC} ({s.get('episode_number')})")
        
    sel = input(f"\nSelect item number to manage [1-{len(schedules)}, 0 to cancel]: ").strip()
    if not sel.isdigit() or int(sel) < 1 or int(sel) > len(schedules):
        return
        
    item = schedules[int(sel) - 1]
    print(f"\nSelected: {BOLD}{item.get('mix_title')}{NC}")
    print(f"  Date & Time: {item.get('publish_date')} {item.get('publish_time')}")
    print(f"  Platforms:   {', '.join(item.get('platforms', []))}")
    print(f"  Notes:       {item.get('notes')}")
    print(f"  Status:      {item.get('status')}")
    
    print(f"\nActions:")
    print(f"  1) Mark as PUBLISHED")
    print(f"  2) Delete this scheduled entry")
    print(f"  3) Edit publication date / time")
    print(f"  0) Cancel")
    act = input("Enter action [1-3, 0]: ").strip()
    if act == '1':
        item["status"] = "PUBLISHED"
        save_schedule_db(data)
        export_to_ical(data)
        print(f"{GREEN}✓ Marked as PUBLISHED.{NC}")
    elif act == '2':
        schedules.pop(int(sel) - 1)
        save_schedule_db(data)
        export_to_ical(data)
        print(f"{RED}✓ Entry removed.{NC}")
    elif act == '3':
        new_d = input(f"New Date [{item.get('publish_date')}]: ").strip() or item.get('publish_date')
        new_t = input(f"New Time [{item.get('publish_time')}]: ").strip() or item.get('publish_time')
        item["publish_date"] = new_d
        item["publish_time"] = new_t
        save_schedule_db(data)
        export_to_ical(data)
        print(f"{GREEN}✓ Updated schedule.{NC}")
    input("Press Enter to continue...")

def build_platform_bundle_wizard(data):
    """Packages assets for multi-platform distribution into a dedicated release folder."""
    schedules = data.get("schedules", [])
    if not schedules:
        print(f"\n{YELLOW}No scheduled releases found.{NC}")
        input("Press Enter to return...")
        return
        
    print(f"\n{BOLD}{MAGENTA}--- Build Multi-Platform Publishing Bundle ---{NC}")
    for idx, s in enumerate(schedules, start=1):
        print(f"  {idx:2d}) {s.get('publish_date')} - {s.get('mix_title')} ({s.get('episode_number')})")
    sel = input(f"Select release to package [1-{len(schedules)}]: ").strip()
    if not sel.isdigit() or int(sel) < 1 or int(sel) > len(schedules):
        return
        
    item = schedules[int(sel) - 1]
    title_slug = re.sub(r'[^a-zA-Z0-9_-]', '_', item.get("mix_title", "mix"))
    bundle_dir = get_base_dir() / "assets" / "release_bundles" / f"{item.get('publish_date')}_{title_slug}"
    bundle_dir.mkdir(parents=True, exist_ok=True)
    
    # 1. Write show notes and platform checklist
    checklist_file = bundle_dir / "platform_checklist.md"
    with open(checklist_file, "w", encoding="utf-8") as f:
        f.write(f"# Publishing Package: {item.get('mix_title')} ({item.get('episode_number')})\n\n")
        f.write(f"- **Publication Date:** {item.get('publish_date')} at {item.get('publish_time')}\n")
        f.write(f"- **Show Notes / Description:**\n\n{item.get('notes')}\n\n")
        f.write("## Distribution Platform Checklist\n")
        for p in item.get("platforms", []):
            url = next((x["url"] for x in PLATFORMS if x["name"] == p), "")
            f.write(f"- [ ] **{p}** - Upload URL: {url}\n")
            
    # 2. Write RSS snippet
    with open(bundle_dir / "rss_item.xml", "w", encoding="utf-8") as f:
        f.write(generate_podcast_rss_snippet(item))
        
    print(f"\n{BOLD}{GREEN}✓ Release package generated at:{NC}")
    print(f"  {CYAN}{bundle_dir}{NC}")
    print(f"  Includes: platform_checklist.md, rss_item.xml")
    input("Press Enter to continue...")

def main():
    parser = argparse.ArgumentParser(description="Mix Publishing Calendar & Multi-Platform Scheduler")
    parser.add_argument("--list", action="store_true", help="List all scheduled releases")
    parser.add_argument("--export-ical", action="store_true", help="Export schedule to .ics file")
    args = parser.parse_args()
    
    if args.list:
        data = load_schedule_db()
        for s in data.get("schedules", []):
            m_title = s.get("mix_title") or s.get("title") or "Untitled Mix"
            m_ep = s.get("episode_number") or ""
            ep_str = f" ({m_ep})" if m_ep else ""
            print(f"[{s.get('publish_date')} {s.get('publish_time')}] {m_title}{ep_str} - {s.get('status')}")
    elif args.export_ical:
        data = load_schedule_db()
        path = export_to_ical(data)
        print(f"Exported iCal to {path}")
    else:
        interactive_calendar_ui()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{YELLOW}Exited calendar.{NC}")
        sys.exit(0)
