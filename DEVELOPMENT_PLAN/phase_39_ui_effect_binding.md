# Phase 39: UI effect binding

> **Purpose**: Bind every checked UI port and named external link to exactly one trusted, compatible catalog
> entry before exposing a constructor-private `BoundUiProgram`.
> **Read this if**: the port/handler/capability relation, fixed-HTTPS link catalog, or `BoundUiProgram`
> boundary has to change.

This phase owns the pure binding decision between checked requirements and trusted catalogs. It does not
compile client/server plans, dispatch handlers, authenticate a request, contact a provider, or prove live
tenant isolation. Those effects belong to later phases.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/illegal_state/illegal_state_capability_messaging.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 39.1: Exact port and capability binding ✅](#sprint-391-exact-port-and-capability-binding-)
- [Sprint 39.2: Trusted links and negative controls ✅](#sprint-392-trusted-links-and-negative-controls-)
- [Sprint 39.3: Calculus projection and phase seal ✅](#sprint-393-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. The complete twelve-sided gate passes on natural `darwin/arm64`, untranslated.
Seven ports exact-join their handlers, codecs, capabilities, scopes, retry rules, and audit classes; two named
links resolve to canonical fixed-HTTPS entries. Eight binding errors, eight link errors, three bounded-input
errors, thirteen generated classes, and all seven paired mutants pass. The real five-calculus composition
projects counts `7,2,19,13,7` to resource vector `5,48,0,0`. All 16 metrics match and 61 surfaces join to 91
enumerated items. Attestation `sha256:6466f549d0a079b773a86cda14acc2625c45fd3161bfa19d3444786c092f8b4a`
binds source `sha256:a9a2fe607e95c82e…` over 2,262 files.

**Activated 2026-08-21** when Phase 38 sealed. The generative re-baseline invalidated the earlier result because
it had no calculus projection or natural-architecture record.

---

## Phase Summary

Seven `PortRequirement` values span data read/write, workflow start/observation, subscription, bounded upload,
and ready-artifact use. Binding exact-joins each port to one trusted handler, public request/response codecs,
semantic capability, scope requirement, retry contract, and audit class. Missing, duplicate, unexpected,
contract-mismatched, scope-mismatched, capability-less, unsafe-retry, unbounded, and unready inputs retain
distinct refusals and no partial effect trace.

Two `ExternalLinkId` requirements exact-join a separate trusted catalog. Only canonical, lowercase,
userinfo-free, wildcard-free, caller-template-free HTTPS entries enter the private `BoundExternalLinks` value.
A named link cannot be interpreted as effect transport, and a provider coordinate cannot enter `PortEffect`.

**Phase scope:** one cohesive claim — a checked UI requirement cannot become a `BoundUiProgram` until every
port and external link has exactly one compatible trusted binding. Plan compilation and runtime effects split
out.

**Substrate:** `none` — the finite relations, generated properties, calculus composition, and mutants are pure
host processes with credentials scrubbed and networking denied.

**Lane:** `none` ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 1 — pure/generative: independently authored tables constrain the binding relation; handler
implementation, provider state, browser enforcement, and live tenant isolation remain UNVERIFIED.

**Depends on:** [Phase 10](phase_10_calculus_composition.md) — actual five-calculus composition; [Phase
38](phase_38_ui_authorization_kernel.md) — the sealed action registry carried into the bound program.

**Gate:** `python3 tools/run_phase_gate.py 39` passes the exact binding/link independent oracle, refusal,
generated-coverage, five-calculus, paired-mutant, network-observer, natural-architecture, surface, containment,
and attestation checks in [Gate integrity](#gate-integrity).

---

## Gate integrity

`ports.tsv`, `handlers.tsv`, `capabilities.tsv`, and `expected_bindings.tsv` are separate authored relations.
The Haskell suite builds production values and compares their normalized projection with
`EffectBindingReference`, which imports neither production binder. Handler and capability key sets are checked
both ways, including duplicates, so equal-cardinality swaps cannot pass by count.

The seven effect arms are enumerably closed. Six private identifiers and sealed values remain
constructor-private. Source checks reject partial tokens and raw coordinates in `PortRequirement`; project
totality warnings keep later closed-sum growth visible in the suite.

Eight pinned binding failures leave an empty pure trace. Eight external-link defects and three bounded-input
defects retain distinct tags. Thirteen QuickCheck classes cover all seven effects and six central refusal
classes at a 5% floor.

Each mutant runs in its own process and must report its exact locus: duplicate-handler quantifier weakening,
missing capability, erased scope guard, swapped response codec, missing idempotency, raw provider topic, or
external-link-as-effect. A generic non-zero exit is insufficient.

Artifact, budget, lift, workflow, and evidence components carry the `7,2,19,13,7`
port/link/refusal/property/mutant counts and compose to resource vector `5,48,0,0`. Normal and Darwin
network-denied executions must report both calculus and binding tokens. Generated records remain beneath
`.build/**`.

Passing proves the pure closed binding relation for this bounded corpus. Browser traffic, handler behavior,
provider authentication/state, and live tenant isolation remain UNVERIFIED.

- **Extension conformance (§M.13).** Not applicable. This core UI binder has no extension declaration or
  linked set to judge.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §4.4 — external links are trusted names](../documents/engineering/low_code_ui_runtime_doctrine.md#44-external-links-are-names-resolved-by-a-trusted-catalog): named requirements exact-join the fixed-HTTPS catalog.
- [`low_code_ui_runtime_doctrine.md` §8 — effects are typed ports](../documents/engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations): semantic effects bind through one sealed server-side relation.
- [`service_capability_doctrine.md` §2 — capability set](../documents/engineering/service_capability_doctrine.md#2-the-capability-set): ports name semantic capabilities rather than provider coordinates.
- [`low_code_ui_workflow_lifting.md` §12 — workflow and artifact lifting](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux): workflow and ready-artifact handles bind through the same port relation.
- [`illegal_state_capability_messaging.md` §3.82](../documents/illegal_state/illegal_state_capability_messaging.md#382-a-browser-effect-or-provider-call-escaping-the-server-mediated-capability-boundary): raw browser/provider escape arms remain absent.

---

## Sprints

## Sprint 39.1: Exact port and capability binding ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Bind.hs`, `test/fixture/ui_effect_binding/{ports,handlers,capabilities,expected_bindings}.tsv`, `test/spec/ui/EffectBindingReference.hs`
**Blocked by**: [Phase 38](phase_38_ui_authorization_kernel.md) gate
**Independent Validation**: seven normalized production bindings equal both the authored expectation and the independent finite join; handler/capability keys agree exactly
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/engineering/service_capability_doctrine.md`

### Objective

Adopt one exact relation whose only successful result is a constructor-private `BoundUiProgram`.

### Deliverables

- Seven closed effect requirements and their exact handler/capability/contract tuples.
- Six constructor-private identifiers and bound values.
- Exact key-set parity, empty refusal traces, and generated coverage floors.

### Validation

1. All seven bindings agree with the authored table and independent relation.
2. Missing, duplicate, unexpected, mismatched, unbounded, and unready cases fail distinctly.
3. Closed-union, constructor-export, partial-token, and totality checks pass.

### Remaining Work

None.

## Sprint 39.2: Trusted links and negative controls ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/ExternalLinkCatalog.hs`, `test/fixture/ui_effect_binding/{external_link_catalog,expected_external_links,bind_errors}.tsv`, `test/mutant/ui_effect_binding/**`
**Blocked by**: Sprint 39.1
**Independent Validation**: two names exact-join canonical fixed-HTTPS entries; nineteen distinct refusals and seven exact mutant loci pass
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/illegal_state/illegal_state_capability_messaging.md`

### Objective

Keep navigation names separate from effect transport and provider coordinates.

### Deliverables

- Exact named-link catalog parity and canonical fixed-HTTPS validation.
- Nineteen binding/link/bounded-input refusals.
- Seven paired quantifier, guard, type, invariant, and escape mutants.

### Validation

1. Both link projections equal the independent relation.
2. Every binding/link/bounded refusal retains its exact tag before a trace exists.
3. Every mutant exits red and reports only its authored locus.

### Remaining Work

None.

## Sprint 39.3: Calculus projection and phase seal ✅

**Status**: Done
**Implementation**: `test/oracle/ui_effect_binding/{calculus_projection,validation_locus}.tsv`, `test/oracle/ui_effect_binding_surfaces.tsv`, `tools/ui_effect_binding_gate.py`
**Blocked by**: Sprint 39.2
**Independent Validation**: real five-calculus values match all four projection rows; normal and Darwin network-denied suite executions report both acceptance tokens
**Docs to update**: `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, `DEVELOPMENT_PLAN/system_components.md`

### Objective

Seal the pure binding claim with current calculus, architecture, surface, containment, and attestation evidence.

### Deliverables

- A real five-calculus composition over the phase's bounded sets.
- Linux and Darwin network-denial observers plus a natural-architecture declaration.
- A complete surface/ledger join with live runtime/provider residues retained as UNVERIFIED.

### Validation

1. The authored calculus rows fix the five-kind order, component names, count vector, and resource sum.
2. Ordinary and Darwin-denied executions accept; seven isolated mutant executions report their exact loci.
3. Architecture, surfaces, ledger, containment, write guard, and attestation all close on the same run.

### Remaining Work

None.

---

## Documentation Requirements

**Engineering docs updated with this seal:**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — pure exact binding and honest live residues.
- `documents/engineering/service_capability_doctrine.md` — semantic capability consumer evidence.
- `documents/illegal_state/illegal_state_capability_messaging.md` — exact escape controls and mutants.

**Cross-references updated:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — seal, substrate, gate, and owned modules.

---

## Related Documents

- [Development Plan Tracker](README.md) — phase order and current status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, register honesty, and gate integrity.
- [Phase 10](phase_10_calculus_composition.md) — five-calculus composition.
- [Phase 38](phase_38_ui_authorization_kernel.md) — sealed authorization registry.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — port and link binding ownership.
- [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) — semantic capabilities.
- [Illegal-State Capability/Messaging Slice](../documents/illegal_state/illegal_state_capability_messaging.md) — browser/provider escape foreclosure.
