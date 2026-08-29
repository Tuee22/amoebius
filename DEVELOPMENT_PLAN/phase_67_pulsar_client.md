# Phase 67: Native Pulsar client (CBOR)

> **Purpose**: Stand up `amoebius-pulsar` — the one native-protocol Haskell Pulsar client (no WebSockets),
> its capability surface, its declarative topology algebra, its exclusively-CBOR payload codec, and its
> at-least-once + broker-side-dedup delivery contract — gated by a single command→event round-trip on
> `linux-cpu`.
> **Read this if**: phase 67 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 67.1: Fork supernova → amoebius-pulsar native binary protocol ⏸️](#sprint-671-fork-supernova--amoebius-pulsar-native-binary-protocol-)
- [Sprint 67.2: Capability surface + exclusively-CBOR payload codec ⏸️](#sprint-672-capability-surface--exclusively-cbor-payload-codec-)
- [Sprint 67.3: Declarative topology algebra + one-sided-link validation ⏸️](#sprint-673-declarative-topology-algebra--one-sided-link-validation-)
- [Sprint 67.4: At-least-once + broker-side dedup + the command→event round-trip gate ⏸️](#sprint-674-at-least-once--broker-side-dedup--the-commandevent-round-trip-gate-)
- [Sprint 67.5: Register-2.5 exactly-once effect under simulated redelivery ⏸️](#sprint-675-register-25-exactly-once-effect-under-simulated-redelivery-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 66, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase's target is amoebius's **one and only transport to Pulsar**: a single native-protocol Haskell client,
`amoebius-pulsar`, speaking Pulsar's TCP binary protocol directly. There is no WebSocket transport, no
HTTP-upgrade side-door, and no second-language runtime; this client replaces both sibling transports outright.
It owns four things. First, the **native binary protocol** — length-prefixed `proto-lens`-generated
`BaseCommand` frames, the `0x0e02`/`0x0e01` magic + mandatory CRC32C payload tail, and one persistent TCP
session per broker with lookup-based service discovery. Second, the **five-verb capability surface** —
lookup · produce · consume · subscribe · seek — with all four subscription types exposed (Exclusive, Failover,
Shared, Key_Shared) and role-selection deliberately left to the daemon-topology layer, so the client only
exposes and never picks. Third, the **exclusively-CBOR payload codec**: every application payload is CBOR
through a typed codec (`serialise`/`cborg`); a non-CBOR application body (JSON/base64/protobuf/raw) is
unrepresentable, while the protocol framing itself stays protobuf. Fourth, the **declarative topology algebra** — topic names are *derived* from a typed `RouteEntry` descriptor, never hand-written, and a graph
that fails one-sided-link / duplicate / empty-lane validation cannot be reconciled — and the **at-least-once + broker-side dedup** delivery contract, with `(producer_name, sequence_id)` as a first-class protocol field.

What this phase deliberately does **not** do: the three-tier content-addressed MinIO store and the
orchestrator/worker workflow runtime with Pulsar-Failover single-writer takeover (both Phase 69), the topic
storage-lifecycle reconcile (retention / size-triggered S3 offload / backlog quota, consumed later), and any
intra-cluster HA proof — Pulsar's own broker/bookie consensus is **delegated, not re-proven**. This phase
exposes the four subscription types but runs **no bespoke election**: any single-writer property is delegated
to the broker's subscription model.

**Phase scope:** one cohesive claim — *one native-protocol client, one payload codec, and no WebSocket anywhere*. The delivery contract is at-least-once with broker-side dedup, which the round-trip has to exhibit.

**Substrate:** linux-cpu — the gate runs on a single-node `kind` cluster on a linux-cpu host. The specialized topic lanes
remain additive and are exercised by later phases.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 (live infrastructure) — the gate runs against a real broker on a real cluster, not an
in-process fake.

**Depends on:** [Phase 66](phase_66_app_tenancy.md)
**Gate:** `pb validate phase 67`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *one native-protocol client, one payload codec, and no WebSocket anywhere*. The delivery contract is at-least-once with broker-side dedup, which the round-trip has to exhibit. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 67` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance have been established. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not yet been demonstrated by a passing gate for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not yet been demonstrated by a passing gate. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not yet been demonstrated by a passing gate. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a checked pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or checked non-applicability have not yet been demonstrated by a passing gate. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 66; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

This phase instantiates the canonical resource matrix and sealed whole-deployment provision boundary from
[`resource_capacity_types.md §3.1`](../documents/engineering/resource_capacity_types.md#31-the-systematic-provision-matrix)
and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting);
embedded client demand must be charged to a canonical execution envelope.

`amoebius-pulsar` is a library, not a hidden standalone daemon: it creates no resource-free client Pod. A pure
`PulsarClientExecutionDemand` names maximum broker connections, producers, consumers, outstanding requests,
in-flight frames, frame/payload bytes, FLOW permits, redelivery/replay window, CBOR encode/decode workspace,
and reconnect burst. Binding compiles those operands into the complete `PodResourceEnvelope` of each consuming
orchestrator/worker. The Phase-67 live gate therefore declares a client-runner Pod with immutable image and OCI
import footprint; CPU, memory, and ephemeral-storage requests and limits; runtime working set; writable-root
and log headroom; projected credentials/config/service-account-token bytes; local volumes; pod slot;
exact byte-free `PodRuntimeMetadataSource` network-attachment identities and container-to-volume mount
identities; `cache = None`; and `accelerator = None`. Later phases must re-bind the same client demand into
their own Pod envelopes rather than borrowing the gate runner's capacity. The finite gate runner is
structurally a Job body with `completions=1`, `parallelism=1`, `restartPolicy=Never`, replacement-on-Failed,
bounded backoff, and finite terminal retention; it does not carry Deployment rollout fields. Its runtime-metadata
accounting is not restated here: the derivation of `KubeletRuntimeMetadataShape` from an expanded
`BoundExecutionUnit`, the private byte/role fold, the `SplitRuntime` split across backings, and the rule that
these physical bytes are never repeated as logical Pod ephemeral demand are all owned by
[`pulumi_iac_doctrine.md §1`](../documents/engineering/pulumi_iac_doctrine.md#1-pulumi-runs-only-from-inside-an-existing-amoebius-cluster).
This phase inherits that accounting unchanged; what it adds is the client demand bound into the gate runner's
own envelope.

Pure provision represents each planned epoch, and live preflight each observed snapshot, by one
`ProvisionedNodeRuntimeStorageAccounting` per node. Its planned-slot/observed-UID domain equals the assigned
Pods exactly, its qualified Pod metadata keys and image-model component keys form a disjoint exhaustive
partition, and its combined backing map debits each carve once. A missing/swapped role, wrong backing, scope or
domain mismatch, ownership hole/overlap, or alias double debit rejects before any broker socket opens.

Topics and subscriptions are not free either. Each descriptor retains its hot-ledger/backlog operands and its
required `StorageBudgetId` plus complete `PulsarOffloadObjectDemand` (exact topic identity, retained and segment
bytes, concurrent/rate-window offloads, deletion lag, failed/orphan horizon, mutation admission). The Phase-62
Pulsar provisioner merges these with BookKeeper/ZooKeeper, broker execution, and the closed six-arm MinIO
producer inventory. The whole-deployment check runs against a live snapshot before opening a broker socket or
changing a namespace policy. Only the private provisioned client/topic projection reaches the gate runner and
reconciler. Pure expansion gives every desired/prior object a `KubernetesApiObjectDemand`; live preflight
joins the observed old/new/apply transition map. `EtcdLogicalDemand { desiredObjects, churn, model }` derives
the private logical peak, which must fit `ControlPlaneStorageDemand.etcd.backendQuotaBytes`, before the
backend-at-quota plus WAL/snapshot/serialized-defrag peak separately fits its physical backing. Normalized live
Pod resources, API/etcd state, and broker topic/subscription/offload policy must equal the witness.

Exact-fit/one-short cases cover every client buffer/concurrency term, Pod CPU/memory/ephemeral/image/log term,
runtime-metadata shape/component/role and each grouped layout backing, hot ledger/backlog, object count/segment size, offload
concurrency/failure, budget, API-object revision/Event, and etcd term. Mutants that omit the
client runner, a reconnect/redelivery buffer, a subscription cursor, the offload producer, one desired API
object, a churn operand, metadata role/domain/ownership/grouping, the kubelet metadata model or largest simultaneous metadata row, or the etcd model must reject before
the first CONNECT or broker-admin mutation; a successful command/event round-trip cannot excuse an omitted
provision.

## Doctrine adopted

- [`workflow_calculus_doctrine.md` §3 — Teardown is a type obligation](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation) — native Pulsar client (CBOR) provisions, and a teardown obligation it cannot discharge is a value it cannot construct.
- [`pulsar_client_doctrine.md` §1 — One client, one wire, no WebSockets](../documents/engineering/pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets)
  — *one client, one wire, no WebSockets*: this phase's target must build the single native-protocol client the doctrine
  mandates and eliminate both sibling WebSocket/Node transports; lookup, produce, consume, subscribe, and seek
  ride the native protocol or they do not happen.
- [`pulsar_client_doctrine.md` §3 — The native binary protocol](../documents/engineering/pulsar_client_doctrine.md#3-the-native-binary-protocol)
  and [`pulsar_client_doctrine.md` §4 — Forked from supernova — what amoebius re-derives and what it adds](../documents/engineering/pulsar_client_doctrine.md#4-forked-from-supernova--what-amoebius-re-derives-and-what-it-adds)
  — *the native binary protocol* and *forked from supernova*: `proto-lens`-generated `BaseCommand` framing
  with hand-written size prefixes / magic / CRC32C only, one persistent TCP session per broker, forked from
  `cr-org/supernova` onto the repo-wide GHC 9.12.4 pin — treated as a *starting point with sibling provenance*,
  not a proven foundation.
- [`pulsar_client_doctrine.md` §5 — The capability surface: lookup · produce · consume · subscribe · seek](../documents/engineering/pulsar_client_doctrine.md#5-the-capability-surface-lookup--produce--consume--subscribe--seek)
  — *the capability surface: lookup · produce · consume · subscribe · seek*: long-lived producers,
  flow-controlled consumers, all four subscription types exposed (the client exposes, the daemon-topology
  layer picks), and seek-based replay.
- [`pulsar_client_doctrine.md` §3.1 — Payloads are exclusively CBOR](../documents/engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor)
  — *payloads are exclusively CBOR*: every application payload is CBOR through a typed codec, canonical where
  content-addressed; a non-CBOR body has no inhabitant
  ([`illegal_state_capability_messaging.md` §3.23 — A non-CBOR Pulsar payload](../documents/illegal_state/illegal_state_capability_messaging.md#323-a-non-cbor-pulsar-payload)).
- [`pulsar_client_doctrine.md` §6 — The declarative topology algebra](../documents/engineering/pulsar_client_doctrine.md#6-the-declarative-topology-algebra)
  — *the declarative topology algebra*: topic names are a derived function of a typed `RouteEntry`, and an
  unroutable graph is a validation error returning the full violation list, not a runtime mystery.
- [`pulsar_client_doctrine.md` §7 — Delivery: at-least-once with broker-side dedup (the robust default)](../documents/engineering/pulsar_client_doctrine.md#7-delivery-at-least-once-with-broker-side-dedup-the-robust-default)
  — *delivery: at-least-once with broker-side dedup*: at-least-once made effectively-once by **broker-side**
  namespace deduplication on `(producer_name, sequence_id)`; intra-cluster consensus is delegated, not
  re-proven.
- [`substrate_doctrine.md` §3 — The no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract) [`substrate_doctrine.md` §3 — The no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract) — *the no-environment / no-`PATH` lazy tool-ensure contract*: the supernova fork's `protoc`/`proto-lens` codegen is discovered lazily by full path through the
  substrate package manager — no host-`PATH` lookup for code generation and no ambient-environment client
  configuration.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 67.1: Fork supernova → amoebius-pulsar native binary protocol ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 66](phase_66_app_tenancy.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`pulsar_client_doctrine.md §3`](../documents/engineering/pulsar_client_doctrine.md#3-the-native-binary-protocol)
and [`§4`](../documents/engineering/pulsar_client_doctrine.md#4-forked-from-supernova--what-amoebius-re-derives-and-what-it-adds):
fork `cr-org/supernova` into the `amoebius-pulsar` package on the repo-wide GHC 9.12.4 pin, and stand up the
framing layer, the CONNECT/CONNECTED handshake, and LOOKUP-based service discovery over one persistent TCP
session per broker — the supernova provenance as **sibling evidence, not an amoebius result**.

### Deliverables

- The `amoebius-pulsar` cabal package forked from supernova, dependency bounds bumped to GHC 9.12.4.
- A frame codec: simple commands (`totalSize` · `commandSize` · `command`) and payload commands (command +
  optional broker-entry-metadata block behind `0x0e02` + magic `0x0e01` + mandatory CRC32C + `metadata` + raw
  `payload`), rejecting any frame over the 5 MiB maximum; only the framing is hand-written, never the protobuf
  bodies.
- `proto-lens`-generated `PulsarApi` (`BaseCommand` + message metadata) from the version-pinned upstream
  `PulsarApi.proto`, acquired lazily beneath `.build/**` and never retained as repository source; hand-rolled
  protobuf body parsing is forbidden.
- A `Connection` that performs CONNECT → CONNECTED and resolves topics by looping on `LOOKUP_TOPIC`
  Connect/Redirect responses, multiplexing producers and consumers by `producer_id` / `consumer_id` /
  `request_id`.
- A structural `PulsarClientExecutionDemand` for connection/request/frame/reconnect peaks, bound into the
  complete envelope of the Phase-67 client-runner Pod and, later, each actual consumer Pod; there is no
  separately scheduled or uncharged client service.
- Any codegen tool (`protoc`) discovered lazily by full path through the substrate package manager — no
  environment variable, no `PATH` lookup, anywhere in the build or runtime path.

### Validation

1. Encode/decode golden frames for representative `BaseCommand` types and assert byte-for-byte equality
   against spec-derived fixtures.
2. Drive CONNECT → CONNECTED → LOOKUP_TOPIC against a single-node broker on the `linux-cpu` kind cluster and
   assert the client reaches an owning broker through any redirects.
3. Flip one byte of a payload frame's body and assert a structured CRC32C-mismatch decode error, never a
   silent drop.
4. Make the client-runner CPU, memory, ephemeral, image/import, log, connection, outstanding-frame, or
   reconnect term one unit short in turn; each fixture refuses before CONNECT. The exact-fit runner's live
   requests/limits/image/local storage normalize to the private provisioned projection.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 67.2: Capability surface + exclusively-CBOR payload codec ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 67.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`pulsar_client_doctrine.md §5`](../documents/engineering/pulsar_client_doctrine.md#5-the-capability-surface-lookup--produce--consume--subscribe--seek)
and [`§3.1`](../documents/engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor): build the
five-verb client surface — long-lived producers, flow-controlled consumers, all four subscription types, and
seek-based replay — over the persistent session from Sprint 67.1, with **every application payload encoded exclusively as CBOR** through a typed codec.

### Deliverables

- A producer: `PRODUCER` → `PRODUCER_SUCCESS` binds a `producer_id` + `producer_name`; each `SEND` carries
  `producer_id` and a first-class `sequence_id`; replies are `SEND_RECEIPT` (with `message_id`) or
  `SEND_ERROR`. One long-lived producer session — no per-publish connection churn, no base64-in-JSON inflation.
- A consumer: `SUBSCRIBE` binds a `consumer_id` + subscription; consumer-granted `FLOW` permits are the
  backpressure knob; the broker pushes `MESSAGE` frames; the consumer `ACK`s and receives `ACK_RESPONSE`.
- All four subscription types exposed — **Exclusive**, **Failover** (primary + name-ordered standbys),
  **Shared** (round-robin), **Key_Shared** (same key → same consumer); the client exposes all four and does
  **not** pick and runs **no** election — role-selection is owned by the daemon-topology layer.
- `SEEK` repositioning a subscription to an earlier `message_id` or timestamp for replay.
- A typed **CBOR payload codec** (`Amoebius.Pulsar.Cbor`, on `serialise`/`cborg`): `produce`/`consume` accept
  only a `Serialise`-constrained value (equivalently a `CborPayload` whose sole constructor is
  `encodeCbor :: Serialise a => a -> CborPayload`); there is **no** `produceRaw`, no JSON/protobuf/base64 path,
  so a non-CBOR body is unrepresentable (type-foreclosed). Consume is a total `Either DecodeError a`. Canonical
  CBOR (shared with the store's canonical encoder, Phase 69) is used where the payload is content-addressed; a
  large-artifact payload carries a manifest-SHA reference, never the raw blob inline; the broker sees opaque
  `BYTES`.

### Validation

1. Produce N messages over one persistent producer and assert N `SEND_RECEIPT`s with monotonic `message_id`s.
2. For each subscription type, attach the matching consumer set and assert its delivery shape (single reader;
   primary-then-standby ordering; round-robin spread; per-key affinity).
3. Consume a prefix, `SEEK` back, and assert the earlier messages are redelivered.
4. A typed command/event round-trips through the CBOR codec byte-for-byte against the oracle-pinned CBOR
   vector. Non-CBOR foreclosure is proven **by specific reason** (§M.8), not by any compile failure: the
   compile-fail harness carries one checked Haskell `.hs` negative **per foreclosed route** — raw
   `ByteString`, JSON, and base64 — each paired with a separately authored Haskell diagnostic expectation
   (respectively `No instance for (Serialise
   ByteString)` / `produceRaw not in scope` / `No instance for (Serialise …)` as authored), each paired with a
   positive Haskell fixture that differs only in wrapping the body through `encodeCbor` and does type-check.
   The harness requires the diagnostic to match the Haskell-declared tag, so an unrelated type error does not
   satisfy the clause. An independently authored Haskell API-surface expectation declares
   `amoebius-pulsar`'s exported `produce`/`consume` signatures and compares them with the actual export list;
   any serialized listing is generated lazily beneath `.build/test-corpora/pulsar-client/**`. It asserts no
   export accepts an unconstrained `ByteString` payload and no raw-send arm exists. An applied Haskell mutant
   that re-adds a `produceRaw :: ByteString -> …` export must turn this
   validation red. A corrupted CBOR body yields a structured `Left DecodeError` on consume (decode-foreclosed,
   like CRC32C), never a silent misread.
5. A consumer grants `FLOW` permits, receives `MESSAGE` frames up to those permits, and `ACK`s each one,
   confirmed by the broker's `ACK_RESPONSE`.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 67.3: Declarative topology algebra + one-sided-link validation ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 67.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`pulsar_client_doctrine.md §6`](../documents/engineering/pulsar_client_doctrine.md#6-the-declarative-topology-algebra):
make topic names a derived function of a typed descriptor and make an unroutable graph a validation error, not
a runtime mystery — the illegal-state-unrepresentable principle applied to the message bus.

### Deliverables

- A typed `RouteEntry { workflow, phase, lanes, liveness }` descriptor as the single source of truth, and a
  `topicFor` derivation producing the fully-qualified `<workflow>.<phase>.<substrate>` topic — no hand-written
  topic strings anywhere.
- Both the per-substrate reconciled topic set and a substrate-stripped *logical* topic family derived from the
  same descriptor, so per-substrate routing cannot diverge from the declared logical set.
- `validateTopology` rejecting (1) duplicate derived topics, (2) entries with no lanes, (3) one-sided
  links on a `(workflow, lane)` pair — an input with no report, or a report with no producing input — with an
  explicit `emit-only` exemption, (4) `MonitoringInfeasible workflow reason` — a declared freshness below the
  achievable scrape interval, or a derived recording-rule cost overflowing the `Observability` workload's
  capacity — and (5) `UnroutedMonitor workflow` — a `routes[].workflow` naming no owning `Workflow` record;
  it returns the **full** list of violations so an author fixes the whole graph
  in one pass. Clauses (4) and (5) are the monitoring extension of the fold adopted from
  [`monitoring_doctrine.md §3`](../documents/engineering/monitoring_doctrine.md#3-derivation-and-the-operator-read-model)
  and are the reason the topology SSoT is a per-workflow `Workflow` record rather than a bare
  `List RouteEntry`.

### Validation

1. Property test: for each generated `RouteEntry`, `topicFor descriptor` equals the entry computed by the
   **oracle-pinned independent expected-topic table** (§M.3) — not merely equal to `topicFor` mapped over
   the descriptor, which is a tautology. "No code path accepts a literal topic string" is made concrete as a
   **type-level foreclosure that reaches the wire layer**: `Connection`'s `LOOKUP_TOPIC` and the produce/consume
   entry points accept only a `Topic` newtype whose sole constructor is private and produced only by `topicFor`;
   an independently authored Haskell API-surface expectation asserts no exported function on the
   reconcile-or-wire path takes a bare `Text`/`String` topic. A checked Haskell `.hs` compile-fail fixture
   attempting to build a `Topic`
   from a string literal fails with its expected diagnostic.
2. Feed validation graphs with seeded duplicate / empty-lane / one-sided-link defects and assert the complete
   violation list (not just the first) is returned. The property generator carries `cover`/`classify`
   obligations (§M.4) forcing each defect class — duplicate, empty-lane, one-sided-link, and the multi-defect
   graph — to fire in **≥20%** of generated cases each, so the reject path is exercised, not a near-constant
   legal graph. A Haskell-authored changed-subject seeded mutant with the one-sided-link clause deleted from `validateTopology`
   (invariant-clause-delete operator) must turn this validation red.
3. Assert an `emit-only` workflow with unsourced reports validates — the `gc` exemplar, accepted despite
   having reports with no producing input — while the same graph without the exemption
   is rejected: a positive/negative pair differing only in the exemption flag (§M.8).
4. Prove the algebra is on the gate path, not dead code (§M.3): a Haskell-declared gate topology, rendered
   lazily beneath `.build/test-corpora/pulsar-client/**`, carries a `RouteEntry` descriptor. The Sprint 67.4
   gate run asserts the actually produced and consumed topic names equal the independent Haskell expected-topic
   table — the reconcile/gate path derives its
   topics through `topicFor`, never from hand-written strings.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 67.4: At-least-once + broker-side dedup + the command→event round-trip gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 67.3
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`pulsar_client_doctrine.md §7`](../documents/engineering/pulsar_client_doctrine.md#7-delivery-at-least-once-with-broker-side-dedup-the-robust-default):
default to at-least-once delivery made effectively-once by **broker-side** deduplication, so a retried
producer or a redelivered consumer cannot corrupt idempotent state — then assemble the phase gate: a
command→event round-trip over the native protocol with dedup on and CBOR payloads.

### Deliverables

- The **broker half**: a reconcile step that enables Pulsar's namespace deduplication policy so the broker
  tracks `(producer_name, sequence_id)` and rejects duplicates at ingest.
- The **producer half**: every publish carries a stable `producer_name` and a monotonic `sequence_id` within
  that producer scope, with producer-name scoping chosen so unrelated keys never share one dedup cursor.
- The `sequence_id` derivation: when a message has a causal upstream `MessageId`
  (`<ledgerId>:<entryId>:<partition>:<batchIdx>`), pack `ledgerId`/`entryId` into a 64-bit `sequence_id`;
  otherwise fall back to a stable hash of a generated request id paired with a request-scoped producer name.
- At-least-once consumer discipline: `ACK` only after processing; un-acked messages are redelivered after a
  crash or rebalance.
- A Haskell-declared `InForceSpec` gate topology, rendered lazily beneath
  `.build/test-corpora/pulsar-client/**`, carrying a `RouteEntry` descriptor so its
  topics are `topicFor`-derived, not hand-written: bring up against the standing Pulsar service, produce a
  workflow `command`, consume it, produce the corresponding `event`, consume it back — all CBOR — and always
  tear down, emitting a per-run proven/tested/assumed ledger.
- A pure provision boundary covering the client runner, exact topic/subscription/cursor set, hot
  BookKeeper/ZooKeeper demand, and complete `PulsarOffloadObjectDemand`/`StorageBudgetId`, followed by
  snapshot-bound preflight of observed/reserved/terminating identities and node runtime/image-storage rows; no
  broker socket or namespace mutation occurs on `Left ProvisionError` or live-preflight refusal.
- The oracle-pinned gate oracles (§M.1), authored before the client exists: the CBOR command/event byte
  vectors, the hand-authored expected derived-topic table, the standing-namespace pre-run policy snapshot, and
  the Haskell-authored changed-subject seeded-mutant set (topicFor-literal, one-sided-link-clause-deleted, produceRaw-re-added) each
  asserted to turn the gate red (§M.2).

### Validation

1. Run the gate topology end-to-end on the `linux-cpu` kind cluster and assert: a workflow command round-trips
   to an event over the native protocol with broker-side dedup enabled; the CBOR payloads round-trip
   byte-for-byte against the oracle-pinned CBOR command/event vectors; the produced and consumed topic
   names equal the independently authored Haskell derived-topic expectation (§M.3, algebra on the gate path).
   A checked Haskell `.hs` fixture attempting a non-CBOR payload fails to type-check with its Haskell-declared
   expected diagnostic (§M.8). A companion negative gate
   run seeds the same topology with a one-sided link and asserts `validateTopology` refuses it **before any broker socket is opened**.
2. Enable namespace dedup, publish the same `(producer_name, sequence_id)` twice, and assert the broker
   collapses the duplicate; kill a consumer between receive and `ACK` and assert redelivery on reconnect.
3. **Idempotency (§M.6) — re-apply, not re-run-from-clean.** Re-apply the topology a second time against a
   **distinct test namespace** (cache-bypass: no reuse of run 1's namespace, cursors, producer name, or dedup
   cursor) and assert the setup/round-trip path **actually executed** on run 2 (a no-op served by leftover run-1
   state fails); re-enabling the namespace dedup policy on an already-enabled namespace is a no-op success
   (idempotent). **Leak-free teardown** is proven by an **external enumerate-and-compare sweep** (§M.5): after
   teardown, an observer external to the client queries the standing broker's admin surface and asserts the test
   tenant contains **zero** topics, subscriptions/cursors, and namespaces, and asserts the standing Phase-62
   namespace's policy set (including the deduplication policy) equals the oracle-pinned pre-run snapshot —
   subscriptions, stray topics, and a left-enabled dedup policy each fail the assertion. Emit the Register-3
   ledger — the deferred content-store, workflow-runtime, and cross-cluster surfaces (Phase 69 and later)
   recorded UNVERIFIED, never green.
4. Run one-short and omission mutants for the client-runner envelope, session buffers, cursor/backlog, offload
   demand, both SplitRuntime metadata backings, role resolution, planned/observed domain, qualified ownership,
   and alias grouping. Assert zero CONNECT frames and zero broker-admin writes for every rejection; for the
   exact-fit twin, externally read Pod and broker policy/state normalize exactly to the provisioned value.

> **Honesty.** infernix's duplicate-collapse was validated against a real broker — but **over WebSockets, in > infernix**. That is *sibling evidence*, not an amoebius result; this sprint re-implements the contract over
> the native protocol and proves it here for the first time. Pulsar's own broker/bookie consensus is
> delegated, not re-proven.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate. The content store, workflow runtime, cross-cluster correspondence, and broker consensus internals remain
explicitly UNVERIFIED under their owning later phases.

## Sprint 67.5: Register-2.5 exactly-once effect under simulated redelivery ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 67.4
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`deterministic_simulation_doctrine.md §3/§4`](../documents/engineering/deterministic_simulation_doctrine.md#3-the-simulated-environment-and-its-fault-model)
and the R3 rule ([`chaos_failover_doctrine.md §13`](../documents/engineering/chaos_failover_doctrine.md#13-the-supporting-rules--the-conditions-the-moves-need)):
validate that the *built* dedup fold makes at-least-once delivery effectively-once under adversarial
redelivery/reorder/crash schedules **in-process and deterministically replayable**, before the Register-3 live
gate — the interleaving a single-threaded test cannot reach.

### Deliverables

- The `PulsarDedupSimSpec` battery: the real dedup fold under `IOSimPOR` against the modeled Pulsar, asserting
  no-loss + no-double-apply on every explored schedule under injected
  reorder/duplicate/crash-mid-acknowledge/partition faults.
- A Register-2.5 proven/tested/assumed ledger — the fold upholds exactly-once under the modeled schedules and
  faults; honest limit: modeled-Pulsar fidelity is **assumed**, discharged by the Sprint 67.4 Register-3 live
  gate. The dedup fold is the amoebius-owned part; Pulsar's own broker/bookie consensus stays delegated and is
  only *modeled* here.

### Validation

1. Rejected historical observation: the `pulsar-dedup-sim` Cabal suite was recorded green — no schedule loses
   or double-applies an effect; a deliberately broken
   fold (a non-stable key, an ack-before-process) is caught red; the discovered counterexample replays
   identically under its seed.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate. Modeled-broker fidelity is discharged only to the extent covered by the Register-3 live run.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/pulsar_client_doctrine.md` — record that §1, §3–§7 (no-WebSockets rule, native
  protocol, supernova fork, capability surface, topology algebra, dedup contract) **and §3.1 (the exclusively-CBOR payload codec)** are realized in `amoebius-pulsar`; flip the relevant sibling-evidence
  honesty notes to delivered once the gate runs (status itself stays in this plan).
- `documents/illegal_state/illegal_state_catalog.md` — annotate §3.23 (non-CBOR payload) with its realized
  layer: produce-side type-foreclosed uninhabitable, consume-side decode-foreclosed total decode, no
  runtime-checked claim.
- `documents/engineering/substrate_doctrine.md` — record that the supernova fork's `protoc`/`proto-lens`
  codegen conforms to the no-env/no-`PATH` lazy-tool-ensure contract.
- `documents/engineering/daemon_topology_doctrine.md` — record that the client exposes all four subscription
  types (including Failover) but runs no election; role-selection and single-writer takeover are that doc's,
  landing in Phase 68.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/system_components.md` — register the `amoebius-pulsar` package and its target module paths
  (`Frame`, `Connection`, `Proto/PulsarApi`, `Producer`, `Consumer`, `Subscription`, `Seek`, `Cbor`,
  `Topology`, `Dedup`, `Namespace`) as Phase-67 design-first rows against the component inventory.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 67's gate substrate (`linux-cpu`) in the per-phase substrate
  map, and the topology algebra's per-substrate topic lanes.
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-67 row's status from this plan once the gate passes; link this
  document.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys ([§D](development_plan_standards.md#d-the-per-phase-document-skeleton) skeleton, [§F](development_plan_standards.md#f-the-sprint-block-format) sprint format, [§H](development_plan_standards.md#h-the-doctrine-citation-rule-cite-by-name) citation rule, [§K](development_plan_standards.md#k-honesty-proven--tested--assumed) honesty/registers, [§L](development_plan_standards.md#l-one-substrate-discipline) one-substrate discipline)
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (the CBOR-only payload and no-WebSockets rules)
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Native Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) — the adopted transport,
  capability, topology, CBOR-payload, and dedup doctrine
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — the Register-2.5 io-sim environment the dedup fold's exactly-once is validated against in Sprint 67.5
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — [§3.23](../documents/illegal_state/illegal_state_capability_messaging.md#323-a-non-cbor-pulsar-payload), the non-CBOR payload made
  unrepresentable
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) — the no-env/no-`PATH` lazy tool
  discovery the fork conforms to
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — who runs producers/
  consumers and picks subscription roles (Phase 69), delegated here
- [phase_62](phase_62_platform_backbone.md) — the standard-service stack that brings Pulsar up HA
- [phase_66](phase_66_app_tenancy.md) — the app tenancy this phase opens after
- [phase_69](phase_69_content_store_workflow.md) — the content store + workflow runtime that consumes this
  client
