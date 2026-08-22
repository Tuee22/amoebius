# Phase 52: Linux: sudoless Docker and the native image

> **Purpose**: Take a pristine Linux guest to a running amoebius image without elevation, and prove that a
> second identical run changes nothing on it.
> **Read this if**: a bare Linux host has to reach a working container engine, or a host action's re-run
> behaviour has to change.

This phase owns the first contact with a real host: what a newly materialized Linux guest carries before
anything is installed, what the run installs into it, and what a second identical run is permitted to touch.
It does not own how that guest is materialized — the provider mapping and the pristine-guest contract belong
to
[`substrate_doctrine.md` §4](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux),
which this phase consumes without restating. Nor does it own the recipe it builds: its generated semantics and
native invocation value are constrained by [Phase 35](phase_35_image_recipe_generation.md), and the pre-binary command surface belongs to
[Phase 50](phase_50_host_assert_cli.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 52.1: The pristine guest and its recorded preflight 📋](#sprint-521-the-pristine-guest-and-its-recorded-preflight-)
- [Sprint 52.2: The pre-binary leg on a host that carries nothing 📋](#sprint-522-the-pre-binary-leg-on-a-host-that-carries-nothing-)
- [Sprint 52.3: The engine, and sudoless access as three proofs 📋](#sprint-523-the-engine-and-sudoless-access-as-three-proofs-)
- [Sprint 52.4: The native build and the version verdict 📋](#sprint-524-the-native-build-and-the-version-verdict-)
- [Sprint 52.5: The second run that changes nothing 📋](#sprint-525-the-second-run-that-changes-nothing-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

🔄 Active — Phase 51 sealed 2026-08-22. This is the sole open contract. No live gate implementation or
current `linux-cpu/amd64` evidence exists yet; the phase remains open until both are present.

The 2026-08-22 routed attempt reached the retained command and returned RED because
`tools/linux_engine_bringup_gate.py` is absent. This native Darwin/`arm64` workstation also cannot supply the
contract's natural `linux-cpu/amd64` lane; an ARM guest or an emulated AMD64 guest cannot substitute for it.

Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi
change what this phase's gate must cover, so any earlier seal is history and no longer presents completion
evidence.

---

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

**Depends on:** [Phase 35](phase_35_image_recipe_generation.md)

**Requires**: `host-floor`

**Gate:** `python3 tools/run_phase_gate.py 52` passes every check named in
[Gate integrity](#gate-integrity), twice in succession against one guest. Phase 53 does not open until it is
green.

---

## Gate integrity

The gate is `python3 tools/linux_engine_bringup_gate.py --execute`, and it decides five things, none of which
is decidable off a host.


**The clean preflight is evidence, not a formality.** Before the first install argv, the run reads the guest
and writes what it found: no engine package, no `docker` group row, no daemon socket, and no image carrying
the amoebius name. `test/fixture/linux_engine_bringup/preflight.tsv` holds the committed inventory that read
is joined against, so a guest that was already populated fails at the first check rather than yielding a pass
a dirty host would also have produced.

**Sudoless reach is read three ways, and each read is separate.** The group database is read for the invoking
user's membership; a client call is issued inside a login session created after the install; and the same
call is issued from the process that did the installing, before any re-login. All three must succeed and none
may be retried under elevation, because reach with elevation is a different property from the one claimed.

**The post-state joins an independently authored oracle.**
`test/oracle/linux_engine_bringup_surfaces.tsv` enumerates every surface the run may have changed — the
packages it may install, the group row it writes, the daemon's data root, and the image reference it builds.
The join runs in both directions, so a change the oracle does not name and an oracle row nothing realized are
both failures. The table is authored from the doctrine rather than captured from a first run, since a run
that records its own expectation demonstrates only that it is self-consistent.

**Idempotence is a comparison of two ledgers.** Each pass emits an action ledger that separates a probe from
a mutation. The second pass must record probes and no mutations: an empty mutation set alone is satisfied by
a pass that did nothing at all, including nothing to check, so an empty probe set fails the same check.

**`test/mutant/registry.tsv` carries five mutants for this gate.** Each must fail it, and no two may fail
it at the same check:

- `ephemeral-membership` grants the group to the running process only and never writes the group database —
  reddens the durable-membership read while the current-process read stays green, which is what shows the
  three proofs are not one proof spelled three ways.
- `unrefreshed-credentials` writes the group database and leaves the installing process's credential set as
  it was — reddens the current-process read alone.
- `elevated-retry` re-issues a denied daemon call under elevation — reddens the future-session read, because
  a call that needed elevation answers a question the gate did not ask.
- `converge-without-probe` reports the second pass converged from the first pass's recorded result — reddens
  the empty-probe-set check.
- `platform-override` hands the build an explicit platform the guest cannot execute — reddens the
  native-architecture check.

---

- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`; negatives under `test/negative/linux_engine_bringup/`.

## Doctrine adopted

- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — linux: sudoless Docker and the native image is admitted by satisfying the contract, not by appearing on a list.
- [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract):
  the engine is probed, installed when absent, resolved to an absolute path from the package manager, and
  invoked by that path, which is what makes "installed" a state a later run can re-read.
- [`substrate_doctrine.md` §4.3 — Incus on Linux](../documents/engineering/substrate_doctrine.md#43-incus-on-linux):
  the guest is created only after the provider's own initialisation verifies, so a provider that is not ready
  is reported as a provider failure rather than as a failed install inside a guest that never existed.
- [`image_build_doctrine.md` §3 — one image per architecture](../documents/engineering/image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index):
  the requested architecture, the guest's, and the engine's are compared before the build starts, and a
  mismatch refuses rather than emulating, because a container shares the host's instruction set.
- [`testing_doctrine.md` §3 — the test-topology contract](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down):
  the guest is destroyed on every exit path, so a failed run leaves no host state for the next run to
  inherit and misread as its own.

---

## Sprints

## Sprint 52.1: The pristine guest and its recorded preflight 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/Frame/Incus.hs`, `test/fixture/linux_engine_bringup/`
**Blocked by**: none within the phase
**Requires**: `host-floor`
**Independent Validation**: the guest's pre-install read matches the committed preflight inventory row for row, and the provider reports no guest after the run
**Docs to update**: `documents/engineering/substrate_doctrine.md`

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

## Sprint 52.2: The pre-binary leg on a host that carries nothing 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/Floor/Linux.hs`, `tools/toolchain_requirements.json`
**Blocked by**: Sprint 52.1
**Independent Validation**: the guest reaches `exe:amoebius` at one absolute path, and no Python process survives the handoff
**Docs to update**: `documents/engineering/substrate_doctrine.md`

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

## Sprint 52.3: The engine, and sudoless access as three proofs 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/Engine/Docker.hs`, `src/Amoebius/Host/Engine/Access.hs`
**Blocked by**: Sprint 52.2
**Independent Validation**: the group database, a freshly created login session, and the installing process each reach the daemon, and none of the three calls is elevated
**Docs to update**: `documents/engineering/substrate_doctrine.md`

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

## Sprint 52.4: The native build and the version verdict 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/Engine/Build.hs`, `src/Amoebius/Image/Build.hs`
**Blocked by**: Sprint 52.3
**Independent Validation**: the built image's architecture equals the guest's, and the recorded version string is the one the container printed
**Docs to update**: `documents/engineering/image_build_doctrine.md`

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

## Sprint 52.5: The second run that changes nothing 📋

**Status**: Planned
**Implementation**: `tools/linux_engine_bringup_gate.py`, `test/oracle/linux_engine_bringup_surfaces.tsv`
**Blocked by**: Sprint 52.4
**Independent Validation**: the second pass's ledger records probes and no mutations, and the two post-state reads agree on every surface the oracle names
**Docs to update**: `documents/engineering/testing_doctrine.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`

### Objective

Adopt [`testing_doctrine.md` §3 — the test-topology contract](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down);
run the whole sequence a second time against the same guest and require that it did nothing.

### Deliverables

- An action ledger per pass that types each entry as a probe or a mutation, so two passes are comparable
  rather than merely both green.
- A post-state read after each pass over exactly the surfaces the oracle enumerates, joined in both
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

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
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
