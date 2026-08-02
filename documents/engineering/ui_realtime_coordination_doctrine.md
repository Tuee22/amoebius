# UI Realtime Coordination

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_20_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_21_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_22_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_25_base_image_registry.md, DEVELOPMENT_PLAN/phase_31_platform_services_2.md, DEVELOPMENT_PLAN/phase_32_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_38_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_40_ui_program_release.md, DEVELOPMENT_PLAN/phase_50_infernix_ui_lift.md, DEVELOPMENT_PLAN/phase_52_jitml_ui_lift.md, DEVELOPMENT_PLAN/phase_55_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_56_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_57_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_58_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_61_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_64_offline_multizone_continuity.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

> **Purpose**: Define the browser transport, cross-pod WebSocket-routing protocol, ephemeral Redis topology,
> and durable replay boundary that let replicated amoebius UI servers remain stateless for correctness.

Phase order, implementation status, and validation gates live only in
[`DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md). This doctrine states target architecture;
it does not claim that the runtime or its failure behavior is implemented.

---

## 1. Why this doctrine exists

A browser connection terminates at one UI-server pod, while the event that should reach it may be observed by
another pod. Local connection maps therefore lose delivery when origin and destination differ, and sticky
sessions merely hide the defect until a pod drains or fails. Persisting command outcomes in that routing layer
creates a second application database whose failover semantics can disagree with the provider that performed
the effect.

Pulsar is the durable event backbone, but exposing its native protocol or credentials to a browser would cross
the UI-server authority boundary. Using Pulsar's WebSocket proxy would also create a second browser protocol
and bypass the sealed `UiServerPlan` dispatch path.

amoebius therefore uses one authenticated same-origin WebSocket between browser and UI server, Redis for
short-lived connection ownership and cross-pod fanout, and durable provider/Pulsar state for replay and command
receipts. Redis routes live work; it never decides whether durable work happened.

This choice gives up continuity of an individual socket when Redis or its owning pod fails. The client must
reconnect and resume from a checked cursor; correctness cannot depend on retaining the socket.
"Stateless" therefore means **stateless for durable application correctness**, not literally memoryless: the
pod that terminates a socket necessarily holds an ephemeral local connection registry and output buffers.
Those may disappear at any time without losing authority, accepted effects, receipts, or replayable events.

---

## 2. Ownership and non-overlap

This document owns:

- the browser HTTPS/WebSocket transport split;
- the authenticated WebSocket handshake and typed envelope;
- Redis's platform-internal role, topology, TTL discipline, and failure semantics;
- cross-pod connection routing, fanout, drain, and reconnect; and
- the boundary between lossy routing hints and durable command/event replay.

The bounded UI language, ports, plans, authorization, and tenant semantics remain owned by
[Low-Code UI Runtime](./low_code_ui_runtime_doctrine.md). Native Pulsar framing, CBOR payloads, deduplication,
and durable subscriptions remain owned by [The Native Pulsar Client](./pulsar_client_doctrine.md). Redis is a
standard platform implementation service governed by [Platform Services](./platform_services_doctrine.md),
not an application capability in [Service Capabilities](./service_capability_doctrine.md). Offline browser
persistence and outbox replay are owned by [Browser Offline Runtime](./browser_offline_runtime_doctrine.md).

---

## 3. One browser transport contract

The browser-facing protocol has two fixed parts:

- **HTTPS** serves OIDC callbacks, session bootstrap, immutable assets, plan envelopes, uploads, downloads,
  and platform-owned health endpoints.
- **One authenticated same-origin WebSocket** carries typed port requests, completions, subscription events,
  cursor acknowledgements, replay outcomes, and server control messages.

There is no application-authored transport selection, URL, subprotocol, topic, Redis key, or fallback to direct
Pulsar/provider access. The Gateway API route admits an HTTP upgrade only for the UI-server backend after the
same Keycloak-owned edge, host, TLS, Origin, and session checks as HTTPS. SSE is not a second supported UI
transport; an environment that blocks WebSockets receives a typed unavailable/retry result rather than a
semantically different path.

The HTTP upgrade validates the secure HTTP-only same-origin session cookie, exact allowed `Origin`, and a fixed
versioned subprotocol. Because the browser WebSocket API cannot attach a private arbitrary authorization
header, the upgraded socket remains quarantined until its first typed `Register` frame presents an
unpredictable session-bound nonce obtained over HTTPS. The session authority atomically consumes that nonce
and rechecks the current subject, tenant, membership, policy, program, and scope epochs before the connection
becomes routable. Any Redis nonce copy is only a disposable cache: cache loss fails closed, and a failover that
forgets a cache write cannot bypass the authoritative consume/current-session check. Browser-visible bearer
and refresh tokens are absent.

---

## 4. Typed routing and resume envelope

Every routed frame carries an envelope equivalent to:

```haskell
data UiRealtimeEnvelope = UiRealtimeEnvelope
  { application    :: AppId
  , session        :: SessionId
  , subjectEpoch   :: SubjectEpoch
  , scope           :: ScopeId
  , scopeEpoch      :: ScopeEpoch
  , program         :: ProgramDigest
  , uiServerAbi     :: UiServerAbi
  , stream          :: StreamId
  , cursor          :: Maybe StreamCursor
  , request         :: Maybe RequestId
  , payload         :: PublicUiPayload
  }
```

The concrete encoding may differ, but none of the identity/epoch fields may be omitted. Redis channel names and
keys are derived from server-validated opaque identities; no browser field becomes a Redis key or authorization
fact. A receiving pod exact-matches the envelope against its admitted plan and current connection registry
before delivery. A cross-application, cross-subject, cross-tenant, stale-scope, stale-program, or stale-ABI
envelope is discarded and audited without revealing whether the target exists.

On registration, the socket-owning pod creates a random `ConnectionId`, records it only in its local registry,
and refreshes a TTL-bound Redis route to a fenced `UiServerInstance` identity derived from the pod UID and boot
epoch. Each admitted subscription also refreshes a bounded trusted
`(AppId, ScopeId, ScopeEpoch, StreamId) -> Set ConnectionId` membership index. A sending pod resolves that
index and the per-connection routes, then publishes to the owning instances' channels; only those instances can
join the targets to local sockets. Missing/stale routes, instance restarts, and route-change races produce no
guessed delivery and fall through to the durable repair rules below. A small fixed broadcast channel may carry
bounded drain/revocation controls, but application payload fanout is scope-checked even when more than one pod
observes the notification.

Each durable event stream is monotonically sequenced and cursor-addressable. Redis Pub/Sub is a lossy wake-up
hint: a gap, reconnect, ownership change, or suspected loss triggers repair from the authoritative Pulsar
subscription or projection beginning at the last server-validated cursor. A bounded heartbeat/reconciliation
interval compares each active stream's delivered cursor with its durable high-water mark, so losing the last
Pub/Sub notification cannot leave an otherwise quiet connection stale forever. Duplicate events are folded
by stream identity and cursor. A Redis publish acknowledgement is never a delivery or durability receipt.

---

## 5. Redis is ephemeral platform-internal coordination

`UiRealtimeCoordination` is a platform-internal facility, not a `Capability`/`UiSource` arm. Its admitted data
classes are closed:

- TTL-bound BFF session material and revocation-sensitive cache entries whose authority remains Keycloak and
  current server policy;
- connection presence and `ConnectionId -> UiServerInstance` routing;
- bounded app/scope/epoch/stream subscription membership indexes containing opaque connection identities;
- Pub/Sub fanout and drain/control notifications;
- bounded rate-limit counters; and
- optional short-lived `RequestId -> waiting ConnectionId` correlations.

Redis must not contain authoritative application rows, workflow state, object metadata, tenant/membership
truth, policy truth, durable subscription cursors, command receipts, or command outcomes. Every key class has a
finite TTL or an instance-ownership cleanup rule, a scope prefix derived from trusted server context, a maximum
serialized size, and an aggregate cardinality/rate budget.

The standard distributed shape is one writable primary, at least two replicas, and three Sentinel voters
spread across admitted failure domains. It uses TLS certificates and least-authority Redis ACL credentials
issued or delivered through Vault, default-deny
NetworkPolicy, explicit client/output-buffer/command-rate/memory bounds, and a failover/reconnect budget. It has
no PVC, AOF, RDB snapshot, backup, or durability claim. The one-node projection retains the same roles and
configuration contract but makes no HA claim.

Redis may be flushed, restarted, or fail over while durable providers remain intact. The permitted outcome is
socket closure, cache loss, reauthentication, bounded reconnect, and cursor repair. A duplicated or missing
durable effect is not permitted. If Redis loss can change whether an application command was accepted, the
command path is incorrectly designed.

---

## 6. Durable commands, receipts, and replay

Every mutating or workflow-starting request carries an opaque client `RequestId`. After current authentication,
membership, authorization, program/ABI, port, and input validation, the UI server derives a scope-qualified
`CommandId` from `(AppId, TenantId, Owner, PortId, RequestId)`. The client id is correlation, not authority;
different replicas derive the same command identity only after the same trusted context validates. Each
request also has an idempotency contract and an authoritative receipt path colocated with or derived from the
effect owner:

| Effect owner | Authoritative acceptance/receipt rule |
|--------------|---------------------------------------|
| SQL transaction | Effect and receipt commit in the same database transaction. |
| Pulsar/workflow command | Producer resends use broker dedup; consumer redelivery uses the work-id-keyed idempotent fold. The effect worker durably records the scoped result in a compacted receipt projection queryable by every UI-server replica. |
| Object mutation | The object provider's conditional write/CAS identity decides acceptance; the durable result projection records the observed version. |
| Other typed handler | The handler contract names an equally coherent durable idempotency/receipt mechanism before binding succeeds. |

For a workflow command, that server-derived scoped `CommandId` is also the application work-id carried
unchanged in the canonical Pulsar command, every progress/terminal event, the `WorkflowHandle`, and the
compacted receipt key.
The terminal event supplies the effect-owner outcome folded into that receipt. A producer sequence id, Pulsar
`MessageId`, pod/run identity, artifact digest, Redis correlation, or replacement UI-server request id cannot
substitute for it. Exact scoped identity plus equal normalized input returns the same receipt; equal identity
plus different normalized input is a typed pre-effect conflict.

Redis may wake the pod waiting for a receipt, but it cannot be the only place the receipt or outcome exists.
After reconnect—or after a bounded delivery timeout while the socket remains open—any replica can query the
authoritative receipt/projection and return the same typed outcome. An unknown outcome remains
`Pending`/`Unknown` until authoritative state resolves it; the server never guesses success from a prior
socket write. "Effectively once" is earned only by the named idempotency/fold contract at the effect owner;
Pulsar delivery and Redis routing do not provide a generic exactly-once side-effect guarantee.

---

## 7. Replicas, drain, rollout, and gateway migration

`UiRuntimeServer` is an unelected horizontally scalable worker. At least two ready replicas are required by the
first live cross-pod routing gate; Phase 58's multi-zone HA claim requires at least three admitted UI-server
replicas across at least three zones. Neither condition makes the control-plane admin REST service replicated;
that service remains on the `replicas=1` singleton.

There is no sticky-session correctness dependency. A connection-owning pod registers presence only after its
plan/ABI/handler admission and WebSocket authentication complete. During drain it stops accepting new
connections, emits a reconnect control frame where possible, removes or expires its registrations, and lets
clients reconnect to any ready replica. Rolling overlap retains every plan/ABI and cursor decoder needed by
the admitted compatibility window.

During a planned gateway migration, the old edge forwards WebSocket upgrades and frames until the drain edge
is observed or closes connections with a reconnect reason that causes same-hostname resolution. During forced
failover, sockets are expected to break; clients reconnect through the same active hostname and repair from
durable cursors. Redis state is cluster-local and is not geo-replicated as application truth.

---

## 8. Resource, observability, and failure obligations

Provisioning accounts for UI-server replicas, connection counts, per-connection inbound/outbound buffers,
subscription counts, frame sizes, heartbeats, handshake nonce cardinality, Redis keys/memory/client buffers,
Pub/Sub fanout rate, Sentinel members, reconnect storms, cursor-repair reads, and old/new rollout overlap.
Bounds are derived from deployment policy and the admitted application plan; none defaults to unbounded.

Metrics include active/routable/draining connections, connection registrations by instance, rejected envelope
reasons, fanout publishes/deliveries, cursor gaps/repairs, replay latency, Redis memory/client-buffer pressure,
Sentinel failover state, reconnect rate, and authoritative receipt lookup outcomes. Logs contain opaque scoped
identities and epochs, never credentials or public payload bodies.

Required negative gates include sticky-only routing, pod-local-only fanout, Redis as sole receipt store, a
Redis loss that duplicates an effect, an unrepaired Pub/Sub gap, a cross-scope routed frame, an unbounded key or
buffer class, and a one-zone topology described as HA. Live gates observe the provider/Pulsar effect boundary,
not only UI-server or Redis self-reports.

---

## 9. Honesty and planning ownership

The routing and failure semantics above are design intent until their phase gates run. Multiple replicas and
Sentinel configuration are topology evidence, not availability proof. A live fault test may establish tested
behavior for its declared envelope; it does not prove behavior for every network partition or Redis defect.

Sequencing, implementation status, and acceptance commands are owned by the
[Development Plan](../../DEVELOPMENT_PLAN/README.md). Online WebSocket/Redis work is integrated into the
existing pre-Phase-59 UI and platform phases so those phases do not depend on later offline work.

The sibling `/home/matthewnowak/mattandjames` repository is concrete implementation evidence for the basic
shape: `App.WebSocketPresence` keeps TTL connection presence in Redis and `App.WebSocketFanout` uses Redis
Pub/Sub so a non-owning server replica can reach sockets elsewhere. amoebius generalizes that app-specific
session fanout into typed app/subject/scope/program envelopes and fenced instance routes. The sibling's Redis
replay records and leases are not copied as authoritative receipts; amoebius requires the durable effect-owner
rule in [§6](#6-durable-commands-receipts-and-replay). Sibling code is evidence, not an amoebius test result.

---

## Cross-references

- [Low-Code UI Runtime](./low_code_ui_runtime_doctrine.md)
- [Browser Offline Runtime](./browser_offline_runtime_doctrine.md)
- [Platform Services](./platform_services_doctrine.md)
- [The Native Pulsar Client](./pulsar_client_doctrine.md)
- [Daemon Topology](./daemon_topology_doctrine.md)
- [Gateway Migration](./gateway_migration_doctrine.md)
- [Service Capabilities](./service_capability_doctrine.md)
- [Resource Capacity](./resource_capacity_doctrine.md)
- [Testing](./testing_doctrine.md)
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
