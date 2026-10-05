#!/usr/bin/env bash
# export-to-s3.sh — Upload a trained model to S3 for cross-cluster promotion.
#
# Usage:
#   ./export-to-s3.sh [--model-name NAME] [--bucket BUCKET] [--region REGION]
#
# Prerequisites: aws CLI configured, or NooBaa S3 endpoint + credentials.
set -euo pipefail

MODEL_NAME="${1:-parasol-anomaly-detector}"
BUCKET="${2:-model-storage}"
REGION="${3:-us-east-1}"

MODEL_DIR="/mnt/models/${MODEL_NAME}"
S3_PREFIX="s3://${BUCKET}/${MODEL_NAME}/"

echo "============================================"
echo "Export Model to S3"
echo "  Model  : ${MODEL_NAME}"
echo "  Source  : ${MODEL_DIR}"
echo "  Dest   : ${S3_PREFIX}"
echo "============================================"

if [ ! -f "${MODEL_DIR}/model.pkl" ]; then
  echo "✗ ERROR: ${MODEL_DIR}/model.pkl not found"
  echo "  Train a model first with training/train-parasol-anomaly-model.ipynb"
  exit 1
fi

# Detect NooBaa vs AWS endpoint
if [ -n "${S3_ENDPOINT_URL:-}" ]; then
  echo "Using custom endpoint: ${S3_ENDPOINT_URL}"
  ENDPOINT_FLAG="--endpoint-url ${S3_ENDPOINT_URL}"
else
  ENDPOINT_FLAG=""
fi

aws s3 sync "${MODEL_DIR}/" "${S3_PREFIX}" \
  --region "${REGION}" \
  ${ENDPOINT_FLAG} \
  --exclude "*.pyc" \
  --exclude "__pycache__/*"

echo ""
echo "✓ Model exported to ${S3_PREFIX}"
echo ""
echo "Contents:"
aws s3 ls "${S3_PREFIX}" --region "${REGION}" ${ENDPOINT_FLAG}
