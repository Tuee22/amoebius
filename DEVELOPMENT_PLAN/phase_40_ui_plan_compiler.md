# Phase 40: UI plan compiler

> **Purpose**: Compile one sealed `BoundUiProgram` deterministically into matching immutable client, server,
> public-contract, content-manifest, digest, and finite-demand projections.
> **Read this if**: the paired-plan compiler, its canonical artifact boundary, or its Register-1 evidence has
> to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
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
- [Sprint 40.1: Paired semantic projection ⏸️](#sprint-401-paired-semantic-projection-)
- [Sprint 40.2: Canonical artifacts, digests, and demand ⏸️](#sprint-402-canonical-artifacts-digests-and-demand-)
- [Sprint 40.3: Calculus projection and phase seal ⏸️](#sprint-403-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 39, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** One private Haskell `BoundUiProgram` is to produce public client instructions, a serializable private server dispatch
manifest, public contracts, a content manifest, complete authority/content identities, and finite client/server
runtime demand together. Exact action, route, contract, audit, handler, and resolved-link projections cannot
drift between halves. Public output excludes private fields, handles, policies, provider coordinates, and raw
effect destinations.

The target compiler exposes no client-only or server-only entry point. Canonical ordering and encoding make repeated
fresh compilation stable, while changing or omitting an authority-bearing source changes the authority digest.
All serialized plans, manifests, cases, and mutations are generated lazily beneath `.build/**`. Separately
reviewed Haskell semantics, never repository-retained JSON or renderer-produced bytes, constrain the projection.

**Phase scope:** one target claim — one sealed Haskell program compiles purely and deterministically to one matching,
finite artifact set. Interpretation, publication, serving, and live freshness split out.

**Substrate:** `none` — compilation, reference comparison, calculus composition, and generated mutations are
pure; the canonical Haskell gate has no credentials or network.

**Lane:** `none` ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 1 — pure/semantic-oracle. Logical projection is independently constrained; interpreter fidelity, release
publication, edge enforcement, and live authority freshness remain UNVERIFIED.

**Depends on:** [Phase 39](phase_39_ui_effect_binding.md)
**Gate:** `pb validate phase 40`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — one sealed Haskell program compiles purely to a matching finite artifact set; serialized output and mutations are lazy `.build/**` products, not tracked authority. Interpretation and live freshness are not claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 40` is future public spelling only. Before current reviewer approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent reviewer have been accepted. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 39; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

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

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 40.1: Paired semantic projection ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 39](phase_39_ui_effect_binding.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 40.2: Canonical artifacts, digests, and demand ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 40.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The pre-reset serialized expectation paths are condemned historical inventory. Current work requires independently authored Haskell expectations and lazy untracked `.build/**` materializations.

## Sprint 40.3: Calculus projection and phase seal ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 40.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Seal the pure compiler claim with current calculus, architecture, surface, containment, and attestation
evidence.

### Deliverables

- A real five-calculus composition over the phase's observed sets.
- Six Haskell-authored paired changed-subject mutants with exact red tokens.
- A complete natural-architecture, surface, ledger, containment, write-guard, and attestation record.

### Validation

1. The authored calculus rows fix kind order, component names, count vector, and resource sum.
2. Ordinary and Darwin-denied executions accept; all six Haskell changed-subject mutant executions fail at
   their own loci.
3. All 17 metrics and the 61-surface/72-item join pass in the attested run.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

---

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

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
