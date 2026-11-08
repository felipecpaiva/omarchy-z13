# Choppy cursor after sleep

Status as of 2026-11-08. Tested on my own Z13 (GZ302EA), Omarchy 4.5.0-3, kernel 7.2.15-1-omarchy,
Hyprland 0.56.2.

## Symptom

After the lid closes and opens again, the cursor works for about 2 seconds, then gets choppy. It
comes and goes: a few smooth seconds, then choppy again. A reboot clears it, until the next sleep.

## What I checked

- **The hardware cursor is on.** `hyprctl getoption cursor:no_hardware_cursors` returned `set: false`,
  so the software cursor was not the cause.
- **The kernel log had a repeating `amdgpu` error.** `journalctl -b -k` showed
  `[drm] [handle_hpd_irq_replay_sink] DPCD read addr.0x378 failed with 10 retries`. It appeared at boot
  and again at the wake from `s2idle`. That error belongs to the panel's self refresh path (PSR and
  Panel Replay). I found no `i2c_hid` reset errors, so the touchpad driver looked fine.
- **I found no community report for this exact setup.** Searches for the Z13, Hyprland and cursor lag
  after resume turned up only loosely related threads. A search of the Omarchy issues found nothing.

## Fix

Turn off PSR and Panel Replay in the `amdgpu` driver with a kernel option. This follows the pattern of
the other drop-ins in `/etc/limine-entry-tool.d/`:

```bash
echo 'KERNEL_CMDLINE[default]+=" amdgpu.dcdebugmask=0x410"' | sudo tee /etc/limine-entry-tool.d/amdgpu-psr.conf
sudo limine-update
```

Reboot, then check `cat /proc/cmdline | grep -o "amdgpu[^ ]*"`. It should print
`amdgpu.dcdebugmask=0x410`.

## Result

Tested once: after the reboot I closed the lid, opened it, and moved the mouse. It stayed smooth. One
test, not a long soak. I did not measure the battery cost. Turning off panel self refresh should cost
some power, and I have not put a number on it.

## Narrower option: 0x600 also works

On 2026-11-08 I swapped `0x410` for `0x600` (turns off PSR-SU, `0x200`, and Panel Replay, `0x400`; plain
PSR, `0x10`, stays on). After a reboot, the cursor stayed smooth after sleep. One reboot, one sleep
test by eye, no battery measurement. So plain PSR is probably not the cause. Panel Replay or PSR-SU
is. I did not test `0x400` or `0x200` alone. The `0x600` value comes from the
[GZ302 setup project](https://github.com/th3cavalry/GZ302-Linux-Setup). I now run `0x600`.

## Rollback

Delete `/etc/limine-entry-tool.d/amdgpu-psr.conf`, run `sudo limine-update`, and reboot.

## Upstream

Posted to Omarchy on 2026-11-08 as a Support discussion:
[omacom/omarchy#18120](https://github.com/omacom/omarchy/discussions/18120). It asks whether Omarchy
should ship the option for the Z13 or whether this is a kernel bug. No reply yet.

## Not proven

- I did not test Panel Replay (`0x400`) and PSR-SU (`0x200`) one at a time, so I do not know which one
  is the cause. `0x600` turns off both.
- I did not capture the bad state with a frame counter, so "choppy" is by eye.
