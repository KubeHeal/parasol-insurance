#!/usr/bin/env python3
"""Score one feature vector with the saved Isolation Forest pipeline.

Columns, in order:
cpu_usage, memory_usage, memory_limit, restarts,
network_rx, network_tx, memory_utilization, network_ratio, cpu_memory_product.
"""
import sys
import warnings

import joblib

warnings.filterwarnings("ignore")

MODEL = "/opt/app-root/src/models/parasol-anomaly-detector/model.pkl"


def row(cpu, mem, limit, restarts, rx, tx):
    util = mem / limit
    ratio = tx / rx
    return [cpu, mem, limit, restarts, rx, tx, util, ratio, cpu * util]


# Centers of the synthetic ranges in 07-05-train-anomaly-model.ipynb.
VECTORS = {
    "normal": row(0.15, 180e6, 512e6, 0, 50000, 30000),
    "oom": row(0.30, 450e6, 512e6, 0, 50000, 30000),
}

kind = sys.argv[1] if len(sys.argv) > 1 else ""
if kind not in VECTORS:
    print("usage: score_decision.py normal|oom", file=sys.stderr)
    sys.exit(2)

model = joblib.load(MODEL)
verdict = int(model.predict([VECTORS[kind]])[0])
print(f"verdict={verdict}")
