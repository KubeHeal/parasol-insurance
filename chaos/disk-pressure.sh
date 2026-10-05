#!/bin/bash
# disk-pressure.sh — Fill the PostgreSQL PVC to simulate disk pressure
#
# Triggers: Predictive analytics alert on disk usage trend
# Expected: Coordination engine detects disk pressure, cleans up or expands PVC
#
# Usage: ./chaos/disk-pressure.sh [NAMESPACE]
#        ./chaos/disk-pressure.sh --cleanup [NAMESPACE]   # remove injected data

set -euo pipefail

NAMESPACE="${2:-${1:-parasol-insurance}}"
ACTION="${1:-inject}"
FILL_SIZE_MB=500

if [ "${ACTION}" = "--cleanup" ]; then
    NAMESPACE="${2:-parasol-insurance}"
    echo "=== Cleaning up disk pressure injection ==="
    POD=$(oc get pods -n "${NAMESPACE}" -l app=claimdb -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -n "${POD}" ]; then
        oc exec -n "${NAMESPACE}" "${POD}" -- rm -f /var/lib/pgsql/data/chaos-fill
        echo "Removed chaos-fill file from ${POD}"
    else
        echo "No database pod found to clean up"
    fi
    exit 0
fi

echo "=== Parasol Insurance: Disk Pressure Injection ==="
echo "Namespace: ${NAMESPACE}"
echo "Fill size: ${FILL_SIZE_MB}MB"
echo ""

POD=$(oc get pods -n "${NAMESPACE}" -l app=claimdb -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "${POD}" ]; then
    echo "ERROR: No running database pods found (label: app=claimdb)"
    exit 1
fi

echo "Target pod: ${POD}"
echo ""

echo ">>> Current disk usage:"
oc exec -n "${NAMESPACE}" "${POD}" -- df -h /var/lib/pgsql/data 2>/dev/null || echo "(could not read disk usage)"
echo ""

echo ">>> Filling ${FILL_SIZE_MB}MB on PostgreSQL PVC..."
oc exec -n "${NAMESPACE}" "${POD}" -- dd if=/dev/zero of=/var/lib/pgsql/data/chaos-fill bs=1M count=${FILL_SIZE_MB} 2>&1 || true

echo ""
echo ">>> Disk usage after injection:"
oc exec -n "${NAMESPACE}" "${POD}" -- df -h /var/lib/pgsql/data 2>/dev/null || echo "(could not read disk usage)"
echo ""

echo ">>> Disk pressure injection complete."
echo ""
echo "Expected self-healing response:"
echo "  1. Predictive analytics model detects disk usage trend"
echo "  2. Alert fires before PVC reaches 100%"
echo "  3. Coordination engine runs cleanup or PVC expansion"
echo ""
echo "Cleanup: ./chaos/disk-pressure.sh --cleanup ${NAMESPACE}"
