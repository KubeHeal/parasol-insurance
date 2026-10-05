# Parasol Insurance — Chaos Injection Scripts

These scripts deliberately inject faults into the Parasol Insurance application to
demonstrate how the KubeHeal self-healing platform detects and remediates problems
in a namespace it does not own.

## Prerequisites

- `oc` CLI logged into the cluster
- Parasol Insurance deployed in the `parasol-insurance` namespace
- KubeHeal platform deployed in `self-healing-platform` namespace
- KubeHeal bootstrap applied: `oc apply -k bootstrap/kubeheal/`

## Scenarios

| Script | Fault | Detection | Expected Remediation |
|--------|-------|-----------|---------------------|
| `memory-leak.sh` | OOMKill via `stress` | `ParasolOOMRisk` alert, anomaly score spike | Coordination engine restarts pod, optionally patches memory limit |
| `cpu-spike.sh` | CPU saturation via `stress` | `ParasolCPUThrottling` alert, Isolation Forest anomaly | Coordination engine scales deployment or restarts pod |
| `crash-loop.sh` | Invalid command patch | `ParasolCrashLooping` alert | Coordination engine rolls back deployment to previous revision |
| `disk-pressure.sh` | Fill PostgreSQL PVC | Predictive analytics alert on disk trend | Coordination engine cleans up or expands PVC |
| `network-partition.yaml` | NetworkPolicy blocks DB | `ParasolDBConnectionFailure` alert | Coordination engine removes the faulty NetworkPolicy |

## Usage

```bash
# Run a single scenario
./chaos/memory-leak.sh

# Apply network partition (and remove it)
oc apply -f chaos/network-partition.yaml -n parasol-insurance
# To remove:
oc delete -f chaos/network-partition.yaml -n parasol-insurance
```

## Observing the Self-Healing Loop

1. Open a terminal watching coordination engine logs:
   ```bash
   oc logs -f deploy/coordination-engine -n self-healing-platform
   ```

2. Open another terminal watching Parasol pods:
   ```bash
   oc get pods -n parasol-insurance -w
   ```

3. Run a chaos script from a third terminal.

4. Watch the coordination engine detect the anomaly, query the model, and apply remediation.
