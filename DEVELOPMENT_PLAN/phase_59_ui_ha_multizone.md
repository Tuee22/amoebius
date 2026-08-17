# Phase 59: Initial online UI multi-zone high availability

> **Purpose**: Establish genuine end-to-end UI availability across provider failure domains with redundant
> stateless UI servers, redundant projectors, resumable streams, and an externally observed live fault.
> **Read this if**: phase 59 is next in the queue, or a later phase depends on what its gate establishes.

Phase 59 delivers the initial online UI multi-zone high availability; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [daemon_topology_doctrine.md](../documents/engineering/daemon_topology_doctrine.md), [platform_services_doctrine.md](../documents/engineering/platform_services_doctrine.md), and the plan for reaching it is owned here.
Register 3, scoped live, on the `linux-cpu → provider` substrate.
The scoped gate passed on 2026-08-11; genuine provider multi-zone HA remains `UNVERIFIED`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: DEVELOPMENT_PLAN/phase_44_spa_live_deploy.md (HA/failover portion)
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — multi-zone UI fault envelope](#resource-provision--multi-zone-ui-fault-envelope)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 59.1: Run the multi-zone UI failure campaign ⏸️](#sprint-591-run-the-multi-zone-ui-failure-campaign-)
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

🟡 Scoped gate passed. Topology admission, fault-scope, post-fault authority, durable repair, a three-role
host-process campaign, and all ten mutation loci pass. Provider multi-zone availability is still
`UNVERIFIED`; replica counts and local roles are not a live HA claim.

## Phase Summary

This phase is the only initial UI phase allowed to claim high availability. It deploys at least three
UI-server replicas across independent zones and at least three projector replicas across the same zones, with the authenticated edge
and required identity/data/workflow services in admitted redundant shapes. An external client continues a
fresh read, idempotent mutation, workflow start, and subscription while a provider-native fault isolates every
node and serving endpoint in one selected availability zone. Killing one Pod or node does not satisfy this
gate. The gate observes that declared whole-zone fault only; it is not a proof against every correlated
provider failure.
Redis follows its distributed one-primary/two-replica/three-Sentinel topology across the admitted zones. The
fault removes the selected-zone Redis/Sentinel members as well as application members; surviving UI servers
reconnect through Sentinel, and any lost Pub/Sub hint repairs from Pulsar/projection cursors. This is the
online HA gate. Offline outbox/blob continuity is not claimed until Phase 64.

**Session scope:** Implement and run one provider multi-zone UI failover campaign with one acceptance command,
`cabal test phase58-ui-ha-multizone`; split if validation adds another provider, substrate, simultaneous-zone
loss model, or disaster-recovery claim.

**Substrate:** `linux-cpu → provider` — the parent drives one managed provider target
([§L](development_plan_standards.md#l-one-substrate-discipline)). Every hardware substrate can always run
`linux-cpu`. When pristine Linux is needed, use Incus on Linux or Linux-CUDA, Lima on Apple, and WSL2 on
Windows.

**Lane:** linux-cpu/amd64 → provider ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Gate:** `cabal test phase58-ui-ha-multizone` provisions the exact redundant topology, runs the declared
whole-zone isolation while an off-cluster authenticated probe exercises the pinned operation and tenant matrix,
and satisfies every external availability, isolation, placement, disruption, reconnect, and mutant predicate in
[Gate integrity](#gate-integrity).

## Gate integrity

**Representative set.** The provider target has at least three schedulable zones, three ready UI-server Pods
with hard topology spread, at least three ready owner-keyed projector Pods across the same three zones, a
PodDisruptionBudget, and non-sticky correctness. Keycloak/Envoy, SQL, MinIO, Pulsar, and the exercised workflow
are deployed in the redundant shapes their owning phases admit, with the gate refusing if a required dependency
has all serving members in the selected fault zone. Tenant A contains owner and non-owner subjects; tenant B
contains a foreign owner with equal-shaped ids, data, action, and cursor. The inventory is captured from the
Kubernetes and provider APIs before traffic begins.
Redis has one primary, at least two replicas, and three Sentinel voters spread across the zones with no
persistent volume. Its loss may close sockets but cannot change durable effects or cursor repair.

**Pinned oracle and budgets.** Phase 0 commits `test/golden/phase_59_ha_timeline.tbl`,
`test/golden/phase_59_placement.tbl`, `test/golden/phase_59_access_matrix.tbl`, and
`test/golden/phase_59_post_fault_authority.tbl`. They independently fix the failure trigger, complete
selected-zone member set, maximum login/reconnect window, post-fault OIDC and membership/epoch outcome,
read/mutation/workflow/subscription outcomes, accepted-action rule, minimum zone distribution, and paired
same-owner/same-tenant-non-owner/foreign-tenant outcomes. The implementation cannot widen those budgets after
observing a run.

**Fresh live operation matrix.** An off-cluster Playwright/API probe obtains distinct least-privilege OIDC
sessions for tenant A's owner/non-owner and tenant B's owner. It primes an owner-scoped stream, then invokes a
provider-native fault that isolates every node and serving endpoint in the selected zone as one fault domain.
While provider/API evidence says the whole zone is isolated, a cookie-empty browser context completes a new
OIDC authorization-code/PKCE login for tenant A's owner and the UI server re-reads current membership and scope
epoch before issuing the new session. The probe then uses post-fault authority to issue fresh challenges for a
bounded read, idempotent mutation, and workflow start and keeps the subscription active. The same stable origin
must authenticate/respond/reconnect within pinned bounds; every accepted mutation/start nonce must reach
authoritative Pulsar/data observations exactly once; the read must return the current challenged version; and
the stream must resume without owner, tenant, cursor, or sequence change. A pre-fault cookie, cached membership,
or replayed token cannot satisfy the post-fault authority row.

**External observers and paired denial.** A provider read-only API identity confirms that every predeclared
member and endpoint in the selected zone is isolated, not merely one node; Kubernetes API watches record
scheduling and endpoint membership; a separate Keycloak event/membership observer records the new post-fault
authorization and current epoch; Envoy logs record identity and backend continuity; an independent native
Pulsar consumer records message ids/cursors; and provider-native SQL/MinIO request/audit readers confirm reads
and effects. During the fault, the same-tenant non-owner and tenant-B owner repeat tenant A's opaque handle,
mutation, workflow start, and cursor and must remain denied with zero forbidden read, dispatch, subscription,
or provider effect. Unavailable or challenge-mismatched authority/observers fail the gate rather than becoming
UNVERIFIED green.

**Bypass probes and mutants.** During the isolated-zone interval, a named caller Pod using each real user
session probes UI-server Pod IPs, the projector Service, SQL, MinIO, Pulsar, Vault, and inference endpoints.
CNI flow logs plus provider authentication/audit must show that only the public Keycloak/Envoy origin is usable;
an HTTP denial alone is insufficient. The gate must turn red for `test/mutants/phase_58_replicas_one.dhall`,
`test/mutants/phase_58_sticky_session_required.dhall`,
`test/mutants/phase_58_drop_pdb.dhall`, and
`test/mutants/phase_58_drop_topology_spread.dhall`, plus
`test/mutants/phase_58_fault_one_node_only.patch` and
`test/mutants/phase_58_drop_tenant_cursor_key.patch`, plus
`test/mutants/phase_58_drop_keycloak_zone_spread.dhall`. Placement/provider observation catches structural or
under-scoped faults; the external login/operation/reconnect trace catches identity unavailability and
sticky-state dependence; and the cross-tenant broker/access oracle catches scope collapse. A Deployment status
claiming three replicas is not placement or availability evidence.
The gate also turns red for `test/mutants/phase_58_redis_one_node.dhall`,
`test/mutants/phase_58_redis_persistent_receipt.patch`, and
`test/mutants/phase_58_skip_cursor_repair.patch`.

## Resource provision — multi-zone UI fault envelope

Before mutation, the provision seal accounts for all UI-server/projector replicas, topology and disruption
constraints, post-fault Keycloak login/membership observation, gateway/auth/data/workflow dependency survival
after removal of every selected-zone member, fault overlap, retry/idempotency buffers, subscription catch-up,
Redis/Sentinel members, connection/key/client/output-buffer demand, failover and reconnect storms, cursor
repair reads, and the external operation matrix. An
unschedulable third zone, one-short post-fault dependency, one-short disruption budget, or unbounded replay
buffer refuses before the first provider or Kubernetes mutation.

## Doctrine adopted

- Adopt [`low_code_ui_runtime_doctrine.md` §14 — runtime role, deployment, and HA](../documents/engineering/low_code_ui_runtime_doctrine.md#14-runtime-role-deployment-and-high-availability): stateless replicas and resumable subscriptions, with no leader election.
- Adopt [`daemon_topology_doctrine.md` §4 — unelected workers](../documents/engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected): scale UI workers without granting control-plane authority.
- Adopt [`platform_services_doctrine.md` §2 — one topology across replica counts](../documents/engineering/platform_services_doctrine.md#2-ha-always--including-replicas1): distinguish an HA-capable shape from an observed HA outcome.
- Adopt [`testing_doctrine.md` §12 — spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): bind the claim to an off-cluster challenge and provider-observed fault.
- Adopt [`ui_realtime_coordination_doctrine.md §§5–8`](../documents/engineering/ui_realtime_coordination_doctrine.md#5-redis-is-ephemeral-platform-internal-coordination): survive one-zone Redis/Sentinel and UI-server loss through bounded reconnect plus durable cursor/receipt repair.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 59.1: Run the multi-zone UI failure campaign ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `src/Amoebius/Ui/Ha/MultiZone.hs`,
`src/Amoebius/Ui/Realtime/RedisCoordination.hs`, `test/live/UiHaSpec.hs`,
`tools/phase58_ui_ha_live.py`, and `tools/phase58_gate.py`
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: `python3 tools/phase58_gate.py`; the scoped topology,
fault, authority, repair, host-process, and mutant predicates are tested. Provider-confirmed zone isolation
and off-cluster observations remain `UNVERIFIED`.
**Docs to update**:
`documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/daemon_topology_doctrine.md`, `documents/engineering/platform_services_doctrine.md`,
`documents/engineering/ui_realtime_coordination_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Deliver one externally observed provider-zone failure result for the complete UI path.

### Deliverables

- Provisioned multi-zone UI-server/projector topology with PDB and hard spread.
- Multi-zone Redis primary/replicas/Sentinel with bounded client reconnect and durable cursor/receipt repair;
  no Redis persistence or sticky-session dependency.
- Off-cluster three-principal/two-tenant OIDC challenge probe, cookie-empty post-fault login/current-membership
  check, and provider-driven whole-zone isolation.
- Read, idempotent mutation, workflow-start, reconnect, exactly-once accepted-action, cursor-resume, and
  same-owner/same-tenant/foreign-tenant denial observations.
- Named structural, behavioral, and security mutants that independently defeat the HA claim.

### Validation

1. Run `python3 tools/phase58_gate.py`; require the scoped canonical run green and
   every named mutant red. The ledger must not promote unavailable provider observations above `UNVERIFIED`.

### Remaining Work

Run the campaign against at least three real provider zones with provider-confirmed whole-zone isolation,
off-cluster fresh OIDC, Gateway/Keycloak, Redis/Sentinel, Pulsar/SQL/MinIO, Kubernetes, CNI, and provider audit
observers. Until then, no provider HA claim exists.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the exact tested fault and bounds.
- `documents/engineering/platform_services_doctrine.md` — distinguish topology parity from observed HA.
- `documents/engineering/daemon_topology_doctrine.md` — record worker failover behavior without election.
- `documents/engineering/testing_doctrine.md` — link the off-cluster challenge and raw observer digests.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record the precise tested Redis/UI-server
  zone-fault envelope and retain the lossy-routing/durable-repair boundary.

**Cross-references to add:**
- The phase tracker, substrate map, and component inventory must identify this as the first UI HA claim.

## Related Documents

- [Development Plan](README.md)
- [Phase 58 — UI rollout and reconnect](phase_58_ui_rollout_reconnect.md)
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
