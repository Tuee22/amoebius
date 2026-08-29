# Phase 68: Live subject/tenant isolation

> **Purpose**: Prove on live `linux-cpu` infrastructure that authenticated subject and tenant scope is injected
> by amoebius and enforced across SQL, object, and message data paths with zero foreign-scope effects.
> **Read this if**: phase 68 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, documents/engineering/tenancy_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 68.1: Live scoped request and provider-isolation gate ⏸️](#sprint-681-live-scoped-request-and-provider-isolation-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 67, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase targets one live seam: current Keycloak identity and the derived `TenantSpec` policy become the trusted
`RequestContext` consumed by scoped handlers and provider policies. A minimal bound server probe exercises
subject-owned and tenant-owned Postgres rows, MinIO objects, and Pulsar messages without exposing provider
coordinates or credentials to the caller. The phase tests enforcement, not a full browser UX; Phase 82 owns
multi-tenant UI scope switching.

**Phase scope:** one live request-context-to-provider isolation claim. The
`user-tenant-isolation-live` Haskell component suite can supply supporting observations only; the sole acceptance command is `pb
validate phase 68`. Split if a browser interaction, UI-plan rollout, HA failure, second substrate, or
independently useful provider feature is required.
**Substrate:** `linux-cpu` — future live cluster observation only after the Phase-49 barrier and every predecessor gate pass.
**Lane:** `linux-cpu/amd64`.
**Register:** 3 — live real-authority isolation; NOT VALIDATED.
**Depends on:** [Phase 67](phase_67_pulsar_client.md)
**Gate:** `pb validate phase 68`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *scope is injected by amoebius and enforced on every data path, with zero foreign-scope effects*. This is the first phase where the tenancy claim is made against live infrastructure. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 68` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 67; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

- One minimal same-binary server worker behind the Phase-64 Keycloak/Envoy edge, with a sealed action registry
  and no direct wild provider route.
- Two tenant policy projections, three subject memberships, one grant/revocation sequence, and isolated
  Postgres, MinIO, and Pulsar fixture resources with equal-shaped identifiers.
- Separate least-privilege SUT identities and read-only observer identities; no shared credential may serve both.
- Complete pod/image/slot/API/etcd/storage/message demand plus probe and observer envelopes admitted before the
  first realm, row, object, or topic mutation.

- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`, `S1`–`S6`; negatives under `.build/test-corpora/user_tenant_isolation_live/`.

## Doctrine adopted

- [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6) — live subject/tenant isolation carries an identity boundary, and S1-S6 are what make crossing it unrepresentable.
- [`tenancy_doctrine.md` §4 — The typed shapes: `TenantSpec` / `SubjectSpec` / `Membership` / `Owner` / `RoleBinding`](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--subjectspec--membership--owner--rolebinding) and [`tenancy_doctrine.md` §5 — RBAC is derived, never authored](../documents/engineering/tenancy_doctrine.md#5-rbac-is-derived-never-authored): live authority comes from the declared graph, not request fields.
- [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): every action is reauthorized server-side.
- [`low_code_ui_runtime_doctrine.md` §11 — data, forms, and storage](../documents/engineering/low_code_ui_runtime_doctrine.md#11-data-forms-and-storage): tenant/subject constraints are server-injected.
- [`illegal_state_security.md` §3.80 — A subject resolving or mutating another subject's resource without a grant](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant): the live paired matrix and mutants discharge its runtime residue.
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): fresh effects, real authority, and external observers are mandatory.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 68.1: Live scoped request and provider-isolation gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 67](phase_67_pulsar_client.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Connect authenticated identity to the Phase-8/27 scoped authorization values and test that provider effects
remain tenant- and subject-confined even when a hostile caller swaps identifiers, headers, handles, or grants.

### Deliverables

- The server-side adapter from verified Keycloak session plus current tenant policy to private
  `RequestContext tenant subject`; public request fields cannot construct or override it.
- Scoped SQL/object/message probe handlers using server-held capabilities and provider-derived predicates.
- The live authority fixture, runtime nonce protocol, provider state and request/audit observer clients,
  edge-response observer, CNI bypass probe, cleanup inventory, explicit mutant suite, and schema-checked
  Register-3 evidence ledger.

### Validation

1. Rejected historical observation: the `user-tenant-isolation-live` Cabal suite expected all allowed nonces
   to appear exactly once and all forbidden nonces
   remain absent across Postgres, MinIO, Pulsar, edge-response, and audit observations; denied reads also have
   no matching provider statement/request/delivery record.
2. Confirm same-tenant/foreign-subject, foreign-tenant, forged-header, swapped-handle, direct-provider, and
   post-revocation attempts return the pinned public denial without disclosing resource existence.
3. Run `drop_user_predicate` and `accept_body_tenant`; require a distinct matrix/observer failure for each.
4. Always tear down; authenticated provider and Kubernetes inventories return to their preflight sets, and the
   ledger records `linux-cpu`, Register 3, challenge hashes, authority source, and raw-observation digests.

### Remaining Work

None in this phase. Browser tenant switching is deliberately deferred to Phase 82. Cross-cluster isolation and
complete provider-audit-log correspondence remain `UNVERIFIED` and are not claimed by this single-cluster gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` and `documents/engineering/tenancy_doctrine.md`
  record the tested live request-context/provider-isolation residue.
- `documents/illegal_state/illegal_state_security.md` attaches §3.80's paired real-credential evidence.
- `documents/engineering/testing_doctrine.md` records the provider-side zero-effect observer instance.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the gate, `linux-cpu` substrate, and adapter ownership.
- `DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md` — consume this provider-isolation result unchanged.

## Related Documents

- [Phase 66](phase_66_app_tenancy.md) — tenant policy derivation and provider materialization.
- [Phase 67](phase_67_pulsar_client.md) — native authenticated message path used by this gate.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — trusted request-context and scoped data rules.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — live authority, challenge, observer, and teardown rules.
