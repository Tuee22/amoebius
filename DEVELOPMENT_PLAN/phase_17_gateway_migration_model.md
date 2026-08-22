# Phase 17: Gateway-migration model (both branches)

> **Purpose**: Express the planned and failover gateway-migration branches as one reifiable `Model`, then
> establish their bounded design properties through independent semantic, explorer, TLC, simulation, and
> structural-fit readings.
> **Read this if**: the cross-cluster gateway protocol, its proof boundary, or its per-spec cutoff must be
> changed or reviewed.

This phase owns the concrete `GatewayMigration` model, its semantic renderer contract, bounded design proof,
schedule agreement, and structural-fit cutoff. It consumes the formal kernel and deterministic-simulation
substrate; it does not establish correspondence to a live daemon or forest.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/gateway_migration_model_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 17.1: Concrete model, semantic renderer, and calculus projection ✅](#sprint-171-concrete-model-semantic-renderer-and-calculus-projection-)
- [Sprint 17.2: Explorer and TLC proof battery ✅](#sprint-172-explorer-and-tlc-proof-battery-)
- [Sprint 17.3: Schedule agreement, structural cutoff, and sealed gate ✅](#sprint-173-schedule-agreement-structural-cutoff-and-sealed-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All ten gate sides passed on natural `arm64`, untranslated: all fourteen metrics
matched, 17 surfaces joined to 19 run-time items, and 34 emitted TLA+/CFG artifacts remained generated and
untracked. Attestation `sha256:492ebe71ffe1abac5cf95bfa800518685544eadabdba440f46b95d30fdb84031`
binds source `sha256:fce1f042661a4eb4…` over 2,185 files. Repository-conformance and documentation support
gates passed on that snapshot. The design is proven only for the bounded model; runtime fidelity is
UNVERIFIED and the decomposition lemma remains OPEN.

## Phase Summary

`gatewayMigrationModel` is one Phase-11 `Model` containing both the `Planned` coordinated handover and the
`Failover` emergency takeover. Its five safety invariants are `UniqueGatewayOwner`,
`SessionAlwaysRebindable`, `PlannedIsLossless`, `NoWriteAfterStaleFailover`, and
`NoTakeWithoutProvenFreshness`. Its three liveness properties are `MergeConverges`,
`SessionEventuallyRebinds`, and `PlannedMigrationTerminates`, each checked under the model's declared weak
fairness.

The in-process explorer and TLC agree on the exact set of 53 reachable states and on their fingerprints.
Every action and the antecedent-bearing paths are reachable. Five invariant-specific mutants violate exactly
their named invariant, five mechanical safety mutants are red, and removing fairness makes each of the three
liveness properties red. `IOSimPOR` agrees with the safety reading inside an explicit schedule bound of 20.

The generated TLA+/CFG bytes are transient. A twelve-row semantic table instead fixes the module,
extensions, constants, variables, initialization, actions, fairness, invariants, properties, constraint,
specification, and deadlock policy; two renderer mutations must change those facts. The same suite also
constructs the real Phase-10 artifact/budget/lift/workflow/evidence composition and passes its Phase-11
`compositionModel` projection, preventing the protocol gate from validating a parallel formal vocabulary.

The total `structuralFit` fold admits only pairwise, graph-independent, resource-independent, acyclic
migration graphs within the model's budget, TTL, freshness, and offset envelope. A distinct reference
predicate, an exact corpus, 500 covered QuickCheck cases, 500 totality cases, and eight clause-deletion
mutants decide that claim. A scope-3 shared-resource stress model is green while its dual-owner mutant is red.
This stress result does not prove the general decomposition lemma, which remains OPEN.

**Phase scope:** One concrete two-branch protocol model, one generated-artifact semantic contract, one actual
five-calculus projection, one bounded proof/simulation battery, and one per-spec structural-fit envelope;
split if another protocol, proof calculus, or live correspondence boundary is introduced.
**Substrate:** none
**Lane:** none
**Register:** 1 — pure/in-process design validation; TLC is a local proof tool, not a live substrate.
**Depends on:** [Phase 11](phase_11_formal_model_kernel.md) — supplies `Model`, explorer, TLA+/CFG renderer,
and the formal composition bridge; [Phase 16](phase_16_deterministic_sim_substrate.md) — supplies the
deterministic-simulation and actual-calculus harness boundary and is the preceding numeric seal.
**Gate:** `python3 tools/run_phase_gate.py 17` passes the model/TLC/simulation suite, fourteen exact
metrics, semantic renderer and calculus projections, all mutation families, complete surface join, generated
artifact discipline, natural architecture, containment, write guard, ledger, and source-bound attestation;
the anti-tautology apparatus is specified in [Gate integrity](#gate-integrity).

## Gate integrity

- **Representative set (§M.7):** both migration branches, all 20 declared actions, five safety invariants,
  three temporal properties, the exact 53-state bounded graph, the actual five-calculus composition, every
  eight-clause structural-fit dimension, and the scope-3 shared-resource stress model are named inputs.
- **Independent oracles (§M.1/§M.3):** `model_contract.tsv`, `invariant_mutants.tsv`, `cutoff_cases.tsv`,
  `cutoff_mutants.tsv`, `renderer_semantics.tsv`, and `CalculusComposition.expected.tsv` are authored semantic
  expectations. `referenceFit` shares no decision helper with `structuralFit`; TLC and the in-process explorer
  are separate readings of the model. No committed fixture is regenerated from emitted output.
- **Semantic renderer, not a byte golden:** freshly emitted `.tla`/`.cfg` are projected to twelve semantic
  facts. Dropping an invariant declaration or changing weak to strong fairness changes the projection.
  Generated artifacts, metrics, fingerprints, logs, ledgers, and attestations remain beneath `.build/**`.
- **Mutation quota (§M.2):** five exact per-invariant mutations, five mechanical guard/effect mutations,
  three fairness deletions, two renderer mutations, eight cutoff-clause deletions, and one scope-3 dual-owner
  mutation all turn the applicable instrument red. The invariant mutants must violate their own invariant and
  no other; a generic failure cannot satisfy the check.
- **Vacuity and positive controls (§M.4/§M.8):** both branches, every action, and the three guarded safety
  paths are reachable on the correct model. The correct model is green before each mutant is trusted, each
  liveness property is green with fairness before it is required to redden without fairness, and the cutoff
  corpus pairs each rejected dimension with an admitted neighbour.
- **Generator coverage (§M.4):** the 500-case structural-fit property requires at least five-percent coverage
  of multi-active, shared-DNS, cluster-reuse, cyclic, budget, TTL, freshness, offset, and over-scope cases; a
  separate 500-case run forces the fold to normal form.
- **Bounded honesty:** 53 states and the `IOSimPOR` schedule bound of 20 are exact model bounds, not runtime
  coverage. Safety and liveness are `proven-for-the-model`; structural-fit and schedule evidence are tested.
  Live daemon/forest correspondence remains UNVERIFIED and the decomposition lemma is OPEN.
- **External observation (§M.5/§M.10):** TLC's subprocess result and fingerprints are compared to the
  in-process explorer rather than to a self-reported compliance log. Authentication, authorization,
  ownership authority, and alternate live paths are absent from this Register-1 model, so §§M.10–M.12 have no
  applicable credential or bypass pair.
- **Fresh challenge (§M.9):** not applicable. This phase is pure and binds independently authored semantic
  predicates rather than an effectful service response.
- **Extension conformance (§M.13).** Not applicable. Phase 17 declares no extension or domain member.

## Doctrine adopted

- [`gateway_migration_model_doctrine.md` §3](../documents/engineering/gateway_migration_model_doctrine.md#3-the-model): both branches are one reifiable value with named safety and liveness obligations.
- [`gateway_migration_model_doctrine.md` §4](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove): explorer, TLC, and bounded schedule readings have distinct scopes.
- [`gateway_migration_model_doctrine.md` §5](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit): decode-time structural fit transfers only the admitted bounded envelope.
- [`formal_model_doctrine.md` §4.1](../documents/engineering/formal_model_doctrine.md#41-the-reference-model-and-its-semantic-oracle): semantic renderer facts replace generated-output snapshots.
- [`formal_model_doctrine.md` §6](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): a bounded green result proves the model claim, not runtime fidelity.

## Sprints

## Sprint 17.1: Concrete model, semantic renderer, and calculus projection ✅

**Status**: Done.
**Implementation**: `src/Amoebius/Formal/GatewayMigration.hs`,
`test/spec/formal/gateway/GatewayMigrationSpec.hs`,
`test/harness/deterministic_simulation/CalculusProjection.hs`, and
`test/oracle/formal/gateway/{model_contract,renderer_semantics,gateway_migration_manifest}.tsv`.
**Blocked by**: None.
**Independent Validation**: the model matches the authored constants/actions/obligations contract; twelve
renderer facts match exactly; two semantic renderer mutants are detected; and the actual Phase-10
composition matches all eight Phase-11 formal projection facts.
**Docs to update**: `documents/engineering/{gateway_migration_model_doctrine,formal_model_doctrine}.md` and
`DEVELOPMENT_PLAN/{overview,system_components}.md`.

### Objective

Make the gateway protocol and every formal input it consumes one inspectable semantic value rather than a
hand-maintained TLA+ source or generated byte fixture.

### Deliverables

- One structurally valid `GatewayMigration` `Model` containing both branches and all named obligations.
- Generated TLA+/CFG semantic fact oracle with no committed generated output.
- Focused harness adapter from the actual Phase-10 composition to Phase 11's `compositionModel`.

### Validation

1. Require exact constants, action names, invariants, properties, and the 53-state expectation.
2. Compare the twelve semantic renderer rows in both directions and redden two meaning-changing mutations.
3. Require exact calculus kinds, count, resource totals, and one-state formal safety result.

### Remaining Work

None.

## Sprint 17.2: Explorer and TLC proof battery ✅

**Status**: Done.
**Implementation**: `src/Amoebius/Formal/GatewayMigration.hs`,
`test/spec/formal/gateway/GatewayMigrationSpec.hs`, and
`test/oracle/formal/gateway/{invariant_mutants,model_contract}.tsv`.
**Blocked by**: Sprint 17.1's concrete model and authored contract.
**Independent Validation**: explorer/TLC fingerprint equality, exact invariant-local mutation outcomes, and
fairness removal are distinct observations over the same model.
**Docs to update**: `documents/engineering/{gateway_migration_model_doctrine,formal_model_doctrine}.md`.

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

None.

## Sprint 17.3: Schedule agreement, structural cutoff, and sealed gate ✅

**Status**: Done.
**Implementation**: `src/Amoebius/Multicluster/StructuralFit.hs`,
`test/spec/formal/gateway/GatewayMigrationSpec.hs`,
`test/oracle/formal/gateway/{cutoff_cases,cutoff_mutants}.tsv`,
`test/oracle/gateway_migration_model_surfaces.tsv`, and `tools/gateway_migration_model_gate.py`.
**Blocked by**: Sprint 17.2's green reference model.
**Independent Validation**: bounded `IOSimPOR` agreement, a separate structural-fit predicate/corpus,
coverage floors, eight diagnostic clause mutations, and a scope-3 shared-resource mutation.
**Docs to update**: `DEVELOPMENT_PLAN/{README,overview,legacy_tracking_for_deletion,system_components}.md`.

### Objective

Bound the schedule claim, enforce the per-spec proof envelope without running TLC at decode time, and package
the result as a source-bound phase attestation.

### Deliverables

- Safety agreement inside an explicit `IOSimPOR` schedule bound of 20.
- Total structural-fit fold and independent equivalence predicate over all eight envelope clauses.
- Green scope-3 shared-resource model, red dual-owner mutant, and honestly OPEN decomposition lemma.
- Fourteen exact metrics, 17-surface/19-item join, containment, write guard, ledger, and attestation.

### Validation

1. Require bounded simulated safety agreement for the correct model and red invariant mutants.
2. Run the exact cutoff corpus, 500 covered equivalence cases, 500 totality cases, and all eight deletion
   mutations.
3. Require every shared-resource action reachable, the correct stress model green, and its mutant red.
4. Run the ten-sided gate on the natural architecture and bind its evidence to the complete source snapshot.

### Remaining Work

None for the bounded model. Runtime fidelity is UNVERIFIED and the decomposition lemma remains OPEN by design.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `gateway_migration_model_doctrine.md` — record the current semantic renderer and actual-calculus projection,
  and preserve the bounded proof/runtime distinction.
- `formal_model_doctrine.md` — record the concrete Phase-17 use of the semantic renderer rule and formal
  composition bridge.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `system_components.md`, and
  `legacy_tracking_for_deletion.md` — reconcile order, evidence, implementation paths, and retired byte-golden
  and pre-rebaseline-body debt.

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
