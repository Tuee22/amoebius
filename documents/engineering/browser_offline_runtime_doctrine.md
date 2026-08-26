# Browser Offline Runtime

> **Purpose**: Define the bounded DSL, paired plans, encrypted browser facilities, authentication states,
> authoritative replay protocol, and release obligations for offline-capable amoebius applications.
> **Read this if**: an application has to keep working without a network, or queued work has to be replayed safely.

This document owns bounded offline continuity: what a specification may declare offline, the encrypted local
store, and the rule that queued intent carries no execution authority and is re-decided by the server on
replay. It does not own the online runtime it pairs with, owned by
[low_code_ui_runtime_doctrine.md](./low_code_ui_runtime_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/extension_conformance_security.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/illegal_state/illegal_state_techniques.md, documents/illegal_state/illegal_state_tenancy.md
**Generated sections**: none

</details>

## Contents
- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. Scope and adjacent owners](#2-scope-and-adjacent-owners)
- [3. The external continuity surface](#3-the-external-continuity-surface)
- [4. Queueable ports are a stricter port class](#4-queueable-ports-are-a-stricter-port-class)
- [5. One bound program, paired online and offline plans](#5-one-bound-program-paired-online-and-offline-plans)
- [6. Closed browser facilities and encrypted storage](#6-closed-browser-facilities-and-encrypted-storage)
- [7. Offline identity and partitioning](#7-offline-identity-and-partitioning)
- [8. One active tab owns connection and replay](#8-one-active-tab-owns-connection-and-replay)
- [9. Authoritative replay and typed outcomes](#9-authoritative-replay-and-typed-outcomes)
- [10. Offline blobs](#10-offline-blobs)
- [11. Release, schema, and compatibility horizon](#11-release-schema-and-compatibility-horizon)
- [12. Deployment policy, resources, and honesty](#12-deployment-policy-resources-and-honesty)
- [Related Documents](#related-documents)

---

Phase order, implementation status, and validation gates live only in
[`DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md). This doctrine states the offline target
contract; it does not claim that browser persistence or replay is implemented.

## 1. Why this doctrine exists

An in-memory-only application loses pending user intent and useful projections when connectivity disappears.
Adding ad hoc IndexedDB records or a service worker does not solve the semantic problem: a stale browser can
queue an unauthorized intent, replay it twice from two tabs, expose another tenant's cached data, or become
unreadable after the server drops its old decoder.

Treating the browser outbox as authoritative fails because revocation, conflicts, and current provider state
are unavailable offline. Treating `ReloadRequired` as permission to clear local state loses acknowledged user
intent. A useful offline mode therefore needs a checked application contract, a trusted generic persistence
runtime, authoritative idempotent replay, and a release horizon that preserves old data until it is migrated or
resolved.

amoebius adds offline continuity as an explicit `UiSource` choice. The app declares which projections and
ports have offline meaning; trusted runtime plans choose browser mechanisms and server replay handlers. The
browser is authoritative only for the fact that a local pending-intent record exists. It never becomes
authoritative for identity, authorization, acceptance, conflict resolution, or provider effects.

---

## 2. Scope and adjacent owners

This document owns:

- the `UiSource.continuity` surface and queueable-port contract;
- offline client/server plan projections;
- encrypted local storage, service-worker, local-blob, and cross-tab facilities;
- offline authentication states and the opaque local partition handle;
- ordered authoritative replay and typed outcomes;
- offline release/schema/ABI compatibility; and
- offline quotas, isolation, and honest limitations.

[Low-Code UI Runtime](./low_code_ui_runtime_doctrine.md) continues to own the general UI language, port,
authorization, plan, and browser/server trust boundary. [UI Realtime Coordination](./ui_realtime_coordination_doctrine.md)
owns the online WebSocket/Redis path used at reconnect. [Release Lifecycle](./release_lifecycle_doctrine.md)
owns deployment promotion and rollout. [Tenancy](./tenancy_doctrine.md) owns live membership and provider
isolation. This document narrows those mechanisms for temporarily disconnected clients; it does not replace
them.

---

<a id="3-the-authored-continuity-surface"></a>
## 3. The external continuity surface

`UiSource` adds one mandatory closed field:

```dhall
, continuity : < OnlineOnly | Offline : OfflineSource >
```

Conceptually, `OfflineSource` contains:

```dhall
{ projections : List OfflineProjection
, queuedPorts : List QueuedPort
, localBlobs  : List LocalBlobClass
, offlineView : ModuleRef
}
```

The bounded Haskell mirror may use `Projection { projectionId : Text }`,
`BlobClass { blobClassId : Text }`, and a textual `offlineView`. Those identifiers are language-level keys;
schemas, examples, test cases, and serialized browser plans are generated beneath `.build/**` from Haskell.
An operator's actual `UiSource` value remains external or local-untracked input.

`OnlineOnly` preserves the memory-only behavior. `Offline` names semantics only: values that may be projected
locally, ports whose user intent may be queued, blob classes needed before upload, and the bounded view shown
without the network. It cannot name IndexedDB, OPFS, Cache Storage, a service worker, Web Locks,
BroadcastChannel, Redis, WebSocket, a filesystem path, an encryption primitive, or a browser quota.

Every persisted field has a derived information-flow label and an explicit retention/size bound. Binding
requires the deployment's `OfflinePolicy` to permit that label and duration. Credentials, refresh tokens,
private `UiServerPlan` data, provider coordinates, raw policy, server capabilities, and unrestricted response
bodies have no persistable representation.

---

## 4. Queueable ports are a stricter port class

A `QueuedPort` references an existing typed mutating/workflow port and adds a contract equivalent to:

```haskell
data OfflineQueueContract = OfflineQueueContract
  { localValidation      :: AdvisoryValidatorId
  , serverValidation     :: AuthoritativeValidatorId
  , idempotency          :: IdempotencyContract
  , conflict             :: ConflictContract
  , ordering             :: OrderingContract
  , dependencies         :: BoundedDependencies
  , maximumCount         :: PositiveInt
  , maximumBytes         :: Bytes
  , maximumAge           :: Duration
}
```

The Phase-41 mirror names the nine required terms `maxCount`, `maxBytes`, `maxAgeSeconds`,
`localValidation`, `idempotency`, `conflict`, `ordering`, `dependency`, and
`authoritativeValidation`. Its exact refusal corpus covers every absent term and every operation that must stay
online-only; no browser persistence or live authority behavior follows from that result.

Read-only ports and subscriptions are represented as cached projections with cursors, not queued reads.
Uploads use the local-blob protocol in [§10](#10-offline-blobs). A port without authoritative validation,
idempotency, conflict, ordering, dependency, count, byte, and age semantics cannot be marked queueable.
The initial infernix/jitML operation classification is owned by
[Low-Code UI Runtime §12](./low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux):
this doctrine supplies the queue machinery but cannot broaden an adapter's eligible port set.

Local validation is advisory presentation. Reconnect always reruns server validation, authentication,
authorization, membership, plan/contract compatibility, handle resolution, and provider preconditions. A
locally valid intent may therefore be rejected, conflicted, expired, or require reauthentication.

---

## 5. One bound program, paired online and offline plans

An offline-capable `BoundUiProgram` still emits one public `ClientPlan` and one private `UiServerPlan`, but each
contains a typed offline projection:

```text
ClientPlan.offline
  = store descriptors + reducers + outbox codecs + auth states
  + migrations + service-worker asset manifest + local limits

UiServerPlan.replay
  = queue action registry + old/current codecs + idempotency/conflict handlers
  + receipt lookup + cursor repair + WebSocket outcome dispatch
```

The two projections are compiled from the same queueable-port and projection set. Exact-key equality rejects a
client codec without a server replay handler, a handler absent from the client plan, an unbounded record class,
or incompatible scopes. The public plan cannot contain handler internals, Redis identities, credentials, or
server policy.

---

## 6. Closed browser facilities and encrypted storage

The trusted generic runtime has a closed browser-facility set:

```text
LocalStructuredStore | LocalAssetCache | LocalBlobStore |
CrossTabCoordination | LocalCryptography
```

The runtime binds these facilities to IndexedDB, Cache Storage/service workers, optional OPFS, Web
Locks/BroadcastChannel, and Web Crypto or an admitted equivalent. Application Dhall and trusted components do
not access those APIs directly. `localStorage` may contain only a non-authoritative random device-instance id;
it never contains application state, identity, scope, intents, or credentials.

Structured projections, outbox records, cursors, offline-auth metadata, storage migrations, quota accounting,
and upload metadata are encrypted at rest. Local blobs are encrypted before IndexedDB/OPFS persistence. Keys
are non-exportable where the platform permits and become usable only after the configured local-unlock step.
The service-worker shell cache contains immutable public assets only; it is not an application-data store.

Browser storage quota is a runtime observation, not a cluster-provisioning proof. The runtime reserves against
its declared count/byte limits, handles quota denial and eviction explicitly, and never acknowledges a queued
intent until its encrypted record is transactionally committed locally. The runtime requests persistent
origin storage where the browser supports it, but browser storage is not a durable system of record: a user,
browser, OS, or origin reset can still clear it. The continuity claim is conditional on that storage remaining
available and never substitutes for a server-side accepted-effect receipt.

---

## 7. Offline identity and partitioning

The client auth state is closed:

```text
OnlineVerified | OfflineUnlocked | ReauthRequired | LocallyRevoked
```

Before disconnect, the server may issue an opaque `OfflinePartitionHandle` bound to application, tenant,
subject, device, program, scope epoch, storage schema, allowed persisted labels, and a maximum offline lease.
The handle is local partition metadata, not a bearer credential and not authority to execute an intent. It is
never accepted as a substitute for an online Keycloak session.

Every local keyspace and encryption context includes the handle's partition identity. Switching tenant,
subject, application, device, or incompatible program never re-tags records; it closes the old partition and
opens another. Sign-out or a locally observed revocation moves the partition to `LocallyRevoked` and prevents
display/replay until the configured wipe or online reconciliation completes.

Offline revocation has an unavoidable limit: a disconnected client cannot learn a server-side revocation
until it reconnects. The maximum offline lease bounds this exposure; sensitive labels may be forbidden from
offline persistence entirely. Local wall-clock time can be altered, so lease evaluation uses the strongest
available monotonic/server-anchored evidence but is not described as tamper-proof.

---

## 8. One active tab owns connection and replay

At most one tab per offline partition is the active runtime leader. It owns the WebSocket, outbox replay,
cursor advancement, and storage migration lock. Followers receive state/outcome notifications through the
trusted `CrossTabCoordination` facility and can append an intent only through an atomic store transaction.

Web Locks is the primary admitted lease mechanism, with BroadcastChannel for notifications. A bounded
fencing-generation record in the structured store prevents a stale former leader from committing cursor or
outbox transitions after ownership changes. When those browser facilities are unavailable, the runtime falls
back to a safe single-tab/refuse-concurrent-tab posture; it never replays independently from every tab.

---

## 9. Authoritative replay and typed outcomes

**The queue element is an `Intent`, never a `Command`.** The name is normative, and it carries the whole
security argument of this section. A *command* is something that will be executed; an *intent* is something a
caller wishes to happen and the server may refuse. What a disconnected browser can produce is only ever the
second — the caller may have lost authority, the scope may have changed, the schema may have moved — and giving
it the first name invites every consumer downstream to treat it as settled. `Command` is reserved for the
scope-qualified value the server derives *after* validation
([UI Realtime Coordination §6](./ui_realtime_coordination_doctrine.md#6-durable-commands-receipts-and-replay)),
which is exactly the claimed-versus-attested index of
[`extension_conformance_security.md` §S1](./extension_conformance_security.md#s1-authentication-is-an-index-not-a-check)
applied to a queued effect, with
[§S3](./extension_conformance_security.md#s3-refusal-is-the-default-not-the-fallback) supplying the default.

Reconnect establishes a fresh online session and WebSocket before replay. The server validates the partition,
program/ABI/contracts, current scope, membership, policy, and device limits. Queued intents then replay in the
declared dependency/order relation under bounded concurrency. Each carries its immutable opaque client
`RequestId` and the digest/schema identities recorded when queued. Only after current-authority validation
does the server derive the scope-qualified `CommandId` from
`(AppId, TenantId, Owner, PortId, RequestId)`; the browser cannot author or retain execution authority merely
by retaining the request id.

The result is one of:

```text
Accepted receipt
| Rejected publicError
| Conflicted conflict
| ReauthRequired
| Expired
| UpgradeRequired migrationRequirement
```

`Accepted` is emitted only from the authoritative receipt mechanism defined by
[UI Realtime Coordination §6](./ui_realtime_coordination_doctrine.md#6-durable-commands-receipts-and-replay).
Redis may route an outcome but does not establish it. A disconnect between effect and response leaves the
intent pending; the next replica queries the same durable receipt. Replay transitions and outcomes are
written atomically to the encrypted outbox before the UI reports completion.

A rejected or conflicted intent is retained with its typed public explanation until the application-defined
resolution flow handles or explicitly discards it. `UpgradeRequired` preserves the record and names the
required migration/compatible runtime; it never clears the outbox.

---

## 10. Offline blobs

A `LocalBlobClass` declares media type, per-blob and aggregate byte bounds, retention, flow label, and the
queued upload port that may consume it. The runtime encrypts bytes locally and assigns an opaque local identity.
Reconnect obtains a fresh server upload handle, uploads bounded chunks, verifies the server-side content
identity, and only then replays dependent intents.

Local path names, OPFS handles, and plaintext content never enter a `ClientPlan` event or server request.
Tenant/subject partition switching makes a blob unreachable from another partition. Quota pressure produces a
typed refusal or an explicit application-approved eviction of records with no pending dependency; it never
silently removes a blob referenced by queued intent.

---

## 11. Release, schema, and compatibility horizon

Every persisted envelope records:

- `ProgramDigest`, `ClientRuntimeAbi`, and `UiServerAbi`;
- public-contract and port-contract digests;
- offline storage schema and record-kind version;
- partition/scope epoch and intent/cursor identity; and
- encryption/key-generation identity.

A release may become current only when every record schema within the deployment's maximum offline/replay
horizon has either a total, independently tested migration to the new schema or a retained old decoder and
server replay handler. Old handlers remain subject to current authorization and provider validation; retaining
a decoder does not retain old authority.

The compatibility horizon must be at least the maximum admitted offline record/blob age plus its bounded
reconnect/replay window, and authoritative receipt retention must cover the longest period in which an
accepted intent can be retried or queried. A deployment whose queue, blob, receipt, and compatibility bounds
do not satisfy those relations is rejected before promotion.

`ReloadRequired` may replace in-memory state but cannot discard an offline outbox or blob dependency. A release
that drops the last compatible decoder/handler before the horizon expires is rejected by the promotion gate.
Migration is atomic per partition and crash-resumable; two tabs cannot run it concurrently.

---

## 12. Deployment policy, resources, and honesty

Deployment rules, not `UiSource`, own `OfflinePolicy`:

```text
maximumOfflineLease, allowedPersistedFlowLabels, localUnlockPolicy,
maximumDevicesPerSubject, localCount/Byte/AgeLimits, reconnectConcurrency,
receiptRetention, releaseCompatibilityHorizon
```

Provisioning includes server receipt projections, replay lookup/concurrency, reconnect storms, snapshot/delta
catch-up, upload staging, WebSocket buffers, Redis fanout, and old/new decoder/handler overlap. Browser quota is
checked at runtime against the policy limits and is not included as cluster supply.

Required gates cover plaintext/credential/private-plan persistence, cross-partition exposure, multi-tab
duplicate replay, Redis-only acceptance, lost outcomes after reconnect, missing queue bounds, local clock
rollback at a lease boundary, quota exhaustion, dependent-blob eviction, and release of an incompatible old
command. Offline data confidentiality remains conditional on the browser/OS and local-unlock assumptions; it is
not equivalent to server-side Vault custody. Encryption at rest does not protect an unlocked partition from
compromised same-origin runtime code, browser extensions, or a compromised device; CSP, dependency integrity,
the bounded generated client, and local unlock reduce that exposure but do not remove it.

Only after the human user accepts the hardware-free UI/DSL/generator barrier may the local browser gate
compile freshly generated PureScript with the closed offline facilities. Separate
browser processes must preserve and recover a fresh encrypted canary, enforce partitioning and fenced
ownership, observe handoff, retain only the generated immutable asset set, and report quota refusal. Haskell
oracles and Haskell-declared production-source mutants must be reviewed independently; browser/container
success cannot retroactively qualify their generator or expectations, and status remains solely in the
[Development Plan](../../DEVELOPMENT_PLAN/README.md).

The sibling `mattandjames` repository supplies implementation evidence for the motivating
browser shape: its `offline_mode.md` and current PureScript/browser boundary use IndexedDB projections and an
outbox, service-worker shell caching, optional OPFS blobs, partition keys, typed replay outcomes, Web Locks,
BroadcastChannel, and server-authoritative reconnect. amoebius re-derives those mechanisms as a reusable checked
`UiSource` contract and deliberately strengthens the boundary with encrypted records, explicit finite
queue/blob/compatibility relations, generated paired plans, and durable effect-owner receipts. It does not
copy the sibling's app-specific record schema, fixed grace periods, Redis replay cache, or product names into
the application DSL. This is sibling evidence, not an amoebius implementation claim.

---

## Related Documents
- [Low-Code UI Runtime](./low_code_ui_runtime_doctrine.md)
- [UI Realtime Coordination](./ui_realtime_coordination_doctrine.md)
- [Release Lifecycle](./release_lifecycle_doctrine.md)
- [Tenancy](./tenancy_doctrine.md)
- [Generated Artifacts](./generated_artifacts_doctrine.md)
- [Testing](./testing_doctrine.md)
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
