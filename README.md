# omarchy-z13

Omarchy has no tablet mode yet. On the ASUS ROG Flow Z13 you can build one from community parts, and
Omarchy 4.5 will add some of it. This repo tracks what exists, what is coming, and what I am doing on
my own Z13.

Status: research written 2026-10-31, nothing here is a finished guide yet. Every claim in
[docs/research.md](docs/research.md) says how I checked it: read from source, tested on my machine, or
only seen in a search result.

## The short version

- **Omarchy 4.0.6 and 4.5.0-rc2 have no on-screen keyboard and no auto-rotate.** I compared the two
  tags and found no tablet commits (commit messages only, so a change with a vague title could hide).
- **One plugin targets the Z13 directly:**
  [AlanRoman117/omarchy-tablet-mode-asus-rog-flow-z13](https://github.com/AlanRoman117/omarchy-tablet-mode-asus-rog-flow-z13).
  It was tested on one Z13 (GZ302EA) with Omarchy 4.0.6 and Hyprland 0.56.2, which matches my setup.
- **That plugin turns rotation on at the moment you detach the keyboard.** Read from its source: the
  rotation lock starts off every time the service starts, and the sensor reader runs whenever tablet
  mode is on and the lock is off. There is no setting to separate the two.
- **Omarchy 4.5 has two open pull requests for rotation** ([#13531](https://github.com/omacom/omarchy/pull/13531)
  and [#7493](https://github.com/omacom/omarchy/pull/7493)). Both follow the sensor all the time with a
  lock, like a phone. Neither ties rotation to the keyboard. Neither adds an on-screen keyboard.
- **Touch users hit real bugs today:** the Omarchy menu and bar pop-ups close when you tap an on-screen
  keyboard ([#9029](https://github.com/omacom/omarchy/issues/9029),
  [#9756](https://github.com/omacom/omarchy/issues/9756)), and the lock screen needs the real keyboard.

## What is in here

| File | What it holds |
|---|---|
| [docs/research.md](docs/research.md) | Findings, tool comparison, upstream status, sources, and what I could not find |
| [docs/plan.md](docs/plan.md) | What I will do on this machine, step by step with rollback, plus what I want to send upstream |

No scripts yet. I will add one only after it has run on a real Z13.

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
