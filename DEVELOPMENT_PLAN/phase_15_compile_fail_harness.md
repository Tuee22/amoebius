# Phase 15: The compile-fail fixture harness

> **Purpose**: Bind an unrepresentability claim to a legal/illegal source twin and the structured compiler
> reason at which the illegal expression must fail.
> **Read this if**: a type-level foreclosure needs executable evidence, or a compile failure must be
> distinguished from an unrelated broken fixture.

This phase owns the reusable GHC compile-fail harness and the first reconciled claim inventory over the five
calculus-owner phases that already expose suitable twins. It requires a green positive, a structured error
code, an exact source start, message pins, and opposing source probes. It proves only that the indexed illegal
expression is rejected for that reason; it does not prove that every expression representing the state is
uninhabited.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 15.1: Structured diagnostic and twin contract ✅](#sprint-151-structured-diagnostic-and-twin-contract-)
- [Sprint 15.2: Claim inventory and mutation evidence ✅](#sprint-152-claim-inventory-and-mutation-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All twelve gate sides passed on natural `arm64`, untranslated: ten legal twins
compiled, ten illegal twins failed at their exact structured code/start/message pins, all twelve metrics
matched, all three meta-mutants were red at their own loci, and 23 surfaces joined to 25 enumerated items.
Attestation `sha256:ffec5a0b37b42e263c7bb5dcb84870289b02cb0baa82d5be379ba73aac8f0a74` binds source
`sha256:0f20aadfd92e96f8…` over 2,184 files. Repository-conformance and documentation support gates passed on
that same snapshot.

## Phase Summary

`tools/compile_fail_harness.py` reads one authored row per unrepresentability claim. Each row names its owner,
legal and illegal Haskell sources, foreclosed dimension, exact GHC error code and start coordinate, required
message fragments, and a probe exclusive to each twin. An absolute dynamically resolved GHC compiles both
sources with structured JSON diagnostics: the legal source must be entirely green, while every illegal error
must have the pinned code and exactly one must occur at the pinned source start with all required fragments.
Module-not-found, parse, and unbound-name failures are explicitly unrelated and cannot satisfy a row.

**Phase scope:** One GHC structured-diagnostic schema, one legal/illegal twin contract, and one representative
inventory covering ten claims from Phases 4, 5, 6, 7, and 10; split if work admits another language/compiler,
needs a compiler-version-specific schema, or migrates a later domain's whole negative corpus.
**Substrate:** none
**Lane:** none
**Register:** 1 — pure/golden
**Depends on:** [Phase 7](phase_07_evidence_calculus.md) — the claim/fixture strength rule this runner makes
executable; [Phase 10](phase_10_calculus_composition.md) — the latest source owner represented in the first
inventory tranche.
**Gate:** `python3 tools/run_phase_gate.py 15` passes the authored manifest, owner and diagnostic-code
coverage, absolute compiler boundary, ten source twins and twelve exact metrics, three registry-backed
meta-mutants at their own loci, generated-result discipline, surface join, ledger, containment, write guard,
natural architecture, and source-bound attestation.

## Gate integrity

- **Representative set:** ten claims cover a hidden constructor, omitted argument, incompatible type index,
  custom `TypeError`, and rank/scoped-type mismatch across four distinct GHC codes and five prior owner phases.
- **Independent oracle:** `test/oracle/compile_fail_harness/fixtures.tsv` is authored from the owning phase
  contracts. It fixes claim identity, both source paths, the one foreclosed dimension, code, source start,
  message fragments, and two exclusive source probes without reading compiler output at run time.
- **Positive counterpart:** every illegal file has a separately compiled legal counterpart. The harness will
  not inspect the negative until the positive is green, and both source digests enter the generated metrics.
- **Specific-reason negative:** GHC `-fdiagnostics-as-json` is parsed as data. Every error in an illegal compile
  must carry the one expected code, exactly one record must start at the pinned line/column, and its messages
  must contain every authored fragment.
- **Twin dimension:** an authored legal probe must occur only in the legal source and an illegal probe only in
  the illegal source. This makes the claimed difference checkable without pretending arbitrary Haskell
  sources can be mechanically proved semantically identical outside that dimension.
- **Wrong-reason rejection:** a zero exit, no structured error, unexpected code, missing pin/fragment,
  module-resolution error, parse failure, or unbound name is a harness failure rather than evidence.
- **Compiler boundary:** GHC is dynamically resolved from `>=9.12 <9.13` and injected by absolute path; the
  harness performs no ambient executable discovery and writes compiler output only beneath `.build/tmp/**`.
- **Seeded defects:** one mode accepts a generated parse failure as any failure, one omits the positive compile
  and offers the red fixture as its own twin, and one substitutes impossible diagnostic code zero. Each is
  rejected at a distinct registry-declared locus.
- **Generated-artifact discipline:** the suite emits only `.build/checkers/compile-fail/results.tsv`. Twelve
  metrics must equal authored values, 23 surfaces must join to 25 run-time items, and output remains outside
  the source snapshot.
- **Honesty boundary:** the result establishes rejection of ten exact expressions under the resolved GHC
  semantics. It neither proves a Haskell type uninhabited nor says anything about runtime enforcement.
- **Observer controls:** no authenticated service or authority path exists in a pure compiler process. The
  independent controls are the positive compile, authored structured pin, exclusive probes, and wrong-reason
  challenges rather than privileged/unprivileged runtime observers.
- **Extension conformance (§M.13).** Phase 15 declares no extension or domain member; clause 13 has no
  declaration boundary to exercise.

The harness turns “failed somehow” into a stable evidence contract while preserving the evidence calculus's
deliberately narrow `this-expression-rejected` strength.

## Doctrine adopted

- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing): compile-fail evidence is a Register-1 source/compiler observation.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): generated metrics and checks join to an authored Phase-15 surface.

## Sprints

## Sprint 15.1: Structured diagnostic and twin contract ✅

**Status**: Done
**Implementation**: `tools/compile_fail_harness.py` and the existing
`test/negative/compile_fail/{budget_calculus,lift_calculus,workflow_calculus,evidence_calculus,calculus_composition}/**`
source twins.
**Blocked by**: None.
**Independent Validation**: the legal source is compiled separately before the structured diagnostic from
the illegal source is compared to a hand-authored code, span, and message pin.
**Docs to update**: `documents/engineering/testing_doctrine.md` and
`DEVELOPMENT_PLAN/{README,overview,system_components}.md`.

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

None.

## Sprint 15.2: Claim inventory and mutation evidence ✅

**Status**: Done
**Implementation**: `test/oracle/compile_fail_harness/fixtures.tsv`,
`test/oracle/compile_fail_harness_surfaces.tsv`, `test/mutant/registry.tsv`, and
`tools/compile_fail_harness_gate.py`.
**Blocked by**: Sprint 15.1's structured diagnostic and positive-twin contract.
**Independent Validation**: ten hand-authored claim rows cross five owner phases and four compiler codes, then
three meta-mutants attack different conditions of acceptance.
**Docs to update**: `documents/engineering/testing_doctrine.md` and
`DEVELOPMENT_PLAN/{README,legacy_tracking_for_deletion,system_components}.md`.

### Objective

Demonstrate that the format carries real heterogeneous claims and remains sensitive to wrong reasons,
missing positives, and impossible expectations.

### Deliverables

- Ten unique claims and twins from Phases 4, 5, 6, 7, and 10.
- GHC codes 1928, 83865, 64725, and 25897 with ten exact starts and message pins.
- Ten legal successes, ten illegal failures, and eleven structured error records.
- Registry-backed accept-any-failure, positive-deletion, and impossible-pin mutants.
- Twelve result metrics, 23 authored surfaces/25 run-time items, a Register-1 ledger, containment, write guard,
  natural-architecture record, and source-bound attestation.

### Validation

1. Require the exact ten-claim/five-owner/four-code inventory shape.
2. Compare all twelve generated metrics to the authored expectations.
3. Run each meta-mutant independently and require its exact registry-declared failure locus.
4. Join every run-time item to one authored surface and leave runtime fidelity `UNVERIFIED`.

### Remaining Work

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
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
