# Phase 10: chain/Step kernel + `--dry-run` plan render

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Seed the pure chain/Step reconcile kernel and its `--dry-run` plan render — `chain :: cfg ->
> [Step]` as a pure value whose byte-for-byte preview is produced with no effects and whose descent
> (`nextFrameAfter`/`foldLift`) is golden-locked — in-process, before any cluster or effectful interpreter exists.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 9 gate (the pure `render ::
ServiceSpec -> [K8sObject]` and its rendered-output goldens) and runs on **no substrate** (`none`) in
**Register 1** — it stands up no host, no cluster, and no effectful interpreter, only an in-process plan-render
battery. Where a shape below is already exercised in a sibling system (hostbootstrap's `Step`/`Chain` algebra,
its `renderChainPlan`, its `foldLift`, and its `runChainFromFrame` descent), that is **sibling evidence, not an
amoebius result**.

## Phase Summary

This phase seeds, from hostbootstrap, the pure reconcile kernel every later apply rides on — and proves that
its plan is *data*. It delivers the `Step` algebra (a label, the frame it runs in, a `StepKind`, and an
effectful `stepRun` action that is *declared but never invoked here*), the `chain :: cfg -> [Step]` builder
that turns a decoded config into a pure list of steps, the pure descent (`nextFrameAfter`/`foldLift`) that
computes which steps belong to which frame without running a single action, and the `renderChainPlan` /
`--dry-run` renderer that emits the exact plan a live apply would execute. The load-bearing claim is
[conformance_harness_doctrine §3](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)'s
invariant: **rendering a plan never touches live infrastructure** — the render path is a pure function of
committed source and completes with no apiserver, no credentials, no broker, no Vault. Because `[Step]` is a
pure value, the `--dry-run` preview is byte-for-byte what a live apply would submit; both consume the same
rendered value. What is *not* here: the effectful interpreter's *invocation* against real or fake tools (the
one thin IO seam, `runChainFromFrame`), which Register 2 exercises against fakes in
[Phase 11](phase_11_boundary_fake_tool_harness.md) and Register 3 exercises against the live Deployment
`replicas=1` singleton in [Phase 20](phase_20_live_dsl_singleton.md) — there is **no election, no standby, and
no singleton runtime** in this phase, only the pure kernel and its no-effect render.

**Substrate:** none — no host, no cluster, no effectful interpreter; the gate is an in-process `cabal test`
plan-render battery analogous to the Phase-9 rendered-output goldens.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** `chain :: cfg -> [Step]` renders a byte-for-byte `--dry-run` plan with no effects and the pure
descent is golden-locked — concretely, `cabal test chain-spec` is green: `chain` produces a pure plan value
whose `--dry-run` render is pinned byte-for-byte against a golden and is produced with **zero** `stepRun`
invocations, the pure descent (`nextFrameAfter`/`foldLift`) is golden-locked, and the whole render path
completes in-process with no apiserver, credentials, broker, or Vault — a **Register-1** check that runs on no
substrate.

## Doctrine adopted

- [`dsl_doctrine.md §2 — two languages, one system: Dhall carries params, Haskell carries logic`](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic):
  the **chain/Step algebra** and its load-bearing consequence, *"the plan is the data."* A project's deploy is
  a pure function `chain :: cfg -> [Step]`; each `Step` is *"the pure renderable shape plus the effectful
  reconcile action"*; because `[Step]` is a pure value, `--dry-run` renders the exact plan it would execute
  (`renderChainPlan` / `renderChain`) *without running a single action*, and `runChainFromFrame` is *"the thin
  effectful seam"* — declared here but exercised only from Register 2 onward.
- [`conformance_harness_doctrine.md §3 — rendering never touches live infrastructure`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure):
  the load-bearing invariant this phase discharges for the plan — a render is a pure function of committed
  source, the `--dry-run` preview is byte-for-byte what a live apply would submit, and prerequisite checks (is
  a cluster reachable, are credentials present) belong on the *apply* path, never the *render* path.
- [`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md) §2 (Register 1
  — pure/golden, in-process) and §4 (the spine's **Plan** step — *"`chain` produces the `[Step]` value;
  `--dry-run` renders it; a golden test pins the plan"*): this phase is exactly that spine step, golden-locked,
  with the single IO seam deferred to Register 3.
- [`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md): the rendered
  plan is emitted from the Haskell source of truth and **never committed** — the `--dry-run` preview is a golden
  fixture of the renderer, not a committed runtime artifact.
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) §2 (**Register 1**, the register this
  gate reaches) and §4 (the per-run proven/tested/assumed ledger the battery emits, marking model↔runtime
  correspondence and runtime fidelity UNVERIFIED, owned by Phases 11/20).

## Sprints

## Sprint 10.1: The `Step` algebra + `chain :: cfg -> [Step]` builder 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Kernel/Step.hs` (the `Step` type, `StepKind`, and the `stepRun` action
field), `src/Amoebius/Kernel/Chain.hs` (the `chain :: cfg -> [Step]` builder) — target paths, not yet built.
**Blocked by**: Phase 9 gate (the pure `render :: ServiceSpec -> [K8sObject]` a step's renderable shape
embeds); Phase 5 (the decoded `cfg` = `ClusterIR` / `FrameConfig` the chain consumes).
**Independent Validation**: `chain` of a decoded fixture `cfg` evaluates to a pure `[Step]` value whose shape
(label, frame, `StepKind`, embedded rendered objects) is inspectable with no `stepRun` forced — a
`-Wall`-clean, partiality-free evaluation.
**Docs to update**: `documents/engineering/dsl_doctrine.md` (§2 chain/Step-kernel status backlink),
`DEVELOPMENT_PLAN/system_components.md` (register the `Amoebius.Kernel.*` modules).

### Objective
Adopt [`dsl_doctrine.md §2 — Dhall carries params, Haskell carries logic`](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic):
seed hostbootstrap's chain/Step algebra as the amoebius reconcile kernel — `chain :: cfg -> [Step]`, each
`Step` being a pure renderable shape (label, frame, `StepKind`, the `[K8sObject]` it would apply) plus an
effectful `stepRun` action — with the chain being the system and the decoded config merely supplying `cfg`.

### Deliverables
- A `Step` type = label + frame + `StepKind` + `stepRun :: cfg -> IO ()`, and a `chain :: cfg -> [Step]`
  builder, **both pure values**; the `stepRun` field is carried but never invoked in this phase.
- Each `Step`'s renderable shape embeds the Phase-9 `render` output for the objects it would apply, so the plan
  is derivable from the step value alone.

### Validation
1. `chain` of a decoded fixture `cfg` produces a pure `[Step]` whose renderable shape is fully inspectable
   without forcing any `stepRun`; the evaluation is partiality-free.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 10.2: The pure descent — `nextFrameAfter` / `foldLift` (golden-locked) 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Kernel/Descent.hs` (`nextFrameAfter`, `foldLift`), plus the *declaration
only* of the effectful seam `runChainFromFrame` in `src/Amoebius/Kernel/Chain.hs` — target paths, not yet
built.
**Blocked by**: Sprint 10.1.
**Independent Validation**: `nextFrameAfter` and `foldLift` are pure functions with no `IO` in their type; a
descent over a fixture chain reproduces a golden frame/step assignment, and an out-of-frame step is folded
into the plan but its `stepRun` is provably never reached.
**Docs to update**: `documents/engineering/dsl_doctrine.md` (§2 descent/seam status backlink),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`dsl_doctrine.md §2`](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic)'s
recursive-descent claim: the interpreter *"runs a step's action only when the binary is in that step's
frame; the descent logic itself is pure and unit-tested, and `runChainFromFrame` is the thin effectful
seam."* This phase builds and golden-locks the **pure** half — `nextFrameAfter` (which frame follows a step)
and `foldLift` (folding the chain into the lift/plan structure) — and only *declares* the effectful seam,
whose invocation is deferred to Registers 2–3.

### Deliverables
- Pure `nextFrameAfter :: Frame -> [Step] -> Maybe Frame` and `foldLift :: cfg -> [Step] -> Plan`, neither
  carrying `IO`, computing the frame/step assignment and the fold-derived plan with no action run.
- The effectful `runChainFromFrame` **declared** as the single IO seam, with an in-file honesty note that its
  *invocation* is out of scope here — Register 2 exercises it against fake tools (Phase 11) and Register 3
  against the live Deployment-`replicas=1` singleton (Phase 20); there is no election or standby anywhere in
  the kernel.

### Validation
1. A descent over a fixture chain reproduces a golden frame/step assignment; an out-of-frame step appears in
   the fold but its `stepRun` is unreachable (a purity/partiality check confirms no action forced).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 10.3: `renderChainPlan` / `--dry-run` byte-for-byte render (no live infra) 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Kernel/Plan.hs` (`renderChainPlan` / `renderChain`), `src/Amoebius/Cli.hs`
(the `--dry-run` **render** path, kept structurally separate from any apply path) — target paths, not yet
built.
**Blocked by**: Sprint 10.1, Sprint 10.2.
**Independent Validation**: `renderChainPlan` of a fixture chain is a pure `Text`/bytes value; the `--dry-run`
code path has no branch that opens a socket, reads a credential, or resolves a cluster — a static seam check
plus a run under a no-network sandbox both succeed.
**Docs to update**: `documents/engineering/conformance_harness_doctrine.md` (§3 render-never-touches-infra
backlink), `documents/engineering/generated_artifacts_doctrine.md` (the plan is emitted, never committed),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`conformance_harness_doctrine.md §3 — rendering never touches live infrastructure`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure):
implement the pure `renderChainPlan` that produces the exact plan a live apply would execute, wired to a
`--dry-run` command surface whose render path is a pure function of committed source — no apiserver, no
credentials, no broker, no Vault — so the preview is byte-for-byte what would run and prerequisite checks live
only on the (here-absent) apply path.

### Deliverables
- A pure `renderChainPlan` / `renderChain :: [Step] -> PlanText` that serializes the fold-derived plan
  deterministically (stable ordering, no ambient clock/host reads).
- A `--dry-run` render command that emits the plan and returns, structurally incapable of reaching the
  effectful seam; the emitted plan is a *generated artifact* — rendered from source, never committed
  ([generated_artifacts_doctrine.md](../documents/engineering/generated_artifacts_doctrine.md)).

### Validation
1. `renderChainPlan` is a pure value and `--dry-run` produces it under a no-network sandbox with no
   infrastructure contacted; a seam audit confirms no credential/socket/cluster access on the render path.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 10.4: The plan-render golden battery (`chain-spec`) — the gate 📋

**Status**: Planned
**Implementation**: `test/kernel/PlanSpec.hs` and `test/kernel/fixtures/*.golden` (the pinned `--dry-run` plan
and descent goldens) — target paths, not yet built.
**Blocked by**: Sprint 10.3 (and Sprints 10.1, 10.2).
**Independent Validation**: `cabal test chain-spec` is green — the `--dry-run` render of the fixture chain
matches the committed golden byte-for-byte, the descent goldens hold, and an instrumentation assertion records
zero `stepRun` invocations across the run.
**Docs to update**: `documents/engineering/conformance_harness_doctrine.md` (§4 the Plan spine step is
golden-locked here), `documents/engineering/testing_doctrine.md` (the Register-1 plan-render ledger variant),
`DEVELOPMENT_PLAN/README.md` (flip the Phase-10 status when the gate passes).

### Objective
Adopt [`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md) §4's spine
**Plan** step (*"`chain` produces the `[Step]` value; `--dry-run` renders it; a golden test pins the plan"*)
and §2's **Register 1**: assemble the in-process battery that pins the `--dry-run` plan and the descent
byte-for-byte and proves no action runs during render, emitting a Register-1 proven/tested/assumed ledger with
model↔runtime correspondence and runtime fidelity marked UNVERIFIED (owned by Phases 11/20).

### Deliverables
- `test/kernel/PlanSpec.hs` asserting: the `--dry-run` render of the fixture chain equals its committed golden
  byte-for-byte; the `nextFrameAfter`/`foldLift` descent goldens hold; an instrumentation counter proves
  **zero** `stepRun` invocations during the whole battery.
- A Register-1 ledger led by a Tier-2-UNVERIFIED banner: the plan is proven pure and exact in-process, but no
  runtime-enforcement or effectful-fidelity claim is made — that residue is Phase 11 (fake-tool) and Phase 20
  (live singleton).

### Validation
1. `cabal test chain-spec` is green — the plan and descent goldens match byte-for-byte and the zero-`stepRun`
   assertion holds; the suite is red if the render drifts from its golden or if any action is forced during
   render.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/dsl_doctrine.md` — backlink §2's chain/Step kernel and its pure `renderChainPlan` to
  this in-process Phase-10 seed; keep the effectful `runChainFromFrame` invocation as the deferred Register-2/3
  residue.
- `documents/engineering/conformance_harness_doctrine.md` — record that §3's rendering-never-touches-infra
  invariant and §4's Plan spine step are golden-locked in Phase 10 for the `[Step]` plan.
- `documents/engineering/generated_artifacts_doctrine.md` — record that the `--dry-run` plan is a rendered,
  uncommitted artifact whose golden fixture pins the renderer's output.
- `documents/engineering/testing_doctrine.md` — record the Register-1 plan-render ledger variant this gate
  emits (correspondence and runtime fidelity UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-10 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-10 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Kernel/{Step,Chain,Descent,Plan}.hs`, the
  `--dry-run` render path in `src/Amoebius/Cli.hs`, and the `chain-spec` test-suite as Phase-10 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the DSL vision
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — §2 the chain/Step algebra and *"the plan is the data"*
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — §3 rendering never
  touches live infrastructure, §4 the decode→validate→render→plan→dry-run spine, §2 Register 1
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — the rendered plan
  is emitted from source and never committed
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 1, §4 the per-run ledger
- [phase_09](phase_09_render_manifest_goldens.md) — the pure `render` a step's renderable shape embeds
- [phase_11](phase_11_boundary_fake_tool_harness.md) — Register 2 exercises the effectful seam against fake tools
- [phase_20](phase_20_live_dsl_singleton.md) — Register 3 runs the chain via the Deployment-`replicas=1`
  singleton (no election)
