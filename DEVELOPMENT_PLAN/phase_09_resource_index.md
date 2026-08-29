# Phase 9: Capacity core fold + topology relation

> **Purpose**: Specify the target Haskell capability to provide a pure Haskell base-capacity fold
> and finite compute-engine/topology relation that reject overcommitment and incompatible placement
> without consulting a host or cluster.
> **Read this if**: Phase 9 is the open contract, or a later phase consumes its base placement witness.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/substrate_node_inventory.md, documents/illegal_state/illegal_state_catalog.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 9.1: Base capacity and topology witness ⏸️](#sprint-91-base-capacity-and-topology-witness-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 8, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to provide a pure Haskell base-capacity fold and finite
compute-engine/topology relation that reject overcommitment and incompatible placement without
consulting a host or cluster.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — provide a pure Haskell base-capacity fold and finite
compute-engine/topology relation that reject overcommitment and incompatible placement without
consulting a host or cluster. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 8](phase_08_scope_index.md)
**Gate:** `pb validate phase 09`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target capability only — provide a pure Haskell base-capacity fold and finite compute-engine/topology relation that reject overcommitment and incompatible placement without consulting a host or cluster. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 09` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 08; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- [`resource_capacity_doctrine.md` §1 — Capacity is a budget the fold consumes, and overcommit is a checked rejection](../documents/engineering/resource_capacity_doctrine.md#1-capacity-is-a-budget-the-fold-consumes-and-overcommit-is-a-checked-rejection): demand admission returns a witness or a structured refusal.
- [`resource_capacity_doctrine.md` §2 — The load-bearing honesty limit: a capacity sum is a decode-foreclosed check, never type-foreclosed](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed): pure capacity arithmetic is a checked decision, never proof of live enforcement.
- [`resource_capacity_folds.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting): base vectors nest through total fit, carve, and placement operations.
- [`resource_capacity_folds.md` §4.1 — `place` branches: static proves a placement, dynamic proves a growth envelope](../documents/engineering/resource_capacity_folds.md#41-place-branches-static-proves-a-placement-dynamic-proves-a-growth-envelope): fixed supply returns assignments while elastic supply returns a quota-bounded envelope.
- [`cluster_topology_doctrine.md` §2 — `ComputeEngine`: a closed union, EKS a first-class arm](../documents/engineering/cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm): Kind, rke2, and managed EKS form the closed engine set.
- [`cluster_topology_doctrine.md` §5 — The compatibility relation (technique §4.7): only compatible pairs have a constructor](../documents/engineering/cluster_topology_doctrine.md#5-the-compatibility-relation-technique-47-only-compatible-pairs-have-a-constructor): the finite engine/environment relation rejects incompatible pairs.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): runtime surface enumeration joins to separately authored expected decisions.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 9.1: Base capacity and topology witness ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 8](phase_08_scope_index.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt [`resource_capacity_folds.md` §4 — the total fold](../documents/engineering/resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting)
and [`cluster_topology_doctrine.md` §5 — the compatibility relation](../documents/engineering/cluster_topology_doctrine.md#5-the-compatibility-relation-technique-47-only-compatible-pairs-have-a-constructor): return a checked witness only for base demands that fit compatible supply.

### Deliverables

- A closed base resource vector with explicit request, limit, reserve, headroom, slot, and logical ephemeral axes.
- Total fit and zero-capable subtraction operations with stable axis-specific errors.
- Fixed-node placement assignments and bounded elastic growth-envelope witnesses.
- A closed compute-engine, host-environment, node-supply, and topology compatibility model.
- Fifteen exact fold negative/twin pairs and two positive topology cases.
- Seven Haskell specific-reason compiler pairs.
- Four coverage-bound properties with a separately implemented placement validator.
- Nineteen registry-backed mutants and an eight-current/three-deferred validation-locus join.
- A contained Register-1 gate with architecture, source-snapshot, ledger, surface, and exact run observations.

### Validation

1. Require all fifteen fold cases to return their exact errors and every distinct legal twin to succeed.
2. Construct and place both positive topologies; exhaust all nine compatibility pairs against the independent
   relation; validate every returned witness through `validatePlacement`.
3. Compile each Haskell legal twin and reject its illegal twin at the pinned reason.
4. Meet both-direction coverage floors for all four properties and require all nineteen mutations, including
   five validator weakenings, to turn red at their declared loci.
5. Join all eleven Phase-9 catalogue subcases, requiring eight discharged and three Phase-25 deferrals; join
   every test surface, keep output generated, and bind the result to the natural architecture and snapshot.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/resource_capacity_doctrine.md` and `resource_capacity_folds.md` — record the current pure fold result and preserve the runtime residue.
- `documents/engineering/cluster_topology_doctrine.md` — record the finite compatibility and placement result without claiming a node join.
- `documents/engineering/substrate_node_inventory.md` — distinguish Haskell-declared capacity cases from live inventory observation.
- `documents/engineering/testing_doctrine.md` — retain sampled-versus-exhausted honesty and exact catalogue ownership.
- `documents/illegal_state/illegal_state_catalog.md` — record the eleven Phase-9 loci and their bounded evidence.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, and `system_components.md` — reconcile status, sequence, and concrete paths.
- `DEVELOPMENT_PLAN/phase_10_calculus_composition.md` — consume the sealed resource index before composition.
- `DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md` and `phase_29_execution_accelerator_folds.md` — retain the physical and expanded-vector seams.

## Related Documents

- [Development Plan Standards](development_plan_standards.md) — the phase and gate contract.
- [Gate Integrity](development_plan_gate_integrity.md) and [Phase Model](development_plan_phase_model.md) — universal gate and sequencing rules.
- [Development Plan Tracker](README.md) — numeric order and current status.
- [Overview](overview.md) — the algebra-band architecture.
- [Artifact Calculus](phase_03_artifact_calculus.md) — the demand-producing algebra this index sizes.
- [GADT Decode](phase_26_gadt_decode_ir.md) and [Illegal-State Covering](phase_27_illegal_state_covering.md) — later schema and catalogue consumers.
- [Storage Geometry](phase_28_storage_geometry_folds.md) and [Execution/Accelerator Folds](phase_29_execution_accelerator_folds.md) — later capacity-vector extensions.
- [Capability Bind](phase_30_capability_bind.md) and [Provision Seal](phase_31_provision_seal.md) — later whole-deployment consumers.
- [Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — the authoritative capacity model and honesty limit.
- [Capacity Folds](../documents/engineering/resource_capacity_folds.md) — the detailed total arithmetic.
- [Cluster Topology Doctrine](../documents/engineering/cluster_topology_doctrine.md) — engine, host, topology, and compatibility ownership.
- [Budget Doctrine](../documents/engineering/jit_budget_doctrine.md) — the bounded budget that later capacity projections consume.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — Register-1 and derivation discipline.
- [Illegal-State Catalog](../documents/illegal_state/illegal_state_catalog.md) — catalogue ownership and validation loci.
- [Illegal-State Capacity](../documents/illegal_state/illegal_state_capacity.md), [Security](../documents/illegal_state/illegal_state_security.md), [Storage](../documents/illegal_state/illegal_state_storage.md), [Techniques](../documents/illegal_state/illegal_state_techniques.md), and [Topology](../documents/illegal_state/illegal_state_topology.md) — the foreclosed states and reusable mechanisms consumed by the corpus.
