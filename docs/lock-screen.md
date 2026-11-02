# The lock screen on a detachable

Written 2026-11-01. The one place a tablet with its keyboard off cannot be used.

## The problem

With the keyboard detached, an idle lock or a suspend leaves a password field that nothing can type
into. The session lock hides every layer surface, so a normal on-screen keyboard cannot appear over it.
The Z13 has no fingerprint reader (`omarchy-hw-fingerprint` says none, and no matching USB device
exists, `[tested here]`). The only way in today is to reattach the keyboard, type, and detach again.

Other people hit the same thing: discussion [#9600](https://github.com/omacom/omarchy/discussions/9600)
(lanwen, Surface Pro, 2026-09-01) and [#14341](https://github.com/omacom/omarchy/discussions/14341)
(Alan Roman, the same Z13, 2026-10-06). Both had no reply when I checked on 2026-11-01.

## What Omarchy's lock plugin looks like (`[source]`, 4.0.6 on this machine)

- Plugin id `omarchy.lock`, files `LockView.qml`, `Service.qml`, `manifest.json`. Manifest description:
  "separate password and fingerprint PAM flows".
- Two PAM contexts today, `passwordPam` and `fingerprintPam`. A PIN or face method would be a third.
- The interface a lock keyboard needs is already there. ragtop's `LockKeyboard.qml` reads seven properties
  of the lock view: `passwordText`, `passwordTextEdited`, `submitPassword`, `authenticatingPassword`,
  `inputEnabled`, `fieldHeight` and `wakeRequested`. All seven are in `LockView.qml` and `Service.qml` on
  4.0.6, and in a copy of 4.5.0-rc1 that ragtop keeps as a test fixture. `[tested here]` for 4.0.6.
- The lock plugin changes a lot between versions. In ragtop's fixtures, `lock/Service.qml` is 551 lines in
  4.0.4 and 982 lines in 4.5.0-rc1. Any patch to it needs a check after each Omarchy update.

## Who has the lock screen covered

| | Lock screen typing | How |
|---|---|---|
| Native route ([minimal.md](minimal.md)) | No | Nothing reaches the session lock |
| Alan's Z13 plugin | No | Documented limit, reattach to unlock |
| yeutterg set | Number pad only | A replacement lock screen plugin with a 4 to 6 digit PIN |
| ragtop | Yes, full keyboard | Copies Omarchy's lock plugin into user config and patches it. Opt-in. |

## Options for getting typing on the lock screen

| Option | What | Effort (my estimate) | Safety |
|---|---|---|---|
| 1. Use ragtop as is | Pin to commit `1ffb2cc`, install in stages | Small, plus about 11,000 unread lines | Medium. Brings hooks, Python helpers, a root rule that may not match |
| 2. Full hardened fork | Review all 17,600 lines, remove extras, merge upstream | Weeks. Review dominates. | Highest, but you own a large project |
| 3. Take only the lock keyboard | Copy `LockKeyboard.qml` (MIT, keep the notice), write a short lock patch (100 to 150 lines, a guess), keep everything else native | A few days. Hardware testing is the long part. | High. About 900 lines to review. No root rule, no Python watcher, no network. |
| 4. Write one from scratch | A new lock keyboard in QML | Not worth it | |
| 5. Upstream | Ask Omarchy to add a keyboard or a hook to `omarchy.lock` | Slow, not in our hands | Best long term |

Why option 3 is the smallest useful piece of ragtop:

- `LockKeyboard.qml` is 781 lines, plus a small icon file and `KeyContrast.js`.
- It needs only the seven lock view properties. Without ragtop's service it falls back to a US layout.
- Our Hyprland switch bind can write the mode file it reads, so no root rule and no Python watcher.
- It would not bring ragtop's boot and update hooks, or any network access.

What option 3 costs:

- The lock screen is the most sensitive screen. A bug could lock the user out. Rescue is the text
  screen (`Ctrl+Alt+F3`), and Omarchy has a stranded-lock helper (`omarchy-hyprland-session-lock-stranded`).
- The patch needs a check after every Omarchy update. ragtop wrote about 400 lines of hook code for this.
- We would own the maintenance. The licence is MIT, so copying is allowed if the copyright notice stays.
  The word list data in ragtop is CC BY-SA 4.0, which a lock-only copy would not include.

Alan Roman, author of #14341 and of the Z13 tablet plugin, replied on #17222 on 2026-11-01. He prefers
shape (a), with `omarchy.lock` drawing the keyboard itself, because password input then stays in
Omarchy's lock code and keeps up with its updates instead of being passed to a plugin. His plugin
deliberately stays out of authentication, and he looked at a cloned lock screen and rejected it for the
same reasons. That is a second voice against the clone route (options 1 to 3), from someone with the
same hardware.

Chosen so far: option 5 first (the upstream post, see [upstream.md](upstream.md)). Option 3 is the
fallback if upstream stays silent. The owner decides on 2026-11-15. Not started.

## The login ladder, and what other systems do

Windows Hello and phone lock screens use the same order: biometrics first, then a PIN, then the
password. Omarchy has fingerprint and password today. A PIN and face login would add the middle and the
front of that ladder. See [face-unlock.md](face-unlock.md).

A PIN has a real security cost. Once the disk is open, the lock screen is the only barrier. So a PIN
needs rate limiting (`pam_faillock` or the five wrong tries then password pattern one community plugin
uses) and a fall back to the password. The post to Omarchy deliberately does not design this.

## Not checked

- Whether `omarchy.lock` in 4.5 final keeps the same seven properties.
- The lock keyboard on a live lock screen. Nothing was run.
- How `LockKeyboard.qml` behaves in full, beyond its key handling (read in part).
