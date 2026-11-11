# omarchy-z13

Omarchy has no tablet mode yet. On the ASUS ROG Flow Z13 you can build one from community parts, and
Omarchy 4.5 will add some of it. This repo tracks what exists, what is coming, and what I am doing on
my own Z13.

Status as of 2026-11-01: research and design only. **No tablet software is installed on the Z13 yet**,
and nothing here is a finished guide. Every claim says how I checked it: tested on my machine, read from
source, or only seen in a search result. To pick the work up again, start at the "Where we stopped"
section of [docs/plan.md](docs/plan.md).

## The short version

- **Omarchy 4.0.6 and the 4.5 release candidates (rc2, and the rc3 tag) have no on-screen keyboard and no auto-rotate.** I compared the two
  tags and found no tablet commits (commit messages only, so a change with a vague title could hide).
- **One plugin targets the Z13 directly:**
  [AlanRoman117/omarchy-tablet-mode-asus-rog-flow-z13](https://github.com/AlanRoman117/omarchy-tablet-mode-asus-rog-flow-z13).
  It was tested on one Z13 (GZ302EA) with Omarchy 4.0.6 and Hyprland 0.56.2, which matches my setup.
- **That plugin turns on sensor rotation at the moment you detach the keyboard.** Read from its source:
  the rotation lock starts off every time the service starts, and the sensor reader runs whenever tablet
  mode is on and the lock is off. `auto_rotate=false` in its config stops the screen from following the
  sensor while the on-screen keyboard and touch tweaks still come on at detach (the plugin's author
  confirmed this on 2026-11-01). It also turns sensor rotation off for good. I found no setting that
  keeps sensor rotation available but starts it only on request.
- **The detach is visible to Hyprland with no extra software.** The Z13's `Asus WMI hotkeys` device
  carries a tablet-mode switch, and a Hyprland bind on it fired on detach and again on attach (tested
  once, on kernel 7.2.8 and Hyprland 0.56.2). One KDE project reports the opposite for the same model, so
  firmware or kernel versions may differ. That makes a small route possible: two binds, one static
  settings file, and one on-screen keyboard package. See [docs/minimal.md](docs/minimal.md).
- **Omarchy 4.5 has two open pull requests for rotation** ([#13531](https://github.com/omacom/omarchy/pull/13531)
  and [#7493](https://github.com/omacom/omarchy/pull/7493)). Both follow the sensor all the time with a
  lock, like a phone. Neither ties rotation to the keyboard. Neither adds an on-screen keyboard.
- **Touch users hit real bugs today:** the Omarchy menu and bar pop-ups close when you tap an on-screen
  keyboard ([#9029](https://github.com/omacom/omarchy/issues/9029),
  [#9756](https://github.com/omacom/omarchy/issues/9756)), and the lock screen needs the real keyboard.
- **The lock screen is the hard part.** The session lock hides every window, so no keyboard plugin can
  appear on it. Only ragtop reaches it, by copying and patching Omarchy's lock plugin. I posted a proposal
  to Omarchy on 2026-11-01 for a lock screen keyboard and then a PIN
  ([#17222](https://github.com/omacom/omarchy/discussions/17222)). See
  [docs/lock-screen.md](docs/lock-screen.md) and [docs/upstream.md](docs/upstream.md).
- **Face login is not in Omarchy.** The Z13's IR camera is visible to Linux. Several community tools
  exist. Nothing is tried yet. See [docs/face-unlock.md](docs/face-unlock.md).
- **The boot password cannot be typed on glass.** It is the disk password, asked before any desktop
  exists. Attach the keyboard to power on. See section 10 of [docs/research.md](docs/research.md).

## What is in here

| File | What it holds |
|---|---|
| [docs/research.md](docs/research.md) | Findings, tool comparison, upstream status, sources, and what I could not find |
| [docs/minimal.md](docs/minimal.md) | A design for tablet mode with one new package, no plugin and no rotation code, built on what Omarchy already has. Not built yet. |
| [docs/evaluation.md](docs/evaluation.md) | The native route against ragtop, Alan's plugin and the yeutterg set: functions, toggles, resource cost, a measurement protocol, and the two questions that decide the path |
| [docs/ragtop-review.md](docs/ragtop-review.md) | A reading of ragtop's code at one commit: what looked good, what to watch, how to trial it safely |
| [docs/lock-screen.md](docs/lock-screen.md) | The lock screen problem, what Omarchy's lock plugin offers, and the options with effort and safety |
| [docs/face-unlock.md](docs/face-unlock.md) | Face login on Omarchy and the Z13's IR camera |
| [docs/upstream.md](docs/upstream.md) | How Omarchy takes changes, what I sent, what I watch, what comes next |
| [docs/upstream-proposal.md](docs/upstream-proposal.md) | The proposal text exactly as posted |
| [docs/audio.md](docs/audio.md) | Quiet speakers: the hidden `Master` volume at 69%, the fix, and the right-amp errors I saw |
| [docs/side-button.md](docs/side-button.md) | The Z13's side button (confirmed as `XF86Launch3`): the live test, what other setups do with it, prior art for a button mapper, a design for one, and the one line applied so far (the button opens the Omarchy menu) |
| [docs/cursor-lag-after-resume.md](docs/cursor-lag-after-resume.md) | Choppy cursor after sleep: the `amdgpu` panel replay error in the log, the kernel option that fixed it, and what I did not prove |
| [docs/power-profile.md](docs/power-profile.md) | Power profiles and fans: `performance` on AC runs the fans hard, CPU and GPU measurements per profile, `powerprofilesctl launch` for performance on demand, a fan curve I tried and rolled back, and what I did not prove |
| [docs/upstream-power-profile.md](docs/upstream-power-profile.md) | The report for Omarchy on the power profile findings, with the posted text and links (posted 2026-11-10) |
| [docs/plan.md](docs/plan.md) | Where I stopped, what to do next on this machine with rollback, and the upstream track |

The only scripts are the measurement ones in [scripts/power-profile/](scripts/power-profile/), and they have
run on a real Z13.

## Device this was checked on

ASUS ROG Flow Z13 (2025), GZ302EA. Omarchy 4.0.6-1, Hyprland 0.56.2-4, Quickshell 0.3.2,
iio-sensor-proxy 3.9-1, kernel 7.2.8-9-omarchy. Other Z13 revisions may differ.

## Help wanted

If you run Omarchy on a Z13, a detachable or a convertible, a hardware report is the most useful thing
you can send. Open an issue with your model, Omarchy version, what you tried and what happened. Fixes to
this research are welcome as pull requests.

## License

MIT, see [LICENSE](LICENSE). Third-party tools linked here keep their own licenses. The `wvkbd` patches
inside Alan's plugin are GPL-3.0-only, so I do not copy them here.
