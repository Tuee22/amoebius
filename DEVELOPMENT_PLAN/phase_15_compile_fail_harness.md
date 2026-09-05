# Phase 15: The compile-fail fixture harness

> **Purpose**: Specify the target Haskell capability to bind each compile-time unrepresentability
> claim to legal and illegal `.hs` source twins and the structured GHC diagnostic reason at which
> the illegal twin must fail.
> **Read this if**: a type-level foreclosure needs executable evidence, or a compile failure must be
> distinguished from an unrelated broken fixture.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_03_artifact_calculus.md, DEVELOPMENT_PLAN/phase_05_lift_calculus.md, DEVELOPMENT_PLAN/phase_06_workflow_calculus.md, DEVELOPMENT_PLAN/phase_07_evidence_calculus.md, DEVELOPMENT_PLAN/phase_08_scope_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision](#resource-provision)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 15.1: Structured diagnostic and twin contract](#sprint-151-structured-diagnostic-and-twin-contract-)
- [Sprint 15.2: Claim inventory and mutation evidence](#sprint-152-claim-inventory-and-mutation-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 14, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to bind each compile-time unrepresentability claim to legal and illegal `.hs`
source twins and the structured GHC diagnostic reason at which the illegal twin must fail.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — bind each compile-time unrepresentability claim to legal
and illegal `.hs` source twins and the structured GHC diagnostic reason at which the illegal twin
must fail. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 14](phase_14_refinement_checker.md)
**Gate:** `pb validate phase 15`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-15 semantic and resource payloads,
package-hidden serial supervisor, typed Haskell diagnostic subject, independently authored ten-pair corpus,
and three changed-production subjects are complete; only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | The Haskell harness binds ten type-level claims to legal/illegal `.hs` twins and accepts an illegal twin only for its exact structured GHC code, start, and message fragments. |
| `Subject` | `Amoebius.Compiler.CompileFailHarness` is acquired only through package-hidden `Amoebius.Validation.CompileFailHarnessRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 15`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly and synchronously. |
| `Oracle` | `CompileFailHarnessSpec.hs` independently embeds the ten-pair/five-owner/four-code inventory and its exact diagnostic pins. |
| `Positive controls` | Every legal twin compiles first and emits no structured Error before its corresponding illegal twin can be considered. |
| `Paired negatives` | Every illegal twin fails at its exact code/start/message pin; wrong-reason parse failure, missing JSON diagnostic, and unbound-name failure are rejected. |
| `Mutants` | Accept-any-failure, positive-counterpart deletion, and impossible-pin changed production subjects compile and turn their assigned loci red. |
| `Discovery` | The production harness, Haskell oracle, and twenty Haskell twin sources equal the fixed 22-file inventory bidirectionally. |
| `Challenge` | All three mutations execute after acquisition and must be distinguished at independent exact loci. |
| `Observer` | The supervisor records absolute executable, argv, exit, transcript digest, and bounded failure text for each compiler and oracle process. |
| `Authority/bypass` | `pb`, PATH compiler discovery, network, host/hardware effects, writes outside the run root, and compiler/linker overlap are forbidden. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-15/work/**` root and requires equal opening/closing source identities. |
| `Qualification` | Exact inventory, clean legal/illegal corpus, three specific boundary refusals, artifact metrics, discovery, and all changed-production subjects pass together. |
| `Cleanroom` | Binaries, objects, wrong-reason fixtures, transcripts, and results are generated lazily beneath the fresh run root. |
| `Legacy closure` | Retired Phase-15 Python harness/gate and serialized behavioral manifest/surfaces are absent. |
| `Predecessor` | Consume exactly one durable Phase-14 receipt for this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Deterministic simulation, concrete models, runtimes, live effects, and hardware remain explicitly later-owned. |
| `Pass criterion` | `qualified-phase-fifteen-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

## Resource provision

Phase 15 owns serial GHC children and generated products beneath `.build/runs/phase-15/**`. Preflight requires
an absolute authenticated compiler path and a fresh run root. Allowed mutations are source compilation and
writes inside that root; PATH discovery, `pb`, network, host/hardware effects, writes elsewhere, and compiler
overlap are forbidden. The package-hidden parent supervisor is the external observer, cleanup is run-root
scoped, and no external owned residue is permitted.

## Doctrine adopted

- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing): compile-fail evidence is a Register-1 source/compiler observation.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): generated metrics and checks join to an authored Phase-15 surface.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 15.1: Structured diagnostic and twin contract ✅

**Status**: Done
**Implementation**: `src/compile-fail-harness/Amoebius/Compiler/CompileFailHarness.hs` and the twenty Haskell twin fixtures
**Blocked by**: [Phase 14](phase_14_refinement_checker.md) gate pass
**Independent Validation**: ten legal-green prerequisites, ten exact structured illegal pins, source digests, and three specific wrong-reason refusals
**Oracle**: `test/spec/compile_fail_harness/CompileFailHarnessSpec.hs`
**Legacy IDs**: none; retired Python and serialized Phase-15 behavioral sources are checked absent
**Docs to update**: this phase file, `testing_doctrine.md`, and `system_components.md`

### Objective

Create one total runner that cannot confuse an unrelated compiler failure with the type-level foreclosure a
claim names.

### Deliverables

- Closed TSV schema for claim, owner, twins, dimension, diagnostic, and probes.
- Absolute-path GHC invocation with JSON diagnostics and contained output.
- Legal-green prerequisite and exact illegal code/start/message classification.
- Explicit rejection of missing diagnostics and module, parse, or unbound-name failures.
- Source identity and exclusive legal/illegal dimension probes.

### Validation

1. Require all manifest fields, paths, numeric pins, claims, and illegal fixtures to be unique where owned.
2. Compile every positive with no structured error before accepting its negative.
3. Require every negative error code to equal the authored code and exactly one to match the pinned start.
4. Require all message/probe pins and both 64-hex source digests.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 15.2: Claim inventory and mutation evidence ✅

**Status**: Done
**Implementation**: package-hidden `src/validation-kernel/Amoebius/Validation/CompileFailHarnessRun/Internal.hs`
**Blocked by**: Sprint 15.1
**Independent Validation**: serial clean/three-mutant matrix, exact red loci, discovery, containment, metrics, and process receipts
**Oracle**: the same independently authored Haskell corpus; generated result TSV is an observation only
**Legacy IDs**: none; retired Python and serialized Phase-15 behavioral sources are checked absent
**Docs to update**: this phase file, `testing_doctrine.md`, and `system_components.md`

### Objective

Demonstrate that the format carries real heterogeneous claims and remains sensitive to wrong reasons,
missing positives, and impossible expectations.

### Deliverables

- Ten unique claims and twins from Phases 4, 5, 6, 7, and 10.
- GHC codes 1928, 83865, 64725, and 25897 with ten exact starts and message pins.
- Ten legal successes, ten illegal failures, and eleven structured error records.
- Registry-backed accept-any-failure, positive-deletion, and impossible-pin mutants.
- Twelve result metrics, 23 authored surfaces/25 run-time items, a Register-1 ledger, containment, write guard,
  natural-architecture record, and exact source-bound run record.

### Validation

1. Require the exact ten-claim/five-owner/four-code inventory shape.
2. Compare all twelve generated metrics to the authored expectations.
3. Run each meta-mutant independently and require its exact registry-declared failure locus.
4. Join every run-time item to one authored surface and leave runtime fidelity `UNVERIFIED`.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `testing_doctrine.md` — record the structured diagnostic/twin rule and its
  `this-expression-rejected` honesty boundary.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — reconcile status,
  compiler boundary, implementation paths, and evidence.

## Related Documents

- [Development Plan Tracker](README.md) — order, status, and accepted evidence.
- [Phase 7](phase_07_evidence_calculus.md) — the fixture kind and evidence strength this runner instantiates.
- [Phase 10](phase_10_calculus_composition.md) — the latest owner represented by the first manifest tranche.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — register, enumeration, and compile-fail evidence rules.
