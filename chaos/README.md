# Parasol Insurance — Chaos Injection Scripts

These scripts deliberately inject faults into the Parasol Insurance application to
demonstrate how the KubeHeal self-healing platform detects and remediates problems
in a namespace it does not own.

## Prerequisites

- `oc` CLI logged into the cluster
- KubeHeal platform deployed in `self-healing-platform` namespace
- Parasol demo deployed in `parasol-insurance`: `oc apply -k bootstrap/rosa/`
- KubeHeal bootstrap applied: `oc apply -k bootstrap/kubeheal/`

## Scenarios

| Script | Fault | Detection | Expected Remediation |
|--------|-------|-----------|---------------------|
| `memory-leak.sh` | Hold ~90% of the container memory limit | `ParasolOOMRisk` | `parasol-remediator` deletes the ic-app pod |
| `cpu-spike.sh` | CPU saturation via a busy loop | `ParasolCPUThrottling` | `parasol-remediator` deletes the ic-app pod |
| `crash-loop.sh` | Invalid command patch | `ParasolCrashLooping` | `parasol-remediator` rolls the deployment back |
| `disk-pressure.sh` | Fill the PostgreSQL PVC past 70% | `ParasolDiskPressure` | `parasol-remediator` deletes the fill file |
| `network-partition.yaml` | NetworkPolicy blocks DB | `ParasolDBConnectionFailure` | `parasol-remediator` removes the NetworkPolicy |

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
