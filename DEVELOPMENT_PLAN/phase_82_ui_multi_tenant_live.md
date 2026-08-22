# Phase 82: Multi-tenant low-code UI isolation

> **Purpose**: Prove a multi-tenant low-code UI live through Keycloak/Envoy, including opaque scope selection,
> epoch rotation, stale-handle refusal, server-side authorization, and zero cross-tenant effects.
> **Read this if**: phase 82 is next in the queue, or a later phase depends on what its gate establishes.

Phase 82 delivers the multi-tenant low-code UI isolation; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [testing_doctrine.md](../documents/engineering/testing_doctrine.md), [ui_realtime_coordination_doctrine.md](../documents/engineering/ui_realtime_coordination_doctrine.md), and the plan for reaching it is owned here.
Register 3, scoped live, on the `linux-cpu` substrate.
The scoped gate passed on 2026-08-11; real identity/provider isolation remains `UNVERIFIED`.

> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — two-scope UI fixture](#resource-provision--two-scope-ui-fixture)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 82.1: Live opaque tenant switching and stale-scope refusal ⏸️](#sprint-821-live-opaque-tenant-switching-and-stale-scope-refusal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-81 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Blocked (superseded) — containment amendment recorded 2026-08-15. Any earlier capability seal is historical and
invalidated until this phase reruns in numerical order with all amoebius-owned state confined to the
repository roots defined by Phase 0. Scope amendments below remain normative.

**Pre-containment status record (invalidated where it claims completion):**

Blocked (superseded) by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish repository-local evidence without changing an authored path.

**Invalidated historical record:**

🟡 **Scoped gate passed 2026-08-11.** Opaque choices, current-membership recheck, scope-epoch rotation,
state/handle invalidation, tenant/subject/epoch keying, fresh two-scope local observations, and four mutants
pass. Real Keycloak sessions, browser switching, provider zero-delta observers, Kubernetes audit, CNI, and
Redis realtime remain **UNVERIFIED**. Ledger `external-run-reference`.

## Phase Summary

This phase owns one vertical seam: the generic browser and same-origin UI server perform an authenticated
multi-tenant scope change using opaque `TenantChoiceHandle`s. A successful change rotates the server scope
epoch, clears tenant state, invalidates handles and in-flight work, and reloads routes and authorization
projections. Every subsequent action is resolved and authorized against current server truth; control visibility
remains advisory.
The scope epoch also keys WebSocket registrations, routed frames, Redis presence, and resume cursors. A scope
change closes the old connection/registration before the new scope becomes routable; no Redis key or frame may
retain or reveal a raw tenant identity supplied by the browser.

**Session scope:** one live multi-tenant browser/session transition and its isolation gate; acceptance command
`cabal test ui-multi-tenant-live`; split on workflow/artifact UX, replica failure/HA, a second substrate, or a
second independently releasable runtime feature.
**Depends on:** [Phase 68](phase_68_user_tenant_isolation_live.md) and
[Phase 81](phase_81_ui_single_tenant_live.md) — live provider isolation and the live single-tenant generic UI path.
Phase 68 is validated and is consumed unchanged; this phase still waits for Phase 81 and owns browser scope
switching rather than reopening the provider-isolation result.
**Phase scope:** one cohesive claim — *two tenants share the live edge and observe nothing of each other*. Opaque scope selection and epoch rotation are what make a stale handle a refusal rather than a leak.

**Substrate:** linux-cpu — one live `kind` cluster with the standing platform; no GPU, Apple, provider-cloud,
multicluster, or HA-failure claim.
**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure.
**Gate:** `python3 tools/run_phase_gate.py 82` drives the generic PureScript client through a real
Keycloak-authenticated scope change and satisfies every pinned matrix, fresh challenge, stale replay, bypass
probe, and mutant in [Gate integrity](#gate-integrity). Forbidden effects require authenticated external
zero-delta evidence.

## Gate integrity

Phase 0 pins expected browser presentation and server authorization separately. The browser trace may enumerate
controls, but it is never the authority oracle and cannot satisfy a denial row by hiding a button.

- **Representative set:** one checked UI template serves tenants `t-a` and `t-b` × subjects `alice` and `bob`,
  with both users initially admitted to both scopes, plus `mallory-a`, who is never a member of `t-b`.
  Equal-shaped routes, subject-owned records, tenant-wide records, and mutations exist in every admitted cell.
  Alice's `t-b` membership is revoked mid-run. The same action ids and labels are reused deliberately to expose
  alias/keying mistakes.
- **Pinned matrices:** `test/fixture/ui_multi_tenant/visibility_matrix.tsv` owns expected controls/routes;
  `authorization_matrix.tsv` independently owns server allow/deny; `scope_transition_trace.tsv` owns epoch,
  cancellation, state-clear, and handle-validity outcomes; `tenant_choice_matrix.tsv` owns which opaque choices
  may be issued and selected before/after revocation; `expected_network_origins.tsv` owns the allowed immutable-
  asset and same-origin request set. None is generated from either runtime plan.
- **Real authority:** after startup, Keycloak mints least-privilege credentials for all three subjects. The
  browser receives only the protected session mechanism; no bearer, refresh token, raw tenant id, provider
  credential, or policy document enters UI state, fixtures, screenshots, or Playwright logs.
- **Fresh challenges:** the harness creates unpredictable tenant-specific nonces after the UI server is ready.
  It writes and reads the permitted nonce, switches scope, tries the old handle/request/epoch directly, writes a
  new-scope nonce, then changes membership and retries both the revoked `TenantChoiceHandle` directly against
  the scope-change endpoint and the old plan. Mallory also submits a bit-identical captured `t-b` choice that
  was valid for Alice. Fixed/canned output cannot pass.
- **Paired own/foreign checks:** every permitted action is paired with same-action foreign-tenant and, where
  applicable, foreign-subject requests. The hostile versions differ only in authenticated scope, handle, epoch,
  or caller-supplied tenant field; all other public bytes are identical.
- **External observers:** separate read-only Postgres/MinIO/Pulsar observers, Keycloak event/membership readback,
  read-only session-store/epoch readback, Kubernetes audit, and a foreign-pod CNI probe record raw challenge-
  bearing effects and network paths. A Playwright network observer outside the generated client confirms only
  immutable assets and same-origin UI transport. Missing or unauthenticated evidence fails closed.
- **Bypass and zero-effect checks:** a hidden/disabled action is invoked directly; raw tenant/header/handle
  substitutions, a random guessed handle, a bit-mutated real handle, Mallory's never-authorized selection, and
  Alice's revoked choice hit the server; browser and foreign-pod probes try platform/provider addresses.
  Rejected choice selection must mint no session/scope epoch and denied nonces must be absent from provider
  state, cursors, logs, caches, and audit payloads except the sanitized denial event.
- **Seeded mutants:** `drop_tenant_key` removes trusted tenant scope from a lookup/cache key, and
  `drop_user_key` removes trusted subject/owner scope; `accept_unlisted_tenant_choice` skips current membership
  when selecting an opaque choice. All three variants are committed and must create a choice/session or
  cross-scope matrix/provider mismatch that turns the gate red.
  `drop_scope_epoch_from_realtime_route` is an additional committed mutant and must deliver a stale old-scope
  frame, turning the browser/provider/cursor oracle red.

The gate always deletes the realm fixtures and test-owned tenant data and requires an authenticated postflight
inventory equal to preflight. Phase 84, not this phase, owns whole-zone HA fault evidence.

## Resource provision — two-scope UI fixture

- The generic immutable PureScript runtime and same-binary UI-server worker behind Keycloak/Envoy, using paired
  plans from one sealed `BoundUiProgram`; no per-app image or browser provider client exists.
- Two tenant scopes, two real subjects, equal-shaped data, route/action projections, and one live membership
  change; all handles and caches are scope/subject/epoch keyed.
- Separate SUT and observer credentials, a foreign CNI probe, bounded Playwright harness, and complete
  pod/image/slot/API/etcd/storage/message envelopes admitted before effects.

- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`, `S1`–`S6`; negatives under `test/negative/ui_multi_tenant_live/`.

## Doctrine adopted

- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — multi-tenant low-code UI isolation carries an identity boundary, and S1-S6 are what make crossing it unrepresentable.
- [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): browser presentation is not authority.
- [`low_code_ui_runtime_doctrine.md` §10.2 — multi-tenant mode](../documents/engineering/low_code_ui_runtime_doctrine.md#102-multi-tenant-mode): opaque selection rotates scope and invalidates tenant state.
- [`low_code_ui_runtime_doctrine.md` §13 — generic client and UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): all effects cross the same-origin server boundary.
- [`low_code_ui_runtime_doctrine.md` §15 — versioning and rollout](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): membership or policy changes invalidate stale authority.
- [`illegal_state_catalog.md` §3.79](../documents/illegal_state/illegal_state_security.md#379-a-ui-action-whose-server-authorization-does-not-match-its-declaration), [`§3.80`](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant), [`§3.82`](../documents/illegal_state/illegal_state_capability_messaging.md#382-a-browser-effect-or-provider-call-escaping-the-server-mediated-capability-boundary), and [`§3.83`](../documents/illegal_state/illegal_state_security.md#383-a-ui-plan-executed-after-an-authority-bearing-source-changed): their live oracles and mutants are mandatory.
- [`testing_spoof_resistance.md` §12](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): authority and effect evidence come from outside the UI runtime.
- [`ui_realtime_coordination_doctrine.md §4`](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): every routed frame/registration exact-matches current tenant/subject/scope/program epochs.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 82.1: Live opaque tenant switching and stale-scope refusal ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `src/Amoebius/Ui/Server/TenantSession.hs`,
`ui/src/Amoebius/Ui/TenantSwitch.purs`, `test/spec/live/UiMultiTenantSpec.hs` (target authored
sources; not yet built)
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: the one gate command
drives real Keycloak sessions and compares browser, server, network, and provider observations with the
independent Phase-0 matrices; every named mutant must turn red.
**Docs to update**:
`documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/engineering/tenancy_doctrine.md`,
`documents/illegal_state/illegal_state_security.md`,
`documents/illegal_state/illegal_state_capability_messaging.md`,
`documents/engineering/ui_realtime_coordination_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Adopt the multi-tenant session protocol in the generic UI runtime and test that scope switching changes only
server-established authority while invalidating every stale client value that could cross the old boundary.

### Deliverables

- Server handling for bounded opaque tenant choices, membership recheck, epoch rotation, handle invalidation,
  request/subscription cancellation, and current route/authorization projection reload.
- Generic PureScript tenant-choice rendering that stores no tenant authority and clears tenant-scoped state on
  the server-confirmed transition.
- Live Playwright/security harness, Keycloak identities, fresh-challenge protocol, independent provider/network
  and session-epoch observers, explicit mutants, cleanup inventory, and a schema-checked Register-3 ledger.

### Validation

1. Run `cabal test ui-multi-tenant-live`; all visibility rows and independent server decisions match their own
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

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` and `documents/engineering/tenancy_doctrine.md` —
  record live opaque scope switching and current-policy enforcement.
- `documents/illegal_state/illegal_state_security.md` and
  `documents/illegal_state/illegal_state_capability_messaging.md` — attach the four live illegal-state oracles.
- `documents/engineering/testing_doctrine.md` — register the split visibility/auth matrix and browser/provider
  zero-effect observer pattern.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, gate, substrate, and runtime modules.
- Phase 84 — consume this multi-tenant correctness result before adding whole-zone HA evidence.

## Related Documents

- [Phase 68](phase_68_user_tenant_isolation_live.md) — required live provider isolation beneath the UI.
- [Phase 81](phase_81_ui_single_tenant_live.md) — required live single-tenant generic client/server path.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — multi-tenant session, server boundary, and freshness rules.
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md) — membership, ownership, grants, and provider policy source.
- [Illegal-State Capability/Messaging Slice](../documents/illegal_state/illegal_state_capability_messaging.md) — browser/provider bypass foreclosure.
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md) — scoped
  connection routing and stale-registration refusal during tenant changes.
