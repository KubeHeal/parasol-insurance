#!/bin/bash
# memory-leak.sh — Inject memory pressure into the Parasol Insurance app
#
# Triggers: ParasolOOMRisk alert, OOMKill detection by coordination engine
# Expected: Coordination engine detects OOMKill pattern, restarts pod with backoff
#
# Usage: ./chaos/memory-leak.sh [NAMESPACE]

set -euo pipefail

NAMESPACE="${1:-parasol-insurance}"
CONTAINER="insurance-claim-app"
TIMEOUT="60s"

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
echo "Duration:   ${TIMEOUT}"
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
echo ">>> Injecting memory pressure (${STRESS_BYTES} for ${TIMEOUT})..."
echo "    Watch for ParasolOOMRisk alert in Prometheus/AlertManager"
echo ""

# Install stress if not present, then run
oc exec -n "${NAMESPACE}" "${POD}" -c "${CONTAINER}" -- /bin/sh -c "
    if command -v stress >/dev/null 2>&1; then
        stress --vm 1 --vm-bytes ${STRESS_BYTES} --timeout ${TIMEOUT}
    else
        echo 'stress not found, using dd-based memory allocation...'
        dd if=/dev/zero of=/dev/shm/fill bs=1M count=200 2>/dev/null || true
        sleep ${TIMEOUT%%s}
        rm -f /dev/shm/fill
    fi
" 2>&1 || true

echo ""
echo ">>> Memory pressure injection complete."
echo ""
echo "Expected self-healing response:"
echo "  1. ParasolOOMRisk alert fires (container >85% memory limit)"
echo "  2. If OOMKilled: coordination engine detects restart, applies backoff"
echo "  3. Coordination engine may patch memory limit via oomRemediation config"
echo ""
echo "Verify: oc get events -n ${NAMESPACE} --sort-by='.lastTimestamp' | tail -10"
