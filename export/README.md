# Model Promotion: QA to Production

This directory contains scripts for promoting trained Parasol Insurance anomaly
detection models between environments.

## Promotion Workflow

```
┌─────────────┐     export-to-s3.sh     ┌────────────────┐     import-model.sh     ┌──────────────┐
│  QA Cluster │ ──────────────────────►  │   S3 / OCI     │  ──────────────────────► │ Prod Cluster │
│  (train)    │     export-to-oci.sh     │   Registry     │     --from-s3/oci       │  (serve)     │
└─────────────┘                          └────────────────┘                          └──────────────┘
```

### Step 1: Train on QA

In the QA cluster workbench, run the training notebook:

```bash
cd training/
jupyter nbconvert --execute train-parasol-anomaly-model.ipynb
```

Or trigger the Tekton pipeline:

```bash
tkn pipeline start parasol-model-training-pipeline \
  -p data-source=prometheus \
  -p training-hours=168 \
  -n self-healing-platform --showlog
```

### Step 2: Export from QA

**Option A — S3:**

```bash
./export/export-to-s3.sh parasol-anomaly-detector my-model-bucket us-east-1
```

**Option B — OCI registry:**

```bash
./export/export-to-oci.sh parasol-anomaly-detector quay.io/myorg/models
```

### Step 3: Import to Production

**From S3:**

```bash
./export/import-model.sh --from-s3 \
  --model-name parasol-anomaly-detector \
  --bucket my-model-bucket \
  --region us-east-1
```

**From OCI:**

```bash
./export/import-model.sh --from-oci \
  --model-name parasol-anomaly-detector \
  --registry quay.io/myorg/models
```

### Step 4: Restart InferenceService

After importing, restart the KServe predictor to pick up the new model:

```bash
oc rollout restart deployment -l serving.kserve.io/inferenceservice=parasol-anomaly-detector \
  -n self-healing-platform
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `export-to-s3.sh` | Sync model directory to an S3 bucket |
| `export-to-oci.sh` | Package model as an OCI artifact and push to a container registry |
| `import-model.sh` | Download model from S3 or OCI into the local model PVC |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `S3_ENDPOINT_URL` | (none) | Custom S3 endpoint for NooBaa or MinIO |
| `AWS_ACCESS_KEY_ID` | (from `~/.aws`) | S3 credentials |
| `AWS_SECRET_ACCESS_KEY` | (from `~/.aws`) | S3 credentials |
