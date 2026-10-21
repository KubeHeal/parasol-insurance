#!/bin/bash
# crash-loop.sh — Force Parasol Insurance app into CrashLoopBackOff
#
# Triggers: ParasolCrashLooping alert
# Expected: parasol-remediator rolls the deployment back to the previous revision
#
# Usage: ./chaos/crash-loop.sh [NAMESPACE]
#        ./chaos/crash-loop.sh --rollback [NAMESPACE]   # undo the injection

set -euo pipefail

if [ "${1:-}" = "--rollback" ]; then
    ACTION="rollback"
    NAMESPACE="${2:-parasol-insurance}"
else
    ACTION="inject"
    NAMESPACE="${1:-parasol-insurance}"
fi

echo "=== Parasol Insurance: Crash Loop Injection ==="
echo "Namespace: ${NAMESPACE}"
echo ""

if ! oc get deploy/ic-app -n "${NAMESPACE}" &>/dev/null; then
    echo "ERROR: Deployment ic-app not found in namespace ${NAMESPACE}"
    exit 1
fi

if [ "${ACTION}" = "rollback" ]; then
    echo ">>> Rolling back deployment to undo crash loop injection..."
    oc rollout undo deploy/ic-app -n "${NAMESPACE}"
    echo ">>> Rollback triggered. Watch pods recover:"
    echo "    oc get pods -n ${NAMESPACE} -w"
    exit 0
fi

echo ">>> Saving current deployment revision for rollback..."
CURRENT_REV=$(oc get deploy/ic-app -n "${NAMESPACE}" -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
echo "    Current revision: ${CURRENT_REV}"
echo ""

echo ">>> Patching deployment with invalid command to trigger CrashLoopBackOff..."
oc patch deploy/ic-app -n "${NAMESPACE}" --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/command",
    "value": ["/bin/sh", "-c", "echo CHAOS: crash-loop injection && exit 1"]
  }
]'

echo ""
echo ">>> Crash loop injection applied."
echo ""
echo "Expected self-healing response:"
echo "  1. Pod restarts rapidly, enters CrashLoopBackOff"
echo "  2. ParasolCrashLooping alert fires (>3 restarts in 10min)"
echo "  3. parasol-remediator detects the firing alert"
echo "  4. parasol-remediator rolls back to the previous revision"
echo ""
echo "Watch: oc get pods -n ${NAMESPACE} -w"
echo ""
echo "Manual rollback: ./chaos/crash-loop.sh --rollback ${NAMESPACE}"
