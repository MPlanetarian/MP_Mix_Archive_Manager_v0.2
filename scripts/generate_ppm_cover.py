#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.2 - Procedural PPM Gradient Cover Art Generator
Generates high-resolution podcast cover art using pure PPM (Portable Pixmap P6)
algorithms with procedural gradients, randomized aesthetic palettes, and text overlays.
"""

import os
import sys
import math
import random
import subprocess
import shutil
import argparse
from pathlib import Path

# --- ANSI Colors ---
BOLD = "\033[1m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
MAGENTA = "\033[0;35m"
CYAN = "\033[0;36m"
WHITE = "\033[1;37m"
NC = "\033[0m"

PALETTES = {
    "cyberpunk": [
        (255, 0, 128),   # Hot Pink
        (0, 240, 255),   # Electric Cyan
        (120, 0, 255),   # Deep Neon Violet
        (255, 230, 0)    # Electric Yellow
    ],
    "synthwave": [
        (25, 10, 55),    # Night Sky
        (180, 20, 140),  # Synth Magenta
        (255, 90, 40),   # Neon Tangerine
        (255, 215, 60)   # Sunset Gold
    ],
    "aurora": [
        (10, 25, 45),    # Polar Deep
        (0, 210, 140),   # Aurora Green
        (0, 160, 220),   # Arctic Cyan
        (160, 70, 240)   # Cosmic Violet
    ],
    "deep_ocean": [
        (5, 15, 40),     # Abyss Blue
        (0, 100, 160),   # Deep Teal
        (0, 200, 200),   # Aqua Cyan
        (180, 240, 255)  # Surf Foam
    ],
    "solar_flare": [
        (60, 5, 10),     # Dark Maroon
        (200, 30, 0),    # Solar Red
        (255, 130, 0),   # Blaze Orange
        (255, 230, 90)   # Corona Yellow
    ],
    "cosmic_twilight": [
        (12, 10, 35),    # Deep Space
        (80, 25, 110),   # Violet Nebula
        (190, 60, 140),  # Starburst Pink
        (240, 200, 255)  # Starlight White
    ]
}

def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    # Smoothstep interpolation: 3t^2 - 2t^3
    smooth_t = t * t * (3 - 2 * t)
    r = int(c1[0] + (c2[0] - c1[0]) * smooth_t)
    g = int(c1[1] + (c2[1] - c1[1]) * smooth_t)
    b = int(c1[2] + (c2[2] - c1[2]) * smooth_t)
    return (r, g, b)

def sample_palette(palette, t):
    t = max(0.0, min(0.9999, t))
    n = len(palette) - 1
    idx = int(t * n)
    local_t = (t * n) - idx
    return lerp_color(palette[idx], palette[min(idx + 1, n)], local_t)

def generate_random_palette():
    # Golden ratio hue distribution for vibrant harmonic palettes
    base_hue = random.random()
    palette = []
    for i in range(4):
        h = (base_hue + i * 0.28) % 1.0
        s = 0.85 + random.random() * 0.15
        v = 0.70 + random.random() * 0.30
        # HSV to RGB
        c = v * s
        x = c * (1 - abs((h * 6) % 2 - 1))
        m = v - c
        if h < 1/6:   r, g, b = c, x, 0
        elif h < 2/6: r, g, b = x, c, 0
        elif h < 3/6: r, g, b = 0, c, x
        elif h < 4/6: r, g, b = 0, x, c
        elif h < 5/6: r, g, b = x, 0, c
        else:         r, g, b = c, 0, x
        palette.append((int((r + m) * 255), int((g + m) * 255), int((b + m) * 255)))
    return palette

def render_ppm_gradient(width, height, style, palette):
    """Generate raw 24-bit binary PPM image bytes."""
    header = f"P6\n{width} {height}\n255\n".encode("ascii")
    pixel_data = bytearray(width * height * 3)
    
    # Precalculate parameters
    cx = width / 2.0
    cy = height / 2.0
    max_radius = math.sqrt(cx * cx + cy * cy)
    angle_rad = random.uniform(0, 2 * math.pi)
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    
    # Plasma frequencies
    f1 = random.uniform(1.5, 3.5) / width
    f2 = random.uniform(1.5, 3.5) / height
    f3 = random.uniform(2.0, 4.0) / width
    
    idx = 0
    for y in range(height):
        ny = y / height
        dy = y - cy
        for x in range(width):
            nx = x / width
            dx = x - cx
            
            if style == "linear":
                # Projected distance along angle vector
                proj = (dx * cos_a + dy * sin_a) / max_radius
                t = (proj + 1.0) / 2.0
            elif style == "radial":
                dist = math.sqrt(dx * dx + dy * dy)
                t = dist / max_radius
            elif style == "plasma":
                val = (
                    math.sin(x * f1 * 2 * math.pi) +
                    math.sin(y * f2 * 2 * math.pi) +
                    math.sin((x + y) * f3 * math.pi) +
                    math.sin(math.sqrt(dx*dx + dy*dy) * f1 * 2 * math.pi)
                ) / 4.0
                t = (val + 1.0) / 2.0
            elif style == "angular":
                ang = math.atan2(dy, dx) + math.pi
                t = ang / (2 * math.pi)
            else: # mesh 4-corner bilinear
                top = lerp_color(palette[0], palette[1], nx)
                bot = lerp_color(palette[2], palette[3], nx)
                rgb = lerp_color(top, bot, ny)
                pixel_data[idx] = rgb[0]
                pixel_data[idx+1] = rgb[1]
                pixel_data[idx+2] = rgb[2]
                idx += 3
                continue
                
            rgb = sample_palette(palette, t)
            pixel_data[idx] = rgb[0]
            pixel_data[idx+1] = rgb[1]
            pixel_data[idx+2] = rgb[2]
            idx += 3
            
    return header + pixel_data

def find_system_font():
    """Find a clean, bold sans-serif font for text overlay."""
    candidates = [
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
        "C:/Windows/Fonts/arialbd.ttf"
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return ""

def apply_text_overlays_ffmpeg(ppm_path, out_path, artist, title, episode, tags):
    """Use FFmpeg to composite high-res typography and border overlays onto the PPM image."""
    font_file = find_system_font()
    font_arg = f":fontfile='{font_file}'" if font_file else ""
    
    # Escape single quotes and colons for ffmpeg drawtext
    def esc(text):
        return text.replace("'", "\\'").replace(":", "\\:")
    
    e_artist = esc(artist.upper())
    e_title = esc(title)
    e_episode = esc(episode.upper())
    e_tags = esc(tags)
    
    filters = [
        # Draw translucent dark lower card for text legibility
        "drawbox=y=ih-ih*0.36:color=black@0.65:width=iw:height=ih*0.36:t=fill",
        # Top branding bar
        "drawbox=y=0:color=black@0.45:width=iw:height=ih*0.08:t=fill",
        # Border frame
        "drawbox=x=0:y=0:w=iw:h=ih:color=white@0.25:t=18",
        # Accent dividing line
        "drawbox=x=iw*0.08:y=ih-ih*0.36:w=iw*0.84:h=6:color=white@0.8:t=fill"
    ]
    
    # 1. Top Artist branding
    filters.append(
        f"drawtext=text='{e_artist}'{font_arg}:fontsize=h*0.038:fontcolor=white:x=(w-text_w)/2:y=h*0.022:shadowcolor=black@0.8:shadowx=3:shadowy=3"
    )
    
    # 2. Episode Tag (e.g. EPISODE 041)
    if e_episode:
        filters.append(
            f"drawtext=text='{e_episode}'{font_arg}:fontsize=h*0.042:fontcolor='#00F0FF':x=w*0.08:y=h-h*0.31:shadowcolor=black@0.9:shadowx=4:shadowy=4"
        )
        
    # 3. Main Mix Title
    filters.append(
        f"drawtext=text='{e_title}'{font_arg}:fontsize=h*0.065:fontcolor=white:x=w*0.08:y=h-h*0.24:shadowcolor=black@0.9:shadowx=5:shadowy=5"
    )
    
    # 4. Genre / BPM Tags Subtitle
    if e_tags:
        filters.append(
            f"drawtext=text='{e_tags}'{font_arg}:fontsize=h*0.030:fontcolor='#FFD700':x=w*0.08:y=h-h*0.11:shadowcolor=black@0.8:shadowx=3:shadowy=3"
        )
        
    vf = ",".join(filters)
    cmd = [
        "ffmpeg", "-y", "-i", str(ppm_path),
        "-vf", vf,
        "-frames:v", "1",
        str(out_path)
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode == 0

def interactive_wizard():
    base_dir = Path(__file__).resolve().parent
    covers_dir = base_dir / "COVERS"
    covers_dir.mkdir(parents=True, exist_ok=True)
    
    os.system('clear' if os.name == 'posix' else 'cls')
    print(f"{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"{BOLD}{MAGENTA}      Procedural .PPM Gradient Cover Art Generator (Pure Algorithmic) {NC}")
    print(f"{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"Generates high-resolution podcast cover art directly from mathematical")
    print(f"wavefields and gradients with custom typography, episode tags, and borders.\n")
    
    # Dimensions
    print(f"{BOLD}Choose Canvas Resolution:{NC}")
    print(f"  1) 3000 x 3000 px  ${GREEN}(Apple Podcasts & Spotify Hi-Res Standard)${NC}")
    print(f"  2) 1400 x 1400 px  ${CYAN}(Standard Web & Mobile Podcast Specs)${NC}")
    print(f"  3) 1080 x 1080 px  ${CYAN}(Square Social Media / Instagram)${NC}")
    res_choice = input("Select resolution [1-3, default 1]: ").strip()
    dim_map = {"1": 3000, "2": 1400, "3": 1080}
    size = dim_map.get(res_choice, 3000)
    
    # Gradient style
    print(f"\n{BOLD}Select Procedural Gradient Style:{NC}")
    print(f"  1) Linear Directional Gradient   ${DIM}(Smooth angular ray projection)${NC}")
    print(f"  2) Radial Concentric Gradient     ${DIM}(Circular focal glow)${NC}")
    print(f"  3) Plasma Wavefield               ${DIM}(Multi-frequency harmonic sine fields)${NC}")
    print(f"  4) Angular / Conical Gradient     ${DIM}(Swept angle field)${NC}")
    print(f"  5) 4-Corner Bilinear Mesh         ${DIM}(Independent corner chromatic blending)${NC}")
    style_choice = input("Select style [1-5, default 3]: ").strip()
    style_map = {"1": "linear", "2": "radial", "3": "plasma", "4": "angular", "5": "mesh"}
    style = style_map.get(style_choice, "plasma")
    
    # Palette
    print(f"\n{BOLD}Select Color Palette Theme:{NC}")
    print(f"  1) Cyberpunk Neon    ${DIM}[Hot Pink, Electric Cyan, Neon Violet, Yellow]${NC}")
    print(f"  2) Synthwave Sunset  ${DIM}[Night Navy, Magenta, Tangerine, Sunset Gold]${NC}")
    print(f"  3) Aurora Borealis   ${DIM}[Deep Polar, Aurora Green, Arctic Cyan, Violet]${NC}")
    print(f"  4) Deep Ocean        ${DIM}[Abyss Blue, Deep Teal, Aqua Cyan, Foam]${NC}")
    print(f"  5) Solar Flare       ${DIM}[Maroon, Solar Red, Blaze Orange, Corona Yellow]${NC}")
    print(f"  6) Cosmic Twilight   ${DIM}[Deep Void, Violet Nebula, Starburst Pink]${NC}")
    print(f"  7) Pure Random Harmony ${GREEN}(Algorithmically generated complementary palette)${NC}")
    pal_choice = input("Select palette [1-7, default 1]: ").strip()
    pal_map = {
        "1": "cyberpunk", "2": "synthwave", "3": "aurora",
        "4": "deep_ocean", "5": "solar_flare", "6": "cosmic_twilight"
    }
    if pal_choice == "7" or pal_choice not in pal_map:
        palette = generate_random_palette() if pal_choice == "7" else PALETTES["cyberpunk"]
        pal_name = "Random Harmony" if pal_choice == "7" else "Cyberpunk Neon"
    else:
        palette = PALETTES[pal_map[pal_choice]]
        pal_name = pal_map[pal_choice].replace('_', ' ').title()
        
    print(f"\n{BOLD}Enter Cover Typography & Metadata:{NC}")
    artist = input("Artist Name [MPlanetarian]: ").strip() or "MPlanetarian"
    title = input("Mix Title [Stream of Frequency]: ").strip() or "Stream of Frequency"
    episode = input("Episode Number [Episode 041]: ").strip() or "Episode 041"
    tags = input("Subtitle / Genre / BPM Tags [Deep Trance • Ambient Lounge • 138 BPM]: ").strip() or "Deep Trance • Ambient Lounge • 138 BPM"
    
    # Output filenames
    safe_title = re.sub(r'[^a-zA-Z0-9_-]', '_', f"{artist}_{title}_{episode}".replace(" ", "_"))
    raw_ppm_path = covers_dir / f"{safe_title}.ppm"
    final_png_path = covers_dir / f"{safe_title}.png"
    
    print(f"\n{BOLD}{BLUE}Generating {size}x{size} raw PPM image using {style} gradient ({pal_name})...{NC}")
    ppm_data = render_ppm_gradient(size, size, style, palette)
    with open(raw_ppm_path, "wb") as f:
        f.write(ppm_data)
    print(f"{GREEN}✓ Raw PPM file written: {raw_ppm_path} ({len(ppm_data) / (1024*1024):.1f} MB){NC}")
    
    # Compositing text overlay
    if shutil.which("ffmpeg"):
        print(f"{BOLD}{CYAN}Compositing typography overlays, framing & branding via FFmpeg...{NC}")
        success = apply_text_overlays_ffmpeg(raw_ppm_path, final_png_path, artist, title, episode, tags)
        if success:
            print(f"{BOLD}{GREEN}✓ High-Resolution Cover Art Successfully Generated:{NC}")
            print(f"  PNG: {BOLD}{final_png_path}{NC}")
            print(f"  PPM: {DIM}{raw_ppm_path}{NC}")
        else:
            print(f"{YELLOW}Warning: FFmpeg text rendering failed. Raw PPM is intact at {raw_ppm_path}{NC}")
            final_png_path = raw_ppm_path
    else:
        print(f"{YELLOW}FFmpeg not found. Raw PPM saved: {raw_ppm_path}{NC}")
        final_png_path = raw_ppm_path
        
    # Option to set as active Cover.png
    print("")
    set_active = input("Set this cover as the active default Cover.png for the archive? [Y/n]: ").strip().lower()
    if not set_active or set_active in ('y', 'yes'):
        active_png = base_dir / "Cover.png"
        assets_png = base_dir / "assets" / "Cover.png"
        if final_png_path.suffix.lower() == ".png":
            shutil.copy2(final_png_path, active_png)
            shutil.copy2(final_png_path, assets_png)
        elif shutil.which("ffmpeg"):
            subprocess.run(["ffmpeg", "-y", "-i", str(raw_ppm_path), str(active_png)], capture_output=True)
            subprocess.run(["ffmpeg", "-y", "-i", str(raw_ppm_path), str(assets_png)], capture_output=True)
        print(f"{GREEN}✓ Active Cover.png updated!{NC}")
        
    input("\nPress Enter to return...")

def main():
    parser = argparse.ArgumentParser(description="Procedural PPM Cover Art Generator")
    parser.add_argument("--auto", action="store_true", help="Generate cover with default settings")
    parser.add_argument("--artist", default="MPlanetarian", help="Artist name")
    parser.add_argument("--title", default="Stream of Frequency", help="Mix title")
    parser.add_argument("--episode", default="Episode 041", help="Episode number")
    parser.add_argument("--tags", default="Deep Trance • Ambient Lounge", help="Subtitle tags")
    parser.add_argument("--size", type=int, default=1400, help="Width/Height in pixels")
    parser.add_argument("--style", default="plasma", choices=["linear", "radial", "plasma", "angular", "mesh"])
    parser.add_argument("--output", help="Output PNG path")
    
    args = parser.parse_args()
    if args.auto:
        palette = PALETTES["cyberpunk"]
        ppm_data = render_ppm_gradient(args.size, args.size, args.style, palette)
        out_base = Path(__file__).resolve().parent / "COVERS" / f"Cover_{args.episode.replace(' ', '_')}"
        ppm_path = out_base.with_suffix(".ppm")
        png_path = Path(args.output) if args.output else out_base.with_suffix(".png")
        ppm_path.parent.mkdir(parents=True, exist_ok=True)
        with open(ppm_path, "wb") as f:
            f.write(ppm_data)
        if shutil.which("ffmpeg"):
            apply_text_overlays_ffmpeg(ppm_path, png_path, args.artist, args.title, args.episode, args.tags)
            print(f"Generated {png_path}")
        else:
            print(f"Generated {ppm_path}")
    else:
        interactive_wizard()

if __name__ == "__main__":
    try:
        if len(sys.argv) > 1 and "--auto" in sys.argv:
            main()
        else:
            interactive_wizard()
    except KeyboardInterrupt:
        print("")
        sys.exit(0)
