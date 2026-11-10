#!/bin/bash
# Step 4: gentler balanced fan curve, tested at idle, CPU load, GPU load. Guard: Tctl > 88 C turns the curve off.
OUT="${1:?csv path}"
DATA="48c:4%,54c:10%,60c:20%,65c:32%,70c:48%,75c:66%,80c:86%,85c:100%"
MODEL=~/models/Qwen3-30B-A3B-Q4_K_M.gguf
HW=/sys/class/hwmon/hwmon5
ABORT=0
revert() { asusctl fan-curve --mod-profile balanced --enable-fan-curves false >/dev/null 2>&1; }
trap 'pkill -x stress-ng 2>/dev/null; pkill -x llama-bench 2>/dev/null; if [ "$ABORT" = 1 ]; then revert; fi' EXIT

[ "$(powerprofilesctl get)" = balanced ] || powerprofilesctl set balanced
for fan in cpu gpu; do
  asusctl fan-curve --mod-profile balanced --fan $fan --data "$DATA" >/dev/null || { echo "apply failed"; exit 1; }
done
asusctl fan-curve --mod-profile balanced --enable-fan-curves true >/dev/null
asusctl fan-curve --get-enabled

echo "phase,t_s,cpu_fan_rpm,gpu_fan_rpm,tctl_c,apu_w,gpu_busy" >"$OUT"
sample() { # phase seconds
  local ph=$1 total=$2 t
  for ((t=0; t<=total; t+=10)); do
    s=$(sensors 2>/dev/null)
    cf=$(awk '/^cpu_fan:/{print $2}' <<<"$s"); gf=$(awk '/^gpu_fan:/{print $2}' <<<"$s")
    tc=$(awk '/^Tctl:/{gsub(/[+°C]/,"",$2); print $2}' <<<"$s")
    w=$(awk '{printf "%.1f", $1/1000000}' $HW/power1_average)
    busy=$(cat /sys/class/drm/card1/device/gpu_busy_percent)
    echo "$ph,$t,$cf,$gf,$tc,$w,$busy" >>"$OUT"
    if awk -v x="${tc:-0}" 'BEGIN{exit !(x>88)}'; then ABORT=1; echo "ABORT hot $tc in $ph" >>"$OUT"; return 1; fi
    sleep 10
  done
}

sleep 60                                   # let the new curve settle
sample idle 90 || exit 2
stress-ng --cpu 0 --timeout 190s >/dev/null 2>&1 &
sample cpu_load 180 || exit 2
pkill -x stress-ng; sleep 60
( for i in $(seq 1 40); do llama-bench -m "$MODEL" -ngl 99 -p 2048 -n 512 -r 8 >/dev/null 2>&1 || break; done ) &
GL=$!
sample gpu_load 180 || { kill $GL 2>/dev/null; exit 2; }
kill $GL 2>/dev/null; pkill -x llama-bench
echo DONE >>"$OUT"
