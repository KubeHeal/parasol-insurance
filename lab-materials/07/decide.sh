#!/bin/bash
# Score model.pkl, then delete ic-app only when the verdict is -1.
set -euo pipefail

KIND="${1:-}"
case "${KIND}" in
  normal|oom) ;;
  *)
    echo "usage: bash lab-materials/07/decide.sh normal|oom" >&2
    exit 2
    ;;
esac

HERE="$(cd "$(dirname "$0")" && pwd)"
NS=parasol-insurance
before="$(oc get pod -n "${NS}" -l app=ic-app -o jsonpath='{.items[0].metadata.name}')"
verdict="$(
  oc exec -i -n self-healing-platform self-healing-workbench-0 -c self-healing-workbench -- \
    python3 - "${KIND}" < "${HERE}/score_decision.py" | awk -F= '/^verdict=/{print $2}'
)"

echo "vector=${KIND} verdict=${verdict}"
echo "ic-app pod before: ${before}"

if [ "${verdict}" = "-1" ]; then
  oc delete pod -n "${NS}" -l app=ic-app
  oc rollout status "deploy/ic-app" -n "${NS}" --timeout=180s
elif [ "${verdict}" = "1" ]; then
  echo "verdict 1: leaving ic-app running"
else
  echo "unexpected verdict: ${verdict}" >&2
  exit 1
fi

after="$(oc get pod -n "${NS}" -l app=ic-app -o jsonpath='{.items[0].metadata.name}{" "}{.items[0].status.phase}')"
echo "ic-app pod after: ${after}"
