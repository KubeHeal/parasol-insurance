#!/usr/bin/env bash
# import-model.sh — Download a model from S3 or OCI registry into the local model PVC.
#
# Usage:
#   ./import-model.sh --from-s3  [--bucket BUCKET] [--model-name NAME]
#   ./import-model.sh --from-oci [--registry REGISTRY] [--model-name NAME]
set -euo pipefail

MODEL_NAME="parasol-anomaly-detector"
SOURCE=""
BUCKET="model-storage"
REGION="us-east-1"
REGISTRY="quay.io/kubeheal/models"
TAG="latest"

while [[ $# -gt 0 ]]; do
  case $1 in
    --from-s3)  SOURCE="s3"; shift ;;
    --from-oci) SOURCE="oci"; shift ;;
    --model-name) MODEL_NAME="$2"; shift 2 ;;
    --bucket)     BUCKET="$2"; shift 2 ;;
    --region)     REGION="$2"; shift 2 ;;
    --registry)   REGISTRY="$2"; shift 2 ;;
    --tag)        TAG="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

MODEL_DIR="/mnt/models/${MODEL_NAME}"
mkdir -p "${MODEL_DIR}"

echo "============================================"
echo "Import Model"
echo "  Model : ${MODEL_NAME}"
echo "  Dest  : ${MODEL_DIR}"
echo "  Source : ${SOURCE}"
echo "============================================"

if [ "${SOURCE}" = "s3" ]; then
  S3_PREFIX="s3://${BUCKET}/${MODEL_NAME}/"
  ENDPOINT_FLAG=""
  [ -n "${S3_ENDPOINT_URL:-}" ] && ENDPOINT_FLAG="--endpoint-url ${S3_ENDPOINT_URL}"

  aws s3 sync "${S3_PREFIX}" "${MODEL_DIR}/" \
    --region "${REGION}" \
    ${ENDPOINT_FLAG}

  echo "✓ Model imported from S3"

elif [ "${SOURCE}" = "oci" ]; then
  ARTIFACT="${REGISTRY}/${MODEL_NAME}:${TAG}"

  if command -v oras &>/dev/null; then
    cd "${MODEL_DIR}"
    oras pull "${ARTIFACT}"
  elif command -v podman &>/dev/null; then
    CONTAINER_ID=$(podman create "${ARTIFACT}")
    podman cp "${CONTAINER_ID}:/model/." "${MODEL_DIR}/"
    podman rm "${CONTAINER_ID}"
  else
    echo "✗ ERROR: Neither oras nor podman found"
    exit 1
  fi

  echo "✓ Model imported from OCI"

else
  echo "✗ ERROR: Specify --from-s3 or --from-oci"
  exit 1
fi

echo ""
echo "Imported files:"
ls -la "${MODEL_DIR}/"
