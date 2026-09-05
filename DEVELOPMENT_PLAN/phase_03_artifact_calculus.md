# Phase 3: The artifact calculus

> **Purpose**: Specify the target Haskell capability to represent artifact kind, recipe,
> content-derived address, materialization, consumption, and reap boundaries as one typed Haskell
> calculus.
> **Read this if**: an artifact's name, region, or recipe has to be reasoned about, or this gate has to be read precisely.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_04_budget_calculus.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 3.1: The artifact calculus](#sprint-31-the-artifact-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

The complete Phase-2 gate is recorded for the same source identity before this phase may run. The phase remains
Active until its own complete integrated gate passes and authorizes the mechanical status projection.

## Phase Summary

This phase implements artifact kind, recipe, content-derived address, materialization, consumption, and reap
boundaries as one typed Haskell calculus. Its package-hidden validation supervisor builds a separately authored
Haskell oracle from the exact source snapshot, executes clean and changed-production subjects, and compiles the
legal and illegal region-lifetime twins one at a time.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` is not used by this pre-`BOOTSTRAP_HANDOFF` gate. The dispatcher and every compiler child are invoked from
the exact absolute source-bound Haskell executable and authenticated compiler input.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Represent artifact kind, pure recipe, content-derived address, materialization, consumption,
and reap boundaries as one typed Haskell calculus. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model capability. NOT VALIDATED.

**Depends on:** [Phase 2](phase_02_repository_layout_conformance.md)
**Gate:** `pb validate phase 03`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-3 semantic payload, package-hidden serial
compiler supervisor, independent Haskell oracle, paired compile-negative control, and changed-production
matrix are complete; only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | The closed target index, pure recipe, four-input address, and rank-2 region lifetime calculus all satisfy their independently observed contract in one source-bound run. |
| `Subject` | `Amoebius.Calculus.Artifact.{Target,Recipe,Address,Region}` is acquired through package-hidden `Amoebius.Validation.ArtifactCalculusRun.Internal`; no caller supplies outcomes. |
| `Command` | Future public spelling is `pb validate phase 03`; before `BOOTSTRAP_HANDOFF`, the exact absolute source-bound Haskell executable runs directly. Every direct GHC child uses the authenticated 9.12.4 compiler and one discovered matching package database, synchronously and without `-j`. |
| `Oracle` | `test/spec/calculus/ArtifactCalculusSpec.hs` contains a separately authored Haskell expectation relation and observes the production calculus through its public modules. |
| `Positive controls` | All eleven clean calculus predicates pass, two independently seeded clean render reports are byte-identical, and the legal same-region handle fixture compiles. |
| `Paired negatives` | `handle_stays_in_region.hs` compiles; its minimally different `handle_escapes_region.hs` twin is refused specifically by GHC-25897 at the rigid region type mismatch. |
| `Mutants` | Three applied CPP selectors change production: dropping rendered bytes from the address reddens only `address-folds-rendered`; admitting ambient seed into a recipe makes two reports differ; weakening the rank-2 region boundary makes the illegal twin compile. |
| `Discovery` | The exact artifact production modules, Haskell corpus/oracle, and compile-negative pair are discovered from the captured Git source snapshot and reconciled bidirectionally with the fixed phase inventory. |
| `Challenge` | After acquisition, the fixed address, ambient-recipe, and region-escape changed subjects execute and must each be distinguished by its assigned independent observation. |
| `Observer` | The supervisor records every compiler and process executable, exact argv, exit status, transcript digest, and bounded failure transcript outside the production subject. |
| `Authority/bypass` | `pb`, network, hardware, live services, PATH-selected compiler substitution, and compiler/linker concurrency are forbidden; every compiler child is synchronous and contains no parallelism flag. |
| `Freshness` | Every candidate creates a new run root beneath `.build/runs/phase-03/work/**`; the dispatcher independently requires the closing source identity to equal the opening identity. |
| `Qualification` | Clean controls, the exact compile-negative diagnostic, and all three fixed changed-production subjects must pass together; a survivor or wrong-locus failure rejects the candidate. |
| `Cleanroom` | All binaries, interfaces, objects, stubs, and transcripts are generated lazily under the fresh Phase-3 run root; none becomes authored source. |
| `Legacy closure` | Phase 3 owns no legacy-debt identifier; the complete predecessor and phase prerequisites must pass, while later-owned typed source debt remains residue rather than evidence. |
| `Predecessor` | Consume exactly one durable Phase-2 receipt bound to this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Budget, composed calculi, effects, runtimes, hardware, and live-service claims remain explicitly owned by later phases; no Phase-3 evidence row is residue. |
| `Pass criterion` | `qualified-phase-three-gate-pass`: all eighteen rows must be execution-derived green in one candidate for one stable source, with the exact Phase-2 receipt and empty mandatory residue. |

**This phase owns its compile-negative evidence.** Each illegal twin below requires a phase-local, source-bound
GHC invocation, a minimally different positive control, and a separately authored exact-diagnostic oracle.
[Phase 15](phase_15_compile_fail_harness.md) later consolidates reusable compile-fail machinery; it is not a
prerequisite of this earlier gate. This phase's local package-hidden runner owns the bounded pair now.

## Doctrine adopted

- [`jit_artifact_doctrine.md` §3 — Targets and recipes](../documents/engineering/jit_artifact_doctrine.md#3-targets-and-recipes) — the rule behind the artifact calculus.

## Sprints

The sprint seam below is bound to the same Haskell-only subject, oracle, and serial supervisor as the gate.

## Sprint 3.1: The artifact calculus ✅

**Status**: Done
**Implementation**: `src/Amoebius/Calculus/Artifact/{Target,Recipe,Address,Region}.hs`; package-hidden supervisor `src/validation-kernel/Amoebius/Validation/ArtifactCalculusRun/Internal.hs`
**Blocked by**: [Phase 2](phase_02_repository_layout_conformance.md) gate pass
**Independent Validation**: eleven clean predicates and equal clean seed reports; exact GHC-25897 paired negative; address-rendering, ambient-recipe, and region-escape production mutants; later calculi and effectful observations remain explicit residue
**Oracle**: `test/spec/calculus/ArtifactCalculusSpec.hs`, separately authored against public calculus modules; `test/spec/calculus/ArtifactCorpus.hs` supplies only subject inputs, not expected verdicts
**Legacy IDs**: none; later-owned tracked-source debt remains in the typed central registry and cannot satisfy this phase
**Docs to update**: this phase file, `DEVELOPMENT_PLAN/README.md`, and `documents/engineering/jit_artifact_doctrine.md`

### Objective

Give every artifact amoebius emits a type, a recipe, and a name that is a total function of what it contains.

### Deliverables

- A closed `Target` set indexing artifact kinds, so a consumer expecting one kind cannot be handed another.
- A `Recipe` as a pure function from a declaration to rendered content, with no clock, environment or directory read.
- An address digesting target, recipe identity, declaration and the rendered bytes together.
- A region whose exit reaps every artifact materialized inside it and not promoted to retained.

### Validation

Two independently seeded clean processes render each target and must agree byte for byte; an artifact
referenced after its region ends fails to compile.

**Both are checked where they can actually fail, which is not where the suite runs.** The determinism claim is
one a single process structurally cannot settle: it shares whatever ambient state a recipe reached for, so it
would agree with itself. The suite therefore prints its renderings and the gate runs it twice, comparing the
two reports.

The recipe API is pure and admits no effect capability. The applied ambient-input production mutant folds the
independently supplied seed into rendered bytes; two clean reports remain equal while the mutant reports must
differ. This gives the outside supervisor a deterministic, replayable observation of the prohibited dimension
without reading environment, clock, or working-directory state itself.

The escape claim is a type-level one, so it is a checked `.hs` compile-fail pair typechecked under `-fno-code`
rather than a test that runs. Its separately authored Haskell oracle requires the rejection to name the rigid
type variable rather than merely to fail
([§M.8](development_plan_gate_integrity.md#m8-paired-negatives-assert-an-exact-reason-at-an-exact-locus)); any
serialized diagnostic is a lazy `.build/**` observation. It carries a weaken-the-constraint mutant that
relaxes the region's rank-2 skolem, under which the illegal twin must compile and only then.

The address selector drops rendered bytes from the four-input production digest and must redden exactly the
independent rendered-content case. The region selector weakens the rank-2 skolem and must make the illegal twin
compile. Together with the ambient-recipe selector these are reconciled as the phase's fixed three-member
changed-production matrix.

### Remaining Work

The implementation and phase-local evidence contract are complete. The phase remains Active until the exact
Phase-2 predecessor receipt is refreshed for the final source identity and the integrated Phase-3 gate passes.
The budget a materialization spends is the next calculus's explicit residue; nothing here observes a running
system.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md)

**Cross-references to add:**

- [`phase_04_budget_calculus.md`](phase_04_budget_calculus.md) consumes artifact materialization as its typed input.

## Related Documents

- [Development Plan](README.md)
- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md) — the rule behind the artifact calculus.
