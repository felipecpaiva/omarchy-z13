# Upstream report: power profile on the Z13

**Status: POSTED on 2026-11-10.** Comment on issue 7516: https://github.com/omacom/omarchy/issues/7516#issuecomment-6759541297 .
Discussion in Suggestions: https://github.com/omacom/omarchy/discussions/18332 . Two lines in the discussion were softened at
posting time to say only what I tested: the `asusctl` setting "should" stop the plug flash (not re-tested), and the speed under
`launch` was "in line with" `performance` in a short run. The text below is the draft; the posted discussion has those two edits.
Measurements and method are in [power-profile.md](power-profile.md).

## Where it goes, and why

- **A comment on issue 7516** ("Performance power profile runs fans at 100% while idle"). Same symptom on
  other hardware, still open, and pull request 16454 (unset plugged in profile becomes `balanced`) is the
  proposed fix. My numbers are a second hardware data point for it. No new issue, because 7516 already
  covers the symptom.
- **One post in Discussions, category Suggestions**, for the two small ideas that are not in 7516.

Before posting, re-read 7516, 16454 and the Omarchy version on `main`, so nothing in the text is stale.

## Comment for issue 7516

> Another data point, ASUS ROG Flow Z13 (GZ302EA, Ryzen AI Max+ 395), Omarchy 4.5.0-3, on AC.
>
> Same cause as above: the firmware `performance` mode on this model also runs the fans harder than
> `balanced`. At the same idle temperature (49 C), the CPU fan ran at 3983 RPM on `performance` and 2300 RPM
> on `power-saver`. It is not only G-Mode on Dell and Alienware.
>
> What it buys on this machine (one run per profile, plugged in):
>
> - CPU, 5 minutes all core: `performance` and `balanced` ran at the same speed (2.93 and 2.90 GHz) and the
>   same chip power (about 40 W). `performance` only added fan noise.
> - GPU, 4 minutes of a local LLM (llama.cpp on Vulkan): `performance` was 18% faster at reading prompts
>   (1314 against 1115 tokens/s), at 66 W against 48 W and 90 C against 77 C.
>
> So for this hardware `balanced` as the plugged in default (pull request 16454) costs nothing for normal
> work, and the GPU gap only shows on long heavy jobs. Raw numbers, scripts and caveats:
> https://github.com/felipecpaiva/omarchy-z13/blob/main/docs/power-profile.md

## Post for Discussions, Suggestions

**Title:** Hold the performance profile only while a command runs, and a small `asusd` note

> I measured the power profiles on an ASUS Z13 and found two things that might be worth a line in the
> manual or a small feature. Take or leave them.
>
> **1. `powerprofilesctl launch` already gives "performance on demand".**
> `powerprofilesctl launch -p performance -- <command>` holds `performance` only while the command runs, and
> the profile goes back by itself. On a `balanced` Z13 I ran a local LLM job under it: the profile was
> `performance` during the job and `balanced` after, and Omarchy's saved per source profile files were not
> touched. The speed matched `performance`. It could be one manual page, or a launcher or menu entry that
> wraps an app this way (a game, a build, a model server). No new daemon.
>
> **2. `asusd` has its own plugged in profile and acts before Omarchy.**
> On the Z13 the `asusd` default plugged in profile is `Performance`. On a plug event it moves the platform
> profile to `performance` for about 0.4 s, then Omarchy applies its saved value. The end result is right,
> but the fans and power limits get a short push first. `asusctl profile set --ac balanced` stops it. This
> may only be worth a note for ASUS users.
>
> I did not find anything that switches the profile by load or temperature, in Omarchy or in TLP,
> auto-cpufreq or power-profiles-daemon. On the Z13 `balanced` already speeds up the CPU when work needs it,
> so I did not build one. I would only build one if a real gap shows up.
>
> Data and method: https://github.com/felipecpaiva/omarchy-z13/blob/main/docs/power-profile.md . One
> machine, one run per profile, AC power only. I have not tested the plug time change after the `asusctl`
> setting, and I only measured chip power, not the whole machine.

## Checks before posting

- [x] The repo link works (the repo and `docs/power-profile.md` are pushed).
- [x] Re-read issue 7516, pull request 16454 and Discussions for anything new or a duplicate. Nothing new since 2026-11-01. Related but different: discussion 7830 (profile at boot) and 10859 (OSD for the ASUS power profile hotkey).
- [x] Re-tested the plug flash after `asusctl profile set --ac balanced` on 2026-11-10: no `performance` flash on replug (one run, plug in only). The posted text still says "should".
- [x] No machine name, address or private path in the text.
- [x] I read the wording and approved it.
