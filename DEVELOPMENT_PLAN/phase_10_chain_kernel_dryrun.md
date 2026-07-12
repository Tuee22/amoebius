# Phase 10: chain/Step kernel + `--dry-run` plan render

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_12_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/system_components.md
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
`replicas=1` singleton in [Phase 22](phase_22_live_dsl_singleton.md) — there is **no election, no standby, and
no singleton runtime** in this phase, only the pure kernel and its no-effect render.

**Substrate:** none — no host, no cluster, no effectful interpreter; the gate is an in-process `cabal test`
plan-render battery analogous to the Phase-9 rendered-output goldens.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** `chain :: cfg -> [Step]` renders a byte-for-byte `--dry-run` plan with no effects and the pure
descent is golden-locked — concretely, `cabal test chain-spec` is green **when run inside a network-isolated
namespace (`unshare -n`) with `KUBECONFIG`/cloud-credential/`VAULT_ADDR`/`VAULT_TOKEN` env vars scrubbed**,
and:
- **Representative set (§7, concrete corpus).** The gate exercises exactly the two Phase-0-committed decoded
  fixture cfgs at `test/kernel/fixtures/cfg/`: `multi.cfg.json` (≥2 frames, ≥3 declared services, with one
  service whose step is out-of-frame so its `stepRun` must never be reached) and `minimal.cfg.json` (one
  frame, one service). "Fixture chain" everywhere in this phase means `chain` **applied to a decoded fixture
  cfg** — the builder exercised end-to-end — never a hand-authored `[Step]` literal.
- **Oracle-pinning (§1).** The `--dry-run` plan goldens (`test/kernel/fixtures/plan/{multi,minimal}.plan.golden`)
  and descent goldens (`.../descent/{multi,minimal}.descent.golden`) are hand-authored and **committed in
  Phase 0 before `renderChainPlan` exists**; a golden regenerated from the renderer is not a test. The
  independent step-set reference is a hand-authored table `test/kernel/fixtures/plan/expected_steps.json`
  (one entry per declared service/frame per cfg), authored from the cfg by hand — not from `chain`'s output.
- **Cross-golden render identity (§3, independent oracle).** `chain` produces a pure `[Step]` value whose
  `--dry-run` render matches the plan golden byte-for-byte **and** whose each Step's embedded rendered objects
  are byte-identical to the **Phase-9** committed `render` goldens for the corresponding fixture `ServiceSpec`
  — the reference side is Phase 9's independently-committed output, not the kernel's own.
- **Structural step-set coverage (§3).** The plan contains exactly the step set in `expected_steps.json` for
  the cfg (asserted structurally against the hand table, not read back off the plan golden).
- **Committed mutants (§2).** `cabal test chain-spec` turns **red** on each of ≥2 committed seeded mutants:
  (m1) a cfg mutant removing one service from `multi.cfg.json` (plan and descent goldens must diverge), and
  (m2) a descent mutant weakening `nextFrameAfter` to place the out-of-frame step in-frame (`stepRun`-reach
  guard negation). Each mutant is committed and re-run, not run once.
- **Zero-`stepRun` via a canaried counter (§5).** Every `Step` is constructible only through the counting
  smart constructor, and the counter increments **when the `stepRun` IO action is executed** (not when the
  field thunk is forced). The battery asserts the counter reads **zero** over the whole render, and a
  committed **canary** control case that deliberately executes one `stepRun` asserts the counter reads
  nonzero — proving the counter can detect an invocation and that the zero-assertion is falsifiable.
- **Render-purity trace (§5, OS-boundary observer).** Because the suite runs under `unshare -n` with
  credentials scrubbed, any apiserver/broker/Vault/socket contact on the render path fails the run at the OS
  boundary — the isolation is the observer, not a self-emitted compliance note. A committed static assertion
  additionally checks the transitive import closure of `Amoebius.Kernel.Plan` and the `--dry-run` CLI path
  excludes network/process/credential modules.

The pure descent (`nextFrameAfter`/`foldLift`) is golden-locked and the whole render path completes in-process
with no apiserver, credentials, broker, or Vault — a **Register-1** check that runs on no substrate, still
emitting its proven/tested/assumed ledger with model↔runtime correspondence and runtime fidelity UNVERIFIED.

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
**Independent Validation**: `chain` applied to each committed decoded fixture cfg (`multi.cfg.json`,
`minimal.cfg.json`) evaluates to a pure `[Step]` value whose shape (label, frame, `StepKind`, embedded
rendered objects) is inspectable with no `stepRun` executed. "Partiality-free evaluation" is defined
concretely as **`deepseq` of the `[Step]` value to normal form succeeds** (the `stepRun` IO field is excluded
from the `NFData` instance so forcing the plan cannot execute an action), with a `-Wall`-clean build. Each
Step's embedded rendered objects are byte-identical to the corresponding Phase-9 committed `render` golden.
**Docs to update**: `documents/engineering/dsl_doctrine.md` (§2 chain/Step-kernel status backlink),
`DEVELOPMENT_PLAN/system_components.md` (register the `Amoebius.Kernel.*` modules).

### Objective
Adopt [`dsl_doctrine.md §2 — Dhall carries params, Haskell carries logic`](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic):
seed hostbootstrap's chain/Step algebra as the amoebius reconcile kernel — `chain :: cfg -> [Step]`, each
`Step` being a pure renderable shape (label, frame, `StepKind`, the `[K8sObject]` it would apply) plus an
effectful `stepRun` action — with the chain being the system and the decoded config merely supplying `cfg`.

### Deliverables
- A `Step` type = label + frame + `StepKind` + `stepRun :: cfg -> IO ()`, and a `chain :: cfg -> [Step]`
  builder, **both pure values**; the `stepRun` field is carried but never executed in this phase. `Step` is
  constructible **only** through a counting smart constructor (the raw constructor is not exported), so no
  step's action can be executed without incrementing the battery's instrumentation counter, and the `NFData`
  instance excludes the `stepRun` field so forcing the plan cannot execute an action.
- Each `Step`'s renderable shape embeds the Phase-9 `render` output for the objects it would apply, so the plan
  is derivable from the step value alone.

### Validation
1. `chain` applied to each decoded fixture cfg (`multi.cfg.json`, `minimal.cfg.json`) produces a pure `[Step]`
   whose renderable shape is fully inspectable without executing any `stepRun`; the evaluation is
   partiality-free in the sense above (`deepseq` to normal form succeeds; `stepRun` excluded from `NFData`).
2. Each Step's embedded rendered objects equal the Phase-9 committed `render` goldens for the corresponding
   fixture `ServiceSpec` byte-for-byte (independent cross-golden oracle, not the kernel's own output).
3. The `[Step]` step set equals the hand-authored `expected_steps.json` table for the cfg (one entry per
   declared service/frame), asserted structurally against the table.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 10.2: The pure descent — `nextFrameAfter` / `foldLift` (golden-locked) 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Kernel/Descent.hs` (`nextFrameAfter`, `foldLift`), plus the *declaration
only* of the effectful seam `runChainFromFrame` in `src/Amoebius/Kernel/Chain.hs` — target paths, not yet
built.
**Blocked by**: Sprint 10.1.
**Independent Validation**: `nextFrameAfter` and `foldLift` are pure functions with no `IO` in their type; a
descent over the fixture chain (`chain` applied to `multi.cfg.json`) reproduces the Phase-0-committed golden
frame/step assignment (`descent/multi.descent.golden`), and the out-of-frame step is folded into the plan but
its `stepRun` is provably never reached — "provably never reached" defined as `deepseq` of the fold-derived
plan to normal form succeeding with the counting-constructor counter still reading zero (the IO action is
never executed). The committed descent mutant (m2) that weakens `nextFrameAfter` to place the out-of-frame
step in-frame MUST turn this check red.
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
  against the live Deployment-`replicas=1` singleton (Phase 22); there is no election or standby anywhere in
  the kernel.

### Validation
1. A descent over the fixture chain (`chain` applied to `multi.cfg.json`) reproduces the committed golden
   frame/step assignment byte-for-byte; the out-of-frame step appears in the fold but its `stepRun` is
   unreachable (`deepseq`-to-NF of the plan with the constructor counter reading zero confirms no action
   executed).
2. The committed descent mutant (m2, `nextFrameAfter` guard weakened so the out-of-frame step is placed
   in-frame) turns this validation **red** — committed and re-run, not run once.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 10.3: `renderChainPlan` / `--dry-run` byte-for-byte render (no live infra) 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Kernel/Plan.hs` (`renderChainPlan` / `renderChain`), `src/Amoebius/Cli.hs`
(the `--dry-run` **render** path, kept structurally separate from any apply path) — target paths, not yet
built.
**Blocked by**: Sprint 10.1, Sprint 10.2.
**Independent Validation**: `renderChainPlan` of the fixture chain (`chain` applied to a decoded fixture cfg)
is a pure `Text`/bytes value; the `--dry-run` code path has no branch that opens a socket, reads a credential,
or resolves a cluster. This is enforced by two committed mechanisms that are **part of the gate command**, not
a one-off manual check: (a) an automated static assertion (a `cabal test chain-spec` case) that the transitive
module-import closure of `Amoebius.Kernel.Plan` and the `--dry-run` CLI code path **excludes** any
network/process/credential module (e.g. `Network.*`, `System.Process`, socket/HTTP/Vault clients); and (b) the
suite runs inside `unshare -n` with `KUBECONFIG`/cloud-credential/`VAULT_*` env vars scrubbed, so any actual
socket/apiserver/Vault contact fails at the OS boundary — the isolated namespace is the external observer.
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
1. `renderChainPlan` is a pure value and `--dry-run` produces it under `unshare -n` with credentials scrubbed
   (part of the `cabal test chain-spec` gate invocation) with no infrastructure contacted; the committed
   import-closure static assertion confirms `Amoebius.Kernel.Plan` and the `--dry-run` path reach no
   network/process/credential module. Both mechanisms run on every gate execution, not once.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 10.4: The plan-render golden battery (`chain-spec`) — the gate 📋

**Status**: Planned
**Implementation**: `test/kernel/PlanSpec.hs`, the Phase-0-committed fixtures under `test/kernel/fixtures/cfg/`
(`multi.cfg.json`, `minimal.cfg.json`), `test/kernel/fixtures/plan/{multi,minimal}.plan.golden`,
`test/kernel/fixtures/descent/{multi,minimal}.descent.golden`, the hand-authored step-set table
`test/kernel/fixtures/plan/expected_steps.json`, and the committed mutants under `test/kernel/mutants/`
(m1 cfg service-drop, m2 descent guard-weaken) — target paths, not yet built; the goldens and tables are
committed in Phase 0 before the renderer exists.
**Blocked by**: Sprint 10.3 (and Sprints 10.1, 10.2).
**Independent Validation**: `cabal test chain-spec`, run inside `unshare -n` with credential env vars scrubbed,
is green — the `--dry-run` render of each fixture chain (`chain` applied to the decoded fixture cfg) matches
its Phase-0-committed golden byte-for-byte, each Step's embedded rendered objects match the Phase-9 committed
`render` goldens, the step set matches `expected_steps.json`, the descent goldens hold, the canaried counter
reads zero `stepRun` executions across the run (and the canary control case proves it reads nonzero when one
is executed), and both committed mutants (m1, m2) turn the suite red.
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
- The Phase-0-committed corpus: `test/kernel/fixtures/cfg/{multi,minimal}.cfg.json` (the representative set —
  `multi` has ≥2 frames, ≥3 services, one out-of-frame step; `minimal` has one frame/one service), the plan
  goldens, the descent goldens, and the hand-authored `expected_steps.json` step-set table — all authored and
  committed **before** the renderer exists (a golden regenerated from the implementation is not a test).
- `test/kernel/PlanSpec.hs` asserting, for each fixture cfg: the `--dry-run` render of `chain cfg` equals its
  committed plan golden byte-for-byte; **each Step's embedded rendered objects are byte-identical to the
  Phase-9 committed `render` goldens** for the corresponding fixture `ServiceSpec` (independent cross-golden
  oracle); the `[Step]` step set equals `expected_steps.json` (structural, not read off the golden); the
  `nextFrameAfter`/`foldLift` descent goldens hold.
- A **canaried** instrumentation counter: `Step` values are constructible **only** via the counting smart
  constructor, and the counter increments when a `stepRun` IO action is *executed*. The battery asserts zero
  executions over the render, and a committed **canary control case** deliberately executes one `stepRun` and
  asserts the counter reads nonzero (proving the counter can detect an invocation and the zero-assertion is
  falsifiable). "Zero `stepRun` invocations" means the IO action is never executed — forcing/`deepseq`-ing the
  plan value (with `stepRun` excluded from `NFData`) is permitted and does not increment the counter.
- The two committed seeded mutants: `test/kernel/mutants/m1_cfg_drop_service` (removes a service from
  `multi.cfg.json` — plan and descent goldens must diverge) and `test/kernel/mutants/m2_descent_inframe`
  (weakens `nextFrameAfter` so the out-of-frame step is placed in-frame — the zero-`stepRun`/descent check must
  go red). The gate re-runs both; each MUST turn the suite red.
- The gate command runs `cabal test chain-spec` inside `unshare -n` with `KUBECONFIG`/cloud-credential/`VAULT_*`
  env vars scrubbed, plus the committed static import-closure assertion that `Amoebius.Kernel.Plan` and the
  `--dry-run` path reach no network/process/credential module.
- A Register-1 ledger led by a Tier-2-UNVERIFIED banner: the plan is proven pure and exact in-process, but no
  runtime-enforcement or effectful-fidelity claim is made — that residue is Phase 11 (fake-tool) and Phase 22
  (live singleton).

### Validation
1. `cabal test chain-spec`, run inside `unshare -n` with credential env vars scrubbed, is green — for each
   fixture cfg the plan and descent goldens match byte-for-byte, each Step's embedded objects match the
   Phase-9 committed `render` goldens, the step set matches `expected_steps.json`, and the canaried
   zero-`stepRun`-execution assertion holds (with the canary case proving nonzero detection); the suite is red
   if the render drifts from its golden or if any action is executed during render.
2. Both committed mutants turn the suite red: m1 (cfg service-drop) diverges the plan and descent goldens; m2
   (descent guard-weaken) fails the zero-`stepRun`/descent check. Both are committed and re-run every gate.
3. The committed import-closure static assertion passes: `Amoebius.Kernel.Plan` and the `--dry-run` path reach
   no network/process/credential module.

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
- [phase_22](phase_22_live_dsl_singleton.md) — Register 3 runs the chain via the Deployment-`replicas=1`
  singleton (no election)
