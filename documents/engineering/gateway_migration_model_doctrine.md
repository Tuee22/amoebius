# The Gateway-Migration Model: amoebius's one proof obligation

**Status**: Authoritative source
**Supersedes**: documents/engineering/tla_modelling_assumptions.md
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_33_gateway_migration_drills.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/tla_modelling_assumptions.md, documents/illegal_state/illegal_state_multicluster.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: Single source of truth for the *one* protocol amoebius proves itself — the cross-cluster **gateway migration**, covering **both** branches of `GatewayMigration = <Planned | Failover>` — expressed as a reifiable `Model` ([formal_model_doctrine.md](./formal_model_doctrine.md)), **simulated** with io-sim and **proven** with TLC, and reduced to every `InForceSpec` by a decode-time structural-fit fold rather than any per-spec model-check.

---

## 1. The one obligation

Amoebius delegates almost every consensus problem to a system that already discharges it, and does not re-prove
it ([chaos_failover_doctrine.md](./chaos_failover_doctrine.md)):

- **Intra-cluster replicated state** — object storage, the message log, the SQL primary — is delegated to
  **MinIO**, **Pulsar/BookKeeper**, and **Percona/Patroni Postgres**.
- **Single-writer authority of the control-plane singleton** is delegated to **k8s/etcd**: the singleton is a
  Deployment `replicas=1` protected by the mandatory reconciler `Lease`
  ([daemon_topology_doctrine.md §3](./daemon_topology_doctrine.md#3-the-control-plane-singleton)). There is
  **no bespoke leader election** — amoebius does not duplicate etcd, and there is no First-Axis
  singleton-election model to prove.

What is left — the single place a per-system proof obligation concentrates on amoebius itself — is the
**asynchronous cross-cluster gateway migration**: moving the wild-ingress gateway between clusters and
repointing DNS, across geo-replication lag, without stranding a live session or admitting two owners. etcd
cannot cover it because it spans clusters. This is the *only* boundary this model targets, and it is the
**main focus of amoebius's simulation and proofs**.

Both branches are in scope. The prior framing (`tla_modelling_assumptions.md`, now superseded) scoped the
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
superseded doc).

The model asserts properties of **two kinds** — safety (nothing bad ever happens; checked on every reachable
state) and liveness (something good eventually happens; a temporal `modelProperties` goal checked by TLC under a
named fairness assumption `F`, per [formal_model_doctrine.md §2–§3](./formal_model_doctrine.md#2-the-model-is-data)).
The distinction is load-bearing here: the anti-split-brain guarantee is *both* "never two owners" (safety) *and*
"eventually exactly one owner" (liveness) — a stalled state with **zero** owners satisfies the first and violates
the second, so safety alone would not catch a failover that deadlocks.

**Safety invariants** (`modelInvariants`, concrete failure each prevents):

- **`UniqueGatewayOwner`** — at most one cluster ever holds the wild-ingress role (no split-brain gateway).
- **`SessionAlwaysRebindable`** — no reachable transition removes the last working endpoint for a live session
  (the client-rebind property; the illegal state is [illegal_state_catalog §3.44](../illegal_state/illegal_state_catalog.md)).
- **`PlannedIsLossless`** — on the `Planned` branch, cutover is reachable only after `verify-caught-up`, so no
  committed write is lost (RPO=0) — the property the superseded doc left merely assumed.
- **`NoWriteAfterStaleFailover`** — on the `Failover` branch, any divergence is named and within the declared
  data-loss budget (the safety half of the old `FailoverBounded`).
- **`NoTakeWithoutProvenFreshness`** — no cluster takes the wild-ingress role from a data plane whose freshness
  is unproven. The `Planned` branch's `verify-caught-up` precondition is **generalized** to a `FreshnessWitness`
  guard on the promote / gateway-take transition, dischargeable two ways: a warm replica proven caught up (the
  original `PlannedIsLossless` path), or a cold secondary seeded from backup and proven fresh within its
  declared `freshnessBound` (the `ColdSeedFromBackup` recovery source owned by
  [consistency_pacelc_doctrine.md §3.7](./consistency_pacelc_doctrine.md#37-the-cold-dr-seed-recovery-source) and
  [backup_recovery_doctrine.md §8](./backup_recovery_doctrine.md#8-the-gateway-dovetail-seed-from-backup-under-consistency-over-availability)).
  This is the safety face of the consistency-over-availability choice: a stalled state with **zero** gateway
  owners satisfies this invariant (staying down is safe), and only the liveness `MergeConverges` goal requires
  freshness to become reachable — so a secondary whose seeded state cannot prove freshness never takes the
  gateway, and the pairing stays down rather than serving stale data. The illegal state is
  [illegal_state_catalog §3.69](../illegal_state/illegal_state_multicluster.md#369-a-cold-seeded-secondary-taking-the-gateway-without-proven-freshness).

**Liveness properties** (`modelProperties`, under the fairness assumption `F` — every continuously-enabled
migration action eventually fires, i.e. no cluster is starved by an adversarial scheduler; `F` is a named
*assumed* premise, [formal_model_doctrine.md §6](./formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not)):

- **`MergeConverges`** — after a `Failover` and a heal, the forest *eventually* reconverges to exactly one
  owner (`ownerCount ~> ownerCount = 1`) — the convergence a safety invariant cannot express.
- **`SessionEventuallyRebinds`** — a session on the losing endpoint *eventually* rebinds to the survivor
  (the liveness face of bounded rebind; the real-time *bound* itself is an R8 assumed premise, monitored at
  runtime, never proven by the model).

Because liveness is TLC-only ([formal_model_doctrine.md §3](./formal_model_doctrine.md#3-two-total-renderings)),
each `modelProperties` goal carries a **fairness-sensitivity check**: it must go red when `F` is removed, proving
the fairness annotation is load-bearing and the property is not vacuously true.

---

## 4. Simulate and prove

Both instruments read the **same** `Model`:

- **Simulate (io-sim).** The lifted pure decision core is driven by `io-classes`/`IOSimPOR`'s deterministic,
  partial-order-reduced scheduler against adversarial interleavings, asserting the same safety predicates the
  invariants name. This is the design-schedule check for both branches.
- **Prove (TLC).** `emitTLA` renders the `Model` to a spec TLC model-checks exhaustively at a bounded scope,
  reaching every safety invariant with no counterexample **and** every liveness `PROPERTY` under the fairness
  `F`. Because the model is the value the runtime interprets, a green run is proven-for-the-model *about the
  shape the code takes*, at the bound. Liveness is a TLC-only verdict — the io-sim and explorer readings assert
  the *safety* predicates only ([formal_model_doctrine.md §3](./formal_model_doctrine.md#3-two-total-renderings)).

Both are Register-1, in-process, needing no cluster ([conformance_harness_doctrine.md](./conformance_harness_doctrine.md)).
A validated model is green in both, and both go red under a seeded mutation (a transition that drops the fence,
or decommissions before drain-complete).

---

## 5. One-and-done, plus a per-`InForceSpec` structural fit

The protocol is proven **once**, at design time, over the bounded `Model`. TLC is **never** on the spec-decode
path. What runs per-`InForceSpec` is a fast, total **decode-time structural-fit fold** that rejects any spec
whose migration graph falls outside the proven envelope.

The envelope is bought by the DSL shape: `GatewayFailover { active, standby, dnsRecord, hubRole }` is the
per-migration record the decoder folds into a migration graph, which the fold then bounds on two axes — graph
**shape** and a declared **parameter envelope**.

**The migration graph, precisely.** Each `InForceSpec` decodes to a directed labelled graph *G = (V, E)*: the
**vertices** *V* are the forest's clusters, and each **edge** is one migration — a directed edge from the
`active` cluster to the `standby` cluster labelled `(active, standby, dnsRecord, hubRole)`, carrying the DNS
record it repoints and the hub role it moves. The fold accepts *G* only when it is:

- **pairwise** — each `dnsRecord` labels **at most one** edge (one active + one standby per record);
- **acyclic** — the directed edge relation has no cycle (no chain of hand-offs loops back onto a cluster);
- **independent** — **both** graph-independence **and** resource-independence. Two edges are graph-independent
  iff their `dnsRecord`s differ and no reachable interleaving of their transitions requires one vertex to hold
  the wild-ingress role for two records at once. They are resource-independent iff **no cluster is reused as
  `active` or `standby` across two DNS records**. The fold requires both, and therefore **rejects
  cluster-reuse-across-records**, not only cycle and pairing structure.

  Rejecting the shared survivor is the deliberate strict reading. A shared vertex would be admissible only
  under the shared-resource premise of the honest limit below — an *assumed* premise, not a proven one — so
  admitting it would let the decoder accept specs the scope-2 proof does not cover on the strength of an
  assumption. The fold instead admits only what the proof reaches. The cost is stated in
  [§6](#6-modelling-bounds-and-honesty): the shared-survivor topology is **not expressible** in an accepted
  spec, and remains a named deferred obligation gated on the decomposition lemma.

**The parameter envelope, not only the graph shape.** Graph shape alone does not carry the scope-2 proof: that
proof was discharged over specific `CONSTANTS` — a declared per-branch **data-loss budget**, a bounded **TTL
regime**, and the replication-**offset**/log domains the state variables range over — and an accepted instance
whose parameters fall outside those constants is **not** covered by it even when its graph is
pairwise/acyclic/independent. The fold therefore checks each instance against a declared **parameter envelope**
as well as the graph: every edge's `Failover` data-loss budget lies within the proven cap, its `dnsRecord` TTL
lies within the modelled TTL regime, every `ColdSeedFromBackup` edge's `freshnessBound` lies within the
modelled freshness regime the `NoTakeWithoutProvenFreshness` guard was proven over, and its clusters'
offset/log domains instantiate (lie within) the model's `CONSTANTS`. A spec that fits the graph but exceeds the
parameter envelope is rejected, so the scope-2 proof's parameter side-conditions transfer to every accepted
instance rather than being silently assumed.

An N-cluster forest that passes both checks then reduces to a set of independent 2-cluster instances, so a
green model-check at scope 2 is **an argued cutoff, stress-tested** — covering every spec the decoder accepts —
the reduction
[formal_model_doctrine.md §6](./formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not)
requires before "green at scope N" generalizes.

**The honest limit of the cutoff (do not overclaim it).** Rejecting cluster reuse removes the *shared-cluster*
interaction from the accepted set, but it does **not** make accepted instances resource-independent in general.
Two vertex-disjoint 2-cluster instances still interact through infrastructure the graph does not model — one
route53 hosted zone and its write rate-limit, one Vault, one commit log. The scope-2 cutoff is sound only if
those remaining shared-resource interactions are genuinely absent or themselves confluent, and **that is an
assumed premise, not a proven one**. The strict fold therefore narrows the assumption rather than discharging
it: it removes the one shared-resource class the decoder can see, and leaves the classes it cannot.

Two things keep the residue honest, and neither may be reported as more than it is: (a) the **decomposition
lemma** — that the N-instance product refines the 2-instance model under the decoder's independence predicate —
is a named obligation, discharged either by a machine-checked proof (TLAPS/Lean,
[formal_model_doctrine.md §4](./formal_model_doctrine.md#4-correspondence-by-construction)) or by an over-scope
TLC run (scope 3–4) that **models the shared resources in**; (b) until either lands, at least one over-scope
stress run (3 clusters, chained) is checked ([§6](#6-modelling-bounds-and-honesty)) and the cutoff is recorded
**argued/tested**, never *proven*.

---

## 6. Modelling bounds and honesty

Per [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline):

- **Proven-for-the-model at scope 2**, generalized by the [§5](#5-one-and-done-plus-a-per-inforcespec-structural-fit)
  pairwise cutoff. What scope 2 alone does not prove (concurrent three-way or chained migration) is exactly what
  the cutoff argument, not the raw scope, discharges; at least one over-scope run (3 clusters, chained) is
  checked to stress the cutoff assumption.
- **Abstracted premises are named as assumptions.** Real-time and clock-skew are abstracted away and monitored
  at runtime, never proven by the model; the "MinIO/Pulsar/Patroni effectively lossless" delegation ([§1](#1-the-one-obligation))
  is an assumed premise the whole reduction rests on, recorded as such. Two further premises are named
  explicitly: the **liveness fairness `F`** ([§3](#3-the-model)) — the scheduler eventually fires every
  continuously-enabled action — which the `MergeConverges`/`SessionEventuallyRebinds` proofs rest on; and the
  **shared-resource independence** the scope-2 cutoff assumes ([§5](#5-one-and-done-plus-a-per-inforcespec-structural-fit)).
- **The shared-survivor topology is a named deferred obligation, not a supported shape.** Because [§5](#5-one-and-done-plus-a-per-inforcespec-structural-fit)'s
  independence predicate rejects cluster-reuse-across-records, a forest in which one survivor stands by for two
  DNS records **has no accepted spec**. The exclusion is deliberate: admitting it would rest on the
  shared-resource premise above, which is assumed rather than proven. It is revisitable only once the
  decomposition lemma is discharged, and until then the shape is unavailable rather than unsound. The
  over-scope stress run still *models* a shared survivor in, so the stress model retains the ability to detect
  a cutoff violation the fold now forecloses.
- **Correspondence is by construction; runtime fidelity is bridged, not only sampled.** Because `interpret` and
  `emitTLA` render one `Model`, there is no separate variable→module correspondence table to complete later —
  the inversion the superseded doc left "empty and UNVERIFIED until Phase 32" is dissolved. The residual
  **runtime-fidelity** obligation (that the effectful daemon only takes transitions the `Model` sanctions) is
  discharged in two stages, not one: **trace validation**
  ([formal_model_doctrine.md §8](./formal_model_doctrine.md#8-trace-validation-the-earlier-codemodel-bridge)) —
  the daemon's observed transition log is checked step-by-step against the emitted spec's `Next` relation —
  runs first in **Register 2.5** against the deterministically-simulated daemon
  ([deterministic_simulation_doctrine.md](./deterministic_simulation_doctrine.md)) and then in **Register 3**
  against the running forest, so the code↔model bridge is a formal, early check rather than only sampled chaos.
  What remains genuinely live-only is that the abstracted physics (real replication lag, clock skew) actually
  hold — Register-3, never a paper correspondence.

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
- [Illegal State Catalog](../illegal_state/illegal_state_catalog.md) — a session that cannot rebind on migration is unrepresentable
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — the Register-1 explorer + io-sim, no cluster
- [Deterministic Simulation Doctrine](./deterministic_simulation_doctrine.md) — the Register-2.5 io-sim environment where the runtime-fidelity trace-validation runs before the Register-3 forest
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
