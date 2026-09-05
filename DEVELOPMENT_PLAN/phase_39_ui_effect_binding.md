# Phase 39: UI effect binding

> **Purpose**: Bind every checked UI port and named external link to exactly one trusted, compatible catalog
> entry before exposing a constructor-private `BoundUiProgram`.
> **Read this if**: the port/handler/capability relation, fixed-HTTPS link catalog, or `BoundUiProgram`
> boundary has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, documents/engineering/service_capability_doctrine.md, documents/illegal_state/illegal_state_capability_messaging.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 39.1: Exact port and capability binding](#sprint-391-exact-port-and-capability-binding-)
- [Sprint 39.2: Trusted links and negative controls](#sprint-392-trusted-links-and-negative-controls-)
- [Sprint 39.3: Calculus projection and phase seal](#sprint-393-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 38, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

## Phase Summary

**Target capability — NOT VALIDATED.** Seven Haskell `PortRequirement` values are to span data read/write,
workflow start/observation, subscription, bounded upload,
and ready-artifact use. Binding exact-joins each port to one trusted handler, public request/response codecs,
semantic capability, scope requirement, retry contract, and audit class. Missing, duplicate, unexpected,
contract-mismatched, scope-mismatched, capability-less, unsafe-retry, unbounded, and unready inputs retain
distinct refusals and no partial effect trace.

Two target `ExternalLinkId` requirements exact-join a separate trusted catalog. Only canonical, lowercase,
userinfo-free, wildcard-free, caller-template-free HTTPS entries enter the private `BoundExternalLinks` value.
A named link cannot be interpreted as effect transport, and a provider coordinate cannot enter `PortEffect`.

**Phase scope:** one target claim — a checked UI requirement cannot become a `BoundUiProgram` until every
port and external link has exactly one compatible trusted binding. Plan compilation and runtime effects split
out.

**Substrate:** `none` — finite relations, Haskell properties, calculus composition, and generated mutations are
pure; the canonical Haskell gate has no credentials or network.

**Lane:** `none` ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 1 — pure Haskell/generative: separately authored Haskell tables constrain the binding relation; handler
implementation, provider state, browser enforcement, and live tenant isolation remain UNVERIFIED.

**Depends on:** [Phase 38](phase_38_ui_authorization_kernel.md)
**Gate:** `pb validate phase 39`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `pure-exact-ui-effect-binding` |
| `Subject` | `acquired-ui-effect-binding-supervisor` |
| `Command` | `pb validate phase 39` (future public spelling); the pre-handoff gate directly executes the exact source-bound Haskell supervisor and its offline serial matrix. |
| `Oracle` | `independent-ui-effect-binding-oracle` |
| `Positive controls` | `ui-effect-binding-positive-controls` |
| `Paired negatives` | `exact-ui-effect-binding-paired-negatives` |
| `Mutants` | `applied-ui-effect-binding-production-mutants` |
| `Discovery` | `exact-ui-effect-binding-source-discovery` |
| `Challenge` | `post-acquisition-ui-effect-binding-challenge` |
| `Observer` | `ui-effect-binding-process-observation` |
| `Authority/bypass` | `no-pb-network-provider-browser-host-hardware-or-parallelism` |
| `Freshness` | `fresh-ui-effect-binding-build-root-and-stable-source` |
| `Qualification` | `qualified-ui-effect-binding-harness` |
| `Cleanroom` | `ui-effect-binding-products-contained-below-build` |
| `Legacy closure` | `retired-ui-effect-binding-authorities-absent` |
| `Predecessor` | `exact-phase-thirty-eight-receipt` |
| `Residue` | `ui-plan-runtime-and-provider-owners-explicit` |
| `Pass criterion` | `qualified-phase-thirty-nine-gate-pass` |

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §4.4 — External links are names resolved by a trusted catalog](../documents/engineering/low_code_ui_runtime_doctrine.md#44-external-links-are-names-resolved-by-a-trusted-catalog): named requirements exact-join the fixed-HTTPS catalog.
- [`low_code_ui_runtime_doctrine.md` §8 — Effects are typed ports, not network operations](../documents/engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations): semantic effects bind through one sealed server-side relation.
- [`service_capability_doctrine.md` §2 — The capability set](../documents/engineering/service_capability_doctrine.md#2-the-capability-set): ports name semantic capabilities rather than provider coordinates.
- [`low_code_ui_workflow_lifting.md` §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux): workflow and ready-artifact handles bind through the same port relation.
- [`illegal_state_capability_messaging.md` §3.82 — A browser effect or provider call escaping the server-mediated capability boundary](../documents/illegal_state/illegal_state_capability_messaging.md#382-a-browser-effect-or-provider-call-escaping-the-server-mediated-capability-boundary): raw browser/provider escape arms remain absent.

---

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 39.1: Exact port and capability binding ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/{Bind,ExternalLinkCatalog}.hs`, `test/spec/ui/{EffectBindingCases,UiEffectBindingSpec,EffectBindingReference}.hs`, and the package-hidden Phase-39 supervisor own this sprint surface.
**Blocked by**: [Phase 38](phase_38_ui_authorization_kernel.md) gate pass
**Independent Validation**: one clean Haskell semantic suite and seven production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/ui/EffectBindingReference.hs` independently evaluates the seven port relations and two fixed-HTTPS link relations without importing production or the typed case module.
**Legacy IDs**: Phase-local closure covers the retired Python gate, ten serialized oracle/fixture tables, and seven materialized mutant descriptors.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked UI/capability/illegal-state doctrines.

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

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 39.2: Trusted links and negative controls ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/{Bind,ExternalLinkCatalog}.hs`, `test/spec/ui/{EffectBindingCases,UiEffectBindingSpec,EffectBindingReference}.hs`, and the package-hidden Phase-39 supervisor own this sprint surface.
**Blocked by**: Sprint 39.1
**Independent Validation**: one clean Haskell semantic suite and seven production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/ui/EffectBindingReference.hs` independently evaluates the seven port relations and two fixed-HTTPS link relations without importing production or the typed case module.
**Legacy IDs**: Phase-local closure covers the retired Python gate, ten serialized oracle/fixture tables, and seven materialized mutant descriptors.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked UI/capability/illegal-state doctrines.

### Objective

Keep navigation names separate from effect transport and provider coordinates.

### Deliverables

- Exact named-link catalog parity and canonical fixed-HTTPS validation.
- Nineteen binding/link/bounded-input refusals.
- Seven paired Haskell quantifier, guard, type, invariant, and escape changed-subject mutants.

### Validation

1. Both link projections equal the independent relation.
2. Every binding/link/bounded refusal retains its exact tag before a trace exists.
3. Every Haskell-authored changed-subject mutant exits red and reports only its declared locus; any external
   mutant form is generated lazily beneath `.build/**`.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 39.3: Calculus projection and phase seal ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/{Bind,ExternalLinkCatalog}.hs`, `test/spec/ui/{EffectBindingCases,UiEffectBindingSpec,EffectBindingReference}.hs`, and the package-hidden Phase-39 supervisor own this sprint surface.
**Blocked by**: Sprint 39.2
**Independent Validation**: one clean Haskell semantic suite and seven production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/ui/EffectBindingReference.hs` independently evaluates the seven port relations and two fixed-HTTPS link relations without importing production or the typed case module.
**Legacy IDs**: Phase-local closure covers the retired Python gate, ten serialized oracle/fixture tables, and seven materialized mutant descriptors.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked UI/capability/illegal-state doctrines.

### Objective

Seal the pure binding claim with current calculus, architecture, surface, containment, and exact run observations.

### Deliverables

- A real five-calculus composition over the phase's bounded sets.
- Linux and Darwin network-denial observers plus a natural-architecture declaration.
- A complete surface/ledger join with live runtime/provider residues retained as UNVERIFIED.

### Validation

1. The authored calculus rows fix the five-kind order, component names, count vector, and resource sum.
2. Ordinary and Darwin-denied executions accept; seven isolated Haskell changed-subject mutant executions
   report their exact loci.
3. Architecture, surfaces, ledger, containment, write guard, and exact run binding all close on the same run.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

---

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — pure exact binding and honest live residues.
- `documents/engineering/service_capability_doctrine.md` — semantic capability consumer evidence.
- `documents/illegal_state/illegal_state_capability_messaging.md` — exact escape controls and Haskell
  changed-subject mutants.

**Cross-references to add:**

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
