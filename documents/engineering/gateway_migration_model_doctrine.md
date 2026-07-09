# The Gateway-Migration Model: amoebius's one proof obligation

**Status**: Authoritative source
**Supersedes**: documents/engineering/tla_modelling_assumptions.md
**Referenced by**: documents/engineering/README.md, documents/engineering/formal_model_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/daemon_topology_doctrine.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Single source of truth for the *one* protocol amoebius proves itself — the cross-cluster **gateway migration**, covering **both** branches of `GatewayMigration = <Planned | Failover>` — expressed as a reifiable `Model` ([formal_model_doctrine.md](./formal_model_doctrine.md)), **simulated** with io-sim and **proven** with TLC, and reduced to every `InForceSpec` by a decode-time structural-fit fold rather than any per-spec model-check.

---

## 1. The one obligation

Amoebius delegates almost every consensus problem to a system that already discharges it, and does not re-prove
it ([chaos_failover_doctrine.md](./chaos_failover_doctrine.md)):

- **Intra-cluster replicated state** — object storage, the message log, the SQL primary — is delegated to
  **MinIO**, **Pulsar/BookKeeper**, and **Percona/Patroni Postgres**.
- **Single-instance of the control-plane singleton** is delegated to **k8s/etcd**: the singleton is a
  Deployment `replicas=1`, and a hard lock (if ever needed) is a k8s `Lease`, itself etcd-backed
  ([daemon_topology_doctrine.md §3](./daemon_topology_doctrine.md#3-the-control-plane-singleton)). There is
  **no bespoke leader election** — amoebius does not duplicate etcd, and there is no First-Axis
  singleton-election model to prove.

What is left — the single place a per-system proof obligation concentrates on amoebius itself — is the
**asynchronous cross-cluster gateway migration**: moving the wild-ingress gateway between clusters and
repointing DNS, across geo-replication lag, without stranding a live session or admitting two owners. etcd
cannot cover it because it spans clusters. This is the *only* boundary this model targets, and it is the
**main focus of amoebius's simulation and proofs**.

Both branches are in scope. The prior framing (`tla_modelling_assumptions.md §2`, now superseded) scoped the
model to the `Failover` branch and treated the `Planned` branch's RPO=0 as merely an argued assumption. **This
doctrine reverses that:** the `Planned` coordinated handover and the `Failover` emergency takeover are *both*
modelled, simulated, and proven.

---

## 2. The two branches (the state machine this model checks)

The migration is a typed, edge-observed state machine owned by
[gateway_migration_doctrine.md §5](./gateway_migration_doctrine.md#5-the-migration-as-a-typed-edge-observed-state-machine);
this document owns the **`Model` of it**.

- **`Planned` — coordinated, strong-consistency handover (target RPO = 0).** The ordered path
  `stand-up-replica → quiesce → drain / verify-caught-up → promote → (old gateway = transparent proxy + repoint
  DNS) → unfreeze → drain-monitor → decommission(old)`. The old gateway is decommissioned **only** from an
  observed `drain-complete` edge, so no transition removes the last working endpoint for a live session. The
  model must prove the `Planned` path loses no committed write (RPO=0) and never strands a session.
- **`Failover` — availability-first emergency takeover.** The active has vanished with no chance to freeze or
  drain; a survivor promoted from an async-replicated replica takes the wild-ingress role and repoints DNS. The
  guarantee weakens honestly to **bounded rebind** (clients error, re-resolve within the already-low TTL, and
  rebind to the survivor) and a **named, capped divergence** (a declared data-loss budget). The model must
  prove no split-brain gateway and a well-defined, bounded outcome — never undefined behaviour.

---

## 3. The `Model`

Following [formal_model_doctrine.md](./formal_model_doctrine.md), the protocol is one reifiable `Model` value —
state variables (per-cluster replication offset/log, gateway owner, DNS record, migration phase, branch), the
`Planned` and `Failover` transitions as guarded actions, and the invariants below — from which `interpret`
(the runtime decision core) and `emitTLA` (the generated, never-committed `.tla`) are total renderings, so the
model↔code correspondence holds by construction (no hand-maintained variable→module table, unlike the
superseded doc's §2).

Invariants the model asserts (each named, checked on every reachable state; concrete failure it prevents):

- **`UniqueGatewayOwner`** — at most one cluster ever holds the wild-ingress role (no split-brain gateway).
- **`SessionAlwaysRebindable`** — no reachable transition removes the last working endpoint for a live session
  (the client-rebind property; the illegal state is [illegal_state_catalog §3.44](./illegal_state_catalog.md)).
- **`PlannedIsLossless`** — on the `Planned` branch, cutover is reachable only after `verify-caught-up`, so no
  committed write is lost (RPO=0) — the property the superseded doc left merely assumed.
- **`FailoverBounded`** — on the `Failover` branch, any divergence is named and within the declared data-loss
  budget, and the system converges to a single owner (`MergeConverges`, `NoWriteAfterStaleFailover`).

---

## 4. Simulate and prove

Both instruments read the **same** `Model`:

- **Simulate (io-sim).** The lifted pure decision core is driven by `io-classes`/`IOSimPOR`'s deterministic,
  partial-order-reduced scheduler against adversarial interleavings, asserting the same safety predicates the
  invariants name. This is the design-schedule check for both branches.
- **Prove (TLC).** `emitTLA` renders the `Model` to a spec TLC model-checks exhaustively at a bounded scope,
  reaching every invariant with no counterexample. Because the model is the value the runtime interprets, a
  green run is proven-for-the-model *about the shape the code takes*, at the bound.

Both are Register-1, in-process, needing no cluster ([conformance_harness_doctrine.md](./conformance_harness_doctrine.md)).
A validated model is green in both, and both go red under a seeded mutation (a transition that drops the fence,
or decommissions before drain-complete).

---

## 5. One-and-done, plus a per-`InForceSpec` structural fit

The protocol is proven **once**, at design time, over the bounded `Model`. TLC is **never** on the spec-decode
path. What runs per-`InForceSpec` is a fast, total **decode-time structural-fit fold** that rejects any spec
whose migration graph falls outside the proven envelope.

The envelope is bought by the DSL shape: `GatewayFailover { active, standby, dnsRecord, hubRole }` is
**pairwise** (one active + one standby per DNS record), and the decoder enforces **independence and acyclicity**
of the migration graph. An N-cluster forest then reduces to a set of independent 2-cluster instances, so a
green model-check at **scope 2 is a genuine cutoff** covering every spec the decoder accepts — the reduction
[formal_model_doctrine.md §6](./formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not)
requires before "green at scope N" generalizes.

---

## 6. Modelling bounds and honesty

Per [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline):

- **Proven-for-the-model at scope 2**, generalized by the [§5](#5-one-and-done-plus-a-per-inforcespec-structural-fit)
  pairwise cutoff. What scope 2 alone does not prove (concurrent three-way or chained migration) is exactly what
  the cutoff argument, not the raw scope, discharges; at least one over-scope run (3 clusters, chained) is
  checked to stress the cutoff assumption.
- **Abstracted premises are named as assumptions.** Real-time and clock-skew are abstracted away and monitored
  at runtime, never proven by the model; the "MinIO/Pulsar/Patroni effectively lossless" delegation ([§1](#1-the-one-obligation))
  is an assumed premise the whole reduction rests on, recorded as such.
- **Correspondence is by construction, not deferred.** Because `interpret` and `emitTLA` render one `Model`,
  there is no separate variable→module correspondence table to complete later — the inversion the superseded
  doc left "empty and UNVERIFIED until Phase 9" is dissolved. What remains for the live phase is Register-3
  chaos injection against the running forest (that the abstracted physics actually hold), never a paper
  correspondence.

---

## 7. Planning ownership

This document is normative model doctrine only. The `Model`, the io-sim harness, and the `emitTLA` model-check
are built and run in the pre-cluster formal-model phase; the live chaos injection against a running forest is a
Register-3 gate in the multi-cluster phase. Phase order, status, and gates live only in
[DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md). Every statement here is design intent, never a
tested amoebius result.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Formal Model Doctrine](./formal_model_doctrine.md) — the `Model`→{interpret, emitTLA} pattern this is an instance of
- [Gateway Migration Doctrine](./gateway_migration_doctrine.md) — the `GatewayMigration` taxonomy and the state machine this models
- [Chaos & Failover Doctrine](./chaos_failover_doctrine.md) — the Extract→Model→Inject methodology and the concentration principle
- [Daemon Topology Doctrine](./daemon_topology_doctrine.md) — the singleton is a Deployment, single-instance delegated to k8s/etcd (no election)
- [Illegal State Catalog](./illegal_state_catalog.md) — a session that cannot rebind on migration is unrepresentable
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — the Register-1 explorer + io-sim, no cluster
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
