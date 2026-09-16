#!/usr/bin/env python3
"""ws — restore the Otty workspace after the lid closes.

Run it from any tab of the workspace window. Tabs are grouped by the sidebar
dividers (right-click between tabs → Insert Divider); tabs above the first
divider form the "local" group. For each group in LAYOUT, ws:

- reconnects remote tabs whose ssh has dropped (tab not busy); busy tabs are left alone,
- opens the tabs a group is missing, placed inside that group,
- never closes a tab, and cannot create dividers (Otty has no API for them).

Keep a tab above the first divider: Otty deletes the first divider when the last
tab under it closes and nothing sits above it.
"""
import json
import os
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

HOME = str(Path.home())
ALI_DIR = "/mnt/cpfs/xuyucheng"
# ~/.ssh/config's keepalive (300s × 9999) never notices a link that died during
# sleep; these make a dropped connection exit within ~45s so ws can reconnect it.
KEEPALIVE = "-o ServerAliveInterval=15 -o ServerAliveCountMax=3"

FILES = "files"  # a file-browser tab at ~ (matches any file tab in the group)
SHELL = "shell"  # a local terminal tab (matches any terminal tab in the group)

ALI_SHELL = f"ssh -t {KEEPALIVE} ali 'cd {ALI_DIR} && exec bash'"
# `bash -ic` loads ~/.bashrc so ~/.local/bin (claude) is on PATH; `exec bash` keeps
# the tab usable after claude exits.
ALI_CLAUDE = f"ssh -t {KEEPALIVE} ali 'cd {ALI_DIR} && bash -ic claude; exec bash'"

# Divider name → the tabs that group should hold, in order. Remote tabs beyond the
# list reuse its last command when reconnecting.
LAYOUT = {
    "local": [FILES, SHELL],
    "ali": [ALI_SHELL, ALI_CLAUDE, ALI_CLAUDE],
    "stepmind": [f"ssh {KEEPALIVE} stepmind"],
}

STATE_DB = Path.home() / "Library/Application Support/io.appmakes.otty/state.db"

# The tab ws runs in can't be reconnected from inside ws, so its command is printed
# on this marker line for the calling shell to run (see the ws function in alias.zsh).
SELF_MARKER = "__ws_exec__"

# `do script` runs the command in an existing tab (unlike recipe replay, it presses Enter).
RECONNECT = """
on run argv
  set wanted to item 1 of argv
  set cmd to item 2 of argv
  tell application "Otty"
    repeat with w in windows
      repeat with t in tabs of w
        if (id of t) is wanted then
          if busy of t then return "busy"
          do script cmd in t
          return "reconnected"
        end if
      end repeat
    end repeat
  end tell
  return "missing"
end run
"""


def otty(*args):
    return json.loads(subprocess.check_output(["otty", *args, "--json"]))["data"]


def read_groups(window_id):
    """[(group, [(live tab id, content type)])] in sidebar order.

    Dividers only exist in Otty's saved window state, as '---<name>' entries among
    the saved tab ids. Saved panes share ids with live tabs (minus the t_ prefix),
    which ties each saved tab to the live tab the CLI and AppleScript drive.
    """
    live = {t["id"] for t in otty("tab", "list") if t["window_id"] == window_id}
    db = sqlite3.connect(f"file:{STATE_DB}?mode=ro", uri=True)
    try:
        row = db.execute(
            "select tab_ids from window where id = ?", (window_id.removeprefix("w_"),)
        ).fetchone()
        if row is None:
            sys.exit("ws: Otty hasn't saved this window yet — try again in a moment")
        groups = [("local", [])]
        for entry in json.loads(row[0]):
            if entry.startswith("---"):
                groups.append((entry[3:], []))
                continue
            pane = db.execute(
                "select id, content_type from pane where tab_id = ?"
                " and (closed_at is null or closed_at = '') order by rowid limit 1",
                (entry,),
            ).fetchone()
            if pane and "t_" + pane[0] in live:
                groups[-1][1].append(("t_" + pane[0], pane[1]))
        return groups
    finally:
        db.close()


def tab_count(groups):
    return sum(len(tabs) for _, tabs in groups)


def wait_for_tab(window_id, count):
    """Re-read the groups until Otty has saved `count` tabs (it saves within ~1s)."""
    for _ in range(40):
        groups = read_groups(window_id)
        if tab_count(groups) >= count:
            return groups
        time.sleep(0.25)
    sys.exit("ws: Otty didn't save the new tab — run ws again")


def open_tab(window_id, groups, group, kind):
    """Open a tab at the end of `group`; returns the refreshed groups."""
    # New tabs (`tab new` and `view --new-tab`) land right after the focused tab and
    # stay above the next divider; `tab new --after` has no effect on placement.
    otty("tab", "focus", dict(groups)[group][-1][0])
    if kind == FILES:
        otty("view", HOME, "--new-tab")
    elif kind == SHELL:
        otty("tab", "new", "--window", window_id, "--no-focus", "--cwd", HOME)
    else:
        otty("tab", "new", "--window", window_id, "--no-focus", "--command", kind)
    return wait_for_tab(window_id, tab_count(groups) + 1)


def reconnect(tab_id, command):
    return subprocess.check_output(
        ["osascript", "-", tab_id.removeprefix("t_"), command],
        input=RECONNECT,
        text=True,
    ).strip()


def main():
    pane_id = os.environ.get("OTTY_PANE_ID")
    if not pane_id:
        sys.exit("ws: run this from a tab in the Otty workspace window")
    pane = otty("pane", "show", pane_id)
    window_id, home_tab = pane["window_id"], pane["tab_id"]

    groups = read_groups(window_id)
    ssh_started = False
    self_command = None

    for group, wanted in LAYOUT.items():
        if group not in dict(groups):
            print(f"{group}: no '{group}' divider — add one (right-click between tabs → Insert Divider)")
            continue
        if not dict(groups)[group]:
            # An empty group can't be filled: a tab placed after the previous group's
            # last tab lands above this group's divider, not under it.
            print(f"{group}: no tabs under the divider — drag one tab under it, then run ws again")
            continue

        if group == "local":
            content_type = {FILES: "file", SHELL: "terminal"}
            for i, kind in enumerate(wanted):
                if any(c == content_type[kind] for _, c in dict(groups)[group]):
                    state = "open"
                else:
                    groups = open_tab(window_id, groups, group, kind)
                    state = "opened"
                print(f"local {i + 1}: {state}")
            continue

        for i in range(max(len(dict(groups)[group]), len(wanted))):
            command = wanted[min(i, len(wanted) - 1)]
            # Otty's zsh ssh wrapper deletes every *empty* /tmp/otty-ssh.* dir when any
            # ssh exits, so a fast-failing ssh would wipe the ControlMaster sockets of
            # tabs still connecting ("unix_listener: cannot bind to path"). Stagger.
            if ssh_started:
                time.sleep(2)
            tabs = dict(groups)[group]
            if i < len(tabs):
                if tabs[i][0] == home_tab:
                    # This tab is busy running ws itself, and a command sent here now
                    # would be swallowed by the running script — hand it to the shell
                    # that called ws (see the ws function in zsh/alias.zsh).
                    self_command = command
                    state = "self"
                else:
                    state = reconnect(tabs[i][0], command)
            else:
                groups = open_tab(window_id, groups, group, command)
                state = "opened"
            ssh_started = ssh_started or state in ("reconnected", "opened")
            print(f"{group} {i + 1}: {state}")

    otty("tab", "focus", home_tab)
    if self_command:
        print(f"{SELF_MARKER} {self_command}")


if __name__ == "__main__":
    main()
