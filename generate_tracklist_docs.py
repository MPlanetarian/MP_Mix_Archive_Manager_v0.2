#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.3 - Tracklist Document Generator (HTML & PDF)
Converts Traktor/Stream of Frequency .txt tracklists into publication-quality
interactive HTML documents and print-ready PDF files.
"""

import sys
import os
import re
import argparse
import subprocess
import html

def parse_tracklist_file(filepath):
    """Parses a tracklist .txt file into metadata and structured tracks."""
    if not os.path.isfile(filepath):
        raise FileNotFoundError(f"File not found: {filepath}")

    metadata = {
        "artist": "MPlanetarian",
        "album": "Stream of Frequency",
        "title": os.path.splitext(os.path.basename(filepath))[0],
        "date": "Unknown",
        "conversion_date": "",
        "show_id": "",
        "sources": [],
        "filename": os.path.basename(filepath)
    }

    tracks = []
    lines = []
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        lines = [line.rstrip() for line in f]

    in_tracklist = False
    for line in lines:
        s = line.strip()
        if not s:
            continue

        # Check metadata headers
        if s.startswith("Artist:"):
            metadata["artist"] = s.split(":", 1)[1].strip()
        elif s.startswith("Album:"):
            metadata["album"] = s.split(":", 1)[1].strip()
        elif s.startswith("Title:"):
            metadata["title"] = s.split(":", 1)[1].strip()
        elif s.startswith("Conversion Date:"):
            metadata["conversion_date"] = s.split(":", 1)[1].strip()
        elif s.startswith("- ") and not in_tracklist:
            metadata["sources"].append(s[2:].strip())
        elif "TRACKLIST" in s.upper() or "TRACK LIST" in s.upper():
            in_tracklist = True
            continue
        elif in_tracklist or re.match(r'^\d+[\.\-\)]', s):
            # Parse track entry: e.g. "01. [00:05:22] Artist - Title" or "01. Artist - Title"
            m = re.match(r'^(\d+)[\.\-\)]\s*(?:\[([\d:]+)\])?\s*(.*)$', s)
            if m:
                t_num = m.group(1).zfill(2)
                t_time = m.group(2) or ""
                t_content = m.group(3).strip()
                t_artist = ""
                t_title = t_content

                if " - " in t_content:
                    parts = t_content.split(" - ", 1)
                    t_artist = parts[0].strip()
                    t_title = parts[1].strip()

                tracks.append({
                    "number": t_num,
                    "time": t_time,
                    "artist": t_artist,
                    "title": t_title,
                    "raw": t_content
                })

    # Extract Show ID from title or filename
    base_name = os.path.splitext(os.path.basename(filepath))[0]
    show_m = re.search(r'(?:Frequency|Mix)[_ -]+(\d{3})', base_name, re.IGNORECASE)
    if not show_m:
        show_m = re.search(r'(\d{3})', base_name)
    if show_m:
        metadata["show_id"] = show_m.group(1)

    # Extract Date from title or filename
    date_m = re.search(r'(20\d{2}[-_]\d{2}[-_]\d{2})', base_name)
    if date_m:
        metadata["date"] = date_m.group(1).replace("_", "-")
    elif metadata["conversion_date"]:
        metadata["date"] = metadata["conversion_date"].split()[0]

    return metadata, tracks

def generate_html(metadata, tracks, output_path):
    """Generates a modern, responsive HTML page with dark mode and print styling."""
    title_escaped = html.escape(metadata["title"])
    artist_escaped = html.escape(metadata["artist"])
    album_escaped = html.escape(metadata["album"])
    date_escaped = html.escape(metadata["date"])
    show_id_str = f"Episode {metadata['show_id']}" if metadata["show_id"] else "Special Mix"

    track_rows = []
    for t in tracks:
        num = html.escape(t["number"])
        time_badge = f'<span class="badge time-badge">{html.escape(t["time"])}</span>' if t["time"] else ''
        art = html.escape(t["artist"]) if t["artist"] else '<span class="unknown-artist">Various / Unknown</span>'
        tit = html.escape(t["title"])
        track_rows.append(f"""
        <tr>
            <td class="col-num">{num}</td>
            <td class="col-time">{time_badge}</td>
            <td class="col-artist">{art}</td>
            <td class="col-title">{tit}</td>
        </tr>
        """)

    rows_html = "\n".join(track_rows) if track_rows else '<tr><td colspan="4" class="no-tracks">No structured tracks found in tracklist file.</td></tr>'

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title_escaped} - Tracklist</title>
    <style>
        :root {{
            --bg-primary: #0a0c10;
            --bg-card: rgba(18, 22, 32, 0.85);
            --border-card: #2a3346;
            --text-primary: #f0f4fc;
            --text-secondary: #8b9bb4;
            --accent-cyan: #00f0ff;
            --accent-pink: #ff007f;
            --accent-green: #00ff88;
            --accent-gold: #ffd700;
        }}
        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}
        body {{
            background: var(--bg-primary);
            color: var(--text-primary);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
            padding: 2.5rem 1rem;
            min-height: 100vh;
        }}
        .container {{
            max-width: 960px;
            margin: 0 auto;
        }}
        .card {{
            background: var(--bg-card);
            border: 1px solid var(--border-card);
            border-radius: 12px;
            padding: 2rem;
            box-shadow: 0 12px 36px rgba(0, 0, 0, 0.5);
            backdrop-filter: blur(10px);
            margin-bottom: 2rem;
        }}
        .header {{
            border-bottom: 2px solid var(--border-card);
            padding-bottom: 1.5rem;
            margin-bottom: 1.5rem;
            position: relative;
        }}
        .header::after {{
            content: '';
            position: absolute;
            bottom: -2px;
            left: 0;
            width: 120px;
            height: 2px;
            background: linear-gradient(90deg, var(--accent-cyan), var(--accent-pink));
        }}
        .badge {{
            display: inline-block;
            font-size: 0.75rem;
            font-weight: 700;
            text-transform: uppercase;
            padding: 0.25rem 0.65rem;
            border-radius: 6px;
            letter-spacing: 0.5px;
        }}
        .badge-show {{
            background: rgba(0, 240, 255, 0.15);
            color: var(--accent-cyan);
            border: 1px solid rgba(0, 240, 255, 0.3);
            margin-bottom: 0.75rem;
        }}
        .badge-count {{
            background: rgba(0, 255, 136, 0.15);
            color: var(--accent-green);
            border: 1px solid rgba(0, 255, 136, 0.3);
            margin-left: 0.5rem;
        }}
        h1 {{
            font-size: 1.85rem;
            font-weight: 800;
            color: #ffffff;
            margin-bottom: 0.5rem;
            letter-spacing: -0.5px;
        }}
        .meta-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 1rem;
            margin-top: 1.25rem;
        }}
        .meta-item {{
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 8px;
            padding: 0.75rem 1rem;
        }}
        .meta-label {{
            font-size: 0.75rem;
            text-transform: uppercase;
            color: var(--text-secondary);
            letter-spacing: 0.5px;
            margin-bottom: 0.2rem;
        }}
        .meta-val {{
            font-size: 1rem;
            font-weight: 600;
            color: #ffffff;
        }}
        .track-table {{
            width: 100%;
            border-collapse: collapse;
            margin-top: 1rem;
        }}
        .track-table th {{
            text-align: left;
            padding: 0.85rem 1rem;
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.75px;
            color: var(--text-secondary);
            border-bottom: 1px solid var(--border-card);
        }}
        .track-table td {{
            padding: 0.85rem 1rem;
            border-bottom: 1px solid rgba(255, 255, 255, 0.04);
            font-size: 0.95rem;
        }}
        .track-table tr:hover td {{
            background: rgba(0, 240, 255, 0.03);
        }}
        .col-num {{
            width: 45px;
            font-weight: 700;
            color: var(--accent-cyan);
            font-family: monospace;
            font-size: 1rem !important;
        }}
        .col-time {{
            width: 90px;
        }}
        .time-badge {{
            background: rgba(255, 215, 0, 0.12);
            color: var(--accent-gold);
            border: 1px solid rgba(255, 215, 0, 0.25);
            font-family: monospace;
            font-size: 0.8rem;
        }}
        .col-artist {{
            width: 35%;
            font-weight: 600;
            color: #e2e8f0;
        }}
        .col-title {{
            color: #ffffff;
        }}
        .unknown-artist {{
            color: var(--text-secondary);
            font-style: italic;
        }}
        .footer {{
            text-align: center;
            font-size: 0.8rem;
            color: var(--text-secondary);
            margin-top: 2rem;
        }}
        @media print {{
            body {{
                background: #ffffff !important;
                color: #000000 !important;
                padding: 0 !important;
            }}
            .card {{
                box-shadow: none !important;
                border: none !important;
                background: none !important;
                padding: 0 !important;
            }}
            h1 {{
                color: #000000 !important;
            }}
            .track-table th, .track-table td {{
                color: #000000 !important;
                border-bottom: 1px solid #ccc !important;
            }}
            .col-num {{
                color: #000000 !important;
            }}
            .badge {{
                border: 1px solid #333 !important;
                color: #000000 !important;
                background: none !important;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="card">
            <div class="header">
                <span class="badge badge-show">{show_id_str}</span>
                <span class="badge badge-count">{len(tracks)} Tracks</span>
                <h1>{title_escaped}</h1>
                <div class="meta-grid">
                    <div class="meta-item">
                        <div class="meta-label">Artist / DJ</div>
                        <div class="meta-val">{artist_escaped}</div>
                    </div>
                    <div class="meta-item">
                        <div class="meta-label">Series / Album</div>
                        <div class="meta-val">{album_escaped}</div>
                    </div>
                    <div class="meta-item">
                        <div class="meta-label">Session Date</div>
                        <div class="meta-val">{date_escaped}</div>
                    </div>
                    <div class="meta-item">
                        <div class="meta-label">Total Tracks</div>
                        <div class="meta-val">{len(tracks)}</div>
                    </div>
                </div>
            </div>

            <table class="track-table">
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Time</th>
                        <th>Artist</th>
                        <th>Track Title</th>
                    </tr>
                </thead>
                <tbody>
                    {rows_html}
                </tbody>
            </table>
        </div>
        <div class="footer">
            Generated by <strong>Stream of Frequency Mix Archive Manager</strong> (MP_Mix_Manager_v0.3)
        </div>
    </div>
</body>
</html>
"""
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    return output_path

def generate_pdf_postscript(metadata, tracks, output_pdf_path):
    """
    Generates a crisp PostScript file and renders it to vector PDF via ps2pdf.
    Features auto-pagination, clean headers, and crisp typography.
    """
    ps_lines = [
        "%!PS-Adobe-3.0",
        "%%BoundingBox: 0 0 612 792",
        "%%Pages: (atend)",
        "%%LanguageLevel: 2",
        "%%EndComments",
        "/Courier findfont 10 scalefont setfont"
    ]

    title = metadata["title"][:60]
    artist = metadata["artist"]
    date_str = metadata["date"]
    show_id = f"Episode {metadata['show_id']}" if metadata['show_id'] else "Mix"

    lines_per_page = 42
    chunks = [tracks[i:i + lines_per_page] for i in range(0, len(tracks), lines_per_page)]
    if not chunks:
        chunks = [[]]

    total_pages = len(chunks)

    def ps_escape(text):
        text = str(text).replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')
        # Replace non-ascii chars with clean ascii approximations
        return text.encode('ascii', 'replace').decode('ascii')

    for page_idx, page_tracks in enumerate(chunks, 1):
        ps_lines.append(f"%%Page: {page_idx} {page_idx}")
        ps_lines.append("save")

        # Top Header Bar
        ps_lines.append("0.1 0.1 0.15 setrgbcolor")
        ps_lines.append("36 730 540 32 rectfill")

        ps_lines.append("1 1 1 setrgbcolor")
        ps_lines.append("/Helvetica-Bold findfont 13 scalefont setfont")
        ps_lines.append(f"46 742 moveto ({ps_escape('STREAM OF FREQUENCY - ' + show_id)}) show")

        ps_lines.append("/Helvetica findfont 9 scalefont setfont")
        ps_lines.append(f"450 742 moveto ({ps_escape('Date: ' + date_str)}) show")

        # Mix Title & Meta
        ps_lines.append("0 0 0 setrgbcolor")
        ps_lines.append("/Helvetica-Bold findfont 11 scalefont setfont")
        ps_lines.append(f"36 710 moveto ({ps_escape(title)}) show")

        ps_lines.append("/Helvetica-Oblique findfont 9 scalefont setfont")
        ps_lines.append(f"36 696 moveto ({ps_escape('Artist: ' + artist + '  |  Total Tracks: ' + str(len(tracks)))}) show")

        # Divider line
        ps_lines.append("0.7 0.7 0.7 setrgbcolor")
        ps_lines.append("0.5 setlinewidth")
        ps_lines.append("36 688 moveto 576 688 lineto stroke")

        # Table Header
        ps_lines.append("0.92 0.94 0.96 setrgbcolor")
        ps_lines.append("36 672 540 14 rectfill")
        ps_lines.append("0.2 0.2 0.2 setrgbcolor")
        ps_lines.append("/Helvetica-Bold findfont 8 scalefont setfont")
        ps_lines.append("42 676 moveto (#) show")
        ps_lines.append("68 676 moveto (TIME) show")
        ps_lines.append("120 676 moveto (ARTIST) show")
        ps_lines.append("280 676 moveto (TRACK TITLE) show")

        # Track rows
        y = 658
        for t in page_tracks:
            # Alternating row tint
            if int(t["number"]) % 2 == 0:
                ps_lines.append(f"0.97 0.98 0.99 setrgbcolor")
                ps_lines.append(f"36 {y-3} 540 13 rectfill")

            ps_lines.append("0 0 0 setrgbcolor")
            ps_lines.append("/Helvetica-Bold findfont 8 scalefont setfont")
            ps_lines.append(f"42 {y} moveto ({ps_escape(t['number'])}) show")

            if t["time"]:
                ps_lines.append("/Courier findfont 8 scalefont setfont")
                ps_lines.append(f"68 {y} moveto ({ps_escape(t['time'])}) show")

            art_str = ps_escape(t["artist"][:30]) if t["artist"] else ps_escape(t["raw"][:30])
            tit_str = ps_escape(t["title"][:48]) if t["title"] else ""

            ps_lines.append("/Helvetica-Bold findfont 8 scalefont setfont")
            ps_lines.append(f"120 {y} moveto ({art_str}) show")

            ps_lines.append("/Helvetica findfont 8 scalefont setfont")
            ps_lines.append(f"280 {y} moveto ({tit_str}) show")

            y -= 13

        # Footer
        ps_lines.append("0.7 0.7 0.7 setrgbcolor")
        ps_lines.append("36 40 moveto 576 40 lineto stroke")
        ps_lines.append("/Helvetica findfont 8 scalefont setfont")
        ps_lines.append("0.4 0.4 0.4 setrgbcolor")
        ps_lines.append(f"36 30 moveto ({ps_escape('Stream of Frequency Archive Suite')}) show")
        ps_lines.append(f"520 30 moveto (Page {page_idx} of {total_pages}) show")

        ps_lines.append("showpage")
        ps_lines.append("restore")

    ps_lines.append("%%Trailer")
    ps_lines.append(f"%%Pages: {total_pages}")
    ps_lines.append("%%EOF")

    ps_content = "\n".join(ps_lines)
    temp_ps = output_pdf_path + ".tmp.ps"
    os.makedirs(os.path.dirname(os.path.abspath(output_pdf_path)), exist_ok=True)
    with open(temp_ps, "w", encoding="ascii") as f:
        f.write(ps_content)

    try:
        subprocess.run(["ps2pdf", temp_ps, output_pdf_path], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if os.path.exists(temp_ps):
            os.remove(temp_ps)
        return output_pdf_path
    except Exception as e:
        if os.path.exists(temp_ps):
            os.remove(temp_ps)
        raise RuntimeError(f"ps2pdf conversion failed: {e}")

def convert_single_tracklist(txt_path, output_dir=None, out_fmt="both"):
    metadata, tracks = parse_tracklist_file(txt_path)
    base_name = os.path.splitext(os.path.basename(txt_path))[0]
    out_dir = output_dir or os.path.dirname(os.path.abspath(txt_path))

    results = {}
    if out_fmt in ("html", "both"):
        html_out = os.path.join(out_dir, f"{base_name}.html")
        generate_html(metadata, tracks, html_out)
        results["html"] = html_out

    if out_fmt in ("pdf", "both"):
        pdf_out = os.path.join(out_dir, f"{base_name}.pdf")
        generate_pdf_postscript(metadata, tracks, pdf_out)
        results["pdf"] = pdf_out

    return metadata, tracks, results

def batch_convert(target_dir, output_dir=None, out_fmt="both"):
    out_dir = output_dir or target_dir
    txt_files = [os.path.join(target_dir, f) for f in os.listdir(target_dir) if f.lower().endswith(".txt")]
    processed = []
    errors = []

    for tf in sorted(txt_files):
        try:
            _, _, res = convert_single_tracklist(tf, out_dir, out_fmt)
            processed.append((tf, res))
        except Exception as e:
            errors.append((tf, str(e)))

    return processed, errors

def main():
    parser = argparse.ArgumentParser(description="Generate HTML and PDF tracklist documents.")
    parser.add_argument("-i", "--input", help="Path to single .txt tracklist file")
    parser.add_argument("-d", "--dir", help="Directory containing .txt tracklists for batch generation")
    parser.add_argument("-o", "--output-dir", help="Output directory for generated documents")
    parser.add_argument("-f", "--format", choices=["html", "pdf", "both"], default="both", help="Output format (default: both)")

    args = parser.parse_args()

    if args.input:
        meta, tracks, res = convert_single_tracklist(args.input, args.output_dir, args.format)
        print("\n" + "=" * 60)
        print("          TRACKLIST DOCUMENT GENERATED")
        print("=" * 60)
        print(f"  Mix Title:   {meta['title']}")
        print(f"  Episode:     {meta['show_id'] or 'Special'}")
        print(f"  Tracks:      {len(tracks)}")
        if "html" in res:
            print(f"  HTML File:   {res['html']}")
        if "pdf" in res:
            print(f"  PDF File:    {res['pdf']}")
        print("=" * 60 + "\n")
    elif args.dir:
        print(f"\nScanning {args.dir} for tracklists...")
        processed, errors = batch_convert(args.dir, args.output_dir, args.format)
        print("\n" + "=" * 60)
        print("       BATCH TRACKLIST GENERATION COMPLETE")
        print("=" * 60)
        print(f"  Total Processed: {len(processed)}")
        print(f"  Total Errors:    {len(errors)}")
        for orig, res in processed[:10]:
            print(f"  ✓ {os.path.basename(orig)} -> {', '.join(res.keys())}")
        if len(processed) > 10:
            print(f"  ... and {len(processed) - 10} more.")
        print("=" * 60 + "\n")
    else:
        parser.print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()
