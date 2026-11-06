#!/usr/bin/env bash
set -u

pass_count=0
fail_count=0

report() {
  local status="$1"
  local name="$2"
  local detail="$3"
  if [ "$status" = "PASS" ]; then
    pass_count=$((pass_count + 1))
  else
    fail_count=$((fail_count + 1))
  fi
  printf '%s  %-28s %s\n' "$status" "$name" "$detail"
}

# Prometheus must answer its own health endpoint.
if curl -fsS --max-time 10 http://127.0.0.1:9090/-/healthy >/dev/null 2>&1; then
  report PASS "Prometheus health" "http://127.0.0.1:9090/-/healthy"
else
  report FAIL "Prometheus health" "no healthy response on port 9090"
fi

# Count active Prometheus targets reporting health="up".
targets_json="$(curl -fsS --max-time 10 http://127.0.0.1:9090/api/v1/targets 2>/dev/null || true)"
active_up="$(printf '%s' "$targets_json" | python3 -c 'import json,sys
try:
    data=json.load(sys.stdin)
    targets=data.get("data", {}).get("activeTargets", [])
    print(sum(1 for target in targets if target.get("health") == "up"))
except Exception:
    print(0)' 2>/dev/null || printf '0')"

if [ "$active_up" -ge 3 ]; then
  report PASS "Prometheus targets" "$active_up active targets are up"
else
  report FAIL "Prometheus targets" "only $active_up active targets are up (expected at least 3)"
fi

# Grafana must answer its health endpoint.
if curl -fsS --max-time 10 http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
  report PASS "Grafana health" "http://127.0.0.1:3000/api/health"
else
  report FAIL "Grafana health" "no healthy response on port 3000"
fi

printf '\nPassed: %s  Failed: %s\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
