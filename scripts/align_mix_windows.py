#!/usr/bin/env python3
"""
scripts/align_mix_windows.py - Cross-Platform Window Alignment for Mix Manager
Positions windows according to active monitor configuration:
- Multi-Display (> 1 displays active):
  * Mix Archive Manager window is displayed on the PRIMARY display (Main Screen),
    always centered, and never full screen or maximized.
  * Strawberry Audio Player and Cover Art Viewer are placed ONLY on the SECONDARY display
    side-by-side with zero overlap: Cover Art (square on left) and Strawberry (player on right).
  * Any tracklist console window is minimized on multi-display so the primary display
    remains exclusively dedicated to the Mix Archive Manager.
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
import re
import json

def get_args():
    parser = argparse.ArgumentParser(description="Mix Archive Manager Window & Display Aligner")
    parser.add_argument("--mgr-pid", type=int, default=0, help="PID of Mix Archive Manager process")
    parser.add_argument("--parent-pid", type=int, default=0, help="Parent/terminal PID of Manager")
    parser.add_argument("--expect-strawberry", action="store_true", help="Wait for Strawberry window to appear")
    parser.add_argument("--expect-cover", action="store_true", help="Wait for Cover window to appear")
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

def get_ancestor_pids(pid):
    """Return list of ancestor PIDs for a process up to init (PID 1)."""
    ancestors = []
    curr = pid
    while curr > 1:
        ancestors.append(curr)
        try:
            with open(f"/proc/{curr}/stat", "r") as f:
                ppid = int(f.read().split()[3])
                if ppid == curr or ppid <= 1:
                    if ppid > 1:
                        ancestors.append(ppid)
                    break
                curr = ppid
        except Exception:
            break
    return ancestors

def get_display_priorities():
    """Detect primary and secondary display names using kscreen-doctor."""
    prim_name = None
    sec_name = None
    try:
        out = subprocess.check_output(['kscreen-doctor', '-o'], stderr=subprocess.DEVNULL, text=True)
        clean = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', out)
        outputs = []
        curr = None
        for line in clean.splitlines():
            ls = line.strip()
            if ls.startswith('Output:'):
                parts = ls.split()
                if len(parts) >= 3:
                    curr = {'name': parts[2], 'priority': 999}
                    outputs.append(curr)
            elif curr and ls.startswith('priority '):
                p_parts = ls.split()
                if len(p_parts) >= 2 and p_parts[1].isdigit():
                    curr['priority'] = int(p_parts[1])
        outputs.sort(key=lambda x: x['priority'])
        if len(outputs) >= 1:
            prim_name = outputs[0]['name']
        if len(outputs) >= 2:
            sec_name = outputs[1]['name']
    except Exception:
        pass
    return prim_name, sec_name

def align_kwin(timeout_seconds=8.0, mgr_pid=0, parent_pid=0, expect_strawberry=False, expect_cover=False):
    """Align windows using KDE Plasma 6 KWin Scripting DBus API."""
    try:
        import dbus
    except ImportError:
        return False

    # Collect ancestor PIDs for Manager window identification
    mgr_ancestors = []
    if mgr_pid > 0:
        mgr_ancestors.extend(get_ancestor_pids(mgr_pid))
    if parent_pid > 0:
        mgr_ancestors.extend(get_ancestor_pids(parent_pid))
    mgr_ancestors = list(set(mgr_ancestors))

    prim_name, sec_name = get_display_priorities()
    run_token = f"T{int(time.time() * 1000)}_{os.getpid()}"

    start_time = time.time()
    poll_interval = 0.25
    aligned_any = False

    while time.time() - start_time < timeout_seconds:
        straw_proc = is_proc_running(['strawberry'])
        cover_proc = is_proc_running(['gwenview', 'loupe', 'eog', 'feh'])

        # Expect Strawberry / Cover if flagged or if their process has launched
        expect_straw = expect_strawberry or straw_proc
        expect_cover = expect_cover or cover_proc

        try:
            bus = dbus.SessionBus()
            kwin_obj = bus.get_object('org.kde.KWin', '/Scripting')
            scripting = dbus.Interface(kwin_obj, 'org.kde.kwin.Scripting')

            js_code = f'''
(function() {{
    var runToken = "{run_token}";
    var mgrAncestorPids = {json.dumps(mgr_ancestors)};
    var mgrPid = {mgr_pid};
    var parentPid = {parent_pid};
    var expectStraw = {str(expect_straw).lower()};
    var expectCover = {str(expect_cover).lower()};
    var primScreenName = "{prim_name or ''}";
    var secScreenName = "{sec_name or ''}";

    var screens = workspace.screenOrder;
    if (!screens || screens.length === 0) {{
        screens = workspace.screens;
    }}
    var numScreens = screens ? screens.length : 1;

    var primScreen = null;
    var secScreen = null;

    if (primScreenName) {{
        for (var s = 0; s < screens.length; s++) {{
            if (screens[s].name === primScreenName) {{
                primScreen = screens[s];
                break;
            }}
        }}
    }}
    if (secScreenName) {{
        for (var s = 0; s < screens.length; s++) {{
            if (screens[s].name === secScreenName) {{
                secScreen = screens[s];
                break;
            }}
        }}
    }}

    if (!primScreen && screens && screens.length > 0) primScreen = screens[0];
    if (!secScreen && screens && screens.length > 1) {{
        secScreen = (screens[1] !== primScreen) ? screens[1] : screens[0];
    }}

    var wins = workspace.windowList();
    var mgrWin = null;
    var strawWin = null;
    var coverWin = null;
    var tlWin = null;

    for (var i = 0; i < wins.length; i++) {{
        var w = wins[i];
        if (!w || !w.caption) continue;
        var cap = w.caption;
        var capLower = cap.toLowerCase();
        var rClass = (w.resourceClass || '').toLowerCase();
        var dName = (w.desktopFileName || '').toLowerCase();

        // 1. Manager Window (Konsole / terminal running Mix Archive Manager)
        if (!mgrWin) {{
            if ((mgrAncestorPids && mgrAncestorPids.indexOf(w.pid) !== -1) ||
                (mgrPid > 0 && w.pid === mgrPid) ||
                (parentPid > 0 && w.pid === parentPid) ||
                cap.indexOf('Mix Archive Manager') !== -1 ||
                cap.indexOf('Mix_Archive_Manager') !== -1 ||
                capLower.indexOf('mix manager') !== -1 ||
                (rClass.indexOf('konsole') !== -1 && (capLower.indexOf('mix') !== -1 || capLower.indexOf('bash_scripts') !== -1))) {{
                mgrWin = w;
                continue;
            }}
        }}

        // 2. Strawberry Audio Player Window
        if (!strawWin) {{
            if (rClass.indexOf('strawberry') !== -1 || 
                capLower.indexOf('strawberry') !== -1 || 
                dName.indexOf('strawberry') !== -1) {{
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
                dName.indexOf('gwenview') !== -1 ||
                rClass.indexOf('loupe') !== -1 ||
                rClass.indexOf('eog') !== -1 ||
                (rClass.indexOf('feh') !== -1 && capLower.indexOf('cover') !== -1) ||
                capLower.indexOf('cover.png') !== -1 ||
                capLower.indexOf('cover.jpg') !== -1 ||
                (capLower.indexOf('cover') !== -1 && rClass.indexOf('konsole') === -1 && rClass.indexOf('sublime') === -1 && rClass.indexOf('dolphin') === -1 && rClass.indexOf('code') === -1)) {{
                coverWin = w;
                continue;
            }}
        }}
    }}

    var isDone = false;

    // =========================================================================
    // MULTI-DISPLAY LOGIC (Only if > 1 displays are active)
    // =========================================================================
    if (numScreens > 1 && primScreen && secScreen) {{
        var pArea = workspace.clientArea(0, primScreen, workspace.currentDesktop);
        var sArea = workspace.clientArea(0, secScreen, workspace.currentDesktop);

        // A. Display ONLY the Manager on the PRIMARY display (Main Screen)
        // Must ALWAYS be centered and NEVER full screen or maximized
        if (mgrWin) {{
            mgrWin.fullScreen = false;
            if (typeof mgrWin.setMaximize === 'function') {{
                mgrWin.setMaximize(false, false);
            }}
            if (typeof mgrWin.quickTileMode !== 'undefined') {{
                mgrWin.quickTileMode = 0;
            }}
            workspace.sendClientToScreen(mgrWin, primScreen);

            var curW = mgrWin.frameGeometry.width;
            var curH = mgrWin.frameGeometry.height;
            var maxAllowedW = Math.floor(pArea.width - 60);
            var maxAllowedH = Math.floor(pArea.height - 60);
            var targetW = curW;
            var targetH = curH;

            // If current size was maximized or fills screen, give standard centered dimensions
            if (targetW >= maxAllowedW || targetW < 750) {{
                targetW = Math.min(1380, Math.floor(pArea.width * 0.72));
            }}
            if (targetH >= maxAllowedH || targetH < 480) {{
                targetH = Math.min(880, Math.floor(pArea.height * 0.8));
            }}

            var posX = Math.floor(pArea.x + (pArea.width - targetW) / 2);
            var posY = Math.floor(pArea.y + (pArea.height - targetH) / 2);

            mgrWin.frameGeometry = {{
                x: posX,
                y: posY,
                width: targetW,
                height: targetH
            }};
            workspace.raiseWindow(mgrWin);
            workspace.activeWindow = mgrWin;
        }}

        // Minimize any tracklist console window so main screen has only the manager
        if (tlWin) {{
            tlWin.minimized = true;
        }}

        // B. Place Strawberry and Cover Photo onto the SECONDARY display (Second Screen)
        var sX = Math.floor(sArea.x);
        var sY = Math.floor(sArea.y);
        var sW = Math.floor(sArea.width);
        var sH = Math.floor(sArea.height);

        // Check if we are still waiting for expected windows to map
        if (expectStraw && !strawWin) {{
            console.warn("MIX_ALIGN_RUN:" + runToken + " DONE:0 WAITING:strawberry");
            return;
        }}
        if (expectCover && !coverWin) {{
            console.warn("MIX_ALIGN_RUN:" + runToken + " DONE:0 WAITING:cover");
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
            if (typeof coverWin.quickTileMode !== 'undefined') coverWin.quickTileMode = 0;
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
            if (typeof strawWin.quickTileMode !== 'undefined') strawWin.quickTileMode = 0;
            workspace.sendClientToScreen(strawWin, secScreen);
            strawWin.frameGeometry = {{ x: strawX, y: strawY, width: strawW, height: strawH }};
            workspace.raiseWindow(strawWin);

            isDone = true;
        }} else if (strawWin && !expectCover) {{
            // Only Strawberry open on secondary display
            strawWin.fullScreen = false;
            if (typeof strawWin.setMaximize === 'function') strawWin.setMaximize(false, false);
            if (typeof strawWin.quickTileMode !== 'undefined') strawWin.quickTileMode = 0;
            workspace.sendClientToScreen(strawWin, secScreen);
            strawWin.frameGeometry = {{ x: sX + 20, y: sY + 20, width: sW - 40, height: sH - 40 }};
            workspace.raiseWindow(strawWin);
            isDone = true;
        }} else if (coverWin && !expectStraw) {{
            // Only Cover open on secondary display
            var targetH = Math.min(sH - 40, Math.max(500, Math.floor(sH * 0.85)));
            var coverW = Math.min(targetH, Math.floor(sW * 0.45));
            coverWin.fullScreen = false;
            if (typeof coverWin.setMaximize === 'function') coverWin.setMaximize(false, false);
            if (typeof coverWin.quickTileMode !== 'undefined') coverWin.quickTileMode = 0;
            workspace.sendClientToScreen(coverWin, secScreen);
            coverWin.frameGeometry = {{
                x: sX + Math.floor((sW - coverW) / 2),
                y: sY + Math.floor((sH - targetH) / 2),
                width: coverW,
                height: targetH
            }};
            coverWin.keepAbove = true;
            workspace.raiseWindow(coverWin);
            isDone = true;
        }} else if (!expectStraw && !expectCover) {{
            // Neither player nor cover running, manager on primary display is aligned
            isDone = true;
        }}

        console.warn("MIX_ALIGN_RUN:" + runToken + " DONE:" + (isDone ? "1" : "0") + " straw=" + (strawWin ? 1 : 0) + " cover=" + (coverWin ? 1 : 0) + " mgr=" + (mgrWin ? 1 : 0));
        return;
    }}

    // =========================================================================
    // SINGLE DISPLAY FALLBACK (<= 1 display active)
    // Keep windows on the single display; center HUD floating above manager
    // =========================================================================
    var refWin = tlWin || coverWin || workspace.activeWindow;
    var screen = (refWin && refWin.output) ? refWin.output : (primScreen || workspace.activeScreen);
    var sArea = workspace.clientArea(0, screen, workspace.currentDesktop);
    var sX = Math.floor(sArea.x);
    var sY = Math.floor(sArea.y);
    var sW = Math.floor(sArea.width);
    var sH = Math.floor(sArea.height);

    // Center Manager on single display (not full screen)
    if (mgrWin) {{
        mgrWin.fullScreen = false;
        if (typeof mgrWin.setMaximize === 'function') mgrWin.setMaximize(false, false);
        if (typeof mgrWin.quickTileMode !== 'undefined') mgrWin.quickTileMode = 0;
        workspace.sendClientToScreen(mgrWin, screen);

        var curW = mgrWin.frameGeometry.width;
        var curH = mgrWin.frameGeometry.height;
        var maxAllowedW = Math.floor(sW - 40);
        var maxAllowedH = Math.floor(sH - 40);
        var targetW = curW;
        var targetH = curH;

        if (targetW >= maxAllowedW || targetW < 750) {{
            targetW = Math.min(1360, Math.floor(sW * 0.75));
        }}
        if (targetH >= maxAllowedH || targetH < 480) {{
            targetH = Math.min(860, Math.floor(sH * 0.8));
        }}

        mgrWin.frameGeometry = {{
            x: sX + Math.floor((sW - targetW) / 2),
            y: sY + Math.floor((sH - targetH) / 2),
            width: targetW,
            height: targetH
        }};
        workspace.raiseWindow(mgrWin);
    }}

    if (!coverWin && !tlWin) {{
        console.warn("MIX_ALIGN_RUN:" + runToken + " DONE:1 straw=0 cover=0 mgr=" + (mgrWin ? 1 : 0) + " screens=1");
        return;
    }}

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
        coverWin.fullScreen = false;
        if (typeof coverWin.setMaximize === 'function') coverWin.setMaximize(false, false);
        workspace.sendClientToScreen(coverWin, screen);
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
        tlWin.fullScreen = false;
        if (typeof tlWin.setMaximize === 'function') tlWin.setMaximize(false, false);
        workspace.sendClientToScreen(tlWin, screen);
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

    console.warn("MIX_ALIGN_RUN:" + runToken + " DONE:1 straw=" + (strawWin ? 1 : 0) + " cover=" + (coverWin ? 1 : 0) + " mgr=" + (mgrWin ? 1 : 0) + " screens=1");
}})();
'''

            with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as f:
                f.write(js_code)
                tmp_js = f.name

            pname = f"mix_align_{int(time.time() * 1000)}"
            try:
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

            # Check journalctl for completion token of this specific execution
            try:
                res = subprocess.run(['journalctl', '--user', '-n', '25', '--no-pager'], capture_output=True, text=True)
                for line in reversed(res.stdout.splitlines()):
                    if f"MIX_ALIGN_RUN:{run_token}" in line:
                        if "DONE:1" in line:
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

            if not mgr_win and ((mgr_pid > 0 and pid == mgr_pid) or 'mix archive manager' in t_lower or 'mix_archive_manager' in t_lower):
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

            # Manager -> Primary display: ALWAYS centered and NEVER full screen
            if mgr_win:
                subprocess.run(['wmctrl', '-i', '-r', mgr_win, '-b', 'remove,maximized_vert,maximized_horz,fullscreen'], check=False)
                target_w = min(1380, int(prim['w'] * 0.72))
                target_h = min(880, int(prim['h'] * 0.8))
                pos_x = prim['x'] + (prim['w'] - target_w) // 2
                pos_y = prim['y'] + (prim['h'] - target_h) // 2
                subprocess.run(['wmctrl', '-i', '-r', mgr_win, '-e', f"0,{pos_x},{pos_y},{target_w},{target_h}"], check=False)
                subprocess.run(['wmctrl', '-i', '-a', mgr_win], check=False)

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

                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-b', 'remove,maximized_vert,maximized_horz,fullscreen'], check=False)
                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-e', f"0,{cov_x},{cov_y},{cov_w},{cov_h}"], check=False)
                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-b', 'add,above'], check=False)

                straw_x = cov_x + cov_w + gap
                straw_w = (s_x + s_w) - straw_x - 15
                straw_y = s_y + 15
                straw_h = s_h - 30

                subprocess.run(['wmctrl', '-i', '-r', straw_win, '-b', 'remove,maximized_vert,maximized_horz,fullscreen'], check=False)
                subprocess.run(['wmctrl', '-i', '-r', straw_win, '-e', f"0,{straw_x},{straw_y},{straw_w},{straw_h}"], check=False)

            elif straw_win:
                subprocess.run(['wmctrl', '-i', '-r', straw_win, '-b', 'remove,maximized_vert,maximized_horz,fullscreen'], check=False)
                subprocess.run(['wmctrl', '-i', '-r', straw_win, '-e', f"0,{s_x + 20},{s_y + 20},{s_w - 40},{s_h - 40}"], check=False)
            elif cover_win:
                cov_w = min(s_h - 40, int(s_w * 0.45))
                cov_x = s_x + (s_w - cov_w) // 2
                cov_y = s_y + (s_h - cov_w) // 2
                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-b', 'remove,maximized_vert,maximized_horz,fullscreen'], check=False)
                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-e', f"0,{cov_x},{cov_y},{cov_w},{cov_w}"], check=False)
                subprocess.run(['wmctrl', '-i', '-r', cover_win, '-b', 'add,above'], check=False)

            return True

        # Single-display fallback
        if mgr_win:
            s = screens[0]
            subprocess.run(['wmctrl', '-i', '-r', mgr_win, '-b', 'remove,maximized_vert,maximized_horz,fullscreen'], check=False)
            target_w = min(1360, int(s['w'] * 0.75))
            target_h = min(860, int(s['h'] * 0.8))
            pos_x = s['x'] + (s['w'] - target_w) // 2
            pos_y = s['y'] + (s['h'] - target_h) // 2
            subprocess.run(['wmctrl', '-i', '-r', mgr_win, '-e', f"0,{pos_x},{pos_y},{target_w},{target_h}"], check=False)

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
        if align_kwin(timeout_seconds=args.timeout, mgr_pid=args.mgr_pid, parent_pid=args.parent_pid,
                      expect_strawberry=args.expect_strawberry, expect_cover=args.expect_cover):
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
