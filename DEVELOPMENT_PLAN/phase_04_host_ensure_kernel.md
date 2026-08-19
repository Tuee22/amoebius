# Phase 4: The host-ensure kernel

> **Purpose**: Move every host assertion after the handoff into one closed, substrate-indexed algebra whose
> install steps are typed data, and prove that algebra total.
> **Read this if**: a host tool has to be ensured, a substrate arm has to be added, or a step has to run inside
> a frame rather than on the host.

This phase owns what the binary asserts about its own host: which frame a substrate supplies, which engine
that frame supplies, what each reconciler installs, and how a step is executed. It does not own the
pre-binary floor assertions or the toolchain build, which belong to
[Phase 3](phase_03_host_assert_cli.md), and it does not own the frame's mount contract or the pristine-Linux
provider selection, which
[`substrate_doctrine.md` §4](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux)
fixes and this phase only consumes.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/phase_03_host_assert_cli.md, DEVELOPMENT_PLAN/phase_05_amoebius_image_recipe.md, DEVELOPMENT_PLAN/phase_07_apple_engine_bringup.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 4.1: The closed substrate algebra ✅](#sprint-41-the-closed-substrate-algebra-)
- [Sprint 4.2: Install steps as typed data ✅](#sprint-42-install-steps-as-typed-data-)
- [Sprint 4.3: The reconciler table ✅](#sprint-43-the-reconciler-table-)
- [Sprint 4.4: The probe-first ensure driver ✅](#sprint-44-the-probe-first-ensure-driver-)
- [Sprint 4.5: The lift fold to argv ✅](#sprint-45-the-lift-fold-to-argv-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-19. `python3 tools/host_ensure_kernel_gate.py` passes all twelve sides on
substrate `none`, lane `none`, natural `arm64`, untranslated. The host modules build under
`--ghc-options=-Werror`, and no `case` over `Substrate`, `Frame` or `HostTool` in them carries a default
arm — a property the compiler cannot check, because a wildcard makes an exhaustive-looking match
absorb the next constructor. All four catalogue members' plans join
`test/oracle/host_ensure_plans.tsv` in both directions; the applicability column is the single
statement of each reconciler's set, with the diagnostic rendered from it and compared exactly rather
than by substring; the absent → present → present replay converges on pass one having issued exactly
the five authored install argv, and passes two and three carry probes and no mutation at all; and one
step list folds to fifteen argv across host, frame and container, differing only in the prefix, with
every nested command a guest name. 23 surfaces join to 23 enumerated items and all five seeded
mutants redden their own check and no other. Attestation
`sha256:0c15e7073cd5baf6dfbdf02e9467c4425926989eeb95b9ea6f96ff5b211cb37e` binds source snapshot
`sha256:cd14de88acd08838…` over 2,023 files.

The run found three defects. `dsl-core` needed `Amoebius.Pulumi.Engine` at compile time and never
declared it, so `-Werror=missing-home-modules` refused the build outright — the module is now
declared. The first draft of the wildcard scan keyed on any constructor appearing in a `case` block,
which read `classify`'s case over a `String` as a case over `Substrate` and refused its legitimate
catch-all; it now keys on the arm patterns. And the first draft of the diagnostic check compared by
substring, which passes for a diagnostic naming a *superset* of the set its row admits — exactly the
drift the check exists to catch.

---

## Phase Summary

The binary takes over every assertion the moment [Phase 3](phase_03_host_assert_cli.md) execs it, and the
pressure on this phase is that the takeover happens once, in one place. One table answers which frame a
substrate supplies and which engine that frame supplies. One type describes an install step. One driver
executes a plan, and one fold turns a lift context into the argv that runs a step inside it. A second
spelling of any of the four is the defect this phase exists to make unconstructable.

Making it unconstructable is a typing obligation rather than a testing one. "Install Docker twice on Apple"
and "no Linux frame on Windows" are not conditions a suite catches after the fact — they are values the
algebra never builds. The map from substrate to frame is total, closed, and carries no default arm to absorb
a member nobody considered. A test can only observe the cases someone thought to write down; a total
map without a wildcard refuses to compile when a case goes missing.

What the tree carries today is a declared substrate story with no interpreter behind it.
`installAndVerify` has zero callers, and `pristineLinuxProvider` is consumed only by two specs.
`Cluster/Bootstrap.hs` refuses `apple` and `windows` outright rather than entering their frames; `HostTool`
has five constructors and no Docker arm; and `installMechanism :: String` in `src/Amoebius/Host/Ensure.hs`
holds values like `brew-install:ghcup` that nothing parses and nothing executes. The plan is pure and
uninterpretable at the same time, and that pairing is what this phase closes.

**Phase scope:** one cohesive claim — *every post-handoff host assertion resolves through one closed,
substrate-indexed algebra whose install steps are typed data*. Its sprint seams are the algebra, the step
type, the reconciler table, the driver, and the lift fold. It splits if a second acceptance register or a
second substrate appears.

**Substrate:** `none` — the algebra is replayed against a committed fake tool directory, not a host ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** none ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 2 — boundary-with-fakes: the claim is about tool resolution and emitted argv, not about a value ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on**: [Phase 3](phase_03_host_assert_cli.md)

**Requires**: `host-floor`

**Gate:** `python3 tools/host_ensure_kernel_gate.py` passes every check named in
[Gate integrity](#gate-integrity). Phase 5 does not open until it is green.

---

## Gate integrity

`python3 tools/host_ensure_kernel_gate.py` settles four questions, none of which needs a machine to answer
because every one of them is a question about a value.

**The rendered plan is compared against an independent oracle, not against itself.** The gate renders the
ensure plan for all four catalog members — `linux-cpu`, `linux-cuda`, `apple`, `windows`. Each rendering
joins against `test/oracle/host_ensure_plans.tsv`, a table authored from the doctrine rather than dumped from
the implementation. The join runs in both directions, so a step the oracle does not name and an oracle
row no plan emits are both failures. A golden captured from the code under test proves only that the code is
deterministic.

**Resolution is exercised against a committed fixture, by absolute path.**
`test/fixture/host_ensure_kernel/` holds a fake tool directory whose entries are stubs that record the argv
they were invoked with. Every step resolves into that directory and is invoked by the path the resolver
returned, so a bare name reaching the process layer appears in the recorded argv rather than being inferred
from the source.

**Idempotence is replayed, not asserted.** Each plan is driven absent → present → present against the
fixture. The first pass must converge, the second must issue no install argv at all, and the post-probe must
be the predicate the pre-probe used — a driver that probes one property and verifies another reports a
convergence it never reached.

**Totality is structural.** `cabal build --ghc-options=-Werror` fails the gate on any incomplete pattern
match over `Substrate`, `Frame`, or `HostTool`, and the gate separately refuses a wildcard arm in any `case`
over those types inside the host modules. A wildcard makes an exhaustive-looking match silently absorb the
next constructor, which is the failure the compiler otherwise catches for free.

**Five mutants sit in `test/mutant/registry.tsv`**, and the battery is only meaningful if each reddens a
different check:

- A Docker install step added to the Apple reconciler row — reddens the oracle join, because the Apple row's
  engine is already supplied inside the frame and the oracle names it exactly once.
- A reconciler row whose applicability column and diagnostic disagree — reddens the single-table join, since
  the diagnostic is derived from the applicability column rather than authored beside it.
- A driver that omits the re-resolve between steps — reddens the fixture replay, because the step after an
  install reads the pre-install snapshot and reports its tool missing.
- A driver that reports converged without re-probing — reddens the absent → present → present replay at the
  post-condition, where the second pass observes an unverified claim.
- A lift fold that drops the frame prefix — reddens the recorded argv, which then names the host tool at the
  position the guest command occupies.

---

## Doctrine adopted

- [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract):
  probe, install when absent, resolve the absolute path from the package manager, invoke by that path and
  never by a name the OS searches for.
- [`substrate_doctrine.md` — the exact boundary of the no-`PATH` rule](../documents/engineering/substrate_doctrine.md#the-exact-boundary-of-the-no-path-rule):
  only the outermost tool is resolved, and a nested command is the guest's own name against the guest's own
  environment — which is what makes a single fold over a lift context sufficient.
- [`dsl_doctrine.md` §5 — the illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  a state the types cannot express needs no test, and the ensure algebra is where that contract reaches the
  host surface.
- [`testing_doctrine.md` §9 — derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation):
  the substrate cases are enumerated from the type and every expectation is authored, so a new constructor
  arrives with a missing expectation rather than with silent coverage.

---

## Sprints

## Sprint 4.1: The closed substrate algebra ✅

**Status**: Done
**Implementation**: `src/Amoebius/Host/Frame.hs`, `src/Amoebius/Host/Substrate.hs`
**Blocked by**: none within the phase
**Requires**: `host-floor`
**Independent Validation**: the frame and engine maps are total over `Substrate` with no wildcard arm, proved by `-Wincomplete-patterns` under `-Werror`
**Docs to update**: `documents/engineering/substrate_doctrine.md`

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

1. Every `case` over `Substrate` in the host modules is exhaustive and wildcard-free.
2. Adding a constructor to `Substrate` or `Frame` fails the build at each table obliged to answer for it.

### Remaining Work

None.

## Sprint 4.2: Install steps as typed data ✅

**Status**: Done
**Implementation**: `src/Amoebius/Host/HostTool.hs`, `src/Amoebius/Host/Ensure.hs`
**Blocked by**: Sprint 4.1
**Independent Validation**: no install step carries a free-form string, and every step renders to an argv whose head is a resolved `AbsExe`
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`

### Objective

Adopt [`substrate_doctrine.md` §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract);
make an install step a value the driver executes rather than a label a reader interprets.

### Deliverables

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

1. The step type admits no constructor whose payload is an unparsed string.
2. Every tool a production path invokes is a `HostTool` constructor, joined from the invocation sites to the
   enum in both directions.

### Remaining Work

None.

## Sprint 4.3: The reconciler table ✅

**Status**: Done
**Implementation**: `src/Amoebius/Host/Reconciler.hs`, `test/fixture/host_ensure_kernel/`
**Blocked by**: Sprint 4.2
**Independent Validation**: applicability, diagnostic, and install plan for every reconciler derive from one row, and a second declaration of any of the three is refused
**Docs to update**: `documents/engineering/substrate_doctrine.md`

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
- A golden rendering of the whole table under `test/fixture/host_ensure_kernel/`, so a row change is a
  reviewable diff rather than a behavioural surprise at run time.

### Validation

1. A reconciler's diagnostic names exactly the substrates its applicability column admits, with no third
   place where either is written.
2. Driving a reconciler on an excluded substrate refuses before any process is created.

### Remaining Work

None.

## Sprint 4.4: The probe-first ensure driver ✅

**Status**: Done
**Implementation**: `src/Amoebius/Host/Ensure.hs`, `src/Amoebius/Host/Context.hs`
**Blocked by**: Sprint 4.3
**Independent Validation**: the absent → present → present replay against the committed fake tool directory converges once and issues no install argv thereafter
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`

### Objective

Adopt [`substrate_doctrine.md` §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract);
give the driver an installer and a production caller, and make the probe the post-condition as well as the
pre-condition.

### Deliverables

- An installer that executes a typed step by absolute path and returns a classified failure, so a failed
  install is distinguishable from a tool that was never attempted.
- A re-resolve after every step, because a tool a step laid down is absent from the config snapshot that step
  began with, and the next step would otherwise report it missing.
- One predicate serving as both pre-probe and post-probe, since a driver that probes one property and verifies
  another reports a convergence nothing established.
- A production caller in the binary's host context, replacing `Cluster/Bootstrap.hs`'s outright refusal of
  `apple` and `windows` with entry into the frame their rows name.

### Validation

1. A second run issues no install argv, and the recorded argv set is the evidence rather than a return code.
2. A plan exhausted with the requested tool still unresolved fails with that tool named.

### Remaining Work

None.

## Sprint 4.5: The lift fold to argv ✅

**Status**: Done
**Implementation**: `src/Amoebius/Host/Lift.hs`, `test/spec/host/HostEnsureKernelSpec.hs`
**Blocked by**: Sprint 4.4
**Independent Validation**: one fold produces host, VM, and container argv from a single step list, each compared against the authored oracle
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `documents/engineering/daemon_topology_doctrine.md`

### Objective

Adopt [the exact boundary of the no-`PATH` rule](../documents/engineering/substrate_doctrine.md#the-exact-boundary-of-the-no-path-rule);
fold a lift context into argv once, so one step list runs on the host, inside a VM, and inside a container
without a second deployment path.

### Deliverables

- A `LiftContext` describing where a step executes, and one pure fold from that context and a step to the argv
  that runs it. Two deployment paths for one step list is how a fix reaches one substrate and not the others.
- Absolute-path resolution applied to the outermost tool only, with a nested command left as the guest's own
  name against the guest's own environment.
- A golden argv set per context, so a change to the fold surfaces as a diff rather than as a runtime
  difference observed on one substrate.

### Validation

1. The three contexts consume one step list and differ only in the prefix the fold emits.
2. The fold creates no process and reads no environment variable, so it is testable as a pure function.

### Remaining Work

None.

---

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/substrate_doctrine.md` — §3's honesty note records package-manager-canonical
  discovery once the resolver performs it, and the install-and-verify subsection records the typed step and
  the closed frame map.
- `documents/engineering/daemon_topology_doctrine.md` — the composition lift records that one fold serves all
  three contexts.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/system_components.md` — the lazy tool-ensure row leaves PARTIAL once the driver has a
  caller and the mechanism is typed, and the new host modules take their rows.
- `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md` — the
  [host-ensure amendment](legacy_tracking_for_deletion.md#host-ensure-amendment--2026-08-17) rows naming the
  uninterpretable mechanism, the caller-less driver, the thrice-written tool set, and the second discovery
  helper close here.

---

## Related Documents
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md)
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Phase 3](phase_03_host_assert_cli.md)
- [Development Plan](README.md)
