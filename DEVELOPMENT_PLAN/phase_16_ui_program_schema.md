# Phase 16: Bounded UI-program schema

> **Purpose**: Add the bounded `UiSource` Dhall algebra and total UI checker that seals structurally valid
> application programs as `CheckedUiProgram` values without admitting executable browser escape hatches.
> **Read this if**: phase 16 is next in the queue, or a later phase depends on what its gate establishes.

Phase 16 delivers the UI program schema; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [dsl_doctrine.md](../documents/engineering/dsl_doctrine.md), and the plan for reaching it is owned here.
Register 1: an in-process battery, no cluster.
Gate passed on 2026-08-09 with ledger `external-run-reference`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_14_chain_kernel_boundary.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/dsl_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 16.1: Bounded `UiSource` and total structural checker ✅](#sprint-161-bounded-uisource-and-total-structural-checker-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-13. The migrated gate passed against source snapshot `sha256:89b25d3a…`
(1941 non-ignored files) and published verified external attestation
`sha256:4580dcd430b5608434256528d6500153f7aac31b5bfe27bcf1b484e53ab44c9c`.

**Observed progress — 2026-08-13:** **Policy-conformant.** The bounded UI-program schema result is unchanged
and re-run: three positive programs decode and ten negatives fail with exact diagnostics, the graph reference
and normalized wire golden hold byte-identically, the eight generated classes each clear their coverage floor,
the checked-program compile seal rejects its illegal construction, and all six seeded mutants redden. Evidence
and the ledger move into `gen/runs/phase_16/<run-id>/`, and 30 run-time items partition one-to-one across the
schema's foreclosure surfaces.

**Each foreclosure surface takes both halves of its evidence.** The bound check joins its negative fixture
*and* `M-drop-bound-check`; exhaustiveness joins its negative *and* `M-skip-exhaustiveness`; port unification
joins its negative *and* `M-swap-port-contract`. A foreclosure is only evidenced by both — the negative that
must fail, and the mutant proving the check has teeth — and the join now says so.

Three surfaces join to source checks the gate always performed but never named: the forbidden browser-source
arm scan, the `CheckedUiProgram` constructor-export check, and the UI partial-token scan. Only
`runtime-noninterference` carries no id, because it is a runtime property this pure register cannot reach. The
network observer is normalized to the sanctioned pair as in Phase 14, so a host proving isolation by the other
route still passes.

**Invalidated historical record:**

✅ Done. The closed Dhall wire, total structural checker, independent oracles, generated coverage, constructor
seal, and all six mutants pass. Browser, UI-server, identity-provider, and storage-provider enforcement remain
UNVERIFIED. See the Phase-16 ledger.

## Phase Summary

This phase implements one admission seam: normalized Dhall `UiSource` decodes to a closed wire value and a
total Haskell checker validates module identities, references, types, bounded graphs, routes, state/event
tables, exhaustive branches, public-value projections, and deterministic composition before sealing a
constructor-private `CheckedUiProgram`. Raw JavaScript, HTML, CSS, URLs, provider coordinates, recursive
effects, unbounded collections, and caller-authored authority have no source constructor.

The result reifies the client-safe value universe and structural graph consumed by later scope,
authorization, binding, and runtime phases. This phase does not bind a handler, evaluate authorization, emit
runtime plans, or interpret an effect.

**Session scope:** one `UiSource` wire schema and its total structural checker; acceptance command
`cabal test ui-program-schema-spec`; split immediately if work requires scoped authorization, effect binding,
plan emission, a browser/server interpreter, a second register, or a substrate.
**Dependency:** Phase 15 — the pre-cluster design band and deterministic test substrate are available; this
gate itself is pure and does not consume simulated effects.
**Substrate:** none — no host, browser, network, credential, provider service, or cluster is contacted.
**Register:** 1 — pure/golden.
**Gate:** `python3 tools/phase16_gate.py` passes the Phase-0 corpus, structural and
wire oracles, coverage floors, constructor compile seal, network observer, six explicit mutant-red runs, and
ledger check.

## Gate integrity

Phase 0 commits every fixture, expected result, diagnostic tag/span, and reference table below before the
`Amoebius.Ui` schema or checker exists. The test may parse those pins but may not regenerate them from the
checker under test.

- **Representative set:** `minimal_single_tenant.dhall`, `minimal_multi_tenant.dhall`, and
  `composed_workflow_ui.dhall` cover every source union arm, qualified module import, route, state/event/value
  type, bounded collection, branch table, typed port declaration, named external-link requirement, and public
  projection.
- **Pinned negatives:** `raw_browser_escape.dhall`, `recursive_effect.dhall`,
  `unbounded_collection.dhall`, `duplicate_qualified_id.dhall`, `missing_reference.dhall`,
  `raw_external_link_url.dhall`, `duplicate_external_link_requirement.dhall`,
  `port_type_mismatch.dhall`, `non_exhaustive_event.dhall`, and `private_value_projection.dhall` each differ
  from a positive twin only in the named illegal dimension and assert a committed Gate-1 or `UiCheckError`
  tag plus source span.
- **Pinned oracles:** `test/fixtures/ui_program_schema/cases.tsv` owns accept/reject and diagnostic outcomes;
  `normalized_wire.golden` owns the canonical decoded wire shape; and `graph_reference.tsv` explicitly lists
  the expected qualified nodes, edges, types, and exhaustive event coverage for the three positives.
- **Independent predicates:** the reference reader performs a finite table/graph comparison without importing
  production normalization, lookup, type-unification, graph-walk, or exhaustiveness helpers. Goldens are
  hand-authored from the doctrine and fixtures, never refreshed from observed output.
- **Generator coverage:** QuickCheck classifies every source arm and forces duplicate, missing, cyclic,
  ill-typed, over-bound, non-exhaustive, and private-projection rejection classes to at least 5% each.
- **Effect discipline:** fresh challenges, authority credentials, and OS-boundary effect observers are not
  applicable to this Register-1 gate. The process runs with network unavailable and credential variables
  scrubbed; the ledger says “spec-composition proven,” never “runtime proven.”
- **Seeded mutants:** `add_raw_js_arm` and `add_raw_url_arm` (union-arm additions), `M-drop-bound-check` (guard weakening),
  `M-first-id-wins` (duplicate collapse), `M-skip-exhaustiveness` (invariant-clause delete), and
  `M-swap-port-contract` (effect/type swap) are committed and must each turn a distinct pinned case red.

Passing proves that the checked corpus has the intended closed structure and sampled properties. It does not
prove browser safety, authorization truth, handler correctness, tenant isolation at a provider, or runtime
noninterference.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §4 — the authored Dhall surface](../documents/engineering/low_code_ui_runtime_doctrine.md#4-the-authored-dhall-surface): `UiSource` is bounded data with no raw browser or network language.
- [`low_code_ui_runtime_doctrine.md` §5 — Gate 2 and the checked Haskell IR](../documents/engineering/low_code_ui_runtime_doctrine.md#5-gate-2-and-the-checked-haskell-ir): the checker is total and `CheckedUiProgram` has a private constructor.
- [`low_code_ui_runtime_doctrine.md` §6 — modules and total composition](../documents/engineering/low_code_ui_runtime_doctrine.md#6-modules-and-total-composition): qualified identities and deterministic graph merge replace textual inclusion.
- [`low_code_ui_runtime_doctrine.md` §7 — state, events, and deterministic updates](../documents/engineering/low_code_ui_runtime_doctrine.md#7-state-events-and-deterministic-updates): closed state/event tables are bounded and exhaustive.
- [`dsl_doctrine.md` §2 — Dhall carries params, Haskell carries logic](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic) and [`§5 — illegal-state-unrepresentable contract`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract): UI source enters through the existing Gate-1/Gate-2 discipline.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 16.1: Bounded `UiSource` and total structural checker ✅

**Status**: Done — the capability is re-established by the migrated gate; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**: `dhall/amoebius/ui/`, `src/Amoebius/Ui/{Source,Check}.hs`, and
`test/ui/Phase16UiProgramSchemaSpec.hs` — built and validated.
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: the suite reads the Phase-0 decisions and independent graph/wire tables. Three
positives and ten exact negatives pass, eight generated classes meet their floors, and all six mutants fail.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/engineering/dsl_doctrine.md`,
`documents/engineering/generated_artifacts_doctrine.md`

### Objective

Adopt the low-code UI source and checking boundary: make executable escape hatches absent, reject every
malformed or semantically incomplete graph with a stable diagnostic, and expose only a sealed checked value to
later phases.

### Deliverables

- Closed normalized Dhall records/unions, smart-constructor prelude, wire decoder, and canonical module merge.
- Private `CheckedUiProgram` plus total reference, type, bounds, graph, branch, and projection checks.
- Phase-0 corpus readers, independent reference-table comparator, round-trip properties, coverage floors,
  mutant configurations, and a Register-1 honesty ledger.

### Validation

1. Run `cabal test ui-program-schema-spec`; all positive programs normalize/decode/check identically and every
   negative rejects at its pinned layer, tag, and span.
2. Confirm every generated module/event/route/port obligation joins the independent reference tables and no
   expected outcome is generated from the subject.
3. Run `add_raw_js_arm`, `add_raw_url_arm`, `M-drop-bound-check`, `M-first-id-wins`, `M-skip-exhaustiveness`, and
   `M-swap-port-contract`; every mutant turns a distinct pin red.
4. Verify the gate makes no network or credential access and its ledger leaves browser/server/provider claims
   UNVERIFIED.

### Remaining Work

Done. All runtime-enforcement layers remain UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record Gate-1/Gate-2 schema evidence without
  claiming runtime enforcement.
- `documents/engineering/dsl_doctrine.md` — record the checked `UiSource` specialization of the general DSL.
- `documents/engineering/generated_artifacts_doctrine.md` — record generated wire/coverage artifacts while
  retaining the never-commit rule.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, `none` substrate, gate, and target modules.
- Phase 17 — consume only the sealed program and reified public-value universe.

## Related Documents

- [Development Plan Standards](development_plan_standards.md) — one-session scope, Register-1 honesty, and gate integrity.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — the source algebra and checked IR implemented here.
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — the shared Dhall/Haskell admission discipline.
- [Illegal-State Techniques](../documents/illegal_state/illegal_state_techniques.md) — closed sums, private constructors, bounded values, and total folds.
