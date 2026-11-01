# Plan

Nothing in here has been done yet unless it says so. Owner: Felipe Paiva. Last updated 2026-11-01.

## Where we stopped (2026-11-01)

Everything below is research and design. **No tablet software has been installed on the Z13 yet.**

Done:

- Research on the community tools, Omarchy 4.5, and the Hyprland and fcitx5 pieces ([research.md](research.md)).
- A design for a native route with one new package ([minimal.md](minimal.md)).
- One live test: a Hyprland bind on the `Asus WMI hotkeys` switch fires on detach and attach.
- A comparison of the native route and the plugins, with a measurement protocol ([evaluation.md](evaluation.md)).
- A code review of ragtop at commit `1ffb2cc` ([ragtop-review.md](ragtop-review.md)).
- Lock screen analysis and options ([lock-screen.md](lock-screen.md)), face login research
  ([face-unlock.md](face-unlock.md)), and the boot password limit ([research.md](research.md) section 10).
- A proposal posted to Omarchy, #17222 ([upstream.md](upstream.md), [upstream-proposal.md](upstream-proposal.md)).

Answered by the owner:

- Typing on the lock screen without reattaching the keyboard **is required** (2026-11-01).
- Face login is queued behind the lock screen keyboard.
- The fully patched copy of ragtop is not wanted as is. Taking only its lock keyboard is the preferred
  fallback.

Waiting:

- A reply from Omarchy on #17222. The owner decides on 2026-11-15 whether to build the lock keyboard
  without one.
- The owner's answer on whether copies of Omarchy's overlays and a root udev rule are acceptable (the
  second question in [evaluation.md](evaluation.md)). It only matters if ragtop is trialled.

Next, in order, when work resumes:

1. Step 0, the baseline backup and the resource baseline protocol.
2. Test the touch swipe and the fcitx5 keyboard channel (minimal.md tests 3 and 4).
3. Build `wvkbd` for show and hide, then the static tablet file and the menu toggles.
4. Trial ragtop's lock screen copy only if upstream stays silent, after the staged steps in
   [ragtop-review.md](ragtop-review.md), or build the smaller lock keyboard copy
   ([lock-screen.md](lock-screen.md), option 3).
5. Face login, last.

## Rules for this plan

- One change at a time. Keep it or roll it back before the next.
- Stay on the stable Omarchy channel (4.0.6). Revisit when 4.5 final ships. Moving to the RC channel is
  an open decision, see the end.
- Read third-party code before installing it. Two of the tools run a build or a background service.
- Nothing goes upstream without a yes from the owner.

## Track 1: this machine

**Which path wins is not fully settled.** [evaluation.md](evaluation.md) compares the native route with
the plugins and names the two questions that decide it. Question one is answered: typing on the lock
screen is required. That means the native route alone is not enough, and the lock screen needs either
Omarchy to add it (the posted proposal), a minimal copy of ragtop's lock keyboard, or ragtop itself
([lock-screen.md](lock-screen.md)). Question two (patched Omarchy overlays and a root udev rule) is
explained and not yet answered. The text below assumes the native route for everything except the lock
screen.

**Main path: the minimal design in [minimal.md](minimal.md).** Use what Omarchy and Hyprland already
have, add one package (an on-screen keyboard), no plugin, no rotation code. It needs the detach tests in
that file first.

**Fallback: Alan's Z13 plugin**, steps 1 to 4 below. Use it if the minimal path cannot detect the detach
or the keyboard cannot be made to work. Do not run both at once.

Order of work for the main path:

1. Detach tests (minimal.md tests 1 and 2): **done 2026-11-01.** Hyprland hears the detach through a
   switch bind, so no watcher is needed.
2. Test the touch swipe (test 3).
3. Build `wvkbd` and test show and hide by signal (test 4).
4. Write the static tablet file and the menu entry, then test detach, attach and suspend (tests 5 and 6).
5. Record what worked in this repo.

### Step 0, baseline (before any change)

- Copy `~/.config/hypr` and `~/.config/omarchy` to a dated folder.
- Save the output of `omarchy plugin list`.
- Note the working state: touchscreen taps land correctly, the keyboard works, suspend and resume work.

### Step 1, read the plugin

Read `bin/tablet-mode`, `systemd/omarchy-tablet-mode.service`, `Widget.qml`, and the three `wvkbd`
patches plus the `PKGBUILD` in `packaging/wvkbd-deskus`. Look for anything that writes outside its own
folders, runs as root, or fetches code at run time. The setup step asks for the sudo password and builds
from source, so this step is not optional.

### Step 2, install the plugin with rotation off

```bash
omarchy plugin add https://github.com/AlanRoman117/omarchy-tablet-mode-asus-rog-flow-z13.git --enable
```

Before the first detach, set `auto_rotate=false` in `~/.config/omarchy/tablet-mode.conf` and restart the
service with `systemctl --user restart omarchy-tablet-mode`. This keeps the first test free of rotation.

Checks (write down pass or fail for each):

1. Detach: keyboard shows, the screen does not turn, a notification says tablet mode.
2. Touch tweaks apply (wider gaps) and `touch_tweaks=false` turns them off.
3. Reattach: keyboard hides, gaps return.
4. Typing works in a terminal and in a browser text field.
5. Suspend with the keyboard detached, then resume. The author says an early version hung a Z13 here
   once, so test this early and with nothing unsaved open.
6. `tablet-mode doctor` reports clean.
7. `tablet-mode disable --full` followed by `tablet-mode doctor --full` proves everything is undone.

Rollback: `tablet-mode uninstall --packages`, then `omarchy plugin remove alanroman117.tablet-mode`.

### Step 3, decide how rotation should work

The goal: the screen can rotate by itself, but detaching the keyboard must not be what switches it on.

| Option | How | Cost |
|---|---|---|
| A | Edit the plugin script so the daemon starts with `LOCK=true`. Detach then never rotates. A tap on the lock (or a chosen angle) in the bar card turns it on. | A plugin update overwrites the edit. Note the edit in this repo. |
| B | Leave the plugin as is. Tap the lock after every login. | Easy to forget. |
| C | Wait for Omarchy 4.5 final and use its own rotation lock, keep only the keyboard from the plugin. | Waiting. Rotation in 4.5 is not merged yet. |

Current leaning: A or B while on 4.0.6, then C when 4.5 ships. Undecided until Step 2 is tested.

### Step 4, when 4.5 final ships

- Read its release notes for rotation, keyboard and touch changes.
- Update. Check that the plugin's rotation does not fight Omarchy's rotation. If it does, set
  `auto_rotate=false` in the plugin and keep only the keyboard.
- Re-check the `ShellIpc` plugins that did not load on 4.0.6 (a separate issue, not about touch).

### Tweaks already applied on this machine (not touch related, `[tested here]`)

These are generic Z13 settings that worked. Other guides cover the same ground, so this is a record.

1. **Power profile follows the charger.** `/etc/udev/rules.d/99-z13-power-profile.rules`:

   ```
   SUBSYSTEM=="power_supply", KERNEL=="AC0", ATTR{online}=="1", RUN+="/usr/bin/powerprofilesctl set performance"
   SUBSYSTEM=="power_supply", KERNEL=="AC0", ATTR{online}=="0", RUN+="/usr/bin/powerprofilesctl set balanced"
   ```

   It runs only when the cable is plugged or unplugged. After a reboot the profile stays at Omarchy's
   default. Undo: delete the file and run `sudo udevadm control --reload`.

2. **GPU memory: small fixed block, large borrowable pool.** BIOS UMA frame buffer on `Auto` gave 512 MiB
   of fixed video memory. Kernel parameter `ttm.pages_limit=12582912` (48 GiB ceiling, not a reservation)
   through `/etc/limine-entry-tool.d/gpu-memory.conf`, then `sudo limine-update` and a reboot. Checked
   with `/sys/module/ttm/parameters/pages_limit` and `/sys/class/drm/card*/device/mem_info_gtt_total`.
   Not tested with a large local model yet. If the GPU runs out of memory, raise the ceiling.

3. **Launcher gotcha.** Omarchy's launcher hides desktop ids listed in
   `/usr/share/omarchy/default/omarchy/launcher.hides`, and the id is the file name. A `btop.desktop` file
   never shows up. Give the file another name, keep `Name=btop`, then run `omarchy-restart-shell`.

## Track 2: what we send upstream

Each item needs a yes from the owner before it is posted. How Omarchy handles proposals and the full
status are in [upstream.md](upstream.md).

| # | Where | What | Needs first |
|---|---|---|---|
| 0 | `omacom/omarchy` discussion #17222 | **Posted 2026-11-01.** Lock screen keyboard for detachables, then a PIN. Pointer comments left on #9600 and #14341. Decision date 2026-11-15. | Done, waiting for a reply |
| 0b | `omacom/omarchy` discussion #15977 | A comment linking #17222, since its author asks for a hook for extra login methods, the same hook as shape (b). | The owner's yes |
| 1 | Alan's plugin repo | Issue: ask for a setting that starts the plugin locked, or separates rotation from detaching the keyboard. Mention the `LOCK=false` start and the `sensor_sync` condition. | Step 2 results |
| 2 | Alan's plugin repo | Z13 hardware report: what worked on a second Z13, including the suspend test. | Step 2 results |
| 3 | `omacom/omarchy` #9029 and #9757 | Comment with a test on a Z13 and `wvkbd` (does the menu close on the first tap, does the fix help). | A test with the plugin installed |
| 4 | `omacom/omarchy` #13531 or #7493 | Test the PR on the Z13 and report. The Z13's tablet switch is on the `Asus WMI hotkeys` device and its keyboard is a USB device that detaches, which is a useful case for the rotation daemon. | Step 2 done, a separate branch checkout |
| 5 | This repo | Keep the research current. Add a Z13 hardware report issue template if others start filing. | Nothing |

Workspace rule: a PR branch lives in `~/contrib/<repo>`, not in a submodule, and every filed item goes
into the workspace's contributions list.

## Open decisions

1. Rotation option A, B or C (above).
2. Stay on the stable channel, or try the 4.5 RC channel on this machine. The RC could break things, and
   I lean towards waiting for final.
3. Whether to trial `ragtop`, and in what form. Lock screen typing is required, so ragtop's lock
   keyboard matters. The review is in [ragtop-review.md](ragtop-review.md), the options are in
   [lock-screen.md](lock-screen.md). On a Z13 its root rule probably does not match the switch device,
   so detection would need a workaround.
4. Whether to evaluate `ekollof/omarchy-osk` (a keyboard and touch plugin, not yet examined).
5. Whether to start the lock keyboard work without a green light on 2026-11-15.
