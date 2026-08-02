# Phase 57: UI rollout, projection catch-up, and reconnect

**Status**: Authoritative source
**Supersedes**: DEVELOPMENT_PLAN/phase_43_spa_live_deploy.md (rollout/reconnect portion)
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_58_ui_ha_multizone.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Prove a checked UI program can roll from release A to B and roll back without stale-plan
> effects, premature traffic shift, lost owner-scoped projections, or discarded reconnect cursors.

---

## Phase Status

📋 Planned. The release transition and its live evidence are unimplemented design intent.

## Phase Summary

This phase owns one live release transition: projectors catch up to B's recorded watermark, the gateway shifts
traffic only afterward, old and new plan/ABI identities coexist only under a checked compatibility witness,
subscriptions resume from owner-scoped cursors, and rollback returns to A's immutable release. It does not
claim replica or zone failure tolerance; Phase 58 owns that fault boundary.
Connection registrations and routed envelopes carry the admitted program/ABI epoch. Draining replicas stop
accepting sockets, remove or expire Redis registrations, issue a bounded reconnect control frame, and retain
old decoders until their compatibility window closes.

**Session scope:** Implement and validate the single `A → B → A` UI release transition with one acceptance
command, `cabal test phase57-ui-rollout-reconnect`; split if the work introduces another rollout algorithm,
substrate, or infrastructure-failure injection.

**Substrate:** `linux-cpu` ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Gate:** `cabal test phase57-ui-rollout-reconnect` performs the pinned transition and satisfies the
independent timeline, fresh-action, cursor, stale-plan, rollback, and mutant predicates in
[Gate integrity](#gate-integrity). UI-server readiness or an app-authored rollout trace alone is insufficient.

## Gate integrity

**Representative set.** Release A and release B have distinct `ProgramDigest`s and compatible state/port
contracts recorded in a committed witness. B changes one visible projection and one idempotent mutation.
Tenant A has one owner and one same-tenant non-owner; tenant B has a foreign owner with equal-shaped resource,
cursor, and action identities. The owners maintain live projected streams while Gateway API shifts `HTTPRoute`
weights. The transition includes B catch-up, 0→100 traffic shift, an old-client request, same-owner cursor
resume, same-tenant and cross-tenant cursor replays, and CAS rollback to A.

**Pinned independent oracle.** Phase 0 commits `test/golden/phase_57_rollout_timeline.tbl`,
`test/golden/phase_57_cursor_expectations.json`, and `test/golden/phase_57_access_matrix.tbl`. The timeline
requires `B watermark reached < first B traffic < old drain`; the cursor table fixes accepted sequence ids
without consulting the projector implementation; the access matrix pairs owner success with same-tenant
non-owner and equal-shaped foreign-tenant denials.

**Real authority provenance.** After A is ready, Keycloak mints distinct least-privilege sessions for tenant
A's owner/non-owner and tenant B's owner. Tenant, owner, membership, and scope epochs are derived from those
sessions; caller-supplied values never seed the rollout, cursor, or access oracle. Unavailable or stale
Keycloak provenance makes the gate fail closed.

**Fresh challenge and outside observations.** After A is serving, the harness issues fresh nonces before,
during, and after the shift. A read-only Kubernetes/API observer records immutable release/pointer history;
Gateway API status and Envoy access logs record actual backend selection; a separately implemented native
Pulsar consumer records broker message ids and B's watermark; and a browser-network proxy records plan ids,
reload responses, and resume cursors. Each accepted nonce must appear exactly once in the authoritative
workflow/data observation and in the owner projection. Missing or self-reported evidence fails closed.

**Security and stale-state negatives.** The same-tenant non-owner and tenant-B owner each replay tenant A's
cursor and handle and observe the same denial with zero provider effect or subscription movement. An A client
invoking a changed B port receives either a compatibility-admitted response or `ReloadRequired`; it can never
execute by digest omission. Caller-supplied tenant, owner, release, or watermark values are hostile inputs.
Rollback must not retag a cursor or projection to another subject or tenant scope.

**Bypass probes.** The browser-network harness sends the stale A plan directly to B's action endpoint and a
foreign-owner and foreign-tenant cursors directly to the projector service, bypassing route visibility and
normal reconnect code. The action journal and native broker observer must show zero forbidden effect, and a
named caller Pod using each real user session must be denied direct UI-server Pod, projector Service, Pulsar,
MinIO, and SQL paths. CNI flow records and provider authentication/audit—not client error text—decide the
result.

**Committed mutants.** `test/mutants/phase_57_shift_before_watermark.dhall` must fail the external timeline,
and `test/mutants/phase_57_discard_resume_cursor.dhall` must fail the independent broker/browser sequence
predicate. `test/mutants/phase_57_drop_tenant_cursor_key.patch` must leak or advance the equal-shaped
foreign-tenant cursor and fail the access/broker oracle. A hardcoded success page cannot reproduce the
post-start nonce across the API, broker, gateway, and browser observers.
`test/mutants/phase_57_stale_redis_registration.patch` keeps an A registration routable after drain and must
fail the backend/Redis/cursor timeline.

## Doctrine adopted

- Adopt [`release_lifecycle_doctrine.md` §5 — readiness-gated rollout](../documents/engineering/release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply): move only immutable release pointers and ordered gateway weights.
- Adopt [`low_code_ui_runtime_doctrine.md` §15 — versioning and rollout](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): enforce exact plan/contract epochs or checked compatibility.
- Adopt [`pulsar_client_doctrine.md` §5.1 — TableView projection](../documents/engineering/pulsar_client_doctrine.md#51-two-derived-capabilities-read-model-and-two-deliberately-absent-ones): catch up and resume owner-scoped projections.
- Adopt [`testing_doctrine.md` §12 — spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): observe the transition through independent live observers.
- Adopt [`ui_realtime_coordination_doctrine.md §7`](../documents/engineering/ui_realtime_coordination_doctrine.md#7-replicas-drain-rollout-and-gateway-migration): drain connection ownership and preserve cursor/ABI compatibility without sticky sessions.

## Sprints

## Sprint 57.1: Execute and verify the coherent UI release transition 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Ui/ReleaseTransition.hs`, `src/Amoebius/Ui/Realtime/Drain.hs`, `test/live/Phase57UiRolloutSpec.hs` (planned; not built)
**Blocked by**: Phases 40, 55, and 56
**Independent Validation**: `cabal test phase57-ui-rollout-reconnect` against real Keycloak authority, pinned
timeline/access/cursor tables, and broker/browser/API/CNI observations
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/engineering/release_lifecycle_doctrine.md`, `documents/engineering/pulsar_client_doctrine.md`, `documents/engineering/ui_realtime_coordination_doctrine.md`

### Objective

Deliver one coherent, reversible UI release transition with scope-preserving reconnect.

### Deliverables

- Release-A/B compatibility and projector-watermark admission.
- Ordered Gateway API shift, stale-client handling, cursor resume, and CAS rollback.
- Real three-principal/two-tenant authority plus external API/Gateway/Pulsar/browser/CNI traces with fresh
  nonces.
- Early-shift, cursor-discard, and tenant-cursor-key mutants.
- Draining connection-registration lifecycle and stale-registration mutant.

### Validation

1. Run `cabal test phase57-ui-rollout-reconnect` on `linux-cpu`; the canonical transition must match all
   independent timeline, authority, scope, and bypass predicates and all three mutants must fail at their
   pinned locus.

### Remaining Work

The whole sprint is planned; no live rollout evidence exists.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/release_lifecycle_doctrine.md` — record the coherent rollout/rollback evidence.
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record stale-plan and compatibility behavior.
- `documents/engineering/pulsar_client_doctrine.md` — record watermark and cursor-resume evidence.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record program/ABI-bound connection drain
  and non-sticky reconnect behavior.

**Cross-references to add:**
- The phase tracker, substrate map, and component inventory must link this transition and ledger.

## Related Documents

- [Development Plan](README.md)
- [Phase 40 — atomic UI program release](phase_40_ui_program_release.md)
- [Phase 56 — multi-tenant UI](phase_56_ui_multi_tenant_live.md)
- [Release Lifecycle Doctrine](../documents/engineering/release_lifecycle_doctrine.md)
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
