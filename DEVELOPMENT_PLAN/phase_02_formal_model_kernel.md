# Phase 2: Formal-model EDSL (`Model`/`interpret`/`emitTLA`)

> **Purpose**: Build the reusable formal-model kernel — the reifiable Haskell `Model` fragment and its two total renderings, the in-process `interpret` explorer and the `emitTLA` TLA+ emitter — and prove them on one small model whose generated `.tla` is TLC-checkable and never committed.
> **Read this if**: phase 2 is next in the queue, or a later phase depends on what its gate establishes.

Phase 2 delivers the formal-model EDSL (`Model`/`interpret`/`emitTLA`); its design is owned by [formal_model_doctrine.md](../documents/engineering/formal_model_doctrine.md), [generated_artifacts_doctrine.md](../documents/engineering/generated_artifacts_doctrine.md), [conformance_harness_doctrine.md](../documents/engineering/conformance_harness_doctrine.md), and the plan for reaching it is owned here.
Register 1: an in-process battery, no cluster.
The gate passed on 2026-08-09; Phase-3 code correspondence and runtime fidelity remain UNVERIFIED.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/formal_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 2.1: The `Model` fragment EDSL (the reifiable value) ✅](#sprint-21-the-model-fragment-edsl-the-reifiable-value-)
- [Sprint 2.2: `interpret` + the in-process reachability explorer ✅](#sprint-22-interpret--the-in-process-reachability-explorer-)
- [Sprint 2.3: `emitTLA` renderer + never-committed emission ✅](#sprint-23-emittla-renderer--never-committed-emission-)
- [Sprint 2.4: Round-trip + single-source correspondence on `ToyModel` ✅](#sprint-24-round-trip--single-source-correspondence-on-toymodel-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — resealed 2026-08-15. `python3 tools/formal_model_kernel_gate.py` passed all nine sides: the
31 authored metrics match, all model and renderer mutants are caught, 608 emitted `.tla`/`.cfg` files remain
beneath `.build/**` and outside the 1968-file source snapshot, 14 surfaces join to 39 run-time items, and the
outside-host inventory and authored roots are unchanged. The project-contained attestation is
`sha256:fae2ea35bd57b40dd1a054a362ba53a63bc4fbab0833672a08687b1406ab7d0f`, bound to source snapshot
`sha256:a0b29d7c344b8990…`; Phase 2 owns no remaining migration deferral.

**Pre-containment status record (invalidated where it claims completion):**

✅ Done — sealed 2026-08-12. The migrated gate passed against source snapshot `sha256:12481410e5094291…`
(1927 non-ignored files) and published a verified pre-containment external attestation
`sha256:a6c345e051ff96ff3c66c98a4ea2832f56ada1d50c0d91524a0ce9763b19710e`.

**Observed progress — 2026-08-12:** **Policy-conformant.** The capability result is unchanged and re-run: the
explorer and TLC agree on `ToyModel`'s eight distinct reachable states and its safety verdict with identical
canonical fingerprints, TLC proves liveness under the declared fairness and reddens with fairness removed, and
all five model-safety, one spec-weakening, two renderer-golden, and two renderer-differential mutants are
caught. What changed is the apparatus around it. The JVM and `tla2tools` are resolved from
`tools/toolchain_requirements.json` through `tools/toolchain.py` rather than acquired from URLs and archive checksums
pinned in a tracked manifest, and the two hard-coded runtime version strings are replaced by requirement
satisfaction plus a live TLC banner probe. The 31 recorded metrics are checked against the authored expectation
read off this contract's Gate paragraph, the ledger is derived from those same recorded metrics into
`.build/runs/phase_02/<run-id>/`, and 14 surfaces join to 39 run-time enumerated items. A new `artifact` side
asserts what this phase has always claimed but never checked: all 608 emitted `.tla`/`.cfg` files are outside
the source snapshot, and no specification file sits in authored source.

**Invalidated historical record:**

✅ Done. The Register-1 gate passed on 2026-08-09 with
`python3 tools/formal_model_kernel_gate.py`, emitting ledger
`dynamically-resolved`. The explorer and pinned TLC
agree on all eight distinct `ToyModel` states and its safety verdict; TLC proves its three temporal properties
under the declared weak/strong fairness, and removing fairness makes liveness red. The deterministic
QuickCheck differential passed 200 non-degenerate models with 47.5% safety-violating cases, 100% explicit
expansion-boundary cases, and 100% coverage of every required fragment constructor. This is a
proven-for-the-model/tested kernel result on substrate `none`, not correspondence to Phase-3 code and not
runtime fidelity; both remain **UNVERIFIED**.

## Phase Summary

This phase delivers the **formal-model kernel** amoebius's one proof obligation will later be expressed in:
a single reifiable Haskell `Model` value from which both the runtime decision core and the TLA+ specification
are total functions, so the model↔code correspondence is differentially checked. It stands up three things and
nothing more. First, the `Model` fragment itself — a deliberately small, first-order, side-effect-free
transition-system EDSL (named state variables, an initial assignment, guarded parameterized actions, named
boolean *safety* invariants, per-action *fairness* annotations, named *liveness* (temporal) properties, and
an optional bounding constraint). Second, the two total renderings of that value:
`interpret :: Model -> Event -> State -> Maybe State`, the pure decision core, paired with an in-process
bounded-reachability explorer that walks reachable states the same way TLC does; and
`emitTLA :: Model -> (Tla, Cfg)`, a structural walk of the fragment that emits a TLA+ module and its `.cfg`.
Third, the never-committed discipline: the `.tla`/`.cfg` are build artifacts emitted fresh by an `amoebius`
subcommand, stamped generated, and produced only at check time.

The one concrete protocol amoebius proves itself — the cross-cluster gateway migration, both branches — is
**not** authored here; that is [Phase 3](phase_03_gateway_migration_model.md). This phase proves the *kernel*
on the **reference model** — a small, throwaway bounded two-process mutual-exclusion model, `ToyModel` — so the
machinery is trustworthy before a load-bearing model rides on it. The obligation a reference model discharges,
and why its rendering is byte-locked, are doctrine
([`formal_model_doctrine.md §4.1`](../documents/engineering/formal_model_doctrine.md#41-the-reference-model-and-why-its-rendering-is-byte-locked));
this phase names the concrete model, its fixtures, and its mutants. Validation is entirely in-process
([`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation) [§2](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation) — the registers, and [§3](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure) — rendering never touches live infrastructure): the explorer is a `cabal test`, and TLC
runs on the emitted spec through the version-stable JVM `tla2tools` toolchain. This is a **Register 1**
(pure/golden, in-process, no cluster) design-proof phase.

**Substrate:** none
**Register:** 1 — pure/golden, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Gate:** `python3 tools/formal_model_kernel_gate.py` is green over the committed `ToyModel` round-trip, the Phase-0
oracles, the mechanical model-mutation set, the four `emitTLA` renderer mutants, and the 200-model
differential coverage floors of [Gate integrity](#gate-integrity), and its machine-derived Register-1 ledger
agrees with that run.

## Gate integrity

The apparatus the phase-2 gate closes over, in the slot
[§D](development_plan_standards.md#d-the-per-phase-document-skeleton) reserves for it; every clause it
discharges is owned by [§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub).

**What the command proves.** The reifiable `Model` explorer (`interpret` plus the in-process
bounded-reachability checker) and the `emitTLA` renderer round-trip a single small transition-system model:
the in-process explorer and TLC — run through the standard `tla2tools` toolchain over the freshly emitted
`.tla`/`.cfg` — reach the *identical* safety verdict on the correct model. The emitted `.tla`/`.cfg` are
rendered fresh from the committed `Model` source and are **never committed** to the repository. A green run
establishes that the two renderings agree, not that any cluster enforces anything.

**The normative safety-equality convention** is fixed and shared by both sides, so the two implementations
cannot count under incompatible conventions. Equality is over the set of **canonical fingerprints of *distinct
reachable* states** — TLC's *distinct states*, not its *states generated* counter — with `CHECK_DEADLOCK` set
explicitly on both sides, and with a state satisfying the model's `CONSTRAINT` boundary
**checked-but-not-expanded** on both sides: a boundary state is counted and invariant-checked, its successors
are not enumerated.

**The representative set** is named explicitly: the single committed `ToyModel` — the bounded two-process
mutual-exclusion model of Sprint 2.1 — plus the QuickCheck fragment generator below. No other model is in
scope for Phase 2.

**The model-mutation set is mechanical**, not one hand-picked strawman. Every mutant of the operator family
(guard negation/weakening, effect swap, dropped effect entry/`UNCHANGED`, quantifier flip, fairness drop,
invariant-clause delete) is caught, and the set is partitioned by detection mechanism because the three
mechanisms see different faults. The **safety mutants** — guard negation/weakening, effect swap, dropped
effect entry/`UNCHANGED`, quantifier flip — redden **both readings**: the in-process explorer and TLC reach
the same safety counterexample. The **fairness-drop/liveness mutant** reddens TLC's liveness `PROPERTY` only,
because the safety-only in-process explorer cannot see it. The **spec-weakening mutants**, which drop an
obligation rather than introduce a reachable violation (invariant-clause delete, and the fairness annotation
the fairness-drop removes), are caught by the emitted `INVARIANT`/`PROPERTY` set diverging from the
Phase-0-pinned expected invariant/property set and byte golden, not by a red reachability verdict.
Independently of the mutants, TLC proves the model's liveness `PROPERTY` under weak fairness and reports it
red with fairness removed.

**The differential generator may not pass vacuously.** A QuickCheck generator over the fragment finds no
explorer/TLC disagreement — identical verdict and identical canonical distinct-state fingerprint sets,
safety-scoped — across **at least 200 non-degenerate generated models**, each carrying >=1 enabled action and
>=2 reachable states, with `maxDiscardRatio` bounded (<=10) so precondition discards cannot silently gut the
effective sample and with a floor on `maxSuccess` (>=200 passing cases, not the QuickCheck default of 100).
QuickCheck `checkCoverage` **asserts every fragment constructor fires**: each of `Expr`'s booleans, arithmetic
comparison, finite-set membership, finite quantifier, and function literal/update/application, and each of
`WeakFair`/`StrongFair` and `Always`/`Eventually`/`LeadsTo`, appears in at least 20% of generated models — so
a generator restricted to the easy boolean two-variable subset fails the coverage obligation instead of
passing vacuously. A `cover`/`classify` floor additionally requires a minimum fraction of the generated models
to be **safety-violating** (a reachable counterexample exists) and to reach a `CONSTRAINT` boundary state, so
explorer↔TLC agreement on the red/boundary branch — not only the both-green branch — is exercised by the
generated distribution itself, not solely by the `ToyModel` mutation set.

**The four committed renderer mutants** prove the suite has teeth against `emitTLA` itself, not only against
model bugs. `emitTLA-mut-01` (a dropped `UNCHANGED` conjunct on an action's non-effected variables) and
`emitTLA-mut-02` (a finite quantifier mistranslated `\A`↔`\E`) must each be exposed by the differential
generator as an explorer/TLC divergence, symmetric to the model-mutation check, so a renderer that is correct
only on the constructors `ToyModel` happens to exercise cannot pass. Because that differential check is
legitimately **safety-scoped**, the three liveness/fairness constructors it cannot see — `StrongFair`
(`SF_vars`), `Always` (`[]`), and `Eventually` (`<>`) — are pinned instead by the byte-for-byte `emitTLA`
golden itself, **not** by any in-process liveness checker: the Sprint 2.1 structural assertion forces
`ToyModel` to carry all five liveness/fairness constructors, so the pre-renderer committed golden fixes the
rendered bytes of every one (`WF_vars`/`SF_vars` conjuncts, `[]`/`<>`/`~>` operators). **Two further committed
liveness-path renderer mutants** — `emitTLA-mut-03` (`StrongFair` rendered as `WF_vars`) and `emitTLA-mut-04`
(`Always` rendered as `<>`), committed under `test/mutant/formal/` — which the golden **must turn red**,
close the gap that a renderer swapping `StrongFair`→`WeakFair` or `[]`↔`<>` would otherwise slip through.

**The oracles** this gate checks against are the hand-derived `ToyModel` reachable-distinct-state count and
safety verdict, the `emitTLA ToyModel` byte-for-byte golden **under the canonical TLA+ rendering convention
fixed in Sprint 2.3**, the **expected `INVARIANT`/`PROPERTY` name set** the emitted `.cfg` must equal exactly
(the oracle the spec-weakening mutants above are caught by), and the mutation-operator/renderer-mutant catalog
with their expected red outcomes. All of them are **authored and committed before `interpret`/`emitTLA`
exist** (§M.1) — the convention-independent oracles in Phase 0, and the byte-for-byte golden in Sprint 2.3
itself, authored from the canonical rendering convention that sprint fixes as its first deliverable and before
its renderer is written. A golden regenerated from the renderer's own output does not satisfy the gate.

**The ledger** the run emits is a committed, schema-checked Register-1 ledger
([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)). Its rows — safety
proven-for-the-model at the declared bound *with the recorded distinct-state count*; liveness proven under the
named fairness *with the recorded fairness-sensitivity outcome*; the differential-test case count and
per-constructor coverage percentages; and model-correspondence-to-Phase-3-code and runtime fidelity marked
**UNVERIFIED** — are each **machine-derived from the corresponding recorded test outcome**, and a harness
assertion fails the gate if the emitted ledger does not equal the suite's recorded results. A hardcoded or
print-statement ledger cannot pass.

```mermaid
flowchart LR
  %% register: algebra
  fx["committed fixtures"]:::intent
  or["independently authored oracle"]:::intent
  mu["seeded mutant"]:::intent
  g{{"the phase 2 gate command"}}:::gate
  ok((("phase seal: the ledger this gate emits"))):::seal
  no>"the mutant must turn it red"]:::refuse
  fx -->|"binds the corpus"| g
  or -->|"binds the expectation"| g
  mu -->|"binds the defect"| g
  g -->|"fixtures green, oracle agrees"| ok
  g -->|"mutant green means the gate is not one"| no
  classDef intent   fill:#e8eef7,stroke:#33587a,color:#12283f,stroke-width:1px
  classDef gate     fill:#fde9c8,stroke:#b8791b,color:#5c3a06,stroke-width:2px
  classDef seal     fill:#d3f0dd,stroke:#1f8a4c,color:#0c3a1f,stroke-width:2px
  classDef refuse   fill:#f8d6d6,stroke:#b23636,color:#5c1414,stroke-width:2px
```
*Design intent. Phase 2's gate apparatus; [§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) owns its clauses.*

## Doctrine adopted

- [`formal_model_doctrine.md §2`](../documents/engineering/formal_model_doctrine.md#2-the-model-is-data) — the
  **`Model` is data**: a bounded transition system in a closed first-order fragment (booleans, arithmetic
  comparison, finite sets, finite quantifiers, function literals/update/application) whose transition relation
  is *reified* so it can be walked structurally rather than run as an opaque Haskell function.
- [`formal_model_doctrine.md §3`](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings) —
  **two total renderings**: `interpret` as the runtime decision core and `emitTLA` as the structural emitter,
  the only two consumers of the fragment, each intended to denote every constructor identically and checked by
  the differential suite.
- [`formal_model_doctrine.md §4`](../documents/engineering/formal_model_doctrine.md#4-single-source-correspondence)
  — **single-source correspondence**: a validated model is one where the in-process explorer and TLC agree
  on the correct model *and* both go red under the same seeded mutation — agreement plus shared fault
  sensitivity, in place of a hand-maintained variable→code correspondence table.
- [`formal_model_doctrine.md §5`](../documents/engineering/formal_model_doctrine.md#5-the-tlacfg-are-generated-never-committed)
  — the **`.tla`/`.cfg` are generated, never committed**: emitted by an `amoebius` subcommand, stamped
  generated, regenerated from the current `Model` at every check.
- [`formal_model_doctrine.md §6`](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not)
  — **what a green model-check proves, and what it does not**: proven-for-the-model at the declared bound, not
  a general-scope proof and not a proof the model is the right one; the honest ledger token this phase emits.
- [`generated_artifacts_doctrine.md §2`](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what)
  and [`§3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule) — **what is generated and the rule**: the `emitTLA` row of the generated-artifacts table, stamped generated and emitted by a subcommand,
  with a golden test pinning the *renderer's* behaviour rather than committing the artifact.
- [`conformance_harness_doctrine.md §2`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
  and [`§3`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
  — the **registers and the no-live-infrastructure invariant**: this phase's Register-1 in-process explorer +
  TLC pairing is an instance of "rendering never touches live infrastructure" — validation runs entirely
  in-process over golden/emitted artifacts and stands up no host and no cluster.

## Sprints

> **Current validation record.** Every sprint is covered by the 2026-08-15 reseal. Historical dates and
> implementation observations below remain diagnostic; the Phase Status and current gate result own the seal.
> Any historical instruction to commit generated output, freeze dependency resolution, retain resolved values,
> or consume repository-resident evidence remains superseded by current doctrine.

## Sprint 2.1: The `Model` fragment EDSL (the reifiable value) ✅

**Status**: Done — the capability is re-established by the migrated 2026-08-12 gate; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**: `src/Amoebius/Formal/Model.hs` (the `Model`/`Action`/`Expr` fragment
types), the `formal-model` Cabal library, and the `formal-model-spec` test suite — built.
**Blocked by**: none; the phase is sealed.
**Independent Validation**: the fragment types compile under the pinned GHC 9.12.4 / Cabal 3.16.1.0; a hand-authored small
model (`ToyModel`) is expressible entirely inside the fragment with no opaque Haskell function in its
transition relation.
**Docs to update**: `documents/engineering/formal_model_doctrine.md` (Phase-2 status
backlink), `DEVELOPMENT_PLAN/system_components.md` (register `src/Amoebius/Formal/Model.hs`).

### Objective
Adopt [`formal_model_doctrine.md §2 — the Model is data`](../documents/engineering/formal_model_doctrine.md#2-the-model-is-data):
define the closed, first-order, side-effect-free EDSL — `Model` (name, constants, vars, init, actions,
invariants, optional constraint), `Action` (guarded, parameterized, primed-effect), and the `Expr` fragment —
so that a modelled protocol is a *value that can be walked structurally*, which is the precondition for
emitting faithful TLA+ rather than hand-writing it.

### Deliverables
- `data Model`, `data Action`, and the `Expr` fragment carrying only booleans, arithmetic comparison, finite
  sets, quantifiers over finite sets, and function literal/update/application — and no more; plus the closed
  liveness pieces `data Fairness = WeakFair | StrongFair` and `data Temporal = Always Expr | Eventually Expr |
  LeadsTo Expr Expr`, carried by the `modelFairness`/`modelProperties` fields
  ([`formal_model_doctrine.md §2`](../documents/engineering/formal_model_doctrine.md#2-the-model-is-data)).
- The reference model (`ToyModel` — the bounded two-process mutual exclusion named in
  [Gate integrity](#gate-integrity)) authored
  purely inside the
  fragment, carrying at least one named safety invariant, a bounding constraint, and — so the Phase-0 byte
  golden can pin the rendered bytes of **all five** liveness/fairness constructors — both a `WeakFair` and a
  `StrongFair` action annotation and at least one each of an `Always`, an `Eventually`, and a `LeadsTo`
  temporal property (e.g. *each process eventually enters its critical section* as the `LeadsTo`/`Eventually`
  witnesses, with the `StrongFair` annotation on an action a fair scheduler must not starve).

### Validation
1. The fragment types and `ToyModel` compile on the pinned toolchain; `ToyModel`'s transition relation is
   fully reified (a value in the fragment, not an opaque function) — checked by construction.
2. `ToyModel` is not a boolean-only strawman: it **exercises the harder fragment constructors** the round-trip
   must render faithfully — at least one finite quantifier over a finite set and at least one function
   literal/update/application in a guard or effect, **both** a `WeakFair` and a `StrongFair` action annotation,
   and at least one each of an `Always`, an `Eventually`, and a `LeadsTo` temporal property — so the Sprint 2.4
   round-trip and mutation checks cannot pass while quantifier/function/fairness translation stays stubbed, and
   so the Sprint 2.3 byte golden pins the rendered bytes of **all five** liveness/fairness constructors
   (`WF_vars`/`SF_vars` conjuncts, `[]`/`<>`/`~>` operators), not just the `WeakFair`+`LeadsTo` pair. This
   closes a faithfulness gap the **safety-scoped** differential test ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)) cannot: because that round-trip
   oracle is safety-only, a renderer that emits `StrongFair` as `WF_vars` or swaps `[]`↔`<>` is invisible to it and is caught **only** by the byte golden over a `ToyModel` that actually carries those constructors. This is a committed structural assertion over the `ToyModel` value (a test that walks its `Expr`/`Action`/`Temporal` nodes and fails if any of these constructor classes — including `StrongFair`, `Always`, and `Eventually` — is absent), pinned in Phase 0.

### Remaining Work
None. The closed fragment and structurally complete `ToyModel` are built and exercised by the phase gate.

## Sprint 2.2: `interpret` + the in-process reachability explorer ✅

**Status**: Done — the capability is re-established by the migrated 2026-08-12 gate; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**: `src/Amoebius/Formal/Interpret.hs` (`interpret`),
`src/Amoebius/Formal/Explore.hs` (the bounded breadth-first reachability checker),
`test/spec/formal/RoundTripSpec.hs` — built; the phase suite owns the hand table and explorer checks.
**Blocked by**: none; the phase is sealed.
**Independent Validation**: `interpret` computes the next state for a hand-checked (event, state) pair and the
explorer visits exactly `ToyModel`'s reachable-state set under its constraint — a `cabal test`, no cluster —
with the reference side read from a committed Phase-0 hand table, never from the code under test. Validation 2
below states the provenance rule that table carries.
**Docs to update**:
`documents/engineering/formal_model_doctrine.md` (§3/§4 backlink), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`formal_model_doctrine.md §3 — two total renderings`](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings):
build `interpret :: Model -> Event -> State -> Maybe State`, the pure runtime decision core, and the in-process
bounded-reachability explorer that mirrors TLC — breadth-first over reachable states, pruned by the model's
constraint, checking every invariant on every reachable state.

### Deliverables
- `interpret`, a total function from a `Model` to an `Event -> State -> State` step, unit-tested against
  hand-computed transitions.
- A bounded reachability explorer that returns the reachable-state count and the first invariant violation (if
  any), matching in shape the whole-state-space search TLC applies to the emitted spec.

### Validation
1. `interpret` reproduces the transitions of the committed Phase-0 hand table; the explorer's reachable-
   **distinct**-state count (under the normative CONSTRAINT/`CHECK_DEADLOCK` convention fixed in
   [Gate integrity](#gate-integrity)) and
   green/red verdict on `ToyModel` equal the **Phase-0-committed hand-derived expectation** (not a value
   transcribed from the explorer's first run) — **proven for the model** at the declared bound. The explorer
   reports every invariant on every reachable state, not only the first violated one.
2. The `(event, state) → state` transition table and the `ToyModel` reachable-**distinct**-state count and
   safety verdict this sprint checks against are a **committed Phase-0 hand table authored before
   `Interpret.hs`/`Explore.hs` exist** (§M.1, §M.3), carrying a note recording that its provenance is
   hand-derivation from the model definition, **not** transcription from the explorer's own first output; the
   harness reads the reference side from this committed table, never from the code under test. TLC's
   independent re-derivation of the same count in Sprint 2.4 corroborates but does not replace this Phase-0
   pin, so this sprint's reference is not self-referential.

### Remaining Work
None. The hand transition table, eight-state explorer oracle, invariant checks, and explicit
checked-but-not-expanded boundary convention are green.

## Sprint 2.3: `emitTLA` renderer + never-committed emission ✅

**Status**: Done — the capability is re-established by the migrated 2026-08-12 gate; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**: `src/Amoebius/Formal/EmitTLA.hs` (`emitTLA`),
`src/Amoebius/Cli/Formal.hs` (the `amoebius dev model emit` subcommand),
`test/spec/formal/RoundTripSpec.hs`, and the two committed liveness-path renderer mutants
`emitTLA-mut-03`/`emitTLA-mut-04` under `test/mutant/formal/`; emitted output lands in the git-ignored
`.build/tla/` tree — built.
**Blocked by**: none; the phase is sealed.
**Independent Validation**:
`emitTLA ToyModel` renders a `.tla` + `.cfg`; the renderer is byte-for-byte golden-locked against a
**pre-implementation golden authored before `EmitTLA.hs` exists** (§M.1 — a golden regenerated from the
renderer's own output is not a test), under the **canonical TLA+ rendering convention** fixed below —
without which a byte-exact golden cannot be hand-authored at all; the emitted artifact carries a valid TLA+
`\* GENERATED … do not edit by hand` stamp and is written only to an ignored build path. The never-committed
scan and the golden-fixture layout follow the normative conventions owned by
[`generated_artifacts_doctrine.md §3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)
(one emitted path, one `.golden` suffix, one scan), instantiated here: the committed golden fixtures live at
`test/golden/formal/ToyModel.tla.golden` and `test/golden/formal/ToyModel.cfg.golden` — *"independent
expected-output fixtures are authored test inputs, not captured generated artifacts"* — while the emitted
artifacts land under `.build/tla/` and the scan (`git ls-files -- '.build/*' '*.tla' '*.cfg'`) returns empty. A
`.golden`-suffixed fixture matches neither pattern by construction; an actual emitted
`ToyModel.tla`/`ToyModel.cfg` under version control fails it.
**Docs to update**:
`documents/engineering/formal_model_doctrine.md` (§5 backlink),
`documents/engineering/generated_artifacts_doctrine.md` (the `emitTLA` row → built by Phase 2),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`formal_model_doctrine.md §3`](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings)
and [`§5 — generated, never committed`](../documents/engineering/formal_model_doctrine.md#5-the-tlacfg-are-generated-never-committed),
with [`generated_artifacts_doctrine.md §3 — the rule`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule):
build `emitTLA :: Model -> (Tla, Cfg)` as a structural walk of the fragment — state variables become
`VARIABLES`, the initial assignment becomes `Init`, each action an operator, their disjunction `Next`,
invariants named operators listed as `INVARIANT`s in the `.cfg`, the constraint a `CONSTRAINT`, each
`modelFairness` entry a `WF_vars`/`SF_vars` conjunct on the temporal `Spec`, and each `modelProperties` entry a
named temporal operator listed as a `PROPERTY` — emitted by an `amoebius` subcommand, stamped generated, and
never committed.

### Deliverables
- **The canonical TLA+ rendering convention**, pinned in Phase 0 before the golden is authored — the analogue
  of the canonical Aeson encoding [`phase_13`](phase_13_render_manifest_goldens.md) pins for `renderAll`, and
  the precondition that makes "drifts by a single byte" unambiguous. It fixes: the module header and
  `EXTENDS` line; declaration order (`CONSTANTS`, `VARIABLES`, `vars` tuple, `Init`, one operator per action in
  `modelActions` order, `Next`, invariant operators in `modelInvariants` order, `Spec`, property operators in
  `modelProperties` order); two-space continuation indent with each conjunct/disjunct on its own line under a
  leading `/\`/`\/`; one space either side of every binary operator; **fully parenthesized** nested
  expressions, so no precedence rule is load-bearing on the reader or the renderer; ASCII operator spellings
  (`\A`, `\E`, `[]`, `<>`, `~>`, `\in`, `#`); LF endings and exactly one trailing LF; and a `.cfg` whose
  `CONSTANT`/`INVARIANT`/`PROPERTY`/`CONSTRAINT`/`CHECK_DEADLOCK` stanzas appear in that fixed order.
  The generated-by stamp is **content-stable**: a fixed string naming the tool and the source `Model`, with
  **no timestamp, host, path, user, or version field** — a stamp that varied per run would make the byte
  golden unauthorable and self-defeating
  ([`generated_artifacts_doctrine.md §3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)).
- **The Phase-0-committed expected `INVARIANT`/`PROPERTY` name set** for `ToyModel`, which the emitted `.cfg`
  must equal exactly (set equality, not containment). This is the oracle that catches the spec-weakening
  mutants named in [Gate integrity](#gate-integrity) — an invariant-clause delete or a dropped fairness
  annotation removes an
  *obligation* rather than introducing a reachable violation, so no red reachability verdict would fire.
- `emitTLA`, a total renderer, with the structural mapping above — safety (`INVARIANT`), the fairness-annotated
  `Spec`, and liveness (`PROPERTY`).
- An `amoebius dev model` subcommand that emits the `.tla`/`.cfg` fresh into an ignored build directory with a
  generated-by header; no `.tla`/`.cfg` is added to version control.
- A Register-1 golden test pinning the *renderer's* byte-for-byte output against the Phase-0-committed
  `test/golden/formal/ToyModel.{tla,cfg}.golden` fixtures (authored before `EmitTLA.hs`) — the golden is a
  fixture of the renderer, not a committed spec, and is not regenerated from the renderer's own output.
- Because the Sprint 2.1 structural assertion forces `ToyModel` to carry **all five** liveness/fairness
  constructors, this same byte golden is the **only** oracle that pins liveness/fairness *rendering*
  faithfulness (the Sprint 2.4 differential test is legitimately safety-scoped and cannot see a
  `SF_vars`→`WF_vars` or `[]`↔`<>` swap): it fixes the `WF_vars`/`SF_vars` conjuncts and the `[]`/`<>`/`~>` operators byte-for-byte. **Two committed liveness-path renderer mutants** prove that oracle has teeth — `emitTLA-mut-03` (`StrongFair` rendered as `WF_vars`, breaking the golden's `SF_vars` conjunct) and
  `emitTLA-mut-04` (`Always` rendered as `<>`, breaking the golden's `[]` operator), committed under
  `test/mutant/formal/`, each paired with the positive it breaks (§M.2 — the correct golden byte is the
  positive, the mutant that flips it the negative) and each of which the byte golden **must turn red**; a
  surviving liveness-path renderer mutant fails the gate.

### Validation
1. `emitTLA ToyModel` is byte-for-byte golden-locked against the Phase-0-committed
   `test/golden/formal/ToyModel.{tla,cfg}.golden` fixtures; the emitted files appear only under the ignored
   build path and carry the generated stamp; the `git ls-files -- '.build/*' '*.tla' '*.cfg'` scan returns empty (the
   `.golden`-suffixed fixtures do not match it).
2. The byte golden pins the rendered bytes of **all five** liveness/fairness constructors carried by `ToyModel`
   (`WF_vars`/`SF_vars` conjuncts, `[]`/`<>`/`~>` operators), and the two committed liveness-path renderer
   mutants `emitTLA-mut-03` (`StrongFair`→`WF_vars`) and `emitTLA-mut-04` (`Always`→`<>`) each turn the golden
   **red** — so a renderer that mistranslates a fairness or temporal constructor cannot pass, even though the
   Sprint 2.4 differential oracle stays legitimately safety-scoped.

### Remaining Work
None. The emitter and CLI are byte-golden locked; generated `.tla`/`.cfg` files remain ignored and untracked.

## Sprint 2.4: Round-trip + single-source correspondence on `ToyModel` ✅

**Status**: Done — the capability is re-established by the migrated 2026-08-12 gate; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**: `test/spec/formal/RoundTripSpec.hs` (drives the explorer and TLC over the
same `Model`), a `tla2tools` invocation wrapper, the committed mechanical model-mutation catalog, and the
two committed seeded renderer mutants `emitTLA-mut-01`/`emitTLA-mut-02` under `test/mutant/formal/` —
built and run by `tools/formal_model_kernel_gate.py`.
**Blocked by**: none; the phase is sealed.
**Independent Validation**: on the correct `ToyModel` the in-process explorer and TLC reach the identical
safety verdict; every mechanical model mutant and both renderer mutants are caught; the fairness-sensitivity
check and the safety-scoped >=200-model differential hold. The numbered Validation below states each
predicate, and [Gate integrity](#gate-integrity) pins the operator set and the coverage floors.
**Docs to update**:
`documents/engineering/formal_model_doctrine.md` (§4/§6 — the correspondence + honesty ledger this gate
emits), `documents/engineering/conformance_harness_doctrine.md` (§2/§3 — the Register-1 in-process explorer
+ TLC pairing as a no-live-infrastructure instance). The Phase-2 status flip in `DEVELOPMENT_PLAN/README.md`
and the `none` gate row in `DEVELOPMENT_PLAN/substrates.md` are carried in this phase's Documentation
Requirements (Cross-references to add), not here.

### Objective
Adopt [`formal_model_doctrine.md §4 — single-source correspondence`](../documents/engineering/formal_model_doctrine.md#4-single-source-correspondence)
and [`§6 — what a green model-check proves`](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not):
validate the kernel by running *both* readings of the same `Model` — the in-process explorer and TLC on the
emitted spec — and require agreement on the correct model plus shared sensitivity to one seeded fault, the
operational form of "the two renderings mean the same thing."

### Deliverables
- **The `tla2tools` pin.** [`README.md`](README.md) and [`phase_01`](phase_01_toolchain_spike.md) both delegate
  this acquisition path to Phase 2, so this sprint records the **exact `tla2tools.jar` release** the harness
  resolves and the **JRE floor** (≥ 17, a floor rather than a pin) it runs under, together with the checksum
  the wrapper verifies before invoking it. The recorded values are then carried into
  [`README.md`](README.md)'s Toolchain section, which remains their status home. A TLC verdict produced by an
  unrecorded toolchain is not a pinned independent oracle — the harness refuses to run.
- A round-trip harness that: emits `ToyModel` to `.tla`/`.cfg`, runs TLC through the pinned `tla2tools`, runs
  the in-process explorer, and asserts identical safety verdicts; and drives TLC on the liveness `PROPERTY`
  under fairness (green) and with fairness removed (red).
- A **mechanical mutation set** over the fragment, not one hand-picked strawman: a mutation-operator family
  (guard negation/weakening, effect swap, dropped effect entry/`UNCHANGED`, quantifier flip, fairness drop,
  invariant-clause delete) applied exhaustively to `ToyModel`, with **every** generated mutant required to be
  caught — each safety mutant red in both the explorer and TLC, each fairness-drop/liveness mutant (a
  stall/livelock safety misses) red in TLC's `PROPERTY` — so a single surviving mutant fails the gate, showing
  liveness adds fault-detection safety alone lacks.
- A **differential faithfulness** property test with a non-vacuous generator: a QuickCheck generator over the
  `Model` fragment runs the explorer and TLC on **>=200 non-degenerate generated models** (each >=1 enabled
  action and >=2 reachable states; `maxSuccess>=200`, `maxDiscardRatio<=10` so discards cannot gut the sample)
  under a pinned convention — the explorer mirroring TLC's `CONSTRAINT` semantics (boundary states
  counted/checked but not expanded), `CHECK_DEADLOCK` set explicitly on both sides — and asserts identical
  verdicts and identical **canonical distinct-state fingerprint sets** (not just equal cardinality), shrinking
  any divergence to a minimal offending model. It carries `checkCoverage` obligations that **fail the test unless every fragment constructor fires**: each `Expr` constructor (booleans, arithmetic comparison,
  finite-set membership, finite quantifier, function literal/update/application), each `Fairness`
  (`WeakFair`/`StrongFair`), and each `Temporal` (`Always`/`Eventually`/`LeadsTo`) appears in >=20% of
  generated models — so a generator drawing only the easy boolean subset fails rather than passing vacuously.
  The obligations also include a `cover`/`classify` floor on the **safety-violating** branch (a minimum
  fraction of generated models carry a reachable counterexample) and on `CONSTRAINT`-boundary states, so the
  red/boundary path of the explorer↔TLC differential is exercised by the generated distribution, not only by
  the `ToyModel` mutation set. The claim is **scoped to the safety sub-fragment** (the liveness/fairness
  rendering is not covered by it — the `Fairness`/`Temporal` coverage floor exists only to keep the *safety*
  differential robust when liveness annotations are present; liveness rendering faithfulness is validated on
  `ToyModel` alone — round-trip, fairness-sensitivity, and the fairness-drop mutants — not across the generated
  distribution)
  ([`formal_model_doctrine.md §4`](../documents/engineering/formal_model_doctrine.md#4-single-source-correspondence)).
- **Two committed seeded renderer mutants** proving the differential suite has teeth against `emitTLA` bugs (not
  only model bugs): `emitTLA-mut-01` (a deliberately dropped `UNCHANGED` conjunct) and `emitTLA-mut-02` (a
  finite quantifier `\A`↔`\E` mistranslation), committed under `test/mutant/formal/`, each of which the
  differential generator must expose as an explorer/TLC divergence — a surviving renderer mutant fails the gate.
- The **generated, schema-checked Register-1 ledger** under `.build/runs/` ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed); its schema and external retention are owned by `testing_doctrine.md` and Phase 0), whose Phase-2 rows are:
  (a) safety proven-for-the-model at the declared bound with the recorded reachable-distinct-state count; (b)
  liveness proven under the named fairness with the recorded fairness-sensitivity outcome; (c) the
  differential-test case count and per-constructor coverage percentages; (d) model-correspondence-to-Phase-3-code
  and runtime fidelity marked **UNVERIFIED**. Each row is **machine-derived from the corresponding recorded test outcome** (not a print statement), and a harness assertion fails the gate if the emitted ledger does not equal
  the suite's recorded results — carrying the honest caveats of [§6](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not) (bounded scope; not a general-scope proof; not a proof the model is the right model; liveness proven only under the assumed fairness).

### Validation
1. Explorer and TLC agree (same verdict and identical canonical distinct-state fingerprint sets under the
   normative CONSTRAINT/`CHECK_DEADLOCK` convention, no counterexample) on the correct `ToyModel`; **every**
   mutant of the mechanical model-mutation set is caught (safety mutants red in both, fairness-drop/liveness
   mutants red in TLC's `PROPERTY`); **both committed renderer mutants** `emitTLA-mut-01`/`emitTLA-mut-02` are
   exposed by the differential generator as explorer/TLC divergences; TLC proves the liveness `PROPERTY` under
   fairness and reports it red with fairness removed; the safety-scoped differential generator finds no
   explorer/TLC disagreement over **>=200 non-degenerate models** with `checkCoverage` satisfied (each fragment
   constructor >=20%); and the emitted run-local Register-1 ledger equals the suite's recorded results (harness
   assertion) — the round-trip closes and the kernel is validated for the model at scope.

### Remaining Work
None. The pinned TLC round-trip, liveness sensitivity, mechanical mutants, 200-model differential, and
machine-derived ledger all pass. Phase-3 code correspondence and runtime fidelity remain UNVERIFIED by design.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/formal_model_doctrine.md` — backlink §2/§3/§4/§5/§6 to the Phase-2 kernel that
  realizes them; the round-trip claim moves from spike evidence (§7) to a built, Register-1-validated
  amoebius result on `ToyModel` when the gate runs.
- `documents/engineering/generated_artifacts_doctrine.md` — mark the `emitTLA` row's renderer as built by
  Phase 2 and note the golden-locked, never-committed emission.
- `documents/engineering/conformance_harness_doctrine.md` — record the Register-1 in-process explorer + TLC
  pairing as an instance of the "rendering never touches live infrastructure" invariant.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-2 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-2 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Formal/{Model,Interpret,Explore,EmitTLA}.hs`
  and `src/Amoebius/Cli/Formal.hs` as Phase-2 design-first rows.
- `DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md` — backlink: the gateway-migration `Model` is authored
  on this kernel; only the kernel and its `ToyModel` round-trip are proven here.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *proven for the model*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the one-formal-obligation constraint
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — the one reifiable `Model` and
  its two total renderings (`interpret`, `emitTLA`); the doctrine this phase builds
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — why the emitted
  `.tla`/`.cfg` are rendered fresh and never committed
- [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) — the one
  concrete `Model` that rides this kernel, authored in Phase 3
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — the Register-1
  in-process explorer that mirrors TLC, and the no-live-infrastructure invariant
- [phase_01](phase_01_toolchain_spike.md) — the toolchain spike this phase is blocked by
- [phase_03](phase_03_gateway_migration_model.md) — the gateway-migration model built on this kernel
