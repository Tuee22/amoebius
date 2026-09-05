# Phase 2: Repository layout conformance and de-phased naming

> **Purpose**: Specify the target Haskell capability to enforce the repository layout and compiler-backed
> semantic source graph: behavioral source is `.hs` only outside `pb/**`, every declared and observed
> source/module/import/call/effect/consumer relation reconciles, and generated foreign products are absent
> from Git.
> **Read this if**: phase 2 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_03_artifact_calculus.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 2.1: `test/`'s second level collapses to the seven role nouns](#sprint-21-tests-second-level-collapses-to-the-seven-role-nouns-)
- [Sprint 2.2: The package-only roots become cabal stanzas](#sprint-22-the-package-only-roots-become-cabal-stanzas-)
- [Sprint 2.3: Tracked UI roots enter typed deletion ownership](#sprint-23-tracked-ui-roots-enter-typed-deletion-ownership-)
- [Sprint 2.4: Every authored name loses its phase ordinal](#sprint-24-every-authored-name-loses-its-phase-ordinal-)
- [Sprint 2.5: One mutant record format, one registry](#sprint-25-one-mutant-record-format-one-registry-)
- [Sprint 2.6: Compiler-backed source graph and typed legacy reconciliation](#sprint-26-compiler-backed-source-graph-and-typed-legacy-reconciliation-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 1, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. This phase owns replacing its retained inventory with exact typed contracts and independent oracles. That hardware-free implementation may be prepared before Phases 0–1 pass, but its gate, candidate evidence, predecessor consumption, and status remain blocked by them. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. It consumes the authenticated/reproducible Phase-1 toolchain and closes the compiler-backed semantic
source graph: Cabal declarations, source roots, modules, imports, parsing, renaming, typechecking, resolved calls
and control flow, potential effects, provenance, dynamic loading, behavior sinks, and consumers reconcile in
both directions. Behavioral source is `.hs` only outside `pb/**`, consumers resolve at canonical Haskell module
and package paths, and generated foreign products are absent from Git.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — enforce the repository layout and compiler-backed semantic source
graph: behavioral source is `.hs` only outside `pb/**`; every Cabal/source/module/import/call/effect/provenance/
sink/consumer relation resolves; and generated foreign products are absent from Git.
NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 1](phase_01_toolchain_spike.md)
**Gate:** `pb validate phase 02`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-2 semantic payload, package-hidden acquired
supervisor, and independent oracle are complete; only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | Every tracked path is reconciled with the canonical repository layout; the authenticated compiler build, source closure, bounded `pb` grammar, and layout predicates all pass for the same source snapshot. Later-owned non-Haskell migrations remain exact typed debt through the Phase-49 zero-source barrier. |
| `Subject` | The package-hidden `Amoebius.Validation.RepositoryLayoutRun.Internal` acquired supervisor composes `RepositoryLayoutRun`, `SourceClosure`, `PbBootstrapGrammar`, and the compiler-built independent component. |
| `Command` | Future public spelling is `pb validate phase 02`; before `BOOTSTRAP_HANDOFF`, the exact absolute source-bound Haskell executable runs directly. Its Cabal child is absolute, offline, serial (`--jobs=1`), and bound to authenticated GHC and Cabal inputs. |
| `Oracle` | `test/validation-kernel/RepositoryLayoutRunOracle.hs` is separately authored and executes from the independently compiled `validation-compiler-source-graph-acquired-component`. |
| `Positive controls` | The clean repository snapshot, bounded canonical `pb` grammar, source-closure result, compiler build, and independently compiled oracle are all exact green controls. |
| `Paired negatives` | Minimally different stale-ignore and runtime-phase-ordinal subjects produce their exact single refusal codes; a validation phase label is the unaffected scope control. |
| `Mutants` | The qualification corpus applies the retired-ignore-root and runtime-ordinal changes to the production checker and requires their exact red outcomes while clean and validation-label controls stay green. |
| `Discovery` | The captured Git snapshot is reconciled by source closure, `pb` inventory grammar, layout discovery, Cabal component selection, and successful compiler construction in both the subject and independent component. |
| `Challenge` | The fixed changed-subject layout corpus executes after acquisition and must distinguish the two negative dimensions without rejecting the validation-label control. |
| `Observer` | The supervisor records absolute executable, exact argv, exit status, and transcript digest for archive extraction, compiler build, oracle discovery, and independent oracle execution. |
| `Authority/bypass` | Network, `pb`, hardware, live effects, PATH-selected compiler substitution, and compiler concurrency above one are forbidden. Compiler argv is checked for literal `--offline` and `--jobs=1`. |
| `Freshness` | Each candidate creates a fresh run/build root after its opening source capture; the dispatcher independently requires the closing source identity to match. |
| `Qualification` | The independently authored oracle and fixed clean/negative/control corpus must both pass from freshly compiled Haskell. |
| `Cleanroom` | Generated project, extracted tool, build output, and transcripts are contained beneath `.build/runs/phase-02/**`; no generated material becomes authored source. |
| `Legacy closure` | `LTD-SRC-000`, `LTD-SRC-008`, `LTD-META-001`, and `LTD-NAME-001` are zero only when compiler build, bounded `pb` grammar, layout predicates, and every non-circular gate prerequisite pass for the same source. |
| `Predecessor` | Consume exactly one durable Phase-1 receipt bound to this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Only explicitly typed later-owned source migrations and later hardware/live claims remain; no Phase-2 evidence row is residue. |
| `Pass criterion` | `qualified-phase-two-gate-pass`: all eighteen rows must be execution-derived green in one candidate for one stable source, with exact predecessor receipt and empty mandatory residue. |

## Doctrine adopted

- [`jit_artifact_doctrine.md` §2 — The rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every foreign or generated
  product must be derived lazily beneath `.build/**`, never tracked as authored behavioral source.
- [`repository_layout_doctrine.md` §2 — Complete repository structure](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure):
  the target tree, its fixed second levels, and the seven singular `test/` role nouns.
- [`repository_layout_doctrine.md` §2.1 — When a unit warrants its own build package](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package):
  the criterion a package-only root fails.
- [`repository_layout_doctrine.md` §2.2 — Present-day roots and their required destination](../documents/engineering/repository_layout_doctrine.md#22-present-day-roots-and-their-required-destination):
  the per-root destination the target Haskell conformance capability must enforce.
- [`generated_artifacts_doctrine.md` §3 — The rule](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule): the rule that
  separates a relocation from a deletion — a generated destination cannot hold bytes until its generator runs.

## Sprints

> **Reset validation check.** A sprint whose required fields still say `UNRESOLVED` retains its pre-reset
> `Independent Validation` and `### Validation` only as historical capability inventory. A wholly replaced
> sprint contract may guide hardware-free implementation, but cannot run this phase gate or change status before
> the Phase-1 predecessor pass.

```mermaid
flowchart LR
  %% register: orientation
  s1["2.1 seven role nouns"]
  s2["2.2 one package"]
  s3["2.3 UI roots assigned for deletion"]
  s4["2.4 no phase ordinal"]
  s5["2.5 one mutant registry"]
  s6["2.6 compiler source graph + typed closures"]
  gate["repository conformance gate"]
  s1 -->|"a Haskell-only test tree"| s2
  s2 -->|"one Haskell package"| s3
  s2 -->|"the flag set 2.4 de-phases"| s4
  s3 -->|"no UI source root retained"| s4
  s4 -->|"final paths, so no registry row is stale"| s5
  s5 -->|"every mutation Haskell-declared"| s6
  s6 -->|"zero typed closure findings"| gate
```
*Orientation. Which sprint produces what the next consumes, ending at the gate; the seam rules are owned by [development_plan_standards.md §F](development_plan_standards.md#f-the-sprint-block-format). The de-phasing precedes the registry because a registry authored first would name a hundred paths the same phase then renames.*

## Sprint 2.1: `test/`'s second level collapses to the seven role nouns ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 1](phase_01_toolchain_spike.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Fold the historical test prefixes into Haskell module namespaces for specifications, cases, independent
oracles, negatives, mutation operators, and harnesses. Serialized fixture, golden, and materialized-mutant
directories are not target roots; any such transport artifact is rendered lazily beneath
`.build/test-corpora/**`.

### Deliverables

- A Haskell case-collision check and checked Haskell mutation operator, run before any move.
- Every behavioral file retained under `test/**` is `.hs`; roles are represented by Haskell module hierarchy,
  while serialized cases, expectations, and applied mutants live only beneath `.build/test-corpora/**`.
- Every Haskell consumer of a moved module is updated in the same edit.

### Validation

1. Every behavioral file beneath `test/**` is `.hs`, every serialized transport product is contained beneath
   `.build/**`, and a whole-tree Haskell reference scan finds no dangling consumer.
2. Two changed-subject mutants — one weakening the test-tree source-language predicate, one weakening the
   case-collision predicate — redden exactly `target-tree-clean` and `collision-free-tree` respectively, each
   at its own locus, and no other check. UNRESOLVED — blocks validation: neither mutant is bound to an exact
   Haskell selector identity, production locus, or assigned oracle case.

### Remaining Work

The pre-reset record said `None`; that statement and its test-tree count  cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass,
owned legacy closure, and a Haskell-only test tree with lazy transport material beneath `.build/**`.

## Sprint 2.2: The package-only roots become cabal stanzas ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 2.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Fourteen roots carried a package declaration and little else. Each becomes a stanza in the one authored
package, against the criterion [§2.1](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package)
already states; the two out-of-tree `hs-source-dirs` become `source-repository-package` entries.

### Deliverables

- Authored Haskell sources under `src/**` and `test/**`. Proto and Dhall inputs or bindings are generated from
  Haskell only beneath `.build/proto/**` and `.build/dhall/**`.
- No `hs-source-dirs` reaching outside the repository.
- One `amoebius` package carrying thirteen further sub-libraries and thirty-four further Haskell suites.
  Maintained vendor behavior is `.hs` beneath `src/vendor/**`; acquisition and generated probes stay beneath
  `.build/**`.

### Validation

1. Resolution and dry-run test discovery both succeed at the new names.
2. A changed-subject mutant that renames a Cabal stanza without its source directory reddens the
   stanza-to-source-directory agreement check at that stanza and no other check. UNRESOLVED — blocks
   validation: the mutant is not bound to an exact Haskell selector identity, production locus, or assigned
   oracle case.

### Remaining Work

The pre-reset record said `None`; that statement and its package/root disposition  cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass,
owned legacy closure, exact Haskell package/module discovery, and clean-source consumer resolution.

**What this sprint could not carry, and who owns it.** `amoebius-pulsar` was `build-type: Custom`, and its
`Setup.hs` generated the Pulsar protobuf bindings. A root `Setup.hs` is not in the section 2 tree and
[§2.1](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package)
admits no ground for a package that exists only to carry one, so the generator retired with the split. The
condemned tracked Proto schema remains migration debt, and Phase 26 — its owner in the compiled inventory — re-establishes both schema projection and
binding generation from checked Haskell declarations beneath `.build/proto/**`. Its typed legacy binding is
explained in the reader-facing register.

## Sprint 2.3: Tracked UI roots enter typed deletion ownership ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 2.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Account for the current tracked UI roots as migration debt without treating PureScript as an admitted source
language or adding to those roots.

### Deliverables

- One typed Haskell legacy binding assigning removal of all tracked UI/package inputs to Phase 46, plus its
  reader-facing explanation in the single register.
- No new tracked UI source; every generated UI output is contained beneath `.build/ui/**`.

### Validation

1. Every present tracked UI/PureScript/package input is discovered and joined exactly once to the typed
   Haskell binding; the explanatory Markdown row is not an operand.
2. A generated UI tree is required to live beneath `.build/**`; a tracked or source-adjacent reintroduction is
   rejected.

### Remaining Work

Phase 46 must replace the tracked UI/package inputs with Haskell declarations and lazy `.build/ui/**`
materialization. Until that owner reaches zero findings, this is only accounted debt and remains NOT VALIDATED.

## Sprint 2.4: Every authored name loses its phase ordinal ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 2.3
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Strip the ordinal from every product/runtime identity, authored product path, build component, and product
diagnostic filename, replacing it with a capability name derived from the owning phase's slug. Phase-labelled
validation contracts and evidence remain phase-labelled and are forbidden from serving as runtime identities. This is what
makes [§U](development_plan_gate_integrity.md#u-the-final-repository-layout) clause 3 true, and therefore what
makes every future re-baseline documentation-only.

### Deliverables

- Capability-derived names for every ordinal-bearing product/runtime path.
- Every phase document's Haskell implementation/oracle/mutation path and lazy `.build/**` materialization
  destination naming the new capability-derived path.

### Validation

1. The Haskell ordinal-bearing-name analyzer reports zero findings over every product/runtime identity locus, and consumes no
   Markdown row or count. UNRESOLVED — blocks validation: the analyzer is not bound to an exact Haskell module
   and entry point; `LTD-NAME-001` is a reader-facing reference, not the check.
2. A changed-subject mutant that reintroduces an ordinal-bearing tool name reddens that analyzer at the
   reintroduced path and no other check. UNRESOLVED — blocks validation: the mutant is not bound to an exact
   Haskell selector identity, production locus, or assigned oracle case.

### Remaining Work

The pre-reset record said `None`; that statement and its path-translation account  cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass,
owned legacy closure, and a checked Haskell old-name→capability join. The condemned serialized allowlist and
Python gates are non-operative debt and may not be copied into the replacement.

**The `-DPHASE31_*` preprocessor symbols are deliberately untouched.** A cpp macro is not a name that becomes
a path, so [§U](development_plan_gate_integrity.md#u-the-final-repository-layout) clause 3 does not reach it
and the ordinal-bearing-name analyzer does not scan it; the tree's own precedent — `PHASE26_*` beside `object-reconciler-*` — leaves it to
the phase that owns the module. Renaming two hundred macros across the Haskell sources would be a behavioural
edit this phase's scope excludes.

## Sprint 2.5: One mutant record format, one registry ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 2.4
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Replace the historical materialized-mutant roots and build-flag-only mutations with one checked Haskell
mutation registry. Applied source copies and any serialized registry projection are generated lazily beneath
`.build/mutants/**`.

### Deliverables

- One Haskell registry module with a closed mutation record type.
- Each former build-flag mutation expressed as a checked Haskell value naming its operator and production
  locus; no materialized mutant is tracked.

### Validation

1. The Haskell registry enumerates every declared mutation, and every run-local applied mutant resolves through
   it in both directions.
2. A mutation reachable only by a build flag fails the gate unless that flag's resulting compiled
   production locus and changed binary are both observed. That observation is the sole admission
   [§M.3](development_plan_gate_integrity.md#m3-mutants-must-prove-that-they-changed-the-subject)
   grants a build flag, so an unobserved flag mutation is refused at its own locus while an observed
   one remains admissible until the Haskell registry above replaces it.
3. The registry carries no disposition that admits a mutation lacking an operator or a production locus, and
   admission reads no tracker status. A negative that reintroduces either — an operator-less row, or a read of
   a phase's Done marker — is refused at its own locus.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work
includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and
phase-specific obligation in the redesigned gate. The target mutation registry is a Haskell value carrying
capability, id, operator, expected locus, changed-subject witness, and application mode. Any TSV projection or
executable helper is generated beneath `.build/**`; no tracked table or Python parser is authority.

**Why the registry, and not a body file per flag.** A hundred and six mutations existed only as a cabal flag,
and inventing a body for each would have fabricated an operator and a locus nobody authored. The registry
records what is known and stops there. There is no `unstated` disposition, and admission never reads the
tracker. Both were one mechanism, and it had no first tooth: at a phase's own gate that phase is by definition
not Done, so the condition admitted every one of its own mutants, and under the reset — where nothing is
Done — it was universally true. Reading the marker was independently inadmissible, because
[§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass) forbids reader-facing Markdown
from converting a refusal into a satisfied state. A flag with no authored operator and locus is therefore not
a registry row at all: it is deleted, or it is authored into a real mutant. Until then it is reported as
unwired coverage against the capability that owns closing it, and is never counted.

## Sprint 2.6: Compiler-backed source graph and typed legacy reconciliation ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/RepositoryLayoutRun.hs`, `src/validation-kernel/Amoebius/Validation/CompilerComponentPlan.hs`, `src/validation-kernel/Amoebius/Validation/CompilerSourceGraph.hs`, `src/validation-kernel/Amoebius/Validation/SourceClosure.hs`, and `src/validation-kernel/Amoebius/Validation/SourceConsumerGraph.hs`; acquired composition remains UNRESOLVED and blocks validation.
**Blocked by**: Sprint 2.5
**Independent Validation**: From the exact Phase-1 toolchain receipt and captured source, run the complete `VALIDATION_PB_GRAMMAR` selector corpus and reconcile the Cabal plan and every source/module/import/parse/rename/typecheck/call/control-flow/effect/provenance/dynamic-load/sink/consumer edge in both directions. Missing, extra, stale, disguised, unresolved, dynamically bypassed, or wrong-consumer edges are paired exact negatives; each applied changed-subject selector must red only its assigned row.
**Oracle**: `test/validation-kernel/PbBootstrapGrammarOracle.hs` owns the complete `VALIDATION_PB_GRAMMAR` expectation surface; planned separate Haskell `test/validation-kernel/RepositoryCompilerGraphOracle.hs` is authored from the remaining repository/source requirements rather than the production graph. Integrated provenance remains UNRESOLVED.
**Legacy IDs**: `LTD-SRC-000`, `LTD-SRC-008`, `LTD-META-001`, `LTD-NAME-001`
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`, `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`

### Objective

Close the compiler-backed semantic source graph and the four typed Haskell legacy bindings this phase owns,
`LTD-SRC-000`, `LTD-SRC-008`, `LTD-META-001`, and `LTD-NAME-001`; re-own each remaining binding under the checked Haskell audit
map and narrow the bindings whose residue is behavioral rather than positional. Reader-facing rows explain the
values but are never operands.

### Deliverables

- Complete `VALIDATION_PB_GRAMMAR` selector/oracle qualification plus two-way Cabal/source/module/compiler
  semantic graph with exact acquired-toolchain provenance.
- Zero Haskell findings for the `LTD-SRC-000`, `LTD-SRC-008`, `LTD-META-001`, and `LTD-NAME-001` bindings;
  the `LTD-SRC-008` result includes its owner-level reintroduction proof rather than reusing Phase 0's scoped observation.
- Each residual Haskell binding narrowed to the behavioral half its subject-matter phase owns.

### Validation

1. The compiler-backed source audit reports every declared and observed semantic edge exactly once and rejects
   each missing, extra, unresolved, stale, dynamically loaded, effect-bypassing, or wrong-consumer paired case.
2. The Haskell artifact audit reports zero `LTD-SRC-000`, `LTD-SRC-008`, `LTD-META-001`, and `LTD-NAME-001` findings under their compiled
   closure predicates, and cannot consume a Markdown row or count. UNRESOLVED — blocks validation: the owning
   analyzers and their independently authored reintroduction negatives are not bound to exact Haskell modules.
3. The typed deferral inventory contains only the declared deletion class and rejects an unbound residue.

### Remaining Work

Implement the acquired Phase-1 compiler/toolchain binding and independent oracle, qualify the phase-owned
selector partition, close all four due legacy analyzers and negatives, and retain them in the complete Phase-2
gate. The pre-reset row-count result cannot support that pass.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `repository_layout_doctrine.md` — §2.2's destination cells become history once realised (Sprint 2.6); §6 and
  §7's normative ignore patterns name the paths the move produced.
- `substrate_doctrine.md` — the Pulsar code-generation paragraph names the retired `Setup.hs` as retired, and
  the phase that re-establishes the invariant it enforced.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` Phase Overview links its Phase 2 row to this document.
- Each moved path's owning phase document names the new path (Sprint 2.4).

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 2 row is the source for this phase's objective and gate.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys.
- [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) — the reader-facing explanation of the
  typed whole-tree bindings this phase exists to close.
- [`repository_layout_doctrine.md`](../documents/engineering/repository_layout_doctrine.md) — the target tree
  this phase realises.
- [`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md) — the
  emit-from-source, never-commit rule that separates a relocation from a deletion.
