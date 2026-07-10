# Phase 29: Multi-cluster spawn + geo-replication + gateway-migration correspondence

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_27_jitml_lift_cuda.md, DEVELOPMENT_PLAN/phase_30_provider_clusters.md, DEVELOPMENT_PLAN/phase_31_test_topology_dsl.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Turn the single-cluster control plane into a recursive forest — a parent spawns two children,
> hands each only its own `project(subtree)`, geo-replicates a workflow between the siblings — and discharge
> the Register-3 residue of amoebius's one proof obligation: drive the built `src/Amoebius/Multicluster/*`
> gateway-migration runtime through **both** a `Planned` coordinated handover (RPO=0) and a `Failover`
> emergency takeover (bounded rebind) against a live forest, and show that runtime *is* the Phase-3
> design-model's decision core.

---

## Phase Status

📋 Planned. Amoebic spawning, per-child unseal, geo-replication, the `Planned` and `Failover` gateway-migration
branches, the teardown-vs-chaos distinction, the unsatisfiable-`.dhall` push-back, and the Register-3
correspondence against the Phase-3 design-model are all specified and unstarted; every sprint below is design
intent and every prescriptive statement is a target shape, not a tested amoebius result. This phase opens after
the Phase 28 gate (the Apple-Metal host compute daemon) and runs on the **linux-cpu** substrate in **Register 3**
(live infrastructure). Where it leans on the sibling prodbox project — the gateway single-writer pattern, the
transit-seal trust tree — that is **sibling evidence, not an amoebius result**. There is **no**
First-Axis / singleton-election work here: single-instance of the control-plane singleton is a Deployment
`replicas=1` delegated to k8s/etcd, and the sole per-system obligation amoebius owns is the cross-cluster
gateway migration, both branches.

## Phase Summary

This phase crosses the line the chaos/failover doctrine calls the **Second Axis**: the moment a parent spawns a
child and the two geo-replicate, the system stops being one strongly-consistent cluster and becomes a forest
with an **asynchronous** boundary between its clusters. It does four things and stops there. First, **amoebic
spawn** — a parent provisions two child clusters (`kind`/`rke2` via SSH-key Pulumi run from inside the parent
against a Vault-enveloped MinIO backend) and hands each child exactly its own subtree: the value a child
receives is, by construction, `project(subtree)` — a typed `ChildInForceSpec` in which no sibling or
ancestor-only branch can appear — with the child's Vault unsealing in one of two sanctioned modes, its subtree
enveloped under a per-child Transit key, and named secrets injected directly into the child's Vault. Second,
**geo-replication** — the two siblings replicate a `command → event* → result` workflow over native-protocol
Pulsar, write-once content-addressed MinIO blobs, and Patroni Postgres; the bulk of that data plane is
**confluent by construction** and crosses freely, and every crossing mutable multi-record invariant is sorted
by the invariant-confluence classifier before a mechanism is chosen. Third, **the gateway-migration runtime** —
the built `src/Amoebius/Multicluster/*` modules enact the wild-ingress gateway move in both branches:
a `Planned` coordinated `quiesce → drain → verify-caught-up → cutover` that loses no committed write (RPO=0),
and a `Failover` survivor-promotion through a fail-closed freshness gate that repoints route53 and rebinds
within a declared data-loss budget, each keeping a live session bindable throughout. Fourth, **the
correspondence** — because Phase 3 rendered one reifiable `Model` into both `interpret` (the runtime decision
core) and `emitTLA` (the proven, never-committed `.tla`), the built runtime's per-edge decision *is* that
`interpret`; correspondence therefore holds by construction, and what this phase adds is the Register-3 chaos
injection against a running forest that confirms the abstracted physics (real time, clock skew, actual
replication lag, the MinIO/Pulsar/Patroni lossless delegation) actually hold — never a hand-maintained
variable→module table.

This phase consumes earlier phases and does not re-implement them: Phase 13's `pb` bootstrap of a `kind`/`rke2`
cluster, Phase 17's root Vault/PKI trust anchor, Phase 18's platform services (MinIO, Pulsar, Patroni Postgres),
Phase 19's Keycloak-owned wild ingress, Phase 20's live DSL deploy via the `replicas=1` singleton, Phase 22's
native Pulsar client, Phase 23's content-addressed store + workflow runtime, and — critically — Phase 3's
`GatewayMigration` `Model`, `interpret`, and the decode-time structural-fit fold. A **stretched cluster is not
geo-replication**: one etcd, one boundary, one `Topology` whose nodes merely span network `Site`s owes no R9
budget and no Second-Axis obligation and is out of scope here.

**Substrate:** linux-cpu — the gate spins up the parent and both child clusters as `kind`/`rke2` clusters on a
single linux-cpu host; no accelerator and no provider cluster is in scope (provider-managed clusters are
[Phase 30](phase_30_provider_clusters.md)). Partition tolerance is exercised by killing a sibling on the same
host — not a property a single root cluster exercises.

**Register:** 3 — live infrastructure: a real parent and two real child clusters, a real geo-replicated
workflow, a real DNS repoint, and adversarial fault injection against the running forest.

**Gate:** two children geo-replicate a workflow; a `Planned` handover completes with **RPO=0** (no committed
write lost, argued-design-level and drilled); killing the lead cluster mid-workflow drives a `Failover` that
promotes the surviving sibling only through its fail-closed freshness gate, repoints route53, and **rebinds
within the declared data-loss budget**; and the Phase-3 `GatewayMigration` design-model is shown to correspond
to the built `src/Amoebius/Multicluster/*` runtime — the built decision core is that model's `interpret`
(correspondence-by-construction), the Register-3 Inject drills assert the four named invariants
(`UniqueGatewayOwner`, `SessionAlwaysRebindable`, `PlannedIsLossless`, `FailoverBounded`) against the live
forest, and the run emits a proven/tested/assumed ledger recording recovery time as *tested* (drilled), the
data-loss bound as *assumed* (monitored, not proven), and the modeled safety/liveness as *proven-for-the-model
at scope 2* (a Phase-3 design result, never a runtime guarantee).

## Doctrine adopted

- [`gateway_migration_model_doctrine.md §6`](../documents/engineering/gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty)
  and [`§7`](../documents/engineering/gateway_migration_model_doctrine.md#7-planning-ownership)
  — *correspondence by construction* and *planning ownership*: because `interpret` and `emitTLA` render one
  `Model`, there is **no** separate variable→module correspondence table to complete; what remains for the live
  phase is the Register-3 chaos injection against a running forest (that the abstracted physics hold), and this
  phase is exactly that gate. It also inherits the [`§1`](../documents/engineering/gateway_migration_model_doctrine.md#1-the-one-obligation)
  one-obligation framing (no First-Axis election model) and the [`§5`](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)
  scope-2 pairwise cutoff the built forest must stay inside.
- [`gateway_migration_doctrine.md §2`](../documents/engineering/gateway_migration_doctrine.md#2-the-planned-branch--a-coordinated-strong-consistency-handover)
  and [`§3`](../documents/engineering/gateway_migration_doctrine.md#3-the-failover-branch--an-availability-first-emergency-takeover)
  — the two arms of `GatewayMigration = <Planned | Failover>`: the coordinated strong-consistency handover
  (RPO=0, argued-design-level) and the availability-first emergency takeover (RPO>0, bounded by the data-loss
  budget, reconciling to a single owner) — with the client-rebind protocol of
  [`§4`](../documents/engineering/gateway_migration_doctrine.md#4-client-rebind--a-live-session-must-always-find-the-gateway)
  and the typed, edge-observed state machine of
  [`§5`](../documents/engineering/gateway_migration_doctrine.md#5-the-migration-as-a-typed-edge-observed-state-machine)
  built as the effectful shell around the Phase-3 decision core, honest per
  [`§6`](../documents/engineering/gateway_migration_doctrine.md#6-honesty-and-layer-markers).
- [`chaos_failover_doctrine.md §16`](../documents/engineering/chaos_failover_doctrine.md#16-the-second-axis--when-one-cluster-becomes-a-forest),
  [`§17`](../documents/engineering/chaos_failover_doctrine.md#17-the-boundary-and-its-classifier),
  [`§18`](../documents/engineering/chaos_failover_doctrine.md#18-the-rules-scale-to-the-boundary),
  and [`§19`](../documents/engineering/chaos_failover_doctrine.md#19-the-cross-boundary-ledger-and-conformance-rows)
  — the Second Axis: the invariant-confluence classifier (R1/§17), the fail-closed promotion-freshness gate and
  active-merge reconciliation (R7), the named-bounded-monitored replication lag (R8), and the two-dimensional
  failover budget — bounded permanent data loss and bounded recovery time (R9) — with the
  [Inject move (§11)](../documents/engineering/chaos_failover_doctrine.md#11-move-iii--inject-break-the-running-thing-on-purpose)
  run against the running forest and the [proven/tested/assumed ledger (§12)](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
  kept honest. The doctrine works this exact shape through in its
  [Appendix B](../documents/engineering/chaos_failover_doctrine.md#appendix-b--worked-example-fenced-cross-cluster-geo-replication-failover-the-open-cross-cluster-failover-question)
  worked example; this phase realizes it live.
- [`cluster_lifecycle_doctrine.md §3`](../documents/engineering/cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest),
  [`§5`](../documents/engineering/cluster_lifecycle_doctrine.md#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction),
  [`§6`](../documents/engineering/cluster_lifecycle_doctrine.md#6-push-back-when-teardown-would-break-the-root-inforcespec),
  and [`§9`](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)
  — the `project(subtree)` handoff, the central distinction between a lossless teardown-with-cleanup and a
  bounded-loss chaos-failover, and the declarative push-back on a teardown that would make the root `InForceSpec`
  unsatisfiable — all enacted as `discover → diff → enact → re-observe` reconciles over a managed-resource
  registry, never a bespoke lifecycle state machine.
- [`vault_pki_doctrine.md §6`](../documents/engineering/vault_pki_doctrine.md#6-parentchild-unseal-two-sanctioned-modes)
  and [`§7`](../documents/engineering/vault_pki_doctrine.md#7-parent-injects-secrets-into-the-childs-vault)
  — the recursive parent/child spawn unseal (self-unseal from a k8s secret, or parent-held unlock with the brick
  cascading down a sealed subtree), the per-child Transit key (`transit/amoebius-<child-id>-config`) that makes a
  sibling's subtree cryptographically undecryptable even under an unsealed parent, and the
  parent-injects-named-secrets path (Dhall names only; the parent materializes the bytes).
- [`content_addressing_doctrine.md §5`](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely)
  — the confluent data plane: content-addressed write-once blobs (identical content ⇒ identical key ⇒ idempotent
  cross-cluster write) and the work-id-keyed Pulsar fold land in bucket (i) and cross freely, leaving only the
  gateway authority and any CAS "latest" pointer in bucket (ii) for the migration runtime.
- [`testing_doctrine.md §3`](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down)
  (the test-as-`InForceSpec` spin-up → run → always-tear-down contract) and §4 (the per-run
  proven/tested/assumed ledger): the register this gate reaches and the ledger it emits.

## Sprints

## Sprint 29.1: Amoebic spawn — `project(subtree)` handoff + per-child unseal / Transit key / secret injection 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Multicluster/Spawn.hs`, `src/Amoebius/Dsl/ChildInForceSpec.hs`,
`pulumi/child-cluster/Pulumi.yaml`, `src/Amoebius/Multicluster/ChildUnseal.hs`,
`src/Amoebius/Vault/TransitChildKey.hs`, `src/Amoebius/Multicluster/SecretInjection.hs` — target paths, not yet
built.
**Blocked by**: Phase 13 (bootstrap a `kind`/`rke2` cluster idempotently); Phase 17 (root Vault/PKI trust
anchor); Phase 20 (the Dhall DSL deploy via the `replicas=1` singleton, and Pulumi-from-inside with a
Vault-enveloped MinIO backend).
**Independent Validation**: a parent spawns two child `kind` clusters from inside itself; each child comes up
empty and reconciles toward its spec; the child's received value is shown — at the type level — to be
`project(subtree)` with no field carrying a sibling or ancestor-only branch; each child unseals in each of the
two sanctioned modes; child A's subtree ciphertext fails to decrypt under child B's Transit key even with the
parent's Vault unsealed; and a named `SecretRef` resolves to bytes the parent injected, never from a Dhall
fragment or an env var.
**Docs to update**: `documents/engineering/cluster_lifecycle_doctrine.md`,
`documents/engineering/vault_pki_doctrine.md`, `documents/engineering/pulumi_iac_doctrine.md`,
`documents/engineering/dsl_doctrine.md`.

### Objective
Adopt [`cluster_lifecycle_doctrine.md §3`](../documents/engineering/cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest)
and [`vault_pki_doctrine.md §6`](../documents/engineering/vault_pki_doctrine.md#6-parentchild-unseal-two-sanctioned-modes)/[`§7`](../documents/engineering/vault_pki_doctrine.md#7-parent-injects-secrets-into-the-childs-vault):
implement the spawn as a Pulumi deploy run from inside an existing cluster, tracked in a Vault-enveloped MinIO
backend, delivering the structural `project(subtree)` projection so a child receives exactly its own subtree
and nothing about siblings, with per-child unseal, a per-child Transit key, and parent→child secret injection.

### Deliverables
- A `ChildInForceSpec` type that is, by construction, the projection of a parent spec onto one subtree — no
  field admits a sibling or ancestor-only branch, and a grandchild path proves the projection composes to
  arbitrary depth.
- A `spawnChild` action: SSH-key (`kind`/`rke2`) Pulumi deploy from inside the parent, registered as a typed
  managed resource carrying its own `discover`/`destroy`.
- A `SealMode` (`SelfUnseal` | `ParentHeldUnlock`) decoded from the child `.dhall`, per-child Transit key
  provisioning with a decrypt-on-that-key-alone policy, and an `injectSecret` action materializing named
  secrets into the child's Vault (in-cluster consumers read via Vault k8s auth).

### Validation
1. A parent brings up two empty child `kind` clusters on linux-cpu; re-running the spawn is a no-op; there is no
   total function producing a `ChildInForceSpec` containing a sibling's branch; mode (b) bricks with the parent
   sealed and unseals with it available; cross-child Transit decrypt fails.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 29.2: Geo-replication of two siblings + invariant-confluence classification 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Multicluster/GeoReplication.hs`, `src/Amoebius/Multicluster/ConfluenceClass.hs`
— target paths, not yet built.
**Blocked by**: Sprint 29.1; Phase 22 (native Pulsar client, CBOR); Phase 23 (content-addressed store + workflow
runtime); Phase 18 (MinIO + Patroni Postgres).
**Independent Validation**: two sibling children replicate a `command → event* → result` workflow over
native-protocol Pulsar geo-replication, write-once content-addressed MinIO blobs, and Patroni Postgres; a
duplicate cross-cluster write is shown idempotent; every crossing mutable multi-record invariant is sorted by
the §17 classifier into confluent (crosses freely) or non-confluent (held by bounded authority), an
unclassified invariant defaulting to non-confluent.
**Docs to update**: `documents/engineering/chaos_failover_doctrine.md`,
`documents/engineering/content_addressing_doctrine.md`, `documents/engineering/platform_services_doctrine.md`.

### Objective
Adopt [`chaos_failover_doctrine.md §17`](../documents/engineering/chaos_failover_doctrine.md#17-the-boundary-and-its-classifier)
over the confluent data plane of
[`content_addressing_doctrine.md §5`](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely):
wire asynchronous geo-replication between two siblings and run the invariant-confluence test (R1) on every
crossing mutable invariant *before* assigning a mechanism — so content-addressed blobs and the work-id-keyed
Pulsar log cross freely, while the gateway authority and any CAS "latest" pointer are correctly held in bucket
(ii) for the migration runtime.

### Deliverables
- Pulsar geo-replication (native binary protocol, no WebSockets) between two siblings, with the consumer
  decision a **pure fold keyed by a replication-surviving work-id** that absorbs duplication, reordering, and
  late-after-heal arrival (R3 cross-boundary).
- Content-addressed write-once MinIO blob replication (idempotent duplicate cross-cluster write) and Patroni
  Postgres replication for relational state.
- A `ConfluenceClass` value per crossing invariant — confluent (deterministic total merge) vs non-confluent
  (singleton claim/yield, escrow/reservation, or disjoint-namespace allocation) — with the unclassified default
  = non-confluent, rejecting an "active-active on a non-confluent invariant" wiring.

### Validation
1. A workflow round-trips between the two siblings; replaying a duplicate or reordered batch produces the same
   fold result (exactly-once for replicated-or-recovered effects); the classifier refuses active-active on a
   non-confluent invariant.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 29.3: The gateway-migration runtime — both branches over the Phase-3 `interpret` core 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Multicluster/GatewayMigration.hs` (the effectful orchestrator whose per-edge
decision delegates to the Phase-3 `src/Amoebius/Formal/GatewayMigration.hs` `interpret`),
`src/Amoebius/Multicluster/PlannedHandover.hs`, `src/Amoebius/Multicluster/PromotionGate.hs`,
`src/Amoebius/Multicluster/DnsRepoint.hs`, `src/Amoebius/Multicluster/ClientRebind.hs` — target paths, not yet
built.
**Blocked by**: Sprint 29.2; Phase 3 (the `GatewayMigration` `Model` + `interpret` + structural-fit fold);
Phase 19 (Keycloak-owned wild ingress via the LB + Gateway API).
**Independent Validation**: a `Planned` handover drives the ordered edge-observed state machine
(`stand-up-replica → quiesce → drain / verify-caught-up → promote → source-proxy + repoint DNS → unfreeze →
drain-monitor → decommission`) and loses no committed write (RPO=0), the old gateway serving as a transparent
proxy for the whole DNS-drain window so a live session always has a working endpoint; a `Failover` promotes the
survivor *only after* its freshness gate proves a known commit watermark (or holds a fence), then repoints
route53, accounting for the un-replicated suffix **only** by the R9 data-loss budget, never silently resolved to
"absent."
**Docs to update**: `documents/engineering/gateway_migration_doctrine.md`,
`documents/engineering/chaos_failover_doctrine.md`, `documents/engineering/pulumi_iac_doctrine.md`.

### Objective
Adopt [`gateway_migration_doctrine.md §2`](../documents/engineering/gateway_migration_doctrine.md#2-the-planned-branch--a-coordinated-strong-consistency-handover)/[`§3`](../documents/engineering/gateway_migration_doctrine.md#3-the-failover-branch--an-availability-first-emergency-takeover),
the client-rebind protocol of [`§4`](../documents/engineering/gateway_migration_doctrine.md#4-client-rebind--a-live-session-must-always-find-the-gateway),
and the R7/R8/R9 cross-boundary rules of
[`chaos_failover_doctrine.md §18`](../documents/engineering/chaos_failover_doctrine.md#18-the-rules-scale-to-the-boundary):
build the effectful gateway-migration shell for **both** branches whose every branch decision is the Phase-3
pure `interpret` value (a *liveness* coercion is licensed; a *durability* claim is forbidden — the tail beyond
the watermark stays a typed `NotYetObserved`), so the runtime realizes the proven model rather than re-deriving
it.

### Deliverables
- A `Planned` coordinated `quiesce → drain → verify-caught-up → cutover` (repoint the gateway DNS record, the
  WireGuard hub role, and the apiserver VPN-IP, then unfreeze) whose `decommission(source-ingress)` edge is
  reachable only from an observed `drain-monitor` edge, so no transition removes the last working endpoint.
- A `Failover` fail-closed `PromotionGate`: the survivor promotes only on a proven commit watermark or a held
  fence, trading recovery time (R9 RTO) for zero divergence beyond the already-lost suffix; a route53 repoint via
  Pulumi-from-inside; and a deterministic, total, timestamp-free merge of the non-confluent CAS "latest" pointer
  on failback.
- The client-rebind mechanisms — old-gateway transparent proxy, a low steady-state DNS TTL, stable per-cluster
  addresses, and the 307 fallback — plus an exported live-lag monitor (R8) and a declared `DataLossBudget` =
  (data-loss window, recovery time).

### Validation
1. A `Planned` handover under a live workflow moves authority with measured loss = 0 and a session that never
   loses its endpoint; a `Failover` after killing the lead resumes through one authority with measured loss ≤
   the data-loss window and authority transfer within the recovery-time bound; driving lag past the bound makes
   the freshness gate refuse to promote and the lag monitor alarm before a breach.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 29.4: Teardown-with-cleanup vs chaos-failover + unsatisfiable-`.dhall` push-back 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Multicluster/Teardown.hs`, `src/Amoebius/Multicluster/Pushback.hs` — target
paths, not yet built.
**Blocked by**: Sprint 29.1; Sprint 29.3 (a clean gateway handoff is part of a graceful teardown).
**Independent Validation**: a graceful teardown of a child drains workloads, flushes Pulsar/MinIO/Postgres
replication to a synchronization event, hands off the gateway (a `Planned` migration), and releases compute while
preserving retained `no-provisioner` PVs — losing nothing; a teardown that would make the root `InForceSpec`
unsatisfiable pushes back, names what stops working and the declared failback, and proceeds only under an
explicit override.
**Docs to update**: `documents/engineering/cluster_lifecycle_doctrine.md`,
`documents/engineering/storage_lifecycle_doctrine.md`.

### Objective
Adopt [`cluster_lifecycle_doctrine.md §5`](../documents/engineering/cluster_lifecycle_doctrine.md#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction)/[`§6`](../documents/engineering/cluster_lifecycle_doctrine.md#6-push-back-when-teardown-would-break-the-root-inforcespec),
enacted as the reconciler of
[`§9`](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine):
implement a graceful teardown as a controlled handoff that is lossless by construction, and the declarative
push-back that refuses — by default — a teardown that would leave the persistent global `.dhall` unsatisfiable,
with an explicit operator override the only escape.

### Deliverables
- A `gracefulTeardown` reconcile: idempotent drain/flush/handoff ordering timed to a synchronization event,
  releasing compute and preserving retained PVs so a later spin-up rebinds the same bytes.
- A `satisfiability` check over the root `InForceSpec` using each container's declared CPU/RAM: if the surviving
  forest can no longer satisfy the spec without cluster C, push back naming the loss and the `.dhall` failback,
  with the same fail-closed `Unreachable → refuse` posture as the reconciler.
- A managed-resource registry entry per cluster/child/node/stack/PV so teardown is one `reconcileAbsent` loop
  with "cannot observe" never collapsed to "absent."

### Validation
1. A graceful child teardown loses nothing (rides a sync event, preserves PVs) and a later spin-up rebinds the
   identical shape and bytes; a teardown of a load-bearing cluster pushes back and aborts by default, and the
   explicit override falls to the declared failback; a graceful teardown and a chaos-failover are observably
   distinct — lossless-by-construction vs bounded-by-budget — and the code reports which guarantee held.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 29.5: Register-3 correspondence — Inject drills against the running forest + live gate `.dhall` + ledger 📋

**Status**: Planned
**Implementation**: `test/dhall/phase_29_gateway_migration.dhall` (the live gate topology) and
`test/inject/GatewayMigrationForest.hs` (the Register-3 Inject harness re-using the Phase-3 named invariants
against the built runtime) — target paths, not yet built. The Phase-3 `GatewayMigration` `Model`, its `emitTLA`
proof, and its io-sim agreement were authored and discharged in Phase 3; this sprint consumes them, it does not
re-author them.
**Blocked by**: Phase 3 (the proven-for-the-model `GatewayMigration` `Model` + `interpret` + structural-fit
fold); Sprint 29.2; Sprint 29.3; Sprint 29.4.
**Independent Validation**: the built `src/Amoebius/Multicluster/*` decision core is shown to be the Phase-3
`interpret` (correspondence-by-construction — no variable→module table, per the superseded framing's reversal);
the Register-3 Inject drills (cut replication, kill the lead mid-`Planned`-handover, kill the lead with no drain
to force `Failover`, drive lag past the bound, fail back with late + duplicate arrivals) run against the live
forest and assert the four named invariants (`UniqueGatewayOwner`, `SessionAlwaysRebindable`,
`PlannedIsLossless`, `FailoverBounded`); and `phase_29_gateway_migration.dhall` spins the forest up, runs both
branches, asserts RPO=0 for `Planned` and measured loss ≤ the budget for `Failover`, tears down leak-free, and
emits a proven/tested/assumed ledger.
**Docs to update**: `documents/engineering/gateway_migration_model_doctrine.md`,
`documents/engineering/chaos_failover_doctrine.md`, `documents/engineering/testing_doctrine.md`.

### Objective
Adopt [`gateway_migration_model_doctrine.md §6`](../documents/engineering/gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty)/[`§7`](../documents/engineering/gateway_migration_model_doctrine.md#7-planning-ownership):
because correspondence holds by construction (one `Model` → `interpret` + `emitTLA`), run the deferred
Register-3 residue — the [Inject move (§11)](../documents/engineering/chaos_failover_doctrine.md#11-move-iii--inject-break-the-running-thing-on-purpose)
against the running forest confirming the abstracted physics actually hold — as the test-`.dhall` of
[`testing_doctrine.md §3`](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down),
ledgered per [`chaos_failover_doctrine.md §12`](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
and [`§19`](../documents/engineering/chaos_failover_doctrine.md#19-the-cross-boundary-ledger-and-conformance-rows).

### Deliverables
- The Register-3 Inject drill set run in the inter-cluster dimension against the running forest, asserting the
  Phase-3 named invariants — the concrete confirmation that the built runtime, which *is* the model's
  `interpret`, upholds under real physics what the model proves in logical time (never a re-authored TLA+ spec,
  never a paper variable→module table).
- `test/dhall/phase_29_gateway_migration.dhall`: spin two children up, geo-replicate, run a `Planned` handover
  asserting RPO=0, kill the lead to force `Failover` asserting rebind within budget, reconcile divergent
  histories, and always tear down leak-free — emitting the per-run ledger artifact.
- A per-run proven/tested/assumed ledger that marks `Planned` RPO=0 **argued-design-level + drilled (tested)**,
  the `Failover` recovery time + reconciliation **tested (drilled)**, the data-loss / replication-lag bound
  **assumed (monitored, never proven)**, and the modeled safety/liveness **proven-for-the-model at scope 2**
  (Phase-3, a design-layer result) — and never reports an assumed-and-monitored result as proven.

### Validation
1. The built decision core resolves to the Phase-3 `interpret` with no orphaned modeled action; the Inject drills
   run against the live forest and pass; `phase_29_gateway_migration.dhall` reports RPO=0 for `Planned` and
   measured loss ≤ budget for `Failover`, and tears down leak-free; the ledger classifies every result honestly.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/gateway_migration_model_doctrine.md` — flip §6's Register-3 chaos-injection residue to
  *run against a live forest* for both branches, recording that correspondence held by construction (the built
  runtime is `interpret`) and that no variable→module table was needed; keep the abstracted premises assumed.
- `documents/engineering/gateway_migration_doctrine.md` — backlink §2/§3/§4/§5 to the built
  `src/Amoebius/Multicluster/*` runtime; confirm `Planned` RPO=0 stayed argued-design-level (now drilled) and
  `Failover` stayed bounded-by-budget.
- `documents/engineering/chaos_failover_doctrine.md` — the §19 cross-boundary ledger and the §15/§19 conformance
  rows gain an amoebius-tested linux-cpu datapoint (recovery-time drilled, data-loss assumed), so the matrix
  stops resting on prodbox sibling-evidence alone; cross-reference the realized `Multicluster/*` module paths.
- `documents/engineering/cluster_lifecycle_doctrine.md` — §3/§5/§6/§9 gain the realized module paths for the
  spawn, the teardown-vs-chaos distinction, the push-back, and the reconciler/registry.
- `documents/engineering/vault_pki_doctrine.md` — §6/§7 gain the realized per-child Transit-key and
  secret-injection module paths (prodbox's transit-seal tree remains the evidence, not the proof).
- `documents/engineering/pulumi_iac_doctrine.md` — record the child-cluster spawn program and the route53
  failover repoint as realized DNS-failover / spawn owners.
- `documents/engineering/testing_doctrine.md` — record the Register-3 Inject + live-gate ledger this phase emits.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-29 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/system_components.md` — register the `src/Amoebius/Multicluster/*` modules,
  `src/Amoebius/Vault/TransitChildKey.hs`, `src/Amoebius/Dsl/ChildInForceSpec.hs`, and the Register-3 Inject +
  gate suites as Phase-29 rows.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-29 → linux-cpu row in the per-phase substrate map.

## Related Documents
- [README.md](README.md) — the live tracker; Phase 29 objective, gate, and substrate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — target architecture and the one-formal-obligation constraint
- [system_components.md](system_components.md) — target component inventory (the `Multicluster/*` module paths)
- [substrates.md](substrates.md) — substrate registry and per-phase map
- [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) — the one obligation, both branches, correspondence-by-construction, and the Register-3 chaos residue this phase discharges
- [Gateway Migration Doctrine](../documents/engineering/gateway_migration_doctrine.md) — the `GatewayMigration = <Planned | Failover>` taxonomy, client rebind, and the typed edge-observed state machine
- [Chaos & Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the invariant-confluence Second Axis, the Inject move, and the proven/tested/assumed cross-boundary ledger
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — amoebic spawning, teardown-vs-chaos, and push-back
- [Vault, PKI & Secret Injection Doctrine](../documents/engineering/vault_pki_doctrine.md) — parent/child unseal + per-child Transit keys + secret injection
- [phase_03](phase_03_gateway_migration_model.md) — the `GatewayMigration` design-model whose Register-3 correspondence against the built forest is discharged here
- [phase_28](phase_28_apple_metal_host_daemon.md) — the prior phase; its gate opens this one
- [phase_30](phase_30_provider_clusters.md) — the next phase; the forest extended to provider-managed clusters
