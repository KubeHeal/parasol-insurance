#!/bin/bash
# disk-pressure.sh — Fill the PostgreSQL PVC to simulate disk pressure
#
# Triggers: ParasolDiskPressure when claimdb volume usage stays above 70%
# Expected: parasol-remediator deletes /var/lib/pgsql/data/chaos-fill
#
# Usage: ./chaos/disk-pressure.sh [NAMESPACE]
#        ./chaos/disk-pressure.sh --cleanup [NAMESPACE]   # remove injected data

set -euo pipefail

NAMESPACE="${2:-${1:-parasol-insurance}}"
ACTION="${1:-inject}"

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

# Fill to about 75% and never past 88%, so ParasolDiskPressure (>70%) can fire
# without using the last of the volume.
read -r CAP_KB USED_KB < <(oc exec -n "${NAMESPACE}" "${POD}" -- df -P -k /var/lib/pgsql/data | awk 'NR==2 {print $2, $3}')
TARGET_KB=$((CAP_KB * 75 / 100))
CEILING_KB=$((CAP_KB * 88 / 100))
NEED_KB=$((TARGET_KB - USED_KB))
if [ "${NEED_KB}" -lt 1 ]; then
    echo ">>> Volume is already at or above 75%. No additional data written."
else
    ROOM_KB=$((CEILING_KB - USED_KB))
    if [ "${NEED_KB}" -gt "${ROOM_KB}" ]; then
        NEED_KB=${ROOM_KB}
    fi
    NEED_MB=$(((NEED_KB + 1023) / 1024))
    echo ">>> Writing ${NEED_MB}MB so usage is just over 70% and under 88%..."
    oc exec -n "${NAMESPACE}" "${POD}" -- dd if=/dev/zero of=/var/lib/pgsql/data/chaos-fill bs=1M count="${NEED_MB}" 2>&1 || true
fi

echo ""
echo ">>> Disk usage after injection:"
oc exec -n "${NAMESPACE}" "${POD}" -- df -h /var/lib/pgsql/data 2>/dev/null || echo "(could not read disk usage)"
echo ""

echo ">>> Disk pressure injection complete."
echo ""
echo "Expected self-healing response:"
echo "  1. ParasolDiskPressure fires when the claimdb volume stays above 70% for 30s"
echo "  2. parasol-remediator deletes /var/lib/pgsql/data/chaos-fill"
echo ""
echo "Cleanup: ./chaos/disk-pressure.sh --cleanup ${NAMESPACE}"
