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

## Phase Status

⏸️ Blocked — NOT VALIDATED.

The [2026-09-08 reset](README.md#reopened-numeric-sequence) withdraws prior certification. Existing
implementation is an Observed footprint / Known partial. Retained requirements remain obligations; only this
phase's complete qualified gate under the replacement acceptance baseline can authorize Done.

Gate execution remains blocked by the qualified Phase-51 predecessor and its compatible evidence chain.
Live effects also require the preceding named barriers in [the phase model](development_plan_phase_model.md#l-one-substrate-discipline).

## Phase Summary

This phase is the first live hardware-bearing gate, and its prerequisites remain closed until every predecessor has a new qualified pass. The audit found planned ledgers presented as executed actions, version-only tracing that missed both guest passes, root Docker probes/builds despite a sudoless claim, and selector-based generic failure labels. The replacement gate must observe complete execution and exact refusal loci before asserting engine readiness or second-pass convergence.

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

**Contract check**: BOUND — the replacement certification generation, protected accepted baseline,
authenticated phase receipt, and current compatibility closure are Haskell-owned inputs. Execution evidence
remains phase-local and cannot be supplied by this prose.

| Key | Contract |
|---|---|
| `Claim` | One pristine natural-architecture Ubuntu Linux guest installs its engine and runs the native source-bound smoke image through a designated non-root Docker client. Complete external observations cover the whole run; the identical second complete guest pass issues required probes and zero mutations. |
| `Subject` | `Amoebius.Host.LinuxEngine`, the `dev linux-engine-guest-pass` entry point, and the acquired `Amoebius.Validation.LinuxEngineBringupRun` supervisor. |
| `Command` | `pb validate phase 52`; the validated bootstrap hands off unchanged to Haskell, which serially qualifies the production subject and then owns one live Incus guest from launch through destruction. |
| `Oracle` | `test/spec/host/LinuxEngineBringupOracle.hs`, importing no `Amoebius.*` module and separately authoring the exact surfaces, ledgers, refusal cases, architecture rule, and unelevated argv. |
| `Positive controls` | Acquire the pristine guest and complete successful install, durable membership, current/future-session access, native smoke build/run and second complete guest pass. Independently observe every process, daemon endpoint, credential context, surface and owned resource involved. |
| `Paired negatives` | Pair each dirty-surface, architecture, credential, root-client, endpoint, missing-probe and unexpected-mutation refusal with a successful observed control. Require the exact independent error and zero forbidden effects, including unrelated-failure and untraced-action regressions. |
| `Mutants` | Mutate actual membership, credential refresh, elevation, architecture, probing, process observation or ledger derivation. Each must fail its independently assigned exact semantic/authority case; any assertion failure printed as the active selector token is rejected. |
| `Discovery` | Join every process and effect-producing call site, typed action, Docker invocation, observed UID/groups/environment/endpoint and resource to an independent expected role and case. Planned rows or a fixed four-surface list cannot conceal unobserved actions. |
| `Challenge` | A uniquely named guest is observed pristine after acquisition, both passes execute against that same live guest, and the second pass must freshly observe every surface while issuing zero mutations. |
| `Observer` | An external supervisor continuously records both actual guest passes and smoke work, including executable/argv/environment, UID/effective UID/groups, Docker endpoint/context, syscall/process outcomes, package/group/daemon/image effects, version output and teardown. The earlier version-only trace cannot supply this coverage. |
| `Authority/bypass` | Only the marked guest may change. Privileged package/group/daemon setup is explicit; every Docker client invocation, including version/info/inspect/build/run, must run as the designated non-root user against the declared guest daemon endpoint, without elevated retry. Parent engine and hidden root probes are forbidden. |
| `Freshness` | The run root and guest name are newly absent; source and Phase-51 receipt are acquired before launch; live preflight precedes install; both ledgers are regenerated; opening and closing tracked-source identities must match. |
| `Qualification` | Observe successful legal controls and exact dirty/architecture/credential/ledger refusals, then reject wrong-case selector labels, fabricated planned ledgers, missing pass traces, root Docker calls, endpoint substitutions and hidden second-pass mutations before admitting any live verdict. |
| `Cleanroom` | Source/support archives, compiler products, transcripts, and image context exist only below `.build/runs/phase-52/**` or inside the owned guest; the guest is destroyed in an unconditional bracket and provider inventory must return to its pre-run value. |
| `Legacy closure` | Phase 52 owns no legacy ID; the acquired legacy reverse map must therefore remain empty for this ordinal. |
| `Predecessor` | Authenticated `ImmediatePredecessorPass` for Phase 51 in the admitted certification generation, plus the accepted verifier's current compatibility decision under [§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass). Missing, forged, revoked, incompatible, or wrong-phase evidence refuses before any phase effect. Historical source identity remains recorded; reuse requires unchanged relevant dependency and acceptance closures. |
| `Residue` | Apple/Windows, other guest architectures, clusters, canonical published images, registries/services, accelerators and later live acceptance remain unverified. No unseen setup/smoke/root action is deferred as residue; complete observation and declared authority are required within this guest run. |
| `Pass criterion` | All eighteen rows pass for one stable source and exact predecessor; assigned mutants fail their specific independently observed cases, all Docker calls obey the declared non-root boundary, both actual passes have complete truthful ledgers, and externally observed owned live residue is zero. |

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

The sprint requirements below remain part of the target acceptance scope. Each owner must bind them in
Haskell and qualify the mechanism that first admits their result; component observations cannot close a sprint.

## Sprint 52.1: The pristine guest and its recorded preflight ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `Amoebius.Validation.LinuxEngineBringupRun` owns unique Incus launch, pristine preflight, observation, and unconditional deletion.
**Blocked by**: [Phase 51](phase_51_host_ensure_kernel.md) gate pass
**Independent Validation**: Externally acquire and observe the pristine owned guest; each singly dirty surface refuses at its exact reason after successful setup; assigned preflight/observer mutants are detected; foreign hosts and other substrates remain excluded.
**Oracle**: `test/spec/host/LinuxEngineBringupOracle.hs`, importing no production module.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/substrates.md`.

### Objective

Adopt [`substrate_doctrine.md` §4.3 — Incus on Linux](../documents/engineering/substrate_doctrine.md#43-incus-on-linux);
materialize the guest the rest of the phase runs inside, and record what it looked like before anything was
installed.

### Deliverables

- Start external process/effect observation before guest setup and retain it through both passes, smoke work and cleanup. Assign every permitted privileged setup action an explicit role; no Docker client call is exempt from non-root observation.

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

- Interrupt at every acquisition/setup boundary and require independently observed cleanup. A failing provider or absent guest is setup failure, not a successful dirty-surface negative.

1. The recorded preflight names the engine, the group row, and the image reference as absent, and the run
   refuses when any of the three is already present.
2. A run interrupted between creation and the first install leaves the provider inventory as it found it.

### Remaining Work

Run the complete acquired Phase-52 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 52.2: The pre-binary leg on a host that carries nothing ⏸️

**Status**: Blocked — NOT VALIDATED
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

- Bind the externally observed bootstrap-to-binary handoff to the same guest, exact authenticated source/toolchain and credential context used by subsequent passes; version tracing alone cannot attest later execution.

- A linux floor decision taken before any tool is resolved: the package-manager root at its absolute path,
  and the privilege that installs through it, verified without a prompt.
- The virtualization fact excluded from the guest's floor, because `/dev/kvm` is the parent's prerequisite
  and was already decided when the guest was created.
- A handoff observed from the guest's process table rather than from the coordinator's own report, so
  "replaces itself" is a read and not a claim.
- A refusal naming its prerequisite and the instruction that clears it, so a guest missing the floor is told
  what to do instead of failing several requirements deep.

### Validation

- Continue custody after the version handoff through the actual ensure entry points. Missing observation intervals or substituted guest/UID/executable identities refuse before live acceptance.

1. The floor decision is recorded before the first install argv, and a guest whose package-manager root is
   removed refuses with the remedy.
2. After the handoff exactly one amoebius process exists in the guest, and it is the binary.

### Remaining Work

Run the complete acquired Phase-52 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 52.3: The engine, and sudoless access as three proofs ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `Amoebius.Host.LinuxEngine` owns typed probes/mutations and the live absolute-path interpreter.
**Blocked by**: Sprint 52.2
**Independent Validation**: Observe durable membership and actual non-root Docker access in current and future sessions; root/elevated/endpoint-substituted variants fail specifically; assigned access mutants fail their exact cases; no other substrate is claimed.
**Oracle**: `LinuxEngineBringupOracle.expectedFirstLedger`, `expectedUnelevatedProbe`, and `expectedFutureSession`.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective

Adopt [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract);
install the container engine and make it usable without elevation as three properties checked apart.

### Deliverables

- Every actual Docker client call carries independently observed UID/effective UID, supplementary groups, argv, environment, context and endpoint. Use the explicit default owned-guest daemon endpoint and refuse ambient context/socket substitution.
- Observe all probe, version, info, inspect, build and run invocations as the designated non-root user. Privileged package/group/service setup does not authorize a root Docker client.

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

- Reproduce the audited hidden root version/build path and require exact authority refusal even if the non-root access probes also succeed. Include wrong endpoint, ambient Docker context and elevated retry negatives.
- An unrelated assertion failure under a membership/refresh selector cannot count as its kill; require its independently assigned exact failed access observation and a passing unaffected control.

1. A client call issued inside a login session created after the install succeeds, unelevated.
2. The same call from the installing process succeeds before any re-login.
3. No daemon call the run issues is wrapped in an elevation, on either the success or the failure path.

### Remaining Work

Run the complete acquired Phase-52 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 52.4: The native build and the version verdict ⏸️

**Status**: Blocked — NOT VALIDATED
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

- Build and run the owned native smoke image through the same observed non-root client and declared daemon endpoint. Record smoke build/run effects separately but retain them in the complete run ledger.

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

- Compare observed requested/guest/engine/image architectures and actual container output from the acquired non-root invocation. A root-side inspect/build result cannot substitute.
- Require observation of the real build/run process and image/container effects; generated recipe text, a source-bound version expectation or a planned build row is not execution evidence.

1. A build requesting an architecture the guest cannot execute refuses, and names which of the three reads
   disagreed.
2. The verdict the gate records and the string the container printed are identical.

### Remaining Work

Run the complete acquired Phase-52 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 52.5: The second run that changes nothing ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `planLinuxEnginePass` derives each ledger from a fresh live observation and the runner invokes it twice in one guest.
**Blocked by**: Sprint 52.4
**Independent Validation**: The actual first and second complete guest passes have externally derived full action ledgers; the second retains required probes and no mutations; hidden-action/root-client/plan-only-ledger pairs and assigned mutants fail exactly; all owned resources are externally absent after teardown.
**Oracle**: `LinuxEngineBringupOracle.expectedSecondLedger` and `expectedSurfaces`.
**Legacy IDs**: none.
**Docs to update**: `documents/engineering/testing_doctrine.md`.

### Objective

Adopt [`testing_doctrine.md` §3 — the test-topology contract](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down);
run the whole sequence a second time against the same guest and require that it did nothing.

### Deliverables

- Derive both ledgers from acquired process/effect events, then reconcile them bidirectionally to the planned typed actions. `planLinuxEnginePass` supplies intended actions only and cannot populate an executed ledger.
- Give the entire run an explicit ledger scope: guest acquisition, each complete production guest pass including smoke work, and final cleanup. The second complete pass must reuse converged package/group/daemon/image/container resources through observed probes; rebuilding an image, creating an unrecorded container or moving smoke mutations outside its ledger cannot satisfy zero mutations.

- An action ledger per pass that types each entry as a probe or a mutation, so two passes are comparable
  rather than merely both green.
- A post-state read after each pass over exactly the surfaces the Haskell oracle enumerates, joined in both
  directions.
- A teardown that destroys the guest on every exit path, so the phase leaves nothing behind for a later run
  to inherit.
- A run identifier under which both passes' ledgers are retained, so the comparison is reproducible from the
  record rather than only from the console.

### Validation

- Reproduce a plan-only second ledger with an injected actual install, root Docker call, image rebuild or smoke mutation; the external action join must identify and reject the hidden event.
- Trace both actual guest passes, not only an earlier `pb --version` call. Compare exact observed probes/mutations, credential contexts, surfaces and endpoints before claiming idempotence.
- Require each qualification failure to identify its exact independent case/reason and observed event. The active CPP selector cannot determine a generic red label for any failed assertion.

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
