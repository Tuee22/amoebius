# Phase 0: Documentation, source policy, and validation trust root

> **Purpose**: Establish one coherent documentation corpus, the closed Haskell source boundary, the qualified
> Haskell gate kernel, and human-only validation promotion before any product phase opens.
> **Read this if**: Phase 0 is active, a cross-cutting rule changes, or later work needs to know what its trust
> root must establish first.

Phase 0 owns the repository's documentary and validation floor. It does not validate the DSL or any runtime
capability; Phase 49 owns the complete no-hardware DSL barrier. It makes those later claims possible without
trusting Python wrappers, tracked generated fixtures, self-reported evidence, or historical status.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, documents/documentation_standards.md, documents/engineering/migration_doctrine.md, pb/README.md
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
- [Sprint 0.6: Candidate evidence and human approval boundary ⏸️](#sprint-06-candidate-evidence-and-human-approval-boundary-)
- [Sprint 0.7: Review all numbered phase contracts ⏸️](#sprint-07-review-all-numbered-phase-contracts-)
- [Sprint 0.8: Integrated Phase-0 candidate ⏸️](#sprint-08-integrated-phase-0-candidate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

🔄 Active — NOT VALIDATED.

The reset status is exact: Phase 0 is Active — NOT VALIDATED; every Phase 1 through Phase 95 is Blocked — NOT
VALIDATED; and every sprint in every phase is NOT VALIDATED. Every prior pass, Done marker, seal, receipt,
attestation, hash, completion statement, or implementation result is permanently invalid as current
validation evidence. Existing machinery is an **Observed footprint / Known partial**. This phase is active
only for the documentation, tracked-source, and validation-authority reset. No later implementation or
promotion gate may open until a qualified Phase-0 candidate is reviewed and the human validation authority
personally promotes this phase.

---

## Phase Summary

Phase 0 makes the repository say one thing in one place and installs the mechanism that can refuse future
drift. The reset fixes these target decisions without claiming they are validated: behavioural source is Haskell; `pb/**` is the only non-Haskell
source exception and only bootstraps/execs Haskell; every reproducible non-Haskell artifact is generated lazily
beneath `.build/**`; the in-cluster OCI service is exclusively Distribution `registry:2`; one
active legacy register replaces every archive; and every phase is NOT VALIDATED until human promotion in
strict numerical order.

An **Observed footprint / Known partial** of the target Haskell validation kernel now exists beneath
`src/validation-kernel/Amoebius/Validation/**`. It includes the typed cross-cutting policy contract, source
closure, legacy-register, documentation, phase-contract, qualification-report, candidate-evidence,
approval-verification, and dispatch modules. The
component-oracle footprint is beneath `test/validation-kernel/**`. Current `pb/**` still parses public verbs,
contains broader bootstrap/admin/test/check behavior, and exposes no conforming opaque validation handoff.
All 15 current paths are therefore frozen as `LTD-SRC-008`: token scanning cannot prove the absence of hidden
Python behavior, so Phase 0 must statically prove the exact minimal-platform-discrimination,
contained-toolchain-establishment, source-bound-build, opaque-exec source graph before `pb` may remain as the
sole non-Haskell source exception. That source-admission proof does not claim the handoff ran; Phase 50 alone
owns its external runtime observation. The general classifier also lacks a semantic parser/consumer/effect graph
for disguised source. Its tracked regular-file reads are descriptor-pinned and its final index binding observes
concealment flags, but authored-root recursion still uses path-based directory queries and is vulnerable to
ancestor-symlink and replacement races. All of this remains same-workstream component work that has not been
independently qualified or externally observed.

A 2026-08-22 supporting `cabal build lib:validation-kernel exe:amoebius` diagnostic and unmutated
`cabal test validation-kernel-component` component diagnostic completed successfully. In each separate build
that widened the compiled Registry-provider universe, redirected the compiled owner map, or admitted `pb` as
transport before Phase 50, the runner executed all nine named component oracles; only `PolicyContractOracle`
failed. The other eight oracles stayed green. Those observations establish only
compilation and component behaviour; they are not harness qualification, independent human review, clean-room
observation, a Phase-0 candidate, or validation. The dispatcher intentionally refuses a
candidate because the fixed sabotage corpus has not been executed against its exact build, independent human
review and key custody are absent, no external clean-room observer is connected, and the evidence writer is
not integrated. Its candidate schema also lacks closed typed command, toolchain, substrate, run-identity, and
cleanup fields, and no reviewed binding connects the repository's Git object-format identity to the required
SHA-256 evidence provenance. The current worktree is also dirty, so clean source-snapshot acquisition must refuse. In the
current corpus, 93 phase contracts still contain 1,290 `UNRESOLVED` gate cells and 92 `MISSING`
predecessor cells: 1,382 fail-closed cells in total. Phase 0 therefore
remains Active — NOT VALIDATED, and Phase 1 remains shut.

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

**Contract review**: REWRITTEN — NOT VALIDATED; an implementation footprint exists, but qualification,
clean-room observation, evidence integration, independent human review, and key custody remain open.

| Key | Phase-0 contract |
|---|---|
| `Claim` | The governed corpus has one structural owner/link surface; all current statuses are explicitly NOT VALIDATED; the executable cross-cutting decisions live in one typed Haskell `PolicyContract` awaiting independent human review; every tracked path is classified exactly once; and every present source-boundary violation joins in both directions to one strictly-later typed Haskell legacy binding. No Phase-0-owned source-policy or validation-integrity violation may remain, and the qualified Haskell kernel must refuse every specified spoof. The Markdown register is reader-facing only: its rows, cells, IDs, owners, predicates, and counts cannot affect the join or closure verdict. Natural-language correspondence is a human-review obligation, never a machine-parsed verdict. Phase 0 does not claim that later-owned source migrations, DSL semantics, or runtime behaviour are complete. |
| `Subject` | Observed production entry points beneath `src/validation-kernel/Amoebius/Validation/**`: `Dispatch.validatePhase`, `PolicyContract.checkPolicyContract`, `Documentation.checkCorpus`, `PhaseContract.checkPhaseContracts`, `SourceClosure.classifySnapshot`, `Legacy.legacyCheck`, `Gate.checkQualificationReport`, `Evidence.candidateFromChecks`, and `Approval.verifyApproval`. The typed contract feeds dispatch bounds, status syntax, owner-anchor checks, structural register-path/archive checks, source classification, Phase-49 source closure, phase ordering, and promotion authority. `Amoebius.Validation.Legacy` must own a closed 25-constructor legacy-ID universe, total owner/lifecycle/required-analyzer bindings, and total dispatch that returns a typed unavailable state whenever the selected analyzer is absent. A due or retired unavailable analyzer refuses; before its owner an active unavailable analyzer is explicit later-owned debt and cannot claim closure. Sprint 0.2 owns that inventory and delegation seam only; observation/closure analyzers and their domain reintroduction negatives belong to their owning sprints. A retired ID remains in Haskell as a reintroduction guard after its active-only Markdown explanation is removed. Fields for later unimplemented behavior remain typed requirements rather than claims that a consumer exists. This footprint is unqualified; evidence and approval remain refusal-only; all current `pb/**` is Phase-0 debt, not a validation subject. |
| `Command` | Future public target: `pb validate phase 00`; it is not currently an admissible validation transport. The Phase-0 candidate must build and invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. Phase 50 alone may validate the already source-bounded `pb` ensure/build/unchanged-argv/exec runtime handoff. The Haskell binary owns discovery, observations, schema checks, and the candidate verdict. |
| `Oracle` | Separate component modules exist under `test/validation-kernel/`, including `PolicyContractOracle.hs`. It separately restates every closed enum universe, the exact selected values and owner map, canonical bytes and digest, and code/subject/detail expectations for focused negatives. The component runner executes every named oracle before aggregating failure, but neither independent authorship nor custody, harness qualification, or human prose-correspondence review is established. Reviewer assignment and custody remain absent and block validation. |
| `Positive controls` | The complete governed path/link/metadata graph and tracked source snapshot, plus structural parser corpora that are explicitly incapable of becoming candidates. Production and oracle modules separately state every closed policy universe, the typed provider choice, decision-owner map, canonical policy bytes, source partition, and frozen later-owned source fingerprints. No independent human review is claimed. A human must separately compare the prose diff with the typed `PolicyContract`. |
| `Paired negatives` | Minimally different input pairs cover missing or unexpected governed paths, malformed metadata, broken links, a deleted typed Haskell legacy ID, duplicate stable-ID encoding, a missing or wrong owner/required-analyzer binding, dispatch that accepts an unavailable analyzer, a removed retired-ID guard, changed paths inside an open source family, non-Haskell behavioural source, disguised executables, widened `pb` behavior, missing `NOT VALIDATED`, malformed gate rows, forward dependencies, empty discovery, and generated output in an authored root. Policy value negatives remove one `pb` operation, redirect or omit one owner, select or rename the eliminated archive path, swap two phase roles, or admit hardware at Phase 51; each pins finding code, subject, and a distinguishing detail. Editing any legacy-register row, ID spelling, owner cell, predicate string, or count must leave the behavioral verdict unchanged; human review must still report the prose-correspondence defect. The Registry provider has no runtime alternate-input constructor; widening that closed production type is a changed-subject mutant, not a fabricated paired input. |
| `Mutants` | Required changed-production-subject operators weaken source classification, skip one governed document, accept an empty gate table, treat evidence as approval, ignore one compiled Haskell legacy binding, or accept a second registry. Each records the applied Haskell-source change and must redden only its named oracle row while unaffected controls stay green. A Markdown register edit is a prose-correspondence case, never this mutation operator. |
| `Discovery` | The Haskell kernel enumerates all tracked paths and all governed Markdown at run time and joins each in both directions to independently derived expectations. Zero files, a missing root, an unclassified path, a duplicate path, or an unexpected governed file refuses the run. |
| `Challenge` | Pure claim: a live nonce is inapplicable. Qualification instead selects run-local sabotage cases after the clean snapshot is fixed; the human reviewer must approve this substitution. |
| `Observer` | Component oracles separately inspect the raw snapshot bytes, modes, shebangs, path inventory, metadata fields, headings, links, anchors, dependencies, status fields, and fixed gate-table shape made available at their seams rather than accepting a compliance summary emitted by the classifier. Independent custody is absent. They never interpret natural-language policy as a verdict, and a missing or partial seam read fails closed. |
| `Authority/bypass` | Source-policy bypass probes cover extensionless files, misleading extensions, executable bits, shebangs, symlinks, ignored inputs, generated copies, widened `pb` behavior, and a policy-looking prose decoy that must have no effect. Only the typed Haskell contract and structured source/config observations govern behavior. Human approval verification rejects absent, automation-authored, wrong-key, wrong-source, stale-contract, and replayed receipts. |
| `Freshness` | The candidate uses a fresh snapshot and run root with all generated/state roots absent; prior evidence, cached discovery, ignored inputs, and copied status are unusable. Source and contract digests are provenance only. |
| `Qualification` | Before the clean run, the same Haskell harness must reject constant success, no-op subject, wrong output, empty discovery, missing subject/oracle, skipped/no-op mutant, wrong-locus failure, stale evidence, self-observer, authority bypass, residue, and smuggled generated/legacy input. |
| `Cleanroom` | Run from the tracked snapshot with `.build/**`, `.data/**`, `.test_data/**`, source-adjacent caches, and condemned legacy copies absent. All compiler output, synthetic corpora, observations, and raw candidate evidence are generated beneath one `.build/runs/phase-00/**` run root; the tracked tree remains unchanged. The current dirty worktree is ineligible. |
| `Legacy closure` | Sprint 0.2 must independently pin the closed 25-ID Haskell inventory, total owner/lifecycle/required-analyzer bindings, and total fail-closed dispatch. It does not make an owner-domain query zero. The owning sprint supplies each typed observation/closure analyzer and independently authored domain reintroduction negative; an absent analyzer, missing negative, or open due query refuses. Sprint 0.8 is the first point at which all Phase-0-owned queries—`LTD-SRC-000`, `LTD-SRC-008`, and `LTD-VAL-001` through `LTD-VAL-004`—must jointly be zero, alongside the complete source partition, frozen later-owned source fingerprints, and an exact non-empty static `PbBootstrapGrammar` AST/import/resolved-call/control-flow/potential-effect proof. Runtime effect, executable-identity, unchanged-argv, and exec-replacement evidence is explicitly excluded and remains Phase-50 residue. Retirement changes an ID's lifecycle state but preserves its Haskell reintroduction guard; only its active-only Markdown explanation is removed after human acceptance. The structural seam may require exactly one canonical UTF-8-readable register and no archive alias, while the general documentation checker may enforce ordinary structure. Neither may interpret Markdown row content as a binding or verdict. Human review owns correspondence. |
| `Predecessor` | `genesis`; there is no prior numbered phase. The human approval trust root predates and is outside the candidate. |
| `Residue` | `UNVERIFIED`: qualification of all three `PolicyContract` changed-subject mutants and human prose-correspondence review; a dispatcher-composition bypass mutant; complete document-shape enforcement assigned to Sprint 0.4; the `LTD-SRC-008` Python-boundary closure; a semantic parser/consumer/effect graph that detects disguised behavioral content in otherwise admitted non-source files; a descriptor-relative `openat`/no-follow authored-root walk with ancestor-symlink, ignored-input, special-file, and replacement-race mutants; changed-subject qualification and external clean-room observation of the Git concealment, descriptor-pinned byte/mode, authored-root, and final index-binding checks; independent Git-blob hashing rather than trust in reported object IDs; all product/DSL/runtime semantics; semantic phase-contract joins; every owner-sprint analyzer and domain reintroduction negative behind the total legacy dispatcher; execution of the fixed qualification corpus against the exact integrated harness; independent reviewer and key custody; authenticated Git/tool acquisition; candidate-evidence integration; a closed typed evidence schema for exact command, toolchain, substrate/lane/architecture, run identity, and cleanup; a reviewed binding between Git object-format identity and SHA-256 evidence provenance; 1,290 unresolved-marker cells plus 92 absent-predecessor cells across 93 later contracts; the sentence-budget backlog; external approval operation; and every tracked-source migration owned by a later phase. |
| `Human authority` | `human-only`: automation and LLMs may report a candidate but may not create approval, mark a sprint/phase Done, or describe approval as already decided. |

## Doctrine adopted

- [`documentation_standards.md` §1 — philosophy](../documents/documentation_standards.md#1-philosophy) — one documentary authority,
  required metadata, link-graph reconciliation, and no current validation claims in doctrine.
- [`repository_layout_doctrine.md` §2 — complete repository structure](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) — the closed
  Haskell source tree, bounded `pb/**`, and lazy `.build/**` generation.
- [`testing_spoof_resistance.md` §12 — spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence) — qualification,
  changed-subject witnesses, external observation, residue, and human authorization.
- [`conformance_harness_doctrine.md` §5 — the pre-hardware promotion barrier](../documents/engineering/conformance_harness_doctrine.md#5-the-pre-hardware-promotion-barrier) — the later
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
**Independent Validation**: Separately restated closed constructor universes, typed values, bytes, digest, and owner headings pin the component positive control. Constructible negatives cover `pb`, status reset, owners, register/archive, and ordering at code, subject, and detail. In full aggregate runs, the Registry-universe, owner-map, and `pb`-transport production mutants each red only `PolicyContractOracle` while all eight unrelated named oracles execute green. Prose correspondence remains human residue.
**Oracle**: `test/validation-kernel/PolicyContractOracle.hs`; integrated component diagnostic, not qualified-harness evidence, human review, or validation.
**Legacy IDs**: none — zero-query policy-surface sprint; `LTD-VAL-002` through `LTD-VAL-004` remain owned by their later Phase-0 seams
**Docs to update**: all governed documentation owners touched by the reset

### Objective

Make the Haskell-only source boundary, `pb` exception, lazy generation, sole `registry:2` provider, separately
pinned/preloaded Registry-image placement, single active legacy register, validation reset, strict numerical
order, pre-hardware barrier, and human-only promotion agree everywhere.

### Deliverables

- One closed typed value, constructor universe, and exact decision-to-owner anchor for each cross-cutting decision.
- One versioned deterministic serialized contract and SHA-256 digest, independently restated by the component oracle.
- One canonical prose statement and backlinks for each cross-cutting decision.
- One typed reset keeping Phase 0 Active and every later phase Blocked, all explicitly NOT VALIDATED.
- One typed requirement that every `LTD-SRC-*` query is zero before the Phase-49 DSL barrier can open.
- Zero governed prose links or references treating the eliminated archive as a document; its exact path exists
  only as a typed forbidden target and in rejection diagnostics/negatives.
- One closed Haskell registry-provider constructor selecting Distribution `registry:2`, plus a distinct
  placement decision for its separately pinned/preloaded bootstrap image; human review confirms both exact
  doctrine owners and that the service-capability prose rejects every alternate provider.
- Phase 0 Active — NOT VALIDATED; Phases 1–95 Blocked — NOT VALIDATED.

### Validation

Run the unmutated policy component diagnostic and all three changed-production builds from isolated build roots. The
unmutated build must pass. The aggregate runner must execute all nine named oracles in every build. Each mutant
must fail only `PolicyContractOracle`; every unrelated oracle must execute and stay green. These are supporting
diagnostics, not qualification or validation.

```text
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-diagnostic --test-show-details=direct
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-registry-mutant -fvalidation-policy-alternate-registry-mutant --test-show-details=direct
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-owner-mutant -fvalidation-policy-owner-map-mutant --test-show-details=direct
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-pb-transport-mutant -fvalidation-policy-pb-transport-mutant --test-show-details=direct
```

For acceptance, a human reviewer compares every typed value and owner anchor with the prose diff. The reviewer
also confirms that no Markdown keyword or machine-oriented projection can affect a behavioral verdict. Full
corpus-shape validation remains owned by Sprint 0.4, so Sprint 0.1 does not depend on a later sprint.

### Remaining Work

The unmutated, Registry-universe-mutant, owner-map-mutant, and `pb`-transport-mutant component diagnostics are
recorded. None is the qualified parent harness: applied-change and changed-binary witnesses remain Sprint-0.5
residue. Independent human review must compare every typed value and owner heading with the prose, then issue
an explicit same-phase implementation release for the exact current contract, subject, oracle, observations,
and residue. That release may open Sprint 0.2 without marking Sprint 0.1 Done. Sprint 0.1 remains Active — NOT
VALIDATED until the qualified parent gate retains this seam and the human authority promotes it; Sprint 0.2
remains blocked until the implementation release.

## Sprint 0.2: One active legacy register ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`, `src/validation-kernel/Amoebius/Validation/Legacy.hs`, `test/validation-kernel/LegacyOracle.hs`, `amoebius.cabal`
**Blocked by**: Sprint 0.1
**Independent Validation**: A structural Haskell check proves that the canonical reader-facing register path occurs exactly once, is UTF-8 readable, and has no forbidden archive path or alias. General documentation checks may still enforce ordinary orientation metadata, headings, links, and anchors. A separate oracle restates the exact 25-constructor Haskell ID universe, stable encodings, owners, lifecycle states, required-analyzer keys, unavailable-analyzer refusals, and retained reintroduction guards; independent authorship and custody are not claimed. Production mutations of that typed inventory/dispatch surface must fail at their named loci while owner-domain analyzers remain explicitly outside this sprint. Any row/cell/ID/owner/count/predicate change remains inert with respect to legacy semantics. Component output is diagnostic only; a human reviewer owns prose correspondence and acceptance.
**Oracle**: `test/validation-kernel/LegacyOracle.hs`; it separately states the 25 bindings and source baselines. The clean aggregate is green and each of eight isolated production mutants reds only this oracle, but external reviewer authorship/custody and human correspondence review are absent.
**Legacy IDs**: all 25 typed identities — `LTD-SRC-000` through `LTD-SRC-009`, `LTD-META-001`, `LTD-VAL-001` through `LTD-VAL-006`, `LTD-DOC-001`, `LTD-NAME-001`, `LTD-HOST-001`, `LTD-HOST-002`, `LTD-IMG-001`, `LTD-RUN-001`, `LTD-SEED-001`, and `LTD-SEED-002`; inventory/delegation only, with no owner-domain closure claimed
**Docs to update**: `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `documents/engineering/migration_doctrine.md`

### Objective

Make current divergence actionable through one closed Haskell lifecycle inventory, one total fail-closed
dispatcher, and one non-executable reader-facing explanation, without pulling later analyzers into Phase 0 or
creating a second historical register.

### Deliverables

- One canonical active-only Markdown register whose rows explain current work to readers and cannot alter an
  executable result.
- A closed 25-constructor Haskell legacy-ID universe with unique stable encodings and total owner, lifecycle,
  required-analyzer, and dispatch bindings. Missing analyzer evidence always produces a typed unavailable state;
  it refuses at or beyond the owner and can never represent closure before then.
- A retained Haskell reintroduction guard for every retired ID. Retirement removes the active Markdown
  explanation only after the owning analyzer reaches zero and the human accepts the transition.
- Independent Haskell expectations and changed-production mutants for the inventory/dispatch surface, plus a
  human correspondence-review obligation. Owner-domain analyzers and their semantic negatives remain work of
  the owning sprints.

### Validation

Missing or duplicated canonical register paths, non-UTF-8 bytes, and every archive alias fail the legacy
structural check without parsing row semantics. Changed-production cases for a deleted constructor, duplicate
stable encoding, missing or wrong owner/required-analyzer binding, non-total dispatch, accepted unavailable
analyzer, and removed retired-ID guard fail the independent Haskell oracle at distinct loci while unaffected
controls run. No case may substitute a constant refusal for dispatch coverage: every constructor must reach its
own typed analyzer key and exact unavailable result. Changing, adding, deleting, or duplicating a Markdown row,
ID, owner cell, predicate-shaped string, or count leaves those executable outcomes unchanged. The human reviewer
separately rejects any correspondence mismatch before acceptance. These are component diagnostics and human
acceptance criteria, not full harness qualification, owner-domain closure, or phase validation.

```text
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-diagnostic --test-show-details=direct
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-drop-id-mutant -fvalidation-legacy-drop-id-mutant --test-show-details=direct
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-duplicate-render-mutant -fvalidation-legacy-duplicate-render-mutant --test-show-details=direct
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-wrong-owner-mutant -fvalidation-legacy-wrong-owner-mutant --test-show-details=direct
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-missing-owner-mutant -fvalidation-legacy-missing-owner-mutant --test-show-details=direct
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-dispatch-redirect-mutant -fvalidation-legacy-dispatch-redirect-mutant --test-show-details=direct
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-missing-observation-mutant -fvalidation-legacy-missing-observation-mutant --test-show-details=direct
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-missing-closure-mutant -fvalidation-legacy-missing-closure-mutant --test-show-details=direct
cabal --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-legacy-missing-reintroduction-mutant -fvalidation-legacy-missing-reintroduction-mutant --test-show-details=direct
```

### Remaining Work

The closed universe, typed lifecycle/analyzer map, retained case identities, source-family baselines, and
per-constructor fail-closed dispatch are present as an unqualified component footprint. The separately stated
oracle passes in the clean aggregate. Each of the eight isolated production mutants above exits nonzero with
only `LegacyOracle` red while the other eight named oracles execute green. These same-workstream component
diagnostics establish neither external reviewer independence/custody nor parent-harness qualification. Human
correspondence review and acceptance therefore remain open, and Sprint 0.2 remains Blocked — NOT VALIDATED.
Owning sprints then implement the actual observation/closure analyzers and execute their domain reintroduction
negatives. No Phase-0-owned query is claimed zero here: `LTD-SRC-000`, `LTD-SRC-008`, and `LTD-VAL-001` through
`LTD-VAL-004` must first be delivered by Sprints 0.3 through 0.7 and may jointly reach zero only at the
integrated Sprint-0.8 candidate.

## Sprint 0.3: Haskell source-closure classifier ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/SourceClosure.hs`
**Blocked by**: Sprint 0.2
**Independent Validation**: Classify every tracked path exactly once by path, extension, mode, shebang,
content role, and consumer; reject every unbound, stale, duplicate, Phase-0-owned, or wrongly owned
source-boundary finding, while requiring two-way equality between present later-owned findings and the closed
typed Haskell legacy bindings. The Markdown register is not an input.
**Oracle**: `test/validation-kernel/SourceClosureOracle.hs`; separately authored as a component diagnostic but not independently human-reviewed.
**Legacy IDs**: `LTD-SRC-000`, `LTD-SRC-008`
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Turn the closed tracked-source grammar into a semantic Haskell check that renaming cannot bypass.

### Deliverables

- Complete source-snapshot partition and exact later-owned finding/Haskell-binding equality.
- Exact non-empty deny-by-default `pb/**` AST/import/resolved-call/control-flow/potential-effect graph, with
  every possible effect statically routed to the declared `BootstrapAdapter`; runtime observation is Phase 50.
- Lazy-output and authored-root write checks.

### Validation

Paired cases cover `.hs`, allowed non-code inputs, each `pb` bootstrap role, disguised Python/shell, executable
data, shebang source, behavioural metadata, source-adjacent cache, and generated output under authored roots.

### Remaining Work

The current component footprint rejects assume-unchanged and skip-worktree flags, binds a final tagged index
observation to mode/object/stage/path, and compares descriptor-pinned tracked-file bytes/kind/owner-execute mode
with the index. The authored-root inventory sees ignored and untracked material but is still path-based rather
than descriptor-relative; ancestor-symlink, special-file, and replacement races remain open. Git-reported blob
bytes are not independently rehashed against object identity. Its generated-repository component cases are
diagnostics only and have not qualified the harness.

The content-role/consumer/effect graph is still absent. The disconnected experimental external-interpreter
summary was removed rather than retained as apparent evidence: a self-reported identity and internally
self-consistent counts cannot authenticate an executable, prove compile validity, or close control flow. Build
the complete versioned AST and Haskell-owned resolution/effect proof stated above, implement the descriptor-relative
walker and independent blob binding, add changed-production-subject, forged-report, symlink, special-file, and
replacement-race cases, connect all raw observations to the gate, and obtain independent review after Sprint 0.2
is accepted.

## Sprint 0.4: Haskell documentation and plan-contract checker ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Documentation.hs`, `src/validation-kernel/Amoebius/Validation/PhaseContract.hs`
**Blocked by**: Sprint 0.3
**Independent Validation**: Complete structural component corpora are accepted and minimally different dependency, inventory, raw-status, retired-path, wildcard, fence, comment, and line-wrap defects are refused at exact loci. The documentation inventory-baseline and retired-artifact production mutants each red only their named oracle in isolated diagnostics; PhaseContract changed-production-subject qualification and semantic policy/prose correspondence remain open.
**Oracle**: `test/validation-kernel/DocumentationOracle.hs` and `test/validation-kernel/PhaseContractOracle.hs`; separately authored component diagnostics without independent human review.
**Legacy IDs**: `LTD-VAL-001`, `LTD-VAL-002`
**Docs to update**: `documents/documentation_standards.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`

### Objective

Replace Python and token-presence checks with typed structural validation whose negative corpus exercises only
machine-decidable document structure. Executable cross-cutting policy lives in `PolicyContract`; prose
correspondence remains human review.

### Deliverables

- Governed inventory, metadata, Markdown/link/anchor/status/dependency checker.
- Fixed gate-contract parser with closed keys and fail-closed `UNRESOLVED` handling.
- Two-way phase/tracker/substrate/component joins.
- Haskell-owned sentence and paragraph budget measurement, replacing the condemned Python `p3` implementation.

### Validation

The Haskell checker rejects one generated minimal mutation for every structural rule and reports the exact
rule, file, and locus. Empty discovery refuses. A keyword-only decoy must be structurally inert and must never
alter a source, registry, validation, or ordering verdict.

### Remaining Work

The checkers and component oracles exist but are not qualified or independently human-reviewed. The
documentation checker separately pins the 195-path governed inventory/count digest and rejects retired tracked
fixture/golden/oracle/mutant syntax unless it names one exact non-wildcard lowercase-`.hs` file, plus ambiguous
committed/checked-in artifact wording; raw, fenced, comment-split, and physically wrapped spellings cannot hide
those defects. Phase and sprint status fields are exact raw reset forms: dual-status wording, extra bare markers,
fenced decoys, comments, and line wraps refuse. These focused cases and isolated production mutants are component
diagnostics, not corpus acceptance. Add and qualify changed-production PhaseContract status/gate bypass mutants,
complete the semantic phase-by-phase body review, and resolve every `UNRESOLVED` or `MISSING` gate cell after
Sprint 0.3 is accepted. The recorded sentence backlog is 1,613 over forty-five
words, including 133 over ninety. `python3 tools/doc_lint.py` is the transitional measurement command only;
it is condemned non-Haskell source, cannot produce acceptance evidence, and must be replaced by the Haskell
checker in this sprint.

## Sprint 0.5: Gate-kernel qualification and spoof corpus ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Gate.hs`, `test/validation-kernel/QualificationOracle.hs`
**Blocked by**: Sprint 0.4
**Independent Validation**: Inject every mandatory sabotage into the exact harness build, retain raw refusals, then prove the same build runs the clean subject; the qualifier cannot accept its own summary.
**Oracle**: `test/validation-kernel/QualificationOracle.hs`; component diagnostic exists, and a separate human reviewer remains required.
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
to the exact dispatcher/harness build. Execute and retain those changed-subject witnesses, then obtain
independent oracle review after Sprint 0.4 is accepted.

## Sprint 0.6: Candidate evidence and human approval boundary ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Evidence.hs`, `src/validation-kernel/Amoebius/Validation/Approval.hs`
**Blocked by**: Sprint 0.5
**Independent Validation**: A dispatcher-acquired bundle is the positive control; caller-invented green rows and every absent, wrong-key, stale-source, stale-contract, stale-harness, replayed, automation-authored, self-generated-root, or same-change-root pair are negatives; the approval path remains UNVERIFIED until the external trust root and durable replay observer exist.
**Oracle**: `test/validation-kernel/EvidenceOracle.hs` and `test/validation-kernel/ApprovalOracle.hs`; component diagnostics exist, but review and key custody by the human trust-root owner are absent.
**Legacy IDs**: `LTD-VAL-003`, `LTD-VAL-004`
**Docs to update**: `AGENTS.md`, `documents/engineering/testing_spoof_resistance.md`, `DEVELOPMENT_PLAN/development_plan_phase_model.md`

### Objective

Separate evidence production from the only authority that may change status.

### Deliverables

- Candidate evidence schema and provenance binding.
- External human-signature verification with predecessor-snapshot trust-root rule.
- Human-only promotion policy consumed by plan validation.

### Validation

Every forged/stale approval pair differs minimally from an externally supplied, non-repository test-anchor
fixture and fails at its specific verification locus. A self-generated test key is itself a required negative
and no test key is accepted for real promotion.

### Remaining Work

Connect the observed evidence writer to the qualified dispatcher, establish the external approval/key-custody
mechanism without a test-key promotion path, and complete human custody review after Sprint 0.5 is accepted.

## Sprint 0.7: Review all numbered phase contracts ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `DEVELOPMENT_PLAN/phase_[0-9][0-9]_*.md`
**Blocked by**: Sprint 0.6
**Independent Validation**: Every phase has one fixed 18-row table, checked only for structure and explicit `UNRESOLVED` state. Separately reviewed Haskell phase contracts pin subjects, oracles, controls, mutants, observers, typed legacy bindings, predecessors, and residue. Human review owns correspondence with the table prose; no cell text supplies semantic authority. Any structural `UNRESOLVED` row or missing Haskell binding refuses Phase 0 at its own locus.
**Oracle**: `test/validation-kernel/PhaseContractOracle.hs`; component diagnostic exists, and an independent human reviewer remains required for each oracle boundary.
**Legacy IDs**: `LTD-VAL-002`
**Docs to update**: all numbered phase contracts and their doctrine owners

### Objective

Replace every pre-reset gate with a phase-specific, non-spoofable contract in numerical order.

### Deliverables

- Canonical `pb validate phase NN` command in all 96 phases.
- Exactly eighteen required contract rows per phase.
- No operative Python runner, tracked serialized oracle, self-derived expectation, unwitnessed mutant, or
  machine promotion authority.

### Validation

The structural checker rejects missing/duplicate keys, unresolved fields, and forward or absent numerical
dependencies. Independent Haskell contract oracles reject missing subject/oracle bindings, self-derived
expectations, absent reviewer custody, and missing typed legacy closure bindings. Generic prose, a semantic
keyword, or a changed `Legacy IDs` cell cannot create a pass; human review owns semantic prose correspondence.

### Remaining Work

Resolve the 1,290 `UNRESOLVED` gate cells and 92 `MISSING` predecessor cells currently spread across 93
contracts and complete the
independent phase-by-phase review after Sprint 0.6 is accepted. Every affected phase remains shut meanwhile.

## Sprint 0.8: Integrated Phase-0 candidate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Dispatch.hs`, `app/amoebius/Main.hs`
**Blocked by**: Sprint 0.7
**Independent Validation**: From an empty generated tree, the exact absolute source-built Haskell executable is invoked directly with `validate phase 00`; it qualifies the harness, runs the clean corpus, resolves every Phase-0-owned typed Haskell legacy binding to zero for the first time, emits explicit candidate evidence, and cannot mutate status. `pb` is unavailable as validation transport. Retired IDs remain compiled reintroduction guards, while their explanations are absent from the active-only Markdown register. Markdown register contents are unavailable to the semantic verdict.
**Oracle**: `test/validation-kernel/Main.hs` currently composes component diagnostics only; a separate integration oracle, independent reviewer, and final human validation-authority review remain absent.
**Legacy IDs**: `LTD-SRC-000`, `LTD-SRC-008`, `LTD-VAL-001`, `LTD-VAL-002`, `LTD-VAL-003`, `LTD-VAL-004`
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only after the human authority decides promotion

### Objective

Produce the first admissible candidate without claiming or applying validation.

### Deliverables

- One Haskell-owned phase dispatcher.
- Qualified raw observations and schema-checked candidate bundle under `.build/runs/phase-00/candidates/**`.
- External human-review input surface with no automatic status mutation.

### Validation

Run the full Gate-integrity table. The result is only a Validation candidate; the human reviewer independently
checks it and alone decides whether to sign and promote Phase 0.

### Remaining Work

The dispatcher and current nonconforming `pb/**` implementation are observed footprints, not an integrated
candidate path. The opaque `pb` handoff remains a target with no conforming implementation. Qualification
execution, clean-room observation, evidence-writer integration, contract resolution, independent review,
legacy closure, external key custody, and the human decision remain open.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

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
  Haskell owns lifecycle, dispatch, owner-analyzer closure, and retained reintroduction guards
- [Migration doctrine](../documents/engineering/migration_doctrine.md) — retirement keeps the compiled guard and
  removes only the accepted active explanation
- [Documentation standards](../documents/documentation_standards.md)
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
- [No-cluster conformance harness](../documents/engineering/conformance_harness_doctrine.md)
