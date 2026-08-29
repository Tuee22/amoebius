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
- [Sprint 39.1: Exact port and capability binding ⏸️](#sprint-391-exact-port-and-capability-binding-)
- [Sprint 39.2: Trusted links and negative controls ⏸️](#sprint-392-trusted-links-and-negative-controls-)
- [Sprint 39.3: Calculus projection and phase seal ⏸️](#sprint-393-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 38, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

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
**Gate:** `pb validate phase 39`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target only — a Haskell checked UI requirement cannot become `BoundUiProgram` until every port and link has exactly one compatible trusted binding. Generated cases remain beneath `.build/**`; runtime effects are not claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 39` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance have been established. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not yet been demonstrated by a passing gate for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not yet been demonstrated by a passing gate. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not yet been demonstrated by a passing gate. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a checked pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or checked non-applicability have not yet been demonstrated by a passing gate. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 38; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §4.4 — External links are names resolved by a trusted catalog](../documents/engineering/low_code_ui_runtime_doctrine.md#44-external-links-are-names-resolved-by-a-trusted-catalog): named requirements exact-join the fixed-HTTPS catalog.
- [`low_code_ui_runtime_doctrine.md` §8 — Effects are typed ports, not network operations](../documents/engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations): semantic effects bind through one sealed server-side relation.
- [`service_capability_doctrine.md` §2 — The capability set](../documents/engineering/service_capability_doctrine.md#2-the-capability-set): ports name semantic capabilities rather than provider coordinates.
- [`low_code_ui_workflow_lifting.md` §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux): workflow and ready-artifact handles bind through the same port relation.
- [`illegal_state_capability_messaging.md` §3.82 — A browser effect or provider call escaping the server-mediated capability boundary](../documents/illegal_state/illegal_state_capability_messaging.md#382-a-browser-effect-or-provider-call-escaping-the-server-mediated-capability-boundary): raw browser/provider escape arms remain absent.

---

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 39.1: Exact port and capability binding ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 38](phase_38_ui_authorization_kernel.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

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

## Sprint 39.2: Trusted links and negative controls ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 39.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

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

## Sprint 39.3: Calculus projection and phase seal ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 39.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

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
