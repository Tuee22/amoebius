# Phase 89: Apple-Metal host compute daemon

> **Purpose**: Stand up the Apple-Silicon host compute daemon that runs a Metal ML workload as a plain cluster
> Pulsar/content-store peer over host-only loopback NodePorts with no mTLS, where the content endpoint is the
> sole Phase-69 mutation gateway fronting MinIO, with the native worker built **headless
> on-host through the fixed Metal bridge — no VM — only after one pure physical-host → Lima-VM + cluster +
> host-worker + cache resource fold proves CPU, memory/unified memory, and presentation/allocation-derived
> storage fit without double counting.**
> **Read this if**: phase 89 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_90_test_topology_live.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/apple_metal_headless_builds.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 89.1: Apple substrate management — Lima Linux VM + brew lazy tool-ensure ⏸️](#sprint-891-apple-substrate-management--lima-linux-vm--brew-lazy-tool-ensure-)
- [Sprint 89.2: Host-only loopback NodePort exposure of the content-mutation gateway + Pulsar ⏸️](#sprint-892-host-only-loopback-nodeport-exposure-of-the-content-mutation-gateway--pulsar-)
- [Sprint 89.3: Headless host-native Metal bridge + native worker build (no Tart) ⏸️](#sprint-893-headless-host-native-metal-bridge--native-worker-build-no-tart-)
- [Sprint 89.4: Host compute daemon lifecycle as a managed subprocess ⏸️](#sprint-894-host-compute-daemon-lifecycle-as-a-managed-subprocess-)
- [Sprint 89.5: Channel-2 peer + wild-exposure unrepresentable + the Apple-Metal peer gate ⏸️](#sprint-895-channel-2-peer--wild-exposure-unrepresentable--the-apple-metal-peer-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 88, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

This phase's target is the one class of amoebius compute that lives **outside a cluster pod**: the same binary under the host-daemon context, holding the `Worker` arm of `HostRole` ([daemon_topology_doctrine.md §2](../documents/engineering/daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid)) — a long-running
host subprocess that reaches hardware which refuses to be performantly contained — Apple-Metal needs Apple
Silicon unified memory, so it cannot run in a Linux container or a Linux VM. The phase does four things and
stops there. Its prerequisite is one complete physical-host provision: the observed Apple host advertises CPU,
physical unified memory, host cache/storage backing, and an `AppleMetalOffering` with a compatible
`MetalProfile`; the Lima VM carves vCPU, memory, and a materializable disk from that host. A raw VM-disk byte
scalar is not an input: `VmDiskCarve` instead carries
`{ id, presentation : FilesystemPresentation, allocation, guestSystem, kubelet }`; there is no `Block`
guest-root arm. Provisioning sums the guest-system and unique
kubelet-layout **usable** carves, applies the versioned filesystem/sparse-image overhead model and the host
backing's minimum/quantum, and alone constructs private
`ProvisionedVmDiskCarve { id, requiredUsableBytes, provisionedBytes, presentation, allocation, witness }`. The VM's
Kubernetes node advertises net allocatable CPU/memory, logical ephemeral bytes, and a closed
filesystem/content-snapshot layout inside that VM disk; and the host worker declares CPU,
non-Metal runtime memory, and an unprovisioned `MetalOwnerDemand` with exact equal-keyed inference/JIT/library
source and workload maps plus finite class-based coexistence policy. Provision derives every permitted
unified-memory epoch and privately aggregates its peak; only that private claim renders. The worker also declares its
bounded host-cache demand. The fold charges the VM reservation, host/runtime headroom, worker non-Metal runtime, and
the provisioned Metal epoch peak once against physical memory. Inside the VM disk the gate must test
`guest usable system reserve + Σ(unique layout usable carves) = requiredUsableBytes`; presentation/allocation
then derive the raw sparse-disk high-water `provisionedBytes`. That high-water is charged **once** beside
disjoint durable backing and host-cache pools on the physical disk, never again as the nodefs/imagefs
sub-budgets nested inside it. If any axis does not fit, `provision` rejects before Lima creation, bridge build,
cache materialization, or worker launch.

First, it manages the apple substrate, synthesizing the Linux host the cluster wants via **Lima**
and rooting every host tool in **brew** through the no-environment / no-`PATH` lazy tool-ensure contract —
probe, install-if-absent, resolve the absolute path from the package manager, invoke by full path. Second, it
binds the in-cluster Phase-69 content-mutation gateway and Pulsar service to **host-only loopback NodePorts** reachable only
from the host (`127.0.0.1:<nodeport>`), with no LoadBalancer, no Envoy route, and no path from LAN/WAN — the
sanctioned localhost carve-out from Keycloak-owns-all-wild-ingress. Third, it must build the native Apple-Metal
worker **headless, directly on the host — no VM (no Tart)** — via a fixed Objective-C/C Metal bridge
generated lazily from Haskell declarations beneath `.build/metal/**` and compiled with `/usr/bin/clang` by absolute path,
with generated MSL compiled at runtime through the OS
Metal framework. Fourth, it runs that worker as a managed subprocess of the host binary and wires it as an
**ordinary Pulsar + content-store peer over host-only NodePorts with no mTLS**: commands arrive as Pulsar
messages, mutations pass only through the Phase-69 gateway into the content-addressed MinIO store, and there is
no bespoke binary↔daemon RPC — coordination is Pulsar plus the gateway-backed store, with security from the
network restriction, not from transport crypto. The representative fixture exposes no raw MinIO backend
NodePort. A future raw-GET endpoint must be a separately counted read-only Service with read-only credentials,
no PUT/DELETE/multipart authority and no mutation route; it cannot share the gateway Service identity.

The scope stops at the host-worker shell and its wire. [Phase 80](phase_80_determinism_jitcache.md) owns resolution
of the Metal ML kernel's named catalog entry into the bounded content-addressed jit cache; it is never baked or
URL-fetched. On the Apple substrate the cache
artifact is content-addressed source metadata — the rendered MSL plus launch/determinism metadata — not a
compiled dylib. The daemon carries no cluster-control authority: state-changing coordination flows through the
same Pulsar/gateway-backed-content-store nervous system every in-cluster worker uses, and the durable side of
that store lives in the
Vault-enveloped MinIO bucket that is the stateless Deployment-`replicas=1` control-plane daemon's only
durable state (single-instance delegated to k8s/etcd, **no election**). The windows-CUDA host worker is the
structurally identical case on a different substrate and is named throughout as target shape, but it is **not**
part of this phase's single-substrate gate. This phase's target must consume only future human-approved
predecessor capabilities rather than re-implement them: Phase 55's substrate detection, `pb` bootstrap
coordinator handoff, and no-`PATH` tool-ensure kernel; Phase 62's MinIO
and Pulsar standard services; Phase 67's native Pulsar client; Phase 69's content-addressed store and workflow
runtime; Phase 80's determinism kernel; Phase 80's jit-build engine cache; and Phase 61's Vault secrets-by-name.

```mermaid
flowchart LR
%% register: orientation
  apple[Apple Silicon host: detected apple substrate] --> lima[Lima Ubuntu-24.04 VM: single-node cluster]
  lima --> svc[Phase-69 content-mutation gateway fronting MinIO plus Pulsar]
  svc --> np[Two host-only NodePorts bound to 127.0.0.1, no mTLS; no raw MinIO backend port]
  apple --> bridge[Headless on-host fixed Metal bridge build: clang, no VM]
  bridge --> daemon[Host compute daemon: managed subprocess of the host binary]
  np --> daemon
  daemon --> metal[Metal ML kernel: jit-resolved MSL on Apple unified memory]
  daemon --> peer[Channel-2 peer: Pulsar consume plus gateway content put and get]
  peer --> gate[Gate: Apple daemon runs a Metal workload as a cluster peer]
```
*Orientation. Design intent. The target Apple-Silicon topology must stand up with the two host-only NodePorts as
the only route between the on-host daemon and its in-cluster peers; the future gate's apparatus is owned by
[Gate integrity](#gate-integrity). No part of it has run.*

**Phase scope:** one cohesive target claim — *a Metal workload must be an ordinary cluster peer over host-only
loopback*. The target must build the native worker headless on the host and must use the content endpoint as the
single mutation gateway.

**Substrate:** apple — the whole gate runs on an Apple-Silicon host whose Lima-synthesized Linux VM carries a
single-node cluster in Register 3 (live infrastructure); no linux-cpu, linux-cuda, or windows substrate is
touched by the gate, and the windows-CUDA host worker is named only as the structurally identical non-gate case.

**Lane:** metal ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 88](phase_88_offline_multizone_continuity.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 89`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | one cohesive claim — *a Metal workload is an ordinary cluster peer over host-only loopback*. The native worker is built headless on the host, and the content endpoint is the single mutation gateway. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 89` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | MISSING — blocks validation: the current Phase 88 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

The physical-host fold retains complete envelopes for every new execution unit, not just the Metal working
set. The contained `pb` toolchain establishment, the post-handoff Haskell brew probe/install/resolve step,
Lima/provider process, fixed-bridge compiler invocation,
long-lived host supervisor+worker child, and host gate/probe process each name an executable content digest
and installed bytes, CPU/memory reservation and ceiling under the finite Apple supervisor policy, bounded
stdout/stderr/rotated logs, writable/temp/scratch bytes on a named host backing, cache participation, process
concurrency and lifetime. The tool install/download/unpack peak uses the existing
`BootstrapExecutionEnvelope`; the bridge uses `BuildExecutionEnvelope`. The worker envelope separates non-
Metal RSS from `MetalOwnerDemand`: exact source/workload keys cover inference jobs, JIT compilations, and
library work; structural residency is governed by finite class-based resident/running bounds whose domains
both equal `classes(sources)`. Provision derives every allowed coexistence epoch and privately sums its
residency into Apple unified memory. The parent physical-memory ledger charges non-Metal RSS plus the private
epoch peak once; native Pulsar/content-gateway/Vault clients, Metal command buffers and response staging are work
inside that envelope and never become fictional client Pods. Runtime MSL compilation adds its intermediate
and cache-write high-water to the same worker/cache transition rather than pretending compilation is free.
The worker's source-equal Phase-67/48 work/result topic and subscription demand also retains finite message/
rate/concurrency, backlog/retention, cursor/dedup, hot-ledger and offload object extents; those bytes merge into
the inherited Pulsar/BookKeeper/MinIO ledger before dispatch, rather than being hidden by the loopback client.
The host content client terminates at the Phase-69 sole content-mutation gateway NodePort; raw MinIO backend
credentials/routing are absent. The gateway and its
collector/verification Job retain complete Pod/image/CPU/memory/ephemeral/mapped/log/pod-IP-CSI/API-object
envelopes, finite admission concurrency, exact output/upload/failure extents and rollout overlap before the
host may write. Reads still resolve the content-addressed object through that gateway-backed MinIO store.

The content gateway/collector, MinIO backend, Pulsar, Vault and Phase-65 control-plane daemon instances are inherited
service definitions, but they are not
free prerequisites: whether newly materialized with the apple cluster or already live in the current snapshot,
their exact Pods remain in the whole-deployment fold with complete images, resources, local/durable storage,
pod/IP and CSI attachment slots. A NodePort `Service`, firewall rule and pure client library do not create
additional Pods. Any incremental control-plane daemon reconciliation/API-client work for the two Services is charged to
the control-plane daemon's existing container envelope. The host worker is the only new compute *role*; the gate still
spends the exact inherited service-Pod slots and cannot call that count zero.

The host worker is structurally paired only with
`HostProcessReplacementPolicy.MetalDrainThenReplaceAfterObservedExit`. Its supervisor first CAS-reserves the
complete host vector, moves Reserved→LaunchInFlight, and keeps an ambiguous launch charged until PID/process
readback repairs it to Running. During replacement, its PID, executable, CPU/RSS,
unified-memory hold, cache residents/temp, logs and socket/client buffers stay charged until Drain completes,
the process is absent, `MTLDevice.currentAllocatedSize` returns to the admitted residual, and cache cleanup is
observed. CPU/Metal axes may then release, but cache/log/local artifacts remain in the host resident ledger
until their own deletion/GC observation. Only a snapshot-bound
`ValidatedMetalReleaseEvidence` may authorize replacement acquisition. The cache-bypassed determinism recompute runs through
the same surviving worker serially; its old and new MinIO output objects coexist for comparison, and its new
MSL/cache workspace is included in the transition peak. Any future overlapping worker policy must provision
two complete host envelopes and two privately derived Metal-owner epoch peaks; v1 supplies no shortcut for it.

The `MetalOwnerDemand` source/workload maps and policy never render. Only the private
`ProvisionedMetalOwnerDemand` aggregate claim enters `ProvisionedSpec`; live readback exact-matches work-item
dispatches and current allocated unified memory to that witness. Omitting a work item, mismatching either
policy domain, supplying a favorable epoch list, or dropping a co-resident overlap so the host fits by one byte
rejects before bridge/cache/worker effects.

This phase must apply the exhaustive desired-object and etcd-capacity protocol that human-approved Phase 73 must supply to the
Metal worker's complete expanded object set. The private logical witness accounts for revision, Lease, and Event
churn under the backend quota, while the physical witness separately covers the quota-sized backend, WALs,
snapshots, and defrag overlap; live readback must equal both. Haskell one-byte logical/physical shortage and
drop-API-object/churn/model operators must reject before Lima workload/NodePort apply; any serialized cases
are generated beneath `.build/test-corpora/**`.

Only the snapshot-bound private provision projections authorize `brew`, Lima, clang, bridge/cache writes,
NodePort mutation or worker acquire. Live readback compares the executable digests, supervisor/child process
tree, CPU/RSS samples and breach policy, Metal profile/allocation, log/writable/scratch/cache high-water,
Lima VM/root geometry, Kubernetes survivor images/resources/slots, the exact
`{ContentMutationGateway, Pulsar}` NodePort identities/listeners/firewall and raw-MinIO-backend absence (or the
separately provisioned read-only Service identity/credential/route set in its optional arm), exact Pulsar
topic/cursor/backlog/offload, content-gateway/collector execution/admission, and MinIO resident/transient
objects to that witness. Besides the VM/Metal boundaries, separately authored Haskell cases owned by this
phase must supply one-unit/one-byte-short observations for bootstrap/tool install, provider, compiler,
supervisor/worker and harness CPU/memory, process slots, logs/writable/scratch/cache, client buffers, Pulsar
topic/backlog/offload, output-object overlap, content-gateway/collector execution, and every surviving
pod/IP/CSI/image/storage commitment. Phase 0 supplies only the generic validation kernel. Haskell
dropped-envelope operators launch clang, the worker, or the host probe with no row; other
Haskell operators replace the worker before observed release, omit the Pulsar work-topic or content
gateway/collector, or attempt a direct MinIO backend put. Each must turn the gate red before any lasting effect,
and every external mutation form is generated beneath `.build/test-corpora/**`.

- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`; Haskell negatives may render external forms only beneath `.build/test-corpora/**`.

## Doctrine adopted

- [`extension_conformance_doctrine.md` §5 — The conformance gate is generated, not authored](../documents/engineering/extension_conformance_doctrine.md#5-the-conformance-gate-is-generated-not-authored) — apple-Metal host compute daemon is admitted by satisfying the contract, not by appearing on a list.
This phase's target is to become the first live amoebius realization of three doctrines; individual sprints
cite the same sections where they must adopt them.

- [`host_cluster_comms_doctrine.md` §2 — The decision that was open, and is now resolved](../documents/engineering/host_cluster_comms_doctrine.md#2-the-decision-that-was-open-and-is-now-resolved)
  — *the decision that was open, and is now resolved*: this phase's target must implement the resolved channel-2 design — a host
  compute daemon as a plain Pulsar + gateway-backed-MinIO peer over host-only NodePorts with **no mTLS**; the
  gateway is the sole mutation endpoint and the raw MinIO backend is not exposed — taking the two
  localhost-only channels of [`host_cluster_comms_doctrine.md` §1 — The host-origin surface: two channels, both localhost-only](../documents/engineering/host_cluster_comms_doctrine.md#1-the-host-origin-surface-two-channels-both-localhost-only),
  the no-bespoke-control-channel rule of [`host_cluster_comms_doctrine.md` §3 — There is no bespoke control channel — coordination *is* Pulsar + MinIO](../documents/engineering/host_cluster_comms_doctrine.md#3-there-is-no-bespoke-control-channel--coordination-is-pulsar--minio)
  (*coordination is Pulsar + MinIO*, with MinIO mutation mediated by the Phase-69 gateway), the
  network-restriction threat model of [`host_cluster_comms_doctrine.md` §5 — Why no mTLS is safe here: the network restriction *is* the security boundary](../documents/engineering/host_cluster_comms_doctrine.md#5-why-no-mtls-is-safe-here-the-network-restriction-is-the-security-boundary)
  (*why no mTLS is safe here*), the loopback-NodePort realization and prodbox precedent of [`host_cluster_comms_doctrine.md` §6 — The host-only restriction in practice (and its sibling precedent)](../documents/engineering/host_cluster_comms_doctrine.md#6-the-host-only-restriction-in-practice-and-its-sibling-precedent),
  and the type-excluded illegal states of [`host_cluster_comms_doctrine.md` §7 — What the DSL makes unrepresentable here](../documents/engineering/host_cluster_comms_doctrine.md#7-what-the-dsl-makes-unrepresentable-here)
  (*what the DSL makes unrepresentable here*).
- [`substrate_doctrine.md` §5 — Host worker nodes: substrate-specific hardware that cannot be containerized](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-cannot-be-containerized)
  — *host worker nodes: substrate-specific hardware that refuses to be contained*: this phase's target must implement the
  apple host worker (Apple-Metal on unified memory) as a managed subprocess of the host binary with the
  Load → Prereq → Acquire → Ready → Serve → Drain → Exit role lifecycle, built via the virtualized-substrate
  provider of [`substrate_doctrine.md` §4 — Virtualized substrates: synthesizing a Linux host where the host is not Linux](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux)
  ([`substrate_doctrine.md` §4.1 — Colima and Lima on Apple: the provider follows the workload](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload) for the Linux VM),
  all under the [`substrate_doctrine.md` §3 — The no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)
  *no-environment / no-`PATH` lazy tool-ensure contract* rooted in the Haskell host path after the bounded
  Python `pb` pre-binary handoff of
  [`substrate_doctrine.md` §6 — The pre-binary handoff contract](../documents/engineering/substrate_doctrine.md#6-the-pre-binary-handoff-contract),
  never a shell script or Python-owned host-policy path.
- [`resource_capacity_types.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`; “The systematic provision matrix”](../documents/engineering/resource_capacity_types.md#31-the-systematic-provision-matrix)
  and [`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — *the systematic provision matrix* / *the total provision fold*: the Apple physical host is the single
  supply owner. The Lima VM carves CPU/memory plus a presentation/allocation-derived private raw disk whose
  guest-usable layout and sparse physical high-water are distinct; the VM node and pods consume net
  CPU/memory/local ephemeral storage; the host worker requires a compatible `AppleMetalOffering` profile and
  consumes CPU/non-Metal runtime memory plus the private worst permitted `MetalOwnerDemand` unified-memory
  epoch; and the jit cache carves one
  bounded host-cache pool. Unified memory and storage are each charged once, with disjoint pool witnesses,
  before any live effect.
- [`apple_metal_headless_builds.md` §1 — The commitment: headless, on-host, no VM](../documents/engineering/apple_metal_headless_builds.md#1-the-commitment-headless-on-host-no-vm)
  — *the commitment: headless, on-host, no VM* — with [`§3 — Architecture`](../documents/engineering/apple_metal_headless_builds.md#3-architecture)
  (the fixed host Metal bridge), [`§4 — Build and prerequisite model`](../documents/engineering/apple_metal_headless_builds.md#4-build-and-prerequisite-model),
  and [`apple_metal_headless_builds.md` §6 — Why Tart is not viable (the no-VM rationale)](../documents/engineering/apple_metal_headless_builds.md#6-why-tart-is-not-viable-the-no-vm-rationale):
  this phase's target must build the Apple-Metal worker **headless on the host — no Tart, no macOS VM** — source-building the
  fixed Objective-C/C Metal bridge with `/usr/bin/clang` by absolute path and compiling generated MSL at
  runtime through the OS Metal framework, so a cache miss never starts a VM, invokes SwiftPM, or depends on a
  login keychain.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and a human tracker change.

## Sprint 89.1: Apple substrate management — Lima Linux VM + brew lazy tool-ensure ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`substrate_doctrine.md §4.1 — Colima and Lima on Apple`](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload)
and [`substrate_doctrine.md §3`](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)
— the no-environment / no-`PATH` lazy tool-ensure contract — reached after the bounded Python `pb` pre-binary handoff of
[`substrate_doctrine.md` §6 — The pre-binary handoff contract](../documents/engineering/substrate_doctrine.md#6-the-pre-binary-handoff-contract):
synthesize the Linux host the apple substrate's cluster runs on via Lima, with every host tool ensured and
invoked by absolute path through brew — the substrate foundation every later Phase-89 sprint stands on. The
physical-host provision fold this sprint builds adopts [`resource_capacity_types.md §3.1`](../documents/engineering/resource_capacity_types.md#31-the-systematic-provision-matrix)
and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
— the systematic provision matrix and the total provision fold.

### Deliverables

- An apple-substrate manager that drives Lima (`limactl`) to start a named, budget-sized Ubuntu-24.04 VM and
  re-invokes amoebius subcommands inside it via `limactl shell <vm> -- <amoebius> <subcmd>` (the composition
  lift is owned elsewhere and only consumed here).
- A pure physical-host resource plan that inventories allocatable CPU, unified memory, and disjoint VM-disk /
  durable-backing / host-cache pools; carves the Lima VM; derives the VM node's net allocatable CPU, memory,
  logical local ephemeral storage and closed filesystem/content-snapshot layout capacity. Its raw
  `VmDiskCarve` has
  `{ id, presentation : FilesystemPresentation, allocation, guestSystem, kubelet }` and deliberately has no
  `bytes` field or `Block` presentation. The fold
  sums the guest-system carve and the unique carves prescribed by the kubelet filesystem layout into
  `requiredUsableBytes`, applies the versioned filesystem/sparse-image overhead and
  `BackingAllocationPolicy { minimumBytes, quantumBytes }`, and alone returns the opaque private
  `ProvisionedVmDiskCarve { id, requiredUsableBytes, provisionedBytes, presentation, allocation, witness }`,
  with `id` copied unchanged from the raw carve. It proves the
  guest-usable carves fit the resulting presentation, charges the sparse raw-allocation high-water
  `provisionedBytes` once to the physical partition, and proves the remaining host supply fits the Metal
  worker and cache. It also carries the fixed bridge's single-stage
  `BuildExecutionEnvelope`: clang CPU/RSS, intermediate object/dylib scratch on a named `BuildScratch` pool,
  compiler-cache write delta/backing, and serial architecture/stage concurrency. Transition admission proves
  both `VM + bridge build` and `VM + worker` epochs (not an invalid sum of non-overlapping peaks). The
  constructor returned to the effectful driver is opaque, so `limactl create/start` cannot receive an unchecked
  shape.
- A read-only `observeHost → diff → validatePlan` live boundary that converts that pure plan into a
  single-use `ValidatedAppleHostPlan` bound to the physical CPU/memory/process/disk/cache/Metal fingerprint.
  Every `brew` mutation, Lima create/start, bridge build, cache write, and worker `Acquire` requires the token;
  the fingerprint is re-read immediately before the first mutation and change restarts the read-only prefix.
  The disk fingerprint includes parent-device identity/free bytes, Lima sparse-image raw virtual and host
  allocated byte counts, guest mount/device identities, mounted usable bytes, fs types, and the layout-carve
  quota/partition limits; aliasing, a missing mount, or an unobservable value refuses.
- A brew-rooted lazy-tool-ensure binding: probe → install-if-absent → resolve the absolute path from the
  package manager (`brew --prefix`) → invoke by full path; the install *plan* is a pure value so the substrate
  branching is unit-tested without invoking brew, and only the driver is `IO`. Its
  `BootstrapExecutionEnvelope` includes probe/installer CPU+memory, installed bytes, peak download/unpack and
  logs on named `ToolInstall`/scratch backings, cache delta, and serial tool-install concurrency; it is
  provisioned in the bootstrap epoch before `brew install`, not hidden inside the later VM/worker steady row.
- A substrate-applicability guard so the apple reconcilers fail fast — before any side effect — when run on a
  non-apple substrate, with a one-line diagnostic.

### Validation

1. With `limactl` absent, the reconciler installs it via brew, re-resolves it to an absolute path, and starts
   the VM; with it present, the same call is a verified no-op (idempotent).
2. A unit test exercises the pure install plan for apple without invoking brew.
3. Cross-check the live physical-host and VM/node inventory against
   `test/golden/apple_metal_host_daemon/resource_fold.json`; observed supply below any declared CPU, memory/unified-memory, or
   storage value fails. Before creation, rederive the current fixture's
   `requiredUsableBytes` from the guest system plus unique kubelet-layout carves, apply its
   `FilesystemPresentation` overhead and backing minimum/quantum, and assert the private result is the pinned
   40-GiB raw `provisionedBytes`; the raw field cannot be supplied directly. Reserve that sparse-allocation
   high-water exactly once in the parent physical-disk ledger keyed by the unchanged
   `ProvisionedVmDiskCarve.id`. One-field negatives that drop or swap the id, debit the wrong parent, overdraw host unified
   memory, overlap the VM-disk and cache pools, exceed the physical CPU, double-charge or omit the VM sparse
   high-water, or remove/change the compatible `AppleMetalOffering MetalProfile` reject
   before `brew install`, `limactl create`, bridge build, or cache write; the Metal case returns
   `MissingCapability AppleMetal`/profile mismatch and an external effects trace is empty.
   A changed-snapshot fixture allocates host memory, parent-disk/sparse-image high-water, or cache bytes after
   validation but before Lima/worker enactment; the immediate token recheck refuses and the trace contains zero
   brew/Lima/bridge/cache/worker mutation.
4. After Lima creates the accepted disk, independently assert `qemu-img info`/Lima reports raw virtual size
   `== ProvisionedVmDiskCarve.provisionedBytes` for the same `ProvisionedVmDiskCarve.id`; inside the guest,
   assert the root/layout mounts expose the
   declared `fsType`, each quota/partition supplies its promised usable bytes, and their unique-carve sum plus
   guest-system reserve equals `requiredUsableBytes`. At the host boundary, record allocated sparse bytes
   (`st_blocks`/Lima's actual-size observer), drive the fixture through its pinned allocation high-water, and
   assert allocation never exceeds the once-reserved high-water or spills into durable/cache carves. A live
   raw virtual disk one byte below the witness, an incorrect fs type, a missing layout hard cap, or a host
   allocated high-water above the witness refuses start/continuation and turns the external oracle red.
5. Run `vm_disk_boundaries.csv`: the exact-boundary case fits; adding one guest-usable byte crosses the
   allocation quantum and, with the same parent residual, rejects before `brew install`/Lima create. A
   provisioner mutant that omits filesystem/sparse-image overhead or rounds down instead of up is caught by
   the independent expected witness. The paired live one-byte-short image is rejected by Validation 4. Every
   failure has an empty mutation trace up to the deliberate observer-created live mutant.
6. Execution-boundary trace check (not a source grep): the whole sprint run is driven through the tool-ensure
   seam, which records `(argv, env)` for every spawn, and is additionally run under an OS-boundary exec trace
   (`dtruss`/`execsnoop` capturing every `execve` and its environment). The suite asserts, from the trace, that
   **every** recorded `argv[0]` is an absolute path (no bare command name) and every spawn's environment is
   exactly the fixed closed allow-set the contract permits (`PATH` absent from it) — covering transitively
   spawned subprocesses and library-issued execs, which a grep of the author's modules cannot see.

### Remaining Work

Physical Apple/Lima/brew and live VM-disk observations remain UNVERIFIED on the current Linux host.

## Sprint 89.2: Host-only loopback NodePort exposure of the content-mutation gateway + Pulsar ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`host_cluster_comms_doctrine.md §6 — the host-only restriction in practice`](../documents/engineering/host_cluster_comms_doctrine.md#6-the-host-only-restriction-in-practice-and-its-sibling-precedent)
and [`§1 — two channels, both localhost-only`](../documents/engineering/host_cluster_comms_doctrine.md#1-the-host-origin-surface-two-channels-both-localhost-only):
realize channel 2's transport — a NodePort bound to the host's loopback so the daemon connects to
`127.0.0.1:<nodeport>` with no path from LAN/WAN — applying the sibling project's loopback-only precedent
(sibling evidence, not an amoebius result) onto the Lima-backed apple substrate, whose Lima VM node network —
per [`substrate_doctrine.md §4.1 — Colima and Lima on Apple`](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload)
— this sprint's substrate-layer loopback binding constrains. The rendered manifests are
emitted from Haskell and never committed.

### Deliverables

- Exactly two rendered host-only NodePort Services in the representative arm —
  `{ContentMutationGateway, Pulsar}` — whose reachability is restricted to host-origin traffic, plus the
  substrate-layer loopback binding / host-only firewalling that makes the
  `127.0.0.1:<nodeport>` shape hold on the Lima VM **without relaxing the restriction** (never by publishing
  the port wider). The MinIO backend has no raw NodePort and has no credential or route reachable by the host
  worker.
- A closed optional raw-content-read arm: `None` for the representative fixture, or a separately counted
  read-only Service with its own identity, read-only credential, complete provisioned Service/API-object and
  backing demand, and no PUT/DELETE/multipart/mutation route. A raw MinIO mutation endpoint is not an arm.
- An assertion seam proving the negative: no `LoadBalancer` Service, no Gateway/HTTPRoute, and no wild listener
  references any selected host-origin port — these are the only channel-2 endpoints and they are
  localhost-only.
- A recorded note that the same loopback shape is what the windows substrate's WSL2 case would target, as
  target shape (not exercised by the apple gate).

### Validation

1. Connect to the content-mutation gateway and Pulsar from the host at `127.0.0.1:<nodeport>` and succeed;
   attempt the same from a second physical host on the LAN and from the host's routable
   `<lan-ip>:<nodeport>` (WAN-equivalent probe) and fail — where fail means `connection refused`/`no route` or
   a connect that does not complete within a 5s timeout (no established session), per the Independent
   Validation definition.
2. Assert the representative render has exactly `{ContentMutationGateway, Pulsar}` host-origin Services, no
   raw MinIO backend listener, no `LoadBalancer`-typed Service and no Envoy route fronting either port. In the
   separately tested optional raw-GET arm, count the third Service and its resource/API-object demand, then
   prove a content-addressed GET succeeds while direct PUT, DELETE and multipart initiation are denied and no
   mutation route or credential is present.
3. Tear the cluster down and back up; the loopback binding is re-established idempotently.

### Remaining Work

The portable and Linux loopback boundary is tested; Lima NodePort realization and a second physical LAN-host probe remain UNVERIFIED.

## Sprint 89.3: Headless host-native Metal bridge + native worker build (no Tart) ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`apple_metal_headless_builds.md §1 — the commitment: headless, on-host, no VM`](../documents/engineering/apple_metal_headless_builds.md#1-the-commitment-headless-on-host-no-vm),
[`§3 — Architecture`](../documents/engineering/apple_metal_headless_builds.md#3-architecture),
[`§4 — Build and prerequisite model`](../documents/engineering/apple_metal_headless_builds.md#4-build-and-prerequisite-model),
and [`§6 — Why Tart is not viable`](../documents/engineering/apple_metal_headless_builds.md#6-why-tart-is-not-viable-the-no-vm-rationale),
with the host-worker build rule of [`substrate_doctrine.md §5`](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-cannot-be-containerized):
build the Apple-Metal worker **headless, directly on the host — with no macOS VM (no Tart)** — so build
provenance is host-controlled without inheriting VM lifecycle, keychain, or SwiftPM surfaces. The
headless fixed-bridge shape is proven in the sibling jitML project (sibling evidence, not an amoebius result);
this sprint realizes it in amoebius for the first time.

### Deliverables

- A one-stage host `BuildExecutionEnvelope` for the fixed bridge: `/usr/bin/clang` CPU/memory envelope,
  object/dylib intermediate bytes, compiler-cache write delta, named `BuildScratch`/cache backings, and serial
  architecture/stage policies. The bridge-build action consumes the unchanged Apple-host snapshot token and
  runs in the declared process/disk policies; it is not steady worker overhead.
- A fixed Objective-C/C Metal bridge, source-built once on the host by invoking `/usr/bin/clang` **by absolute path** (linking macOS `Foundation`/`Metal`), then `dlopen`'d and verified by resolving an exported probe
  symbol before the worker subscribes to work — no env, no `PATH`, no VM.
- Runtime MSL compilation: the host binary renders Metal Shading Language, writes a content-addressed
  source-metadata cache record into the Phase-80 `CacheBudget`-bounded cache, and dispatches through the
  bridge's `MTLDevice.makeLibrary(source:options:)` with fast-math **off** (the Phase-80 determinism
  contract), reusing an in-process pipeline cache across calls. The cache has one explicit host backing and
  bounded peak occupancy (resident artifacts plus temporary materialization and headroom); it cannot reuse the
  Lima VM disk or durable backing as an unaccounted second name for the same bytes.
- The native Apple-Metal worker built on-host (targeting Apple Silicon unified memory) as a host-worker binary,
  **not** a container image, carrying an explicit host `ResourceEnvelope` for CPU, non-Metal runtime memory,
  identity-complete `MetalOwnerDemand` (profile, exact source/workload maps, structural residency, finite
  coexistence policy), and cache demand; only the private aggregate unified-memory epoch peak can render. The optional Homebrew-`swiftc` +
  explicit-`SDKROOT` lane is available for any non-core Swift parts but is never the cache-miss path and never
  a VM.

### Validation

1. Build the fixed bridge with `/usr/bin/clang`, `dlopen` it, and pass its probe; assert (from the
   Sprint-80.3 exec trace, not a self-report) no `tart`/VM process was started and no `security`/keychain
   unlock call was made.
   Independently overdraw clang CPU/RSS, intermediate scratch, and compiler-cache write headroom and make the
   scratch identity unknown. Each case starts zero clang processes and writes zero object/cache bytes. For a
   fitting build, an OS/config observer proves the compiler stays within CPU/RSS and named backing ceilings;
   deliberate overrun is throttled/terminated/`ENOSPC`, never spilled elsewhere.
2. Compile generated MSL at runtime and dispatch A, B, and nonce-derived C. Generate all three expected outputs
   with `test/golden/apple_metal_host_daemon/metal_job_ref.py` under `.build/runs/phase_86/`; require exact equality, distinct
   A/B output, and a real `MTLLibrary`/pipeline-reflection/`MTLBuffer` observation. Assert bit-stable output
   under the fast-math-off determinism contract by recomputing `job_A` on a **cache-bypassed** run in a distinct
   content-addressed namespace and asserting the compute path (MSL compile + GPU dispatch) actually executed and
   produced a bit-identical result — a store hit does not satisfy this. The committed mutants
   `test/mutant/apple_metal_host_daemon/const_output.patch` and `cpu_reference_bypass.patch` must each turn this validation
   red at the numeric or Metal-observer locus respectively.
   The OS-boundary memory/cache observer also confirms the worker stays within its declared runtime +
   Metal-unified-memory ceiling and the host cache stays inside its one carved backing; crossing either ceiling
   is red even if the numerical output is correct.
3. Execution-boundary trace check (not a source grep): under the OS-boundary exec trace, assert every tool the
   build/dispatch path spawns has an absolute-path `argv[0]`, every spawn env is the fixed closed allow-set with `PATH` absent, and the trace contains no `tart`, `swift build`, or offline `metal` compiler `execve` on the core path — covering transitively spawned processes a module grep cannot observe.

### Remaining Work

Remove the tracked A/B expected files, retain the reviewed reference script and inputs, replace the replay
mutant, and generate expectations at run time. Physical bridge compilation,
`MTLDevice`/`MTLLibrary` observation, and GPU dispatch remain UNVERIFIED.

## Sprint 89.4: Host compute daemon lifecycle as a managed subprocess ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`substrate_doctrine.md §5 — host worker nodes: substrate-specific hardware that refuses to be contained`](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-cannot-be-containerized):
run the Apple-Metal worker as a **managed subprocess of the host binary** — the one place amoebius compute
lives outside a cluster pod — with the stateless-role lifecycle and a guaranteed drain, so the worker has a
defined startup and a clean shutdown rather than an unmanaged background process.

### Deliverables

- A supervised host-worker lifecycle implementing Load → Prereq → Acquire → Ready → Serve → Drain → Exit, with
  the drain guaranteed via bracket-style resource handling even when `Serve` raises.
- `Acquire` consumes only the opaque host placement/cache witness produced by the physical-host fold and applies
  the declared CPU/non-Metal-runtime-memory/Apple-unified-memory/cache bounds through the private
  `AppleSupervisor` enforcement witness; there is no constructor that launches a worker from raw unchecked
  quantities or debits Metal memory from a second pool.
- Enforcement is externally observable and explicitly reactive: the finite `AppleSupervisor` policy samples
  process CPU/RSS and the Metal bridge's `MTLDevice.currentAllocatedSize`, terminates after the declared
  consecutive-breach bound, and restricts cache writes to the named bounded carve. macOS is not claimed to
  provide a Linux-cgroup/Windows-Job-style instantaneous hard CPU/RSS quota or scheduler reservation.
  A worker that requires such a stronger guarantee returns `UnsupportedEnforcement` before `Acquire`;
  crossings under the supported supervised policy are terminated/refused, not merely logged.
- Prerequisite gating that fails fast — before `Serve` — when the Metal worker binary, the host-only NodePort
  endpoints, or the worker's content-mutation-gateway/Pulsar credential names are not available, with a
  one-line diagnostic; no raw MinIO mutation credential is accepted.
- Subprocess ownership tying the worker's lifetime to the host binary: a host-binary exit (clean or signal)
  drains and reaps the worker; no orphaned process survives.

### Validation

1. Start the worker, force `Serve` to throw, and assert `Drain` still runs and resources are released.
2. Remove a prerequisite and assert a fast, pre-`Serve` failure with an actionable message.
3. Kill the host binary mid-`Serve` and assert the worker subprocess is drained and gone.
4. Mutate the worker demand so the VM carve plus host/runtime headroom plus worker non-Metal runtime and Metal
   unified-memory ceiling exceed physical memory; assert failure before `Acquire` and zero worker/cache effects.
5. Run deliberate CPU, RSS, Metal-allocation, and cache-write overrun fixtures. An OS process observer plus an
   independent supervisor-event reader proves the declared sample interval/consecutive-breach/terminate policy
   is applied, no process survives beyond that finite breach window,
   `MTLDevice.currentAllocatedSize` is covered by the same response, and the cache carve never exceeds its
   cap. A hard-enforcement-required fixture rejects as `UnsupportedEnforcement`; a mutant that launches the
   worker without applying the supervisor must turn every corresponding oracle red.
6. Race two supervisor starts against the same host-ledger root and require one CAS winner. Crash after
   Reserved and after LaunchInFlight, then restart: identical reservation retry is idempotent, an observed PID
   repairs to Running, and an unknown launch outcome remains charged. During replacement, stale drain/process/
   Metal/cache observations, process-absent with retained cache/log extents, or a second start before
   `ValidatedMetalReleaseEvidence` must produce no launch capability. Exact observed cleanup releases retained
   artifacts only by a new CAS.

### Remaining Work

The lifecycle and finite policy are tested; macOS process/Metal observers and crash-repair CAS remain UNVERIFIED.

## Sprint 89.5: Channel-2 peer + wild-exposure unrepresentable + the Apple-Metal peer gate ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`host_cluster_comms_doctrine.md §3 — coordination is Pulsar + MinIO`](../documents/engineering/host_cluster_comms_doctrine.md#3-there-is-no-bespoke-control-channel--coordination-is-pulsar--minio)
with the resolution of [`§2`](../documents/engineering/host_cluster_comms_doctrine.md#2-the-decision-that-was-open-and-is-now-resolved),
the threat model of [`§5 — why no mTLS is safe here`](../documents/engineering/host_cluster_comms_doctrine.md#5-why-no-mtls-is-safe-here-the-network-restriction-is-the-security-boundary),
and the type-exclusions of [`§7 — what the DSL makes unrepresentable here`](../documents/engineering/host_cluster_comms_doctrine.md#7-what-the-dsl-makes-unrepresentable-here):
make the host worker an ordinary Pulsar/gateway-backed-content-store peer over the host-only NodePorts with no custom RPC and no
transport crypto, close the carve-out so its boundaries cannot be drawn wrong, and prove the phase gate from
[`§1`](../documents/engineering/host_cluster_comms_doctrine.md#1-the-host-origin-surface-two-channels-both-localhost-only)
— an Apple-Silicon host daemon runs a Metal ML workload as a cluster Pulsar/gateway-backed-content-store peer.

### Deliverables

- A channel-2 peer that consumes its work topic via the shared native-protocol Pulsar client (at-least-once +
  dedup preserved; broker ids/timestamps are never part of any content address) and writes results to
  `blobs/<sha256>` + a content-addressed manifest through the sole mutation gateway into MinIO — the same coordination shape an
  in-cluster worker Pod uses — over a plain socket on `127.0.0.1:<nodeport>` with **no mTLS layer added**, and
  secrets-by-name client auth resolved through Vault (no host env, no `PATH`, no bespoke RPC to the binary).
- Type-level exclusions instantiated from the illegal-state catalog: a host-origin NodePort cannot be expressed
  as `LoadBalancer`-typed, Envoy-routed, or wild-listening, and a host compute daemon cannot publish its own
  wild ingress — its only inbound coordination is Pulsar plus the provisioned content endpoint. Raw MinIO
  mutation authority is unrepresentable; an optional raw-GET Service is a distinct read-only arm.
- The gate `.dhall` (`test/fixture/dhall/phase_75_apple_metal_peer.dhall`) is a **generated artifact emitted from Haskell at gate-run time and never committed** — its byte-authority is the authored Haskell emitter in
  `src/Amoebius/HostWorker/Peer.hs` / `HostComms/Illegal.hs`, per development_plan_standards [§B](development_plan_standards.md#b-canonical-file-layout-snake_case) (Implementation names authored source, never a generated artifact). The authority for the type-check negatives is
  instead a separately authored Haskell host-comms oracle plus four Haskell one-field mutation operators; all
  serialized illegal cases are emitted beneath `.build/test-corpora/**`. The gate `.dhall`, once emitted, drives:
  derive and verify the complete physical-host → Lima-VM/node + host-worker + cache provision witness —
  including the private presentation/allocation-rounded `ProvisionedVmDiskCarve` and its once-charged sparse
  high-water; bring up the apple cluster on Lima; expose the content-mutation gateway and Pulsar on the
  host-only loopback NodePorts while proving the raw MinIO backend remains unexposed; and
  build the worker
  **headless on-host via the fixed Metal bridge (no VM)**, start the daemon as a managed subprocess, dispatch a
  Metal inference job over Pulsar, land its output in the content-addressed store, then tear the worker and
  cluster down — emitting a ledger recording NodePort-is-localhost-only and no-mTLS / no-bespoke-RPC as
  **tested on apple**, and Apple-Metal physics as **assumed** (prodbox loopback precedent, not an amoebius
  proof).
- The complete provider/compiler/supervisor/worker/harness host envelopes, surviving-cluster inventory,
  exact `MetalOwnerDemand` source/workload/coexistence input, private aggregate epoch witness,
  output-object/cache transition, and `MetalDrainThenReplaceAfterObservedExit` policy from the phase resource
  contract. Native clients are charged to the worker and the NodePort introduces no imaginary Pod.

### Validation

1. Each of the four committed wild-exposure negatives in `test/fixture/dhall/phase_75_illegal/` (NodePort as
   `LoadBalancer`; Envoy/HTTPRoute route on the port; wild listener on the port; daemon wild ingress) — each a
   one-field mutation of the committed green host-comms spec, differing only in the foreclosed field — fails
   `dhall type` with the pinned structured error naming its specific violated exclusion (asserted against the
   corpus-registered expected error string at its validation-locus tag), while the green spec type-checks; the
   committed mutant `test/mutant/apple_metal_host_daemon/lb_nodeport.patch` (which re-types the NodePort `LoadBalancer` in the
   *gate* spec) must turn this validation red.
2. The gate `.dhall` runs the full Apple-Metal peer workflow: the worker consumes the job over native Pulsar
   (no WebSocket frames, no TLS handshake, only `127.0.0.1:<nodeport>`), and the output landed through the
   provisioned mutation gateway in MinIO,
   retrieved by content address, equals the fresh reference output generated under the run bundle for reviewed
   inputs A/B and nonce-derived challenge C. A and B yield distinct outputs, so a constant result fails. The
   committed `cpu_reference_bypass.patch` returns correct numerical bytes without a Metal dispatch and must
   fail the external `MTLDevice`/library/pipeline/buffer observation. The gate then tears down leak-free per the
   three-part residue check.
3. The live host, Lima VM, Kubernetes node, pods, host worker, private Metal epoch peak, cache, and storage inventory
   matches the Phase-0 resource-fold oracle: all CPU, memory/unified-memory, logical pod-ephemeral,
   layout-routed OCI content/snapshot/workspace, durable, and cache demands fit with nested/disjoint pool
   ownership. The VM's raw virtual size equals private
   `provisionedBytes`; its mounted guest/layout usable bytes and fs types match the presentation witness; and
   its sparse host allocation stays within the single parent-ledger high-water debit. The over-memory,
   overlapping-storage, one-byte-short-raw-disk, next-allocation-quantum, double-debit, omitted-work-item,
   coexistence-domain-mismatch, favorable-epoch, co-resident-overlap-one-short, and
   missing/incompatible-Metal-profile negatives fail before any Lima/bridge/cache/worker mutation (except the
   deliberately materialized live-short-disk observer fixture, which refuses start before workload effects).
4. Auth resolves the worker's content-mutation-gateway/Pulsar credentials by name through Vault with no
   env/`PATH` read and supplies no raw MinIO mutation credential; the ledger artifact is emitted and marks
   the Apple-Metal physics row as assumed, not green.
5. Independently lower every provider/compiler/worker/harness CPU, memory, process, writable/log/scratch/cache,
   client-buffer and object-overlap operand by one unit/byte, and lower each surviving pod/IP/CSI/image/storage
   residual by one. Each case returns its pinned `Left` before effects. Dropped-execution-envelope and
   premature-replacement, omitted-work-item, favorable-epoch, and dropped-overlap-debit mutants turn the
   external process/Metal/cache/store observer red; the exact-fit
   control live-readbacks equal the private provision projection.

### Remaining Work

Remove the tracked expected outputs and old replay mutant as part of Sprint 89.3. The pure peer/auth and
illegal-state boundaries are tested; the physical Apple Pulsar/gateway/MinIO/Vault workflow remains UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/host_cluster_comms_doctrine.md` — its §9 planning-ownership pointer resolves to
  delivered Phase-89 sprints, and the §2/§5/§6 honesty notes flip from "resolved design decision / sibling
  evidence" to a delivered, apple-tested channel-2 peer (status recorded here in the plan, never as doctrine
  status); add the `Amoebius.HostComms.*` and `Amoebius.HostWorker.*` module paths to its cross-reference set.
- `documents/engineering/apple_metal_headless_builds.md` — its §1/§3/§4/§6 honesty notes flip from "jitML
  sibling evidence / design intent" to a delivered, apple-tested amoebius fixed-Metal-bridge build (status in
  the plan, never as doctrine status).
- `documents/engineering/substrate_doctrine.md` — its §9 planning-ownership pointer resolves to delivered
  Phase-89 sprints; the §4.3 "no macOS build VM" note and the §5 host-worker description gain their first
  amoebius datapoint on apple; record that the Lima provider, the headless on-host Metal-bridge build, and the
  Haskell-owned brew lazy-tool-ensure were exercised by full-path subprocess with no env/`PATH`; record the live
  raw-virtual/usable/fs-type/sparse-high-water observations for the materialized VM disk.
- `documents/engineering/resource_capacity_doctrine.md` — record the Phase-89 live check for private
  `ProvisionedVmDiskCarve` derivation, minimum/quantum boundaries, and the once-only sparse physical-disk
  high-water debit without changing the canonical type or arithmetic owned there.

**Cross-references to add:**

- [README.md](README.md) — flip the Phase-89 row status once the gate passes and link this document.
- [substrates.md](substrates.md) — record Phase 89's gate substrate (apple) in the per-phase substrate map, and
  note the windows-CUDA host worker as the structurally identical non-gate case.
- [system_components.md](system_components.md) — register the host-worker and host-comms modules
  (`Substrate/Apple`, `Substrate/Lima`, `Substrate/Brew`, `HostComms/NodePort`, `HostComms/Loopback`,
  `HostWorker/MetalBridge`, `HostWorker/Lifecycle`, `HostWorker/Peer`) and the `AppleMetalPeerSpec` live suite
  as Phase-89 design-first rows.

## Related Documents

- [README.md](README.md) — the live tracker; the Phase 89 row is the authoritative one-line gate and status
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the Register-3 honesty token: a passed gate is a live-substrate result, never a compile claim)
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (the host-only NodePort carve-out, host worker nodes, the stateless `replicas=1` control-plane daemon, and jit-resolved engine payloads)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Host ↔ Cluster Comms Doctrine](../documents/engineering/host_cluster_comms_doctrine.md) — the host-only
  NodePort, no-mTLS channel-2 peer design this phase implements
- [Apple Metal Headless Builds](../documents/engineering/apple_metal_headless_builds.md) — the headless,
  on-host, no-Tart fixed-Metal-bridge build/run shape this phase implements
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) — the apple host worker, the Lima
  provider and the Haskell no-env/no-`PATH` tool-ensure; the earlier `pb` pre-binary handoff is a dependency,
  not a Phase-89 implementation surface
- [Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) — the native-protocol CBOR
  client the peer rides on (cross-reference, not adopted here)
- [Vault / PKI Doctrine](../documents/engineering/vault_pki_doctrine.md) — the secrets-by-name client auth the
  channel-2 peer resolves through (cross-reference, not adopted here)
- [phase_80](phase_80_determinism_jitcache.md) — the jit-build engine resolver + `CacheBudget` cache the Metal
  kernel is materialized into
- [phase_93](phase_93_jitml_rederivation.md) — the CUDA jitML lift; its Windows-CUDA case is the structurally
  identical host worker on a different substrate
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
