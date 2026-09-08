# Phase 52: Linux: sudoless Docker and the native image

> **Purpose**: Take a pristine Linux guest to a running amoebius image without elevation, and prove that a
> second identical run changes nothing on it.
> **Read this if**: a bare Linux host has to reach a working container engine, or a host action's re-run
> behaviour has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision](#resource-provision)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 52.1: The pristine guest and its recorded preflight](#sprint-521-the-pristine-guest-and-its-recorded-preflight-)
- [Sprint 52.2: The pre-binary leg on a host that carries nothing](#sprint-522-the-pre-binary-leg-on-a-host-that-carries-nothing-)
- [Sprint 52.3: The engine, and sudoless access as three proofs](#sprint-523-the-engine-and-sudoless-access-as-three-proofs-)
- [Sprint 52.4: The native build and the version verdict](#sprint-524-the-native-build-and-the-version-verdict-)
- [Sprint 52.5: The second run that changes nothing](#sprint-525-the-second-run-that-changes-nothing-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 51, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

---

> **Gate interpretation.** The phase-specific contract is bound but remains NOT VALIDATED until the complete
> acquired gate passes for one stable source snapshot. The validated Phase-49 barrier and Phase-50 bootstrap
> authorize this first hardware-bearing run; no prose or component result substitutes for its candidate.

## Phase Summary

Every earlier phase decides its claim in-process or against a fake tool directory. This one decides it on a
Linux guest that carries nothing amoebius put there. The run asserts the floor, builds `exe:amoebius` and
hands off; the binary installs the container engine and makes it usable without elevation; a run-local smoke
image containing that exact binary builds natively at `amd64`; and the built image runs far enough to print a version the gate reads back out of
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
**Gate:** `pb validate phase 52`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED; implementation and independent execution remain open.

| Key | Contract |
|---|---|
| `Claim` | A pristine Ubuntu Linux guest reaches a running native amoebius smoke image through a sudoless Docker client, and the identical second pass records probes but no mutations. |
| `Subject` | `Amoebius.Host.LinuxEngine`, the `dev linux-engine-guest-pass` entry point, and the acquired `Amoebius.Validation.LinuxEngineBringupRun` supervisor. |
| `Command` | `pb validate phase 52`; the validated bootstrap hands off unchanged to Haskell, which serially qualifies the production subject and then owns one live Incus guest from launch through destruction. |
| `Oracle` | `test/spec/host/LinuxEngineBringupOracle.hs`, importing no `Amoebius.*` module and separately authoring the exact surfaces, ledgers, refusal cases, architecture rule, and unelevated argv. |
| `Positive controls` | Four pristine surfaces, five typed first-pass mutations, four second-pass probes, two identical converged surface reads, two version reads, and current/future-session unelevated daemon probes form the closed corpus. |
| `Paired negatives` | Pristine versus each singly dirty surface, agreeing versus mismatched requested/guest/engine architecture, elevated versus unelevated daemon argv, and converged-with-probes versus an empty second ledger are distinguished at exact constructors. |
| `Mutants` | Five Cabal-selected changed production subjects drop durable membership, skip credential refresh, add elevated retry, erase converged probes, or admit platform override. Each must emit its assigned red token while the clean subject remains green. |
| `Discovery` | The acquired tracked-source inventory equals the Linux-engine product module, entry point, Haskell spec, independent oracle, runner pair, dispatch/evidence/runner wiring, and Cabal declarations; the live inventory equals the four surface rows and generated ledgers in both directions. |
| `Challenge` | A uniquely named guest is observed pristine after acquisition, both passes execute against that same live guest, and the second pass must freshly observe every surface while issuing zero mutations. |
| `Observer` | The outer Haskell runner records Incus inventory, process handoff trace, absolute child argv/exits, group database, current and future-session Docker probes, engine architecture, image inspect result, container stdout, and teardown inventory. |
| `Authority/bypass` | The unique Phase-52 owner marker bounds the guest. Docker client calls are never elevated, only the owned guest may be mutated, the host engine is not used, and provider inventory before and after must match exactly. |
| `Freshness` | The run root and guest name are newly absent; source and Phase-51 receipt are acquired before launch; live preflight precedes install; both ledgers are regenerated; opening and closing tracked-source identities must match. |
| `Qualification` | The fixed clean, four dirty-surface, architecture, unelevated-argv, second-pass, and five-mutant corpus qualifies the harness before its live verdict is admitted. Missing observations, the wrong red locus, cached output, or concurrent compiler argv refuses. |
| `Cleanroom` | Source/support archives, compiler products, transcripts, and image context exist only below `.build/runs/phase-52/**` or inside the owned guest; the guest is destroyed in an unconditional bracket and provider inventory must return to its pre-run value. |
| `Legacy closure` | Phase 52 owns no legacy ID; the acquired legacy reverse map must therefore remain empty for this ordinal. |
| `Predecessor` | Exact `ImmediatePredecessorPass` for Phase 51; an absent, stale, replayed, later-phase, or different-source receipt refuses before the guest is launched. |
| `Residue` | `UNVERIFIED`: Apple and Windows engine bring-up, VM host actions beyond this disposable Linux guest, clusters, canonical published base-image execution, registry, services, accelerators, and later live acceptance remain Phase-53+-owned. |
| `Pass criterion` | `qualified-gate-pass` — all eighteen rows pass for one exact stable source snapshot, all five production mutants are red at their assigned loci, both live passes and external observations agree, and owned live residue is exactly zero. |

## Resource provision

- **Owner marker:** exact source snapshot, Phase-51 receipt, unique Phase-52 run root, and unique Incus instance name carrying the `user.owner=phase-52` marker.
- **Preflight:** Linux `x86_64`, initialized Incus, KVM, adequate storage/memory, an absent run root and guest name, and a guest whose Docker package, group membership, daemon surface, and image reference are all absent.
- **Allowed mutation:** create run-local `.build/**` evidence; launch and configure only the marked guest; install `docker.io` and contained build prerequisites inside it; add only guest user `ubuntu` to `docker`; start only its Docker daemon; build/run only the run-owned native smoke image.
- **Forbidden mutation:** no host package, group, daemon, image, VM other than the owned instance, cluster, registry, published tag, foreign Incus instance, ambient toolchain, concurrent compiler, or repository path outside `.build/**` may be changed.
- **Observer:** the outer Haskell supervisor reads provider inventory before/after, guest preflight and architecture, process `execve` trace, group/session/daemon state, image metadata, both ledgers/surface inventories, and container version stdout.
- **Cleanup:** the exact validated instance name is forcibly deleted in an unconditional bracket on success or failure; no wildcard or user-supplied deletion target is admitted.
- **Residue:** provider inventory after cleanup must byte-equal its pre-run inventory; only run-owned `.build/**` evidence may remain, and every other owned live resource count is zero.

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

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 52.1: The pristine guest and its recorded preflight ✅

**Status**: Done
**Implementation**: `Amoebius.Validation.LinuxEngineBringupRun` owns unique Incus launch, pristine preflight, observation, and unconditional deletion.
**Blocked by**: [Phase 51](phase_51_host_ensure_kernel.md) gate pass
**Independent Validation**: exact four-surface pristine admission plus provider inventory equality after forced teardown.
**Oracle**: `test/spec/host/LinuxEngineBringupOracle.hs`, importing no production module.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/substrates.md`.

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

Run the complete acquired Phase-52 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 52.2: The pre-binary leg on a host that carries nothing ✅

**Status**: Done
**Implementation**: the live runner installs only guest build prerequisites, mounts the authenticated contained toolchain read-only, and invokes `pb` under an external `execve` trace.
**Blocked by**: Sprint 52.1
**Independent Validation**: guest `pb --version` output and `execve` trace must identify the source-bound Haskell binary after the Python child.
**Oracle**: the outer runner independently reads the process trace and exact version token.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/substrate_doctrine.md`.

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

Run the complete acquired Phase-52 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 52.3: The engine, and sudoless access as three proofs ✅

**Status**: Done
**Implementation**: `Amoebius.Host.LinuxEngine` owns typed probes/mutations and the live absolute-path interpreter.
**Blocked by**: Sprint 52.2
**Independent Validation**: exact durable group row, current-process probe, future-session probe, and no-sudo argv, with three changed-subject mutants.
**Oracle**: `LinuxEngineBringupOracle.expectedFirstLedger`, `expectedUnelevatedProbe`, and `expectedFutureSession`.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

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

Run the complete acquired Phase-52 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 52.4: The native build and the version verdict ✅

**Status**: Done
**Implementation**: `Amoebius.Host.LinuxEngine.admitNativeBuild` and its live image builder own three-way architecture admission and the run-local smoke image.
**Blocked by**: Sprint 52.3
**Independent Validation**: all agreeing architectures admit, each singly mismatched triple refuses, the platform-override mutant reddens, and live container stdout equals the recorded version.
**Oracle**: `LinuxEngineBringupOracle.architectureCases` and the outer container-output observer.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/image_build_doctrine.md`.

### Objective

Adopt [`image_build_doctrine.md` §3 — one image per architecture](../documents/engineering/image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index);
build the exact run-local binary smoke recipe on this guest, at this guest's architecture, and run the result far enough to produce
a verdict.

### Deliverables

- A three-way architecture agreement — requested, guest, engine — checked before the build starts, with a
  mismatch refused and the disagreeing pair named.
- A version verdict read from the running container's own output, because a version taken from the recipe or
  the build log describes what was asked for rather than what runs.
- An image reference carrying its architecture, so no later consumer can select bytes its host cannot
  execute.
- A run-local recipe written by the source-bound Haskell subject beside the exact executing binary; the
  canonical published base-image recipe and fixed tags remain explicit later residue rather than being
  silently substituted into this engine-access gate.

### Validation

1. A build requesting an architecture the guest cannot execute refuses, and names which of the three reads
   disagreed.
2. The verdict the gate records and the string the container printed are identical.

### Remaining Work

Run the complete acquired Phase-52 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 52.5: The second run that changes nothing ✅

**Status**: Done
**Implementation**: `planLinuxEnginePass` derives each ledger from a fresh live observation and the runner invokes it twice in one guest.
**Blocked by**: Sprint 52.4
**Independent Validation**: the second exact ledger is four probes and zero mutations, both surface tables and version outputs agree, and the empty-ledger mutant reddens.
**Oracle**: `LinuxEngineBringupOracle.expectedSecondLedger` and `expectedSurfaces`.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/testing_doctrine.md`.

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

Run the complete acquired Phase-52 gate; only its exact pass can authorize the mechanical status projection.

---

## Documentation Requirements

**Engineering docs that must agree with the exact gate snapshot:**

- `documents/engineering/substrate_doctrine.md` — §3.1's linux floor records what a real guest actually
  needed, and §4.3 records Incus as an exercised provider rather than a planned one.
- `documents/engineering/image_build_doctrine.md` — §3 distinguishes the independently qualified
  architecture-mismatch refusal from the naturally agreeing live-host observation.

**Cross-references to add:**

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
