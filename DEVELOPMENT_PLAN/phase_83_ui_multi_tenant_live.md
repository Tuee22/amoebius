# Phase 83: Multi-tenant low-code UI isolation

> **Purpose**: Prove a multi-tenant low-code UI live through Keycloak/Envoy, including opaque scope selection,
> epoch rotation, stale-handle refusal, server-side authorization, and zero cross-tenant effects.
> **Read this if**: phase 83 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_84_ui_rollout_reconnect.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 83.1: Live opaque tenant switching and stale-scope refusal ⏸️](#sprint-831-live-opaque-tenant-switching-and-stale-scope-refusal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 82, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-50 barrier is invalidated and non-operative.

## Phase Summary

This phase targets one vertical seam: the generic browser and same-origin UI server perform an authenticated
multi-tenant scope change using opaque `TenantChoiceHandle`s. A successful change rotates the server scope
epoch, clears tenant state, invalidates handles and in-flight work, and reloads routes and authorization
projections. Every subsequent action is resolved and authorized against current server truth; control visibility
remains advisory.
The scope epoch also keys WebSocket registrations, routed frames, Redis presence, and resume cursors. A scope
change closes the old connection/registration before the new scope becomes routable; no Redis key or frame may
retain or reveal a raw tenant identity supplied by the browser.

**Phase scope:** one live multi-tenant browser/session transition and its isolation gate. The
`ui-multi-tenant-live` Haskell component suite can supply supporting observations only; the sole acceptance command is `pb validate
phase 83`. Split on workflow/artifact UX, replica failure/HA, a second substrate, or a second independently
releasable runtime feature.
**Substrate:** `linux-cpu` — future live browser/cluster observation only after the Phase-50 barrier and every predecessor approval.
**Lane:** `linux-cpu/amd64`.
**Register:** 3 — live authenticated multi-tenant browser isolation; NOT VALIDATED.
**Depends on:** [Phase 82](phase_82_ui_single_tenant_live.md)
**Gate:** `pb validate phase 83`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive claim — *two tenants share the live edge and observe nothing of each other*. Opaque scope selection and epoch rotation are what make a stale handle a refusal rather than a leak. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 83` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 82; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

- The generic immutable PureScript runtime generated lazily from reviewed Haskell beneath ignored `.build/**`,
  and the same-binary Haskell UI-server worker behind Keycloak/Envoy, using paired plans from one sealed
  `BoundUiProgram`; no per-app image or browser provider client exists.
- Two tenant scopes, two real subjects, equal-shaped data, route/action projections, and one live membership
  change; all handles and caches are scope/subject/epoch keyed.
- Separate SUT and observer credentials, a foreign CNI probe, and a bounded Haskell browser harness that lazily
  generates any Playwright transport beneath `.build/**`, with complete
  pod/image/slot/API/etcd/storage/message envelopes admitted before effects.

- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`, `S1`–`S6`; Haskell negative declarations
  materialize their serialized cases lazily under `.build/test-corpora/ui_multi_tenant_live/`.

## Doctrine adopted

- [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6) — multi-tenant low-code UI isolation carries an identity boundary, and S1-S6 are what make crossing it unrepresentable.
- [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): browser presentation is not authority.
- [`low_code_ui_runtime_doctrine.md` §10.2 — multi-tenant mode](../documents/engineering/low_code_ui_runtime_doctrine.md#102-multi-tenant-mode): opaque selection rotates scope and invalidates tenant state.
- [`low_code_ui_runtime_doctrine.md` §13 — Generic PureScript client and amoebius UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): all effects cross the same-origin server boundary; PureScript is a lazy Haskell-generated `.build/**` output, never repository source.
- [`low_code_ui_runtime_doctrine.md` §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): membership or policy changes invalidate stale authority.
- [`illegal_state_security.md` §3.79 — A UI action whose server authorization does not match its declaration](../documents/illegal_state/illegal_state_security.md#379-a-ui-action-whose-server-authorization-does-not-match-its-declaration), [`illegal_state_security.md` §3.80 — A subject resolving or mutating another subject's resource without a grant](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant), [`illegal_state_capability_messaging.md` §3.82 — A browser effect or provider call escaping the server-mediated capability boundary](../documents/illegal_state/illegal_state_capability_messaging.md#382-a-browser-effect-or-provider-call-escaping-the-server-mediated-capability-boundary), and [`illegal_state_security.md` §3.83 — A UI plan executed after an authority-bearing source changed](../documents/illegal_state/illegal_state_security.md#383-a-ui-plan-executed-after-an-authority-bearing-source-changed): their live Haskell oracles and changed-subject mutation operators are mandatory.
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): authority and effect evidence come from outside the UI runtime.
- [`ui_realtime_coordination_doctrine.md` §4 — Typed routing and resume envelope](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): every routed frame/registration exact-matches current tenant/subject/scope/program epochs.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and a human tracker change.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in reviewed Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 83.1: Live opaque tenant switching and stale-scope refusal ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 82](phase_82_ui_single_tenant_live.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt the multi-tenant session protocol in the generic UI runtime and test that scope switching changes only
server-established authority while invalidating every stale client value that could cross the old boundary.

### Deliverables

- Server handling for bounded opaque tenant choices, membership recheck, epoch rotation, handle invalidation,
  request/subscription cancellation, and current route/authorization projection reload.
- Generic tenant-choice rendering generated lazily as PureScript from reviewed Haskell beneath `.build/**`; it
  stores no tenant authority and clears tenant-scoped state on the server-confirmed transition.
- A live Haskell browser/security harness that lazily generates any Playwright transport beneath `.build/**`,
  Keycloak identities, fresh-challenge protocol, independent provider/network and session-epoch observers,
  explicit Haskell changed-subject mutations, cleanup inventory, and a Haskell-schema-checked Register-3 ledger.

### Validation

1. Rejected historical observation: the `ui-multi-tenant-live` Cabal suite expected all visibility rows and
   independent server decisions to match their own
   matrices, with every own/foreign pair exercised under real authority.
2. Switch `t-a → t-b`; old handles, outstanding completions, direct action calls, and old plan/scope epochs fail
   with zero external effect. Revoke membership and replay the old tenant-choice handle without refreshing the
   browser; Mallory's captured never-authorized choice must fail identically and mint no scope epoch.
3. Confirm browser traffic is same-origin only, direct platform/provider paths fail, and no credential, provider
   coordinate, raw tenant id, or unsanitized foreign-resource distinction appears in client state or payloads.
4. Run `drop_tenant_key`, `drop_user_key`, and `accept_unlisted_tenant_choice`, tear down, and record challenge,
   authority, external-observation, network-trace, and postflight-inventory digests in the `linux-cpu`
   Register-3 ledger.

### Remaining Work

The authority kernel and scoped local probe are implemented; the full Register-3 provider/browser path remains UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` and `documents/engineering/tenancy_doctrine.md` —
  record live opaque scope switching and current-policy enforcement.
- `documents/illegal_state/illegal_state_security.md` and
  `documents/illegal_state/illegal_state_capability_messaging.md` — attach the four live illegal-state oracles.
- `documents/engineering/testing_doctrine.md` — register the split visibility/auth matrix and browser/provider
  zero-effect observer pattern.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, gate, substrate, and runtime modules.
- Phase 85 — consume this multi-tenant correctness result before adding whole-zone HA evidence.

## Related Documents

- [Phase 69](phase_69_user_tenant_isolation_live.md) — required live provider isolation beneath the UI.
- [Phase 82](phase_82_ui_single_tenant_live.md) — required live single-tenant generic client/server path.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — multi-tenant session, server boundary, and freshness rules.
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md) — membership, ownership, grants, and provider policy source.
- [Illegal-State Capability/Messaging Slice](../documents/illegal_state/illegal_state_capability_messaging.md) — browser/provider bypass foreclosure.
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md) — scoped
  connection routing and stale-registration refusal during tenant changes.
