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

## Not done

- Which actions the owner wants as presets.
- Nothing is built. No script exists.
- Short press against long press timing (see the test result above).
