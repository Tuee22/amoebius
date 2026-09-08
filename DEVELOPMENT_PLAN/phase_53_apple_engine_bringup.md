# Phase 53: Apple: Homebrew, Colima, and the native image

> **Purpose**: Bring an Apple Silicon host to a container engine, a budget-sized Linux frame, and a native
> `arm64` image — and prove the steps that run inside were lifted rather than written a second time.
> **Read this if**: an apple host has to reach an image build or a kind cluster, or the frame a workload selects has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision](#resource-provision)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 53.1: The Homebrew floor is verified, never installed](#sprint-531-the-homebrew-floor-is-verified-never-installed-)
- [Sprint 53.2: Colima ensured, and a frame sized from the carve](#sprint-532-colima-ensured-and-a-frame-sized-from-the-carve-)
- [Sprint 53.3: The provider follows the workload](#sprint-533-the-provider-follows-the-workload-)
- [Sprint 53.4: The ephemeral one-off and the frame that persists](#sprint-534-the-ephemeral-one-off-and-the-frame-that-persists-)
- [Sprint 53.5: The lifted step list and the native image](#sprint-535-the-lifted-step-list-and-the-native-image-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

🔄 Active — NOT VALIDATED.

Phase 52 and every earlier gate have passed in numerical order. The source-bound Haskell subject, independent
oracle, paired negatives, six changed-production-subject mutants, acquired runner, and typed gate/resource
contracts are implemented and qualified. The exact Phase-53 gate currently refuses at the required live
boundary because this development host is Linux `x86_64`; a physical Apple Silicon macOS host must execute
the owned Colima profile before any status projection may mark this phase Done.

---

> **Gate interpretation.** The phase-specific contract is bound but remains NOT VALIDATED until the complete
> acquired gate passes for one stable source snapshot on physical Apple Silicon. Component checks and a
> non-Apple refusal cannot substitute for the live result.

## Phase Summary

An apple host supplies no Linux kernel and no container engine, so every workload amoebius actually wants
runs one boundary away from the host it started on. The target gate must close that distance: it must verify
the one prerequisite Homebrew is, ensure Colima through it, provision a frame whose size came from the carve
arithmetic rather than from a default, and run the linux step list inside it. The frame is plumbing; what
the cluster sees is a CPU-only Linux host at `arm64`.

What makes this phase cheap is that the step list is Phase 51's, lifted into the Colima frame rather than
re-authored for it. That is the load-bearing property, not an efficiency: a second deployment path is how one
answer becomes two that drift, and if this phase needed deployment logic of its own then the ensure kernel
would have failed at the purpose it exists for. The phase is therefore sized by the frame — the floor, the
provider, the carve, the lifecycle, and the lift — and by nothing that runs inside it.

**Phase scope:** one cohesive claim — *an apple host reaches a container engine, a budget-sized frame, and a
native `arm64` image, using the linux step list unchanged*. Its sprint seams are the floor, the frame, the
selection, the lifecycle, and the lift. It splits if a second substrate or a second acceptance register
appears.

**Substrate:** `apple` — the claim is about macOS on Apple Silicon, and no other host can carry it ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** `linux-cpu/arm64` — the frame's natural architecture, never emulated ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 3 — live: a frame is created, used, and destroyed on physical hardware ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 52](phase_52_linux_engine_bringup.md)
**Gate:** `pb validate phase 53`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED; live Apple execution remains open.

| Key | Contract |
|---|---|
| `Claim` | A physical Apple Silicon host verifies its operator-owned floor, ensures Colima, admits a checked frame carve, executes the unchanged lifted Linux step list, and builds and runs a native arm64 image without emulation. |
| `Subject` | `Amoebius.Host.AppleEngine`, the shared `Amoebius.Substrate.Brew` ensure algebra, and the acquired `Amoebius.Validation.AppleEngineBringupRun` supervisor. |
| `Command` | `pb validate phase 53`; the validated bootstrap hands off unchanged to Haskell, which serially qualifies the changed production subjects before executing one owned live Colima profile. |
| `Oracle` | `test/spec/host/AppleEngineBringupOracle.hs`, importing no `Amoebius.*` module and separately authoring provider, lifecycle, carve argv, lifted-step, floor, and architecture observations. |
| `Positive controls` | The complete three-member floor, four workloads, four lifecycle rows, observed-and-admitted 4-core/8-GiB/40-GiB carve, all five executable rows of Phase 51's unchanged Linux plan and their concrete Colima envelopes, all five rows executed and argument-observed through run-owned boundary shims in the disposable live profile, a non-mutating real-guest `df` challenge, ready owned-context Docker endpoint, initially absent and then native arm64 image, and owned teardown form the closed corpus. |
| `Paired negatives` | Each missing floor member, non-Apple substrate, CPU/memory/disk one-short supply, architecture disagreement, emulation, bare executable, and leaked ephemeral lifecycle are distinguished at exact constructors or argv rows. |
| `Mutants` | Six Cabal-selected changed production subjects install an operator floor, choose Lima for an image build, persist an ephemeral frame, substitute default sizing, re-author the lifted step, or admit emulation; each must emit its assigned red token while the clean subject remains green. |
| `Discovery` | The acquired tracked-source inventory equals the Apple-engine product, independent oracle, spec, runner pair, dispatch/evidence/runner wiring, and Cabal declarations; live discovery equals the floor, provider profile, endpoint, architecture, image, invocation, and teardown observations in both directions. |
| `Challenge` | After Colima reports started, the runner decodes the provider's independent inventory and requires the exact running owner profile, architecture, CPU, memory, disk, and runtime carve; it then challenges the owned-context Docker endpoint, proves the run-owned image is initially absent, builds and executes it without cache, re-reads provider/image architecture, and refuses any cached or pre-start answer. |
| `Observer` | The outer Haskell supervisor records absolute argv and exits for `uname`, `xcode-select`, `sysctl`, `df`, Homebrew, Colima, and Docker; Colima inventory, Docker-context inventory, and the active Docker context before/after; host/frame/engine/image architecture; guest `binfmt_misc` registrations; container stdout; and cleanup inventory. |
| `Authority/bypass` | A unique Phase-53 profile and image reference bound the mutable scope. Colima/Lima/Docker root and selector environment overrides are cleared. Colima is started with host mounts, ambient templates, active-context mutation, SSH-agent/config integration, Kubernetes, and binfmt emulation disabled. Only that profile and image may be created; no foreign profile, cluster, registry, published tag, provider-cloud resource, or emulation path is admitted. |
| `Freshness` | The run root, profile, and image name are newly absent; source and Phase-52 receipt precede mutation; floor and capacity preflight precede provider ensure/start; observations are regenerated; opening and closing source identities match. |
| `Qualification` | The fixed clean row and six-mutant corpus qualify the Haskell harness with pinned absolute compiler/store, `--jobs=1`, and offline resolution before the live verdict is admitted. |
| `Cleanroom` | Generated recipes, logs, and compiler products remain below `.build/runs/phase-53/**`; the exact owned image, Colima profile, and separate runtime data are destroyed in an unconditional bracket and Colima/Docker-context inventories return to their pre-run values. |
| `Legacy closure` | Phase 53 owns no legacy ID; the acquired legacy reverse map must remain empty for this ordinal. |
| `Predecessor` | Exact `ImmediatePredecessorPass` for Phase 52; an absent, stale, replayed, later-phase, or different-source receipt refuses before any Apple mutation. |
| `Residue` | `UNVERIFIED`: Windows engine bring-up, kind and later clusters, registry, canonical published base images, services, accelerators, and later live acceptance remain Phase-54+-owned. |
| `Pass criterion` | `qualified-gate-pass` — all eighteen rows pass for one exact stable source on physical Apple Silicon, all six production mutants are red at assigned loci, live external observations agree, no emulation is observed, and owned live residue is zero. |

## Resource provision

- **Owner marker:** exact source snapshot, Phase-52 receipt, unique Phase-53 run root, unique `amoebius-phase53-<pid>` Colima profile, two boundary-observer shims inside that disposable profile, and matching run-owned image reference.
- **Preflight:** physical macOS `arm64`; `/opt/homebrew/bin/brew` and `xcode-select -p` verified without repair; sufficient observed CPU, memory, and home-volume disk for the exact carve; absent owner profile and image; no emulation or redirected-root selector.
- **Allowed mutation:** create run-local `.build/**` evidence; install Colima and the Docker client through the verified Homebrew root only when absent; create/start only the marked profile at the admitted carve; create two exact echo-backed boundary-observer shims only inside that fresh disposable profile; build/run/remove only the run-owned native image.
- **Forbidden mutation:** no Homebrew installation or Xcode repair, redirected Colima/Lima/Docker state root, foreign Colima profile/image/context, host-directory mount, active Docker-context switch, ambient Colima template, operator SSH config/agent integration, kind/Kubernetes cluster, registry, published tag, cloud resource, cross-build/binfmt emulation, ambient toolchain, concurrent compiler, or repository path outside `.build/**` may be changed.
- **Observer:** the outer Haskell supervisor reads platform/floor/capacity, Colima inventory, Docker-context inventory, and the active Docker context before/after, exact process argv/exits, Docker endpoint readiness, host/frame/engine/image architecture, guest `binfmt_misc` registrations, container stdout, and final owned-resource inventory.
- **Cleanup:** the exact validated image reference is removed and the exact validated profile plus its separate runtime data are deleted in an unconditional bracket on success or failure; no wildcard or caller-supplied deletion target is accepted.
- **Residue:** the owner profile, its boundary-observer shims, context, runtime data, and image must be absent and foreign Colima/Docker-context inventories must byte-equal their pre-run values; only run-owned `.build/**` evidence and allowed durable Colima/Docker-client package ensures may remain.

## Doctrine adopted

- [`extension_conformance_doctrine.md` §5 — The conformance gate is generated, not authored](../documents/engineering/extension_conformance_doctrine.md#5-the-conformance-gate-is-generated-not-authored) — apple: Homebrew, Colima, and the native image is admitted by satisfying the contract, not by appearing on a list.
- [`substrate_doctrine.md` §4.1 — Colima and Lima on Apple: the provider follows the workload](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload):
  the selection is a function of the workload and the substrate together, the two providers are one family
  with one extra capability, and the logic that runs inside is the same logic in both.
- [`substrate_doctrine.md` §3.1 — The per-substrate floor: what only the operator can supply](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply):
  Homebrew is the apple package-manager root, which is verified rather than ensured, and a failed floor check
  is a value naming its own remedy.
- [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract):
  Colima is probed, installed when absent, resolved to an absolute path from the package manager, and invoked
  by that path.
- [`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting):
  the frame's CPU, memory, and disk are a demand the host's supply must admit, so an oversized frame is a
  rejection at authoring rather than a failure at creation.

---

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 53.1: The Homebrew floor is verified, never installed 🔄

**Status**: Active — NOT VALIDATED
**Implementation**: `Amoebius.Host.AppleEngine.admitAppleFloor` and the acquired live supervisor verify physical Apple Silicon, Homebrew, and Xcode before any mutation.
**Blocked by**: [Phase 52](phase_52_linux_engine_bringup.md) gate pass
**Independent Validation**: one green floor and three exact missing-prerequisite pairs, plus the installs-floor production mutant.
**Oracle**: `test/spec/host/AppleEngineBringupOracle.hs`, importing no production module.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/substrate_doctrine.md`.

### Objective

Adopt [`substrate_doctrine.md` §3.1 — the per-substrate floor](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply);
decide the apple floor before any tool is resolved, and refuse rather than repair what only the operator can
supply.

### Deliverables

- A Homebrew probe that answers from the package manager itself and resolves its prefix once, because every
  later absolute path on this substrate descends from that one resolution.
- A refusal value carrying the prerequisite id and the exact instruction that clears it, so the operator is
  told what to do rather than shown a resolution failure several requirements deep.
- A verification of the command-line tools through `xcode-select -p`, which is a floor fact because a source
  build needs the headers and amoebius cannot supply them.
- The apple floor rows declared as data beside the toolchain requirements the same resolver reads, so the
  floor is authored input rather than a branch in a program.

### Validation

1. The Homebrew check has exactly two outcomes — a verified no-op and a refusal — and no install path.
2. A refusal names its prerequisite id, and the id is one the requirements data declares.

### Remaining Work

Run the complete acquired Phase-53 gate on physical Apple Silicon; only its exact pass can authorize the mechanical status projection.

## Sprint 53.2: Colima ensured, and a frame sized from the carve ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `Amoebius.Host.AppleEngine.admitFrameDemand` and absolute Colima argv bind the exact carve before provider start.
**Blocked by**: Sprint 53.1
**Independent Validation**: exact admitted carve, CPU/memory/disk one-short refusals, absolute argv, and the default-frame mutant.
**Oracle**: `AppleEngineBringupOracle.expectedColimaStart`.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md`.

### Objective

Adopt [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract);
ensure Colima through the verified root and provision a frame whose size is a checked value.

### Deliverables

- Colima and Docker-client ensures that probe, install through Homebrew when absent, resolve their absolute
  paths beneath the verified package-manager prefix, and invoke only those paths — a bare command handed to
  the OS is a search, not a resolution.
- A frame whose CPU, memory, and disk come from the carve arithmetic, because a default size is a number
  nothing checked against the host it runs on.
- A refusal on a failed fit, issued before the provider is called, so an overcommit costs a rejection rather
  than a half-created VM.
- A readiness probe on the Docker endpoint the frame publishes, since the frame is not ready when the
  provider returns but when the endpoint answers.

### Validation

1. No invocation on this substrate names a bare command, and the resolved prefix is the one the floor read.
2. A frame request exceeding the admitted supply is rejected, and the provider records no creation.

### Remaining Work

Run the complete acquired Phase-53 gate on physical Apple Silicon; only its exact pass can authorize the mechanical status projection.

## Sprint 53.3: The provider follows the workload ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `AppleWorkload`, `AppleProvider`, and `providerFor` form the closed workload-sensitive provider table; `providerBrewTool` binds both providers to the one corrected `BrewEnsurePlan` interpreter used by the live runner.
**Blocked by**: Sprint 53.2
**Independent Validation**: all four workload rows, exact Colima/Lima/Docker-client ensure plans, non-absolute path refusals, the non-Apple refusal, and the image-build wrong-provider mutant.
**Oracle**: `AppleEngineBringupOracle.expectedProviders`.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/substrates.md`.

### Objective

Adopt [`substrate_doctrine.md` §4.1 — Colima and Lima on Apple: the provider follows the workload](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload);
make the frame a consequence of what the run needs, and make the substrate-only alternative unrepresentable.

### Deliverables

- A selection function whose domain is the workload and the substrate together; a selector keyed on the
  substrate alone cannot express the doctrine's rows, so the type does not admit one.
- Colima for a workload that needs a container endpoint — an image build, a one-off `docker run --rm`, or a
  persistent container runtime. Kind cluster creation remains Phase 55-owned.
- Lima for a workload that needs the distribution rather than an endpoint, because software installing into a
  full Linux system cannot be satisfied by a container runtime.
- One ensure path shared by both providers, since Colima is Lima carrying a container runtime and the
  difference between them is that runtime alone.

### Validation

1. Every workload the Haskell oracle names resolves to exactly one provider, and no workload resolves to two.
2. Changing the substrate without changing the workload cannot change the row the selector returns.

### Remaining Work

Run the complete acquired Phase-53 gate on physical Apple Silicon; only its exact pass can authorize the mechanical status projection.

## Sprint 53.4: The ephemeral one-off and the frame that persists ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `lifecycleFor`, the typed `StopFrame` action, and the runner's unconditional cleanup bracket bind lifetime to workload and exact ownership.
**Blocked by**: Sprint 53.3
**Independent Validation**: all four lifecycle rows, an ephemeral terminal teardown, the leak mutant, and provider before/after equality.
**Oracle**: `AppleEngineBringupOracle.expectedLifecycles` plus the outer provider observer.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/substrate_doctrine.md`.

### Objective

Adopt [`substrate_doctrine.md` §4.1 — Colima and Lima on Apple: the provider follows the workload](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload);
tie each frame's lifetime to the thing it backs, so nothing outlives its reason to exist.

### Deliverables

- A one-off invocation that acquires a frame for the length of that invocation and destroys it — ephemeral by
  construction rather than by a cleanup step a failure can skip.
- A bracket that destroys the frame on the failure path as well as the success path, because a leaked VM is a
  debit no later run knows to account for.
- A frame that persists for the life of a persistent container-runtime workload; the cluster lifecycle that
  will later consume that runtime remains Phase 55-owned.
- An inventory read that answers from the provider rather than from amoebius's record of what it created, so
  a frame created outside this run is still observed.

### Validation

1. A failed one-off leaves the provider inventory exactly as it found it.
2. A persistent-runtime workload does not receive the ephemeral teardown action; cluster ownership remains
   unverified until Phase 55.

### Remaining Work

Run the complete acquired Phase-53 gate on physical Apple Silicon; only its exact pass can authorize the mechanical status projection.

## Sprint 53.5: The lifted step list and the native image ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `liftLinuxSteps`, `admitNativeArm64`, and the live runner's run-owned image build/invocation bind unchanged lift and native architecture.
**Blocked by**: Sprint 53.4
**Independent Validation**: exact argv for every executable Phase-51 Linux-plan row and every concrete Colima envelope, exact argument echoes from all five rows through live disposable-profile boundary shims, a non-mutating real-guest transport challenge, native/mismatched/emulated pairs, two production mutants, and live frame/engine/image/container architecture reads.
**Oracle**: `AppleEngineBringupOracle.expectedLiftedPlan`, `expectedColimaLiftedPlan`, and `expectedLiftedStep`, plus the outer Docker/Colima observer.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `documents/engineering/image_build_doctrine.md`.

### Objective

Adopt [`substrate_doctrine.md` §4.1 — Colima and Lima on Apple: the provider follows the workload](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload);
run Phase 51's step list inside the Colima frame and build the native image with it.

### Deliverables

- A lift that parameterizes the existing step list by the frame it runs in, so the Colima path carries no
  step the linux path lacks.
- A frame delta compared with a separately authored Haskell expectation covering every executable Phase-51
  Linux-plan row; its diff is emitted lazily beneath `.build/**`, because divergence that is not diffable is
  divergence discovered late. The live provider challenge executes all five unchanged rows through exact
  run-owned echo shims inside the disposable profile and compares their external argument observations, then
  executes a non-mutating Phase-51-typed `df` row against the real guest through the same concrete Colima
  envelope. This proves the complete transport and deliberately does not claim package-install effects.
- A native image built at `arm64`, the host's natural architecture — virtualization synthesizes an operating
  system, not an instruction set, so no cross-build and no emulation is available or wanted.
- A run-owned container invocation from that image through the frame's endpoint. Kind creation and its
  endpoint-consumption proof remain Phase 55-owned.

### Validation

1. The emitted step list differs from the linux one only at rows the Haskell frame-delta expectation admits.
2. The built image reports `arm64`, and the run records no emulation layer.

### Remaining Work

Run the complete acquired Phase-53 gate on physical Apple Silicon; only its exact pass can authorize the mechanical status projection.

---

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/substrate_doctrine.md` — §4 records Colima as an implemented provider, and §4.4's
  honesty note drops the live Apple/Lima/brew clause for exactly what this gate observed and no more.
- `documents/engineering/resource_capacity_doctrine.md` — §4 records the engine frame as a debited demand
  once the live fit has actually run.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/substrates.md` — record Colima beside Lima in the apple row, with the workload that
  selects each.

---

## Related Documents

- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md)
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Phase 51](phase_51_host_ensure_kernel.md)
- [Phase 89](phase_89_apple_metal_host_daemon.md)
- [Development Plan](README.md)
