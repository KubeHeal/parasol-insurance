# Parasol Insurance Anomaly Detection Model

## Baseline Model

`baseline-model.pkl` is a pre-trained **Isolation Forest** model packaged as an sklearn Pipeline.
It detects anomalous container behaviour in the Parasol Insurance namespace.

### Model Details

| Field | Value |
|-------|-------|
| **Algorithm** | Isolation Forest (sklearn) |
| **Pipeline** | StandardScaler → IsolationForest |
| **Training data** | 5 000 synthetic samples (90 % normal, 10 % anomaly) |
| **Features** | 9 (see below) |
| **Contamination** | 0.10 |
| **Estimators** | 200 |
| **Serving format** | KServe sklearn server (`model.pkl`) |

### Features

| # | Name | Description |
|---|------|-------------|
| 0 | `cpu_usage` | CPU usage rate (cores) |
| 1 | `memory_usage` | Working set bytes |
| 2 | `memory_limit` | Container memory limit bytes |
| 3 | `restarts` | Pod restart count in last 10 m |
| 4 | `network_rx` | Network receive bytes/s |
| 5 | `network_tx` | Network transmit bytes/s |
| 6 | `memory_utilization` | `memory_usage / memory_limit` |
| 7 | `network_ratio` | `network_tx / network_rx` |
| 8 | `cpu_memory_product` | `cpu_usage × memory_utilization` |

### Anomaly Scenarios Covered

The model was trained on synthetic data that mirrors the five chaos injection scenarios:

1. **OOM risk** — high memory usage near limit (memory-leak.sh)
2. **CPU spike** — sustained high CPU (cpu-spike.sh)
3. **Crash loop** — high restart count, low CPU/memory (crash-loop.sh)
4. **Network partition** — very low network I/O (network-partition.yaml)
5. **Disk pressure** — elevated memory + high network TX (disk-pressure.sh)

### Using the Model

**Copy to the model PVC:**

```bash
oc cp models/baseline-model.pkl \
  self-healing-platform/self-healing-workbench-0:/mnt/models/parasol-anomaly-detector/model.pkl
```

**Or retrain on real data:**

```bash
# Run the training notebook
cd training/
jupyter nbconvert --execute train-parasol-anomaly-model.ipynb
```

### Inference

The model accepts a 2-D array with 9 features and returns predictions where:
- `1` = normal
- `-1` = anomaly

```python
import joblib, numpy as np
model = joblib.load('baseline-model.pkl')
sample = np.array([[0.15, 180e6, 512e6, 0, 50000, 30000, 0.35, 0.6, 0.05]])
print(model.predict(sample))   # [1] → normal
```

### Retraining

See [`../training/train-parasol-anomaly-model.ipynb`](../training/train-parasol-anomaly-model.ipynb) for full retraining on live Prometheus data.
