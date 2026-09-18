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
#
# Otty's zsh ssh wrapper mints its ControlMaster socket in a fresh /tmp/otty-ssh.*
# dir, and every ssh that exits deletes all *empty* such dirs — including those of
# tabs still connecting, whose ssh then dies on "unix_listener: cannot bind". One
# unreachable host (stepmind off VPN) took the other tabs down with it. The wrapper
# leaves a caller-supplied ControlPath alone, so each tab slot gets its own socket
# ({socket}, filled in per slot). ControlMaster=auto unlinks a stale one before
# binding; ControlPersist=no ties the master to its tab's session.
SSH_OPTS = (
    "-o ServerAliveInterval=15 -o ServerAliveCountMax=3"
    " -o ControlMaster=auto -o ControlPath={socket} -o ControlPersist=no"
)

# The local tab kind, named by the pane content type Otty saves for it.
SHELL = "terminal"  # a local terminal tab (matches any terminal tab in the group)

ALI_SHELL = f"ssh -t {SSH_OPTS} ali 'cd {ALI_DIR} && exec zsh -l'"
# `zsh -ic` loads ~/.zshrc so ~/.local/bin (claude) is on PATH. The fallback shell
# has to be exec'd *inside* that same interactive shell: as a sibling command
# (`zsh -ic claude; exec zsh`) the tab dropped out of ssh back to this Mac when
# claude exited. -o ignoreeof makes the fallback shell shrug off a stray Ctrl-D —
# e.g. one more than claude consumed on its way out — instead of closing the ssh
# session; `exit` still does.
ALI_CLAUDE = (
    f"ssh -t {SSH_OPTS} ali "
    f"""'cd {ALI_DIR} && exec zsh -ic "claude; exec zsh -o ignoreeof -i"'"""
)

# Divider name → the tabs that group should hold, in order. Remote tabs beyond the
# list reuse its last command when reconnecting.
LAYOUT = {
    "local": [SHELL],
    "ali": [ALI_SHELL, ALI_CLAUDE, ALI_CLAUDE],
    "stepmind": [f"ssh {SSH_OPTS} stepmind"],
}

STATE_DB = Path.home() / "Library/Application Support/io.appmakes.otty/state.db"

# The tab ws runs in can't be reconnected from inside ws, so its command is printed
# on this marker line for the calling shell to run (see the ws function in zsh/alias.local.zsh).
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
    """{group: [(live tab id, {content types})]} in sidebar order.

    Dividers only exist in Otty's saved window state, as '---<name>' entries among
    the saved tab ids. Saved panes share ids with live panes (minus the p_ prefix),
    which ties each saved tab to the live tab the CLI and AppleScript drive. Every
    pane is tried: a split tab keeps the id of its first pane, which may be closed,
    and the CLI doesn't list file panes, whose ids match their tab's instead.
    """
    live = {t["id"] for t in otty("tab", "list") if t["window_id"] == window_id}
    pane_tab = {p["id"].removeprefix("p_"): p["tab_id"] for p in otty("pane", "list")}
    db = sqlite3.connect(f"file:{STATE_DB}?mode=ro", uri=True)
    try:
        row = db.execute(
            "select tab_ids from window where id = ?", (window_id.removeprefix("w_"),)
        ).fetchone()
        if row is None:
            sys.exit("ws: Otty hasn't saved this window yet — try again in a moment")
        groups = {"local": []}
        tabs = groups["local"]
        for entry in json.loads(row[0]):
            if entry.startswith("---"):
                tabs = groups[entry[3:]] = []
                continue
            panes = db.execute(
                "select id, content_type from pane where tab_id = ?"
                " and (closed_at is null or closed_at = '') order by rowid",
                (entry,),
            ).fetchall()
            tab_ids = {pane_tab.get(pane_id, "t_" + pane_id) for pane_id, _ in panes} & live
            if tab_ids:
                tabs.append((tab_ids.pop(), {c for _, c in panes}))
        return groups
    finally:
        db.close()


def tab_count(groups):
    return sum(map(len, groups.values()))


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
    otty("tab", "focus", groups[group][-1][0])
    if kind == SHELL:
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
    self_command = None

    for group, wanted in LAYOUT.items():
        if group not in groups:
            print(f"{group}: no '{group}' divider — add one (right-click between tabs → Insert Divider)")
            continue
        if not groups[group]:
            # An empty group can't be filled: a tab placed after the previous group's
            # last tab lands above this group's divider, not under it.
            print(f"{group}: no tabs under the divider — drag one tab under it, then run ws again")
            continue

        if group == "local":
            for i, kind in enumerate(wanted):
                if any(kind in types for _, types in groups[group]):
                    state = "open"
                else:
                    groups = open_tab(window_id, groups, group, kind)
                    state = "opened"
                print(f"local {i + 1}: {state}")
            continue

        for i in range(max(len(groups[group]), len(wanted))):
            socket = f"{HOME}/.ssh/ws-{group}-{i + 1}"
            command = wanted[min(i, len(wanted) - 1)].format(socket=socket)
            tabs = groups[group]
            if i < len(tabs):
                if tabs[i][0] == home_tab:
                    # This tab is busy running ws itself, and a command sent here now
                    # would be swallowed by the running script — hand it to the shell
                    # that called ws (see the ws function in zsh/alias.local.zsh).
                    self_command = command
                    state = "self"
                else:
                    state = reconnect(tabs[i][0], command)
            else:
                groups = open_tab(window_id, groups, group, command)
                state = "opened"
            print(f"{group} {i + 1}: {state}")

    otty("tab", "focus", home_tab)
    if self_command:
        print(f"{SELF_MARKER} {self_command}")


if __name__ == "__main__":
    main()
