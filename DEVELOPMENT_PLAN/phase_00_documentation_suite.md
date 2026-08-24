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
component-oracle footprint is beneath `test/validation-kernel/**`. The mutable worktree now contains only
`pb/__main__.py`; the old fifteen-path bootstrap/admin/test/check footprint remains in the Git index because
agents may not stage changes. The one-file subject therefore is not yet an acquired tracked snapshot and
`LTD-SRC-008` remains open. Token scanning cannot prove the absence of hidden Python behavior, so Phase 0 must
statically prove the exact minimal-platform-discrimination,
contained-toolchain-establishment, source-bound-build, opaque-exec source graph before `pb` may remain as the
sole non-Haskell source exception. That source-admission proof does not claim the handoff ran; Phase 50 alone
owns its external runtime observation. A linked-GHC parser/renamer/typechecker and conservative consumer/effect
adapter footprint exists, but the 2026-08-23 adversarial integration review rejected its candidate path. The
current acquisition hardening now keeps caller-selected absolute Git diagnostic-only and refuses candidate
authority with explicit authentication and atomic-custody residue; focused exact index-object, HEAD-race,
authority-mint, raw-closure, and executable-mask mutants were killed. No authenticated external acquisition
authority exists. The compiler adapter hardening remains in progress after the same review found that component
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
component oracles. The runner now contains eighteen named component oracles. The latest completed aggregate
reached all eighteen; sixteen met their component expectations, `DispatchOracle` exposed a stale observation
classifier that has since been corrected, and `DocumentationOracle` refused the intentionally stale corpus
manifest while documentation and phase semantics are still changing. That result has been invalidated by the
subsequent semantic-contract hardening and must be rerun. In each earlier separate build
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
current corpus, all 96 phase contracts contain 1,728 exact-prefix `UNRESOLVED` gate cells. The former 92 generic
`MISSING` predecessor cells now specify typed `ImmediatePredecessorApproval` inputs and separately require the
candidate to refuse absent or stale runtime evidence. All 270 sprint sections now have the exact ordered reset
schema and immediate plan edge; unresolved implementation, oracle, validation, legacy, and documentation
bindings remain explicit rather than being guessed. Two independent read-only audits found no structural
schema or blocker-edge mismatch across the 262 later-phase sprints. These specification corrections are not
validation. Phase 0 therefore remains Active — NOT VALIDATED, and Phase 1 remains shut.

An earlier 2026-08-23 Sprint-0.2 clean-plus-thirteen component matrix remains stale. Sprint 0.3 exposed and
corrected a lifecycle sequencing error: an Active zero must be admissible at the exact owning-phase candidate,
while refusing before the owner as a missing finding and after the owner as an unrecorded promoted transition.
That production/oracle change invalidated the prior byte witnesses and matrix result. On current bytes a fresh
warning-clean direct build and clean oracle completed, followed by twenty isolated changed-production builds;
all twenty compiled and reddened their exact inventory, encoding, owner/lifecycle, dispatch, analyzer, source-map,
or diagnostic-authority controls. The Cabal registry contains one exact mapping for each selected macro. These
runs still lack applied source and binary witnesses, same-harness unaffected controls, independent custody,
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

**Contract review**: REWRITTEN — NOT VALIDATED; an implementation footprint exists, but qualification,
clean-room observation, evidence integration, independent human review, and key custody remain open.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: The governed corpus has one structural owner/link surface; all current statuses are explicitly NOT VALIDATED; the executable cross-cutting decisions live in one typed Haskell `PolicyContract` awaiting independent human review; every tracked path is classified exactly once; and every present source-boundary violation joins in both directions to one strictly-later typed Haskell legacy binding. No Phase-0-owned source-policy or validation-integrity violation may remain, and the qualified Haskell kernel must refuse every specified spoof. The Markdown register is reader-facing only: its rows, cells, IDs, owners, predicates, and counts cannot affect the join or closure verdict. Natural-language correspondence is a human-review obligation, never a machine-parsed verdict. Phase 0 does not claim that later-owned source migrations, DSL semantics, or runtime behaviour are complete. |
| `Subject` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Candidate-facing production entry points beneath `src/validation-kernel/Amoebius/Validation/**`: the future externally anchored immutable-bundle verifier that alone may construct `AcquiredSourceSnapshot`; `Dispatch.checkAcquiredPhaseZeroSnapshot`; `SourceClosure.sourceClosureCheckAcquired`; `CompilerSourceGraph.analyzeAcquiredCompilerSourceGraph`; `Legacy.legacyCheckAcquired`; `PolicyContract.checkPolicyContract`; `Documentation.checkCorpus`; `PhaseContract.checkPhaseContracts`; the future qualification executor rather than the caller-authored `Gate.checkQualificationReportDiagnostic` consistency seam; the integrated evidence writer; and `Approval.verifyApproval`. Raw `SourceSnapshot`, `classifySnapshot`, `legacyCheck`, and caller-selected Git entry points remain permanently diagnostic and are not candidate subjects. The typed contract feeds dispatch bounds, status syntax, owner-anchor checks, structural register-path/archive checks, source classification, Phase-49 source closure, phase ordering, and promotion authority. `Amoebius.Validation.Legacy` must own a closed 25-constructor legacy-ID universe, total owner/lifecycle/required-analyzer bindings, and total dispatch that returns a typed unavailable state whenever the selected analyzer is absent. Every current disposition is Active: unavailable evidence refuses at or beyond its owner and is explicit later-owned debt before then. A Retired constructor is inadmissible until the owning analyzer implements and qualifies the required reintroduction negative. Sprint 0.2 owns the inventory and delegation seam only; observation/closure analyzers and their domain negatives belong to their owning sprints. Fields for later unimplemented behavior remain typed requirements rather than claims that a consumer exists. This footprint is unqualified; evidence and approval remain refusal-only; all current `pb/**` is Phase-0 debt, not a validation subject. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Future public target: `pb validate phase 00`; it is not currently an admissible validation transport. The Phase-0 candidate must build and invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. Phase 50 alone may validate the already source-bounded `pb` ensure/build/unchanged-argv/exec runtime handoff. The Haskell binary owns discovery, observations, schema checks, and the candidate verdict. |
| `Oracle` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Separate component modules exist under `test/validation-kernel/`, including `PolicyContractOracle.hs`. It separately restates every closed enum universe, the exact selected values and owner map, canonical bytes and digest, and code/subject/detail expectations for focused negatives. The component runner executes every named oracle before aggregating failure, but neither independent authorship nor custody, harness qualification, or human prose-correspondence review is established. Reviewer assignment and custody remain absent and block validation. |
| `Positive controls` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: The complete governed path/link/metadata graph and tracked source snapshot, plus structural parser corpora that are explicitly incapable of becoming candidates. Production and oracle modules separately state every closed policy universe, the typed provider choice, decision-owner map, canonical policy bytes, source partition, and frozen later-owned source fingerprints. No independent human review is claimed. A human must separately compare the prose diff with the typed `PolicyContract`. |
| `Paired negatives` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Minimally different input pairs cover missing or unexpected governed paths, malformed metadata, broken links, an omitted legacy-ID inventory projection, duplicate stable-ID encoding, missing or wrong owner/required-analyzer bindings, a skipped analyzer route, accepted unavailable evidence, a non-canonical parser alias, missing required reintroduction-case identity, changed paths inside an open source family, non-Haskell behavioural source, disguised executables, widened `pb` behavior, missing `NOT VALIDATED`, malformed gate rows, forward dependencies, empty discovery, and generated output in an authored root. Acquisition pairs cover an unknown or self-selected key, altered signature or signed field, absent/stale/wrong/replayed challenge, noncanonical/duplicate/reordered/empty bundle entries, byte/Git-OID/blob-SHA-256/snapshot-identity mismatch, wrong observer/tool-closure identity, mutable or sequential custody substituted for an externally frozen bundle, and source/compiler/build identity swaps. Policy value negatives remove one `pb` operation, redirect or omit one owner, select or rename the eliminated archive path, swap two phase roles, or admit hardware at Phase 51; each pins finding code, subject, and a distinguishing detail. Editing any legacy-register row, ID spelling, owner cell, predicate string, or count must leave the legacy binding/closure verdict unchanged; human review at the integrated phase gate must still report a prose-correspondence defect. The Registry provider has no runtime alternate-input constructor; widening that closed production type is a changed-subject mutant, not a fabricated paired input. |
| `Mutants` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Required changed-production-subject operators weaken source classification, skip one governed document, accept an empty gate table, treat evidence as approval, ignore one compiled Haskell legacy binding, accept a second registry, or bypass exactly one acquisition signature, fresh-challenge, immutable-bundle digest, observer/tool identity, or frozen-custody check. Each records the applied Haskell-source change and must redden its named oracle row for the named reason. A separate oracle that intentionally asserts composition through the mutated seam may also turn red; every unrelated control must stay green. A Markdown register edit is a prose-correspondence case, never this mutation operator. |
| `Discovery` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: The Haskell kernel enumerates all tracked paths and all governed Markdown at run time and joins each in both directions to independently derived expectations. Zero files, a missing root, an unclassified path, a duplicate path, or an unexpected governed file refuses the run. |
| `Challenge` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: The policy/document/source classification claim is pure and uses run-local sabotage selection rather than pretending a nonce strengthens semantics. Input custody separately requires an external fresh unpredictable challenge, a durable replay identity, and a signed immutable source bundle issued only after that challenge; missing, stale, wrong, or replayed custody evidence refuses acquisition. The human reviewer must approve both mechanisms. |
| `Observer` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Component oracles separately inspect the raw snapshot bytes, modes, shebangs, path inventory, metadata fields, headings, links, anchors, dependencies, status fields, and fixed gate-table shape made available at their seams rather than accepting a compliance summary emitted by the classifier. Candidate acquisition additionally requires an external, pre-anchored observer to originate or freeze an immutable source bundle and sign its complete canonical envelope; sequential mutable-worktree reads and a candidate-selected observer/key are inadmissible. Haskell independently recomputes every Git object ID, blob SHA-256, manifest identity, and signature before constructing the opaque token. Independent custody is presently absent. The checks never interpret natural-language policy as a verdict, and a missing or partial seam read fails closed. |
| `Authority/bypass` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Source-policy bypass probes cover extensionless files, misleading extensions, executable bits, shebangs, symlinks, ignored inputs, generated copies, widened `pb` behavior, and a policy-looking prose decoy that must have no effect on the typed policy or legacy semantic verdict. Acquisition bypass probes cover malicious-tool/root substitution, self-generated or same-change keys, signature and bundle-field alteration, challenge replay, mutable-custody substitution, HEAD/index/worktree ABA, observer/tool replacement, raw `SourceSnapshot` record updates, acquired-wrapper construction/rewrapping attempts, and source/compiler/build identity swaps. Documentation diagnostics may still react to document structure, filename stems, or the forbidden archive basename. Only the typed Haskell contract and structured source/config observations govern behavior. Acquisition authority may mint input custody only and remains distinct from human promotion authority. Human approval verification rejects absent, automation-authored, wrong-key, wrong-source, stale-contract, and replayed receipts. |
| `Freshness` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: The candidate uses a newly challenged externally frozen immutable source bundle and a fresh run root with all generated/state roots absent. The signed envelope binds its durable replay identity, complete source manifest, observer/tool closure, custody method, and exact snapshot identity; Haskell rejects replay or recomputation mismatch. Prior evidence, cached discovery, ignored inputs, copied status, and mutable Git/worktree rereads are unusable. Source and contract digests are provenance only. |
| `Qualification` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Before the clean run, the same Haskell harness must reject constant success, no-op subject, wrong output, empty discovery, missing subject/oracle, skipped/no-op mutant, wrong-locus failure, stale evidence, self-observer, authority bypass, residue, and smuggled generated/legacy input. |
| `Cleanroom` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Run from the tracked snapshot with `.build/**`, `.data/**`, `.test_data/**`, source-adjacent caches, and condemned legacy copies absent. All compiler output, synthetic corpora, observations, and raw candidate evidence are generated beneath one `.build/runs/phase-00/**` run root; the tracked tree remains unchanged. The current dirty worktree is ineligible. |
| `Legacy closure` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Sprint 0.2 separately pins the closed 25-ID Haskell inventory, total owner/lifecycle/required-analyzer bindings, and total fail-closed dispatch; independent reviewer custody remains absent. Every canonical disposition is currently Active, and this sprint does not make an owner-domain query zero or claim an executed reintroduction guard. The owning sprint supplies each typed observation/closure analyzer and domain reintroduction negative; an absent analyzer, missing negative, or open due query refuses. Sprint 0.8 is the first point at which all Phase-0-owned queries—`LTD-SRC-000`, `LTD-SRC-008`, and `LTD-VAL-001` through `LTD-VAL-004`—must jointly be zero, alongside the complete source partition, frozen later-owned source fingerprints, and an exact non-empty static `PbBootstrapGrammar` AST/import/resolved-call/control-flow/potential-effect proof. Runtime effect, executable-identity, unchanged-argv, and exec-replacement evidence is explicitly excluded and remains Phase-50 residue. An Active zero is accepted only at the exact owning-phase candidate; it refuses before that owner as stale/missing debt and after it as a missing promoted transition. Human promotion precedes the successor-phase source transition to Retired, and the qualified negative remains compiled. The structural seam requires one canonical regular non-executable UTF-8 register, no second exact canonical basename, and no exact forbidden archive basename; it does not infer arbitrary semantic aliases. The general documentation checker may enforce ordinary structure plus its basename-substring cardinality and forbidden-archive-basename content diagnostics. Neither may interpret Markdown row content as a binding or verdict. Human review owns correspondence at the integrated phase gate. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `genesis`; there is no prior numbered phase. The human approval trust root predates and is outside the candidate. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `UNVERIFIED`: qualification of all three `PolicyContract` changed-subject mutants and human prose-correspondence review; the dispatcher omission matrix and composition-bypass mutant; complete document-shape enforcement assigned to Sprint 0.4; the `LTD-SRC-008` Python-boundary closure; a real multi-package/multi-component compiler parser/consumer/effect graph that detects disguised behavioral content in otherwise admitted non-source files; changed-subject qualification and external clean-room observation of the implemented descriptor-relative no-follow authored-root walk, independent Git-blob hashing, concealment, byte/mode, authored-root, and final index-binding checks; the externally anchored signed immutable-source-bundle verifier and its challenge/signature/digest/tool/custody mutants; all product/DSL/runtime semantics; semantic phase-contract joins; every owner-sprint analyzer and domain reintroduction negative behind the total legacy dispatcher; execution of the fixed qualification corpus against the exact integrated harness; independent reviewer and separate acquisition/promotion key custody; authenticated toolchain acquisition; candidate-evidence integration; a closed typed evidence schema for exact command, toolchain, substrate/lane/architecture, run identity, cleanup, and the signed status-only projection; a reviewed binding between Git object-format identity and SHA-256 evidence provenance; all 1,728 typed semantic slots remain exact-prefix `UNRESOLVED` gaps even where retained prose records prior intent; 385 unresolved resource fields; unresolved sprint field meanings despite structurally complete envelopes; absent runtime predecessor evidence where applicable; the sentence-budget backlog; external approval operation; and every tracked-source migration owned by a later phase. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only`: automation and LLMs may report a candidate but may not create approval, mark a sprint/phase Done, or describe approval as already decided. |

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
**Oracle**: `test/validation-kernel/PolicyContractOracle.hs`; integrated component diagnostic, not qualified-harness evidence or validation. Its independent review is consolidated into the Phase-0 gate; no sprint-level confirmation is requested.
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
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-diagnostic --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-registry-mutant -fvalidation-policy-alternate-registry-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-owner-mutant -fvalidation-policy-owner-map-mutant --test-show-details=direct
cabal --offline --store-dir=.build/cabal-store test validation-kernel-component --builddir=.build/dist-newstyle/phase-00-policy-pb-transport-mutant -fvalidation-policy-pb-transport-mutant --test-show-details=direct
```

During the consolidated Phase-0 gate review, the human reviewer compares every typed value and owner anchor with
the prose diff and confirms that no Markdown keyword or machine-oriented projection can affect a behavioral
verdict. This is not a Sprint-0.1 confirmation point. Full corpus-shape validation remains owned by Sprint 0.4,
so Sprint 0.1 does not depend on a later sprint.

### Remaining Work

The unmutated, Registry-universe-mutant, owner-map-mutant, and `pb`-transport-mutant component diagnostics are
recorded and reproduce on 2026-08-23. They establish implementation readiness for Sprint 0.2 but are not the
qualified parent harness: applied-change and changed-binary witnesses remain Sprint-0.5 residue. Human
prose-correspondence review of every typed value and owner heading stays phase-gate residue. Sprint 0.1 remains
NOT VALIDATED until the qualified parent gate retains this seam and the human authority promotes it.
All Phase-0 oracle fields now state the same consolidated-review boundary: component diagnostics make the next
sprint implementation-ready, while one Phase-0 gate review covers the completed seam set. No intermediate
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
independent custody, human prose-correspondence review, and the integrated Phase-0 candidate remain open.
These are component diagnostics only and do not validate or promote Sprint 0.1.

## Sprint 0.2: One active legacy register ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`, `src/validation-kernel/Amoebius/Validation/Legacy.hs`, `test/validation-kernel/LegacyOracle.hs`, `amoebius.cabal`
**Blocked by**: Sprint 0.1
**Independent Validation**: A structural Haskell check proves that the canonical reader-facing register is one tracked, non-executable regular UTF-8 file; no second occurrence of its exact basename and no occurrence of the exact forbidden archive basename is tracked. It does not claim to recognize an arbitrarily renamed semantic copy. The general documentation checker separately applies its governed-document structure rules, a basename-substring register-cardinality diagnostic, and a case-folded forbidden-archive-basename content diagnostic; those findings may change when Markdown changes. A separate oracle restates the exact 25-constructor Haskell ID universe, every closed binding-key universe, stable encodings, owners, the one-constructor Active lifecycle universe, required-analyzer routes, unavailable-analyzer refusals, and required reintroduction-case identities; independent authorship and custody are not claimed. Twenty changed-production flags declare mutations of that typed inventory, parser, owner-boundary/lifecycle comparison, diagnostic authority, dispatch surface, exact source-family join, and analyzer-execution boundary. Each must fail at its named locus when run, while owner-domain analyzers remain explicitly outside this sprint; an intentional Dispatch composition assertion may co-fail for a mutation that changes its observed legacy surface. Caller-constructible observations exist only behind a permanent diagnostic refusal; the candidate accepts a private snapshot/analyzer-bound evidence registry produced by one closed dispatcher. Any row/cell/ID/owner/count/predicate change remains inert only with respect to legacy binding and closure semantics. Component output is diagnostic only; prose correspondence is reviewed once at the integrated Phase-0 gate.
**Oracle**: `test/validation-kernel/LegacyOracle.hs`; it separately states the 25 bindings, closed key universes, exact parser grammar, the Active-only disposition universe, before-owner stale-zero refusal, exact-owner zero candidate readiness, post-owner missing-transition refusal, open/unavailable refusals at and beyond every owner, the exact nine-family `SourceDebtId`-to-`LegacyId` map, diagnostic/candidate separation, closed-registry completeness, and an ambient live diagnostic over the tracked index path/mode/object and indexed register blob bytes. The earlier 2026-08-23 clean-plus-thirteen result is invalidated. The current fresh clean direct build and oracle exited zero; all twenty isolated mutant builds, including the one-locus source-debt/Legacy correspondence swap and both diagnostic-authority bypasses, compiled and red at their named controls. This remains a component diagnostic only. External reviewer authorship/custody and the consolidated Phase-0 correspondence review remain absent.
**Legacy IDs**: all 25 typed identities — `LTD-SRC-000` through `LTD-SRC-009`, `LTD-META-001`, `LTD-VAL-001` through `LTD-VAL-006`, `LTD-DOC-001`, `LTD-NAME-001`, `LTD-HOST-001`, `LTD-HOST-002`, `LTD-IMG-001`, `LTD-RUN-001`, `LTD-SEED-001`, and `LTD-SEED-002`; inventory/delegation only, with no owner-domain closure claimed
**Docs to update**: `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `documents/engineering/migration_doctrine.md`

### Objective

Make current divergence actionable through one closed Haskell lifecycle inventory, one total fail-closed
dispatcher, and one non-executable reader-facing explanation, without pulling later analyzers into Phase 0 or
creating a second historical register.

### Deliverables

- One canonical active-only Markdown register whose rows explain current work to readers and cannot alter a
  legacy binding or closure verdict.
- A closed 25-constructor Haskell legacy-ID universe with unique stable encodings and total owner, lifecycle,
  required-analyzer, and dispatch bindings. Missing analyzer evidence always produces a typed unavailable state;
  it refuses at or beyond the owner and can never represent closure before then.
- One private candidate evidence type bound to the exact snapshot, row, and analyzer. Caller-authored lifecycle
  values and maps remain permanently refusal-marked diagnostics and cannot enter the candidate evaluator.
- One total, exhaustive `SourceDebtId`-to-`LegacyId` function and exact closed-registry key check.
- A required typed Haskell reintroduction-case identity for every ID. The owning analyzer must implement and
  qualify that negative before retirement; Sprint 0.2 does not claim executable guard coverage.
- Separately stated Haskell expectations and changed-production mutants for the inventory/dispatch surface, plus a
  human correspondence-review obligation. Owner-domain analyzers and their semantic negatives remain work of
  the owning sprints.

### Validation

Missing or duplicated canonical paths, a second exact canonical basename, the exact forbidden archive
basename, non-UTF-8 bytes, executable mode, and symlink mode fail the legacy structural check without parsing
row semantics. Changed-production cases cover an omitted inventory projection, duplicate stable encoding,
wrong and missing owners, redirected analyzer binding, missing observation/closure/reintroduction bindings, a
skipped registry route, accepted due-but-unavailable evidence, an equality-only owner-boundary comparison,
an owner-tail comparison that stops refusing after the first post-owner phase, one widened parser alias, one
omitted source-family route, one zero substituted without executing the complete-source analyzer, two removed
diagnostic-authority refusals, and one swapped source-debt/Legacy binding. Each must fail the
separately stated Haskell oracle at its exact locus while unrelated controls run. DispatchOracle intentionally checks
legacy composition, so a mutation that changes its observed ID count or Phase-0 unavailable-finding count may
also turn that composition oracle red for the corresponding reason. No constant refusal may substitute
for dispatch coverage: all 25 constructors must reach their separately expected analyzer keys and exact
unavailable states. Changing, adding, deleting, or duplicating a Markdown row, ID, owner cell,
predicate-shaped string, or count leaves legacy binding and closure outcomes unchanged. Documentation findings
may still change because that checker applies ordinary document rules, a basename-substring cardinality check,
and a forbidden-archive-basename content check. The consolidated Phase-0 human review separately rejects correspondence mismatch.
These are component diagnostics, not full harness qualification, owner-domain closure, phase validation, or
per-sprint human acceptance.

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
phase candidate impossible: it demanded the post-promotion transition before the candidate that a human could
promote. The correction accepts zero only at the exact owner, rejects it before and after that point for distinct
reasons, and expands the separately stated oracle accordingly. An adversarial Sprint-0.3 review then found that
the exported model evaluator still let a caller fabricate an analyzer-tagged zero and that the source-family
join was an unchecked list. The implementation now separates permanently refused caller-authored diagnostics
from opaque snapshot/analyzer-bound candidate evidence, adds a total nine-family join, and declares independent
route-omission and analyzer-zero-substitution mutants. This invalidates the earlier clean-plus-thirteen byte and
execution observations; the replacement clean-plus-twenty direct diagnostic matrix now reds every named mutant,
but has no applied source/binary witness or qualified parent harness. Sprint 0.2 remains Blocked — NOT VALIDATED
until the integrated qualified parent candidate receives human review and promotion. External reviewer
authorship/custody, parent-harness qualification, and correspondence review remain Phase-0 gate residue.
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

The in-progress replacement now has a package-hidden implementation and a raw refusal-only public facade.
Its current safe checkpoint contains 441 once-only source selectors, 441 literal oracle rows, and 441 exact
Cabal flag/condition/`-D` mappings with zero two-way identity delta. Production and oracle compile warning-free
under the strict component diagnostic, the clean exact oracle and independent SHA control run green, and seven
representative new selectors produced distinct changed executables that reddened their assigned rows without
reddening the independent control. This checkpoint deliberately does not freeze 441 as complete: renderer and
commitment contributions, UTF-8 boundaries, the complete 441-plus matrix, package-boundary controls, integrated
qualification, external custody, and the post-matrix adversarial audit remain open. It is a component diagnostic
only; Sprint 0.2 remains Blocked — NOT VALIDATED.

## Sprint 0.3: Haskell source-closure classifier ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/SourceAcquisition.hs`, `src/validation-kernel/Amoebius/Validation/SourceClosure.hs`, `src/validation-kernel/Amoebius/Validation/SourceConsumerGraph.hs`, `src/validation-kernel/Amoebius/Validation/SourceDebtBaseline.hs`, `src/validation-kernel/Amoebius/Validation/PbBootstrapGrammar.hs`, `src/validation-kernel/Amoebius/Validation/CompilerBuildInfo.hs`, `src/validation-kernel/Amoebius/Validation/CompilerComponentPlan.hs`, `src/validation-kernel/Amoebius/Validation/CompilerElaboratedPlan.hs`, and `src/validation-kernel/Amoebius/Validation/CompilerSourceGraph.hs`
**Blocked by**: Sprint 0.2
**Independent Validation**: Classify every tracked path exactly once by path, extension, mode, shebang,
content role, and consumer; reject every unbound, stale, duplicate, Phase-0-owned, or wrongly owned
source-boundary finding, while requiring two-way equality between present later-owned findings and the closed
typed Haskell legacy bindings. Each of the nine component oracles owns a literal selector-to-exact-case
registry covering every independent predicate, permanent refusal, bound, result-retention rule, closed-grammar
alternative, and composition decision in its subject. Exact selector identities must reconcile in both
directions across production, oracle, and Cabal; each isolated changed subject must red its assigned exact row
at its named locus while same-harness unaffected controls remain green. The Markdown register is not an input.
**Oracle**: `test/validation-kernel/SourceAcquisitionOracle.hs`, `test/validation-kernel/SourceClosureOracle.hs`, `test/validation-kernel/SourceConsumerGraphOracle.hs`, `test/validation-kernel/SourceDebtBaselineOracle.hs`, `test/validation-kernel/PbBootstrapGrammarOracle.hs`, `test/validation-kernel/CompilerBuildInfoOracle.hs`, `test/validation-kernel/CompilerComponentPlanOracle.hs`, `test/validation-kernel/CompilerElaboratedPlanOracle.hs`, `test/validation-kernel/CompilerSourceGraphOracle.hs`, and `test/validation-kernel/CompilerSourceGraphAcquiredOracle.hs`; separately authored component diagnostics without authenticated inputs. Their independent review is consolidated into the Phase-0 gate, not requested per sprint.
**Legacy IDs**: `LTD-SRC-000`, `LTD-SRC-008`
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Turn the closed tracked-source grammar into a semantic Haskell check that renaming cannot bypass.

### Deliverables

- Complete source-snapshot partition and exact later-owned finding/Haskell-binding equality.
- An externally anchored fresh-challenge verifier over a signed immutable source bundle; only that verifier may
  construct `AcquiredSourceSnapshot`, and acquisition authority cannot promote status.
- Exact non-empty deny-by-default `pb/**` authored AST/import/resolved-direct-call/control-flow/potential-effect
  graph, with every supported authored effect node statically routed to the declared `BootstrapAdapter`;
  interpreter startup plus standard-library, native, transitive, and concrete-adapter effects remain explicit
  Phase-50 runtime residue.
- Lazy-output and authored-root write checks.

### Validation

Paired cases cover `.hs`, allowed non-code inputs, each `pb` bootstrap role, disguised Python/shell, executable
data, shebang source, behavioural metadata, source-adjacent cache, generated output under authored roots, and
every signature/challenge/bundle/tool/custody/source-identity acquisition boundary named by the phase contract.

### Remaining Work

The acquisition component now rejects an unborn repository, staged index/HEAD divergence, assume-unchanged and
skip-worktree flags, and final-index changes. It independently recomputes SHA-1 or SHA-256 Git blob framing,
binds the index to the repository storage format at both acquisition boundaries, and derives the candidate
snapshot identity as domain-separated SHA-256 over that format plus the exact path/mode/object manifest. Its
descriptor-relative `O_NOFOLLOW` walk pins directory device/inode identity, sees ignored and untracked authored
material, and refuses symlinks, special files, and replacement. Fixed vectors and generated-repository paired
cases are green as component diagnostics on 2026-08-23; the object-format-boundary changed-subject mutant is red
at its exact oracle. These observations have not qualified the parent harness, authenticated the Git/toolchain
input, or received independent human review.

A 2026-08-23 acquisition-boundary audit confirmed that the ordinary build cannot mint
`AcquiredSourceSnapshot`: caller-selected Git always stops with separate authentication and atomic-custody
refusals, and only the intentional acquisition-bypass mutant reaches the private constructor. It also confirmed
that sequential HEAD/index/worktree reads cannot prove a globally atomic view or exclude ABA. The candidate
design is therefore an externally anchored fresh-challenge verifier over a signed immutable source bundle. Its
canonical envelope must bind the acquisition-authority and observer/tool-closure identities, durable replay
identity, frozen-custody method, object format, exact HEAD/tree, nonempty canonical path/mode/Git-OID/length/blob-
SHA-256 manifest, authored-root observation digest, and resulting source-snapshot identity. Haskell must verify
the signature and independently recompute every byte commitment before the verifier alone constructs the opaque
token. The private refusal-only v2 Haskell wire parser now binds repository identity, requested revision,
expected HEAD, expected source-snapshot identity, and an externally supplied authored-root identity. The signed
payload carries bounded raw commit bytes; Haskell authenticates them before decoding, recomputes the Git-framed
SHA-1 or SHA-256 commit OID to HEAD, requires the canonical tree-first/parent/author/committer header grammar, and
joins the parsed tree to the manifest tree. A separate bounded canonical expected-manifest input independently
states the exact object-format plus path/mode/Git-OID/length/blob-SHA256 universe and produces exact
missing/unexpected/per-field mismatches. Neither input can construct `AcquiredSourceSnapshot`, and the sole
public result retains permanent authority residue. Trust anchor, challenge, replay, observer, and key-role inputs
remain caller-selected diagnostics; replay consumption is not durable or atomic; no streaming immutable-bundle
transport exists; and an external authored-root observer must still establish that the expected identity covers
ignored, untracked, special, and replacement-race material. The parser bounds envelope, signed payload, bundle,
commit, expected manifest, field, entry count, member length, path length, path depth, and segment length; verifies
untouched raw payload bytes before semantic decoding; canonicalizes only after authentication; uses a narrow
portable ASCII path grammar with case-fold and prefix-conflict detection; and applies strict folds and set-based
duplicate detection. Its oracle owns local wire/fixture declarations, pinned complete v2 bytes and signature,
Git framing vectors, exact constructor inventories, and exact diagnostic projections. Eight new single-locus
mutants target repository, revision, expected HEAD/source/authored-root, commit identity/tree, and expected-
manifest joins. Focused warning-clean compilation, the clean oracle, and all eight isolated changed-production
diagnostics behaved as expected; independent adversarial review and integrated qualification remain pending.
The preceding v1 API audit rejected the apparent positive path because the module still
exports constructible manifest and entry records plus `verifySourceAcquisitionDiagnostic :: ... -> Either ...
SourceAcquisitionManifest`, and the oracle calls the `Right` branch “verified” while constructing fixtures with
those production record types. That conventional success/result-sharing surface could detach the mandatory
diagnostic residue. It had to become private behind the always-refusing `CheckResult` front door, and fixture
declarations had to become oracle-local before isolated mutants could run. At that historical point, an external
trust anchor and acquisition-key custody, fresh challenge issuance, durable atomic replay consumption, signed
commit bytes and the HEAD-to-tree join, repository/request identity, an independently acquired complete expected
manifest, a separate complete authored-root inventory, compile-negative API checks, applied mutation witnesses,
and qualification were absent. Acquisition authority will not be promotion authority. That read-only review
also found that the six then-advertised
mutants are not an atomic matrix: the “key” mutation removes four expectation joins rather than Ed25519 key
binding, the identity mutation covers only the tree, and the mapping mutation is killed first by replacing the
permanent residue. Bundle-digest and custody mutants are absent; seven problem constructors lack any oracle case;
nearly every negative bypasses the public diagnostic mapping; case-folded ancestry and a changed tree-sort
comparator are uncovered; and the signature covers payload bytes rather than the complete canonical envelope
prefix promised by the contract. The completed rewrite reduces the production export surface to the single
always-refusing `sourceAcquisitionDiagnostic` front door; raw values and expectation records are private. The
oracle uses local fixture and wire types plus independent literals, and the signature covers the canonical
envelope prefix plus payload. Focused warning-clean compilation, the clean oracle, and an external-client attack
on both private result imports completed on 2026-08-23. Fourteen isolated production mutations bypassed signature
verification, authentication-before-decode, canonicality, phase, authority, observer, challenge, replay, frozen
custody, bundle identity, tree identity, Git tree ordering, permanent diagnostic authority, or one exact problem
mapping; every changed build reddened a named exact oracle row. Their Cabal registrations now replace the three
rejected multi-locus flags. A Cabal-selected signature-bypass build also reached the oracle and red rather than
failing to select the mutation. These direct and component runs still lack applied source/binary witnesses,
same-harness unaffected controls, external trust/custody, durable replay consumption, qualification, and human
review, so they are diagnostics rather than acquisition or promotion evidence.

The exact later-owned source families now have separately declared Haskell path-count, exact path-inventory,
and path/mode/object/blob-byte baselines. An independent Haskell Git-index/blob observer freezes the live values;
direct observer cases change membership, family, path digest, and byte digest without trusting production
comparison. Changed-count/identity/mode/path/wrong-family cases and five changed-production debt mutants are
component diagnostics. That check, the snapshot classifier, and the fail-closed
source-consumer seam are composed into the real Phase-0 dispatcher. Source-related legacy observations are
derived from those checks rather than caller-supplied flags: later-owned families remain exact open debt,
`LTD-SRC-008` can report zero only after full `pb` admission, and `LTD-SRC-000` refuses while any source,
baseline, or compiler-consumer finding remains.

A 2026-08-24 re-audit superseded that source-debt API and oracle surface. The exposed facade now accepts only
raw path/mode/object/blob tuples and returns a permanently refusing `CheckResult`; the baseline registry,
observations, comparison state, and exact `AcquiredSourceSnapshot`-bound opaque evidence live in a package-hidden
Internal module consumed by Dispatch and Legacy. The oracle uses local fixture types and complete ordered
results rather than production snapshot constructors or selected-finding presence. Preflight bounds raw
traversal at 16,384 entries, registered-family allocation at 1,468 entries, UTF-8 path and object identity at
1,024 and 64 bytes, each blob at 16,777,216 bytes, aggregate blobs at 33,554,432 bytes, problems at 24, and
observations at 26; each literal first-excess control is distinct. Path, payload, and inventory commitments use
incremental SHA-256 contexts without concatenating the manifest. All twenty-seven production selectors and
eighteen one-symbol opacity clients now have distinct Cabal registrations, the hidden module is an
`other-modules` target, a public facade control is present, and `cabal check` accepts the description. The
post-handoff static audit replaced one nonexistent opacity target and added separate attacks for every package-
internal entry point and the evidence type versus its constructor. It also found that the raw facade reached
SourceClosure classification before applying field and aggregate byte bounds; a new raw preflight now checks
every path, object identity, blob, and aggregate before that semantic traversal. Warning-clean direct compilation
then exposed and repaired only unused/shadowed-binding diagnostics, and the clean exact SourceDebt oracle exits
zero. On these bytes a fresh clean compiled control also exits zero; all twenty-seven isolated selectors compile
with a preprocessed production subject distinct from clean and redden the exact ordered oracle, and a separately
stated twenty-seven-row intent inventory finds its required named failure locus in every retained log. Seventeen
one-symbol attacks on private exports of the public facade fail with exact missing-export diagnostics naming
symbols that really exist in the package-internal implementation, while the public facade control compiles. The
eighteenth attack targets package-level opacity of the entire Internal module and still requires a Cabal-package
build; Cabal-selected mutation runs, same-harness unaffected controls, and qualification are also absent. The
exact acquired-evidence binding deliberately remains unmutated residue because no external oracle can reach its
mismatch branch without weakening the opacity boundary. None of this is validation.

The exact-selector audit has also narrowed the meaning of that twenty-seven-row SourceDebt result. The closed
later-owned registry contains eight baseline rows with three independent fields each, but only the count,
fingerprint, and path-inventory fields of `SourceTools` have field selectors; the other twenty-one literal
baseline fields have none. A `SourceVendor` row-omission selector does not cover mutation of its individual
fields or omission of the other rows. `VALIDATION_SOURCE_DEBT_OBSERVER_FABRICATION_MUTANT` also changes all
three observation fields together; it is a compound challenge, not an atomic selector, although the three
individual observer-fabrication selectors do exist. The prior clean oracle remains useful as a diagnostic, but
complete baseline-field and row-presence selectors, an exact selector-intent registry, and a fresh matrix are
required before the source-debt comparison can be called mutation-complete.

The baseline-specific repair is now present but not yet execution-qualified. Each of the eight later-owned rows
has one independent omission selector and each of its count, fingerprint, and path-inventory fields has one
independent value selector; the original generic omission remains the exact `SourceVendor` row selector. The
oracle now carries a closed fifty-five-row selector-to-exact-case intent registry covering those thirty-two
baseline rows together with the twenty-three existing resource, observer, comparison, diagnostic, and grammar
selectors. A static current-byte reconciliation finds the same fifty-five names exactly once in production,
the independent oracle registry, and Cabal `-D` mappings. This closes the previously identified twenty-one field
holes and seven row-presence holes. A fresh warning-as-error direct build and exact clean oracle now exit zero.
The first complete registry-driven run was discarded after the byte-commitment selector left its real hashing
helper dead under `-Werror`; production now evaluates that helper before deliberately substituting the changed
commitment. On the repaired current source, all fifty-five registry-named selectors compile warning-free, produce
executables distinct from the clean executable, and red inside `SourceDebtBaselineOracle`, with zero survivors,
build failures, unchanged executables, or failures outside the oracle. A second run driven from the oracle-owned
registry also bound all fifty-five red logs to their named exact-case labels. Through Cabal's real package
boundary, the public facade control compiled and ran, the Internal-module client failed with the exact hidden-
module diagnostic, and the restored default public control compiled and ran again. The package build used the
existing mutable local store, so it is diagnostic rather than authenticated toolchain evidence. Cabal-selected
changed-subject witnesses, same-integrated-harness controls, qualification, authenticated inputs, and independent
custody remain pending. These are component diagnostics only; SourceDebt is still NOT VALIDATED.

The first three-file `pb` grammar candidate was rejected during review despite a green component oracle. Its
one-file replacement freezes `pb/__main__.py` at 4,770 bytes and independently restates its digest, calls,
effects, control-flow graph, environment keys, artifacts, and Phase-50 residue. A second adversarial review on
2026-08-23 still rejected static admission. Conditional module-level imports escaped the direct-import check;
module assignments could rebind `__file__` and `__name__`; and an early return or raise could make the exact
last handoff unreachable. The review also corrected two overclaims: `-I -S -B /abs/repo/pb` is a required
Phase-50 invocation contract rather than a source-derived fact, and the exact seven-key mapping proves a closed
child environment rather than absence of ambient interpreter, proxy, certificate, or default-search authority.
The Haskell analyzer now rejects each bypass and the independent oracle contains direct/conditional paired
negatives for all of them. A third adversarial review then found public record-update proof surfaces, a falsely
non-returning handoff CFG, incomplete effect traversal for calls nested in assignments, and an exact-child-call
enumeration gap. The proof and enclosing source closure are now private positional values with ordinary
projections; the CFG truthfully records handoff requests as may-return until Phase 50; and the total resolved-call
walk includes nested adapter invocations. Focused clean diagnostics and isolated adapter-effect-omission,
child-call-omission, and handoff-may-return mutants behaved as intended. The integrated component runner reached
all seventeen then-current oracles and the bootstrap row was green, while the independently stale documentation-residue
manifest kept the aggregate red. Dispatcher qualification and human review still block removal of the static
readiness refusal; `LTD-SRC-008` stays Active, and the bootstrap is not executed. The Git index still
contains the old fifteen-path footprint, so the one-file worktree is not a tracked-snapshot closure claim.
The dispatcher’s stale `PB-GRAMMAR-UNIMPLEMENTED` blanket has now been corrected to the exact
`PB-GRAMMAR-UNQUALIFIED` residue: the analyzer exists, while an acquired one-file tracked snapshot, applied
changed-subject qualification, and independent review do not. This message correction is not a closure claim.

The 2026-08-24 refusal-boundary rewrite now exposes only
`pbBootstrapGrammarDiagnostic :: [(FilePath, Text, ByteString)] -> CheckResult`. Canonical input retains the
diagnostic-only finding plus all twenty-one explicit Phase-50 runtime findings; SourceClosure no longer turns a
static grammar result into `PbBootstrapSource`, so `LTD-SRC-008` remains active debt. Exact raw byte/mode/digest
preflight and bounded token/AST/call/effect/control-flow/problem metrics precede the private analysis. Fifty-
eight one-locus production selectors have distinct Cabal flags and mappings. A post-handoff audit rejected
nineteen advertised opacity clients because they imported names that did not exist and would therefore fail
even if the real private API leaked; those false tests and their Cabal entries were deleted. The remaining
sixty-two one-symbol clients each name an actually present private production symbol, and one public control
names the sole facade function. Warning-clean direct compilation of Pb, SourceClosure, their two oracles, and
the source-debt seam completed. The first clean Pb run then exposed two oracle defects—an independently computed
syntax depth of four had been expected as three, and an `os.system` fixture reached unresolved-call refusal
instead of the advertised direct-effect predicate. The corrected literal depth and minimally different
resolvable `platform.system` direct-effect fixture make the clean Pb and SourceClosure oracles exit zero. No Pb
bootstrap was executed. On the current bytes a newly compiled clean control exits zero; all fifty-eight isolated
changed-production selectors compile, have a preprocessed production subject distinct from the clean subject,
and redden the exact ordered oracle. A separately stated fifty-eight-row intent manifest then matched the
production-selector inventory exactly and found its required named failure locus in every retained log,
including selectors with collateral failures. All sixty-two one-symbol clients fail with a compiler diagnostic
that names their actually present private production symbol as not exported, while the sole public-facade
control compiles. The complete per-selector failure logs are retained beneath ignored `.build/**`;
Cabal-selected execution, acquired tracked inventory, same-harness unaffected controls, qualification, and
human review remain pending. These observations are component diagnostics only.

A subsequent exact-locus audit has invalidated the claimed fifty-eight-row completeness. The single
`VALIDATION_PB_GRAMMAR_PHASE50_RESIDUE_BYPASS_MUTANT` removes all twenty-one independent Phase-50 runtime
requirements at once, so it cannot prove that the oracle notices omission of any one interpreter, isolation,
environment, transport, filesystem, tool, argument, exec, or exit-propagation residue. The runtime-residue
registry now gives every row its own once-only production selector and Cabal mapping while the oracle continues
to compare the complete ordered observation and finding lists. The replacement inventory is exactly seventy-
eight source selectors and seventy-eight `-D` mappings, with no duplicate source occurrence or old combined
name. A warning-clean direct clean build exits zero; all twenty-one new changed-production executables have a
different digest from that clean executable and redden only the canonical full-result case. These focused runs
used the exact source-bound Haskell modules directly, never executed `pb`, and remain component diagnostics.
The old combined selector and its retained result are rejected; the complete seventy-eight-row matrix,
Cabal-selection witnesses, same-harness unaffected controls, integrated qualification, and human review remain
pending, and this repair cannot establish any Phase-50 runtime fact.

A current isolated direct Haskell rebuild has again compiled the Pb grammar subject and its independent oracle
under `-Wall -Wcompat -Werror`, and the exact clean oracle exits zero. The run did not invoke Python or execute
`pb`. It does not rehabilitate the prior matrix: the oracle still lacks the independently literal 78-row
selector-to-exact-case registry now required by the gate-integrity standard, so production-derived enumeration
cannot establish completeness or assigned-locus rejection. Registry integrity, the complete registry-driven
matrix, package opacity and public controls, Cabal-selected witnesses, same-harness unaffected controls,
tracked one-file source acquisition, qualification, and human review remain open. This is a component
diagnostic only.

The independent Pb atomic-completeness audit has rejected seventy-eight before constructing a literal registry.
Most decisively, `boundProblemList` returned only the first semantic problem whenever the full list remained
within its sixty-four-problem ceiling. A correct first refusal could therefore mask omission or corruption of
every later binding, call, effect, control-flow, or proof problem while the oracle remained green. Production
now retains the complete bounded problem list and still replaces the first sixty-five-problem prefix with the
single exact limit refusal. This necessarily invalidates every grammar expectation that relied on first-only
projection. The audit also found compound observation-retention selectors—five subject observations, the full
resource/limit vector, and nine static-claim rows—as well as unselected problem-code mappings and proof-field
contributions. The oracle must independently restate the new complete ordered results and every such atomic
projection before a successor selector total or matrix is admissible. No Python or `pb` execution is involved.

The first complete-list oracle repair now independently states every finding, in order, for the existing changed-
grammar cases, all nine exact resource ceilings, the exact sixty-four-problem boundary, and the sixty-five-problem
collapse. A strict direct `-Wall -Wcompat -Werror` rebuild of the Haskell subject and oracle completed, and the
resulting oracle exited zero without invoking Python or `pb`. This closes the first-only expectation defect only;
it does not close the atomic-completeness rejection above. The literal selector registry, split observation and
claim projections, problem-code and proof-contribution selectors, assigned-locus matrix, package-opacity controls,
Cabal-selection witnesses, integrated qualification, and human review remain open. The result is a component
diagnostic and no sprint or phase status changes.

The consumer seam assigns closed non-behavioural roles and exact authorized consumers, rejects lexical
license/notice admission, audits supplied resolved effects only as negative evidence, and binds every `.hs`
path/mode/object identity. The 2026-08-23 adversarial integration review rejected the linked-GHC path. The
acquisition slice now makes arbitrary Git diagnostic-only, compares the exact final index-object/mode and HEAD,
and retains explicit external atomic-custody residue; its focused clean and five isolated mutant diagnostics
behaved as intended. The review's remaining compiler findings were that missing Cabal input was accepted, the
derived component plan was ignored, all required compiler facts were asserted wholesale, the compiler join
deleted findings by textual code, and dispatcher assertions were masked by unconditional readiness refusals.
The compiler slice now refuses missing or non-exact restricted Cabal declarations, applies their source roots,
derives only four witnessed facts, and removes exactly one typed positional consumer residue while preserving
duplicate, absent, length-mismatched, and unrelated same-coded findings. The review also found two multi-locus
mutants, weak exact-locus negatives, production-derived expected universes, and a missing typed
`SourceDebtId`-to-`LegacyId` evidence join. Current work has split the source-consumer mutations, bound both
legacy IDs with an inverse-checking swap mutant, frozen its bounded universes, and made raw closure/debt checks
permanently diagnostic.

The 2026-08-24 refusal-boundary rewrite now exposes only `sourceConsumerGraphDiagnostic` over raw standard
tuples; the source inventory, effects, bindings, Haskell subjects, compiler requirements, problems, and acquired
composition state are package-hidden. The facade always retains diagnostic-only, source-custody, and all twelve
compiler-fact refusals. It preflights the two raw inventories at 64 entries, bindings/Haskell subjects/problems
at 32, result observations at 218, paths at 1,024 UTF-8 bytes/64 segments/255 bytes per segment, and other text
fields at 256 bytes. The oracle now uses separately frozen exact counts, rows, identities, object IDs, and full
ordered results rather than deriving its decisive expectations from the production inputs. Cabal maps eighty-
seven facade selectors and four Internal selectors to ninety-one distinct production loci, each occurring once;
forty-five one-symbol opacity clients and one public control are registered. Static set reconciliation and
`cabal check` are clean. The complete clean/selector/opacity matrix deliberately awaits the SourceClosure
facade/Internal split, which changes its exact authorized-reader module and path literals; no current observation
has been counted as SourceConsumer candidate evidence.

After the SourceClosure public-boundary rewrite stabilized, a fresh isolated direct Haskell build compiled the
SourceConsumer facade and independent exact-result oracle under `-Wall -Wcompat -Werror`, and the clean oracle
exited zero. The clean result is not a matrix result: the oracle still contains none of the 91 production
selector identities and therefore cannot independently declare the mutation inventory or bind a changed
subject to its assigned exact case. Its literal registry, two-way source/oracle/Cabal reconciliation,
registry-driven 91-row matrix, package opacity/public controls, Internal acquired composition, same-harness
unaffected controls, qualification, authenticated inputs, and human review remain open. This is a component
diagnostic only and does not advance Sprint 0.3.

A further 2026-08-23 adversarial audit established that this remains synthetic-only. The Git index has five
Cabal packages, 183 components, 682 Haskell files, and two remote packages; the current worktree has 708 Haskell
files, so the indexed count is not a current worktree-source claim. The remote refs have now been
changed from `master` to the exact cached commits, but their bytes and dependency custody remain unauthenticated;
the adapter accepts exactly one dependency-free component and therefore cannot reach GHC on the repository
graph. The audit's record-update bypasses are now closed: `CompilerComponentPlan`,
`CompilerSourceGraph`, and their nested compiler facts are private positional values with ordinary projections,
and two external-client compile negatives fail at the exact record-field loci. Re-exposure mutants exist for
both outer proofs. Required facts now truthfully say that conditional preprocessing and compile-time execution
features are absent in the restricted accepted session rather than claiming branch/execution coverage. Package-
level build type, custom Setup, data/source inputs, and an unelaborated `cabal.project` now refuse explicitly;
Cabal-declared module names join to exact GHC-observed module headers. Isolated bypass flags exist for those
loci and for unowned subjects, multiple components, conditionals, options, dependencies, component BuildInfo,
assignment identity, and configuration differences. On the current bytes all thirteen such isolated behavior
bypasses fail their focused oracle at the named locus; both external record-update attacks fail against clean
production and compile only when the corresponding proof re-exposure mutant is enabled; and a restored clean
build plus the three current compiler diagnostics is green. This is a component mutation matrix, not candidate
evidence: the new elaborated-plan parser still awaits adversarial and changed-subject qualification, and none of
these runs supplies authenticated source/compiler inputs or repository semantic closure.

The 2026-08-24 ComponentPlan refusal rewrite supersedes that thirteen-mutant surface. Its public facade now
exports only `compilerComponentPlanDiagnostic`; all parsed declarations, assignments, configurations, limits,
problems, projections, and candidate-facing composition remain package-hidden. At that checkpoint, seventy-eight
production selectors had seventy-eight distinct manual Cabal flags and exact `-D` mappings; eighteen one-symbol opacity
clients and one public control are registered. A pre-matrix audit then rejected all eighty-five oracle cases
because their decisive expected counts and inventory/projection digests were recomputed from the same fixture
inputs. Those expectations are now frozen as eighty-five literal eight-field rows, while separate fixture-
integrity checks can only fail and cannot rewrite an expected `CheckResult`. An exact offline diagnostic package
instance (`Cbl-syntx-3.16.1.0-8ff4cf5a`) matches the cached source and Cabal hashes, but its mutable local-store
custody is explicitly non-candidate. A discarded clean attempt against that package exposed and repaired six
oracle expectations covering build type, Cabal condition rendering, reexport normalization, and interacting
module/assignment limits. The coordinated clean and selector matrix has not run: the next attempt encountered
the intentionally incomplete concurrent SourceClosure split and was discarded at compile time. No survivor,
kill, opacity result, receipt, or validation claim is retained.

A further static fail-closed review then found that the clean result-limit branch replaced all findings with one
limit row and thereby discarded the four permanent diagnostic/custody/elaboration/execution refusals; the oracle
endorsed that loss. Production now retains those four rows before the result-limit finding, and the bypass branch
also preserves them before bounded truncation. The two exact boundary expectations were changed with it. This
repair has not compiled or run across the in-progress SourceClosure dependency and must be included in the later
coordinated clean and selector rerun.

The same review invalidated that seventy-eight-selector cardinality: one `PUBLIC_RESIDUE` selector removed all
four logically independent permanent refusals. Source now gives diagnostic-only, source-custody, Cabal-
elaboration, and compiler-execution retention separate one-locus selectors, producing an eighty-one-selector
source inventory. The old combined Cabal flag/mapping has been replaced by four exact registrations, but the
updated exact intent rows and coordinated rerun remain open. A static reconciliation now finds eighty-one unique
source selectors, eighty-one manual flags, eighty-one exact mappings, one global production occurrence per
selector, no old combined name, and a clean `cabal check`; the plan does not represent that structural result as
runtime coverage.

The first current coordinated warning-as-error rebuild rejected that 81-selector surface at compile time:
`unsupportedBuildInfoFields` referenced Cabal's removed `jsppOptions` projection even though the pinned
Cabal-syntax 3.16.1 parser reports `jspp-options` only as an unknown-field warning. More fundamentally, the
component used `parseGenericPackageDescriptionMaybe`, which discarded every parser warning and could therefore
admit an unknown declaration field. Production now consumes the duplicate-aware parse result, refuses any
nonempty warning set before component projection, removes the nonexistent projection, and suppresses secondary
unowned-subject analysis after a parse failure or warning. Two once-only selectors separately bypass warning
refusal and that fallout barrier; two minimally different exact full-result cases bind those loci. A fresh
direct build of production and the independent oracle completed under `-Wall -Wcompat -Werror`, and the clean
oracle exited zero. Each of the two new changed subjects compiled warning-free and reddened its named exact
case. Static source/Cabal identity reconciliation is now 83/83 with no duplicate or delta. This remains partial
diagnostic work: the oracle still has no independently literal 83-row selector registry, and the complete
registry matrix, package opacity/public controls, same-harness unaffected controls, integration, qualification,
authenticated inputs, and human review remain open. ComponentPlan is NOT VALIDATED.

The ComponentPlan oracle now owns a literal eighty-three-row selector-to-exact-case registry rather than
discovering its inventory from production or Cabal. Its integrity check fixes the cardinality, rejects
duplicate selector identities and duplicate exact-case labels, requires every target label to exist exactly
once, and limits intentionally unassigned exact cases to a literal control whitelist. Static reconciliation on
the current bytes finds the same eighty-three once-only identities in production, the oracle registry, Cabal
flags, and Cabal `-D` mappings. The first registry-driven sweep is rejected in full: although all eighty-three
preprocessed subjects changed, only seventy-four compiled under `-Wall -Wcompat -Werror`, and the language-
projection subject left its assigned row green while reddening other rows. The nine compile failures were
warning fallout caused by mutation branches making real imports, helpers, or values unused; such fallout is not
an admissible predicate kill. Production now applies those nine bypasses through typed projection functions so
the real calculation remains referenced and warning-checked, and the language selector is assigned to the
literal supported-projection case it actually changes. A fresh clean build and exact oracle exit zero, and a
focused rerun of the nine repaired subjects plus the language subject finds ten changed preprocessed subjects,
ten changed executables, ten warning-clean compiles, and ten assigned-row and aggregate reds. A fresh complete
eighty-three-row sweep, same-harness unaffected controls, package opacity, independent atomic-predicate review,
integration, qualification, authenticated inputs, and human review remain open. The discarded 74/83 sweep and
the focused repair run are diagnostics only and do not advance Sprint 0.3.

The fresh complete ComponentPlan rerun then froze the exact production tree and oracle beneath the diagnostic
run root and verified their hashes still matched the live bytes after execution. The clean warning-as-error
build and all-case oracle exited zero. All eighty-three registry-selected subjects compiled warning-clean,
changed both the preprocessed `CompilerComponentPlan.Internal` subject and linked executable, and reddened
exactly one failure line bearing their literal assigned-case label. There are no duplicate changed-subject or
changed-executable hashes. Current production, oracle, Cabal macro, manual-flag, `if flag(...)`, and exact
flag-to-macro inventories contain the same eighty-three identities once each with zero pair or set delta. This
result closes the defects exposed by the discarded first sweep, but it is still a direct component diagnostic.
The independent atomic-predicate audit, package opacity/public controls, Cabal-selected witness, integrated
unaffected controls, qualification, authenticated toolchain/source custody, and human review remain open, so
ComponentPlan and Sprint 0.3 remain NOT VALIDATED.

The promised independent atomic-predicate audit has now rejected eighty-three as a completeness total. The
snapshot-identity grammar selector changes both exact length and alphabet in one branch; the object-identity
corpus has no independently mutable 39-, 41-, 63-byte, or uppercase class; and the byte ceilings exercise only
ASCII, so replacing UTF-8 byte counts with character counts can survive. More broadly, the raw-inventory and
component-projection commitments lack one selector per domain tag, frame, and contributed field; component kind,
subject path, subject mode, merged configuration, observations, result status, and many problem-to-finding
projections have no atomic changed-subject row. The clean 83/83 result proves only that its declared baseline
selectors are live and correctly assigned. Those grammar partitions, digest contributions, projections, and
render mappings must receive independent literal cases and once-only selectors before a successor total is
admissible; eighty-three is therefore superseded as a mutation-completeness claim.

An exact tracked-tree CPP inventory currently finds 152 Haskell files containing directives, 389 conditional
directive lines, 71 compound `#if`/`#elif` lines, 19 `#elif` lines across 15 files, and five files nested to
depth two. Therefore clean plus isolated one-flag runs cannot establish the configuration graph: the elaborated
plan must enumerate every admitted flag/configuration and independently establish every reachable branch
combination, or refuse the unsupported configuration before producing evidence. Elaborated unit IDs,
dependencies, flags, authenticated ambient compiler state, that conditional-configuration closure, and
individual mutations for every residue-discharge conjunct remain absent. Until a real elaborated multi-package
compiler graph closes calls, indirect calls, control flow, effects, tracked-content provenance,
product-behaviour sinks, and dynamic loading against exact repository bytes, the compiler path is a conservative
declaration linter plus restricted fixture diagnostic—not repository evidence.
The current generated Cabal `plan.json` has also been audited only as a schema diagnostic. It contains 457
unique unit IDs: 183 local units projecting 184 components across five package roots, 235 remote-source units,
and 39 pre-existing units. Its 3,251 top-level or nested dependency edges resolve to those unit IDs, and it exposes
component names, Boolean flag maps, compiler/platform identity, package source origins, and some build paths.
It does not expose individual Haskell paths, module names, source directories, or Cabal-file paths; it omits
source locations for pre-existing units and unpacked paths for remote units; and local entries carry neither
source nor Cabal hashes. Its absolute paths are machine-bound, and the generated file and generating Cabal/GHC
inputs are not externally authenticated. A conservative parser may therefore establish plan shape and
dependency/flag identity while retaining these exact refusals, but it cannot independently establish source or
compiler-graph closure. The first parser candidate is not yet admissible even for that bounded role: its local
component-completeness comparison is self-derived from the same JSON keys, and it collapses three remotely
sourced `inplace` units with build-info paths into an origin for which it emits no source-path residue. Both
conditions were rejected rather than waived. The public result and parser are now explicitly named
`DiagnosticCompilerElaboratedPlan` and `parseCompilerElaboratedPlanDiagnostic`; source provenance and Cabal build
style are separate; the three `inplace` units retain source-path residue; and the tautological comparison has
been replaced by permanent unauthenticated-input, independent-component-universe, and accepted-field-binding
residues. A token-preserving Aeson pass now rejects duplicate keys before `KeyMap` normalization, including an
exact root-key paired negative. Applied to the 3,770,198 current generated bytes, the parser returns all 457
units and 194 explicit problems: unauthenticated plan input; unavailable independent component, configuration-
branch, CPP-branch, and dependency-semantics universes; lexical-only and unavailable physical local-root
identity; and unavailable exact source paths for 184 local and three `inplace` components. Independent expected-
universe acquisition, exact branch and dependency semantics, changed-subject qualification, and the acquired-
plan wrapper remain absent, so this stays disconnected from compiler evidence and Dispatch.
The structural parser now also refuses empty configured-component maps, malformed closed component names,
self-dependencies, dependency cycles, and duplicate/unknown ordinary versus executable edges without conflating
their edge roles. It bounds input bytes, JSON depth/tokens/decoded text/collections, and accumulated problems,
and its oracle pins boundary and one-over cases plus escaped nested duplicate identities. Its current plan parse
retains observations with the same 194 mandatory residues, but a second adversarial review has rejected that
API: the conventional `Either` success branch and exported observation projectors let a caller detach or ignore
those residues, while direct singleton-component and aggregate singleton-component-map encodings collapse to
the same observation because their configured-component shape is discarded. The parser must become refusal-only,
retain that shape, add the minimally different paired control, and kill changed-production mutants before it may
serve even as a diagnostic input. The completed review also found nonempty-text identifier/path grammars that
admit control bytes and unsafe paths; residues not bound to the exact input digest, role-labelled dependency
edges, or flag/configuration subject; resource expectations copied from production constants with non-exact or
wrong-result-accepting controls; semantic problem lists bounded only after construction and sorting; no
independent duplicate-key observer residue; and incomplete positive retention checks for admitted fields. The
refusal-only rewrite, fixed literal boundaries, early bounded accumulation, full snapshot controls, and the
review's changed-production matrix are now implemented. The production export list contains only
`checkCompilerElaboratedPlanDiagnostic`; all parser values, limits, enums, snapshots, problems, and projections
are private, and the oracle independently restates the diagnostic wire grammar and hashes its inputs through a
different Haskell package. Focused production and oracle compilation, the clean diagnostic, and the raw-parser
compile-negative completed on 2026-08-23. Twelve isolated production mutations removed the public refusal,
duplicate-key guard, one resource ceiling, sum/product distinction, accepted-field retention, dependency or cycle
guard, mandatory diagnostic residue, source-identity guard, component-shape distinction, semantic grammar, or
path grammar; each reddened its exact named row, with separately recorded expected collateral where a mutation
changed multiple fixture outcomes. Those direct runs lack an applied source/binary witness, same-harness clean
control, independent acquisition/custody, aggregate Cabal execution, qualification, and human review, so they are
component diagnostics rather than promotion evidence.
The broader refusal-only audit has now superseded that twelve-selector sample. The current production surface
still exports only `checkCompilerElaboratedPlanDiagnostic`; its exact inventory is ninety-one one-locus
selectors, ninety-one distinct manual Cabal flags, ninety-one exact `-D` mappings, five one-symbol private
opacity clients, and one public control. A fresh warning-clean production/oracle build and clean oracle completed.
All ninety-one isolated selector builds compiled, produced executables distinct from the frozen clean
executable, and were rejected by the clean exact-result oracle; none survived, build-failed, remained unchanged,
or failed outside the oracle. Four successful mutant builds emitted dead-code warnings, but no warning was
promoted to a kill. Each of the five private clients failed for its exact named non-exported symbol, while the
public client compiled and ran. The retained ignored receipt and logs record one corrected diagnostic-driver
defect: an initial `pipefail` path treated a zero-warning search as failure, so that attempt was discarded and all
six boundary clients were rerun. These are current component diagnostics only; no Cabal build, applied
source/binary witness, authenticated plan/toolchain acquisition, same-integrated-harness controls, qualification,
independent custody, or human review follows from them.
A 2026-08-24 fail-closed re-audit has invalidated that ninety-one-selector result as a complete matrix. When a
valid observed plan produces more than the semantic problem ceiling, `boundedProblemList` replaces the entire
problem list with one `PlanResourceLimitExceeded` row. That drops the input-authentication, plan-generation,
independent-universe, snapshot-binding, source-custody, and oracle-qualification refusals instead of retaining
them beside a bounded result-limit refusal. Only snapshot-binding and oracle-qualification residue currently
have individual selectors; the other permanent refusal predicates therefore also lack atomic changed-production
coverage. The repair must separate permanent findings from variable semantic findings, retain every permanent
row under the result ceiling, give each row one selector and one independently literal exact-result case, and
rerun the complete matrix. No earlier CompilerElaboratedPlan green result is candidate evidence.
A refusal-retention repair is now present but remains a component diagnostic. Observed-plan problems are split
into a fixed fifteen-row mandatory prefix and a data-dependent source-path tail. The public result ceiling is a
literal 128 findings: exactly 113 variable rows retain all fifteen mandatory rows, while the 114th variable row
produces those same fifteen rows followed by one exact `observed-variable-problems` limit refusal. The oracle
states both complete boundary results from separately authored Haskell snapshots and an independent `crypton`
digest. Each mandatory row, the source-path row, the mandatory-prefix join, and the result-limit predicate has
an atomic once-only production selector. Component, dependency, and flag ceilings count the complete decoded-
input subject before unit parsing, sorting, dependency-graph construction, snapshot projection, or rendering.
Seven independent counter selectors cover direct components, component-map members, root ordinary and
executable dependencies, nested ordinary and executable dependencies, and flags; exact maximum and one-over
cases cover every admitted aggregate locus. Together with the literal unit, scalar, path, collection, and
128-result ceilings, these checks bound every public observation and finding list before rendering.

The first 114-selector rerun after that repair was rejected because its driver discovered selectors from the
production CPP subject. The oracle could therefore have omitted the same selector without changing the reported
total. The oracle now owns a closed 114-row literal selector-to-exact-case registry and a separately declared
95-label exact-case list. Runtime integrity checks require literal cardinality 114, no duplicate selector, no
duplicate exact-case label, exactly one declaration of every referenced target, and no reverse-unreferenced
target. A separate static check found each of the 95 labels exactly once in an executable assertion. Two-way
reconciliation finds exactly the same 114 once-only identities in the oracle, production source, Cabal `-D`
mappings, manual flag declarations, and `if flag(...)` conditions, with no missing, extra, or unknown identity.
A strict compile pass exposed the public-refusal, duplicate-key, and cycle selectors as the three formerly
warning-bearing variants. Their mutation loci were narrowed so the bounded finding, JSON-scanner, and graph-
edge subjects remain used; all 114 variants now compile with `-Wall -Wcompat -Werror`.

The first registry-driven execution was also rejected honestly: all 114 subjects compiled, changed, remained
distinct, and reddened the oracle, but the component-shape-collapse selector was mapped to the direct-shape row
rather than the aggregate singleton row it actually changes, so assigned-locus coverage was only 113/114. After
correcting both independent literal declarations, the same-harness clean control passed with frozen executable
SHA-256 `5de7a2595270dc64962a465c13e9b9b118ecd6f632ab5d17b232c2640ed6a493`.
The complete corrected rerun recorded 114/114 strict compilations, changed production subjects, distinct subject
hashes, in-oracle refusals, and assigned-locus refusals. Survivors, build failures, unchanged subjects, duplicate
subjects, out-of-oracle failures, and wrong-locus rows were all zero.

The implementation remains behind a package-hidden `CompilerElaboratedPlan.Internal` facade whose sole public
export is `checkCompilerElaboratedPlanDiagnostic`. The default cached build root rebuilt the library offline,
and the independently compiled focused oracle matched when linked only against that Cabal-built package. The
five named private parser/carrier/type/fold clients failed for their exact non-exported symbol, the `Internal`
client failed for the exact hidden-module boundary, and the paired public client compiled and ran. The aggregate
validation-kernel oracle suite remains open because `DispatchOracle`, `LegacyOracle`, and `PolicyContractOracle`
still import the package-hidden `SourceClosure.Internal` module. None of these focused diagnostics supplies an
applied source/binary witness, authenticated plan/toolchain acquisition, qualification, independent custody,
human review, or validation of Sprint 0.3.
An offline fresh-build-root diagnostic then failed before configuration because the isolated root did not contain
the two remote source-repository checkouts; the default mutable build root succeeded only by reusing its existing
cache. Running Cabal's diagnostic `--enable-build-info` switch there produced a component JSON file with the
unit/component identity, compiler arguments, module list, source directories, package databases, source root,
and Cabal-file path. Those bytes did not exist until this unauthenticated Cabal invocation, contain absolute
host/store/build paths, and report named modules rather than exact immutable source bytes. They identify a useful
future join but are not clean-room or compiler evidence. A subsequent ordinary Cabal reconfiguration removed
that generated file entirely; no `build-info.json` remains beneath the current `dist-newstyle`, reinforcing that
it is mutable diagnostic output rather than a stable input. A new closed-schema Haskell diagnostic parser retains
the exact compiler/component identities, arguments, modules, source files/directories, source root, and Cabal
file; refuses duplicate keys, identity mismatch, unsafe or escaping paths, missing package-boundary flags, and
known plugin, Template Haskell, preprocessor, FFI, linker, package-environment, and response-file hazards. Its
public result is now refusal-only: both folds receive a nonempty problem set, no success constructor or evidence
conversion exists, and retained observations always carry explicit generator, compiler, path, argument,
independent-universe, exact-source-ownership, generated-input, dependency, configuration, pragma, physical-
containment, elaborated-plan, invocation, and oracle-qualification residue. The duplicate-aware JSON scan and all
semantic collections are bounded, with exact boundary and one-over controls. The focused module compile and
independently literal oracle completed on 2026-08-23. Eight isolated changed-production diagnostics then widened
the input bound or bypassed duplicate-key detection, unknown-argument refusal, the compiler-argument unit join,
the expected compiler join, the expected component-universe join, generated-input residue, or oracle-
qualification residue; every changed subject compiled and reddened its intended exact oracle row. These runs do
not include applied source/binary witnesses, same-harness controls, independent custody, or qualification. The
parser still uses caller-constructible expected compiler and component universes; does not authenticate generator/
compiler/path state, resolve each module or main path to exact bundle bytes, authenticate generated/autogen
inputs, join an acquired plan/toolchain, or invoke GHC. Focused compiler diagnostics do not alter that verdict.
An independent API review then confirmed that no production consumer currently imports this diagnostic, but
rejected its non-detachability claim: the arbitrary-result fold lets a caller ignore the `NonEmpty` refusal and
projects only nine of twelve component fields, dropping parsed argument paths, generated inputs, and package IDs.
A present `cabal-file` also suppresses the exact Cabal-source join residue instead of retaining `(unit, Maybe
path)` for every component. Accepted-boundary controls inspect only counts/resource absence, and the positive argv
fixture shares the same list with its expected projection, so field loss or coordinated corruption can remain
green. The fold/projection, permanent Cabal join, oracle-local literal bytes, and exact full boundary snapshots
must be corrected before the eight local mutants are rerun. The review also found duplicate identity recorded
only after scanning the second value, late/repeated semantic traversal before the problem cap, unbounded caller
expectations/compiler IDs, POSIX-only paths without explicit platform residue, collapsed identity/argv/path
semantics, and uncovered package-boundary, attached-path, generated-input, identity-length, and path-limit loci.
The completed rewrite reduces the production export list to the single `compilerBuildInfoDiagnostic` function,
makes parsing and expected-value types private behind its always-refusing `CheckResult`, retains typed full
observations internally, applies an early budget, and expands atomic mutations and exact controls for those
defects. The Cabal version and every limit are private so the oracle states them independently. Focused
warning-clean compilation and the clean oracle completed on 2026-08-23, and an external-client attack fails at
all three private parser/refusal/eliminator imports. Sixteen isolated production mutations widen an input,
component-array, or problem boundary; bypass duplicate, unknown-argument, unit, expected compiler, expected
component, package-boundary, or path guards; omit generated-input, oracle, Cabal-join, platform, or diagnostic-only
residue; or drop an accepted projection field. Every changed build compiled and reddened its exact oracle control;
none silently survived. Cabal flags map all sixteen loci, but these direct runs have no applied source/binary
witness, same-harness unaffected controls, independent custody, or qualification and remain component diagnostics.
Qualification against the exact dispatcher build, authenticated external source/compiler authority, clean-room
custody, and independent re-review remain open.

The broader Sprint-0.3 audit subsequently superseded that sixteen-mutant BuildInfo matrix: sorting the public
result concealed order changes, several structural and field-specific resource ceilings shared one selector,
attached and separated path arguments shared another, and a combined opacity client could not detect selective
leaks. The production surface remains the single always-refusing `compilerBuildInfoDiagnostic`, now with a used
private refusal eliminator. The oracle compares the full ordered `CheckResult`, independently states exact
maximum/maximum-plus-one fixtures for every scalar, structural, object, generic-array, argument, module,
source-file, source-directory, expected-identity, expected-compiler-path, and problem limit, and separates both
path forms. Fourteen replacement one-locus selectors and twenty-one one-symbol opacity clients are present and
mapped into Cabal. A warning-clean direct Haskell compilation, clean focused diagnostic, and final clean restore
completed on these bytes. All twenty-eight current BuildInfo changed-subject selectors—including the fourteen
replacements—compiled independently and reddened the exact full-result oracle; the one public-control client
compiled, and each of the twenty-one one-symbol private-import clients failed at its sole missing export. These
direct invocations do not prove Cabal selected the intended flags, retain applied source/binary witnesses or
same-harness unaffected controls, join Dispatch, authenticate source/compiler custody, qualify the harness, or
supply human review. This is corrected component implementation and diagnostic behavior only, not compiler
evidence or validation.

A 2026-08-24 selector-to-predicate audit has superseded that twenty-eight-row completeness claim. The observed
BuildInfo result carries eighteen distinct permanent problem rows in addition to the diagnostic-only finding,
but only Cabal-source join, generated-input custody, platform semantics, oracle qualification, and the outer
diagnostic-only finding have individual selectors. Dropping any of the other fourteen custody, independent-
universe, source-ownership, dependency, configuration, pragma, physical-containment, elaborated-plan, or
compiler-invocation rows has no changed-production witness. The fixed 512-component ceiling, path depth and
segment ceilings, identity ceilings, supported Cabal version, and numerous compiler-argument and path-grammar
conjuncts likewise lack atomic selectors even where a clean boundary case exists. Finally, a one-megabyte input
bound does not replace an explicit pre-render envelope: the facade can materialize observation and finding
details across 512 components and 4,096-entry per-component arrays without a literal result count/byte ceiling.
The component needs a complete predicate/selector inventory, one selector per independent permanent row, exact
maximum/maximum-plus-one result-envelope cases, and a fresh full matrix before its prior diagnostics can be
relied on by Sprint 0.3.

The completed bounded BuildInfo repair supersedes that forty-nine-row interim inventory. The package-visible
module now exports only the refusal-only `compilerBuildInfoDiagnostic` function; parsing, carriers, problem
constructors, folds, and projections live in package-hidden `CompilerBuildInfo.Internal`. Seventy-five reachable
problem constructors remain after removing three impossible fallback/mismatch alternatives. The oracle states
175 independently executable full-result cases, including every reachable constructor, every schema and JSON-
scanner predicate, every grammar conjunction and closed alternative, canonical component/problem ordering,
every scalar and collection maximum/maximum-plus-one boundary, and the exact 14,877-entry and 2,097,152-byte
pre-render envelopes. Each of the eighteen permanent rows, every output family, every independent acceptance
predicate, resource ceiling, closed alternative, and routing/order decision has an atomic once-only selector.

The oracle owns a literal 220-row selector-to-exact-case registry and exposes a per-selector runner that executes
only the assigned full-result case while retaining literal registry, fixture, constructor, and opacity inventories
as unaffected controls. A hardware-free direct-Haskell diagnostic matrix compiled all 220 isolated changed
subjects: all 220 reddened their assigned locus, while no subject survived, failed at a wrong locus, disturbed a
control, or had an unresolved mapping. Exact set reconciliation found the same 220 identities, each once, in
`CompilerBuildInfo.Internal`, the oracle registry, Cabal CPP mappings, Cabal manual flags, and `if flag(...)`
conditions. The Cabal-built clean package matched the focused oracle and its public-control client. Each of the
twenty-one one-symbol public-facade attacks failed specifically because its symbol was not exported, the separate
implementation-module attack failed specifically because the module was hidden, and their literal oracle/Cabal
inventories reconcile as twenty-one plus one. A representative Cabal-selected JSON-colon build compiled the
changed BuildInfo subject but was interrupted during final package registration by concurrent
`Legacy.Internal` Cabal/source changes; it is not recorded as a Cabal-selection witness. These results remain
component diagnostics only: the complete Cabal-selected matrix, applied source/binary identity, authenticated
elaborated-plan/toolchain acquisition, external compiler execution, independent custody and qualification,
integrated Dispatch retention, human review, and human promotion remain absent. Sprint 0.3 is NOT VALIDATED.

A later adversarial review rejected the v2 commit decoder's permissive header order and combined privacy
attack. The decoder now uses a bounded state machine for exact tree, parent, author, and committer order. It
rejects continuation, unknown, duplicate, reordered, and malformed identity headers. Public expectations,
replay identities, header count, and line length have literal bounds. Expected-manifest entry and object-format
joins are separate production loci. The oracle now covers every reachable problem constructor with local wire
types and exact full results. Manifest and verifier opacity are separate one-symbol compile negatives. Six new
single-locus mutants for these repairs compiled and reddened the focused oracle, and both privacy clients failed
only at their intended missing export. External trust, immutable transport, durable replay consumption,
independent intent/manifest acquisition, qualification, and human review remain explicit permanent findings.
These runs are component diagnostics, not acquired-source or validation evidence.

A final static SourceAcquisition review found that selective exports of four other private values could evade
the two original privacy clients; four additional one-symbol attacks now name `decodeManifest`,
`decodeExpectedManifest`, `authenticateAndDecode`, and `SourceAcquisitionExpectation`. It also found unselected
acceptance branches for a missing committer, malformed parent identity, missing header/message separator,
parent-after-committer order, expected-manifest trailing bytes, and complete diagnostic-residue removal. Each
now has one production selector and an exact oracle case; the residue-removal subject makes the internally
consistent diagnostic genuinely green so its oracle must prevent a false authority result. Inclusive controls
now pin the commit, expected-manifest byte/entry, replay-set, authority, and revision maxima. Commit-header count
is checked before header slices are allocated, revision is explicitly an opaque protocol identifier rather than
a Git-ref parser, and the streaming-ingress residue names every already-materialized caller input. Static Cabal/
CPP mapping checks are clean, but the clean oracle, all six SourceAcquisition compile-negative clients, six new changed-subject
cases, complete existing SourceAcquisition matrix, integrated dispatcher composition, external acquisition,
qualification, and independent review still require coordinated execution. No validation claim follows from
the implementation or static review.

A fresh reviewer then rejected that qualification surface before execution. The manifest-path control jumps
from the admitted 1,024-byte boundary to 1,029 bytes, so a 1,025-byte widening survives. No case currently
places NUL in an otherwise canonical commit message, uses a two-byte nondigit phase, supplies a correct-width
uppercase digest/object identity, isolates every requested-revision predicate, or covers every identity
display/email/timestamp/timezone and portable-path grammar branch. These are blocking oracle gaps, not optional
hardening: an implementation can admit each malformed value while the current exact-result corpus remains
green. The additional paired negatives and single-locus changed-subject witnesses must be implemented and the
fresh reviewer must re-audit them before any SourceAcquisition matrix is treated as complete.

The rejected SourceAcquisition predicate matrix has now been replaced at source level. Eighty additional
one-locus selectors separately address phase width and ASCII digits; authority nonemptiness, length, and
alphabet; every requested-revision conjunct; text and byte object/digest widths and lowercase-hex alphabets;
wire decimal, signature, and trailing-payload framing; commit emptiness, header framing, message NUL, display,
email, local-part, domain-label, timestamp, and timezone rules; and portable-path alphabets, segment forms,
all twenty-two reserved device names, case/extension variants, and the literal 1,024/1,025-byte boundary. The
oracle now contains the corresponding minimally different controls and exact full diagnostic expectations,
including correct-width malformed identities and adjacent admitted path forms. Static selector/flag/mapping and
whitespace checks completed. A coordinated direct diagnostic then found and repaired two oracle defects: an
empty commit-header block was being normalized away, and malformed fixed-width digest values could hit the
expectation-ingress bound before the intended exact shape-and-mismatch projection. The warning-clean production/
oracle compile and restored clean oracle then exited zero. Sixty-two isolated SourceAcquisition production
selectors compiled and reddened their exact rows; one advertised selector was correctly rejected from this
matrix because its changed locus is in `SourceClosure`, and the rest of the run was discarded when concurrent
`PbBootstrapGrammar` work made that transitive dependency build-red. The complete matrix, all six opacity
clients, Cabal-selected builds, same-harness controls, integrated dispatch, and independent repetition therefore
still require a stable coordinated rerun. These are partial component diagnostics only; they are not
qualification, acquisition, or validation.

A subsequent exact macro-occurrence audit found that two of the 113 SourceAcquisition flag mappings were still
non-atomic despite their unique Cabal names: the signature bypass occupied two conditional-import sites plus
the verifier, and the commit-identity bypass occupied both the validator and the complete grammar definition.
Both now select one Boolean production locus while the real cryptographic verifier and complete identity grammar
remain imported, compiled, and referenced. Static global occurrence counts are one for each repaired selector;
their clean and changed-subject diagnostics remain intentionally pending behind the coordinated SourceClosure
restore and must not be inferred from the source edit.

That exact-occurrence result is not yet a complete residue matrix. The successful parse retains one
diagnostic-authority finding plus eleven separately meaningful refusals for caller-supplied intent/session
custody, absent observer execution, missing key-role separation, strict pre-materialized ingress, absent
dispatcher composition, unintegrated trust anchor and replay state, unobserved authored-root and frozen custody,
and absent oracle qualification. `VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_RESIDUE_REMOVAL_MUTANT` deletes the
entire set at once to make the diagnostic green; only the diagnostic-authority row has its own selector. The
green-making selector is a useful compound challenge but cannot establish that omission of any one other
mandatory row is observed. The eleven rows now each have their own once-only Boolean retention selector and
exact normalized Cabal flag/`-D` mapping while the compound challenge remains separate. Static two-way
reconciliation reports 124 source selectors, 124 distinct source names, and 124 exact mappings with no delta.
The previously absent external positive control for the sole public facade now has its own Haskell client and
Cabal suite beside the six one-symbol opacity attacks. The existing oracle already states the complete ordered
result, but clean compilation, the public-control build, each new changed-subject run, named intended-locus
checks, the complete 124-row matrix, and integrated qualification remain pending behind the coordinated
SourceClosure restore; no runtime result is inferred from this source edit.

The SourceClosure dependency is now stable enough for a fresh clean SourceAcquisition component diagnostic.
An isolated direct Haskell build of production and the independently authored oracle completed under
`-Wall -Wcompat -Werror`, and the exact clean oracle exited zero. The build used the existing local diagnostic
package database and therefore does not establish authenticated toolchain custody. More importantly, the
oracle still has no literal 124-row selector-to-exact-case registry, so this clean result cannot authorize a
mutation inventory or retain any prior production-derived matrix count. The six one-symbol opacity attacks,
public package control, registry integrity, assigned-locus 124-row matrix, same-harness unaffected controls,
integrated Dispatch composition, qualification, and external source acquisition remain open. This run is a
component diagnostic only and does not advance Sprint 0.3.

A subsequent atomic-completeness re-audit has rejected that 124-row SourceAcquisition count rather than freezing
it into the missing registry. The implementation had no independent selectors for multiple envelope, payload,
bundle, field, commit, manifest, expected-manifest, expectation, replay, path-depth, path-segment, inventory,
content-join, and derived-identity requirements; the one expected-entry selector suppressed six distinct joins.
Closed alphabet and wire-tag alternatives were also compound-only, and an attempted empty-header-name selector
was removed after direct execution proved that locus unreachable behind the earlier continuation refusal. The
source now contains 231 unique once-only selectors, including separate missing, unexpected, mode, object,
length, and digest joins while retaining the old compound entry selector only as a supplemental challenge. The
oracle owns a literal 231-row selector-to-exact-case registry plus an independently declared 171-label target
inventory; it rejects duplicate selectors, duplicate exact labels, duplicate or unknown targets, selector target
multiplicity, unreferenced reverse targets, and targets that do not occur exactly once. A warning-as-error direct
compile and the complete clean oracle exited zero after these edits. Cabal now has exact one-to-one manual flags,
`if flag(...)` conditions, and `-D` mappings for all 231 oracle identities; the source, oracle, and all three Cabal
sets reconcile in both directions with no duplicate. The first complete warning-as-error direct matrix was
correctly rejected: 217 rows reddened their exact target, three assigned cases survived, and eleven selector
variants exposed unused-limit or unused-derived-value warnings. None failed at a wrong label or disturbed the
independent oracle control. The overlapping dot/dot-dot/trailing-dot guards, the misassigned field-availability
case, and all eleven warning variants have been repaired; a focused rerun compiled and reddened all fourteen
rejected rows. The subsequent complete direct matrix compiled all 231 distinct changed subjects and reddened
each assigned exact row, with zero survivors, build failures, unchanged or duplicate subjects, wrong targets,
or independent-control failures. Its clean baseline object digest was
`055285749b39ce019255afd0029fab9db9484d91c20bb7e62db4900a20f141ed`. This run used an existing ambient/local
diagnostic package database; it is not an authenticated or network-independent toolchain observation. Static
source/oracle/Cabal reconciliation, the six opacity clients, public package control, post-matrix predicate
audit, integrated dispatcher, and external acquisition remain pending, so this is a component diagnostic only.
Sprint 0.3 remains NOT VALIDATED.

The broader Sprint-0.3 integration audit has also rejected earlier component-green claims. `DispatchOracle`
derives its expected merged result by calling the same production components, the debt and consumer oracles
accept selected finding presence instead of exact ordered results, and the BuildInfo oracle sorts public output
before comparison. `PbBootstrapGrammar` publicly returns a detachable `Right PbBootstrapProof` and exports its
parser, AST, and projections before source acquisition; its oracle drops one problem class, checks only the first
remaining problem, and leaves proof projections unobserved. Existing compiler opacity attacks cover only record
updates or combine several forbidden symbols so selective leaks can survive, while Pb has no opacity client.
SourceClosure, Pb, ComponentPlan, and CompilerSourceGraph also lack reviewed literal pre-allocation/traversal
bounds. These are implementation and oracle defects rather than permanent external-custody residue. Their
public seams must become refusal-only, expectations must be independently literal and exact-order, privacy
attacks must be one-symbol, and every resource predicate needs exact maximum/maximum-plus-one controls before
Sprint 0.3 can be a candidate seam.

A 2026-08-24 read-only re-audit has now made the SourceClosure rejection concrete. Its public module exposes
forty-five export items—153 entities after constructor expansion—and the existing oracle accepts selected
findings, booleans, set-normalized inventories, ignored success payloads, and a wildcard Pb branch rather than
complete ordered results. Twenty-eight of the fifty-six `SnapshotProblem` constructors have no oracle mention.
The eleven current selectors are not an atomic coverage matrix: acquisition, final-index, and executable-mode
selectors each suppress multiple predicates, one debt selector is dead in integrated production, and two
state-root subjects preprocess unchanged on Windows. The implementation also splits, sorts, maps, decodes,
concatenates, traverses directories, and captures process output before applying any closed resource envelope.
The replacement in progress is a one-function raw diagnostic facade over a package-hidden Internal module,
with three permanent input-bound custody/discovery refusals, every Pb diagnostic and all twenty-one Phase-50
runtime residues retained, literal maximum/maximum-plus-one preflights before traversal or allocation, exact
ordered oracle-local expectations, one-locus selectors, fifty-seven one-symbol facade opacity clients, one
package-opacity client, and one public control. No result from the rejected surface is candidate evidence.

The private split also exposes an integration dependency that must remain visible. `PolicyContractOracle`,
`LegacyOracle`, `CompilerSourceGraphOracle`, and `DispatchOracle` currently construct or import SourceClosure
types through the public module. Moving those types to a package-hidden Internal module correctly makes the
external component test unable to compile; adding the source directory to the test would create a second,
unmutated type universe and is prohibited. Those oracles must migrate to the eventual raw refusal facades of
their owning public components. Until that work lands, the aggregate component suite is an explicit compile
blocker, not a reason to re-expose SourceClosure internals or report a partial green.

A parallel read-only CompilerSourceGraph audit has rejected its current boundary before another matrix run.
The public module exposes fifty-four items—107 entities after constructor expansion—and its sole combined
privacy client can fail for record-update syntax even if unrelated private symbols leak. The oracle constructs
`SourceSnapshot` values with production constructors and identity helpers, projects the returned production
graph, sorts some observations, and accepts many predicates by `any`, `elem`, booleans, or partial pattern
matches. It mentions only eleven of thirty-three `CompilerGraphProblem` constructors; `CompilerLoadFailed` has
no production site beyond its declaration. Eight broad selectors do not isolate the version, path, duplicate,
order, object-format, identity, subject-inventory, assignment, session, produced-subject, digest, module,
dependency, renamed-tree, compiler-option, FFI, home-reference, external-unit, content-edge, required-fact, or
residue-join predicates. There is no literal input/GHC-result envelope before whole-inventory concatenation,
sorting and maps, generic renamed-tree traversal, or the content-effect-by-tracked-target cross product. A
hard integration mismatch also makes the acquired path unreachable: it reuses ComponentPlan's raw diagnostic
ceilings of 128 snapshot entries and 64 assignments, while the current index contains 2,337 paths including 682
`.hs` paths, and it accepts only one component/configuration. It therefore refuses the repository before GHC
regardless of compiler correctness; widening a fixture parser cannot substitute for a separately bounded,
authenticated elaborated multi-component path. The blanket compiler-fact requirement is also unsatisfiable:
the tracked Haskell inventory deliberately contains compile-negative opacity clients that must fail to rename or
typecheck, while default Cabal elaboration excludes those flag-gated components. A closed Haskell subject-role/
expected-outcome registry must be two-way complete against the acquired `.hs` inventory and bind every expected
refusal to its authenticated configuration, exact structured diagnostic, and minimally different compiling
control; neither paths, Markdown, nor `buildable` flags may invent that role. A
one-function refusal facade, package-hidden acquired/compiler graph, bounded compiler execution/result traversal,
complete exact-result oracle, atomic selectors, and one-symbol opacity corpus are required. Implementation had
not begun at that audit checkpoint, and every earlier graph-green claim remains superseded.

The completed read-only graph audit also proved that the current discharge branch is unreachable rather than
merely under-covered. Every nonempty inventory receives eight `CompilerRequiredFactUnestablished` problems
because the implementation can derive evidence for only four of twelve facts; an empty inventory receives its
own refusal plus all twelve missing facts. `compilerGraphDischargesResidue` therefore cannot be true and the
typed consumer residue cannot be removed. Compilation also ignores `snapshotRoot`, so relative targets are
resolved through ambient process state while `GHC.Paths.libdir`, package databases, interfaces, and dependencies
remain unauthenticated live inputs. The renamed-tree `Data.Data` walk is not a call graph, control-flow proof,
indirect-call closure, effect proof, or tracked-content value-flow proof. The replacement must use a separate
repository-scale acquired path, an authenticated multi-configuration elaboration, and a two-way-complete Haskell
`SubjectRole`/`ExpectedCompilerOutcome` registry covering normal, opacity-negative, and mutation runs. Every
expected compiler refusal must bind an exact structured diagnostic and minimally different compiling control.
The raw facade remains permanently refusing; no selector may disable a compiler safety guard and then execute an
untrusted plugin, Template Haskell, or preprocessor fixture. Implementation of that refusal-only boundary is now
the next bounded repair, and no compiler execution is authorized by it.

The bounded CompilerSourceGraph refusal rewrite now replaces that rejected surface. The public module exports
only `compilerSourceGraphDiagnostic :: Text -> [(FilePath, Text, Text, ByteString)] -> IO CheckResult`.
Caller-authored inventory can produce diagnostics only, and the function never invokes GHC. Package-hidden
`CompilerSourceGraph.Internal` consumes the package-hidden SourceClosure and SourceConsumerGraph seams without
re-exposing their constructors. The raw path preflights 64 identity bytes, 128 entries, 1,024 path bytes, 64
segments, 255 segment bytes, six mode bytes, 64 object-identity bytes, 65,536 bytes per blob, 262,144 aggregate
blob bytes, 64 Haskell subjects, and four Cabal entries before later traversal. The distinct acquired path
admits up to 16,384 entries before even the bounded source-consumer diagnostic. It never reuses the small raw
fixture ceiling. Eight raw findings and five acquired findings unconditionally refuse source custody, subject-
outcome authority, elaboration, toolchain custody, supervised execution, semantic closure, qualification, or
the applicable diagnostic authority. No success constructor or discharge branch crosses the facade.

The separately authored oracle now states forty-four exact ordered full-result rows. It covers all thirty-three
raw problem constructors, exact-maximum and maximum-plus-one controls for all eleven resource predicates, and a
non-ASCII decimal path negative. A forty-one-row executable Haskell intent registry names the exact oracle row
owned by every selector without parsing production source, Cabal, or Markdown. Static reconciliation finds
forty-one once-only production selectors, forty-one distinct manual Cabal flags, forty-one exact `-D` mappings,
and the same forty-one oracle intents. Every selector changes the preprocessed production subject. Six
one-symbol public-facade attacks fail at their exact missing export, the package-level Internal attack fails as
a hidden module, and the sole-facade public control builds and runs. One Cabal-selected identity-alphabet mutant
built and reddened its exact malformed-identity row; the restored default library build and clean focused oracle
then exited zero. The other forty changed-subject executions, same-harness unaffected controls, integrated
dispatcher run, authenticated acquired inputs, qualified external observer, and independent human review remain
absent. These are bounded component diagnostics only, not compiler execution, qualification, or validation.

The acquired-path follow-up closes that mutation-inventory gap without widening the one-function package facade.
The repository-scale 16,384-entry ceiling and each of the five mandatory subject-role, elaboration, toolchain,
supervised-execution, and semantic-closure findings now have one once-only selector. A separate direct-source
oracle compiles with the exact production source universe and pins three complete acquired results: a two-entry
source-consumer composition, the exact 16,384-entry boundary, and the 16,385th-entry refusal before consumer
construction. Its test-local representation-matched opaque fixture is explicitly unauthenticated and cannot
enter the packaged production API. The acquired six-row literal registry and raw forty-one-row registry form a
47-selector closed union. Exact identity reconciliation finds the same 47 once-only names in production CPP,
the two oracle registries, Cabal manual flags, Cabal `-D` mappings, and `if flag(...)` conditions. The combined
hardware-free direct-source matrix compiled all 47 isolated subjects: all 47 reddened their assigned exact row,
with zero survivors, control failures, wrong-locus rows, or unresolved mappings. After clean restoration, the
Cabal-built package matched the raw focused oracle; all six one-symbol public-facade attacks failed for their
exact missing exports, the Internal attack failed for the hidden-module boundary, and the public client compiled.
These remain component diagnostics. The parent Dispatch gate still must exercise the genuine package-hidden
acquired token, and authenticated source custody, subject/outcome registry, multi-run elaboration, toolchain,
supervised compiler execution, semantic closure, qualification, independent custody, and human review remain
absent. CompilerSourceGraph is NOT VALIDATED.

A fresh SourceAcquisition post-matrix line audit has superseded any completeness reading of its 231-row
checkpoint. The provisional source now has 835 once-only selectors, a fail-closed 128-problem result bound, and
exact 128/129 replay-entry cases; its strict clean oracle exits zero. The first 503-row expansion attempt is
discarded because its temporary harness omitted dependency interfaces and all 503 subjects build-failed. In the
replacement run, 497 assigned rows reddened; one genuine no-op/unreachable design and three invalid type-
constructor projections were removed, while two warning-as-error dead-helper cases were repaired and then
reddened. The remaining observation, mandatory-residue, decoder/framing, digest, association, aggregate, and
serializer expansion checkpoints reddened after two real survivors were repaired. A fresh production-line pass
now reports no known uncovered predicate/result/observation/problem/limit/serializer locus, but that is not a
completeness witness. The independently literal 835-row registry, exact Cabal reconciliation, paired product
controls, full frozen-source matrix, opacity rerun, and post-matrix adversarial audit remain open. The earlier
231-row matrix and every discarded harness run are superseded diagnostics only.

A 2026-08-24 independent selector-authority audit also rejected production-derived matrix enumeration as a
completeness witness. A driver that discovers its work only from production CPP can silently omit the same
missing selector from both its enumeration and reported total. SourceAcquisition replaced its production-derived
124-row baseline with the literal 231-row checkpoint, but the fresh audit above has superseded that count and its
matrix as a completeness claim. SourceClosure has separately added a literal 124-row registry, but its broader post-matrix audit remains
open. `PbBootstrapGrammar` now has an oracle-owned literal 78-row selector-to-exact-case registry with duplicate
and unknown-target rejection, independent fixture/digest controls, and exact two-way source/oracle/Cabal
reconciliation. Its first complete strict matrix correctly rejected four warning-as-error subjects and reddened
the other seventy-four assigned rows. After the four dead-code witnesses were repaired, all seventy-eight
changed binaries reddened their assigned exact rows with no survivor, build failure, unchanged binary, or
wrong-locus result. That rerun is itself rejected as evidence because an unrelated Cabal selector region changed
during execution and the source-set stability check refused. The 78-row baseline also leaves compound proof,
observation, problem-mapping, parser, control-flow, and result-retention predicates without atomic selectors;
expansion and a post-matrix audit remain open. Five expansion checkpoints add twenty-six atomic subject/resource
projections, twelve preflight-observation projections, thirty proof-member projections, twenty-seven private
problem-to-finding mappings, twenty-three result-assembly/finding projections, and nineteen ordered structured-
projection and renderer-field selectors. The provisional 215-row
source, literal oracle registry, Cabal flag, condition, and `-D` inventories reconcile exactly in both directions
without duplicates. A strict clean oracle exited zero. All 118 new changed binaries reddened their assigned
exact result with no survivor, build failure, unchanged binary, wrong-locus result, or source/oracle change
during their focused runs. The nineteen newest rows initially reused a path-limit exact-result check as an
allegedly unaffected control; two ordering mutants correctly changed that result, so that receipt was rejected
rather than counted. A literal selector-to-product-control registry now assigns those nineteen rows an
independent empty-inventory finding-projection control. In the replacement frozen-source run, all nineteen
distinct changed binaries reddened their assigned exact result and all nineteen product controls stayed green,
with no build, unchanged-binary, resolution, or source-stability failure. Thus 137 expansion rows have assigned
red evidence. The single literal selector registry now assigns a product control to all 215 rows as a mandatory
third field: the nineteen exercised structured-projection rows and the check-name row use an exact independent
empty-inventory finding projection, while every other row uses the exact diagnostic name as its unrelated
product control. Registry cardinality and clean strict compilation are green, but the 196 newly assigned
controls have not yet run against their changed binaries and therefore are not evidence. This is a bounded
component diagnostic; further claim/control-flow field projections, parser, semantic proof, the complete
changed-binary control matrix, and the complete post-matrix predicate audit remain open.
SourceConsumerGraph still has only the rejected 91-row baseline.
CompilerComponentPlan has expanded beyond its
rejected 81/83-row baselines to a literal 232-row registry; its complete rerun and post-matrix audit are still in
progress. Each unfinished seam requires oracle-local literal cardinality, duplicate rejection, exactly-one
target-case binding, two-way source/oracle/Cabal reconciliation, and an unaffected control before a matrix count
is admissible. CompilerElaboratedPlan's 114-row registry and earlier rerun are likewise subject to a final
comprehensive predicate audit. SourceDebt's 55-row and CompilerSourceGraph's combined 47-row raw/acquired
registries meet only this narrow structural requirement; their separately recorded completeness, integration,
qualification, external execution, and custody residue remains. This audit is not validation and does not
advance Sprint 0.3.

The current Git index also still names fifteen condemned legacy `pb/**` paths, while the intended single
`pb/__main__.py` bootstrap is present only in the unstaged worktree. An agent may neither stage nor commit that
transition. Consequently no acquired tracked-tree diagnostic can establish the required one-file Pb inventory
on the current index, and a production literal fed back into both Pb and SourceClosure oracles cannot substitute
for binding the independently observed tracked bootstrap bytes. This remains explicit integration residue until
the human applies the source transition and the scoped oracle observes the resulting exact tracked blob.

## Sprint 0.4: Haskell documentation and plan-contract checker ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Documentation.hs`, `src/validation-kernel/Amoebius/Validation/PhaseContract.hs`, internal `src/validation-kernel/Amoebius/Validation/PhaseIdentity.hs`, `src/validation-kernel/Amoebius/Validation/PhaseSemanticContract.hs`, `src/validation-kernel/Amoebius/Validation/PhaseSemanticJoin.hs`, and `src/validation-kernel/Amoebius/Validation/ResourceProvisionContract.hs`
**Blocked by**: Sprint 0.3
**Independent Validation**: Complete structural component corpora are accepted and minimally different dependency, inventory, raw-status, retired-path, wildcard, fence, comment, and line-wrap defects are refused at exact loci. The Haskell prose-budget oracle independently states an exact 50-word sentence in single-line and hard-wrapped forms, a seven-sentence paragraph, and table/fence exemptions. Physical-line and measurement-omission production mutants must red those exact controls. The current documentation selector registry has a complete nine-row changed-subject component bracket. PhaseContract now has a literal thirty-two-selector and thirty-two-case registry whose full changed-subject dependency discovery is running; package opacity, qualification, and semantic policy/prose correspondence remain open.
**Oracle**: `test/validation-kernel/DocumentationOracle.hs`, `test/validation-kernel/PhaseContractOracle.hs`, and `test/validation-kernel/PhaseSemanticContractOracle.hs`; separately authored component diagnostics whose independent review is consolidated into the Phase-0 gate, not requested per sprint.
**Legacy IDs**: `LTD-VAL-001`, `LTD-VAL-002`
**Docs to update**: `documents/documentation_standards.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`

### Objective

Replace Python and token-presence checks with typed structural validation whose negative corpus exercises only
machine-decidable document structure. Executable cross-cutting policy lives in `PolicyContract`; prose
correspondence remains human review.

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

The checkers and component oracles exist but are not qualified or independently human-reviewed. The
documentation checker separately pins the 196-path governed inventory/count digest and rejects retired tracked
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
through the complete component runner. The latest completed aggregate executed all eighteen named component
oracles; sixteen met their diagnostic expectations, `DispatchOracle` exposed a stale classifier, and
`DocumentationOracle` refused the deliberately stale manifest. A provisional post-schema measurement observed
1,583 over-target sentences and 655 over-target paragraphs, with all 1,728 typed semantic slots represented by
exact-prefix unresolved gate cells, 385 resource-contract gaps, no reviewed semantic payload, and the permanent diagnostic-only
join refusals. Subsequent semantic-contract and documentation hardening invalidated those exact bytes. No current
finding-manifest digest is frozen, and neither the provisional counts nor the eventual digest are qualification
evidence. `python3 tools/doc_lint.py` remains
condemned non-Haskell source and
cannot produce acceptance evidence. The 2026-08-23 semantic audit found that the lexical gate-cell count
materially understates the contract debt. All 270 sprint sections now have the exact mandatory field sequence and
closed immediate-blocker grammar; two independent read-only audits found no structural schema or blocker-edge
mismatch in the 262 Phase-1-through-95 sprint blocks. Those repairs establish structure only. The typed
96-phase semantic registry and its Markdown join remain under adversarial hardening, and every `UNRESOLVED`,
`MISSING`, absent reviewed value, or permanent diagnostic-only refusal must be resolved only from its owning phase
contract. A read-only design audit
has now frozen the exact 96 ordinal/capability/file/title identities, substrate/lane/register projections,
execution stages, immediate predecessors, and independent legacy-owner reverse map. It requires a canonical
no-caller-input Haskell registry with explicit `ContractGap` versus reviewed slots; natural-language Claim,
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
independent literal Markdown path inventory. Adversarial review found substring, indentation, tracker-header,
delimiter, raw-HTML, container-prefix, comment-splice, and path-position spoof routes. Production now requires
the exact unresolved prefix, exact tracker header, an immediate canonical delimiter, and structural rows outside
code or raw-HTML blocks. List- or blockquote-prefixed block openers make the remaining document opaque rather
than supplying structural values. Comment masking is linear and preserves a non-whitespace splice sentinel;
tracker preflight is linear and saturates at the 129th row. The eight privacy claims are now eight one-symbol
compile negatives rather than one masked multi-import failure. Their individual compiler failures and a clean
expanded container, alternating-block, delimiter, dense-comment, and repeated-header oracle run are component
diagnostics only. Thirteen isolated semantic-join production mutations then compiled and reddened their named
oracle cases. A subsequent independent review nevertheless found a real unselected attack: deleting a top-level
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
frame role. A final static review found all selectors at one production locus and the current 96 Gate/tracker
owners structurally compatible with the stricter grammar; it deliberately made no compilation or execution
claim. All eighteen selectors now have distinct Cabal declarations and CPP mappings, and `cabal check` accepts
that static package description. No clean or isolated changed-subject run has occurred on the stricter parser,
so the prior clean and mutation runs remain superseded diagnostics rather than qualification. A coordinated
clean rerun, all affected isolated mutations, qualification, independent reviewer custody, prose
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
post-matrix audit, authenticated source/toolchain inputs, independent custody, and human correspondence review
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
source acquisition. The structure, inventory, owner, and worktree refusals are distinct production decisions.
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

Reachability review immediately rejected three of those mandatory-retention alternatives. A policy-owner
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
assigned oracle result, binary witness, Cabal reconciliation, completeness claim, or validation authority.

On 2026-08-24 the Finite Resource Execution Authority Protocol joined the governed engineering corpus as the
196th path. The production and independent inventories now pin count 196 and sorted-path digest
`97964f2fc3e6bf6c98159089f6f2f99683f3ffaab7834504b2a9647d5927d4df`, and source closure names the path
explicitly. This is documentation-path registration only: the protocol states target shapes, while Phases 29,
32, 51, and 52–54 retain the compile-fail, pure-boundary, and live-mechanism work. The prose observations and
finding-manifest digest must be remeasured after this edit, and no sprint or phase status changes.

The permitted serial `cabal test validation-kernel-component -j1` diagnostic was attempted after that
registration. Dependency solving and compilation stayed single-worker, but the production
`Documentation.Internal` module failed before the oracle ran because six referenced header-finding helpers are
absent: title, purpose, read-this, details, order, and metadata-block. The exact same unresolved references are
present in `HEAD`; this doctrine change touches only the inventory count and digest in that module. The run is
therefore a build refusal, not a documentation result, and the prose observations and finding-manifest digest
remain deliberately unfrozen until the owning Sprint-0.4 implementation repairs and revalidates that seam.
The separate package-description check exited zero with only its already-declared distribution-metadata
warnings; it does not substitute for the component diagnostic.

## Sprint 0.5: Gate-kernel qualification and spoof corpus ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Gate.hs`, `test/validation-kernel/QualificationOracle.hs`
**Blocked by**: Sprint 0.4
**Independent Validation**: Inject every mandatory sabotage into the exact harness build, retain raw refusals, then prove the same build runs the clean subject; the qualifier cannot accept its own summary.
**Oracle**: `test/validation-kernel/QualificationOracle.hs`; component diagnostic exists, and its independent review is consolidated into the Phase-0 gate rather than requested as a sprint confirmation.
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
changed-subject observation only: the aggregate runner, applied source/binary witnesses, and independent custody
are still pending. The development-plan and spoof-resistance standards now also forbid pre-authority adapters
from exporting conventional success branches, optional residue, arbitrary-result folds, or detachable
observations, and require oracle-local fixture types, literal limits, and exact full boundary projections. This
closes the documentation ambiguity exposed by the acquisition and compiler adapter reviews but does not qualify
their implementations. The
opaque execution-derived report and qualifying supervisor remain absent: they must apply each changed
production subject, observe the exact binary and refusal locus, and then run the unmodified controls with the
same harness identity. Execute and retain those changed-subject witnesses once Sprint 0.4 is
implementation-ready. Independent oracle review stays phase-gate residue.

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

## Sprint 0.6: Candidate evidence and human approval boundary ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Evidence.hs`, `src/validation-kernel/Amoebius/Validation/Approval.hs`
**Blocked by**: Sprint 0.5
**Independent Validation**: A dispatcher-acquired bundle is the positive control; caller-invented green rows and every absent, wrong-key, stale-source, stale-contract, stale-harness, replayed, automation-authored, self-generated-root, or same-change-root pair are negatives; the approval path remains UNVERIFIED until the external trust root and durable replay observer exist.
**Oracle**: `test/validation-kernel/EvidenceOracle.hs` and `test/validation-kernel/ApprovalOracle.hs`; component diagnostics exist, but consolidated Phase-0 gate review and key custody by the human trust-root owner are absent; no sprint-level confirmation is requested.
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

Connect the observed evidence writer to the qualified dispatcher and establish the external approval and
key-custody mechanism without a test-key promotion path after Sprint 0.5 qualifies the harness. The current
public evidence constructor is permanently refused and the approval verifier ends in
`ApprovalExternalAnchorUnavailable`, so neither exposes a present promotion path. The same 2026-08-23 API
audit found that their future schemas are still incomplete: evidence lacks closed typed command, authenticated
toolchain, substrate/lane/architecture, run identity, cleanup, and status-projection fields; approval binds no
exact post-promotion status-only projection digest or permitted status-field set; and the candidate writer has
not been qualified for exclusive atomic no-follow publication and directory-replacement races. These are
implementation blockers, not `UNVERIFIED` values that a candidate may carry. Human custody review stays
phase-gate residue.

The 2026-08-24 API and selector audit makes those blockers stricter. `Evidence` still publicly exports the
candidate/provenance model, every projection, serialization and digest operation, a conventional
`Either [Finding] CandidateEvidence` constructor with a syntactically present `Right`, and a filesystem writer;
its unconditional acquisition finding merely makes that success branch unreachable. `Approval` likewise
exports all trust-root, binding, approval, and error constructors plus `verifyApproval :: ... -> Either
ApprovalError ()`; its final unconditional external-anchor failure does not make the conventional success API
admissible. Both violate the pre-authority refusal-only boundary. Neither module has any changed-production
selector or oracle-owned registry. Their current oracles use production record constructors and accept selected
finding/error presence; they do not bind complete ordered refusal results, bounded input/output envelopes,
serializer domain/framing/field contributions, every validation conjunct and error mapping, or an applied atomic
publication witness. The candidate and approval models must move behind package-hidden implementations; public
facades must remain bounded, standard-value, and refusal-only until a real dispatcher-owned evidence writer and
external trust/replay authority exist. Exact serializer and Ed25519 vectors, every field and ordering decision,
status-only projection digest/permitted-field set, exclusive no-follow publication, replay consumption, and
all error/result mappings require literal atomic registries and changed-subject matrices. No current Evidence or
Approval diagnostic is Sprint-0.6 candidate evidence.

## Sprint 0.7: Review all numbered phase contracts ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `DEVELOPMENT_PLAN/phase_[0-9][0-9]_*.md`
**Blocked by**: Sprint 0.6
**Independent Validation**: Every phase has one fixed 18-row table, checked only for structure and explicit `UNRESOLVED` state. Separately reviewed Haskell phase contracts pin subjects, oracles, controls, mutants, observers, typed legacy bindings, predecessors, and residue. Human review owns correspondence with the table prose; no cell text supplies semantic authority. Any structural `UNRESOLVED` row or missing Haskell binding refuses Phase 0 at its own locus.
**Oracle**: `test/validation-kernel/PhaseContractOracle.hs`; component diagnostic exists, and the consolidated Phase-0 gate review covers every oracle boundary without separate sprint confirmations.
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

Resolve the 1,728 exact-prefix `UNRESOLVED` gate cells across all 96 contracts and replace each explicit
`UNRESOLVED` sprint binding with one reviewed semantic value from its owning phase; the mechanical sprint
envelopes and immediate blocker edges are now complete. Complete the independent phase-by-phase review once
Sprint 0.6 is implementation-ready. The former 92 generic predecessor placeholders now specify typed inputs,
but their receipts remain runtime evidence that cannot exist before the numerical predecessor is promoted.
Every affected phase remains shut meanwhile.

## Sprint 0.8: Integrated Phase-0 candidate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Dispatch.hs`, `app/amoebius/Main.hs`
**Blocked by**: Sprint 0.7
**Independent Validation**: From an empty generated tree, the exact absolute source-built Haskell executable is invoked directly with `validate phase 00`; it qualifies the harness, runs the clean corpus, resolves every Phase-0-owned typed Haskell legacy binding to zero for the first time, emits explicit candidate evidence, and cannot mutate status. `pb` is unavailable as validation transport. If an owning gate has retired an ID by this point, its qualified owner-domain reintroduction negative remains compiled while its explanation is absent from the active-only Markdown register. Markdown register contents are unavailable to the legacy semantic verdict.
**Oracle**: `test/validation-kernel/Main.hs` currently composes component diagnostics only; a separate integration oracle and the single consolidated Phase-0 human validation-authority review remain absent.
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
  Haskell owns lifecycle, dispatch, owner-analyzer closure, and required reintroduction-case identities; the
  owning analyzer supplies a qualified negative before any future retirement
- [Migration doctrine](../documents/engineering/migration_doctrine.md) — retirement keeps the qualified negative
  and removes only the explanation after the owning gate is promoted
- [Documentation standards](../documents/documentation_standards.md)
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
- [No-cluster conformance harness](../documents/engineering/conformance_harness_doctrine.md)
