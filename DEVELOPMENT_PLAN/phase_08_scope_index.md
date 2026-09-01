# Phase 8: Scoped identity kernel

> **Purpose**: Specify the target Haskell capability to provide a constructor-private Haskell
> request-scope index and total information-flow relation that reject forging, retagging, widening,
> and cross-scope exchange.
> **Read this if**: Phase 8 is the open contract, or a later phase needs the type-level scope boundary it
> establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/extension_conformance_security.md, documents/engineering/tenancy_doctrine.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_tenancy.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 8.1: Rank-2 scope index and total flow checking](#sprint-81-rank-2-scope-index-and-total-flow-checking-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 7, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to provide a constructor-private Haskell request-scope index and total
information-flow relation that reject forging, retagging, widening, and cross-scope exchange.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — provide a constructor-private Haskell request-scope index
and total information-flow relation that reject forging, retagging, widening, and cross-scope
exchange. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 7](phase_07_evidence_calculus.md)
**Gate:** `pb validate phase 08`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target capability only — provide a constructor-private Haskell request-scope index and total information-flow relation that reject forging, retagging, widening, and cross-scope exchange. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 08` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 07; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- [`extension_conformance_security.md` §3 — The skolem scope](../documents/engineering/extension_conformance_security.md#3-the-skolem-scope): a rank-2 eliminator mints one fresh request index and private constructors prevent a second introduction rule.
- [`low_code_ui_runtime_doctrine.md` §10.3 — Information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels): labels preserve subject audience and integrity across direct and transitive pure flows.
- [`tenancy_doctrine.md` §4 — The typed shapes: `TenantSpec` / `SubjectSpec` / `Membership` / `Owner` / `RoleBinding`](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--subjectspec--membership--owner--rolebinding): tenant, subject, membership, owner, and grant distinctions are constructor-private.
- [`illegal_state_security.md` §3.80 — A subject resolving or mutating another subject's resource without a grant](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant): paired owner and tenant swaps exercise exact denial reasons.
- [`illegal_state_security.md` §3.81 — A UI value flowing to an incompatible tenant, subject, or audience scope](../documents/illegal_state/illegal_state_security.md#381-a-ui-value-flowing-to-an-incompatible-tenant-subject-or-audience-scope): the finite flow relation and total graph diagnostics exercise the pure foreclosure layer.
- [`illegal_state_tenancy.md` §3.94 — Two same-typed scope identifiers exchangeable at a call site](../documents/illegal_state/illegal_state_tenancy.md#394-two-same-typed-scope-identifiers-exchangeable-at-a-call-site): distinct private identity types and the request skolem reject transposition and cross-scope reuse.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 8.1: Rank-2 scope index and total flow checking ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 7](phase_07_evidence_calculus.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt [`extension_conformance_security.md` §3 — the skolem scope](../documents/engineering/extension_conformance_security.md#3-the-skolem-scope)
and [`low_code_ui_runtime_doctrine.md` §10.3 — information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels): make trusted scope introduction singular and every pure value flow explicit.

### Deliverables

- A constructor-private rank-2 request-scope index and scope-preserving value operations.
- Constructor-private tenant, subject, membership, owner, grant, resource, and resolved-handle types.
- Indexed flow labels and witnesses with a total direct and graph-path checker.
- Stable structured errors for owner, grant, subject-flow, audience, integrity, cycle, missing-member, missing-path, and transitive failures.
- Five checked `.hs` specific-reason compile-refusal cases, each paired with a legal `.hs` twin and a
  separately authored Haskell error-class/locus expectation.
- An independent Haskell finite corpus, nine-class generated coverage, and one checked Haskell mutation
  operator applied only beneath `.build/mutants/**`.
- A contained Register-1 gate with architecture, source-snapshot, ledger, surface-join, and artifact-hygiene evidence.

### Validation

1. Match all six owner rows, both exact swap errors, four flow decisions, and four exact flow diagnostic
   tag/path rows against separately authored Haskell expectations.
2. Compile every legal twin and require each illegal twin to fail at its pinned compiler reason.
3. Meet all nine QuickCheck reject-class floors and require `drop_owner_equality` to redden on both swaps.
4. Run the suite through an injected Haskell effect adapter that refuses every network request, scan the
   public API for twelve closed constructors and no retag/declassification escape, and reject partial or
   unsafe source tokens. No OS, host, socket, or hardware observation is admissible.
5. Join every enumerated item and surface, keep all outputs generated, bind the result to the natural
   architecture and source snapshot, and record provider/runtime layers as `UNVERIFIED`.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/extension_conformance_security.md` — record the delivered lexical skolem mechanism and retain the persisted-value re-entry residue.
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the pure label/index result without promoting live enforcement.
- `documents/engineering/tenancy_doctrine.md` — distinguish the pure request index from later provider isolation.
- `documents/engineering/testing_doctrine.md` — record the exact authored-expectation/generated-enumeration split.
- `documents/illegal_state/illegal_state_security.md` and `illegal_state_tenancy.md` — refresh the Phase-8 evidence at the type and pure-decision loci.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, and `system_components.md` — reconcile status, sequence, and concrete module paths.
- `DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md` — consume Phase 8 rather than present a reverse dependency.

## Related Documents

- [Development Plan Standards](development_plan_standards.md) — the phase shape and gate contract.
- [Development Plan Tracker](README.md) — numeric order and current status.
- [Evidence Calculus](phase_07_evidence_calculus.md) — the preceding claim-to-fixture boundary.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) — the authored-expectation and generated-enumeration split.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — the later UI consumer and information-flow rule.
- [Extension Security Laws](../documents/engineering/extension_conformance_security.md) — the shared skolem mechanism and its honest residue.
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md) — the authoritative tenant and subject model.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — foreign-resource and incompatible-flow states.
- [Illegal-State Tenancy Slice](../documents/illegal_state/illegal_state_tenancy.md) — run-time scope-index states.
