# Phase 18: DSL formal model

> **Purpose**: Give a bounded tranche of amoebius's DSL decisions and concurrent protocols both an actual-code
> reading and a reifiable formal-model reading before live reconciliation begins.
> **Read this if**: the decoder/fold/render boundary, Lease/reservation/reconcile models, or the line between
> bounded design proof and runtime fidelity must be changed.

This phase owns five bounded DSL/protocol models, their actual-code projections, and their TLC/explorer gate.
It consumes the formal kernel, the five-calculus composition adapter, and existing DSL constructors. It does
not claim coverage of every DSL input or correspondence to an effectful daemon.

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
- [Sprint 18.1: Actual bounded DSL projections ✅](#sprint-181-actual-bounded-dsl-projections-)
- [Sprint 18.2: Protocol models and correspondence ✅](#sprint-182-protocol-models-and-correspondence-)
- [Sprint 18.3: Explorer, TLC, mutation, and gate ✅](#sprint-183-explorer-tlc-mutation-and-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All ten gate sides passed on natural `arm64`, untranslated: all fourteen metrics
matched, 15 surfaces joined to 18 run-time items, and 34 emitted TLA+/CFG artifacts remained generated and
untracked. Attestation `sha256:9fcb3a2cf8686c7c04e90029a2b1f894b67edebe5bb0a4df3ef2062a7b6fd81b`
binds source `sha256:3bfce081173586eb…` over 2,192 files. Repository-conformance attestation
`sha256:ebe799134b00fb10b0938a2f18a75d5de938e3ce20660c5f1664e908214ebf34` and documentation attestation
`sha256:db5964aa67444da4e08ee1ec278c7ccda805d64772c119cac0b7d5ee3ffd9395` passed on that snapshot. Decision
code is tested only over the declared bounded tranche, protocol properties are proven only for the models,
and runtime fidelity is UNVERIFIED.

## Phase Summary

The actual-code half exercises five authored decoder positives and four exact-tag negatives, ignoring their
generated normalization hashes; those hashes detect change but do not explain meaning. It exhausts all 6,561
pairs of four-axis demand/capacity vectors whose coordinates lie in `0..2` against an independently written
componentwise reference. Two provisioned fixtures—single-node object storage and three-member SQL—project 19
rendered objects into 19 `chain` steps with exact semantic identity and activation-frame sequences and no
construction-time effects.

Three concrete protocol readings check the actual `dsl-core` implementation: a Lease action token succeeds
once and rejects reuse and a foreign holder, one scheduler reservation is not double-debited and follows the
legal `Reserved → BindingInFlight → Bound` path, and an unreachable node observation refuses a destructive
reconcile while the adjacent present observation permits it. The suite also constructs the real Phase-10
artifact/budget/lift/workflow/evidence composition through the shared adapter and checks its Phase-11 formal
projection.

Five new models cover the bounded projection, snapshot-token use, reservation transition, Lease authority,
and reconcile protocol. With the existing calculus-composition model, the contract contains six models and
18 reachable states. Explorer and TLC agree exactly on every fingerprint of the five transition-bearing DSL
models. Eight safety invariants and four liveness properties hold under named fairness; eight exact safety
mutants and four fairness-drop mutants turn red. Fresh TLA+/CFG are checked semantically against the authored
model contract and remain generated beneath `.build/**`.

**Phase scope:** Five actual decoder cases/four exact negatives, one finite 6,561-cell capacity domain, two
provisioned render/chain fixtures, three concrete protocol decisions, five DSL/protocol models, and the shared
calculus projection; split or open a later owner for another domain, fixture family, or runtime bridge.
**Substrate:** none
**Lane:** none
**Register:** 1 — pure/in-process bounded design validation.
**Depends on:** [Phase 11](phase_11_formal_model_kernel.md) — supplies `Model`, explorer, and `emitTLA`;
[Phase 16](phase_16_deterministic_sim_substrate.md) — supplies the actual five-calculus harness adapter;
[Phase 17](phase_17_gateway_migration_model.md) — supplies the preceding numeric seal and the concrete
semantic-renderer precedent.
**Gate:** `python3 tools/run_phase_gate.py 18` passes the bounded actual-code and formal-model battery,
fourteen exact metrics, complete surface join, generated-artifact discipline, architecture, containment,
write guard, ledger, and source-bound attestation; [Gate integrity](#gate-integrity) owns the anti-tautology
apparatus.

## Gate integrity

- **Representative set (§M.7):** the decoder corpus is exactly the five positive and four negative rows in
  the existing Gate-2 tables; the capacity domain is every demand/capacity pair in `{0,1,2}⁴`; render/chain
  uses object-store/SingleNode and SQL/Distributed-3; concrete protocols are Lease token, scheduler
  reservation, and unreachable node planning; the formal set is named above.
- **Independent oracles (§M.1/§M.3):** `positive_trees.tsv` contributes fixture, surface, and structural
  count; `decode_cases.tsv` contributes exact error tags; `implementation_projection.tsv` fixes bounded
  counts, identities, and frames; `model_contract.tsv` fixes names, states, actions, invariants, and properties;
  `mutation_catalog.tsv` fixes each mutant's invariant; and `CalculusComposition.expected.tsv` fixes the
  shared formal projection. The componentwise capacity reference does not call `fits`.
- **No generated-output oracle:** decoder normalization hashes and structural fingerprints are deliberately
  not Phase-18 acceptance facts. TLA+/CFG and render output are freshly projected to semantic names,
  identities, frames, and outcomes; no emitted bytes are committed or compared to a committed byte snapshot.
- **Mutation quota (§M.2):** initial-value substitution, token and reservation guard weakening, Lease guard
  deletion, and four reconcile action/effect mutations each violate exactly one authored invariant. Removing
  fairness from each temporal model makes its property red. A generic non-zero result cannot satisfy either
  family.
- **Positive and adjacent controls (§M.8):** every decoder negative carries an authored positive twin; the
  unreachable/present node decisions differ only in observation; correct models and actual implementations
  are green before mutations are trusted; token first-use precedes reuse denial; reservation legal transitions
  bracket the illegal skip.
- **Finite coverage honesty (§M.4):** the capacity comparison is exhaustive only inside its 6,561-cell domain.
  The five decoder positives, four negatives, and two provisioned fixtures are named examples, not generators
  and not claims about the entire DSL.
- **Independent formal observer (§M.5/§M.10):** TLC subprocess fingerprints are compared to the in-process
  explorer for all five transition-bearing models. The actual code projections are compared to authored
  semantic tables and independent predicates, not self-reported compliance traces.
- **Proof boundary:** eight safety and four liveness claims are `proven-for-the-model`; actual-code projections
  are tested at their bounds. The calculus projection inherits its one-state Phase-11 reading. Effectful daemon
  traces, live service behavior, and model-to-runtime fidelity remain UNVERIFIED for Phase 19 and later owners.
- **Fresh challenge (§M.9):** not applicable. This is a pure Register-1 gate with authored semantic predicates,
  no effectful service response, and no accepted stale state.
- **Authority/bypass (§§M.11–M.12):** not applicable to a design-model gate. The Lease holder pair is a pure
  decision check, not an authentication or live authority claim.
- **Extension conformance (§M.13).** Not applicable. Phase 18 declares no extension or domain member.

## Doctrine adopted

- [`formal_model_doctrine.md` §3](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings): explorer and TLC are separate readings of one model value.
- [`formal_model_doctrine.md` §4.1](../documents/engineering/formal_model_doctrine.md#41-the-reference-model-and-its-semantic-oracle): semantic facts, not generated bytes, decide renderer acceptance.
- [`formal_model_doctrine.md` §6](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): finite green results do not establish runtime fidelity.
- [`dsl_doctrine.md` §5](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract): the model does not claim credit for states the type system already excludes.
- [`cluster_lifecycle_doctrine.md` §9](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine): unreachable observation is distinct from absence.

## Sprints

## Sprint 18.1: Actual bounded DSL projections ✅

**Status**: Done.
**Implementation**: `test/spec/formal/dsl/DslFormalModelSpec.hs`,
`test/oracle/formal/dsl/implementation_projection.tsv`, existing Gate-2 decoder tables, `BindFixtures`, and
`ProvisionFixtures`.
**Blocked by**: None.
**Independent Validation**: actual decoder surface/count and exact errors, exhaustive componentwise capacity
comparison, and exact render/chain identity/frame projections are read from distinct authored expectations.
**Docs to update**: `documents/engineering/{dsl_doctrine,formal_model_doctrine}.md` and
`DEVELOPMENT_PLAN/{overview,system_components}.md`.

### Objective

Connect a finite, explicitly named DSL decision tranche to real repository code without accepting generated
hashes or byte snapshots as semantic evidence.

### Deliverables

- Five actual decoder positives, four exact negatives, and a stated non-hash semantic projection.
- Exhaustive four-axis `0..2` demand/capacity differential over 6,561 pairs.
- Two actual provision/render/chain projections totaling 19 objects and steps.
- Actual five-calculus composition projected through the shared formal bridge.

### Validation

1. Require exact decoder surfaces, structural counts, and negative tags.
2. Compare `fits` to independent componentwise subtraction on every finite-domain pair.
3. Require exact render/chain identities and frames, unique objects, and zero construction-time effects.
4. Match all eight shared calculus facts.

### Remaining Work

None.

## Sprint 18.2: Protocol models and correspondence ✅

**Status**: Done.
**Implementation**: `src/Amoebius/Formal/Dsl/Models.hs`,
`test/spec/formal/dsl/DslFormalModelSpec.hs`, and `test/oracle/formal/dsl/model_contract.tsv`.
**Blocked by**: Sprint 18.1's bounded actual-code vocabulary.
**Independent Validation**: model names/actions/states/obligations are authored separately; actual Lease,
reservation, and node-observation decisions are exercised through `dsl-core`.
**Docs to update**: `documents/engineering/{cluster_lifecycle_doctrine,formal_model_doctrine}.md`.

### Objective

State temporal safety/liveness for token, reservation, Lease, and reconcile behavior, while keeping the actual
code correspondence explicitly bounded.

### Deliverables

- One projection model and four transition models with eight safety and four liveness obligations.
- Actual one-use token, one-debit reservation, and unreachable-refusal readings.
- Six-model contract including the actual calculus-composition model.

### Validation

1. Require exact model structure and an 18-state explorer total.
2. Require the actual protocol decisions at their exact outcomes and reasons.
3. Keep all live/effectful correspondence marked UNVERIFIED.

### Remaining Work

None.

## Sprint 18.3: Explorer, TLC, mutation, and gate ✅

**Status**: Done.
**Implementation**: `test/spec/formal/dsl/DslFormalModelSpec.hs`,
`test/oracle/formal/dsl/{model_contract,mutation_catalog}.tsv`,
`test/oracle/dsl_formal_model_surfaces.tsv`, and `tools/dsl_formal_model_gate.py`.
**Blocked by**: Sprint 18.2's models and actual-code projections.
**Independent Validation**: exact explorer/TLC state fingerprints, exact-invariant safety mutations, and
fairness removal are three distinct controls.
**Docs to update**: `DEVELOPMENT_PLAN/{README,overview,legacy_tracking_for_deletion,system_components}.md`.

### Objective

Prove the bounded model claims, demonstrate their obligations are load-bearing, and retain the result as a
source-bound phase attestation.

### Deliverables

- Five exact explorer/TLC fingerprint comparisons.
- Eight exact safety mutants and four fairness-drop mutants red.
- Fourteen metrics, 15-surface/18-item join, ledger, containment, write guard, and attestation.

### Validation

1. Require explorer/TLC fingerprint equality on all five transition-bearing DSL models.
2. Require each safety mutant to violate exactly its authored invariant and each fairness drop to fail TLC.
3. Require all generated model-check output beneath `.build/**` and absent from the source snapshot.
4. Bind the complete result to the natural architecture and source digest.

### Remaining Work

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `formal_model_doctrine.md` — record the bounded DSL/protocol model set and actual-code projection boundary.
- `dsl_doctrine.md` — record the bounded decoder/fold/render/chain evidence without generalizing it.
- `cluster_lifecycle_doctrine.md` — record the modeled and actual unreachable-observation decision while
  leaving effectful reconciliation UNVERIFIED.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `system_components.md`, and
  `legacy_tracking_for_deletion.md` — reconcile order, evidence, implementation paths, and rewritten-body debt.

## Related Documents

- [Development Plan Tracker](README.md) — numeric order and current phase status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, honesty, and artifact rules.
- [Phase 11](phase_11_formal_model_kernel.md) — formal kernel.
- [Phase 16](phase_16_deterministic_sim_substrate.md) — shared actual-calculus harness adapter.
- [Phase 17](phase_17_gateway_migration_model.md) — preceding concrete model and semantic-renderer instance.
- [Phase 19](phase_19_reconcile_core_simulation.md) — next numeric contract and runtime-simulation owner.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — model/proof boundary.
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — language and illegal-state boundary.
- [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) — sibling concrete-protocol model.
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — reconcile observation semantics.
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — transient TLA+/CFG rule.
