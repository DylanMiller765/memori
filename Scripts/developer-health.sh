#!/bin/zsh

# Read-only health check for Memo development. This script reports storage and
# Simulator state; it never deletes devices, DerivedData, or trace files.

set -u

health_script_dir="${0:A:h}"
health_repo_root="${health_script_dir:h}"
health_minimum_free_gb=15
health_minimum_free_kb=$((health_minimum_free_gb * 1024 * 1024))
health_available_kb=$(df -Pk "$health_repo_root" | awk 'NR == 2 { print $4 }')
health_available_gb=$((health_available_kb / 1024 / 1024))

echo "Memo developer health"
echo "Repository: $health_repo_root"
echo

echo "Disk space"
df -h "$health_repo_root"
if (( health_available_kb < health_minimum_free_kb )); then
  echo "WARNING: ${health_available_gb}GB free. Keep at least ${health_minimum_free_gb}GB free before clean-build or Instruments benchmarks."
else
  echo "OK: ${health_available_gb}GB free."
fi
echo

echo "Developer storage"
du -sh "${HOME}/Library/Developer/Xcode/DerivedData" 2>/dev/null || echo "DerivedData: not found"
du -sh "${HOME}/Library/Developer/CoreSimulator" 2>/dev/null || echo "CoreSimulator: not found"
echo

echo "Booted simulators"
health_booted_devices=$(xcrun simctl list devices 2>/dev/null | awk '/\(Booted\)/ { print }')
if [[ -n "$health_booted_devices" ]]; then
  echo "$health_booted_devices"
else
  echo "None"
fi
echo

echo "Stale temporary traces (older than 7 days)"
health_trace_root="${TMPDIR:-/tmp}"
health_stale_traces=$(find "$health_trace_root" -maxdepth 3 -type d \( -name '*.trace' -o -name '*.tracev3' \) -mtime +7 -print 2>/dev/null)
if [[ -n "$health_stale_traces" ]]; then
  echo "$health_stale_traces"
else
  echo "None found"
fi

