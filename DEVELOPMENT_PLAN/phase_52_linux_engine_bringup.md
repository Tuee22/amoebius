# Phase 52: Linux: sudoless Docker and the native image

> **Purpose**: Take a pristine Linux guest to a running amoebius image without elevation, and prove that a
> second identical run changes nothing on it.
> **Read this if**: a bare Linux host has to reach a working container engine, or a host action's re-run
> behaviour has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 52.1: The pristine guest and its recorded preflight ⏸️](#sprint-521-the-pristine-guest-and-its-recorded-preflight-)
- [Sprint 52.2: The pre-binary leg on a host that carries nothing ⏸️](#sprint-522-the-pre-binary-leg-on-a-host-that-carries-nothing-)
- [Sprint 52.3: The engine, and sudoless access as three proofs ⏸️](#sprint-523-the-engine-and-sudoless-access-as-three-proofs-)
- [Sprint 52.4: The native build and the version verdict ⏸️](#sprint-524-the-native-build-and-the-version-verdict-)
- [Sprint 52.5: The second run that changes nothing ⏸️](#sprint-525-the-second-run-that-changes-nothing-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 51, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

---

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

Every earlier phase decides its claim in-process or against a fake tool directory. This one decides it on a
Linux guest that carries nothing amoebius put there. The run asserts the floor, builds `exe:amoebius` and
hands off; the binary installs the container engine and makes it usable without elevation; the sealed recipe
builds natively at `amd64`; and the built image runs far enough to print a version the gate reads back out of
the container.

**Sudoless engine access is three distinct proofs, not one.** The first is durable group membership — the
group database records the invoking user, so the fact outlives the process that wrote it. The second is that
a session created *after* the change reaches the daemon, which is what a re-login actually delivers. The
third is that the *current* process reaches it before any re-login, because a process's supplementary group
set is fixed when it is forked and adding a database row does not revisit it. The middle proof is the one an
implementation forgets, because the other two bracket it: membership is visible in a file, and the current
process is the one running the check. A future session is neither, so nothing observes it unless the run
deliberately creates one.

**The re-run is this phase's real claim.** A host can be made to work once by any sequence of commands, and a
single green run cannot separate an action that converged from an action that merely succeeded. The gate
therefore executes the whole sequence twice against the same guest and requires the second pass to install
nothing, write no group row, restart no daemon, and rebuild no image. Idempotence asserted in prose is an
intention; idempotence is the difference between two recorded action sets.

The steps the run executes are typed data rather than code paths, because the apple and windows bringups lift
this list instead of re-authoring it. A second spelling of one step is how two host paths begin to differ.

**Phase scope:** one cohesive claim — *a pristine Linux guest reaches a running amoebius image without
elevation, and an identical second run mutates nothing*. Its sprint seams are the guest, the pre-binary leg,
the engine, the native build, and the re-run. It splits if a second substrate or a second acceptance register
appears.

**Substrate:** `linux-cpu` — a newly created Linux guest, and no other host participates ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** `linux-cpu/amd64` — the guest's own architecture, never emulated ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 3 — live: the claim is about a host's observable state, which no in-process model settles ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 51](phase_51_host_ensure_kernel.md)
**Gate:** `pb validate phase 52`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive claim — *a pristine Linux guest reaches a running amoebius image without elevation, and an identical second run mutates nothing*. Its sprint seams are the guest, the pre-binary leg, the engine, the native build, and the re-run. It splits if a second substrate or a second acceptance register appears. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 52` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 51; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [`extension_conformance_doctrine.md` §5 — The conformance gate is generated, not authored](../documents/engineering/extension_conformance_doctrine.md#5-the-conformance-gate-is-generated-not-authored) — linux: sudoless Docker and the native image is admitted by satisfying the contract, not by appearing on a list.
- [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract):
  the engine is probed, installed when absent, resolved to an absolute path from the package manager, and
  invoked by that path, which is what makes "installed" a state a later run can re-read.
- [`substrate_doctrine.md` §4.3 — Incus on Linux](../documents/engineering/substrate_doctrine.md#43-incus-on-linux):
  the guest is created only after the provider's own initialisation verifies, so a provider that is not ready
  is reported as a provider failure rather than as a failed install inside a guest that never existed.
- [`image_build_doctrine.md` §3 — One image per architecture — the tag carries the architecture, not an index](../documents/engineering/image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index):
  the requested architecture, the guest's, and the engine's are compared before the build starts, and a
  mismatch refuses rather than emulating, because a container shares the host's instruction set.
- [`testing_doctrine.md` §3 — The test-topology contract: spin up → run → always tear down](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down):
  the guest is destroyed on every exit path, so a failed run leaves no host state for the next run to
  inherit and misread as its own.

---

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 52.1: The pristine guest and its recorded preflight ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 51](phase_51_host_ensure_kernel.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`substrate_doctrine.md` §4.3 — Incus on Linux](../documents/engineering/substrate_doctrine.md#43-incus-on-linux);
materialize the guest the rest of the phase runs inside, and record what it looked like before anything was
installed.

### Deliverables

- A guest created from the pinned image at the parent's detected architecture, after the provider's
  initialisation has verified, because a guest created from an unverified provider proves nothing about
  either.
- A preflight read taken from the guest itself — packages, group rows, daemon sockets, image references — and
  emitted before the first install argv is issued.
- A teardown bracketed around the whole run, including the failure path, so a leaked guest cannot become the
  next run's starting state.
- An inventory answered by the provider rather than by amoebius's record of what it created, so a guest this
  run did not create is still observed.

### Validation

1. The recorded preflight names the engine, the group row, and the image reference as absent, and the run
   refuses when any of the three is already present.
2. A run interrupted between creation and the first install leaves the provider inventory as it found it.

### Remaining Work

The whole sprint.

## Sprint 52.2: The pre-binary leg on a host that carries nothing ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 52.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Run the pre-binary leg where it has never actually run — inside a guest holding nothing amoebius installed —
and observe the handoff from outside the process that performs it.

### Deliverables

- A linux floor decision taken before any tool is resolved: the package-manager root at its absolute path,
  and the privilege that installs through it, verified without a prompt.
- The virtualization fact excluded from the guest's floor, because `/dev/kvm` is the parent's prerequisite
  and was already decided when the guest was created.
- A handoff observed from the guest's process table rather than from the coordinator's own report, so
  "replaces itself" is a read and not a claim.
- A refusal naming its prerequisite and the instruction that clears it, so a guest missing the floor is told
  what to do instead of failing several requirements deep.

### Validation

1. The floor decision is recorded before the first install argv, and a guest whose package-manager root is
   removed refuses with the remedy.
2. After the handoff exactly one amoebius process exists in the guest, and it is the binary.

### Remaining Work

The whole sprint.

## Sprint 52.3: The engine, and sudoless access as three proofs ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 52.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract);
install the container engine and make it usable without elevation as three properties checked apart.

### Deliverables

- An engine install driven as probe, install, resolve, invoke, whose probe is also its post-condition, so the
  same read decides both whether to act and whether the action worked.
- A durable group membership written to the group database, which is what a session created later reads.
- A refresh of the installing process's own credential set, because that process's supplementary groups were
  fixed at fork and no database write reaches back into it.
- A refusal carrying the remedy when the daemon answers only under elevation, since a reachable-with-sudo
  daemon satisfies a different claim than the one this phase makes.
- The install and access steps emitted as typed data the driver interprets, so another substrate lifts this
  list rather than authoring a second one.

### Validation

1. A client call issued inside a login session created after the install succeeds, unelevated.
2. The same call from the installing process succeeds before any re-login.
3. No daemon call the run issues is wrapped in an elevation, on either the success or the failure path.

### Remaining Work

The whole sprint.

## Sprint 52.4: The native build and the version verdict ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 52.3
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`image_build_doctrine.md` §3 — one image per architecture](../documents/engineering/image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index);
build the sealed recipe on this guest, at this guest's architecture, and run the result far enough to produce
a verdict.

### Deliverables

- A three-way architecture agreement — requested, guest, engine — checked before the build starts, with a
  mismatch refused and the disagreeing pair named.
- A version verdict read from the running container's own output, because a version taken from the recipe or
  the build log describes what was asked for rather than what runs.
- An image reference carrying its architecture, so no later consumer can select bytes its host cannot
  execute.
- A build that consumes the recipe as published bytes and renders none of its own, since a build that
  re-renders is a second projection nothing pinned.

### Validation

1. A build requesting an architecture the guest cannot execute refuses, and names which of the three reads
   disagreed.
2. The verdict the gate records and the string the container printed are identical.

### Remaining Work

The whole sprint.

## Sprint 52.5: The second run that changes nothing ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 52.4
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`testing_doctrine.md` §3 — the test-topology contract](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down);
run the whole sequence a second time against the same guest and require that it did nothing.

### Deliverables

- An action ledger per pass that types each entry as a probe or a mutation, so two passes are comparable
  rather than merely both green.
- A post-state read after each pass over exactly the surfaces the Haskell oracle enumerates, joined in both
  directions.
- A teardown that destroys the guest on every exit path, so the phase leaves nothing behind for a later run
  to inherit.
- A run identifier under which both passes' ledgers are retained, so the comparison is reproducible from the
  record rather than only from the console.

### Validation

1. The second pass records at least one probe per assertion and no mutation.
2. The two post-state reads agree on every enumerated surface, and any surface only one of them names is a
   failure.
3. Nothing outside the guest is written, and the parent's inventory after teardown equals the one before
   creation.

### Remaining Work

The whole sprint.

---

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/substrate_doctrine.md` — §3.1's linux floor records what a real guest actually
  needed, and §4.3 records Incus as an exercised provider rather than a planned one.
- `documents/engineering/image_build_doctrine.md` — §3's refusal-on-mismatch rule records its observed
  failure mode once a mismatch has been refused on a host.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/development_plan_standards.md` — add this phase to the `Declared by` column of the
  `host-floor` row in §F, because that column is joined in both directions.
- `DEVELOPMENT_PLAN/substrates.md` — add the per-phase row naming this gate's substrate, lane, and what it
  validates.

---

## Related Documents

- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md)
- [Image Build & Registry](../documents/engineering/image_build_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Phase 50](phase_50_host_assert_cli.md)
- [Phase 35](phase_35_image_recipe_generation.md)
- [Development Plan](README.md)
