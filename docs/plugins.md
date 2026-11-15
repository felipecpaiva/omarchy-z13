# Plugins on my Z13

Written 2026-11-15. Community plugins I run on the Z13 that touch the lock screen or how I move
between desktops. Checked on Omarchy 4.5.0-3 and Hyprland 0.56.2.

Each entry says how I checked it: `[tested here]`, `[source]` (read from the code), or not checked.

## Lock Screen Explorer (lock screen)

Plugin `io.github.sirjul1337.lock-explorer`,
[SirJul1337/omarchy-lock-explorer](https://github.com/SirJul1337/omarchy-lock-explorer), version
2.0.14 at commit `6eaabfa`. MIT. It replaces Omarchy's own lock screen (`omarchy.lock`) with a set of
designs and a picker to preview and switch between them.

### Why this one

I compared it with the other lock screen plugins on GitHub on 2026-11-15. About 20 exist, most with
no stars. I read the top five `[source]`:

| Plugin | Stars | Main file | What it adds |
|---|---|---|---|
| [SirJul1337/omarchy-lock-explorer](https://github.com/SirJul1337/omarchy-lock-explorer) | 238 | 5,560 lines | Many designs, a picker, a designer, face and security key checks, tests |
| [Rockeyxx/omarchy-plugin-lock-plus](https://github.com/Rockeyxx/omarchy-plugin-lock-plus) | 5 | 919 lines | Stock look plus clock, date, shutdown and reboot buttons |
| [MrDemonc/Omarchy-lock-style](https://github.com/MrDemonc/Omarchy-lock-style) | 4 | 551 lines | Colour, wallpaper and blur editor |
| [shmall03/omarchy-shmall.lock-plugin](https://github.com/shmall03/omarchy-shmall.lock-plugin) | 4 | 541 lines | Shows the music that is playing |
| [iamcheyan/omarchy-lock-screen](https://github.com/iamcheyan/omarchy-lock-screen) | 3 | 582 lines | Stock look plus an avatar |

All five work the same way: they replace `omarchy.lock` and run their own PAM check (the Linux
login check) for the password. All five are MIT. I picked Lock Screen Explorer because it is the
most used and the most active, and its designs cover most of what the small ones add.

**None of them has an on-screen keyboard.** With the keyboard detached, you still cannot type the
password. Installing this plugin does not solve the problem in [lock-screen.md](lock-screen.md).

### Install

```sh
omarchy plugin add https://github.com/SirJul1337/omarchy-lock-explorer.git --enable --yes
omarchy restart shell
omarchy-shell lock explore
```

What I saw `[tested here]`:

- After the add, `omarchy plugin list` showed the plugin enabled and `omarchy.lock` disabled.
- The shell log said another handler still owned the `lock` command. The plugin's README says to
  restart the shell if that happens. After `omarchy restart shell` the warning was gone.
- No errors from bare `Color.*` uses, the Qt 6.12 problem that made an older copy of this plugin
  log errors on another machine.

- Lock and unlock with the password worked several times on 2026-11-15. For a first try on your own
  machine, keep a text screen (`Ctrl+Alt+F3`) logged in.

### Do not use

The boot screen part (drive decryption screen). It writes system files with `pkexec` `[source]`.
The lock screen part does not need it.

### Remove

```sh
omarchy plugin remove --yes io.github.sirjul1337.lock-explorer
omarchy plugin enable omarchy.lock
```

The second line matters. The plugin's README says Omarchy can leave its own lock off after removal,
and then nothing locks the screen.

## Mission Control (moving between desktops)

Plugin `henri.missioncontrol`,
[henriSchulz/omarchy-mission-control](https://github.com/henriSchulz/omarchy-mission-control),
commit `76cfd0a`. A macOS style Mission Control (all desktops at once), App Exposé (all windows of
one app) and Show Desktop. I read the code before install: no root, no network, it runs `hyprctl -j`
and a wallpaper name script `[source]`. Installed 2026-11-14.

### Keys and gestures `[tested here]`

Keys in `~/.config/hypr/bindings.lua`:

| Key | Action |
|---|---|
| `F8` | Mission Control |
| `SHIFT + F8` | App Exposé |
| `CTRL + F8` | Show Desktop |

Not `F9`, because I use it for dictation.

Touchpad gestures in `~/.config/hypr/input.lua`:

| Gesture | Action |
|---|---|
| 3 or 4 fingers up | Mission Control (follows the fingers) |
| 4 fingers down | App Exposé |
| 3 fingers down | Previous desktop |
| 3 or 4 fingers sideways | Switch desktop. While the overview is open, it slides the overview. |

I turned off the old 3 fingers up gesture (jump to an empty desktop). It looked like Show Desktop and
was confusing. The plugin calls `mission_control_swipe_mode()` in `input.lua` when it opens and
closes, and I made that function swap both the 3 and 4 finger sideways gestures. So this needs no
change to the plugin. `hyprctl reload` applied every gesture change, no logout.

These are touchpad gestures. With the keyboard detached there is no touchpad, so on glass only a tap
on the overview works. Touch screen gestures need `hyprgrass`, see [minimal.md](minimal.md).

### Local patches, sent upstream

My installed copy carries four changes, each sent as a pull request:

| PR | Change |
|---|---|
| [#1](https://github.com/henriSchulz/omarchy-mission-control/pull/1) | A clicked floating window comes to the front, and copies keep the real stacking order |
| [#2](https://github.com/henriSchulz/omarchy-mission-control/pull/2) | Overlapping floating windows are spread out |
| [#3](https://github.com/henriSchulz/omarchy-mission-control/pull/3) | A tap closes the overview in 140 ms with no wait. The swipe is unchanged. |
| [#4](https://github.com/henriSchulz/omarchy-mission-control/pull/4) | White overview text gets a thin dark outline, so it reads on a light wallpaper |

The patch is a local commit on a `local-patches` branch in the plugin folder. A plugin update then
cannot fast forward and stops with an error, so it cannot delete the patch. My post-update hook also
skips this plugin until the PRs merge.

After they merge: in the plugin folder run `git switch main && git branch -D local-patches`, then
`omarchy plugin update henri.missioncontrol` and `omarchy restart shell`.

### Test without touching the machine

```sh
hyprctl dispatch 'hl.dsp.event("mission-control toggle")'
grim overview.png
```

## Spaces (desktops in the bar)

Plugin `tornikegomareli.spaces`,
[tornikegomareli/omarchy-spaces](https://github.com/tornikegomareli/omarchy-spaces), v1.8.0. It
replaces the desktop numbers in the bar with app icons and a preview. Two of my fixes are in it
(PRs #51 and #52, merged 2026-11-13), so I run it with no local patch. A click on an app icon is a
good touch target with the keyboard off.

## Not checked

- Lock Screen Explorer after sleep with the keyboard detached (it cannot work today, no keyboard).
- Any of these plugins on Omarchy versions other than 4.5.0-3.
