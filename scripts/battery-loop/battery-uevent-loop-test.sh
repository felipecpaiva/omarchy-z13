#!/usr/bin/env bash
# Z13 battery uevent loop: isolate what takes part and whether an add-only rule is safe.
# Run as: sudo bash scripts/battery-loop/battery-uevent-loop-test.sh   (about 1 minute, leaves nothing installed)
# Written for the Z13 (BAT0, asusd); not tested elsewhere. Results are also written to
# /tmp/z13-loop-tests.result.
#
# T0  no rule, one `change` trigger            -> baseline: how many events the trigger alone makes
# T1  the old rule (add|change), asusd STOPPED -> does the loop need asusd?
# T2  add-only rule, one `change` trigger      -> an add-only rule must not loop
# T3  add-only rule, one `add` trigger         -> the case an add-only rule is meant for
# Every test installs a test rule, triggers, counts power_supply kernel events for 7 s, then removes
# the rule. The rule goes to /run/udev/rules.d (volatile), so a crash or a power loss cannot leave
# it active across a reboot. On exit (also on Ctrl-C) the rule is removed, udev reloaded and asusd
# restarted.
set -u
case "${1:-}" in
  -h|--help) sed -n '2,/^set -u$/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
[ "$(id -u)" -eq 0 ] || { echo "run with sudo: sudo bash $0" >&2; exit 2; }
RULE=/run/udev/rules.d/99-battery-limit-test.rules
RES=/tmp/z13-loop-tests.result
T="$(mktemp -d /tmp/z13-loop.XXXXXX)"
ASUSD_WAS="$(systemctl is-active asusd 2>/dev/null)"
mkdir -p "$(dirname "$RULE")"
: > "$RES"
say() { echo "$*" | tee -a "$RES"; }

cleanup() {
  rm -f "$RULE"
  udevadm control --reload
  if [ "$ASUSD_WAS" = active ] && [ "$(systemctl is-active asusd)" != active ]; then systemctl start asusd; fi
  rm -rf "$T"; chmod 644 "$RES" 2>/dev/null
}
trap cleanup EXIT
trap 'exit 130' INT TERM

FULL='ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}="85"'
ADDONLY='ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}="85"'

# seconds -> number of power_supply kernel events, the monitor banner excluded
# (redirect to a file: the piped form lost the count in my shell; a reviewer could not reproduce
# that in bash, sh or zsh, but the redirect form works everywhere)
count_events() {
  timeout "$1" udevadm monitor --kernel -s power_supply > "$T/ev.txt" 2>/dev/null
  grep -c '^KERNEL\[' "$T/ev.txt"
}

run_test() {  # label rule-text-or-empty trigger-action [stop-asusd]
  local label="$1" rule="$2" act="$3" stop="${4:-}" n drain asd mon
  if [ -n "$stop" ]; then systemctl stop asusd; fi
  asd="$(systemctl is-active asusd 2>/dev/null)"
  if [ -n "$stop" ] && [ "$asd" != inactive ]; then
    say "$label: FAIL asusd is '$asd' after systemctl stop; the test would not show whether the loop needs it"
    return 1
  fi
  if [ -n "$rule" ]; then printf '%s\n' "$rule" > "$RULE"; else rm -f "$RULE"; fi
  udevadm control --reload
  timeout 7 udevadm monitor --kernel -s power_supply > "$T/$label.txt" 2>/dev/null &
  mon=$!
  sleep 1
  udevadm trigger --action="$act" --subsystem-match=power_supply --sysname-match=BAT0
  wait "$mon"
  n="$(grep -c '^KERNEL\[' "$T/$label.txt")"
  rm -f "$RULE"; udevadm control --reload
  [ -n "$stop" ] && [ "$ASUSD_WAS" = active ] && systemctl start asusd
  drain="$(count_events 3)"
  say "$label: $n events in 7 s (trigger=$act, rule=$([ -n "$rule" ] && echo installed || echo none), asusd=$asd); 3 s after removal: $drain"
  if [ "$drain" -gt 60 ]; then
    say "  storm still running after the rule was removed: restarting systemd-udevd and both sockets"
    systemctl restart systemd-udevd.service systemd-udevd-control.socket systemd-udevd-kernel.socket
    sleep 2
    say "  3 s after the udevd restart: $(count_events 3) events"
  fi
  sleep 2
}

say "Z13 battery uevent loop tests, $(date '+%F %T'), kernel $(uname -r)"
say "start: asusd=$ASUSD_WAS, threshold=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold), old rule absent=$([ ! -e /etc/udev/rules.d/99-battery-limit.rules ] && echo yes || echo NO), test rules absent=$([ ! -e /etc/udev/rules.d/99-battery-limit-test.rules ] && [ ! -e /run/udev/rules.d/99-battery-limit-test.rules ] && echo yes || echo NO)"
run_test "T0 no rule, change trigger" "" change
run_test "T1 old rule, asusd stopped, change trigger" "$FULL" change stop
run_test "T2 add-only rule, change trigger" "$ADDONLY" change
run_test "T3 add-only rule, add trigger" "$ADDONLY" add
say "end: asusd=$(systemctl is-active asusd), threshold=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold), test rule present=$([ -e "$RULE" ] && echo YES || echo no)"
say "Expected if only the rule loops: T0 small, T1 about 1000 if asusd is not needed (small if it is), T2 small, T3 small."
say "Results are also in $RES"
chmod 644 "$RES"
