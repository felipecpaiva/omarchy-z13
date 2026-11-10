#!/bin/bash
# GPU test: llama-bench (Vulkan) in 4 chunks of ~1 min per profile, with a 10 s sensor sampler.
# Restores the starting profile on exit.
DIR="${1:?output dir}"
START=$(powerprofilesctl get)
MODEL=~/models/Qwen3-30B-A3B-Q4_K_M.gguf
HW=/sys/class/hwmon/hwmon5
RES="$DIR/gpu-results.csv"; SER="$DIR/gpu-series.csv"
trap 'pkill -x llama-bench 2>/dev/null; kill $SP 2>/dev/null; powerprofilesctl set "$START"' EXIT
echo "profile,chunk,pp2048_tps,tg512_tps" >"$RES"
echo "profile,t_s,cpu_fan_rpm,gpu_fan_rpm,tctl_c,gpu_edge_c,apu_w,gpu_sclk,gpu_busy" >"$SER"

sampler() { # $1 profile
  local t=0
  while true; do
    s=$(sensors 2>/dev/null)
    cf=$(awk '/^cpu_fan:/{print $2}' <<<"$s"); gf=$(awk '/^gpu_fan:/{print $2}' <<<"$s")
    tc=$(awk '/^Tctl:/{gsub(/[+°C]/,"",$2); print $2}' <<<"$s")
    ed=$(awk '/^edge:/{gsub(/[+°C]/,"",$2); print $2}' <<<"$s")
    w=$(awk '{printf "%.1f", $1/1000000}' $HW/power1_average)
    sclk=$(awk '/\*/{print $2}' /sys/class/drm/card1/device/pp_dpm_sclk)
    busy=$(cat /sys/class/drm/card1/device/gpu_busy_percent)
    echo "$1,$t,$cf,$gf,$tc,$ed,$w,$sclk,$busy" >>"$SER"
    if awk -v x="${tc:-0}" 'BEGIN{exit !(x>95)}'; then pkill -x llama-bench; fi
    t=$((t+10)); sleep 10
  done
}

for prof in balanced performance power-saver; do
  powerprofilesctl set "$prof"
  sleep 90
  sampler "$prof" & SP=$!
  for c in 1 2 3 4; do
    out=$(llama-bench -m "$MODEL" -ngl 99 -p 2048 -n 512 -r 8 -o csv 2>/dev/null)
    # columns from the end: n_prompt n_gen n_depth test_time avg_ns stddev_ns avg_ts stddev_ts
    pp=$(tr -d '"' <<<"$out" | awk -F, 'NR>1 && $(NF-7)>0 {print $(NF-1)}')
    tg=$(tr -d '"' <<<"$out" | awk -F, 'NR>1 && $(NF-6)>0 {print $(NF-1)}')
    echo "$prof,$c,$pp,$tg" >>"$RES"
  done
  kill $SP 2>/dev/null; wait $SP 2>/dev/null
done
echo DONE >>"$RES"
