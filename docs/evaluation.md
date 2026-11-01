# Evaluation: native route or plugin route

Written 2026-11-01. Goal, from the owner: enable as many tablet functions as possible, let the user turn
each one on or off, and take as few hardware resources as possible.

Markers: `[tested here]`, `[source]` (read in code or docs, not run), `[snippet]`, `[untested]`, and
`[estimated]` for any resource cost I have not measured. **Only the baseline in section 4 is measured.
Every per-candidate cost below is a source reading or an estimate.**

## 1. The candidates

| Id | Candidate | What it is |
|---|---|---|
| N | Native route | Hyprland switch binds, a static settings file, menu toggles, and one small keyboard program. See [minimal.md](minimal.md). Nothing built yet. |
| R | [ragtop](https://github.com/sclemance/ragtop) | Quickshell plugin plus Python helpers. Keyboard, rotation, touch overlays, lock screen keyboard. Beta, MIT. |
| A | [Alan's Z13 plugin](https://github.com/AlanRoman117/omarchy-tablet-mode-asus-rog-flow-z13) | Bash daemon plus a small QML widget plus a patched `wvkbd`. Tested by its author on a Z13. MIT, patches GPL-3.0-only. |
| Y | [yeutterg set](https://github.com/yeutterg/omarchy-tablet) | Several repos: tablet layer, [on-screen keyboard plugin](https://github.com/yeutterg/omarchy-on-screen-keyboard), lock PIN pad, tray fix, `hyprgrass`. Made for Surface-style detachables. No license file in the tablet repo. |
| H | Hybrid | Native detection, toggles and touch settings, with the keyboard from a plugin or from `wvkbd` plus a small fcitx5 listener. |

## 2. Features, and who has them

"Toggle" means the user can turn that one function on or off without touching a config file.

| Function | N | R | A | Y |
|---|---|---|---|---|
| Detach detection | Yes, a Hyprland bind. `[tested here]` | Yes, reads the kernel switch. Names `asus-wmi`. Not yet seen on a Z13. `[source]` | Yes, watches USB. Author tested on a Z13. `[source]` | Yes, switch or a named device. `[source]` |
| Keyboard show and hide | Yes, `wvkbd` by signal from a menu entry. `[untested]` | Yes, themed keyboard, several layouts. `[source]` | Yes, patched `wvkbd`, floating button. `[source]` | Yes, themed, swipe typing. `[source]` |
| Auto-show on a text field | Optional, through a small fcitx5 listener. `[untested]` | Yes, through fcitx5. Auto-hide does not work. `[source]` | No `[source]` | Yes, but it needs fcitx5 stopped. `[source]` |
| Manual rotation | Small command, not built | Yes, Rotate left and right. `[source]` | Yes, 0, 90, 180, 270 in a card. `[source]` | Yes, through a display panel plugin. `[source]` |
| Auto-rotation | Not built. Omarchy 4.5 may bring it (#13531, #7493). | Yes. Three states. `[source]` | Yes, but tied to tablet mode and starts unlocked. `[source]` | Yes, through the display panel plugin. `[source]` |
| Rotation lock | Comes with the 4.5 rotation | Yes `[source]` | Yes `[source]` | Yes `[source]` |
| Bigger gaps and border grab | Yes, a static file | Not seen in the README | Yes, `touch_tweaks` `[source]` | Not seen |
| Touch workspace swipe | Option exists, off now. Not tested on this panel. | Not seen | No | Resize and move by touch through `hyprgrass` `[source]` |
| Typing on the lock screen | **No.** Reattach to unlock. | **Yes**, a separate lock-screen keyboard `[source]` | No, reattach `[source]` | Number pad only `[source]` |
| Typing in the Omarchy menu and bar pop-ups | No. Open bugs #9029 and #9756. | Yes, by patched copies of the overlays `[source]` | No, documented limit `[source]` | Not seen |
| Tap to dismiss the screensaver | No | Yes `[source]` | No | Not seen |
| Dictation key | Yes, a menu entry running `voxtype record toggle` (voxtype is installed here) | Not seen | Held key works with voxtype `[source]` | Yes, a mic key `[source]` |
| Bar button | No, menu entries and key binds | Yes `[source]` | Yes `[source]` | Yes `[source]` |

Reading the table: **R covers the most**. It is the only one with lock-screen typing and menu pop-up typing.
**N covers the basics** and is the only one where each piece is optional by design. A and Y sit between.

## 3. User control: how each one toggles

- **N.** Omarchy already has the pattern. The Trigger, Toggle menu holds entries like
  `trigger.toggle.window-gaps` with an `action` command (`[tested here]`, read from the default menu).
  The user already has a `~/.config/omarchy/extensions/omarchy-menu.jsonc` file (`[tested here]`). Each
  function becomes one entry that runs a small `z13-toggle-*` command, which drops or removes a static
  flag file in `~/.local/state/omarchy/toggles/hypr/`. Per-function on and off with no new interface
  code. Not built yet.
- **R.** The richest toggles that ship today. Keyboard: Follow Sensor, Always On, Always Off. Rotation:
  Auto-rotate (tablet mode only), Locked, Unlocked (follows the sensor all the time). Auto keyboard on
  or off. Tablet mode automatic or always on. Layout and keyboard size. `[source]`
- **A.** Config keys (`auto_rotate`, `show_keyboard`, `touch_tweaks`, `notify`), three bar switches
  (tablet mode, keyboard, rotation lock), and `tablet-mode disable --full`. No setting to start locked. `[source]`
- **Y.** A JSON options file (`autoShow` as tablet, always or never, and others), plus bar and tray
  buttons. `[source]`

## 4. Resources

### Measured baseline (2026-11-01, this Z13, idle desktop, on battery)

| Item | Value |
|---|---|
| Shell (`quickshell`) | 881 MB PSS, 965 MB RSS. Plugins load into this process. |
| `Hyprland` | 116 MB PSS |
| `fcitx5` | 19 MB PSS |
| `iio-sensor-proxy` | about 10 MB RSS, idle |
| `voxtype` plus its on-screen display | about 200 MB plus about 110 MB RSS (running now) |
| Accelerometer claim | None. `monitor-sensor` is not running. |
| Accelerometer rate when claimed | 50 Hz |
| Battery | Discharging at 9.69 W, 68 percent. One reading, brightness not fixed, so it is not a baseline for power. |

### Expected cost per candidate (`[source]` for the process list, `[estimated]` for the cost)

| Id | Always running | Only on demand | Accelerometer |
|---|---|---|---|
| N | Nothing of its own. The binds live inside Hyprland. | `wvkbd` while shown. The fcitx5 listener only if auto-show is on. | Only if the user turns rotation on |
| R | QML inside the shell (a 4,034-line service plus keyboard and theme files) and several Python helpers: keyboard sender, fcitx5 bridge, word predictor, terminal helper, switch watcher. Which of those idle at rest is not clear from reading. | Word list download for swipe typing | Held in Auto-rotate **even in laptop mode** `[source]` |
| A | A bash daemon and three reader processes (USB, Hyprland socket, sleep events) `[source]` | `wvkbd`. The sensor reader. | Only in tablet mode with the lock off `[source]` |
| Y | QML inside the shell, Python helpers (keyboard sender, tray icon, word predictor), plus `hyprgrass` inside Hyprland | | Through the display panel plugin |

The accelerometer claim is the one continuous cost that differs between candidates, because
`iio-sensor-proxy` powers the sensor only while a client holds a claim (`[source]`, described in PR
#13531). Whether 50 Hz sampling shows up in battery draw on this machine is `[untested]`.

### Measurement protocol for the trial phase

This protocol is the real answer to the resource criterion. Run it once for the baseline and once per
candidate, one candidate at a time, in laptop mode and in tablet mode.

1. Same conditions every time: on battery, same brightness, same Wi-Fi state, nothing else open, two
   minutes to settle.
2. Over five minutes, sample `/sys/class/power_supply/BAT0/power_now` every 10 seconds and average it.
3. Record PSS, not RSS, for the shell and every new process: `grep Pss /proc/<pid>/smaps_rollup`.
4. Record CPU time used by each new process over the five minutes (fields 14 and 15 of `/proc/<pid>/stat`).
5. Count processes and see who holds the sensor: `pgrep -a monitor-sensor`, `systemctl --user list-units`,
   `busctl --user list`.
6. Time `omarchy-restart-shell` until the bar returns, before and after.
7. Report the difference from baseline. Keep the raw numbers in this repo.

## 5. Costs that are not memory or battery

| | N | R | A | Y |
|---|---|---|---|---|
| Root changes | None. Hyprland already gets the switch. The node `/dev/input/event18` is `root:input` and my user cannot read it, which is why ragtop needs a rule (`[tested here]`). | A udev rule through `pkexec` (`/etc/udev/rules.d/70-ragtop-tablet-switch.rules`), switch devices only, and only if the switch is unreadable, after asking `[source]`. **On this Z13 the rule probably does not match.** The rule requires `ID_INPUT_KEY` to be not 1, and the Z13's switch device reports both `ID_INPUT_SWITCH=1` and `ID_INPUT_KEY=1` because it also carries the hotkey buttons (`[tested here]`, `udevadm info`). My reading of the rule says it would skip this device. `[untested]` | `sudo` password for the setup step, builds a package `[source]` | `sudo` once for `hyprgrass` build `[source]` |
| Copies of Omarchy code in user config | None | **Yes, but opt-in.** Copies of the menu, pickers, password prompt and lock screen, patched. Off by default, turned on one overlay at a time. The lock screen copy alone gives lock-screen typing. Copies stop following Omarchy updates, and live in user config where any program running as the user can rewrite them. `[source]` | None | Lock screen replaced by a plugin |
| Runs inside the shell process | No | Yes. Its own notes say a QML error can take the whole shell down. `[source]` | Small widget | Yes |
| New packages | `wvkbd` (AUR) or `squeekboard` (official) | `python-pywayland` (official, not installed here `[tested here]`) | Builds `wvkbd-deskus` (needs `base-devel`) | `python-pywayland`, `meson`, `glm` |
| License | Ours | MIT | MIT, patches GPL-3.0-only | No license file in the tablet repo |

"As linked to Omarchy as possible" and "copies of Omarchy's overlays" pull in opposite directions. That
is the main cost of getting lock-screen typing from ragtop today.

## 6. Scores on the three criteria

No made-up numbers. Order, best first, with the reason.

| Criterion | Order | Why |
|---|---|---|
| Most functions | R, then Y, then A and N | R alone has lock-screen and pop-up typing. N matches A once the 4.5 rotation lands. |
| User control per function | R, then N, then A, then Y | R ships the most states. N gets one toggle per function from Omarchy's own menu pattern, but is unbuilt. |
| Fewest resources | N, then A, then R and Y | N has no process of its own at rest. R and Y add helpers and shell code. `[estimated]` until measured. |

## 7. What decides it

Two questions decide the path. I am not picking a winner without them.

1. **Is typing on the lock screen without reattaching the keyboard required?** Only R has a full
   keyboard there. If yes, the plugin route is the only one that delivers it today.
2. **Are patched copies of Omarchy's overlays and a root udev rule acceptable?** R needs both.

Answer to question 1, 2026-11-01: **yes, typing on the lock screen is required.** Question 2 is being
explained to the owner before it is answered. Note for question 2: ragtop's overlay copies are opt-in
per overlay, so only the lock screen copy is needed for this goal, and on this Z13 the udev rule may
not apply as written (section 5).

| If | Then |
|---|---|
| Both answers are no | Build N. It wins on resources and on staying close to Omarchy. Expect to accept the lock screen limit. |
| Lock-screen typing is required | Trial R first, under the measurement protocol, one feature at a time. Keep N as the fallback. |
| Not sure | Trial R for a short period to get measured numbers and a real feature list, remove it, then decide whether N covers enough. |

Whichever path wins, two pieces are worth reading for their method, with credit to their authors:
ragtop's overlay focus fix (on-demand keyboard focus instead of exclusive, which is what breaks #9029) and
its fcitx5 bridge.

## 8. Not done

- No candidate has been run on this machine except the detach bind from the native route.
- No resource number for any candidate. Only the baseline.
- The Z13 has not been tried with ragtop's udev rule or switch watcher.
- The fcitx5 listener for auto-show is read, not run.
- Yeutterg's repos were only skimmed.
