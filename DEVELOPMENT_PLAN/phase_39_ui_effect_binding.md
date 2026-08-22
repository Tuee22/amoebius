# Phase 39: UI effect binding

> **Purpose**: Bind every checked UI port and named external link to exactly one trusted, compatible catalog
> entry before exposing a constructor-private `BoundUiProgram`.
> **Read this if**: the port/handler/capability relation, fixed-HTTPS link catalog, or `BoundUiProgram`
> boundary has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
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

Blocked by redesigned Phase 38, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

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

**Register:** 1 — pure Haskell/generative: separately reviewed Haskell tables constrain the binding relation; handler
implementation, provider state, browser enforcement, and live tenant isolation remain UNVERIFIED.

**Depends on:** [Phase 38](phase_38_ui_authorization_kernel.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 39`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target only — a Haskell checked UI requirement cannot become `BoundUiProgram` until every port and link has exactly one compatible trusted binding. Generated cases remain beneath `.build/**`; runtime effects are not claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 39` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | MISSING — blocks validation: the current Phase 38 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §4.4 — External links are names resolved by a trusted catalog](../documents/engineering/low_code_ui_runtime_doctrine.md#44-external-links-are-names-resolved-by-a-trusted-catalog): named requirements exact-join the fixed-HTTPS catalog.
- [`low_code_ui_runtime_doctrine.md` §8 — Effects are typed ports, not network operations](../documents/engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations): semantic effects bind through one sealed server-side relation.
- [`service_capability_doctrine.md` §2 — The capability set](../documents/engineering/service_capability_doctrine.md#2-the-capability-set): ports name semantic capabilities rather than provider coordinates.
- [`low_code_ui_workflow_lifting.md` §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux): workflow and ready-artifact handles bind through the same port relation.
- [`illegal_state_capability_messaging.md` §3.82 — A browser effect or provider call escaping the server-mediated capability boundary](../documents/illegal_state/illegal_state_capability_messaging.md#382-a-browser-effect-or-provider-call-escaping-the-server-mediated-capability-boundary): raw browser/provider escape arms remain absent.

---

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 39.1: Exact port and capability binding ⏸️

**Status**: Blocked — NOT VALIDATED

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 39.2: Trusted links and negative controls ⏸️

**Status**: Blocked — NOT VALIDATED

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 39.3: Calculus projection and phase seal ⏸️

**Status**: Blocked — NOT VALIDATED

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

---

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — pure exact binding and honest live residues.
- `documents/engineering/service_capability_doctrine.md` — semantic capability consumer evidence.
- `documents/illegal_state/illegal_state_capability_messaging.md` — exact escape controls and mutants.

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
