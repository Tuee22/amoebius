# TLA+ Modelling Assumptions (superseded)

**Status**: Deprecated
**Supersedes**: N/A
**Referenced by**: documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/formal_model_doctrine.md
**Generated sections**: none

> **Purpose**: This document is **superseded**. Its subject — the formal model of the cross-cluster failover boundary — is now owned by [gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md), authored against the model-as-data approach of [formal_model_doctrine.md](./formal_model_doctrine.md).

---

## Why this doc is deprecated

This document described a **two-tier** record for a **hand-written** TLA+ specification: a design-model tier
authored now, and a **variable-to-implementation correspondence tier** (a prose table + divergence log) to be
completed later. That framing is retired for two reasons converged during the DSL-first refactor:

1. **The `.tla` is no longer hand-written.** A protocol is authored once as a reifiable Haskell **`Model`**;
   both the runtime decision function (`interpret`) and the generated, never-committed `.tla` (`emitTLA`) are
   total renderings of that one value ([formal_model_doctrine.md](./formal_model_doctrine.md),
   [generated_artifacts_doctrine.md](./generated_artifacts_doctrine.md)). The model↔code correspondence is
   therefore **by construction** — there is **no correspondence table to maintain**, which is the entire
   artifact this document existed to track.

2. **The obligation covers both migration branches.** The sole amoebius simulation/proof obligation is now
   **gateway migration — both the `Planned` and `Failover` branches** of `GatewayMigration` (this document
   previously scoped the model to `Failover` only and treated `Planned` RPO=0 as merely assumed). The
   First-Axis singleton-election obligation is **removed**: the control-plane singleton is a Kubernetes
   Deployment `replicas=1` whose single-instance is delegated to k8s/etcd, with no bespoke election
   ([daemon_topology_doctrine.md §3](./daemon_topology_doctrine.md#3-the-control-plane-singleton)).

## Where its content went

- **The system model, invariant catalog, modelling bounds, and one-and-done + per-`InForceSpec` structural-fit**
  → [gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md).
- **The model-as-data pattern, `interpret`/`emitTLA`, correspondence-by-construction, generated-not-committed**
  → [formal_model_doctrine.md](./formal_model_doctrine.md).
- **The Extract → Model → Inject methodology and the proven/tested/assumed ledger** remain owned by
  [chaos_failover_doctrine.md](./chaos_failover_doctrine.md).

Inbound links that still point here should be repointed to those documents; this stub remains only so existing
references resolve during the transition.

---

## Cross-references

- [Gateway Migration Model Doctrine](./gateway_migration_model_doctrine.md) — the successor
- [Formal Model Doctrine](./formal_model_doctrine.md) — the model-as-data pattern
- [Chaos & Failover Doctrine](./chaos_failover_doctrine.md) — the methodology
- [Engineering Doctrine Index](./README.md)
