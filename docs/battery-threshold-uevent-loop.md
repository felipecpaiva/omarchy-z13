# A battery-limit udev rule can start a 200 events per second loop (ASUS ROG Flow Z13, Omarchy)

Written to be copied into an issue or a forum post. Measured 2026-11-27 on my Z13; the
boundaries of what is and is not proven are stated below. Full audit:
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
- **That nothing else starts a storm after a resume** once the rule is gone. A logger collects
  resumes ([battery-soak.sh](../scripts/battery-loop/battery-soak.sh): `start`, then `report`; the
  audit doc lists the reboot steps); until a few long resumes pass clean, treat this as open.

## Fix

1. Move that rule out of the way: rename the file that diagnosis step 2 found, for example
   `sudo mv /etc/udev/rules.d/99-battery-limit.rules ~/99-battery-limit.rules.off`, then run
   `sudo udevadm control --reload`. Keep the file until the checks pass; it is the backup.
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

## Where this could be shared (nothing has been posted)

| Place | What to post | Condition |
|---|---|---|
| Omarchy discussions or issues (`omacom/omarchy`) | The symptom, the 30 second diagnosis, the fix. A short note, since Omarchy is not the cause | After the resume checks pass |
| ArchWiki, Laptop/ASUS, "udev rule" section | A note that a rule reacting to `change` can loop, with my add-only `BAT0` rule (tested here) as the safe one; not the wiki's `asus-nb-wmi` rule, which was not tested | Ready; one machine only |
| Kernel `platform-driver-x86` / ACPI battery, or ASUS firmware contacts | The 7-second tests with event counts: a threshold write seems to produce one extra `change`. Not `asusd` | If someone can show what emits it (a trace needs root) |
