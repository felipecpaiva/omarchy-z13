# Minimal tablet mode: use what Omarchy already has

Written 2026-11-01. This is a design, not code. Nothing here has been built. Markers are the same as in
[research.md](research.md): `[tested here]`, `[source]`, `[snippet]`, plus `[untested]` for a claim I
could not check yet.

## The idea

Take the keyboard off and the Z13 turns on a small set of touch settings. Put it back and they turn off.
Use the Omarchy and Hyprland parts that are already installed. Add the least software possible.

Three rules come out of the research:

1. **Rotation stays out of the detach handler.** Detaching must never be what switches rotation on. Do
   not write a rotation daemon either. Omarchy 4.5 is getting one upstream (PRs
   [#13531](https://github.com/omacom/omarchy/pull/13531) and
   [#7493](https://github.com/omacom/omarchy/pull/7493)). Not holding an accelerometer claim also avoids
   the suspend hang the Z13 plugin's author hit with an early version.
2. **No `omarchy-*` names.** That namespace belongs to Omarchy, and an update could collide with it. Use
   `z13-tablet-*`.
3. **The tablet-mode Lua file must be static.** Omarchy's `toggles.lua` carries a comment about an older
   bug where a generated file could carry an injected USB device name and run as code. Never interpolate
   a device name into a file Hyprland loads.

## The tally

| | Count | What |
|---|---|---|
| New packages | **1, unavoidable** | An on-screen keyboard. Nothing installed draws one. |
| New plugins | **0** | A menu entry in `~/.config/omarchy/extensions/omarchy-menu.jsonc` does the show and hide job. |
| New background daemons | **0, or 1 if auto-show is turned on** | Hyprland itself hears the detach (`[tested here]`). Auto-show needs one small D-Bus listener, and only runs while the user enables it. |
| Rotation code | **0** | Wait for Omarchy 4.5, or use manual rotation. |

For comparison, the Z13 plugin ([research.md section 3](research.md)) builds its own `wvkbd` with three
patches, runs a 1,736-line script and a QML widget. It works as one unit, but it does more than this
goal needs.

## What is already on this machine

| Piece | Already here | Evidence |
|---|---|---|
| Touchscreen | `elan9008:00-04f3:43c7`, with a stylus device `...-stylus` | `[tested here]` `hyprctl devices -j`, and `omarchy-hw-touchscreen` prints the same name |
| Display | `eDP-1`, 2560x1600, scale 2, 180 Hz, transform 0 | `[tested here]` |
| Detachable keyboard | Shows up in Hyprland as `asustek-computer-inc.-gz302ea-keyboard` (plus `-keyboard-2`, and mouse and touchpad devices with the same prefix) | `[tested here]` |
| Accelerometer | `accel_3d`, `iio-sensor-proxy` 3.9-1, `monitor-sensor` present | `[tested here]` |
| A way to run Lua live | `hyprctl eval` | `[tested here]` (`hyprctl eval 'return 1'` answers `ok`) |
| Mode flags that survive a reload | `omarchy-hyprland-toggle` copies a flag file into `~/.local/state/omarchy/toggles/hypr/`, and `toggles.lua` loads every file there on reload | `[source]` |
| Menu entries with no plugin | `~/.config/omarchy/extensions/omarchy-menu.jsonc` | `[source]` the Z13 plugin uses it |
| `wtype`, `jq`, `socat`, `gdbus`, `udevadm` | Installed | `[tested here]` |
| Touch workspace swipe | Option `gestures.workspace_swipe_touch` exists and is currently off | `[tested here]` |
| Border grab area | `general.extend_border_grab_area` is 15 here. `gaps_in` and `gaps_out` are 0 here. | `[tested here]` |

## Detecting the detach, three candidates

Hyprland 0.56 has no "keyboard added or removed" event. Its Lua event list covers windows, workspaces,
monitors, config reloads and key presses, and a search of the Hyprland binary for device events found
nothing. `[source]` So the signal must come from somewhere else.

| Candidate | How | State |
|---|---|---|
| A. Hyprland switch bind | `switch:on:Asus WMI hotkeys` and `switch:off:...`, the same way Omarchy handles the lid (`switch:on:Lid Switch`) | **Works.** `[tested here]` One detach and one reattach on 2026-11-01: `on` logged at 08:42:01 and `off` at 08:42:12. `on` means detached, `off` means attached. One KDE project says the Z13 firmware never sends this switch ([aic0d3r/z13-tablet-kit](https://github.com/aic0d3r/z13-tablet-kit)). It does here, with kernel 7.2.8 and Hyprland 0.56.2. |
| B. udev | A small user service reading `udevadm monitor` for USB id `0b05:1a30`, modelled on Omarchy's `omarchy-hyprland-monitor-watch` | **Also works.** `[tested here]` The same detach produced `remove` events for the keyboard's four USB interfaces and its input devices, and the reattach produced `add` events about 10 seconds later. Only `0b05:1a30` came and went. The `0b05:18c6` device (`N-KEY Device`) never moved, so it stays on the tablet. |
| C. Poll | `hyprctl devices -j \| jq` every second or two, looking for the keyboard name | Not needed. |

**Use A.** Detection needs no daemon and no script of its own. The probe was a runtime bind written like
this, and it fired:

```lua
hl.bind('switch:on:Asus WMI hotkeys', hl.dsp.exec_cmd('<command>'), { locked = true })
hl.bind('switch:off:Asus WMI hotkeys', hl.dsp.exec_cmd('<command>'), { locked = true })
```

`locked = true` is what Omarchy uses for the lid, so it keeps working on the lock screen.

Two limits of a bind: it fires only when the switch **changes**. It says nothing about the state at
login, or after waking from suspend with the keyboard in a different state. Read that state once at
startup from `hyprctl devices -j`: the keyboard is attached when a device named
`asustek-computer-inc.-gz302ea-keyboard` is listed. `[tested here]` for the name, `[untested]` for the
suspend case. B (udev) remains the backup if A turns out to miss events after suspend.

## The keyboard, the one real install

Nothing installed draws a keyboard. fcitx5's virtual keyboard add-on is the message channel, not the
screen. This was first dismissed here, and that was a mistake. Checked on 2026-11-01:

- fcitx5 on this machine has the add-on loaded and exposes `/virtualkeyboard` with `ShowVirtualKeyboard`,
  `HideVirtualKeyboard` and `ToggleVirtualKeyboard` (`[tested here]`, `busctl --user introspect`).
- ragtop's `fcitx-osk-bridge.py` shows the other side: a program claims the D-Bus name
  `org.fcitx.Fcitx5.VirtualKeyboard`, and fcitx5 then calls `ShowVirtualKeyboard` and
  `HideVirtualKeyboard` on it when a text field gains or loses focus (`[source]`).
- So any small keyboard program can get auto-show next to Omarchy's fcitx5, with no change to the input
  method, if something answers on that name and shows or hides the keyboard. `python-gobject` is
  installed. That "something" is the only code to write. `[untested]` until I see a show call arrive.
- Limit, from ragtop's README: fcitx5's "hide" also fires on every keystroke from the on-screen keyboard,
  so auto-hide cannot be trusted. Auto-show works, hide is by hand.

Hyprland shows `hl-virtual-keyboard-fcitx5` as the main keyboard (`[tested here]`), so Omarchy's fcitx5
service is the active input method. That decides the choice:

| | `squeekboard` | `wvkbd` |
|---|---|---|
| Where it comes from | Official `extra` repo, 5.9 MB installed (`[tested here]`, `pacman -Si`) | Not in the official repos (`[tested here]`). AUR build, and `yay` is installed. |
| Auto-show on a tapped text field | Yes, through `text-input-v3` (`[snippet]`) | Not by itself. By signal, button or menu, or through the fcitx5 listener described above (`[untested]`). |
| Conflict | It wants the input-method slot that Omarchy's fcitx5 holds. The tablet repo from yeutterg masks fcitx5 to make it work (`[source]`), which changes an Omarchy default. | None. It sends plain virtual key presses. |
| Show and hide | A D-Bus call (`sm.puri.OSK0 SetVisible`) is what I expect, `[untested]` | `SIGUSR2` shows, `SIGUSR1` hides (`[snippet]`) |

**Recommendation: `wvkbd`.** It leaves Omarchy's input method alone, and the Z13 plugin's author already
ran it on this exact hardware. The cost is an AUR build and no auto-show. Electron apps do not auto-show
any keyboard anyway (`[source]`, yeutterg's README).

## The design

- **Show and hide** `wvkbd` from a menu entry (tappable) and, when detached, from the same command.
- **Touch settings** in one static file, for example `z13-tablet.lua`, that sets bigger window gaps and
  a wider border grab area, and optionally turns on `gestures.workspace_swipe_touch`. Detach puts the file
  in `~/.local/state/omarchy/toggles/hypr/`. Attach removes it. A reload then applies or drops it. That is
  the same pattern as `omarchy-hyprland-toggle`.
- **Two binds and one startup check**, no watcher. The binds call one small command, `z13-tablet on` or
  `z13-tablet off`. At login, one autostart line runs the same command with the state read from
  `hyprctl devices -j`, so a boot with the keyboard already off lands in the right mode. The command is
  idempotent: running `on` twice does nothing the second time.
- **Rotation:** not part of this. Manual rotation, if wanted, is a separate command. If added, replay the
  panel's mode, position and scale along with the transform, because a transform-only monitor rule resets
  the scale (a reviewer found this on a Framework 12 in #7493, `[source]`). Omarchy's
  `omarchy-hyprland-monitor-scaling` has the clean-scale logic to reuse.

Expected size: small, but I have not written it, so I will not give a line count.

## What this design does not fix

- **Lock screen.** It covers the on-screen keyboard. The Z13 here has no fingerprint reader
  (`omarchy-hw-fingerprint` says none, and no matching USB device, `[tested here]`). With the keyboard
  detached you cannot type your password. A PIN-pad plugin exists, but it is another plugin.
- **Menu and bar pop-ups.** Typing into the Omarchy menu search, or into a bar pop-up such as the Wi-Fi
  password box, closes them on the first tap of the keyboard
  ([#9029](https://github.com/omacom/omarchy/issues/9029), [#9756](https://github.com/omacom/omarchy/issues/9756)).
  Tapping a menu entry is fine.
- **Electron apps** will not show the keyboard on their own.
- **Hover-only interface** such as the tray drawer misbehaves on touch.
- **Custom touchscreen gestures** need the `hyprgrass` plugin, which is not in the repos, and `hyprpm` is
  not installed. `hl.gesture` exists in the Lua API, but whether it receives touchscreen input is
  `[untested]`. Earlier versions of Hyprland used it for touchpads only.

## Tests

| # | Test | State |
|---|---|---|
| 1 | Does `switch:on` or `switch:off` fire for `Asus WMI hotkeys` when the keyboard is detached and reattached? | **Done 2026-11-01. Yes.** `on` on detach, `off` on attach. |
| 2 | What does `udevadm monitor` print for `0b05:1a30` on detach and attach? | **Done.** Remove and add events for all four interfaces. `0b05:18c6` unchanged. |
| 3 | Does one `hl.gesture` react to a touchscreen swipe? | Not run |
| 4 | Build `wvkbd`, show and hide it by signal, tap a key in a terminal | Not run |
| 5 | Tap a menu entry that runs the show and hide command | Not run |
| 6 | Boot with the keyboard detached: does the startup check pick tablet mode? | Not run |
| 7 | Suspend with the keyboard attached, detach while asleep, resume: is the mode right? Then the reverse. | Not run |
| 8 | Detach and reattach several times fast: do the binds ever fire out of order or twice? | Not run |
