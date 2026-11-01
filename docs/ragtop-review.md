# ragtop code review

Written 2026-11-01. A reading of [sclemance/ragtop](https://github.com/sclemance/ragtop) before anyone
installs it. This is a point in time reading of one commit, not a verdict on the project or its author.
I have not contacted the author. Nothing was installed and none of its code was run.

Markers: `[read]` means I read it in full, `[part]` means I read the relevant section, `[grep]` means I
searched for patterns only, `[tested here]` means I ran a command on my Z13.

## What was reviewed

| Item | Value |
|---|---|
| Commit | `1ffb2ccb61d273214ac38dcf225de63b606f0a42`, 2026-10-31, version 0.48.1 |
| History | 136 commits, one author, created 2026-09-20, MIT license |
| Version churn | 0.47.0 in the manifest earlier on 2026-10-31, 0.48.0 and 0.48.1 the same day |
| Method | Cloned into an isolated folder, read only, pattern search over every non-test file |

## Size

About 17,600 lines of code, not counting tests, benchmarks, translations or data.

| File | Lines | Role |
|---|---|---|
| `Service.qml` | 4,034 | State, child processes, every surface, runs inside the Omarchy shell |
| `Keyboard.qml` | 2,519 | The on-screen keyboard |
| `predictor.py` | 1,442 | Word suggestions and swipe decoding |
| `ragtop` (CLI) | 1,160 | Settings, themes, diagnostics, downloads |
| `overlay-clones.sh` | 1,088 | Copies and patches Omarchy overlays |
| `keyboard-helper.py` | 974 | Sends key presses through a Wayland virtual keyboard |
| `LockKeyboard.qml` | 781 | The lock screen keyboard |
| `Tour.qml`, `ToolsPanel.qml`, `SetupWizard.qml` | 773, 702, 679 | Tour, settings panel, first run setup |
| `fcitx-osk-bridge.py` | 412 | Talks to fcitx5 for auto-show |
| `install.sh` | 369 | Installer |
| others | under 350 each | `udev-rule.sh` is 110, `tablet-switch.py` is 71 |

## What I read

- `[read]` `udev-rule.sh`, `install.sh`, `setup-apply.sh`, `tablet-switch.py`, `find-tablet-switch.py`.
- `[part]` `overlay-clones.sh` (the function map and the lock screen patch), `LockKeyboard.qml` (the key
  handling), the `ragtop` CLI (the download and update functions), `fcitx-osk-bridge.py` (the top).
- `[grep]` Every non-test file, for root use, network access, shell execution, file writes and typed text.
- Not read line by line: `Service.qml`, `Keyboard.qml`, `predictor.py`, `keyboard-helper.py`, most of the
  CLI and `overlay-clones.sh`. About 11,000 lines. The word data files are binary, and a small custom
  msgpack reader in `predictor.py` parses them. I did not audit that reader.

## What looked good

- **One root path, and it is narrow.** Only `udev-rule.sh` uses `pkexec` (or `sudo` when `pkexec` is
  missing). It runs a fixed script, passes values as arguments, and does not interpolate user data. On
  removal it also takes back the access that `uaccess` had put on the device, which many installers miss.
- **No telemetry, no runtime network.** The CLI downloads two things. Word lists for other languages come
  from the author's own release (`github.com/sclemance/ragtop/releases/download/data-v1`), https only,
  checked against a fixed SHA-256 before use. A version check reads `manifest.json` from GitHub raw and
  uses only the version string, which is never run.
- **Careful shell use.** Commands built in QML pass data as positional arguments (`"$1"`), not inline.
  Runtime files are written to a temp name and moved into place.
- **Typed text stays in memory.** Nothing I found writes it to disk. A Typing Memory setting limits what
  is kept, and password fields are excluded. The lock screen keyboard sends keys straight to the password
  field and keeps nothing. The one log of keystrokes is a `--dry-run` mode used by tests.
- **The Omarchy overlay copies are opt-in.** Off by default. The installer asks once with a default of
  no. You choose overlays one at a time. If a patch no longer fits after an Omarchy update, ragtop removes
  its copy and the stock overlay comes back.
- **Project health signs.** Many tests, fixtures for Omarchy 4.0.4, a pinned 7cc6a55 build and 4.5.0-rc1,
  and a changelog style that records its own mistakes.

## Concerns, ranked

1. **The lock screen copy loads code from the plugin folder.** The patched lock plugin loads
   `LockKeyboard.qml` from `~/.config/omarchy/plugins/sclemance.ragtop/` and gives it the lock view, which
   includes the password text. If that file changes, it can see what is typed there. The folder is a git
   checkout from one author, so a later plugin update changes code that runs on your lock screen.
2. **It installs boot and update hooks.** `~/.config/omarchy/hooks/post-boot.d/ragtop-overlay-check.hook`
   and `post-update.d/ragtop-overlay-sync.hook`, plus a kept copy of its scripts in
   `~/.local/share/ragtop/keeper`. The hooks run the kept copy when the plugin folder is gone, to clean
   up. All of it is user level, with no root. It is still code that runs on every boot and update.
3. **On a Z13 the root rule probably does not match.** See the next section.
4. **It runs inside the shell.** A QML error can take the whole shell down, and its own notes say so. The
   project is six weeks old with one maintainer.
5. **Custom parser for bundled binary data.** Small, but unaudited.

## The udev rule and the Z13

The rule file is `/etc/udev/rules.d/70-ragtop-tablet-switch.rules`:

```
SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_SWITCH}=="1", ENV{ID_INPUT_KEY}!="1", TAG+="uaccess"
```

It is only offered when the switch device is not readable by the user, and only after asking.

On this Z13 the tablet switch lives on the device `Asus WMI hotkeys` (`/dev/input/event18`, mode 0660,
`root:input`, my user is not in `input`). `udevadm info` reports `ID_INPUT_SWITCH=1` and also
`ID_INPUT_KEY=1`, because the same device carries the hotkey buttons. `[tested here]` The rule requires
`ID_INPUT_KEY` to not be 1, so by my reading it skips this device and ragtop could not read the switch.
That is `[untested]`.

Ways around it: use ragtop's manual "Always On" tablet mode, widen the rule (programs running as the user
could then read the hotkey presses, which are only the special keys), or have our own Hyprland bind write
the mode file ragtop reads (`$XDG_RUNTIME_DIR/ragtop-mode`). Whether ragtop accepts that last route is
`[untested]`.

## Where ragtop writes

`~/.config/omarchy/plugins/sclemance.ragtop` (a link to the checkout), a marked block at the top of
`~/.config/omarchy/extensions/omarchy-menu.jsonc`, `~/.config/ragtop`, `~/.local/state/ragtop`,
`~/.cache/ragtop/stems`, `$XDG_RUNTIME_DIR/ragtop-*.json` and `ragtop-mode`, and when overlays are on,
patched copies of the menu, emoji picker, clipboard picker, polkit prompt, image picker and lock screen
under `~/.config/omarchy/plugins`. The uninstaller removes all of it.

## Programs it launches

`bash` and `sh` (with data as arguments), `/usr/bin/python3` for its helpers, `hyprctl eval` and
`hyprctl getoption`, `systemd-run --user` for the setup apply step, `monitor-sensor --accel`, `jq`,
`busctl get-property`, `omarchy-shell lock`, and a few Omarchy commands. `[grep]`

## If it is trialled anyway

1. Clone it and check out `1ffb2cc`. Do not auto-update.
2. Back up `~/.config/omarchy` first.
3. Install with `--no-udev --no-overlays`. Test the keyboard and measure with the protocol in
   [evaluation.md](evaluation.md).
4. Turn on only the lock screen copy, and last. Know the text screen rescue (`Ctrl+Alt+F3`) first.
5. Before a later update, diff the new commit against `1ffb2cc` for the files listed above.

## Not done

- The unread files above.
- No run, no install, no test of ragtop's own test suite.
- The Z13 has not been tried with ragtop.
- Whether Omarchy's own plugin update would pull a newer ragtop.

See also [lock-screen.md](lock-screen.md) for what a minimal copy of only the lock keyboard would cost.
