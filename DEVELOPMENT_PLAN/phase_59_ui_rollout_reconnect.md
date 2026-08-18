# Phase 59: UI rollout, projection catch-up, and reconnect

> **Purpose**: Prove a checked UI program can roll from release A to B and roll back without stale-plan
> effects, premature traffic shift, lost owner-scoped projections, or discarded reconnect cursors.
> **Read this if**: phase 59 is next in the queue, or a later phase depends on what its gate establishes.

Phase 59 delivers the UI rollout, projection catch-up, and reconnect; its design is owned by [release_lifecycle_doctrine.md](../documents/engineering/release_lifecycle_doctrine.md), [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [pulsar_client_doctrine.md](../documents/engineering/pulsar_client_doctrine.md), and the plan for reaching it is owned here.
Register 3, scoped live, on the `linux-cpu` substrate.
The scoped gate passed on 2026-08-11; cluster, browser, and provider observations remain `UNVERIFIED`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: DEVELOPMENT_PLAN/phase_48_spa_live_deploy.md (rollout/reconnect portion)
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_60_ui_ha_multizone.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 59.1: Execute and verify the coherent UI release transition ⏸️](#sprint-591-execute-and-verify-the-coherent-ui-release-transition-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-58 revalidation — **reopened 2026-08-16 by the natural-architecture amendment.**
[§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 15 requires a run to record
the natural architecture it proved and to execute no artifact of another. This phase's last gate recorded no
architecture, so its seal is invalidated as a current result and stands only as history; the rerun differs from
it by naming the lane and architecture the run actually used. A sprint marker below records what that sprint achieved before the amendment; under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) it is a diagnostic, not surviving closure.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Blocked (superseded) — containment amendment recorded 2026-08-15. Any earlier capability seal is historical and
invalidated until this phase reruns in numerical order with all amoebius-owned state confined to the
repository roots defined by Phase 0. Scope amendments below remain normative.

**Pre-containment status record (invalidated where it claims completion):**

Blocked (superseded) by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish repository-local evidence without changing an authored path.

**Invalidated historical record:**

🟡 Scoped gate passed. The transition kernel, cursor isolation, registration drain, host-local durable
observers, and all four mutation loci pass. Real Keycloak, Gateway API/Envoy, Pulsar, browser, Kubernetes,
CNI, and provider observations remain `UNVERIFIED`.

## Phase Summary

This phase owns one live release transition: projectors catch up to B's recorded watermark, the gateway shifts
traffic only afterward, old and new plan/ABI identities coexist only under a checked compatibility witness,
subscriptions resume from owner-scoped cursors, and rollback returns to A's immutable release. It does not
claim replica or zone failure tolerance; Phase 60 owns that fault boundary.
Connection registrations and routed envelopes carry the admitted program/ABI epoch. Draining replicas stop
accepting sockets, remove or expire Redis registrations, issue a bounded reconnect control frame, and retain
old decoders until their compatibility window closes.

**Session scope:** Implement and validate the single `A → B → A` UI release transition with one acceptance
command, `cabal test phase57-ui-rollout-reconnect`; split if the work introduces another rollout algorithm,
substrate, or infrastructure-failure injection.

**Substrate:** `linux-cpu` ([§L](development_plan_standards.md#l-one-substrate-discipline)). Every hardware
substrate can always run `linux-cpu`. When the gate needs a pristine Linux host, use Incus on Linux or
Linux-CUDA, Lima on Apple, and WSL2 on Windows.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

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

**Pinned independent oracle.** Phase 0 commits `test/golden/ui_rollout_reconnect/rollout_timeline.tbl`,
`test/golden/ui_rollout_reconnect/cursor_expectations.json`, and `test/golden/ui_ha_multizone/access_matrix.tbl`. The timeline
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

**Committed mutants.** `test/mutant/ui_rollout_reconnect/shift_before_watermark.dhall` must fail the external timeline,
and `test/mutant/ui_rollout_reconnect/discard_resume_cursor.dhall` must fail the independent broker/browser sequence
predicate. `test/mutant/ui_rollout_reconnect/drop_tenant_cursor_key.patch` must leak or advance the equal-shaped
foreign-tenant cursor and fail the access/broker oracle. A hardcoded success page cannot reproduce the
post-start nonce across the API, broker, gateway, and browser observers.
`test/mutant/ui_rollout_reconnect/stale_redis_registration.patch` keeps an A registration routable after drain and must
fail the backend/Redis/cursor timeline.

## Doctrine adopted

- Adopt [`release_lifecycle_doctrine.md` §5 — readiness-gated rollout](../documents/engineering/release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply): move only immutable release pointers and ordered gateway weights.
- Adopt [`low_code_ui_runtime_doctrine.md` §15 — versioning and rollout](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): enforce exact plan/contract epochs or checked compatibility.
- Adopt [`pulsar_client_doctrine.md` §5.1 — TableView projection](../documents/engineering/pulsar_client_doctrine.md#51-two-derived-capabilities-read-model-and-two-deliberately-absent-ones): catch up and resume owner-scoped projections.
- Adopt [`testing_doctrine.md` §12 — spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): observe the transition through independent live observers.
- Adopt [`ui_realtime_coordination_doctrine.md §7`](../documents/engineering/ui_realtime_coordination_doctrine.md#7-replicas-drain-rollout-and-gateway-migration): drain connection ownership and preserve cursor/ABI compatibility without sticky sessions.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 59.1: Execute and verify the coherent UI release transition ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `src/Amoebius/Ui/ReleaseTransition.hs`,
`src/Amoebius/Ui/Projection/Cursor.hs`, `src/Amoebius/Ui/Realtime/Drain.hs`,
`test/spec/live/UiRolloutSpec.hs`, `tools/ui_rollout_reconnect_live.py`, and `tools/ui_rollout_reconnect_gate.py`
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: `python3 tools/ui_rollout_reconnect_gate.py`; scoped transition,
cursor, registration, fresh-journal, durable reconnect, and mutant observations are tested. Real Keycloak,
Gateway/Pulsar/browser/API/CNI observations remain `UNVERIFIED`.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/release_lifecycle_doctrine.md`, `documents/engineering/pulsar_client_doctrine.md`,
`documents/engineering/ui_realtime_coordination_doctrine.md`

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

1. Run `python3 tools/ui_rollout_reconnect_gate.py` on `linux-cpu`; the scoped canonical
   transition must match the pinned custody and local timeline/cursor/scope predicates, all four mutants must
   fail at their pinned loci, and unsupported provider observations must remain `UNVERIFIED`.

### Remaining Work

Run the same transition through real Keycloak sessions, Gateway API/Envoy access logs, a native Pulsar
watermark observer, a browser-network proxy, Kubernetes audit, and CNI/provider zero-effect observations.
Those surfaces are deliberately `UNVERIFIED`; the scoped local gate does not substitute for them.

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
- [Phase 45 — atomic UI program release](phase_45_ui_program_release.md)
- [Phase 58 — multi-tenant UI](phase_58_ui_multi_tenant_live.md)
- [Release Lifecycle Doctrine](../documents/engineering/release_lifecycle_doctrine.md)
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
