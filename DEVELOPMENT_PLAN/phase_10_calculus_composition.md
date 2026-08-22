# Phase 10: Composition across the five calculi

> **Purpose**: Deliver the total composition boundary that preserves the Phase 8 request-scope index and
> exactly adds the Phase 9 resource index across values from all five core calculi.
> **Read this if**: two calculus components must be combined, a component transform must retain its indices,
> or the boundary between base composition and later extension-law conformance must be read precisely.

This phase owns the base composition operator, not arbitrary-extension closure. It combines representative
values from the artifact, budget, lift, workflow, and evidence calculi at one request scope and derives one
exact resource fold. Phase 22 later instantiates C1–C7 over extension declarations and retains the unproved
C1 residue.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_37_ui_program_schema.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 10.1: Index-preserving five-calculus composition ✅](#sprint-101-index-preserving-five-calculus-composition-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All thirteen gate sides passed on natural `arm64`, untranslated. The run
exhausted 25 ordered pairs and 125 triples, passed three 500-case properties, rejected different request
scopes, and reddened all three real mutants. All ten metrics matched and 18 surfaces joined completely.
Attestation `sha256:d18a3046817c4ab9c5291cc345c8c0ee78703bcdc420c777b4714e069261eb2e` binds source
`sha256:9660bb0796d25968…` over 2,156 files.

## Phase Summary

`Component scope` is a private closed sum whose five arms contain real representative values from the five
owning calculi. Each smart constructor requires a `RequestScope scope` and a `ResourceVector`. `compose`
accepts the same `scope` variable on both arguments, `append` preserves sequence, and
`compositionResource` folds exact `Natural` addition. A label transform preserves the calculus payload and
both indices.

**Phase scope:** One Register-1 composition boundary accepted by
`python3 tools/calculus_composition_gate.py`; split if work introduces extension declarations, verdicts,
generated extension gates, arbitrary-link-set closure, a protocol, or a runtime observer.
**Substrate:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 1 — pure/golden
**Depends on:** [Phases 3–7](README.md#phase-overview) — the five calculus payload types;
[Phase 8](phase_08_scope_index.md) — the rank-2 request scope; and
[Phase 9](phase_09_resource_index.md) — the exact base resource vector.
**Gate:** `python3 tools/run_phase_gate.py 10` passes committed oracle
`test/oracle/calculus_composition/pairs.tsv`, compiler fixtures
`test/negative/compile_fail/calculus_composition/{same_scope_composes,different_scopes_do_not_compose}.hs`,
125 triples, three coverage-bound properties, three real mutants, totality/boundary scans, surface join,
ledger, containment, write guard, natural architecture, and source-bound attestation.

## Gate integrity

- **Representative set:** one value from each real calculus payload type; all 25 ordered pairs; all 125
  ordered triples; both identity directions; and one label transform per calculus.
- **Independent oracle:** `test/oracle/calculus_composition/pairs.tsv` predates each run and states the exact
  four-axis resource result for every ordered pair. The gate verifies its closed 5×5 shape before the suite
  reads it and never regenerates expected values from observed composition.
- **Generated properties:** three QuickCheck properties sample arbitrary resource vectors for exact addition,
  associativity, and transform preservation. Each runs 500 cases and covers every calculus constructor at
  15% or more. These infinite-domain results are `TESTED (sampled)`.
- **Exhausted properties:** the five-calculus constructor set, 25 ordered kind pairs, and 125 ordered kind
  triples are finite and exhausted. This does not exhaust the payload or numeric domains.
- **Specific compiler barrier:** the same-scope program type-checks; the minimal different-scope twin fails
  because the two rank-2 request skolems cannot unify. The reason is pinned to GHC's type mismatch.
- **Seeded mutants:** three registry-backed configurations admit different scopes, saturate exact resource
  addition, or erase the resource index during a transform. Each must fail at its named compiler or property
  locus, and the clean configuration is restored afterward.
- **Totality and numeric developability:** the one-module `calculus-composition` library uses a dedicated
  source root, depends only on Phases 3–9, has exhaustive-pattern warnings as errors, and is scanned for
  partial or ambient-read tokens. It imports no later `dsl-core`.
- **Law honesty:** the gate exercises the base forms of identity (C2), associativity (C3), resource
  additivity (C5), and scope conjunction (C6). It does not establish extension closure (C1), external
  non-interference (C4), address disjointness (C7), or composition of the S/P law families. Those later
  obligations remain `UNVERIFIED`.
- **Observer controls:** this value-only boundary has no authority endpoint or external effect at which to
  place a nonce, authenticated observer, bypass attempt, or authority pair. Its independent instruments are
  the authored table, the compiler, and source/build mutants; protocol and runtime remain unclaimed.
- **Extension conformance (§M.13).** Not applicable: the deliverable is algebra infrastructure consumed by
  future extensions, not a domain, provider, hardware extension, or conformance verdict.

The gate establishes exact finite-kind composition and sampled index laws. It does not prove arbitrary
extension closure, correctness of a calculus payload, live capacity truth, or runtime isolation.

## Doctrine adopted

- [`extension_conformance_laws.md` C2 — Identity](../documents/engineering/extension_conformance_laws.md#c2-identity): the request-indexed empty composition is a two-sided identity.
- [`extension_conformance_laws.md` C3 — Associativity](../documents/engineering/extension_conformance_laws.md#c3-associativity): grouping never changes component order, names, or the derived resource fold.
- [`extension_conformance_laws.md` C5 — Budget additivity](../documents/engineering/extension_conformance_laws.md#c5-budget-additivity): the base resource requirement is the exact sum of its components.
- [`extension_conformance_laws.md` C6 — Scope conjunction](../documents/engineering/extension_conformance_laws.md#c6-scope-conjunction): composition accepts one request-scope index and never widens it.
- [`extension_conformance_doctrine.md` §7 — link-time union closure](../documents/engineering/extension_conformance_doctrine.md#7-link-time-union-closure): pair/triple tests remain evidence rather than the missing universal C1 proof.
- [`testing_doctrine.md` §9 — generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): run-time surfaces and generated cases join to independent expectations.

## Sprints

## Sprint 10.1: Index-preserving five-calculus composition ✅

**Status**: Done
**Implementation**: `lib:calculus-composition`,
`src/calculus-composition/Amoebius/Calculus/Composition.hs`,
`test/spec/calculus/CalculusCompositionSpec.hs`,
`test/negative/compile_fail/calculus_composition/**`,
`test/oracle/calculus_composition/**`, and `tools/calculus_composition_gate.py`.
**Blocked by**: None.
**Independent Validation**: The authored 25-row table states every pair's exact resource vector. The
different-scope compiler twin, exhaustive triples, generated properties, and three build/source mutants use
independent failure mechanisms.
**Docs to update**: `documents/engineering/{extension_conformance_doctrine,extension_conformance_laws,testing_doctrine}.md`, `DEVELOPMENT_PLAN/{README,overview,system_components,legacy_tracking_for_deletion}.md`.

### Objective

Adopt C2, C3, C5, and C6 at the base calculus/index boundary: compose any two of the five component arms only
at one request scope, preserve their payloads and order, and derive the exact resource sum.

### Deliverables

- A closed `Calculus` enumeration and private five-arm `Component scope` over real calculus payloads.
- Scope-requiring constructors, same-scope `compose`, identity, associative `append`, and index-preserving
  label transform operations.
- An exact `Natural` resource fold over the Phase-9 four-axis vector.
- A 25-row independent ordered-pair oracle and exhaustive 125-triple composition corpus.
- Three 500-case coverage-bound generated properties.
- One same-scope/different-scope compiler pair pinned to the rank-2 mismatch.
- Three registry-backed real mutants for scope, arithmetic, and transform weakening.
- A contained Register-1 gate with architecture, surface, ledger, and source-bound evidence.

### Validation

1. Require the oracle to enumerate each ordered calculus pair exactly once and the suite to construct every
   pair in the stated order with its exact four-axis sum.
2. Exhaust all 125 kind triples for associativity and both identity directions for every component.
3. Run 500 generated cases per numeric additivity, associativity, and transform property with declared
   constructor coverage.
4. Compile the same-scope twin, reject the different-scope twin at the rigid type mismatch, and require the
   weakened signature to make that negative compile.
5. Require the saturation and transform mutants to fail at their named property loci, then restore and rerun
   the clean build.
6. Join all metrics and checks to 18 authored surfaces, keep outputs generated, and bind the result to the
   natural architecture and complete source snapshot.

### Remaining Work

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `extension_conformance_doctrine.md` — distinguish the built base operator from the unbuilt extension
  declaration, generated gate, verdict, and C1 proof.
- `extension_conformance_laws.md` — record the finite Phase-10 instances of C2, C3, C5, and C6 without
  claiming the Phase-22 extension-law discharge.
- `testing_doctrine.md` — record finite exhaustion, sampled numeric properties, the compiler barrier, and the
  runtime residue.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md`, `overview.md`, and `system_components.md` — reconcile status, sequence,
  component paths, and evidence.
- `DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md` — consume the sealed algebra before the proof stack.
- `DEVELOPMENT_PLAN/phase_20_extension_declaration.md` and Phase 22 — retain the later declaration and
  arbitrary-extension law boundaries.

## Related Documents

- [Development Plan Standards](development_plan_standards.md) — the phase and gate contract.
- [Gate Integrity](development_plan_gate_integrity.md) and [Phase Model](development_plan_phase_model.md) — universal gate and sequencing rules.
- [Development Plan Tracker](README.md) — numeric order and current status.
- [Overview](overview.md) and [System Components](system_components.md) — algebra placement and concrete inventory.
- [Artifact](phase_03_artifact_calculus.md), [Budget](phase_04_budget_calculus.md), [Lift](phase_05_lift_calculus.md), [Workflow](phase_06_workflow_calculus.md), and [Evidence](phase_07_evidence_calculus.md) — the five payload owners.
- [Scope Index](phase_08_scope_index.md) and [Resource Index](phase_09_resource_index.md) — the two indices composition preserves.
- [Extension Declaration](phase_20_extension_declaration.md) and [Compositional Laws](phase_22_extension_laws_compositional.md) — later open-extension consumers.
- [Generic Browser Interpreter](phase_42_ui_browser_interpreter.md) — a later real five-calculus projection.
- [UI-Server Boundary](phase_43_ui_server_boundary.md) — a later real five-calculus projection.
- [Local UI Composition](phase_44_ui_local_composition.md) — a later real five-calculus projection across the
  composed browser/server/fake-adapter boundary.
- [Encrypted Browser Offline Runtime](phase_45_encrypted_browser_runtime.md) — a later real five-calculus
  projection across the production PureScript and two-process Chrome boundary.
- [Extension Conformance Doctrine](../documents/engineering/extension_conformance_doctrine.md) and [Laws](../documents/engineering/extension_conformance_laws.md) — normative composition claims and honesty boundary.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — Register-1, finite exhaustion, and sampled-property discipline.
