# Substrate Registry and Per-Phase Substrate Map

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, development_plan_standards.md, later_phases.md, legacy_tracking_for_deletion.md, overview.md, phase_00_documentation_suite.md, phase_01_formal_first_dsl_integrity.md, phase_02_bootstrap_kernel_kind.md, phase_03_platform_services_storage_vault.md, phase_04_dsl_control_plane_singleton.md, phase_05_pulsar_content_store_workflow.md, phase_06_determinism_infernix.md, phase_07_jitml_ha_coordinator.md, phase_08_host_compute_daemons.md, phase_09_multicluster_spawn_georeplication.md, phase_10_provider_clusters_provisioning.md, phase_11_test_topology_dsl.md, phase_12_spa_composition.md, system_components.md
**Generated sections**: none

> **Purpose**: The plan-side substrate registry and the per-phase substrate map — which single substrate each
> phase's acceptance gate keys to (phases 0–12), keyed to the closed substrate catalog owned by the substrate
> doctrine.

---

## 1. The one-substrate-per-validation discipline

This document is the **plan-side projection** of the substrate catalog. The normative catalog — what the four
substrate names *mean*, how they are detected, the no-`PATH` lazy tool-ensure contract, the virtualization
strategy, and the host-worker carve-out — is owned in full by
[`substrate_doctrine.md` §1 — the substrate is a fact about the host, not a knob](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob).
This file does not restate that doctrine; it records **which substrate each phase gate runs on** and keeps
that map honest against the plan.

The governing rule is the one-substrate discipline from
[`development_plan_standards.md` §L — one-substrate discipline](development_plan_standards.md#l-one-substrate-discipline)
and the [README.md Phase discipline](README.md#phase-discipline): **a phase's acceptance gate requires at
most one substrate** (`apple` | `linux-cuda` | `linux-cpu` | `windows`), named in that phase's `Phase
Summary` and tracked here. This prevents cross-substrate flip-flopping mid-development — a phase whose work
would touch several substrates is split until each gate is single-substrate. A phase that needs no host at all
(pure documentation or pure type-checking) is `none`.

Two facts from the doctrine make this discipline enforceable rather than aspirational:

- **The catalog is closed and detected, not configured.** The substrate is read from the host (OS,
  architecture, GPU presence) and classified into one of four members; it is never an operator knob
  ([`substrate_doctrine.md` §1](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob)).
  A `.dhall` therefore cannot assert a substrate a machine does not have.
- **Substrate equivalence is near-total.** Every cluster on every substrate stands up the identical standard
  service set; the *single* lower-layer difference the substrate dictates is the LoadBalancer
  ([`substrate_doctrine.md` §7 — the LoadBalancer is the one substrate-driven platform difference](../documents/engineering/substrate_doctrine.md#7-the-loadbalancer-is-the-one-substrate-driven-platform-difference),
  reinforced by
  [`platform_services_doctrine.md` §12 — substrate equivalence as a structural invariant](../documents/engineering/platform_services_doctrine.md#12-substrate-equivalence-as-a-structural-invariant)).
  So a gate written for `linux-cpu` differs from the same work on a provider substrate only at the LB and DNS
  layers, never in the service set.

> **Honesty.** The whole amoebius suite is greenfield: nothing in the table below is implemented. Every
> `Status` cell is 📋 Planned and every substrate row is a **target gate**, not an exercised result. Where
> detection and the virtualization providers lean on the sibling `hostbootstrap` library, that is *evidence
> from a sibling*, not amoebius proof — see the honesty notes in
> [`substrate_doctrine.md`](../documents/engineering/substrate_doctrine.md). Live status is owned only by
> [README.md](README.md).

---

## 2. Substrate inventory

The four members of the closed catalog
([`substrate_doctrine.md` §1](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob)),
each as a plan-side registry entry. The doctrine owns *why* each is special; this is the projection keyed to
gates.

> **Two axes — detected vs declared.** The four members below are the **detected** host substrate (a fact
> about the machine, never a knob). The **compute engine** — `kind` / `rke2` / `Managed EKS` — is a separate
> **declared** axis owned by
> [`cluster_topology_doctrine.md`](../documents/engineering/cluster_topology_doctrine.md); EKS is therefore a
> *managed provider entry* (below), **not** a fifth detected substrate. Each host entry also **advertises a
> declared `Capacity`** (cpu / mem / disk / gpu) — the number the capacity fold
> ([`resource_capacity_doctrine.md`](../documents/engineering/resource_capacity_doctrine.md) §4) checks
> workload/VM/engine demand against, cross-checked at runtime against detection (§2 of the substrate
> doctrine). The registry records that a `Capacity` is declared per host/node; the fold and its layer are the
> capacity doctrine's.

### apple

| Field | Value |
|-------|-------|
| Host kind | macOS on Apple Silicon — the admin laptop / highest-level root cluster host |
| Native arch | `arm64` (always; Intel-Mac is rejected outright, [`substrate_doctrine.md` §1](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob)) |
| GPU axis | Apple Metal — on-host, **not containerizable** (needs unified memory); the worker is built **headless on the host, no VM** ([`apple_metal_headless_builds.md`](../documents/engineering/apple_metal_headless_builds.md)) |
| Virtualization | Lima (Ubuntu-24.04 Linux VM) — see §3. **No macOS build VM (no Tart)**: Apple-Metal builds are headless on-host |
| LoadBalancer | MetalLB (bare-metal / kind / rke2 lane) |
| What it validates | The Phase 8 gate — an Apple-Silicon **host compute daemon** runs a Metal ML workload as an in-cluster Pulsar/MinIO peer over host-only NodePorts ([`substrate_doctrine.md` §5 — host worker nodes](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained)) |
| Gate phase(s) | 8 |
| Status | 📋 Planned |

### linux-cpu

| Field | Value |
|-------|-------|
| Host kind | Linux host — bare-metal / kind / rke2, single- or multi-node |
| Native arch | `amd64` or `arm64` (mixed-arch clusters and multi-arch images are expressible) |
| GPU axis | none |
| Virtualization | none (native Linux); Incus / Colima where a nested Linux VM is wanted |
| LoadBalancer | MetalLB |
| What it validates | The **default validation substrate** — the bulk of the plan: bootstrap, platform services + retained storage, the DSL + control-plane singleton, the Pulsar/store/workflow runtime, CPU-inference determinism, the demo web apps (application-logic-only), multi-cluster spawn/geo-replication/failover, and SPA composition |
| Gate phase(s) | 2, 3, 4, 5, 6, 9, 12 (and the local control side of 10) |
| Status | 📋 Planned |

### linux-cuda

| Field | Value |
|-------|-------|
| Host kind | Linux host with an NVIDIA GPU present (detection promotes the substrate) |
| Native arch | `amd64` or `arm64` |
| GPU axis | NVIDIA present ⇒ **in-cluster** CUDA via the NVIDIA container runtime — the *contained-GPU* case ([`substrate_doctrine.md` §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained) contrast) |
| Virtualization | none |
| LoadBalancer | MetalLB |
| What it validates | The Phase 7 gate — a jitML training run is bit-deterministic per its determinism contract and the HA coordinator fails over; CUDA stays confined behind a default-off cabal flag |
| Gate phase(s) | 7 |
| Status | 📋 Planned |

### windows

| Field | Value |
|-------|-------|
| Host kind | Windows host |
| Native arch | `amd64` |
| GPU axis | CUDA present ⇒ **on-host worker node** — CUDA does not run performantly inside WSL2 ([`substrate_doctrine.md` §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained)) |
| Virtualization | WSL2 (Ubuntu-24.04 Linux distro) for the Linux-host role — see §3 |
| LoadBalancer | MetalLB (when acting as a Linux cluster host) |
| What it validates | No phase gate in 0–12 keys its single substrate to `windows`: Windows participates either as a Linux host (via WSL2) or as the Windows-CUDA host-worker case, which shares the Phase 8 host-compute doctrine whose gate substrate is `apple`. This round elevates the Windows-CUDA host worker to a **first-class** case alongside Apple-Metal — role parity, not evidence parity ([`substrate_doctrine.md` §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained), `daemon_topology_doctrine.md` §4). The standalone `windows` gate is a later-phase concern (README later phases) |
| Gate phase(s) | none in 0–12 (host-worker doctrine shared with Phase 8) |
| Status | 📋 Planned |

> **Honesty.** Detection and classification are seeded from the sibling `hostbootstrap` library (a closed
> `SubstrateName` enum with finer `apple-silicon` / `linux-cpu` / `linux-gpu` / `windows-cpu` / `windows-gpu`
> granularity that the four-name DSL catalog collapses). That seed is **evidence from a sibling**, not an
> amoebius-built behaviour; amoebius has not built Phase 2
> ([`substrate_doctrine.md` §1](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob)).

> **Why `windows` is not split into `windows-cuda` (§F, this round's addition — normative in the doctrine).**
> The amoebius four-name catalog keys each member on the **OS / VM-provider + wire strategy**, not on accelerator
> presence: a Windows host's CUDA reaches the cluster as a **host worker** regardless (CUDA does not run
> performantly under WSL2), so the deployment-shape-changing axis is captured by the Phase-8 host-worker
> elevation (§B), not by a new substrate name. The seed's finer `windows-gpu` member therefore collapses to
> `windows`, while the seed-attributed `linux-gpu` keeps its `linux-gpu` ⇔ amoebius `linux-cuda` mapping — the
> seed strings above are quotations and are kept verbatim. `cuda` names the **NVIDIA accelerator family**; a
> future non-NVIDIA accelerator (e.g. ROCm) would be its own substrate, which is why the amoebius name is
> `linux-cuda`, not the too-generic `gpu`
> ([`substrate_doctrine.md` §1](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob)).

### eks (managed provider — a *declared engine*, not a detected substrate)

EKS is a first-class citizen on the **compute-engine axis**, not a member of the detected substrate catalog:
it has no host to detect and no `LinuxHost` witness. It is the `Managed Eks` arm of the `ComputeEngine` union
([`cluster_topology_doctrine.md`](../documents/engineering/cluster_topology_doctrine.md) §2).

| Field | Value |
|-------|-------|
| Kind | Provider-managed cluster (`Managed Eks`) — no host binary, no host worker daemons, only the in-cluster singleton |
| Detected substrate? | **No** — declared, provisioned over the cloud API from inside a parent ([`pulumi_iac_doctrine.md` §4](../documents/engineering/pulumi_iac_doctrine.md#4-what-pulumi-provisions-the-resource-catalog)) |
| Node capacity | From the declared **instance types**, not a physical host; folded like any other `Capacity` ([`resource_capacity_doctrine.md` §3](../documents/engineering/resource_capacity_doctrine.md)) |
| Storage ceiling | A **cloud quota** (`CloudQuota` `StorageBacking`); "unbounded" storage/compute only via a quota-bounded `ScalingPolicy` |
| LoadBalancer | Cloud LoadBalancer (the one substrate-driven difference, [`substrate_doctrine.md` §7](../documents/engineering/substrate_doctrine.md#7-the-loadbalancer-is-the-one-substrate-driven-platform-difference)) |
| Gate phase(s) | 10 (the `linux-cpu` parent drives the deploy; the provider target is not a hardware substrate) |
| Status | 📋 Planned |

---

## 3. Virtualized substrates: Lima / WSL2

When the host is not natively Linux, amoebius synthesizes a Linux host in a VM and then treats it as an
ordinary Linux substrate — same charts, same services, same DSL — per
[`substrate_doctrine.md` §4 — virtualized substrates: synthesizing a Linux host where the host is not Linux](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux).
The VM is plumbing; the substrate the cluster sees is Linux. These are **providers**, not catalog members — a
Lima VM on Apple presents as `linux-cpu` to everything above it.

### lima

| Field | Value |
|-------|-------|
| Runs on | `apple` host substrate |
| Provider / tool | Lima (`limactl`), ensured via `brew install lima` (verified no-op if present) |
| Synthesizes | A named, project-budget-sized Ubuntu-24.04 Linux VM presenting as `linux-cpu` |
| Seed module | `HostBootstrap.Ensure.Lima` / `HostBootstrap.Lima` (sibling `hostbootstrap`) |
| Used by | Phase 8 (`apple`) — the binary re-invokes its own subcommands via `limactl shell <vm> -- <amoebius> <subcmd>` |
| Status | 📋 Planned |

### wsl2

| Field | Value |
|-------|-------|
| Runs on | `windows` host substrate |
| Provider / tool | WSL2 (`wsl`; install via `winget install --id Microsoft.WSL`) |
| Synthesizes | An Ubuntu-24.04 Linux distro presenting as `linux-cpu` |
| Seed module | `HostBootstrap.Ensure.Wsl2` / `HostBootstrap.Wsl2` (sibling `hostbootstrap`) |
| Used by | The Windows Linux-host role; firmware-virtualization-off and a required reboot are first-class fail-fast outcomes, never silent hangs |
| Status | 📋 Planned |

> **VM budget.** Each virtualized substrate carves a **`Capacity`** from its host (`carve`,
> [`resource_capacity_doctrine.md` §4](../documents/engineering/resource_capacity_doctrine.md)); the guest
> Linux cluster folds against that sub-capacity, so "a VM asking for more than its host" is decode-rejected
> ([`illegal_state_catalog.md` §3.17](../documents/engineering/illegal_state_catalog.md)). A Lima/WSL2 VM is
> also the **only `LinuxHost` witness** its non-Linux host can produce — which is why an rke2/kind cluster on
> apple/windows must interpose one (I1, §3.14).

> **No Tart / no macOS build VM.** The Apple-Metal host worker's Swift/Metal parts are **not** built in a VM.
> They build headless, directly on the macOS host via a fixed `/usr/bin/clang`-built Metal bridge with runtime
> MSL compilation — a shape proven in the sibling jitML project and adopted after sibling `infernix` removed
> its legacy Tart path. There is no Tart provider, and none is planned
> ([`apple_metal_headless_builds.md`](../documents/engineering/apple_metal_headless_builds.md)).

---

## 4. Per-phase substrate map (phases 0–12)

The single substrate each phase's acceptance gate keys to. Each row matches the substrate named in that
phase's `Phase Summary`; the README Phase index carries the same values
([README.md Phase discipline](README.md#phase-discipline)). Each row's full objective, gate, and sprint
breakdown lives in its phase document (`phase_00_documentation_suite.md` … `phase_12_spa_composition.md`).

| Phase | Name | Substrate | Why this substrate |
|-------|------|-----------|--------------------|
| 0 | Documentation suite (whole DSL) | `none` | The gate is the documentation lint — header metadata, SSoT/no-duplication, no orphan cross-links. No host, no cluster, no hardware axis is exercised. |
| 1 | Formal-first DSL & protocol integrity | `none` | In-process formal validation — stands up no host or cluster: the Dhall typecheck + Haskell auto-decoder + QuickCheck type-discipline gates, the SPA-composition representational check, and the TLA+/TLC cross-cluster-failover & singleton-election design invariants all run before any real resource. No host, cluster, or hardware axis is exercised. |
| 2 | Bootstrap + kernel + single kind cluster | `linux-cpu` | The default substrate brings up an empty single-node kind cluster idempotently. Substrate *detection* runs here, but the gate (`bootstrap` is a no-op on re-run) is a plain Linux control plane — no GPU, no host worker. |
| 3 | Platform services + retained storage + root Vault/PKI | `linux-cpu` | The full standard service set + MetalLB + `no-provisioner` retained PVs that rebind across delete/recreate, validated on the default substrate. The LB is MetalLB — the bare-metal/kind choice ([`substrate_doctrine.md` §7](../documents/engineering/substrate_doctrine.md#7-the-loadbalancer-is-the-one-substrate-driven-platform-difference)). No GPU axis. |
| 4 | Orchestration Dhall DSL + control-plane singleton | `linux-cpu` | Type-checking, the typed reconciler, and singleton election are pure-DSL + control-plane work with no hardware axis; the default substrate carries the deploy-a-trivial-app / reject-an-illegal-`.dhall` gate. |
| 5 | Native Pulsar client + content-addressed store + workflow-runtime | `linux-cpu` | A native-Pulsar round-trip, a 3-tier content-addressed store, and worker-daemon failover are fully containerized; no GPU. The default substrate is sufficient. |
| 6 | Determinism kernel + infernix migration | `linux-cpu` | Reproducibility of a **CPU** infernix-inference workflow (same `experimentHash` ⇒ same output). Determinism is proven without a GPU; CUDA is confined to a later phase. |
| 7 | jitML migration + HA coordinator | `linux-cuda` | The first GPU workload — a jitML training run that must be bit-deterministic, plus coordinator failover. This is the **in-cluster** CUDA path via the NVIDIA container runtime (the contained-GPU case, [`substrate_doctrine.md` §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained)), so `linux-cuda`, not a host worker. |
| 8 | Host compute daemons (Apple Metal / Windows CUDA) | `apple` | The host-worker case where hardware refuses containerization: Apple Metal needs unified memory and cannot run in a Linux VM/container ([`substrate_doctrine.md` §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained)). The gate runs an Apple-Silicon host daemon as a Pulsar/MinIO peer; one-substrate discipline pins the gate to `apple` (the Windows-CUDA case shares the doctrine but is not the gate substrate). |
| 9 | Multi-cluster: amoebic spawning + geo-replication + failover | `linux-cpu` | Parent and child kind/rke2 clusters, geo-replication, DNS failover, and the async cross-cluster failover proof are all Linux clusters. No GPU/host-hardware axis enters the gate; everything stays on the default substrate. |
| 10 | Provider-managed clusters + dynamic provisioning | `linux-cpu → provider` | The amoebius cluster that drives Pulumi is `linux-cpu`, but the **gate** spins up a provider-managed cluster (AWS/EKS — prodbox's reality) and dynamically provisions a node. The substrate shifts from the local Linux control plane to the provider's managed substrate, where the LB becomes a cloud LoadBalancer ([`substrate_doctrine.md` §7](../documents/engineering/substrate_doctrine.md#7-the-loadbalancer-is-the-one-substrate-driven-platform-difference)). |
| 11 | Test-topology DSL + suggest-test + storage-lifecycle safety | `per generated test` | `suggest-test` detects the actual substrate + resources + credentials present and emits a representative test `.dhall`. The substrate is therefore **whatever the generated test targets** — not fixed at plan time — and is still single-substrate per the discipline, just chosen at generation. |
| 12 | SPA composition | `linux-cpu` | Compose a multi-service SPA + an ML workflow over the shared services behind Keycloak/Envoy, deployed and reachable on the default substrate — no new hardware axis. |

The provider/host-side details under three of these rows are owned elsewhere: the cloud-LB and provider-cluster
provisioning behind Phase 10 by the Pulumi IaC doctrine; the host-worker wire behind Phase 8 by the
host↔cluster comms doctrine; the in-cluster vs on-host GPU split behind Phases 7/8 by
[`substrate_doctrine.md` §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained).
This map owns only the **one substrate per gate** assignment.

---

## 5. Generated sections

**None yet.** This file is the *sole home of generated tables* in the plan suite
([`development_plan_standards.md` §I](development_plan_standards.md#i-generated-section-markers)), but both
tables above are **hand-authored** today and the header declares `Generated sections: none` accordingly. A
future amoebius `dev docs generate` will own a generated **stack-surface table** (the per-substrate ×
per-service provider/LB/arch matrix — and, alongside it, the **compute-engine × substrate compatibility
matrix** that [`cluster_topology_doctrine.md` §5](../documents/engineering/cluster_topology_doctrine.md)
defines, plus a **per-provider quota** column for the `CloudQuota` backing) fenced between
`<!-- amoebius:stack_surface:start -->` /
`<!-- amoebius:stack_surface:end -->` markers; until that generator exists, marking a table generated is
premature, so the equivalent content is carried by hand and the header stays `none`
([`development_plan_standards.md` §I](development_plan_standards.md#i-generated-section-markers)).

Delivery sequencing, completion status, and validation gates for everything above are owned by
[README.md](README.md) and the per-phase documents, never by this registry — the same separation the doctrine
keeps in
[`substrate_doctrine.md` §9 — planning ownership](../documents/engineering/substrate_doctrine.md#9-planning-ownership).

---

## Related Documents

- [README.md](README.md) — the live tracker; the Phase index carries the same substrate column
- [development_plan_standards.md](development_plan_standards.md) — §L one-substrate discipline, §I generated-section markers
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) — the normative substrate catalog, detection, no-`PATH` contract, virtualization, and host-worker carve-out this registry projects
- [Cluster Topology Doctrine](../documents/engineering/cluster_topology_doctrine.md) — the declared compute-engine axis (kind/rke2/EKS) this registry keeps distinct from the detected substrate
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — the fold over the per-host `Capacity` this registry declares
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — §9 the LoadBalancer + single wild-ingress path, §12 substrate equivalence as a structural invariant
- [Host ↔ Cluster Comms Doctrine](../documents/engineering/host_cluster_comms_doctrine.md) — the host-worker wire (host-only NodePorts, no mTLS) behind Phase 8
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — the composition lift and worker-role taxonomy
- [Pulumi IaC Doctrine](../documents/engineering/pulumi_iac_doctrine.md) — provider-cluster provisioning behind Phase 10
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine the phases adopt
