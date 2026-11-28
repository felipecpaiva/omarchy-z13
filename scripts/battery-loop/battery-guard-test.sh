#!/usr/bin/env bash
# Z13: does a guarded rule (write only when the value differs) avoid the BAT0 uevent loop?
# Run as: sudo bash scripts/battery-loop/battery-guard-test.sh   (about 40 s, leaves nothing installed)
#
# G0  guarded rule, threshold already 85, one `change` trigger      -> no write, so no loop expected
# G1  guarded rule, threshold set to 80 first, one `change` trigger -> one corrective write, then quiet
# The test rule lives in /run/udev/rules.d (volatile). On exit, also on Ctrl-C, the rule is removed,
# udev reloaded and the threshold put back to its starting value. asusd is not touched.
# Counts are `^KERNEL\[` lines of a redirect-to-file capture (the banner line is not counted).
# Results are also written to /tmp/z13-guard-test.result.
set -u
case "${1:-}" in
  -h|--help) sed -n '2,/^set -u$/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
[ "$(id -u)" -eq 0 ] || { echo "run with sudo: sudo bash $0" >&2; exit 2; }
RULE=/run/udev/rules.d/99-battery-limit-guard-test.rules
THR=/sys/class/power_supply/BAT0/charge_control_end_threshold
RES=/tmp/z13-guard-test.result
T="$(mktemp -d /tmp/z13-guard.XXXXXX)"
START="$(cat "$THR")"
: > "$RES"
say() { echo "$*" | tee -a "$RES"; }

cleanup() {
  rm -f "$RULE"
  udevadm control --reload
  [ -n "${START:-}" ] && echo "$START" > "$THR" 2>/dev/null
  rm -rf "$T"
  chmod 644 "$RES" 2>/dev/null
}
trap cleanup EXIT
trap 'exit 130' INT TERM

GUARDED='ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}!="85", ATTR{charge_control_end_threshold}="85"'

count_events() {  # seconds
  timeout "$1" udevadm monitor --kernel -s power_supply > "$T/ev.txt" 2>/dev/null
  grep -c '^KERNEL\[' "$T/ev.txt"
}

run_test() {  # label start-value
  local label="$1" val="$2" n drain end
  echo "$val" > "$THR"
  mkdir -p /run/udev/rules.d
  printf '%s\n' "$GUARDED" > "$RULE"
  udevadm control --reload
  timeout 7 udevadm monitor --kernel -s power_supply > "$T/$label.txt" 2>/dev/null &
  local mon=$!
  sleep 1
  udevadm trigger --action=change --subsystem-match=power_supply --sysname-match=BAT0
  wait "$mon"
  n="$(grep -c '^KERNEL\[' "$T/$label.txt")"
  end="$(cat "$THR")"
  rm -f "$RULE"; udevadm control --reload
  drain="$(count_events 3)"
  say "$label: start threshold $val, $n events in 7 s, threshold after $end; 3 s after rule removal: $drain"
  if [ "$drain" -gt 60 ]; then
    say "  storm still running after the rule was removed: restarting systemd-udevd"
    systemctl restart systemd-udevd.service systemd-udevd-control.socket systemd-udevd-kernel.socket
    sleep 2
    say "  3 s after the udevd restart: $(count_events 3) events"
  fi
  sleep 2
}

say "Z13 guarded-rule test, $(date '+%F %T'), kernel $(uname -r), starting threshold $START"
[ "$START" = 85 ] || say "note: starting threshold is $START, not 85; it is restored at exit"
say "baseline, no rule: $(count_events 6) events in 6 s"
run_test "G0 guarded rule, value already 85" 85
run_test "G1 guarded rule, value 80 (one corrective write)" 80
say "end: threshold=$(cat "$THR") (start $START), test rule present=$([ -e "$RULE" ] && echo YES || echo no)"
say "Expected if the guard works: G0 about baseline; G1 a handful of events and threshold back to 85; no storm."
say "Results are also in $RES"
