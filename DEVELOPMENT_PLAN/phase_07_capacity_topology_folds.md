# Phase 7: Capacity / topology folds (representational)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_08_capability_binder.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Build the pure capacity-accounting fold (`fits`/`carve`/`place`) and the compute-engine/topology
> relation as total, in-process Haskell, and prove under QuickCheck that they hold on the positive corpus and
> reject every capacity/topology negative at decode — before any host or cluster exists.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 6 gate (the illegal-state
corpus, its QuickCheck properties, and the validation-locus ledger) and runs on **no substrate** (`none`) in
**Register 1** — it stands up no host and no cluster, only an in-process fold + property battery. Where a shape
below is exercised in a sibling system (prodbox's `Prodbox/CLI/Rke2.hs` single-node rke2 base and the
teardown push-back soundness it proves), that is **sibling evidence, not an amoebius result**.

## Phase Summary

This phase makes amoebius's *"resource demand never exceeds capacity"* and *"the compute engine matches its
substrate, and topology matches its hosts"* invariants executable as pure decode-time folds, and proves them
under QuickCheck in-process. It delivers the capacity model — the refined non-zero `Quantity`, the shared
`Capacity`/`Demand`/`Budget` record shape, and the four total functions `fits` / `podFits` / `carve` / `place`
that nest host → VM → workload and branch `place` on a fixed node set (a concrete pod→node **witness**
bin-pack) versus an elastic one (a two-envelope growth check) — together with the closed `StorageBudget` /
`Growable` unions and the two-ceiling Pulsar fold. It delivers the topology relation — the closed
`ComputeEngine` union, the substrate-indexed `LinuxHost` witness, the `Topology` fold over a `NonEmpty Node`,
and the **elementwise** compatible-pair relation that keeps heterogeneous multi-substrate clusters legal while
rejecting an incompatible pairing. Every one of these is a **decode-foreclosed** total check over a
constructible value, never a type-inhabitance claim: the phase proves the folds are total, sound (they never
admit an over-committed or incompatible spec), and structurally rejecting on the capacity/topology negatives.
What is *not* here: the live re-run of any fixture against a real cluster, VM boot, pod schedule, S3 offload,
or autoscaler growth (the runtime-checked residue, deferred to the live band); the capability → provider →
shape binder ([Phase 8](phase_08_capability_binder.md)); and the `ScalingPolicy` enaction as Pulumi node
provisioning (a later live phase).

**Substrate:** none — no host, no cluster; the gate is an in-process `cabal test` fold + QuickCheck battery,
analogous to the Phase 5 decode battery and the Phase 6 property suite.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** the `fits`/`carve`/`place` capacity fold and the compute-engine/topology relation hold under
QuickCheck — every generated positive input yields a sound headroom/placement/compatibility result and the
folds are provably total — and the decode-foreclosed folds return a structured `Left` on each
capacity/topology negative fixture (engine↔substrate mismatch, a reused rke2 host, host/VM/cluster overcommit,
a store over its backing, a time-only or hot-tier-over-bookie topic, an unplaceable taint), while the positive
`legal_multisubstrate_cluster` and `legal_managed_eks` fixtures place feasibly — a **Register-1** in-process
check that runs on no substrate.

## Doctrine adopted

- [`resource_capacity_doctrine.md §4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — the total fold `fits`/`carve`/`place` and the nesting: this phase implements the four total functions and
  the host → VM → workload nesting as pure Haskell, with `place` branching per
  [§4.1](../documents/engineering/resource_capacity_doctrine.md#41-place-branches-static-proves-a-placement-dynamic-proves-a-growth-envelope)
  (a fixed node set proves a placement witness; an elastic one proves a growth envelope), reading the declared
  `Capacity`/`Demand`/`Budget` types of [§3](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget).
- [`resource_capacity_doctrine.md §2`](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed)
  — the load-bearing honesty limit: a capacity check is **decode-foreclosed**, never type-foreclosed, and the
  compute placement is **sound, not complete** (first-fit-decreasing may reject a packable spec but never
  admits an unplaceable one). The QuickCheck properties assert soundness only; completeness is deliberately not
  claimed.
- [`resource_capacity_doctrine.md §5`](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm),
  [`§6`](../documents/engineering/resource_capacity_doctrine.md#6-growable--scalingpolicy-the-escape-valve-amoebius-owns),
  and [`§7`](../documents/engineering/resource_capacity_doctrine.md#7-pulsar-has-two-ceilings-the-hot-tier-and-the-durable-total)
  — the storage arithmetic: the closed `StorageBudget` union (no unbounded arm), the `Growable`/`ScalingPolicy`
  escape valve (no bare-unbounded arm), the aggregate `Σ(sizes) ≤ backing` fold, and Pulsar's two ceilings
  (hot-tier fit + durable-total fit) — the union *shapes* are type-foreclosed (Phase 4/6); the aggregate
  *arithmetic* over them is the decode fold this phase adds.
- [`cluster_topology_doctrine.md §2`](../documents/engineering/cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm),
  [`§3`](../documents/engineering/cluster_topology_doctrine.md#3-the-linuxhost-witness-rke2kind-on-a-host-with-no-linux-node-is-uninhabitable),
  and [`§4`](../documents/engineering/cluster_topology_doctrine.md#4-topology-a-cluster-is-a-fold-over-its-nodes-and-cardinality-is-by-construction)
  — the compute-engine axis: the closed `ComputeEngine` union with `Managed Eks` as a first-class arm, the
  substrate-indexed `LinuxHost` witness (whose only apple/windows constructor is `limaHost`/`wsl2Host`), and
  the `Topology` fold over `NonEmpty Node` in which cardinality is by construction — this phase realizes the
  distinctness-over-`servers ∪ agents` decode fold and the placement fold over that `Topology`.
- [`cluster_topology_doctrine.md §5`](../documents/engineering/cluster_topology_doctrine.md#5-the-compatibility-relation-technique-47-only-compatible-pairs-have-a-constructor)
  — the compatibility relation (catalog technique §4.7): the compatible-pair smart constructor at the element
  level and the **total elementwise fold** over `NonEmpty Node` at the collection level, returning the full
  list of incompatible nodes so heterogeneous multi-substrate stays legal by construction.
- [`illegal_state_catalog.md §4.6`](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
  and [`§4.7`](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)
  — the two typing techniques this phase discharges (capacity-accounting placement + compatibility/topology
  relations over a collection), covering catalog entries §3.13–§3.22 at the honest layer
  ([`§6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)):
  every capacity **sum** is decode-foreclosed, never type-foreclosed, honoring the load-bearing limit of
  [`§2`](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it).
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) §2 (**Register 1** — pure/golden,
  in-process, no cluster) and §4 (the per-run proven/tested/assumed ledger): the register this gate reaches and
  the ledger it emits, with model↔runtime correspondence and runtime fidelity marked UNVERIFIED (owned by the
  live band).

## Sprints

## Sprint 7.1: The `Topology` relation — `ComputeEngine` / `LinuxHost` witness / elementwise compatibility fold 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Dsl/Topology.hs` (`ComputeEngine`, the substrate-indexed `LinuxHost`
witness, `Topology = { engine, nodes : NonEmpty Node }`, the compatible-pair smart constructor, the total
elementwise compatibility fold, and the `mkRke2` distinctness fold over `servers ∪ agents`); extends
`src/Amoebius/Dsl/SmartConstructors.hs` — target paths, not yet built.
**Blocked by**: Phase 5 gate (the GADT-indexed IR + total decoder the topology types live in); Phase 6 gate
(the property/corpus framework + validation-locus ledger).
**Independent Validation**: a unit + property suite decodes each positive `Topology` (heterogeneous
multi-substrate, managed EKS) and returns a structured `Left` naming the full set of incompatible nodes for a
mismatched pair and a duplicate `HostId` for a reused host; a typed-hole check confirms `bareAppleHost` /
`bareWindowsHost` / an even-server quorum have no constructor.
**Docs to update**: `documents/engineering/cluster_topology_doctrine.md` (Phase-7 status backlink),
`documents/engineering/substrate_doctrine.md` (§8 node inventory read-side), `documents/illegal_state/illegal_state_catalog.md`
(§3.13–§3.16 per-entry layer reconciliation), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`cluster_topology_doctrine.md §2/§3/§4`](../documents/engineering/cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm)
and the compatibility relation of [`§5`](../documents/engineering/cluster_topology_doctrine.md#5-the-compatibility-relation-technique-47-only-compatible-pairs-have-a-constructor):
build the declared compute-engine axis as pure Haskell so that a cluster is a `Topology` fold over its nodes,
cardinality is by construction, and the element/collection compatibility relation admits every legal
heterogeneous cluster while rejecting an incompatible pairing at decode.

### Deliverables
- The closed `ComputeEngine` union (`Kind { host, replicas }` / `Rke2 { servers : Rke2Servers, agents }` /
  `Managed Eks`) and the substrate-indexed `LinuxHost` witness — kind's single `host` field *is* the
  cardinality bound; the only apple/windows `LinuxHost` constructor is `limaHost`/`wsl2Host`.
- The compatible-pair smart constructor for `Node` and the **total elementwise** compatibility fold over
  `NonEmpty Node`, returning the complete list of incompatible nodes (not just the first) so heterogeneous
  multi-substrate is legal element by element.
- The `mkRke2` distinctness fold over `servers ∪ agents` rejecting a duplicate `HostId` — the decode-foreclosed
  floor Dhall cannot express as a type — with an in-file note that the odd-quorum shape and "more nodes than
  hosts" are already type-foreclosed upstream (Phase 4/5).

### Validation
1. Each positive `Topology` decodes; a mismatched pair returns a structured `Left` listing every incompatible
   node; a reused host returns a duplicate-`HostId` `Left`; the illegal constructors have no inhabitant.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 7.2: The capacity fold — `fits` / `podFits` / `carve` / `place` + storage/retention Σ 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Capacity/Types.hs` (`Quantity`, `ResourceVec`, `Capacity`/`Demand`/`Budget`,
`requests ≤ limits`); `src/Amoebius/Capacity/Fold.hs` (`fits`/`podFits`/`carve`/`place`, the host → VM →
workload nesting, the §4.1 static/elastic branch); `src/Amoebius/Capacity/Storage.hs` (`StorageBudget`
Σ fold + the two-ceiling Pulsar fold); `src/Amoebius/Capacity/Growable.hs` (`Growable`/`ScalingPolicy`) —
target paths, not yet built.
**Blocked by**: Sprint 7.1 (the `Topology` `place` folds over); Phase 5 gate (the IR + decoder).
**Independent Validation**: a unit + property suite runs `fits`/`carve`/`place` over generated envelopes: a
feasible workload set yields a placement witness or a sound growth envelope; an over-committed one returns
`Left Overcommit`/`Left Unschedulable` naming the offending axis; the storage/Pulsar Σ folds return `Left` on
an over-backing or un-tiered topic.
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md` (Phase-7 status backlink),
`documents/engineering/storage_lifecycle_doctrine.md` (§5.2 backing read-side),
`documents/engineering/pulsar_client_doctrine.md` (§6 two-ceiling read-side),
`documents/illegal_state/illegal_state_catalog.md` (§3.17–§3.21 layer reconciliation),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`resource_capacity_doctrine.md §3/§4/§4.1`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
and the storage arithmetic of [`§5`](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)/[`§7`](../documents/engineering/resource_capacity_doctrine.md#7-pulsar-has-two-ceilings-the-hot-tier-and-the-durable-total):
implement the four total capacity functions and the storage/retention Σ as pure, decode-foreclosed checks — a
concrete pod→node witness for a fixed node set, a two-envelope growth check for an elastic one, genuine
subtractions for the single-owner carves, and `Σ ≤ backing` for divisible storage — reading declared numbers
only (the substrate node inventory and PV sizes are owned elsewhere).

### Deliverables
- `Quantity` (refined non-zero, per unit), the shared `Capacity`/`Demand`/`Budget` record shape with
  `requests ≤ limits`, and `fits`/`podFits`/`carve`/`place` — `place` branching on the topology's budget shape
  (fixed → first-fit-decreasing witness; elastic → per-pod-fits-largest-candidate + Σ-at-max-scale ≤ quota),
  with the host → VM → guest and cluster → workload nesting; accelerators are wholesale-owned, so the
  pod→node bin-pack ranges over `cpu`/`mem` only and VRAM is a per-owner `Σ served-model ≤ node vram` arm
  modelled like storage.
- The closed `StorageBudget`/`Growable` unions (no unbounded / no bare-unbounded arm) and the aggregate
  `Σ(sizes) ≤ backing` fold; the two-ceiling Pulsar fold (hot-tier fit against the BookKeeper backing +
  durable-total fit against the offload target), so a time-only or hot-tier-over-bookie topic decode-rejects.
- An in-file honesty note: the union *shapes* are type-foreclosed (Phase 4/6); every capacity/retention **sum**
  here is a decode-foreclosed total check, sound-not-complete for the compute bin-pack; the fold re-runs after
  any `Growable` growth so growth never silently invalidates an earlier check.

### Validation
1. A feasible input yields a witness or a sound envelope; an over-committed host/VM/cluster, an over-backing
   store, or an un-tiered topic returns the tagged `Left` naming the offending axis; the folds never throw.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 7.3: QuickCheck properties — soundness, totality, elementwise compatibility 📋

**Status**: Planned
**Implementation**: `test/dsl/CapacityTopologyProps.hs` (QuickCheck generators for `Topology` / envelope /
workload sets + the property battery) reusing the Phase-6 property harness — target paths, not yet built.
**Blocked by**: Sprint 7.1, Sprint 7.2.
**Independent Validation**: `cabal test dsl-spec` runs the property battery green — the fold/relation
soundness, totality, headroom-non-negativity, carve-subtraction, elementwise-compatibility, and Pulsar
two-ceiling properties hold over generated inputs; a seeded mutant fold (drop an axis, admit an incompatible
pair) is caught.
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md`,
`documents/engineering/cluster_topology_doctrine.md`, `documents/engineering/testing_doctrine.md` (the
Register-1 property register), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) §2 (Register 1) and the honesty
limit of [`resource_capacity_doctrine.md §2`](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed):
express the capacity fold and the topology relation as QuickCheck properties that assert **soundness** (the
fold never admits an over-committed or incompatible spec) without ever claiming completeness, proving the
in-process laws hold on generated corpora.

### Deliverables
- Capacity properties: `fits d c = Right h ⟹` `d + h` reconstructs `c` per axis with no underflow; `carve` is
  total subtraction; a returned `place` witness assigns every pod to a node it `podFits` (soundness); `place`
  may return `Left` on a packable spec but never a witness that violates an allocatable (the one-directional
  soundness caveat); the fold re-runs consistently after a `Growable` growth.
- Topology properties: the elementwise compatibility fold accepts a heterogeneous multi-substrate `NonEmpty
  Node` iff every pair is compatible and returns the exact incompatible-node set otherwise; `mkRke2` rejects a
  duplicate `HostId`; kind cardinality is fixed at one host regardless of `replicas`.
- A totality guard: every property generator exercises the fold on arbitrary constructible inputs and no input
  yields an exception, `error`, or partial match.

### Validation
1. The property battery is green; a deliberately mutated fold (an admitted overcommit, a dropped incompatible
   pair) makes a property red — the properties have teeth.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 7.4: The capacity/topology fold-negative corpus + the gate 📋

**Status**: Planned
**Implementation**: `dhall/examples/{illegal_engine_substrate_mismatch,illegal_rke2_reused_host,
illegal_overcommit_host,illegal_overcommit_vm,illegal_overcommit_cluster,illegal_store_over_backing,
illegal_topic_time_only_offload,illegal_hot_tier_over_bookie,illegal_untolerated_taint}.dhall` (the
decode-foreclosed fold negatives) + reuse of `legal_multisubstrate_cluster`/`legal_managed_eks`;
`test/dsl/CapacityTopologyGate.hs` (the gate battery + validation-locus ledger) — target paths, not yet built.
**Blocked by**: Sprint 7.1, Sprint 7.2, Sprint 7.3; Phase 4 gate (the positive Gate-1 corpus).
**Independent Validation**: the gate decodes each positive fixture to a feasible placement and returns a
structured `Left` for each fold negative, each assertion annotated with its catalog entry (§3.13–§3.22) and
its decode-foreclosed layer; the run emits a Register-1 proven/tested/assumed ledger.
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (the §3.13–§3.22 decode-foreclosed
entries → layer-2 Register-1), `documents/engineering/testing_doctrine.md`, `DEVELOPMENT_PLAN/README.md` (flip
the Phase-7 status when the gate passes), `DEVELOPMENT_PLAN/substrates.md` (the Phase-7 `none` gate row).

### Objective
Adopt [`illegal_state_catalog.md §4.6/§4.7`](../documents/illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
and [`§3`](../documents/illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent):
assemble the phase's single Register-1 gate — the decode-foreclosed folds reject each capacity/topology
negative while the positive multi-substrate / managed-EKS fixtures place feasibly — and emit the per-entry
validation-locus ledger that names the honest foreclosure layer of each.

### Deliverables
- The fold-negative fixtures — `illegal_engine_substrate_mismatch` (§3.13), `illegal_rke2_reused_host` (§3.16
  distinctness), `illegal_overcommit_{host,vm,cluster}` (§3.17), `illegal_store_over_backing` (§3.19),
  `illegal_topic_time_only_offload` + `illegal_hot_tier_over_bookie` (§3.20), `illegal_untolerated_taint`
  (§3.22 placeable-node existence) — each asserted to return the tagged `Left` at the fold, with the
  type-foreclosed neighbours (§3.14/§3.15/§3.18/§3.21/§3.24) noted as already foreclosed upstream.
- The positive fixtures `legal_multisubstrate_cluster` (the §3.13 heterogeneous carve-out) and
  `legal_managed_eks` (EKS first-class) asserted to decode and `place` feasibly.
- A Register-1 validation-locus ledger mapping every entry to its catalog id and its layer (decode-foreclosed),
  explicitly marking the runtime residue (VM boot, pod schedule, S3 offload, autoscaler growth) deferred to the
  live band — sibling evidence where the capacity arithmetic generalizes prodbox's teardown push-back
  soundness, not an amoebius result.

### Validation
1. `cabal test dsl-spec` is green — every fold negative returns the tagged `Left`, both positives place
   feasibly, the QuickCheck battery holds, and the suite is red if any capacity/topology negative decodes;
   the validation-locus ledger is present and honestly classifies each foreclosure.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/resource_capacity_doctrine.md` — backlink §4's fold + §5/§6/§7 storage arithmetic to
  the implemented `Amoebius.Capacity.*`; confirm every capacity/retention sum stayed decode-foreclosed and
  sound-not-complete.
- `documents/engineering/cluster_topology_doctrine.md` — backlink §2/§3/§4 and the §5 compatible-pair fold to
  the implemented `Amoebius.Dsl.Topology`; keep the runtime (VM boot, node join) residue deferred.
- `documents/illegal_state/illegal_state_catalog.md` — annotate §3.13–§3.22 with their realized decode-foreclosed
  layer (technique §4.6/§4.7 → layer 2, Register-1); keep runtime-checked entries (layer 3) deferred.
- `documents/engineering/storage_lifecycle_doctrine.md` (§5.2), `documents/engineering/pulsar_client_doctrine.md`
  (§6), `documents/engineering/substrate_doctrine.md` (§8 node inventory) — reconcile each read-side with the
  as-built fold; each remains the single owner of its number.
- `documents/engineering/testing_doctrine.md` — record the Register-1 property + fold ledger this gate emits
  (correspondence and runtime fidelity UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-7 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-7 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Dsl/Topology.hs`,
  `src/Amoebius/Capacity/{Types,Fold,Storage,Growable}.hs`, and the capacity/topology property + gate suites as
  Phase-7 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the capacity/topology invariants
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — the `fits`/`carve`/`place` fold, `StorageBudget`/`Growable`, and the two-ceiling Pulsar arithmetic
- [Cluster Topology Doctrine](../documents/engineering/cluster_topology_doctrine.md) — the `ComputeEngine`/`LinuxHost`/`Topology` types and the elementwise compatibility relation
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — §3.13–§3.22 and the §4.6/§4.7 techniques, with §2/§6 the load-bearing limit and the honest foreclosure-layer split
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 1, §4 the per-run ledger
- [phase_05](phase_05_gadt_decoder_gate2.md) — Gate 2, the IR + decoder these folds decode into
- [phase_06](phase_06_illegal_state_corpus.md) — the illegal-state corpus, properties, and validation-locus ledger this phase extends
- [phase_08](phase_08_capability_binder.md) — the capability → provider → shape binder built atop these folds
