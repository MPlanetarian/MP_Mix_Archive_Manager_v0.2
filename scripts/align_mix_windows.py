#!/usr/bin/env python3
"""
scripts/align_mix_windows.py - Cross-Platform Window Alignment for Mix Manager
Positions the Cover Art Viewer and Tracklist Console Window side-by-side:
- In the exact middle of the active screen
- Centered horizontally and vertically aligned
- Floating directly on top of the manager window (Keep Above)
- Zero overlap so the user can clearly see both cover and tracklist simultaneously
"""

import sys
import os
import time
import platform
import subprocess

def align_kwin(timeout_seconds=5.0):
    """Align windows using KDE Plasma 6 KWin Scripting DBus API."""
    try:
        import dbus
    except ImportError:
        return False

    start_time = time.time()
    aligned_both = False

    while time.time() - start_time < timeout_seconds:
        try:
            bus = dbus.SessionBus()
            kwin_obj = bus.get_object('org.kde.KWin', '/Scripting')
            scripting = dbus.Interface(kwin_obj, 'org.kde.kwin.Scripting')

            js_code = r'''
(function() {
    var wins = workspace.windowList();
    var coverWin = null;
    var tlWin = null;

    for (var i = 0; i < wins.length; i++) {
        var w = wins[i];
        if (!w || !w.caption) continue;
        var cap = w.caption;
        var rClass = w.resourceClass || '';

        // Match Tracklist Window
        if (cap.indexOf('Mix Tracklist Viewer') !== -1 || 
            (cap.indexOf('Tracklist') !== -1 && rClass.indexOf('konsole') !== -1)) {
            tlWin = w;
        }

        // Match Cover Window (Gwenview or title containing Cover)
        if (cap.indexOf('Mix Cover Art Viewer') !== -1 || 
            (cap.indexOf('Cover') !== -1 && (rClass.indexOf('gwenview') !== -1 || cap.indexOf('Gwenview') !== -1)) ||
            (rClass.indexOf('gwenview') !== -1 && cap.indexOf('Gwenview') !== -1)) {
            coverWin = w;
        }
    }

    if (!coverWin && !tlWin) {
        return;
    }

    // Determine target screen and client area
    var refWin = tlWin || coverWin || workspace.activeWindow;
    var screen = refWin && refWin.output ? refWin.output : workspace.activeScreen;
    var sArea = workspace.clientArea(0, screen, workspace.currentDesktop);

    var sX = sArea.x;
    var sY = sArea.y;
    var sW = sArea.width;
    var sH = sArea.height;

    // Calculate dimensions: vertically aligned with identical height
    var targetH = Math.min(760, Math.max(500, Math.floor(sH * 0.65)));
    var coverW = coverWin ? Math.min(targetH, Math.floor(sW * 0.38)) : 0;
    var tlW = tlWin ? Math.min(960, Math.max(680, Math.floor(sW * 0.44))) : 0;
    var gap = (coverWin && tlWin) ? 24 : 0;

    var totalW = coverW + gap + tlW;
    if (totalW > sW - 40) {
        var scale = (sW - 60) / totalW;
        coverW = Math.floor(coverW * scale);
        tlW = Math.floor(tlW * scale);
        targetH = Math.floor(targetH * scale);
        totalW = coverW + gap + tlW;
    }

    var startX = sX + Math.max(10, Math.floor((sW - totalW) / 2));
    var startY = sY + Math.max(10, Math.floor((sH - targetH) / 2));

    if (coverWin) {
        coverWin.keepAbove = true;
        coverWin.frameGeometry = {
            x: startX,
            y: startY,
            width: coverW,
            height: targetH
        };
        workspace.raiseWindow(coverWin);
    }

    if (tlWin) {
        var tlX = coverWin ? (startX + coverW + gap) : startX;
        tlWin.keepAbove = true;
        tlWin.noBorder = true;
        tlWin.frameGeometry = {
            x: tlX,
            y: startY,
            width: tlW,
            height: targetH
        };
        workspace.raiseWindow(tlWin);
    }

    console.warn("MIX_ALIGN_SUCCESS: Aligned cover=" + (!!coverWin) + " tl=" + (!!tlWin) + " at Y=" + startY);
})();
'''
            import tempfile
            with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as f:
                f.write(js_code)
                tmp_js = f.name

            try:
                num = scripting.loadScript(tmp_js)
                script_obj = bus.get_object('org.kde.KWin', f'/Scripting/Script{num}')
                script_obj.run()
                aligned_both = True
            finally:
                if os.path.exists(tmp_js):
                    os.remove(tmp_js)

            # Check if both windows were found and positioned
            if aligned_both:
                time.sleep(0.4)
                return True

        except Exception:
            pass

        time.sleep(0.3)

    return aligned_both

def align_x11():
    """Align windows using wmctrl / xdotool on X11 / Xwayland."""
    if not (shutil_which('wmctrl') and shutil_which('xdotool')):
        return False
    try:
        # Query active desktop resolution via xrandr
        out = subprocess.check_output(['xrandr'], text=True, errors='ignore')
        w, h = 1920, 1080
        for line in out.splitlines():
            if '*' in line:
                parts = line.split()[0].split('x')
                w, h = int(parts[0]), int(parts[1])
                break

        target_h = min(720, max(500, int(h * 0.62)))
        cover_w = target_h
        tl_w = min(900, max(680, int(w * 0.42)))
        gap = 20
        total_w = cover_w + gap + tl_w
        start_x = max(10, (w - total_w) // 2)
        start_y = max(10, (h - target_h) // 2)

        # Position Cover
        subprocess.run(['wmctrl', '-r', 'Mix Cover', '-e', f'0,{start_x},{start_y},{cover_w},{target_h}'], check=False)
        subprocess.run(['wmctrl', '-r', 'Mix Cover', '-b', 'add,above'], check=False)

        # Position Tracklist
        tl_x = start_x + cover_w + gap
        subprocess.run(['wmctrl', '-r', 'Mix Tracklist Viewer', '-e', f'0,{tl_x},{start_y},{tl_w},{target_h}'], check=False)
        subprocess.run(['wmctrl', '-r', 'Mix Tracklist Viewer', '-b', 'add,above'], check=False)
        return True
    except Exception:
        return False

def shutil_which(cmd):
    from shutil import which
    return which(cmd) is not None

def main():
    # If running with --daemon or background mode, give newly launched windows a moment to map
    time.sleep(0.2)
    sys_name = platform.system().lower()

    if sys_name == 'linux':
        if align_kwin(timeout_seconds=4.0):
            sys.exit(0)
        align_x11()
    elif sys_name == 'darwin':
        # macOS AppleScript alignment
        ascript = '''
tell application "Finder"
    set b to bounds of window of desktop
    set screenW to item 3 of b
    set screenH to item 4 of b
end tell
set targetH to (screenH * 0.65) as integer
set coverW to targetH
set tlW to (screenW * 0.42) as integer
set gap to 24
set totalW to coverW + gap + tlW
set startX to ((screenW - totalW) / 2) as integer
set startY to ((screenH - targetH) / 2) as integer

tell application "System Events"
    if exists (process "Preview") then
        tell process "Preview"
            try
                set position of window 1 to {startX, startY}
                set size of window 1 to {coverW, targetH}
            end try
        end tell
    end if
    if exists (process "Terminal") then
        tell process "Terminal"
            try
                set position of window 1 to {startX + coverW + gap, startY}
                set size of window 1 to {tlW, targetH}
            end try
        end tell
    end if
end tell
'''
        subprocess.run(['osascript', '-e', ascript], check=False)

if __name__ == '__main__':
    main()
