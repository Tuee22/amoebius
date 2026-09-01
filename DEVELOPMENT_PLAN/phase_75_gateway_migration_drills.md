# Phase 75: Gateway-migration drills + model-correspondence

> **Purpose**: Target the Register-3 residue of amoebius's one proof obligation — drive the future Haskell
> gateway-migration runtime through **both** a `Planned` coordinated handover (RPO=0) and a `Failover`
> emergency takeover (bounded rebind) against the future [Phase 74](phase_74_multicluster_spawn_georepl.md)
> forest, then compare its trace with the Phase-17 model. NOT VALIDATED.
> **Read this if**: phase 75 is next in the queue, or a later phase depends on its future gate.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 75.1: The gateway-migration runtime — both branches over the Phase-17 `interpret` core](#sprint-751-the-gateway-migration-runtime--both-branches-over-the-phase-17-interpret-core-)
- [Sprint 75.2: Teardown-with-cleanup vs chaos-failover + unsatisfiable-spec push-back](#sprint-752-teardown-with-cleanup-vs-chaos-failover--unsatisfiable-spec-push-back-)
- [Sprint 75.3: Register-2.5 gateway-migration runtime fidelity — simulation + trace validation](#sprint-753-register-25-gateway-migration-runtime-fidelity--simulation--trace-validation-)
- [Sprint 75.4: Register-3 correspondence — Inject drills against the running forest + lazy live-gate projection + ledger](#sprint-754-register-3-correspondence--inject-drills-against-the-running-forest--lazy-live-gate-projection--ledger-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 74, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** After Phase 74's future gate pass, this phase must exercise the authority
handoff across the non-confluent gateway boundary. The Haskell runtime must enact both branches: a `Planned`
`quiesce → drain → verify-caught-up → cutover` handover targeting RPO=0, and a `Failover` promotion through a
fail-closed freshness gate within a declared data-loss budget. The gate must distinguish lossless
teardown-with-cleanup from bounded-loss chaos failover and refuse teardown that would make the root
`InForceSpec` unsatisfiable. Before live injection, the production decision core must run under `IOSimPOR`
against modeled boundaries and its transition log must satisfy the separately authored Phase-17 `Model`
relation. The live challenge then tests only the named physical premises; it does not convert a model result
or sampled drill into universal proof. No predecessor result or runtime correspondence is current.

This phase consumes earlier phases and does not re-implement them: Phase 74's geo-replicated forest and
invariant-confluence classifier, Phase 17's `GatewayMigration` `Model` + `interpret` + decode-time
structural-fit fold, Phase 64's Keycloak-owned wild ingress, Phase 73's WireGuard fabric (whose hub role the
`Planned` handover repoints), and Phase 16's (Sprints 28.1/15.2) `io-classes` seams and modeled route53/Pulsar. A
**stretched cluster is not geo-replication**: one etcd, one boundary owes no R9 budget and no Second-Axis
obligation and is out of scope here.

**Phase scope:** one cohesive target claim — *both branches of the one proof obligation are challenged against a live forest and compared with the independently passed model*. No discharge is current.

**Substrate:** linux-cpu — the future gate drives the migration over the parent and both child clusters that Phase 74
must spin up as `kind` clusters on a single linux-cpu host; no accelerator and no provider cluster is in
scope (provider-managed clusters are [Phase 76](phase_76_provider_deploy_checkpoint.md)). Partition tolerance is
exercised by killing a sibling on the same host — not a property a single root cluster exercises.
The `linux-cpu` lane remains available on every hardware substrate.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure: a real child forest, an authoritative local DNS repoint, a real
WireGuard hub-role move, and adversarial fault injection against the running forest. Route53 provider mutation
is explicitly outside the target boundary.

**Depends on:** [Phase 74](phase_74_multicluster_spawn_georepl.md)
**Gate:** `pb validate phase 75`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive target claim — *both branches of the one proof obligation are challenged against a live forest and compared with the independently passed model*. No discharge is current. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 75` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance have been established. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not yet been demonstrated by a passing gate for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not yet been demonstrated by a passing gate. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not yet been demonstrated by a passing gate. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a checked pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or checked non-applicability have not yet been demonstrated by a passing gate. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 74; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

This phase instantiates the canonical resource matrix and sealed whole-deployment provision boundary from
[`resource_capacity_types.md §3.1`](../documents/engineering/resource_capacity_types.md#31-the-systematic-provision-matrix)
and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting).
`GatewayMigrationTransitionDemand` is only a phase-local source composite: binding must exhaustively flatten it
to the canonical identity-keyed execution set and storage/system demands before either migration arm may run.

The runtime executes inside the Phase-65 control-plane daemon, whose complete pod envelope is expanded for migration-plan
evaluation, replication-watermark watches, DNS/fabric mutation serialization, source-proxy control, and
readiness/drain buffers; it is not a free second controller. Every transition epoch also retains both
clusters' Phase-64 edge controllers, operator-derived data-plane children, admission webhooks/gateways, and
rollout operands; the source transparent proxy and target serving path coexist through the full DNS drain
window. The Phase-73 `NetworkFabricSystemDemand` is derived for the source, overlap, and target peer/hub
graphs, including kernel/listener CPU and memory, queues, and rotated nodefs logs. The route53 repoint retains
the Phase-74 in-cluster `PulumiExecutionDemand`, exact executor-Job envelopes, plugin/workspace volumes,
checkpoint producer/admission gateway, and old/new checkpoint revisions. A `Planned` or `Failover` branch that
fits only by deleting the old gateway, proxy, peer graph, Pulumi executor, or checkpoint state before external
observation returns a structured pre-effect rejection.

The non-idle drill workload is provisioned too. Its source-equal Phase-67/48 client/workflow projection carries
every traffic-generator, active/standby worker, content mutation gateway, collector/verifier, topic/subscription,
BookKeeper/ZooKeeper/offload, MinIO object, and Patroni data/WAL/recovery demand. Every pod has a complete
image/CPU/memory/ephemeral/local-volume envelope and consumes pod/CNI and unique CSI-attachment slots; this
linux-cpu phase declares `accelerator = None`. The fault injector, out-of-forest write journal, trace
collector, and OS-boundary verifier form an identity-keyed host harness with an executable digest, finite
CPU/memory reservation and ceiling, bounded capture/log/scratch bytes on named host backings, finite
concurrency and retention, and no cache or accelerator. The journal's maximum acknowledged-write count and
record size derive its peak; “outside the forest” is an independence property, not an unbounded-storage
exception.

The exact post-controller-expansion `desiredObjects` map exhaustively includes every desired and surviving
Kubernetes object, including Namespaces, service accounts/RBAC, Secrets/ConfigMaps, workloads and generated
ReplicaSets/children, Services/EndpointSlices, policies, claims/volumes, Jobs, status/apply objects, and Leases.
Each identity has a `KubernetesApiObjectDemand`. Binding combines that complete map with bounded
revision/Event/Lease `churn` and a pinned storage `model` as
`EtcdLogicalDemand { desiredObjects, churn, model }`; its private
`ProvisionedEtcdLogicalDemand.derivedPeak` must fit `ControlPlaneStorageDemand.etcd.backendQuotaBytes` before
the separate backend-at-quota, WAL, snapshot, and serialized-defrag peak fits the control-plane backing.
Provisioning uses one read-only snapshot across every parent/child node, backing, object store, database,
provider account, and host-harness carve; only private projections mint the single-use mutation capability.
Live readback normalizes the old/overlap/new gateway and fabric epochs, Pulumi/checkpoint state,
workflow/store/database high-water, exhaustive API identities/churn/model, physical etcd state, and harness
process/backing use.

The Haskell-declared resource corpus makes each execution envelope, pod/CNI/CSI slot, CPU, memory, logical ephemeral
and routed physical byte, image/workspace object, durable/object/database extent, Pulumi plugin/checkpoint
operand, API object/churn/model term, etcd logical/physical byte, network queue/log term, and host-harness
operand one unit short in isolation and expects zero migration/cloud/store effects. Serialized cases are
generated beneath `.build/test-corpora/**`. Applied Haskell dropped-envelope mutants
remove the source proxy, target edge child, overlap peer graph, Pulumi executor, checkpoint admission gateway,
workflow collector, API object, etcd churn/model, or external journal; each must turn the gate red even if the
RPO/RTO assertions would otherwise pass.

## Doctrine adopted

- [`workflow_calculus_doctrine.md` §3 — Teardown is a type obligation](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation) — gateway-migration drills + model-correspondence provisions, and a teardown obligation it cannot discharge is a value it cannot construct.
- [`consistency_pacelc_doctrine.md` §3 — The one configurable axis — the deployment-rules PACELC surface](../documents/engineering/consistency_pacelc_doctrine.md#3-the-one-configurable-axis--the-deployment-rules-pacelc-surface)
  — **the PACELC failover budget (`rto` / `dnsTtl` / `lagBound`) and its decode folds.** The `Failover` drill
  rebinds within the declared `FailoverBudget`; the phase corpus includes an `rto < dnsTtl` spec that is gadt-decode
  decode-rejected ([`consistency_pacelc_doctrine.md` §3.5 — The upload-time feasibility push-back](../documents/engineering/consistency_pacelc_doctrine.md#35-the-upload-time-feasibility-push-back)),
  and "clients/resolvers honor the record TTL" is recorded as a named R8 **assumed** premise.
- [`gateway_migration_model_doctrine.md` §6 — Modelling bounds and honesty](../documents/engineering/gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty)
  and [`gateway_migration_model_doctrine.md` §7 — Planning ownership](../documents/engineering/gateway_migration_model_doctrine.md#7-planning-ownership)
  — *single-source correspondence* and *planning ownership*: because `interpret` and `emitTLA` render one
  `Model`, there is **no** separate variable→module correspondence table to complete; what remains for the live
  phase is the Register-3 chaos injection against a running forest (that the abstracted physics hold), and this
  phase is exactly that gate. It also inherits the [`gateway_migration_model_doctrine.md` §1 — The one obligation](../documents/engineering/gateway_migration_model_doctrine.md#1-the-one-obligation)
  one-obligation framing (no First-Axis election model) and the [`gateway_migration_model_doctrine.md` §5 — One-and-done, plus a per-`InForceSpec` structural fit](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)
  scope-2 pairwise cutoff the target forest must stay inside.
- [`gateway_migration_doctrine.md` §2 — The `Planned` branch — a coordinated strong-consistency handover](../documents/engineering/gateway_migration_doctrine.md#2-the-planned-branch--a-coordinated-strong-consistency-handover)
  and [`gateway_migration_doctrine.md` §3 — The `Failover` branch — an availability-first emergency takeover](../documents/engineering/gateway_migration_doctrine.md#3-the-failover-branch--an-availability-first-emergency-takeover)
  — the two arms of `GatewayMigration = <Planned | Failover>`: the coordinated strong-consistency handover
  (RPO=0, proven-for-the-model at scope 2) and the availability-first emergency takeover (RPO>0, bounded by the data-loss
  budget, reconciling to a single owner) — with the client-rebind protocol of
  [`gateway_migration_doctrine.md` §4 — Client rebind — a live session must always find the gateway](../documents/engineering/gateway_migration_doctrine.md#4-client-rebind--a-live-session-must-always-find-the-gateway)
  and the typed, edge-observed state machine of
  [`gateway_migration_doctrine.md` §5 — The migration as a typed, edge-observed state machine](../documents/engineering/gateway_migration_doctrine.md#5-the-migration-as-a-typed-edge-observed-state-machine)
  to be built as the effectful shell around the Phase-17 decision core, honest per
  [`gateway_migration_doctrine.md` §6 — Honesty and layer markers](../documents/engineering/gateway_migration_doctrine.md#6-honesty-and-layer-markers).
- [`chaos_failover_second_axis.md` §18 — The rules scale to the boundary](../documents/engineering/chaos_failover_second_axis.md#18-the-rules-scale-to-the-boundary)
  and [`chaos_failover_second_axis.md` §19 — The cross-boundary ledger and conformance rows](../documents/engineering/chaos_failover_second_axis.md#19-the-cross-boundary-ledger-and-conformance-rows)
  — the R7/R8/R9 cross-boundary rules: the fail-closed promotion-freshness gate and active-merge reconciliation
  (R7), the named-bounded-monitored replication lag (R8), and the two-dimensional failover budget — bounded
  permanent data loss and bounded recovery time (R9) — with the
  [`chaos_failover_doctrine.md` §11 — Move III — Inject: break the running thing on purpose](../documents/engineering/chaos_failover_doctrine.md#11-move-iii--inject-break-the-running-thing-on-purpose)
  run against the running forest and the [`chaos_failover_doctrine.md` §12 — The moral core — proven, tested, assumed](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
  kept honest. The doctrine works this exact shape through in its
  [`chaos_failover_worked_examples.md` Appendix B — Worked example (fenced): cross-cluster geo-replication failover (the open cross-cluster failover question)](../documents/engineering/chaos_failover_worked_examples.md#appendix-b--worked-example-fenced-cross-cluster-geo-replication-failover-the-open-cross-cluster-failover-question)
  worked example; this phase must challenge that target live.
- [`cluster_lifecycle_doctrine.md` §5 — Teardown-with-cleanup vs chaos-failover (the central distinction)](../documents/engineering/cluster_lifecycle_doctrine.md#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction),
  [`cluster_lifecycle_doctrine.md` §6 — Push-back when teardown would break the root `InForceSpec`](../documents/engineering/cluster_lifecycle_doctrine.md#6-push-back-when-teardown-would-break-the-root-inforcespec),
  and [`cluster_lifecycle_doctrine.md` §9 — How bring-up and teardown are implemented: the reconciler, not a state machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)
  — the central distinction between a lossless teardown-with-cleanup and a bounded-loss chaos-failover, and the
  declarative push-back on a teardown that would make the root `InForceSpec` unsatisfiable — all to be enacted as
  `discover → diff → enact → re-observe` reconciles over a managed-resource registry, never a bespoke lifecycle
  state machine.
- [`deterministic_simulation_doctrine.md` §4 — Register 2.5 — where deterministic simulation sits](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
  — the Register-2.5 runtime-fidelity stage: the future production forest code under `IOSimPOR` against a modeled
  route53/Pulsar, trace-validated against the Phase-17 emitted spec's `Next` relation before the Register-3 live
  drills, so the code↔model bridge is a formal, early, replayable check rather than only sampled live chaos.
- [`testing_doctrine.md` §3 — The test-topology contract: spin up → run → always tear down](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down)
  (the test-as-`InForceSpec` spin-up → run → always-tear-down contract) and
  [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
  (the per-run proven/tested/assumed ledger): the register this gate must reach and the candidate ledger it must emit.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 75.1: The gateway-migration runtime — both branches over the Phase-17 `interpret` core ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 74](phase_74_multicluster_spawn_georepl.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`gateway_migration_doctrine.md §2`](../documents/engineering/gateway_migration_doctrine.md#2-the-planned-branch--a-coordinated-strong-consistency-handover)/[`§3`](../documents/engineering/gateway_migration_doctrine.md#3-the-failover-branch--an-availability-first-emergency-takeover),
the client-rebind protocol of [`§4`](../documents/engineering/gateway_migration_doctrine.md#4-client-rebind--a-live-session-must-always-find-the-gateway),
and the R7/R8/R9 cross-boundary rules of
[`chaos_failover_second_axis.md §18`](../documents/engineering/chaos_failover_second_axis.md#18-the-rules-scale-to-the-boundary):
build the effectful gateway-migration shell for **both** branches whose every branch decision is the Phase-17
pure `interpret` value (a *liveness* coercion is licensed; a *durability* claim is forbidden — the tail beyond
the watermark stays a typed `NotYetObserved`), so the runtime realizes the proven model rather than re-deriving
it.

### Deliverables

- A `Planned` coordinated `quiesce → drain → verify-caught-up → cutover` (repoint the gateway DNS record and
  the WireGuard hub role, then unfreeze — **not** the apiserver-VPN-IP, which is a per-cluster stretched-cluster
  construct owned by its own cluster and never repointed by a gateway migration,
  [`gateway_migration_doctrine.md` §2](../documents/engineering/gateway_migration_doctrine.md#2-the-planned-branch--a-coordinated-strong-consistency-handover))
  whose `decommission(source-ingress)` edge is
  reachable only from an observed `drain-monitor` edge, so no transition removes the last working endpoint.
- A `Failover` fail-closed `PromotionGate`: the survivor promotes only on a proven commit watermark or a held
  fence, trading recovery time (R9 RTO) for zero divergence beyond the already-lost suffix; an authoritative
  local DNS repoint (with provider Route53 explicitly UNVERIFIED); and a deterministic, total, timestamp-free merge of the non-confluent CAS "latest" pointer
  on failback.
- The client-rebind mechanisms — old-gateway transparent proxy, a low steady-state DNS TTL, stable per-cluster
  addresses, and the 307 fallback — plus an exported live-lag monitor (R8) and a declared `DataLossBudget` =
  (data-loss window, recovery time).

### Validation

1. A `Planned` handover under a **non-idle** workflow (the drill client journals every source-acked write ID to
   the out-of-forest store of [Gate integrity](#gate-integrity), and the harness asserts **≥ 8 acked-but-un-replicated IDs exist at the quiesce instant** — observed replication lag > 0 — so an idle-workload rubber stamp cannot pass) moves authority with
   **measured loss = 0 proven by set-equality of journaled-vs-present IDs on the new owner** (not by a
   self-defined "committed = already replicated"), and a session that never loses its endpoint; a `Failover`
   after killing the lead (again with ≥ 8 acked-but-un-replicated IDs in flight) resumes through one authority
   with **measured loss ≤ the Haskell-declared `lagBound` and authority transfer within the Haskell-declared `RTO`**, where
   those oracle-pinned numeric values are authored in checked Haskell and lazily projected to
   `.build/test-corpora/dhall/phase_65_gateway_migration.dhall`
   (`lagBound = 5 s`, `RTO = 60 s`) before the drill runs — the drill **reports declared-vs-measured for both dimensions**, so a generous or post-hoc-tuned budget is visible; driving lag
   past the declared bound makes the freshness gate refuse to promote and the lag monitor alarm before a breach;
   and the Haskell-authored changed-subject `promote-before-fence` mutant ([Gate integrity](#gate-integrity)) — the `PromotionGate` guard negated — must go red.
2. The `Planned` branch drives the ordered edge sequence `stand-up-replica → quiesce → drain /
   verify-caught-up → promote → source-proxy + repoint DNS → unfreeze → drain-monitor → decommission`, the old
   gateway serving as a transparent proxy for the whole DNS-drain window so a live session always has a working
   endpoint.
3. The `Failover` branch promotes the survivor *only after* its freshness gate proves a known commit watermark,
   or holds a fence, and then repoints the authoritative DNS owner and the WireGuard hub. The un-replicated
   suffix is accounted for **only** by the R9 data-loss budget, never silently resolved to "absent."

### Remaining Work

Route53 provider mutation remains UNVERIFIED; the authoritative local DNS and raw-kernel fabric paths are done.

## Sprint 75.2: Teardown-with-cleanup vs chaos-failover + unsatisfiable-spec push-back ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 75.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`cluster_lifecycle_doctrine.md §5`](../documents/engineering/cluster_lifecycle_doctrine.md#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction)/[`§6`](../documents/engineering/cluster_lifecycle_doctrine.md#6-push-back-when-teardown-would-break-the-root-inforcespec),
enacted as the reconciler of
[`§9`](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine):
implement a graceful teardown as a controlled handoff that is lossless by construction, and the declarative
push-back that refuses — by default — a teardown that would leave the persistent global Haskell-declared
`InForceSpec` unsatisfiable (any Dhall form is only a lazy `.build/**` projection),
with an explicit operator override the only escape.

### Deliverables

- A `gracefulTeardown` reconcile: idempotent drain/flush/handoff ordering timed to a synchronization event,
  releasing compute while preserving retained backing so a later spin-up recreates PV bindings over the same
  bytes.
- A `satisfiability` check over the root `InForceSpec` using every execution unit's complete
  `ResourceEnvelope`: CPU requests/limits, memory requests/limits, pod-local ephemeral-storage
  requests/limits, durable-volume backing, bounded cache carve, and any identity-complete accelerator-owner
  source/workload maps, structural residency/shards, policy-class domains, and every derived coexistence
  epoch's device-count/per-device net-VRAM or Metal shared-memory requirement. Teardown may proceed only when the surviving forest can re-run
  `provision` for the unchanged desired spec and construct a fresh opaque `ProvisionedSpec` with placement,
  storage, and capability witnesses; otherwise it pushes back before releasing any resource, naming the
  exhausted axis/capability and the Haskell-declared failback, with the same fail-closed `Unreachable → refuse` posture
  as the reconciler.
- A managed-resource registry entry per cluster/child/node/stack/PV so teardown is one `reconcileAbsent` loop
  with "cannot observe" never collapsed to "absent."

### Validation

1. A graceful child teardown loses nothing (rides a sync event, preserves backing while PV API objects may
   disappear) and a later spin-up recreates the identical shape over the same bytes; a teardown of a
   load-bearing cluster whose removal breaks any CPU, memory, ephemeral-storage, durable-storage, cache,
   accelerator owner-map/domain, device-count, residency/shard, coexistence-epoch, per-device net-VRAM, or
   Metal shared-memory witness pushes back **before the first teardown effect** and
   aborts by default, and the
   explicit override falls to the declared failback; a graceful teardown and a chaos-failover are observably
   distinct — lossless-by-construction vs bounded-by-budget — and the code reports which guarantee held.

### Remaining Work

None inside the sealed single-host child-forest boundary.

## Sprint 75.3: Register-2.5 gateway-migration runtime fidelity — simulation + trace validation ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 75.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`deterministic_simulation_doctrine.md §4`](../documents/engineering/deterministic_simulation_doctrine.md#4-register-25--where-deterministic-simulation-sits)
and [`gateway_migration_model_doctrine.md §6`](../documents/engineering/gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty):
discharge the runtime-fidelity obligation in two stages, not one — first as trace-validated deterministic
simulation against the modeled world here (Register 2.5), then as live Inject drills (Sprint 75.4, Register 3)
— so the code↔model bridge is a formal, early, replayable check rather than only sampled live chaos.

### Deliverables

- The `GatewayMigrationSimSpec` battery: the real forest code under `IOSimPOR` against the modeled route53
  (short-TTL, **no compare-and-swap**, propagation delay) and the modeled geo-replicated Pulsar, asserting all
  five safety invariants — `UniqueGatewayOwner`, `SessionAlwaysRebindable`, `PlannedIsLossless`,
  `NoWriteAfterStaleFailover`, `NoTakeWithoutProvenFreshness` — on every explored schedule under injected
  partition/kill-cluster-mid-geo-sync/lag.
- The `GatewayMigrationTrace` validator: each observed transition of the simulated forest is a legal `Next`-step
  of the Phase-17 emitted spec
  ([`formal_model_doctrine.md §8`](../documents/engineering/formal_model_doctrine.md#8-trace-validation-the-earlier-codemodel-bridge)),
  and a mismatch is a code↔model divergence, red.
- A Register-2.5 proven/tested/assumed ledger — the built forest upholds the safety invariants and refines the
  model's `Next` under the modeled schedules and faults; honest limit: modeled route53/Pulsar fidelity and real
  replication-lag / clock-skew physics remain the Register-3 residue (Sprint 75.4).

### Validation

1. Rejected historical observation: the `gateway-migration-sim` Cabal suite was recorded green — no schedule
   violates a safety invariant and no observed
   transition falls outside `Next`; a deliberately broken forest (a fence dropped, a decommission-before-drain)
   is caught red; the discovered counterexample replays identically under its seed.

### Remaining Work

The pre-reset `None` claim is permanently invalid; this sprint remains blocked and NOT VALIDATED. Real WAN physics remain outside the retained historical single-host result.

## Sprint 75.4: Register-3 correspondence — Inject drills against the running forest + lazy live-gate projection + ledger ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 75.3
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`gateway_migration_model_doctrine.md §6`](../documents/engineering/gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty)/[`§7`](../documents/engineering/gateway_migration_model_doctrine.md#7-planning-ownership):
because correspondence is differentially checked (one `Model` → `interpret` + `emitTLA`), run the deferred
Register-3 residue — the [Inject move (§11)](../documents/engineering/chaos_failover_doctrine.md#11-move-iii--inject-break-the-running-thing-on-purpose)
against the running forest confirming the abstracted physics actually hold — as the Haskell-declared test
topology lazily rendered beneath `.build/**` described by
[`testing_doctrine.md §3`](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down),
ledgered per [`chaos_failover_doctrine.md §12`](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
and [`§19`](../documents/engineering/chaos_failover_second_axis.md#19-the-cross-boundary-ledger-and-conformance-rows).

### Deliverables

- The Register-3 Inject drill set run in the inter-cluster dimension against the running forest — cut
  replication, kill the lead mid-`Planned`-handover, kill the lead with no drain to force `Failover`, drive lag
  past the bound, and fail back with late plus duplicate arrivals — each asserting the Phase-17 named invariants.
  This is the concrete confirmation that the built runtime, which *is* the model's
  `interpret`, upholds under real physics what the model proves in logical time (never a re-authored TLA+ spec,
  never a paper variable→module table, which is what the superseded framing had reversed).
- A checked Haskell gate-topology declaration that lazily renders
  `.build/test-corpora/dhall/phase_65_gateway_migration.dhall`: spin two children up, geo-replicate, run a `Planned` handover
  asserting RPO=0 via the write-journal oracle, kill the lead to force `Failover` asserting rebind within the
  oracle-pinned numeric budget (`lagBound = 5 s`, `RTO = 60 s`, hash-pinned), reconcile divergent
  histories, and always tear down leak-free (verified by the OS-boundary kind/network-namespace/journal/DNS observer) —
  emitting the machine-derived per-run ledger artifact. The gate topology, out-of-forest write-ID journal
  schema, run-ledger schema validator, and their independent expectations are authored as checked Haskell
  before the runtime exists; their reproducible Dhall, journal, and ledger materializations are generated lazily
  beneath `.build/test-corpora/**` or `.build/runs/**` and remain untracked. The runtime-dependent Haskell seeded
  mutation operators (`verify-caught-up`-stub and `promote-before-fence`) mutate the Sprint-70.1 implementation,
  so they are **checked at the start of Phase 75, before that implementation is trusted** (the §M.1
  start-of-owning-phase form for oracles that depend on later code).
- A machine-derived per-run proven/tested/assumed ledger that marks `Planned` RPO=0 **proven-for-the-model (Phase 17, scope 2) + drilled (tested)**, the `Failover` recovery time + reconciliation **tested (drilled)**, the data-loss /
  replication-lag bound **assumed (monitored, never proven)**, and the modeled safety/liveness
  **proven-for-the-model at scope 2** (Phase-17, a design-layer result) — and never reports an
  assumed-and-monitored result as proven.

### Validation

1. The built decision core resolves to the Phase-17 `interpret` — the correspondence-check mechanic is fixed as:
   the step-by-step trace-validation of Sprint 75.3 (Register 2.5) **plus** a Register-3 **modeled-action-coverage assertion** that every modeled action fired ≥ 1 time across the drill set (no orphaned modeled action); step-by-step
   trace-validation is the Sprint-70.3 obligation and is not re-run in Register 3. The Inject drills run against
   the live forest and pass, each asserting all five named safety invariants (`NoWriteAfterStaleFailover` is the
   safety half; the recovery-time half is the separate *tested* RTO datapoint). The Haskell-declared gate topology,
   lazily projected to `.build/test-corpora/dhall/phase_65_gateway_migration.dhall`,
   reports **RPO=0 for `Planned` proven by the write-journal set-equality oracle ([Gate integrity](#gate-integrity)) under a workload with ≥ 8 acked-but-un-replicated IDs at the cut** — not a bare "loss = 0" — and **measured loss ≤ the oracle-pinned `lagBound` and transfer ≤ the Haskell-declared `RTO`** (declared-vs-measured reported
   for both). Teardown is **leak-free by the OS-boundary observer of [Gate integrity](#gate-integrity)**: kind,
   network-namespace, exact-root, and local-DNS inventories report zero surviving migration records and test clusters, with the
   retained `no-provisioner` PVs of Sprint 75.2 explicitly exempt. The Haskell-authored changed-subject seeded mutants ([Gate integrity](#gate-integrity): `verify-caught-up`-stub and `promote-before-fence`) each go red. The ledger is **machine-derived from the run record** and passes its Haskell validator — every ledger figure (RPO/RTO, observed max lag, raw journal
   counts, seeds, timestamps, teardown-observer result) cross-checks against the raw journal, and any mismatch or
   hand-edited field fails the gate; out-of-Register-3 layers stay marked UNVERIFIED.

### Remaining Work

Route53 provider API mutation, physically independent brokers, and real WAN partitioning remain UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/gateway_migration_model_doctrine.md` — flip §6's Register-3 chaos-injection residue to
  *run against a live forest* for both branches, recording the differential-correspondence result and live trace
  validation without inventing a variable→module table; keep the abstracted premises assumed.
- `documents/engineering/gateway_migration_doctrine.md` — backlink §2/§3/§4/§5 to the built
  `src/Amoebius/Multicluster/*` runtime; confirm `Planned` RPO=0 stayed proven-for-the-model (Phase 17, scope 2; now drilled live) and
  `Failover` stayed bounded-by-budget.
- `documents/engineering/chaos_failover_doctrine.md` — the §19 cross-boundary ledger and the §15/§19 conformance
  rows gain an amoebius-tested linux-cpu datapoint (recovery-time drilled, data-loss assumed), so the matrix
  stops resting on prodbox sibling-evidence alone; cross-reference the realized `Multicluster/*` module paths.
- `documents/engineering/cluster_lifecycle_doctrine.md` — §5/§6/§9 gain the realized module paths for the
  teardown-vs-chaos distinction, the push-back, and the reconciler/registry.
- `documents/engineering/deterministic_simulation_doctrine.md` — record the Register-2.5 io-sim + trace-validation
  of the gateway-migration runtime.
- `documents/engineering/pulumi_iac_doctrine.md` — record the local authoritative-DNS failover repoint and
  WireGuard hub-role move, leaving the Route53 provider owner UNVERIFIED.
- `documents/engineering/testing_doctrine.md` — record the Register-3 Inject + live-gate ledger this phase emits.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-75 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/system_components.md` — register the `src/Amoebius/Multicluster/GatewayMigration.hs`,
  `PlannedHandover.hs`, `PromotionGate.hs`, `DnsRepoint.hs`, `ClientRebind.hs`, `Teardown.hs`, `Pushback.hs`
  modules and the Register-2.5 simulation + Register-3 Inject + gate suites as Phase-75 rows.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-75 → linux-cpu row in the per-phase substrate map.

## Related Documents

- [README.md](README.md) — the live tracker; Phase 75 objective, gate, and substrate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — target architecture and the one-formal-obligation constraint
- [system_components.md](system_components.md) — target component inventory (the `Multicluster/*` module paths)
- [substrates.md](substrates.md) — substrate registry and per-phase map
- [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) — the one obligation, both branches, single-source correspondence, and the Register-3 chaos residue this phase discharges
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — the Register-2.5 io-sim + trace-validation (Sprint 75.3) that pulls the runtime-fidelity obligation forward from Register-3-only chaos
- [Gateway Migration Doctrine](../documents/engineering/gateway_migration_doctrine.md) — the `GatewayMigration = <Planned | Failover>` taxonomy, client rebind, and the typed edge-observed state machine
- [Chaos & Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the Inject move, the R7/R8/R9 cross-boundary rules, and the proven/tested/assumed cross-boundary ledger
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — teardown-vs-chaos and push-back
- [phase_17](phase_17_gateway_migration_model.md) — the `GatewayMigration` design-model whose Register-3 correspondence against the built forest is discharged here
- [phase_74](phase_74_multicluster_spawn_georepl.md) — the prior phase; the geo-replicated forest and confluence classifier this phase runs over
- [phase_76](phase_76_provider_deploy_checkpoint.md) — the next phase; the forest extended to provider-managed clusters
