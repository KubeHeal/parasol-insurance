#!/bin/bash
# memory-leak.sh — Inject memory pressure into the Parasol Insurance app
#
# Triggers: ParasolOOMRisk alert
# Expected: parasol-remediator deletes the ic-app pod
#
# Usage: ./chaos/memory-leak.sh [NAMESPACE]

set -euo pipefail

NAMESPACE="${1:-parasol-insurance}"
CONTAINER="insurance-claim-app"
HOLD_SECONDS="100"

# Stress ~90% of the container memory limit so ParasolOOMRisk (>85%) can fire.
# A fixed 200M stays under the 1Gi limit used by bootstrap/rosa/.
LIMIT_RAW=$(oc get deploy/ic-app -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[?(@.name=="insurance-claim-app")].resources.limits.memory}' 2>/dev/null || true)
STRESS_BYTES="200M"
if [ -n "${LIMIT_RAW}" ]; then
    NUM=$(echo "${LIMIT_RAW}" | sed -E 's/[^0-9].*//')
    UNIT=$(echo "${LIMIT_RAW}" | sed -E 's/[0-9]+//')
    case "${UNIT}" in
        Gi) MIB=$((NUM * 1024)) ;;
        Mi) MIB=${NUM} ;;
        Ki) MIB=$((NUM / 1024)) ;;
        *) MIB=0 ;;
    esac
    if [ "${MIB}" -gt 0 ]; then
        STRESS_MIB=$((MIB * 90 / 100))
        if [ "${STRESS_MIB}" -lt 32 ]; then
            STRESS_MIB=32
        fi
        STRESS_BYTES="${STRESS_MIB}M"
    fi
fi

echo "=== Parasol Insurance: Memory Leak Injection ==="
echo "Namespace:  ${NAMESPACE}"
echo "Container:  ${CONTAINER}"
echo "Memory:     ${STRESS_BYTES}"
echo "Duration:   ${HOLD_SECONDS}s"
echo ""

# Verify the deployment exists
if ! oc get deploy/ic-app -n "${NAMESPACE}" &>/dev/null; then
    echo "ERROR: Deployment ic-app not found in namespace ${NAMESPACE}"
    echo "Deploy Parasol Insurance first: oc apply -k bootstrap/ic-shared-app/base/"
    exit 1
fi

POD=$(oc get pods -n "${NAMESPACE}" -l app=ic-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "${POD}" ]; then
    echo "ERROR: No running pods found for app=ic-app"
    exit 1
fi

echo "Target pod: ${POD}"
echo ""
echo ">>> Injecting memory pressure (${STRESS_BYTES} for ${HOLD_SECONDS}s)..."
echo "    Watch for ParasolOOMRisk. The parasol-remediator deletes the pod."
echo ""

# stress is optional. Without it, allocate anonymous memory in the process
# (not /dev/shm, which is only 64Mi) and hold it past the 30s alert window.
oc exec -n "${NAMESPACE}" "${POD}" -c "${CONTAINER}" -- /bin/sh -c "
    if command -v stress >/dev/null 2>&1; then
        stress --vm 1 --vm-bytes ${STRESS_BYTES} --timeout ${HOLD_SECONDS}s
    else
        echo 'stress not found, allocating anonymous memory with python...'
        python3 -c \"
import time
def cgroup():
    try:
        cur = int(open('/sys/fs/cgroup/memory.current').read())
        raw = open('/sys/fs/cgroup/memory.max').read().strip()
        mx = int(raw) if raw != 'max' else 0
        inactive = 0
        for line in open('/sys/fs/cgroup/memory.stat'):
            k, v = line.split()
            if k == 'inactive_file':
                inactive = int(v)
        return cur, mx, max(cur - inactive, 0)
    except Exception:
        return 0, 0, 0
cur, mx, ws = cgroup()
step = 16 * 1024 * 1024
buf = []
allocated = 0
target = int(mx * 0.90) if mx else 0
ceiling = int(mx * 0.98) if mx else 0
while True:
    cur, mx, ws = cgroup()
    if not mx:
        break
    if ws >= target or cur + step >= ceiling:
        break
    buf.append(bytearray(step))
    allocated += step
cur, mx, ws = cgroup()
print('allocated', allocated // (1024 * 1024), 'MiB', 'working_set', ws, 'current', cur, 'limit', mx, flush=True)
time.sleep(${HOLD_SECONDS})
\"
    fi
" 2>&1 || true

echo ""
echo ">>> Memory pressure injection complete."
echo ""
echo "Expected self-healing response:"
echo "  1. ParasolOOMRisk fires after memory stays above 85% for 30s"
echo "  2. parasol-remediator deletes the ic-app pod"
echo "  3. The Deployment starts a replacement pod"
echo ""
echo "Verify: oc get events -n ${NAMESPACE} --sort-by='.lastTimestamp' | tail -10"
