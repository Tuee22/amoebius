# Phase 43: UI-server boundary

> **Purpose**: Add the UI-server responsibility to the amoebius executable and test with boundary fakes that
> every request is freshly authenticated, scoped, authorized, freshness-checked, and dispatched before effect.
> **Read this if**: phase 43 is next in the queue, or a later phase depends on what its gate establishes.

Phase 43 delivers the UI server boundary; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [testing_doctrine.md](../documents/engineering/testing_doctrine.md), [ui_realtime_coordination_doctrine.md](../documents/engineering/ui_realtime_coordination_doctrine.md), and the plan for reaching it is owned here.
Register 2: a real boundary against fake tools.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_44_ui_local_composition.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 43.1: Authenticated scoped UI-server dispatch ✅](#sprint-431-authenticated-scoped-ui-server-dispatch-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-22. `python3 tools/ui_server_boundary_gate.py` passes all fourteen sides on natural
`arm64`, untranslated. Seven HTTP rows, five access rows, five sanitized audits, five handler-effect rows, six
pre-readiness startup rows, five public assets, five private probes, seven WebSocket rows, the post-start
challenge/idempotency checks, and all nine production mutants pass. The added startup row proves an
unreferenced linked handler is legal without entering the plan's dispatch set. The real five-calculus
projection accounts for 80 units, all 23 metrics match, and 84 surfaces join to 102 run-time items. Darwin
loopback-only enforcement passes. Attestation
`sha256:0bf76e1e1c17b9d525470fd9a72c3d51f931999a60058801cbd7f049b014f0e9` binds source
`sha256:28428437a5b25a11…` over 2,268 files. Live Keycloak/Envoy, provider policy, cluster deployment, replica
loss, and HA remain UNVERIFIED.

## Phase Summary

This phase implements one seam: the `amoebius serve-ui` runtime responsibility over `UiServerPlan`. The same
amoebius executable that owns other runtime roles authenticates the request, derives `RequestContext` from the
verified credential, checks origin/CSRF and plan/authority epochs, resolves scoped opaque handles, constructs
`AuthorizedAction`, and only then dispatches to the one bound trusted handler. Browser tenant, subject, owner,
role, grant, resource coordinate, and serialized capability claims are hostile inputs and cannot replace the
server-derived context.

Before readiness, the worker verifies the server ABI and exact-joins every serialized handler identity in the
plan against the closed registry linked into the binary. A missing, duplicate, or incompatible binding for a
referenced identity refuses readiness; unreferenced linked handlers remain legal but unreachable. Runtime
reflection and name-based fallback are absent.

The same boundary serves only allowlisted immutable client assets and `ClientPlan` values with the fixed
production CSP, strict MIME, clickjacking, referrer, cache, and related security headers. Those headers are
closed server defaults rather than application options, and their exact policy must match the browser-enforced
Phase-42 fixture. The private `UiServerPlan`, dispatch table, policy graph, and server codecs have no asset
route.

The boundary also terminates the authenticated same-origin WebSocket. Before registration it verifies the
secure session cookie, exact Origin, single-use session nonce, fixed subprotocol, current plan/ABI/scope epochs,
and the complete typed routing envelope. A boundary-injected `UiRealtimeCoordination` interface registers
connection ownership and fanout; the Register-2 gate uses an independent fake, while the real Redis adapter is
stood up in Phase 62. Redis identifiers never enter handler input or establish authorization.

The boundary returns sanitized structured refusal or `ReloadRequired` responses and records no handler effect
on every denial. This phase does not implement the browser interpreter, a domain provider, deployment
manifests, replicas, failover, or a separate server artifact.

**Phase scope:** one `serve-ui` HTTPS/WebSocket/session-to-`AuthorizedAction`-to-handler boundary in the existing
executable, with acceptance command `python3 tools/ui_server_boundary_gate.py`; split immediately if work
requires browser rendering, a live Keycloak/provider, deployment/HA, a second register, or a substrate.
**Substrate:** none — harness-owned local authority/handler processes only; no cluster or external service.
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 2 — boundary integration with fakes.
**Depends on:** [Phase 40](phase_40_ui_plan_compiler.md) — canonical `UiServerPlan`, public contracts, route
dispatch, and authority digests; [Phase 42](phase_42_ui_browser_interpreter.md) — the exact browser-facing
security-header and same-origin transport contract.
**Gate:** `python3 tools/run_phase_gate.py 43` emits a green Register-2 ledger with live identity, provider, and
HA layers UNVERIFIED, and Phase 44's server branch waits on it. The apparatus is
[Gate integrity](#gate-integrity).

## Gate integrity

Phase 0 commits request fixtures, access decisions, expected HTTP responses and security headers, expected
effect rows, and mutant outcomes before `Amoebius.Ui.Server` exists. The authority and handler are separate
harness processes; neither reads a decision trace emitted by the server under test.


The command passes only when all of it holds together: the Phase-0-pinned request, access, startup, and asset
matrices; cryptographically minted least-privilege own- and foreign-scope credentials; the post-start nonce
round trip; the stale-epoch, private-plan, and bypass negatives; the independent HTTP and OS-boundary effect
observations; and every seeded mutant below turning its own oracle row red.

- **Representative set:** public `ClientPlan` fetch, authenticated route read, scoped data read/mutation, workflow
  start/observe, bounded upload, subscription resume, ready-artifact use, sign-out, idempotent replay, and
  stale-plan reload span single-tenant and multi-tenant programs.
- **Pinned oracles:** `test/fixture/ui_server/requests.tsv`, `access_matrix.tsv`, `expected_http.tsv`,
  `test/fixture/ui_security/production_headers.tsv`, `expected_effects.tsv`, and `expected_audit.tsv` own
  inputs/outcomes; `startup_plan_matrix.tsv` owns ABI and handler-registry admission; and
  `public_asset_allowlist.tsv` plus `forbidden_server_manifest_paths.tsv` own the exact browser-visible set and
  server-plan path probes. Every allow pairs with a denial differing only in subject, tenant, permission, grant
  state, origin, or authority epoch. Asset/plan responses must exactly match the Phase-42 browser-enforced
  header policy.
- **Authority provenance:** an independently started ephemeral signing-authority process mints HMAC-signed,
  least-privilege credentials after the server starts. The server derives tenant/subject/roles from the
  verified token; spoofed `X-Tenant`, `X-Subject`, owner, and role fields never affect the decision.
- **Fresh challenge and external observation:** after readiness, the harness creates an unpredictable nonce
  and includes it in an authorized typed mutation. A separate handler process records raw request bytes to an
  append-only harness-owned descriptor. Darwin applies an OS sandbox that allows loopback and denies
  non-loopback outbound IP; Linux records `connect`/`sendto` calls with `strace`. Both
  observers must recover the nonce and matching scoped action; self-reported server audit is insufficient.
- **Paired denials and bypass probes:** same request with a foreign-subject token, foreign-tenant token,
  revoked grant, stale epoch, invalid origin/CSRF token, direct handler address, or caller tenant header returns
  its pinned refusal and produces zero handler bytes. The observer failing, incomplete, or challenge-mismatched
  fails the gate closed.
- **Startup fail-closed matrix:** the canonical manifest exact-joins each referenced identity once and reaches
  readiness. Twins with a missing referenced identity, duplicate bindings for one referenced identity, an
  incompatible handler contract, or the wrong `UiServerAbi` never become ready, serve a client plan, or emit
  handler bytes; an HTTP error from an already-serving worker is not equivalent. Extra linked handlers omitted
  from the sealed dispatch table remain legal and unreachable.
- **WebSocket registration and routing:** valid session/Origin/nonce/subprotocol establishes one scoped
  connection registration. Replayed nonce, stale scope/program/ABI, missing envelope field, cross-scope frame,
  and unavailable coordinator refuse registration or delivery. A fake coordinator publish is a routing hint,
  never a durable receipt.
- **Private-plan non-disclosure:** authenticated and unauthenticated clients request guessed paths and the exact
  content-addressed path of the serialized `UiServerPlan`, with path/query/accept variants. An external HTTP
  transcript must match the pinned non-enumerating denial, contain none of the independently held server-plan
  bytes or private canary, and expose only paths in `public_asset_allowlist.tsv`. Browser inability to decode a
  leaked object is not a pass.
- **Seeded mutants:** `M-trust-tenant-header` (provenance guard deletion), `M-dispatch-before-authorize`
  (effect reorder), `M-skip-current-epoch` (freshness guard deletion), `M-disable-origin-check` (guard
  weakening), `M-drop-csp-header` (security-boundary deletion), `M-ready-with-unresolved-handler` and
  `M-server-first-handler-wins` (startup guard/quantifier weakening), `M-serve-server-plan-as-client-asset`
  (private-surface exposure), and `M-new-idempotency-key-on-retry` (effect swap) are committed and must each
  turn a distinct oracle row red.

Passing tests this local boundary against independent fakes and real signed test credentials. Keycloak truth,
edge exclusivity, provider policy, storage isolation, and behavior after replica loss remain UNVERIFIED.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): verified server context and current policy, never browser visibility, construct authority.
- [`low_code_ui_runtime_doctrine.md` §10 — single-tenant and multi-tenant applications](../documents/engineering/low_code_ui_runtime_doctrine.md#10-single-tenant-and-multi-tenant-applications): both modes retain scoped witnesses and foreign-scope denial.
- [`low_code_ui_runtime_doctrine.md` §13 — generic client and UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): the server is an amoebius binary responsibility and the sole provider-dispatch edge.
- [`low_code_ui_runtime_doctrine.md` §15 — versioning and rollout](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): current authority and contract identity is rechecked immediately before effects.
- [`testing_spoof_resistance.md` §12](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): credentials, nonce, paired denial, external observer, and bypass probes are mandatory.
- [`ui_realtime_coordination_doctrine.md §3`](../documents/engineering/ui_realtime_coordination_doctrine.md#3-one-browser-transport-contract) and [`§4`](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): authenticated WebSocket admission and scoped routing are part of the server boundary; Redis remains behind an injected platform interface.
- [`illegal_state_security.md` §3.79](../documents/illegal_state/illegal_state_security.md#379-a-ui-action-whose-server-authorization-does-not-match-its-declaration), [`§3.80`](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant), and [`§3.83`](../documents/illegal_state/illegal_state_security.md#383-a-ui-plan-executed-after-an-authority-bearing-source-changed): runtime refusal and zero-effect pairs cover the server residue.

## Sprints

## Sprint 43.1: Authenticated scoped UI-server dispatch ✅

**Status**: Done
**Implementation**:
`app/amoebius/Amoebius/Entry/ServeUi.hs`, `src/Amoebius/Ui/Server/{Dispatch,RequestContext,SecurityHeaders,WebSocket}.hs`,
`src/Amoebius/Ui/Realtime/{Class,Envelope}.hs`, `test/spec/ui/UiServerBoundarySpec.hs`,
`test/harness/ui_server/server_boundary.mjs`, and `tools/ui_server_boundary_gate.py`
**Blocked by**: [Phase 42](phase_42_ui_browser_interpreter.md) gate
**Independent Validation**: `python3 tools/ui_server_boundary_gate.py` starts the
authority/server/handler as separate processes, drives paired HTTP
requests, reads independent raw effect/network observations, and requires every named mutant to fail.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/daemon_topology_doctrine.md`,
`documents/engineering/ui_realtime_coordination_doctrine.md`,
`documents/illegal_state/illegal_state_security.md`

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
- Mutant configurations and Register-2 ledger carrying raw-observation digests and marking live layers
  UNVERIFIED.

### Validation

1. Run `cabal test ui-server-boundary-spec`; all own-scope actions match the authored HTTP/effect/audit rows,
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
   acknowledgement can satisfy the durable handler-effect oracle.

### Remaining Work

None. Live identity, edge exclusivity, provider/storage policy, cluster deployment, replica loss, and HA remain
explicitly UNVERIFIED for their owning later phases rather than Phase-43 work.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record local server-boundary evidence without
  claiming live identity/provider or HA behavior.
- `documents/engineering/daemon_topology_doctrine.md` — register the UI-server responsibility in the same
  executable, not a new product binary.
- `documents/illegal_state/illegal_state_security.md` — attach credentials, paired denials, observers, and
  freshness/scope mutants.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, Register 2, `none` substrate, and target modules.
- Phase 44 — compose this boundary with the generic browser without replacing either oracle.

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
