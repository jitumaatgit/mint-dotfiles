# The Chicago95 Cinnamon port

Chicago95 is a Windows 95 GTK2 theme whose Cinnamon stylesheet was written
against Cinnamon 3.x. This machine runs Cinnamon 6.6.9. This guide explains why
that produces a half-applied desktop, what the fix is, and how to re-apply it.

## Why the theme is only half applied

Cinnamon does not load a theme on its own. It builds a stylesheet whose
fallback is **Cinnamon's own stylesheet**, then layers the selected theme on
top:

```js
// /usr/share/cinnamon/js/ui/main.js, Main.loadTheme()
let theme = new St.Theme({ fallback_stylesheet: /usr/share/cinnamon/theme/cinnamon.css });
theme.load_stylesheet(<theme dir>/cinnamon/cinnamon.css);
```

That fallback is a **dark** stylesheet: `#1a1a1a` panels, `#242424` popups,
`#303030` menu sidebar, 8/16/9999px corner radii. Every selector the chosen
theme does not declare resolves against it.

So the failure mode is a *fall-through*, not a theme bug. A widget looks right
at rest and flashes dark the moment you hover it, because the widget is themed
but `:hover` is not. That reads as "part of the theme is broken" and is not.

**It is not dark mode.** Check `org.gnome.desktop.interface color-scheme` once;
if it is `default` and `gtk-color-scheme` is empty, stop looking. In this setup
both are unset.

## What the port fixed

238 selectors. The larger groups, in the order they were done:

| Area | What was wrong |
|---|---|
| Menu applet | Cinnamon 6.x renamed every class from `.menu-*` to `.appmenu-*`. Chicago95 declares only the old names, so the entire menu fell through. |
| Dialogs | `.modal-dialog*` → `.dialog*`. Every dialog rendered `#242424` with an 18px radius. |
| Panel | The theme paints the outer panel containers, which Cinnamon 6.6 does not paint. The visible surface is `#panelLeft` / `#panelCenter` / `#panelRight`. |
| Taskbars | Bare `:hover` was never declared, so task buttons flashed `#393939`. |
| Entry fields | Drawn as rounded dark pills with white text instead of white sunken fields. |
| Workspace switcher, OSDs, sound player | Dark theme values, including some **in the theme itself**. |

## Why the rules live in a patch script

Cinnamon exposes no user stylesheet override. `Main.setThemeStylesheet()` takes
exactly one path, taken from `org.cinnamon.theme name`. So these rules have to
live inside the theme's own `cinnamon/cinnamon.css`.

The theme directory is **excluded from home-git** on purpose: it holds tens of
thousands of static assets and makes `hsnap` unusably slow. Anything written
there is therefore unversioned and is destroyed the next time the theme is
re-extracted from upstream.

Hence:

- `patches/cinnamon6-override.css` — the versioned copy of every ported rule.
- `patches/apply-cinnamon6-override.sh` — reconciles the two. Idempotent, with
  `--check`, `--revert` and `--status`.

```sh
patches/apply-cinnamon6-override.sh          # apply
patches/apply-cinnamon6-override.sh --check  # exit 0 if in sync, 1 if not
patches/apply-cinnamon6-override.sh --revert # back to upstream
```

The applier wraps the block in sentinel markers, so `--revert` is an exact cut
rather than a pattern guess, and re-applying after an upstream update cannot
double-apply.

**After re-extracting the theme from upstream, re-run the applier.** That is the
whole reason it exists.

## Reloading without logging out

```sh
gsettings set org.cinnamon.theme name 'Adapta-Nokto'
gsettings set org.cinnamon.theme name 'Chicago95'
```

This re-reads the stylesheet from disk. Verified.

## Checking it

```sh
python3 patches/cinnamon6-coverage.py            # report
python3 patches/cinnamon6-coverage.py --gate     # exit 1 if anything is unstyled
```

This diffs the selector heads Cinnamon ships against the ones the theme
declares. Because its expectations come from Cinnamon's own stylesheet rather
than a hand-written list, it survives point releases.

It reports two numbers, and the difference matters:

- **unstyled widgets** — collapsed over pseudo-class states. Answers *how big is
  the job*.
- **unstyled selectors** — exact. Answers *what do I write*.

A widget themed at rest but not on hover counts as covered by the first and
still-to-do by the second. That is correct: the hover state genuinely still
falls through.

`./smoke.sh` runs both this and the applier's `--check`.

Two deliberate exclusions, both in `EXCLUDED` in the script:

- `vkeyboard` / `virtual-keyboard` — the on-screen keyboard, agreed out of scope.
- `menu-` — Cinnamon 3.x menu class names that no widget sets any more. They
  remain in Cinnamon's own default stylesheet, but writing theme rules for them
  would be cargo-culting a rename in the other direction.

## Editing

Edit `patches/cinnamon6-override.css`, then re-run the applier. **Do not edit
the copy inside the theme**; it is overwritten.

Conventions the file follows:

- Square corners, `#c0c0c0` face, `#000080` selection, white selected text.
- The theme's own assets: `button-assets/`, `panel-assets/`, `frame/`,
  `control-assets/`, `misc-assets/`, `Handles/`, `background-assets/`.
  No new artwork.
- Within a family, more specific selectors come after less specific ones, since
  St resolves equal-specificity rules last-wins and the whole file relies on it.

## Two traps worth knowing

**Never verify a stylesheet change with `background-color`.** St draws
`border-image` *over* the background, so on any widget whose existing rule uses
a border image — very common in retro themes — a changed background is
completely invisible while having applied correctly. Use a layout property
(`font-size`, `padding`); it cannot be occluded. This cost a full debugging
detour: a rule was working perfectly and looked like a failure.

**An absent effect is evidence about which element paints, not about whether
the change landed.** The panel's `background-color` did nothing on
`.panel-top`/`#panel`/`#panel-left`/`#panel-right`, which read like dead
selectors. They were not — `font-size` on the same `#panel` rule worked, so the
selector matched and the property specifically was ignored. Painting the inner
boxes magenta identified the real surface. Confirm with a second probe before
concluding a rule failed.