#!/bin/bash
# cpu-spike.sh — Inject CPU saturation into the Parasol Insurance app
#
# Triggers: ParasolCPUThrottling alert
# Expected: parasol-remediator deletes the ic-app pod
#
# Usage: ./chaos/cpu-spike.sh [NAMESPACE]

set -euo pipefail

NAMESPACE="${1:-parasol-insurance}"
CONTAINER="insurance-claim-app"
CPU_WORKERS="4"
TIMEOUT="120s"

echo "=== Parasol Insurance: CPU Spike Injection ==="
echo "Namespace:  ${NAMESPACE}"
echo "Container:  ${CONTAINER}"
echo "CPU cores:  ${CPU_WORKERS}"
echo "Duration:   ${TIMEOUT}"
echo ""

if ! oc get deploy/ic-app -n "${NAMESPACE}" &>/dev/null; then
    echo "ERROR: Deployment ic-app not found in namespace ${NAMESPACE}"
    exit 1
fi

POD=$(oc get pods -n "${NAMESPACE}" -l app=ic-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "${POD}" ]; then
    echo "ERROR: No running pods found for app=ic-app"
    exit 1
fi

echo "Target pod: ${POD}"
echo ""
echo ">>> Injecting CPU spike (${CPU_WORKERS} workers for ${TIMEOUT})..."
echo "    Watch for ParasolCPUThrottling. The parasol-remediator deletes the pod."
echo ""

oc exec -n "${NAMESPACE}" "${POD}" -c "${CONTAINER}" -- /bin/sh -c "
    if command -v stress >/dev/null 2>&1; then
        stress --cpu ${CPU_WORKERS} --timeout ${TIMEOUT}
    else
        echo 'stress not found, using busy-loop...'
        for i in \$(seq 1 ${CPU_WORKERS}); do
            while true; do :; done &
        done
        sleep ${TIMEOUT%%s}
        kill %- 2>/dev/null || true
        kill \$(jobs -p) 2>/dev/null || true
    fi
" 2>&1 || true

echo ""
echo ">>> CPU spike injection complete."
echo ""
echo "Expected self-healing response:"
echo "  1. ParasolCPUThrottling fires when more than 25% of CPU periods are throttled"
echo "  2. parasol-remediator deletes the ic-app pod"
echo "  3. The Deployment starts a replacement pod"
echo ""
echo "Verify: oc top pods -n ${NAMESPACE}"
