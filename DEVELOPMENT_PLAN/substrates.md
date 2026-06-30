# Substrate Registry and Per-Phase Substrate Map

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, development_plan_standards.md, later_phases.md, legacy_tracking_for_deletion.md, overview.md, phase_00_documentation_suite.md, phase_01_bootstrap_kernel_kind.md, phase_02_platform_services_storage_vault.md, phase_03_dsl_control_plane_singleton.md, phase_04_pulsar_content_store_workflow.md, phase_05_determinism_infernix.md, phase_06_jitml_ha_coordinator.md, phase_07_host_compute_daemons.md, phase_08_mattandjames_app_logic.md, phase_09_multicluster_spawn_georeplication.md, phase_10_provider_clusters_provisioning.md, phase_11_test_topology_dsl.md, phase_12_spa_composition.md, system_components.md
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

### apple

| Field | Value |
|-------|-------|
| Host kind | macOS on Apple Silicon — the admin laptop / highest-level root cluster host |
| Native arch | `arm64` (always; Intel-Mac is rejected outright, [`substrate_doctrine.md` §1](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob)) |
| GPU axis | Apple Metal — on-host, **not containerizable** (needs unified memory) |
| Virtualization | Lima (Ubuntu-24.04 Linux VM); Tart (macOS VM for Swift/Xcode builds) — see §3 |
| LoadBalancer | MetalLB (bare-metal / kind / rke2 lane) |
| What it validates | The Phase 7 gate — an Apple-Silicon **host compute daemon** runs a Metal ML workload as an in-cluster Pulsar/MinIO peer over host-only NodePorts ([`substrate_doctrine.md` §5 — host worker nodes](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained)) |
| Gate phase(s) | 7 |
| Status | 📋 Planned |

### linux-cpu

| Field | Value |
|-------|-------|
| Host kind | Linux host — bare-metal / kind / rke2, single- or multi-node |
| Native arch | `amd64` or `arm64` (mixed-arch clusters and multi-arch images are expressible) |
| GPU axis | none |
| Virtualization | none (native Linux); Incus / Colima where a nested Linux VM is wanted |
| LoadBalancer | MetalLB |
| What it validates | The **default validation substrate** — the bulk of the plan: bootstrap, platform services + retained storage, the DSL + control-plane singleton, the Pulsar/store/workflow runtime, CPU-inference determinism, mattandjames, multi-cluster spawn/geo-replication/failover, and SPA composition |
| Gate phase(s) | 1, 2, 3, 4, 5, 8, 9, 12 (and the local control side of 10) |
| Status | 📋 Planned |

### linux-cuda

| Field | Value |
|-------|-------|
| Host kind | Linux host with an NVIDIA GPU present (detection promotes the substrate) |
| Native arch | `amd64` or `arm64` |
| GPU axis | NVIDIA present ⇒ **in-cluster** CUDA via the NVIDIA container runtime — the *contained-GPU* case ([`substrate_doctrine.md` §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained) contrast) |
| Virtualization | none |
| LoadBalancer | MetalLB |
| What it validates | The Phase 6 gate — a jitML training run is bit-deterministic per its determinism contract and the HA coordinator fails over; CUDA stays confined behind a default-off cabal flag |
| Gate phase(s) | 6 |
| Status | 📋 Planned |

### windows

| Field | Value |
|-------|-------|
| Host kind | Windows host |
| Native arch | `amd64` |
| GPU axis | CUDA present ⇒ **on-host worker node** — CUDA does not run performantly inside WSL2 ([`substrate_doctrine.md` §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained)) |
| Virtualization | WSL2 (Ubuntu-24.04 Linux distro) for the Linux-host role — see §3 |
| LoadBalancer | MetalLB (when acting as a Linux cluster host) |
| What it validates | No phase gate in 0–12 keys its single substrate to `windows`: Windows participates either as a Linux host (via WSL2) or as the Windows-CUDA host-worker case, which shares the Phase 7 host-compute doctrine whose gate substrate is `apple`. The standalone `windows` gate is a later-phase concern (README later phases) |
| Gate phase(s) | none in 0–12 (host-worker doctrine shared with Phase 7) |
| Status | 📋 Planned |

> **Honesty.** Detection and classification are seeded from the sibling `hostbootstrap` library (a closed
> `SubstrateName` enum with finer `apple-silicon` / `linux-cpu` / `linux-gpu` / `windows-cpu` / `windows-gpu`
> granularity that the four-name DSL catalog collapses). That seed is **evidence from a sibling**, not an
> amoebius-built behaviour; amoebius has not built Phase 1
> ([`substrate_doctrine.md` §1](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob)).

---

## 3. Virtualized substrates: Lima / WSL2 / Tart

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
| Used by | Phase 7 (`apple`) — the binary re-invokes its own subcommands via `limactl shell <vm> -- <amoebius> <subcmd>` |
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

### tart

| Field | Value |
|-------|-------|
| Runs on | `apple` host substrate |
| Provider / tool | Tart (macOS VM) |
| Synthesizes | A clean, reproducible macOS VM for Swift/Xcode builds of the Apple-Metal host-worker ML parts |
| Seed module | **Design intent — no seed code** (sibling `infernix` removed its legacy Tart; amoebius provisions fresh under the Apple phase) |
| Used by | Phase 7 (`apple`) — keeps Apple build provenance off the developer's hand-configured machine |
| Status | 📋 Planned (design intent, not seeded) |

---

## 4. Per-phase substrate map (phases 0–12)

The single substrate each phase's acceptance gate keys to. Each row matches the substrate named in that
phase's `Phase Summary`; the README Phase index carries the same values
([README.md Phase discipline](README.md#phase-discipline)). Each row's full objective, gate, and sprint
breakdown lives in its phase document (`phase_00_documentation_suite.md` … `phase_12_spa_composition.md`).

| Phase | Name | Substrate | Why this substrate |
|-------|------|-----------|--------------------|
| 0 | Documentation suite (whole DSL) | `none` | The gate is the documentation lint — header metadata, SSoT/no-duplication, no orphan cross-links. No host, no cluster, no hardware axis is exercised. |
| 1 | Bootstrap + kernel + single kind cluster | `linux-cpu` | The default substrate brings up an empty single-node kind cluster idempotently. Substrate *detection* runs here, but the gate (`bootstrap` is a no-op on re-run) is a plain Linux control plane — no GPU, no host worker. |
| 2 | Platform services + retained storage + root Vault/PKI | `linux-cpu` | The full standard service set + MetalLB + `no-provisioner` retained PVs that rebind across delete/recreate, validated on the default substrate. The LB is MetalLB — the bare-metal/kind choice ([`substrate_doctrine.md` §7](../documents/engineering/substrate_doctrine.md#7-the-loadbalancer-is-the-one-substrate-driven-platform-difference)). No GPU axis. |
| 3 | Orchestration Dhall DSL + control-plane singleton | `linux-cpu` | Type-checking, the typed reconciler, and singleton election are pure-DSL + control-plane work with no hardware axis; the default substrate carries the deploy-a-trivial-app / reject-an-illegal-`.dhall` gate. |
| 4 | Native Pulsar client + content-addressed store + workflow-runtime | `linux-cpu` | A native-Pulsar round-trip, a 3-tier content-addressed store, and worker-daemon failover are fully containerized; no GPU. The default substrate is sufficient. |
| 5 | Determinism kernel + infernix migration | `linux-cpu` | Reproducibility of a **CPU** infernix-inference workflow (same `experimentHash` ⇒ same output). Determinism is proven without a GPU; CUDA is confined to a later phase. |
| 6 | jitML migration + HA coordinator | `linux-cuda` | The first GPU workload — a jitML training run that must be bit-deterministic, plus coordinator failover. This is the **in-cluster** CUDA path via the NVIDIA container runtime (the contained-GPU case, [`substrate_doctrine.md` §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained)), so `linux-cuda`, not a host worker. |
| 7 | Host compute daemons (Apple Metal / Windows CUDA) | `apple` | The host-worker case where hardware refuses containerization: Apple Metal needs unified memory and cannot run in a Linux VM/container ([`substrate_doctrine.md` §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained)). The gate runs an Apple-Silicon host daemon as a Pulsar/MinIO peer; one-substrate discipline pins the gate to `apple` (the Windows-CUDA case shares the doctrine but is not the gate substrate). |
| 8 | mattandjames as application-logic-only | `linux-cpu` | Deploy mattandjames from one app `.dhall` at a configurable replica count with inference via an infernix CPU workflow — the default substrate, no new hardware axis. |
| 9 | Multi-cluster: amoebic spawning + geo-replication + failover | `linux-cpu` | Parent and child kind/rke2 clusters, geo-replication, DNS failover, and the async cross-cluster failover proof are all Linux clusters. No GPU/host-hardware axis enters the gate; everything stays on the default substrate. |
| 10 | Provider-managed clusters + dynamic provisioning | `linux-cpu → provider` | The amoebius cluster that drives Pulumi is `linux-cpu`, but the **gate** spins up a provider-managed cluster (AWS/EKS — prodbox's reality) and dynamically provisions a node. The substrate shifts from the local Linux control plane to the provider's managed substrate, where the LB becomes a cloud LoadBalancer ([`substrate_doctrine.md` §7](../documents/engineering/substrate_doctrine.md#7-the-loadbalancer-is-the-one-substrate-driven-platform-difference)). |
| 11 | Test-topology DSL + suggest-test + storage-lifecycle safety | `per generated test` | `suggest-test` detects the actual substrate + resources + credentials present and emits a representative test `.dhall`. The substrate is therefore **whatever the generated test targets** — not fixed at plan time — and is still single-substrate per the discipline, just chosen at generation. |
| 12 | SPA composition | `linux-cpu` | Compose a multi-service SPA + an ML workflow over the shared services behind Keycloak/Envoy, deployed and reachable on the default substrate — no new hardware axis. |

The provider/host-side details under three of these rows are owned elsewhere: the cloud-LB and provider-cluster
provisioning behind Phase 10 by the Pulumi IaC doctrine; the host-worker wire behind Phase 7 by the
host↔cluster comms doctrine; the in-cluster vs on-host GPU split behind Phases 6/7 by
[`substrate_doctrine.md` §5](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained).
This map owns only the **one substrate per gate** assignment.

---

## 5. Generated sections

**None yet.** This file is the *sole home of generated tables* in the plan suite
([`development_plan_standards.md` §I](development_plan_standards.md#i-generated-section-markers)), but both
tables above are **hand-authored** today and the header declares `Generated sections: none` accordingly. A
future amoebius `dev docs generate` will own a generated **stack-surface table** (the per-substrate ×
per-service provider/LB/arch matrix) fenced between `<!-- amoebius:stack_surface:start -->` /
`<!-- amoebius:stack_surface:end -->` markers; until that generator exists, marking a table generated is
premature, so the equivalent content is carried by hand and the header stays `none`
([`development_plan_standards.md` §I](development_plan_standards.md#i-generated-section-markers)).

Delivery sequencing, completion status, and validation gates for everything above are owned by
[README.md](README.md) and the per-phase documents, never by this registry — the same separation the doctrine
keeps in
[`substrate_doctrine.md` §8 — planning ownership](../documents/engineering/substrate_doctrine.md#8-planning-ownership).

---

## Related Documents

- [README.md](README.md) — the live tracker; the Phase index carries the same substrate column
- [development_plan_standards.md](development_plan_standards.md) — §L one-substrate discipline, §I generated-section markers
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) — the normative substrate catalog, detection, no-`PATH` contract, virtualization, and host-worker carve-out this registry projects
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — §9 the LoadBalancer + single wild-ingress path, §12 substrate equivalence as a structural invariant
- [Host ↔ Cluster Comms Doctrine](../documents/engineering/host_cluster_comms_doctrine.md) — the host-worker wire (host-only NodePorts, no mTLS) behind Phase 7
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — the composition lift and worker-role taxonomy
- [Pulumi IaC Doctrine](../documents/engineering/pulumi_iac_doctrine.md) — provider-cluster provisioning behind Phase 10
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine the phases adopt
