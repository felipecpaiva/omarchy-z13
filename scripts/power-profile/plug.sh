#!/bin/bash
# Step 2: log who sets the profile on unplug and replug. Read only. Runs for 150 s.
OUT="${1:?log path}"
exec >"$OUT" 2>&1
stamp() { date +%H:%M:%S.%3N; }
echo "START $(stamp)"
echo "saved: ac=$(cat ~/.local/state/omarchy/powerprofiles/ac) battery=$(cat ~/.local/state/omarchy/powerprofiles/battery)"
journalctl -f -n0 -o short-precise -u asusd -u power-profiles-daemon -u upower --no-pager &
JP=$!
trap 'kill $JP 2>/dev/null' EXIT
last=""
end=$((SECONDS+150))
while (( SECONDS < end )); do
  ac=$(cat /sys/class/power_supply/AC0/online)
  ob=$(busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null | awk '{print $2}')
  ppd=$(powerprofilesctl get)
  pp=$(cat /sys/firmware/acpi/platform_profile)
  cur="AC=$ac OnBattery=$ob ppd=$ppd platform=$pp"
  if [[ $cur != "$last" ]]; then echo "$(stamp) STATE $cur"; last=$cur; fi
  sleep 0.25
done
echo "END $(stamp)"
ls -l --time-style=full-iso ~/.local/state/omarchy/powerprofiles/
