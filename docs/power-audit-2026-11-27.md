# Z13 power and resource audit, 2026-11-27

Why: the Z13 (`Z13P`) is a mobile machine, so idle cost matters more than on the M5 or the Windows
server. I turned the local LLM server off on the Z13 to save battery; it starts on demand with
`lms server start`. This audit looks at everything else that runs. Findings 1 and 2 turned out to
share one cause, which was found and removed the same day (see "Result"). Findings 3 to 5 got
decisions the same day (see "Findings 3 to 5").

Everything below was measured on 2026-11-27 on kernel `7.2.15-4-omarchy`, AC connected, battery at
the 85% charge limit. There is no passwordless sudo on this machine, so the root-side steps are run
by hand. Watt figures are estimates; CPU, event and time numbers are measured.

## Findings 1 and 2: one battery uevent loop burns about one core

### What is measured

| Fact | Evidence |
|---|---|
| The kernel emits about 196 `change` uevents per second for `BAT0`, and for nothing else | `udevadm monitor --kernel -s power_supply`: 1178 events in 6 s, every one `BAT0`; 1177 `change BAT0` after rule processing (`--udev`) |
| One `udev-worker` (pid 852592) sits at about 80% of a core and runs in the kernel | `schedstat` delta 4.04 s per 5 s; `utime` 1.06 M ticks vs `stime` 7.34 M ticks (87% kernel); about 1,090 context switches per second; state `R` for 27 h |
| `upowerd` is busy with the same events | Main thread about 20% CPU, about 270 context switches per second; `upower --monitor-detail` shows `BAT0` changing every second (upower coalesces) |
| `asusd` is busy with them too | Two `tokio-rt-worker` threads at about 4% each, mostly kernel time; 329 CPU-minutes in 3 days |
| The loop started at a resume from suspend, not at boot | `udev-worker` 852592 started 2026-11-26 17:27, the exact second `systemd-sleep` logged "System returned from sleep operation 'suspend'". The older worker 357239 started 2026-11-25 11:05:18, also a resume (it has since calmed down). The resume at 2026-11-25 09:36 produced no stuck worker, so it is intermittent. |
| The battery limit is written by two things | `/etc/udev/rules.d/99-battery-limit.rules` (created 2026-11-08, `ACTION=="add|change"`, writes `charge_control_end_threshold=85`) and `asusd` (`/etc/asusd/asusd.ron`: `charge_control_end_threshold: 85`) |
| `upowerd` was already at about 16% CPU in the previous boot | journal: "Consumed 4h 27min of CPU over 1d 3h 57min" on 2026-11-24 |

Correction to the first audit message: I first suspected the SD card (`mmc0`) because a
`irq/83-mmc0` thread and `fwupd` started at the same moment as the worker. They are all just
re-created at resume. The card is healthy (mounted since boot, no kernel errors, no I/O errors).
It is not the cause.

### Root cause: the rule is a self-sustaining loop (confirmed 2026-11-27)

Shareable write-up with the diagnosis and fix: [battery-threshold-uevent-loop.md](battery-threshold-uevent-loop.md).

What is established:

- The rule was mine. I added `99-battery-limit.rules` on 2026-11-08. No package owns it, and
  Omarchy 4.5.0 ships no charge-limit rule or feature (installed `omarchy-settings 4.5.0-3`, and
  tags v4.5.0 and v4.6.0-rc1; its own rules are the I/O scheduler and the touchpad). Upstream's
  default branch has had `bin/omarchy-battery-limit` since
  [PR #20379](https://github.com/omacom/omarchy/pull/20379) (merged 2026-11-27, "Add sleep drain
  visibility, battery health, and charge limit to power panel"), which sets the limit through
  UPower's `EnableChargeThreshold`. Once a machine enables that, `upowerd` becomes a threshold
  writer, so "`asusd` is the only writer" and "`upowerd` only reads" stop holding. Whether UPower's
  writes can loop on the Z13 is untested (`ChargeThresholdEnabled` is false here today).
  The ArchWiki ASUS page recommends a rule for `ACTION=="add"` only; mine also reacted to `change`.
- The rule wrote `charge_control_end_threshold` on every `add` and `change` event for `BAT0`, and
  `asusd` enforces the same 85%, so the rule was redundant.
- **Controlled test (below): with the rule installed, one triggered `change` event starts a storm of
  about 196 events per second; with the rule absent there are 0.** The rate is the same as the
  27-hour storm that began at a resume.

What is not established: which component re-emits the event. The kernel driver does not: `asus-wmi.c`
`charge_control_end_threshold_store` calls `asus_wmi_set_devstate()` and stores the value, with no
`power_supply_changed()`. The likely path is firmware: the embedded controller notifies the ACPI
battery driver after the WMI call, and that driver emits the `change`. Not verified. Similar storms
are reported without any custom rule: [systemd issue 21751](https://github.com/systemd/systemd/issues/21751)
is a `BAT0` storm on a Dell Latitude after wake, cleared by restarting `systemd-udevd.service` and
both udevd sockets and fixed permanently by a BIOS update (which supports a firmware cause);
[Launchpad LP #2169715](https://bugs.launchpad.net/bugs/2169715) reports 800 to 1500 events per
second on `BAT1` of a Lenovo LOQ (`ideapad-laptop` battery extension). So a storm can start
elsewhere too. Here the rule is what sustains it.

### Test 1 (I ran it): remove the rule and reload udev

```
sudo mv /etc/udev/rules.d/99-battery-limit.rules ~/99-battery-limit.rules.off
sudo udevadm control --reload
```

| Measurement | Before | After |
|---|---|---|
| `BAT0` kernel `change` events in 6 s | 1178 | 0 |
| `udev-worker` that was stuck | 80% of a core | gone |
| `upowerd` | 13 to 20% | 0% |
| `asusd` | 7 to 10% | 0% |
| `charge_control_end_threshold` | 85 | 85 (kept, with `asusd` as the only writer) |

This changed two things at once (the rule and a udev reload, which may recycle the workers), so it
did not isolate the cause. Test 2 does.

### Test 2 (I ran it): put the rule back, trigger one `change`, then remove it

A logger recorded every `BAT0` kernel `change` event while I ran:

```
sudo cp ~/99-battery-limit.rules.off /etc/udev/rules.d/99-battery-limit.rules
sudo udevadm control --reload
sudo udevadm trigger --action=change --subsystem-match=power_supply --sysname-match=BAT0
sleep 8; sudo rm /etc/udev/rules.d/99-battery-limit.rules && sudo udevadm control --reload
```

| Time (22:26) | `change` events per second |
|---|---|
| before the rule was installed | 0 |
| :10 (the trigger) | 107 |
| :11 to :17 | 195 to 197 every second |
| :18 (rule removed) | 98, then 0 |

1579 events in about 8.5 seconds, none before and none after. After removal: 0 events in 6 s,
`upowerd` and `asusd` at 0%, threshold still 85.

### Test 3 (I ran it): is `asusd` needed, and is an add-only rule safe?

Script: [battery-uevent-loop-test.sh](../scripts/battery-loop/battery-uevent-loop-test.sh) (`sudo
bash`, about 1 minute, removes its test rule and restarts `asusd` on exit). Each test counts
`power_supply` kernel events for 7 s around one `udevadm trigger` on `BAT0`. Run 2026-11-27 22:35,
kernel `7.2.15-4-omarchy`.

| Test | Rule | `asusd` | Trigger | Events in 7 s |
|---|---|---|---|---|
| T0 | none | running | `change` | 1 |
| T1 | the old `add\|change` rule | **stopped** | `change` | **1176** |
| T2 | add-only | running | `change` | 1 |
| T3 | add-only | running | `add` | 2 |

- **`asusd` is not needed for the loop.** T1 looped at the same rate with `asusd` stopped. So this
  is not an `asusd` bug and not an `asusctl` report.
- **An add-only rule does not loop.** T2 and T3 stayed at the baseline. T3 had one event more than
  T0, which fits a single write producing about one extra `change`; with `change` in the rule that
  one extra event is what feeds the next write.
- Still not identified: what emits that extra `change` (not `asus-wmi`; likely firmware through the
  ACPI battery driver). `upowerd` was running in every test and was not stopped; it is read-only in
  normal operation, but its role is untested, so it is not ruled out as the re-emitter.
- Counting methods: Test 1 and Test 2 are hand counts from `udevadm monitor` that matched `change`
  lines only, so they never included the banner. Test 3 and `battery-soak.sh` count `^KERNEL\[`
  lines. The banner line the monitor prints, `KERNEL - the kernel uevent`, matched the earlier
  `^KERNEL` count and added 1 to every script count.
- After the test: no test rule left, `asusd` active, threshold 85.

The 85 limit had to survive a **suspend and resume** and a **reboot**; both were checked on
2026-11-28 (results under "Reboot and resume checks" below). The resume check has to
be the charging one: on AC with the battery at or above the limit,
`cat /sys/class/power_supply/BAT0/status` must read `Not charging`, because charging would continue
past 85 if the limit were lost. `charge_control_end_threshold` cannot fail that check: it returns the
driver's cached last write, not a firmware read. After a **reboot** the threshold file is valid,
because the driver resets it to 100 when the battery is added, so `85` proves `asusd` restored it.
And the original storm began at a resume, so a resume with no rule installed is the check that
nothing else starts one (systemd issue 21751 suggests it can). A 48-hour logger (`z13-uevent-soak`,
one sample every 5 minutes, notifies on a storm) is collecting that; its results go here. The first
samples in its log read `bat0_events_3s=1` because the script then counted the `udevadm monitor`
banner; in that log a reading of 1 means 0.

Set the limit with the tool that owns it: `asusctl battery limit 85` (stored in
`/etc/asusd/asusd.ron` as `charge_control_end_threshold`).

### Options that were considered

| | Change | Status |
|---|---|---|
| A | Delete the udev rule; `asusd` applies 85 | **Done 2026-11-27** (file moved to `~/99-battery-limit.rules.off`) |
| B | Keep the rule but only for `ACTION=="add"` | Not needed while `asusd` holds the limit; the fallback for a machine without `asusd` |
| C | Kernel or `asusctl` update and an upstream report | Not needed: the events stopped without the rule |
| D | Detection so a repeat is seen in minutes: a small check that warns on a hot long-running process or a kernel uevent rate of 50 per second or more; I run mine from private tooling | **Built.** The loop ran 27 hours unnoticed |
| E | A root watchdog that kills a hot `udev-worker` | Skipped: it hides the cause |

## Findings 3 to 5: decisions

### 3. Memory held by user programs (about 8.9 GB, near 0% CPU)

| Program | Measured | Notes |
|---|---|---|
| Chrome | 24 renderers, 5.2 GB | One renderer is 1.3 GB and 3 days old; most of the rest are 50 to 500 MB |
| coding-agent CLI sessions | 6 processes, 1.5 GB, plus one at 940 MB and a 65 MB worker daemon | Four idle `--resume` sessions at 176 to 235 MB each, up 3 days; two active ones at 390 to 410 MB |
| `quickshell` (Omarchy shell) | 620 MB | Up only 24 min, so it was restarted recently; check whether it grows |
| Slack | 8 processes, about 530 MB | Up 2 d 11 h |
| a terminal multiplexer | app 86 MB, 6 core processes | Holds the agent panes |

The gain is RAM headroom, not battery. The Z13 has 58 GB and about 21 GB free, so this is low
priority.

### 4. Small background services (all near 0% CPU): decisions 2026-11-27

I chose what to turn off after a dependency check (`pacman -Qi`, `lpstat`, my Z13 notes). The total
saving is small, about 50 MB of RAM and about 0% CPU; the point is fewer listeners and fewer things
to wonder about.

| Service | Measured | Decision |
|---|---|---|
| `print-applet` autostart | not running | Already off: `~/.config/autostart/print-applet.desktop` has `Hidden=true`. `lpstat` shows no printers. |
| `geoclue` demo agent | 3.7 MB | **Off.** `~/.config/autostart/geoclue-demo-agent.desktop` with `Hidden=true`, and the running `app-geoclue\x2ddemo\x2dagent@autostart.service` was stopped. The `geoclue` system service stays available on demand. Undo: delete that file. |
| `cupsd` | listens on `127.0.0.1:631` and `[::1]:631` only | **Off since 2026-11-28.** No printer is configured and no package requires `cups`. Ran `sudo systemctl disable --now cups.service cups.socket cups.path`; `systemctl is-active cups.service` says `inactive`. Undo: `sudo systemctl enable --now cups.socket cups.path`. |
| `passim` (`passimd`) | 6.5 MB | **Off since 2026-11-28.** It is the owner of the `0.0.0.0:27500/tcp` listener (below). Only `fwupd` uses it, and `fwupd` works without it. Ran `sudo systemctl mask --now passim.service`; `systemctl is-active passim.service` says `inactive`. Undo: `sudo systemctl unmask passim.service`. |
| `localsearch-3` | 14 MB, a file indexer | Kept. `nautilus` requires it for file search. |
| Evolution alarm notifier autostart | not measured | Kept (my choice). |
| `goa-daemon`, `evolution-source-registry`, `goa-identity-service` | about 35 MB | Kept: `gnome-control-center` requires GNOME online accounts, and the Google Calendar sync uses a Google account there. (The first audit said nothing used them; that was wrong.) |
| `avahi-daemon` | advertises `Z13P.local` on the LAN | Kept: `cups`, `geoclue`, `nss-mdns`, `pipewire-pulse` and others require it. |
| `bolt` | 4 MB | Kept: `gnome-control-center` requires it; it manages Thunderbolt and USB4 device authorization. |
| `voxtype` stack (daemon, `qs` OSD, audio bridge) | about 40 MB | Kept: I have a voxtype config for this machine. |
| `udiskie` | 17 MB | Kept: SD card automount. |

### 5. Checked and fine

- Power profile `balanced`, governor `powersave`, `amd_pstate` active.
- No containers (`docker.service` inactive); no stray LM Studio process.
- Only these timers: system timers snapper cleanup, shadow, plocate, man-db, tmpfiles, keyring
  sync; the user timer `omarchy-google-calendar-sync.timer` (every 5 minutes); and the transient
  `z13-uevent-soak.timer` (this audit's logger).
- Idle memory pressure: 14 GB used, 45 GB available.

### The listener on `0.0.0.0:27500`: resolved

`sudo ss -ltnp | grep 27500` (mine, 2026-11-27) showed `passimd`, pid 858216: the firmware
metadata sharing daemon (`passim`) listening on all interfaces. It is by design (it shares firmware
metadata with other machines on the LAN), not a leak. Masking `passim` (above) closes the port.
Checked 2026-11-28: `cups` and `passim` inactive, and `ss -ltn | grep 27500` prints nothing.
(`sshd` on `0.0.0.0:22` is expected.)

## Status at the end of 2026-11-27

| Item | State |
|---|---|
| Local LLM server on the Z13 | **Off** by decision (mobile machine). Nothing starts it at login; start it on demand with `lms server start` (the API listens on 127.0.0.1:1234) |
| Battery uevent loop | Cause found and removed: the old `99-battery-limit.rules`. `asusd` holds 85. Detail above and in [battery-threshold-uevent-loop.md](battery-threshold-uevent-loop.md) |
| Detection check | A small check warns on a hot long-running process or a kernel uevent rate of 50 per second or more; I run mine from private tooling |
| Soak logger | Running: user timer `z13-uevent-soak`, one sample per 5 minutes for 48 h (see below) |
| Findings 3 to 5 | Decided and applied: geoclue demo agent off (2026-11-27); `cups` disabled and `passim` masked (2026-11-28); the rest of the services kept. Memory (finding 3) not acted on |

## Still to do: resume and reboot checks (updated 2026-11-28, results in the next section)

These needed the machine used normally and rebooted; they were run on 2026-11-28.

1. **Resumes without the rule.** **Done 2026-11-28:** three resumes, the longest 10 h 45 min (next
   section). The check was: the original storm began at a resume, so suspend the Z13 a few times,
   at least one long (an hour or more), then run `bash scripts/battery-loop/battery-soak.sh report`.
   Clean means `STORM lines: 0`, a maximum of a few events per 3 s sample (0 is normal; plugging in
   AC adds a burst of its own, because every `power_supply` device is counted) and no sustained 30
   or more, and the thresholds seen all 85. The report only says clean for resumes that have a
   sample after them. The logger also sends a critical desktop notification if a storm appears.
2. **Charging stops at the limit after a resume.** **Done 2026-11-28:** `Not charging` after each of
   the three resumes. On AC with the battery at or above 85,
   `cat /sys/class/power_supply/BAT0/status` must read `Not charging`; charging would continue past
   85 if the limit were lost. Do not use `charge_control_end_threshold` here: it returns the
   driver's cached last write, so it cannot show that the limit survived the resume.
3. **Reboot.** **Done 2026-11-28 at 00:36:** all checks PASS (next section). A transient user timer
   does not survive a reboot. The checks were:
   - `cat /sys/class/power_supply/BAT0/charge_control_end_threshold` must show `85` with `asusd`
     as the only writer. This check is valid: the driver resets the limit to 100 when the battery
     is added, so `85` proves `asusd` restored it.
   - `ls /etc/udev/rules.d/` must not list `99-battery-limit.rules`, and neither
     `/etc/udev/rules.d/99-battery-limit-test.rules` nor
     `/run/udev/rules.d/99-battery-limit-test.rules` may exist (the test script writes its rule to
     `/run`, which a reboot clears).
   - Restart the logger: `bash scripts/battery-loop/battery-soak.sh start 48`. Its log continues.

   `bash scripts/battery-loop/battery-soak.sh postboot` runs the rule, threshold, `asusd`, uevent
   and process checks and then starts the logger; `--no-start` skips the restart and `--limit N`
   sets the expected limit.
4. **If a storm appears without the rule:** run
   `sudo systemctl restart systemd-udevd.service systemd-udevd-control.socket systemd-udevd-kernel.socket`
   and it ends for now. That is inferred from
   systemd issue 21751, where that restart cleared the storm; it was not measured on the Z13, where
   every stop here was rule removal plus reload. Then it is not the rule. Save the `STORM` lines,
   the kernel version, and the output of
   `timeout 6 udevadm monitor --kernel -s power_supply > /tmp/ev.txt; head -40 /tmp/ev.txt`, and
   reopen this audit (systemd issue 21751 is the closest known report).
5. **When Omarchy ships its charge limit.** **Open.** Upstream `omacom/omarchy` has
   `bin/omarchy-battery-limit` since PR #20379; it enables the limit through UPower, which makes
   `upowerd` a threshold writer. Enable it here when it arrives and re-run the trigger test from
   this audit to see whether UPower's writes can loop on the Z13.
6. **After the checks pass, delete the backup.** **Done 2026-11-28.** `~/99-battery-limit.rules.off`
   was the original rule, kept as a backup (it was moved with `sudo`) and owned by root;
   `sudo rm ~/99-battery-limit.rules.off` was run and the file is gone. `/etc/udev/rules.d` now
   holds only `60-omarchy-io-scheduler.rules` and `99-omarchy-asus-z13-touchpad.rules`.
7. **Remaining.** Two things: the decision on where to post the notes (the shareable doc's venues
   table lists the candidates; nothing is posted yet), and the re-test when Omarchy ships the
   `bin/omarchy-battery-limit` from PR #20379. Then stop the logger
   (`bash scripts/battery-loop/battery-soak.sh stop`) and mark this closed.

The soak logger was started by hand earlier in the session and restarted from this repo script at
23:05 on 2026-11-27 (`battery-soak.sh start 48`); the log continues.

## Reboot and resume checks (2026-11-28)

Same machine: `GZ302EA`, BIOS `GZ302EA.314`, Omarchy 4.5.0-3, kernel `7.2.15-4-omarchy`, on AC
with the battery at 85%. All numbers are measured.

### Reboot at 00:36

`bash scripts/battery-loop/battery-soak.sh postboot` reported every check PASS:

| Check | Result |
|---|---|
| Battery-limit rule in `/etc/udev/rules.d` or `/run/udev/rules.d` | none |
| `BAT0/charge_control_end_threshold` | `85`, with `asusd` as the only writer. The driver resets the value to 100 when the battery is added at boot, so `85` shows `asusd` restored it |
| `BAT0/status` on AC at 85% | `Not charging`, so charging stopped at the limit |
| `asusd` | active |
| `power_supply` kernel events in 3 s | 0 |
| Busiest process | 12.9%, a normal one |
| `upowerd` and `asusd` CPU | 0.2% each |

### Resumes without the rule

Three `s2idle` suspends, no battery-limit rule installed:

| Suspend | Duration | After the resume |
|---|---|---|
| 2026-11-27 23:29:27 to 23:30:20 | 53 s | 0 `BAT0` kernel events in 6 s, limit 85, status `Not charging`, `upowerd` and `asusd` 0% CPU over 5 s, no `udev-worker` process |
| 2026-11-27 23:31:23 to 23:34:36 | 3 min 13 s | the same |
| 2026-11-28 00:54:12 to 11:39:55 | 10 h 45 min | the same |

`bash scripts/battery-loop/battery-soak.sh report` after the overnight suspend: 31 samples, a
maximum of 1 event in a 3 s sample, 0 `STORM` lines, limit 85 in all 31 samples, and
`RESULT: clean across 3 resume(s)`. The maximum of 1 is the monitor banner, not an event: the first
6 samples were written before the script stopped counting that line, so in those samples a reading
of 1 means 0 (the same offset the test table notes above).

The 10 h 45 min suspend is the comparable case: the 27-hour storm followed a 1.5 h suspend, and the
older stuck worker followed a 16 h one. What this does not show: it is one machine and one long
suspend. The logger keeps running for its 48 h.

## Not done

- Nothing about `cups` or `passim` is pending: both were disabled or masked by hand on 2026-11-28,
  `systemctl is-active cups.service passim.service` says `inactive` for both, and
  `ss -ltn | grep 27500` prints nothing.
- Finding 3 (memory held by Chrome, the coding-agent sessions, `quickshell`, Slack, the terminal
  multiplexer) is not acted on.
- The changes on the Z13 were: the udev rule moved away and its backup deleted (by me), the local
  LLM server stopped, the geoclue demo agent autostart hidden, `cups` disabled and `passim` masked.
  Nothing else was changed.
- Which component emits the extra `change` event that feeds the loop is still unidentified (see
  [battery-threshold-uevent-loop.md](battery-threshold-uevent-loop.md)).
- Nothing has been posted anywhere yet; where to post is item 7 above.
- Battery draw on battery power was not measured (the machine was on AC), so the watt saving is an
  estimate from CPU time: about one core of mostly kernel time.
