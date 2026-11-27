#!/usr/bin/env bash
# battery-soak.sh - a low-cost logger that proves a BAT0 uevent storm does not come back.
#
# Context: docs/battery-threshold-uevent-loop.md. A battery-limit udev rule looped at
# about 196 events per second after a resume and kept udev-worker, upowerd and asusd busy for 27
# hours. The rule is gone; this logger collects evidence across resumes and reboots.
#
# usage: bash scripts/battery-loop/battery-soak.sh start [HOURS]   (default 48; no sudo)
#        bash scripts/battery-loop/battery-soak.sh report          (summary of the log so far)
#        bash scripts/battery-loop/battery-soak.sh stop
#        bash scripts/battery-loop/battery-soak.sh sample          (one sample; what the timer runs)
#        bash scripts/battery-loop/battery-soak.sh postboot [--limit N] [--no-start]
#                                        (after a reboot: rule, threshold, asusd, uevent and
#                                         busiest-process checks; starts the logger for 48 h
#                                         unless --no-start; exit 0 only if every check passes)
#
# `start` creates a transient user timer, z13-uevent-soak, every 5 minutes. Each sample counts
# kernel uevents from every power_supply device for 3 seconds (5 devices here, so plugging in AC or
# a battery state change adds a burst of its own; the log field is still named bat0_events_3s).
# Clean is 0 to a few per sample with no sustained 30 or more; a storm is about 590. It records the
# charge limit, AC state and the busiest process, and sends a critical desktop notification if the
# count is 30 or more. The timer stops itself after HOURS. A transient timer does NOT survive a
# reboot: run `start` again after one (the log in ~/.local/share/z13-soak/soak.log continues).
#
# For tests every path can be overridden: SOAK_SYSFS (default /sys/class/power_supply) and
# SOAK_RULES_DIRS (default "/etc/udev/rules.d /run/udev/rules.d").
set -u
D="$HOME/.local/share/z13-soak"; LOG="$D/soak.log"; UNIT=z13-uevent-soak
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SYSFS="${SOAK_SYSFS:-/sys/class/power_supply}"
RULES_DIRS="${SOAK_RULES_DIRS:-/etc/udev/rules.d /run/udev/rules.d}"
mkdir -p "$D"

sample() {
  local end now t n thr ac top1
  end="$(cat "$D/end" 2>/dev/null || echo 0)"; now="$(date +%s)"
  if [ "$now" -gt "$end" ]; then systemctl --user stop "$UNIT.timer" 2>/dev/null; return 0; fi
  t="$(mktemp)"; timeout 3 udevadm monitor --kernel -s power_supply > "$t" 2>/dev/null
  n="$(grep -c '^KERNEL\[' "$t")"; rm -f "$t"
  thr="$(cat "$SYSFS/BAT0/charge_control_end_threshold" 2>/dev/null)"
  ac="$(cat "$SYSFS/AC0/online" 2>/dev/null)"
  top1="$(top -b -n 2 -d 1 -o %CPU -w 120 2>/dev/null | awk '/^top -/{i++} i==2 && $1 ~ /^[0-9]+$/ {print $9"% "$12; exit}')"
  echo "$(date '+%F %T') up=$(awk '{print int($1/60)}' /proc/uptime)m bat0_events_3s=$n threshold=$thr ac=$ac top=\"$top1\"" >> "$LOG"
  if [ "$n" -ge 30 ]; then
    echo "$(date '+%F %T') STORM: $n power_supply events in 3 s" >> "$LOG"
    notify-send -u critical "BAT0 uevent storm" "$n events in 3 s. Run: sudo systemctl restart systemd-udevd.service systemd-udevd-control.socket systemd-udevd-kernel.socket, then check /etc/udev/rules.d" 2>/dev/null
  fi
}

start() {
  local hours="${1:-48}" end
  case "$hours" in ''|*[!0-9]*) echo "HOURS must be a whole number of hours (digits only): '$hours'" >&2; return 2 ;; esac
  hours=$((10#$hours))
  if [ "$hours" -lt 1 ]; then echo "HOURS must be at least 1" >&2; return 2; fi
  end=$(( $(date +%s) + hours * 3600 ))
  echo "$end" > "$D/end"
  systemctl --user stop "$UNIT.timer" 2>/dev/null
  if ! systemd-run --user --unit="$UNIT" --on-calendar='*:0/5' --collect bash "$SELF" sample; then
    echo "systemd-run failed: the soak timer was not started (any previous one was stopped)" >&2
    return 1
  fi
  echo "soak logger running for ${hours}h; log: $LOG; summary: bash $SELF report"
}

report() {
  [ -s "$LOG" ] || { echo "no samples yet in $LOG"; return 0; }
  local first last last_epoch age resumes total no_later ts
  first="$(grep -m1 'bat0_events_3s=' "$LOG" | cut -c1-19)"; last="$(grep 'bat0_events_3s=' "$LOG" | tail -1 | cut -c1-19)"
  awk -v first="$first" -v last="$last" '
    /bat0_events_3s=/ { n++; for (i = 1; i <= NF; i++) { if ($i ~ /^bat0_events_3s=/) { v = substr($i, 16) + 0; if (v > max) max = v }
                                                          if ($i ~ /^threshold=/) { th[substr($i, 11)]++ } } }
    /STORM/ { storms++ }
    END { printf "samples: %d (%s to %s)\nmax power_supply events in a 3 s sample: %d (clean 0 to a few, no sustained 30 or more; storm about 590)\nSTORM lines: %d\nthresholds seen:", n, first, last, max, storms
          for (k in th) printf " %s x%d", k, th[k]; printf "\n" }' "$LOG"
  # A resume counts only if a sample followed it; otherwise a clean result would be about no data.
  resumes="$(journalctl --since "$first" -o short-iso --no-pager -q 2>/dev/null \
    | grep 'returned from sleep operation' | awk '{print $1}' \
    | sed -e 's/T/ /' -e 's/[+-][0-9][0-9]:[0-9][0-9]$//' -e 's/[+-][0-9][0-9][0-9][0-9]$//' | sort -u)"
  total=0; no_later=0
  while IFS= read -r ts; do
    [ -n "$ts" ] || continue
    total=$((total + 1))
    if ! awk -v ts="$ts" 'substr($0, 1, 19) > ts { found = 1; exit } END { exit !found }' "$LOG"; then
      no_later=$((no_later + 1))
    fi
  done <<EOF
$resumes
EOF
  echo "suspend/resume cycles in the journal since the first sample: $total (with no sample after: $no_later)"
  if last_epoch="$(date -d "$last" +%s 2>/dev/null)"; then
    age=$(( $(date +%s) - last_epoch ))
    if [ "$age" -gt 900 ]; then
      echo "WARNING: newest sample is $last, more than 15 minutes old; logger not running: run: bash $SELF start"
    fi
  fi
  if grep -q STORM "$LOG"; then echo "RESULT: a storm was seen, see the STORM lines in $LOG"
  elif [ "$total" -eq 0 ]; then echo "RESULT: no storm so far, but no resume yet; suspend the machine and look again"
  elif [ "$no_later" -gt 0 ]; then echo "RESULT: no storm so far, but $no_later of $total resume(s) have no sample after them; suspend, then check again"
  else echo "RESULT: clean across $total resume(s)"; fi
}

postboot() {
  local limit=85 do_start=1 fails=0 dir name hit thr status asd t n top1 pct
  while [ $# -gt 0 ]; do
    case "$1" in
      --limit) [ $# -ge 2 ] || { echo "--limit needs a number" >&2; return 2; }; limit="$2"; shift 2 ;;
      --no-start) do_start=0; shift ;;
      *) echo "postboot: unknown argument '$1'" >&2; return 2 ;;
    esac
  done
  case "$limit" in ''|*[!0-9]*) echo "--limit must be a whole number: '$limit'" >&2; return 2 ;; esac

  echo "postboot checks ($(date '+%F %T'))"

  # (a) no battery-limit rule left behind, including the test rule in /run
  hit=""
  for dir in $RULES_DIRS; do
    for name in 99-battery-limit.rules 99-battery-limit-test.rules; do
      [ -e "$dir/$name" ] && hit="$hit $dir/$name"
    done
  done
  if [ -n "$hit" ]; then
    echo "FAIL rules: still present:$hit"; fails=$((fails + 1))
  else
    echo "PASS rules: no battery-limit rule in $RULES_DIRS"
  fi

  # (b) the charge limit survived, and what the battery reports (info only)
  thr="$(cat "$SYSFS/BAT0/charge_control_end_threshold" 2>/dev/null)"
  if [ "$thr" = "$limit" ]; then
    echo "PASS threshold: BAT0/charge_control_end_threshold=$thr"
  else
    echo "FAIL threshold: BAT0/charge_control_end_threshold='${thr:-missing}', expected $limit (asusd should restore it; run: asusctl battery limit $limit)"
    fails=$((fails + 1))
  fi
  status="$(cat "$SYSFS/BAT0/status" 2>/dev/null)"
  echo "INFO status: BAT0/status=${status:-unknown} (Not charging expected on AC at or above the limit)"

  # (c) asusd active; not installed is info, not a failure
  asd="$(systemctl is-active asusd 2>/dev/null)"
  if [ "$asd" = active ]; then
    echo "PASS asusd: active"
  elif systemctl cat asusd.service >/dev/null 2>&1; then
    echo "FAIL asusd: '$asd' (run: sudo systemctl start asusd)"; fails=$((fails + 1))
  else
    echo "INFO asusd: not installed, skipped"
  fi

  # (d) no uevent storm: at most 5 power_supply kernel events in 3 s
  t="$(mktemp)"
  timeout 3 udevadm monitor --kernel -s power_supply > "$t" 2>/dev/null
  n="$(grep -c '^KERNEL\[' "$t" 2>/dev/null)"; n="${n:-0}"; rm -f "$t"
  if [ "$n" -le 5 ]; then
    echo "PASS uevents: $n power_supply kernel events in 3 s (at most 5)"
  else
    echo "FAIL uevents: $n power_supply kernel events in 3 s, a storm is running: run: sudo systemctl restart systemd-udevd.service systemd-udevd-control.socket systemd-udevd-kernel.socket, then check /etc/udev/rules.d"
    fails=$((fails + 1))
  fi

  # (e) busiest process over a 2 s top window: warn, do not fail
  top1="$(top -b -n 3 -d 1 -o %CPU -w 120 2>/dev/null | awk '/^top -/{i++} i==3 && $1 ~ /^[0-9]+$/ {print $9"% "$12; exit}')"
  pct="${top1%%%*}"; pct="${pct%%.*}"
  if [ -n "$pct" ] && [ "$pct" -ge 50 ] 2>/dev/null; then
    echo "WARN busiest process over 2 s: $top1 (50% or more; look for a hot long-running process)"
  else
    echo "INFO busiest process over 2 s: ${top1:-not measured}"
  fi

  # (f) restart the logger, unless asked not to
  if [ "$do_start" -eq 1 ]; then
    echo "INFO logger: starting for 48 h"
    if start 48; then echo "PASS logger: started (48 h)"; else echo "FAIL logger: start failed"; fails=$((fails + 1)); fi
  else
    echo "INFO logger: not started (--no-start)"
  fi

  if [ "$fails" -eq 0 ]; then
    echo "postboot: all checks pass"; return 0
  fi
  echo "postboot: $fails check(s) failed"; return 1
}

case "${1:-}" in
  start) shift; start "$@" ;;
  report) report ;;
  stop) systemctl --user stop "$UNIT.timer" 2>/dev/null; echo stopped ;;
  sample) sample ;;
  postboot) shift; postboot "$@" ;;
  -h|--help|'') sed -n '2,/^set -u$/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//' ;;
  *) echo "usage: bash $0 start [HOURS]|report|stop|sample|postboot [--limit N] [--no-start]" >&2; exit 2 ;;
esac
