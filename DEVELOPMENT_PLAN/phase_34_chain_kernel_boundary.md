# Phase 34: chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker

> **Purpose**: Seed the pure chain/Step reconcile kernel and its `--dry-run` plan render — `chain :: cfg ->
> [Step]` as a pure value whose semantic projection and canonical encoding are checked with no effects
> (Register 1) — then run the real amoebius binary against fake `kubectl`/`docker`/`pulumi` invoked by absolute
> path, asserting the exact argv stream and relayed bytes (Register 2), the two-register boundary that closes the
> pre-cluster conformance spine in-process, before any
> cluster or effectful interpreter exists.
> **Read this if**: phase 34 is next in the queue, or a later phase depends on what its gate establishes.

Phase 34 delivers the chain/Step kernel + `--dry-run` + boundary fake-tool harness; its design is owned by [dsl_doctrine.md](../documents/engineering/dsl_doctrine.md), [conformance_harness_doctrine.md](../documents/engineering/conformance_harness_doctrine.md), [generated_artifacts_doctrine.md](../documents/engineering/generated_artifacts_doctrine.md), and the plan for reaching it is owned here.
Register 1: an in-process battery, no cluster.
The composite Register-1/2 gate passed on 2026-08-09. Live tools, apiserver apply, and runtime behavior remain UNVERIFIED.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 34.1: The `Step` algebra + `chain :: cfg -> \[Step\]` builder ✅](#sprint-341-the-step-algebra--chain--cfg---step-builder-)
- [Sprint 34.2: The pure descent — `nextFrameAfter` / `foldLift` (semantic-oracle locked) ✅](#sprint-342-the-pure-descent--nextframeafter--foldlift-semantic-oracle-locked-)
- [Sprint 34.3: `renderChainPlan` / `--dry-run` byte-for-byte render (no live infra) ✅](#sprint-343-renderchainplan----dry-run-byte-for-byte-render-no-live-infra-)
- [Sprint 34.4: The semantic plan battery (`chain-spec`) — the Part-A gate ✅](#sprint-344-the-semantic-plan-battery-chain-spec--the-part-a-gate-)
- [Sprint 34.5: The single typed subprocess seam + `boundary-spec` skeleton ✅](#sprint-345-the-single-typed-subprocess-seam--boundary-spec-skeleton-)
- [Sprint 34.6: The fake `kubectl`/`helm`/`docker`/`pulumi` recorders ✅](#sprint-346-the-fake-kubectlhelmdockerpulumi-recorders-)
- [Sprint 34.7: The boundary battery — exact commands + applied bytes + no-`PATH` — the Part-B gate ✅](#sprint-347-the-boundary-battery--exact-commands--applied-bytes--no-path--the-part-b-gate-)
- [Sprint 34.8: The sanctioned-API surface — what extension source may reach ✅](#sprint-348-the-sanctioned-api-surface--what-extension-source-may-reach-)
- [Sprint 34.9: extension-astcheck — the extension AST checker and the link seal ✅](#sprint-349-extension-astcheck--the-extension-ast-checker-and-the-link-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21 by the amended generative gate. The artifact, budget, lift, workflow and evidence
calculi are projected explicitly, and the current result supersedes every invalidated historical seal below.

**Validation record.** The amended thirteen-sided gate
passes on natural `arm64`, untranslated. Both semantic cases and all nineteen ordered Plan rows pass with zero
render actions and one observed canary; exact boundary argv/bytes and the hostile-`PATH` canary pass; all seven
paired mutants redden. All 29 metrics match and 45 surfaces join to 58 items. Attestation
`sha256:c7da6c817733030e3ef69578629de6c781260c9e002d70d7bcd7c334734b52bb` binds source
`sha256:bb3fa3736080d8d2…` over 2,233 files. Live tools, apiserver apply, and runtime correspondence remain
UNVERIFIED.

**Activated 2026-08-21** when the preceding phase resealed.

**A third sanctioned network observer, because two of them were the same substrate's.** The render path's
no-network claim was proven by `unshare -n` or, failing that, by `strace` socket injection — both Linux kernel
facilities, so a gate declaring substrate `none` had no observer at all on Apple and died on a missing
executable before it could say so. Darwin's `sandbox-exec` with `(deny network*)` is the kernel-level
counterpart and is now the third member of the sanctioned set. It is not taken on trust: the gate first runs a
control that must be denied a socket, because a sandbox that is not actually denying would certify a render
that reached the network. Each candidate is probed for existence before it is run, which is what the old
`unshare` probe did not do.

**And the fake boundary tools were Linux-only.** All four captured stdin with `/usr/bin/dd … status=none` — a
path that does not exist on Darwin and a GNU flag BSD `dd` does not take. Each now resolves `cat` between the
two absolute paths it can occupy and fails loudly if it finds neither, which keeps the invoke-by-absolute-path
contract this fixture exists to observe while making it decidable everywhere.

**Opened 2026-08-17** when the preceding phase resealed.
[§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 15 requires a run to record
the natural architecture it proved and to execute no artifact of another. This phase's last gate recorded no
architecture, so its seal is invalidated as a current result and stands only as history; the rerun differs from
it by naming the lane and architecture the run actually used. A sprint marker below records what that sprint achieved before the amendment; under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) it is a diagnostic, not surviving closure.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Done (invalidated) — resealed 2026-08-15. `python3 tools/chain_boundary_gate.py` passed all twelve sides: the chain,
boundary, AST, compile-fail, and network-isolation suites, all seven mutants, and all eleven metrics pass; 40
surfaces join to 40 enumerated items. The project-contained attestation is
`sha256:a3ab699be5f004bd68fd7b3ea0ecbc15bac74328d4b39924d44cd35f61f5dade`, bound to source snapshot
`sha256:d3d92e8c10c59625…`; Phase 34 owns no remaining migration deferral.

**Pre-containment status record (invalidated where it claims completion):**

Done (invalidated) — sealed 2026-08-12. The migrated gate passed against source snapshot `sha256:d79a808594ad51a9…`
(1939 non-ignored files) and published a verified pre-containment external attestation
`sha256:95a34d33ad9a72a75072bfd1e905a7f9c811a6871a0ecbbde0b67b9613064eb5`.

**Observed progress — 2026-08-12:** **Policy-conformant.** This phase's two-register claim is unchanged and
re-run. Register 1: two cfg/plan/descent fixtures are byte-locked, the render path performs zero actions with
its canary observed, and the checked-source compile-fail seal rejects the illegal construction at its authored
locus. Register 2: three boundary tools are invoked with Helm at zero, four argv-and-byte transcripts are
exact, extension-astcheck accepts two positives and rejects all six violation reasons, and all seven seeded mutants redden.
The network-isolated render observer is asserted to be one of the two the contract sanctions and recorded
normalized, so a host reaching the same conclusion by the other route still passes rather than being pinned to
one implementation.

**Six surfaces gained the source checks that always decided them** — the raw `Step` constructor export scan,
the dry-run import closure, the subprocess primitive-site inventory, the partial-token scan, the independent
step-set oracle, and the fake-tool executability check are now named check ids the ledger can cite.
**Thirteen have no recorded observation at all** and are carried UNVERIFIED.

**The subprocess-site inventory had drifted.** `Image/Build.hs`, `Image/BuildRuntime.hs`, and
`Image/Publish.hs` reach the process primitive and were not in the declared set. This is a whole-tree
invariant, so its list must name every legitimate site including later phases'; the three are added with the
reason recorded beside them and the check stays exact, so any site not named still fails. Both findings are
recorded in [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md).

**Invalidated historical record:**

Done (invalidated). Validated on 2026-08-09 with `python3 tools/chain_boundary_gate.py` on
substrate `none` across Registers 1 and 2. Part A covers the pure chain/descent/render boundary, two cfg
fixtures, two plan goldens, two descent goldens, zero action executions, and a positive canary. Part B drives
the real binary through the one absolute-path subprocess seam and checks four exact transcripts across three
invoked tools while Helm records zero calls. extension-astcheck covers all six violation arms and the opaque checked-source
link seal. All seven mutants turn red. The ledger is
`dynamically-resolved`.
The Phase-34 ledger records the exact tested and UNVERIFIED
boundary.

## Phase Summary

This phase seeds, from hostbootstrap, the pure reconcile kernel every later apply rides on and proves that its
plan is *data* (Part A), then closes the pre-cluster conformance spine by running the real binary over that plan
against fakes and asserting the exact commands and bytes (Part B) — both without any live infrastructure.

**Part A (Register 1) — the pure kernel and its no-effect render.** It delivers the `Step` algebra (a label, the
frame it runs in, a `StepKind`, and an effectful `stepRun` action that is *declared but never invoked here*), the
`chain :: cfg -> [Step]` builder whose amoebius instantiation receives a checked plan config containing the whole `ProvisionedSpec`, the pure descent (`nextFrameAfter`/`foldLift`) that computes which steps belong to which frame
without running a single action, and the `renderChainPlan` / `--dry-run` renderer that emits the exact plan a
live apply would execute. The load-bearing claim is
[conformance_harness_doctrine §3](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)'s
invariant: **rendering a plan never touches live infrastructure** — the render path is a pure function of
committed source and completes with no apiserver, no credentials, no broker, no Vault. Because `[Step]` is a pure value, the `--dry-run` preview is byte-for-byte what a live apply would submit; both consume the same rendered value. `renderAll` contributes the complete desired object set, while Step construction retains each source's `RenderActivation`; the dry-run therefore shows later-stage objects and their readiness-gated action stage without implying they are eligible for the first generic apply. The effectful `runChainFromFrame` seam is *declared* here but its live invocation is out of scope — there is **no election, no standby, and no control-plane daemon runtime** in this phase.

**Part B (Register 2) — the boundary that executes the plan against fakes.** It delivers the single, thin IO seam
through which the amoebius binary invokes every external tool (`src/Amoebius/Exec/Tool.hs`, the boundary
facade that runs a resolved tool **by absolute path**, never a `PATH` lookup), the four fake tool
recorders (`kubectl`, `helm`, `docker`, `pulumi`) that capture argv and applied-manifest bytes and return canned
success, and the `boundary-spec` test-suite that drives the *real* binary against those fakes and asserts the
exact command stream and relayed bytes. Nothing here contacts live infrastructure: Part A fixes plan meaning
through an independent semantic oracle and canonical generated encodings; Part B passes an authored protocol
input through the real binary and proves the fake receives precisely those bytes. The mocking
posture is strict: mocking happens **only** at the subprocess boundary; the planning and rendering code under
test stays pure and untouched. The harness also proves the cross-cutting no-`PATH` invariant at the boundary —
the binary invokes each fake by the exact absolute path it was handed and never resolves a tool against the
host's `PATH` — with the `helm` fake present only as a **negative control that must record zero invocations**
(amoebius renders and applies its own typed manifests and never shells to Helm).

What is *not* here: the effectful interpreter's *invocation* against a **real** cluster with **real** tools — the
live SSA reconciler that replaces the fakes ([phase_58_object_reconciler.md](phase_58_object_reconciler.md)), and
the runtime-enforcement claim that a cluster admits what the fakes accepted, exercised against the live
Deployment-`replicas=1` control-plane daemon ([phase_65_live_dsl_deploy.md](phase_65_live_dsl_deploy.md)) — the
Tier-2 residue this two-register gate leaves UNVERIFIED by construction. The deterministic-simulation activity
that this boundary harness unblocks lives in [phase_16_deterministic_sim_substrate.md](phase_16_deterministic_sim_substrate.md).

**Phase scope:** one cohesive claim — *the plan is a pure value and the execution of it is observed at the boundary*. Two registers meet here, which is why this is the only contract that declares both.

**Substrate:** none — no host, no cluster, no live effectful interpreter; the gate is an in-process
`cabal test chain-spec` semantic-plan and canonical-render battery (Part A) plus an
in-process `cabal test boundary-spec` battery driving the real binary against fake tool binaries in a controlled
directory (Part B).

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1/2 — a two-register gate: **Part A is Register 1** (pure/golden, in-process, no cluster) and
**Part B is Register 2** (boundary integration with fake tools, no cluster), both in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 33](phase_33_render_manifest_oracles.md) — pure `renderAll` plus its semantic renderer
oracle, which this phase composes into the chain without consuming generated snapshots.

**Gate:** `python3 tools/run_phase_gate.py 34` passes the Part-A, Part-B, extension-astcheck,
compile-fail, network-observer, mutant, and ledger checks. The committed
Phase-34 ledger records the exact commands, oracle coverage,
and live-runtime residue.

## Gate integrity

This section fixes the one shared interpretation of the gate's representative corpora, oracle pins, and seeded
mutants, so two engineers implement the same gate ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clauses 1–8); it strengthens, never weakens, the Gate and sprint Validations above. Because this phase **merges**
two former phases, it keeps **both** sources' committed fixtures, mutants, and oracles, **partitioned** into the
two parts along the register seam: Part A owns the pure plan-render corpus under `test/spec/kernel/`, Part B owns the
boundary corpus under `test/spec/boundary/`. All artifacts named here are authored and committed in this phase's oracle-pinning sprint before
`Amoebius.Kernel.*` and `Amoebius.Exec.*` exist (the one exception is the executor-argv transcript of Part B,
pinned at the start of Phase 34 before the executor — the §M.1 named exception).


```mermaid
flowchart LR
  %% register: orientation
  s0["Sprint 34.1: The Step algebra + chain :: cfg -> [Step] builder"]
  s1["Sprint 34.2: The pure descent — nextFrameAfter / foldLift (semantic oracle)"]
  s2["Sprint 34.3: renderChainPlan / --dry-run byte-for-byte render (no live infra)"]
  s3["Sprint 34.4: The semantic plan battery (chain-spec) — the Part-A gate"]
  s4["Sprint 34.5: The single typed subprocess seam + boundary-spec skeleton"]
  s5["Sprint 34.6: The fake kubectl/helm/docker/pulumi recorders"]
  s6["Sprint 34.7: The boundary battery — exact commands + applied bytes…"]
  s7["Sprint 34.8: The sanctioned-API surface — what extension source may reach"]
  s8["Sprint 34.9: extension-astcheck — the extension AST checker and the link seal"]
  gate["the phase 34 gate"]
  s0 -->|"produces what the next consumes"| s1
  s1 -->|"produces what the next consumes"| s2
  s2 -->|"produces what the next consumes"| s3
  s3 -->|"produces what the next consumes"| s4
  s4 -->|"produces what the next consumes"| s5
  s5 -->|"produces what the next consumes"| s6
  s6 -->|"produces what the next consumes"| s7
  s7 -->|"produces what the next consumes"| s8
  s8 -->|"the last seam the gate closes over"| gate
```
*Orientation. The seams phase 34 builds, in order; [Gate integrity](#gate-integrity) owns the apparatus. The 2026-08-21 gate executed the complete path.*

### Part A (Register 1) — the pure plan-render corpus (`test/spec/kernel/`)

- **Representative set (§M.7, concrete corpus).** `test/oracle/chain_boundary/cases.tsv` is the consumed,
  independently authored input table: the minimal case provisions `objectstore` as `SingleNode`, while the
  multi case provisions `sql` as `Distributed 3`. Each row travels through the real fixture binding and
  provision path before `chain`; neither an unused description of a case nor a hand-authored `[Step]` can pass.
- **Semantic oracle (§M.1/§M.3).** `test/oracle/chain_boundary/plan_semantics.tsv` fixes all nineteen ordered
  `PlanEntry` projections — case, position, label, frame, kind, and object identity — independently of
  `renderChainPlan`. The suite compares `foldLift` structurally, then decodes and canonically re-encodes each
  generated plan. Renderer-produced plan and descent snapshots are forbidden rather than committed.
- **Whole-render identity (§M.3).** For both cases, manifest-bearing steps are identity-disjoint and their
  ordered union equals the one in-memory `renderAll` result for the retained whole `ProvisionedSpec`. Phase 33's
  semantic renderer oracle establishes the renderer independently; Phase 34 does not depend on its retired
  output snapshots.
- **Committed mutants (§M.2).** `m1_cfg_drop_service` drops the final multi-case entry and must diverge from the
  semantic Plan oracle. `m2_descent_inframe` moves managed admission into the cutover frame and must diverge
  from the authored frame column. Each control first proves the unmutated Plan equals the oracle.
- **Zero-`stepRun` via a canaried counter (§M.5, OS-boundary observer).** Every `Step` is constructible **only**
  through the counting smart constructor (the raw constructor is not exported), and the counter increments **when the `stepRun` IO action is executed** (not when the field thunk is forced; `stepRun` is excluded from the
  `NFData` instance so `deepseq`-ing the plan cannot execute an action). The battery asserts the counter reads
  **zero** over the whole render, and a committed **canary** control case that deliberately executes one
  `stepRun` asserts the counter reads nonzero — proving the counter can detect an invocation and that the
  zero-assertion is falsifiable. The gate first attempts `unshare -n`; where the sandbox denies namespace
  creation, `strace` injects `EPERM` into every socket call and requires an empty network-syscall trace. Thus any
  apiserver/broker/Vault/socket contact on the render path fails the run at the OS boundary. A committed static
  assertion additionally checks the transitive import closure of `Amoebius.Kernel.Plan` and the `--dry-run` CLI
  path excludes network/process/credential modules (e.g. `Network.*`, `System.Process`, socket/HTTP/Vault
  clients).

### Part B (Register 2) — the boundary corpus (`test/spec/boundary/`)

- **Representative plan corpus (§M.7, concrete corpus).** A committed `[Step]` fixture containing **at least one step routed to each tool amoebius actually invokes** — `kubectl` apply, `docker` build/push, `pulumi` up — over
  the Part-A cfg fixtures, so every real boundary surface is driven, not just `kubectl`. The `helm` fake is
  present **only as a negative control asserted to record zero invocations** (amoebius never shells to Helm). An
  invoked tool the binary never routed through leaves an empty transcript and the suite is red, foreclosing a
  `kubectl`-only executor.
- **Oracle-pinning — the expected-argv transcript (§M.1 named exception, §M.3 independent oracle).** The
  expected-argv transcripts are a separate committed hand-authored oracle (`test/golden/chain_boundary/argv/`), pinned
  at the **start of Phase 34 before the executor implementation** (the §M.1 named exception), authored at
  fixture-authoring time from the spec — **never** by the executor's own `Step→argv` fold or any function
  reachable from it. A source gate rejects any import of executor argv-building code into the oracle; a check
  whose oracle is the subject under test is a tautology.
- **Applied bytes (§M.3).** `test/fixture/chain_boundary/boundary/apply_input.json` is an authored protocol
  input, not renderer output. The real binary relays it to the fake `kubectl` byte-for-byte; the byte mutant
  changes one byte and the original-equal/mutated-unequal pair must hold.
- **Committed mutants (§M.2), re-run every gate run.** `cabal test boundary-spec` turns **red** on each of three
  committed seeded mutants under `test/mutant/chain_boundary/boundary/`: **mB1** (`mB1_argv`, an executor argv mutant — drop a
  flag), **mB2** (`mB2_byte`, a one-byte relay mutation), and **mB3** (`mB3_path_resolve`, a `PATH`-resolution mutant — the seam
  resolving the tool by bare name instead of by absolute path). The suite failing on each is a demonstrated
  negative control, not merely assertion logic; each is committed and re-run.
- **No-`PATH` invariant via an external-observer trace (§M.5, OS-boundary observer).** The no-`PATH` invariant is
  detected by the hostile **decoy-`PATH` arrangement**: the run executes with the fakes' parent directory
  **absent** from `PATH` and a decoy directory holding same-named sabotage executables (each writing a distinct
  sabotage-marker) placed **first** on `PATH`; the suite is red if any sabotage-marker is observed (a `PATH`
  lookup would have executed the decoy, not the handed absolute path) or if any fake's transcript `argv[0]`
  differs from the handed absolute path. The trace is read from an observer at the OS boundary
  (the fakes' argv/byte transcript at the process boundary and the decoy markers), never from a self-emitted
  compliance note. A committed source gate additionally proves there is exactly one subprocess-invocation
  site over all of `src/`: Phase 34 initially placed it in `src/Amoebius/Exec/Tool.hs`; Phase 55 moved the raw
  primitive behind the opaque `AbsExe` boundary in `src/Amoebius/Host/Ensure.hs`, with `Exec.Tool` retained as
  the compatibility facade. The gate is red if any subprocess-spawning primitive appears outside that one
  implementation — the enumerated token set is `System.Process`
  (`createProcess`/`readProcess`/`callProcess`/`spawnProcess`/`readCreateProcess`/`callCommand`),
  `typed-process` (`runProcess`/`readProcess`/`startProcess`/`withProcessWait`), `System.Posix.Process`
  (`executeFile`/`forkProcess`/`createSession`), and any raw FFI `c_exec*`/`system` import — and red if the
  enumerated set is empty (guarding against a vacuous scope).
- **Lossless recorder round-trip (§M.3).** `test/spec/boundary/BoundarySpec.hs` reads each fake's argv and stdin
  transcript and proves every expected argv element is ordered and every input byte survives without
  normalization; it is red if any byte or argv element is dropped or re-encoded.

- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`; negatives under `test/negative/chain_kernel_boundary/`.

## Doctrine adopted

- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — the L-laws chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker must satisfy in isolation, and the C-laws its composition with any peer must satisfy.
- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md) — every artifact chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker emits is a recipe over a content address, never an authored file.
- [`dsl_doctrine.md §2 — two languages, one system: Dhall carries params, Haskell carries logic`](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic)
  (Part A): the **chain/Step algebra** and its load-bearing consequence, *"the plan is the data."* A project's
  deploy is a pure function `chain :: cfg -> [Step]`. Each `Step` pairs a pure renderable shape with its
  reconcile action. Therefore `--dry-run` renders the exact plan without executing an action. Pure descent
  selects actions by frame; `runChainFromFrame` remains the thin effectful seam.
- [`conformance_harness_doctrine.md §3 — rendering never touches live infrastructure`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
  (Parts A and B): the load-bearing invariant — a render is a pure function of committed source, the `--dry-run`
  preview is byte-for-byte what a live apply would submit, and the plan and manifest bytes the fakes receive in
  Part B were rendered in Part A with no cluster (the fake-apply adds no infrastructure dependency); prerequisite
  checks (is a cluster reachable, are credentials present) belong on the *apply* path
  ([phase_58_object_reconciler.md](phase_58_object_reconciler.md)), never the render or boundary path.
- [`conformance_harness_doctrine.md §2 — the registers as amoebius uses them for pre-cluster validation`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
  (Register 1 — pure/golden, in-process, Part A; **and** Register 2 — boundary integration with fakes, no
  cluster, Part B: the real binary run with fake `helm`/`kubectl`/`docker`/`pulumi` that record their argv and
  applied bytes) and
  [`§4 — the spine`](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--bindexpand--planresolve-infrastructure--provision--renderall--plan--dry-run)
  (the **Plan** step — `chain` produces the `[Step]` value, the semantic oracle fixes its meaning, and canonical
  round trips constrain its generated bytes — for Part A; and the **fake apply** step — the binary runs against
  fake tools while commands and relayed bytes are asserted — for Part B, closing the pre-cluster spine).
- [`conformance_harness_doctrine.md §5 — honesty: what the harness does and does not establish`](../documents/engineering/conformance_harness_doctrine.md#5-honesty-what-the-harness-does-and-does-not-establish)
  (Part B): a green boundary run is quoted as *"the binary emits the exact commands and applied bytes,"* never as
  *"the cluster is correct."*
- [`generated_artifacts_doctrine.md §3 — The rule`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)
  (Parts A and B): the rendered plan is emitted from the Haskell source of truth and **never committed**. An
  independently authored semantic table constrains the plan, and canonical decode/re-encode checks constrain
  its generated bytes. Part B separately proves lossless relay of an authored boundary input; neither test
  mistakes subject-produced output for an oracle.
- [`testing_doctrine.md §2 — the registers of amoebius testing`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)
  (Register 1 for Part A and **Register 2, boundary integration with fakes** for Part B). Pure code never
  touches a mock; fakes live at the subprocess boundary while planning and rendering stay pure. See also
  [`§4 — no skips, fail-fast, and the per-run ledger artifact`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact):
  the composite gate emits a per-run proven/tested/assumed ledger led by a Tier-2-UNVERIFIED banner, marking
  model↔runtime correspondence and runtime fidelity UNVERIFIED (owned by
  [phase_58_object_reconciler.md](phase_58_object_reconciler.md) and
  [phase_65_live_dsl_deploy.md](phase_65_live_dsl_deploy.md)); fail-fast, no skips — a missing fake or a
  missing oracle or fake fails with an actionable error, never a pass-with-a-skip.

## Sprints

> **Current validation record.** Every sprint is covered by the 2026-08-21 amended gate. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure was
> established by the current phase gate plus universal artifact hygiene.

## Sprint 34.1: The `Step` algebra + `chain :: cfg -> [Step]` builder ✅
**Status**: Done
**Implementation**: `src/Amoebius/Kernel/Step.hs` (the `Step` type, `StepKind`, and the
`stepRun` action field), `src/Amoebius/Kernel/Chain.hs` (the `chain :: cfg -> [Step]` builder) — built and
validated.
**Blocked by**: None.
**Independent Validation**: both fixtures pass the real path through provision and `chain`. Their plans force
to normal form while the counted actions remain at zero. Each Step contains an identity-selected subset of one
whole-deployment `renderAll` result; the disjoint ordered union equals that in-memory result exactly.
**Docs to update**:
`documents/engineering/dsl_doctrine.md` (§2 chain/Step-kernel status backlink).

### Objective
Adopt [`dsl_doctrine.md §2 — Dhall carries params, Haskell carries logic`](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic):
seed hostbootstrap's chain/Step algebra as the amoebius reconcile kernel — `chain :: cfg -> [Step]`, instantiated with a checked plan config containing the whole `ProvisionedSpec`, each `Step` being a pure renderable shape (label, frame, `StepKind`, the `[K8sObject]` it would apply) plus an effectful `stepRun` action — with the chain being the system and the checked config supplying `cfg`.

### Deliverables
- A `Step` type = label + frame + `StepKind` + `stepRun :: cfg -> IO ()`, and a generic `chain :: cfg -> [Step]`;
  the amoebius `cfg` exposes only the opaque whole-deployment `ProvisionedSpec` to the manifest-plan builder,
  never raw `ClusterIR`/`BoundDeployment` or an independently renderable service projection. `chain` calls only
  public `renderAll`; manifest-bearing steps select typed identity subsets from that one result and preserve the
  sources' four-arm activation partition. The builder and its resulting list are pure values; the `stepRun` field
  is carried but never executed in this phase. `Step` is constructible **only** through a counting smart
  constructor (the raw constructor is not exported), so no step's action can be executed without incrementing the
  battery's instrumentation counter, and the `NFData` instance excludes the `stepRun` field so forcing the plan
  cannot execute an action.
- Each `Step`'s renderable shape embeds its identity-selected projection of the Phase-33 whole-deployment
  `renderAll` output, so the plan is derivable from the step value alone without a second render boundary.

### Validation
1. The real provision path followed by `chain` on each consumed case in `cases.tsv`
   produces a pure `[Step]` whose renderable shape is fully inspectable without executing any `stepRun`; the evaluation is partiality-free in the sense above (`deepseq` to normal form succeeds; `stepRun` excluded from `NFData`).
2. The identity-disjoint union of all manifest-bearing Step projections equals the one whole-deployment
   `renderAll` value exactly; every projected object is identical to the same identity in that value and no
   public per-service renderer is reachable.
3. The `[Step]` projection equals the nineteen independently authored ordered rows in
   `plan_semantics.tsv`, asserted structurally rather than read from renderer output.

### Remaining Work
None.

## Sprint 34.2: The pure descent — `nextFrameAfter` / `foldLift` (semantic-oracle locked) ✅
**Status**: Done
**Implementation**: `src/Amoebius/Kernel/Descent.hs` (`nextFrameAfter`, `foldLift`),
plus the effectful seam `runChainFromFrame` in `src/Amoebius/Kernel/Chain.hs` — built and validated.
**Blocked by**: None.
**Independent Validation**: both functions remain pure and both cases match the authored frame and order
columns. The fold-derived plan forces to normal form with a zero action count. Mutant m2 changes one frame and
turns the semantic check red.
**Docs to update**: `documents/engineering/dsl_doctrine.md` (§2 descent/seam status
backlink).

### Objective
Adopt [`dsl_doctrine.md §2`](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic)'s
recursive-descent claim: the interpreter *"runs a step's action only when the binary is in that step's frame; the
descent logic itself is pure and unit-tested, and `runChainFromFrame` is the thin effectful seam."* This sprint
builds and semantic-oracle-locks the **pure** half — `nextFrameAfter` (which frame follows a step) and `foldLift` (folding
the chain into the lift/plan structure) — and only *declares* the effectful seam, whose invocation is deferred to
Part B (Register 2) and Register 3.

### Deliverables
- Pure `nextFrameAfter :: Frame -> [Step] -> Maybe Frame` and `foldLift :: cfg -> [Step] -> Plan`, neither carrying
  `IO`, computing the frame/step assignment and the fold-derived plan with no action run.
- The effectful `runChainFromFrame` is declared as the single IO seam, with an in-file honesty note that its
  invocation is out of scope in Part A. Part B exercises it against fake tools (Sprints 34.5–34.7) and Register 3
  against the live Deployment-`replicas=1` control-plane daemon
  ([phase_65_live_dsl_deploy.md](phase_65_live_dsl_deploy.md)); there is no election or standby anywhere in the
  kernel.

### Validation
1. A descent over both case chains reproduces the authored ordered frame/step assignments exactly; the
   out-of-frame step appears in the fold but its `stepRun` is
   unreachable (`deepseq`-to-NF of the plan with the constructor counter reading zero confirms no action
   executed).
2. The committed descent mutant (m2, managed admission moved into the cutover frame) diverges from the authored
   frame column and turns this validation **red** — committed and re-run, not run once.

### Remaining Work
None.

## Sprint 34.3: `renderChainPlan` / `--dry-run` byte-for-byte render (no live infra) ✅
**Status**: Done
**Implementation**: `src/Amoebius/Kernel/Plan.hs` (`renderChainPlan` / `renderChain`),
`src/Amoebius/Cli.hs` (the `--dry-run` **render** path, kept structurally separate from any apply path) — built
and validated.
**Blocked by**: None.
**Independent Validation**:
`renderChainPlan` of the fixture chain (`chain` applied after the fixture has successfully constructed its
`ProvisionedSpec`) is a pure `Text`/bytes value; the `--dry-run` code path has no branch that opens a
socket, reads a credential, or resolves a cluster. This is enforced by two committed mechanisms that are
**part of the gate command**, not a one-off manual check: (a) an automated static assertion (a `cabal test
chain-spec` case) that the transitive module-import closure of `Amoebius.Kernel.Plan` and the `--dry-run`
CLI code path **excludes** any network/process/credential module. The gate also scrubs credentials and
observes the suite with socket calls denied. It uses a network namespace when permitted and a `strace`
socket-`EPERM` fallback in this sandbox.
**Docs to update**:
`documents/engineering/conformance_harness_doctrine.md` (§3 render-never-touches-infra backlink),
`documents/engineering/generated_artifacts_doctrine.md` (the plan is emitted, never committed).

### Objective
Adopt [`conformance_harness_doctrine.md §3 — rendering never touches live infrastructure`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure):
implement the pure `renderChainPlan` that produces the exact plan a live apply would execute, wired to a
`--dry-run` command surface whose render path is a pure function of committed source — no apiserver, no
credentials, no broker, no Vault — so the preview is byte-for-byte what would run and prerequisite checks live
only on the (here-absent) apply path.

### Deliverables
- A pure `renderChainPlan` / `renderChain :: [Step] -> PlanText` that serializes the fold-derived plan deterministically (stable ordering, no ambient clock/host reads).
- A `--dry-run` render command that emits the plan and returns, structurally incapable of reaching the effectful
  seam; the emitted plan is a *generated artifact* — rendered from source, never committed
  ([generated_artifacts_doctrine.md](../documents/engineering/generated_artifacts_doctrine.md)).
- **The argv dispatch itself**, in `app/amoebius/Main.hs` and nothing else: argv selects a *verb*, and a verb
  is not a role. Where a verb enters a long-running frame, the role that frame holds is read from the decoded
  `FrameConfig` Phase 55 mints, never inferred from the verb, the executable's filename, or the environment
  ([daemon_topology_doctrine.md §2](../documents/engineering/daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid)).
  `--dry-run` is the one verb this phase implements; the dispatch is total over the verb set from the start,
  so a later verb is a compile error at the site that forgot it rather than a runtime fall-through.

### Validation
1. `renderChainPlan` is a pure value and `--dry-run` produces it with credentials scrubbed and socket calls
   blocked and observed (part of the `chain-spec` gate invocation). The committed
   import-closure static assertion confirms `Amoebius.Kernel.Plan` and the `--dry-run` path reach no
   network/process/credential module. Both mechanisms run on every gate execution, not once.

### Remaining Work
None.

## Sprint 34.4: The semantic plan battery (`chain-spec`) — the Part-A gate ✅
**Status**: Done
**Implementation**: `test/spec/kernel/PlanSpec.hs`, the consumed case table and nineteen-row semantic oracle
under `test/oracle/chain_boundary/`, the calculus projection beside them, and the committed mutants under
`test/mutant/chain_boundary/` (`m1_cfg_drop_service`, `m2_descent_inframe`) — built and validated without
committing renderer output.
**Blocked by**: None.
**Independent Validation**: `chain-spec` passes with credentials scrubbed and socket calls blocked and
observed. Both generated Plans match all nineteen semantic rows, round-trip canonically, and project the exact
whole-render object union; the zero-action canary and both paired mutants hold.
**Docs to update**:
`documents/engineering/conformance_harness_doctrine.md` (§4 the Plan spine step is semantic-oracle locked here),
`documents/engineering/testing_doctrine.md` (the Register-1 plan-render ledger variant).

### Objective
Adopt [`conformance_harness_doctrine.md §4`](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--bindexpand--planresolve-infrastructure--provision--renderall--plan--dry-run)'s
spine **Plan** step and [`§2`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)'s
**Register 1**: assemble the in-process battery that pins the Plan semantics and canonical render stability and
proves no action runs during render, emitting a Register-1 proven/tested/assumed ledger with model↔runtime
correspondence and runtime fidelity marked UNVERIFIED (owned by Part B and Register 3).

### Deliverables
- The independently authored corpus: two consumed rows in `cases.tsv`, nineteen ordered entries in
  `plan_semantics.tsv`, and a five-component calculus projection. Renderer-produced plan/descent bytes remain
  uncommitted and cannot satisfy the semantic oracle.
- `test/spec/kernel/PlanSpec.hs` asserts exact `foldLift` semantics, identity-disjoint projections of one
  `renderAll` value, exact whole-render union, all four activation frames and descent edges, canonical
  decode/re-encode stability, and the canonical zero-step Plan.
- A **canaried** instrumentation counter: `Step` values are constructible **only** via the counting smart
  constructor, and the counter increments when a `stepRun` IO action is *executed*. The battery asserts zero
  executions over the render, and a committed **canary control case** deliberately executes one `stepRun` and
  asserts the counter reads nonzero (proving the counter can detect an invocation and the zero-assertion is
  falsifiable). "Zero `stepRun` invocations" means the IO action is never executed — forcing/`deepseq`-ing the
  plan value (with `stepRun` excluded from `NFData`) is permitted and does not increment the counter.
- The two committed seeded mutants: `test/mutant/chain_boundary/m1_cfg_drop_service` drops the last multi-case
  entry, and `test/mutant/chain_boundary/m2_descent_inframe` changes managed admission's frame. Each control
  proves the original equals the oracle and the mutated value does not; the zero-action invariant still holds.
  The gate re-runs both;
  each MUST turn the suite red.
- The gate command runs `chain-spec` with credential variables scrubbed and socket calls blocked and observed,
  plus the committed static import-closure assertion that `Amoebius.Kernel.Plan` and the
  `--dry-run` path reach no network/process/credential module.
- A Register-1 ledger led by a Tier-2-UNVERIFIED banner: the plan is proven pure and exact in-process, but no
  runtime-enforcement or effectful-fidelity claim is made — that residue is Part B (fake-tool, Sprints 34.5–34.7)
  and [phase_65_live_dsl_deploy.md](phase_65_live_dsl_deploy.md) (live control-plane daemon).

### Validation
1. `cabal test chain-spec`, run with credentials scrubbed and socket calls blocked and observed, is green. Both
   cases match all nineteen semantic entries, their canonical Plan bytes decode and re-encode identically, the
   object/frame/descent invariants hold, and the canaried action count remains zero during render.
2. Both paired semantic mutants turn the suite red at their named row/frame loci and are re-run every gate.
3. The committed import-closure static assertion passes: `Amoebius.Kernel.Plan` and the `--dry-run` path reach no
   network/process/credential module. This is the **Part-A (Register 1)** half of the phase gate.

### Remaining Work
None.

## Sprint 34.5: The single typed subprocess seam + `boundary-spec` skeleton ✅
**Status**: Done
**Implementation**: `src/Amoebius/Exec/Tool.hs` (the Phase-34 boundary facade that invokes a tool by absolute
path over the `[Step]`/effect data) and, after Phase 55, `src/Amoebius/Host/Ensure.hs` (the sole raw
`typed-process` implementation), a `boundary-spec` test-suite stanza in
`amoebius.cabal`, and `test/spec/boundary/` — built and validated.
**Blocked by**: None.
**Independent Validation**: the build and boundary suite pass on the dynamically resolved authored toolchain. A non-vacuous source
gate scans all of `src/` and confirms `Host/Ensure.hs` is the sole subprocess-primitive site while the
Phase-34 boundary cases continue to pass through `Exec/Tool.hs`.
**Docs to update**: `DEVELOPMENT_PLAN/system_components.md` (register the exec seam + `boundary-spec` suite), this
document.

### Objective
Adopt [`conformance_harness_doctrine.md §2`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
and [`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing):
stand up the **single thin IO seam** through which every external tool invocation flows, so the boundary suite
can substitute fakes at exactly one substitutable point while the planning/rendering code stays pure — the
prodbox single-IO-seam shape as *sibling evidence, not an amoebius result*.

### Deliverables
- `src/Amoebius/Exec/Tool.hs`: the boundary facade that runs a resolved tool **by absolute path** (never a
  `PATH` lookup), threading argv and stdin bytes from the `[Step]`/effect data and returning exit + captured
  streams. Phase 55 preserves this contract while delegating its sole raw process call to the opaque-`AbsExe`
  implementation in `src/Amoebius/Host/Ensure.hs`.
- The `boundary-spec` test-suite stanza and an empty `test/spec/boundary/` tree wired to the seam.

### Validation
1. `cabal build` and the zero-test `boundary-spec` suite are green on the Phase-1 pin; the source gate reports the
   seam is the only subprocess call site.

### Remaining Work
None.

## Sprint 34.6: The fake `kubectl`/`helm`/`docker`/`pulumi` recorders ✅
**Status**: Done
**Implementation**: `test/harness/chain_boundary/fakes/{kubectl,helm,docker,pulumi}` (the four fake
executables that append argv + stdin bytes to per-tool transcripts and exit with canned success), exercised
directly by `test/spec/boundary/BoundarySpec.hs` — built and validated.
**Blocked by**: None.
**Independent Validation**: each fake, invoked directly, appends its full argv
(in order) and its complete stdin bytes to the run transcript and returns its canned exit; a unit check
proves the transcript captures argv order and applied-manifest bytes **losslessly** (round-trips the
recorded bytes with no re-encoding).
**Docs to update**: `documents/engineering/testing_doctrine.md` (the
Register-2 fake-tool recorder shape), `documents/engineering/conformance_harness_doctrine.md` (the §2/§4
fake-apply recorder), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`conformance_harness_doctrine.md §2/§4`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation):
build the four **subprocess-boundary fixtures** — fake tools that record argv and applied bytes and return canned
success — that stand in for the real `kubectl`/`helm`/`docker`/`pulumi`. These are *fixtures*: they fake a
boundary and are reusable, and (per the testing doctrine) a fixture never silences a missing real-substrate
prerequisite — that distinction is what keeps Register 2 honestly separate from Register 3.

### Deliverables
- Four fake tool executables that transcribe argv + stdin (the applied-manifest bytes) and return a canned exit,
  placed at controlled absolute paths for the seam to invoke.
- `BoundarySpec.hs` reads the per-tool argv, stdin, and sabotage-marker transcripts and checks the recorder
  results without an executor-reachable reference implementation.

### Validation
1. Each fake transcribes argv order and applied-manifest bytes losslessly and returns its canned exit; the
   round-trip check is red if any byte or argv element is dropped or re-encoded.

### Remaining Work
None.

## Sprint 34.7: The boundary battery — exact commands + applied bytes + no-`PATH` — the Part-B gate ✅
**Status**: Done
**Implementation**: `test/spec/boundary/BoundarySpec.hs`; the exact relay input is the authored protocol fixture
`test/fixture/chain_boundary/boundary/apply_input.json`; the **expected-argv transcripts are a separate committed
hand-authored oracle** (`test/golden/chain_boundary/argv/`), not derived by any executor-reachable function; the
committed mutants under `test/mutant/chain_boundary/boundary/` (`mB1_argv`, `mB2_byte`, `mB3_path_resolve`)
— built and validated.
**Blocked by**: None.
**Independent Validation**: `boundary-spec` drives the real binary through all three invoked tools and keeps
Helm as a zero-call control. Exact hand-authored argv and manifest-byte transcripts match. Absolute paths
defeat hostile `PATH` decoys, and all three committed mutants turn the suite red.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (flip the Phase-34 status when the gate passes),
`documents/engineering/testing_doctrine.md`, `documents/engineering/conformance_harness_doctrine.md`.

### Objective
Adopt [`testing_doctrine.md §2 — Register 2`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing),
[`conformance_harness_doctrine.md §4`](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--bindexpand--planresolve-infrastructure--provision--renderall--plan--dry-run)
(the fake-apply step),
[`§5`](../documents/engineering/conformance_harness_doctrine.md#5-honesty-what-the-harness-does-and-does-not-establish)
(honesty), and
[`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
(the per-run ledger): drive the real amoebius binary over the Part-A plan against the fakes and assert the exact
commands and applied bytes, and prove at the boundary that every tool was invoked by absolute path (the
cross-cutting no-`PATH` invariant, [README.md](README.md)) — then emit the composite Register-1/2
proven/tested/assumed ledger led by a Tier-2-UNVERIFIED banner (no cluster admitted anything; runtime enforcement
is owned by [phase_65_live_dsl_deploy.md](phase_65_live_dsl_deploy.md) and the live apply by
[phase_58_object_reconciler.md](phase_58_object_reconciler.md)).

### Deliverables
- The committed **representative plan corpus** — a `[Step]` fixture with at least one step per tool — and the committed **hand-authored expected-argv transcripts** (`test/golden/chain_boundary/argv/`, pinned at the start of Phase 34 before the executor implementation (the §M.1 named exception), authored independently of the executor
  per §M.3).
- The committed **seeded mutants** named in the Gate (`mB1_argv`, `mB2_byte`, `mB3_path_resolve`) with a harness
  that re-runs each and asserts `boundary-spec` red (§M.2).
- `test/spec/boundary/BoundarySpec.hs` asserting: the recorded argv stream equals the committed hand-authored
  expected-argv transcript; the applied-manifest bytes equal the authored boundary input byte-for-byte; each of the
  three invoked tool transcripts (`kubectl`/`docker`/`pulumi`) is non-empty and the `helm` transcript is empty;
  and each fake was invoked by its exact absolute path under the hostile decoy-`PATH` arrangement with no decoy
  sabotage-marker observed.
- A composite Register-1/2 ledger led by a Tier-2-UNVERIFIED banner: the binary emits the exact commands and
  applied bytes, but no runtime-enforcement claim is made — a skipped-but-applicable Runtime move stays
  UNVERIFIED, never green.

### Validation
1. `cabal test boundary-spec` is green — commands match the committed hand-authored argv transcript, applied
   bytes match the authored boundary input exactly, the three invoked tool transcripts (`kubectl`/`docker`/`pulumi`)
   are non-empty and the `helm` transcript is empty, and invocation is by absolute path under the hostile
   decoy-`PATH` arrangement. This is the **Part-B (Register 2)** half of the phase gate; together with Sprint 34.4
   (Part A) it constitutes the two-part Phase-34 gate.
2. Demonstrated negative controls (§M.2): each committed seeded mutant — mB1 (argv), mB2 (byte), mB3
   (`PATH`-resolution) — is re-run and turns `boundary-spec` red. A green run against any mutant fails the gate.

### Remaining Work
None.

## Sprint 34.8: The sanctioned-API surface — what extension source may reach ✅
**Status**: Done
**Implementation**: `src/Amoebius/Dsl/SanctionedApi.hs`,
`dhall/amoebius/SanctionedApi.dhall`, and the oracle-pinned oracle
`test/fixture/chain_boundary/sanctioned_api_expected.dhall` (the hand-authored module and effect allowlist,
authored **independently** of `SanctionedApi.hs` per §M.3) — built and validated.
**Blocked by**: None.
**Independent Validation**: the committed allowlist and the implementation's `SanctionedApi` value agree exactly,
reconciled automatically against the Phase-0 fixture and never against the implementer's own value; every
entry names a module that exists in the pinned dependency closure; the surface contains **no** arm admitting
raw `IO`, and a grep for `unsafePerformIO`/`unsafeCoerce`/`foreign import` over the allowlisted surface
returns nothing.
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective
Adopt [`dsl_doctrine.md` §5 — extension-astcheck](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
and [§8](../documents/engineering/dsl_doctrine.md#8-the-haskell-extension-dsl--the-constrained-surface-extension-astcheck-admits):
fix the closed set of amoebius library entry points and effect constructors extension source may reference,
so that widening it is a reviewed amendment rather than something an extension author grants themselves.

### Deliverables
- A `SanctionedApi` value: the `NonEmptySet ModuleName` an extension may import and the
  `NonEmptySet SanctionedEffect` through which it may perform effects. There is no unrestricted-`IO`
  constructor; every effect an extension can reach is a named arm.
- The oracle-pinned independent allowlist oracle and its reconciliation check.

### Validation
1. The implementation surface equals the committed oracle; a module absent from the oracle but present in the
   implementation (and the converse) fails.
2. No sanctioned effect arm exposes raw `IO`, FFI, or an `unsafe*` operation.

### Remaining Work
None.

## Sprint 34.9: extension-astcheck — the extension AST checker and the link seal ✅
**Status**: Done
**Implementation**: `src/Amoebius/Dsl/AstCheck.hs`, `test/spec/dsl/AstCheckSpec.hs`, and
`test/fixture/chain_boundary/astcheck/`. The corpus contains positives and one exact-span negative for each of the
six `AstViolationReason` arms. The checker and its opaque `CheckedExtensionSource` are built and validated.
**Blocked by**: None.
**Independent Validation**: positives are accepted; each negative matches its exact tagged reason and source
span. A compile-fail golden proves the checked-source constructor remains opaque. The raw-IO and exported-
constructor mutants both turn their checks red.
**Docs to update**: `documents/engineering/dsl_doctrine.md`,
`documents/illegal_state/illegal_state_lifecycle.md`, `DEVELOPMENT_PLAN/system_components.md`

### Objective
Deliver extension-astcheck: admit extension source against the Sprint-33.8 surface, and make unchecked source
**unlinkable** rather than merely discouraged — closing
[`illegal_state_lifecycle.md` §3.78](../documents/illegal_state/illegal_state_lifecycle.md#378-extension-source-that-reaches-outside-the-sanctioned-api).

### Deliverables
- The checker: `ExtensionSourceVerdict`, returning `Rejected` with a `NonEmpty AstViolation` carrying module
  path, source span, and reason, or `Accepted` with an opaque `CheckedExtensionSource`.
- The link seal: `CheckedExtensionSource`'s constructor is private and the checker is its only producer, so
  the link step has no way to consume unchecked source.
- A `--why` diagnostic rendering a rejection as located facts rather than a bare refusal.

### Validation
1. Positives accept; each negative rejects at its oracle-pinned reason **and** span.
2. The compile-fail golden proves the seal: constructing `CheckedExtensionSource` outside the checker does not
   compile.
3. Both seeded mutants turn the suite red.
4. The run emits a proven/tested/assumed ledger recording extension-astcheck as **link-time foreclosed** and recording
   explicitly that *behaviour* of checked source — termination, budget adherence, correct serving — is
   **UNVERIFIED**; the checker bounds what code may reach, never what it computes.

### Remaining Work
None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/dsl_doctrine.md` — backlink §2's chain/Step kernel and its pure `renderChainPlan` to
  this in-process Phase-34 seed; keep the effectful `runChainFromFrame` live invocation as the deferred Register-3
  residue.
- `documents/engineering/conformance_harness_doctrine.md` — record that §3's rendering-never-touches-infra
  invariant and §4's Plan spine step are semantic-oracle locked in Phase 34 for the `[Step]` plan (Part A), and that §2/§4's
  fake-apply step is exercised by the in-process Phase-34 boundary harness (Part B); keep Register 3 (live apply)
  as the residue owned by the live band.
- `documents/engineering/generated_artifacts_doctrine.md` — record that the `--dry-run` plan is rendered and
  uncommitted, constrained by an authored semantic oracle plus canonical round trips; record the independent
  authored boundary input used to prove byte-preserving fake-tool relay.
- `documents/engineering/testing_doctrine.md` — record the Register-1 plan-render ledger variant (Part A) and the
  Register-2 fake-tool recorder + per-run ledger variant (Part B) this composite gate emits (Tier-2
  runtime/correspondence UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-34 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-34 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Kernel/{Step,Chain,Descent,Plan}.hs`, the
  `--dry-run` render path in `src/Amoebius/Cli.hs`, the `chain-spec` test-suite, `src/Amoebius/Exec/Tool.hs`,
  `test/spec/boundary/BoundarySpec.hs`, the fake tools under `test/harness/chain_boundary/`, and the
  `boundary-spec` test-suite as Phase-34
  design-first rows. Phase 55 separately registers `src/Amoebius/Host/Ensure.hs` as the strengthened raw
  process implementation.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the DSL / pre-cluster conformance vision
- [substrates.md](substrates.md) — substrate registry and per-phase map
- [system_components.md](system_components.md) — target component inventory (the kernel modules, the exec seam, and the `chain-spec`/`boundary-spec` suites)
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — [§2](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic) the chain/Step algebra and *"the plan is the data"*
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — [§2](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation) the registers for
  pre-cluster validation (Registers 1 and 2), [§3](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure) rendering never touches live infrastructure, [§4](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--bindexpand--planresolve-infrastructure--provision--renderall--plan--dry-run) the
  decode→bind/expand→`planInfrastructure`→(infrastructure-plan golden | authenticated-materialization
  fixture→provision→`renderAll`)→plan→dry-run→fake-apply spine, [§5](../documents/engineering/conformance_harness_doctrine.md#5-honesty-what-the-harness-does-and-does-not-establish) the honesty limit
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — the rendered plan is
  emitted from source and never committed, and the applied bytes equal the `--dry-run` bytes
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) the registers (Register 1 for Part A, Register 2 for Part B), [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run proven/tested/assumed ledger
- [phase_31](phase_31_provision_seal.md) — the whole-deployment provision seal that constructs the opaque
  `ProvisionedSpec` the plan config carries
- [phase_33](phase_33_render_manifest_oracles.md) — the pure `renderAll` output from which a step selects its
  renderable shape and the applied bytes asserted at the boundary
- [phase_1](phase_01_toolchain_spike.md) — dynamically resolves the build and boundary-tool prerequisites
- [phase_26](phase_26_gadt_decode_ir.md) — supplies the typed decoder consumed before planning
- [phase_16](phase_16_deterministic_sim_substrate.md) — the deterministic-simulation substrate this boundary
  harness unblocks
- [phase_37](phase_37_ui_program_schema.md) — the bounded UI source/checker phase that consumes the same
  pre-cluster dhall-typecheck/gadt-decode discipline without adding a second boundary-runtime claim
- [phase_58](phase_58_object_reconciler.md) — the live SSA reconciler that replaces the fakes with real tools
- [phase_65](phase_65_live_dsl_deploy.md) — Register 3 runs the chain via the Deployment-`replicas=1` control-plane daemon
  (no election); the Tier-2 runtime-enforcement half this two-register gate leaves UNVERIFIED
