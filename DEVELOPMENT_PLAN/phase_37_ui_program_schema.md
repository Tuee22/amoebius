# Phase 37: Bounded UI-program schema

> **Purpose**: Admit bounded declarative UI programs through a total checker and expose only a
> constructor-private `CheckedUiProgram` to later UI phases.
> **Read this if**: the UI source algebra, graph checker, program fixture corpus, or checked-program boundary
> has to change.

This phase owns the pure `UiSource` admission seam. It does not scope a user request, evaluate authorization,
bind an effect handler, emit client/server plans, or run a browser or server. Those boundaries remain with
Phases 38–44.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/dsl_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 37.1: Closed source algebra and total checker ✅](#sprint-371-closed-source-algebra-and-total-checker-)
- [Sprint 37.2: Independent semantics and rejection coverage ✅](#sprint-372-independent-semantics-and-rejection-coverage-)
- [Sprint 37.3: Calculus projection and phase seal ✅](#sprint-373-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21 by the amended bounded-UI Register-1 gate.

**Validation record.** The thirteen-sided gate passed on natural `darwin/arm64`, untranslated. Three positive
program-semantic projections and ten exact diagnostic rows pass; all eight generated rejection classes meet
their coverage floor; the constructor seal rejects its illegal twin; all six mutants redden at their exact
loci; and the real five-calculus composition accounts for 30 projected units. All 17 metrics match, and 39
surfaces join to 56 enumerated items. The normalized-wire byte golden is absent. Attestation
`sha256:99821aa662d19520fee179bae3cc860d03b6ac5e6bff98fad128f02854778b5e` binds source
`sha256:4db7e943dae7534f…` over 2,260 files. Browser, server, authorization, handler, and provider enforcement
remain UNVERIFIED.

**Observed progress — 2026-08-21:** **Known partial.** Three positive programs decode and check, ten negative
programs fail with exact tag/span diagnostics, all eight generated rejection classes meet their coverage
floor, the checked-program constructor seal compiles only its legal twin, all six paired mutants have distinct
loci, and the real five-calculus composition matches its `3,10,8,3,6` projection. The former normalized-wire
byte golden is retired in favour of an authored program-semantic table.

**Activated 2026-08-21** after Phase 36 sealed. The generative re-baseline invalidated the former seal because
it had no five-calculus projection and treated derived wire bytes as an oracle.

---

## Phase Summary

The closed Dhall `UiSource` record carries a tenant mode, finite modules, finite nodes, and named external-link
requirements. Its node and value types are closed unions; there is no source constructor for JavaScript,
HTML, CSS, a raw URL, provider coordinates, or authority credentials. Real Dhall decoding feeds one total
Haskell checker.

The checker qualifies node identities, refuses duplicate or missing references, detects graph cycles, enforces
finite collection bounds, unifies port types, checks exhaustive event branches, and prevents server-private
values from entering a public projection. Successful checking produces a normalized, constructor-private
`CheckedUiProgram`; later phases can inspect its bounded graph but cannot forge it.

**Phase scope:** one cohesive claim — an application UI is bounded declarative data whose complete structural
admission precedes every scope, authorization, binding, plan, and runtime effect. Any request identity,
authorization decision, handler binding, plan emission, browser interpretation, or server dispatch splits out.

**Substrate:** `none` — Dhall decode, graph checking, compiler barriers, QuickCheck properties, and calculus
composition are pure host processes; no browser, provider, credential, or cluster is contacted
([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** `none` ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 1 — pure/generative: semantic tables and negative controls constrain the decision boundary;
browser, server, identity-provider, and storage-provider enforcement remain UNVERIFIED
([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 8](phase_08_scope_index.md) — the generative request scope used by the calculus
projection; [Phase 10](phase_10_calculus_composition.md) — the actual five-calculus composition; [Phase
25](phase_25_dhall_schema_generation.md) — the Dhall Gate-1 toolchain and closed-schema discipline.

**Gate:** `python3 tools/run_phase_gate.py 37` passes the semantic, diagnostic, graph, generated-property,
compile-seal, five-calculus, exact-mutant-locus, network-observer, surface-join, containment, and attestation
checks in [Gate integrity](#gate-integrity).

---

## Gate integrity

The gate consumes exactly three positive programs and ten independently pinned negatives. Each negative has a
stable rejection tag and source span in `test/fixture/ui_program_schema/cases.tsv`; the two failures at Dhall
Gate 1 and the eight failures in the Haskell checker remain distinguishable.

`test/oracle/ui_program_schema/program_semantics.tsv` independently names each positive program's tenant mode,
module identities, fully qualified node identities, and external-link names. It replaces the retired rendered
wire-byte golden. `graph_reference.tsv` separately names one representative checked node per program with its
kind, value type, qualified edges, and exhaustive event set. Repeated decode/check results must agree, but no
fresh output is copied into an authored oracle.

QuickCheck selects all eight illegal classes with a 5% minimum coverage floor: duplicate identity, missing
reference, cycle, port mismatch, excessive bound, non-exhaustive events, private projection, and duplicate
link. The closed tenant, node-kind, and value-type arm vectors are checked explicitly. A legal compiler twin
can consume `CheckedUiProgram`; an illegal twin cannot construct one.

Six paired mutants each start from an oracle-conforming subject, neutralize one rejection, and must exit red
at its exact locus: `RawBrowserEscape`, `RawExternalLinkUrl`, `UnboundedCollection`, `DuplicateQualifiedId`,
`NonExhaustiveEvent`, or `PortTypeMismatch`. A generic non-zero exit or another mutant's token is insufficient.

The artifact, budget, lift, workflow, and evidence components carry the `3,10,8,3,6`
program/diagnostic/generated-class/graph/mutant counts and compose to resource vector `5,30,0,0`. Normal and
kernel-observed network-isolated executions must both carry the semantic and calculus acceptance tokens.
Generated results and ledgers stay beneath `.build/**`.

Passing proves the bounded source admission boundary. It does not prove browser safety, authorization truth,
handler correctness, provider tenant isolation, or runtime noninterference; those rows remain UNVERIFIED.

- **Extension conformance (§M.13).** Not applicable: this phase declares no extension and composes no extension
  set. Its compiler seal, semantic oracles, and paired mutants constrain a standalone language boundary.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §4 — the authored Dhall surface](../documents/engineering/low_code_ui_runtime_doctrine.md#4-the-authored-dhall-surface):
  the UI language is finite data with no arbitrary browser or network language.
- [`low_code_ui_runtime_doctrine.md` §5 — GADT decode and the checked Haskell IR](../documents/engineering/low_code_ui_runtime_doctrine.md#5-gadt-decode-and-the-checked-haskell-ir):
  checking is total and only successful admission creates the private checked value.
- [`low_code_ui_runtime_doctrine.md` §6 — modules and total composition](../documents/engineering/low_code_ui_runtime_doctrine.md#6-modules-and-total-composition):
  qualified identities and deterministic merge replace textual inclusion.
- [`low_code_ui_runtime_doctrine.md` §7 — state, events, and deterministic updates](../documents/engineering/low_code_ui_runtime_doctrine.md#7-state-events-and-deterministic-updates):
  event tables and collections are finite and exhaustive.
- [`dsl_doctrine.md` §2 — Dhall carries params, Haskell carries logic](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic):
  Dhall describes the program while Haskell owns the admission logic.
- [`generated_artifacts_doctrine.md` §5 — authored vs generated](../documents/engineering/generated_artifacts_doctrine.md#5-authored-vs-generated-the-committed-source):
  authored semantic inputs constrain per-run derived output; rendered wire bytes are not committed evidence.

---

## Sprints

## Sprint 37.1: Closed source algebra and total checker ✅

**Status**: Done
**Implementation**: `dhall/amoebius/ui/`, `src/Amoebius/Ui/{Source,Check}.hs`
**Blocked by**: [Phase 25](phase_25_dhall_schema_generation.md) gate
**Independent Validation**: the real decoder admits all three positive programs, the checker returns the exact eight semantic error constructors, and the legal/illegal compiler twins preserve constructor opacity
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/engineering/dsl_doctrine.md`

### Objective

Adopt the bounded source and checked-IR doctrines; make executable escape hatches absent and structural
admission total.

### Deliverables

- Closed tenant, node-kind, and value-type unions plus finite module/node records.
- A deterministic decoder and normalizer with no raw browser or authority arm.
- A private checked-program constructor and total graph/type/bounds/event/projection folds.

### Validation

1. All three positives decode/check and all ten negatives reject at their exact layer, tag, and span.
2. The forbidden-arm, totality-token, and constructor-export scans pass.
3. The legal compiler twin builds and the illegal construction fails for the pinned reason.

### Remaining Work

None.

## Sprint 37.2: Independent semantics and rejection coverage ✅

**Status**: Done
**Implementation**: `test/fixture/ui_program_schema/**`, `test/oracle/ui_program_schema/{program_semantics,validation_locus}.tsv`, `test/spec/ui/UiProgramSchemaSpec.hs`, `test/mutant/ui_program_schema/**`
**Blocked by**: Sprint 37.1
**Independent Validation**: three program-semantic rows and three graph rows match real checked values; eight generated classes meet their floor; six controls each discriminate one exact locus
**Docs to update**: `documents/engineering/generated_artifacts_doctrine.md`, `documents/engineering/low_code_ui_runtime_doctrine.md`

### Objective

Constrain the admission meaning with independent semantic facts and falsifiable negative controls rather than a
snapshot of derived bytes.

### Deliverables

- Three authored program-semantic rows and three independent graph rows.
- Ten exact diagnostics and eight generated rejection classes with coverage floors.
- Six registered paired mutants and a complete 30-entry validation-locus inventory.

### Validation

1. Program and graph projections join their authored tables in both directions.
2. Two repeated decodes/checks agree without becoming the semantic oracle.
3. The retired normalized-wire golden is absent and every paired mutant reaches only its named locus.

### Remaining Work

None.

## Sprint 37.3: Calculus projection and phase seal ✅

**Status**: Done
**Implementation**: `test/oracle/ui_program_schema/calculus_projection.tsv`, `test/oracle/ui_program_schema_surfaces.tsv`, `tools/ui_program_schema_gate.py`
**Blocked by**: Sprint 37.2
**Independent Validation**: the real five-calculus values match all four authored projection rows and both normal and isolated suite executions carry the acceptance tokens
**Docs to update**: `documents/engineering/generated_artifacts_doctrine.md`, `documents/engineering/low_code_ui_runtime_doctrine.md`

### Objective

Seal the bounded admission claim with the re-baselined calculus, natural-architecture proof, complete surface
join, and repository-local attestation.

### Deliverables

- One five-calculus composition over the phase's actual bounded counts.
- A gate with Darwin/Linux network observers, exact mutant loci, generated-output containment, and lane
  declaration.
- A complete surface map retaining runtime and provider residues as UNVERIFIED.

### Validation

1. The calculus kind order, component names, counts, and resource vector match the authored oracle.
2. Normal and network-isolated executions pass; all six explicit mutant executions fail exactly.
3. The universal surface, ledger, containment, write-guard, architecture, and attestation sides pass.

### Remaining Work

None.

---

## Documentation Requirements

**Engineering docs to update when the gate seals:**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the bounded checked-graph evidence while
  retaining runtime claims as UNVERIFIED.
- `documents/engineering/dsl_doctrine.md` — record the checked `UiSource` specialization of Gate 1/2.
- `documents/engineering/generated_artifacts_doctrine.md` — replace the wire-table language with the semantic
  program oracle and retain the no-generated-output rule.

**Cross-references to update:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — record the seal, `none` substrate/lane, concrete gate, and honest
  live residues.

---

## Related Documents

- [Development Plan Tracker](README.md) — the phase order and current status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, one-substrate discipline, and gate integrity.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — the source algebra and checked IR.
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — the shared Dhall/Haskell admission discipline.
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — semantic-oracle and generated-output ownership.
- [Illegal-State Techniques](../documents/illegal_state/illegal_state_techniques.md) — closed sums, private constructors, bounded values, and total folds.
