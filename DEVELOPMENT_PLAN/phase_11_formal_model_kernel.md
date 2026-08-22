# Phase 11: Formal-model EDSL (`Model`/`interpret`/`emitTLA`)

> **Purpose**: Deliver one reifiable transition-system value with an in-process interpreter/explorer and a
> total TLA+ renderer, then validate that the two readings agree without committing generated specifications.
> **Read this if**: a later checker or protocol model needs the formal kernel, or the exact reach of its
> Register-1 evidence must be understood.

This phase owns the reusable formal-model kernel and its reference-model validation. It does not own the
amoebius explicit-state, symbolic, or refinement checkers, nor the gateway-migration or DSL models that later
run on the kernel.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_14_refinement_checker.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/formal_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 11.1: Reifiable kernel and semantic expectations ✅](#sprint-111-reifiable-kernel-and-semantic-expectations-)
- [Sprint 11.2: Explorer/TLC differential and contained evidence ✅](#sprint-112-explorertlc-differential-and-contained-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All ten sides were green on natural `arm64`, untranslated: 32 metrics matched,
608 fresh `.tla`/`.cfg` files remained generated, and 15 surfaces joined to 40 enumerated items. The seal
replaces the generated-output byte lock with semantic facts and an invariant truth table, and exercises a
formal projection of the Phase-10 composition value. Attestation
`sha256:64a906b6e357d5cedf1fdfd8e83106437d2c42045edb33b9b29ca64f9856751e` binds source
`sha256:ee194c5b58976d08…` over 2,158 files. Repository-conformance and documentation support gates also pass.

## Phase Summary

`Model` is a closed, first-order transition-system EDSL. `interpret` evaluates one event; `explore` walks the
bounded reachable state set and checks named invariants; `emitTLA` structurally emits the same value as a TLA+
module and TLC configuration. `ToyModel`, a bounded two-process mutual-exclusion model, exercises the complete
fragment. A separate `formal-composition-model` sublibrary projects the real Phase-10 `Composition scope`
sequence and exact resource fold into a one-state `Model` without copying the composition algebra.

**Phase scope:** One reusable formal kernel and one reference-model correspondence gate; split if work adds a
new checking algorithm, a production protocol model, runtime simulation, or an unbounded proof claim.
**Substrate:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 1 — pure/golden
**Depends on:** [Phase 10](phase_10_calculus_composition.md) — the indexed five-calculus composition value
projected into the formal EDSL rather than restated there.
**Gate:** `python3 tools/run_phase_gate.py 11` passes the hand-derived transition/count oracle, the
authored renderer-semantic facts and invariant truth table, the Phase-10 composition projection, explorer↔TLC
state-set agreement, liveness/fairness sensitivity, ten model/renderer mutations, the 200-model differential,
generated-artifact discipline, surface join, ledger, containment, write guard, natural architecture, and
source-bound attestation.

## Gate integrity

- **Representative set:** `ToyModel` carries both fairness constructors, all three temporal constructors, and
  every required expression constructor. The seeded 200-model distribution exercises each required
  constructor in every case, 95 safety-red cases, and 200 explicit expansion-boundary cases.
- **Independent transition oracle:** `ToyModel.transitions.tsv` states hand-derived event/state transitions;
  `ToyModel.expected.tsv` fixes eight distinct reachable states, the safety verdict, boundary convention,
  deadlock setting, and exact invariant/property name sets.
- **Semantic renderer oracle:** `ToyModel.renderer_semantics.tsv` states 25 facts about the module,
  declarations, initial assignments, actions, fairness strength, obligation kinds, constraint, specification,
  and deadlock policy. The test extracts those facts from emitted TLA+/CFG and requires set equality. No
  committed generated-output snapshot participates in acceptance.
- **Invariant oracle:** `ToyModel.invariant_cases.tsv` is an eight-row truth table covering valid states and
  each independent invariant failure class. Deleting an invariant clause must disagree with it.
- **Phase-10 bridge oracle:** `CalculusComposition.expected.tsv` fixes the ordered five-calculus projection,
  exact component/resource indices, one formal state, and green safety. The bridge has a dedicated source root
  so no sibling library is silently recompiled as a home module.
- **Independent checker:** TLC 2.19 runs the freshly emitted module. For `ToyModel`, TLC and the in-process
  explorer agree on the green safety verdict, exactly eight distinct states, and the full canonical state
  fingerprint set. TLC proves the temporal properties under the declared fairness; removing fairness is red.
- **Generated differential:** QuickCheck deterministically samples 200 non-degenerate bounded models with
  `maxDiscardRatio <= 10`, explicit safety-red/boundary floors, and at least 20% coverage for every required
  fragment, fairness, and temporal constructor. Explorer and TLC verdicts and state sets must agree.
- **Seeded defects:** five safety-model mutants are red in both readings; fairness removal is liveness-red;
  invariant-clause deletion fails the truth table; two safety-renderer mutants cause a differential; and two
  liveness-renderer mutants fail the semantic fact set. Each mechanism observes a defect the others cannot.
- **Generated-artifact discipline:** `.tla` and `.cfg` are emitted only beneath `.build/tla/**`; the gate
  requires fresh output, hashes it as observation evidence, and rejects any authored specification file.
- **Honesty boundary:** the result is proven-for-`ToyModel` at the declared finite scope and tested over the
  generated distribution. General scope, correctness of future protocol models, Phase-17 code
  correspondence, runtime fidelity, and fairness of a real scheduler remain `UNVERIFIED` or assumed as named.
- **Observer controls:** this is a deterministic design checker over authored values and a resolved checker,
  with no authority endpoint or live service. A nonce, authenticated runtime observer, bypass attempt, or
  authority pair is therefore not applicable; the independent instruments are the hand oracles and TLC.
- **Extension conformance (§M.13).** Not applicable: the phase delivers proof infrastructure, not an extension
  declaration, provider/hardware domain, or extension-conformance verdict.

The gate establishes agreement of two readings of the bounded fragment and sensitivity to the named defect
families. It does not prove that TLA+ itself, TLC, or the hand-authored model expresses the intended production
protocol.

## Doctrine adopted

- [`formal_model_doctrine.md` §2 — The `Model` is data](../documents/engineering/formal_model_doctrine.md#2-the-model-is-data): transition relations are reifiable values rather than opaque functions.
- [`formal_model_doctrine.md` §3 — Two total renderings](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings): interpreter/explorer and TLA+ emission consume the same closed fragment.
- [`formal_model_doctrine.md` §4 — Single-source correspondence](../documents/engineering/formal_model_doctrine.md#4-single-source-correspondence): state-set agreement and shared mutation sensitivity operationalize correspondence.
- [`formal_model_doctrine.md` §4.1 — The reference model and its semantic oracle](../documents/engineering/formal_model_doctrine.md#41-the-reference-model-and-its-semantic-oracle): authored semantic expectations pin meaning without freezing generated bytes.
- [`formal_model_doctrine.md` §5 — Generated, never committed](../documents/engineering/formal_model_doctrine.md#5-the-tlacfg-are-generated-never-committed): emitted specifications are run-local artifacts.
- [`formal_model_doctrine.md` §6 — What a green check proves](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): bounded proof and fairness premises retain explicit limits.
- [`generated_artifacts_doctrine.md` §3 — The rule](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule): authored semantic oracles remain source while rendered specifications remain output.
- The testing doctrine's generated-enumeration/authored-expectation rule: all run-time surfaces join to independently authored expectations.

## Sprints

## Sprint 11.1: Reifiable kernel and semantic expectations ✅

**Status**: Done
**Implementation**: `lib:formal-model`, `lib:formal-composition-model`,
`src/Amoebius/Formal/{Model,Interpret,Explore,EmitTLA,ToyModel}.hs`,
`src/formal-composition-model/Amoebius/Formal/CalculusComposition.hs`, and `test/oracle/formal/**`.
**Blocked by**: None.
**Independent Validation**: Hand-derived transitions, a state-count/verdict table, 25 renderer facts, eight
invariant cases, and eight Phase-10 projection metrics are read as authored inputs and compared with observed
values.
**Docs to update**: `documents/engineering/{formal_model_doctrine,generated_artifacts_doctrine}.md` and
`DEVELOPMENT_PLAN/{README,overview,system_components,legacy_tracking_for_deletion}.md`.

### Objective

Adopt the model-as-data and generated-artifact doctrines: define the complete bounded fragment, keep both
readings total, project the preceding indexed algebra without duplication, and replace generated byte
snapshots with semantic expectations.

### Deliverables

- Closed `Value`, `Expr`, `Action`, fairness, temporal-property, and `Model` data types with structural
  well-formedness checks.
- Total `interpret`, bounded `explore`, and structural `emitTLA` consumers.
- A complete reference `ToyModel` with hand-derived transition, state, obligation, constructor, semantic
  renderer, and invariant expectations.
- A dedicated-root `formal-composition-model` projection of ordered calculus kinds and exact resource indices.
- Removal of `ToyModel.{tla,cfg}.golden`; generated bytes are observations, not expected source.

### Validation

1. Require `ToyModel` to be structurally well formed and contain every named hard fragment constructor.
2. Replay the hand transition rows, match the eight-state safety oracle, and exhaust the invariant truth table.
3. Extract renderer meaning into a fact set and require exact equality to 25 authored facts.
4. Build all five real calculus components at one scope and match the exact formal projection oracle.
5. Require the clause-deletion and liveness-renderer mutants to fail semantic oracles rather than byte diffs.

### Remaining Work

None.

## Sprint 11.2: Explorer/TLC differential and contained evidence ✅

**Status**: Done
**Implementation**: `test/spec/formal/RoundTripSpec.hs`, `test/mutant/formal/**`,
`test/oracle/formal_model_kernel_surfaces.tsv`, and `tools/formal_model_kernel_gate.py`.
**Blocked by**: Sprint 11.1 semantic expectations.
**Independent Validation**: TLC is a separately implemented checker resolved from authored toolchain ranges;
the explorer/TLC comparison uses exact canonical state-fingerprint sets, not only counts.
**Docs to update**: `documents/engineering/{formal_model_doctrine,conformance_harness_doctrine,testing_doctrine}.md`
and `DEVELOPMENT_PLAN/{README,substrates,system_components}.md`.

### Objective

Adopt single-source correspondence and bounded-proof honesty: require the in-process reading and TLC reading
to agree on correct models and share sensitivity to safety defects, while TLC alone carries explicitly scoped
liveness evidence.

### Deliverables

- Explorer↔TLC equality on `ToyModel` and 200 generated bounded models.
- Five mechanical safety-model mutants, one fairness mutant, one invariant weakening, and four renderer
  mutants split across their honest detection mechanisms.
- Coverage floors for safety-red, expansion-boundary, expression, fairness, and temporal constructors.
- Fresh generated TLA+/CFG emission, complete surface join, machine-derived Register-1 ledger, containment,
  write guard, natural-architecture record, and source-bound attestation.

### Validation

1. Require exact `ToyModel` explorer/TLC safety, distinct-state, and fingerprint-set agreement.
2. Require liveness green under the declared weak/strong fairness and red when fairness is removed.
3. Run every model/renderer mutant and require the expected independent locus to turn red.
4. Pass 200 deterministic generated cases with the declared non-vacuity and constructor coverage floors.
5. Require 32 authored metrics, 15 surfaces/40 items, generated-only artifacts, ledger equality, containment,
   natural architecture, and source-bound evidence.

### Remaining Work

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `formal_model_doctrine.md` — replace byte-lock rationale with the semantic fact/truth-table oracle and record
  the Phase-10 projection.
- `generated_artifacts_doctrine.md` — identify semantic validation rather than a generated-output golden.
- `conformance_harness_doctrine.md` and `testing_doctrine.md` — record the current Register-1 result and honest
  model/runtime boundary.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — reconcile status,
  sequence, component paths, and evidence.
- `DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md` — consume the sealed kernel as the next algorithm.
- `DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md` and Phase 18 — retain ownership of concrete models.

## Related Documents

- [Development Plan Standards](development_plan_standards.md), [Gate Integrity](development_plan_gate_integrity.md), and [Phase Model](development_plan_phase_model.md) — phase/gate rules.
- [Phase 1](phase_01_toolchain_spike.md) — compatible GHC/Cabal/JVM/TLC resolution consumed by the gate.
- [Development Plan Tracker](README.md), [Overview](overview.md), [Substrates](substrates.md), and [System Components](system_components.md) — order, lane, and implementation inventory.
- [Phase 10](phase_10_calculus_composition.md) — the indexed composition value projected here.
- [Phases 12–14](phase_12_explicit_state_checker.md) — later checker algorithms.
- [Phases 17–18](phase_17_gateway_migration_model.md) — later concrete protocol/DSL models.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) and [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — normative design and artifact boundaries.
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — Register-1 placement and the no-live-infrastructure boundary.
