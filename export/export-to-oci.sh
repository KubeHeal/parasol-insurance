#!/usr/bin/env bash
# export-to-oci.sh — Package a trained model as an OCI artifact for registry-based promotion.
#
# Usage:
#   ./export-to-oci.sh [--model-name NAME] [--registry REGISTRY]
#
# Prerequisites: oras CLI (https://oras.land) or podman.
set -euo pipefail

MODEL_NAME="${1:-parasol-anomaly-detector}"
REGISTRY="${2:-quay.io/kubeheal/models}"
TAG="${3:-latest}"

MODEL_DIR="/mnt/models/${MODEL_NAME}"
ARTIFACT="${REGISTRY}/${MODEL_NAME}:${TAG}"

echo "============================================"
echo "Export Model as OCI Artifact"
echo "  Model    : ${MODEL_NAME}"
echo "  Source   : ${MODEL_DIR}"
echo "  Artifact : ${ARTIFACT}"
echo "============================================"

if [ ! -f "${MODEL_DIR}/model.pkl" ]; then
  echo "✗ ERROR: ${MODEL_DIR}/model.pkl not found"
  exit 1
fi

# Check for oras CLI
if command -v oras &>/dev/null; then
  echo "Using oras to push OCI artifact..."
  cd "${MODEL_DIR}"
  oras push "${ARTIFACT}" \
    model.pkl:application/vnd.kubeheal.model.sklearn.v1 \
    training_metadata.json:application/json
  echo "✓ Pushed ${ARTIFACT}"

elif command -v podman &>/dev/null; then
  echo "Using podman to build OCI image..."
  TMPDIR=$(mktemp -d)
  cat > "${TMPDIR}/Containerfile" <<'CEOF'
FROM scratch
COPY model.pkl /model/model.pkl
COPY training_metadata.json /model/training_metadata.json
LABEL io.kubeheal.model.name="${MODEL_NAME}"
CEOF
  cp "${MODEL_DIR}/model.pkl" "${TMPDIR}/"
  cp "${MODEL_DIR}/training_metadata.json" "${TMPDIR}/" 2>/dev/null || true
  podman build -t "${ARTIFACT}" "${TMPDIR}"
  podman push "${ARTIFACT}"
  rm -rf "${TMPDIR}"
  echo "✓ Pushed ${ARTIFACT}"

else
  echo "✗ ERROR: Neither oras nor podman found. Install one of them."
  exit 1
fi
