#!/bin/bash
# 5 minute all-core load on balanced then performance. Restores the starting profile on exit.
OUT="${1:?csv path}"
START=$(powerprofilesctl get)
trap 'pkill -x stress-ng 2>/dev/null; powerprofilesctl set "$START"' EXIT
A=/sys/class/firmware-attributes/asus-armoury/attributes
HW=/sys/class/hwmon/hwmon5   # amdgpu: power1_average is whole-APU power in microwatts

echo "profile,t_s,cpu_fan_rpm,gpu_fan_rpm,tctl_c,avg_mhz,apu_w,gpu_sclk,pl1_w,pl2_w" >"$OUT"
for prof in balanced performance; do
  powerprofilesctl set "$prof"
  sleep 90                                  # cooldown at the new profile
  stress-ng --cpu 0 --timeout 302s >/dev/null 2>&1 &
  for ((t=0; t<=300; t+=10)); do
    s=$(sensors 2>/dev/null)
    cf=$(awk '/^cpu_fan:/{print $2}' <<<"$s")
    gf=$(awk '/^gpu_fan:/{print $2}' <<<"$s")
    tc=$(awk '/^Tctl:/{gsub(/[+°C]/,"",$2); print $2}' <<<"$s")
    mhz=$(awk '/cpu MHz/{s+=$4;n++} END{printf "%.0f", s/n}' /proc/cpuinfo)
    w=$(awk '{printf "%.1f", $1/1000000}' $HW/power1_average)
    sclk=$(awk '/\*/{print $2}' /sys/class/drm/card1/device/pp_dpm_sclk)
    pl1=$(cat $A/ppt_pl1_spl/current_value); pl2=$(cat $A/ppt_pl2_sppt/current_value)
    echo "$prof,$t,$cf,$gf,$tc,$mhz,$w,$sclk,$pl1,$pl2" >>"$OUT"
    if awk -v x="${tc:-0}" 'BEGIN{exit !(x>95)}'; then pkill -x stress-ng; echo "ABORT hot $tc" >&2; break; fi
    sleep 10
  done
  pkill -x stress-ng; wait 2>/dev/null
done
echo DONE >>"$OUT"
