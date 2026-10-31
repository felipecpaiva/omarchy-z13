# Research: touch and tablet use on Omarchy, on the ROG Flow Z13

Written 2026-10-31. Star counts and PR states change daily, so treat them as a snapshot.

**How to read the markers**

- `[tested here]` I ran it on my Z13.
- `[source]` I read the code or the page. I did not run it.
- `[snippet]` I only saw it in a web search summary and did not open the page.
- `[commits]` I searched commit messages only, not the diffs.

## 1. The device (all `[tested here]`)

| Item | Value |
|---|---|
| Model | ASUS ROG Flow Z13 (2025), `GZ302EA` |
| Detachable keyboard | USB `0b05:1a30` (`GZ302EA-Keyboard`). A second ASUS device, `0b05:18c6` (`N-KEY Device`), is also present. |
| Accelerometer | IIO device `accel_3d` at `/sys/bus/iio/devices/iio:device0` |
| Tablet-mode switch | None. The only switch-type input device is `Lid Switch`. |
| Software | Omarchy 4.0.6-1, Hyprland 0.56.2-4, Quickshell 0.3.2, iio-sensor-proxy 3.9-1, kernel 7.2.8-9-omarchy |

The missing tablet switch matters. Tools that wait for a "tablet mode" event from the kernel will never
hear one on this model. One KDE project says the same thing in its README
([aic0d3r/z13-tablet-kit](https://github.com/aic0d3r/z13-tablet-kit), `[source]`): the firmware advertises
a switch but never sends it. Alan's Omarchy plugin works around this by watching the keyboard appear and
disappear on USB.

## 2. What Omarchy ships

- **4.0.6 (stable) and 4.5.0-rc2 (release candidate, 2026-10-27):** no on-screen keyboard, no
  auto-rotate. `[commits]` I compared `v4.0.6...v4.5.0-rc2` (1,272 commits) and searched the messages for
  tablet, touch, rotate, on-screen, osk, accelerometer and orientation. Nothing relevant. The 4.5 release
  notes list no tablet feature either (`[source]`).
- **Omarchy 4 has a plugin system** (Quickshell). Tablet tools ship as plugins and install with
  `omarchy plugin add <git url> --enable`. A plugin copies files into `~/.config/omarchy/plugins`, so
  removal is cheap. `[source]`
- **4.5 adds floating workspaces with a dock.** It may help on touch. I have not tried it.

## 3. Community tools

| Tool | What it does | Fit for the Z13 | State on 2026-10-31 |
|---|---|---|---|
| [AlanRoman117/omarchy-tablet-mode-asus-rog-flow-z13](https://github.com/AlanRoman117/omarchy-tablet-mode-asus-rog-flow-z13) | Detects keyboard detach over USB. Shows a themed `wvkbd` keyboard, rotates with the accelerometer, widens gaps for fingers, bar card with lock. | Built and tested on a GZ302EA, Omarchy 4.0.6, Hyprland 0.56.2 | v0.1.2, created 2026-10-06, one tester, MIT (patches GPL-3.0-only) |
| [sclemance/ragtop](https://github.com/sclemance/ragtop) | Keyboard drawn by the shell (themes, swipe typing), touch moves and resizes tiles, lock screen. Follows a kernel tablet switch. | Needs a tablet switch, which the Z13 lacks. Has a manual "Always On" mode. | Beta, v0.47.0, tested on a Yoga and a Surface |
| [yeutterg/omarchy-tablet](https://github.com/yeutterg/omarchy-tablet) | Touch layer: keyboard that pops up on text fields, lock-screen PIN pad, `hyprgrass` touch resize, tray fix. | Made for Surface-style detachables. Good source of ideas. | No license file |
| [andreiyurik/omarchy-tablet-mode](https://github.com/andreiyurik/omarchy-tablet-mode) | Rotation, touch and pen mapping, keyboard off when folded. No keyboard of its own. | Made for hinged 2-in-1 laptops | v1.7.5, tested on a ThinkPad X1 Yoga |
| [TeaRevver/2-in-1-rotation](https://github.com/TeaRevver/2-in-1-rotation) | Rotation tool announced in the Omarchy rotation discussion | Surface-specific | Not examined beyond the announcement |

Non-Omarchy sources for the same hardware:

- [ib99 Z13 guide](https://github.com/ib99/ASUS-ROG-Flow-Z13-2025-Linux-Guide-Omarchy-CachyOS-Kernel)
  `[snippet]`: a no-plugin setup with `iio-hyprland` and a `wvkbd-mobintl` key bind. It uses the old
  `hyprland.conf` syntax, so it needs translating to Lua for Hyprland 0.55 and later.
- [dank0296 Z13 notes](https://github.com/dank0296/rog-flow-z13-linux/blob/main/docs/PERIPHERALS.md)
  `[snippet]`: says GNOME handles rotation and the on-screen keyboard without extra packages.
- [ankk98 setup notes](https://dev.to/ankk98/asus-rog-flow-z13-2025-linux-setup-notes-1k35) `[snippet]`:
  one user finds the Z13 rotation sensor unreliable.
- [hyprgrass](https://github.com/horriblename/hyprgrass) `[snippet]`: touch gestures plugin. Its README
  warns early versions could make touch unusable until the plugin is unloaded.

## 4. The rotation coupling in Alan's plugin (`[source]`, not run)

Read from `bin/tablet-mode` at the repository head on 2026-10-31 (plugin version 0.1.2):

- Detaching the keyboard calls `enter_tablet`. That function shows the keyboard, applies touch tweaks,
  then calls `sensor_sync`.
- `sensor_sync` starts the accelerometer reader only when `MODE == tablet`, `LOCK != true`, the machine
  is not asleep, and `auto_rotate` is on. Otherwise it stops the reader.
- At service start the daemon sets `LOCK=false` (around line 1074). The README says the lock carries over
  between laptop and tablet mode. The code shows it does not survive a service restart.
- Config keys in `~/.config/omarchy/tablet-mode.conf` include `auto_rotate`, `show_keyboard`,
  `touch_tweaks`, `keyboard` (USB id, or `none` for manual only), `orientation_offset` and
  `debounce_ms`. I found no key that starts the plugin locked or that rotates only on request.
- Manual rotation (0, 90, 180, 270 in the bar card) turns the screen and locks rotation.

What this means: with the default settings, detaching the keyboard turns on rotation that follows the
sensor. If you hold the device in portrait at that moment, the screen turns. `auto_rotate=false` stops
that, and also stops all automatic rotation.

## 5. Open Omarchy bugs that touch users hit

| Issue | Problem | State |
|---|---|---|
| [#9029](https://github.com/omacom/omarchy/issues/9029) | The menu takes exclusive keyboard focus and pointer input, so the first tap on an on-screen keyboard closes it. You cannot type into the menu search by touch. | Open. Reporter's hardware: GPD Pocket 4, `wvkbd` 0.20. |
| [#9756](https://github.com/omacom/omarchy/issues/9756) | Bar pop-ups (Wi-Fi password and others) close on the first on-screen keyboard tap. | Open. Fix proposed in [#9757](https://github.com/omacom/omarchy/pull/9757), verified on an Omarchy test worker, not merged. |
| [#11835](https://github.com/omacom/omarchy/pull/11835) | The touchscreen toggle disables only the first digitizer. | Open PR, for dual-screen laptops. |
| [#15615](https://github.com/omacom/omarchy/pull/15615) | Bar and wallpaper flash on rotation and scaling. | Open PR |
| Lock screen | The lock screen covers the on-screen keyboard. With the keyboard detached you cannot type a password. | Stated in Alan's README. Not an Omarchy issue I could find. |

Also from yeutterg's README `[source]`: apps without `text-input-v3` support, which includes most
Electron apps, do not pop the keyboard up on their own. You need a button to show it.

## 6. Upstream rotation work for 4.5 (`[source]`, all open on 2026-10-31)

| PR | What it does | Evidence |
|---|---|---|
| [#13531](https://github.com/omacom/omarchy/pull/13531) | A daemon rotates the built-in panel with the accelerometer. Rotation lock under Trigger, Hardware. Adds `iio-sensor-proxy` only when a sensor is present. | Author runs it daily on a ThinkPad X12 Detachable. Reviewers ask for `iio-sensor-proxy` in the ISO package lists. |
| [#7493](https://github.com/omacom/omarchy/pull/7493) | Display panel gets an Orientation section (Normal, 90, 180, 270) and a rotate lock. Manual rotation works while locked. | Users report success on a GPD Pocket 4, a Framework 12 and an IdeaPad 2-in-1. |

The two overlap, and I could not tell which one maintainers prefer. Both rotate from the sensor at all
times, with a lock. Neither is tied to detaching a keyboard. Neither adds an on-screen keyboard.

## 7. Protocol notes

- `wvkbd` is simple and works on wlroots-style compositors, including Hyprland. It shows and hides on
  signals (`SIGUSR2` shows, `SIGUSR1` hides). Its input-method support is limited. `[snippet]`
- `squeekboard` supports `text-input-v3`, `input-method-v2` and virtual keyboard, so it can auto-show on
  text fields. The `hyprgrass` README says it does not work well with fcitx or IBus. `[snippet]`
- Chromium on Wayland and `text-input-v3`: one May 2026 post on the Chromium discussion list reports no
  on-screen keyboard on focus. It was tested on GNOME only and had no replies. `[snippet]` I did not
  confirm this on Hyprland.

## 8. What I could not find

- Any other Omarchy repo for the Z13 that handles touch or tablet mode.
- Anything from ASUS or the asus-linux project on tablet mode under Linux.
- A way to start Alan's plugin locked without editing its script.
- Which of #13531 or #7493 Omarchy will take, and the date of 4.5 final.
- Real use reports for the Z13 plugin beyond its author.

My GitHub searches for "hyprland on screen keyboard" and "hyprland touchscreen gestures" returned zero
repositories. The work lives in Omarchy plugin repos and forum threads.

## 9. Method

GitHub search through the `gh` command line for repositories, issues and pull requests. Web search for
guides and forums. Plugin READMEs and `bin/tablet-mode` read through the GitHub API. The three plugin
manifests I opened do not mention `ShellIpc`, but I only scanned the first 30 `.qml` and `.json` files of
each repo, so treat "none use it" as unproven.
