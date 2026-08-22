# Phase 53: Apple: Homebrew, Colima, and the native image

> **Purpose**: Bring an Apple Silicon host to a container engine, a budget-sized Linux frame, and a native
> `arm64` image — and prove the steps that run inside were lifted rather than written a second time.
> **Read this if**: an apple host has to reach an image build or a kind cluster, or the frame a workload selects has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
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
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 53.1: The Homebrew floor is verified, never installed ⏸️](#sprint-531-the-homebrew-floor-is-verified-never-installed-)
- [Sprint 53.2: Colima ensured, and a frame sized from the carve ⏸️](#sprint-532-colima-ensured-and-a-frame-sized-from-the-carve-)
- [Sprint 53.3: The provider follows the workload ⏸️](#sprint-533-the-provider-follows-the-workload-)
- [Sprint 53.4: The ephemeral one-off and the frame that persists ⏸️](#sprint-534-the-ephemeral-one-off-and-the-frame-that-persists-)
- [Sprint 53.5: The lifted step list and the native image ⏸️](#sprint-535-the-lifted-step-list-and-the-native-image-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 52, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

---

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

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

**Depends on:** [Phase 52](phase_52_linux_engine_bringup.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 53`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | one cohesive claim — *an apple host reaches a container engine, a budget-sized frame, and a native `arm64` image, using the linux step list unchanged*. Its sprint seams are the floor, the frame, the selection, the lifecycle, and the lift. It splits if a second substrate or a second acceptance register appears. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 53` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 52 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

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

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 53.1: The Homebrew floor is verified, never installed ⏸️

**Status**: Blocked — NOT VALIDATED

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

## Sprint 53.2: Colima ensured, and a frame sized from the carve ⏸️

**Status**: Blocked — NOT VALIDATED

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

## Sprint 53.3: The provider follows the workload ⏸️

**Status**: Blocked — NOT VALIDATED

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

## Sprint 53.4: The ephemeral one-off and the frame that persists ⏸️

**Status**: Blocked — NOT VALIDATED

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

## Sprint 53.5: The lifted step list and the native image ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`substrate_doctrine.md` §4.1 — Colima and Lima on Apple: the provider follows the workload](../documents/engineering/substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload);
run Phase 51's step list inside the Colima frame and build the native image with it.

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

**Engineering docs to update (when the human promotes the gate, never before):**

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
- [Phase 51](phase_51_host_ensure_kernel.md)
- [Phase 89](phase_89_apple_metal_host_daemon.md)
- [Development Plan](README.md)
