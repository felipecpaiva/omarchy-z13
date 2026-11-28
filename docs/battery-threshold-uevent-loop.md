# A battery-limit udev rule can start a 200 events per second loop (ASUS ROG Flow Z13, Omarchy)

Written to be copied into an issue or a forum post. Measured 2026-11-27 and 2026-11-28 on my Z13;
the boundaries of what is and is not proven are stated below. Full audit:
[power-audit-2026-11-27.md](power-audit-2026-11-27.md).

## Symptom

After a suspend and resume (not every time), the machine runs warm and the battery drains faster.
`top` shows three busy processes and nothing explains why:

- one `(udev-worker)` near 80% of a core, mostly kernel time, for hours or days;
- `upowerd` at 10 to 20% CPU;
- `asusd` at 5 to 10% CPU (on ASUS machines).

Together about one core. On my Z13 it ran for 27 hours until I stopped it by hand.

## 30 second diagnosis

```
# 1. How many battery change events per second? Normal: a few per minute. Storm: hundreds per second.
timeout 6 udevadm monitor --kernel -s power_supply > /tmp/ev.txt; grep -c change /tmp/ev.txt

# 2. Do you have a rule that writes a charge threshold on `change`?
grep -rn 'ATTR{charge_control' /etc/udev/rules.d/ /usr/lib/udev/rules.d/ 2>/dev/null
```

A `TEST=="charge_control_end_threshold"` line in the stock
`/usr/lib/udev/rules.d/60-upower-battery.rules` is harmless: it only loads hwdb data, it does not
write the threshold.

Redirect to a file instead of piping into `grep`: in my interactive shell the piped form printed
`Terminated` and lost the count. It was not reproducible in `bash`, `sh` or `zsh`; the redirect form
works everywhere, so it is the one documented here.

The storm in this report: 1178 events in 6 s, all for `BAT0`, about 196 per second.

## The rule that caused it

```
ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}="85"
```

It reacts to `change` events and writes to the same device.

## Confirmed on the Z13

| Test | Result |
|---|---|
| Old rule installed, one `udevadm trigger --action=change` on `BAT0` | 107 events in the first second, then 195 to 197 per second, until the rule was removed |
| Rule absent | 1 event in 7 s (the trigger itself) |
| Rule removed (during a storm that had run 27 hours) | 1178 events per 6 s to 0; `udev-worker`, `upowerd`, `asusd` from about one core to 0% |
| Old rule, `asusd` **stopped** | 1176 events in 7 s: the loop does not need `asusd` |
| Add-only rule, one `change` trigger | 1 event: no loop |
| Add-only rule, one `add` trigger | 2 events: no loop |
| Charge limit after removal | still 85, held by `asusd` (`asusctl battery limit 85`) |
| Reboot with the rule absent (2026-11-28 at 00:36) | 0 `power_supply` kernel events in 3 s; limit `85` restored by `asusd` (the driver resets it to 100 when the battery is added at boot); `BAT0` status `Not charging` on AC at 85%; `upowerd` and `asusd` at 0.2% CPU each |
| Three `s2idle` resumes without the rule: 53 s, 3 min 13 s, and 10 h 45 min (2026-11-27 and 2026-11-28) | after each: 0 `BAT0` kernel events in 6 s, limit 85, status `Not charging`, `upowerd` and `asusd` at 0% CPU over 5 s, no `udev-worker` process |
| Soak logger across those resumes (one sample per 5 minutes) | 31 samples, 0 `STORM` lines, limit 85 in all 31 samples, `RESULT: clean across 3 resume(s)`. The maximum of 1 event in a 3 s sample is not an event: the first 6 samples counted the `udevadm monitor` banner, and in that log a reading of 1 means 0 |

Rate and shape were the same in the 27-hour storm that began at a resume and in the 8-second test.
Hand counts in this table matched `change` lines only; the 7 s rows come from the test script, which
counts `^KERNEL\[` lines with the monitor banner excluded, so they differ by one from an unfiltered
count. Test script: [battery-uevent-loop-test.sh](../scripts/battery-loop/battery-uevent-loop-test.sh)
(needs `sudo`, about a minute, removes its test rule on exit).

## Not proven

- **Which component re-emits the event.** The kernel's `asus-wmi` driver does not:
  `charge_control_end_threshold_store` stores the value and returns, with no
  `power_supply_changed()`. It is not `asusd` (the loop ran with it stopped). The likely path is
  firmware (the embedded controller notifies the ACPI battery driver after the write). Not verified.
- **Why it began at a resume, and only at some resumes.** Presumably a `change` event at resume
  reaches the rule. Of the three resumes checked in the journal, two were followed by a stuck worker.
- **Other hardware.** Only the Z13 was tested. Similar storms are reported without any custom rule:
  [systemd issue 21751](https://github.com/systemd/systemd/issues/21751) is a `BAT0` storm on a
  Dell Latitude after wake, cleared by restarting `systemd-udevd.service` and both udevd sockets
  and fixed permanently by a BIOS update (which supports a firmware cause);
  [Launchpad LP #2169715](https://bugs.launchpad.net/bugs/2169715) reports 800 to 1500 events per
  second on `BAT1` of a Lenovo LOQ (`ideapad-laptop` battery extension). So a storm can start in
  other places. Here, the rule is what sustained it.
- **`upowerd` as the re-emitter.** It ran in all four tests and was not stopped (it is read-only in
  normal operation, but untested), so it is not ruled out as the component that re-emits.
- **An upstream Omarchy charge limit.** `omacom/omarchy`'s default branch has
  `bin/omarchy-battery-limit` since
  [PR #20379](https://github.com/omacom/omarchy/pull/20379), which sets the limit through UPower's
  `EnableChargeThreshold`. With that enabled, `upowerd` becomes a threshold writer; whether its
  writes can loop on the Z13 is untested (`ChargeThresholdEnabled` is false here today).
- **Other resume paths.** Three resumes without the rule, one of them 10 h 45 min, were clean, and
  the logger runs for 48 h. That is still one machine and one long suspend; treat other suspend
  lengths as untested (the two earlier stuck workers followed suspends of 1.5 h and 16 h).

## Independent report of the same pattern

[omacom/omarchy#20162](https://github.com/omacom/omarchy/issues/20162) (opened 2026-11-25, closed
2026-11-26) reports the same symptom on a MacBookAir5,2 with the same kernel `7.2.15-4-omarchy` and
Omarchy 4.5.0-3: `BAT0` `change` uevents at about 100 to 250 per second, `upowerd` and
`udev-worker` at 50 to 90% CPU, a hot chassis and faster drain. The reporter first suspected the
kernel `sbs` driver, then found a local rule of their own
(`ATTR{charge_control_end_threshold}="80"` on every `BAT0` `change`, added 2026-11-21) and fixed it
by guarding the write with `ATTR{charge_control_end_threshold}!="80"`: 0 events per second after
`udevadm control --reload`.

What that changes here:

- It is not specific to my machine and not specific to `asusd`. Their battery hangs off the kernel
  `sbs` driver; mine off the ACPI battery driver with the ASUS WMI hook. A rule that reacts to
  `change` was enough in both places.
- Their statement that the attribute write itself emits the `change` uevent is about their driver.
  On the Z13 my reading of `asus-wmi.c` `charge_control_end_threshold_store` found no
  `power_supply_changed()`, so which component re-emits the event here is still unproven (see
  "Not proven").
- Their `!=` guard is their fix; I have not tested it on the Z13 (see "Fix").
- Their diagnostic is the same one used below, and it carries extra evidence: they counted with
  `udevadm monitor --kernel`, stopping UPower did not stop the stream, and unloading the battery
  driver did (that removes `BAT0` as well, so it only bounds the source). That supports the
  30 second diagnosis.

## Fix

1. Move that rule out of the way: rename the file that diagnosis step 2 found, for example
   `sudo mv /etc/udev/rules.d/99-battery-limit.rules ~/99-battery-limit.rules.off`, then run
   `sudo udevadm control --reload`. Keep the file until the checks pass; it is the backup. On my
   machine the checks passed on 2026-11-28 and I deleted the backup then.
2. Set the limit with the tool that owns it. On ASUS with `asusd`: `asusctl battery limit 85`
   (stored in `/etc/asusd/asusd.ron`). Without `asusd`: TLP, or an add-only rule. The add-only rule
   I tested: `ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT0",
   ATTR{charge_control_end_threshold}="85"`. It differs from the
   [ArchWiki ASUS page](https://wiki.archlinux.org/title/Laptop/ASUS#udev_rule) rule
   (`ACTION=="add", KERNEL=="asus-nb-wmi", RUN+="..."`, a shell write); both are add-only, and only
   mine was tested (table above). The wiki also notes the limit resets after hibernation, not after
   suspend to RAM.
3. Verify: the count from the diagnosis is 0 to a handful (0 is normal; plugging in AC adds a burst,
   since every `power_supply` device is counted). After a suspend, on AC with the battery at or
   above your limit, `cat /sys/class/power_supply/BAT0/status` must read `Not charging`: charging
   would continue past the limit if it were lost. The threshold file cannot show this, because it
   returns the driver's cached last write. After a reboot it does: the driver resets the limit to
   100 when the battery is added, so `85` means `asusd` restored it.

Reported alternative to removing the rule, **not tested on the Z13**: keep a rule that reacts to
`change` but guard the write so it only runs when the value differs, for example
`ATTR{charge_control_end_threshold}!="85"`. The reporter of
[omacom/omarchy#20162](https://github.com/omacom/omarchy/issues/20162) fixed their loop that way
(0 `BAT0` uevents per second after `udevadm control --reload`). I did not test it here: removing the
rule was enough, and `asusd` already holds the limit. If nothing else sets the limit, this is the
form to try; if `asusd` or TLP owns it, remove the rule instead.

Restarting `systemd-udevd.service` and both udevd sockets ends a storm temporarily:
`sudo systemctl restart systemd-udevd.service systemd-udevd-control.socket systemd-udevd-kernel.socket`.
That is inferred from systemd issue 21751, where the same restart cleared the storm; it was not
measured on the Z13, where every stop was rule removal plus reload. The next `change` event that
reaches the rule starts it again.

## Environment

| | |
|---|---|
| Machine | ASUS ROG Flow Z13 (2025) `GZ302EA`, BIOS `GZ302EA.314` (2026-07-20) |
| OS | Omarchy 4.5.0 (Arch Linux), kernel `7.2.15-4-omarchy` |
| Software | systemd 262.1, upower 1.91.5, asusctl/asusd 6.5.0 |
| Omarchy involvement | none on 4.5.0: I added the rule by hand and Omarchy 4.5.0 ships no charge-limit rule or feature. Upstream's default branch has `bin/omarchy-battery-limit` since PR #20379, which uses UPower (see "Not proven") |

## Where this could be shared (nothing has been posted yet; waiting for my decision)

Order of preference: the closed issue first (same root cause, a second data point from other
hardware and a different battery driver, and the Z13 results in one place), then the wiki note once
the `!=` guard has been tested here. Not asus-linux (`asusd` is not required for the loop) and not
systemd (not their bug).

| Place | What to post | Status |
|---|---|---|
| Comment on [omacom/omarchy#20162](https://github.com/omacom/omarchy/issues/20162) | A short note: same root cause on the Z13, on different hardware and a different battery driver; removal and the add-only form tested, `asusd` not required; their `!=` guard untested here. It is one rule pattern, not an Omarchy problem | Not posted yet; waiting for the decision |
| [ArchWiki Laptop/ASUS](https://wiki.archlinux.org/title/Laptop/ASUS#udev_rule), "udev rule" section | A note that a rule that reacts to `change` and writes the threshold can loop, citing #20162 and my tests, with the add-only `BAT0` rule as the tested safe form | Not posted yet; waiting until the `!=` guard is tested on the Z13 |
| Kernel `platform-driver-x86` / ACPI battery, or ASUS firmware contacts | The 7-second tests with event counts: a threshold write seems to produce one extra `change`. Not `asusd` | Not posted yet; only if someone can trace what emits the extra event (needs root, not done here) |
| Not recommended: asus-linux, systemd | `asusd` is not required for the loop, and nothing here is a systemd bug | Dropped |

To re-test when Omarchy ships its own charge limit: upstream's default branch has
`bin/omarchy-battery-limit` (UPower based, [PR #20379](https://github.com/omacom/omarchy/pull/20379),
not in 4.5.0), which makes `upowerd` a threshold writer; the trigger test from the audit has to be
re-run against it.
