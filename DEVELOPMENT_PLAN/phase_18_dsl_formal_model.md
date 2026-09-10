# Phase 18: DSL formal model

> **Purpose**: Specify the target Haskell capability to project a bounded tranche of DSL decisions
> and concurrent protocols from Haskell values into executable and formal-model readings, with every
> Dhall, TLA+, CFG, or rendered fixture product generated only beneath `.build/**`.
> **Read this if**: the decoder/fold/render boundary, Lease/reservation/reconcile models, or the line between
> bounded design proof and runtime fidelity must be changed.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/formal_model_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 18.1: Actual bounded DSL projections](#sprint-181-actual-bounded-dsl-projections-)
- [Sprint 18.2: Protocol models and correspondence](#sprint-182-protocol-models-and-correspondence-)
- [Sprint 18.3: Explorer, TLC, mutation, and gate](#sprint-183-explorer-tlc-mutation-and-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

✅ Done.

The [2026-09-08 reset](README.md#reopened-numeric-sequence) withdraws prior certification. Existing
implementation is an Observed footprint / Known partial. Retained requirements remain obligations; only this
phase's complete qualified gate under the replacement acceptance baseline can authorize Done.

Gate execution remains blocked by the qualified Phase-17 predecessor and its compatible evidence chain.

## Phase Summary

The prior projection reduced parts of the DSL to constants and fixture counts and exercised only a few protocol examples. This phase must state and test the actual bounded semantic correspondence it claims. The later decoder, provision, renderer and chain owners must extend that correspondence using real values before the DSL barrier can pass.

This phase has a bound Haskell implementation but does not report a passing result until its complete gate
runs. It projects a bounded tranche of DSL decisions and concurrent protocols from
Haskell values into executable and formal-model readings, with every Dhall, TLA+, CFG, or rendered
fixture product generated only beneath `.build/**`.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Bound capability — project a bounded tranche of DSL decisions and concurrent
protocols from Haskell values into executable and formal-model readings, with every Dhall, TLA+,
CFG, or rendered fixture product generated only beneath `.build/**`. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 17](phase_17_gateway_migration_model.md)
**Gate:** `pb validate phase 18`; see [Gate integrity](#gate-integrity).

## Gate integrity

The admitted model-check runtime is shared with Phase 17: Temurin 21.0.9+10 x86_64 Linux JRE
`bin/java` SHA-256 `e865867065e48928c58293f30e7ae26a79c842f8607fa51d7e2e9fb90b602786` and TLA+ 1.8.0
calver `2026.09.04.170753` jar SHA-256
`b658b4e504fdf0b721caf7066320f6b6fe5805f4dd2f717d0e47baba4097205e`. Both are ignored local-custody
inputs and both exact digests are rechecked by the Haskell supervisor.

**Contract check**: BOUND — the replacement certification generation, protected accepted baseline,
authenticated phase receipt, and current compatibility closure are Haskell-owned inputs. Execution evidence
remains phase-local and cannot be supplied by this prose.

| Key | Contract |
|---|---|
| `Claim` | Haskell-authored bounded DSL decisions and protocol models have independently specified safety/liveness obligations and explicit correspondence to actual production decisions; explorer/TLC results establish only those declared models and bounds. |
| `Subject` | `Amoebius.Formal.Dsl.Models`, the Phase-9 capacity fold, three protocol decision modules, and the calculus projection are acquired only through package-hidden `DslFormalModelRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 18`; before `BOOTSTRAP_HANDOFF`, the exact source-bound Haskell executable invokes absolute Cabal 3.16.1.0 and GHC 9.12.4 directly, offline and serially, with digest-pinned Java 21.0.9/TLA+ 1.8.0. |
| `Oracle` | `test/spec/formal/dsl/DslFormalModelOracle.hs` independently states domain values, actual decision/input-output relations, model states/transitions, safety/liveness obligations, fairness assumptions and exact mutation assignments. |
| `Positive controls` | Exercise every declared bounded decision and transition correspondence, capacity boundary, token, reservation, Lease, reconcile and indexed calculus case; compare semantic states and edges with independently generated TLC observations. |
| `Paired negatives` | Minimally alter actual capacity decisions, token reuse, reservation transitions, authority, unreachable deletion and convergence; the relevant invariant or correspondence must fail for its specific reason while the legal control succeeds. |
| `Mutants` | Mutate actual production decisions and model/implementation projection seams, including binding and resource values; changing a fixture-count constant or checker-only pass flag cannot discharge a production-semantic obligation. |
| `Discovery` | Reconcile the independently declared bounded DSL/protocol semantic surface with production constructors/functions, model obligations, actual correspondence observations and exact selector assignments. Historical model/state/fixture totals are examples, never the discovery authority. |
| `Challenge` | The three changed-production builds are post-acquisition challenges and must each fail while the clean subject passes. |
| `Observer` | Exact process argv, exits, stdout/stderr digests, generated-product inventory, and source snapshots are captured outside the test subject. |
| `Authority/bypass` | No `pb`, network, host, hardware, or live service is admitted; only absolute Cabal, GHC, JVM, and TLC paths run, with compiler and TLC workers fixed to one. |
| `Freshness` | One unique `.build/runs/phase-18/work/candidate-*` root is created after acquisition; opening and closing source identities must match. |
| `Qualification` | Use qualified model/checker predecessors and authenticated TLC input, then require independent decision/transition correspondences, safety/liveness observations, paired negatives and assigned changed-production failures together. |
| `Cleanroom` | All TLA/CFG/DOT/log/result products are created beneath the fresh run root; the authenticated network-independent source-package cache is copied into that root. |
| `Legacy closure` | The Python Phase-18 gate and four serialized behavioral oracle files are absent and independently enumerated. |
| `Predecessor` | Authenticated `ImmediatePredecessorPass` for Phase 17 in the admitted certification generation, plus the accepted verifier's current compatibility decision under [§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass). Missing, forged, revoked, incompatible, or wrong-phase evidence refuses before any phase effect. Historical source identity remains recorded; reuse requires unchanged relevant dependency and acceptance closures. |
| `Residue` | No unbounded whole-language or runtime-effect theorem is claimed. Decoder correspondence is owned by Phase 26, provision by Phase 31, rendering by Phase 33 and chain by Phase 34; their actual-value joins are required by Phase 49. |
| `Pass criterion` | Every one of these 18 rows must be execution-derived green in one qualified run for the exact source snapshot. |

## Doctrine adopted

- [`formal_model_doctrine.md` §3 — Two total renderings](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings): explorer and TLC are separate readings of one model value.
- [`formal_model_doctrine.md` §4.1 — The reference model and its semantic oracle](../documents/engineering/formal_model_doctrine.md#41-the-reference-model-and-its-semantic-oracle): semantic facts, not generated bytes, decide renderer acceptance.
- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): no finite result is current; any future accepted model result would still leave runtime fidelity unproved.
- [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract): the target model must not claim credit for states that a gate-passed Haskell type-system boundary must first exclude.
- [`cluster_lifecycle_doctrine.md` §9 — How bring-up and teardown are implemented: the reconciler, not a state machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine): unreachable observation is distinct from absence.

## Sprints

The sprint requirements below remain part of the target acceptance scope. Each owner must bind them in
Haskell and qualify the mechanism that first admits their result; component observations cannot close a sprint.

## Sprint 18.1: Actual bounded DSL projections ✅

**Status**: Done
**Implementation**: `src/capacity-topology/Amoebius/Capacity/Fold.hs`, `test/harness/deterministic_simulation/CalculusProjection.hs`, and the capacity/calculus sections of `DslFormalModelSpec.hs`
**Blocked by**: [Phase 17](phase_17_gateway_migration_model.md) gate pass
**Independent Validation**: Observe real bounded DSL decisions and indexed values against independent expectations; pair a semantic value change with its exact correspondence failure; kill production-decision mutants; exclude unbounded and later-owned semantics.
**Oracle**: `DslFormalModelOracle.hs` plus the independently constructed `referenceCalculusProjection`
**Legacy IDs**: none; retired serialized Phase-18 oracles are checked absent directly
**Docs to update**: this phase file, `formal_model_doctrine.md`, `dsl_doctrine.md`, and `system_components.md`

### Objective

Connect a finite, explicitly named DSL decision tranche to real repository code without accepting generated
hashes or byte snapshots as semantic evidence.

### Deliverables

- Replace count-only projection facts with typed input, decision, resource, identity and transition values from the actual production entry points. Model observations retain their independently declared domain and projection relation.
- A Haskell semantic inventory links each bounded claim to its production owner, model obligation, independent oracle and later extension owner. Existing numerical examples remain controls, not complete-language declarations.

- Exhaustive four-axis `0..2` demand/capacity differential over 6,561 pairs.
- Actual five-calculus composition projected through the shared formal bridge.

### Validation

- Hold fixture counts constant while changing a production decision, resource amount or object identity; the actual semantic projection must change and its independent correspondence check must fail.
- Require the same actual value to supply executable and modeled observations; separately constructed stand-in models and literal summary totals cannot establish correspondence.

1. Compare `fits` to independent componentwise subtraction on every finite-domain pair.
2. Match all eight shared calculus facts.

**The decoder and the provision/render/chain tranches are not this phase's to project.** Both named artefacts
this phase does not own: `decodeCluster` is built at
[Phase 26](phase_26_gadt_decode_ir.md), `provision` at [Phase 31](phase_31_provision_seal.md), `renderAll` at
[Phase 33](phase_33_render_manifest_oracles.md), and `Step`/`chain` at
[Phase 34](phase_34_chain_kernel_boundary.md). Requiring "five actual decoder positives" and "two actual
provision/render/chain projections" here made a phase-18 gate pass depend on four later phases, which
`Depends on:` cannot express and no checker could see. Each tranche moves to a sprint of its owning phase and
projects back through this phase's formal bridge locally, where the artefact already exists. What remains at
18 is what Phases 3–17 deliver: the capacity differential over the Phase-9 fold, and the five-calculus
composition over Phase-11 `Model` values.

### Remaining Work

Bind the retained requirements to the replacement Haskell acceptance contract, repair the stated gaps, and
qualify this phase's complete gate after its predecessor. Resolve owned legacy debt with observed closure. The two removed tranches are
carried as obligations on Phases 26 and 34 rather than as residue here, because this phase no longer claims
them.

## Sprint 18.2: Protocol models and correspondence ✅

**Status**: Done
**Implementation**: `src/Amoebius/Formal/Dsl/Models.hs`, `Manifest/Authority.hs`, `Scheduler/Reservation.hs`, `Cluster/NodeProvisioner.hs`, and `DslFormalModelSpec.hs`
**Blocked by**: Sprint 18.1
**Independent Validation**: exact 18-state structure plus actual one-use token, reservation, and unreachable/present decision pairs
**Oracle**: `DslFormalModelOracle.hs` owns exact model/action/invariant/property expectations
**Legacy IDs**: none; no serialized protocol result is admitted
**Docs to update**: this phase file, `formal_model_doctrine.md`, `dsl_doctrine.md`, and `cluster_lifecycle_doctrine.md`

### Objective

State temporal safety/liveness for token, reservation, Lease, and reconcile behavior, while keeping the actual
code correspondence explicitly bounded.

### Deliverables

- For every modeled action, define the precise production decision and state projection it denotes, including refusal and stuttering behavior, with independently authored Haskell correspondence expectations.

- One projection model and four transition models with eight safety and four liveness obligations.
- Actual one-use token, one-debit reservation, and unreachable-refusal readings.
- Six-model contract including the actual calculus-composition model.

### Validation

- Exercise each declared bounded protocol edge and refusal under the real decision function, including concurrency/order boundaries where in scope; three illustrative calls cannot substitute for complete declared edge correspondence.

1. Require exact model structure and an 18-state explorer total.
2. Require the actual protocol decisions at their exact outcomes and reasons.
3. Keep all live/effectful correspondence marked UNVERIFIED.

### Remaining Work

Bind the retained requirements to the replacement Haskell acceptance contract, repair the stated gaps, and
qualify this phase's complete gate after its predecessor. Resolve owned legacy debt with observed closure.

## Sprint 18.3: Explorer, TLC, mutation, and gate ✅

**Status**: Done
**Implementation**: `DslFormalModelSpec.hs`, `DslFormalModelOracle.hs`, and package-hidden `DslFormalModelRun.Internal`
**Blocked by**: Sprint 18.2
**Independent Validation**: five explorer/TLC fingerprint comparisons, eight exact safety mutants, four fairness deletions, and three compiled production mutants
**Oracle**: Haskell model/capacity/calculus expectations and supervisor-bound exact failure loci
**Legacy IDs**: none; five retired Phase-18 behavioral files are enumerated and checked absent
**Docs to update**: this phase file, `formal_model_doctrine.md`, `dsl_doctrine.md`, `cluster_lifecycle_doctrine.md`, and `system_components.md`

### Objective

Prove the bounded model claims, demonstrate their obligations are load-bearing, and retain the result as a
source-bound phase-gate result.

### Deliverables

- Retain exact states, edges, obligations, fairness premises and cutoff assumptions in qualified model receipts; distinguish bounded proof from sampled executable correspondence.

- Five exact explorer/TLC fingerprint comparisons.
- Eight exact safety mutants and four fairness-drop mutants red.
- Fourteen metrics, 15-surface/18-item join, ledger, containment, write guard, and exact run binding.

### Validation

- Run model mutants and actual production-decision mutants separately at their assigned obligations. A change to `capacityCases` alone cannot satisfy a capacity-semantics mutation requirement.
- Reject any candidate missing an owner/model/case link or relying on an unqualified Phase-11 through Phase-14 checker; retain each unsupported or assumed layer explicitly.

1. Require explorer/TLC fingerprint equality on all five transition-bearing DSL models.
2. Require each safety mutant to violate exactly its authored invariant and each fairness drop to fail TLC.
3. Require all generated model-check output beneath `.build/**` and absent from the source snapshot.
4. Bind the complete result to the natural architecture and source digest.

### Remaining Work

Bind the retained requirements to the replacement Haskell acceptance contract, repair the stated gaps, and
qualify this phase's complete gate after its predecessor. Resolve owned legacy debt with observed closure.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

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
