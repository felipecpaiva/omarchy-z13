# The Z13 side button

Written 2026-11-02. The extra button on the right edge, below the volume rocker. On Windows ASUS uses it
for Armoury Crate (the Command Center). On Omarchy 4.0.6 it does nothing yet. This page records what is
known about it and a design for letting the user choose what it does.

Markers: `[tested here]` ran on my Z13, `[source]` read in code or docs, `[snippet]` only seen in a search
result, `[inferred]` reasoned from the above, `[untested]` not checked.

## What the kernel does with it

- A kernel patch, "platform/x86: asus-wmi: Fix ROG button mapping, tablet mode on ASUS ROG Z13"
  ([patchew](https://patchew.org/linux/20250803155713.9301-1-lkml@antheas.dev)), maps the side button's
  WMI code (`ASUS_WMI_KEY_ARMOURY`, `0xffff01`) to `KEY_PROG3`. A quirk table matches the product name
  "ROG Flow Z13". `[snippet]` I did not open the patch.
- The patch was merged upstream and a 6.16 stable backport was posted. `[snippet]` This machine runs
  kernel 7.2.8.
- The device `Asus WMI hotkeys` (`/dev/input/event22`) advertises `KEY_PROG3` and `KEY_PROG4`, plus
  `KEY_F13` to `KEY_F15`, camera, mic mute and other hotkeys. `[tested here]` (kernel capability bitmask)
- The `N-KEY Device` (USB `0b05:18c6`, the one that stays on the tablet when the keyboard comes off)
  advertises `KEY_PROG1` and `KEY_PROG2` and many media keys. `[tested here]`

So the button should arrive as `KEY_PROG3`, which Hyprland calls `XF86Launch3`. The live test below confirmed it
(`[tested here]`). One
community Z13 guide binds `XF86Launch3` to "a dedicated side button"
([ib99 guide](https://github.com/ib99/ASUS-ROG-Flow-Z13-2025-Linux-Guide-Omarchy-CachyOS-Kernel), `[snippet]`).

## What on this machine already uses it

- Nothing in Omarchy 4.0.6's default Hyprland bindings, and nothing in my own `bindings.lua`, uses
  `XF86Launch1` to `XF86Launch4` or `F13` to `F15`. `[tested here]` The keys are free.
- `asusd` (ASUS's control daemon, `asusctl 6.5.0`) has no button setting in `/etc/asusd/asusd.ron`: only
  `ac_command`, `bat_command` and an empty `armoury_settings`. `[tested here]` That does not prove asusd
  never reads the button.

## The live test

Status: **done 2026-11-02.** I added I added temporary Hyprland binds on `XF86Launch1`,
`XF86Launch2`, `XF86Launch3`, `XF86Launch4`, `F13`, `F14` and `F15`. Each writes the key name and the time
to a log and shows a "Z13 probe" notification. They listen only for those seven keys, so no typing is
recorded. They disappear on the next `hyprctl reload`. All seven showed up in `hyprctl binds -j`
(`[tested here]`). I then pressed the button twice (a short press and a press held for about a second). The log shows
`XF86Launch3` at 09:21:15 and again at 09:21:55, one event per press, and none of the other six keys.

**Result: the side button is `XF86Launch3` in Hyprland on this Z13** (kernel 7.2.8, Hyprland 0.56.2,
Omarchy 4.0.6). Nothing grabbed it first, so `asusd` does not swallow it. The probe was removed with a
`hyprctl reload` and no probe binds remained. `[tested here]`

What the test did not show: whether a held press sends one event or a repeat, and how long the hold was.
The log has one line per press, so the held press produced one event. Telling short from long press needs
either Hyprland's long press bind or the release event, and both are `[untested]`.

## Hyprland facts that matter here

- A bind on a key takes one line: `hl.bind('XF86Launch3', hl.dsp.exec_cmd('<command>'), { locked = true })`
  (the form tested above). `locked = true` makes it work on the lock screen too.
- `hyprctl binds -j` shows a `longPress` flag per bind, so Hyprland supports long press binds. The exact
  Lua option name is `[untested]`.
- A short press and a long press can therefore do two different things. A double press needs timing code
  and is left out of a first version.

## The idea: a small button mapper in the Omarchy menu

The owner's idea (2026-11-02): a simple app that appears in the Omarchy menu and lets the user choose what
the button triggers, including any shortcut.

| Option | What | Cost |
|---|---|---|
| 0 | One static bind in `bindings.lua`. The user edits the file to change it. | Zero. No mapper. |
| 1 | **Menu mapper.** A menu entry (in `~/.config/omarchy/extensions/omarchy-menu.jsonc`, the file Omarchy reads for menu extensions, `[tested here]` that it exists) opens a list of actions. Choosing one writes a single line to a small config file. One static bind calls a tiny dispatcher script that reads that line and runs it. | No resident process, no plugin, no package. The dispatcher is a few lines. |
| 2 | A Quickshell panel plugin with a picker window. | Runs inside the shell, more code, closer to ragtop in weight. Not needed for this. |

Option 1 is the smallest one that does what the idea asks. It also works by touch, because Omarchy's menu
entries can be tapped. This repo adds no scripts until they have run on a real Z13, so nothing is built.

What the list of actions could hold:

| Action | Command | State |
|---|---|---|
| Omarchy menu | `omarchy-menu toggle` | exists, used by the default `Super+Space` bind `[tested here]` |
| Show or hide the on-screen keyboard | `wvkbd` signal | needs the keyboard package from [minimal.md](minimal.md) |
| Voice dictation | `voxtype record toggle` | voxtype installed, `record toggle` listed in its help `[tested here]` |
| Screenshot | `omarchy-capture-screenshot` | exists `[tested here]` |
| Lock the screen | `omarchy-system-lock` | exists `[tested here]` |
| Toggle the touchscreen | `omarchy-toggle-touchscreen` | exists `[tested here]` |
| Toggle night light | `omarchy-toggle-nightlight` | exists `[tested here]` |
| Cycle the power profile | `powerprofilesctl set <profile>` | installed `[tested here]`. The charger rule in [plan.md](plan.md) sets the profile only on plug or unplug, so a manual cycle does not fight it. |
| Switch to game mode | the Omarchy Gaming Console session switch | a separate project, fits the handheld idea, needs care |
| Any command | free text | the dispatcher runs it |
| Any key combination | `wtype` sends the keys | `wtype` is installed `[tested here]`. Whether Hyprland binds react to keys sent by `wtype` is `[untested]`. A direct command is more reliable than faking keys. |

A "learn the button" step would make it work on other ROG machines too: it adds probe binds like the ones
above, the user presses the button, and the mapper records which key fired. That is exactly the test that
confirmed `XF86Launch3` on this Z13.

Cost at rest: nothing runs between presses. One static bind lives inside Hyprland.

## Prior art (searched 2026-11-02, before building anything)

Short answer: the idea exists already for mouse buttons, and the Z13 side button is bound to fixed actions
in several setups. No tool lets a user pick the action for a keyboard class hardware button like this one.

### The Z13 side button in other people's setups (`[source]`, files read)

| Where | What the button does | How |
|---|---|---|
| [Cliffback/omarchy-rog-z13-setup](https://github.com/Cliffback/omarchy-rog-z13-setup), `docs/rog-keys.md` | Toggle gaming mode, entered from Hyprland and exited from gamescope | Fixed bind on `XF86Launch3` |
| [mkhan117/omarchy-z13-setup](https://github.com/mkhan117/omarchy-z13-setup), `docs/rog-keys.md` | Gaming mode toggle, and outside gaming mode a monitor mode toggle | Fixed bind on `XF86Launch3` |
| [Naomarik/Z13-StrixHalo-Omarchy](https://github.com/Naomarik/Z13-StrixHalo-Omarchy) | Toggle monitor mode (double or external) | Fixed bind on `XF86Launch3` |
| [ib99 guide](https://github.com/ib99/ASUS-ROG-Flow-Z13-2025-Linux-Guide-Omarchy-CachyOS-Kernel) | Opens a ROG power menu script | Fixed bind on `XF86Launch3` |
| [austinwilkerson/omarchy-rog-helper](https://github.com/austinwilkerson/omarchy-rog-helper) (MIT, 1 star, created 2026-10-15) | Opens and closes its own ASUS panel (profiles, battery, lighting) | An optional user service that reads the hotkey device, plus a udev rule, installed with a root password prompt. It leaves Hyprland config unchanged. |

All of them agree with our live test: the side button is `KEY_PROG3`, scan code `0xffff01`, on the
`Asus WMI hotkeys` device. The rog-helper notes (`RESEARCH.md`) add something our test could not show: in
a 25 second capture with four presses, a **recurring phantom event** appeared on the same device (scan
`0xe9`, `KEY_UNKNOWN`). It is a different key from `KEY_PROG3`, so a Hyprland bind on `XF86Launch3` is not
triggered by it. Our probe saw exactly one event per press. `[source]` for their capture, `[tested here]`
for ours.

Nothing in Omarchy's defaults or in this machine's Hyprland config disables the `Asus WMI hotkeys` device
(`[tested here]`). The device is live in the compositor as `asus-wmi-hotkeys`.

### The mapper idea, already built for mouse buttons

[sambuaneesh/omarchy-hyprmouse](https://github.com/sambuaneesh/omarchy-hyprmouse) (MIT, 0 stars, created
2026-10-25, one author, installed from the AUR as `omarchy-hyprmouse`, `[source]`, not run):

- Lives in the Omarchy menu under Setup, Mouse. A terminal app (Python, Textual).
- A button can run **any Omarchy hotkey, a command, a key combination, or nothing**.
- A "learn" step: press `P`, then the button you want to change.
- It makes any hotkey available as an action by wrapping `hl.bind` when the config loads, remembering the
  action behind every bind, so a button can run exactly the same action. That includes hotkeys that run Lua
  functions. This is the cleverest answer found to the "any shortcut" part.
- Scope: mouse buttons. Its contribution guide says the most useful contribution is support for more
  mice. Nothing there handles a key event from a device like `Asus WMI hotkeys`.

That is the same architecture as the idea (menu entry, learn the button, choose an action), for a different
kind of button. It has not been reviewed here, and it edits Hyprland wiring and installs hooks, so it
would need the same read through as ragtop before use ([ragtop-review.md](ragtop-review.md)).

### Other related tools

| Tool | What | Fit |
|---|---|---|
| [neilerua973/omarchy-keybindings-editor](https://github.com/neilerua973/omarchy-keybindings-editor) (MIT, 0 stars, a diverged fork) | A panel that shows keybindings as an on-screen keyboard and lets you rebind the action or the key combo | Rebinding is limited to Super plus a letter, digit or F key, so it cannot take `XF86Launch3` |
| Omarchy Setup, Keybindings (`omarchy-launch-config-editor ~/.config/hypr/bindings.lua`) | Opens `bindings.lua` in an editor | The built in way today, and works for a fixed bind |
| Discussion [#16581](https://github.com/omacom/omarchy/discussions/16581) | Asks to edit and create keybindings from the Super+K picker | 0 comments |
| Discussion [#12879](https://github.com/omacom/omarchy/discussions/12879) | Asks Omarchy to expose keybinding source information for tooling | 0 comments |
| Discussion [#10859](https://github.com/omacom/omarchy/discussions/10859) | Asks for on screen feedback for the ASUS power profile hotkey | 0 comments, shows interest in ASUS keys |
| Other Z13 and ROG plugins ([T3lluz/omarchy-rog-deck](https://github.com/T3lluz/omarchy-rog-deck), others) | Bar panels for power, lighting and fans | They bind ROG keys to their own panels, not to a user chosen action |

### What this changes

- A new app from scratch would mostly repeat omarchy-hyprmouse, which already has the menu entry, the
  learn step and the "any hotkey, command or key combination" action list.
- The gap is narrow: hardware buttons that arrive as keys, like the Z13 side button.
- Options now: (1) use one fixed bind today, with no build; (2) ask the omarchy-hyprmouse author whether
  they would take support for non mouse hardware buttons, and contribute it there; (3) build our small
  menu mapper only if (2) is declined or does not fit.
- The rog-helper listener needs a root password prompt and a service to read the device. A Hyprland bind
  needs neither, and our probe proved it sees the press.

## Omarchy 4.5 check (2026-11-02)

Checked before building, to make sure the direction still fits. Method: the compare view and file trees of
`omacom/omarchy` at the tag `v4.5.0-rc3` and at the default branch `quattro`. `[source]`, nothing run.

### Where 4.5 stands

- `v4.5.0-rc3` is a tag (commit `f402ad0`). On 2026-11-02 it had no release page yet, only the tag. rc2 is
  the last published release. There are 28 commits between rc2 and rc3. None of their messages mention
  touch, tablet, rotation, an on-screen keyboard or hotkeys (commit messages only).
- Release candidates are cut from a separate `rc` branch, not from `quattro`. That is why a compare of rc3
  against newer `quattro` commits says "diverged". So a change merged on `quattro` is **not automatically
  in rc3**. Anything marked "quattro only" below may or may not reach 4.5 final.

### What it means for the side button

| Finding | Detail |
|---|---|
| The side button stays free | The default bindings at rc3 use no `XF86Launch` key. They bind calculator, audio, brightness, keyboard light, touchpad and media keys only. |
| Nothing disables the hotkey device | PR #9129 "Ignore vendor hotkey keyboard devices" (merged 2026-10-31, `quattro`) only changes the keyboard layout bar widget, so it does not pick a vendor hotkey device as the user's keyboard. It does not turn the device off or touch the button. The "disabled WMI rule" mentioned in the rog-helper notes is not from Omarchy. |
| Binding helpers | 4.0.6 has `o.bind(keys, description, command, options)`, `o.bind_toggle` and `o.launch`. The description is what the keybindings menu shows. 4.5 adds `o.rebind` (replace a default bind, in rc3) and `o.bind_hold` (separate press and release actions, used for push to talk, in rc3). 4.0.6 has neither. A fixed bind written with `o.bind` works on both. |
| Dictation has a command | rc3 has `omarchy-dictation <start\|stop\|toggle>`, which picks the configured backend (voxtype is one). Default binds at rc3: `Super+Ctrl+X` toggle, `F9` and `Alt+Right Alt` push to talk. On `quattro` the keys change again to `Alt+Space` and `Right Alt` (#17188). The command is the stable part, so a button action should call `omarchy-dictation toggle` on 4.5, not voxtype directly. |
| Manual rotation is coming | `omarchy-hyprland-monitor-rotate [--monitor NAME] [0\|90\|180\|270]` exists on `quattro` only, not in rc3, along with a right click rotate in the display panel's layout map (#17170). Auto rotation is still missing. PRs #13531 and #7493 are still open. |
| Keyboard settings | `Setup > Keyboard` grouping and `omarchy keyboard toprow` (#17270, #17258) are on `quattro` only. They do not cover hardware buttons. |
| No keybinding editor yet | The keybindings menu in rc3 lists and runs binds. It has no editing. Discussions #16581 (edit and create keybindings from the picker) and #12879 (expose binding source info for tooling) still have 0 comments. |
| Key naming hook | The keybindings menu reads `/usr/share/omarchy-platform/key-names`, one `<keysym> <name>` per line, so a platform package can name keys the way its keyboard prints them (the example given is a MacBook). No file names the Z13 side button. A small upstream idea, not asked yet. |
| Tablet features | None in rc3. No on-screen keyboard, no auto rotate, no lock screen keyboard. |

### Verdict

The direction holds. 4.5 does not map hardware buttons and does not use `XF86Launch3`, so neither a fixed bind
nor a mapper clashes with it. Adjustments to make:

1. Write binds with `o.bind` and a description, so they work on 4.0.6 and 4.5 and show up in Omarchy's
   keybindings menu.
2. Prefer Omarchy's own commands as actions: `omarchy-menu toggle`, `omarchy-dictation toggle` (4.5),
   `omarchy-hyprland-monitor-rotate` (when it ships), `omarchy-capture-screenshot`, `omarchy-system-lock`.
   On 4.0.6 use `voxtype record toggle` until `omarchy-dictation` exists.
3. Do not build a keybinding editor. Upstream is discussing one, with no replies yet.
4. A mapper for hardware buttons that arrive as keys is still unaddressed upstream and in the community.

## Not done

- Which actions the owner wants as presets.
- Nothing is built. No script exists.
- Short press against long press timing (see the test result above).
