# cinnamon-screensaver: `Error in sys.excepthook` after every unlock

Investigated 2026-10-04 on `mintbook` (Mint 22 "zena", Cinnamon 6.6.1,
`cinnamon-screensaver 6.6.1+zena`, Python 3.12, PyGObject 3.48.2, X11).

## Symptom

Every successful unlock is followed, **exactly 30 seconds later**, by three
identical pairs of journal lines with empty bodies:

```
org.cinnamon.ScreenSaver[<pid>]: Error in sys.excepthook:
org.cinnamon.ScreenSaver[<pid>]: Original exception was:
```

All three land in the same second. Observed 14 times on 2026-10-03/04, e.g.:

| unlock (`gkr-pam: unlocked login keyring`) | error burst |
|---|---|
| 2026-10-04 14:48:14 | 14:48:44 |
| 2026-10-04 15:10:33 | 15:11:03 |
| 2026-10-04 15:34:39 | 15:35:09 |

The count is always exactly 3. The screensaver process exits immediately
afterwards — it is not reused.

## What it is

The 30 s is the application's own idle lifetime, not a bug timer.
`cinnamon-screensaver-main.py` constructs `Main` as

```python
super(Main, self).__init__(application_id="org.cinnamon.ScreenSaver",
                           inactivity_timeout=30000,
                           flags=Gio.ApplicationFlags.IS_SERVICE)
```

and `Manager.unlock()` → `set_active(False)` →
`Gio.Application.get_default().release()` drops the use count to zero
(`/usr/share/cinnamon-screensaver/manager.py:99-105`, `:139-146`).
Per GLib, the countdown starts at the `g_application_release()` that drops
`use_count` to 0 — "the amount of time (in milliseconds) after the last call
to g_application_release() before the application stops running"
(`gio/gapplication.c`, `inactivity-timeout` property).

So the sequence is: unlock → 30 s idle → `g_application_run()` returns →
`main.run()` returns → `Py_FinalizeEx()`.

Upstream independently describes the same lifetime: in
[linuxmint/cinnamon-screensaver#501](https://github.com/linuxmint/cinnamon-screensaver/issues/501)
maintainer mtwebster writes "the process lives on for 30 seconds after you
unlock the desktop before exiting", and that issue's log excerpt shows the
identical three-pair burst.

### Why the bodies are empty

Once finalization reaches `finalize_modules_delete_special()`, CPython sets
`sys.stderr` to `None` (`Python/pylifecycle.c:1337-1375`, reached from
`finalize_modules()` at `:1522-1539` via `Py_FinalizeEx()` at `:1853`). After
that, `PyErr_Display()` is effectively a no-op (`Python/pythonrun.c:1574-1576`)
while `PySys_WriteStderr()` falls back to the raw C `stderr` `FILE*`
(`Python/sysmodule.c:3782-3803`). CPython's own comment calls the result "a
sequence of information-free messages" (`Python/pylifecycle.c:1869-1873`).

The headers still get out — they are written through the raw `stderr` — but the
exception object cannot be formatted, so nothing follows them. **The three
underlying exceptions are unrecoverable from inside the process.** This is not a
property of this bug; it is why the log line is always empty.

### Verified locally

Reproduced deterministically by replacing the D-Bus activation target with a
wrapper that installs a `sys.excepthook` writing to a pre-opened fd:

* The hook was **never entered** (`HOOKS: 0`) and `sys.unraisablehook` never
  fired, in every reproduction.
* Redirecting the process's raw `stderr` to a file captured exactly three
  `Error in sys.excepthook:\n\nOriginal exception was:\n` blocks and nothing
  else — no traceback, no exception type, no message.
* Replacing the inactivity-timeout exit with an explicit
  `Gio.Application.quit()` produced the same three blocks, confirming the
  trigger is interpreter finalization rather than the timer itself.

### Ruled out

* **Not** the AccountsService proxy. `AccountsServiceClient.on_user_loaded`
  emits `accounts-ready`
  (`/usr/share/cinnamon-screensaver/dbusdepot/accountsServiceClient.py:66-67`),
  and in one session that emit landed in the same second as a burst — but in
  another it fired 20 minutes into a process's life with no burst at all
  (2026-10-04 13:22:00, no errors). The coincidence is coincidence.
* **Not** the fingerprint-PAM interaction described in
  [#495](https://github.com/linuxmint/cinnamon-screensaver/issues/495). That
  report's signature is the same three-pair burst, but its cause is
  `pam_fingwit` returning `PAM_IGNORE` during screensaver unlock so
  `pam_fprintd` then tries to claim an already-claimed device. On this machine
  `/etc/pam.d/common-auth` contains no `pam_fingwit`/`pam_fprintd` line at all
  (only `pam_unix`, `pam_deny`, `pam_permit`, `pam_ecryptfs`, `pam_cap`),
  `fprintd-list mint` reports "No devices available", and the journal contains
  zero `fprint` lines. The packages are installed but unwired.

## Does it matter

No functional impact observed. The unlock completes, the keyring unlocks, and
the process is re-activated on demand within seconds of the next
`GetActive()` call from `csd-power`/`cinnamon-session` (12 activations on
2026-10-04). It is exit-time teardown noise in an upstream component, printed
three times per unlock.

Because the exception text is destroyed by CPython before it can be printed,
there is no way to identify the three failing callbacks short of patching
upstream and bisecting on a machine that is deliberately kept alive at
finalization. Not worth it for a cosmetic symptom.

## Upstream status: known, unfixed since 2021

The canonical report is
[#384 'Error in sys.excepthook'](https://github.com/linuxmint/cinnamon-screensaver/issues/384)
(opened 2021-07-09, still reported on Cinnamon 6.6.8 in 2026-08). Maintainer
mtwebster's answer, 2021-07-09:

> You can ignore these [...] This happens when the screensaver exits. Prior to
> 5.0, the screensaver always ran in the background, so we never saw this.
> Now, the screensaver spawns when needed and exits once it's deactivated.
> I'm not even sure these are directly caused by cinnamon-screensaver, as I've
> been unable to silence them so far.

The issue is marked closed, but the last comment (2026-08-12) is another
report of the same lines on 6.6.8 — closed administratively, not fixed. No
commit in the repository silences it. The exit-time explanation in that thread
matches what was measured here.

## Is there a fix, and should it be suppressed?

**No fix is possible locally, and suppression is not recommended.**

Fixing it would require identifying the three exceptions, and CPython destroys
them before anything can print them — no hook, no `PYTHONFAULTHANDLER`, no
`unraisablehook` sees them. Upstream has had five years and multiple releases
and has not identified them either.

The two available suppression mechanisms are both strictly coarser than the
message:

* A journald drop-in (`/etc/systemd/journald.conf.d/*.conf` with
  `SyslogIdentifier=org.cinnamon.ScreenSaver` + `LogLevelMax=err`) would work,
  because everything the process writes arrives at priority 6 (info) — but it
  therefore also drops genuine Python tracebacks from the screensaver. For a
  security component that is a bad trade for six cosmetic lines per unlock.
* Redirecting stderr in the D-Bus activation `Exec` line keeps the
  informational stdout lines but loses real tracebacks the same way, and
  modifies a shipped system file.
* Passing `--hold` would stop the 30 s idle exit and so stop the finalization
  entirely — but it keeps a process permanently resident in a security
  component, which is a worse trade than the log noise.

Recommendation: leave it. Volume is six lines per unlock.

## Separate upstream bug — patched locally

`authClient.py:157` read `if e.code != Gib.IOErrorEnum.CANCELLED:` — `Gib` is
a typo for `Gio`, so a non-cancelled `GLib.Error` from `in_pipe.flush()`
raises `NameError: name 'Gib' is not defined` out of the error handler instead
of being reported. Reported as
[#512](https://github.com/linuxmint/cinnamon-screensaver/issues/512)
(2026-08-23); per that report it is still in upstream master. It is **not** the
cause of the exit-time burst — that code path runs synchronously from
`on_unlock_clicked`, not 30 s later — but it is a real bug, so it is patched
here:

* `patches/cinnamon-screensaver-gib-typo.patch` — the one-line diff.
* `patches/apply-cinnamon-screensaver-gib-patch.sh` — idempotent applier with
  `--check` / `--revert`, matching the `patches/` convention.

The target is owned by the `cinnamon-screensaver` package, so the applier
**diverts** it: `dpkg-divert --add --rename --package cinnamon-screensaver`
registers `/usr/share/cinnamon-screensaver/pamhelper/authClient.py.distrib`,
after which `apt upgrade` installs new upstream versions there and leaves the
patched copy in place. Note that `dpkg-divert --rename` refuses to rename the
file itself ("owned by diverting package"), so the applier makes the pristine
copy itself with `cp -a`; and `--remove --rename` refuses to overwrite a
differing file, so the revert path drops the diversion first and then copies
the packaged file into place.

Because the diversion copy is what `apt upgrade` refreshes, the applier can
tell when upstream fixes the typo: `--check` then reports `UPSTREAM-FIXED` and
a plain run removes the diversion and hands the file back.

Verification drives the real failure path — `message_to_child()` with an
`in_pipe` whose `flush()` raises `Gio.IOErrorEnum.BROKEN_PIPE`. Against the
pristine file that raises `NameError`; against the patched file the handler
runs and prints `Error writing to pam helper: <enum G_IO_ERROR_BROKEN_PIPE ...>`.

## Secondary finding: `pam_unix(cinnamon-screensaver:auth): conversation failed`

22 occurrences on 2026-10-04, always as a pair:

```
pam_unix(cinnamon-screensaver:auth): conversation failed
pam_unix(cinnamon-screensaver:auth): auth could not identify password for [mint]
```

`UnlockDialog.on_unlock_clicked` (`unlock.py:299-314`) sends whatever is in the
entry to the PAM helper, appending a newline, with no guard for an empty
field. Pressing Enter on an empty unlock box therefore reaches `pam_unix` with
no password token, producing both messages. It follows failed attempts in the
log because `on_authentication_failure` clears the entry
(`unlock.py:184-196`, `clear_entry` at `:329-335`), so the next Enter press
starts from empty. Cosmetic, but it is the source of most of the screensaver
noise in the journal.

## Unresolved

* Which three callbacks raise during finalization. Unrecoverable in-process
  (see above); not answered by upstream issues #495 or #501.
* Whether upstream will ever treat it as a bug. #384 is the canonical report
  and is closed, but with no fix and with reports continuing through 6.6.8; the
  maintainer's stated position is "you can ignore these". #495 and #501 are
  about other symptoms and remain open.

## Method note

The local reproduction required overriding
`/usr/share/dbus-1/services/org.cinnamon.ScreenSaver.service` (backed up,
restored afterwards; `/usr/local/share/dbus-1/services` and
`~/.local/share/dbus-1/services` were also tried and removed). D-Bus
activation is the only reliable way to get the tracing build to own
`org.cinnamon.ScreenSaver` — `G_APPLICATION_REPLACE` does not work because the
incumbent does not set `ALLOW_REPLACEMENT`, and starting a traced copy by hand
loses the race against dbus-daemon re-activating the real service.