# Phase 43: Haskell UI-server boundary

> **Purpose**: Define the UI-server responsibility in the amoebius executable and constrain with Haskell-generated boundary fakes that
> every request is freshly authenticated, scoped, authorized, freshness-checked, and dispatched before effect.
> **Read this if**: phase 43 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_44_ui_local_composition.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 43.1: Authenticated scoped UI-server dispatch ⏸️](#sprint-431-authenticated-scoped-ui-server-dispatch-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 42, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** This phase specifies one seam: the `amoebius serve-ui` responsibility
over `UiServerPlan`. The one Haskell executable is to authenticate a modeled request, derive `RequestContext` from the
verified credential, check origin/CSRF and plan/authority epochs, resolve scoped opaque handles, construct
`AuthorizedAction`, and only then dispatches to the one bound trusted handler. Browser tenant, subject, owner,
role, grant, resource coordinate, and serialized capability claims are hostile inputs and cannot replace the
server-derived context.

Before modeled readiness, the target worker is to verify the server ABI and exact-join every serialized handler identity in the
plan against the closed registry linked into the binary. A missing, duplicate, or incompatible binding for a
referenced identity refuses readiness; unreferenced linked handlers remain legal but unreachable. Runtime
reflection and name-based fallback are absent.

The target boundary serves only allowlisted immutable client assets and `ClientPlan` values with the fixed
production CSP, strict MIME, clickjacking, referrer, cache, and related security headers. Those headers are
closed server defaults rather than application options, and their exact policy must match an independently
checked Haskell policy value. Browser enforcement is post-Phase-49; the private `UiServerPlan`, dispatch table, policy graph, and server codecs have no asset
route.

The target boundary also models termination of the authenticated same-origin WebSocket. Before modeled registration it is to verify the
secure session cookie, exact Origin, single-use session nonce, fixed subprotocol, current plan/ABI/scope epochs,
and the complete typed routing envelope. A boundary-injected `UiRealtimeCoordination` interface registers
connection ownership and fanout; the Register-2 target uses an independent fake, while the real Redis adapter
belongs to Phase 63. Redis identifiers never enter handler input or establish authorization.

The boundary returns sanitized structured refusal or `ReloadRequired` responses and records no handler effect
on every denial. This phase does not implement the browser interpreter, a domain provider, deployment
manifests, replicas, failover, or a separate server artifact.

**Phase scope:** one target Haskell `serve-ui` protocol/session-to-`AuthorizedAction`-to-handler boundary,
observed only through Haskell-owned generated fakes; browser rendering, live authority/providers, deployment,
and HA remain deferred.
**Substrate:** none — the Haskell binary and run-local fake boundaries only; no browser, cluster, hardware-specific service, or external authority.
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 2 — boundary integration with fakes.
**Depends on:** [Phase 42](phase_42_ui_browser_interpreter.md)
**Gate:** `pb validate phase 43`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target only — the Haskell `serve-ui` protocol/session/authorization/handler policy is observed through Haskell-generated fakes beneath `.build/**` and compared with an independent Haskell policy value. Browser enforcement, live identity/providers, deployment, and HA are not claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 43` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 42; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. The owner marker, preflight, complete
> allowed/forbidden mutations, external observer, scoped cleanup, and zero-owned-residue contract are absent.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §9 — Routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): verified server context and current policy, never browser visibility, construct authority.
- [`low_code_ui_runtime_doctrine.md` §10 — Single-tenant and multi-tenant applications](../documents/engineering/low_code_ui_runtime_doctrine.md#10-single-tenant-and-multi-tenant-applications): both modes retain scoped witnesses and foreign-scope denial.
- [`low_code_ui_runtime_doctrine.md` §13 — Generic PureScript client and amoebius UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): the server is an amoebius binary responsibility and the sole provider-dispatch edge.
- [`low_code_ui_runtime_doctrine.md` §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): current authority and contract identity is rechecked immediately before effects.
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): Haskell-generated credentials/nonces and paired fake-boundary refusals constrain this phase; live external observation is deferred.
- [`ui_realtime_coordination_doctrine.md` §3 — One browser transport contract](../documents/engineering/ui_realtime_coordination_doctrine.md#3-one-browser-transport-contract) and [`ui_realtime_coordination_doctrine.md` §4 — Typed routing and resume envelope](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): authenticated WebSocket admission and scoped routing are part of the server boundary; Redis remains behind an injected platform interface.
- [`illegal_state_security.md` §3.79 — A UI action whose server authorization does not match its declaration](../documents/illegal_state/illegal_state_security.md#379-a-ui-action-whose-server-authorization-does-not-match-its-declaration), [`illegal_state_security.md` §3.80 — A subject resolving or mutating another subject's resource without a grant](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant), and [`illegal_state_security.md` §3.83 — A UI plan executed after an authority-bearing source changed](../documents/illegal_state/illegal_state_security.md#383-a-ui-plan-executed-after-an-authority-bearing-source-changed): runtime refusal and zero-effect pairs cover the server residue.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 43.1: Authenticated scoped UI-server dispatch ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 42](phase_42_ui_browser_interpreter.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt the sole trusted browser-to-effect boundary so no request can reach a handler without verified current
identity, compatible scope, explicit authorization, current plan identity, and the bound retry/audit contract.

### Deliverables

- UI-server command responsibility, pre-readiness ABI/handler-registry admission, strict public decoders,
  exact client-asset allowlisting/private-plan non-disclosure, session/origin/CSRF checks, current-authority
  transition, scoped handle resolution, fixed asset/plan security headers, sanitized errors, and handler
  dispatch requiring `AuthorizedAction`.
- Authenticated WebSocket handshake, complete routing-envelope decoder, connection lifecycle/drain, and an
  injected realtime-coordination interface whose fake proves cross-instance routing without becoming a
  receipt store.
- Ephemeral signing authority, separate handler process, paired access matrix, post-start challenge, OS-level
  network/effect observer, and direct-bypass probes.
- Haskell mutation declarations and a lazily rendered `.build/**` Register-2 ledger carrying raw-observation
  digests and marking live layers UNVERIFIED.

### Validation

1. Rejected historical observation: the `ui-server-boundary-spec` Cabal suite expected all own-scope actions
   to match the authored HTTP/effect/audit rows,
   while each foreign/stale/spoofed/origin-negative twin returns its pinned refusal and emits zero handler bytes.
2. Recover the post-start nonce and exact scoped action from both external observers; make observer loss,
   authentication failure, incomplete capture, or nonce mismatch fail closed.
3. Require only the exact client-asset allowlist to be fetchable, every private server-manifest probe to return
   zero private bytes, and every missing/duplicate/incompatible referenced handler or ABI twin to refuse before
   readiness.
4. Run `M-trust-tenant-header`, `M-dispatch-before-authorize`, `M-skip-current-epoch`,
   `M-disable-origin-check`, `M-drop-csp-header`, `M-ready-with-unresolved-handler`,
   `M-server-first-handler-wins`, `M-serve-server-plan-as-client-asset`, and
   `M-new-idempotency-key-on-retry`; each turns a distinct pin red.
5. Verify the ledger says UI-server boundary tested with fakes and does not claim live Keycloak, edge,
   provider, cluster, redundancy, or HA evidence.
6. Pair a valid WebSocket handshake/frame with wrong-Origin, replayed-nonce, stale-program, cross-scope, and
   coordinator-loss twins. Only the valid frame reaches the fake remote connection; no fake-coordinator
   acknowledgement can satisfy the separately authored Haskell durable handler-effect oracle.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate. Live identity, edge exclusivity, provider/storage policy, cluster deployment, replica loss, and HA remain
explicitly UNVERIFIED for their owning later phases rather than Phase-43 work.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record local server-boundary evidence without
  claiming live identity/provider or HA behavior.
- `documents/engineering/daemon_topology_doctrine.md` — register the UI-server responsibility in the same
  executable, not a new product binary.
- `documents/illegal_state/illegal_state_security.md` — attach credentials, paired denials, observers, and
  Haskell freshness/scope changed-subject mutants.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, Register 2, `none` substrate, and target modules.
- Phase 44 — compose this boundary with the generic browser without replacing either Haskell oracle.

## Related Documents

- [Development Plan Tracker](README.md) — numeric order and current status.
- [Phase 10](phase_10_calculus_composition.md) — the real five-calculus composition projected by this gate.
- [Phase 40](phase_40_ui_plan_compiler.md) — the required immutable `UiServerPlan` and dispatch contracts.
- [Repository Layout Doctrine](../documents/engineering/repository_layout_doctrine.md) — the single executable
  source-root and generated-output boundary.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — server role, authorization, scope, and freshness boundary.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — authority-paired spoof-resistant evidence.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — authorization, ownership, and stale-plan illegal states.
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md) — WebSocket
  authentication, typed routing envelope, and the Redis/durable-receipt boundary projected behind this seam.
