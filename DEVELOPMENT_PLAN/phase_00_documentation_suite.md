# Phase 0: Documentation, source policy, and validation baseline

> **Purpose**: Establish one coherent documentation corpus, the closed Haskell source boundary, the qualified
> Haskell gate kernel, and gate-pass completion before any product phase opens.
> **Read this if**: Phase 0 is active, a cross-cutting rule changes, or later work needs to know what its gate
> must establish first.

Phase 0 owns the repository's documentary and validation floor. It does not validate the DSL or any runtime
capability; Phase 49 owns the complete no-hardware DSL barrier. It makes those later claims possible without
trusting Python wrappers, tracked generated fixtures, self-reported evidence, or historical status.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, documents/documentation_standards.md, documents/engineering/migration_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 0.1: One documentary policy surface 🔄](#sprint-01-one-documentary-policy-surface-)
- [Sprint 0.2: One active legacy register ⏸️](#sprint-02-one-active-legacy-register-)
- [Sprint 0.3: Haskell source-closure classifier ⏸️](#sprint-03-haskell-source-closure-classifier-)
- [Sprint 0.4: Haskell documentation and plan-contract checker ⏸️](#sprint-04-haskell-documentation-and-plan-contract-checker-)
- [Sprint 0.5: Gate-kernel qualification and spoof corpus ⏸️](#sprint-05-gate-kernel-qualification-and-spoof-corpus-)
- [Sprint 0.6: Candidate evidence and gate-pass result ⏸️](#sprint-06-candidate-evidence-and-gate-pass-result-)
- [Sprint 0.7: Check all numbered phase contracts ⏸️](#sprint-07-check-all-numbered-phase-contracts-)
- [Sprint 0.8: Integrated Phase-0 candidate ⏸️](#sprint-08-integrated-phase-0-candidate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

🔄 Active — NOT VALIDATED.

The reset status is exact: Phase 0 is Active — NOT VALIDATED; every Phase 1 through Phase 95 is Blocked — NOT
VALIDATED; and every sprint in every phase is NOT VALIDATED. Every prior completion statement or implementation
result is invalid as a current gate result. Existing machinery is an **Observed footprint / Known partial**. This phase is active
only for the documentation, tracked-source, and validation-policy reset. No later implementation or phase gate
may open until the complete qualified Phase-0 gate passes and its status-only result is recorded.

---

## Phase Summary

Phase 0 makes the repository say one thing in one place and installs the mechanism that can refuse future
drift. The reset fixes these target decisions without claiming they are validated: behavioural source is Haskell; `pb/**` is the only non-Haskell
source exception and only bootstraps/execs Haskell; every reproducible non-Haskell artifact is generated lazily
beneath `.build/**`; the in-cluster OCI service is exclusively Distribution `registry:2`; one
active legacy register replaces every archive; and every phase is NOT VALIDATED until gate pass in
strict numerical order.

An **Observed footprint / Known partial** of the target Haskell validation kernel now exists beneath
`src/validation-kernel/Amoebius/Validation/**`. It includes the typed cross-cutting policy contract, source
closure, legacy-register, documentation, phase-contract, qualification-report, candidate-evidence,
gate-pass verification, and dispatch modules. The
component-oracle footprint is beneath `test/validation-kernel/**`. The tracked tree now contains exactly one
`pb/__main__.py` blob at 4,770 bytes with SHA-256
`e210494d3ad4bcaad716daed5bb89cb5611107547e83eb018a6369e134cd5418`. That exact inventory removes the
superseded index/worktree mismatch but does not acquire or statically admit the source, so `LTD-SRC-008`
remains open. Token scanning cannot prove the absence of hidden Python behavior, so Phase 0 must
statically prove the exact minimal-platform-discrimination,
contained-toolchain-establishment, source-bound-build, opaque-exec source graph before `pb` may remain as the
sole non-Haskell source exception. That source-admission proof does not claim the handoff ran; Phase 50 alone
owns its external runtime observation. A linked-GHC parser/renamer/typechecker and conservative consumer/effect
adapter footprint exists, but the 2026-08-23 adversarial integration check rejected its candidate path. The
gate must capture the exact local source bytes it builds, bind all observations to that snapshot, and recheck
those bytes before recording a pass;
replacement-race, raw-closure, and executable-mask mutants remain required. The compiler adapter hardening
remains in progress after the same check found that component
plans and unsupported facts were overclaimed. Current compiler bytes now require one exact Cabal component,
two-way subject assignment, exact applied GHC2024/source-directory configuration, and typed per-subject evidence;
focused clean, drop-subject, missing-Cabal, and configuration-drift diagnostics behaved as intended. Only parse,
no-preprocessing, no-compile-time-execution, and rename facts are established; calls, control flow, effects,
provenance, behavior sinks, and dynamic loading remain explicit unestablished residue. Its immutable tracked
regular-file reads and authored-root walk are descriptor-pinned, its final index binding observes concealment
flags, and present contained-state roots remain explicit external-observer residue. All of this remains
same-workstream component work that has not been independently qualified or externally observed.

A 2026-08-23 supporting `cabal build lib:validation-kernel test:validation-kernel-component` diagnostic and
unmutated `cabal test validation-kernel-component` component diagnostic earlier completed with fourteen named
component oracles. The aggregate runner now contains seventeen named component oracles: the eighteenth,
`PhaseContractInternalOracle`, moved to its own `validation-phase-contract-internal-component` suite. The
2026-08-26 aggregate reached the then-eighteen and every oracle reported its bounded diagnostic expectations
met after the documentation-header repair. This is neither qualification nor candidate evidence. In each earlier separate build
that widened the compiled Registry-provider universe, redirected the compiled owner map, or admitted `pb` as
transport before Phase 50, the runner executed all nine named component oracles; only `PolicyContractOracle`
failed. The other eight oracles stayed green. Those observations establish only
compilation and component behaviour; they are not harness qualification, complete gate execution, clean-room
observation, a Phase-0 candidate, or validation. The dispatcher intentionally refuses a
candidate because the fixed sabotage corpus has not been executed against its exact build, gate-result
integration is absent, no clean-room run is connected, and the evidence writer is
not integrated. Its candidate schema also lacks closed typed command, toolchain, substrate, run-identity, and
cleanup fields. A dirty worktree is admissible only when the gate snapshots and tests its exact bytes and
detects any change during the run. In the
current corpus, all 96 phase contracts contain 1,728 exact-prefix `UNRESOLVED` gate cells. The former 92 generic
`MISSING` predecessor cells now specify typed `ImmediatePredecessorPass` inputs and separately require the
candidate to refuse absent or stale runtime evidence. All 270 sprint sections now have the exact ordered reset
schema and immediate plan edge; unresolved implementation, oracle, validation, legacy, and documentation
bindings remain explicit rather than being guessed. Two independent read-only audits found no structural
schema or blocker-edge mismatch across the 262 later-phase sprints. These specification corrections are not
validation. Phase 0 therefore remains Active — NOT VALIDATED, and Phase 1 remains shut.

On 2026-08-29 a new serialized development diagnostic compiled the current 34-module validation library and
20-module aggregate runner through a development-only package projection beneath ignored `.build/**`; all
then-registered component oracles again reported their bounded expectations met. This projection avoided the authored
monolithic package's cold dependency-solver cost but is not the authored package boundary, pinned toolchain
input, qualification harness, clean-room candidate, source snapshot integrity, complete gate execution, or
phase-gate evidence. It changes no readiness finding and leaves every status NOT VALIDATED.

Later on 2026-08-29 the gate kernel's unconditional refusals were replaced by predicates over evidence, at the
authored package boundary and with `--jobs=1` throughout. `Amoebius.Validation.PhaseSemanticContract` no longer
requires the registry to hold exactly 1,728 `ContractGap` slots while simultaneously refusing any slot that is
not one; `ContractSlot` is now the `ContractGap`/`BoundSpecification` pair that
[development_plan_gate_integrity.md §M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass)
names, slot identity is checked on the slot's own ordinal and category rather than on its being unbound, and a
gap is fatal at or below the phase under validation while a gap above it is an explicit deferred-gap
observation. `Amoebius.Validation.Dispatch` replaces the nine constant Phase-0 readiness findings with a
predicate over a typed `PhaseReadiness` record whose fields are all currently unobserved, so the emitted
findings are unchanged while each row can now be retired by supplying its evidence; and `validatePhase` no
longer refuses every later phase by constant, instead re-deriving gates 0..N at the current snapshot and
reporting `DISPATCH-PHASE-SUBJECT-ABSENT` for a phase whose production subject does not exist. The
seventeen-oracle aggregate, the phase-contract, phase-contract-internal, source-debt-internal, and
compiler-source-graph-acquired component suites all report their bounded expectations met after their
independent expectations were re-authored. This is a structural change to what the kernel can express: it is
neither qualification, clean-room observation, candidate evidence, nor a gate run, and every status remains
NOT VALIDATED. No slot is bound, so all eighteen Phase-0 semantic slots remain `ContractGap` and the Phase-0
candidate remains RED.

The same 2026-08-29 session then implemented the first executable `LegacyClosureRule` predicate in the
repository. `CloseInfernixSeedDependency` and `CloseJitMlSeedDependency` were bare constructors whose meaning
existed only as prose in the reader-facing register, so neither binding could be decided in either direction.
`Amoebius.Validation.Legacy` now derives both from the captured snapshot — counting upstream-fetch stanzas in
`cabal.project` and tracked modules beneath the seed's authored namespace root — and binds the locus set by a
domain-separated digest. The analyzer observes only on the acquired path; a caller-authored snapshot refuses,
matching the source-debt bindings, so a supplied snapshot cannot manufacture a closed seed binding. The
integrated run observes seven open loci for `LTD-SEED-001` and one for `LTD-SEED-002`, and the Phase-0 refusal
inventory is unchanged at 2,176 across 28 codes. This makes two previously silent later-owned bindings
measurable; it closes nothing, and every status remains NOT VALIDATED.

The same session then removed the ordinal hard-coding that made the plan's order expensive to change, without
changing any ordinal. `Amoebius.Validation.PolicyContract` gained a fifth `PhaseRole`, `RegistryBoundary`, so
all five semantic cuts are named by role; `PhaseSemanticContract` reads every cut through `phaseRoleOrdinal`
rather than from the literals 49/50/51/52/56, including `executionStageFor`, `stageMatchesOrdinal` and the
guard table, whose literal patterns became role-keyed guards with every changed-production mutant preserved.
`Amoebius.Validation.PhaseIdentity` gained the reverse projection `lookupCapabilityOrdinal`, and both
`legacyIdOwner` and the resource-provision requirement set are now keyed by phase capability with the ordinal
derived: 50 ordinal literals in the legacy owner table and 55 in the resource set became capability names, and
an owner or requirement naming a capability no phase provides is reported rather than silently absorbed. Every
one of these is ordinal-equal by construction, so the integrated refusal inventory is unchanged at 2,176 across
28 codes and `LTD-SEED-001@91` still resolves.

The four hand-copied mutation-selector command lines were also collapsed into one `SelectorCli` module. The
copies had drifted: three defaulted a bare invocation to `--all` and one failed, two spelled the exact-case
listing `--cases` and one `--case-list`, and only some offered `--impacted` or `--control`. A selector harness
whose invocation grammar differs per suite cannot be driven uniformly, which is why the per-gate relevance rule
could not be applied across suites at all. Each suite now declares the operations it implements, an
unimplemented operation is refused by name instead of silently accepted, and `--impacted`/`--unaffected` behave
two-sidedly on all four suites. None of this is qualification, candidate evidence, or a gate run, and every
status remains NOT VALIDATED.

A typed capability relation now exists at `src/validation-kernel/Amoebius/Validation/CapabilityGraph.hs`.
The plan's declared dependency graph is clean — all 96 `Depends on` fields and all 270 sprint `Blocked by`
fields name only an immediate predecessor, with no forward edge — but that is not where the real dependencies
live. They live in deliverable, validation and gate-row prose, which
[development_plan_gate_integrity.md §M.1](development_plan_gate_integrity.md#m1-the-fixed-gate-contract) forbids
any checker from interpreting, so the plan's own forward-dependency check cannot reach them. The relation
states, as typed values, which phase capability provides what and which consumes it. Twenty-five of the
twenty-nine provisions take their provider from the compiled legacy owner map rather than from a re-authored
ordinal, and each edge carries a witness that distinguishes a typed source from a claim proposed by plan prose.
It currently declares 67 edges over 50 of the 96 phases, of which 61 are confirmed and 6 proposed, and reports
63 that run backwards in the present order — the five calculi reaching the later compile-fail harness, four
from the toolchain phase, five from the layout phase, one documentation-phase toolchain requirement, one
boundary-phase generated-fake requirement, and forty-seven phases inheriting run-input closure from a later
owner.

**Nothing consumes this module.** The integrated refusal inventory is unchanged at 2,176 across 28 codes and no
capability finding reaches the gate. That is deliberate: the defects it reports are real today, and consuming
it before they are fixed would hold the gate red across several steps with no way to separate an expected red
from a regression — and the only relief for that is an allowlist, which is the spoof this reset exists to
remove. A separately authored `CapabilityGraphOracle` asserts the exact expected set instead, so a new forward
dependency fails and so does one that silently disappears. Declared coverage is 50 of 96 phases; the relation
is not complete and must not be read as though it were.

Five of the eight recorded ordering defects were then fixed in place, at today's ordinals, with the capability
relation re-run after each. `LTD-VAL-006` moved from Phase 47 to Phase 0, which removed 47 backward edges in
one typed edit and, because the binding is now due at the candidate phase, added one refusal: the integrated
inventory is 2,177 across 28 codes and `LEGACY-OBSERVATION-REFUSED` rises from 14 to 15. That is the intended
trade — hidden later-owned debt became a visible Phase-0 obligation. The Phase-2 layout claim was narrowed from
absolute absence of generated foreign products, which is false at its ordinal, to what it can two-sidedly
observe; the Phase-1 toolchain claim dropped project-schema rendering and the seed-freedom assertion, the
latter because cabal fetches both `source-repository-package` stanzas at configure time regardless of ordering,
so no reordering could have made it true; and the stale Proto-owner reference in `phase_02` was corrected from
Phase 67 to Phase 26, the owner the compiled inventory names, before any renumber could make a reference from
an older numbering silently worse. The relation now reports 7 backward edges, down from 63.

Fixing those exposed a defect that was previously invisible. With run-input closure owned at Phase 0, the
documentation phase both provides it and consumes the pinned toolchain from Phase 1, which consumes run-input
closure back — a two-node cycle the relation now reports at an exact locus. It is not new; it is the
trusting-trust bootstrap that was always there, and it stays until it is minted as an owned binding. The
capability module still has no consumers, so none of this reddens a gate.

The sixth defect was closed by minting `LTD-BOOT-001` into the legacy universe, which grows from 25 to 26
constructors with its own analyzer, observation rule, closure rule and reintroduction case. The bootstrap cycle
the capability relation exposed is a trusting-trust dependency, not a misordering: Phase 0's command needs a
pinned toolchain input, which is the toolchain phase's own claim, and no arrangement of the phases removes that
because something must compile the thing that checks. It is therefore owned rather than dissolved. The binding
is due at its owner, so its unimplemented analyzer refuses and the integrated inventory rises to 2,178 across
28 codes; the bootstrap edge in the capability relation now carries a typed owner witness instead of a claim
read out of plan prose, leaving 101 confirmed and 5 proposed edges. What was an unstated axiom is now a
declared, closable obligation with an independently authored negative to write.

This closes the six in-place ordering fixes. Two ordering defects remain, both relocations rather than
narrowings — the compile-fail harness that five calculi consume, and the generation harness the boundary phase
consumes — and both belong to the rebalance rather than to a claim edit. The capability module still has no
consumers, so none of the seven remaining backward edges reddens a gate.

A proposed plan revision now exists as typed values at
`src/validation-kernel/Amoebius/Validation/PlanRevision.hs`, held dormant beside the identity table the gate
actually reads. It states a ninety-one-phase arrangement and the complete old-to-new audit map that
[development_plan_phase_model.md §E](development_plan_phase_model.md#e-one-canonical-phase-model) requires of
any reordering: ninety-six old phases become ninety-one through eight splits and ten merged capabilities,
every old ordinal is covered exactly once, and every revised capability is reached. The nine bands each occupy
one contiguous range.

Two results are worth recording. First, applying the §O merge rule as a computed predicate rather than an
asserted one rejected a merge that had been proposed for the two Register-2 UI phases: they agree on register,
substrate and lane but not on whether they must declare a resource-provision contract, and that fourth
conjunct is part of the rule. Second, the four role-bearing phases — the hardware-free barrier, the bounded
handoff, the Haskell host ensure and the first hardware validation — stay at 49, 50, 51 and 52, because the
splits above them and the merges below them cancel exactly. The revision moves no semantic cut.

On 2026-08-30 that sprint-sufficiency check was found to be wrong and was replaced. It compared one parent's
sprint budget against the number of capabilities it becomes, which ignores that a capability formed by a merge
draws sprints from any of its parents. The single reported deficit was the pair `{P46, P47}` becoming
`generation_harness` and `ui_contract_and_tool_corpus` — two parents, two sprints, two capabilities, and
feasible. Sufficiency is now computed over each connected component of the parent-and-capability graph:
eighty-two components, none infeasible, so all 270 sprints redistribute across the ninety-one capabilities with
no new sprint body authored. The tool-and-mutant phase remains the one genuine authoring item, because its
single sprint body divides at `Tools.hs` against `TestCorpus.hs`.

Replacing that check exposed a real defect it could not see. Sprint `Blocked by` chains are linear, so
projecting a split through the chain yields a phase edge from the owner of each sprint to the owner of the
next; the split stays acyclic exactly when every capability's sprints form a contiguous run. Three of the eight
splits had been cut by subject rather than by sprint order — Phase 0 three ways over sprints {1,4,7}, {2,3} and
{5,6,8}, Phase 1 as {1,6,7,8} against {2,3,4,5}, and Phase 2 as {1,4,5} against {2,3,6} — and each would have
manufactured a dependency edge running backwards between the very phases the split creates, which is the defect
the revision exists to remove. All three were re-cut at contiguous seams and renamed accordingly, and
`REVISION-SPLIT-DISCONTIGUOUS` now refuses any assignment that is not a contiguous run. Nothing consumes this
module, the present ninety-six-row table remains authoritative, and the integrated inventory is unchanged at
2,178 across 28 codes.

The same 2026-08-30 session made the mutation corpus executable and then measured how little of it was. Two
selector drivers were exported and never called from any `Main.hs`: a 659-locus registry over the Cabal
component plan and a 374-locus registry over the `pb` bootstrap grammar. Their flags existed, their production
guards existed, and the two-way registry reconciliation was exact — but no Cabal stanza could reach them, so
none of the 1,033 mutants could be run. Both now have a suite driven by the shared `SelectorCli`, and both were
verified two-sidedly against the source-built binary: with a mutant set, its own `--impacted` passes because
its declared case reddened, `--unaffected` passes because the others stayed green, `--all` reddens, and a
different selector's `--impacted` fails because the reddening is attributed to the selector that caused it
rather than to any selector. That last property is what separates a mutation registry from a rubber stamp.
Executable loci rose from 151 to 1,184.

Measuring the remainder produced a new standing refusal. The kernel declares 5,712 guarded mutation loci and
five suites between them can execute 1,184, so 4,528 change production under a flag with nothing observing the
change. A locus counted that way reports coverage it does not carry, which is exactly the criticism
`LTD-VAL-002` records. `Amoebius.Validation.MutationCoverage` states the corpus and the driving suites as typed
values, `MutationCoverageOracle` restates both independently, and `MUTANT-UNWIRED` reports the difference
against the capability that owns it. Closing a locus needs an exact case that observes the changed production,
an intent row and an impact row; a flag declaration supplies none of the three, so the count is an obligation
rather than a number to be reduced by deleting flags. The fourteen `LTD-BOOT-001` mutants minted the previous
day were also given their Cabal flags, which is what moved the declared corpus to 5,712. The integrated
inventory is now 2,179 across 29 codes, and every status remains NOT VALIDATED.

Six hard-coded phase-domain literals were then replaced by derivations of the policy contract, each
byte-identical today. `DISPATCH-PHASE-RANGE` and `LEGACY-PHASE-RANGE` had spelled out "00 through 95" beside
code that already derived the same label; the tracker-row, ordinal-domain and resource-domain messages had
spelled out 96, `0..95` and 96 likewise. A seventh change is not a derivation but a new check. The join module
carries its own hand-written ninety-six-entry phase-path table that nothing ever compared against the identity
table's projected paths: the two agreed only because both happened to be right, and a drift would have appeared
as one missing and one unknown finding per affected phase rather than as the single fact that the tables
disagree. `PLAN-SEMANTIC-PATH-TABLE-DISAGREEMENT` now asserts their equality while keeping both authorships.
The integrated inventory is unchanged at 2,179 across 29 codes and the new code does not fire.

An earlier 2026-08-23 Sprint-0.2 clean-plus-thirteen component matrix remains stale. Sprint 0.3 exposed and
corrected a lifecycle sequencing error: an Active zero must be admissible at the exact owning-phase candidate,
while refusing before the owner as a missing finding and after the owner as an unrecorded post-pass transition.
That production/oracle change invalidated the prior byte witnesses and matrix result. On current bytes a fresh
warning-clean direct build and clean oracle completed, followed by twenty isolated changed-production builds;
all twenty compiled and reddened their exact inventory, encoding, owner/lifecycle, dispatch, analyzer, source-map,
or diagnostic/evidence-boundary controls. The Cabal registry contains one exact mapping for each selected macro. These
runs still lack applied source and binary witnesses, same-harness unaffected controls, source snapshot integrity,
harness qualification, and the integrated dispatcher/evidence path; they are not a candidate or validation.

**Phase scope:** one cohesive claim — the governed corpus conforms to the single-source policies, the source
snapshot is completely partitioned, and every violation joins in both directions to a typed Haskell legacy
binding whose owner is either due now or strictly later. A Phase-0 candidate requires every due binding to be
zero and the Haskell validation kernel to reject the fixed spoof corpus. The reader-facing register is not a
join input. It splits if product or live-infrastructure behaviour is required.
**Substrate:** `none`
**Lane:** `none`
**Register:** —
**Depends on:** genesis
**Gate:** `pb validate phase 00`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REWRITTEN — NOT VALIDATED; an implementation footprint exists, but qualification,
clean-room observation, evidence integration, independent complete gate execution, and gate-result integration remain open.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: The governed corpus has one structural owner/link surface, one closed Haskell source policy, and one qualified phase gate. Every required row must pass for the exact current source snapshot; the Markdown legacy register remains reader-facing and cannot alter executable semantics. |
| `Subject` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: The source-bound Haskell dispatcher captures the exact local source snapshot, runs `SourceClosure`, `CompilerSourceGraph`, `Legacy`, `PolicyContract`, `Documentation`, `PhaseContract`, harness qualification, evidence writing, and `GatePass.verifyGatePass`. Raw caller-constructed snapshots and component diagnostics are not phase-gate subjects. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Future public target: `pb validate phase 00`. Before Phase 50 passes, build and invoke the exact absolute source-bound Haskell executable directly from a pinned, network-independent toolchain input. The Haskell binary owns discovery, observations, schema checks, and the verdict. |
| `Oracle` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Separate Haskell oracle modules under `test/validation-kernel/` state expectations without importing subject decision logic. The integrated runner must execute every named oracle and retain its raw result; the raw results need no additional status field. |
| `Positive controls` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: The complete governed document graph, exact local source snapshot, closed policy universes, source partition, and phase-contract registry all pass through production entry points and independently authored expectations. |
| `Paired negatives` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Minimally different pairs cover document/link/status defects, source-boundary violations, disguised behavior, snapshot changes during execution, missing or altered source entries, malformed gate rows, missing predecessors, stale candidate digests, partial evidence, red required rows, and widened status projections. Each pair pins an exact reason and locus. |
| `Mutants` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Changed-production subjects weaken one source, policy, document, contract, qualification, evidence, or gate-pass predicate at a time. The assigned oracle row must red at the named locus while unrelated same-harness controls remain green. |
| `Discovery` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: The Haskell kernel enumerates all tracked paths and all governed Markdown at run time and joins each in both directions to independently derived expectations. Zero files, a missing root, an unclassified path, a duplicate path, or an unexpected governed file refuses the run. |
| `Challenge` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Pure policy and document claims use independently authored predicates and run-local sabotage selection. Source freshness is established by capturing exact local bytes at gate start and rejecting any byte, mode, path, or inventory change before the result is recorded. |
| `Observer` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Component oracles inspect raw snapshot bytes, modes, shebangs, path inventory, metadata, links, dependencies, status fields, and gate-table shape instead of accepting a classifier summary. The source snapshot is captured locally at gate start and independently rehashed before the result is recorded. Missing or partial observations fail. |
| `Authority/bypass` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Bypass probes cover extensionless files, misleading extensions, executable bits, shebangs, symlinks, ignored inputs, generated copies, widened `pb` behavior, policy-looking prose decoys, local snapshot replacement, raw snapshot construction, stale predecessor results, partial evidence, and widened status projections. |
| `Freshness` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: The candidate captures a new exact local source snapshot and uses a fresh run root with generated and state roots absent. It rejects source changes during execution, prior evidence, cached discovery, ignored behavioral inputs, copied status, and results bound to another source or contract. |
| `Qualification` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Before the clean run, the same Haskell harness must reject constant success, no-op subject, wrong output, empty discovery, missing subject/oracle, skipped/no-op mutant, wrong-locus failure, stale evidence, self-observer, authority bypass, residue, and smuggled generated/legacy input. |
| `Cleanroom` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Start with `.build/**`, `.data/**`, `.test_data/**`, source-adjacent caches, and condemned legacy copies absent. Generate compiler output, synthetic corpora, observations, and candidate evidence beneath one `.build/runs/phase-00/**` root. A dirty worktree is allowed only when its exact bytes are captured, tested, and unchanged throughout the run. |
| `Legacy closure` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Sprint 0.2 separately pins the closed 25-ID Haskell inventory, total owner/lifecycle/required-analyzer bindings, and total fail-closed dispatch; independent gate evidence remains absent. Every canonical disposition is currently Active, and this sprint does not make an owner-domain query zero or claim an executed reintroduction guard. The owning sprint supplies each typed observation/closure analyzer and domain reintroduction negative; an absent analyzer, missing negative, or open due query refuses. Sprint 0.8 is the first point at which all Phase-0-owned queries—`LTD-SRC-000`, `LTD-SRC-008`, and `LTD-VAL-001` through `LTD-VAL-004`—must jointly be zero, alongside the complete source partition, frozen later-owned source fingerprints, and an exact non-empty static `PbBootstrapGrammar` AST/import/resolved-call/control-flow/potential-effect proof. Runtime effect, executable-identity, unchanged-argv, and exec-replacement evidence is explicitly excluded and remains Phase-50 residue. An Active zero is accepted only at the exact owning-phase candidate; it refuses before that owner as stale/missing debt and after it as a missing post-pass transition. Gate pass precedes the successor-phase source transition to Retired, and the qualified negative remains compiled. The structural seam requires one canonical regular non-executable UTF-8 register, no second exact canonical basename, and no exact forbidden archive basename; it does not infer arbitrary semantic aliases. The general documentation checker may enforce ordinary structure plus its basename-substring cardinality and forbidden-archive-basename content diagnostics. Neither may interpret Markdown row content as a binding or verdict. Complete gate execution owns correspondence at the integrated phase gate. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `genesis`; there is no prior numbered phase. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `UNVERIFIED`: unfinished qualification execution, clean-room integration, exact local-snapshot capture and recheck, evidence publication, remaining semantic phase-contract slots and resource fields, owner-sprint analyzers, later-owned source migrations, and every product, DSL, provider, hardware, and runtime claim owned by later phases. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- [`documentation_standards.md` §1 — philosophy](../documents/documentation_standards.md#1-philosophy) — one documentary authority,
  required metadata, link-graph reconciliation, and no current validation claims in doctrine.
- [`repository_layout_doctrine.md` §2 — complete repository structure](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) — the closed
  Haskell source tree, bounded `pb/**`, and lazy `.build/**` generation.
- [`testing_spoof_resistance.md` §12 — spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence) — qualification,
  changed-subject witnesses, external observation, residue, and the complete gate-pass criterion.
- [`conformance_harness_doctrine.md` §5 — the pre-hardware gate barrier](../documents/engineering/conformance_harness_doctrine.md#5-the-pre-hardware-gate-barrier) — the later
  no-hardware DSL barrier Phase 0 makes possible but does not claim.
- [`service_capability_doctrine.md` §3 — canonical providers](../documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific) — Distribution
  `registry:2` as the sole in-cluster OCI provider, with no alternate provider constructor.
- [`image_build_doctrine.md` §2 — the single distribution rule](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster) — the sole Registry image is
  separately pinned and preloaded rather than baked into `amoebius-base`.

## Sprints

## Sprint 0.1: One documentary policy surface 🔄

**Status**: Active — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/PolicyContract.hs`, `AGENTS.md`, `CLAUDE.md`, `README.md`, `documents/**/*.md`, and `DEVELOPMENT_PLAN/**/*.md`
**Blocked by**: `genesis`
**Independent Validation**: Separately restated closed constructor universes, typed values, bytes, digest, and owner headings pin the component positive control. Constructible negatives cover `pb`, status reset, owners, register/archive, and ordering at code, subject, and detail. In full aggregate runs, the Registry-universe, owner-map, and `pb`-transport production mutants each red only `PolicyContractOracle` while all eight unrelated named oracles execute green. Prose correspondence remains documentation-gate residue.
**Oracle**: `test/validation-kernel/PolicyContractOracle.hs`; integrated component diagnostic, not qualified-harness evidence or validation. Its independent check is consolidated into the Phase-0 gate; no sprint-level confirmation is requested.
**Legacy IDs**: none — zero-query policy-surface sprint; `LTD-VAL-002` through `LTD-VAL-004` remain owned by their later Phase-0 seams
**Docs to update**: all governed documentation owners touched by the reset

### Objective

Make the Haskell-only source boundary, `pb` exception, lazy generation, sole `registry:2` provider, separately
pinned/preloaded Registry-image placement, single active legacy register, validation reset, strict numerical
order, pre-hardware barrier, and qualified-gate pass agree everywhere.

### Deliverables

- One closed typed value, constructor universe, and exact decision-to-owner anchor for each cross-cutting decision.
- One versioned deterministic serialized contract and SHA-256 digest, independently restated by the component oracle.
- One canonical prose statement and backlinks for each cross-cutting decision.
- One typed reset keeping Phase 0 Active and every later phase Blocked, all explicitly NOT VALIDATED.
- One typed requirement that every `LTD-SRC-*` query is zero before the Phase-49 DSL barrier can open.
- Zero governed prose links or references treating the eliminated archive as a document; its exact path exists
  only as a typed forbidden target and in rejection diagnostics/negatives.
- One closed Haskell registry-provider constructor selecting Distribution `registry:2`, plus a distinct
  placement decision for its separately pinned/preloaded bootstrap image; complete gate execution confirms both exact
  doctrine owners and that the service-capability prose rejects every alternate provider.
- Phase 0 Active — NOT VALIDATED; Phases 1–95 Blocked — NOT VALIDATED.

### Validation

Run the unmutated policy component diagnostic and all three changed-production builds from isolated build roots. The
unmutated build must pass. The aggregate runner must execute all nine named oracles in every build. Each mutant
must fail only `PolicyContractOracle`; every unrelated oracle must execute and stay green. These are supporting
diagnostics, not qualification or validation.

```text
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-diagnostic --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-registry-mutant -fvalidation-policy-alternate-registry-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-owner-mutant -fvalidation-policy-owner-map-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-pb-transport-mutant -fvalidation-policy-pb-transport-mutant --test-show-details=direct
```

During the consolidated Phase-0 gate, the documentation check compares every typed value and owner anchor with
the prose diff and confirms that no Markdown keyword or machine-oriented projection can affect a behavioral
verdict. This is not a Sprint-0.1 confirmation point. Full corpus-shape validation remains owned by Sprint 0.4,
so Sprint 0.1 does not depend on a later sprint.

### Remaining Work

The unmutated, Registry-universe-mutant, owner-map-mutant, and `pb`-transport-mutant component diagnostics are
recorded and reproduce on 2026-08-23. They establish implementation readiness for Sprint 0.2 but are not the
qualified parent harness: applied-change and changed-binary witnesses remain Sprint-0.5 residue. Complete qualified gate
prose-correspondence inspection of every typed value and owner heading stays phase-gate residue. Sprint 0.1 remains
NOT VALIDATED until the qualified parent gate retains this seam and the pass criterion passes.
All Phase-0 oracle fields now state the same consolidated-check boundary: component diagnostics make the next
sprint implementation-ready, while one Phase-0 gate check covers the completed seam set. No intermediate
sprint confirmation is a blocker or status transition. This wording repair is not validation.

A 2026-08-24 selector audit has rejected Sprint 0.1's three-mutant claim as mutation-complete. The checker
compares twenty-eight closed constructor universes, eight compound contracts, eleven decision-owner rows, the
Registry selection/reference/placement predicates, and the complete serialized bytes/digest, but the production
declares only Registry-universe, owner-map, and `pb`-transport selectors. The Registry and transport macros also
occurred twice—once in the constructor universe and once in rendering—so they were not once-only changed-
production loci. Their renderers now use total ordinary comparisons and each of the three current macros occurs
once; clean and all three selected production modules compile warning-free. That source-level repair does not
make the matrix complete. An exact clean positive oracle can notice many edits, but without an atomic selector
and unaffected control for every independent universe, contract field, owner row, serializer field/order, and
digest binding, the harness has not demonstrated that those checks cannot be spoofed or masked. Sprint 0.1
needs a closed Haskell predicate/selector intent registry and a complete matrix before its prior component
diagnostics can enter the integrated candidate.

The same re-audit has also rejected the current PolicyContract package surface. It exports the complete record
model, constructors, selectors, canonical value, renderers, digest function, and an arbitrary
`checkPolicyContract :: PolicyContract -> CheckResult`; the oracle consequently fabricates record-update inputs
through the same production representation it is meant to check. This is neither an opaque subject boundary nor
an independently stated wire oracle. The model and all candidate-capable operations must move behind a package-
hidden implementation, the facade must expose only the smallest permanently refusing diagnostic required by
external consumers, every production consumer must use the hidden typed contract without reopening it publicly,
and actual-symbol compile-negative clients plus a public control must enforce that boundary. The three-row
selector registry remains only a rejected baseline until that privacy repair and the complete atomic registry
above are rerun.

The privacy repair is now implemented. The public package exposes only
`policyContractDiagnostic :: CheckResult`; the full model is package-hidden, and production consumers import
that internal module without reopening it publicly. The source, independently literal oracle registry, Cabal
flags, conditions, and `-D` mappings contain the same 194 unique selectors, each once in production. A strict
exact-project build, clean exact-result oracle, and independent control exit zero. All fifty-five actual-symbol
one-symbol package clients fail at their intended missing export, and the sole public-facade control passes.
The frozen-source 194-row matrix is complete: every row produced a distinct changed linked binary, every
assigned exact-result oracle reddened, every paired unaffected control stayed green, no build or target
resolution failed, and the source hashes remained stable. All fifty-five actual-symbol opacity clients still
fail at the intended missing export, the public-facade control still passes, and all nine production consumers
plus the independently raw-owned Documentation oracle compile against the repaired boundary. A final
atomic/opacity audit found no omitted production selector or reopened representation. Qualification,
source snapshot integrity, documentation-gate correspondence, and the integrated Phase-0 candidate remain open.
These are component diagnostics only and do not validate Sprint 0.1.

## Sprint 0.2: One active legacy register ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`, `src/validation-kernel/Amoebius/Validation/Legacy.hs`, `test/validation-kernel/LegacyOracle.hs`, `amoebius.cabal`
**Blocked by**: Sprint 0.1
**Independent Validation**: A structural Haskell check proves that the canonical reader-facing register is one tracked, non-executable regular UTF-8 file; no second occurrence of its exact basename and no occurrence of the exact forbidden archive basename is tracked. It does not claim to recognize an arbitrarily renamed semantic copy. The general documentation checker separately applies its governed-document structure rules, a basename-substring register-cardinality diagnostic, and a case-folded forbidden-archive-basename content diagnostic; those findings may change when Markdown changes. A separate oracle restates the exact 25-constructor Haskell ID universe, every closed binding-key universe, stable encodings, owners, the one-constructor Active lifecycle universe, required-analyzer routes, unavailable-analyzer refusals, and required reintroduction-case identities; independent authorship and integrated gate execution are not claimed. Twenty changed-production flags declare mutations of that typed inventory, parser, owner-boundary/lifecycle comparison, diagnostic route, dispatch surface, exact source-family join, and analyzer-execution boundary. Each must fail at its named locus when run, while owner-domain analyzers remain explicitly outside this sprint; an intentional Dispatch composition assertion may co-fail for a mutation that changes its observed legacy surface. Caller-constructible observations exist only behind a permanent diagnostic refusal; the candidate accepts a private snapshot/analyzer-bound evidence registry produced by one closed dispatcher. Any row/cell/ID/owner/count/predicate change remains inert only with respect to legacy binding and closure semantics. Component output is diagnostic only; prose correspondence is checked once at the integrated Phase-0 gate.
**Oracle**: `test/validation-kernel/LegacyOracle.hs`; it separately states the 25 bindings, closed key universes, exact parser grammar, the Active-only disposition universe, before-owner stale-zero refusal, exact-owner zero candidate readiness, post-owner missing-transition refusal, open/unavailable refusals at and beyond every owner, the exact nine-family `SourceDebtId`-to-`LegacyId` map, diagnostic/candidate separation, closed-registry completeness, and an ambient live diagnostic over the tracked index path/mode/object and indexed register blob bytes. The earlier 2026-08-23 clean-plus-thirteen result is invalidated. The current fresh clean direct build and oracle exited zero; all twenty isolated mutant builds, including the one-locus source-debt/Legacy correspondence swap and both diagnostic/evidence-boundary bypasses, compiled and red at their named controls. This remains a component diagnostic only. Separate oracle authorship and the consolidated Phase-0 correspondence gate remain absent.
**Legacy IDs**: all 25 typed identities — `LTD-SRC-000` through `LTD-SRC-009`, `LTD-META-001`, `LTD-VAL-001` through `LTD-VAL-006`, `LTD-DOC-001`, `LTD-NAME-001`, `LTD-HOST-001`, `LTD-HOST-002`, `LTD-IMG-001`, `LTD-RUN-001`, `LTD-SEED-001`, and `LTD-SEED-002`; inventory/delegation only, with no owner-domain closure claimed
**Docs to update**: `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `documents/engineering/migration_doctrine.md`

### Objective

Make current divergence actionable through one closed Haskell lifecycle inventory, one total fail-closed
dispatcher, and one non-executable reader-facing explanation, without pulling later analyzers into Phase 0 or
creating a second historical register.

### Deliverables

- One canonical active-only Markdown register whose rows explain current work to readers and cannot alter a
  legacy binding or closure verdict.
- A closed 26-constructor Haskell legacy-ID universe with unique stable encodings and total owner, lifecycle,
  required-analyzer, and dispatch bindings. Missing analyzer evidence always produces a typed unavailable state;
  it refuses at or beyond the owner and can never represent closure before then.
- One private candidate evidence type bound to the exact snapshot, row, and analyzer. Caller-authored lifecycle
  values and maps remain permanently refusal-marked diagnostics and cannot enter the candidate evaluator.
- One total, exhaustive `SourceDebtId`-to-`LegacyId` function and exact closed-registry key check.
- A required typed Haskell reintroduction-case identity for every ID. The owning analyzer must implement and
  qualify that negative before retirement; Sprint 0.2 does not claim executable guard coverage.
- Separately stated Haskell expectations and changed-production mutants for the inventory/dispatch surface, plus a
  documentation-gate correspondence-check obligation. Owner-domain analyzers and their semantic negatives remain work of
  the owning sprints.

### Validation

Missing or duplicated canonical paths, a second exact canonical basename, the exact forbidden archive
basename, non-UTF-8 bytes, executable mode, and symlink mode fail the legacy structural check without parsing
row semantics. Changed-production cases cover an omitted inventory projection, duplicate stable encoding,
wrong and missing owners, redirected analyzer binding, missing observation/closure/reintroduction bindings, a
skipped registry route, accepted due-but-unavailable evidence, an equality-only owner-boundary comparison,
an owner-tail comparison that stops refusing after the first post-owner phase, one widened parser alias, one
omitted source-family route, one zero substituted without executing the complete-source analyzer, two removed
diagnostic/evidence-boundary refusals, and one swapped source-debt/Legacy binding. Each must fail the
separately stated Haskell oracle at its exact locus while unrelated controls run. DispatchOracle intentionally checks
legacy composition, so a mutation that changes its observed ID count or Phase-0 unavailable-finding count may
also turn that composition oracle red for the corresponding reason. No constant refusal may substitute
for dispatch coverage: all 25 constructors must reach their separately expected analyzer keys and exact
unavailable states. Changing, adding, deleting, or duplicating a Markdown row, ID, owner cell,
predicate-shaped string, or count leaves legacy binding and closure outcomes unchanged. Documentation findings
may still change because that checker applies ordinary document rules, a basename-substring cardinality check,
and a forbidden-archive-basename content check. The consolidated Phase-0 complete gate execution separately rejects correspondence mismatch.
These are component diagnostics, not full harness qualification, owner-domain closure, phase validation, or
per-sprint sprint-level confirmation.

```text
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-diagnostic --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-drop-id-mutant -fvalidation-legacy-drop-id-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-duplicate-render-mutant -fvalidation-legacy-duplicate-render-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-wrong-owner-mutant -fvalidation-legacy-wrong-owner-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-missing-owner-mutant -fvalidation-legacy-missing-owner-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-dispatch-redirect-mutant -fvalidation-legacy-dispatch-redirect-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-missing-observation-mutant -fvalidation-legacy-missing-observation-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-missing-closure-mutant -fvalidation-legacy-missing-closure-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-missing-reintroduction-mutant -fvalidation-legacy-missing-reintroduction-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-dispatch-skip-mutant -fvalidation-legacy-dispatch-skip-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-source-map-omission-mutant -fvalidation-legacy-source-map-omission-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-analyzer-zero-substitution-mutant -fvalidation-legacy-analyzer-zero-substitution-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-accept-unavailable-mutant -fvalidation-legacy-accept-unavailable-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-owner-equality-mutant -fvalidation-legacy-owner-equality-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-owner-tail-acceptance-mutant -fvalidation-legacy-owner-tail-acceptance-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-parser-alias-mutant -fvalidation-legacy-parser-alias-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-reject-owner-zero-mutant -fvalidation-legacy-reject-owner-zero-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-accept-zero-any-phase-mutant -fvalidation-legacy-accept-zero-any-phase-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-diagnostic-bypass-mutant -fvalidation-legacy-diagnostic-bypass-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-snapshot-diagnostic-bypass-mutant -fvalidation-legacy-snapshot-diagnostic-bypass-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-source-debt-swap-mutant -fvalidation-legacy-source-debt-swap-mutant --test-show-details=direct
```

### Remaining Work

Sprint 0.3 corrected the Active-zero lifecycle boundary after finding that the prior evaluator made an owning
phase candidate impossible: it demanded the post-pass transition before the complete candidate could pass its gate.
The correction accepts zero only at the exact owner, rejects it before and after that point for distinct
reasons, and expands the separately stated oracle accordingly. An adversarial Sprint-0.3 check then found that
the exported model evaluator still let a caller fabricate an analyzer-tagged zero and that the source-family
join was an unchecked list. The implementation now separates permanently refused caller-authored diagnostics
from opaque snapshot/analyzer-bound candidate evidence, adds a total nine-family join, and declares independent
route-omission and analyzer-zero-substitution mutants. This invalidates the earlier clean-plus-thirteen byte and
execution observations; the replacement clean-plus-twenty direct diagnostic matrix now reds every named mutant,
but has no applied source/binary witness or qualified parent harness. Sprint 0.2 remains Blocked — NOT VALIDATED
until the integrated qualified parent candidate receives a passing complete gate. oracle independence, parent-harness qualification, and correspondence check remain Phase-0 gate residue.
Source-family measurement, classification, and baselines remain Sprint 0.3 work.
Owning sprints then implement the actual observation/closure analyzers and execute their domain reintroduction
negatives. No Phase-0-owned query is claimed zero here: `LTD-SRC-000`, `LTD-SRC-008`, and `LTD-VAL-001` through
`LTD-VAL-004` must first be delivered by Sprints 0.3 through 0.7 and may jointly reach zero only at the
integrated Sprint-0.8 candidate.

The same 2026-08-24 completeness standard reopens the twenty-mutant Legacy diagnostic. Twenty-five stable IDs
each own an encoding, phase owner, analyzer, observation rule, closure rule, disposition, and nonempty
reintroduction-case set, plus the nine-row source-debt correspondence. The current selectors alter only one
representative row for most field classes; they do not apply a changed-production witness to every literal row
and field that the oracle claims to freeze. In addition, the public module still exports `legacyCheck`,
`legacyCheckAcquired`, and `activeRegisterFromSnapshot` with package-hidden SourceClosure types in their
signatures. That surface is unusable to a real external client and caused `LegacyOracle` to import
`SourceClosure.Internal`, defeating the intended package-opacity test. The snapshot/acquired functions must
become private, the public diagnostic must accept bounded raw primitives, and the exact binding/selector
inventory must be two-way complete before Sprint 0.2 can rejoin the Phase-0 aggregate.

The replacement now has a package-hidden implementation and a raw refusal-only public facade. On 2026-08-26,
static reconciliation found 1,306 once-only selector identities across the public and hidden production modules,
the independently literal oracle registry, and both Cabal flag and `-D` mappings, with no set delta or duplicate.
A fixed serial matrix then rebuilt and linked exactly one row at a time from frozen inputs. All 1,306 rows changed
the preprocessed production subject, subject object, and executable; all 1,306 exited one at the assigned exact
oracle locus; every paired product control exited zero; no object or executable digest was duplicated; and the
final input hashes matched the start. The retained result-table SHA-256 is
`0c16db3d89364ef1e25ba9634b380e27afba6b71879851a4185dffacc03a7c3e`; the diagnostic summary SHA-256 is
`d1d629814e48dbc8f91c1359cf5db23dae97a5224a3f2ef8e6b12a4c5e0f3453`. Against the actual Cabal-installed
package boundary, all 36 one-symbol/Internal-module clients failed for the exact missing-export or hidden-module
reason and the refusal-only public control compiled; its result table has SHA-256
`8f18d163465be173511b9be41eed4db830fba86c088521a3e99e86d49dcbac82`. This establishes component
implementation readiness for Sprint 0.3, not validation: parent-harness qualification, exact local inputs,
source snapshot integrity, documentation-gate correspondence inspection, and the integrated Phase-0 candidate remain open. Sprint 0.2
therefore remains Blocked — NOT VALIDATED.

## Sprint 0.3: Haskell source-closure classifier ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/SourceSnapshot/Internal.hs`, `src/validation-kernel/Amoebius/Validation/SourceClosure.hs`, `src/validation-kernel/Amoebius/Validation/SourceConsumerGraph.hs`, `src/validation-kernel/Amoebius/Validation/SourceDebtBaseline.hs`, `src/validation-kernel/Amoebius/Validation/PbBootstrapGrammar.hs`, `src/validation-kernel/Amoebius/Validation/CompilerBuildInfo.hs`, `src/validation-kernel/Amoebius/Validation/CompilerComponentPlan.hs`, `src/validation-kernel/Amoebius/Validation/CompilerElaboratedPlan.hs`, and `src/validation-kernel/Amoebius/Validation/CompilerSourceGraph.hs`
**Blocked by**: Sprint 0.2
**Independent Validation**: Capture every local source path, mode, and byte sequence before the build; classify every tracked path exactly once; reject every unbound, duplicate, due, or wrongly owned source-boundary finding; and re-read the complete captured surface before recording the result so a mid-run source change fails. A dirty worktree is admissible when those exact bytes are the tested candidate.
**Oracle**: Separate Haskell oracles for `SourceClosure`, `SourceConsumerGraph`, `SourceDebtBaseline`, `PbBootstrapGrammar`, `CompilerBuildInfo`, `CompilerComponentPlan`, `CompilerElaboratedPlan`, and `CompilerSourceGraph`; none imports the subject decision logic.
**Legacy IDs**: `LTD-SRC-000`, `LTD-SRC-008`
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Turn the closed tracked-source grammar and exact current worktree into a semantic Haskell check that renaming or replacement cannot bypass.

### Deliverables

- A complete local source-snapshot partition over exact paths, modes, and bytes.
- Start/end snapshot equality so the result applies to precisely the source that was built and tested.
- Exact later-owned finding-to-Haskell-binding equality.
- Exact non-empty deny-by-default `pb/**` authored AST/import/resolved-call/control-flow/potential-effect graph.
- Lazy-output and authored-root write checks.
- No additional source-attestation service; start/end equality of the captured local snapshot is the source-freshness rule.

### Validation

Paired cases cover `.hs`, admitted non-code inputs, each `pb` bootstrap role, disguised Python or shell, executable data, shebang source, behavioral metadata, source-adjacent caches, generated output under authored roots, missing and extra paths, byte/mode changes, empty discovery, and a source replacement between the initial capture and final recheck. Every changed-production selector must red its assigned exact case while same-harness unaffected controls remain green.

### Remaining Work

The dispatcher now captures and rechecks the exact local snapshot, and component oracles cover replacement refusal. Qualify the selector matrices, connect the exact compiler/source observations to the evidence bundle, and run the integrated Phase-0 gate. Existing component diagnostics remain useful implementation observations but are not the complete Phase-0 gate.

## Sprint 0.4: Haskell documentation and plan-contract checker ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Documentation.hs`, `src/validation-kernel/Amoebius/Validation/PhaseContract.hs`, internal `src/validation-kernel/Amoebius/Validation/PhaseIdentity.hs`, `src/validation-kernel/Amoebius/Validation/PhaseSemanticContract.hs`, `src/validation-kernel/Amoebius/Validation/PhaseSemanticJoin.hs`, and `src/validation-kernel/Amoebius/Validation/ResourceProvisionContract.hs`
**Blocked by**: Sprint 0.3
**Independent Validation**: Complete structural component corpora are accepted and minimally different dependency, inventory, raw-status, retired-path, wildcard, fence, comment, and line-wrap defects are refused at exact loci. The Haskell prose-budget oracle independently states an exact 50-word sentence in single-line and hard-wrapped forms, a seven-sentence paragraph, and table/fence exemptions. Physical-line and measurement-omission production mutants must red those exact controls. The current documentation selector registry has a complete nine-row changed-subject component bracket. PhaseContract's production source, two independently literal oracle partitions, Cabal flags, and CPP mappings reconcile at 142 reachable selectors: 134 structural selectors with 134 exact cases and eight internal full-mode selectors with eight exact cases. Fresh fixed-serial brackets from the current bytes completed all 17,956 structural and 64 internal cross-impact classifications with distinct changed preprocessing, object, and linked-executable identities, matching final clean controls, stable frozen inputs, and pairwise-unique mutant identities. The internal partition pins the semantic observation/finding carriers, three semantic routes, checked sprint-inventory retention, and duplicate-path selection/rendering. The earlier 119-row package boundary is stale, and attempts to build the new internal suite did not leave dependency resolution, so refreshed package evidence, the remaining atomic inventory, qualification, and semantic policy/prose correspondence remain open.
**Oracle**: `test/validation-kernel/DocumentationOracle.hs`, `test/validation-kernel/PhaseContractOracle.hs`, `test/validation-kernel/PhaseContractInternalOracle.hs`, and `test/validation-kernel/PhaseSemanticContractOracle.hs`; separately authored component diagnostics whose independent check is consolidated into the Phase-0 gate, not requested per sprint.
**Legacy IDs**: `LTD-VAL-001`, `LTD-VAL-002`
**Docs to update**: `documents/documentation_standards.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`

### Objective

Replace Python and token-presence checks with typed structural validation whose negative corpus exercises only
machine-decidable document structure. Executable cross-cutting policy lives in `PolicyContract`; prose
correspondence remains complete gate execution.

### Deliverables

- Governed inventory, metadata, Markdown/link/anchor/status/dependency checker.
- Fixed gate-contract parser with closed keys and fail-closed `UNRESOLVED` handling.
- Closed no-caller-input 96-phase semantic registry, exact structural projection join, and fail-closed resource-provision registry.
- Two-way phase/tracker/substrate/component joins.
- Haskell-owned sentence and paragraph budget measurement, replacing the condemned Python `p3` implementation.

### Validation

The Haskell checker rejects one generated minimal mutation for every structural rule and reports the exact
rule, file, and locus. Empty discovery refuses. A keyword-only decoy must be structurally inert and must never
alter a source, registry, validation, or ordering verdict.

### Remaining Work

The checkers and component oracles exist but are not qualified or tested for independence. The
documentation checker separately pins the 195-path governed inventory/count digest and rejects retired tracked
fixture/golden/oracle/mutant syntax unless it names one exact non-wildcard lowercase-`.hs` file, plus ambiguous
committed/checked-in artifact wording; raw, fenced, comment-split, and physically wrapped spellings cannot hide
those defects. Phase and sprint status fields are exact raw reset forms: dual-status wording, extra bare markers,
fenced decoys, comments, and line wraps refuse. These focused cases and isolated production mutants are component
diagnostics, not corpus acceptance. At that checkpoint changed-production PhaseContract mutants suppressed,
separately, the phase-status reset guard and the unresolved/missing gate-cell refusal, but their clean and
isolated-red executions had not run and were later superseded by the selector-authority audit below. The paragraph-spanning Haskell measurement and independently literal
component corpus are now implemented. The first mutable-worktree diagnostic on 2026-08-23 observed 1,570
sentences over forty-five words across 195 governed documents, 128 over ninety, a maximum of 667 words, and
650 paragraphs over six sentences. Single-line and hard-wrapped 50-word cases produced the same exact locus;
table and fenced cases were exempt; the physical-line mutant missed only the wrapped overage, and the omission
mutant erased both controls. These are supporting diagnostics, not a candidate or validation. The exact live
counts must be re-frozen after documentation edits stabilize, and both changed-production builds must run
through the complete component runner. The 2026-08-26 aggregate executed all then-eighteen named component oracles,
and every oracle reported its bounded diagnostic expectations met after the six missing documentation-header
finding projections were restored. A provisional post-schema measurement observed
1,583 over-target sentences and 655 over-target paragraphs, with all 1,728 typed semantic slots represented by
exact-prefix unresolved gate cells, 385 resource-contract gaps, no checked semantic payload, and the permanent diagnostic-only
join refusals. Subsequent semantic-contract and documentation hardening invalidated those exact bytes. No current
finding-manifest digest is frozen, and neither the provisional counts nor the eventual digest are qualification
evidence. `python3 tools/doc_lint.py` remains
condemned non-Haskell source and
cannot produce acceptance evidence. The 2026-08-23 semantic audit found that the lexical gate-cell count
materially understates the contract debt. All 270 sprint sections now have the exact mandatory field sequence and
closed immediate-blocker grammar; two independent read-only audits found no structural schema or blocker-edge
mismatch in the 262 Phase-1-through-95 sprint blocks. Those repairs establish structure only. The typed
96-phase semantic registry and its Markdown join remain under adversarial hardening, and every `UNRESOLVED`,
`MISSING`, absent checked value, or permanent diagnostic-only refusal must be resolved only from its owning phase
contract. A read-only design audit
has now frozen the exact 96 ordinal/capability/file/title identities, substrate/lane/register projections,
execution stages, immediate predecessors, and independent legacy-owner reverse map. It requires a canonical
no-caller-input Haskell registry with explicit `ContractGap` versus checked slots; natural-language Claim,
Subject, Oracle, provider, module, count, and Legacy-ID prose must remain semantically inert. All 1,728 typed
slots therefore remain gaps rather than becoming bound merely because 438 Markdown cells contain prose. The same audit
found subject effects requiring resource provision at Phases 1, 13–15, 25, 27, 34, 43, and 49–95; headings are
required at 1, 13–15, 25, 27, 34, 43, 49, and 51 but were missing, while Phase 48 had a noncanonical unnecessary
deferred heading. Those ten missing headings now exist as exact fail-closed `UNRESOLVED` sections, and the Phase-
48 heading and Contents link have been removed.
The standards now explicitly distinguish the universal outer Haskell gate process and contained `.build/**`
observations from additional phase-specific subject/fake/adapter/observer/cleanup effects; short-lived and test-
only effects are included. This resolves the selection ambiguity without resolving any missing seven-field
contract: every required absent or `UNRESOLVED` section still fails closed.

The semantic registry and join now share a hidden ordinal/capability/path identity while retaining an
independent literal Markdown path inventory. Adversarial check found substring, indentation, tracker-header,
delimiter, raw-HTML, container-prefix, comment-splice, and path-position spoof routes. Production now requires
the exact unresolved prefix, exact tracker header, an immediate canonical delimiter, and structural rows outside
code or raw-HTML blocks. List- or blockquote-prefixed block openers make the remaining document opaque rather
than supplying structural values. Comment masking is linear and preserves a non-whitespace splice sentinel;
tracker preflight is linear and saturates at the 129th row. The eight privacy claims are now eight one-symbol
compile negatives rather than one masked multi-import failure. Their individual compiler failures and a clean
expanded container, alternating-block, delimiter, dense-comment, and repeated-header oracle run are component
diagnostics only. Thirteen isolated semantic-join production mutations then compiled and reddened their named
oracle cases. A subsequent independent check nevertheless found a real unselected attack: deleting a top-level
fence, a comment-prefixed line, or indented code could splice Gate or tracker table fragments into a canonical
projection, and the older `PhaseContract` parser independently normalized additional invalid table, tracker,
raw-HTML, link, and projection forms. The semantic join now emits opaque boundaries and requires one exact
contiguous Gate table. `PhaseContract` now has a separate linear structural lexer that retains physical opaque
boundaries for fences, comments, raw HTML, indented code, lists, blockquotes, and continuation indentation; its
Gate and tracker readers are independent one-pass exact-frame state machines rather than global row searches.
Exact negatives cover stale or malformed headers and delimiters, ignored and outside-frame rows, interruption at
each opaque boundary, noncanonical ordinals and links, over-wide rows, projection suffixes, and list-manufactured
status/summary/sprint syntax. Eighteen new one-locus changed-subject selectors and independently integrity-checked
fixtures now name those guards, while the existing table-frame selector has been widened to its truthful exact
frame role. A final static check found all selectors at one production locus and the current 96 Gate/tracker
owners structurally compatible with the stricter grammar; it deliberately made no compilation or execution
claim. All eighteen selectors now have distinct Cabal declarations and CPP mappings, and `cabal check` accepts
that static package description. No clean or isolated changed-subject run has occurred on the stricter parser,
so the prior clean and mutation runs remain superseded diagnostics rather than qualification. A coordinated
clean rerun, all affected isolated mutations, qualification, independent gate evidence, prose
correspondence, and the integrated documentation finding manifest remain absent.

A 2026-08-24 selector-authority audit superseded even that pending eighteen-row parser rerun. At that checkpoint, across
`Documentation`, `PhaseContract`, `PhaseSemanticContract`, `PhaseSemanticJoin`, and
`ResourceProvisionContract`, production contained 4, 28, 16, 15, and 3 selector identities
respectively, but none of the three Sprint-0.4 oracles contains a literal production-selector identity. No
oracle-owned selector-to-exact-case registry or two-way source/oracle/Cabal reconciliation therefore exists for
this sprint. The small selector sets also cover representative parser and registry failures rather than every
independent resource ceiling, result-retention row, finding projection, closed grammar alternative, phase/slot
identity, 96-phase composition decision, or 55 resource-contract row/field. In addition, the exposed
`Documentation` and `PhaseContract` modules still publish multiple parser/checker helpers, and
`DocumentationOracle` imports production PolicyContract values instead of an independent raw facade. These
surfaces require the same package-hidden implementation, minimal refusal-only facade, actual-symbol opacity,
literal registry, assigned-locus matrix, and unaffected-control treatment as Sprint 0.3. The earlier clean runs,
four documentation selectors, twenty-eight PhaseContract selectors, and thirty-four semantic/resource selectors
remain useful rejected baselines only; none is Sprint-0.4 candidate evidence.

A fresh strict direct Documentation-oracle diagnostic exposed five Phase Summary field-frame defects and one
Gate-table boundary defect before its stale live-residue manifest was considered. Five later phase documents
used bold `Supporting observation` prose that the closed field lexer correctly treated as an extra summary
field; those labels are now ordinary prose. Phase 28 placed its Gate heading immediately after a complete raw-
HTML anchor without the blank boundary required by the raw-HTML grammar; the blank boundary is now explicit.
The replacement scan has no summary-containment or semantic-join mismatch. Its exact mutable-worktree
observations are 195 governed paths, 1,596 sentences over forty-five words, 128 over ninety, maximum 667 words,
and 657 paragraphs over six sentences. At that checkpoint the closed residue manifest bound exactly 1,728
unresolved Gate cells, 1,728 typed semantic contract gaps, 385 resource-contract gaps, and four permanent
diagnostic-only resource/semantic/join refusals; no other finding code was admitted. After moving mutant-only PhaseContract link
and container helpers under their selecting CPP boundaries, a direct `-Wall -Wcompat -Werror` build and the
exact component oracle exit zero. This is a mutable-worktree component diagnostic, not qualification or corpus
acceptance. The complete literal selector/control registries, package-opacity repair, changed-binary matrix,
post-matrix audit, exact source and pinned toolchain inputs, source snapshot integrity, and documentation-gate correspondence inspection
remain open, so Sprint 0.4 remains Blocked — NOT VALIDATED.

On 2026-08-24 the documentation and phase-contract implementations moved behind package-hidden
`Documentation.Internal` and `PhaseContract.Internal` modules. The dispatcher now imports those hidden
candidate seams directly. `Documentation` remains a transitional broad re-export facade. `PhaseContract` now
exports only `phaseContractDiagnostic`, the bounded caller-Markdown structural seam that always retains the
permanent diagnostic-only refusal; its component oracle imports only that public symbol. Four one-symbol package
clients separately attack the hidden module and the three removed candidate-capable exports, and a positive
client imports the admitted diagnostic. Their Cabal flags and suites parse, but the exact package-boundary build
has not completed: an isolated build directory lacked the already-cached source-repository checkout, and the
replacement offline build was stopped when concurrent Legacy work changed the package description during
resolution. Neither invocation is evidence. The direct `-Wall -Wcompat -Werror` hidden implementation, facade,
and oracle build is green on the mutable worktree. Documentation facade narrowing and stable-input Cabal
compile-negative executions remain open.

The pure parser entry now refuses before normalization or parsing when a supplied corpus exceeds 256 entries,
4,096 path characters, 1,048,576 characters in one document, or 8,388,608 characters in total. The component
oracle states exact-limit and limit-plus-one pairs for all four bounds. Caller-authored structure checks also
retain an exact permanent diagnostic-only refusal. The current nine once-only selectors cover those five
decisions plus the prior inventory, retired-artifact, and two prose-measurement decisions. Production, the
literal oracle registry, Cabal flags, and Cabal mappings reconcile exactly at nine identities with no set delta.
Every assigned target and named control is green on the clean binary. That clean checkpoint is not a
completeness claim. Worktree discovery still needs no-follow traversal and pre-read file,
directory, and aggregate bounds. Result observation/finding limits and complete parser-decision selector
coverage also remain open.
After those changes, a fresh direct `-Wall -Wcompat -Werror` build and the full component oracle exited zero on
the current mutable worktree. This is a bounded-input component diagnostic only.

The first nine-row changed-subject bracket was rejected because the sentence-measurement omission made eleven
helpers warning-dead. Eight other rows had changed preprocessing, subject objects, and linked binaries; each
reddened only its assigned case and kept its control green, but that partial receipt is not evidence. The
omission now evaluates its helper chain before discarding the measurements. Focused discovery showed that it
must red both the one-line and wrapped-sentence exact cases, and the literal registry records that dependency.
A complete restarted bracket then read its rows from the linked oracle binary. All nine rows compiled and
linked strictly, changed the preprocessed subject, subject object, and same-path binary, reddened every declared
impact, kept every undeclared exact case green, and kept the named product control green. All frozen input hashes
were stable. This closes only the current nine-row component bracket; the explicit completeness gaps above keep
Sprint 0.4 Blocked — NOT VALIDATED.

The pure PhaseContract parser entry now refuses before normalization or parsing when a caller supplies more
than 256 entries, a path longer than 4,096 characters, a document longer than 524,288 characters, or more than
8,388,608 document characters in aggregate. Its oracle owns an exact-limit and first-over-limit pair for every
ceiling and requires the `refused-before-parse` observation at each refusal. A strict direct build of the hidden
implementation, its dependency closure, the transitional facade, and the complete component oracle exited zero
on the mutable worktree. Production, Cabal flag declarations, and Cabal CPP mappings reconcile exactly at the
current thirty-two PhaseContract selector identities. The oracle now independently states those thirty-two
identities, thirty-two primary exact cases, declared impact lists, and one product control per selector; all four
sets reconcile with no delta or duplicate, and the clean strict linked binary emits both exact cardinalities and
exits zero. Its complete all-case changed-subject dependency discovery is in progress, so the current impact
assignments are hypotheses rather than a final matrix. In an earlier focused four-row changed-subject bracket, each new
resource selector changed preprocessing, the hidden implementation object, and the linked binary; compiled
with warnings as errors; and reddened only its named over-limit expectation and refusal observation while its
exact-limit check remained unreported as a problem. The source, oracle, and four owned Cabal flag/mapping slices
were stable across that bracket. This remains a focused component diagnostic: no final thirty-two-row bracket
or post-matrix predicate audit exists, result rendering is not bounded, and the broad parser decision space is
not atomically selected. Sprint 0.4 therefore remains Blocked — NOT VALIDATED.

The first thirty-two-row PhaseContract dependency-discovery bracket was rejected at row fifteen. Its first
fourteen changed subjects had their declared one-case impacts and green controls, but the projection-vocabulary
selector made four production helpers warning-dead and therefore failed the strict subject build. That is not a
mutant kill. The selector now evaluates the vocabulary-finding chain before suppressing its result; a focused
strict build changed the subject and binary, reddened the assigned projection case, and kept its product control
green. A complete discovery bracket has restarted from a fresh clean-object and source boundary, so none of the
fourteen partial rows is counted as final evidence.

The next restart crossed the repaired projection row but was rejected at row nineteen because the sprint-schema
bypass made four schema helpers warning-dead. That selector now evaluates its real schema decision before
suppressing the finding, and its focused changed binary reddens the schema case with a green control. An initial
warning-only sweep was also rejected because its import-path ordering hid the frozen dependency interfaces and
made all thirty-two compiles fail before reaching the subjects. The corrected strict-build sweep copied the
exact clean interface/object set into every isolated row. It found only two further warning failures, the phase-
status and sprint-status bypasses. Both now evaluate their real status predicate before suppressing its result;
all thirty-two selectors compile with warnings as errors, and focused changed binaries for the repaired status
rows red their assigned cases with green controls. A new complete dependency-discovery bracket has restarted.
The warning-only sweep and focused rows are prerequisites and diagnostics, not mutation evidence.

The replacement thirty-two-row dependency discovery completed with stable PhaseContract source, facade,
oracle, owned Cabal flag/mapping slices, and frozen clean object/interface hashes. Every row compiled strictly,
changed preprocessing, the hidden implementation object, and the linked executable, reddened its assigned
primary case, and kept its product control green. Thirty selectors affected exactly one exact case. The broad
Gate-frame bypass truthfully affected five Gate-frame cases, while tracker-unframed seeding affected both its
primary case and the tracker-header-wildcard case. The oracle's literal impact lists now record those exact
sets. This is dependency discovery, not a final bracket: the required post-discovery audit already knows that
independent parser conjuncts, closed-grammar alternatives, finding/observation retention, and result-composition
decisions remain unselected. The registry must expand and undergo a new complete matrix and another post-matrix
audit before this component can contribute candidate evidence.

A current-byte strengthened rerun now supersedes the earlier dependency-only receipt without changing that
completeness verdict. Three selectors that also guarded mutant-only helper definitions were repaired to leave
their CPP identity at one behavioral production locus; the bounded Markdown-target and container-normalization
helpers are evaluated on the clean route so warnings-as-errors cannot decide a row. A Haskell-only direct driver
then exposed the oracle-owned 32-selector, 32-exact-case, and literal impact/control registries. The fixed-serial
matrix reconciled those identities exactly with production, all manual Cabal flags, and all library CPP mappings,
and executed every changed binary against all thirty-two exact cases. All 1,024 expected red/green classifications
matched the literal impact registry; every assigned case reddened, every named product control and undeclared
case stayed green, all preprocessed subjects, objects, and executables changed and remained pairwise unique,
clean-before and clean-after controls passed, and the input set stayed byte-identical. Result-table, summary, and
combined per-row exact-case receipt SHA-256 values are respectively
`3a09f3ca436b5528729883574f357556b1368efa68af12e68fe3804a8ae7885c`,
`16d13dce9432f8b97614eb98116409f4964d001b0f8e7e68112caeff261bf7b6`, and
`3a0e8bd828196217615578e4d728a1cf0e2a91e482400fa854bf8bb83bdf02b6`. The mandatory reachable-decision audit
then rejected thirty-two as a completeness total: phase discovery/path/title parsing, Gate/tracker state-machine
transitions, exact cell and inline-code grammars, phase/dependency/Gate/sprint finding projections and ordering,
closed tracker link/destination grammar alternatives, lexer fence/comment/HTML/container branches, resource
limit values and refusal projections, observation/result retention, and final component composition do not yet
have atomic selectors and independently literal exact cases. This is a stronger bounded component checkpoint,
not PhaseContract implementation readiness or Sprint-0.4 evidence.

The bounded PhaseContract component now also builds and runs through the current Cabal package registration in
the contained `.build/dist-newstyle` tree with `--offline --jobs=1`; its one component case passes. Four separate
warning-strict package-external attacks then fail at the exact intended boundaries: the whole Internal module is
hidden, and `checkPhaseContracts`, `checkPhaseContractStructure`, and `checkPhaseAndTracker` are not exported by
the public facade. The independent public `phaseContractDiagnostic` client compiles, links, and exits zero
against the same registration. `cabal check` succeeds with only the repository's existing missing distribution-
metadata warnings after the component stanza was narrowed from blanket `-Werror` to the package's explicit
warning policy. These are mutable-worktree package-boundary diagnostics for the bounded registry only; they do
not cure the uncovered PhaseContract decisions above, authenticate the compiler or inputs, qualify the harness,
or establish Sprint-0.4 or Phase-0 validation.

The next bounded PhaseContract expansion selects twenty-one additional reachable decisions: governed-directory
phase discovery; duplicate, missing, extra, empty-discovery, and title findings; tracker corpus cardinality,
missing-domain, status, title, contract-target, and projection joins; mandatory summary fields and Gate-section
ownership; genesis, predecessor, and same-or-forward dependency findings; ordered Gate shape and exact command
and summary-command findings; and sprint heading identity. Production, the independently literal oracle, fifty-
three manual Cabal flags, and all library mappings reconcile exactly. The first 53-row matrix was correctly
rejected when complete all-case discovery found three undeclared cross-impacts: indented-code acceptance also
affects the indented Gate-section case, discovery suppression also affects the out-of-directory decoy, and the
whole projection join also affects the prefix-specific case. After those literal declarations were repaired, a
fresh fixed-serial matrix rebuilt clean plus all fifty-three isolated changed subjects and executed all 2,809
selector/case classifications. Every assigned case reddened, all declared and undeclared classifications matched,
the named controls and final clean controls remained green, all preprocessed sources, objects, and executables
changed and remained pairwise unique, and the input set remained byte-identical. Result-table, summary, and
combined per-row case-receipt SHA-256 values are respectively
`1ea9e2107d3e24513b3770b6ccf6ddfea5a9dde6f66228b364b123990e2b01db`,
`223f769aa7fea8db9db64877e3b504ebac63bc85cb7f97c43619fc7e0c97013c`, and
`2a09ed4d290ca3907f6e9d9504c075e3fd6280566f88881c8401abfd61ab2013`. `cabal check` accepts the expanded package
with only its existing missing distribution-metadata warnings.

The post-expansion reachable-decision audit still rejects fifty-three as a completeness total. Unselected loci
remain in phase filename/title grammar and duplicate selection/rendering; observation and final-result
composition; exact table-cell and inline-code grammar; Gate and tracker state transitions, termination, and
problem projections; dependency and tracker closed-link label/destination alternatives; tracker duplicate/extra
and row-cell guards; sprint inventory, heading grammar, schema conjunctions, and blocker alternatives; lexer
fence/comment/HTML/container branches; resource-limit values and refusal projections; and semantic diagnostic
retention. The prior package build and four-negative/one-positive opacity bracket predate this expansion, so a
current package registration and opacity rerun also remain open. This is a stronger bounded component checkpoint,
not PhaseContract implementation readiness or Sprint-0.4 evidence.

The second PhaseContract expansion raises the bounded registry to sixty-one selectors and cases. It now isolates
the two-digit phase filename width, ordinal separator, Markdown extension, duplicate H1 cardinality, dependency-
link finding retention and exact predecessor label, and empty Gate and tracker cell rejection. The unreachable
`PLAN-GATE-EMPTY` projection was removed instead of being given a manufactured selector: the production parser
refuses an empty contract cell before any Gate row exists, so that later verdict could never be observed. The
first 61-row discovery matrix was correctly rejected because the legacy surrounding-prose dependency parser also
ignores the newly isolated link label. After that cross-impact was declared, the fresh fixed-serial matrix rebuilt
clean plus all sixty-one changed subjects and executed all 3,721 classifications. Every assigned case reddened,
all complete-impact classifications matched, named and final controls remained green, preprocessed sources,
objects, and executables changed and remained pairwise unique, and the input set remained byte-identical. Result-
table, summary, and combined case-receipt SHA-256 values are respectively
`15aecb498b214744008dd09ead7c9120532b269940b33482cf7d6916d29d5d92`,
`605cbc41b8d1867621ea571cb236ded44cbc035afd31cfd6826491eb445e3429`, and
`29f3e9e1105f4e0454e610c6e9aaf0eb850679c1f52cf9c7c19b68246764d76c`. The expanded `cabal check` again succeeds
with only the repository's existing missing distribution-metadata warnings.

The post-matrix audit still rejects sixty-one as a completeness total. Phase title-prefix/body grammar,
selection/rendering of duplicate paths, observation and final-result composition, exact table-cell and inline-
code alternatives, Gate and tracker transition/termination/problem projections, tracker closed-link destination
grammar, tracker duplicate/extra reachability, sprint inventory/heading/schema/blocker alternatives, lexer
fence/comment/HTML/container branches, resource-limit values and refusal projections, and semantic diagnostic
retention remain unselected or unresolved. The current Cabal package build and opacity bracket also remain
pending after these source and metadata changes. This remains a bounded component checkpoint, not PhaseContract
implementation readiness or Sprint-0.4 evidence.

The third PhaseContract expansion selects all seven live within-envelope observations independently: exact
phase-document, tracker-row, Gate-row, sprint-section, unresolved-marker, missing-marker, and combined refusal-
marker counts. The literal cases state 96, 96, 1,728, 96, 1, 1, and 2 respectively; the clean warning-strict graph
confirms those values. Production, oracle, sixty-eight manual Cabal flags, and library mappings reconcile exactly.
The complete 68-row fixed-serial matrix passed its first all-case discovery run: all sixty-eight assigned cases
reddened, all 4,624 classifications matched, named and final controls stayed green, all preprocessed sources,
objects, and executables changed and remained pairwise unique, and inputs remained byte-identical. Result-table,
summary, and combined case-receipt SHA-256 values are respectively
`d7bf0ae5701d82aa85289d47bdee61095f480c166d0dd7010f9d2f41d864e781`,
`6f7d64b4a7b712b596c3325aa305a54f4ec109bb93e4c6676bfe47b88fa3861d`, and
`53bcb3dfc89a39a8ff889632743320f22770df417b4165c13f4c60b732030e22`. `cabal check` remains accepted with only
the existing missing distribution-metadata warnings.

The post-observation audit still rejects sixty-eight as a completeness total. Envelope-refusal observation
values, check-name/finding/semantic-diagnostic result composition, and all parser/state/resource loci named by
the prior audit remain open. The current Cabal package and opacity bracket likewise remain stale after this
expansion. This is a bounded reporting checkpoint, not PhaseContract implementation readiness or Sprint-0.4
evidence.

The fourth PhaseContract expansion selects the five envelope-refusal observations: the permanent
`refused-before-parse` state and exact entry, path-character, document-character, and aggregate-character ceilings
of 256, 4,096, 524,288, and 8,388,608. Literal impact declarations include the necessary corresponding limit-
guard relationships and the pre-parse marker's impact on all four earlier refusal cases. Production, oracle,
seventy-three Cabal flags, and library mappings reconcile exactly. The complete 73-row fixed-serial matrix passed
its first all-case discovery run: all seventy-three assigned cases reddened, all 5,329 classifications matched,
named and final controls remained green, every preprocessed source, object, and executable changed and remained
pairwise unique, and inputs stayed byte-identical. Result-table, summary, and combined case-receipt SHA-256 values
are respectively `37a2f72c090f5725b7f766febe5fec04f4dded20627bc5d026e51df4edc0f41f`,
`d5f74c218c9a91859e094d55008ad0e81bcce980f15b8b22343eb14908d89011`, and
`b4fd7fa45d1ac6a98f72a306395b9df277cc25fedaa2a2cb699d18d593a5bd77`. `cabal check` remains accepted with only
the existing missing distribution-metadata warnings.

The post-envelope audit still rejects seventy-three as a completeness total. Check-name, finding-list, semantic-
observation/finding retention, final result composition, and the parser/state/resource loci named by the prior
audit remain open. This is a bounded result-reporting checkpoint, not PhaseContract implementation readiness or
Sprint-0.4 evidence.

The contained `.build/dist-newstyle` Cabal package was then rebuilt from the exact seventy-three-row source and
metadata with `--offline --jobs=1`, and the package-built component case passed. Against that refreshed
registration, four warning-strict external clients failed independently at the intended boundary: the Internal
module was hidden, while `checkPhaseContracts`, `checkPhaseContractStructure`, and `checkPhaseAndTracker` were
absent from the public export list. The public `phaseContractDiagnostic` client compiled, linked, and exited zero
against the same package. That mutable-worktree package diagnostic was current only for the seventy-three-row
checkpoint; it did not close the post-envelope audit, authenticate toolchain or inputs, qualify the harness, or
establish Sprint-0.4 or Phase-0 evidence.

The fifth PhaseContract expansion selects ten additional Gate/tracker frame-state decisions: a second exact
header, nonblank content at the required end boundary, a row after a completed frame, terminal missing-header
finding retention, and terminal incomplete-row finding retention for each table. The first 83-row discovery
matrix was correctly rejected at tracker missing-header suppression because malformed container, indented-code,
and raw-HTML inputs also lost their terminal frame finding. The failed `matrix-83` checkpoint remains preserved;
the literal assignment now keeps `tracker-missing-header` as its unique primary case and declares those three
observed cross-impacts. A fresh fixed-serial bracket rebuilt clean plus all eighty-three isolated changed subjects
and executed all 6,889 selector/case classifications. Every assigned case reddened, every declared and
undeclared classification matched, named and final clean controls remained green, all preprocessed subjects,
objects, and executables changed and remained pairwise unique, and the frozen input set remained byte-identical.
Result-table, summary, and combined per-row case-receipt SHA-256 values are respectively
`5093773991a102e395c79f3e5f886aa853e57aeb9b95bd81985d396c88975f62`,
`88ce780881a8ae63ba1306d80674c6adbe6c4ea7e08ea7c10b7c470dbf55974d`, and
`6cb3d9c8951b806ff7a450d2009a82477f424c611835c52c80526e65d9cca180`. `cabal check` accepts the expanded
package description with only the existing missing distribution-metadata warnings.

The Haskell component driver now also exposes one batched exact-case mode. The development harness still fixes
compiler and linker concurrency at one: it builds the complete clean graph once, copies that graph's exact
dependency interfaces into each isolated row, recompiles only the selected PhaseContract subject, relinks it
against the clean dependency objects, and executes every literal exact case serially inside one process. A fresh
current-byte 83-row rerun after that driver change passed all 6,889 classifications, named and final clean
controls, pairwise preprocessed/object/executable uniqueness checks, registry reconciliation, and frozen-input
checks. Its result-table and combined case-receipt SHA-256 values are respectively
`b9364f4aaef19581f667d772ea962cdd17be462529577a88af378916c55d5639` and
`5e68ec49fefa1b2b70d1f1e7733d207f96e0d21c26942b2634da53e0784d0ea3`; the unchanged summary digest is
`88ce780881a8ae63ba1306d80674c6adbe6c4ea7e08ea7c10b7c470dbf55974d`. This supersedes the prior current-byte
receipt without changing the bounded-completeness verdict.

The post-state-machine audit still rejects eighty-three as a completeness total. Missing-delimiter termination,
exact opening/closing-pipe and Gate-row arity decisions, full opaque-boundary interruption alternatives, phase
title and filename-suffix grammar, exact tracker-link label/destination grammar, inline-code and command-count
alternatives, tracker frame-finding projection, check-name and final result composition, bounded output
rendering, internal semantic observation/finding retention, sprint inventory and remaining heading/schema/blocker
alternatives, and unreachable tracker duplicate/extra projections remain open. The existing package and opacity
receipt was built from the earlier seventy-three-row source and Cabal registration, so it is stale again. This is
a bounded frame-state checkpoint, not PhaseContract implementation readiness or Sprint-0.4 evidence.

The sixth PhaseContract expansion selects twenty-five additional atomic parser and frame decisions: exact check
name; comment and fence opacity; Gate command cardinality, missing-delimiter finding, two-cell row arity, raw
summary-line cardinality, parsed summary value, and pre-header-row refusal; exact opening and closing table pipes;
inline-code width; closed link-target characters; the `phase_` path prefix plus nonempty segmented lowercase slug;
the exact Phase-title prefix plus nonempty title body; tracker delimiter, row, and end-boundary transitions; tracker
frame and missing-delimiter findings; and the exact tracker link label. Unreachable tracker duplicate/extra finding
projections were removed from the claimed inventory rather than assigned artificial subjects. Production, the
independently literal oracle registry, 108 manual Cabal flags, and all library mappings reconcile exactly.

The first complete 108-row discovery bracket correctly rejected two impact declarations while all changed
subjects compiled and linked distinctly and both final clean controls remained green. Tracker link-prose also
changed the exact tracker-link-label case, and tracker row-boundary also changed the tracker fence-boundary case;
the failed `matrix-108-discovery` checkpoint is preserved with result-table, summary, and combined per-row case-
receipt SHA-256 values respectively
`856c5e8f3067a8876de16234313b8d3c564eb9505fa84077a413cc071c481b45`,
`af8e31c7cb4e8255aa9d663be98486590a137837855259ae2a48b38b6c46358d`, and
`fb38fd3f5aa0bde6e619aef24896f69b80d91170bc9532fee9ee781e26b14fa8`. The literal declarations now retain
their unique primary cases and name those observed cross-impacts. A fresh fixed-serial restart rebuilt all 108
changed subjects and executed all 11,664 selector/case classifications. Every assigned case reddened, every
declared and undeclared impact classification matched, named and final clean controls remained green, all
preprocessed subjects, objects, and executables changed and remained pairwise unique, and the frozen input set
remained byte-identical. Result-table, summary, and combined per-row case-receipt SHA-256 values are respectively
`90a76fa2f29dabf6cd25d55a1960f65bbc3accf9563df2b6589475001d6a3018`,
`ed0a70c2f4781f09b4fcf754a632be352bcb62df0c3f527f0e56717cb114d4ae`, and
`b7573e07e155816d5c2a457d4b6da03923e82ffbc1952311a177f5a3ad596843`. `cabal check` accepts the expanded
description with only the existing missing distribution-metadata warnings, and `git diff --check` is clean.

The post-parser audit still rejects 108 as a completeness total. Final result composition and bounded output
rendering, internal semantic observation/finding retention, phase duplicate selection/rendering and remaining
number/path/link grammar alternatives, canonical sprint inventory and remaining heading/schema/blocker
conjuncts, and other reachable composition routes remain open. The package-built component and opacity receipt
still describes the earlier seventy-three-row source and registration and must be refreshed against current
bytes. This is a bounded parser/state checkpoint, not PhaseContract implementation readiness, Sprint-0.4
evidence, or complete gate validation.

The seventh PhaseContract expansion selects eleven top-level result-composition routes: the input-envelope
finding and observation carriers; the within-envelope structural observation carrier; and the dependency, Gate,
phase-domain, phase-structure, projection-vocabulary, sprint, tracker parser/shape, and tracker-to-phase join
finding carriers. The independent route cases use paired defects from separate leaf predicates, or require the
complete observation-key universe across independent envelope attacks, so one older leaf mutation cannot stand
in for its parent route. The projection-vocabulary leaf and route are necessarily overlapping changed loci and
declare their shared exact cases explicitly. Production, the independently literal oracle, 119 manual Cabal
flags, and all library mappings reconcile exactly with no duplicate token.

The first `matrix-119-discovery` clean gate stopped before row one because one route declaration named the
nonexistent exact case `indented-code`; no selector result from that aborted root was accepted. The declaration
was removed rather than redirected to the unrelated tracker-indented-code case, and the clean gate plus complete
matrix restarted from a fresh `matrix-119-discovery2` root. That fixed-serial run rebuilt all 119 changed subjects
and executed all 14,161 selector/case classifications. Every assigned case reddened, every declared and
undeclared impact classification matched, named and final clean controls remained green, all preprocessed
subjects, objects, and executables changed and remained pairwise unique, and the frozen input set remained byte-
identical. Result-table, summary, and combined per-row case-receipt SHA-256 values are respectively
`41e1c5115bfd614d5a26d00aea951c9366b1e76870c86b82c5bf31f83eee6bbb`,
`154221f409d355f34befd9ba4e497f84a7e5a84dd17d062c2c317f1e46f30543`, and
`7bfddaa3e023e752af5ba3daf9f060e43237e72a5a1a754631fc383d060837df`. `cabal check` again accepts the
description with only the existing missing distribution-metadata warnings, and `git diff --check` is clean.

The post-composition audit still rejects 119 as a completeness total. Internal semantic observation and finding
retention require a direct-source full-mode oracle rather than the refusal-only public facade. Canonical sprint
inventory and remaining heading/schema/blocker conjuncts, phase duplicate selection/rendering, remaining
number/path/link grammar alternatives, and other reachable parser and result-carrier decisions remain open. This
is a bounded result-composition checkpoint, not PhaseContract implementation readiness, Sprint-0.4 evidence, or
complete gate validation.

The contained `.build/dist-newstyle` package was then rebuilt from the exact 119-row source and Cabal bytes with
`--offline --jobs=1`. Both the package-built component and the admitted `phaseContractDiagnostic` public client
compiled, linked, and passed; their log SHA-256 values are respectively
`4a2fe06ca1a9e1bf33da2bfeadf4227efa1965038a0d45350ad2abed7305c692` and
`78156dbd3a1d9e7cf8a9780935c26337b03562ae3ce6c4c5dc521d5904833a29`. Against that same refreshed package
registration, four warning-strict `-j1` one-symbol clients failed independently and exactly at the intended
boundary: `Amoebius.Validation.PhaseContract.Internal` is hidden, while `checkPhaseContracts`,
`checkPhaseContractStructure`, and `checkPhaseAndTracker` are absent from the public facade export list. The
registration, combined five-client source set, static library, and dynamic library SHA-256 values are respectively
`da2666517eed599ff7288938fa9510bb0a550e31275da81fa8abc61c9c5fb8cc`,
`e60fff76bffceb8966a979fa7a64ec70be96bb537773bd7aa247b19a8fb9a78c`,
`346f32fa142638addd2e10671c859967b7677fba5c0995a8fa060c43408024be`, and
`d7b5eff0c70a2c7f4e50036ab778a4b7cf5075437b6ad18c6f41276443c2d92d`. This refresh closes only the current
package-opacity diagnostic seam; it does not close the remaining source audit, qualify the mutable harness,
authenticate toolchain or inputs, establish Sprint-0.4 evidence, or authorize validation.

The subsequent integration rerun exposed that PhaseContract's initial 128-entry and 4,194,304-character
envelope could not admit the complete governed documentation corpus passed by both Documentation and Dispatch;
it refused before evaluating any plan contract. Those checkpoints are invalid. The envelope now shares the
already bounded outer documentation ceiling of 256 entries and 8,388,608 characters, with revised exact-limit
and first-over-limit cases. The complete mutable-worktree documentation diagnostic again reaches all plan
contracts. Its closed live-residue manifest now additionally retains the permanent
`DOC-CORPUS-DIAGNOSTIC-ONLY` refusal and binds the exact finding digest
`2e2676c36c6a69cfd809f8d19fb7d2d5f86cf650e51d221e3c3f8a24388ba5be`; this mutable observation is not
authenticated evidence.

Documentation's public module no longer re-exports candidate parsers, caller-selected policy-owner contracts,
or anchor values. Its four remaining entry points return only refusal-bearing structural, canonical-inventory,
canonical-owner, or mutable-worktree diagnostics; the dispatcher alone imports the hidden candidate seam after
source capture. The structure, inventory, owner, and worktree refusals are distinct production decisions.
Package-boundary one-symbol attacks, complete selector assignment, traversal/resource bounds, and the new
matrix remain open, so facade narrowing is not yet an opacity or completeness claim.

The mutable-worktree route now enumerates POSIX directories through a bounded stream rather than materializing
an unbounded name list. It refuses symbolic links without following them, recursion beyond 64 levels,
discovered relative paths beyond 512 characters, more than 1,024 entries in one directory, more than 4,096
entries in aggregate, more than 256 Markdown files, a Markdown file beyond 4,194,304 bytes before read, or more
than 16,777,216 Markdown bytes in aggregate before read. It remeasures each admitted file after reading and
reports a size race. The pure result carrier separately refuses before rendering beyond 4,096 findings, 4,096
observations, 8,192 characters in one field, or 2,097,152 field characters in aggregate. These ceilings are
implementation values, not yet qualified contracts. Focused exact-limit/first-over-limit corpora now cover all
eight worktree ceilings and all four result ceilings, but comprehensive selector discovery, complete cross-impact
discovery, Windows enumeration residue, the post-read identity race model, and authenticated harness construction
remain open.

The first focused worktree resource run rejected the candidate because the aggregate-entry oracle's 4,097th
entry was admitted: the plan and independent case builder required a 4,096-entry ceiling while the implementation
still contained 8,192. The implementation ceiling is now 4,096. A direct source-built diagnostic rerun admits
the exact boundary and refuses the first-over case for each of the eight directory-entry, aggregate-entry, depth,
path, symbolic-link, file-count, per-file-byte, and aggregate-byte families. This is only local candidate
evidence; the selector assignments, output-envelope cases, cross-impact matrix, post-matrix audit, and immutable
toolchain authentication remain open.

The output-envelope audit then rejected the facade composition: structure, inventory, owner, and worktree
wrappers appended their permanent diagnostic refusal after the hidden result had already been bounded. An exact
hidden boundary could therefore produce an oversized public carrier, and an inner refusal could lose the facade's
authority marker. The wrappers now add the required marker before the final envelope, and the four facade markers
are mandatory bounded residue. Independent final-carrier pairs admit exactly 4,096 findings, 4,096 observations,
an 8,192-character field, and 2,097,152 aggregate field characters, while refusing the first value over each
boundary with the exact `DOC-OUTPUT-LIMIT` detail and retained structure marker. The aggregate case uses 250 tiny
malformed governed documents with ten independently enumerated header findings each, one missing-link finding,
and the permanent refusal: 2,502 findings and eleven observations remain below their own ceilings while one link
target moves the aggregate from 2,097,152 to 2,097,153. Earlier prose-heavy and long-link aggregate constructions
were discarded after multi-minute runs; their eventual result was not reused as evidence.

Seven one-symbol package clients now separately attack `Documentation.Internal` and each removed public symbol:
`checkCorpus`, `checkDocumentStructure`, `checkDocuments`, `checkPolicyOwnerReferences`,
`checkPolicyOwnerReferencesFor`, and `githubAnchor`. A separate client imports all four admitted refusal-only
diagnostics. Cabal owns distinct manual flags and suites for those clients and parses the expanded description,
but no package-boundary build has yet established the positive control or exact one-error failures. The oracle now
names 24 literal rows: the prior nine plus three added public refusals, eight traversal/resource decisions, and
four output ceilings, with exact source and Cabal reconciliation. A focused direct-object matrix established that
each of the fifteen added one-symbol builds changes the preprocessed subject, object, and binary, keeps its exact
control green, and makes its assigned attack red. The structure-refusal mutant also makes its four declared output
attacks red while retaining its unrelated owner control. This is not a completeness claim: the comprehensive
parser/output composition audit, all-case discovery bracket, post-matrix audit, package-boundary suites, immutable
toolchain authentication, and independent observer qualification remain open.

After the output-composition repair, the eight worktree resource pairs were rebuilt through a separate
direct-source Haskell entry point against the current hidden implementation, facade, and oracle objects. The
exact directory-entry, aggregate-entry, depth, path, symbolic-link, file-count, per-file-byte, and aggregate-byte
boundaries were admitted and every first-over value refused; the isolated runner exited zero. This supersedes
the earlier resource run whose linked executable predated the output-oracle edits. It remains a mutable-worktree
regression diagnostic only: it does not expand the twenty-four-row selector inventory, authenticate the
toolchain or inputs, establish package opacity, complete the all-case changed-subject matrix, or validate the
sprint.

The ensuing whole-file atomicity audit confirms that twenty-four rows cannot be frozen as the Documentation
inventory. Unselected acceptance decisions remain in corpus normalization and governed-root discovery;
duplicate, missing-root, inventory count/digest, and canonical-owner findings; mandatory-refusal retention and
the sixty-four-finding retention ceiling; facade-before-envelope composition; retired-path and retired-phrase
grammar alternatives; no-follow discovery error/race routes; fence, comment, block, heading, link, anchor, and
destination grammars; metadata cardinality/value/order rules; path resolution; backlink comparison; the exact
CLAUDE import; and archive/register cardinality. Advisory prose measurements also contain unselected closed
grammar branches that contribute retained observations. The current twenty-four rows are therefore a tested
subset only. Each independent conjunct and alternative in those families must receive one production locus,
one independently literal exact case, one named unaffected control, one Cabal mapping, complete changed-subject
cross-impact discovery, and a post-matrix re-audit before Documentation is implementation-ready.

The first expansion checkpoint raises the provisional production inventory from twenty-four to sixty-four
once-only selectors. It separates inventory count and digest refusals; selects duplicate and empty discovery,
all five required governed roots, all five governed-path alternatives, slash and leading-dot normalization,
eleven finding-route joins, the three mutable-corpus component joins, pre-parse envelope routing,
facade-before-envelope composition, seven initially proposed mandatory-finding retention alternatives, and
the exact sixty-four mandatory-finding ceiling. This checkpoint intentionally has no matching oracle or Cabal rows yet
and therefore must fail two-way reconciliation. It is unfinished implementation, not a candidate count; the
remaining retired-syntax, Markdown/prose, discovery/error, header, link, owner, backlink, CLAUDE, and archive
audits may still change it before any matrix is frozen.

Reachability check immediately rejected three of those mandatory-retention alternatives. A policy-owner
diagnostic cannot exceed the output envelope after its input bound and finite canonical-owner check; an input
refusal is itself a small pre-parse result; and `PLAN-INPUT-*` findings are merged outside Documentation's
bounded pure result. Keeping selectors for those branches would manufacture unreachable mutants. The three
branches and selectors are removed; corpus, inventory, structure, and discovery retention remain reachable.
The corresponding provisional count is therefore 61 before the retired-syntax expansion and 101 after it.

The retired-syntax audit adds forty further provisional loci, bringing the in-progress source inventory to
101. It selects raw, comment-elided, and physical-line-join projections independently; every one of the nine
retired path-root alternatives; case-folded root matching; each admitted punctuation class, segment guard,
lowercase Haskell suffix, and non-empty stem in the exact-Haskell-path exception; both retired commitment
prefixes; all eight retired artifact-word alternatives; and each of the four clause delimiters. A strict clean
compile is green. No new oracle or Cabal row exists yet, no changed build has run, and the broader Markdown,
discovery, and delegated header/link audit remains open, so 101 is neither reconciled nor complete.

An isolated warning sweep then compiled all 101 selected variants from the clean dependency-interface boundary
with `-Wall -Wcompat -Werror`. Every row reached the Documentation subject and compiled without warning or
error. This proves only that none of the current selector branches wins by making helpers dead; it supplies no
assigned oracle result, binary witness, Cabal reconciliation, completeness claim, or phase-gate pass.

The current production source has since reached 153 unique selectors by adding the provisional metadata/header
grammar loci. The literal oracle and Cabal registries still contain only the earlier 24-row tested subset, so
129 production selectors are intentionally unreconciled and no 153-row matrix is admissible. The 2026-08-26
strict serialized build exposed six missing header-finding projections introduced during that expansion; those
projections are now restored, and the aggregate component binary executed all then-eighteen named oracles green on
the mutable worktree. The Documentation oracle still freezes the bounded live prose observation at 1,601
over-target sentences. This is a repair and component diagnostic only. Completing the independent 153-plus
oracle/Cabal registry, the broader parser/output audit, package-opacity matrix, qualification, exact captured
inputs, run binding, and documentation-gate correspondence remains open.

The next PhaseContract parser audit initially proposed eighteen additional selectors beyond the 119-row
checkpoint: four closed-link decisions, five sprint-heading decisions, five sprint-schema conjuncts, three
sprint-blocker alternatives, and the sprint-heading prefix. It found and repaired one real production defect:
`## Sprint 10.01` had been accepted as the canonical `10.1` identity, so the parser now requires the digit text
to equal the rendered positive ordinal. The first `matrix-137-discovery` clean gate stopped before row one on a
duplicate exact-case declaration. After that registry defect was corrected, the next clean gate rejected the
sprint-heading-prefix case: a wrong `## Sprint` prefix is refused earlier by the exact mandatory Phase-section
shape and cannot independently reach the sprint parser. That false selector was removed rather than weakening
the outer parser or manufacturing a subject.

The resulting 136-selector discovery run ended without a summary while building row 81, so none of that root is
a bracket receipt. Its eighty complete row tables nevertheless exposed three useful discovery mismatches. The
nested-bracket and empty-label cases stayed green under their proposed parser mutants because both actual callers
already require the complete fixed label (`Contract` or the exact predecessor label); those two checks and their
selectors were observationally redundant and have been removed. The shared trailing-content selector also
reddened the existing dependency-link-prose case, and its literal impact declaration now records that route.
Production, the independently literal oracle, the manual Cabal flags, and library CPP mappings consequently
reconcile at 134 unique reachable identities and 134 exact cases. `cabal check` accepts that package description
with only the repository's existing missing distribution-metadata warnings, and `git diff --check` is clean.

The stopped `matrix-134-final` root remains inadmissible partial history. An initial complete 134-row receipt on
2026-08-28 was then superseded when the full-mode work changed the same production module. A new Haskell-owned,
fixed-serial bracket started from the resulting current bytes, reconciled the disjoint 134-row structural and
eight-row internal selector partitions across production, the independently literal oracles, Cabal flags, and
CPP mappings, and completed all structural rows without resumption. All 17,956 selector/case classifications
matched their literal impact declarations; every assigned case reddened, every undeclared case and named control
stayed green, and every row had changed preprocessing, object, and linked-executable identities distinct from the
clean control and every other mutant. The final clean controls matched, all twenty frozen source inputs retained
their starting hashes, and the retained result-table SHA-256 is
`0be2e82f5ae5b0d8744b4ccbd341164f984147e1e5a5dd82214703a4e2e690b9`. This is a complete component
diagnostic, not qualification or validation. The canonical sprint inventory's atomic count decisions, further
reachable-decision audit, refreshed package-opacity bracket, parent-harness qualification, exact local inputs,
source snapshot integrity, and documentation-gate correspondence inspection remain open. A second fresh direct-source bracket on
2026-08-28 exercised eight newly isolated full-mode
decisions: semantic observation and finding composition, the phase-semantic, resource-provision, and semantic-
join routes, sprint-inventory finding retention, and duplicate-path selection and render ordering. Its eight
rows matched all 64 literal cross-impact classifications; preprocessing, object, and executable identities were
changed and pairwise unique; final clean controls and nineteen frozen input hashes matched. The clean identities
were `6bc98281969e1f024ce499d60e34f590485e311d1b718d5c853d324de51e10f9`,
`69890936a5d888b5be34f2389e05dcf741a589d0c5f4c9751916fcbd2fcfe5fc`, and
`d9ed8388507f3b2c1bf356bdbe9f7659beea1ea11b90ef66400cfad19a07cbab` for preprocessing, object, and executable.
This too is a component diagnostic, not qualification or validation. The corresponding Cabal suite is declared,
but pinned-local package attempts either remained in dependency resolution or reached the configured
zero-backjump refusal before any compiler ran; they are not package evidence. The canonical sprint-count literals
still need an atomic decision audit, and the refreshed package-opacity bracket, parent-harness qualification,
exact local inputs, source snapshot integrity, and documentation-gate correspondence inspection remain open. Sprint 0.4
therefore remains in its blocked, not-validated state.

## Sprint 0.5: Gate-kernel qualification and spoof corpus ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Gate.hs`, `test/validation-kernel/QualificationOracle.hs`
**Blocked by**: Sprint 0.4
**Independent Validation**: Inject every mandatory sabotage into the exact harness build, retain raw refusals, then prove the same build runs the clean subject; the qualifier cannot accept its own summary.
**Oracle**: `test/validation-kernel/QualificationOracle.hs`; component diagnostic exists, and its independent check is consolidated into the Phase-0 gate rather than requested as a sprint confirmation.
**Legacy IDs**: `LTD-VAL-001`, `LTD-VAL-002`
**Docs to update**: `documents/engineering/testing_spoof_resistance.md`, `documents/engineering/evidence_calculus_doctrine.md`

### Objective

Make constant success, no-op behaviour, empty discovery, unchanged mutants, wrong-locus failures, stale
evidence, self-observation, bypass, and residue mechanically unable to yield a candidate.

### Deliverables

- Fixed qualification sabotage algebra.
- Changed-production-subject mutation witnesses.
- Explicit per-row result schema with no default-to-tested path.

### Validation

Each sabotage is selected after the harness digest is fixed, must produce its distinct refusal observation,
and is followed by a clean candidate run over the same harness build.

### Remaining Work

The report-checking algebra and component diagnostic exist, but the fixed sabotage corpus has not been applied
to the exact dispatcher/harness build. A 2026-08-23 API audit confirmed that the caller-authored report API is
now explicitly named `checkQualificationReportDiagnostic`, its public input
records are explicitly diagnostic, and every result carries the exact permanent
`QUALIFICATION-REPORT-DIAGNOSTIC-ONLY` refusal. A changed-production mutant removes only that refusal and the
component oracle requires it, so the former caller-constructible green result is no longer available. On
2026-08-23 the focused clean `QualificationOracle` diagnostic completed; the focused diagnostic compiled with
`VALIDATION_QUALIFICATION_DIAGNOSTIC_BYPASS_MUTANT` refused because the exact permanent triple disappeared and
the same caller-authored report became green. The Cabal flag is registered, but this remains a focused local
changed-subject observation only: the aggregate runner, applied source/binary witnesses, and source snapshot integrity
are still pending. The development-plan and spoof-resistance standards now also forbid pre-authority adapters
from exporting conventional success branches, optional residue, arbitrary-result folds, or detachable
observations, and require oracle-local fixture types, literal limits, and exact full boundary projections. This
closes the documentation ambiguity exposed by the capture and compiler adapter tests but does not qualify
their implementations. The
opaque execution-derived report and qualifying supervisor remain absent: they must apply each changed
production subject, observe the exact binary and refusal locus, and then run the unmodified controls with the
same harness identity. Execute and retain those changed-subject witnesses once Sprint 0.4 is
implementation-ready. Independent oracle check stays phase-gate residue.

A 2026-08-24 fail-closed audit has also rejected the one-selector report checker as an implementation-complete
qualification seam. Its public records remain caller-constructible by design, but the diagnostic has no bounded
envelope before maps, sets, sorting, grouping, result observations, finding details, or unaffected-control lists;
it accepts any nonempty safe refusal detail instead of an exact independently assigned result; and its supplied
"unaffected controls" are merely caller-authored `CheckResult` values. The sole changed-production selector
removes the permanent diagnostic refusal. It does not cover the twelve sabotage-name/code mappings, baseline and
witness grammar conjuncts, inventory routing, exact refusal fields, result-name/observation projections, control
set/duplicate/red/observation predicates, finding mappings, result retention, or ordering. The oracle contains
no literal selector registry because no execution-derived supervisor exists yet. Sprint 0.5 must therefore build
the opaque bounded qualifying executor first, keep this report checker permanently diagnostic, and give every
independent executor/report predicate an oracle-owned selector, exact assigned row, applied subject/binary
witness, and genuinely executed unaffected control. The prior clean and diagnostic-bypass runs are rejected
baselines, not qualification.

## Sprint 0.6: Candidate evidence and gate-pass result ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Evidence.hs`, `src/validation-kernel/Amoebius/Validation/GatePass.hs`
**Blocked by**: Sprint 0.5
**Independent Validation**: One complete dispatcher-produced bundle whose required rows all pass is the positive control. Missing rows, red or refused required rows, stale source/contract/harness digests, a mismatched predecessor result, a partial run, and a status projection containing any non-status edit are exact negatives.
**Oracle**: `test/validation-kernel/EvidenceOracle.hs` and `test/validation-kernel/GatePassOracle.hs`, separately authored from the evidence and gate-pass implementations.
**Legacy IDs**: `LTD-VAL-003`, `LTD-VAL-004`
**Docs to update**: `AGENTS.md`, `documents/engineering/testing_spoof_resistance.md`, `DEVELOPMENT_PLAN/development_plan_phase_model.md`

### Objective

Make a complete qualified gate pass sufficient for the narrow status-only transition.

### Deliverables

- Candidate evidence schema with exact source, contract, harness, predecessor, observation, residue, and row bindings.
- A package-hidden `GatePass` decision that succeeds exactly when every required gate row succeeds.
- A status projection restricted to the tracker and the current phase and sprint status fields.
- The complete qualified gate pass is the only condition for its narrow status update.

### Validation

The positive candidate passes and permits only its exact status projection. Every minimally different stale,
partial, red-row, missing-row, predecessor-mismatch, or widened-projection candidate fails at its assigned locus.
Changed-subject mutants must red those exact cases while unrelated controls remain green.

### Remaining Work

The `GatePass` decision, its independent oracle, and local snapshot equality now pass in the aggregate component
suite. Connect the evidence writer to the qualified dispatcher, complete the closed
command/toolchain/substrate/run/cleanup schema, and qualify atomic no-follow evidence publication. The current
public evidence constructor remains diagnostic until that integrated execution path exists. Status completion
and source freshness remain expressed by the gate pass and exact local snapshot equality.

## Sprint 0.7: Check all numbered phase contracts ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `DEVELOPMENT_PLAN/phase_[0-9][0-9]_*.md`
**Blocked by**: Sprint 0.6
**Independent Validation**: Every phase has one fixed 18-row table, checked for structure and explicit `UNRESOLVED` state. Separately authored Haskell phase contracts pin subjects, oracles, controls, mutants, observers, typed legacy bindings, predecessors, residue, and the gate-pass criterion. The documentation gate checks correspondence with the table prose; no cell text supplies semantic behavior. Any structural `UNRESOLVED` row or missing Haskell binding refuses Phase 0 at its own locus.
**Oracle**: `test/validation-kernel/PhaseContractOracle.hs`; component diagnostic exists, and the consolidated Phase-0 gate check covers every oracle boundary without separate sprint confirmations.
**Legacy IDs**: `LTD-VAL-002`
**Docs to update**: all numbered phase contracts and their doctrine owners

### Objective

Replace every pre-reset gate with a phase-specific, non-spoofable contract in numerical order.

### Deliverables

- Canonical `pb validate phase NN` command in all 96 phases.
- Exactly eighteen required contract rows per phase.
- No operative Python runner, tracked serialized oracle, self-derived expectation, unwitnessed mutant, or
  machine pass criterion.

### Validation

The structural checker rejects missing/duplicate keys, unresolved fields, and forward or absent numerical
dependencies. Independent Haskell contract oracles reject missing subject/oracle bindings, self-derived
expectations, absent gate evidence, and missing typed legacy closure bindings. Generic prose, a semantic
keyword, or a changed `Legacy IDs` cell cannot create a pass; complete gate execution owns semantic prose correspondence.

### Remaining Work

Resolve the 1,728 exact-prefix `UNRESOLVED` gate cells across all 96 contracts and replace each explicit
`UNRESOLVED` sprint binding with one tested semantic value from its owning phase; the mechanical sprint
envelopes and immediate blocker edges are now complete. Complete the phase-by-phase contract tests once
Sprint 0.6 is implementation-ready. The predecessor placeholders now specify typed gate-pass inputs,
but those results cannot exist before the numerical predecessor passes.
Every affected phase remains shut meanwhile.

## Sprint 0.8: Integrated Phase-0 candidate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Dispatch.hs`, `app/amoebius/Main.hs`
**Blocked by**: Sprint 0.7
**Independent Validation**: From an empty generated tree, the exact absolute source-built Haskell executable is invoked directly with `validate phase 00`; it qualifies the harness, runs the clean corpus, resolves every Phase-0-owned typed Haskell legacy binding to zero for the first time, emits explicit candidate evidence, and returns one complete pass/fail result. `pb` is unavailable as validation transport. If an owning gate has retired an ID by this point, its qualified owner-domain reintroduction negative remains compiled while its explanation is absent from the active-only Markdown register. Markdown register contents are unavailable to the legacy semantic verdict.
**Oracle**: `test/validation-kernel/Main.hs` currently composes component diagnostics only; a separate integration oracle and the single consolidated Phase-0 gate execution remain absent.
**Legacy IDs**: `LTD-SRC-000`, `LTD-SRC-008`, `LTD-VAL-001`, `LTD-VAL-002`, `LTD-VAL-003`, `LTD-VAL-004`
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only after the pass criterion records the pass

### Objective

Produce and run the first admissible complete phase gate.

### Deliverables

- One Haskell-owned phase dispatcher.
- Qualified raw observations and schema-checked candidate bundle under `.build/runs/phase-00/candidates/**`.
- Exact gate-pass result and its narrow status-only projection.

### Validation

Run the full Gate-integrity table. If every required row succeeds in the qualified run, the result is sufficient
to make Phase 0 pass; otherwise Phase 0 remains NOT VALIDATED.

### Remaining Work

The dispatcher and current nonconforming `pb/**` implementation are observed footprints, not an integrated
candidate path. The opaque `pb` handoff remains a target with no conforming implementation. Qualification
execution, clean-room observation, evidence-writer integration, contract resolution, oracle independence,
legacy closure, and the complete gate result remain open.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/documentation_standards.md` — only if the governed document mechanics change.
- `documents/engineering/repository_layout_doctrine.md` — only if the closed source tree changes.
- `documents/engineering/testing_spoof_resistance.md` — only if the trust or qualification boundary changes.
- `documents/engineering/conformance_harness_doctrine.md` — only if the later pre-hardware barrier changes.

**Cross-references to add:**

- Actual inbound links discovered by the Haskell link-graph checker, reconciled in the same change.

## Related Documents

- [Development-plan tracker](README.md)
- [Development-plan standards](development_plan_standards.md)
- [Gate integrity](development_plan_gate_integrity.md)
- [Reader-facing legacy register](legacy_tracking_for_deletion.md) — active-only prose correspondence; typed
  Haskell owns lifecycle, dispatch, owner-analyzer closure, and required reintroduction-case identities; the
  owning analyzer supplies a qualified negative before any future retirement
- [Migration doctrine](../documents/engineering/migration_doctrine.md) — retirement keeps the qualified negative
  and removes only the explanation after the owning gate passes
- [Documentation standards](../documents/documentation_standards.md)
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
- [No-cluster conformance harness](../documents/engineering/conformance_harness_doctrine.md)
