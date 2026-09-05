# UI Realtime Coordination

> **Purpose**: Define the browser transport, cross-pod WebSocket-routing protocol, ephemeral Redis topology,
> and durable replay boundary that let replicated amoebius UI servers remain stateless for correctness.
> **Read this if**: a live connection has to survive a reconnect, or cross-pod message routing has to be reasoned about.

This document owns realtime coordination for replicated application servers: one authenticated same-origin
connection, ephemeral cross-pod routing, and the resume envelope that makes sticky sessions unnecessary for
correctness. It does not own durable truth, which never lives in the ephemeral plane and belongs to the
message bus and projections; nor the application language above it, owned by
[low_code_ui_runtime_doctrine.md](./low_code_ui_runtime_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, README.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/extension_conformance_security.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Every phase-run or implementation-result statement in this document is permanently invalidated diagnostic history. It cannot establish or reactivate current status, even if a phase later advances. Target doctrine remains normative; current status is solely in the [tracker](../../DEVELOPMENT_PLAN/README.md).

## Contents
- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. Ownership and non-overlap](#2-ownership-and-non-overlap)
- [3. One browser transport contract](#3-one-browser-transport-contract)
- [4. Typed routing and resume envelope](#4-typed-routing-and-resume-envelope)
- [5. Redis is ephemeral platform-internal coordination](#5-redis-is-ephemeral-platform-internal-coordination)
- [6. Durable commands, receipts, and replay](#6-durable-commands-receipts-and-replay)
- [7. Replicas, drain, rollout, and gateway migration](#7-replicas-drain-rollout-and-gateway-migration)
- [8. Resource, observability, and failure obligations](#8-resource-observability-and-failure-obligations)
- [9. Honesty and planning ownership](#9-honesty-and-planning-ownership)
- [Related Documents](#related-documents)

---

Phase order, implementation status, and validation gates live only in
[`DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md). This doctrine states target architecture;
it does not claim that the runtime or its failure behavior is implemented.

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

[Phase 40](../../DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md) owns the pure paired-plan and finite-demand
compiler that fixes this envelope's generated location. Its typed Haskell cases, independent reference
relation, five-calculus projection, and six production mutants constrain compilation without executing
WebSockets, Redis routing, resume, or cross-pod dispatch. Its status remains owned solely by the development
plan and qualified gate.

[Phase 42](../../DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md) is limited to hardware-free Haskell
browser-interpreter semantics and lazy projection. It must not start a browser, fake server, network service,
or OS-policy observer before the Phase-49 gate barrier. Live same-origin WebSocket behavior belongs to a
later phase. Phase 42 is **NOT VALIDATED**.

[Phase 43](../../DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md) is limited to a Haskell server-boundary model
and Haskell-owned fakes. Its eventual contract must admit the exact signed-credential/current-scope case and
refuse minimally different twins without starting a browser, network service, or OS observer. Live server
admission, Redis routing, resume, durable receipts, cross-pod dispatch, replica drain, and failover belong
after the Phase-49 barrier. Phase 43 is **NOT VALIDATED**.

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

**Phase-63 target coordination boundary — NOT VALIDATED.** One TLS-only primary, two TLS replication
followers, and three mutually authenticated Sentinel voters must use Vault-issued certificate and ACL
material. A least-authority `realtime` identity must write a TTL-bound `amoebius:*` challenge, read it from a
replica, force Sentinel promotion, and observe the challenge after failover. Live args and volume inventory
must show finite memory, client, and output-buffer limits with no PVC/AOF/RDB/backup. This targets the
coordination substrate only;
application-side WebSocket routing, durable cursor repair, and command receipts remain owned by their later
UI-runtime phases.

**Phase-64 target browser-edge boundary — NOT VALIDATED.** Independently of Redis routing, a valid Keycloak bearer,
exact `https://phase32.amoebius.internal` Origin, fresh single-use nonce, and `amoebius.v1` subprotocol
must receive HTTP 101 and the committed challenge. Replayed nonce, wrong Origin, wrong subprotocol,
unauthenticated, and direct-Service attempts must produce no backend challenge. This targets the one-door
handshake and bypass denial; replicated UI-server ownership, reconnect, and durable receipt behavior remain
later-phase obligations.

---

## 6. Durable commands, receipts, and replay

A `Command` in this section is the server's own value, and the distinction is normative: what a client submits
is an **intent**, and a `Command` exists only once the server has validated it
([Browser Offline Runtime §9](./browser_offline_runtime_doctrine.md#9-authoritative-replay-and-typed-outcomes)).
That is [`extension_conformance_security.md` §S1](./extension_conformance_security.md#s1-authentication-is-an-index-not-a-check)
at this seam — attestation is an index, and the client cannot produce a value at it.

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

[Phase 70](../../DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md) must validate this receipt primitive live.
The original scoped command must survive native CBOR publication, redelivery, workflow work-id/handle
retention, and compacted receipt materialization. Only effect-owner accepted/terminal events may advance it;
equal command and input must be idempotent, while changed input must conflict before effect. Owner-keyed
cursors must repair a non-final resume, and stale scope epochs must fail closed. Redis and WebSocket delivery
are deliberately outside this target gate.

---

## 7. Replicas, drain, rollout, and gateway migration

`UiRuntimeServer` is an unelected horizontally scalable worker. At least two ready replicas are required by the
first live cross-pod routing gate; Phase 84's multi-zone HA claim requires at least three admitted UI-server
replicas across at least three zones. Neither condition makes the control-plane admin REST service replicated;
that service remains on the `replicas=1` control-plane daemon.

There is no sticky-session correctness dependency. A connection-owning pod registers presence only after its
plan/ABI/handler admission and WebSocket authentication complete. During drain it stops accepting new
connections, emits a reconnect control frame where possible, removes or expires its registrations, and lets
clients reconnect to any ready replica. Rolling overlap retains every plan/ABI and cursor decoder needed by
the admitted compatibility window.

[Phase 72](../../DEVELOPMENT_PLAN/phase_72_ui_program_release.md) must eventually validate the admission
identity boundary: the paired plan pins the WebSocket subprotocol, routing-envelope schema, and cursor codec
alongside program, content, contract, and authority identities, and stale or mixed tuples fail before effect.
Its bounded target cannot establish multiple UI-server replicas, socket drain, rolling overlap, or reconnect.
Phase 72 is **NOT VALIDATED**.

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
Phase 56.1 owns only the target acceptance criterion that the pinned `redis-server` and `redis-cli` file bytes
are present, SBOM-joined, and executable by absolute path at their pinned archive version in **both**
architectures of the published monocontainer; it cannot establish Redis/Sentinel deployment, coordination,
failover, or realtime availability.

Sequencing, implementation status, and acceptance commands are owned by the
[Development Plan](../../DEVELOPMENT_PLAN/README.md). Online WebSocket/Redis work is integrated into the
existing UI and platform phases so those phases do not depend on the offline work's live half; the
offline language and browser-runtime halves sit in the DSL-validation band and are depended on freely.

The sibling `mattandjames` repository is concrete implementation evidence for the basic
shape: `App.WebSocketPresence` keeps TTL connection presence in Redis and `App.WebSocketFanout` uses Redis
Pub/Sub so a non-owning server replica can reach sockets elsewhere. amoebius generalizes that app-specific
session fanout into typed app/subject/scope/program envelopes and fenced instance routes. The sibling's Redis
replay records and leases are not copied as authoritative receipts; amoebius requires the durable effect-owner
rule in [§6](#6-durable-commands-receipts-and-replay). Sibling code is evidence, not an amoebius test result.

Phase 92 owns a deliberately narrower receipt target: the infernix adapter must make the server-derived
command id the work id, fold the terminal state into the scoped durable receipt, and have a second loopback
server origin recover that receipt from retained MinIO. Exact replay must be effect-free and a mutant that
drops terminal correlation must fail. The target challenge uses real browser and Keycloak sessions plus
retained Pulsar/MinIO and a fresh reference-worker Job, but no Redis or WebSocket failure need be injected and neither mechanism
participates in acceptance. Cross-pod routing, Kubernetes UI replicas, full edge delivery, native-CBOR UI
events, and production inference therefore remain UNVERIFIED. There is always a `linux-cpu` execution option
on each hardware substrate. For pristine Linux, use Incus on Linux or Linux-CUDA, Lima on Apple, and WSL2 on
Windows.

Phase 94 must test the corresponding jitML fold only at a scoped boundary. Its pure routing model must send a
terminal receipt from replica identity B to socket identity A, delete transient route state, and repair exactly
once from the durable receipt while the local-route and Redis-as-receipt mutants fail. Chrome must repeat the
loss and repair sequence across two loopback origins using an independent temporary durable-file record. The
target excludes real Redis, WebSocket, Kubernetes replicas, retained Pulsar/MinIO, and Envoy routes, so those runtime claims and
HA remain UNVERIFIED.

Phase 83's scoped target must add program-epoch registration drain and tenant/owner/stream-keyed cursor resume
to the coordination kernel. An append-only local observer must confirm watermark-before-shift ordering across
A→B→A, and all four semantic mutants must turn red. Real Redis registrations, Gateway API/Envoy traffic, Pulsar,
browser reconnect, Kubernetes, CNI, and provider fault observations remain UNVERIFIED.

Phase 84's scoped target must test admission for one-primary/two-replica/three-Sentinel-shaped ephemeral Redis,
reject Redis as receipt authority, and preserve one durable receipt and cursor across a host-local role
failure. Real Redis/Sentinel, complete provider-zone, Kubernetes-endpoint, and external-observer failures are
not covered; online multi-zone HA remains UNVERIFIED.

Phase 85's scoped replay path must physically drop a response after a durable SQLite effect/receipt commit,
clear transient route state, and recover the same receipt through another loopback UI endpoint. Exact retry
must not duplicate the effect, and Redis-only acknowledgement remains inadmissible. Real Redis/Pulsar and
provider observers remain UNVERIFIED.

Phase 88's scoped campaign must reconnect Chrome through a surviving host-local endpoint after stopping
another, clear transient route state, and recover cursor and receipts from SQLite with one effect per command.
This targets non-sticky/durable-repair behavior but not provider zones or real Redis/Sentinel, which remain
UNVERIFIED.

---

## Related Documents
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
