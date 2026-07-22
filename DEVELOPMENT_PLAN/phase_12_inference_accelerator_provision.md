# Phase 12: InferenceEngine capability + accelerator provision

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_10_capability_bind.md, DEVELOPMENT_PLAN/phase_11_provision_seal.md, DEVELOPMENT_PLAN/phase_38_determinism_jitcache.md
**Generated sections**: none

> **Purpose**: Fill the ninth (`InferenceEngine`) capability arm as a representational union and relation — the
> closed `EngineRuntime` lane union with no `Url`/`Download` arm, the target-offering→lane quotient, the partial
> family×lane availability relation, and identity-complete `CudaOwnerDemand`/`MetalOwnerDemand` shapes — then
> pair a served model to a concrete CUDA/Metal target so that every policy-permitted residency/coexistence epoch
> folds against per-device net allocatable VRAM at the post-bind provision seal, proving before render that a
> CUDA-requiring workload on a CPU-only target has no deployable value.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 11 gate (the whole-deployment
provision seal, from which the accelerator epoch witnesses are constructed) and the Phase 9 gate (the
identity-complete accelerator-residency/coexistence epoch fold these owner demands feed), and runs on **no
substrate** (`none`) in **Register 1** — it stands up no CUDA device, no Metal host, and no cluster, only the
representational `EngineRuntime` union, the family×lane relation, the owner-demand records, and the
accelerator-provision fold plus its property/corpus battery. Where this shape is exercised in a sibling system
(infernix's `Infernix/Runtime/Worker.hs` selecting its engine by `adapterType` and **never fetching it**), that
is **sibling evidence, not an amoebius result** — and the sibling still *fetches* engine payloads and *names*
them, the exact coupling the substrate-selected, jit-resolved `EngineRuntime` identity dissolves.

## Phase Summary

This phase makes amoebius's *"an ML engine is a named catalog identity the substrate selects and the shared
jit-build resolver materializes on first miss — never authored, never baked, never URL-fetched"* invariant
executable as the strictest instance of the capability→provider→shape binding. It **fills the ninth capability
arm** whose reserved head [Phase 10](phase_10_capability_bind.md) delivers: the `InferenceEngine` capability and
its closed `EngineRuntime` lane union (`AppleMetal` · `Cuda` · `LinuxCpu`) with **no arbitrary-`Url`/`Download`
arm**, the closed engine-family union, the target-offering→lane **quotient** projection
(`apple → AppleMetal`, `linux-cpu → LinuxCpu`, `{ linux-cuda, windows } → Cuda`, `Cuda` OS-agnostic with no
Linux-vs-Windows constructor), and the **partial** family×lane availability relation. It delivers the
identity-complete `CudaOwnerDemand`/`MetalOwnerDemand` values: an exact source inventory and equal-keyed
workload map for served models, training jobs, JIT compilations, and library work; structural
weights/KV/activation/optimizer/JIT/library residency components; and a finite class-complete coexistence
policy. CUDA residency uses `Unsharded`, `ReplicatedPerDevice`, or explicit `Sharded` placement (bytes total for
Unsharded/Sharded, per device for ReplicatedPerDevice; shard ids unique, shard bytes summing to the residency
total, shard count ≤ owner devices); Metal derives the identical epochs into shared unified host memory rather
than a separate VRAM scalar.

The pairing is the **accelerator-provision seam of the post-bind provision boundary**: after bind expands the
`InferenceEngine` provider's graph, `provision` selects the **matching eligible target offering** (whose lane is
projected from that concrete node/host or elastic candidate's detected substrate, never an ambiguous cluster-wide
substrate), constructs the private `ProvisionedCudaOwnerDemand`/`ProvisionedMetalOwnerDemand` epoch witnesses by
handing the owner demands to the [Phase 9](phase_09_execution_accelerator_folds.md) accelerator-residency fold,
and rejects — with a structured `ProvisionError` at the `provision-seal` locus, before any `ProvisionedSpec` is
constructed — a served model whose family is unavailable on the serving lane, a CUDA requirement paired with a
non-CUDA target, too few devices, a malformed Unsharded/ReplicatedPerDevice/Sharded placement, unequal
source/workload keys, an incomplete coexistence-policy class domain, or any policy-permitted co-resident epoch
whose per-device aggregate exceeds net allocatable VRAM (raw `memory.total` minus the mandatory driver/runtime
reserve).

What this sub-phase does **not** own: the reserved `InferenceEngine` head and the eight-arm closed union around
it, the representational `bind`, and the object-node-multiset shape oracle
([Phase 10](phase_10_capability_bind.md)); the `provision` constructor, execution-epoch/runtime-storage/
object-store/observability/migration/scheduler-reservation expansion, and the opaque whole-deployment
`ProvisionedSpec` seal it plugs into ([Phase 11](phase_11_provision_seal.md)); the primitive
`fits`/`carve`/`place` accelerator-device / net-allocatable-VRAM / identity-complete residency-coexistence epoch
fold ([Phase 9](phase_09_execution_accelerator_folds.md)); the render of a provisioned deployment into
`[K8sObject]` (the pure `renderAll` phase); and the **live** jit-build resolve of the named `EngineRuntime`
identity into its `CacheBudget`-bounded content-addressed cache plus the runtime-checked cross-lane weight-load
residue — the live band ([Phase 38](phase_38_determinism_jitcache.md)). This phase builds the *representational*
union + relation and the pure accelerator-provision fold only; it performs no live device read and claims no
runtime proof.

**Substrate:** none — no CUDA device, no Metal host, no cluster; the gate is an in-process `cabal test` bind +
accelerator-provision fold + property/corpus battery, analogous to the Phase-9 accelerator fold and the
Phase-11 provision seal.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** the `InferenceEngine` capability and its accelerator provision are green under `cabal test` — the
`legal_inference_cuda` positive (and the `legal_inference_{singlenode,distributed}` shape pair) binds to a
well-typed `BoundServiceSpec` and **provisions to an opaque whole-deployment `ProvisionedSpec` by selecting the
matching CUDA target offering**, its policy-permitted residency/coexistence epochs folding inside per-device net
allocatable VRAM; the committed `illegal_cuda_on_cpu_target` fixture returns its exact
`ProvisionError MissingCapability Cuda` at the `provision-seal` locus with **zero provisioned values**; the
`illegal_engine_by_url` fixture **fails Gate 1** (`dhall type`) at its asserted no-such-alternative locus on the
`EngineRuntime` union; and every engine/accelerator negative — family-unavailable-on-lane, count shortage, VRAM
overcommit, source/workload-key inequality, policy-domain mismatch, residency-placement malformation, and
coexistence overcommit — returns its **specific** structured `Left`, each paired with a positive differing only
in the foreclosed dimension. The full apparatus (the concrete corpus, the Phase-0-pinned goldens, the five
committed accelerator-provision seeded mutants that must go red, and the independent reference predicate) is
named in [Gate integrity](#gate-integrity), to which this line delegates per
[§M](development_plan_standards.md#gate-integrity-delegation). A **Register-1** in-process check that runs on no
substrate.

## Gate integrity

This section pins the concrete interpretations the [§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)
clauses require for Phase 12; it is the InferenceEngine/accelerator-provision **slice** of the source
capability-binder gate corpus, partitioned to this seam (the shape-oracle, execution-epoch, runtime-storage,
object-store, observability, and migration slices live with [Phase 10](phase_10_capability_bind.md) /
[Phase 11](phase_11_provision_seal.md); the primitive accelerator/VRAM fold and its internal seeded mutant live
with [Phase 9](phase_09_execution_accelerator_folds.md)). It strengthens, never weakens, the Gate and sprint
Validations above.

- **Representative positive set (§M.7, §M.1).** The gate's positive corpus is *exactly* the three
  Phase-0-committed fixtures `dhall/examples/legal_inference_singlenode.dhall`,
  `dhall/examples/legal_inference_distributed.dhall` (the `InferenceEngine` arm bound under `SingleNode` and
  `Distributed { nodes = n }`, n ≥ 2, satisfying the [Phase-10](phase_10_capability_bind.md)
  object-node-multiset shape oracle against the reviewer-authored goldens
  `test/capability/goldens/golden_servicespec_inference_singlenode.golden` and
  `golden_servicespec_inference_distributed.golden`), and `dhall/examples/legal_inference_cuda.dhall` (the CUDA
  accelerator positive that binds and provisions by selecting the matching CUDA target offering with its
  residency/coexistence epochs inside net allocatable VRAM). All three fixtures, both goldens, and every
  expected error/locus tag below are **authored and committed in Phase 0 before the
  `Amoebius.Capability.Engine` implementation exists** (§M.1); a golden regenerated from `bind`'s own output is
  not a test. An `Immediate` provision path applies — the `InferenceEngine` owner needs no bootstrap-staged
  render activation.

- **Representative negative set (§M.7, §M.8).** The gate's engine/accelerator negative corpus is *exactly* the
  nine Phase-0-committed fixtures, each asserting **its specific failure reason** and **paired with a positive
  differing only in the foreclosed dimension**:
  - `illegal_engine_by_url` — an engine named by URL — **fails Gate 1** (`dhall type`) at an
    *unknown-constructor / no-such-alternative* type error on the `EngineRuntime` union (the union has no
    `Url`/`Download` arm), paired with `legal_inference_cuda` differing only in that the engine is a named
    catalog identity (§3.25).
  - `illegal_engine_family_unavailable_on_lane` — a served model whose engine family is unavailable on the
    serving lane — returns its committed family-unavailable-on-lane `ProvisionError` at the `provision-seal`
    locus, paired with a positive whose family *is* available on that lane.
  - `illegal_cuda_on_cpu_target` — a CUDA-requiring workload paired with a CPU-only target — returns
    `ProvisionError MissingCapability Cuda` at the `provision-seal` locus with **zero provisioned values**,
    paired with `legal_inference_cuda` differing only in the target offering's lane.
  - `illegal_accelerator_count_shortage` — returns `ProvisionError AcceleratorCountShortage`.
  - `illegal_accelerator_vram_shortage` — a case that fits raw device `memory.total` but exceeds
    `allocatableVram` — returns `ProvisionError VramOvercommit`.
  - `illegal_accelerator_source_workload_mismatch` — unequal `keys(sources)` / `keys(workloads)` — returns its
    exact source/workload-key inequality `Left`.
  - `illegal_accelerator_policy_domain_mismatch` — a missing or extra represented workload class in
    `domains(maxResidentByClass)` / `domains(maxRunningByClass)` / `classes(sources)` — returns its exact
    policy-class-domain `Left`.
  - `illegal_accelerator_residency_placement` — an invalid Unsharded/ReplicatedPerDevice/Sharded assignment
    (non-unique shard ids, wrong shard sum, or more shards than owner devices) — returns its exact
    residency-placement `Left`.
  - `illegal_accelerator_coexistence_overcommit` — steady components fit separately but a policy-permitted
    co-resident epoch is one byte over one device — returns its exact coexistence-overcommit `Left`, paired with
    a positive whose largest co-resident epoch fits by exactly that byte.

  The three accelerator net-fit negatives (`illegal_cuda_on_cpu_target`, `illegal_accelerator_count_shortage`,
  `illegal_accelerator_vram_shortage`) fail **after binding but before `renderAll`, with zero provisioned
  values**; each of the nine negatives is annotated in the validation-locus ledger with its catalog id
  (§3.25 for the engine-by-url state) and its honest foreclosure layer (Gate 1 for `illegal_engine_by_url`; the
  post-bind `provision-seal` locus for the rest).

- **Committed accelerator-provision seeded-mutant battery (§M.2).** The gate turns **red** on each of the five
  committed, re-run (never run-once) seeded mutants, drawn from the defined operator set and each independently
  required to turn the suite red:
  - `mutant_drop_accelerator_work_item` (dropped effect: remove one source/workload identity from the owner
    fold — caught by the `keys(sources) = keys(workloads)` reference predicate and
    `illegal_accelerator_source_workload_mismatch`).
  - `mutant_accept_accelerator_domain_mismatch` (guard weakening: default a missing coexistence-policy class to
    zero/serial — caught by the `domains(maxResidentByClass) = domains(maxRunningByClass) = classes(sources)`
    predicate and `illegal_accelerator_policy_domain_mismatch`).
  - `mutant_select_favorable_accelerator_epoch` (guard weakening: check only a caller-friendly non-overlap epoch
    rather than *every* policy-permitted co-resident epoch — caught by `illegal_accelerator_coexistence_overcommit`).
  - `mutant_drop_accelerator_overlap_debit` (dropped effect: omit one co-resident component from its per-device
    aggregate — caught by the independent per-device co-resident aggregation predicate and
    `illegal_accelerator_coexistence_overcommit`).
  - `mutant_skip_accelerator_shard_validation` (invariant-clause delete: accept duplicate shard ids, a wrong
    shard sum, or more shards than owner devices — caught by `illegal_accelerator_residency_placement`).

  These five are this seam's slice of the source eighteen-mutant capability-binder battery; the shape-oracle,
  execution-epoch, runtime-storage, prometheus-envelope, and prior-ref mutants are exercised by
  [Phase 10](phase_10_capability_bind.md) / [Phase 11](phase_11_provision_seal.md).

- **Independent reference predicate (§M.3).** The equivalence side is defined **independently of the code under
  test** (`Amoebius.Capability.Engine` and the Phase-9 fold): (a) a committed **hand-authored per-device
  co-resident memory aggregation table** — for each policy-permitted coexistence epoch of each owner-demand
  fixture, the expected per-device sum of every co-resident weights/KV/activation/optimizer/JIT/library
  component and the expected `allocatableVram = memory.total − mandatoryReserve` — such that
  `accepts ⟺ every epoch's per-device aggregate ≤ allocatableVram`, never by reusing the fold's own
  accumulator; (b) a committed **hand-authored family×lane availability relation** and the
  **target-offering→lane quotient table** (`apple → AppleMetal`, `linux-cpu → LinuxCpu`,
  `{ linux-cuda, windows } → Cuda`), against which the projection is checked total and the OS-vs-`Cuda` split is
  checked to have no inhabitant (there is no constructor to author a lane free of a selected offering, and no
  Linux-vs-Windows `Cuda` constructor). Product labels and raw `memory.total` totals are **never** the supply.

- **Generator coverage (§M.4).** The QuickCheck accelerator-provision property carries `cover`/`classify`
  obligations forcing the reject branches — CUDA-on-non-CUDA lane, device-count shortage, raw-fits/net-fails
  VRAM, malformed shard assignment, and coexistence overcommit — each to fire a stated minimum fraction under
  `checkCoverage`, so a generator emitting only a near-constant favorable epoch fails coverage rather than
  vacuously passing.

- **Boundary directions (§M).** Exact-fit accelerator-epoch boundaries **accept** (the largest policy-permitted
  co-resident epoch equals net allocatable VRAM to the byte; the shard sum equals the residency total; the
  device count equals the owner requirement) and each minimally-differing one-device/one-byte-short pair
  **rejects**, exercising both directions of every boundary.

## Doctrine adopted

- [`service_capability_doctrine.md §4.1`](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-target-offering-selected-and-jit-resolved-never-authored)
  — **the `InferenceEngine` capability: the engine is target-offering-selected and jit-resolved, never
  authored.** This phase builds the ninth capability's provider as a closed union of substrate-tagged
  `EngineRuntime` identities with **no arbitrary-`Url`/`Download` arm**, the target-offering→lane quotient, and
  the family×lane availability relation — the *representational* union and relation; the actual resolve is the
  live band.
- [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)
  — **the ML-asset lifecycle: one bounded content-addressed cache resolved on first miss.** The `InferenceEngine`
  provider is the Tier-1 read-side of this lifecycle: an ML engine is a **named catalog identity** the shared
  jit-build resolver materializes on first miss into a `CacheBudget`-bounded content-addressed cache — never
  baked, never fetched by URL. This phase decodes that named identity; the resolve is
  [Phase 38](phase_38_determinism_jitcache.md).
- [`service_capability_doctrine.md §4`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
  and [`§3`](../documents/engineering/service_capability_doctrine.md#3-one-canonical-provider-the-type-admits-alternates)
  — **Capability → provider → shape: the binding**, and **one canonical provider (the type admits alternates).**
  The `InferenceEngine` arm is the strictest instance of the three-part binding: its provider is selected from a
  **concrete eligible target offering** — the node/host or elastic candidate whose detected substrate projects
  the lane — not from an ambiguous cluster-wide substrate.
- [`illegal_state_techniques.md §4.7`](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)
  — **compatibility / topology relations by construction over a collection.** The **partial** family×lane
  availability relation makes a served model whose family is unavailable on the serving lane a post-bind
  `provision-seal` `Left`, realized as a relation-over-a-collection rather than a per-pair type.
- [`service_capability_doctrine.md §8`](../documents/engineering/service_capability_doctrine.md#8-capabilities-and-the-illegal-state-contract)
  — **capabilities and the illegal-state contract:** an engine cannot be named by URL (no `Url`/`Download` arm —
  Gate 1), and a CUDA-requiring workload on a non-CUDA target cannot be left half-bound (a structured
  `ProvisionError` at the `provision-seal` locus, never a runtime surprise).
- [`illegal_state_catalog.md §3.25`](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model)
  — **an ML asset named by arbitrary URL or an unready / unlanded model** — the state this phase forecloses at
  Gate 1, honoring the load-bearing limit
  ([`§2`](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)):
  a type-check proves the *binding composes*, not that the *running engine* resolved.
- [`resource_capacity_doctrine.md §3`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)
  and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — the accelerator slice of the complete resource envelope and the opaque post-fold `ProvisionedSpec`
  boundary. This phase owns the ordering for its arm: expand the `InferenceEngine` provider first, select the
  matching offering, then run the Phase-9 accelerator-residency/coexistence fold, then hand only the checked
  result to the render phase. A device/VRAM check over a pre-bind skeleton is insufficient.
- [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
  — **the illegal-state-unrepresentable contract's two typed gates** (Gate 1 the Dhall typechecker, Gate 2 the
  in-process decoder): the `EngineRuntime` union is guarded at Gate 1 (an engine-by-URL has no syntax), and the
  family-on-lane / device / VRAM insufficiencies are the post-bind `provision-seal` layer beneath both gates.
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing)
  §2 (**Register 1** — pure/golden, in-process, no cluster) and §4 (the per-run proven/tested/assumed ledger):
  the register this gate reaches and the ledger it emits, with the live jit-resolve of any engine and the
  runtime-checked cross-lane weight-load residue marked UNVERIFIED, owned by the live band.

## Sprints

## Sprint 12.1: The `InferenceEngine` capability — target-offering-selected runtime + accelerator provision 📋

**Status**: Planned
**Implementation**: `dhall/amoebius/Capability.dhall` (fill the reserved `InferenceEngine` head from
[Phase 10](phase_10_capability_bind.md): the closed `EngineRuntime` lane union, the engine-family union, and the
identity-complete `CudaOwnerDemand`/`MetalOwnerDemand` source, workload, residency, and coexistence shapes);
`src/Amoebius/Capability/Engine.hs` (the target-offering→lane quotient projection and the **partial** family×lane
availability relation plus topology-offering compatibility). The private
`ProvisionedCudaOwnerDemand`/`ProvisionedMetalOwnerDemand` epoch witnesses are constructed by the
[Phase 11](phase_11_provision_seal.md) `provision` seal (`src/Amoebius/Capacity/Provision.hs`) invoking the
[Phase 9](phase_09_execution_accelerator_folds.md) accelerator-residency/coexistence epoch fold; this sprint
supplies the owner-demand inputs, the offering→lane selection, and the family×lane gate, not the seal or the
fold — target paths, not yet built.
**Blocked by**: Phase 10 gate (the reserved nine-arm union with its `InferenceEngine` head this sprint fills);
Phase 11 gate (the whole-deployment provision seal that constructs the accelerator epoch witnesses); Phase 9
gate (the identity-complete accelerator-residency/coexistence epoch fold these owner demands feed).
**Independent Validation**: a unit + property suite confirms the `EngineRuntime` union has **no**
`Url`/`Download` arm (an engine named by URL fails `dhall type`, Gate 1); the target-offering→lane quotient
projects `apple → AppleMetal`, `linux-cpu → LinuxCpu`, `{ linux-cuda, windows } → Cuda` for a **selected target
offering** and has no constructor to author a lane free of that offering, nor a Linux-vs-Windows `Cuda` split.
It proves `keys(sources) = keys(workloads)` and
`domains(maxResidentByClass) = domains(maxRunningByClass) = classes(sources)`; derives every allowed coexistence
epoch; and rejects CUDA-on-CPU, too few devices, malformed Unsharded/ReplicatedPerDevice/Sharded placement, or
any epoch whose per-device aggregate exceeds net allocatable memory. A case that fits raw device `memory.total`
but exceeds `allocatableVram`, an omitted co-resident work item, and a favorable-epoch-only acceptance each
return their exact structured `Left`; product labels and raw totals are never supply. The reference side is the
committed hand-authored per-device aggregation table and family×lane relation (§M.3), never the fold's own
accumulator.
**Docs to update**: `documents/engineering/service_capability_doctrine.md` (§4.1 backlink),
`documents/engineering/content_addressing_doctrine.md` (§4.5 Tier-1 engine read-side),
`documents/illegal_state/illegal_state_catalog.md` (§3.25 layer reconciliation),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`service_capability_doctrine.md §4.1`](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-target-offering-selected-and-jit-resolved-never-authored)
and [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
build the ninth capability as the strictest instance of the
[`§4`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
binding — a provider selected from a **concrete eligible target offering** (whose lane is projected from that
node/host or candidate's detected substrate) and materialized on first miss, with no arm to author a download —
as a representational union and relation, then pair it to a CUDA/Metal target through the provision seal, no live
resolve.

### Deliverables
- The `InferenceEngine` capability and its closed `EngineRuntime` lane union (`AppleMetal` · `Cuda` ·
  `LinuxCpu`) with **no arbitrary-`Url`/`Download` arm** — an ML engine is a **named catalog identity**, never
  baked and never fetched by URL, so "name the engine by URL" has no syntax and fails Gate 1.
- The target-offering→lane **quotient** projection (`apple → AppleMetal`, `linux-cpu → LinuxCpu`,
  `{ linux-cuda, windows } → Cuda`, `Cuda` OS-agnostic with no Linux-vs-Windows constructor) — selected from a
  concrete eligible node/host or elastic candidate, not from an ambiguous cluster-wide substrate — and the
  closed engine-family union.
- The **partial** family×lane availability relation making a served model whose family is unavailable on the
  serving lane a post-bind **`provision-seal` `Left`** (the
  [`illegal_state_techniques.md §4.7`](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)
  relation-over-a-collection technique), plus identity-complete `CudaOwnerDemand`/`MetalOwnerDemand` values: an
  exact source inventory and equal-keyed workload map for served models, training jobs, JIT compilations, and
  library work; structural weights/KV/activation/optimizer/JIT/library residency components; and a finite
  class-complete coexistence policy. CUDA residency uses `Unsharded`, `ReplicatedPerDevice`, or explicit
  `Sharded` placement. Bytes are total for Unsharded/Sharded and per device for ReplicatedPerDevice; shard ids
  are unique, shard bytes sum to the residency total, and shard count cannot exceed owner devices. The
  [Phase-9](phase_09_execution_accelerator_folds.md) fold derives all policy-permitted epochs and sums every
  co-resident component by device; Metal derives the identical epochs into shared unified host memory rather
  than a separate VRAM scalar.
- The accelerator-provision pairing at the provision seal: after bind expands the `InferenceEngine` provider's
  graph, `provision` selects the **matching eligible target offering**, constructs the private
  `ProvisionedCudaOwnerDemand`/`ProvisionedMetalOwnerDemand` epoch witnesses via the Phase-9 fold, and fits each
  derived epoch against per-device **net allocatable VRAM** (raw `memory.total` minus the mandatory
  driver/runtime reserve). A cluster without the required accelerator family or sufficient VRAM cannot produce
  `ProvisionedSpec`: a CUDA requirement on a non-CUDA target returns `ProvisionError MissingCapability Cuda`, a
  device shortage returns `ProvisionError AcceleratorCountShortage`, and a raw-fits/net-fails case returns
  `ProvisionError VramOvercommit` — each at the `provision-seal` locus with **zero provisioned values**, before
  `renderAll`.
- An in-file honesty note: this is the representational union + relation and the pure accelerator-provision fold
  only; the actual jit-build resolve into the `CacheBudget`-bounded content-addressed cache, and the
  runtime-checked cross-lane weight-load residue, are the live band ([Phase 38](phase_38_determinism_jitcache.md))
  — sibling evidence where infernix's `Worker.hs` selects (never fetches) its engine, not an amoebius result.

### Validation
1. An engine named by URL fails Gate 1 at its asserted `dhall type` no-such-alternative locus; an unavailable
   family-on-lane, CUDA-on-CPU target, insufficient device count, unequal source/workload keys, unequal
   policy-class domains, invalid shard ids/sum/count, unplaceable residency, raw-fits/net-fails epoch, omitted
   co-resident work item, or favorable-epoch shortcut returns its exact structured `Left` at the `provision-seal`
   locus; the target-offering→lane quotient is total and the OS-vs-`Cuda` split has no inhabitant; the
   `legal_inference_cuda` positive provisions to an opaque `ProvisionedSpec` by selecting the matching CUDA
   offering. Every equivalence is checked against the independent hand-authored per-device aggregation table and
   family×lane relation (§M.3), never the fold's own accumulator.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 12.2: The accelerator-provision corpus + the Register-1 gate 📋

**Status**: Planned
**Implementation**: `test/capability/EngineAcceleratorProps.hs` (the engine/accelerator property + coexistence-
epoch battery — offering→lane quotient totality, family×lane relation, source/workload-key and policy-domain
equality, shard validation, and exact-fit/one-device/one-byte-short cases); the shared
`test/capability/BindGate.hs` gate harness (this seam's entries in its validation-locus ledger + coverage-
assertion machinery); the **Phase-0-committed** fixtures
`dhall/examples/{legal_inference_singlenode,legal_inference_distributed,legal_inference_cuda,
illegal_engine_by_url,illegal_engine_family_unavailable_on_lane,illegal_cuda_on_cpu_target,
illegal_accelerator_count_shortage,illegal_accelerator_vram_shortage,
illegal_accelerator_source_workload_mismatch,illegal_accelerator_policy_domain_mismatch,
illegal_accelerator_residency_placement,illegal_accelerator_coexistence_overcommit}.dhall`, the reviewer-authored
goldens `test/capability/goldens/golden_servicespec_inference_{singlenode,distributed}.golden` (authored before
`bind` exists), and the five seeded mutants under
`test/capability/mutants/{mutant_drop_accelerator_work_item,mutant_accept_accelerator_domain_mismatch,
mutant_select_favorable_accelerator_epoch,mutant_drop_accelerator_overlap_debit,
mutant_skip_accelerator_shard_validation}` — target paths, not yet built.
**Blocked by**: Sprint 12.1; Phase 11 gate (the provision seal these negatives return `Left` from); Phase 9 gate
(the accelerator-residency/coexistence fold); Phase 4 gate (the `dhall type` positive Gate-1 corpus the
engine-by-URL negative pairs against).
**Independent Validation**: `cabal test capability-spec` is green for the InferenceEngine/accelerator slice —
`legal_inference_cuda` binds and provisions to an opaque `ProvisionedSpec` by selecting the matching CUDA
offering; the `legal_inference_{singlenode,distributed}` pair binds byte-invariant (beta-normalized app-surface
slices from distinct composed files) under both shapes and structurally different by the
[Phase-10](phase_10_capability_bind.md) object-node-multiset oracle (red on scalar-only / copied-shape-tag)
against its Phase-0-committed golden; `illegal_engine_by_url` fails `dhall type` at its asserted locus; each of
the nine engine/accelerator provision negatives returns its specifically-tagged `Left` at the `provision-seal`
locus, each paired with a minimally-differing positive; the QuickCheck coverage obligations meet `checkCoverage`
on every reject branch; exact-fit accelerator-epoch/shard/net-VRAM boundaries accept and each one-device or
one-byte-short pair rejects; and the suite goes **red** under each of the five committed accelerator-provision
seeded mutants. The validation-locus ledger is present and its Phase-6-style coverage-assertion machinery turns
the suite **red** if any named fixture, negative reason, or mutant in this seam is absent — 'honestly
classifies' is a machine oracle, not a hand-written attestation.
**Docs to update**: `documents/engineering/service_capability_doctrine.md` (§4.1),
`documents/illegal_state/illegal_state_catalog.md` (§3.25 → realized layer),
`documents/engineering/content_addressing_doctrine.md` (§4.5 Tier-1 engine read-side),
`documents/engineering/testing_doctrine.md`, `DEVELOPMENT_PLAN/README.md` (flip the Phase-12 status when the gate
passes), `DEVELOPMENT_PLAN/substrates.md` (the Phase-12 `none` gate row).

### Objective
Adopt [`service_capability_doctrine.md §8`](../documents/engineering/service_capability_doctrine.md#8-capabilities-and-the-illegal-state-contract)
and [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing)
§2/§4: assemble this seam's single Register-1 gate — the `InferenceEngine` positives bind and provision by
selecting the matching target offering while every URL-named engine has no syntax and every insufficient
accelerator target returns its specific `ProvisionError` without constructing `ProvisionedSpec` — and emit the
per-entry validation-locus ledger that names the honest foreclosure layer of each.

### Deliverables
- The concrete corpus named in [Gate integrity](#gate-integrity): the three positive fixtures
  (`legal_inference_{singlenode,distributed}`, `legal_inference_cuda`) with their two reviewer-authored goldens,
  and the nine engine/accelerator negatives, each paired with a positive differing only in the foreclosed
  dimension and each asserting its specific `dhall type` error locus or `provision-seal` `ProvisionError` tag.
- The property battery: the offering→lane quotient totality property (and the no-inhabitant OS-vs-`Cuda`
  split); the family×lane availability property; the `keys(sources) = keys(workloads)` and
  `domains(maxResidentByClass) = domains(maxRunningByClass) = classes(sources)` equalities; the shard-validation
  property (unique ids, sum-to-total, count ≤ devices); and the coexistence-epoch property that folds **every**
  policy-permitted co-resident epoch against per-device net allocatable VRAM — all checked against the
  independent hand-authored aggregation table / family×lane relation (§M.3), with `cover`/`classify` +
  `checkCoverage` forcing each reject branch (§M.4).
- The five committed accelerator-provision seeded mutants (§M.2), committed and re-run (not run once), each
  individually required to turn the suite red: `mutant_drop_accelerator_work_item`,
  `mutant_accept_accelerator_domain_mismatch`, `mutant_select_favorable_accelerator_epoch`,
  `mutant_drop_accelerator_overlap_debit`, `mutant_skip_accelerator_shard_validation`.
- A Register-1 validation-locus ledger mapping every entry to its catalog id (§3.25 for the engine-by-URL state)
  and honest layer (Gate 1 for `illegal_engine_by_url`; the post-bind `provision-seal` locus for the rest),
  backed by Phase-6-style coverage-assertion machinery (the ledger goes **red** if any corpus entry, negative
  reason, or seeded mutant named above is absent), explicitly marking the runtime residue (the engine actually
  resolving into its bounded cache, the cross-lane weight-load residue) deferred to the live band — never
  reported as proven.

### Validation
1. `cabal test capability-spec` is green over the InferenceEngine/accelerator slice — `legal_inference_cuda`
   provisions by selecting the matching CUDA offering; the `legal_inference_{singlenode,distributed}` pair is
   byte-invariant and structurally different by the object-node-multiset oracle against its committed golden;
   `illegal_engine_by_url` fails `dhall type` at its asserted locus; each provision negative returns its
   specifically-tagged `Left`; the coverage obligations meet `checkCoverage`; exact-fit boundaries accept and
   each one-device/one-byte-short pair rejects; and the suite is red under each of the five committed seeded
   mutants. The validation-locus ledger is present and its coverage-assertion machinery (Phase-6 precedent)
   turns the suite **red** if any named fixture, negative reason, or mutant is missing.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/service_capability_doctrine.md` — backlink §4.1 (the `InferenceEngine` engine union),
  §4/§3 (the provider selected from a concrete eligible target offering), and §8 (the illegal-state instances) to
  the implemented `Amoebius.Capability.Engine`; confirm the `EngineRuntime` union stayed URL-free and the
  offering→lane quotient stayed total.
- `documents/engineering/content_addressing_doctrine.md` — reconcile §4.5's Tier-1 engine as the
  `InferenceEngine` provider whose named catalog identity this binder decodes; keep the jit-resolve into the
  bounded cache as the live-band residue.
- `documents/illegal_state/illegal_state_catalog.md` — annotate §3.25 (engine by URL) with its realized layer
  (type-foreclosed, Gate 1) and the family-unavailable-on-lane state as a checked rejection at the post-bind
  `provision-seal` locus; keep the runtime-checked residue (engine resolved) deferred.
- `documents/engineering/resource_capacity_doctrine.md` — record that the accelerator arm of the post-fold
  boundary (§3/§4) is exercised through the `InferenceEngine` binding and the Phase-9 residency/coexistence fold
  at this provision seal.
- `documents/engineering/dsl_doctrine.md` — the capability-model instance of the two-gate contract for the
  `EngineRuntime` union (Gate 1) and the accelerator provision seal beneath it.
- `documents/engineering/testing_doctrine.md` — record the Register-1 property + corpus ledger this gate emits
  (engine-resolve fidelity and cross-lane weight-load residue UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-12 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-12 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register the `InferenceEngine` fill of `dhall/amoebius/Capability.dhall`,
  `src/Amoebius/Capability/Engine.hs`, and the engine/accelerator property + gate suites as Phase-12 design-first
  rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *binding-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the accelerator/net-allocatable-VRAM invariant
- [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) — §4.1 the
  substrate-selected `InferenceEngine`, §3/§4 the provider+shape binding, §8 the illegal-state instances
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — §3.25 (engine by URL), with §2
  the load-bearing limit
- [Illegal State Techniques](../documents/illegal_state/illegal_state_techniques.md) — §4.7 compatibility/topology
  relations by construction over a collection (the family×lane relation)
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md) — §4.5 the ML-asset
  lifecycle whose Tier-1 jit-resolved engine is the `InferenceEngine` provider
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — §5 the two typed gates a capability binding decodes through
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 1, §4 the per-run ledger
- [phase_09](phase_09_execution_accelerator_folds.md) — the identity-complete accelerator-device / net-allocatable-VRAM
  / residency-coexistence epoch fold these owner demands feed
- [phase_10](phase_10_capability_bind.md) — the closed nine-arm capability union (whose reserved `InferenceEngine`
  head this phase fills), the representational `bind`, and the object-node-multiset shape oracle
- [phase_11](phase_11_provision_seal.md) — the whole-deployment provision seal that constructs the accelerator
  epoch witnesses and returns the `provision-seal` `Left`s this phase exercises
- [phase_38](phase_38_determinism_jitcache.md) — the live jit-build engine resolver + `CacheBudget` cache that
  materializes the named `EngineRuntime` identity this phase only decodes
