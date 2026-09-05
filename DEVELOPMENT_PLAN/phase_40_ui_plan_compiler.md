# Phase 40: UI plan compiler

> **Purpose**: Compile one sealed `BoundUiProgram` deterministically into matching immutable client, server,
> public-contract, content-manifest, digest, and finite-demand projections.
> **Read this if**: the paired-plan compiler, its canonical artifact boundary, or its Register-1 evidence has
> to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 40.1: Paired semantic projection](#sprint-401-paired-semantic-projection-)
- [Sprint 40.2: Canonical artifacts, digests, and demand](#sprint-402-canonical-artifacts-digests-and-demand-)
- [Sprint 40.3: Calculus projection and phase seal](#sprint-403-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 39, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

## Phase Summary

**Target capability — NOT VALIDATED.** One private Haskell `BoundUiProgram` is to produce public client instructions, a serializable private server dispatch
manifest, public contracts, a content manifest, complete authority/content identities, and finite client/server
runtime demand together. Exact action, route, contract, audit, handler, and resolved-link projections cannot
drift between halves. Public output excludes private fields, handles, policies, provider coordinates, and raw
effect destinations.

The target compiler exposes no client-only or server-only entry point. Canonical ordering and encoding make repeated
fresh compilation stable, while changing or omitting an authority-bearing source changes the authority digest.
All serialized plans, manifests, cases, and mutations are generated lazily beneath `.build/**`. Separately
checked Haskell semantics, never repository-retained JSON or renderer-produced bytes, constrain the projection.

**Phase scope:** one target claim — one sealed Haskell program compiles purely and deterministically to one matching,
finite artifact set. Interpretation, publication, serving, and live freshness split out.

**Substrate:** `none` — compilation, reference comparison, calculus composition, and generated mutations are
pure; the canonical Haskell gate has no credentials or network.

**Lane:** `none` ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 1 — pure/semantic-oracle. Logical projection is independently constrained; interpreter fidelity, release
publication, edge enforcement, and live authority freshness remain UNVERIFIED.

**Depends on:** [Phase 39](phase_39_ui_effect_binding.md)
**Gate:** `pb validate phase 40`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `pure-deterministic-ui-plan-compiler` |
| `Subject` | `acquired-ui-plan-compiler-supervisor` |
| `Command` | `pb validate phase 40` (future public spelling); the pre-handoff gate directly executes the exact source-bound Haskell supervisor and its offline serial matrix. |
| `Oracle` | `independent-ui-plan-compiler-oracle` |
| `Positive controls` | `ui-plan-compiler-positive-controls` |
| `Paired negatives` | `exact-ui-plan-compiler-paired-negatives` |
| `Mutants` | `applied-ui-plan-compiler-production-mutants` |
| `Discovery` | `exact-ui-plan-compiler-source-discovery` |
| `Challenge` | `post-acquisition-ui-plan-compiler-challenge` |
| `Observer` | `ui-plan-compiler-process-observation` |
| `Authority/bypass` | `no-pb-network-interpreter-provider-host-hardware-or-parallelism` |
| `Freshness` | `fresh-ui-plan-compiler-build-root-and-stable-source` |
| `Qualification` | `qualified-ui-plan-compiler-harness` |
| `Cleanroom` | `ui-plan-compiler-products-contained-below-build` |
| `Legacy closure` | `retired-ui-plan-compiler-authorities-absent` |
| `Predecessor` | `exact-phase-thirty-nine-receipt` |
| `Residue` | `ui-interpreter-offline-runtime-and-publication-owners-explicit` |
| `Pass criterion` | `qualified-phase-forty-gate-pass` |

## Doctrine adopted

- [`jit_artifact_doctrine.md` §3 — Targets and recipes](../documents/engineering/jit_artifact_doctrine.md#3-targets-and-recipes): each emitted plan is generated from typed source rather than authored as product input.
- [`low_code_ui_runtime_doctrine.md` §3 — One checked value, two runtime plans](../documents/engineering/low_code_ui_runtime_doctrine.md#3-one-checked-value-two-runtime-plans): both plan halves are inseparable projections of one bound value.
- [`low_code_ui_runtime_doctrine.md` §9 — Routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): route and action projections retain mandatory policy references.
- [`low_code_ui_runtime_doctrine.md` §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): complete authority/content identities and immutable per-app plans are derived.
- [`ui_realtime_coordination_doctrine.md` §4 — Typed routing and resume envelope](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): both halves carry the scoped routing identity while Redis remains platform-internal.
- [`generated_artifacts_doctrine.md` §2 — What is generated (and from what)](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what): plan and manifest output is generated lazily beneath `.build/**` and remains untracked.
- [`illegal_state_security.md` §3.83 — A UI plan executed after an authority-bearing source changed](../documents/illegal_state/illegal_state_security.md#383-a-ui-plan-executed-after-an-authority-bearing-source-changed): complete freshness identity is mandatory.

---

## Sprints

## Sprint 40.1: Paired semantic projection ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Compile/{ClientPlan,ServerPlan,Manifest,Demand}.hs`; `test/spec/ui/UiPlanCompilerCases.hs`; production CPP mutation seams in the compiler modules.
**Blocked by**: [Phase 39](phase_39_ui_effect_binding.md) gate pass
**Independent Validation**: `ui-plan-compiler-spec` exact projection/parity/refusal checks plus isolated production-mutant rows in the acquired Phase-40 supervisor.
**Oracle**: `test/spec/ui/PlanCompilerReference.hs`, independently authored and importing no production or case module.
**Legacy IDs**: `tools/ui_plan_compiler_gate.py`; the five serialized Phase-40 fixture artifacts; three serialized oracle/surface tables; six materialized mutant descriptors.
**Docs to update**: this plan, `DEVELOPMENT_PLAN/{substrates,system_components}.md`, `documents/engineering/{low_code_ui_runtime_doctrine,generated_artifacts_doctrine,ui_realtime_coordination_doctrine}.md`, and `documents/illegal_state/illegal_state_security.md`.

### Objective

Adopt one compiler entry point whose only successful result contains both public and private plan halves.

### Deliverables

- Constructor-private `ClientPlan`, `UiServerPlan`, and combined result values.
- Four exact logical projections and direct action-key parity.
- Public allowlisting and authority-source change/omission refusals.

### Validation

1. All four production projections equal the independent reference relation.
2. Client and server action keys agree exactly.
3. Private-field, link-as-effect, changed-authority, and omitted-authority controls retain distinct loci.

### Remaining Work

The complete integrated Phase-40 gate and its mechanical status projection remain. Browser/server interpretation, offline packaging, publication, live authority enforcement, and hardware remain later-owned residue.

## Sprint 40.2: Canonical artifacts, digests, and demand ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Compile/{ClientPlan,ServerPlan,Manifest,Demand}.hs`; typed artifact expectations in `test/spec/ui/UiPlanCompilerCases.hs`.
**Blocked by**: Sprint 40.1
**Independent Validation**: byte-exact typed artifacts, independent digest derivation, six demand cells, and two serial fresh-process order controls in `ui-plan-compiler-spec`.
**Oracle**: `test/spec/ui/PlanCompilerReference.hs` plus typed Haskell expectations in `test/spec/ui/UiPlanCompilerCases.hs`.
**Legacy IDs**: same closed Phase-40 Python/serialized/materialized-mutant inventory owned by the integrated gate.
**Docs to update**: the generated-artifact and paired-plan owners named by Sprint 40.1.

### Objective

Make compilation finite and reproducible without mistaking generated bytes or digest observations for authored
semantic intent.

### Deliverables

- Four canonical JSON regression artifacts generated lazily beneath `.build/**` from Haskell declarations,
  plus four run-time-derived digest observations.
- Six finite client/server demand cells.
- Cache-disabled fresh-process determinism and insertion-order sensitivity control.

### Validation

1. Every lazily generated regression artifact is canonical JSON and byte-exact; no tracked digest table or
   serialized expectation exists.
2. The independent Haskell oracle derives the four expected digests independently and compares them with the
   current `.build/**` materializations.
3. Two fresh processes with opposite insertion order emit identical artifacts, while the deliberately ordered
   control differs.

### Remaining Work

The complete integrated Phase-40 gate and its mechanical status projection remain. Materialized JSON, digest tables, surface registries, and mutant descriptors are retired authorities; future projections remain lazy `.build/**` products.

## Sprint 40.3: Calculus projection and phase seal ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/UiPlanCompilerRun/Internal.hs`, dispatcher/evidence integration, compiled Phase-40 semantic contract, and serial Cabal matrix.
**Blocked by**: Sprint 40.2
**Independent Validation**: exact source discovery, serial compiler receipts, source stability, cleanroom containment, legacy absence, and the eighteen-row acquired gate.
**Oracle**: the Phase-40 runner binds `PlanCompilerReference`, typed cases, process observations, and changed-production mutant failures.
**Legacy IDs**: exact fifteen-path retired inventory in `UiPlanCompilerRun.Internal` and zero Phase-40 entries in `test/mutant/registry.tsv`.
**Docs to update**: this plan and the tracker/component/substrate cross-references before integrated validation.

### Objective

Test the pure compiler claim with current calculus, architecture, surface, containment, and exact run
observations.

### Deliverables

- A real five-calculus composition over the phase's observed sets.
- Six Haskell-authored paired changed-subject mutants with exact red tokens.
- A complete natural-architecture, surface, ledger, containment, write-guard, and run record.

### Validation

1. The authored calculus rows fix kind order, component names, count vector, and resource sum.
2. Ordinary and Darwin-denied executions accept; all six Haskell changed-subject mutant executions fail at
   their own loci.
3. All 17 metrics and the 61-surface/72-item join pass in the source-bound run.

### Remaining Work

The complete integrated Phase-40 gate and its mechanical status projection remain. All runtime and hardware layers remain explicitly unverified.

---

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — pure paired projection, calculus evidence, and
  honest runtime residues.
- `documents/engineering/generated_artifacts_doctrine.md` — generated artifact boundary and Haskell regression-
  expectation limitation.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — finite routing-envelope compilation without
  runtime claims.
- `documents/illegal_state/illegal_state_security.md` — authority/refusal evidence and exact Haskell
  changed-subject mutants.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — seal, substrate, gate, and owned modules.

---

## Related Documents

- [Development Plan Tracker](README.md) — phase order and current status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, register honesty, and gate integrity.
- [Phase 10](phase_10_calculus_composition.md) — five-calculus composition.
- [Phase 39](phase_39_ui_effect_binding.md) — sealed bound program.
- [JIT Artifact Doctrine](../documents/engineering/jit_artifact_doctrine.md) — generated recipe/address ownership.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — paired-plan and versioning contract.
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — generated-vs-authored boundary.
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md) — typed routing envelope.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — projection parity and stale-plan foreclosure.
