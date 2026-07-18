# Phase 11: Boundary-integration fake-tool harness

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_chain_kernel_dryrun.md, DEVELOPMENT_PLAN/phase_12_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_13_spa_composition_representational.md, DEVELOPMENT_PLAN/phase_16_renderer_reconciler.md, documents/engineering/deterministic_simulation_doctrine.md
**Generated sections**: none

> **Purpose**: Run the real amoebius binary over the pure `[Step]` plan against fake `kubectl`/`docker`/`pulumi`
> (with a `helm` fake present only as a zero-invocations negative control) that record their argv and
> applied-manifest bytes, asserting the exact commands and bytes byte-for-byte — the Register-2 boundary that
> closes the pre-cluster conformance spine without ever standing up a cluster.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 10 gate (the `chain`/`Step`
kernel + `--dry-run` plan render) and runs on **no substrate** (`none`) in **Register 2** — the boundary
register, exercised in-process plus a handful of controlled fake tool binaries, with no apiserver, no broker,
no cloud, and no Vault. It is the boundary register (Register 2) of the pre-cluster conformance harness
([`conformance_harness_doctrine.md §2`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation):
the harness is Registers 1, 2, and 2.5; the Register-2.5 deterministic-simulation substrate is built and gated
separately in [Phase 12](phase_12_deterministic_sim_substrate.md); Register 3 is the acceptance gate of each
*live* phase). Where a shape below is already
exercised in a sibling system — prodbox validating its behaviour through a single thin IO seam with subprocess
fakes in a dedicated boundary suite, `typed-process`, and byte-for-byte dry-run goldens — that is **sibling
evidence, not an amoebius result**.

## Phase Summary

This phase delivers the boundary-integration register: the single, thin IO seam through which the amoebius
binary invokes every external tool, the four fake tool recorders (`kubectl`, `helm`, `docker`, `pulumi`) that
capture argv and applied-manifest bytes and return canned success, and the `boundary-spec` test-suite that
drives the *real* binary over the Phase-10 `[Step]` plan against those fakes and asserts the exact command
stream and applied bytes. Nothing here contacts live infrastructure: the plan and the manifest bytes the fakes
receive are the same pure rendered value Register 1 already golden-locked, so the applied bytes a fake records
are byte-for-byte what a live apply would submit — the identity owned by
[`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md). The mocking
posture is strict: mocking happens **only** at the subprocess boundary; the planning and rendering code under
test stays pure and untouched. The harness also proves the cross-cutting no-`PATH` invariant at the boundary —
the binary invokes each fake by the exact absolute path it was handed and never resolves a tool against the
host's `PATH`. What is *not* here: the live SSA reconciler and the real tool invocations against a real cluster
(Phase 16), and the runtime-enforcement claim that the cluster admits what the fakes accepted (Phase 22) — the
Tier-2 residue this register leaves UNVERIFIED by construction.

**Substrate:** none — no host, no cluster; the gate is an in-process `cabal test boundary-spec` battery driving
the real binary against fake tool binaries in a controlled directory, analogous to the Phase-9/10 goldens it
consumes.

**Register:** 2 — boundary integration with fake tools, no cluster (§K).

**Gate:** `cabal test boundary-spec` is green — the real amoebius binary runs the **representative plan corpus**
(Sprint 11.3, §M-7: a committed `[Step]` plan containing **at least one step for each tool amoebius actually
invokes** — `kubectl`, `docker`, `pulumi` — over the Phase-10 fixtures, while the `helm` fake is a **negative
control that must record zero invocations** (amoebius renders and applies its own typed manifests and never
shells to Helm)) against the fakes invoked by absolute path; the recorded
argv sequence equals the **committed, hand-authored expected-argv transcript** (`test/boundary/golden/argv/`,
Phase-0-pinned per §M-1/§M-3 — authored independently of the executor, no function reachable from the executor
computes it) and the recorded applied-manifest bytes equal the Phase-9/10 `renderAll`/plan goldens byte-for-byte, and
**each of the four tool transcripts is non-empty** (a zero-invocation transcript for any named tool is red).
The gate is not passed by assertion logic alone: it names **committed seeded mutants** (§M-2) that MUST turn the
suite red — an executor argv mutant (drop a flag / reorder argv / swap a subcommand) and a byte mutant (one
flipped manifest byte) — re-run each gate run, not once. The no-`PATH` invariant is proven by an **OS-boundary
observer** (§M-5): the fakes' parent directory is removed from `PATH` and a hostile **decoy directory** holding
same-named sabotage executables is placed **first** on `PATH`; the run is red if any decoy sabotage-marker
appears (a `PATH` lookup would have executed the decoy, not the handed absolute path). A **Register-2** boundary
check that runs on no substrate.

## Doctrine adopted

- [`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing)
  — **Register 2, boundary integration with fakes**: the register this phase's gate reaches. This phase adopts
  its cardinal mocking posture verbatim — *pure code never touches a mock; all mocking happens at the subprocess
  or interpreter boundary* — so the fakes live in a dedicated boundary suite and the planning/rendering code
  stays pure. The prodbox interpreter-only-mocking lineage the register generalizes is **sibling evidence, not
  an amoebius result**.
- [`conformance_harness_doctrine.md §2`](../documents/engineering/conformance_harness_doctrine.md) — the
  registers as amoebius uses them for pre-cluster validation (§2, **Register 2 — boundary integration with
  fakes, no cluster**): the real binary run with fake `helm`/`kubectl`/`docker`/`pulumi` that record their argv
  and applied bytes, asserting the exact commands and manifests. This phase builds precisely that recorder.
- [`conformance_harness_doctrine.md §3`](../documents/engineering/conformance_harness_doctrine.md) — the
  load-bearing invariant (§3), *rendering a plan MUST NOT require, contact, or depend on live infrastructure*:
  the plan and manifest bytes the fakes receive were rendered in Register 1 with no cluster, and the fake-apply
  adds no infrastructure dependency. Prerequisite checks (a cluster is reachable, credentials are present) belong
  on the live *apply* path (Phase 16), never here.
- [`conformance_harness_doctrine.md §4`](../documents/engineering/conformance_harness_doctrine.md) — the spine
  (§4), *decode → bind/expand → `planInfrastructure` → (infrastructure-plan golden | authenticated-
  materialization fixture → provision → `renderAll`) → plan → dry-run → fake apply*: this phase implements the
  **fake
  apply** — the binary runs the plan against fake tools and the recorded commands and applied bytes are asserted
  — closing the pre-cluster spine that Phases 4–10 built in Register 1.
- [`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
  — the per-run proven/tested/assumed ledger (§4): the Register-2 gate emits one, led by a Tier-2-UNVERIFIED
  banner. Fail-fast, no skips — a missing fake or a missing golden fails with an actionable error, never a
  pass-with-a-skip. Per [`conformance_harness_doctrine.md §5`](../documents/engineering/conformance_harness_doctrine.md)
  (honesty), a green boundary run is quoted as *"the binary emits the exact commands and applied bytes,"* never
  as *"the cluster is correct."*

## Sprints

## Sprint 11.1: The single typed subprocess seam + `boundary-spec` skeleton 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Exec/Tool.hs` (the one `typed-process` seam that invokes a tool by absolute
path over the `[Step]`/effect data), a `boundary-spec` test-suite stanza in `amoebius.cabal`, and an empty
`test/boundary/` tree — target paths, not yet built.
**Blocked by**: Phase 10 gate (the `chain :: cfg -> [Step]` plan + its `--dry-run` render — the plan this
harness executes); Phase 5's real `amoebius` cabal package + `dsl-spec` skeleton; Phase 1's recorded
`typed-process` pin under GHC 9.12.4.
**Independent Validation**: `cabal build` and `cabal test boundary-spec` (zero tests) succeed on the pinned
toolchain; a source gate confirms `Exec/Tool.hs` is the **sole** subprocess-invocation site. The gate's scope is
all of `src/`; it is red if any subprocess-spawning primitive appears outside `Exec/Tool.hs` — the enumerated
token set (the one interpretation, closing the "sole site" vs. literal-token divergence) is: `System.Process`
(`createProcess`/`readProcess`/`callProcess`/`spawnProcess`/`readCreateProcess`/`callCommand`), `typed-process`
(`runProcess`/`readProcess`/`startProcess`/`withProcessWait`), `System.Posix.Process`
(`executeFile`/`forkProcess`/`createSession`), and any raw FFI `c_exec*`/`system` import. The gate is red if the
enumerated set is empty (no primitive was searched for), guarding against a vacuous scope.
**Docs to update**: `DEVELOPMENT_PLAN/system_components.md` (register the exec seam + `boundary-spec` suite),
this document.

### Objective
Adopt [`conformance_harness_doctrine.md §2`](../documents/engineering/conformance_harness_doctrine.md) and
[`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing):
stand up the **single thin IO seam** through which every external tool invocation flows, so the boundary suite
can substitute fakes at exactly one substitutable point while the planning/rendering code stays pure — the
prodbox single-IO-seam shape as *sibling evidence, not an amoebius result*.

### Deliverables
- `src/Amoebius/Exec/Tool.hs`: the `typed-process` seam that runs a resolved tool **by absolute path** (never a
  `PATH` lookup), threading argv and stdin bytes from the `[Step]`/effect data and returning exit + captured
  streams.
- The `boundary-spec` test-suite stanza and an empty `test/boundary/` tree wired to the seam.

### Validation
1. `cabal build` and the zero-test `boundary-spec` suite are green on the Phase-1 pin; the source gate reports
   the seam is the only subprocess call site.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 11.2: The fake `kubectl`/`helm`/`docker`/`pulumi` recorders 📋

**Status**: Planned
**Implementation**: `test/boundary/fakes/{kubectl,helm,docker,pulumi}` (the four fake executables that append
argv + stdin bytes to a transcript and exit with a canned response) and `test/boundary/Fakes.hs` (the transcript
ADT + the canned-response table) — target paths, not yet built.
**Blocked by**: Sprint 11.1.
**Independent Validation**: each fake, invoked directly, appends its full argv (in order) and its complete stdin
bytes to the run transcript and returns its canned exit; a unit check proves the transcript captures argv order
and applied-manifest bytes **losslessly** (round-trips the recorded bytes with no re-encoding).
**Docs to update**: `documents/engineering/testing_doctrine.md` (the Register-2 fake-tool recorder shape),
`documents/engineering/conformance_harness_doctrine.md` (the §2/§4 fake-apply recorder), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`conformance_harness_doctrine.md §2/§4`](../documents/engineering/conformance_harness_doctrine.md): build
the four **subprocess-boundary fixtures** — fake tools that record argv and applied bytes and return canned
success — that stand in for the real `kubectl`/`helm`/`docker`/`pulumi`. These are *fixtures*: they fake a
boundary and are reusable, and (per the testing doctrine) a fixture never silences a missing real-substrate
prerequisite — that distinction is what keeps Register 2 honestly separate from Register 3.

### Deliverables
- Four fake tool executables that transcribe argv + stdin (the applied-manifest bytes) and return a canned exit,
  placed at controlled absolute paths for the seam to invoke.
- `test/boundary/Fakes.hs`: the transcript ADT (an ordered command/argv/bytes log) and the canned-response
  table, with a lossless round-trip check over recorded bytes.

### Validation
1. Each fake transcribes argv order and applied-manifest bytes losslessly and returns its canned exit; the
   round-trip check is red if any byte or argv element is dropped or re-encoded.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 11.3: The boundary battery — exact commands + applied bytes + no-`PATH` — the gate 📋

**Status**: Planned
**Implementation**: `test/boundary/BoundarySpec.hs`; the applied-manifest bytes reuse the Phase-9 `renderAll`
goldens; the **expected-argv transcripts are a separate committed hand-authored oracle** (`test/boundary/golden/argv/`),
NOT derived from the Phase-10 plan golden by any executor-reachable function — target paths, not yet built.
**Blocked by**: Sprint 11.2, Sprint 11.1; Phase 10 gate (the `[Step]` plan + `--dry-run` goldens); Phase 9 gate
(the `renderAll` manifest goldens — the applied bytes asserted here).
**Representative plan corpus (§M-7):** the exercised plan is named explicitly here — a committed `[Step]` fixture
containing **at least one step routed to each tool amoebius actually invokes** (`kubectl` apply, `docker`
build/push, `pulumi` up), so every real boundary surface is driven, not just `kubectl`; the `helm` fake is
present only as a **negative control asserted to record zero invocations** (amoebius never shells to Helm).
**Independent Validation**: `cabal test boundary-spec` is green — the real binary runs the representative corpus
against the fakes; the recorded argv sequence equals the **committed hand-authored expected-argv transcript**
(§M-3: authored at fixture-authoring time from the spec, never by the executor's own `Step→argv` fold or any
function reachable from it — a source gate rejects any import of executor argv-building code into the oracle);
the recorded applied-manifest bytes equal the Phase-9/10 goldens byte-for-byte; **each of the four tool
transcripts is asserted non-empty** (§M-7 — a tool the binary never routed through leaves an empty transcript
and the suite is red, foreclosing a `kubectl`-only executor). The no-`PATH` invariant is detected by the
**hostile decoy-`PATH` arrangement** (the one interpretation, §M-5, resolving the detection-mechanism
ambiguity): the run executes with the fakes' directory absent from `PATH` and a decoy directory containing
same-named executables that write a distinct sabotage-marker placed first on `PATH`; the suite is red if any
sabotage-marker is observed (proving `PATH` was consulted) or if any fake's transcript argv[0] differs from the
handed absolute path. **Committed seeded mutants (§M-2), re-run every gate run, that MUST turn the suite red**:
(a) an executor argv mutant — drop a flag / reorder two argv elements / swap a subcommand; (b) a byte mutant —
one flipped byte in a `renderAll` golden; (c) a `PATH`-resolution mutant — the seam resolving by bare tool name.
The suite failing on each is a demonstrated negative control, not merely assertion logic.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (flip the Phase-11 status when the gate passes),
`documents/engineering/testing_doctrine.md`, `documents/engineering/conformance_harness_doctrine.md`.

### Objective
Adopt [`testing_doctrine.md §2 — Register 2`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing),
[`conformance_harness_doctrine.md §4`](../documents/engineering/conformance_harness_doctrine.md) (the fake-apply
step), [`§5`](../documents/engineering/conformance_harness_doctrine.md) (honesty), and
[`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
(the per-run ledger): drive the real amoebius binary over the Phase-10 plan against the fakes and assert the
exact commands and applied bytes, and prove at the boundary that every tool was invoked by absolute path
(the cross-cutting no-`PATH` invariant, [README.md](README.md)) — then emit a Register-2
proven/tested/assumed ledger led by a Tier-2-UNVERIFIED banner (no cluster admitted anything; runtime
enforcement is owned by [Phase 22](phase_22_live_dsl_singleton.md)).

### Deliverables
- The committed **representative plan corpus** — a `[Step]` fixture with at least one step per tool — and the
  committed **hand-authored expected-argv transcripts** (`test/boundary/golden/argv/`, Phase-0-pinned per §M-1,
  authored independently of the executor per §M-3).
- The committed **seeded mutants** named in the Gate (argv mutant, byte mutant, `PATH`-resolution mutant) with a
  harness that re-runs each and asserts `boundary-spec` red (§M-2).
- `test/boundary/BoundarySpec.hs` asserting: the recorded argv stream equals the committed hand-authored
  expected-argv transcript; the applied-manifest bytes equal the Phase-9/10 goldens byte-for-byte (the same
  rendered value the `--dry-run` previews, per
  [`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md)); each of the
  four tool transcripts is non-empty; and each fake was invoked by its exact absolute path under the hostile
  decoy-`PATH` arrangement with no decoy sabotage-marker observed.
- A Register-2 ledger led by a Tier-2-UNVERIFIED banner: the binary emits the exact commands and applied bytes,
  but no runtime-enforcement claim is made — a skipped-but-applicable Runtime move stays UNVERIFIED, never green.

### Validation
1. `cabal test boundary-spec` is green — commands match the committed hand-authored argv transcript, applied
   bytes match the Phase-9/10 goldens exactly, all four tool transcripts are non-empty, and invocation is by
   absolute path under the hostile decoy-`PATH` arrangement.
2. Demonstrated negative controls (§M-2): each committed seeded mutant — argv mutant, byte mutant,
   `PATH`-resolution mutant — is re-run and turns `boundary-spec` red. A green run against any mutant fails the
   gate.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/conformance_harness_doctrine.md` — backlink §2/§4's fake-apply step to the in-process
  Phase-11 boundary harness; keep Register 3 (live apply) as the residue owned by the live band.
- `documents/engineering/testing_doctrine.md` — record the Register-2 fake-tool recorder and the per-run ledger
  variant this gate emits (Tier-2 runtime/correspondence UNVERIFIED).
- `documents/engineering/generated_artifacts_doctrine.md` — annotate that the applied bytes the fakes capture are
  byte-for-byte the same rendered value as the `--dry-run` preview (both consume the one rendered source).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-11 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-11 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Exec/Tool.hs`, `test/boundary/`
  (the fakes + `Fakes.hs` + `BoundarySpec.hs`), and the `boundary-spec` test-suite as Phase-11 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the pre-cluster conformance vision
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 the three registers (Register 2 adopted
  here), §4 the per-run proven/tested/assumed ledger
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — §2 the registers for
  pre-cluster validation, §3 the load-bearing invariant, §4 the spine (fake-apply + simulate steps), §5 the honesty limit
- [phase_12](phase_12_deterministic_sim_substrate.md) — the deterministic-simulation substrate (the `io-classes` environment + the modeled fault-injectable Pulsar/MinIO/apiserver/route53/Vault/clock) that this boundary harness unblocks and that the live-band phases extend
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — why the applied
  bytes equal the `--dry-run` bytes and are never committed
- [phase_09](phase_09_render_manifest_goldens.md) — the `renderAll` manifest goldens = the applied bytes asserted here
- [phase_10](phase_10_chain_kernel_dryrun.md) — the `chain`/`Step` kernel + `--dry-run` plan this harness executes
- [phase_13](phase_13_spa_composition_representational.md) — the companion Register-1/2 phase (the demo SPA run
  locally against a faked backend)
- [phase_16](phase_16_renderer_reconciler.md) — the live SSA reconciler that replaces the fakes with real tools
- [phase_22](phase_22_live_dsl_singleton.md) — the Tier-2 runtime-enforcement half this register leaves UNVERIFIED
