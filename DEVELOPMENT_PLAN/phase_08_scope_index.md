# Phase 8: Scoped identity kernel

> **Purpose**: Specify the target Haskell capability to provide a constructor-private Haskell
> request-scope index and total information-flow relation that reject forging, retagging, widening,
> and cross-scope exchange.
> **Read this if**: Phase 8 is the open contract, or a later phase needs the type-level scope boundary it
> establishes.

This document binds the Phase-8 scoped-identity capability to its current Haskell subject, independent oracle,
serial compiler matrix, and durable evidence lifecycle. Current status is owned by [the tracker](README.md)
and the Phase Status block below; only the complete integrated gate may authorize a status transition.

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

✅ Done.

The complete Phase-7 gate is recorded as the verified immediate-predecessor frontier fact. Phase 8's complete
integrated gate authorized the recorded mechanical status projection.

## Phase Summary

This phase implements a constructor-private Haskell request-scope index and total
information-flow relation that reject forging, retagging, widening, and cross-scope exchange.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` is not used by this pre-`BOOTSTRAP_HANDOFF` gate. The source-bound Haskell dispatcher invokes the
authenticated compiler directly and synchronously.

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

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-8 semantic payload, package-hidden serial
supervisor, independent Haskell oracle, five compile-negative pairs, and changed-production subject are
complete; only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | The single rank-2 request-scope introduction, private identity/handle constructors, and total flow relation reject forging, retagging, owner swaps, widening, elevation, and malformed paths. |
| `Subject` | `Amoebius.Scope.{Index,Flow}` is acquired only through package-hidden `Amoebius.Validation.ScopeIndexRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 08`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly, synchronously, and without `-j`. |
| `Oracle` | `test/spec/ui/ScopeSpec.hs` contains separately authored owner, swap, flow, diagnostic, and nine-class Haskell expectations and observes only public production interfaces. |
| `Positive controls` | The clean oracle and all five legal compile twins succeed. |
| `Paired negatives` | Raw resource construction, scope retagging, declassification, scoped-handle escape, and request-scope forgery fail at separately pinned GHC reason/locus pairs. |
| `Mutants` | `SCOPE_INDEX_DROP_OWNER_EQUALITY_MUTANT` changes the production owner join and must admit both same-tenant and cross-tenant swaps while clean controls remain green. |
| `Discovery` | The two subject modules, Haskell oracle, and ten compile twins are discovered from the Git snapshot and equal the fixed thirteen-file inventory bidirectionally. |
| `Challenge` | The changed-production owner-equality subject runs after acquisition and must be distinguished by the exact two-swap observation. |
| `Observer` | The supervisor records absolute executable, exact argv, exit, transcript digest, and bounded failure text for every compiler and oracle process. |
| `Authority/bypass` | Constructor closure and pure-source scans pass; `pb`, network, hardware, live services, compiler substitution, and compiler/linker overlap are forbidden. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-08/work/**` root and the dispatcher requires equal opening/closing source identities. |
| `Qualification` | Clean controls, five exact negative pairs, source discipline, and the changed-production subject pass together; a survivor or wrong-locus result refuses. |
| `Cleanroom` | Every binary, interface, object, stub, and transcript is generated lazily beneath the fresh run root. |
| `Legacy closure` | Phase 8 owns no legacy-debt identifier; all non-circular prerequisites must pass while later-owned source debt remains residue. |
| `Predecessor` | Consume exactly one durable Phase-7 receipt for this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Persisted-value re-entry, resource indexing, five-calculus composition, effects, runtimes, hardware, and live services remain explicitly later-owned. |
| `Pass criterion` | `qualified-phase-eight-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

**This phase owns its compile-negative evidence.** Each illegal twin requires a phase-local source-bound GHC
invocation, a minimally different positive control, and a separately authored exact diagnostic expectation.
[Phase 15](phase_15_compile_fail_harness.md) later consolidates reusable machinery; it is not a prerequisite.

## Doctrine adopted

- [`extension_conformance_security.md` §3 — The skolem scope](../documents/engineering/extension_conformance_security.md#3-the-skolem-scope): a rank-2 eliminator mints one fresh request index and private constructors prevent a second introduction rule.
- [`low_code_ui_runtime_doctrine.md` §10.3 — Information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels): labels preserve subject audience and integrity across direct and transitive pure flows.
- [`tenancy_doctrine.md` §4 — The typed shapes: `TenantSpec` / `SubjectSpec` / `Membership` / `Owner` / `RoleBinding`](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--subjectspec--membership--owner--rolebinding): tenant, subject, membership, owner, and grant distinctions are constructor-private.
- [`illegal_state_security.md` §3.80 — A subject resolving or mutating another subject's resource without a grant](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant): paired owner and tenant swaps exercise exact denial reasons.
- [`illegal_state_security.md` §3.81 — A UI value flowing to an incompatible tenant, subject, or audience scope](../documents/illegal_state/illegal_state_security.md#381-a-ui-value-flowing-to-an-incompatible-tenant-subject-or-audience-scope): the finite flow relation and total graph diagnostics exercise the pure foreclosure layer.
- [`illegal_state_tenancy.md` §3.94 — Two same-typed scope identifiers exchangeable at a call site](../documents/illegal_state/illegal_state_tenancy.md#394-two-same-typed-scope-identifiers-exchangeable-at-a-call-site): distinct private identity types and the request skolem reject transposition and cross-scope reuse.

## Sprints

The sprint seam is bound to the same Haskell-only subject, oracle, and serial supervisor as the gate.

## Sprint 8.1: Rank-2 scope index and total flow checking ✅

**Status**: Done
**Implementation**: `src/Amoebius/Scope/{Index,Flow}.hs`; package-hidden supervisor `src/validation-kernel/Amoebius/Validation/ScopeIndexRun/Internal.hs`
**Blocked by**: [Phase 7](phase_07_evidence_calculus.md) gate pass
**Independent Validation**: six owner rows, two exact swap errors, four flow decisions, four exact diagnostics, nine generated reject classes, five exact compile-negative pairs, and one assigned changed-production subject
**Oracle**: `test/spec/ui/ScopeSpec.hs`, separately authored in Haskell against public scope modules
**Legacy IDs**: none; later-owned tracked-source debt remains in the typed central registry
**Docs to update**: this phase file plus the scoped-identity doctrine and illegal-state projections named below

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

Persisted-value re-entry deliberately remains absent because lexical scope indices are erased across storage and
message boundaries. Resource indexing, calculus composition, runtime authorization, provider enforcement, and
hardware observations remain assigned to their later phase owners.

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
