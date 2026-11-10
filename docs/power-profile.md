# Power profile: balanced by default, performance on demand

Status as of 2026-11-10. Measured on my own Z13 (GZ302EA, Ryzen AI Max+ 395), Omarchy 4.5.0-3, kernel
7.2.15-1-omarchy, asusctl 6.5.0-1, omarchy-power-profiles-daemon 0.30-3. All runs on AC power. Every
number comes from one run per profile unless it says otherwise.

## The short version

- **Omarchy puts the Z13 on `performance` when plugged in, and `performance` runs the fans hard.** On the
  Z13 the profile sets the fan speed, not the heat. At the same 49 C idle, `performance` spun the CPU fan at
  3983 RPM and `power-saver` at 2300 RPM.
- **For CPU work, `balanced` loses almost nothing.** In a 5 minute all core test the CPU speed and chip
  power were within about 1% of `performance`. Only the fans were louder.
- **For long heavy GPU work, `balanced` is slower.** A local LLM prompt ran 18% faster on `performance`
  over 4 minutes, at 18 W more power and 13 C hotter.
- **No tool does this on demand.** I found nothing in Omarchy, TLP, auto-cpufreq or power-profiles-daemon
  that changes the profile by load or heat. See [What exists](#what-exists-upstream-and-elsewhere).
- **What works today with no new software:** stay on `balanced`, and wrap a heavy job in
  `powerprofilesctl launch -p performance -- <command>`. The profile is `performance` only while the
  command runs. Tested here.
- **A custom fan curve made it worse.** Louder fans and 4 to 5 W more chip power. I rolled it back. Details
  below, so nobody else has to repeat it.

## The question

I plugged in, the profile was `performance`, and the fan came on at once. Is there a mode that boosts when
work needs it and stays quiet and frugal otherwise?

## Who sets the profile

Three things can set the power profile on this machine. I read each one.

| Who | What it does | How I checked |
|---|---|---|
| Omarchy | Keeps one saved profile per power source (`ac`, `battery`) in `~/.local/state/omarchy/powerprofiles/` and applies it on every plug or unplug, through `omarchy-powerprofiles-set` | Read `/usr/share/omarchy/bin/omarchy-powerprofiles-set` and the shell's battery service. A fresh install with nothing saved picks `performance` on AC |
| `asusd` | Has its own plugged-in and battery profile. Mine were `Performance` and `Quiet` | `asusctl profile get`, and the `asusd` journal on a plug event |
| A udev rule I wrote earlier | Ran `powerprofilesctl set performance` on plug and `balanced` on unplug, ignoring Omarchy's saved value | Read the rule file |

## Plug and unplug test

I logged the profile every 0.25 s while unplugging and replugging once, twice in total.

**With my udev rule in place (test 1):**

- Unplug: `asusd` moved the platform profile to `quiet`, then Omarchy set `power-saver` within a second.
- Replug: the profile went to `performance` for about 0.4 s, then Omarchy set `balanced`.

**After I deleted my udev rule (test 2):**

- Unplug: `quiet` first, then `power-saver` after 1.3 s.
- Replug: platform profile `performance` for about 0.4 s, then `balanced`.

What this shows:

- Omarchy ends up with the last word on both events, because it runs a fraction of a second after the
  others. The saved files were not rewritten.
- **A correction to my own first reading.** After test 1 I blamed my udev rule for the `performance` flash
  on plug. That was a guess. The flash still happened without the rule. The source is `asusd`, whose own
  plugged-in profile was `Performance`.
- Two tests is not enough to say the order never changes. I did not test a plug while the machine was
  busy.

## Measurements

Method: set the profile with `powerprofilesctl`, wait for the fans to settle, then record fan RPM (from
`sensors`), `Tctl`, average CPU MHz, and chip power (`power1_average` of the `amdgpu` hwmon, which reports
the whole APU) every 5 to 10 s. The scripts and the raw numbers are in this repo, see
[Reproduce](#reproduce).

### 1. CPU, 60 s all core load (stress-ng)

| Profile | Idle fans, CPU / GPU RPM | Idle Tctl | Load fans, CPU / GPU RPM | Load Tctl |
|---|---|---|---|---|
| `power-saver` | 2300 / 2800 | 49.1 C | 2800 / 3216 | 65.4 C |
| `balanced` | 3100 / 3600 | 51.1 C | 3316 / 3700 | 67.4 C |
| `performance` | 3983 / 4383 | 48.8 C | 4000 / 4416 | 63.8 C |

CPU speed under load was 2.93 to 2.99 GHz in all three.

### 2. CPU, 5 minute all core load

| Window | Profile | CPU fan RPM | CPU speed | Chip power | Tctl |
|---|---|---|---|---|---|
| 0 to 60 s | `balanced` | 2886 | 2.94 GHz | 40.1 W | 61.0 C |
| 0 to 60 s | `performance` | 4200 | 2.97 GHz | 38.8 W | 61.2 C |
| 180 to 300 s | `balanced` | 4208 | 2.90 GHz | 39.8 W | 70.6 C |
| 180 to 300 s | `performance` | 4838 | 2.93 GHz | 39.8 W | 68.2 C |

The ASUS sustained and burst power limits read 60 W and 75 W in both profiles. The `asusd` log says its
tuning group is off, so these limits may not follow the profile at all. The chip drew about 40 W, so it
never reached them. A heavier CPU load might.

### 3. GPU, 4 minutes of llama.cpp (Vulkan)

Model: Qwen3 30B A3B, Q4_K_M, all layers on the GPU. `llama-bench`, prompt of 2048 tokens and 512 generated
tokens, four chunks of about a minute per profile. "Reading" is prompt processing, "writing" is token
generation. Averages over the run.

| Profile | Reading, tokens/s | Writing, tokens/s | Chip power | Tctl | Hottest | Fans, CPU / GPU RPM |
|---|---|---|---|---|---|---|
| `power-saver` | 893 (987 to 791) | 81.8 | 38.2 W | 74.6 C | 78.2 C | 4125 / 4539 |
| `balanced` | 1115 (1232 to 1023) | 86.8 | 48.3 W | 77.2 C | 81.8 C | 4604 / 4981 |
| `performance` | 1314 (1377 to 1258) | 90.3 | 65.8 W | 89.7 C | 93.5 C | 5829 / 6250 |

The numbers in brackets are the first and last chunk. `balanced` lost 17% across the run, `performance`
9%. Writing is bound by memory speed, so it barely moves. Reading is compute bound, so the profile matters.

### 4. The same job with `powerprofilesctl launch`

A short run (3 repeats) on `balanced`, with and without the hold:

| Run | Reading, tokens/s | Writing, tokens/s |
|---|---|---|
| `balanced` | 1305 | 89.1 |
| `performance` held by `launch` | 1395 | 91.7 |

The gap is 7% here, smaller than in test 3, because a short run does not heat the chip enough for
`balanced` to slow down.

## What I changed

1. **Deleted my own udev rule.** It was redundant, as Omarchy applies its saved value anyway.
2. **`asusctl profile set --ac balanced`.** So `asusd` stops trying to put the machine on `performance`
   when I plug in. **Not re-tested.** I confirmed with `asusctl profile get` that the plugged-in profile
   now reads `Balanced`, but I did not log another plug event after the change.
3. **Habit, not a setting:** stay on `balanced`, use `launch` for heavy jobs.

## What I tried and rolled back: a custom fan curve

I turned on a gentler fan curve for `balanced` with `asusctl fan-curve`: 4% at 48 C rising to 100% at
85 C. I expected quieter fans. The custom curves are off by default, so the firmware's own curve runs. The stored default
curve tops out at 40% fan, which I judged unsafe for heavy load, so I wrote my own.

| Load | Factory curve, fans CPU / GPU RPM | My curve, fans CPU / GPU RPM | Factory chip power | My curve chip power |
|---|---|---|---|---|
| Idle | 3100 / 3600 | 3329 / 3529 | not measured | 13.6 W |
| CPU load | 4208 / 4623 | 5215 / 5415 | 39.8 W | 44.9 W |
| GPU load | 4604 / 4981 | 6785 / 6977 | 48.3 W | 52.2 W |

The curve was louder everywhere and the chip drew 4 to 5 W more under load, with no cooler result on the
GPU test (77 C in both). I rolled it back and restored the default data. I do not know why the power went
up. A cooler chip boosting harder is a guess I did not test.

Two caveats on this comparison: the factory numbers come from the earlier runs, not from a back to back
test, and the windows were not the same length. Also, a 3% setting still gave about 3300 RPM, so the
percentages do not map to RPM the way I assumed. A lower curve might behave differently. I did not try.

## What exists upstream and elsewhere

Found by search, not by running it (except where noted):

- **Omarchy already switches by power source** (added in 3.4.0, pull request 4375), and 4.x remembers the
  last profile per source. Read from the installed scripts.
- **Nothing switches by load or heat.** I read the Omarchy scripts and shell service on this machine and
  found no CPU load or temperature logic. Search of TLP, auto-cpufreq and power-profiles-daemon found none
  for the profile either. A negative from search only, so it could be wrong.
- **Pull request 6046** (a config file for the plugged in and battery profiles) was closed without merge
  with the reason that Omarchy now saves the last setting.
- **Issue 7516** reports `performance` running fans at full speed on an Alienware, with the same cause: a
  firmware `performance` mode that ignores temperature. **Pull request 16454** is open and would make an
  unset plugged in profile `balanced`. Both were open on 2026-11-10.
- **Alternatives I did not try:** `tlp-pd` (a drop in for power-profiles-daemon, switches by power source),
  `auto-cpufreq` (the only one that reads load and heat, and it conflicts with power-profiles-daemon), and
  `foamy-power` (configurable plugged in and battery defaults). Running TLP or auto-cpufreq next to
  power-profiles-daemon is not supported.

## What I did not prove

- Whether the plug time flash is gone after the `asusctl profile set --ac balanced` change.
- Why the profile was `performance` once at 16:10 with no plug event. It was not my udev rule and the
  saved files were untouched. Something set it by hand or through a menu.
- Whole machine power. I only see the chip's watts on AC. A battery drain comparison would add fans and
  screen.
- The GPU as a 3D graphics load. The GPU test is compute and memory only.
- Idle chip power per profile.
- Other Z13 revisions, other firmware, other workloads.
- Anything with `tlp-pd`, `auto-cpufreq` or `foamy-power`.

## Roll back

```
asusctl profile set --ac performance        # asusd plugged in profile back to its old value
asusctl fan-curve --mod-profile balanced --enable-fan-curves false
```

To restore my old udev rule, put these two lines in `/etc/udev/rules.d/99-z13-power-profile.rules` and run
`sudo udevadm control --reload`:

```
SUBSYSTEM=="power_supply", KERNEL=="AC0", ATTR{online}=="1", RUN+="/usr/bin/powerprofilesctl set performance"
SUBSYSTEM=="power_supply", KERNEL=="AC0", ATTR{online}=="0", RUN+="/usr/bin/powerprofilesctl set balanced"
```

## Reproduce

Scripts are in [scripts/power-profile/](../scripts/power-profile/), raw numbers in
[docs/data/power-profile/](data/power-profile/). They run on a Z13 on AC power, restore the starting
profile when they end, and stop a load if the CPU passes 95 C (88 C for the fan curve test).

| Script | Test | Data |
|---|---|---|
| `baseline.sh` | CPU, 60 s per profile | `baseline-2026-11-09.csv` |
| `long.sh` | CPU, 5 minutes, balanced then performance | `long-2026-11-09.csv` |
| `gpu.sh` | GPU, llama-bench, three profiles | `gpu-results-2026-11-09.csv`, `gpu-series-2026-11-09.csv` |
| `curve.sh` | The fan curve I rolled back | `curve-2026-11-09.csv`, `fan-curve-balanced-before.txt` |
| `plug.sh` | Logs profile changes during a plug test | the log is not kept, it holds the machine name |

Two things are hard coded for my machine: the `amdgpu` hwmon index (`hwmon5`) and the GPU card
(`card1`). Check yours with `cat /sys/class/hwmon/hwmon*/name` and `ls /sys/class/drm`. `gpu.sh` expects
the model at `~/models/Qwen3-30B-A3B-Q4_K_M.gguf`.

## Where we stopped

- Done: the measurements above, the plug tests, the three changes, the fan curve experiment.
- Next: log one more plug test after the `asusctl` change. Compare idle watts on battery with the profile
  on `balanced` and `power-saver`.
- Next: a report to Omarchy, see [upstream-power-profile.md](upstream-power-profile.md).
- Only if the above leaves a real gap: a small script that switches `balanced` and `performance` by load
  and heat, with a delay so it does not flip back and forth. Not started.
