# Phase 18: DSL formal model

> **Purpose**: Point the Phase-11 model kernel at amoebius's own DSL — the decoder, the folds, `renderAll`,
> the `chain`/`Step` descent, and the concurrent protocols the live band later enacts — so the DSL's semantics
> are model-checked **before** any live behaviour is implemented, rather than argued from the type system alone.
> **Read this if**: phase 18 is next in the queue, or a later phase depends on what its gate establishes.

Phase 18 delivers the DSL formal model; its design is owned by [formal_model_doctrine.md](../documents/engineering/formal_model_doctrine.md), [dsl_doctrine.md](../documents/engineering/dsl_doctrine.md), and the plan for reaching it is owned here.
Register 1: TLC model-checking over emitted specifications, in-process, no cluster.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 18.1: Refinement models for the decoder, the folds, and `renderAll` 📋](#sprint-181-refinement-models-for-the-decoder-the-folds-and-renderall-)
- [Sprint 18.2: The `chain`/`Step` descent 📋](#sprint-182-the-chainstep-descent-)
- [Sprint 18.3: The concurrent protocols 📋](#sprint-183-the-concurrent-protocols-)
- [Sprint 18.4: The reconcile invariants 📋](#sprint-184-the-reconcile-invariants-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-17 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Phase 11 builds a model kernel and proves it on a throwaway two-process reference model. Phase 17 expresses the
one cross-cluster protocol. Between them they leave the DSL itself — the thing every other phase is about —
model-checked by nothing. This phase closes that, and it is the reason the pre-cluster band can claim to
validate the DSL rather than merely to type-check it.

**This phase widens amoebius's proof obligations, deliberately.**
[formal_model_doctrine.md](../documents/engineering/formal_model_doctrine.md) and
[gateway_migration_model_doctrine.md](../documents/engineering/gateway_migration_model_doctrine.md) previously
fixed exactly one obligation, on the argument that a model adds nothing to a pure total function the type
system already forecloses. That argument is sound for totality and wrong for *behaviour over time*: the
protocols the DSL describes — a token that must not be reused after an observed transition, a reservation that
must not double-debit, a Lease that must admit one writer — are state machines, and no type in the decoder
constrains their interleavings. The doctrine sentences are rewritten with this phase, not left to contradict it.

**Where a model earns its keep, and where it is differential.** For the decoder, the folds, and `renderAll`,
the check is **differential, not refinement**, and the distinction is load-bearing: TLC reads TLA+ and has no
access to a Haskell fold, so it cannot compare the two. What the gate does is enumerate a bounded input
domain, evaluate the specification and the Haskell implementation on each input, and compare the results. That
catches a fold disagreeing with its specification on any input in the enumerated domain, and it establishes
nothing outside it. Calling it *refinement* would borrow the credibility of a TLA+ term of art for a check
that is not one.

For the reconcile invariants and the two concurrent protocols the model is doing work no other artifact does,
and there TLC is genuinely model-checking: the properties are about interleavings, which no enumeration of
inputs reaches.

**Phase scope:** one cohesive claim — *every DSL surface has a model, and TLC finds no counterexample* —
across four sprints, one acceptance command, and no runtime code. The split trigger is a second register: the
moment a claim needs the real code running, it belongs to [Phase 19](phase_19_reconcile_core_simulation.md).

**Substrate:** `none` — no host, no cluster ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 1 — pure/golden, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 11](phase_11_formal_model_kernel.md) — the formal-model kernel. This is a second instance of that kernel rather than a consumer of the gateway model beside it; the two models are siblings.

**Gate:** `python3 tools/dsl_formal_model_gate.py` model-checks every specification named in
[Gate integrity](#gate-integrity) to completion with no counterexample, and reddens under every seeded mutant.
Phase 19 does not open unless the ledger records Register 1 green.

Model-to-code correspondence for the *effectful* daemon stays UNVERIFIED here;
[Phase 19](phase_19_reconcile_core_simulation.md) and the live band own it.

## Gate integrity

Every model is emitted by the Phase-11 kernel (`interpret` / `emitTLA` render one value, so there is no
hand-written `.tla` to drift), and every emitted artifact lands beneath `.build/**`, never committed
([generated_artifacts_doctrine.md](../documents/engineering/generated_artifacts_doctrine.md)).


The independent oracle is a **hand-authored expected-outcome table**, committed before the models are written:
one row per model naming the invariant, whether TLC must find a counterexample, and the diameter at which it
must terminate. A model that passes because it is vacuous — no reachable state violates an invariant nothing
constrains — fails that table, because the table pins the state count.

Seeded mutants, each reddening its own model and no other: an invariant weakened to `TRUE`; a fairness
condition dropped; a token-reuse guard removed from the CAS model; the reservation model's double-debit
guard removed; the Lease model's at-most-one-holder conjunct removed; and — for the differential half — a
**Haskell fold** altered to disagree with its specification on one input, which is the mutant that proves the
comparison reaches the implementation rather than only the model of it.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [formal_model_doctrine.md](../documents/engineering/formal_model_doctrine.md): the kernel, the
  `interpret`/`emitTLA` one-value rule, and the spec↔decision-core correspondence boundary.
- [dsl_doctrine.md §5 — the illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  what the type system already forecloses, and therefore what a model must *not* claim credit for.
- [cluster_lifecycle_doctrine.md](../documents/engineering/cluster_lifecycle_doctrine.md): the reconcile loop
  and three-valued observation whose invariants this phase states formally for the first time.

## Sprints

## Sprint 18.1: Refinement models for the decoder, the folds, and `renderAll` 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Formal/Dsl/{Decode,Fold,Render}.hs`, the committed expected-outcome table
**Blocked by**: none within the phase.
**Independent Validation**: the hand-authored table pins each model's invariant, expected verdict, and state
count; a vacuous model fails on the count before it passes on the verdict.
**Docs to update**: `documents/engineering/formal_model_doctrine.md`

### Objective

State the decoder's **totality**, the capacity/storage/execution fold algebra, and `renderAll`'s activation
partition as TLA+ operators, and check the Haskell implementations agree with them over an enumerated domain.

**Determinism is deliberately not among them.** A pure Haskell function is deterministic by the language, and
a TLA+ operator is a function by construction, so a model asserting "this is a function" is exactly the
vacuous invariant [Gate integrity](#gate-integrity) warns about — and this phase's own doctrine adoption says
a model must not claim credit for what the type system already forecloses. Totality is different: a Haskell
function can diverge or bottom, so modelling termination is a real obligation.

### Deliverables
- One specification per surface, emitted by the Phase-11 kernel.
- A refinement mapping per surface, and a mutant proving the mapping is load-bearing.
- An honest statement, in the ledger, that the domain is bounded.

### Validation
1. TLC terminates with no counterexample at the pinned diameter for each model.
2. The refinement mutant reddens exactly its own model.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Sprint 18.2: The `chain`/`Step` descent 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Formal/Dsl/Chain.hs`
**Blocked by**: Sprint 18.1
**Independent Validation**: the descent's termination and the plan's byte-stability are separate invariants,
each with its own expected row.
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Model the `chain :: cfg -> [Step]` descent: that it terminates, that the rendered plan is a function of the
committed source alone, and that no step is reachable twice under one descent.

### Deliverables
- The descent specification and its invariants.
- A mutant that makes the descent non-terminating and must be caught.

### Validation
1. TLC terminates with no counterexample.
2. The non-termination mutant reddens.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Sprint 18.3: The concurrent protocols 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Formal/Dsl/{SnapshotToken,Reservation,Lease}.hs`
**Blocked by**: Sprint 18.1
**Independent Validation**: three models, three invariants, three mutants; each mutant reddens one model only.
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md`

### Objective

The three state machines no type constrains: the snapshot-token/CAS no-reuse discipline, the
`Reserved → BindingInFlight → Bound` reservation machine with its double-debit and crash-recovery hazards, and
the Lease's at-most-one-writer authority.

### Deliverables
- One specification per protocol, each with its safety invariant and, where liveness is claimed, its fairness
  condition stated explicitly rather than assumed.
- The three protocol mutants.

### Validation
1. Each model terminates with no counterexample.
2. Each mutant reddens its own model and no other.
3. Removing a fairness condition changes the verdict, proving the condition is load-bearing.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Sprint 18.4: The reconcile invariants 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Formal/Dsl/Reconcile.hs`
**Blocked by**: Sprint 18.3
**Independent Validation**: the invariants are authored from
[cluster_lifecycle_doctrine.md](../documents/engineering/cluster_lifecycle_doctrine.md), not from the
implementation, which does not exist in this band.
**Docs to update**: `documents/engineering/cluster_lifecycle_doctrine.md`

### Objective

State the reconcile loop's invariants formally: at most one Lease holder acts; no delete precedes its
replacement being Bound and Ready; three-valued observation refuses on `Unreachable` rather than treating it
as `Absent`; and re-running a converged reconcile is a no-op.

Doctrine currently attaches its only proof claim for this algorithm to a **sibling project**
([cluster_lifecycle_doctrine.md §9](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)'s caption), which
is evidence from another system rather than an amoebius result. This sprint replaces that claim.

### Deliverables
- The reconcile specification and its four invariants.
- A mutant per invariant.
- The doctrine caption rewritten to cite this phase rather than the sibling.

### Validation
1. TLC terminates with no counterexample for each invariant.
2. Each invariant mutant reddens its own invariant only.
3. No claim in this phase's ledger asserts anything about the *effectful* daemon, which
   [Phase 19](phase_19_reconcile_core_simulation.md) and the live band own.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `formal_model_doctrine.md` — the obligation set widens from one to the set this phase states (Sprint 18.1).
- `gateway_migration_model_doctrine.md` — the cross-cluster migration remains *an* obligation, no longer *the*
  obligation (Sprint 18.1).
- `dsl_doctrine.md` — the descent's modelled properties (Sprint 18.2).
- `cluster_lifecycle_doctrine.md` — its reconcile-loop proof claim moves from sibling evidence to this phase (Sprint 18.4).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` Phase Overview links its Phase 18 row to this document.

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 18 row is the source for this phase's objective and gate.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys.
- [phase_19_reconcile_core_simulation.md](phase_19_reconcile_core_simulation.md) — the Register-2 half; what a
  model cannot establish about running code.
- [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md) — the kernel and the
  correspondence boundary.
- [`cluster_lifecycle_doctrine.md`](../documents/engineering/cluster_lifecycle_doctrine.md) — the reconcile
  loop whose invariants this phase states.
