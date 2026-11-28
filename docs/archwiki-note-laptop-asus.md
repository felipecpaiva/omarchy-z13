# ArchWiki note for Laptop/ASUS: drafted, not submitted

The text is ready. It is not on the wiki. My new ArchWiki account could not edit the page on 2026-11-28, and I left it for another day.

This file keeps the draft, the evidence behind each sentence and what I checked about the block, so I can pick it up cold. The loop it describes is in [battery-threshold-uevent-loop.md](battery-threshold-uevent-loop.md).

## Status (2026-11-28)

- Not submitted. Nothing is on the wiki.
- The account exists and I was logged in. I did not capture the exact message the page gave me, because I was on another machine when I tried.
- What I checked on the live wiki through its API:
  - `Laptop/ASUS` has no page protection.
  - The default `user` group has the `edit` and `createpage` rights.
  - The `autoconfirmed` group (20 edits and 3 days) only matters for semi-protected pages, and this page is not one.
- So the account restriction should not be the reason. I do not know what is. The cause is open.

### What to look at when I try again

| What the page shows | Guess at the cause | What to try |
|---|---|---|
| A "View source" tab, no "Edit source" | Not logged in on that browser, or another language version of the page | Log in again, open https://wiki.archlinux.org/title/Laptop/ASUS?action=edit |
| An error after Save or Show preview that mentions a filter, spam or an external link | A spam or abuse filter on new accounts and external links. This is a guess, I did not see the filter | Save without the second link first, keeping only the Omarchy issue link, then add the other later |
| A CAPTCHA | Normal for a new account | Finish it and save again |
| "Confirm your email address" | The account needs a confirmed email | Click the link in the wiki's message |
| A block or a rate limit message | The IP or the account was flagged | Wait, then contact the [ArchWiki Maintenance Team](https://wiki.archlinux.org/title/ArchWiki:Maintenance_Team) |

If edits stay blocked, the same text can go on the page's Discussion tab (`Talk:Laptop/ASUS`) as a suggestion. I did not check what the maintainers prefer for that.

I want the exact error text before I guess again. Copy it into this file when I have it.

## What I would post

Page: Laptop/ASUS. Section: "udev rule", under "Battery charge threshold". The text goes after the existing rule.

The wiki writes in an impersonal voice, so this is not in first person. The first-person version is my comment on [omacom/omarchy#20162](https://github.com/omacom/omarchy/issues/20162#issuecomment-7236466497).

Edit summary:

```
Laptop/ASUS: a udev rule that writes charge_control_end_threshold on change events can loop, add a guarded form
```

Text to add, in wiki markup:

```
{{Warning|A rule that writes {{ic|charge_control_end_threshold}} on every {{ic|change}} event can loop. With {{ic|1=ACTION=="add{{!}}change"}} and an unconditional write, an ASUS ROG Flow Z13 emitted about 196 {{ic|change}} uevents per second for 27 hours, and a MacBookAir5,2 100 to 250 per second ([https://github.com/omacom/omarchy/issues/20162 Omarchy issue 20162], 2026-11-26). {{ic|udev-worker}}, {{ic|upowerd}} and {{ic|asusd}} used about one CPU core together. Count the events with {{ic|1=timeout 6 udevadm monitor --kernel -s power_supply > /tmp/ev.txt; grep -c '^KERNEL\[' /tmp/ev.txt}}. A few is normal, hundreds is a loop. Measurements and test scripts: [https://github.com/felipecpaiva/omarchy-z13/blob/main/docs/battery-threshold-uevent-loop.md].}}

To apply the limit again after a change event, for example after [[Power management/Suspend and hibernate|hibernation]] resets it, write only when the value differs:

{{hc|/etc/udev/rules.d/99-battery-limit.rules|2=
ACTION=="add{{!}}change", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}!="80", ATTR{charge_control_end_threshold}="80"
}}

The cause of the extra event is not known.
```

Markup note, not for the wiki. Inside a template a literal pipe has to be written `{{!}}`, so both examples use it. On disk the rule has a plain pipe. In the preview, both rule blocks must show a plain `|`.

## What each sentence rests on

- **196 events per second for 27 hours** on the Z13: measured on 2026-11-27, 1178 events in 6 s. The storm began at a resume on 2026-11-26 at 17:27 and I stopped it on 2026-11-27 around 22:30. The machine is a GZ302EA on Omarchy 4.5.0-3, kernel 7.2.15-4-omarchy.
- **MacBookAir5,2, 100 to 250 per second**: that user's report in omacom/omarchy#20162 (opened 2026-11-25, closed 2026-11-26). I did not reproduce it.
- **About one CPU core together**: measured on the Z13. `udev-worker` 80%, `upowerd` 13 to 20%, `asusd` 7 to 10%. The MacBook report had `upowerd` and `udev-worker` at 50 to 90% each.
- **The guarded rule**: measured on the Z13 with a limit of 85. 1 event in 7 s when the value already matched, 2 when it had to write once from 80, no storm. One run, one machine. The example in the text uses 80 to match the page's own examples, and I did not run it with 80. The Omarchy reporter used the same `!=` guard with 80 and saw 0 events per second.
- **Hibernation resets the limit**: the page's own "Persist after hibernation" section says so. I did not test hibernation.
- **The page's current rule** (`ACTION=="add"`, `KERNEL=="asus-nb-wmi"`, `RUN+=`) cannot react to `change` events. I did not test it. I tested a different add-only rule (`KERNEL=="BAT0"` with `ATTR{}`): 1 and 2 events.
- **"The cause of the extra event is not known"**: the kernel's `asus-wmi.c` threshold store function does not call `power_supply_changed()` (I read it on 2026-11-27 against torvalds master). Firmware through the ACPI battery driver is my guess. The MacBook uses the `sbs` driver, so the mechanism may differ.

## Weak spots

- Both citations are weak. The first is a closed issue from a third party. The second is my own write-up, a self-published source. An editor can ask for a stronger one.
- The MacBook number is not mine.
- One machine, one run for the guard.

## When I submit

1. Preview, and check the two rule blocks show a plain pipe.
2. Keep it to this one edit, with the summary above.
3. Watch the page afterwards for a revert or a talk page note.
4. Update this file: submitted on what date, with the diff link, and what the editors said.
