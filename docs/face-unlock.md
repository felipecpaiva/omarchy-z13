# Face login (Windows Hello style) on Omarchy and the Z13

Written 2026-11-01. Short answer: Omarchy does not support it out of the box. The Z13's camera is
visible to Linux. Nothing has been tried.

## Omarchy today (4.0.6, `[tested here]`)

- Setup scripts exist for fingerprint (`omarchy-setup-security-fingerprint`) and FIDO2
  (`omarchy-setup-security-fido2`). No face script exists.
- A search of `/usr/share/omarchy` for `howdy`, `face auth`, `face unlock` and `windows hello` found
  nothing.
- The lock plugin has two separate PAM flows, password and fingerprint. A face method would be a third.

## What the community has built (`[source]`, threads read 2026-11-01)

| Where | What |
|---|---|
| Discussion [#4982](https://github.com/omacom/omarchy/discussions/4982), opened 2026-03-11 | Facial login request. 8 comments, no maintainer reply seen. Two competing PR lines: #5212, and #6863 followed by #7040 (a prototype using the `facelock` PAM module). |
| [tyvsmith/facelock](https://github.com/tyvsmith/facelock) | A PAM module in the style of fprint, reported to work with Windows Hello cameras. |
| Discussion [#15977](https://github.com/omacom/omarchy/discussions/15977), 2026-10-19 | omaFace by L0adn9: IR cameras first, one `auth sufficient pam_exec.so` line above the password in sudo, polkit and sddm, the password always still works, scanner socket-activated and sandboxed, offline. Also asks Omarchy for a hook for extra login methods in the lock screen. |
| [tslove923/omarchy-howdy-face-unlock](https://github.com/tslove923/omarchy-howdy-face-unlock) | A Howdy based plugin that fires on wake. |
| [0ncoming-Storm/omarchy-storm-polkit](https://github.com/0ncoming-Storm/omarchy-storm-polkit) | Lock screen and polkit plugins, need `facelock` configured by hand. |
| Discussions #3251, #700 | Older suggestions for face recognition and for Howdy as an alternative to fingerprint. |
| Discussion [#14029](https://github.com/omacom/omarchy/discussions/14029) | TPM-backed platform passkeys. Related idea of a platform authenticator. |

## Howdy

[boltgolt/howdy](https://github.com/boltgolt/howdy) is the best known one. Last push 2025-07-29, last
release v2.6.1 on 2020-09-02, and its README asks for a maintainer. Its own security note says it is "in
no way as secure as a password and will never be", that a similar looking person or a well printed
photo could be enough, and "DO NOT USE HOWDY AS THE SOLE AUTHENTICATION METHOD FOR YOUR SYSTEM."

## The Z13 camera (`[tested here]`)

- One USB device, `636e:0bda` `ASUS 5M webcam`, exposes four video nodes.
- `/dev/video0` and `/dev/video1` are the RGB camera (MJPG and YUYV).
- `/dev/video2` and `/dev/video3` are named `ASUS IR camera`, and video2 offers 8-bit `GREY`, the kind of
  format an IR camera gives.
- ASUS lists a 5MP IR camera for Windows Hello on the model
  ([ROG page](https://rog.asus.com/de/laptops/rog-flow/ROG-Flow-Z13-2025/wtb), `[snippet]`).
- The AMD camera driver (ISP4) trouble in the [setup notes](https://dev.to/ankk98/asus-rog-flow-z13-2025-linux-setup-notes-1k35)
  is about the rear sensor. This camera is USB, so I expect it is independent. `[untested]`

Contrast: on the Dell XPS 14 (Panther Lake) the Windows Hello IR camera has no Linux driver at all
(issue [#8641](https://github.com/omacom/omarchy/issues/8641)). The Z13's IR camera is at least present
as a standard USB video device.

Not tested:

- Whether the infrared emitter turns on. Some cameras need a helper such as `linux-enable-ir-emitter`.
- Whether `facelock`, omaFace or Howdy recognises a face with this camera.
- Latency and reliability.

## Security notes

- Face login is a convenience, not a replacement for the password. The password should always remain.
- An IR camera is harder to fool than an RGB webcam. omaFace says so in its own post.
- Any PAM face method used for sudo or polkit needs care. omaFace waits for the user to choose face
  unlock on sudo and polkit so that looking at the screen never approves anything.
- On the Z13 the boot password is the disk password, asked before any face tool can run (see
  [research.md](research.md), section on the boot password).

## Decision

Queued behind the lock screen keyboard (decided 2026-11-01). When it starts:

1. Read the code of the chosen tool first, the same way ragtop was reviewed ([ragtop-review.md](ragtop-review.md)):
   root use, network, shell execution, and what touches the password.
2. Check that the IR emitter works and the camera is read as IR.
3. Trial with the password kept as the fallback.

The hook for extra login methods that omaFace's author asks for in #15977 is the same hook as shape (b)
in our own proposal, so one hook could serve a keyboard, a PIN and face login. A comment linking the two
is drafted in the tracker and not posted. Not started.
