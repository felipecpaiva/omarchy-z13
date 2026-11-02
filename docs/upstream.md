# Working with Omarchy upstream

Written 2026-11-01. How proposals and fixes reach Omarchy, what has been sent, and what comes next.

## How Omarchy takes changes (`[source]`, read 2026-11-01)

- **Suggestions go to Discussions.** There is no feature issue template. `.github/ISSUE_TEMPLATE/config.yml`
  turns off blank issues and sends suggestions to the Suggestions discussion category. Issues are for
  verified bugs only (`bug.yml`).
- **A review bot sorts every PR.** omarchybot, a collaborator account, classifies each pull request with
  two models working separately. Its wording from PR #9160: a `compatibility` change is a hardware fix,
  "verified and reviewed like a bug", and an `enhancement` is a feature, "worked once the maintainer asks
  for it." When the two models disagree, the PR waits for a human.
- **Time to merge, sample of 10 recent merges.** Small separate PRs from the community merged in 5 to 23
  days, one in 63. Maintainer PRs and bot PRs merged the same day. Large mixed PRs, such as #9160 (open
  since 2026-08-30, 16 comments), sit for months.
- **Contribution rules live in `AGENTS.md`** and `agents/skills/`. For the Quickshell desktop the skill is
  `agents/skills/shell-dev.md`. Style notes: bash 5 conditionals, `#!/bin/bash`, commands start with
  `omarchy-`.
- **Hardware support has a pattern.** Detection predicates in `bin/omarchy-hw-*`, setup under
  `install/hardware/<vendor>/`. A device is added only when it needs its own code.
- **Silence is normal.** Discussions often get no reply. A PR gets read by the bot and by community
  reviewers. The rotation PR #13531 had three community reviews and no maintainer approval.

What this means for us: ask in a Discussion first, keep each PR small and separate, and frame hardware
lockouts as fixes where that is honest.

## What we sent

| Date | Where | What | State |
|---|---|---|---|
| 2026-11-01 | [omacom/omarchy#17222](https://github.com/omacom/omarchy/discussions/17222) (Suggestions) | Lock screen keyboard for detachables, then a PIN. Consolidates #9600 and #14341. Offers shape (a) the lock plugin draws it or (b) the lock plugin exposes a hook. Offers to build it after 4.5. | 1 reply on 2026-11-01 from Alan Roman (author of #14341, a second Z13 owner): plus one, prefers (a), leaves the PIN to the maintainers. No maintainer reply yet. |
| 2026-11-02 | Reply on [#17222](https://github.com/omacom/omarchy/discussions/17222#discussioncomment-19344148) under Alan Roman's comment | Thanks, the README correction applied, agreement on shape (a), and a Z13 data point: the tablet switch fires on detach and attach, and his USB detection works too. States we will wait for a maintainer before building. | Posted |
| 2026-11-02 | [sambuaneesh/omarchy-hyprmouse#1](https://github.com/sambuaneesh/omarchy-hyprmouse/issues/1) (issue) | Asks if the author would take support for hardware buttons that arrive as keys, like the Z13 side button (`XF86Launch3`). Suggests a learn step with temporary Hyprland binds, so no root and no udev rule. Offers a PR, Z13 first. | No reply yet |
| 2026-11-01 | Comments on [#9600](https://github.com/omacom/omarchy/discussions/9600) and [#14341](https://github.com/omacom/omarchy/discussions/14341) | One line pointers to #17222 | Posted |

The text as posted is in [upstream-proposal.md](upstream-proposal.md).

## What comes next

| When | What |
|---|---|
| 2026-11-08 and 2026-11-15 | Look at #17222 and hyprmouse#1 for maintainer or author replies. We replied to Alan on 2026-11-02 and are waiting. |
| 2026-11-15 | Owner decides whether to build the lock keyboard without a maintainer green light. If yes, the work branch lives in a separate checkout of Omarchy and not inside this repo. |
| Waiting | A reply on [omarchy-hyprmouse#1](https://github.com/sambuaneesh/omarchy-hyprmouse/issues/1). If the author declines, build the small menu mapper ([side-button.md](side-button.md), option 1). If yes, open a PR to hyprmouse, Z13 first. |
| Any time, needs the owner's yes | A comment on [#15977](https://github.com/omacom/omarchy/discussions/15977) linking #17222. The author asks for "a hook for extra login methods in the lock screen", the same hook as shape (b). |
| After a trial | A Z13 hardware report on Alan's plugin repo, with the suspend test. |
| After a trial | A Z13 test report on PR [#13531](https://github.com/omacom/omarchy/pull/13531) or [#7493](https://github.com/omacom/omarchy/pull/7493) (rotation). The Z13 has a USB detach keyboard and a switch that works, a useful case. |
| After a trial | A comment on #9029 and PR [#9757](https://github.com/omacom/omarchy/pull/9757) with a Z13 and `wvkbd` test. |
| Idea | A request to Alan's plugin for a setting that starts it locked, or that separates rotation from detaching the keyboard. |

## Threads to watch

| Where | What | State on 2026-11-01 |
|---|---|---|
| Discussions #9600, #14341 | Lock screen on-screen keyboard | No replies on either. Alan Roman, author of #14341, answered on #17222 instead. |
| Discussion #15977 | omaFace and a hook for extra login methods | 1 comment |
| Discussion #4982 | Facial login | 8 comments, competing PRs |
| Discussion #14029 | TPM-backed passkeys | 0 comments |
| Issue #8641 | Dell XPS 14 IR camera, no driver | Open |
| PRs #13531, #7493 | Accelerometer rotation with a lock | Open, overlap |
| PR #9757 and issues #9029, #9756 | Keyboards reaching the menu and bar panels | Open |
| PR #9160 | GPD Pocket 4 orientation (ekollof) | Open, bot models disagree on its type |
| Discussion #10028 | `omarchy-osk` by ekollof, a keyboard and touch plugin | Exists. Not evaluated. |
| Discussion #12467 | Rotation, the author asked first and got no reply | 0 comments |

## Not checked

- Whether maintainers read #17222.
- Omarchy 4.5 final's release date.
- `ekollof/omarchy-osk`, a touch and keyboard plugin for Hyprland. It is the one community keyboard not
  yet examined.
