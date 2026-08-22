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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, documents/documentation_standards.md
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

This phase is active only for the documentation, tracked-source, and validation-authority reset. Every prior
pass, Done marker, seal, receipt, attestation, hash, completion statement, or implementation result is
permanently invalid as current validation evidence. Existing machinery is an **Observed footprint / Known
partial**. No later implementation or promotion gate may open until a qualified Phase-0 candidate is reviewed
and the human validation authority personally promotes this phase.

---

## Phase Summary

Phase 0 makes the repository say one thing in one place and installs the mechanism that can refuse future
drift. The reset fixes these target decisions without claiming they are validated: behavioural source is Haskell; `pb/**` is the only non-Haskell
source exception and only bootstraps/execs Haskell; every reproducible non-Haskell artifact is generated lazily
beneath `.build/**`; the in-cluster OCI service is exclusively Distribution `registry:2`; one
active legacy register replaces every archive; and every phase is NOT VALIDATED until human promotion in
strict numerical order.

An **Observed footprint / Known partial** of the target Haskell validation kernel now exists beneath
`src/validation-kernel/Amoebius/Validation/**`. It includes source closure, legacy-register, documentation,
phase-contract, qualification-report, candidate-evidence, approval-verification, and dispatch modules. The
component-oracle footprint is beneath `test/validation-kernel/**`. Current `pb/**` still parses public verbs,
contains broader bootstrap/admin/test/check behavior, and exposes no conforming opaque validation handoff.
All 15 current paths are therefore frozen as `LTD-SRC-008`: token scanning cannot prove the absence of hidden
Python behavior, so Phase 0 must close and externally observe the exact minimal-platform-discrimination,
contained-toolchain-establishment, source-bound-build, opaque-exec boundary before any validation handoff is
eligible. The general classifier also lacks a semantic parser/consumer/effect graph for disguised source, and
its Git workspace check does not yet reject `assume-unchanged`/`skip-worktree` flags or independently compare
every tracked worktree byte and mode with the index.

A 2026-08-22 supporting `cabal build lib:validation-kernel` diagnostic and
`cabal test validation-kernel-component` component diagnostic completed successfully. Those observations
establish only compilation and component behaviour; they are not harness qualification, independent human
review, clean-room observation, a Phase-0 candidate, or validation. The dispatcher intentionally refuses a
candidate because the fixed sabotage corpus has not been executed against its exact build, independent human
review and key custody are absent, no external clean-room observer is connected, and the evidence writer is
not integrated. Its candidate schema also lacks closed typed command, toolchain, substrate, run-identity, and
cleanup fields, and no reviewed binding connects the repository's Git object-format identity to the required
SHA-256 evidence provenance. The current worktree is also dirty, so clean source-snapshot acquisition must refuse. In the
current corpus, 93 phase contracts still contain 1,290 `UNRESOLVED` gate cells and 92 `MISSING`
predecessor cells: 1,382 fail-closed cells in total. Phase 0 therefore
remains Active — NOT VALIDATED, and Phase 1 remains shut.

**Phase scope:** one cohesive claim — the governed corpus conforms to the single-source policies, the source
snapshot is completely partitioned with every violation either owned by Phase 0 or represented by one active
later-phase legacy row, and the Haskell validation kernel rejects the fixed spoof corpus before producing a
Phase-0 candidate. It splits if product or live-infrastructure behaviour is required.
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
| `Claim` | The governed corpus has one structural owner/link surface; all current statuses are explicitly NOT VALIDATED; the executable cross-cutting decisions live in one reviewed Haskell `PolicyContract`; every tracked path is classified exactly once; every present source-boundary violation is matched bijectively to one active later-phase legacy row; no Phase-0-owned source-policy or validation-integrity violation remains; and the qualified Haskell kernel refuses every specified spoof. Natural-language agreement with `PolicyContract` is a human-review obligation, never a machine-parsed verdict. Phase 0 does not claim that later-owned source migrations, DSL semantics, or runtime behaviour are complete. |
| `Subject` | Observed production entry points beneath `src/validation-kernel/Amoebius/Validation/**`: `Dispatch.validatePhase`, `Documentation.checkCorpus`, `PhaseContract.checkPhaseContracts`, `SourceClosure.classifySnapshot`, `Legacy.legacyCheck`, `Gate.checkQualificationReport`, `Evidence.candidateFromChecks`, and `Approval.verifyApproval`. This footprint is unqualified. The planned `PolicyContract` and its independent oracle are not integrated; evidence and approval are deliberately refusal-only; all current `pb/**` is Phase-0 debt, not a validation subject. |
| `Command` | Target contract: `pb validate phase 00`. It is not currently implemented by a conforming public `pb` handoff. The final `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged; the Haskell binary owns discovery, observations, schema checks, and candidate verdict. |
| `Oracle` | Separately authored component modules exist under `test/validation-kernel/`: `DocumentationOracle.hs`, `PhaseContractOracle.hs`, `SourceClosureOracle.hs`, `LegacyOracle.hs`, `QualificationOracle.hs`, `EvidenceOracle.hs`, and `ApprovalOracle.hs`. A separate `PolicyContractOracle.hs` and integration oracle remain required. All explicitly disclaim independent human review and phase validation; reviewer assignment and custody remain absent and block validation. |
| `Positive controls` | The complete governed path/link/metadata graph and tracked source snapshot, plus structural parser corpora that are explicitly incapable of becoming candidates. Expected governed-path manifest, phase count, status projection, canonical legacy ID inventory, typed provider choice, complete source partition, Phase-0-owned zero set, and exact frozen path/mode/blob fingerprint for every later-owned source family are stated in Haskell and independently reviewed. Human review separately compares the prose diff with the typed `PolicyContract`. |
| `Paired negatives` | Minimally different pairs cover a missing/unexpected governed path, malformed metadata, dangling/backlink-missing link, deleted canonical legacy ID, changed or added path inside an open source family, a changed typed registry provider, non-Haskell behavioural source, disguised executable/shebang, widened or hidden `pb` behavior, missing `NOT VALIDATED`, malformed/missing gate row, forward dependency, empty discovery, and generated output in an authored root; each pins code and locus. A prose keyword decoy is the paired negative proving prose cannot affect a behavioral verdict. |
| `Mutants` | Required changed-production-subject operators weaken source classification, skip one governed document, accept an empty gate table, treat evidence as approval, ignore a legacy row, or accept a second registry. Each records the applied Haskell-source change and must redden only its named oracle row while unaffected controls stay green. |
| `Discovery` | The Haskell kernel enumerates all tracked paths and all governed Markdown at run time and joins each in both directions to independently derived expectations. Zero files, a missing root, an unclassified path, a duplicate path, or an unexpected governed file refuses the run. |
| `Challenge` | Pure claim: a live nonce is inapplicable. Qualification instead selects run-local sabotage cases after the clean snapshot is fixed; the human reviewer must approve this substitution. |
| `Observer` | The oracle independently reads raw snapshot bytes, modes, shebangs, path inventory, metadata fields, headings, links, anchors, dependencies, status fields, and fixed gate-table shape rather than a compliance summary emitted by the classifier. It never interprets natural-language policy as a verdict. A missing or partial read fails closed. |
| `Authority/bypass` | Source-policy bypass probes cover extensionless files, misleading extensions, executable bits, shebangs, symlinks, ignored inputs, generated copies, widened `pb` behavior, and a policy-looking prose decoy that must have no effect. Only the typed Haskell contract and structured source/config observations govern behavior. Human approval verification rejects absent, automation-authored, wrong-key, wrong-source, stale-contract, and replayed receipts. |
| `Freshness` | The candidate uses a fresh snapshot and run root with all generated/state roots absent; prior evidence, cached discovery, ignored inputs, and copied status are unusable. Source and contract digests are provenance only. |
| `Qualification` | Before the clean run, the same Haskell harness must reject constant success, no-op subject, wrong output, empty discovery, missing subject/oracle, skipped/no-op mutant, wrong-locus failure, stale evidence, self-observer, authority bypass, residue, and smuggled generated/legacy input. |
| `Cleanroom` | Run from the tracked snapshot with `.build/**`, `.data/**`, `.test_data/**`, source-adjacent caches, and condemned legacy copies absent. All compiler output, synthetic corpora, observations, and raw candidate evidence are generated beneath one `.build/runs/phase-00/**` run root; the tracked tree remains unchanged. The current dirty worktree is ineligible. |
| `Legacy closure` | `LTD-SRC-000`, `LTD-SRC-008`, and `LTD-VAL-001` through `LTD-VAL-004` must satisfy integrated Haskell closure predicates and reintroduction negatives. Closure requires the exact canonical ID inventory, complete source partition, zero unregistered or Phase-0-owned findings, frozen path/mode/blob fingerprints for later-owned source families, and an externally observed ensure/build/identity-argv/exec-only `pb` path. Predicate-shaped Markdown cannot close a row. |
| `Predecessor` | `genesis`; there is no prior numbered phase. The human approval trust root predates and is outside the candidate. |
| `Residue` | `UNVERIFIED`: the `PolicyContract` implementation/oracle and human prose-correspondence review; the `LTD-SRC-008` Python-boundary closure; a semantic parser/consumer/effect graph that detects disguised behavioral content in otherwise admitted non-source files; rejection of Git `assume-unchanged`/`skip-worktree` flags plus independent byte/mode comparison of every tracked worktree path; all product/DSL/runtime semantics; semantic phase-contract joins; per-ID legacy dispatch; execution of the fixed qualification corpus against the exact integrated harness; independent reviewer and key custody; authenticated Git/tool acquisition; external clean-room observation; candidate-evidence integration; a closed typed evidence schema for exact command, toolchain, substrate/lane/architecture, run identity, and cleanup; a reviewed binding between Git object-format identity and SHA-256 evidence provenance; 1,290 unresolved-marker cells plus 92 absent-predecessor cells across 93 later contracts; external approval operation; and every tracked-source migration owned by a later phase. |
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

## Sprints

## Sprint 0.1: One documentary policy surface 🔄

**Status**: Active — NOT VALIDATED
**Implementation**: `AGENTS.md`, `CLAUDE.md`, `README.md`, `documents/**/*.md`, and `DEVELOPMENT_PLAN/**/*.md`
**Blocked by**: `genesis`
**Independent Validation**: A structurally conforming corpus and typed `PolicyContract` are the positive controls; a changed provider constructor is the paired negative; an applied owner-map mutant reddens its named row; prose correspondence and later implementation remain explicit residue for human review.
**Oracle**: `test/validation-kernel/DocumentationOracle.hs` plus planned `PolicyContractOracle.hs`; component diagnostics are not human review and the policy oracle is not integrated.
**Legacy IDs**: `LTD-VAL-002`, `LTD-VAL-003`, `LTD-VAL-004`
**Docs to update**: all governed documentation owners touched by the reset

### Objective

Make the Haskell-only source boundary, `pb` exception, lazy generation, `registry:2`, single active legacy
register, validation reset, strict numerical order, pre-hardware barrier, and human-only promotion agree
everywhere.

### Deliverables

- One canonical statement and backlinks for each cross-cutting decision.
- Zero active references to the eliminated archive.
- One closed Haskell registry-provider constructor selecting Distribution `registry:2`; human review confirms
  that the canonical service-capability prose rejects every alternate provider.
- Phase 0 Active — NOT VALIDATED; Phases 1–95 Blocked — NOT VALIDATED.

### Validation

Run the qualified Haskell structural oracle over the complete path/metadata/link/status graph and its paired
single-defect mutations. Separately compare the prose diff to the typed Haskell `PolicyContract`; automation
must prove that a keyword-only prose decoy cannot change a behavioral verdict.

### Remaining Work

Qualify and independently review the observed Haskell oracle, resolve every corpus inconsistency it discovers,
and obtain human acceptance of this sprint within the eventual Phase-0 candidate.

## Sprint 0.2: One active legacy register ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`, `src/validation-kernel/Amoebius/Validation/Legacy.hs`
**Blocked by**: Sprint 0.1
**Independent Validation**: Haskell discovery proves one active register, the exact frozen ID inventory, stable unique IDs, one owner per row, a separately implemented Haskell closure binding for every ID, no closed rows, and zero archive aliases or inbound references; predicate-shaped Markdown is an explicit negative.
**Oracle**: `test/validation-kernel/LegacyOracle.hs`; component diagnostic exists, but independent human review is absent.
**Legacy IDs**: `LTD-SRC-000`, `LTD-SRC-008`
**Docs to update**: `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `documents/engineering/migration_doctrine.md`

### Objective

Make current divergence actionable without a second historical source of truth.

### Deliverables

- The active-only register contract and stable live rows.
- Haskell row discovery and closure/reintroduction checks.

### Validation

The clean register and generated reintroductions of a deleted canonical ID, duplicate ID, missing owner,
missing Haskell binding, predicate-shaped Markdown without a binding, closed row, archive filename, and stale
reference produce the independently expected outcomes.

### Remaining Work

The Haskell checker and component oracle are an observed footprint only. Qualify the exact integrated build,
close all Phase-0-owned findings, and obtain independent human review after Sprint 0.1 is accepted.

## Sprint 0.3: Haskell source-closure classifier ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/SourceClosure.hs`
**Blocked by**: Sprint 0.2
**Independent Validation**: Classify every tracked path exactly once by path, extension, mode, shebang,
content role, and consumer; reject every unregistered, stale, duplicate, Phase-0-owned, or wrongly owned
source-boundary finding, while requiring an exact bijection between present later-owned findings and active
legacy rows.
**Oracle**: `test/validation-kernel/SourceClosureOracle.hs`; separately authored as a component diagnostic but not independently human-reviewed.
**Legacy IDs**: `LTD-SRC-000`, `LTD-SRC-008`
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Turn the closed tracked-source grammar into a semantic Haskell check that renaming cannot bypass.

### Deliverables

- Complete source-snapshot partition and exact later-owned finding/register bijection.
- Deny-by-default `pb/**` AST/import/effect audit plus external identity-argv/exec process observation.
- Lazy-output and authored-root write checks.

### Validation

Paired cases cover `.hs`, allowed non-code inputs, each `pb` bootstrap role, disguised Python/shell, executable
data, shebang source, behavioural metadata, source-adjacent cache, and generated output under authored roots.

### Remaining Work

Qualify the observed classifier against the complete clean tracked snapshot and spoof corpus, connect its raw
observations to the gate, and obtain independent human review after Sprint 0.2 is accepted.

## Sprint 0.4: Haskell documentation and plan-contract checker ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Documentation.hs`, `src/validation-kernel/Amoebius/Validation/PhaseContract.hs`
**Blocked by**: Sprint 0.3
**Independent Validation**: A complete structural corpus is accepted; a minimally different broken dependency is refused; an applied parser mutant reddens only its named row; semantic policy/prose correspondence remains explicit human-review residue.
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

### Validation

The Haskell checker rejects one generated minimal mutation for every structural rule and reports the exact
rule, file, and locus. Empty discovery refuses. A keyword-only decoy must be structurally inert and must never
alter a source, registry, validation, or ordering verdict.

### Remaining Work

The checkers and component oracles exist but are not qualified or independently human-reviewed. Resolve the
current corpus, including the 1,290 `UNRESOLVED` cells and 92 `MISSING` predecessor cells across 93
contracts, after Sprint 0.3 is
accepted.

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
**Independent Validation**: Every phase has one fixed 18-row table; all phase-specific subjects, oracles, controls, mutants, observers, legacy IDs, predecessors, and residue are explicit and independently reviewed. Any `UNRESOLVED` row refuses Phase 0.
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

The contract checker rejects missing/duplicate keys, generic boilerplate, unresolved fields, forward or absent
predecessors, non-Haskell subject/oracle paths, absent reviewers, and non-executable legacy closure.

### Remaining Work

Resolve the 1,290 `UNRESOLVED` gate cells and 92 `MISSING` predecessor cells currently spread across 93
contracts and complete the
independent phase-by-phase review after Sprint 0.6 is accepted. Every affected phase remains shut meanwhile.

## Sprint 0.8: Integrated Phase-0 candidate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Dispatch.hs`, `app/amoebius/Main.hs`, `pb/pb/cli.py`
**Blocked by**: Sprint 0.7
**Independent Validation**: From an empty generated tree, `pb validate phase 00` qualifies the harness, runs the clean corpus, resolves all Phase-0 legacy rows to zero, emits explicit candidate evidence, and cannot mutate status.
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

The dispatcher and opaque `pb` handoff are observed footprints, not an integrated candidate path. Qualification
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
- [Active legacy register](legacy_tracking_for_deletion.md)
- [Documentation standards](../documents/documentation_standards.md)
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
- [No-cluster conformance harness](../documents/engineering/conformance_harness_doctrine.md)
