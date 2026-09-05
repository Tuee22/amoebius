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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/system_components.md
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

---

## Phase Status

✅ Done.

Phase 17 and every earlier gate have current passing receipts. The Phase-18 implementation and compiled
semantic contract are bound below; completion still requires the exact integrated Phase-18 gate.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

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

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-18 semantic payload, package-hidden serial
supervisor, pure production models and decision subjects, separately authored Haskell oracle, fixed offline
JVM/TLC inputs, and three changed-production subjects are complete; only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | Six Haskell `Model` values cover the bounded projection, token, reservation, Lease, reconcile, and five-calculus claims; explorer and TLC agree for the five transition-bearing DSL models. |
| `Subject` | `Amoebius.Formal.Dsl.Models`, the Phase-9 capacity fold, three protocol decision modules, and the calculus projection are acquired only through package-hidden `DslFormalModelRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 18`; before `BOOTSTRAP_HANDOFF`, the exact source-bound Haskell executable invokes absolute Cabal 3.16.1.0 and GHC 9.12.4 directly, offline and serially, with digest-pinned Java 21.0.9/TLA+ 1.8.0. |
| `Oracle` | `DslFormalModelOracle.hs` separately declares exact model structure, state totals, capacity domain, calculus facts, and mutation catalogue without reading production renderings. |
| `Positive controls` | Six exact model contracts, 18 explorer states, five explorer/TLC fingerprint equalities, 6,561 capacity pairs, eight calculus facts, and three actual protocol decisions pass. |
| `Paired negatives` | Overcommit/admitted capacity pairs, token first/second consumption, unreachable/present reconciliation, eight exact safety mutants, and four fairness deletions all distinguish their intended boundary. |
| `Mutants` | Three Cabal flags change production projection count, token reuse, and unreachable deletion; each fresh build must fail at its exact independent oracle locus before the clean row. |
| `Discovery` | The closed five-production/three-oracle Haskell source set is joined bidirectionally to the captured source snapshot. |
| `Challenge` | The three changed-production builds are post-acquisition challenges and must each fail while the clean subject passes. |
| `Observer` | Exact process argv, exits, stdout/stderr digests, generated-product inventory, and source snapshots are captured outside the test subject. |
| `Authority/bypass` | No `pb`, network, host, hardware, or live service is admitted; only absolute Cabal, GHC, JVM, and TLC paths run, with compiler and TLC workers fixed to one. |
| `Freshness` | One unique `.build/runs/phase-18/work/candidate-*` root is created after acquisition; opening and closing source identities must match. |
| `Qualification` | Exact toolchain digests, all three production mutants, the independent oracle, paired negatives, discovery, containment, and legacy absence must pass before the clean result can qualify. |
| `Cleanroom` | All TLA/CFG/DOT/log/result products are created beneath the fresh run root; the authenticated network-independent source-package cache is copied into that root. |
| `Legacy closure` | The Python Phase-18 gate and four serialized behavioral oracle files are absent and independently enumerated. |
| `Predecessor` | Exact durable Phase-17 receipt for the current evolutionary source lineage; absent, stale, replayed, or wrong-phase evidence refuses execution. |
| `Residue` | Runtime/effect fidelity remains UNVERIFIED; decoder and provision/render/chain projections remain assigned to Phases 26, 31, 33, and 34. |
| `Pass criterion` | Every one of these 18 rows must be execution-derived green in one qualified run for the exact source snapshot. |

## Doctrine adopted

- [`formal_model_doctrine.md` §3 — Two total renderings](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings): explorer and TLC are separate readings of one model value.
- [`formal_model_doctrine.md` §4.1 — The reference model and its semantic oracle](../documents/engineering/formal_model_doctrine.md#41-the-reference-model-and-its-semantic-oracle): semantic facts, not generated bytes, decide renderer acceptance.
- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): no finite result is current; any future accepted model result would still leave runtime fidelity unproved.
- [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract): the target model must not claim credit for states that a gate-passed Haskell type-system boundary must first exclude.
- [`cluster_lifecycle_doctrine.md` §9 — How bring-up and teardown are implemented: the reconciler, not a state machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine): unreachable observation is distinct from absence.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 18.1: Actual bounded DSL projections ✅

**Status**: Done
**Implementation**: `src/capacity-topology/Amoebius/Capacity/Fold.hs`, `test/harness/deterministic_simulation/CalculusProjection.hs`, and the capacity/calculus sections of `DslFormalModelSpec.hs`
**Blocked by**: [Phase 17](phase_17_gateway_migration_model.md) gate pass
**Independent Validation**: exhaustive componentwise reference subtraction over all 6,561 pairs and eight exact five-calculus facts
**Oracle**: `DslFormalModelOracle.hs` plus the independently constructed `referenceCalculusProjection`
**Legacy IDs**: none; retired serialized Phase-18 oracles are checked absent directly
**Docs to update**: this phase file, `formal_model_doctrine.md`, `dsl_doctrine.md`, and `system_components.md`

### Objective

Connect a finite, explicitly named DSL decision tranche to real repository code without accepting generated
hashes or byte snapshots as semantic evidence.

### Deliverables

- Exhaustive four-axis `0..2` demand/capacity differential over 6,561 pairs.
- Actual five-calculus composition projected through the shared formal bridge.

### Validation

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

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate. The two removed tranches are
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

- One projection model and four transition models with eight safety and four liveness obligations.
- Actual one-use token, one-debit reservation, and unreachable-refusal readings.
- Six-model contract including the actual calculus-composition model.

### Validation

1. Require exact model structure and an 18-state explorer total.
2. Require the actual protocol decisions at their exact outcomes and reasons.
3. Keep all live/effectful correspondence marked UNVERIFIED.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

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

- Five exact explorer/TLC fingerprint comparisons.
- Eight exact safety mutants and four fairness-drop mutants red.
- Fourteen metrics, 15-surface/18-item join, ledger, containment, write guard, and exact run binding.

### Validation

1. Require explorer/TLC fingerprint equality on all five transition-bearing DSL models.
2. Require each safety mutant to violate exactly its authored invariant and each fairness drop to fail TLC.
3. Require all generated model-check output beneath `.build/**` and absent from the source snapshot.
4. Bind the complete result to the natural architecture and source digest.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

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
