# Phase 43: Haskell UI-server boundary

> **Purpose**: Define the UI-server responsibility in the amoebius executable and constrain with Haskell-generated boundary fakes that
> every request is freshly authenticated, scoped, authorized, freshness-checked, and dispatched before effect.
> **Read this if**: phase 43 is next in the queue, or a later phase depends on what its gate establishes.

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
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 43.1: Authenticated scoped UI-server dispatch](#sprint-431-authenticated-scoped-ui-server-dispatch-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 42 and every earlier numerical predecessor have passed. The authenticated scoped Haskell boundary,
independent oracle, typed cases, nine production-mutant seams, and acquired serial supervisor are implemented;
the complete integrated gate has not yet passed.

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
**Gate:** `pb validate phase 43`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `authenticated-scoped-ui-server-boundary` |
| `Subject` | `acquired-ui-server-boundary-supervisor` |
| `Command` | `pb validate phase 43` (future public spelling); the pre-handoff gate directly executes the exact source-bound Haskell supervisor and its offline serial matrix. |
| `Oracle` | `independent-ui-server-boundary-oracle` |
| `Positive controls` | `ui-server-boundary-positive-controls` |
| `Paired negatives` | `exact-ui-server-boundary-paired-negatives` |
| `Mutants` | `applied-ui-server-boundary-production-mutants` |
| `Discovery` | `exact-ui-server-boundary-source-discovery` |
| `Challenge` | `post-acquisition-ui-server-boundary-challenge` |
| `Observer` | `ui-server-boundary-process-observation` |
| `Authority/bypass` | `no-pb-node-network-live-identity-provider-host-hardware-or-parallelism` |
| `Freshness` | `fresh-ui-server-boundary-build-root-and-stable-source` |
| `Qualification` | `qualified-ui-server-boundary-harness` |
| `Cleanroom` | `ui-server-boundary-products-contained-below-build` |
| `Legacy closure` | `retired-ui-server-boundary-authorities-absent` |
| `Predecessor` | `exact-phase-forty-two-receipt` |
| `Residue` | `live-identity-provider-browser-deployment-and-ha-owners-explicit` |
| `Pass criterion` | `qualified-phase-forty-three-gate-pass` |

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §9 — Routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): verified server context and current policy, never browser visibility, construct authority.
- [`low_code_ui_runtime_doctrine.md` §10 — Single-tenant and multi-tenant applications](../documents/engineering/low_code_ui_runtime_doctrine.md#10-single-tenant-and-multi-tenant-applications): both modes retain scoped witnesses and foreign-scope denial.
- [`low_code_ui_runtime_doctrine.md` §13 — Generic PureScript client and amoebius UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): the server is an amoebius binary responsibility and the sole provider-dispatch edge.
- [`low_code_ui_runtime_doctrine.md` §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): current authority and contract identity is rechecked immediately before effects.
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): Haskell-generated credentials/nonces and paired fake-boundary refusals constrain this phase; live external observation is deferred.
- [`ui_realtime_coordination_doctrine.md` §3 — One browser transport contract](../documents/engineering/ui_realtime_coordination_doctrine.md#3-one-browser-transport-contract) and [`ui_realtime_coordination_doctrine.md` §4 — Typed routing and resume envelope](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): authenticated WebSocket admission and scoped routing are part of the server boundary; Redis remains behind an injected platform interface.
- [`illegal_state_security.md` §3.79 — A UI action whose server authorization does not match its declaration](../documents/illegal_state/illegal_state_security.md#379-a-ui-action-whose-server-authorization-does-not-match-its-declaration), [`illegal_state_security.md` §3.80 — A subject resolving or mutating another subject's resource without a grant](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant), and [`illegal_state_security.md` §3.83 — A UI plan executed after an authority-bearing source changed](../documents/illegal_state/illegal_state_security.md#383-a-ui-plan-executed-after-an-authority-bearing-source-changed): runtime refusal and zero-effect pairs cover the server residue.

## Sprints

## Sprint 43.1: Authenticated scoped UI-server dispatch ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Server/{Dispatch,RequestContext,Security,SecurityHeaders,WebSocket}.hs`, `src/Amoebius/Ui/Realtime/Envelope.hs`, typed cases, production CPP seams, and the package-hidden acquired Phase-43 supervisor.
**Blocked by**: [Phase 42](phase_42_ui_browser_interpreter.md) gate pass
**Independent Validation**: authenticated HTTP, authorization-before-dispatch, startup registry admission, public/private asset separation, idempotent retry, WebSocket registration, calculus, and nine changed-production checks.
**Oracle**: `test/spec/ui/UiServerBoundaryReference.hs`, importing no production or case module.
**Legacy IDs**: exact 24-path Node/Python/serialized/materialized-mutant inventory in `UiServerBoundaryRun.Internal`.
**Docs to update**: this plan, tracker/component/substrate maps, and the three doctrine owners named below.

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
- Ephemeral Haskell signing authority, paired access matrix, pure handler-invocation observation, and direct
  bypass probes without starting a process or network service.
- Haskell mutation declarations and a run-local Register-2 evidence ledger carrying process-receipt digests
  and marking live layers UNVERIFIED.

### Validation

1. The `ui-server-boundary-spec` Cabal suite requires all own-scope actions
   to match the authored HTTP/effect/audit rows,
   while each foreign/stale/spoofed/origin-negative twin returns its pinned refusal and emits zero handler bytes.
2. Acquire fresh signed credentials and exact scoped actions inside the run; make signature, scope, origin,
   CSRF, epoch, or nonce mismatch fail closed before any handler invocation.
3. Require only the exact client-asset allowlist to be fetchable, every private server-manifest probe to return
   zero private bytes, and every missing/duplicate/incompatible referenced handler or ABI twin to refuse before
   readiness.
4. Run `M-trust-tenant-header`, `M-dispatch-before-authorize`, `M-skip-current-epoch`,
   `M-disable-origin-check`, `M-drop-csp-header`, `M-ready-unresolved-handler`,
   `M-first-handler-wins`, `M-serve-private-plan`, and
   `M-new-idempotency-key-on-retry`; each turns a distinct pin red.
5. Verify the ledger says UI-server boundary tested with fakes and does not claim live Keycloak, edge,
   provider, cluster, redundancy, or HA evidence.
6. Pair a valid WebSocket handshake/frame with wrong-Origin, replayed-nonce, stale-program, cross-scope, and
   coordinator-loss twins. Only the valid frame reaches the fake remote connection; no fake-coordinator
   acknowledgement can satisfy the separately authored Haskell durable handler-effect oracle.

### Remaining Work

The complete integrated Phase-43 gate and mechanical status projection remain. Live identity, edge exclusivity, provider/storage policy, cluster deployment, replica loss, and HA remain
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
