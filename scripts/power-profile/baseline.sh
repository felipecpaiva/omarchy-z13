#!/bin/bash
# Step 1 baseline: per profile, idle then all-core load. Restores the starting profile on exit.
OUT="${1:?csv path}"
START=$(powerprofilesctl get)
trap 'pkill -x stress-ng 2>/dev/null; powerprofilesctl set "$START"' EXIT

sample() { # prints: cpu_fan gpu_fan tctl epp mhz
  local s; s=$(sensors 2>/dev/null)
  local cf gf tc epp mhz
  cf=$(awk '/^cpu_fan:/{print $2}' <<<"$s")
  gf=$(awk '/^gpu_fan:/{print $2}' <<<"$s")
  tc=$(awk '/^Tctl:/{gsub(/[+°C]/,"",$2); print $2}' <<<"$s")
  epp=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference)
  mhz=$(awk '/cpu MHz/{s+=$4;n++} END{printf "%.0f", s/n}' /proc/cpuinfo)
  echo "$cf $gf $tc $epp $mhz"
}

mean_phase() { # profile phase seconds_total  (averages the last 30 s, samples every 5 s)
  local prof=$1 phase=$2 total=$3 i n=0
  local scf=0 sgf=0 stc=0 smhz=0 epp=""
  for ((i=0; i<total; i+=5)); do
    sleep 5
    if (( i >= total-30 )); then
      read -r cf gf tc e mhz <<<"$(sample)"
      scf=$((scf+${cf:-0})); sgf=$((sgf+${gf:-0})); smhz=$((smhz+${mhz:-0}))
      stc=$(awk -v a="$stc" -v b="${tc:-0}" 'BEGIN{print a+b}'); epp=$e; n=$((n+1))
      if awk -v t="${tc:-0}" 'BEGIN{exit !(t>95)}'; then pkill -x stress-ng; echo "ABORT hot $tc" >&2; fi
    fi
  done
  local pp pl
  pp=$(cat /sys/firmware/acpi/platform_profile)
  echo "$prof,$phase,$((scf/n)),$((sgf/n)),$(awk -v a=$stc -v n=$n 'BEGIN{printf "%.1f", a/n}'),$epp,$pp,$((smhz/n))" >>"$OUT"
}

echo "profile,phase,cpu_fan_rpm,gpu_fan_rpm,tctl_c,epp,platform_profile,avg_mhz" >"$OUT"
for prof in power-saver balanced performance; do
  powerprofilesctl set "$prof"
  mean_phase "$prof" idle 120
  stress-ng --cpu 0 --timeout 62s >/dev/null 2>&1 &
  mean_phase "$prof" load 60
  wait
done
echo DONE >>"$OUT"
