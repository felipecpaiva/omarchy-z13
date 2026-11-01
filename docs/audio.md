# Speakers too quiet

Status as of 2026-11-01. Tested on my own Z13 (GZ302EA), Omarchy 4.0.6, kernel 7.2.8, PipeWire 1.6.9.

## Symptom

Speakers play, but sound is thin and quiet even with the system volume at 100%. A YouTube video was hard
to hear.

## What I checked

- **Both speaker amps work.** Two Cirrus `CS35L41` amps load their firmware at boot (`dmesg` shows
  `Firmware Loaded` and `CS35L41 Bound` for both the left and right amp). A tone played on each side
  and both were audible.
- **Firmware is installed.** The files for this model (subsystem `10431fb3`) are in
  `/usr/lib/firmware/cirrus/`.
- **The cause was a hidden hardware volume.** The ALSA `Master` control on the `ALC294` card was at 69%
  (-20 dB). The normal volume slider does not touch it, so 100% on the slider was still 20 dB down.

## Fix

Raise `Master` to 100% (0 dB, the top of its range), in steps of about 10% so nothing gets sudden:

```
amixer -c Generic_1 sset Master 100%
```

Check the card id first with `aplay -l`. Mine is `Generic_1` (the `ALC294 Analog` one, not the HDMI card).

To keep it across reboots, the Z13 runs the same line at login. In `~/.config/hypr/autostart.lua`:

```lua
o.launch_on_start("amixer -c Generic_1 sset Master 100%")
```

Limit: the card is picked by its id. If the card order ever swaps, the line will hit the wrong card.

## Side finding: amp errors

Before a reboot, the kernel log filled with `cs35l41-hda ...hda.1: Enable(1) failed: -16` (error `-16` is
"busy") for the right amp, 32 times in one boot. The right amp shares a reset line with the left one
(`Reset line busy, assuming shared reset` at boot). After a reboot the errors did not come back during
my tests. I do not know the cause, and I did not find a fix. Watch for it if one side goes quiet:

```
journalctl -k -b | grep -E "cs35l41.*(failed|Cannot)"
```

## Not tried

- PipeWire volume above 100%. It can distort loud sounds.
- Other firmware tuning files for the speaker protection. One
  [write-up](https://dev.to/ankk98/rog-flow-z13-2025-linux-audio-quality-investigation-3ggk) says Linux is
  quieter than Windows on this model. That is one report, not a confirmed cause.
