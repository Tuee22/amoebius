# Phase 35: chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker

> **Purpose**: Specify the pure chain/Step reconcile-kernel target and its `--dry-run` plan render — `chain :: cfg ->
> [Step]` as a pure value whose semantic projection and canonical encoding are checked with no effects
> (Register 1) — then run the real amoebius binary against fake `kubectl`/`docker`/`pulumi` invoked by absolute
> path, asserting the exact argv stream and relayed bytes (Register 2), the two-register boundary that closes the
> pre-cluster conformance spine in-process, before any
> cluster or effectful interpreter exists.
> **Read this if**: phase 35 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_17_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_34_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_36_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_59_object_reconciler.md, DEVELOPMENT_PLAN/phase_60_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_81_determinism_jitcache.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 35.1: The `Step` algebra + `chain :: cfg -> \[Step\]` builder ⏸️](#sprint-351-the-step-algebra--chain--cfg---step-builder-)
- [Sprint 35.2: The pure descent — `nextFrameAfter` / `foldLift` (semantic-oracle locked) ⏸️](#sprint-352-the-pure-descent--nextframeafter--foldlift-semantic-oracle-locked-)
- [Sprint 35.3: `renderChainPlan` / `--dry-run` byte-for-byte render (no live infra) ⏸️](#sprint-353-renderchainplan----dry-run-byte-for-byte-render-no-live-infra-)
- [Sprint 35.4: The semantic plan battery (`chain-spec`) — the Part-A gate ⏸️](#sprint-354-the-semantic-plan-battery-chain-spec--the-part-a-gate-)
- [Sprint 35.5: The single typed subprocess seam + `boundary-spec` skeleton ⏸️](#sprint-355-the-single-typed-subprocess-seam--boundary-spec-skeleton-)
- [Sprint 35.6: The fake `kubectl`/`helm`/`docker`/`pulumi` recorders ⏸️](#sprint-356-the-fake-kubectlhelmdockerpulumi-recorders-)
- [Sprint 35.7: The boundary battery — exact commands + applied bytes + no-`PATH` — the Part-B gate ⏸️](#sprint-357-the-boundary-battery--exact-commands--applied-bytes--no-path--the-part-b-gate-)
- [Sprint 35.8: The sanctioned-API surface — what extension source may reach ⏸️](#sprint-358-the-sanctioned-api-surface--what-extension-source-may-reach-)
- [Sprint 35.9: extension-astcheck — the extension AST checker and the link seal ⏸️](#sprint-359-extension-astcheck--the-extension-ast-checker-and-the-link-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 34, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-50 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** This phase specifies a pure reconcile kernel whose plan is data
(Part A) and a Haskell-binary boundary exercised only against Haskell-generated run-local fakes (Part B).
Neither part may contact live infrastructure or use a non-Haskell verdict.

**Part A (Register 1) — the pure kernel and its no-effect render.** The target includes the `Step` algebra (a label, the
frame it runs in, a `StepKind`, and an effectful `stepRun` action that is *declared but never invoked here*), the
`chain :: cfg -> [Step]` builder whose amoebius instantiation receives a checked plan config containing the whole `ProvisionedSpec`, the pure descent (`nextFrameAfter`/`foldLift`) that computes which steps belong to which frame
without running a single action, and the `renderChainPlan` / `--dry-run` renderer that serializes the candidate
plan intended for a later live interpreter. No live-apply correspondence is claimed here. The load-bearing target is
[conformance_harness_doctrine §3](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)'s
invariant: **rendering a plan never touches live infrastructure** — the render path is to be a pure function of
Haskell source and complete with no apiserver, credentials, broker, or Vault. The target type makes the later
interpreter consume the same `[Step]` value that `--dry-run` serializes, but correspondence with real tool or
cluster behavior remains UNVERIFIED. `renderAll` contributes the complete desired object set, while Step
construction retains each source's `RenderActivation`; the dry-run therefore shows later-stage objects and
their readiness-gated action stage without implying they are eligible for the first generic apply. The
effectful `runChainFromFrame` seam is *declared* here but its live invocation is out of scope — there is **no
election, no standby, and no control-plane daemon runtime** in this phase.

**Part B (Register 2) — the boundary that executes the plan against fakes.** The target includes the single, thin IO seam
through which the amoebius binary invokes every external tool (`src/Amoebius/Exec/Tool.hs`, the boundary
facade that runs a resolved tool **by absolute path**, never a `PATH` lookup), the four fake tool
recorders (`kubectl`, `helm`, `docker`, `pulumi`) that Haskell generates beneath `.build/**` to capture argv
and applied-manifest bytes and return canned success, and the Haskell `boundary-spec` test-suite that drives
the *real* binary against those fakes and asserts the exact command stream and relayed bytes. Nothing here
contacts live infrastructure: Part A fixes plan meaning through an independent Haskell semantic oracle and
canonical generated encodings; Part B is to pass a Haskell-declared protocol challenge, serialized beneath
`.build/**`, through the real binary and require the fake to receive precisely those bytes. The mocking
posture is strict: mocking happens **only** at the subprocess boundary; the planning and rendering code under
test stays pure and untouched. The target harness is to constrain the cross-cutting no-`PATH` invariant at the boundary —
the binary invokes each fake by the exact absolute path it was handed and never resolves a tool against the
host's `PATH` — with the `helm` fake present only as a **negative control that must record zero invocations**
(amoebius renders and applies its own typed manifests and never shells to Helm).

What is *not* here: the effectful interpreter's *invocation* against a **real** cluster with **real** tools — the
live SSA reconciler that replaces the fakes ([phase_59_object_reconciler.md](phase_59_object_reconciler.md)), and
the runtime-enforcement claim that a cluster admits what the fakes accepted, exercised against the live
Deployment-`replicas=1` control-plane daemon ([phase_66_live_dsl_deploy.md](phase_66_live_dsl_deploy.md)) — the
Tier-2 residue this two-register gate leaves UNVERIFIED by construction. The deterministic-simulation activity
that this boundary harness unblocks lives in [phase_17_deterministic_sim_substrate.md](phase_17_deterministic_sim_substrate.md).

**Phase scope:** one target claim — the plan is a pure Haskell value and the Haskell binary's boundary behavior
is observed only by generated run-local fakes. Live tools and infrastructure remain out of scope.

**Substrate:** none — no host, cluster, or live interpreter; `pb validate phase 35` may only hand off to the
Haskell gate, which owns both pure observations and generated-fake boundary observations.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 2 — the final claim observes the real Haskell binary at generated fake-tool boundaries; the
Register-1 semantic-plan checks are mandatory supporting rows, not a second final gate ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 34](phase_34_render_manifest_oracles.md)
**Gate:** `pb validate phase 35`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — the plan is a pure Haskell value and the Haskell binary's external-tool protocol is observed only through Haskell-generated fakes beneath `.build/**`; no live infrastructure is contacted. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 35` is future public spelling only. Before current human approval of Phase 51, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 34; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. The owner marker, preflight, complete
> allowed/forbidden mutations, external observer, scoped cleanup, and zero-owned-residue contract are absent.

## Doctrine adopted

- [`extension_conformance_laws.md` §3 — L1–L5: the per-extension laws](../documents/engineering/extension_conformance_laws.md#3-l1l5-the-per-extension-laws) and [`extension_conformance_laws.md` §4 — C1–C7: the compositional laws](../documents/engineering/extension_conformance_laws.md#4-c1c7-the-compositional-laws) — the L-laws chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker must satisfy in isolation, and the C-laws its composition with any peer must satisfy.
- [`jit_artifact_doctrine.md` §2 — The rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every artifact chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker emits is a recipe over a content address, never an authored file.
- [`dsl_doctrine.md` §2 — Two languages, one system: Dhall carries params, Haskell carries logic](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic)
  (Part A): the **chain/Step algebra** and its load-bearing consequence, *"the plan is the data."* A project's
  deploy is a pure function `chain :: cfg -> [Step]`. Each `Step` pairs a pure renderable shape with its
  reconcile action. Therefore `--dry-run` renders the exact plan without executing an action. Pure descent
  selects actions by frame; `runChainFromFrame` remains the thin effectful seam.
- [`conformance_harness_doctrine.md` §3 — The load-bearing invariant: rendering never touches live infrastructure](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
  (Parts A and B): the load-bearing target — a render is a pure function of Haskell source, and the plan and
  manifest bytes the generated fakes receive in Part B are the bytes rendered in Part A with no cluster.
  Correspondence with a later live apply remains UNVERIFIED; prerequisite
  checks (is a cluster reachable, are credentials present) belong on the *apply* path
  ([phase_59_object_reconciler.md](phase_59_object_reconciler.md)), never the render or boundary path.
- [`conformance_harness_doctrine.md` §2 — The registers, as amoebius uses them for pre-cluster validation](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
  (Register 1 — pure/semantic-oracle, in-process, Part A; **and** Register 2 — boundary integration with fakes, no
  cluster, Part B: the real binary run with fake `helm`/`kubectl`/`docker`/`pulumi` that record their argv and
  applied bytes) and
  [`conformance_harness_doctrine.md` §4 — The spine: decode → legality → bind/expand → plan/resolve → provision → `renderAll` → plan → dry-run → fake apply](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply)
  (the **Plan** step — `chain` produces the `[Step]` value, the semantic oracle fixes its meaning, and canonical
  round trips constrain its generated bytes — for Part A; and the **fake apply** step — the binary runs against
  fake tools while commands and relayed bytes are asserted — for Part B, closing the pre-cluster spine).
- [`conformance_harness_doctrine.md` §6 — Honesty: what the harness does and does not establish](../documents/engineering/conformance_harness_doctrine.md#6-honesty-what-the-harness-does-and-does-not-establish)
  (Part B): any future candidate may describe only the command/byte observation at the generated fake boundary,
  never claim *"the cluster is correct."*
- [`generated_artifacts_doctrine.md §3 — The rule`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)
  (Parts A and B): the rendered plan is emitted from the Haskell source of truth only beneath `.build/**`. A
  separately reviewed Haskell semantic table constrains the plan, and canonical decode/re-encode checks constrain
  its generated bytes. Part B must independently constrain lossless relay of a Haskell-declared boundary input; neither test
  mistakes subject-produced output for an oracle.
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)
  (Register 1 for Part A and **Register 2, boundary integration with fakes** for Part B). Pure code never
  touches a mock; fakes live at the subprocess boundary while planning and rendering stay pure. See also
  [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact):
  any future candidate ledger must carry a Tier-2-UNVERIFIED banner, marking
  model↔runtime correspondence and runtime fidelity UNVERIFIED (owned by
  [phase_59_object_reconciler.md](phase_59_object_reconciler.md) and
  [phase_66_live_dsl_deploy.md](phase_66_live_dsl_deploy.md)); fail-fast, no skips — a missing fake or a
  missing oracle or fake fails with an actionable error, never a pass-with-a-skip.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanently invalidated history.** Every completion, seal, reseal, transcript, evidence, and
> closure statement in the sprint bodies below is rejected as current validation. The material is retained
> only as a target-capability inventory and cannot support status, promotion, or a validation claim.

## Sprint 35.1: The `Step` algebra + `chain :: cfg -> [Step]` builder ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 34](phase_34_render_manifest_oracles.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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
- Each `Step`'s renderable shape embeds its identity-selected projection of the Phase-34 whole-deployment
  `renderAll` output, so the plan is derivable from the step value alone without a second render boundary.

### Validation

1. The real provision path followed by `chain` on each case in the reviewed Haskell corpus
   produces a pure `[Step]` whose renderable shape is fully inspectable without executing any `stepRun`; the evaluation is partiality-free in the sense above (`deepseq` to normal form succeeds; `stepRun` excluded from `NFData`).
2. The identity-disjoint union of all manifest-bearing Step projections equals the one whole-deployment
   `renderAll` value exactly; every projected object is identical to the same identity in that value and no
   public per-service renderer is reachable.
3. The `[Step]` projection equals the nineteen ordered entries in the separately authored Haskell semantic
   oracle, asserted structurally rather than read from renderer output or a serialized table.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 35.2: The pure descent — `nextFrameAfter` / `foldLift` (semantic-oracle locked) ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 35.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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
  ([phase_66_live_dsl_deploy.md](phase_66_live_dsl_deploy.md)); there is no election or standby anywhere in the
  kernel.

### Validation

1. A descent over both case chains reproduces the authored ordered frame/step assignments exactly; the
   out-of-frame step appears in the fold but its `stepRun` is
   unreachable (`deepseq`-to-NF of the plan with the constructor counter reading zero confirms no action
   executed).
2. The reviewed Haskell descent operator (m2, managed admission moved into the cutover frame) is applied to a
   temporary production subject beneath `.build/mutants/**`. It diverges from the independent Haskell frame
   expectation and turns this validation **red** when re-run, while the unchanged control remains green.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 35.3: `renderChainPlan` / `--dry-run` byte-for-byte render (no live infra) ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 35.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`conformance_harness_doctrine.md §3 — rendering never touches live infrastructure`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure):
implement the pure `renderChainPlan` that produces the exact plan a live apply would execute, wired to a
`--dry-run` command surface whose render path is a pure function of reviewed Haskell source — no apiserver, no
credentials, no broker, no Vault — so the preview is byte-for-byte what would run and prerequisite checks live
only on the (here-absent) apply path.

### Deliverables

- A pure `renderChainPlan` / `renderChain :: [Step] -> PlanText` that serializes the fold-derived plan deterministically (stable ordering, no ambient clock/host reads).
- A `--dry-run` render command that emits the plan and returns, structurally incapable of reaching the effectful
  seam; the emitted plan is a *generated artifact* — rendered from source only beneath `.build/**`
  ([generated_artifacts_doctrine.md](../documents/engineering/generated_artifacts_doctrine.md)).
- **The argv dispatch itself**, in `app/amoebius/Main.hs` and nothing else: argv selects a *verb*, and a verb
  is not a role. Where a verb enters a long-running frame, the role that frame holds is read from the decoded
  `FrameConfig` Phase 56 mints, never inferred from the verb, the executable's filename, or the environment
  ([daemon_topology_doctrine.md §2](../documents/engineering/daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid)).
  `--dry-run` is the one verb this phase implements; the dispatch is total over the verb set from the start,
  so a later verb is a compile error at the site that forgot it rather than a runtime fall-through.

### Validation

1. `renderChainPlan` is a pure value and `--dry-run` produces it with credentials scrubbed and socket calls
   blocked and observed (part of the `chain-spec` gate invocation). A separately reviewed Haskell
   import-closure assertion confirms `Amoebius.Kernel.Plan` and the `--dry-run` path reach no
   network/process/credential module. Both mechanisms run on every gate execution, not once.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 35.4: The semantic plan battery (`chain-spec`) — the Part-A gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 35.3
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`conformance_harness_doctrine.md §4`](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply)'s
spine **Plan** step and [`§2`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)'s
**Register 1**: assemble the in-process battery that pins the Plan semantics and canonical render stability and
proves no action runs during render, emitting a Register-1 proven/tested/assumed ledger with model↔runtime
correspondence and runtime fidelity marked UNVERIFIED (owned by Part B and Register 3).

### Deliverables

- The independently authored Haskell corpus: two consumed cases, the ordered plan-semantic expectations, and
  a five-component calculus projection. Any TSV diagnostic and renderer-produced plan/descent bytes are
  generated beneath `.build/**` and cannot satisfy the semantic oracle.
- `test/spec/kernel/PlanSpec.hs` asserts exact `foldLift` semantics, identity-disjoint projections of one
  `renderAll` value, exact whole-render union, all four activation frames and descent edges, canonical
  decode/re-encode stability, and the canonical zero-step Plan.
- A **canaried** instrumentation counter: `Step` values are constructible **only** via the counting smart
  constructor, and the counter increments when a `stepRun` IO action is *executed*. The battery asserts zero
  executions over the render, and a reviewed Haskell **canary control case** deliberately executes one `stepRun` and
  asserts the counter reads nonzero (proving the counter can detect an invocation and the zero-assertion is
  falsifiable). "Zero `stepRun` invocations" means the IO action is never executed — forcing/`deepseq`-ing the
  plan value (with `stepRun` excluded from `NFData`) is permitted and does not increment the counter.
- Two reviewed Haskell mutation operators: `m1_cfg_drop_service` drops the last multi-case entry, and
  `m2_descent_inframe` changes managed admission's frame. Each is applied only to a temporary production-source
  copy beneath `.build/mutants/chain_boundary/**`; each control proves the original equals the oracle and the
  mutated value does not, while the zero-action invariant still holds. The gate re-runs both;
  each MUST turn the suite red.
- The gate command runs `chain-spec` with credential variables scrubbed and socket calls blocked and observed,
  plus the separately reviewed Haskell static import-closure assertion that `Amoebius.Kernel.Plan` and the
  `--dry-run` path reach no network/process/credential module.
- A Register-1 ledger led by a Tier-2-UNVERIFIED banner: the plan is proven pure and exact in-process, but no
  runtime-enforcement or effectful-fidelity claim is made — that residue is Part B (fake-tool, Sprints 34.5–34.7)
  and [phase_66_live_dsl_deploy.md](phase_66_live_dsl_deploy.md) (live control-plane daemon).

### Validation

1. Rejected historical observation: the `chain-spec` Cabal suite, with credentials scrubbed and socket calls
   blocked and observed, was recorded green. Both
   cases match all nineteen semantic entries, their canonical Plan bytes decode and re-encode identically, the
   object/frame/descent invariants hold, and the canaried action count remains zero during render.
2. Both paired semantic mutants turn the suite red at their named row/frame loci and are re-run every gate.
3. The Haskell import-closure assertion passes: `Amoebius.Kernel.Plan` and the `--dry-run` path reach no
   network/process/credential module. This is the **Part-A (Register 1)** half of the phase gate.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 35.5: The single typed subprocess seam + `boundary-spec` skeleton ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 35.4
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`conformance_harness_doctrine.md §2`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
and [`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing):
stand up the **single thin IO seam** through which every external tool invocation flows, so the boundary suite
can substitute fakes at exactly one substitutable point while the planning/rendering code stays pure — the
prodbox single-IO-seam shape as *sibling evidence, not an amoebius result*.

### Deliverables

- `src/Amoebius/Exec/Tool.hs`: the boundary facade that runs a resolved tool **by absolute path** (never a
  `PATH` lookup), threading argv and stdin bytes from the `[Step]`/effect data and returning exit + captured
  streams. Phase 56 preserves this contract while delegating its sole raw process call to the opaque-`AbsExe`
  implementation in `src/Amoebius/Host/Ensure.hs`.
- The `boundary-spec` test-suite stanza and an empty `test/spec/boundary/` tree wired to the seam.

### Validation

1. `cabal build` and the zero-test `boundary-spec` suite are green on the Phase-1 pin; the source gate reports the
   seam is the only subprocess call site.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 35.6: The fake `kubectl`/`helm`/`docker`/`pulumi` recorders ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 35.5
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`conformance_harness_doctrine.md §2/§4`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation):
build the four **subprocess-boundary fixtures** — fake tools that record argv and applied bytes and return canned
success — that stand in for the real `kubectl`/`helm`/`docker`/`pulumi`. These are *fixtures*: they fake a
boundary and are reusable, and (per the testing doctrine) a fixture never silences a missing real-substrate
prerequisite — that distinction is what keeps Register 2 honestly separate from Register 3.

### Deliverables

- A reviewed Haskell fake-tool executable that transcribes argv + stdin (the applied-manifest bytes) and
  returns a configured canned exit. The harness lazily materializes four controlled absolute executable paths
  beneath `.build/fakes/**`; no shell/Python recorder or transcript is repository source.
- `BoundarySpec.hs` reads the per-tool argv, stdin, and sabotage-marker transcripts and checks the recorder
  results without an executor-reachable reference implementation.

### Validation

1. Each fake transcribes argv order and applied-manifest bytes losslessly and returns its canned exit; the
   round-trip check is red if any byte or argv element is dropped or re-encoded.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 35.7: The boundary battery — exact commands + applied bytes + no-`PATH` — the Part-B gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 35.6
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`testing_doctrine.md §2 — Register 2`](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing),
[`conformance_harness_doctrine.md §4`](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply)
(the fake-apply step),
[`§5`](../documents/engineering/conformance_harness_doctrine.md#6-honesty-what-the-harness-does-and-does-not-establish)
(honesty), and
[`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
(the per-run ledger): drive the real amoebius binary over the Part-A plan against the fakes and assert the exact
commands and applied bytes, and prove at the boundary that every tool was invoked by absolute path (the
cross-cutting no-`PATH` invariant, [README.md](README.md)) — then emit the composite Register-1/2
proven/tested/assumed ledger led by a Tier-2-UNVERIFIED banner (no cluster admitted anything; runtime enforcement
is owned by [phase_66_live_dsl_deploy.md](phase_66_live_dsl_deploy.md) and the live apply by
[phase_59_object_reconciler.md](phase_59_object_reconciler.md)).

### Deliverables

- A reviewed Haskell **representative plan corpus** with at least one step per tool and a separately authored
  `.hs` expected-argv value, fixed before the executor implementation under the §M.1 exception and independent
  of the executor per §M.3. Recorder transcripts are fresh `.build/runs/phase_34/**` observations.
- Reviewed Haskell mutation operators named in the Gate (`mB1_argv`, `mB2_byte`, `mB3_path_resolve`), applied
  only beneath `.build/mutants/**`, with a harness that re-runs each and asserts `boundary-spec` red (§M.2).
- `test/spec/boundary/BoundarySpec.hs` asserting: the recorded argv stream equals the separately authored
  Haskell expected-argv value; the applied-manifest bytes equal the Haskell-declared boundary input byte-for-byte; each of the
  three invoked tool transcripts (`kubectl`/`docker`/`pulumi`) is non-empty and the `helm` transcript is empty;
  and each fake was invoked by its exact absolute path under the hostile decoy-`PATH` arrangement with no decoy
  sabotage-marker observed.
- A composite Register-1/2 ledger led by a Tier-2-UNVERIFIED banner: the binary emits the exact commands and
  applied bytes, but no runtime-enforcement claim is made — a skipped-but-applicable Runtime move stays
  UNVERIFIED, never green.

### Validation

1. Rejected historical observation: the `boundary-spec` Cabal suite was recorded green — commands match the
   separately authored Haskell argv expectation, applied bytes match the Haskell-declared boundary input
   exactly, the three invoked tool transcripts (`kubectl`/`docker`/`pulumi`)
   are non-empty and the `helm` transcript is empty, and invocation is by absolute path under the hostile
   decoy-`PATH` arrangement. This is the **Part-B (Register 2)** half of the phase gate; together with Sprint 35.4
   (Part A) it constitutes the two-part Phase-35 gate.
2. Demonstrated negative controls (§M.2): each applied Haskell mutant — mB1 (argv), mB2 (byte), mB3
   (`PATH`-resolution) — is re-run and turns `boundary-spec` red. A green run against any mutant fails the gate.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 35.8: The sanctioned-API surface — what extension source may reach ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 35.7
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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

1. The implementation surface equals the separately reviewed Haskell oracle; a module absent from the oracle but present in the
   implementation (and the converse) fails.
2. No sanctioned effect arm exposes raw `IO`, FFI, or an `unsafe*` operation.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 35.9: extension-astcheck — the extension AST checker and the link seal ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 35.8
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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
2. A reviewed `.hs` compile-refusal declaration and independent Haskell error-class/locus expectation exercise
   the seal: constructing `CheckedExtensionSource` outside the checker does not compile. Any compiler
   diagnostic is a run-local `.build/**` observation, not tracked source.
3. Both seeded mutants turn the suite red.
4. The run emits a proven/tested/assumed ledger recording extension-astcheck as **link-time foreclosed** and recording
   explicitly that *behaviour* of checked source — termination, budget adherence, correct serving — is
   **UNVERIFIED**; the checker bounds what code may reach, never what it computes.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/dsl_doctrine.md` — backlink §2's chain/Step kernel and its pure `renderChainPlan` to
  this in-process Phase-35 seed; keep the effectful `runChainFromFrame` live invocation as the deferred Register-3
  residue.
- `documents/engineering/conformance_harness_doctrine.md` — record that §3's rendering-never-touches-infra
  invariant and §4's Plan spine step are semantic-oracle locked in Phase 35 for the `[Step]` plan (Part A), and that §2/§4's
  fake-apply step is exercised by the in-process Phase-35 boundary harness (Part B); keep Register 3 (live apply)
  as the residue owned by the live band.
- `documents/engineering/generated_artifacts_doctrine.md` — record that the `--dry-run` plan is rendered and
  emitted only beneath `.build/**`, constrained by a reviewed Haskell semantic oracle plus canonical round
  trips; record the independent
  authored boundary input used to prove byte-preserving fake-tool relay.
- `documents/engineering/testing_doctrine.md` — record the Register-1 plan-render ledger variant (Part A) and the
  Register-2 fake-tool recorder + per-run ledger variant (Part B) this composite gate emits (Tier-2
  runtime/correspondence UNVERIFIED).

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — only the human authority may change Phase 35 after reviewing a qualified
  candidate; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-35 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Kernel/{Step,Chain,Descent,Plan}.hs`, the
  `--dry-run` render path in `src/Amoebius/Cli.hs`, the `chain-spec` test-suite, `src/Amoebius/Exec/Tool.hs`,
  `test/spec/boundary/{BoundarySpec,BoundaryOracle,FakeToolMain}.hs`; the four named fake executables and their
  transcripts are lazy `.build/fakes/**` and `.build/runs/**` products. Register the `boundary-spec` Haskell suite as Phase-35
  design-first rows. Phase 56 separately registers `src/Amoebius/Host/Ensure.hs` as the strengthened raw
  process implementation.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the DSL / pre-cluster conformance vision
- [substrates.md](substrates.md) — substrate registry and per-phase map
- [system_components.md](system_components.md) — target component inventory (the kernel modules, the exec seam, and the `chain-spec`/`boundary-spec` suites)
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — [§2](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic) the chain/Step algebra and *"the plan is the data"*
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — [§2](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation) the registers for
  pre-cluster validation (Registers 1 and 2), [§3](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure) rendering never touches live infrastructure, [§4](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply) the
  decode→bind/expand→`planInfrastructure`→(Haskell semantic plan oracle | authenticated-materialization
  fixture→provision→`renderAll`)→plan→dry-run→fake-apply spine, [§5](../documents/engineering/conformance_harness_doctrine.md#6-honesty-what-the-harness-does-and-does-not-establish) the honesty limit
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — the rendered plan is
  emitted from Haskell source only beneath `.build/**`, and the applied bytes equal the `--dry-run` bytes
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) the registers (Register 1 for Part A, Register 2 for Part B), [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run proven/tested/assumed ledger
- [phase_32](phase_32_provision_seal.md) — the whole-deployment provision seal that constructs the opaque
  `ProvisionedSpec` the plan config carries
- [phase_34](phase_34_render_manifest_oracles.md) — the pure `renderAll` output from which a step selects its
  renderable shape and the applied bytes asserted at the boundary
- [phase_1](phase_01_toolchain_spike.md) — dynamically resolves the build and boundary-tool prerequisites
- [phase_27](phase_27_gadt_decode_ir.md) — supplies the typed decoder consumed before planning
- [phase_17](phase_17_deterministic_sim_substrate.md) — the deterministic-simulation substrate this boundary
  harness unblocks
- [phase_38](phase_38_ui_program_schema.md) — the bounded UI source/checker phase that consumes the same
  pre-cluster dhall-typecheck/gadt-decode discipline without adding a second boundary-runtime claim
- [phase_59](phase_59_object_reconciler.md) — the live SSA reconciler that replaces the fakes with real tools
- [phase_66](phase_66_live_dsl_deploy.md) — Register 3 runs the chain via the Deployment-`replicas=1` control-plane daemon
  (no election); the Tier-2 runtime-enforcement half this two-register gate leaves UNVERIFIED
