#!/usr/bin/env python3
"""
scripts/align_mix_windows.py - Cross-Platform Window Alignment for Mix Manager
Positions windows according to active monitor configuration:
- Multi-Display (> 1 displays active):
  * Mix Archive Manager window is displayed on the PRIMARY display (Main Screen).
  * Strawberry Audio Player and Cover Art Viewer are placed on the SECONDARY display side-by-side.
  * Windows on the secondary display are arranged with zero overlap: Cover Art (1:1 square on left)
    and Strawberry (controls, playlist, and waveform on right).
  * Any tracklist console window is minimized so only the manager is visible on the primary display
    and only Strawberry and Cover are visible on the secondary display.
- Single-Display (<= 1 display active):
  * Keeps windows on the single active display, centering Cover Art & Tracklist HUD floating above Manager.
"""

import sys
import os
import time
import platform
import subprocess
import argparse
import tempfile

def get_args():
    parser = argparse.ArgumentParser(description="Mix Archive Manager Window & Display Aligner")
    parser.add_argument("--mgr-pid", type=int, default=0, help="PID of Mix Archive Manager process")
    parser.add_argument("--parent-pid", type=int, default=0, help="Parent/terminal PID of Manager")
    parser.add_argument("--timeout", type=float, default=8.0, help="Timeout in seconds for window polling")
    return parser.parse_known_args()[0]

def is_proc_running(names):
    """Check if any of the given process names are currently running (excluding own process)."""
    my_pid = os.getpid()
    for name in names:
        try:
            out = subprocess.check_output(['pgrep', '-i', name], stderr=subprocess.DEVNULL).decode()
            pids = [int(p) for p in out.split() if p.isdigit() and int(p) != my_pid]
            if pids:
                return True
        except Exception:
            pass
    return False

def align_kwin(timeout_seconds=8.0, mgr_pid=0, parent_pid=0):
    """Align windows using KDE Plasma 6 KWin Scripting DBus API."""
    try:
        import dbus
    except ImportError:
        return False

    start_time = time.time()
    poll_interval = 0.25
    aligned_any = False

    while time.time() - start_time < timeout_seconds:
        try:
            bus = dbus.SessionBus()
            kwin_obj = bus.get_object('org.kde.KWin', '/Scripting')
            scripting = dbus.Interface(kwin_obj, 'org.kde.kwin.Scripting')

            straw_running = is_proc_running(['strawberry'])
            cover_running = is_proc_running(['gwenview', 'loupe', 'eog', 'feh'])

            js_code = f'''
(function() {{
    var mgrPid = {mgr_pid};
    var parentPid = {parent_pid};
    var strawProcRunning = {str(straw_running).lower()};
    var coverProcRunning = {str(cover_running).lower()};

    var screens = workspace.screenOrder;
    if (!screens || screens.length === 0) {{
        screens = workspace.screens;
    }}
    var numScreens = screens ? screens.length : 1;

    var wins = workspace.windowList();
    var mgrWin = null;
    var strawWin = null;
    var coverWin = null;
    var tlWin = null;

    for (var i = 0; i < wins.length; i++) {{
        var w = wins[i];
        if (!w || !w.caption) continue;
        var cap = w.caption;
        var rClass = (w.resourceClass || '').toLowerCase();
        var capLower = cap.toLowerCase();

        // 1. Manager Window (Konsole / terminal running Mix Archive Manager)
        if (!mgrWin) {{
            if ((mgrPid > 0 && w.pid === mgrPid) ||
                (parentPid > 0 && w.pid === parentPid) ||
                cap.indexOf('Mix Archive Manager') !== -1 ||
                (rClass.indexOf('konsole') !== -1 && cap.indexOf('Mix Archive Manager') !== -1)) {{
                mgrWin = w;
                continue;
            }}
        }}

        // 2. Strawberry Audio Player Window
        if (!strawWin) {{
            if (rClass.indexOf('strawberry') !== -1 || 
                capLower.indexOf('strawberry') !== -1 || 
                (w.desktopFileName && w.desktopFileName.indexOf('strawberry') !== -1)) {{
                strawWin = w;
                continue;
            }}
        }}

        // 3. Tracklist Console Window
        if (!tlWin) {{
            if (cap.indexOf('Mix Tracklist Viewer') !== -1 || 
                (cap.indexOf('Tracklist') !== -1 && rClass.indexOf('konsole') !== -1)) {{
                tlWin = w;
                continue;
            }}
        }}

        // 4. Cover Photo Window (Gwenview / feh / loupe / eog)
        if (!coverWin) {{
            if (cap.indexOf('Mix Cover Art Viewer') !== -1 || 
                rClass.indexOf('gwenview') !== -1 || 
                capLower.indexOf('gwenview') !== -1 || 
                (w.desktopFileName && w.desktopFileName.indexOf('gwenview') !== -1) ||
                rClass.indexOf('loupe') !== -1 ||
                rClass.indexOf('eog') !== -1 ||
                (rClass.indexOf('feh') !== -1 && capLower.indexOf('cover') !== -1) ||
                (capLower.indexOf('cover') !== -1 && rClass.indexOf('konsole') === -1 && rClass.indexOf('sublime') === -1 && rClass.indexOf('dolphin') === -1)) {{
                coverWin = w;
                continue;
            }}
        }}
    }}

    // =========================================================================
    // MULTI-DISPLAY LOGIC (Only if > 1 displays are active)
    // =========================================================================
    if (numScreens > 1) {{
        var primScreen = screens[0];
        var secScreen = screens[1];
        var pArea = workspace.clientArea(0, primScreen, workspace.currentDesktop);
        var sArea = workspace.clientArea(0, secScreen, workspace.currentDesktop);

        // A. Display ONLY the Manager on the PRIMARY display (Main Screen)
        if (mgrWin) {{
            if (mgrWin.fullScreen) {{
                mgrWin.fullScreen = false;
                workspace.sendClientToScreen(mgrWin, primScreen);
                mgrWin.frameGeometry = {{
                    x: pArea.x,
                    y: pArea.y,
                    width: pArea.width,
                    height: pArea.height
                }};
                mgrWin.fullScreen = true;
            }} else {{
                workspace.sendClientToScreen(mgrWin, primScreen);
                var targetW = Math.min(mgrWin.frameGeometry.width, pArea.width - 40);
                var targetH = Math.min(mgrWin.frameGeometry.height, pArea.height - 40);
                mgrWin.frameGeometry = {{
                    x: pArea.x + Math.max(10, Math.floor((pArea.width - targetW) / 2)),
                    y: pArea.y + Math.max(10, Math.floor((pArea.height - targetH) / 2)),
                    width: targetW,
                    height: targetH
                }};
            }}
            workspace.raiseWindow(mgrWin);
        }}

        // Minimize any tracklist console window so main screen has only manager
        if (tlWin) {{
            tlWin.minimized = true;
        }}

        // B. Place Strawberry and Cover Photo onto the SECONDARY display (Second Screen)
        var sX = sArea.x;
        var sY = sArea.y;
        var sW = sArea.width;
        var sH = sArea.height;

        // If an expected player or viewer process is running but window not mapped yet, wait
        if (strawProcRunning && !strawWin) {{
            console.warn("MIX_ALIGN_STATE: done=0 straw=0 cover=" + (coverWin ? 1 : 0) + " mgr=" + (mgrWin ? 1 : 0) + " screens=" + numScreens);
            return;
        }}
        if (coverProcRunning && !coverWin) {{
            console.warn("MIX_ALIGN_STATE: done=0 straw=" + (strawWin ? 1 : 0) + " cover=0 mgr=" + (mgrWin ? 1 : 0) + " screens=" + numScreens);
            return;
        }}

        // Case 1: Both Cover and Strawberry are present on secondary display
        if (coverWin && strawWin) {{
            var gap = 16;
            var coverW = Math.min(sH - 40, Math.floor(sW * 0.42));
            var coverH = coverW;
            var coverX = sX + 15;
            var coverY = sY + Math.floor((sH - coverH) / 2);

            coverWin.fullScreen = false;
            if (typeof coverWin.setMaximize === 'function') coverWin.setMaximize(false, false);
            workspace.sendClientToScreen(coverWin, secScreen);
            coverWin.frameGeometry = {{ x: coverX, y: coverY, width: coverW, height: coverH }};
            coverWin.keepAbove = true;
            workspace.raiseWindow(coverWin);

            var strawX = coverX + coverW + gap;
            var strawW = (sX + sW) - strawX - 15;
            var strawY = sY + 15;
            var strawH = sH - 30;
            strawWin.fullScreen = false;
            if (typeof strawWin.setMaximize === 'function') strawWin.setMaximize(false, false);
            workspace.sendClientToScreen(strawWin, secScreen);
            strawWin.frameGeometry = {{ x: strawX, y: strawY, width: strawW, height: strawH }};
            workspace.raiseWindow(strawWin);

            console.warn("MIX_ALIGN_STATE: done=1 straw=1 cover=1 mgr=" + (mgrWin ? 1 : 0) + " screens=" + numScreens);
            return;
        }} else if (strawWin && !coverProcRunning) {{
            // Only Strawberry expected and open on secondary display
            strawWin.fullScreen = false;
            if (typeof strawWin.setMaximize === 'function') strawWin.setMaximize(false, false);
            workspace.sendClientToScreen(strawWin, secScreen);
            strawWin.frameGeometry = {{ x: sX + 20, y: sY + 20, width: sW - 40, height: sH - 40 }};
            workspace.raiseWindow(strawWin);
            console.warn("MIX_ALIGN_STATE: done=1 straw=1 cover=0 mgr=" + (mgrWin ? 1 : 0) + " screens=" + numScreens);
            return;
        }} else if (coverWin && !strawProcRunning) {{
            // Only Cover expected and open on secondary display
            var targetH = Math.min(sH - 40, Math.max(500, Math.floor(sH * 0.85)));
            var coverW = Math.min(targetH, Math.floor(sW * 0.45));
            coverWin.fullScreen = false;
            if (typeof coverWin.setMaximize === 'function') coverWin.setMaximize(false, false);
            workspace.sendClientToScreen(coverWin, secScreen);
            coverWin.frameGeometry = {{
                x: sX + Math.floor((sW - coverW) / 2),
                y: sY + Math.floor((sH - targetH) / 2),
                width: coverW,
                height: targetH
            }};
            coverWin.keepAbove = true;
            workspace.raiseWindow(coverWin);
            console.warn("MIX_ALIGN_STATE: done=1 straw=0 cover=1 mgr=" + (mgrWin ? 1 : 0) + " screens=" + numScreens);
            return;
        }} else if (!strawProcRunning && !coverProcRunning) {{
            // Neither player nor cover running, manager on primary display is aligned
            console.warn("MIX_ALIGN_STATE: done=1 straw=0 cover=0 mgr=" + (mgrWin ? 1 : 0) + " screens=" + numScreens);
            return;
        }}

        console.warn("MIX_ALIGN_STATE: done=0 straw=" + (strawWin ? 1 : 0) + " cover=" + (coverWin ? 1 : 0) + " mgr=" + (mgrWin ? 1 : 0) + " screens=" + numScreens);
        return;
    }}

    // =========================================================================
    // SINGLE DISPLAY FALLBACK (<= 1 display active)
    // Keep windows on the single display; center HUD floating above manager
    // =========================================================================
    if (!coverWin && !tlWin) {{
        console.warn("MIX_ALIGN_STATE: done=1 straw=0 cover=0 mgr=" + (mgrWin ? 1 : 0) + " screens=1");
        return;
    }}

    var refWin = tlWin || coverWin || workspace.activeWindow;
    var screen = refWin && refWin.output ? refWin.output : workspace.activeScreen;
    var sArea = workspace.clientArea(0, screen, workspace.currentDesktop);
    var sX = sArea.x;
    var sY = sArea.y;
    var sW = sArea.width;
    var sH = sArea.height;

    var targetH = Math.min(760, Math.max(500, Math.floor(sH * 0.65)));
    var coverW = coverWin ? Math.min(targetH, Math.floor(sW * 0.38)) : 0;
    var tlW = tlWin ? Math.min(960, Math.max(680, Math.floor(sW * 0.44))) : 0;
    var gap = (coverWin && tlWin) ? 24 : 0;

    var totalW = coverW + gap + tlW;
    if (totalW > sW - 40) {{
        var scale = (sW - 60) / totalW;
        coverW = Math.floor(coverW * scale);
        tlW = Math.floor(tlW * scale);
        targetH = Math.floor(targetH * scale);
        totalW = coverW + gap + tlW;
    }}

    var startX = sX + Math.max(10, Math.floor((sW - totalW) / 2));
    var startY = sY + Math.max(10, Math.floor((sH - targetH) / 2));

    if (coverWin) {{
        coverWin.keepAbove = true;
        coverWin.frameGeometry = {{
            x: startX,
            y: startY,
            width: coverW,
            height: targetH
        }};
        workspace.raiseWindow(coverWin);
    }}

    if (tlWin) {{
        var tlX = coverWin ? (startX + coverW + gap) : startX;
        tlWin.keepAbove = true;
        tlWin.noBorder = true;
        tlWin.frameGeometry = {{
            x: tlX,
            y: startY,
            width: tlW,
            height: targetH
        }};
        workspace.raiseWindow(tlWin);
    }}

    console.warn("MIX_ALIGN_STATE: done=1 straw=" + (strawWin ? 1 : 0) + " cover=" + (coverWin ? 1 : 0) + " mgr=" + (mgrWin ? 1 : 0) + " screens=1");
}})();
'''
            with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as f:
                f.write(js_code)
                tmp_js = f.name

            pname = f"mix_align_{int(time.time() * 1000)}"
            try:
                # In KDE Plasma 6, loadScript requires filePath and pluginName with signature 'ss'
                num = scripting.loadScript(tmp_js, pname, signature='ss')
                if num >= 0:
                    script_obj = bus.get_object('org.kde.KWin', f'/Scripting/Script{num}')
                    script_obj.run()
                    aligned_any = True
                try:
                    scripting.unloadScript(pname)
                except Exception:
                    pass
            finally:
                if os.path.exists(tmp_js):
                    os.remove(tmp_js)

            # Check journalctl for completion status
            try:
                res = subprocess.run(['journalctl', '--user', '-n', '10', '--no-pager'], capture_output=True, text=True)
                for line in reversed(res.stdout.splitlines()):
                    if "MIX_ALIGN_STATE:" in line:
                        if "done=1" in line:
                            return True
                        break
            except Exception:
                pass

        except Exception:
            pass

        time.sleep(poll_interval)

    return aligned_any

def align_x11(mgr_pid=0):
    """Align windows using wmctrl / xdotool / xrandr on X11."""
    if not (shutil_which('wmctrl') and shutil_which('xrandr')):
        return False
    try:
        out = subprocess.check_output(['xrandr', '--query'], text=True, errors='ignore')
        screens = []
        for line in out.splitlines():
            if ' connected ' in line:
                parts = line.split()
                name = parts[0]
                is_primary = 'primary' in line
                geo_str = None
                for p in parts[2:]:
                    if 'x' in p and '+' in p:
                        geo_str = p
                        break
                if geo_str:
                    try:
                        wh, x, y = geo_str.split('+')[0], int(geo_str.split('+')[1]), int(geo_str.split('+')[2])
                        w, h = int(wh.split('x')[0]), int(wh.split('x')[1])
                        screens.append({'name': name, 'primary': is_primary, 'x': x, 'y': y, 'w': w, 'h': h})
                    except Exception:
                        pass

        if not screens:
            return False

        # Sort: primary first, then others
        screens.sort(key=lambda s: 0 if s['primary'] else 1)
        num_screens = len(screens)

        # Query windows
        wm_out = subprocess.check_output(['wmctrl', '-l', '-p', '-G'], text=True, errors='ignore')
        mgr_win = None
        cover_win = None
        straw_win = None
        tl_win = None

        for line in wm_out.splitlines():
            parts = line.split(maxsplit=8)
            if len(parts) < 9:
                continue
            wid, dsk, pid_str, x, y, w, h, host, title = parts[0], parts[1], parts[2], int(parts[3]), int(parts[4]), int(parts[5]), int(parts[6]), parts[7], parts[8]
            pid = int(pid_str) if pid_str.isdigit() else 0
            t_lower = title.lower()

            if not mgr_win and ((mgr_pid > 0 and pid == mgr_pid) or 'mix archive manager' in t_lower):
                mgr_win = wid
            elif not straw_win and 'strawberry' in t_lower:
                straw_win = wid
            elif not tl_win and ('mix tracklist viewer' in t_lower or 'tracklist' in t_lower):
                tl_win = wid
            elif not cover_win and ('mix cover' in t_lower or 'gwenview' in t_lower or 'cover' in t_lower):
                cover_win = wid

        if num_screens > 1:
            prim = screens[0]
            sec = screens[1]

            # Manager -> Primary display
            if mgr_win:
                subprocess.run(['wmctrl', '-i', '-r', mgr_win, '-e', f"0,{prim['x']},{prim['y']},{prim['w']},{prim['h']}"], check=False)
                subprocess.run(['wmctrl', '-i', '-r', mgr_win, '-b', 'add,maximized_vert,maximized_horz'], check=False)

            # Minimize tracklist window on multi-display
            if tl_win:
                subprocess.run(['wmctrl', '-i', '-r', tl_win, '-b', 'add,hidden'], check=False)

            # Secondary display: Cover (left) + Strawberry (right)
            s_x, s_y, s_w, s_h = sec['x'], sec['y'], sec['w'], sec['h']

            if cover_win and straw_win:
                gap = 16
                cov_w = min(s_h - 40, int(s_w * 0.42))
                cov_h = cov_w
                cov_x = s_x + 15
                cov_y = s_y + (s_h - cov_h) // 2

                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-b', 'remove,maximized_vert,maximized_horz'], check=False)
                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-e', f"0,{cov_x},{cov_y},{cov_w},{cov_h}"], check=False)
                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-b', 'add,above'], check=False)

                straw_x = cov_x + cov_w + gap
                straw_w = (s_x + s_w) - straw_x - 15
                straw_y = s_y + 15
                straw_h = s_h - 30

                subprocess.run(['wmctrl', '-i', '-r', straw_win, '-b', 'remove,maximized_vert,maximized_horz'], check=False)
                subprocess.run(['wmctrl', '-i', '-r', straw_win, '-e', f"0,{straw_x},{straw_y},{straw_w},{straw_h}"], check=False)

            elif straw_win:
                subprocess.run(['wmctrl', '-i', '-r', straw_win, '-e', f"0,{s_x + 20},{s_y + 20},{s_w - 40},{s_h - 40}"], check=False)
            elif cover_win:
                cov_w = min(s_h - 40, int(s_w * 0.45))
                cov_x = s_x + (s_w - cov_w) // 2
                cov_y = s_y + (s_h - cov_w) // 2
                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-e', f"0,{cov_x},{cov_y},{cov_w},{cov_w}"], check=False)
                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-b', 'add,above'], check=False)

            return True

        # Single-display fallback
        if cover_win or tl_win:
            s = screens[0]
            target_h = min(720, max(500, int(s['h'] * 0.62)))
            cov_w = target_h
            tl_w = min(900, max(680, int(s['w'] * 0.42)))
            gap = 20
            total_w = cov_w + gap + tl_w
            start_x = s['x'] + max(10, (s['w'] - total_w) // 2)
            start_y = s['y'] + max(10, (s['h'] - target_h) // 2)

            if cover_win:
                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-e', f"0,{start_x},{start_y},{cov_w},{target_h}"], check=False)
                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-b', 'add,above'], check=False)
            if tl_win:
                tl_x = start_x + cov_w + gap
                subprocess.run(['wmctrl', '-i', '-r', tl_win, '-e', f"0,{tl_x},{start_y},{tl_w},{target_h}"], check=False)
                subprocess.run(['wmctrl', '-i', '-r', tl_win, '-b', 'add,above'], check=False)
            return True

    except Exception:
        return False
    return False

def shutil_which(cmd):
    from shutil import which
    return which(cmd) is not None

def main():
    args = get_args()
    sys_name = platform.system().lower()

    if sys_name == 'linux':
        if align_kwin(timeout_seconds=args.timeout, mgr_pid=args.mgr_pid, parent_pid=args.parent_pid):
            sys.exit(0)
        align_x11(mgr_pid=args.mgr_pid)
    elif sys_name == 'darwin':
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
