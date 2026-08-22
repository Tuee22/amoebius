# Phase 38: UI authorization kernel

> **Purpose**: Make one sealed action registry and current-authority transition decide whether a scoped UI
> action may produce an effect.
> **Read this if**: action declarations, client/server projection parity, authorization freshness, or the
> `AuthorizedAction` boundary has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 38.1: Sealed registry and parity ⏸️](#sprint-381-sealed-registry-and-parity-)
- [Sprint 38.2: Current-authority decision and negative controls ⏸️](#sprint-382-current-authority-decision-and-negative-controls-)
- [Sprint 38.3: Calculus projection and phase seal ⏸️](#sprint-383-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 37, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** Five Haskell `ActionSpec` values are to form a sealed
`BoundActionRegistry`. Each action fixes its closed effect arm,
permission, presentation visibility, and idempotence bit. Client and server projections come from that same
registry and must match a separately reviewed Haskell projection. Missing, unexpected, duplicate, and
equal-cardinality permission-swapped registries retain distinct refusal constructors. Any serialized case or
mutation is generated lazily beneath `.build/**`.

The target authorization function combines the sealed registry, a scoped request context, subject/tenant ownership, requested
permission, and an `AuthoritySnapshot`. The snapshot and presented authority must agree on policy,
membership, grant, and scope epochs. Only a current, matching decision creates private `CanRead`/`CanInvoke`
witnesses inside a constructor-private `AuthorizedAction`; the pure effect interpreter accepts no weaker
input. Client visibility never enters the authorization predicate.

**Phase scope:** one target claim — presentation, client/server declaration, modeled current policy, request scope,
and effect admission have one pure decision boundary. Live identity truth, HTTP routing, handler binding,
provider policy, or tenant-isolation observation splits out.

**Substrate:** `none` — registry construction, reference evaluation, Haskell properties, epoch replay, and
calculus composition are pure; the canonical Haskell gate has no credentials or network
([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** `none` ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 1 — pure Haskell/generative: separately reviewed Haskell rows and paired controls constrain the decision
relation; identity-provider truth and runtime/provider enforcement remain UNVERIFIED
([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 37](phase_37_ui_program_schema.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 38`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target only — Haskell presentation, declaration, policy-snapshot, request-scope, and effect-admission values meet at one pure decision boundary; any serialized case or mutation is generated beneath `.build/**`. Live identity, HTTP, providers, and tenant enforcement are not claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 38` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 37 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6):
  claimed identity, request scope, exact permissions, and current authority remain distinct inputs.
- [`low_code_ui_runtime_doctrine.md` §8 — Effects are typed ports, not network operations](../documents/engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations):
  the registry owns action/effect meaning and the interpreter consumes only authorization evidence.
- [`low_code_ui_runtime_doctrine.md` §9 — Routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge):
  presentation never grants authority and stale decisions cannot execute.
- [`illegal_state_security.md` §3.79 — A UI action whose server authorization does not match its declaration](../documents/illegal_state/illegal_state_security.md#379-a-ui-action-whose-server-authorization-does-not-match-its-declaration):
  default-deny and visibility independence remain explicit negative controls.

---

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 38.1: Sealed registry and parity ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt one closed action registry as the source for presentation, server dispatch, permission, and audit
identity.

### Deliverables

- Five closed action/effect declarations and three closed permission arms.
- Seven private identifiers, registries, snapshots, actions, and witnesses.
- Equal client/server projections and four exact registry-parity refusals.

### Validation

1. Both production projections equal the independently parsed five-row table.
2. Missing, extra, duplicate, and swapped-permission registries fail distinctly.
3. Closed-union and constructor-export scans match every owned type.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 38.2: Current-authority decision and negative controls ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt one current-authority transition whose successful result is the only representable input to the effect
interpreter.

### Deliverables

- A total authorization transition over registry, policy, scope, owner, permission, and four epochs.
- Hidden-but-invocable and visible-but-unauthorized canaries plus empty denial traces.
- Nine generated coverage classes and two paired semantic mutants.

### Validation

1. All six matrix decisions agree with the independent evaluator and pinned verdict.
2. Each single-epoch replay fails with its own constructor before an effect is recorded.
3. Both mutants redden at their exact authored loci.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 38.3: Calculus projection and phase seal ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Seal the pure authorization claim with current calculus, architecture, surface, containment, and attestation
evidence.

### Deliverables

- A real five-calculus composition over the phase's bounded sets.
- Linux and Darwin network-denial observers plus a natural-architecture declaration.
- A complete surface/ledger join with live identity/provider residues retained as UNVERIFIED.

### Validation

1. Calculus order, names, counts, and resource vector match the authored table.
2. Normal and isolated runs pass and both explicit mutant processes fail exactly.
3. All universal gate sides pass without changing an authored path.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

---

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record pure registry/current-authority evidence
  without claiming live enforcement.
- `documents/illegal_state/illegal_state_security.md` — attach the exact default-deny, visibility, and stale
  controls.
- `documents/engineering/testing_doctrine.md` — record the independent authorization-reference pattern.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — record the seal and honest live residues.

---

## Related Documents

- [Development Plan Tracker](README.md) — phase order and current status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, register honesty, and gate integrity.
- [Phase 8](phase_08_scope_index.md) — trusted scoped identity.
- [Phase 10](phase_10_calculus_composition.md) — five-calculus composition.
- [Phase 37](phase_37_ui_program_schema.md) — checked program admission.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — action ownership and authorization freshness.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — independent authored expectations.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — authorization-parity and visibility-bypass failures.
