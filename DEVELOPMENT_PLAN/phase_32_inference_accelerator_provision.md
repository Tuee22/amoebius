# Phase 32: InferenceEngine capability + accelerator provision

> **Purpose**: Fill the ninth (`InferenceEngine`) capability arm as a representational union and relation — the
> closed `EngineRuntime` lane union with no `Url`/`Download` arm, the target-offering→lane quotient, the partial
> family×lane availability relation, and identity-complete `CudaOwnerDemand`/`MetalOwnerDemand` shapes — then
> pair a served model to a concrete CUDA/Metal target so that every policy-permitted residency/coexistence epoch
> folds against modeled per-device net allocatable VRAM at the post-bind provision seal, requiring before render that a
> CUDA-requiring workload on a CPU-only target has no deployable value.
> **Read this if**: phase 32 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/content_addressing_determinism.md, documents/engineering/resource_capacity_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 32.1: The `InferenceEngine` capability — target-offering-selected runtime + accelerator provision ⏸️](#sprint-321-the-inferenceengine-capability--target-offering-selected-runtime--accelerator-provision-)
- [Sprint 32.2: The accelerator-provision corpus + the Register-1 gate ⏸️](#sprint-322-the-accelerator-provision-corpus--the-register-1-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 31, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** This pure Haskell phase is to make amoebius's *"an ML engine is a named catalog identity the substrate selects and the shared
jit-build resolver materializes on first miss — never authored, never baked, never URL-fetched"* invariant
executable as the strictest instance of the capability→provider→shape binding. Its target **fills the ninth capability arm** whose reserved head [Phase 30](phase_30_capability_bind.md) defines: the `InferenceEngine` capability and
its closed `EngineRuntime` lane union (`AppleMetal` · `Cuda` · `LinuxCpu`) with **no arbitrary-`Url`/`Download` arm**, the closed engine-family union, the target-offering→lane **quotient** projection
(`apple → AppleMetal`, `linux-cpu → LinuxCpu`, `{ linux-cuda, windows } → Cuda`, `Cuda` OS-agnostic with no
Linux-vs-Windows constructor), and the **partial** family×lane availability relation. The target includes the
identity-complete `CudaOwnerDemand`/`MetalOwnerDemand` values: an exact source inventory and equal-keyed
workload map for served models, training jobs, JIT compilations, and library work; structural
weights/KV/activation/optimizer/JIT/library residency components; and a finite class-complete coexistence
policy. CUDA residency uses `Unsharded`, `ReplicatedPerDevice`, or explicit `Sharded` placement (bytes total for
Unsharded/Sharded, per device for ReplicatedPerDevice; shard ids unique, shard bytes summing to the residency
total, shard count ≤ owner devices); Metal derives the identical epochs into shared unified host memory rather
than a separate VRAM scalar. Haskell values own every case and expectation; any Dhall or serialized case is
generated lazily beneath `.build/**`.

The pairing is the **accelerator-provision seam of the post-bind provision boundary**: after bind expands the
`InferenceEngine` provider's graph, `provision` selects the **matching eligible target offering** (whose lane is
projected from a supplied concrete target-offering or elastic-candidate model, never from a live or ambiguous
cluster-wide detection). It constructs the private `ProvisionedCudaOwnerDemand`/`ProvisionedMetalOwnerDemand` epoch witnesses by
handing the owner demands to the [Phase 29](phase_29_execution_accelerator_folds.md) accelerator-residency fold,
and rejects — with a structured `ProvisionError` at the `provision-seal` locus, before any `ProvisionedSpec` is
constructed — a served model whose family is unavailable on the serving lane, a CUDA requirement paired with a
non-CUDA target, too few devices, a malformed Unsharded/ReplicatedPerDevice/Sharded placement, unequal
source/workload keys, an incomplete coexistence-policy class domain, or any policy-permitted co-resident epoch
whose per-device aggregate exceeds modeled net allocatable VRAM (the supplied raw-memory value minus the
mandatory driver/runtime reserve).

What this sub-phase does **not** own:
- the reserved `InferenceEngine` head and the eight-arm closed union around it, the representational `bind`,
  and the object-node-multiset shape oracle ([Phase 30](phase_30_capability_bind.md))
- the `provision` constructor, execution-epoch/runtime-storage/
  object-store/observability/migration/scheduler-reservation expansion, and the opaque whole-deployment
  `ProvisionedSpec` seal it plugs into ([Phase 31](phase_31_provision_seal.md))
- the primitive `fits`/`carve`/`place` accelerator-device / net-allocatable-VRAM / identity-complete
  residency-coexistence epoch fold ([Phase 29](phase_29_execution_accelerator_folds.md))
- the render of a provisioned deployment into `[K8sObject]` (the pure `renderAll` phase)
- and the **live** jit-build resolve of the named `EngineRuntime` identity into its `CacheBudget`-bounded
  content-addressed cache plus the runtime-checked cross-lane weight-load residue — the live band
  ([Phase 80](phase_80_determinism_jitcache.md)).

This phase targets the *representational* union + relation and the pure accelerator-provision fold only; it
performs no live device read and claims no runtime proof.

**Phase scope:** one target claim — a Haskell model requiring an accelerator absent from its supplied target
offering has no deployable value. No device is queried and no runtime behavior is claimed.

**Substrate:** none — no CUDA device, Metal host, cluster, or other hardware; the canonical Haskell gate owns the verdict.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure/semantic-oracle, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 31](phase_31_provision_seal.md)
**Gate:** `pb validate phase 32`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — a pure Haskell model requiring an accelerator absent from its supplied target offering has no deployable value; any Dhall or serialized case is generated beneath `.build/**`; no device, driver, or runtime is observed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 32` is future public spelling only. Before current reviewer approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 31; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

## Doctrine adopted

- [`extension_conformance_doctrine.md` §2 — What an extension is](../documents/engineering/extension_conformance_doctrine.md#2-what-an-extension-is) — inferenceEngine capability + accelerator provision is admitted by satisfying the contract, not by appearing on a list.
- [`service_capability_doctrine.md` §4.1 — The InferenceEngine capability — the engine is target-offering-selected and jit-resolved, never authored](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-target-offering-selected-and-jit-resolved-never-authored)
  — **the `InferenceEngine` capability: the engine is target-offering-selected and jit-resolved, never authored.** The target builds the ninth capability's provider as a closed union of substrate-tagged
  `EngineRuntime` identities with **no arbitrary-`Url`/`Download` arm**, the target-offering→lane quotient, and
  the family×lane availability relation — the *representational* union and relation; the actual resolve is the
  live band.
- [`content_addressing_determinism.md` §4.5 — The ML-asset lifecycle: one bounded content-addressed cache, resolved on first miss](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)
  — **the ML-asset lifecycle: one bounded content-addressed cache resolved on first miss.** The `InferenceEngine`
  provider is the Tier-1 read-side of this lifecycle: an ML engine is a **named catalog identity** the shared
  jit-build resolver materializes on first miss into a `CacheBudget`-bounded content-addressed cache — never
  baked, never fetched by URL. This phase decodes that named identity; the resolve is
  [Phase 80](phase_80_determinism_jitcache.md).
- [`service_capability_doctrine.md` §4 — Capability → provider → shape: the binding](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
  and [`service_capability_doctrine.md` §3 — Canonical providers; extension is capability-specific](../documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific)
  — **Capability → provider → shape: the binding**, and **canonical providers with capability-specific extension.**
  The `InferenceEngine` arm is the strictest instance of the three-part binding: its provider is selected from a
  **concrete eligible target offering** — the node/host or elastic candidate whose detected substrate projects
  the lane — not from an ambiguous cluster-wide substrate.
- [`illegal_state_techniques.md` §4.7 — Compatibility / topology relations by construction over a collection](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)
  — **compatibility / topology relations by construction over a collection.** The **partial** family×lane
  availability relation makes a served model whose family is unavailable on the serving lane a post-bind
  `provision-seal` `Left`, realized as a relation-over-a-collection rather than a per-pair type.
- [`service_capability_doctrine.md` §8 — Capabilities and the illegal-state contract](../documents/engineering/service_capability_doctrine.md#8-capabilities-and-the-illegal-state-contract)
  — **capabilities and the illegal-state contract:** an engine cannot be named by URL (no `Url`/`Download` arm —
  dhall-typecheck), and a CUDA-requiring workload on a non-CUDA target cannot be left half-bound (a structured
  `ProvisionError` at the `provision-seal` locus, never a runtime surprise).
- [`illegal_state_ml_asset.md` §3.25 — An ML asset named by arbitrary URL (or an unready / unlanded model)](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model)
  — **an ML asset named by arbitrary URL or an unready / unlanded model** — the state this phase forecloses at
  dhall-typecheck, honoring the load-bearing limit
  ([`illegal_state_catalog.md` §2 — The load-bearing limit: a type-check proves the spec composes, not that the cluster enforces it](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)):
  a type-check proves the *binding composes*, not that the *running engine* resolved.
- [`resource_capacity_doctrine.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)
  and [`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — the accelerator slice of the complete resource envelope and the opaque post-fold `ProvisionedSpec`
  boundary. This phase owns the ordering for its arm: expand the `InferenceEngine` provider first, select the
  matching offering, then run the Phase-29 accelerator-residency/coexistence fold, then hand only the checked
  result to the render phase. A device/VRAM check over a pre-bind skeleton is insufficient.
- [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
  — **the illegal-state-unrepresentable contract's typed spec gates** (dhall-typecheck the Dhall typechecker, gadt-decode the
  in-process decoder): the `EngineRuntime` union is guarded at dhall-typecheck (an engine-by-URL has no syntax), and the
  family-on-lane / device / VRAM insufficiencies are the post-bind `provision-seal` layer beneath both gates.
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) (**Register 1** — pure/semantic-oracle, in-process, no cluster) and [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) (the per-run proven/tested/assumed ledger):
  the register this gate reaches and the ledger it emits, with the live jit-resolve of any engine and the
  runtime-checked cross-lane weight-load residue marked UNVERIFIED, owned by the live band.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanently invalidated history.** Every completion, seal, reseal, transcript, evidence, and
> closure statement in the sprint bodies below is rejected as current validation. The material is retained
> only as a target-capability inventory and cannot support status, promotion, or a validation claim.

## Sprint 32.1: The `InferenceEngine` capability — target-offering-selected runtime + accelerator provision ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 31](phase_31_provision_seal.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`service_capability_doctrine.md §4.1`](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-target-offering-selected-and-jit-resolved-never-authored)
and [`content_addressing_determinism.md §4.5`](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
build the ninth capability as the strictest instance of the
[`§4`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
binding — a provider selected from a **concrete eligible target offering** (whose lane is projected from that
node/host or candidate's detected substrate) and materialized on first miss, with no arm to author a download —
as a representational union and relation, then pair it to a CUDA/Metal target through the provision seal, no live
resolve.

### Deliverables

- The `InferenceEngine` capability and its closed `EngineRuntime` lane union (`AppleMetal` · `Cuda` ·
  `LinuxCpu`) with **no arbitrary-`Url`/`Download` arm** — an ML engine is a **named catalog identity**, never
  baked and never fetched by URL, so "name the engine by URL" has no syntax and fails dhall-typecheck.
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
  [Phase-29](phase_29_execution_accelerator_folds.md) fold derives all policy-permitted epochs and sums every
  co-resident component by device; Metal derives the identical epochs into shared unified host memory rather
  than a separate VRAM scalar.
- The accelerator-provision pairing at the provision seal: after bind expands the `InferenceEngine` provider's
  graph, `provision` selects the **matching eligible target offering**, constructs the private
  `ProvisionedCudaOwnerDemand`/`ProvisionedMetalOwnerDemand` epoch witnesses via the Phase-29 fold, and fits each
  derived epoch against per-device **net allocatable VRAM** (raw `memory.total` minus the mandatory
  driver/runtime reserve). A cluster without the required accelerator family or sufficient VRAM cannot produce
  `ProvisionedSpec`: a CUDA requirement on a non-CUDA target returns `ProvisionError MissingCapability Cuda`, a
  device shortage returns `ProvisionError AcceleratorCountShortage`, and a raw-fits/net-fails case returns
  `ProvisionError VramOvercommit` — each at the `provision-seal` locus with **zero provisioned values**, before
  `renderAll`.
- An in-file honesty note: this is the representational union + relation and the pure accelerator-provision fold
  only; the actual jit-build resolve into the `CacheBudget`-bounded content-addressed cache, and the
  runtime-checked cross-lane weight-load residue, are the live band ([Phase 80](phase_80_determinism_jitcache.md))
  — sibling evidence where infernix's `Worker.hs` selects (never fetches) its engine, not an amoebius result.

### Validation

1. An engine named by URL fails dhall-typecheck at its asserted `dhall type` no-such-alternative locus; an unavailable
   family-on-lane, CUDA-on-CPU target, insufficient device count, unequal source/workload keys, unequal
   policy-class domains, invalid shard ids/sum/count, unplaceable residency, raw-fits/net-fails epoch, omitted
   co-resident work item, or favorable-epoch shortcut returns its exact structured `Left` at the `provision-seal`
   locus; the target-offering→lane quotient is total and the OS-vs-`Cuda` split has no inhabitant; the
   `legal_inference_cuda` positive provisions to an opaque `ProvisionedSpec` by selecting the matching CUDA
   offering. Every equivalence is checked against the independent hand-authored per-device aggregation table and
   family×lane relation (§M.3), never the fold's own accumulator.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work
includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and
phase-specific obligation in the redesigned gate. The URL-free union, quotient, family relation, opaque
checked accelerator, exact identity/policy domains, permitted epochs, and residency rules remain target claims
requiring fresh evidence.

## Sprint 32.2: The accelerator-provision corpus + the Register-1 gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 32.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`service_capability_doctrine.md §8`](../documents/engineering/service_capability_doctrine.md#8-capabilities-and-the-illegal-state-contract)
and [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)
[§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)/[§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact): assemble this seam's single Register-1 gate — the `InferenceEngine` positives bind and provision by
selecting the matching target offering while every URL-named engine has no syntax and every insufficient
accelerator target returns its specific `ProvisionError` without constructing `ProvisionedSpec` — and emit the
per-entry validation-locus ledger that names the honest foreclosure layer of each.

### Deliverables

- The concrete corpus named in [Gate integrity](#gate-integrity): the three positive fixtures
  (`legal_inference_{singlenode,distributed}`, `legal_inference_cuda`) with the authored Phase-30 semantic projection,
  and the nine engine/accelerator negatives, each paired with a positive differing only in the foreclosed
  dimension and each asserting its specific `dhall type` error locus or `provision-seal` `ProvisionError` tag.
- The property battery: the offering→lane quotient totality property (and the no-inhabitant OS-vs-`Cuda`
  split); the family×lane availability property; the `keys(sources) = keys(workloads)` and
  `domains(maxResidentByClass) = domains(maxRunningByClass) = classes(sources)` equalities; the shard-validation
  property (unique ids, sum-to-total, count ≤ devices); and the coexistence-epoch property that folds **every**
  policy-permitted co-resident epoch against per-device net allocatable VRAM — all checked against the
  independent hand-authored aggregation table / family×lane relation (§M.3), with `cover`/`classify` +
  `checkCoverage` forcing each reject branch (§M.4).
- Five reviewed Haskell accelerator-provision mutation operators (§M.2), applied to temporary production
  subjects beneath `.build/mutants/**` and re-run, each individually required to turn the suite red:
  `mutant_drop_accelerator_work_item`,
  `mutant_accept_accelerator_domain_mismatch`, `mutant_select_favorable_accelerator_epoch`,
  `mutant_drop_accelerator_overlap_debit`, `mutant_skip_accelerator_shard_validation`.
- A Register-1 validation-locus ledger mapping every entry to its catalog id ([§3.25](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model) for the engine-by-URL state)
  and honest layer (dhall-typecheck for `illegal_engine_by_url`; the post-bind `provision-seal` locus for the rest),
  backed by Phase-27-style coverage-assertion machinery (the ledger goes **red** if any corpus entry, negative
  reason, or seeded mutant named above is absent), explicitly marking the runtime residue (the engine actually
  resolving into its bounded cache, the cross-lane weight-load residue) deferred to the live band — never
  reported as proven.

### Validation

1. Rejected historical observation: the `capability-spec` Cabal suite was recorded green over the
   InferenceEngine/accelerator slice — `legal_inference_cuda`
   provisions by selecting the matching CUDA offering; the `legal_inference_{singlenode,distributed}` pair is
   byte-invariant and structurally different by the object-node-multiset oracle against its authored semantic projection;
   `illegal_engine_by_url` fails `dhall type` at its asserted locus; each provision negative returns its
   specifically-tagged `Left`; the coverage obligations meet `checkCoverage`; exact-fit boundaries accept and
   each one-device/one-byte-short pair rejects; and the suite is red under each of the five applied Haskell
   mutants. The validation-locus ledger is present and its coverage-assertion machinery (Phase-27 precedent)
   turns the suite **red** if any named fixture, negative reason, or mutant is missing.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work
includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and
phase-specific obligation in the redesigned gate. The eleven-sided Register-1 gate, 17-row locus ledger,
34-unit five-calculus projection, 18 metrics, and 29-surface/45-item join remain unaccepted target coverage.

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

- `documents/engineering/service_capability_doctrine.md` — backlink §4.1 (the `InferenceEngine` engine union),
  §4/§3 (the provider selected from a concrete eligible target offering), and §8 (the illegal-state instances) to
  the implemented `Amoebius.Capability.Engine`; confirm the `EngineRuntime` union stayed URL-free and the
  offering→lane quotient stayed total.
- `documents/engineering/content_addressing_doctrine.md` — reconcile §4.5's Tier-1 engine as the
  `InferenceEngine` provider whose named catalog identity this binder decodes; keep the jit-resolve into the
  bounded cache as the live-band residue.
- `documents/illegal_state/illegal_state_catalog.md` — annotate §3.25 (engine by URL) with its realized layer
  (type-foreclosed, dhall-typecheck) and the family-unavailable-on-lane state as a checked rejection at the post-bind
  `provision-seal` locus; keep the runtime-checked residue (engine resolved) deferred.
- `documents/engineering/resource_capacity_doctrine.md` — record that the accelerator arm of the post-fold
  boundary (§3/§4) is exercised through the `InferenceEngine` binding and the Phase-29 residency/coexistence fold
  at this provision seal.
- `documents/engineering/dsl_doctrine.md` — the capability-model instance of the two-gate contract for the
  `EngineRuntime` union (dhall-typecheck) and the accelerator provision seal beneath it.
- `documents/engineering/testing_doctrine.md` — record the Register-1 property + corpus ledger this gate emits
  (engine-resolve fidelity and cross-lane weight-load residue UNVERIFIED).

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — only the promotion authority may change Phase 32 after reviewing a qualified
  candidate; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-32 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register the Haskell `InferenceEngine` capability projection,
  `src/Amoebius/Capability/Engine.hs`, and the Haskell engine/accelerator property and oracle suites as
  Phase-32 design-first rows. The Dhall projection is lazy output beneath `.build/dhall/**`.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *binding-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the accelerator/net-allocatable-VRAM invariant
- [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) — [§4.1](../documents/engineering/service_capability_doctrine.md#41-the-inferenceengine-capability--the-engine-is-target-offering-selected-and-jit-resolved-never-authored) the
  substrate-selected `InferenceEngine`, [§3](../documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific)/[§4](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding) the provider+shape binding, [§8](../documents/engineering/service_capability_doctrine.md#8-capabilities-and-the-illegal-state-contract) the illegal-state instances
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — [§3.25](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model) (engine by URL), with [§2](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)
  the load-bearing limit
- [Illegal State Techniques](../documents/illegal_state/illegal_state_techniques.md) — [§4.7](../documents/illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection) compatibility/topology
  relations by construction over a collection (the family×lane relation)
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md) — [§4.5](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss) the ML-asset
  lifecycle whose Tier-1 jit-resolved engine is the `InferenceEngine` provider
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — [§5](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) the typed spec gates a capability binding decodes through
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) Register 1, [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run ledger
- [phase_29](phase_29_execution_accelerator_folds.md) — the identity-complete accelerator-device / net-allocatable-VRAM
  / residency-coexistence epoch fold these owner demands feed
- [phase_30](phase_30_capability_bind.md) — the closed nine-arm capability union (whose reserved `InferenceEngine` head this phase fills), the representational `bind`, and the object-node-multiset shape oracle
- [phase_31](phase_31_provision_seal.md) — the whole-deployment provision seal that constructs the accelerator
  epoch witnesses and returns the `provision-seal` `Left`s this phase exercises
- [phase_80](phase_80_determinism_jitcache.md) — the live jit-build engine resolver + `CacheBudget` cache that
  materializes the named `EngineRuntime` identity this phase only decodes
