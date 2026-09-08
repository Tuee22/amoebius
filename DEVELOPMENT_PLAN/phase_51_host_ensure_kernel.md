# Phase 51: The host-ensure kernel

> **Purpose**: Move every host assertion after the handoff into one closed, substrate-indexed algebra whose
> install steps are typed data, with algebraic totality as the target claim.
> **Read this if**: a host tool has to be ensured, a substrate arm has to be added, or a step has to run inside
> a frame rather than on the host.

This document binds the Phase-51 capability and its still-open exact gate. Current status is owned by
[the tracker](README.md) and the Phase Status block below; only the qualified gate may authorize a status edit.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision](#resource-provision)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 51.1: The closed substrate algebra](#sprint-511-the-closed-substrate-algebra-)
- [Sprint 51.2: Install steps as typed data](#sprint-512-install-steps-as-typed-data-)
- [Sprint 51.3: The reconciler table](#sprint-513-the-reconciler-table-)
- [Sprint 51.4: The probe-first ensure driver](#sprint-514-the-probe-first-ensure-driver-)
- [Sprint 51.5: The lift fold to argv](#sprint-515-the-lift-fold-to-argv-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

The [2026-09-08 reset](README.md#reopened-numeric-sequence) withdraws prior certification. Existing
implementation is an Observed footprint / Known partial. Retained requirements remain obligations; only this
phase's complete qualified gate under the replacement acceptance baseline can authorize Done.

Gate execution remains blocked by the qualified Phase-50 predecessor and its compatible evidence chain.

## Phase Summary

The audit found selector-dependent failure labels that could turn any assertion failure into an apparent assigned mutant kill, and a production-caller check based on the occurrence of `installAndVerify` in source text. The required gate must execute the actual caller through fake boundaries and bind every failure to its independent exact assertion and observation.

The binary takes over every assertion the moment [Phase 50](phase_50_host_assert_cli.md) execs it, and the
pressure on this phase is that the takeover happens once, in one place. One table answers which frame a
substrate supplies and which engine that frame supplies. One type describes an install step. One driver
executes a plan, and one fold turns a lift context into the argv that runs a step inside it. A second
spelling of any of the four is the defect the future phase gate must make unconstructable.

That foreclosure is a typing obligation rather than a testing one. "Install Docker twice on Apple"
and "no Linux frame on Windows" must not be values the target algebra can build. The map from substrate to
frame must be total and closed, with no default arm to absorb a member nobody considered. A test can only
observe the cases someone thought to write down; the future gate must establish that a total map without a
wildcard refuses to compile when a case goes missing.

The tree now carries the closed algebra, typed interpreter, production caller, separately authored Haskell
oracle, paired negatives, and changed-production-subject selectors. None is phase evidence until the integrated
gate observes it under the exact Phase-50 receipt.
`installAndVerify` has zero callers, and `pristineLinuxProvider` is consumed only by two specs.
`Cluster/Bootstrap.hs` refuses `apple` and `windows` outright rather than entering their frames; `HostTool`
has five constructors and no Docker arm; and `installMechanism :: String` in `src/Amoebius/Host/Ensure.hs`
holds values like `brew-install:ghcup` that nothing parses and nothing executes. The plan is pure and
uninterpretable at the same time, and that pairing is what the future phase gate must close.

**Phase scope:** one cohesive claim — *every post-handoff host assertion resolves through one closed,
substrate-indexed algebra whose install steps are typed data*. Its sprint seams are the algebra, the step
type, the reconciler table, the driver, and the lift fold. It splits if a second acceptance register or a
second substrate appears.

**Substrate:** `none` — Haskell declarations generate a fresh run-local fake tool directory beneath
`.build/**`; it is never retained in the repository and the algebra is replayed against it, not a host
([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** none ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 2 — boundary-with-fakes: the claim is about tool resolution and emitted argv, not about a value ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 50](phase_50_host_assert_cli.md)
**Gate:** `pb validate phase 51`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: UNRESOLVED — NOT VALIDATED; the replacement certification-generation and accepted-baseline
binding has not been authored in Haskell. Retained rows specify intended scope and supply no execution evidence.

| Key | Contract |
|---|---|
| `Claim` | The actual Haskell host-context caller drives the typed probe-first ensure and lift semantics against independently observed fake host boundaries, with precise applicability/refusal reasons, fresh resolution after changes and no installation on an already converged second pass. |
| `Subject` | `Amoebius.Host.{Substrate,Frame,HostTool,Ensure,Reconciler,Lift,Context}`, the production `mkBinaryContext` caller, and the acquired `Amoebius.Validation.HostEnsureKernelRun` supervisor. |
| `Command` | `pb validate phase 51`; the already validated bootstrap forwards this exact argv to the source-bound Haskell dispatcher, which runs every compiler-bearing matrix row offline and serially with `--jobs=1`. |
| `Oracle` | `test/spec/host/HostEnsureKernelOracle.hs`, which imports no production module and separately authors the exact frame, plan, applicability, argv, replay, paired-negative, and two-root expectations. |
| `Positive controls` | Observe the actual production caller on every declared substrate/frame/tool/reconciler arm, exact typed plans and lifted requests, absent-to-present convergence, a probe-only second pass and two isolated fake hosts. |
| `Paired negatives` | Require successful paired controls before bare/missing/nonexecutable/foreign-root/excluded-substrate/exhausted-plan cases. Each refusal must match its independently authored constructor, arguments and diagnostic with zero forbidden process requests. |
| `Mutants` | Change initial probing, resolution freshness, applicability, diagnostic derivation, frame lifting or actual production caller routing. The assigned independent exact case must fail for its expected reason; a generic issue list labeled by the active selector is inadmissible. |
| `Discovery` | The acquired source inventory must equal the seven host production modules, production caller, Haskell spec, independent oracle, runner, and Cabal declarations in both directions; runtime discovery must produce exactly the closed expected files and row counts. |
| `Challenge` | Each candidate uses a newly absent run root and two newly absent fake-host roots; a tool created after acquisition must resolve only in its owning root, while the paired foreign root remains empty. |
| `Observer` | The acquired supervisor retains actual fake-boundary process/file identities, argv/environment, requests, state transitions and cleanup, and observes calls reached from the production binary host-context entry point. |
| `Authority/bypass` | Only the validated `pb` handoff, authenticated compiler/Cabal/store, offline serial builds, and run-owned `.build/**` fake files are admitted. Network, package-manager mutation, container/VM/cluster/provider calls, hardware discovery, ambient `PATH`, and external roots are forbidden. |
| `Freshness` | The run root and both fake host roots are unique and absent at acquisition, generated observations are recreated, opening and closing tracked-source identities match, and no prior candidate output can satisfy the new root challenge. |
| `Qualification` | Reject generic-failure selector labeling, wrong-case assertions, failed positive setup, source-token-only caller checks, no-op driver/caller, stale snapshots and forged process observations through their exact acquired qualification cases before accepting the clean corpus. |
| `Cleanroom` | All build directories, fake executables, observations, and mutation products are generated beneath the unique `.build/runs/phase-51/**` owner root; tracked behavioral expectations remain Haskell and no live effect or external residue is admitted. |
| `Legacy closure` | `LTD-HOST-001` closes only when the production caller reaches the probe-first driver and the bypass/stale mutants redden. `LTD-HOST-002` closes only when one resolver serves production and disjoint scoped roots and ambient/foreign-root negatives redden. |
| `Predecessor` | Authenticated `ImmediatePredecessorPass` for Phase 50 in the admitted certification generation, plus the accepted verifier's current compatibility decision under [§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass). Missing, forged, revoked, incompatible, or wrong-phase evidence refuses before any phase effect. Historical source identity remains recorded; reuse requires unchanged relevant dependency and acceptance closures. |
| `Residue` | `UNVERIFIED`: real package-manager privilege and permission fidelity, live Linux/Apple/Windows engine and frame provisioning, containers, VMs, clusters, images, registry, accelerators, and all hardware-bearing behavior remain Phase-52+-owned. |
| `Pass criterion` | `qualified-gate-pass` — all eighteen rows pass for one exact stable source snapshot, both owned legacy IDs close, five changed production subjects are red at their assigned loci, and zero out-of-scope effects or residue are observed. |

## Resource provision

- **Owner marker:** source snapshot, Phase-50 receipt, unique Phase-51 run identity, authenticated toolchain identity, clean/mutant row identity, and fake-host root identity.
- **Preflight:** the unique run root and both fake-host roots must be absent; the acquired tracked-source inventory and predecessor receipt must be exact.
- **Allowed mutation:** create only compiler products, fake executable files, and TSV observations below the owned `.build/runs/phase-51/**` root.
- **Forbidden mutation:** no host package manager, ambient executable search, network, container engine, VM, cluster, provider, registry, device, credential, `.test_data/**`, or path outside the owner root.
- **Observer:** the outer Haskell runner records every child executable, argv, exit, transcript digest, generated path inventory, and two-root resolution result.
- **Cleanup:** generated roots may be retained as evidence; no process or live resource is created, so owned live residue must be exactly zero on every exit path.
- **Residue:** only explicit run-owned `.build/**` evidence may remain; any external path or live effect is a gate failure.

## Doctrine adopted

- [`extension_conformance_doctrine.md` §5 — The conformance gate is generated, not authored](../documents/engineering/extension_conformance_doctrine.md#5-the-conformance-gate-is-generated-not-authored) — the host-ensure kernel is admitted by satisfying the contract, not by appearing on a list.
- [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract):
  probe, install when absent, resolve the absolute path from the package manager, invoke by that path and
  never by a name the OS searches for.
- [`substrate_doctrine.md` §3 — The no-environment / no-`PATH` lazy tool-ensure contract; “The exact boundary of the no-`PATH` rule”](../documents/engineering/substrate_doctrine.md#the-exact-boundary-of-the-no-path-rule):
  only the outermost tool is resolved, and a nested command is the guest's own name against the guest's own
  environment — which is what makes a single fold over a lift context sufficient.
- [`dsl_doctrine.md` §5 — the illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  a state the types cannot express needs no test, and the ensure algebra is where that contract reaches the
  host surface.
- [`testing_doctrine.md` §9 — derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation):
  the substrate cases are enumerated from the type and every expectation is authored in Haskell, so a new constructor
  arrives with a missing expectation rather than with silent coverage.

---

## Sprints

## Sprint 51.1: The closed substrate algebra ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `Amoebius.Host.Substrate` and `Amoebius.Host.Frame` own the wildcard-free closed mappings; `HostEnsureKernelSpec` enumerates every constructor.
**Blocked by**: [Phase 50](phase_50_host_assert_cli.md) gate pass
**Independent Validation**: exact four-substrate frame/engine/provider rows plus compiler exhaustiveness and the foreign-root negative.
**Oracle**: `test/spec/host/HostEnsureKernelOracle.hs`, importing no `Amoebius.*` module.
**Legacy IDs**: `LTD-HOST-001`, `LTD-HOST-002`.
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective

Adopt [`dsl_doctrine.md` §5](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract);
replace the per-site substrate branch with one table that answers frame and engine supply for every catalog
member.

### Deliverables

- A `Frame` sum with three constructors — the native Linux frame, the Lima guest, the WSL2 guest. The package
  manager and the host provider are identical on `linux-cpu` and `linux-cuda`, so a fourth and fifth tag would
  only re-spell an accelerator distinction the ensure surface never reads.
- One total function from `Substrate` to `Frame` and one from `Frame` to the engine it supplies, neither
  carrying a default arm, so an added substrate constructor is a compile error at every site that must answer
  for it.
- Retirement of `supportsLinuxCpu`, which returns `True` for every input and therefore states nothing its own
  type does not already state.
- The accelerator tag confined to the surfaces that read it — capacity and device exposure — and absent from
  the ensure path, since re-spelling the pair at every site is how a new constructor misses a case that reads
  as exhaustive.

### Validation

- For each legal substrate/frame control, require its exact constructed result. An unrelated build or assertion failure under a constructor mutation cannot be accepted as the intended exhaustiveness witness.

1. Every `case` over `Substrate` in the host modules is exhaustive and wildcard-free.
2. Adding a constructor to `Substrate` or `Frame` fails the build at each table obliged to answer for it.

### Remaining Work

Run the complete acquired Phase-51 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 51.2: Install steps as typed data ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `Amoebius.Host.HostTool`, `Amoebius.Host.Ensure`, and `Amoebius.Host.Reconciler` own the closed tool, requirement, resolver, and typed step data.
**Blocked by**: Sprint 51.1
**Independent Validation**: exact 26-row plan plus bare-path and missing-requirement paired refusals.
**Oracle**: `HostEnsureKernelOracle.expectedPlans`.
**Legacy IDs**: `LTD-HOST-001`.
**Docs to update**: `documents/engineering/substrate_doctrine.md`.

### Objective

Adopt [`substrate_doctrine.md` §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract);
make an install step a value the driver executes rather than a label a reader interprets.

### Deliverables

- Observe typed install/tool resolution values through the actual host-context entry point using isolated Haskell fake boundaries, including executable identity and argv rather than source-token presence.

- An `InstallStep` carrying a resolved host tool plus its arguments, replacing `installMechanism :: String`.
  An install step is not a string, it is a tool and an argument vector, and a string is exactly the shape that
  compiles while naming a mechanism no interpreter implements.
- A `Docker` arm on `HostTool`, so the container engine is ensured through the same closed enum as every other
  tool instead of being resolved outside it by a second helper.
- Version and download identity read from the authored requirements rather than embedded in the step, so a pin
  has one home and a bump touches one file.
- One resolver: `Amoebius.Host.Context`'s existence-only discovery helper is deleted in favour of the
  executable-bit resolver, because two predicates over one tool set answer differently on the same host.

### Validation

- Replace the production caller with a no-op while retaining the token `installAndVerify` in a comment or unused function; the behavioral integration case must fail.

1. The step type admits no constructor whose payload is an unparsed string.
2. Every tool a production path invokes is a `HostTool` constructor, joined from the invocation sites to the
   enum in both directions.

### Remaining Work

Run the complete acquired Phase-51 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 51.3: The reconciler table ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `Amoebius.Host.Reconciler` owns the single applicability/diagnostic/step table.
**Blocked by**: Sprint 51.2
**Independent Validation**: Drive an admitted reconciler through the real caller and observe requests; its minimally excluded counterpart refuses at the exact independently authored constructor/diagnostic before effects; assigned applicability mutants fail their exact case; real package-manager fidelity remains unverified.
**Oracle**: `HostEnsureKernelOracle.expectedTable` and `expectedRefusals`.
**Legacy IDs**: `LTD-HOST-001`.
**Docs to update**: `documents/engineering/substrate_doctrine.md`.

### Objective

Adopt [`testing_doctrine.md` §9](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation);
express a reconciler as a row so its three views cannot disagree with each other.

### Deliverables

- One table whose row carries the substrates a reconciler applies to, the phrase a diagnostic uses to describe
  them, and the steps it installs on each. A reconciler is not a module of parallel logic, it is a row.
- A diagnostic rendered from the applicability column rather than authored beside it, because an authored
  phrase drifts from the set it describes the first time that set changes.
- A refusal that fires before any side effect when a reconciler is driven on a substrate its row excludes, so
  a misapplied reconciler costs a message rather than a half-installed host.
- A separately authored Haskell table expectation. Its human-readable rendering is generated lazily beneath
  `.build/**`, so a row change is a reviewable diff without a serialized repository fixture.

### Validation

- Compare the exact expected refusal constructor and payload at each excluded applicability case. A generic failure relabeled with `mutantToken` must fail harness qualification.

1. A reconciler's diagnostic names exactly the substrates its applicability column admits, with no third
   place where either is written.
2. Driving a reconciler on an excluded substrate refuses before any process is created.

### Remaining Work

Run the complete acquired Phase-51 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 51.4: The probe-first ensure driver ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `Amoebius.Host.Ensure.installAndVerify` and `Amoebius.Host.Context.ensureRequiredTools` provide the probe-first driver and production caller.
**Blocked by**: Sprint 51.3
**Independent Validation**: The production host-context entry point observes absent-to-present and a probe-only second pass on independent fake hosts; exhausted/stale/foreign-root pairs fail exactly; assigned driver/caller mutants fail their named assertion; live host behavior remains unverified.
**Oracle**: `HostEnsureKernelOracle.expectedReplay`.
**Legacy IDs**: `LTD-HOST-001`, `LTD-HOST-002`.
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`.

### Objective

Adopt [`substrate_doctrine.md` §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract);
give the driver an installer and a production caller, and make the probe the post-condition as well as the
pre-condition.

### Deliverables

- A Haskell integration harness invokes the real `mkBinaryContext`/host ensure path with acquired fake boundaries and observes the full probe, install, fresh resolution and final verification sequence. Text containing a function name cannot supply this evidence.
- Each error retains its originating action, executable, refusal constructor and exact diagnostic under a case identifier fixed by the independent oracle; the selector does not choose a blanket error label.

- An installer that executes a typed step by absolute path and returns a classified failure, so a failed
  install is distinguishable from a tool that was never attempted.
- A re-resolve after every step, because a tool a step laid down is absent from the config snapshot that step
  began with, and the next step would otherwise report it missing.
- One predicate serving as both pre-probe and post-probe, since a driver that probes one property and verifies
  another reports a convergence nothing established.
- A production caller in the binary's host context, replacing `Cluster/Bootstrap.hs`'s outright refusal of
  `apple` and `windows` with entry into the frame their rows name.

### Validation

- Run a wrong-case assertion failure under each active selector and require qualification to reject it. Also reject controls that fail before their intended driver action.
- Drive two disjoint fake roots through the actual caller and verify externally observed request/state isolation, then repeat the successful root to require fresh probes and zero install requests.

1. A second run issues no install argv, and the recorded argv set is the evidence rather than a return code.
2. A plan exhausted with the requested tool still unresolved fails with that tool named.

### Remaining Work

Run the complete acquired Phase-51 gate; only its exact pass can authorize the mechanical status projection.

## Sprint 51.5: The lift fold to argv ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `Amoebius.Host.Lift` owns the pure context-to-argv fold.
**Blocked by**: Sprint 51.4
**Independent Validation**: exact 15-row argv projection across host, frame, and container plus the frame-prefix changed subject.
**Oracle**: `HostEnsureKernelOracle.expectedLift`.
**Legacy IDs**: `LTD-HOST-002`.
**Docs to update**: `documents/engineering/daemon_topology_doctrine.md`.

### Objective

Adopt [the exact boundary of the no-`PATH` rule](../documents/engineering/substrate_doctrine.md#the-exact-boundary-of-the-no-path-rule);
fold a lift context into argv once, so one step list runs on the host, inside a VM, and inside a container
without a second deployment path.

### Deliverables

- Bind exact lift-fold results to observed outer-tool invocations from the actual caller, preserving each frame’s declared authority and environment.

- A `LiftContext` describing where a step executes, and one pure fold from that context and a step to the argv
  that runs it. Two deployment paths for one step list is how a fix reaches one substrate and not the others.
- Absolute-path resolution applied to the outermost tool only, with a nested command left as the guest's own
  name against the guest's own environment.
- A separately authored Haskell argv expectation per context. Any diff rendering is generated lazily beneath
  `.build/**`, so a fold change is visible without a serialized repository golden.

### Validation

- Pair a correct nested invocation with a wrong prefix or substituted executable and require the exact observed mismatch; printing the assigned mutant token cannot satisfy this check.

1. The three contexts consume one step list and differ only in the prefix the fold emits.
2. The fold creates no process and reads no environment variable, so it is testable as a pure function.

### Remaining Work

Run the complete acquired Phase-51 gate; only its exact pass can authorize the mechanical status projection.

---

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/substrate_doctrine.md` — §3's honesty note records package-manager-canonical
  discovery once the resolver performs it, and the install-and-verify subsection records the typed step and
  the closed frame map.
- `documents/engineering/daemon_topology_doctrine.md` — the composition lift records that one fold serves all
  three contexts.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/system_components.md` — the lazy tool-ensure row leaves PARTIAL once the driver has a
  caller and the mechanism is typed, and the new host modules take their rows.
- `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md` — the reader-facing
  [host-obligation explanations](legacy_tracking_for_deletion.md#4-host-image-and-lift-violations) for the
  uninterpretable mechanism, caller-less driver, thrice-written tool set, and second discovery helper are
  reconciled here only after their typed Haskell closure predicates return zero and the complete gate passes.

---

## Related Documents

- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md)
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Phase 50](phase_50_host_assert_cli.md)
- [Development Plan](README.md)
