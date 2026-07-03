# Phase 4: Native Pulsar client + content-addressed store + workflow-runtime

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, legacy_tracking_for_deletion.md, overview.md, system_components.md
**Generated sections**: none

> **Purpose**: Stand up amoebius's transport and durable-artifact substrate — the native-protocol
> `amoebius-pulsar` client (no WebSockets), the three-tier content-addressed MinIO store, the declarative
> topology algebra, and orchestrator/worker daemon scaffolding with HA failover — gated by a single
> round-trip-plus-failover acceptance test on `linux-cpu`.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is design intent and every
prescriptive statement is a target shape, not a tested amoebius result. The mechanisms are generalized from
two working sibling libraries (`infernix`'s WebSocket Pulsar path and `jitML`'s Node-subprocess Pulsar path
and content-addressed checkpoint store); that is *sibling evidence*, never amoebius proof (honesty rule,
[development_plan_standards.md §K](development_plan_standards.md)).

## Phase Summary

This phase delivers the messaging and storage core that every later workflow phase consumes. It owns four
deliverables, all on a single substrate:

1. **`amoebius-pulsar`** — one native-protocol Haskell Pulsar client forked from `cr-org/supernova`, speaking
   Pulsar's TCP binary protocol directly: lookup, produce, consume, the four subscription types, and seek.
   There is no WebSocket transport, no HTTP-upgrade side-door, and no second-language runtime; this client
   replaces both sibling transports outright. Every application **payload is exclusively CBOR** through a typed
   codec (`serialise`/`cborg`) — no JSON/base64/protobuf application body — with the protocol framing staying
   protobuf (§3.1).
2. **The declarative topology algebra** — topic names are *derived* from a typed `RouteEntry` descriptor,
   never written by hand, and a routing graph that fails one-sided-link / duplicate / empty-lane validation
   cannot be reconciled.
3. **The three-tier content-addressed MinIO store** — `blobs/<sha256>` ← `manifests/<sha256>` ←
   `pointers/*`, with write-once self-naming blobs and manifests (`If-None-Match: *`, `412` = success) and a
   single atomic pointer commit by `If-Match` compare-and-swap. The store is keyed under an opaque
   `experiment-hash` namespace; the `experimentHash` *derivation* and the SplitMix seed kernel are deferred
   to Phase 5 (per README — this phase consumes the namespace as a pinned string, it does not build the
   determinism kernel).
4. **Orchestrator/worker daemon scaffolding** — a workflow runtime in which an elected orchestrator produces
   commands and unelected workers consume them over a **Failover** subscription, so killing the active worker
   yields hot-standby takeover via the kernel election seeded in Phases 1 and 3.

This phase also **realizes the topic storage lifecycle** whose *type shape* lands in Phase 3 (Sprint 3.6): the
mandatory `RetentionPolicy`, the **size-triggered** S3 offload high-water mark, and the backlog-quota
back-pressure are enabled on the namespace as reconcile steps, per
[`pulsar_client_doctrine.md`](../documents/engineering/pulsar_client_doctrine.md) §6.1 and the two-ceiling
fold in [`resource_capacity_doctrine.md`](../documents/engineering/resource_capacity_doctrine.md) §7. This is
the **grade-(3) runtime residue** of [`illegal_state_catalog.md`](../documents/engineering/illegal_state_catalog.md)
§3.20 — the type-layer guarantee (a time-only or retention-less topic cannot be *written*) is Phase 3's; that
the broker *actually* offloads to S3 before BookKeeper fills, and that back-pressure holds under a burst, is
what this phase tests.

**Substrate:** linux-cpu (§L of [development_plan_standards.md](development_plan_standards.md): the gate
requires exactly one substrate). The native protocol, the store CAS protocol, and worker failover are all
substrate-agnostic in design but are *validated* only on `linux-cpu` here; the `apple` / `linux-cuda` /
`windows` lanes the topology algebra partitions traffic onto are exercised by later phases.

**Gate:** an `amoebius.dhall` test topology that, on a `linux-cpu` kind cluster with Pulsar + MinIO up
(Phase 2), **round-trips a workflow command → event over the native Pulsar protocol** (broker-side dedup
enabled) — **the command and event are CBOR payloads that round-trip byte-for-byte, and a non-CBOR payload
fixture fails to type-check** — **stores and fetches a content-addressed artifact** by its manifest SHA, and
then **kills the active worker and observes the Failover-subscription standby take over** — the whole topology
spinning up, running, and tearing down leak-free, idempotently on re-run.

```mermaid
flowchart LR
  dhall[amoebius.dhall test topology] --> up[Bring up Pulsar plus MinIO on linux-cpu kind]
  up --> produce[Orchestrator produces workflow command over native protocol]
  produce --> worker[Worker consumes via Failover subscription]
  worker --> store[Worker writes content-addressed artifact to MinIO store]
  store --> event[Worker produces workflow event carrying the manifest SHA]
  event --> fetch[Orchestrator fetches artifact by manifest SHA]
  fetch --> kill[Kill the active worker]
  kill --> failover[Standby worker takes over the subscription]
  failover --> teardown[Idempotent leak-free teardown]
```

## Doctrine adopted

- **[`pulsar_client_doctrine.md` §1 — One client, one wire, no WebSockets](../documents/engineering/pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets):**
  this phase builds the single native-protocol client the doctrine mandates and deletes both sibling
  transports. Concretely it implements the doctrine's
  [native binary protocol (§3)](../documents/engineering/pulsar_client_doctrine.md#3-the-native-binary-protocol)
  — length-prefixed `proto-lens`-generated `BaseCommand` frames, the `0x0e01` magic + CRC32C payload tail,
  one persistent TCP session per broker — starting from the
  [supernova fork (§4)](../documents/engineering/pulsar_client_doctrine.md#4-forked-from-supernova--what-we-inherit-and-what-we-build);
  the
  [lookup / produce / consume / subscribe / seek capability surface (§5)](../documents/engineering/pulsar_client_doctrine.md#5-the-capability-surface-lookup--produce--consume--subscribe--seek);
  the
  [declarative topology algebra (§6)](../documents/engineering/pulsar_client_doctrine.md#6-the-declarative-topology-algebra);
  and the
  [at-least-once + broker-side dedup delivery contract (§7)](../documents/engineering/pulsar_client_doctrine.md#7-delivery-at-least-once-with-broker-side-dedup-the-robust-default);
  and the [exclusively-CBOR payload codec (§3.1)](../documents/engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor)
  — every application payload is CBOR through a typed codec, and a non-CBOR body is unrepresentable
  ([illegal_state_catalog.md §3.23](../documents/engineering/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent)).
- **[`content_addressing_doctrine.md` §2 — The three-tier store: blobs ← manifests ← pointers](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers):**
  this phase builds the store's three object classes and two write protocols — write-once self-naming
  `blobs/<sha256>` and `manifests/<sha256>` under `If-None-Match: *` (with `412 Precondition Failed` treated
  as success), and the only mutable objects, `pointers/*`, advanced by `If-Match` compare-and-swap as the
  single atomic commit point. The store is namespaced under
  [`experimentHash` (§3)](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-you-asked-for--where-it-ran),
  which this phase consumes as an opaque pinned prefix; the `experimentHash` derivation, the `ContentAddress`
  typeclass, and SplitMix seed derivation are Phase 5 kernel work, not this phase. The
  [confluence property (§5)](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely)
  is what makes the gate's store fetch and the at-least-once redelivery idempotent, and the
  [honest ceiling (§6)](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic)
  bounds what this phase may claim (store *bookkeeping* totality is proven-in-types; producing *compute*
  determinism is not asserted here).

## Sprints

## Sprint 4.1: Fork supernova → amoebius-pulsar native binary protocol 📋

**Status**: Planned
**Implementation**: `amoebius-pulsar/src/Amoebius/Pulsar/Frame.hs`,
`amoebius-pulsar/src/Amoebius/Pulsar/Proto/PulsarApi.hs` (proto-lens-generated),
`amoebius-pulsar/src/Amoebius/Pulsar/Connection.hs` (target layout from
[system_components.md](system_components.md); not yet built)
**Blocked by**: Phase 2 — Pulsar reachable as a standard HA service (external earlier-phase prerequisite)
**Independent Validation**: golden-frame encode/decode round-trips of `BaseCommand` against fixtures from the
Pulsar protocol spec; a CONNECT → CONNECTED → LOOKUP_TOPIC exchange against a single-node broker resolving a
topic owner (following redirects); a deliberately corrupted CRC32C payload frame yields a structured decode
error, never a silent drop
**Docs to update**: `documents/engineering/pulsar_client_doctrine.md` (§3, §4),
`documents/engineering/substrate_doctrine.md` (the no-env/no-`PATH` lazy `protoc` discovery the fork must
conform to)

### Objective
Adopt [`pulsar_client_doctrine.md` §3 — The native binary protocol](../documents/engineering/pulsar_client_doctrine.md#3-the-native-binary-protocol)
and [§4 — Forked from supernova](../documents/engineering/pulsar_client_doctrine.md#4-forked-from-supernova--what-we-inherit-and-what-we-build):
fork `cr-org/supernova` into the `amoebius-pulsar` package on the repo-wide GHC 9.12.4 pin, and stand up the
framing layer, the CONNECT/CONNECTED handshake, and LOOKUP-based service discovery over one persistent TCP
session per broker.

### Deliverables
- The `amoebius-pulsar` cabal package forked from supernova, bounds bumped to GHC 9.12.4.
- `proto-lens`-generated `PulsarApi` (`BaseCommand` + message metadata); hand-rolled protobuf body parsing is
  forbidden — only the framing (size prefixes, `0x0e02`/`0x0e01` magic, CRC32C) is hand-written.
- A frame codec: simple commands (`totalSize` · `commandSize` · `command`) and payload commands (command +
  optional broker-entry-metadata + magic + mandatory CRC32C + metadata + raw payload), rejecting any frame
  over the 5 MiB maximum.
- A `Connection` that performs CONNECT → CONNECTED and resolves topics by looping on `LOOKUP_TOPIC`
  Connect/Redirect responses, multiplexing by `producer_id` / `consumer_id` / `request_id`.
- Any codegen tool (`protoc`) discovered lazily by full path through the substrate package manager — no
  environment variable, no `PATH` lookup, anywhere in the build or runtime path.

### Validation
1. Encode/decode golden frames for representative `BaseCommand` types and assert byte-for-byte equality
   against spec-derived fixtures.
2. Drive CONNECT → CONNECTED → LOOKUP_TOPIC against a single-node broker on the `linux-cpu` kind cluster and
   assert the client reaches an owning broker through any redirects.
3. Flip one byte of a payload frame's body and assert a structured CRC32C-mismatch decode error.

### Remaining Work
The whole sprint.

## Sprint 4.2: Capability surface — produce / consume / subscribe / seek 📋

**Status**: Planned
**Implementation**: `amoebius-pulsar/src/Amoebius/Pulsar/Producer.hs`,
`amoebius-pulsar/src/Amoebius/Pulsar/Consumer.hs`,
`amoebius-pulsar/src/Amoebius/Pulsar/Subscription.hs`,
`amoebius-pulsar/src/Amoebius/Pulsar/Seek.hs`,
`amoebius-pulsar/src/Amoebius/Pulsar/Cbor.hs` (the typed CBOR payload codec, `serialise`/`cborg`) (not yet built)
**Blocked by**: Sprint 4.1
**Independent Validation**: a persistent producer sends N messages and collects N `SEND_RECEIPT`s with
assigned `message_id`s; a consumer grants `FLOW` permits, receives `MESSAGE` frames up to the permits, and
`ACK`s (confirmed by `ACK_RESPONSE`); each of the four subscription types exhibits its distinct delivery
shape; a `SEEK` to an earlier `message_id` replays the log; a typed value round-trips through the CBOR codec,
a non-CBOR payload has no constructor (fails to type-check), and a corrupt-CBOR body yields a structured
`Left` on consume
**Docs to update**: `documents/engineering/pulsar_client_doctrine.md` (§5, §3.1),
`documents/engineering/illegal_state_catalog.md` (§3.23)

### Objective
Adopt [`pulsar_client_doctrine.md` §5 — The capability surface: lookup · produce · consume · subscribe · seek](../documents/engineering/pulsar_client_doctrine.md#5-the-capability-surface-lookup--produce--consume--subscribe--seek)
and [§3.1 — Payloads are exclusively CBOR](../documents/engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor):
build the five-capability client surface — long-lived producers, flow-controlled consumers, all four
subscription types, and seek-based replay — over the persistent session from Sprint 4.1, with **every
application payload encoded exclusively as CBOR** through a typed codec ([illegal_state_catalog.md §3.23](../documents/engineering/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent)).

### Deliverables
- A producer: `PRODUCER` → `PRODUCER_SUCCESS` binds a `producer_id` + `producer_name`; each `SEND` carries
  `producer_id` and a first-class `sequence_id`; replies are `SEND_RECEIPT` (with `message_id`) or
  `SEND_ERROR`. One long-lived producer session — no per-publish connection churn, no base64-in-JSON
  inflation.
- A consumer: `SUBSCRIBE` binds a `consumer_id` + subscription; consumer-granted `FLOW` permits are the
  backpressure knob; the broker pushes `MESSAGE` frames; the consumer `ACK`s and receives `ACK_RESPONSE`.
- All four subscription types exposed — **Exclusive**, **Failover** (primary + name-ordered standbys),
  **Shared** (round-robin), **Key_Shared** (same key → same consumer); the client exposes all four and does
  not pick (role-selection is owned by the daemon-topology doctrine).
- `SEEK` repositioning a subscription to an earlier `message_id` or timestamp for replay.
- A typed **CBOR payload codec** (`Amoebius.Pulsar.Cbor`, on `serialise`/`cborg`): `produce`/`consume` accept
  only a `Serialise` value (equivalently a `CborPayload` whose sole constructor is `encodeCbor`); there is
  **no** raw/JSON/protobuf payload constructor, so a non-CBOR body is unrepresentable (grade-1). Consume is a
  total `Either DecodeError a`. Canonical CBOR (shared with the store's `encodeManifestCbor`, Sprint 4.5) is
  used where the payload is content-addressed; a large-artifact payload carries a manifest SHA reference,
  never the raw blob inline.

### Validation
1. Produce N messages over one persistent producer and assert N `SEND_RECEIPT`s with monotonic
   `message_id`s.
2. For each subscription type, attach the matching consumer set and assert its delivery shape (single reader;
   primary-then-standby ordering; round-robin spread; per-key affinity).
3. Consume a prefix, `SEEK` back, and assert the earlier messages are redelivered.
4. A typed command/event round-trips through the CBOR codec byte-for-byte; a fixture attempting a non-CBOR
   payload fails to type-check (grade-1); a corrupted CBOR body yields a structured `Left` on consume
   (grade-2, like CRC32C), never a silent misread.

### Remaining Work
The whole sprint.

## Sprint 4.3: Declarative topology algebra + one-sided-link validation 📋

**Status**: Planned
**Implementation**: `amoebius-pulsar/src/Amoebius/Pulsar/Topology.hs` (not yet built)
**Blocked by**: none (pure derivation; no broker or session required)
**Independent Validation**: property tests that `topicFor` derives `persistent://<tenant>/<namespace>/<workflow>.<phase>.<substrate>`
from a typed `RouteEntry` and never from a literal; `validateTopology` returns the **full** violation list on
graphs seeded with duplicates, empty lanes, and one-sided links; an `emit-only` workflow (the `gc` exemplar)
is accepted despite having reports with no producing input
**Docs to update**: `documents/engineering/pulsar_client_doctrine.md` (§6)

### Objective
Adopt [`pulsar_client_doctrine.md` §6 — The declarative topology algebra](../documents/engineering/pulsar_client_doctrine.md#6-the-declarative-topology-algebra):
make topic names a derived function of a typed descriptor and make an unroutable graph a validation error,
not a runtime mystery — the illegal-state-unrepresentable principle applied to the message bus.

### Deliverables
- A typed `RouteEntry { workflow, phase, lanes }` descriptor as the single source of truth, and a `topicFor`
  derivation producing the fully-qualified `<workflow>.<phase>.<substrate>` topic — no hand-written topic
  strings anywhere.
- Both the per-substrate reconciled topic set and a substrate-stripped *logical* topic family derived from
  the same descriptor, so per-substrate routing cannot diverge from the declared logical set.
- `validateTopology` rejecting (1) duplicate derived topics, (2) entries with no lanes, and (3) one-sided
  links on a `(workflow, lane)` pair — an input with no report, or a report with no producing input — with an
  explicit `emit-only` exemption; it returns the **full** list of violations so an author fixes the whole
  graph in one pass.

### Validation
1. Property test: every derived topic equals `topicFor` of its descriptor entry; no code path accepts a
   literal topic string.
2. Feed validation graphs with seeded duplicate / empty-lane / one-sided-link defects and assert the complete
   violation list (not just the first) is returned.
3. Assert an `emit-only` workflow with unsourced reports validates, while the same graph without the
   exemption is rejected.

### Remaining Work
The whole sprint.

## Sprint 4.4: At-least-once delivery + broker-side dedup 📋

**Status**: Planned
**Implementation**: `amoebius-pulsar/src/Amoebius/Pulsar/Dedup.hs`,
`amoebius-pulsar/src/Amoebius/Pulsar/Namespace.hs` (namespace dedup-policy reconcile) (not yet built)
**Blocked by**: Sprint 4.2
**Independent Validation**: with namespace deduplication enabled, a producer that retries the same
`(producer_name, sequence_id)` has the duplicate rejected at ingest; a consumer that crashes before `ACK` is
redelivered the un-acked message; the `MessageId`→`sequence_id` packing (`ledgerId`/`entryId`) and the
request-scoped-producer-name fallback both keep distinct keys off one dedup cursor
**Docs to update**: `documents/engineering/pulsar_client_doctrine.md` (§7)

### Objective
Adopt [`pulsar_client_doctrine.md` §7 — Delivery: at-least-once with broker-side dedup](../documents/engineering/pulsar_client_doctrine.md#7-delivery-at-least-once-with-broker-side-dedup-the-robust-default):
default to at-least-once delivery made effectively-once by **broker-side** deduplication, so a retried
producer or a redelivered consumer cannot corrupt idempotent state.

### Deliverables
- The broker half: a reconcile step that enables Pulsar's namespace deduplication policy so the broker
  tracks `(producer_name, sequence_id)` and rejects duplicates at ingest.
- The producer half: every publish carries a stable `producer_name` and a monotonic `sequence_id` within
  that producer scope, with producer-name scoping chosen so unrelated keys never share one dedup cursor.
- The `sequence_id` derivation: when a message has a causal upstream `MessageId`
  (`<ledgerId>:<entryId>:<partition>:<batchIdx>`), pack `ledgerId`/`entryId` into a 64-bit `sequence_id`;
  otherwise fall back to a stable hash of a generated request id paired with a request-scoped producer name.
- At-least-once consumer discipline: `ACK` only after processing; un-acked messages are redelivered after a
  crash or rebalance.

### Validation
1. Enable namespace dedup, publish the same `(producer_name, sequence_id)` twice, and assert the broker
   collapses the duplicate (downstream idempotent state observes it once).
2. Kill a consumer between receive and `ACK`; assert the message is redelivered on reconnect.
3. Unit-test the `MessageId`→`sequence_id` packing and the fallback request-scoped producer name, asserting
   two unrelated keys never collide on a single highest-sequence cursor.

> **Honesty.** `infernix`'s duplicate-collapse was validated against a real broker — but over WebSockets, in
> infernix. That is *sibling evidence*, not an amoebius result; this sprint re-implements the contract over
> the native protocol and proves it here for the first time.

### Remaining Work
The whole sprint.

## Sprint 4.5: Three-tier content-addressed MinIO store 📋

**Status**: Planned
**Implementation**: `amoebius-store/src/Amoebius/Store/ContentAddress.hs`,
`amoebius-store/src/Amoebius/Store/Manifest.hs`,
`amoebius-store/src/Amoebius/Store/Pointer.hs` (not yet built)
**Blocked by**: Phase 2 — MinIO reachable as a standard HA service (external earlier-phase prerequisite)
**Independent Validation**: a blob PUT under `If-None-Match: *` returns success on first write and treats the
second write's `412` as success; a canonical-CBOR manifest encodes byte-identically from two writers with
equal logical content (same key); a `pointers/latest` `If-Match` CAS commits the winner and returns `412` to
the loser, who re-reads and reapplies the typed advance predicate; a reader always observes a 32-byte SHA
naming an immutable manifest, never torn state
**Docs to update**: `documents/engineering/content_addressing_doctrine.md` (§2),
`documents/engineering/storage_lifecycle_doctrine.md` (the retained-PV MinIO the bytes land on)

### Objective
Adopt [`content_addressing_doctrine.md` §2 — The three-tier store](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers),
namespaced under [`experimentHash` (§3)](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-you-asked-for--where-it-ran)
as an opaque pinned prefix: build the three object classes and two write protocols so the only race in the
system is a single one-object atomic pointer flip.

### Deliverables
- `blobs/<sha256>` — write-once content-addressed payloads keyed by `sha256(bytes)`, PUT with
  `If-None-Match: *`, `412` treated as success (the bytes already exist by definition).
- `manifests/<sha256>` — write-once **canonical-CBOR** manifests keyed by `sha256(canonical-cbor(manifest))`,
  naming their constituent blob SHAs; the canonical encoder sorts components deterministically so two writers
  with equal logical content emit the same key. The manifest SHA is the checkpoint id used in Pulsar events
  and resume.
- `pointers/*` (`latest`, `best/<metric>`, `trial/<id>/…`) — the only mutable objects; each body is a 32-byte
  manifest SHA, updated by `If-Match: <etag>` compare-and-swap as the single atomic commit point; the pure
  CAS decision (`PointerWritten` vs `PointerConflict`) and a typed advance predicate resolve a lost CAS.
- Store keys taken under a caller-supplied `experiment-hash` namespace string — this phase does **not** build
  `deriveExperimentHash`, the `ContentAddress` typeclass, or SplitMix seed derivation (Phase 5 kernel work).

### Validation
1. Write the same blob twice and assert first-write success, second-write `412` treated as a no-op success.
2. Encode the same logical manifest from two independent writers and assert byte-identical CBOR and an
   identical key.
3. Race two `pointers/latest` updates; assert one commits, the loser gets `412`, re-reads, and the advance
   predicate converges both to the same HEAD; assert no reader ever sees a torn pointer body.

> **Honesty.** Blob/manifest conflict-freedom and pointer lattice-convergence are *proven-in-types* arguments
> (immutability + a commutative/associative/idempotent join) per
> [content_addressing_doctrine.md §6](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic);
> the CAS protocol's runtime behaviour is validated here, but cross-cluster replication is not exercised in
> this phase.

### Remaining Work
The whole sprint.

## Sprint 4.6: Orchestrator/worker workflow runtime + HA failover (gate) 📋

**Status**: Planned
**Implementation**: `amoebius-runtime/src/Amoebius/Workflow/Runtime.hs`,
`amoebius-runtime/src/Amoebius/Workflow/Orchestrator.hs`,
`amoebius-runtime/src/Amoebius/Workflow/Worker.hs`,
`amoebius-runtime/dhall/test/round_trip_failover.dhall` (the gate topology) (not yet built)
**Blocked by**: Sprint 4.2, Sprint 4.3, Sprint 4.4, Sprint 4.5; Phase 3 — control-plane singleton +
leadership election (external earlier-phase prerequisite)
**Independent Validation**: the gate `amoebius.dhall` round-trips a workflow command → event over the native
protocol with dedup on, stores and fetches a content-addressed artifact by manifest SHA, kills the active
worker, and observes the Failover standby take over; the topology tears down leak-free and re-runs
idempotently; each run emits a proven/tested/assumed ledger artifact
**Docs to update**: `documents/engineering/pulsar_client_doctrine.md` (§5),
`documents/engineering/daemon_topology_doctrine.md` (worker roles + election),
`documents/engineering/content_addressing_doctrine.md` (§5)

### Objective
Adopt [`pulsar_client_doctrine.md` §5 — The capability surface (the Failover subscription)](../documents/engineering/pulsar_client_doctrine.md#5-the-capability-surface-lookup--produce--consume--subscribe--seek),
[`daemon_topology_doctrine.md` §4 — Worker daemons, N, unelected](../documents/engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected)
and [§5 — Leadership election](../documents/engineering/daemon_topology_doctrine.md#5-leadership-election--the-mechanism-the-proof-lives-elsewhere),
and [`content_addressing_doctrine.md` §5 — Confluence](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely):
wire the client, the topology algebra, the dedup contract, and the store into an orchestrator/worker runtime
whose active worker fails over to a hot standby — and assemble the phase gate.

### Deliverables
- An orchestrator daemon that, using the topology algebra (Sprint 4.3), produces a workflow `command` on the
  derived topic and consumes the corresponding `event`.
- Worker daemons attached over a **Failover** subscription (Sprint 4.2): one active, the rest name-ordered hot
  standbys; the active worker consumes the command, writes a content-addressed artifact to the store (Sprint
  4.5), and produces an `event` carrying the manifest SHA — dedup (Sprint 4.4) makes a retried produce or a
  redelivered consume idempotent.
- HA failover driven by the kernel election seeded in Phases 1 and 3: killing the active worker yields
  standby takeover with at-least-once redelivery of the un-acked command; confluence (§5) makes the standby's
  re-fetch of the artifact by manifest SHA safe without a distributed lock.
- The gate `round_trip_failover.dhall` test topology: spin up Pulsar + MinIO, run the command→event
  round-trip + store/fetch, inject the worker kill, and always tear down — emitting a per-run ledger artifact.

### Validation
1. Run the gate topology end-to-end on the `linux-cpu` kind cluster and assert: the command round-trips to an
   event over the native protocol; the artifact written by the worker is fetched by the orchestrator by its
   manifest SHA and matches; killing the active worker triggers standby takeover with no lost command.
2. Re-run the topology and assert idempotent setup and leak-free teardown.
3. Assert the run emits a proven/tested/assumed ledger artifact per
   [chaos_failover_doctrine.md §12 — The moral core](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed);
   skipping an applicable failover-injection move marks that layer UNVERIFIED, never green.

> **Honesty.** This sprint exercises the **intra-cluster** Failover subscription only; the asynchronous
> cross-cluster failover boundary and its formal proof are owned by
> [chaos_failover_doctrine.md](../documents/engineering/chaos_failover_doctrine.md) and scheduled for Phase 9,
> not here. Pulsar's own broker/bookie consensus is delegated, not re-proven.

### Remaining Work
The whole sprint.

## Documentation Requirements

**Engineering docs to update:**
- `documents/engineering/pulsar_client_doctrine.md` — record that §3–§7 (native protocol, supernova fork,
  capability surface, topology algebra, dedup contract) **and §3.1 (the exclusively-CBOR payload codec)** are
  realized in `amoebius-pulsar`; flip the relevant sibling-evidence honesty notes to live-proof status once the
  gate runs (status itself stays in this plan).
- `documents/engineering/illegal_state_catalog.md` — annotate §3.23 (non-CBOR payload) with its realized
  grade: produce-side grade-(1) uninhabitable, consume-side grade-(2) total decode, no grade-(3) claim.
- `documents/engineering/content_addressing_doctrine.md` — record that §2 (the three-tier store + the two
  write protocols) is realized in `amoebius-store`, namespaced under an opaque `experiment-hash` prefix, with
  the §3 `experimentHash` derivation and seed kernel explicitly deferred to Phase 5.
- `documents/engineering/daemon_topology_doctrine.md` — record the orchestrator/worker scaffolding and the
  Failover-based worker failover wired to the kernel election.
- `documents/engineering/substrate_doctrine.md` — record that the supernova fork's `protoc` codegen conforms
  to the no-env/no-`PATH` lazy-tool-ensure contract.

**Cross-references to add:**
- From [system_components.md](system_components.md): the `amoebius-pulsar`, `amoebius-store`, and
  `amoebius-runtime` packages and their target module paths, mapped to the owning doctrine.
- From [substrates.md](substrates.md): Phase 4's single substrate (`linux-cpu`) in the per-phase substrate
  map, and the topology algebra's per-substrate topic lanes.
- From [README.md](README.md): mark the Phase 4 row's status from this plan once the gate passes.

## Related Documents
- [README.md](README.md) — the live tracker; Phase 4 objective, gate, and substrate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this doc obeys (§D skeleton,
  §F sprint format, §H citation rule, §K honesty, §L one-substrate discipline)
- [system_components.md](system_components.md) — the target component inventory (the Implementation paths
  above are its intended layout, not yet built)
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [Native Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) — the adopted transport doctrine
- [Content Addressing & Determinism Doctrine](../documents/engineering/content_addressing_doctrine.md) — the adopted store doctrine
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — orchestrator/worker roles + election
- [Chaos / Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the proven/tested/assumed ledger and the deferred cross-cluster boundary
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — the retained-PV MinIO the store bytes land on
