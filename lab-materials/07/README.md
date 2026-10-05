# Section 7: Making It Self-Healing — Lab Materials

This directory contains notebooks for Section 7 of the Parasol Insurance Workshop.

| Notebook | Section | Description |
|----------|---------|-------------|
| `07-03-explore-parasol-metrics.ipynb` | 7.3 | Query Prometheus for Parasol Insurance container metrics |
| `07-05-train-anomaly-model.ipynb` | 7.5 | Train an Isolation Forest anomaly detector on Parasol metrics |

## Prerequisites

- Parasol Insurance application deployed in `parasol-insurance` namespace
- KubeHeal integration overlay applied: `oc apply -k bootstrap/kubeheal/`
- Self-healing platform deployed on the cluster

## Guided Instructions

Follow the step-by-step instructions at the Parasol Insurance Workshop site,
Section 7: "Making It Self-Healing".
