# Phase 0: Documentation, source policy, and validation baseline

> **Purpose**: Establish the finite validation seed: one documentary policy surface, one bounded static source
> boundary, one irreducible `GenesisTrust`, and one gate-result protocol that can emit but never apply a status
> patch.
> **Read this if**: Phase 0's status or contract is being assessed, a cross-cutting rule changes, or a later phase needs the exact boundary
> between bootstrap assumptions and numbered validation claims.

Phase 0 is deliberately small. It proves only the seed needed to start ordered validation; it does not prove a
reproducible toolchain, a compiler-backed semantic source graph, universal harness self-reference, the `pb`
runtime handoff, a product capability, or any live substrate.

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
- [GenesisTrust pins](#genesistrust-pins)
- [Finite Phase-0 exit contract](#finite-phase-0-exit-contract)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 0.1: One documentary policy surface](#sprint-01-one-documentary-policy-surface-)
- [Sprint 0.2: One active legacy register](#sprint-02-one-active-legacy-register-)
- [Sprint 0.3: Haskell source-closure classifier](#sprint-03-haskell-source-closure-classifier-)
- [Sprint 0.4: Haskell documentation and plan-contract checker](#sprint-04-haskell-documentation-and-plan-contract-checker-)
- [Sprint 0.5: Gate-kernel qualification and spoof corpus](#sprint-05-gate-kernel-qualification-and-spoof-corpus-)
- [Sprint 0.6: Candidate evidence and gate-pass result](#sprint-06-candidate-evidence-and-gate-pass-result-)
- [Sprint 0.7: Check all numbered phase contracts](#sprint-07-check-all-numbered-phase-contracts-)
- [Sprint 0.8: Integrated Phase-0 candidate](#sprint-08-integrated-phase-0-candidate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

The status above is the sole phase-level lifecycle field. No component diagnostic, prepared input, emitted
candidate, or prose change can alter it; only a complete Phase-0 gate pass and the exact emitted status patch
can record Done.

---

## Phase Summary

Phase 0 establishes a finite root from which the numbered plan can validate in strict numerical order. Its
subject is the exact source snapshot being tested, the structural documentation and phase-plan surfaces, the
closed cross-cutting policy values, the bounded static source classifier, the Phase-0 evidence schema, and the
three-case bootstrap mutation seed. Every executable decision and independent expectation is Haskell. Python
under `pb/**` is inspected as source but is not used as validation transport.

`GenesisTrust` is an explicit, irreducible, non-numbered `BootstrapRoot`. It is not a hidden phase, a Phase-1
deliverable, or a theorem proved by the executable it enables. It states only that the candidate was compiled
by the pinned compiler family on the pinned platform and observed the seven exact prepared files below in local
custody. Detached-signature files are pinned bytes, not a signature-verification claim. Reproducible acquisition,
publisher authentication, the compiler executable's bytes and derivation, dynamic-loader closure, broader host
assumptions, trusting-trust reduction, and a second-build agreement remain open and belong to Phase 1.

The Phase-0 source claim is likewise finite: acquire the exact tracked path/kind/mode/byte snapshot, classify
it under the closed Haskell source policy, require the current captured `pb/**` bytes to satisfy the bounded
admission predicate, and reject a changed closing snapshot. It does not qualify the complete
`VALIDATION_PB_GRAMMAR` selector/oracle suite or parse, rename, typecheck, or infer behavior for the whole
repository. Those owner-level grammar and compiler-backed semantic source-graph claims belong to Phase 2.

The only changed-production source qualification required by this seed is the exact clean control plus the
three cases in Sprint 0.5. They are compiled and executed one at a time with the compiler named by
`GenesisTrust`; each mutant must change the copied production source and its binary, then fail the independent
driver while the clean copy passes. Complete per-owner mutation coverage and universal self-reference belong
to Phase 49.

Numerical order governs gate execution, evidence, and status. It does not prohibit implementation of a later
`Substrate: none` phase after that phase has an exact typed contract and separately authored oracle. Such work
cannot validate, mint candidate evidence, use `pb`, consume an absent predecessor, or touch live or hardware
resources before the validation frontier reaches it.

After a complete pass, the validator serializes a verified status-only patch beneath ignored `.build/**` and
exits without changing tracked files. A human, agent, or CI job may subsequently recheck the bound preimage and
apply exactly that patch. The validator is never its own tracked-plan editor.

**Phase scope:** Freeze and validate the finite documentation/source/evidence bootstrap seed; split immediately
if a requirement needs authenticated reproducible acquisition, compiler semantic analysis, universal
self-reference, `pb` runtime observation, product behavior, or live infrastructure.
**Substrate:** `none`
**Lane:** `none`
**Register:** —
**Depends on:** genesis
**Forward-deferred:** authenticated reproducible toolchain acquisition — [Phase 1](phase_01_toolchain_spike.md) `toolchain_spike` / `LTD-BOOT-001`; compiler-backed semantic source graph and owner-level `pb` closure — [Phase 2](phase_02_repository_layout_conformance.md) `repository_layout_conformance` / `LTD-SRC-000`, `LTD-SRC-008`; complete hardware-free universal self-reference and validation-debt closure — [Phase 49](phase_49_self_referential_gates.md) `self_referential_gates` / `LTD-VAL-001` through `LTD-VAL-006`
**Gate:** `pb validate phase 00`; see [Gate integrity](#gate-integrity).

### GenesisTrust pins

The following seven repository-relative local-custody inputs are the complete pinned file set. The byte count
and lowercase SHA-256 are part of the assumption. A missing, symlinked, non-regular, differently sized, or
differently hashed expected input refuses acquisition. Files not named by this pin set confer no authority;
the current acquisition does not claim exclusive ownership of their parent directory.

| Repository-relative path | Bytes | SHA-256 |
|---|---:|---|
| `.build/bootstrap-inputs/ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz` | 302637420 | `4da657809c06c1658ae5713911fcb168a32093e239f61fe77be78aba74132cfa` |
| `.build/bootstrap-inputs/ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz.sig` | 438 | `a5c8828b3c1c53cfc8d5e4459de0790efa5a8dea96cc16dd564382f005280cc5` |
| `.build/bootstrap-inputs/ghc-SHA256SUMS` | 6585 | `67869bc776c7f0ffe76226a689c234b367b2194aececbb53da2275892040053b` |
| `.build/bootstrap-inputs/ghc-SHA256SUMS.sig` | 438 | `9db94ced16b87713e89a41c408bf5efcb29462971c2494fbfec7e05a33de6bad` |
| `.build/bootstrap-inputs/cabal-install-3.16.1.0-x86_64-linux-ubuntu22_04.tar.xz` | 5288744 | `9d68bd17d4aa87e93eea3f667d3edf41ab1cb2b5194bf1745da9dee678426c17` |
| `.build/bootstrap-inputs/cabal-SHA256SUMS` | 2799 | `19ef5e11a70d6d06ae23a2b4cae6b52bcf19575be7343fc9dfcce4104bce8bb3` |
| `.build/bootstrap-inputs/cabal-SHA256SUMS.sig` | 95 | `59fa7dbebd873bd1714f440111fe1607148d25afd23450e4c5ee9afdc38c4eb3` |

The environment half of the same assumption is compile-time GHC `9.12.4`, Linux, `x86_64`, and absolute
`GHC.Paths.ghc` and `GHC.Paths.libdir` values. `GenesisTrust` domain-separates and hashes those observations and
the sorted file pins into an opaque token; callers cannot mint the token from strings.

### Finite Phase-0 exit contract

This checklist is the complete exit boundary. New hardening that is not necessary to falsify one of these
items is assigned to its numbered owner instead of extending Phase 0.

- Acquire one opaque `GenesisTrust` from exactly the seven pins and environment facts above, while making
  no publisher-authentication or reproducible-acquisition claim.
- Capture and re-capture one exact tracked source snapshot; close the static Haskell source partition and
  the bounded `pb/**` grammar without requiring the Phase-2 compiler semantic graph.
- Check the governed-document inventory, link metadata, canonical status syntax, sprint fields, immediate
  blockers, and fixed eighteen-row tables without deriving executable semantics from Markdown.
- Bind all eighteen Phase-0 semantic requirements while permitting later phase semantic contracts to
  remain owned by those later phases.
- Run the clean bootstrap predicate and exactly three changed-source cases serially, retaining source,
  binary, exit, stdout, stderr, compiler, snapshot, transcript-v2, and cleanup identities; clean must be silent
  and successful, while each mutant must return `ExitFailure 1`, empty stdout, and its exact case-label stderr.
- Require the scoped `SourcePb` observation to be zero for the captured Phase-0 source while leaving
  `LTD-SRC-008` active for its Phase-2 owner-level analyzer and reintroduction proof.
- Observe that the compiled legacy due-count for Phase 0 is zero. No legacy ID is owned or retired here;
  later owners remain explicit typed forward deferrals outside the Phase-0 candidate.
- Produce one complete qualified candidate whose required rows pass and whose `captureResidue` is exactly
  empty; a forward-deferred exclusion is not serialized as `UNVERIFIED` candidate residue.
- Emit the exact verified status-only patch beneath `.build/**`; do not apply it or otherwise mutate a
  tracked file from the validator process, and re-acquire the Git source snapshot after emission to prove it
  still equals the opening snapshot.

## Gate integrity

**Contract check**: SPECIFICATION RESOLVED. The rows below are the complete Phase-0 contract, not a record of
execution or a second status field.

| Key | Contract |
|---|---|
| `Claim` | For one exact source snapshot, the governed documentation structure, closed cross-cutting policy, bounded static source classification, finite bootstrap qualification, and evidence/status-patch protocol agree. Later-owned toolchain reproducibility, compiler semantic closure, universal self-reference, runtime handoff, product, and live-resource claims are excluded. |
| `Subject` | The source-bound Haskell Phase-0 dispatcher joins one opaque `GenesisTrust`, one acquired opening/closing source snapshot, the typed policy and Phase-0 contract, structural document observations, the static source/`pb` checks, the finite qualification receipt, and the evidence verifier. No caller-authored snapshot, digest, row result, predecessor, or status projection can substitute for an acquired value. |
| `Command` | Future public spelling is `pb validate phase 00`, but `pb` is inadmissible before `BOOTSTRAP_HANDOFF`. The actual gate launches the running Haskell executable directly by its absolute path with the exact argv suffix `validate`, `phase`, `00`, no wrapper or extra argument. The executable records its path, digest, argv, and GenesisTrust token; it does not claim the executable bytes' compiler/build derivation, which Phase 1 owns. The clean plus three qualification binaries compile serially with `-j1`. |
| `Oracle` | The candidate oracle is the separately tracked `test/validation-kernel/BootstrapMutationDriver.hs`, whose acquired bytes are distinct from both `BootstrapPredicate.hs` and the qualification harness. It states the clean and three bypass expectations. Other named Haskell oracles are bounded component diagnostics and their results are not represented as integrated Phase-0 oracle receipts. |
| `Positive controls` | Exactly one unchanged acquired `BootstrapPredicate.hs` copy compiles and its independent driver exits successfully. Genesis, policy, documentation, source, contract, and mutation-inventory checks are composed into the separately digest-bound `Subject` result rather than being restated as additional positive-control receipts. |
| `Paired negatives` | Exactly three minimally changed predicate copies compile and the independent driver rejects them: digest equality bypass, snapshot freshness bypass, and bootstrap-input path bypass. Each mutant must return exactly `ExitFailure 1`, emit empty stdout, and emit exactly its canonical case label plus one newline on stderr. The unchanged control must return `ExitSuccess` with both streams empty. |
| `Mutants` | The complete Phase-0 changed-production set is exactly `digest-equality-bypass`, `snapshot-freshness-bypass`, and `bootstrap-path-bypass`. Each replaces exactly one stable line in an acquired copy of `BootstrapPredicate.hs`; no `VALIDATION_*` selector family, Cabal-flag universe, or per-module exhaustive selector matrix is Phase-0-owned. Broad validation-infrastructure families belong to Phase 49; source/toolchain families belong to their typed Phase-1/Phase-2 owners. |
| `Discovery` | The executed qualification inventory must be exactly the ordered clean-plus-three case universe and its snapshot digest must equal the candidate's opening source identity. Governed Markdown, tracked-path, and seven-pin discovery are checked inside the composed `Subject`; they are not claimed as separate Discovery-row receipts. |
| `Challenge` | Each qualification case copies the acquired production subject and independent driver into one unique ignored run leaf, changes exactly one named predicate line, and refuses a missing or duplicate marker. The exact three bypass attempts must each return `ExitFailure 1`, empty stdout, and its exact case-label stderr. |
| `Observer` | The opaque protocol retains each compile exit, run exit, stdout, stderr, changed-source SHA-256, changed-binary SHA-256, the acquired oracle/harness digests, compiler path, v2 transcript digest, and removed run-leaf name. It requires a silent successful clean control; exact mutant `ExitFailure 1`, empty stdout, and canonical case-label-plus-newline stderr; distinct source/binary identities; and observed cleanup. |
| `Authority/bypass` | Package-hidden constructors protect `GenesisTrust`, the acquired source snapshot, qualification authority, row outcomes, gate pass, and projection authorization. The finite gate directly challenges mismatched well-formed digest and snapshot values and rejects either equality bypass; broader universal authority and replay attacks belong to Phase 49. |
| `Freshness` | The candidate binds exact opening and independently re-acquired pre-publication closing source identities; inequality or unavailable capture refuses. After the authorized status projection is emitted, the dispatcher re-acquires the Git snapshot again and refuses if it is unavailable or differs from the opening identity. Qualification uses a unique temporary leaf and binds its v2 transcript to the opening snapshot. Phase 0 does not claim that the whole `.build/**` tree was initially absent or that it universally detects prior-run replay. |
| `Qualification` | The exact sequence is clean, `digest-equality-bypass`, `snapshot-freshness-bypass`, `bootstrap-path-bypass`. All four compile one at a time with the absolute genesis compiler and `-j1`; clean returns `ExitSuccess` with empty stdout/stderr; every mutant returns `ExitFailure 1`, empty stdout, and its canonical case label plus newline on stderr; identities are distinct; the ordered v2 transcript retains those outputs and binds the snapshot; and cleanup is observed. |
| `Cleanroom` | Qualification generates copied source, objects, and binaries beneath one unique `.build/runs/phase-00/bootstrap-qualification-*` leaf, compiles serially, and requires that leaf to be absent afterward. Candidate evidence and the authorized status projection are written beneath `.build/**`. This finite row does not claim whole-tree absent-before observation; universal run-input/cleanroom closure belongs to Phase 49. |
| `Legacy closure` | The compiled Haskell inventory owns IDs, owners, analyzers, closures, and reintroduction cases; the Markdown register is reader-facing only. `legacyBootstrapClosureAcquired` must observe a Phase-0 due-count of zero, because every legacy ID has a later capability owner. The separately required scoped `SourcePb` zero proves only the captured Phase-0 `pb` source predicate; it neither executes the Phase-2 owner analyzer nor retires `LTD-SRC-008`. |
| `Predecessor` | `genesis` means the explicit non-numbered `GenesisTrust`/`BootstrapRoot`; there is no prior numbered phase and no synthetic Phase -1 result. |
| `Residue` | `captureResidue` must be exactly empty. Phase-1 toolchain provenance, Phase-2 compiler/`pb` owner closure, Phase-49 universal validation, Phase-50 runtime handoff, and every product or live-resource capability are typed exclusions or `Forward-deferred` relations, not `UNVERIFIED` entries in a Phase-0 candidate. Any retained candidate residue refuses this row. |
| `Pass criterion` | `qualified-gate-pass` — every required Phase-0 row succeeds in one serial run for the same exact source and GenesisTrust identities. The only tracked-state result is a verified status-only patch emitted beneath `.build/**`; the validator never applies it. |

## Doctrine adopted

- [`documentation_standards.md` §1 — philosophy](../documents/documentation_standards.md#1-philosophy) — one
  documentary authority, required metadata, and reconciled links.
- [`repository_layout_doctrine.md` §1 — classification rule](../documents/engineering/repository_layout_doctrine.md#1-classification-rule) — Haskell behavioral source, the bounded
  `pb/**` exception, and lazy `.build/**` products.
- [`validation_frame_doctrine.md` §1 — native Haskell validation](../documents/engineering/validation_frame_doctrine.md#1-native-haskell-is-the-validation-environment) — the finite seed, typed contracts, ordered evidence, and explicit exclusions.
- [`testing_spoof_resistance.md` §12 — spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence) — independent expectations, changed-source witnesses, and authority rejection.
- [`development_plan_gate_integrity.md` §M.3 — mutants must prove that they changed the subject](development_plan_gate_integrity.md#m3-mutants-must-prove-that-they-changed-the-subject) — owner-bounded cumulative mutation scope and the later universal milestone.

## Sprints

## Sprint 0.1: One documentary policy surface ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/PolicyContract.hs`, `src/validation-kernel/Amoebius/Validation/PolicyContract/Internal.hs`, `AGENTS.md`, `CLAUDE.md`, `README.md`, `DEVELOPMENT_PLAN/phase_00_documentation_suite.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`, `documents/documentation_standards.md`, `documents/engineering/repository_layout_doctrine.md`, and `documents/engineering/validation_frame_doctrine.md`
**Blocked by**: `genesis`
**Independent Validation**: The canonical typed policy and matching prose are the component positive control; minimally different raw owner, source-boundary, ordering, and status values are component paired negatives. The Phase-0 changed-production witness remains only `digest-equality-bypass`; the broad `VALIDATION_POLICY` selector family and complete owner mutation coverage belong to Phase 49.
**Oracle**: `test/validation-kernel/PolicyContractOracle.hs` independently restates the closed values and prose owners without deriving them from production rendering; its component result is not an integrated Phase-0 oracle receipt.
**Legacy IDs**: none
**Docs to update**: `AGENTS.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`, and the doctrine owner for each cross-cutting rule

### Objective

Make one typed owner and one canonical prose owner agree for source language, `pb`, lazy generation, validation
order, GenesisTrust, gate sufficiency, and emitted-only status patches.

### Deliverables

- Closed Haskell policy values and stable owner references.
- Canonical documentation statements with reciprocal metadata links.
- Structural status vocabulary that cannot be interpreted as a verdict.

### Validation

Compare independently authored expected policy values and owner anchors with production values and the acquired
documentation bytes. Reject a one-field policy change and a prose-only decoy at distinct loci.

### Remaining Work

Until this sprint records Done, its raw observations must be retained by the integrated Phase-0 gate. No
standalone diagnostic or historical result closes it; after Done, the gate result is the closure authority.

## Sprint 0.2: One active legacy register ✅

**Status**: Done
**Implementation**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`, `src/validation-kernel/Amoebius/Validation/Legacy.hs`, and `src/validation-kernel/Amoebius/Validation/Legacy/Internal.hs`
**Blocked by**: Sprint 0.1
**Forward-deferred**: every owner-domain analyzer and reintroduction proof belongs to its later typed capability; Phase 0 requires only zero IDs assigned to `documentation_suite`
**Independent Validation**: One regular non-executable UTF-8 canonical register, one total compiled ID/owner map, and Phase-0 due-count zero are the positive control; missing, duplicate, Phase-0-owned, renamed-owner, Markdown-forged, or unavailable-due cases are paired negatives. The `digest-equality-bypass` case prevents a copied register digest from becoming evidence. Only the integrated structural receipt remains in this phase.
**Oracle**: `test/validation-kernel/LegacyOracle.hs` separately states the closed ID, owner, lifecycle, analyzer, closure, and reintroduction-case expectations; it does not parse Markdown rows into those values.
**Legacy IDs**: all typed identities, as inventory/delegation only; no later owner-domain closure is claimed
**Docs to update**: `DEVELOPMENT_PLAN/development_plan_gate_integrity.md` and `documents/engineering/migration_doctrine.md`

### Objective

Keep one reader-facing active-debt explanation while Haskell exclusively owns every executable legacy identity,
owner, lifecycle, analyzer, closure, and reintroduction requirement.

### Deliverables

- Exactly one canonical active legacy register with structural checks only.
- A closed, total Haskell owner map assigning every legacy ID to a falsifiable later capability and none to Phase 0.
- Fail-closed analyzer dispatch and opaque owner-bound reintroduction evidence.

### Validation

Reject a missing or duplicate register, forbidden archive basename, executable/symlink/non-UTF-8 file, absent
typed ID, duplicate encoding, wrong owner, missing analyzer, early zero, or Markdown-only closure claim.

### Remaining Work

No owner-domain legacy row closes here. Later-owned entries stay active until their own numerically ordered
gates; Phase 0 proves only inventory integrity, structural register integrity, and that its due-count is zero.

## Sprint 0.3: Haskell source-closure classifier ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/BootstrapPredicate.hs`, `src/validation-kernel/Amoebius/Validation/BootstrapTrust/Internal.hs`, `src/validation-kernel/Amoebius/Validation/SourceClosure.hs`, `src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs`, `src/validation-kernel/Amoebius/Validation/SourceDebtBaseline.hs`, `src/validation-kernel/Amoebius/Validation/SourceDebtBaseline/Internal.hs`, `src/validation-kernel/Amoebius/Validation/PbBootstrapGrammar.hs`, and `src/validation-kernel/Amoebius/Validation/PbBootstrapGrammar/Internal.hs`
**Blocked by**: Sprint 0.2
**Forward-deferred**: the complete `VALIDATION_PB_GRAMMAR` selector/oracle suite, compiler-backed parsing, renaming, typechecking, call/effect analysis, complete source graph, and owner-level `pb` retirement — Phase 2 `repository_layout_conformance` / `LTD-SRC-000`, `LTD-SRC-008`
**Independent Validation**: Exact opening/closing path-kind-mode-byte snapshots, a scoped `SourcePb` zero, and admission of the exact current captured `pb/**` bytes are the positive control; an unclassified path, symlink, mode/byte change, or closing-snapshot mismatch is a paired negative. `bootstrap-path-bypass` and `snapshot-freshness-bypass` are the exact changed-source witnesses. Broad `pb` grammar-selector qualification and compiler semantic completeness are excluded.
**Oracle**: `test/validation-kernel/BootstrapPredicateOracle.hs`, `test/validation-kernel/BootstrapTrustInternalOracle.hs`, `test/validation-kernel/SourceClosureOracle.hs`, and `test/validation-kernel/SourceDebtBaselineOracle.hs` are bounded component diagnostics over raw inputs and fixed expectations; their results are not integrated oracle receipts. `test/validation-kernel/PbBootstrapGrammarOracle.hs` and the full `VALIDATION_PB_GRAMMAR` suite belong to Phase 2.
**Legacy IDs**: `LTD-SRC-008` — observation reference only; Phase 2 owns its analyzer, reintroduction proof, and retirement
**Docs to update**: `documents/engineering/repository_layout_doctrine.md` and `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Establish the bounded static source and freshness claim needed by Phase 0 without requiring a compiler to prove
the semantics of the compiler-facing graph.

### Deliverables

- Opaque GenesisTrust acquisition over the exact seven pins.
- Acquired opening and closing source snapshots with closed structural classification.
- Admission of the exact current captured `pb/**` bytes and a scoped `SourcePb` zero result that does not
  qualify the full grammar suite or retire `LTD-SRC-008`.

### Validation

Require the exact captured `pb/**` input to satisfy the bounded admission predicate and the two relevant
bootstrap mutations to red their independent cases. This finite admission does not claim full
`VALIDATION_PB_GRAMMAR` qualification or runtime interpreter, network, executable, argv, or exec-replacement
behavior.

### Remaining Work

Until this sprint records Done, the integrated run must bind the snapshot and trust token to every Phase-0
row. Phase-2 full grammar-selector qualification, semantic analysis, and owner-level `LTD-SRC-008` retirement,
plus Phase-50 handoff observation, remain outside this sprint.

## Sprint 0.4: Haskell documentation and plan-contract checker ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/Documentation.hs`, `src/validation-kernel/Amoebius/Validation/Documentation/Internal.hs`, `src/validation-kernel/Amoebius/Validation/PhaseContract.hs`, `src/validation-kernel/Amoebius/Validation/PhaseContract/Internal.hs`, `src/validation-kernel/Amoebius/Validation/PhaseSemanticContract.hs`, and `src/validation-kernel/Amoebius/Validation/PhaseSemanticJoin.hs`
**Blocked by**: Sprint 0.3
**Forward-deferred**: universal phase-contract/evidence qualification and `LTD-VAL-002` retirement — Phase 49 `self_referential_gates`
**Independent Validation**: The complete governed file inventory and structurally valid ninety-six-phase plan are the component positive control; a missing file, broken reciprocal link, duplicate status, wrong immediate blocker, malformed sprint field, or malformed gate row is a raw component paired negative. `digest-equality-bypass` is the Phase-0 changed-production witness that prevents stale contract bytes from matching. The broad documentation, phase-contract, and phase-semantic selector families belong to Phase 49; semantic completion of later contracts is excluded.
**Oracle**: `test/validation-kernel/DocumentationOracle.hs`, `test/validation-kernel/PhaseContractOracle.hs`, `test/validation-kernel/PhaseContractInternalOracle.hs`, and `test/validation-kernel/PhaseSemanticContractOracle.hs` own literal structural and typed component expectations separately from the production parsers; their component results are not integrated Phase-0 oracle receipts.
**Legacy IDs**: `LTD-VAL-002` — structural seed reference only; Phase 49 owns retirement
**Docs to update**: `documents/documentation_standards.md` and `DEVELOPMENT_PLAN/development_plan_standards.md`

### Objective

Check the closed plan/document frame while leaving each later phase responsible for its own semantic contract.

### Deliverables

- Complete governed-document discovery and reciprocal metadata/link checks.
- Exact phase/sprint status, field-order, immediate-blocker, and eighteen-row table checks.
- Eighteen bound typed requirements for Phase 0 and explicit owner-held state for later contracts.

### Validation

Exercise canonical documents plus minimally different malformed raw Markdown frames. Confirm that prose can
cause a documentation correspondence finding but cannot construct a semantic contract or gate verdict.

### Remaining Work

Until this sprint records Done, the Phase-0 typed/prose join and full integrated observation remain required.
Later semantic contracts are not a Phase-0 completion condition.

## Sprint 0.5: Gate-kernel qualification and spoof corpus ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/BootstrapPredicate.hs`, `src/validation-kernel/Amoebius/Validation/BootstrapQualification/Internal.hs`, and `test/validation-kernel/BootstrapMutationDriver.hs`
**Blocked by**: Sprint 0.4
**Forward-deferred**: complete per-owner mutation coverage and hardware-free universal self-reference — Phase 49 `self_referential_gates` / `LTD-VAL-001`
**Independent Validation**: One acquired clean subject compiled and accepted silently by the independent driver is the positive control; the exact three one-line changed subjects are paired negatives. Each changed source and binary must differ from clean, return exactly `ExitFailure 1`, emit empty stdout, and emit its canonical case label plus one newline on stderr. Missing markers, duplicate markers, compile failure, a wrong exit or stream, a surviving mutant, or generated-leaf residue refuses qualification. The universal corpus is excluded.
**Oracle**: `test/validation-kernel/BootstrapMutationDriver.hs` states fixed raw predicate expectations and imports only the copied `BootstrapPredicate` surface; `test/validation-kernel/BootstrapPredicateOracle.hs` independently checks the pure predicate boundary.
**Legacy IDs**: none — this is the finite Phase-0 seed; `LTD-VAL-001` belongs to Phase 49
**Docs to update**: `documents/engineering/testing_spoof_resistance.md` and `documents/engineering/validation_frame_doctrine.md`

### Objective

Qualify the minimum changed-production mechanism needed to trust the Phase-0 gate without making Phase 0 prove
the mutation infrastructure for all future source.

### Deliverables

- `digest-equality-bypass`: replace `bootstrapDigestMatches actual expected = validLowerSha256 actual && actual == expected` with `bootstrapDigestMatches _ _ = True`.
- `snapshot-freshness-bypass`: replace `bootstrapSnapshotMatches opening closing = validLowerSha256 opening && opening == closing` with `bootstrapSnapshotMatches _ _ = True`.
- `bootstrap-path-bypass`: replace ``bootstrapInputPathAllowed path = ".build/bootstrap-inputs/" `isPrefixOf` path && boundedRelativePath path`` with `bootstrapInputPathAllowed _ = True`.
- One ordered clean-plus-three receipt bound to exact source, binary, compiler, snapshot, v2 transcript, exits,
  stdout/stderr, and cleanup.

### Validation

Copy the acquired subject and driver into a fresh `.build/runs/phase-00/**` leaf. Compile clean and the three
mutants one at a time with the absolute `GHC.Paths.ghc`, `-j1`, force recompilation, separate object roots, and
no concurrent linker. Require a silent `ExitSuccess` clean run; exact mutant `ExitFailure 1`, empty stdout, and
case-label-plus-newline stderr; distinct identities; exact ordering; v2 transcript retention; and an absent leaf
after cleanup.

### Remaining Work

Until this sprint records Done, its receipt must be consumed by the same integrated candidate as every other
row. Phase 49, not this sprint, owns cumulative mutation completeness and validation of the validator against
the full hardware-free surface.

## Sprint 0.6: Candidate evidence and gate-pass result ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/Evidence.hs`, `src/validation-kernel/Amoebius/Validation/Evidence/Internal.hs`, `src/validation-kernel/Amoebius/Validation/GatePass.hs`, `src/validation-kernel/Amoebius/Validation/GatePass/Internal.hs`, `src/validation-kernel/Amoebius/Validation/PhaseRunner/Internal.hs`, `src/validation-kernel/Amoebius/Validation/StatusFrontier.hs`, and `src/validation-kernel/Amoebius/Validation/StatusProjection/Internal.hs`
**Blocked by**: Sprint 0.5
**Forward-deferred**: universal evidence/gate-pass qualification and `LTD-VAL-003`/`LTD-VAL-004` retirement — Phase 49 `self_referential_gates`
**Independent Validation**: One dispatcher-acquired, complete, ordered green bundle bound to the current source, contract, GenesisTrust, qualification, executable/argv, and exact frontier is the positive control; a missing, duplicate, reordered, red, stale, forged, or widened input is a paired negative. `digest-equality-bypass` and `snapshot-freshness-bypass` must red stale identity acceptance. Applying the emitted patch is explicitly outside the validator.
**Oracle**: `test/validation-kernel/EvidenceGatePassInternalOracle.hs`, `test/validation-kernel/PhaseRunnerInternalOracle.hs`, `test/validation-kernel/StatusFrontierOracle.hs`, and `test/validation-kernel/StatusProjectionInternalOracle.hs` are bounded component diagnostics; their results are not integrated candidate oracle receipts. Candidate oracle authority remains the acquired `BootstrapMutationDriver` digest and finite qualification transcript.
**Legacy IDs**: `LTD-VAL-003`, `LTD-VAL-004` — finite seed references only; Phase 49 owns retirement
**Docs to update**: `AGENTS.md`, `DEVELOPMENT_PLAN/development_plan_phase_model.md`, and `documents/engineering/testing_spoof_resistance.md`

### Objective

Turn complete raw observations into one opaque pass and one verified status-only patch without giving the
validator tracked-write authority.

### Deliverables

- Schema-checked, content-addressed candidate evidence beneath `.build/**`.
- Package-hidden verification that rejects partial, stale, red, or caller-authored candidates.
- An exact frontier patch serializer restricted to tracker, Phase-0, all Phase-0 sprint, and immediate-successor status fields.
- `writeAuthorizedStatusProjection` accepts only an `AuthorizedStatusProjection` sealed by the verified pass and
  emits beneath `.build/**`; its unsealed writer is reachable only through the direct-source test seam.
- No tracked-file write, rename, exchange, journal, or patch-application path reachable from the validator
  command; retained lower-level application helpers confer no validator authority and are outside this seed.

### Validation

Require exact patch bytes and targets for the acquired preimage, reject a widened or non-status projection,
and verify that production reaches only `writeAuthorizedStatusProjection` after `authorizeStatusProjection`,
never the unsealed direct-source test writer or retained application API. Re-acquire the Git source snapshot
after projection emission and require it to equal the opening identity. This final recapture proves validator
tracked-tree immutability for the run; it is not a universal prior-run replay-detection claim.

### Remaining Work

The positive authority can be obtained only by the integrated Phase-0 run. External patch application occurs
after validator exit and requires a fresh preimage check, irrespective of the recorded sprint status.

## Sprint 0.7: Check all numbered phase contracts ✅

**Status**: Done
**Implementation**: `DEVELOPMENT_PLAN/phase_[0-9][0-9]_*.md`, `src/validation-kernel/Amoebius/Validation/PhaseContract.hs`, and `src/validation-kernel/Amoebius/Validation/PhaseSemanticContract.hs`
**Blocked by**: Sprint 0.6
**Forward-deferred**: universal phase-contract qualification and `LTD-VAL-002` retirement — Phase 49 `self_referential_gates`
**Independent Validation**: Exactly ninety-six contiguous phase documents with required metadata, status, fields, immediate edges, and eighteen ordered rows are the positive control; omission, duplication, ordinal/slug mismatch, malformed field order, or forward validation edge is a paired negative. `digest-equality-bypass` prevents a stale plan snapshot from being accepted. Later semantic implementation is excluded.
**Oracle**: `test/validation-kernel/PhaseContractOracle.hs` and `test/validation-kernel/PhaseSemanticContractOracle.hs` independently state the structural inventory and Phase-0 typed obligations without interpreting later prose into behavior.
**Legacy IDs**: `LTD-VAL-002` — structural inventory reference only; Phase 49 owns retirement
**Docs to update**: all numbered phase contracts whose structure or typed ownership is corrected

### Objective

Prove that every numbered phase is a structurally valid, numerically ordered contract container while requiring
semantic completion only at the phase being validated.

### Deliverables

- Contiguous phase identity and exact path/title joins.
- Required phase and sprint schemas with immediate predecessor edges.
- One fixed eighteen-row table per phase and explicit typed ownership of unresolved later work.

### Validation

Run structural discovery over all phase documents and the independent typed identity table. Reject malformed
later contracts structurally, but do not make Phase 0 implement or validate their later-owned semantics.

### Remaining Work

Until this sprint records Done, the integrated gate must bind its observations to the opening source snapshot.
Each later owner still has to replace its own semantic gaps before its own gate can pass.

## Sprint 0.8: Integrated Phase-0 candidate ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/Dispatch.hs`, `src/validation-kernel/Amoebius/Validation/Dispatch/Internal.hs`, and `app/amoebius/Main.hs`
**Blocked by**: Sprint 0.7
**Forward-deferred**: Phase-1 toolchain acquisition, Phase-2 compiler/`pb` owner closure, and Phase-49 universal self-reference are typed exclusions and never enter `captureResidue`
**Independent Validation**: One fresh direct execution of the running Haskell binary by its exact absolute path with argv `validate phase 00` is the positive control; wrong argv, `pb` transport, overlapping qualification compiles, changed source, missing GenesisTrust, incomplete rows, nonzero Phase-0 legacy due-count, nonempty `captureResidue`, generated residue leakage, or a reachable status-application call is a paired negative. All three bootstrap changed sources must have qualified the same snapshot before the clean candidate. Executable build derivation and later-owner evidence are excluded.
**Oracle**: `test/validation-kernel/DispatchOracle.hs` is a refusal-only raw-input component diagnostic and `test/validation-kernel/Main.hs` is a component runner; neither observes the Phase-0 process or retains candidate rows. The integrated candidate's only independent oracle identity is the acquired `test/validation-kernel/BootstrapMutationDriver.hs` source and its finite transcript.
**Legacy IDs**: none due at Phase 0; all compiled legacy IDs retain later capability owners
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through the exact emitted status patch after the complete pass

### Objective

Run the first admissible finite phase gate and emit its result without editing the plan.

### Deliverables

- One source-bound Phase-0 dispatcher and closed runner selection.
- One complete candidate binding every gate row to the same GenesisTrust and source snapshot.
- One pass/refusal result and, only on pass, one emitted verified status-only patch beneath `.build/**`.

### Validation

Build under the repository's one-compiler-job development rule, then invoke exactly one absolute candidate executable directly with the argv suffix
`validate phase 00`. Within that single gate run, execute the clean-plus-three qualification sequence serially,
compose the Phase-0 subject checks, re-acquire source before verification, publish and verify the candidate,
authorize and emit the projection only beneath `.build/**`, then re-acquire Git source and require the final
identity to equal the opening identity. The validator never invokes its retained application API.
Any failed row returns refusal and emits no authorized patch.

### Remaining Work

Until this sprint records Done, the complete integrated execution and its evidence remain required. Its pass
finishes only the finite exit contract above; Phase-1, Phase-2, Phase-49, Phase-50, product, and hardware claims
remain typed exclusions.

## Documentation Requirements

**Engineering docs to update when their governed boundary changes:**

- `documents/documentation_standards.md` — only if governed document mechanics change.
- `documents/engineering/repository_layout_doctrine.md` — only if the finite source boundary changes.
- `documents/engineering/testing_spoof_resistance.md` — only if the finite qualification or evidence boundary changes.
- `documents/engineering/validation_frame_doctrine.md` — only if GenesisTrust, owner deferral, or emitted-only status projection changes.

**Cross-references to add:**

- Actual inbound links discovered by the Haskell link-graph checker, reconciled in the same change.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 1 toolchain spike](phase_01_toolchain_spike.md) — authenticated reproducible acquisition after the finite seed
- [Phase 2 repository layout conformance](phase_02_repository_layout_conformance.md) — compiler-backed semantic source graph
- [Phase 49 self-referential gates](phase_49_self_referential_gates.md) — complete hardware-free universal self-reference
- [Development-plan standards](development_plan_standards.md)
- [Canonical phase model](development_plan_phase_model.md)
- [Gate integrity](development_plan_gate_integrity.md)
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [Validation-frame doctrine](../documents/engineering/validation_frame_doctrine.md)
- [Repository-layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
- [Conformance-harness doctrine](../documents/engineering/conformance_harness_doctrine.md)
- [Image-build doctrine](../documents/engineering/image_build_doctrine.md)
- [Migration doctrine](../documents/engineering/migration_doctrine.md)
- [Service-capability doctrine](../documents/engineering/service_capability_doctrine.md)
