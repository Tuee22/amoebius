# Phase 17: Gateway-migration model (both branches)

> **Purpose**: Specify the target Haskell capability to express the planned and failover
> gateway-migration branches as one Haskell model and compare bounded semantic, explorer, and
> simulation readings, with every foreign model-checker product generated only beneath `.build/**`.
> **Read this if**: the cross-cluster gateway protocol, its proof boundary, or its per-spec cutoff must be
> changed or checked.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/gateway_migration_model_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 17.1: Concrete model, semantic renderer, and calculus projection](#sprint-171-concrete-model-semantic-renderer-and-calculus-projection-)
- [Sprint 17.2: Explorer and TLC proof battery](#sprint-172-explorer-and-tlc-proof-battery-)
- [Sprint 17.3: Historical schedule/cutoff gate work](#sprint-173-schedule-agreement-structural-cutoff-and-sealed-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 16, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to express the planned and failover gateway-migration branches as one Haskell
model and compare bounded semantic, explorer, and simulation readings, with every foreign
model-checker product generated only beneath `.build/**`.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — express the planned and failover gateway-migration
branches as one Haskell model and compare bounded semantic, explorer, and simulation readings, with
every foreign model-checker product generated only beneath `.build/**`. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 16](phase_16_deterministic_sim_substrate.md)
**Gate:** `pb validate phase 17`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target capability only — express the planned and failover gateway-migration branches as one Haskell model and compare bounded semantic, explorer, and simulation readings, with every foreign model-checker product generated only beneath `.build/**`. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 17` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 16; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- [`gateway_migration_model_doctrine.md` §3 — The `Model`](../documents/engineering/gateway_migration_model_doctrine.md#3-the-model): both branches are one reifiable value with named safety and liveness obligations.
- [`gateway_migration_model_doctrine.md` §4 — Simulate and prove](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove): explorer, TLC, and bounded schedule readings have distinct scopes.
- [`gateway_migration_model_doctrine.md` §5 — One-and-done, plus a per-`InForceSpec` structural fit](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit): decode-time structural fit transfers only the admitted bounded envelope.
- [`formal_model_doctrine.md` §4.1 — The reference model and its semantic oracle](../documents/engineering/formal_model_doctrine.md#41-the-reference-model-and-its-semantic-oracle): semantic renderer facts replace generated-output snapshots.
- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): only a future independently accepted bounded result could support the bounded model claim; no current result or runtime-fidelity claim exists.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 17.1: Concrete model, semantic renderer, and calculus projection ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 16](phase_16_deterministic_sim_substrate.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Make the gateway protocol and every formal input it consumes one inspectable semantic value rather than a
hand-maintained TLA+ source or generated byte fixture.

### Deliverables

- One structurally valid `GatewayMigration` `Model` containing both branches and all named obligations.
- A separately authored Haskell semantic-fact oracle; generated TLA+/CFG output exists only beneath `.build/**`.
- Focused harness adapter from the actual Phase-10 composition to Phase 11's `compositionModel`.

### Validation

1. Require exact constants, action names, invariants, properties, and the 53-state expectation.
2. Compare the twelve semantic renderer rows in both directions and redden two meaning-changing mutations.
3. Require exact calculus kinds, count, resource totals, and one-state formal safety result.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 17.2: Explorer and TLC proof battery ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 17.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Establish the bounded safety and liveness claims and demonstrate that every named obligation is reachable and
load-bearing.

### Deliverables

- Exact explorer/TLC agreement over 53 reachable states.
- Five safety invariants green and three temporal properties green under weak fairness.
- Five exact invariant mutants, five mechanical safety mutants, and three fairness-drop mutants red.

### Validation

1. Require every action, both branches, and each antecedent-bearing safety path to be reachable.
2. Compare explorer and TLC fingerprint sets and exact state counts.
3. Require every invariant mutant to violate exactly its authored invariant, every mechanical mutant to
   violate safety, and every fairness deletion to invalidate its temporal property.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 17.3: Schedule agreement, structural cutoff, and sealed gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 17.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Bound the schedule claim, enforce the per-spec proof envelope without running TLC at decode time, and package
the result as a source-bound phase-gate result.

### Deliverables

- Safety agreement inside an explicit `IOSimPOR` schedule bound of 20.
- Total structural-fit fold and independent equivalence predicate over all eight envelope clauses.
- Green scope-3 shared-resource model, red dual-owner mutant, and honestly OPEN decomposition lemma.
- Fourteen exact metrics, 17-surface/19-item join, containment, write guard, ledger, and exact run binding.

### Validation

1. Require bounded simulated safety agreement for the correct model and red invariant mutants.
2. Run the exact cutoff corpus, 500 covered equivalence cases, 500 totality cases, and all eight deletion
   mutations.
3. Require every shared-resource action reachable, the correct stress model green, and its mutant red.
4. Run the ten-sided gate on the natural architecture and bind its evidence to the complete source snapshot.

### Remaining Work

The pre-reset `None` claim is permanently invalid; the phase remains blocked and NOT VALIDATED. Runtime fidelity is UNVERIFIED and the decomposition lemma remains OPEN by design.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `gateway_migration_model_doctrine.md` — record the current semantic renderer and actual-calculus projection,
  and preserve the bounded proof/runtime distinction.
- `formal_model_doctrine.md` — record the concrete Phase-17 use of the semantic renderer rule and formal
  composition bridge.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, and `system_components.md` — reconcile order, evidence, and
  implementation paths; update the reader-facing `legacy_tracking_for_deletion.md` explanation only after the
  corresponding typed Haskell byte-expectation and pre-rebaseline-body bindings close.

## Related Documents

- [Development Plan Tracker](README.md) — numeric order and current phase status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, honesty, and artifact rules.
- [Architecture Overview](overview.md) — the verification-band role of this phase.
- [Phase 11](phase_11_formal_model_kernel.md) — the formal kernel and `compositionModel` projection.
- [Phase 16](phase_16_deterministic_sim_substrate.md) — deterministic schedule and harness substrate.
- [Canonical Phase Model](development_plan_phase_model.md) — status and reopening semantics.
- [Gate Integrity Standard](development_plan_gate_integrity.md) — oracle, mutation, and generated-artifact rules.
- [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) — protocol, cutoff, and honesty owner.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — model, renderer, and proof-semantics owner.
- [Backup and Recovery Doctrine](../documents/engineering/backup_recovery_doctrine.md) — cold-seed freshness boundary.
- [Chaos and Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — model/simulate/inject evidence ladder.
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — Register-1 boundary.
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — delegated single-instance authority.
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — transient TLA+/CFG policy.
- [Illegal Multicluster States](../documents/illegal_state/illegal_state_multicluster.md) — rejected gateway graph states.
