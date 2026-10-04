#!/usr/bin/env python3
"""Report Cinnamon selectors that Chicago95 leaves to Cinnamon's dark fallback.

Run directly:  python3 patches/cinnamon6-coverage.py
               python3 patches/cinnamon6-coverage.py --gate

WHY THIS EXISTS

Cinnamon builds a theme as:

    new St.Theme({ fallback_stylesheet: /usr/share/cinnamon/theme/cinnamon.css })
    theme.load_stylesheet(<theme dir>/cinnamon/cinnamon.css)

That fallback is Cinnamon's own stock stylesheet, and it is a DARK one:
#1a1a1a panels, #242424 popups, #303030 menu sidebar, 8/16/9999px radii. Every
selector the theme does not declare resolves against it. The result looks like a
half-applied theme -- panels and popups correct, dialogs and hover states dark --
and it is emphatically NOT dark mode, so `org.gnome.desktop.interface
color-scheme` is worth checking once and then ignoring.

Chicago95 was written against the Cinnamon 3.x menu, so a large part of the
current shell falls through. This script turns "the menu has weird dark places"
into a finite list, which is the only way to work through it.

WHAT IS COMPARED

The selector HEADS declared by Cinnamon's stylesheet against the heads declared
by the theme's, with pseudo-class states collapsed away.

Collapsing matters, and the reason is the whole point. `.dialog .dialog-button`
and `.dialog .dialog-button:hover` are two selectors, but they are one widget.
A widget themed at rest but not on hover still falls through on hover -- the
defect is the same defect, and counting it twice would inflate the work by ~9x
and make the plan undeliverable. Comparing heads is the honest measure.

Because the expectation set is derived from Cinnamon's own shipped stylesheet
rather than a hand-written list, this keeps working across Cinnamon point
releases and needs no updating when Cinnamon adds a widget.

WHAT IT DOES NOT DO

It cannot tell you whether a rule looks right. Coverage proves a selector is
declared; only a screenshot proves the declaration is what you wanted. See
issue #1.

Skips cleanly (exit 0) when Cinnamon or the theme is not installed, so it is
safe to wire into ./smoke.sh on a machine that has neither.
"""
import argparse
import os
import re
import signal
import sys
from pathlib import Path

CINNAMIN_CSS = Path(os.environ.get("CINNAMIN_THEME_CSS", "/usr/share/cinnamon/theme/cinnamon.css"))
THEME_CSS = Path(
    os.environ.get(
        "CHICAGO95_CSS",
        Path(os.environ.get("CHICAGO95_THEME_DIR", str(Path.home() / ".themes/Chicago95")))
        / "cinnamon/cinnamon.css",
    )
)

# Families deliberately not ported, and why.
#
# `menu-` is not a deferral, it is dead. Cinnamon 6.x's menu applet sets
# `.appmenu-*`; nothing in the shipped Cinnamon sets the 3.x `.menu-*` names,
# which its own default stylesheet nevertheless still carries. Writing rules
# for them would be cargo-culting a rename in the other direction, so they are
# excluded explicitly rather than silently left to fail the gate.
EXCLUDED = {
    "vkeyboard": "on-screen keyboard; excluded by agreement (issue #1)",
    "menu-": "Cinnamon 3.x menu class names; no widget sets these any more",
}

# Interaction states that do not create a new widget head.
PSEUDO_STATES = (
    "hover active focus insensitive checked selected highlighted expanded "
    "default destructive-action active-child needs-attention"
).split()


def strip_noise(css: str) -> str:
    """Remove comments and at-rule preludes, which never contain a selector."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    css = re.sub(r"@[a-zA-Z-]+[^;{]*;", "", css)  # @import, @define-color
    return css


def selector_heads(css: str) -> set[str]:
    """Every selector in the stylesheet, one entry per comma-separated part.

    Walks braces rather than splitting on lines, because a selector list can
    span lines and a declaration value can contain a brace inside a string.
    """
    heads: set[str] = set()
    buf = []
    depth = 0
    in_string = None
    i = 0
    while i < len(css):
        ch = css[i]
        if in_string:
            if ch == "\\":
                i += 2
                continue
            if ch == in_string:
                in_string = None
            i += 1
            continue
        if ch in "\"'":
            in_string = ch
            i += 1
            continue
        if ch == "{":
            head = "".join(buf).strip()
            buf = []
            depth += 1
            # An at-rule block (@media, @keyframes) is a container, not a
            # widget: keep descending rather than recording it as a selector.
            if not head.startswith("@") and head:
                for part in head.split(","):
                    p = re.sub(r"\s+", " ", part.strip())
                    if p:
                        heads.add(p)
        elif ch == "}":
            depth = max(0, depth - 1)
            buf = []
        elif depth == 0 or ch not in "{};":
            if depth == 0:
                buf.append(ch)
        i += 1
    return heads


def collapse(head: str) -> str:
    """Strip interaction states so one widget counts once.

    A repeated pseudo-class has to go in one pass; a loop of sub() calls would
    re-match what the previous pass rewrote.
    """
    return re.sub(r":(" + "|".join(PSEUDO_STATES) + r")\b", "", head).strip()


def family(head: str) -> str:
    m = re.search(r"[.#]?[A-Za-z0-9_-]+", head)
    token = m.group(0).lstrip(".#") if m else head
    for prefix in (
        "appmenu", "menu-", "vkeyboard", "virtual-keyboard", "candidate", "audio-device",
        "calendar", "dialog", "notification", "popup-sub-menu", "window-list-item",
        "grouped-window-list", "panel", "panel-launchers", "systray", "slider", "check-box",
        "radiobutton", "toggle-switch", "workspace", "media-keys", "resize-popup",
        "spacer-box", "applet-cornerbar", "applet-separator", "prompt-dialog", "run-dialog",
        "sound-player", "polkit", "message-dialog", "end-session", "pie-timer",
        "word-suggestions", "ripple-pointer", "separator", "switcher-list", "osd",
    ):
        if token.startswith(prefix):
            return prefix
    return "other"


def main() -> int:
    # Behave like a normal CLI when piped into head/less.
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--gate", action="store_true",
                    help="exit 1 on any gap outside the exclusion list (default: report only)")
    ap.add_argument("--quiet", action="store_true", help="print the summary line only")
    args = ap.parse_args()

    for path, what in ((CINNAMIN_CSS, "Cinnamon"), (THEME_CSS, "the Chicago95 theme")):
        if not path.exists():
            if args.gate:
                print(f"skip: {what} stylesheet not found at {path}")
                return 0
            print(f"error: {what} stylesheet not found at {path}", file=sys.stderr)
            return 2

    default_raw = selector_heads(strip_noise(CINNAMIN_CSS.read_text(errors="ignore")))
    theme_raw = selector_heads(strip_noise(THEME_CSS.read_text(errors="ignore")))
    default_heads = {collapse(h) for h in default_raw}
    theme_heads = {collapse(h) for h in theme_raw}

    # Two different questions, and they need two different sets.
    #
    # Collapsed answers "how many widgets are unstyled" -- the size of the job.
    # Exact answers "which selectors do I still have to write" -- the work
    # itself. They are not the same question and the port needs both: a widget
    # themed at rest but not on hover counts as covered by the first and as
    # still-to-do by the second, which is exactly right, because the hover
    # state genuinely still falls through to the dark fallback.
    gaps = sorted(default_heads - theme_heads)
    exact_gaps = sorted(default_raw - theme_raw)

    excluded_fams = sorted({family(g) for g in gaps if family(g) in EXCLUDED})
    blocking = [g for g in exact_gaps if family(g) not in EXCLUDED]

    by_family: dict[str, list[str]] = {}
    for g in blocking:
        by_family.setdefault(family(g), []).append(g)

    if not args.quiet:
        print(f"Cinnamon selectors      : {len(default_raw)} raw, {len(default_heads)} widgets")
        print(f"Chicago95 selectors     : {len(theme_raw)} raw, {len(theme_heads)} widgets")
        in_scope_widgets = len([g for g in gaps if family(g) not in EXCLUDED])
        print(f"Unstyled widgets        : {len(gaps)} ({in_scope_widgets} in scope)")
        print(f"Unstyled selectors to write: {len(exact_gaps)}"
              f" ({len(blocking)} in scope)\n")
        for fam in sorted(by_family, key=lambda f: -len(by_family[f])):
            print(f"  {len(by_family[fam]):4}  {fam}")
            for g in sorted(by_family[fam]):
                print(f"          {g}")
        if excluded_fams:
            print("\n  excluded:")
            for fam in excluded_fams:
                print(f"          {fam:24} {EXCLUDED[fam]}")

    if args.gate and blocking:
        print(f"\nFAIL: {len(blocking)} unstyled selector(s) in scope.", file=sys.stderr)
        return 1
    print(f"\n{'PASS' if args.gate else 'OK'}: {len(blocking)} selector(s) still to write.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
