# What was posted to Omarchy

Posted 2026-11-01 as [omacom/omarchy#17222](https://github.com/omacom/omarchy/discussions/17222)
(Suggestions). This file is the text exactly as posted, kept so the ask can be found and reused. How
Omarchy handles proposals, the follow up plan and the related threads are in [upstream.md](upstream.md).
The reasoning behind it is in [lock-screen.md](lock-screen.md).

**Title:** Let a detachable unlock without its keyboard: lock screen keyboard, then a PIN

On a detachable, the lock screen is the one place you cannot use the tablet without its keyboard.

I hit it on an ASUS ROG Flow Z13 (GZ302EA), Omarchy 4.0.6, Hyprland 0.56.2, kernel 7.2.8.
Keyboard off, idle lock kicks in, and nothing can type into the password field.
This model has no fingerprint reader, so that path does not help either.
Today the only way in is to put the keyboard back, type, and take it off again.

Two people asked for this already and I do not want to split the thread.
@lanwen in #9600 (2026-09-01) and @AlanRoman117 in #14341 (2026-10-06).
This post is the same ask with a concrete shape, and an offer to build it.

**Why the desktop fixes do not reach it**

The session lock hides every layer surface, so a normal on-screen keyboard cannot appear over it.
The desktop is already covered, three times over (a patched wvkbd in Alan's Z13 plugin, ragtop, and ekollof's omarchy-osk).
The lock screen is covered by one of them, and only by copying Omarchy's lock plugin into the user's
config and patching it.
That copy stops following Omarchy updates.
I think that is the reason it belongs upstream, but that is my opinion.

**What I am asking for**

Part one, the one that matters: an on-screen keyboard on the lock screen.
Two ways to do it, and you pick:

- (a) `omarchy.lock` draws a small keyboard itself.
- (b) `omarchy.lock` exposes a hook, and a plugin draws the keyboard.

For (b), the interface already exists in practice.
ragtop's lock keyboard reads seven things from the lock view: `passwordText`, `passwordTextEdited`,
`submitPassword`, `authenticatingPassword`, `inputEnabled`, `fieldHeight` and `wakeRequested`.
All seven are in `LockView.qml` and `Service.qml` on 4.0.6 (I checked), and in a copy of 4.5.0-rc1.

Part two, what makes part one usable: a PIN.
Nobody wants to type a long password on glass.
Phone lock screens and Windows Hello both work this way: biometrics first, then a PIN, then the password.
`omarchy.lock` already has two separate PAM flows, `passwordPam` and `fingerprintPam`.
A PIN would be a third of the same shape, module to be decided.
It has a real cost: once the disk is open, the lock screen is the only barrier, so a PIN needs rate
limiting and a fall back to the password after a few wrong tries.

I am not asking for face unlock, and I am not touching the disk unlock prompt.

**What I know, and what I do not**

On the Z13 the tablet switch fires on detach and again on attach.
A plain Hyprland bind on `switch:on:Asus WMI hotkeys` saw both (one test, 2026-11-01).
So "is the keyboard attached" is knowable with no plugin.
Notes and the Z13 research are here: https://github.com/felipecpaiva/omarchy-z13
I do not know if every Z13 firmware does this. One other project reports it does not.

**The offer**

If you want this, I will build it and open the PR.
First PR would be (a) or (b) only, no PIN, no rotation, so it stays small.
I would start after 4.5 ships, since the RC is in flight.

Do you want this upstream, and if yes, (a) or (b)?

## Pointer comment left on #9600 and #14341

> Consolidated the lock screen ask here with a concrete shape and an offer to build it:
> https://github.com/omacom/omarchy/discussions/17222. Adding the PIN tier and the list of properties a
> lock keyboard needs from the lock view.
