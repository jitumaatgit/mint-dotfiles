# Hibernation resume guard

This machine hibernates to a **swap file** (`/swapfile`) rather than a swap
partition. That works, but it has one sharp edge worth automating away.

## The problem

The kernel locates the hibernation image using `resume_offset=`, which is the
swapfile's **first physical extent in 4 KiB blocks**. Recreating, resizing or
defragmenting `/swapfile` changes that extent.

With a stale `resume_offset`, the boot initramfs cannot find the image and the
hibernated session is **silently lost**. The only clue is this line in the log:

```
PM: Image not found (code -16)
```

It is not obvious after the fact, because the machine simply boots fresh.

This has already bitten once: the offset changed from `60690432` to `2177024`
when the swapfile was rebuilt from 10 GiB to 20 GiB.

## What is in this directory

| File | Purpose |
|---|---|
| `check-swap-offset` | The checker/repairer (installs to `/usr/local/sbin`) |
| `check-swap-offset.service` | Oneshot unit that runs the checker |
| `check-swap-offset.timer` | Runs it every 30 min, plus 2 min after boot |
| `50-check-swap-offset` | `systemd-sleep` hook: repairs **before every sleep** |
| `apply.sh` | Installs and activates all of the above |

## Install

```sh
sudo ./apply.sh
```

## Why a pre-sleep hook

Creating or resizing a swapfile is a plain file operation, so no `udev` event
fires and there is nothing to hook at the moment it happens. But a swapfile is
only ever recreated *before* someone tries to hibernate, so verifying on every
sleep transition catches drift exactly when it matters.

A repair rewrites `GRUB_CMDLINE_LINUX_DEFAULT` and runs `update-grub` — a few
seconds — which is an easy trade against losing a session.

Per `systemd-sleep(8)`, hooks receive `pre`/`post` plus the action name, and
*"execution of the action is not continued until all executables have
finished"* — so the repair always completes before the image is written.

## The hook never blocks sleep

A non-zero exit from a `systemd-sleep` hook aborts the transition. For a laptop
that is a real hazard: a machine that refuses to suspend will keep running in a
bag, draining the battery and overheating. So the hook **always exits 0**. If a
repair cannot be made it is logged, and the suspend proceeds — worst case is the
pre-existing behaviour (an image that may not resume), which is strictly better
than a machine that will not sleep. The call is also wrapped in `timeout 90` so a
hung `update-grub` cannot hold the transition open.

Measured cost when nothing is wrong: **~0.11 s**.

## Verifying without suspending

`sleep.target` has `RefuseManualStart=yes`, so a real transition cannot be
faked. Check the wiring declaratively instead:

```sh
# the binary that scans /usr/lib/systemd/system-sleep
systemctl show systemd-hibernate.service -p ExecStart
# sleep.target must precede the hibernation unit
systemctl show sleep.target -p Before
systemctl show systemd-hibernate.service -p After
# the timer side
systemctl list-timers check-swap-offset.timer
# runs so far
journalctl -u check-swap-offset.service
```

To confirm the hook itself is invoked on a real transition, suspend or hibernate
once and look for its own journal lines:

```sh
journalctl -t check-swap-offset
```

## What it checks

1. `resume_offset=` in `GRUB_CMDLINE_LINUX_DEFAULT` equals the swapfile's real offset
2. That offset actually lands on the swap header (`blkid -p -O`, the same test
   the boot initramfs hook uses)
3. `resume=UUID=` in the cmdline matches the root filesystem UUID
4. `RESUME=UUID=` in `/etc/initramfs-tools/conf.d/resume` matches too

## Manual use

```sh
sudo check-swap-offset            # report and repair if needed
sudo check-swap-offset --check    # report only; exit 1 if drifted
sudo check-swap-offset --quiet    # silent unless something is wrong
```

## After recreating the swapfile

There is an **ordering constraint**: the swapfile must be recreated *before*
anything can hibernate, and this guard runs before each sleep — so no manual
step is required. If you prefer to be explicit:

```sh
sudo swapoff /swapfile && sudo fallocate -l 20G /swapfile \
  && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
sudo check-swap-offset
```

Note the guard does **not** choose the swapfile's size or create it; it only
keeps the resume configuration consistent with whatever `/swapfile` currently is.

## Background: the resume wiring

| Piece | Value |
|---|---|
| Kernel cmdline | `resume=UUID=<root> resume_offset=<n>` |
| Initramfs | `/etc/initramfs-tools/conf.d/resume` |
| Sleep modes | `/etc/systemd/sleep.conf.d/10-sleep-modes.conf` |

`update-initramfs` prints `W: ... but no matching swap device is available`.
That warning is **expected and harmless** for a swapfile: the hook only checks
whether `RESUME=` names something swap-like, while the boot path uses
`resume=`/`resume_offset=` from the command line.
