# Phase 7: Apple: Homebrew, Colima, and the native image

> **Purpose**: Bring an Apple Silicon host to a container engine, a budget-sized Linux frame, and a native
> `arm64` image — and prove the steps that run inside were lifted rather than written a second time.
> **Read this if**: an apple host has to reach an image build or a kind cluster, or the frame a workload selects has to change.

This phase owns the apple half of engine bringup: what the floor verifies before anything is resolved, which
frame a workload selects, how large that frame may be, and what survives it. It does not own the ensure
algebra its steps are written in — that is [Phase 4](phase_04_host_ensure_kernel.md)'s — and it does not own
the Apple-Metal host worker, which is built headless on the host and never enters a VM at all
([`substrate_doctrine.md` §4.4](../documents/engineering/substrate_doctrine.md#44-no-macos-build-vm-apple-builds-are-headless-on-host),
[Phase 74](phase_74_apple_metal_host_daemon.md)). Its prerequisite is Phase 6, which proved this same claim on
the linux substrate.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/phase_08_windows_engine_bringup.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 7.1: The Homebrew floor is verified, never installed 📋](#sprint-71-the-homebrew-floor-is-verified-never-installed-)
- [Sprint 7.2: Colima ensured, and a frame sized from the carve 📋](#sprint-72-colima-ensured-and-a-frame-sized-from-the-carve-)
- [Sprint 7.3: The provider follows the workload 📋](#sprint-73-the-provider-follows-the-workload-)
- [Sprint 7.4: The ephemeral one-off and the frame that persists 📋](#sprint-74-the-ephemeral-one-off-and-the-frame-that-persists-)
- [Sprint 7.5: The lifted step list and the native image 📋](#sprint-75-the-lifted-step-list-and-the-native-image-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

📋 Planned. No sprint has run; this phase has no implementation footprint and claims none.

---

## Phase Summary

An apple host supplies no Linux kernel and no container engine, so every workload amoebius actually wants
runs one boundary away from the host it started on. This phase closes that distance: it verifies the one
prerequisite Homebrew is, ensures Colima through it, provisions a frame whose size came from the carve
arithmetic rather than from a default, and runs the linux step list inside it. The frame is plumbing; what
the cluster sees is a CPU-only Linux host at `arm64`.

What makes this phase cheap is that the step list is Phase 4's, lifted into the Colima frame rather than
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

**Depends on**: [Phase 6](phase_06_linux_engine_bringup.md)

**Requires**: `host-floor`

**Gate:** `python3 tools/apple_engine_bringup_gate.py --execute` runs on an Apple Silicon host and passes
every check named in [Gate integrity](#gate-integrity). Phase 8 does not open until it is green.

---

## Gate integrity

The gate is `python3 tools/apple_engine_bringup_gate.py --execute`, it runs on physical Apple Silicon, and it
is re-runnable: every frame it creates it also destroys, so a second run starts from the state the first one
found. It decides four things.

**The floor is decided before the frame, and both outcomes are recorded.** The transcripts in
`test/fixture/apple_engine_bringup/floor/` drive the check with `brew` present and with `brew` absent. The
first must be a verified no-op, the second must be a refusal carrying the install instruction, and neither
may issue an install argv for Homebrew itself — a package-manager root cannot be acquired through a tool the
package manager resolves.

**Provider selection is joined against an independently authored oracle.**
`test/oracle/apple_frame_selection.tsv` enumerates each workload, the provider it selects, and whether its
frame outlives the invocation. The gate joins the selector's own enumeration against that table in both
directions, so a workload the oracle does not name and an oracle row the selector cannot answer are both
failures.

**The lift is compared, not asserted.** The gate emits the step list the Colima frame executes and diffs it
against the list the linux frame executes, byte for byte, into
`test/golden/apple_engine_bringup/frame_delta.txt`. An empty delta is the property; a non-empty one passes
only for a line the golden already registers as frame friction, because unregistered divergence is exactly
the second deployment path this phase exists to foreclose.

**Five committed mutants** — `test/mutant/registry.tsv` carries them — must each fail this gate, and each
must fail it at a different place:

- a floor check that installs Homebrew when it is absent instead of refusing — reddens the absent-host
  transcript, which then records an install argv the apple floor never issues;
- a selector keyed on the substrate alone, answering Colima for a workload that needs a full distribution —
  reddens the oracle join in the selector-cannot-answer direction;
- a one-off invocation whose frame outlives it — reddens the post-invocation inventory, which the provider
  itself must report empty;
- a frame requested past the admitted carve — reddens the capacity admission, because a VM is a debit against
  the host's supply and never a source of new capacity;
- a step re-authored for the Colima frame — reddens the frame delta, which is the only place a Colima-only
  step is visible.

---

## Doctrine adopted

- [`substrate_doctrine.md` §4.1 — Colima and Lima on Apple: the provider follows the workload](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload):
  the selection is a function of the workload and the substrate together, the two providers are one family
  with one extra capability, and the logic that runs inside is the same logic in both.
- [`substrate_doctrine.md` §3.1 — the per-substrate floor](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply):
  Homebrew is the apple package-manager root, which is verified rather than ensured, and a failed floor check
  is a value naming its own remedy.
- [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract):
  Colima is probed, installed when absent, resolved to an absolute path from the package manager, and invoked
  by that path.
- [`resource_capacity_doctrine.md` §4 — the total fold](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting):
  the frame's CPU, memory, and disk are a demand the host's supply must admit, so an oversized frame is a
  rejection at authoring rather than a failure at creation.

---

## Sprints

## Sprint 7.1: The Homebrew floor is verified, never installed 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/Floor/Apple.hs`, `tools/toolchain_requirements.json`
**Blocked by**: none within the phase
**Requires**: `host-floor`
**Independent Validation**: a host carrying `brew` yields a verified no-op; a host without it yields a refusal naming the install instruction, and neither run issues an install argv for Homebrew
**Docs to update**: `documents/engineering/substrate_doctrine.md`

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

The whole sprint.

## Sprint 7.2: Colima ensured, and a frame sized from the carve 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/Frame/Colima.hs`
**Blocked by**: Sprint 7.1
**Independent Validation**: the frame is created at the CPU, memory, and disk the carve admitted; a request exceeding the host's supply is rejected before any provider call
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `documents/engineering/resource_capacity_doctrine.md`

### Objective

Adopt [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract);
ensure Colima through the verified root and provision a frame whose size is a checked value.

### Deliverables

- A Colima ensure that probes, installs through Homebrew when absent, resolves the absolute path from the
  package manager, and invokes only that path — a bare `colima` handed to the OS is a search, not a
  resolution.
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

The whole sprint.

## Sprint 7.3: The provider follows the workload 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/Frame/Select.hs`, `src/Amoebius/Host/Frame/Lima.hs`
**Blocked by**: Sprint 7.2
**Independent Validation**: the selector's enumeration joins to `test/oracle/apple_frame_selection.tsv` in both directions
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Adopt [`substrate_doctrine.md` §4.1 — Colima and Lima on Apple: the provider follows the workload](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload);
make the frame a consequence of what the run needs, and make the substrate-only alternative unrepresentable.

### Deliverables

- A selection function whose domain is the workload and the substrate together; a selector keyed on the
  substrate alone cannot express the doctrine's rows, so the type does not admit one.
- Colima for a workload that needs a container endpoint — an image build, a one-off `docker run --rm`, and a
  kind cluster, whose nodes are themselves containers.
- Lima for a workload that needs the distribution rather than an endpoint, because software installing into a
  full Linux system cannot be satisfied by a container runtime.
- One ensure path shared by both providers, since Colima is Lima carrying a container runtime and the
  difference between them is that runtime alone.

### Validation

1. Every workload the oracle names resolves to exactly one provider, and no workload resolves to two.
2. Changing the substrate without changing the workload cannot change the row the selector returns.

### Remaining Work

The whole sprint.

## Sprint 7.4: The ephemeral one-off and the frame that persists 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/Frame/Lifecycle.hs`
**Blocked by**: Sprint 7.3
**Independent Validation**: after a one-off invocation the provider reports no frame; after a kind cluster is created it reports exactly one, and that one is destroyed with the cluster
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Adopt [`substrate_doctrine.md` §4.1 — Colima and Lima on Apple: the provider follows the workload](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload);
tie each frame's lifetime to the thing it backs, so nothing outlives its reason to exist.

### Deliverables

- A one-off invocation that acquires a frame for the length of that invocation and destroys it — ephemeral by
  construction rather than by a cleanup step a failure can skip.
- A bracket that destroys the frame on the failure path as well as the success path, because a leaked VM is a
  debit no later run knows to account for.
- A frame that persists for the life of what it backs, since a kind node is a container the run is keeping
  and the frame is what keeps it.
- An inventory read that answers from the provider rather than from amoebius's record of what it created, so
  a frame created outside this run is still observed.

### Validation

1. A failed one-off leaves the provider inventory exactly as it found it.
2. Destroying the cluster destroys its frame, and destroying the frame is refused while the cluster exists.

### Remaining Work

The whole sprint.

## Sprint 7.5: The lifted step list and the native image 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/Frame/Lift.hs`, `test/golden/apple_engine_bringup/`
**Blocked by**: Sprint 7.4
**Independent Validation**: the frame delta against the linux step list is empty but for registered friction, and the image the frame builds is `linux/arm64` with no emulation
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `documents/engineering/image_build_doctrine.md`

### Objective

Adopt [`substrate_doctrine.md` §4.1 — Colima and Lima on Apple: the provider follows the workload](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload);
run Phase 4's step list inside the Colima frame and build the native image with it.

### Deliverables

- A lift that parameterizes the existing step list by the frame it runs in, so the Colima path carries no
  step the linux path lacks.
- A frame delta emitted as a golden, because divergence that is not diffable is divergence discovered late.
- A native image built at `arm64`, the host's natural architecture — virtualization synthesizes an operating
  system, not an instruction set, so no cross-build and no emulation is available or wanted.
- A kind cluster created from that image inside the frame, which is what proves the endpoint the frame
  publishes is the endpoint the cluster consumed.

### Validation

1. The emitted step list differs from the linux one only at lines the golden registers.
2. The built image reports `arm64`, and the run records no emulation layer.

### Remaining Work

The whole sprint.

---

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/substrate_doctrine.md` — §4 records Colima as an implemented provider, and §4.4's
  honesty note drops the live Apple/Lima/brew clause for exactly what this gate observed and no more.
- `documents/engineering/resource_capacity_doctrine.md` — §4 records the engine frame as a debited demand
  once the live fit has actually run.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/development_plan_standards.md` — add this phase to the `Declared by` column of the
  `host-floor` row in §F, because that column is joined in both directions.
- `DEVELOPMENT_PLAN/substrates.md` — record Colima beside Lima in the apple row, with the workload that
  selects each.

---

## Related Documents
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md)
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Phase 4](phase_04_host_ensure_kernel.md)
- [Phase 74](phase_74_apple_metal_host_daemon.md)
- [Development Plan](README.md)
