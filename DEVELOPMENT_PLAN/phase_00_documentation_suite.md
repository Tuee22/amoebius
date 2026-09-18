# Phase 0: Documentation, governance, and the validation seed

> **Purpose**: Establish the governance seed (decision log, frozen baseline, standalone documentation checker), the finite bootstrap seed (`GenesisTrust`, the three-case predicate matrix, the seven custody probes), and the validator itself (custody core, generic gate runner, human-only transition commands, kernel budget).
> **Read this if**: Phase 0's status or contract is being assessed, a cross-cutting rule changes, or a later phase needs the exact boundary between bootstrap assumptions and numbered validation claims.

Phase 0 specifies the seed needed to start ordered validation under certification generation 2; it proves no
reproducible toolchain, no source closure, no product capability, and no live substrate. It builds the
validator that judges every later phase, so nothing product-facing is a Phase-0 deliverable.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/system_components.md, documents/decision_log.md, documents/documentation_standards.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/validation_frame_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 0.1: Governance surface](#sprint-01-governance-surface-)
- [Sprint 0.2: Checker reconciliation](#sprint-02-checker-reconciliation-)
- [Sprint 0.3: Documentation checker extraction](#sprint-03-documentation-checker-extraction-)
- [Sprint 0.4: Gate specification and runner core](#sprint-04-gate-specification-and-runner-core-)
- [Sprint 0.5: Custody core and human commands](#sprint-05-custody-core-and-human-commands-)
- [Sprint 0.6: Delete pass, package rewrite, and executable split](#sprint-06-delete-pass-package-rewrite-and-executable-split-)
- [Sprint 0.7: Phase-0 gate specification, first reseed, and receipt-bearing reset](#sprint-07-phase-0-gate-specification-first-reseed-and-receipt-bearing-reset-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

🔄 Active — NOT VALIDATED.

The generation-2 reset ([DL-0007](../documents/decision_log.md#dl-0007--certification-generation-2-replaces-the-validation-kernel),
[DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice)) withdraws every
generation-1 certification. This phase is the frontier. Its contract is reopened under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) because its subject changed: the
validator it seeds is replaced, not hardened.

## Phase Summary

Phase 0 establishes a finite root from which the numbered plan can validate in strict numerical order. Its
subject is the governance surface, the standalone documentation checker, the gate-specification library, the
generic runner, the retained custody core, the human transition commands, and the three-case bootstrap
mutation seed. Every executable decision and independent expectation is Haskell. Python under `pb/**` is
inspected as source but is not used as validation transport.

`GenesisTrust` is an explicit, irreducible, non-numbered `BootstrapRoot`. It is not a hidden phase, a Phase-1
deliverable, or a theorem proved by the executable it enables. It states only that the candidate was compiled
by the pinned compiler family on the pinned platform and observed the seven exact prepared files below in local
custody. Reproducible acquisition, publisher authentication, the compiler executable's bytes and derivation,
and a second-build agreement remain open and belong to Phase 1.

The validator is specified by the [gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md):
one generic runner consumes one typed `GateSpec` per phase, holds every verdict, generates every mutant, and
records the kernel line count against a ratchet. The agent command `preview` mints nothing; the human command
`accept` signs and applies exactly one phase's status patch. This phase owes all of that machinery; nothing in
this document is an observed result.

Numerical order governs gate execution, evidence, and status. It does not prohibit implementation of a later
`Substrate: none` phase after that phase has an exact typed contract and separately authored oracle. Such work
cannot validate, mint candidate evidence, use `pb`, consume an absent predecessor, or touch live or hardware
resources before the validation frontier reaches it.

**Phase scope:** Build and validate the governance seed, the finite bootstrap seed, and the generation-2 validator; split immediately if a requirement needs authenticated reproducible acquisition, compiler semantic analysis, product behavior, or live infrastructure.
**Substrate:** `none`
**Lane:** `none`
**Register:** —
**Depends on:** genesis
**Forward-deferred:** authenticated reproducible toolchain acquisition — [Phase 1](phase_01_toolchain_spike.md) `toolchain_spike` / `LTD-BOOT-001`; compiler-backed source closure — [Phase 2](phase_02_repository_layout_conformance.md) `repository_layout_conformance` / `LTD-SRC-000`, `LTD-SRC-008`; the spine fact through the shipped binary — [Phase 3](phase_03_typed_spine.md) `typed_spine` / `LTD-DSL-001`
**Gate:** `pb validate phase 00`; see [Gate integrity](#gate-integrity).

### Gate specification

The compiled specification the runner executes, rendered by `amoebius-validate spec phase 00`; the
documentation checker refuses this document when the block and the compiled value differ.

```gate-spec
capability: documentation_suite
role: seed
claim: For one snapshot, the standalone documentation checker reports zero findings on the governed corpus and the named finding on each rendered negative; the three bootstrap predicate mutants are judged by the independent driver; the custody probes pass; the hygiene row is green at the recorded cap; the generation-2 seed is content-addressed and human-issued.
subjects: Amoebius.Validation.BootstrapPredicate, Amoebius.Doc.Check, Amoebius.Validation.Runner, Amoebius.Validation.Custody
suite: plan-decisions-suite
oracle: oracle-doc
positive: clean-predicate | input=Amoebius.Validation.BootstrapPredicate | expected=silent ExitSuccess
negative: digest-equality-bypass | input=bootstrapDigestMatches | tag=digest-equality-bypass | stage=predicate
negative: snapshot-freshness-bypass | input=bootstrapSnapshotMatches | tag=snapshot-freshness-bypass | stage=predicate
negative: bootstrap-path-bypass | input=bootstrapInputPathAllowed | tag=bootstrap-path-bypass | stage=predicate
positive: store-seed-roundtrip | input=SeedRecord | expected=equal
positive: store-receipt-roundtrip | input=Receipt | expected=equal
negative: store-tampered-receipt | input=receipt payload | tag=signature does not verify | stage=custody
negative: tripwire-agent-shell | input=CLAUDECODE,AI_AGENT | tag=ISSUER-AGENT-SESSION | stage=custody
negative: preflight-status-surface-dirty | input=surface digest | tag=StatusSurfaceDirty | stage=preflight
negative: preflight-verifier-diverged | input=verifier digest | tag=KERNEL-VERIFIER-DIVERGED | stage=preflight
negative: preflight-generation-absent | input=seed | tag=GENERATION-ABSENT | stage=preflight
mutants: stages= per-module=8 cap=40 kill-ratio=3/5
substrate: none
seed: predicates=clean-predicate,digest-equality-bypass,snapshot-freshness-bypass,bootstrap-path-bypass | custody=store-seed-roundtrip,store-receipt-roundtrip,store-tampered-receipt,tripwire-agent-shell,preflight-status-surface-dirty,preflight-verifier-diverged,preflight-generation-absent
```

### GenesisTrust pins

The following seven repository-relative local-custody inputs are the complete pinned file set. The byte count
and lowercase SHA-256 are part of the assumption. A missing, symlinked, non-regular, differently sized, or
differently hashed expected input refuses acquisition. Files not named by this pin set confer no authority.

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

- Admit certification generation 2 as the content address of the verifier, seeded by the human with
  [DL-0007](../documents/decision_log.md#dl-0007--certification-generation-2-replaces-the-validation-kernel),
  under the custody boundary in [§M.0](development_plan_gate_integrity.md#m0-accepted-baseline-and-certification-generation).
  Generation-1 stores are archived, never deleted, and supply no authority.
- Acquire one opaque `GenesisTrust` from exactly the seven pins and environment facts above, while making
  no publisher-authentication or reproducible-acquisition claim.
- Run the standalone documentation checker over the governed corpus and over a runner-rendered corpus of
  negatives; report zero findings on the corpus and the named finding on each negative.
- Reconcile the checker with the fifty-six-phase plan: the domain, tracker cardinality, identity-table
  cardinality, semantic registry, resource registry, and Phase 50's predecessor edge are derived from the
  compiled phase-identity table, so the expected findings recorded in
  [DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice) reach zero.
- Verify the frozen baseline and the decision-log structure; refuse a frozen body change without an entry.
- Run the clean bootstrap predicate and exactly three changed-source cases serially; clean must be silent
  and successful, while each mutant must return `ExitFailure 1`, empty stdout, and its exact case-label stderr.
- Observe the seven custody probes through their separately authored oracle: protected issuer success;
  old-generation refusal; forged receipt plus matching-copy refusal; candidate baseline replacement denial;
  authority-ancestor replacement denial; private issuer read denial; inherited-authority impersonation denial.
- Record the kernel hygiene row: line count at or below the ratchet, no conditional compilation, no `*Run*`
  module, no phase-number literal, one phase table, one definition per vocabulary type.
- Refuse issuance when agent environment markers are present; refuse `preview` from minting anything.
- Observe that the compiled legacy due-count for Phase 0 covers exactly the validator rows named in the
  `Legacy closure` cell below and nothing product-facing.
- Produce one complete qualified candidate whose required rows pass, then stop for the human's `accept`.

## Gate integrity

**Contract check**: BOUND — certification generation 2, the protected accepted baseline, the authenticated
phase receipt, and the closure-based compatibility decision are Haskell-owned inputs. Execution evidence
remains phase-local and cannot be supplied by this prose.

| Key | Contract |
|---|---|
| `Claim` | For one exact source snapshot, the standalone documentation checker reports zero findings on the governed corpus and the named finding on each rendered negative; the three bootstrap mutants are judged by the independent driver; the seven custody probes pass; the kernel hygiene row is green at the recorded ratchet; the generation-2 seed is content-addressed and human-issued. Toolchain reproducibility, source closure, product, and live-resource claims are excluded. |
| `Subject` | The documentation checker under `src/doc-check/**`, the gate-specification library under `src/gate-spec/**`, the plan-decisions library under `src/plan-decisions/**`, the retained custody core, and the runner under `src/validation-kernel/**`. No caller-authored snapshot, digest, row result, predecessor, or status projection can substitute for an acquired value. |
| `Command` | Future public spelling is `pb validate phase 00`, but `pb` is inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs the shipped verifier directly as `amoebius-validate preview phase 00`, which mints nothing; the human runs `sudo amoebius-validate accept --phase 00`. The seed hook compiles and runs the three-case predicate matrix serially with `-j1`. |
| `Oracle` | `test/oracle/doc/Main.hs` prints the expected finding ledger from literals and imports no product or validator module. Acquired `test/validation-kernel/BootstrapMutationDriver.hs` independently states the clean-plus-three predicate expectations. `Amoebius.Validation.SeedCustodyOracle.Internal` separately states the closed seven-case custody transcript without importing the supervisor's decision types. |
| `Positive controls` | The governed corpus; the clean predicate; the seven custody successes; a frozen baseline that matches the tree; a decision log whose entries are well-formed and strictly increasing. |
| `Paired negatives` | Rendered documentation negatives: broken link, stale backlink, missing status line, non-frontier status vector, unauthorised frozen edit, uncited module claim, gate-specification block mismatch, decision-log order. The three predicate mutants. The six custody refusals. Each is refused with its exact finding or case label at its exact locus. |
| `Mutants` | Runner-generated over `Amoebius.Doc.Check`, `Amoebius.Validation.Runner.Spec`, `Amoebius.Validation.Runner.Mutants`, and `Amoebius.Validation.Runner.Hygiene`, eight per module, kill ratio at least 0.6, stillborn excluded. The finite three-case predicate exception in §M.4 is retained as the only authored mutant set. |
| `Discovery` | The governed path inventory is compared two-way with the frozen baseline; the package description's stanza module map is compared two-way with the subjects named above; empty discovery refuses. |
| `Challenge` | The runner renders the negative corpus beneath `.build/docs/**` after the run starts, with a nonce in each negative's path; the checker's finding ledger must carry that nonce. |
| `Observer` | `ProcessObserver` over the checker, the predicate binaries, and the custody supervisor: executable identity, argv, complete output, and exit are runner-captured; no subject log is trusted. |
| `Authority/bypass` | No `sudo` path in `Dispatch`; the agent user identity cannot issue; the supervisor refuses when agent environment markers are present; `preview` cannot reach the issuer. Direct JSON forgery, candidate-selected baselines, replacement of authority-bearing ancestors, and private issuer reads must refuse. |
| `Freshness` | The verifier digest equals the seed's; opening and closing source identities are equal; the negative corpus is rendered fresh under a unique run root. |
| `Qualification` | The generated-mutant matrix over the modules above, plus the finite three-case predicate matrix, precede the clean candidate in the same run. |
| `Cleanroom` | All generated material lives beneath one unique `.build/runs/phase-00/**` leaf, which must be absent afterward; the kernel line count is recorded as the ratchet for the next accept. |
| `Legacy closure` | `LTD-VAL-001`, `LTD-VAL-002`, `LTD-VAL-003`, `LTD-VAL-004`, `LTD-VAL-006`, `LTD-KRN-001`, `LTD-KRN-002`, and `LTD-KRN-003` close here through the compiled inventory; the due-count for every other identifier is zero. The Markdown register is reader-facing only. |
| `Predecessor` | `genesis` means the explicit non-numbered `GenesisTrust`/`BootstrapRoot`; there is no prior numbered phase and no synthetic Phase -1 result. |
| `Residue` | Phase-1 toolchain provenance, Phase-2 source closure, every product claim, and every hardware claim remain explicit typed limitations outside this claim. |
| `Pass criterion` | `qualified-gate-pass` — every required Phase-0 row succeeds in one serial run for the same source and `GenesisTrust` identities, and the human's `accept` records it. |

## Doctrine adopted

- [`documentation_standards.md` §1 — philosophy](../documents/documentation_standards.md#1-philosophy) — one documentary authority, closed structural facts, and reconciled links.
- [`documentation_standards.md` §6 — honesty](../documents/documentation_standards.md#6-honesty-the-proventestedassumed-discipline) — the three-mood rule this checker enforces.
- [`documentation_standards.md` §17 — the doctrine freeze](../documents/documentation_standards.md#17-the-doctrine-freeze) — the frozen set and its baseline.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the typed specification every phase renders.
- [`gate_runner_doctrine.md` §6 — commands, generations, and receipts](../documents/engineering/gate_runner_doctrine.md#6-commands-generations-and-receipts) — `preview`, `accept`, `reset`, `govern`, `demo`, and reseed.
- [`repository_layout_doctrine.md` §1 — classification rule](../documents/engineering/repository_layout_doctrine.md#1-classification-rule) — Haskell behavioral source and the bounded `pb/**` exception.
- [`validation_frame_doctrine.md` §1 — native Haskell validation](../documents/engineering/validation_frame_doctrine.md#1-native-haskell-is-the-validation-environment) — the finite seed and explicit exclusions.
- [`testing_spoof_resistance.md` §12 — spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence) — independent expectations and changed-source witnesses.
- [`development_plan_gate_integrity.md` §M.3 — mutants must prove that they changed the subject](development_plan_gate_integrity.md#m3-mutants-must-prove-that-they-changed-the-subject) — runner-generated mutants and the kill ratio.

## Sprints

## Sprint 0.1: Governance surface 🔄

**Status**: Active — NOT VALIDATED
**Implementation**: `AGENTS.md`, `documents/decision_log.md`, `documents/documentation_standards.md`, `src/plan-decisions/Amoebius/Plan/Decisions.hs`, `src/plan-decisions/Amoebius/Plan/PhaseIdentity.hs`, `src/plan-decisions/Amoebius/Plan/Legacy.hs`, `src/validation-kernel/Amoebius/Validation/PolicyContract/Internal.hs`, and `src/validation-kernel/Amoebius/Validation/StatusFrontier.hs`
**Blocked by**: `genesis`
**Independent Validation**: The frozen baseline that matches the governed corpus, the ten seeded decision-log entries, the fifty-six-row phase-identity table, and the role-named policy contract are the positive control. A frozen body change without an entry, an entry with a reused identifier, a table with a gap-crossing predecessor, and an ordinal literal in the policy contract are paired negatives refused by name. Generated mutants in `Amoebius.Plan.Decisions` are killed by the doc-check oracle.
**Oracle**: `test/oracle/doc/Main.hs` states the expected baseline rows, entry identifiers, and table cardinality from literals; it imports no plan-decisions module.
**Legacy IDs**: none
**Docs to update**: `AGENTS.md`, `documents/documentation_standards.md`, and `documents/decision_log.md`

### Objective

Make the governance surface executable: one frozen set with a baseline, one decision log with a checked entry
contract, one phase-identity table that resolves every role by capability, and a status frontier that is aware
of the reserved gap.

### Deliverables

- `Amoebius.Plan.Decisions` with the frozen path list and baseline rows `(path, digest, DecisionId)`.
- `Amoebius.Plan.PhaseIdentity` with fifty-six rows and role resolution for `DSL_BARRIER`, `BOOTSTRAP_HANDOFF`, `HOST_ENSURE`, and `FIRST_HARDWARE`.
- `Amoebius.Plan.Legacy` with the closed `LegacyId` enumeration and owner-by-capability map, including the `LTD-KRN-*`, `LTD-DSL-*`, `LTD-LIB-*`, `LTD-UI-*`, and `LTD-HELPER-*` families.
- A policy contract that names roles, never ordinals.
- A status frontier that treats table position, not ordinal adjacency, as the predecessor relation.

### Validation

Compare independently authored expected baseline rows, entry identifiers, and table rows with the acquired
values. Refuse a one-row baseline change without an entry, a duplicate identifier, and an ordinal literal at
their exact loci.

### Remaining Work

The paired negatives named above are discharged only by the Phase-0 gate specification owed by
[Sprint 0.7](#sprint-07-phase-0-gate-specification-first-reseed-and-receipt-bearing-reset-); until the human's `accept`, the
plan-decisions projection and its oracle ledger are component diagnostics. The frozen baseline is re-projected
from the governed corpus in the same change that lands it, so the digest rows never lag the bytes they freeze.

## Sprint 0.2: Checker reconciliation ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/PhaseContract/Internal.hs`, `src/validation-kernel/Amoebius/Validation/PhaseSemanticContract.hs`, `src/validation-kernel/Amoebius/Validation/PhaseSemanticJoin.hs`, `src/validation-kernel/Amoebius/Validation/ResourceProvisionContract.hs`, `src/validation-kernel/Amoebius/Validation/PhasePassReceipt/Internal.hs`, `src/validation-kernel/Amoebius/Validation/Legacy/Internal.hs`, and `src/plan-decisions/Amoebius/Plan/PhaseIdentity.hs`
**Blocked by**: Sprint 0.1
**Independent Validation**: The reconciled checker reports zero findings over the fifty-six-phase plan; the expected findings recorded in [DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice) are the paired negatives, each reproduced by re-inserting one literal. A checker that still derives the domain from `0..95` is refused at the identity-table locus.
**Oracle**: `test/oracle/doc/Main.hs` states the expected finding set for the reconciled plan and for each re-inserted literal.
**Legacy IDs**: `LTD-VAL-002` — structural contract relation, owned here
**Docs to update**: `DEVELOPMENT_PLAN/development_plan_standards.md` and `DEVELOPMENT_PLAN/development_plan_phase_model.md`

### Objective

Derive every ordinal-bearing check from the compiled phase-identity table so that the reserved gap, the
fifty-six-row tracker, the semantic and resource registries, and Phase 50's predecessor edge are correct
without a literal.

### Deliverables

- Domain, tracker cardinality, identity cardinality, and predecessor adjacency derived from the table.
- The semantic and resource registries keyed by capability, with fifty-six slots each.
- The receipt domain upper bound derived from the table.

### Validation

Run the checker over the plan and require zero findings. Re-insert each retired literal in turn and require
the named finding at the named locus.

### Remaining Work

The forty phase-missing findings, the cardinality findings, and the Phase-50 edge finding are the
reconciliation target, and the checker must report zero findings over the plan before the Phase-0 gate can
run. Two residues are deliberate: the generation-1 semantic registry keeps its per-slot requirement values as
placeholders for the slice phases and for the rows DL-0008 resolved by decision, and the kernel's own component
suites that pinned the retired literals stay red. Both are deleted, not re-authored, by
[Sprint 0.6](#sprint-06-delete-pass-package-rewrite-and-executable-split-), because a typed second copy of the
plan is what [DL-0007](../documents/decision_log.md#dl-0007--certification-generation-2-replaces-the-validation-kernel)
retires.

## Sprint 0.3: Documentation checker extraction ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/doc-check/Amoebius/Doc/Check.hs`, `src/doc-check/Amoebius/Doc/Governance.hs`, `src/doc-check/Amoebius/Doc/Phase.hs`, `src/doc-check/Amoebius/Doc/Render.hs`, `src/doc-check/Amoebius/Doc/Types.hs`, `src/plan-decisions/Amoebius/Plan/StatusFrontier.hs`, and `app/amoebius-validate/Main.hs`
**Blocked by**: Sprint 0.2
**Independent Validation**: The standalone checker over the governed corpus is the positive control; each runner-rendered negative is a paired negative refused by its named finding. The new checks — decision-log structure, frozen baseline, three-mood honesty under the scope [DL-0011](../documents/decision_log.md#dl-0011--the-honesty-rule-scope-and-trigger) fixes, gate-specification block equality, and the status vector — each have a rendered negative judged by the oracle from its own literals; the paragraph-spanning sentence measurement stays an observation of the prose budget and has no negative. Generated mutants in `Amoebius.Doc.Check` are killed by the ledger.
**Oracle**: `test/oracle/doc/Main.hs`; it depends on no `amoebius` library.
**Legacy IDs**: none
**Docs to update**: `documents/documentation_standards.md`

### Objective

Move the documentation checker into a standalone package with no kernel import and no conditional
compilation, and add the governance checks
([DL-0005](../documents/decision_log.md#dl-0005--the-documentation-checker-is-a-standalone-package)).

### Deliverables

- `Amoebius.Doc.Check` with a recorded size cap and a non-zero exit on findings.
- `Amoebius.Doc.Render` rendering the negative corpus beneath `.build/docs/**`.
- `checkDecisionLog`, `checkFrozenDoctrine`, `checkHonestyCitations`, gate-specification block equality, and the status-vector check.

### Validation

Run the standalone checker over the corpus and over each rendered negative; require zero findings and the
named finding respectively. Refuse a checker that imports a validator module at the package-description locus.

### Remaining Work

The checker's recorded cap is seven thousand lines across `src/doc-check`, measured by the hygiene row owed by
[Sprint 0.4](#sprint-04-gate-specification-and-runner-core-); until that row exists the cap is a constant the
package states about itself. Gate-specification block equality compares against the blocks the corpus carries
until the gate-specification library of the same sprint supplies the compiled values. The generated-mutant
kill over the checker is the runner's, so this sprint's own evidence is the corpus ledger and the eight
negatives.

## Sprint 0.4: Gate specification and runner core ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec.hs`, `src/validation-kernel/Amoebius/Validation/Runner.hs`, `src/validation-kernel/Amoebius/Validation/Runner/Spec.hs`, `src/validation-kernel/Amoebius/Validation/Runner/Mutants.hs`, `src/validation-kernel/Amoebius/Validation/Runner/Binary.hs`, `src/validation-kernel/Amoebius/Validation/Runner/Observer.hs`, `src/validation-kernel/Amoebius/Validation/Runner/Hygiene.hs`, `src/validation-kernel/Amoebius/Validation/Runner/Capture.hs`, and `test/runner/Main.hs`
**Blocked by**: Sprint 0.3
**Independent Validation**: A specification whose subjects are inside the executable's closure verifies; a kernel subject, a non-seed specification without a `BinaryFact`, and an oracle stanza with a product dependency are refused by the smart constructor or `verifySpec` at their exact loci. A generated mutant that changes suite bytes is killed; a stillborn mutant is excluded, not counted.
**Oracle**: `test/oracle/runner/Main.hs` states the expected refusals, the sampled operator loci, and the kill table from literals.
**Legacy IDs**: `LTD-KRN-001` — per-phase runners replaced by the one runner
**Docs to update**: `documents/engineering/gate_runner_doctrine.md`

### Objective

Implement the gate-specification library and the generic runner specified by the
[gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md).

### Deliverables

- `GateSpec`, `ExactCase`, `MutantPolicy`, `BinaryFact`, `SpineFact`, and `Substrate` with smart constructors.
- `verifySpec`, the clean run, generated mutants, binary and spine perturbation, `ProcessObserver`, the hygiene row, and capture into the eighteen-row candidate.

### Validation

Verify a legal specification and refuse each illegal one by name. Apply each operator to a stage module copy
and require the oracle to refuse the changed bytes at the following stage.

### Remaining Work

The operator catalogue is fixed at delivery: constant flip, boundary shift, branch swap, field drop, and
list truncation, sampled by a seeded stream so a rerun draws the same loci. The runner's own suite
exercises the constructor refusals, verification against a fixture package description, the loci and the
witness, the kill table, the hygiene row over a fixture tree, and capture; the first rebuild-and-judge of a
generated mutant against a shipped module is owed by [Phase 1](phase_01_toolchain_spike.md), whose gate is
the first non-seed specification. Two rows stay red by construction until
[Sprint 0.6](#sprint-06-delete-pass-package-rewrite-and-executable-split-): the hygiene row, because the
generation-1 kernel is over budget and carries conditional compilation, and the authority row, because the
product executable still links the validator. A component diagnostic may run the stages past the hygiene
preflight to observe them; it cannot mint a green candidate while either row is red
([DL-0012](../documents/decision_log.md#dl-0012--the-hygiene-rows-roots-run-module-pattern-and-run-directory-convention)).

## Sprint 0.5: Custody core and human commands ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/Custody.hs`, `src/validation-kernel/Amoebius/Validation/Custody/Store.hs`, `src/validation-kernel/Amoebius/Validation/Custody/Status.hs`, `src/validation-kernel/Amoebius/Validation/Custody/Preflight.hs`, `src/validation-kernel/Amoebius/Validation/Compatibility.hs`, `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs`, and `app/amoebius-validate/Main.hs`
**Blocked by**: Sprint 0.4
**Independent Validation**: `preview` runs the complete gate and mints nothing; `accept` from the human account signs and applies exactly one phase's patch; each preflight refusal — `StatusSurfaceDirty`, `PredecessorNotCommitted`, `STATUS-WITHOUT-RECEIPT`, `KERNEL-VERIFIER-DIVERGED`, `GOVERNANCE-UNACCEPTED`, `HARDWARE-BEFORE-BARRIER`, `SUBSTRATE-ABSENT`, `KernelOverBudget`, `SPEC-WEAKENED` — is a paired negative. An agent environment marker refuses issuance. Closure-based chaining keeps a receipt across an edit outside the closure and reopens across an edit inside it.
**Oracle**: `src/validation-kernel/Amoebius/Validation/SeedCustodyOracle/Internal.hs` for the seven custody probes; `test/oracle/runner/Main.hs` for the refusals and chaining cases.
**Legacy IDs**: `LTD-VAL-003`, `LTD-VAL-004` — receipt authenticity and status authority, owned here
**Docs to update**: `documents/engineering/validation_frame_doctrine.md` and `documents/engineering/gate_runner_doctrine.md`

### Objective

Make every status transition a human act with a content-addressed generation behind it
([DL-0009](../documents/decision_log.md#dl-0009--status-authority-is-one-human-act-per-transition),
[DL-0010](../documents/decision_log.md#dl-0010--host-precondition-for-agent-sessions)).

### Deliverables

- Content-addressed generations, reseed with a decision identifier, and archived prior stores.
- The agent command `preview` and the human commands `accept`, `reset`, `govern`, and `demo`.
- The preflight refusals, closure-based predecessor chaining, and refresh as an identity projection.
- Receipt fields: verifier digest, governance digest, `SubjectChangeWitness`, `ResetCause`, `OperatorDemonstration`.

### Validation

Run each command from the agent identity and the human identity; require the specified success or refusal.
Edit a file outside and then inside the predecessor closure and require the receipt to survive and then reopen.

### Remaining Work

The generation-2 custody core is new code beside the generation-1 modules rather than an edit of them: the
store, the signed seed and receipt records, the status surface and its one-phase patch, the preflight
decision as a pure function of gathered facts, and the closure digest. The generation-1 supervisor, its
receipt format, and the protected mirror are retired with the delete pass of
[Sprint 0.6](#sprint-06-delete-pass-package-rewrite-and-executable-split-). Three things wait on later
sprints or the human: the issuer key and the first generation exist only after the human's reseed; `accept`
runs the gate through the registry, which carries no specification until
[Sprint 0.7](#sprint-07-phase-0-gate-specification-first-reseed-and-receipt-bearing-reset-); and the
frozen-document findings the doc-check reports are folded into `GOVERNANCE-UNACCEPTED` once the verifier
links the checker's ledger into the preflight facts. `accept` runs the gate as the user who invoked sudo, never as
root, with that user's home and the tool paths named by `--cabal` and `--ghc`, and only the signing and the
status patch happen with privilege. An accepted phase also turns every paragraph that said
it was owed by that phase into an honesty finding, so the agent's next act after a human `accept` is to
re-mood those paragraphs as observed implementations citing the new receipt, under a decision-log entry
where the paragraph is frozen.

## Sprint 0.6: Delete pass, package rewrite, and executable split ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `amoebius.cabal`, `app/amoebius/Main.hs`, `app/amoebius-validate/Main.hs`, `test/runner/Main.hs`, and the flag-free compile-fail twins beside their legal suites
**Blocked by**: Sprint 0.5
**Independent Validation**: After the pass, the kernel line count is at or below fourteen thousand, no conditional-compilation line remains under `src/`, `app/`, or `test/`, no `*Run*` module remains, the package description declares at most twenty flags, and the product executable's closure contains no validator module. Each is a paired negative reproduced by re-inserting one artefact. The unprotected component suite passes after every family deletion.
**Oracle**: `test/oracle/runner/Main.hs` states the expected hygiene row and closure from literals.
**Legacy IDs**: `LTD-KRN-002`, `LTD-KRN-003`, `LTD-VAL-001`, `LTD-VAL-006` — authored mutant seams, the fake solver as a decision procedure, harness self-measurement, and stale-input acceptance, all owned here
**Docs to update**: `documents/engineering/repository_layout_doctrine.md` and `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`

### Objective

Delete the validator families the runner replaces, one family per serial build, and split the product from
the verifier.

### Deliverables

- Removal of the per-phase runners, the compiler-subject family, the legacy-oracle family, the semantic-contract family, the consumer-graph family, the bootstrap-grammar family, the sabotage corpus, the opacity-attack suites, and every authored conditional-compilation mutant seam.
- A package description of roughly sixty libraries, two executables, and at most twenty flags.
- `amoebius validate` delegating by `exec` to `amoebius-validate`, so `pb` and its pin are untouched.
- A package-description test that refuses any product-to-validator dependency edge.

### Validation

After each family deletion, build serially with `--jobs=1` and run the unprotected component suite. At the
end, require the hygiene row and the closure test to pass.

### Remaining Work

No receipt is issued during the pass. The kernel that remains is the generation-2 custody core, the runner,
and the three-module seed vocabulary; every generation-1 family, its authored mutant seams, and its four
hundred suites are gone, and the package description declares no flag. Two residues are recorded rather than
hidden: the flag-selected compile-fail twins are rendered as flag-free Haskell files beside their legal
suites, and their compilation-failure judgement is owed by [Phase 3](phase_03_typed_spine.md) with the
compile-fail facility it folds in; and the product components that were never buildable before the pass —
the Pulsar client and the fifteen components that link it, which need the lazily generated transport module
— stay unbuilt until [Phase 1](phase_01_toolchain_spike.md) derives that input. Packaging defects the pass
surfaced in never-built product stanzas are repaired in the package description as declared dependencies
and listed modules, never as source changes.

## Sprint 0.7: Phase-0 gate specification, first reseed, and receipt-bearing reset ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Seed.hs`, `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs`, `src/validation-kernel/Amoebius/Validation/BootstrapQualification/Internal.hs`, `src/validation-kernel/Amoebius/Validation/Runner.hs`, and `test/validation-kernel/BootstrapMutationDriver.hs`
**Blocked by**: Sprint 0.6
**Independent Validation**: The Phase-0 specification verifies and its fenced block equals the compiled value; the human's reseed installs generation 2 at the verifier's content address; the receipt-bearing reset names `ResetCause { validatorGap = "gates measured the harness", productGap = LTD-DSL-001 }`; a reset without a product gap is refused while any `LTD-DSL-*` row is open. The three predicate cases retain their exact exits and streams.
**Oracle**: `test/validation-kernel/BootstrapMutationDriver.hs` for the predicate matrix; `test/oracle/runner/Main.hs` for the specification and reset cases.
**Legacy IDs**: none due here beyond the closures recorded above
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through the human's `accept`

### Objective

Author the first generation-2 specification, have the human seed generation 2, and record the reset that
starts the frontier at this phase.

### Deliverables

- The Phase-0 `GateSpec` with `gateSeed` present and no `BinaryFact`.
- The human's reseed with `--decision DL-0007`.
- The human's reset with `--decision DL-0008 --product-gap LTD-DSL-001`.
- The complete Phase-0 candidate ready for `accept`.

### Validation

Run `preview phase 00` from the agent identity and require every row green; run `accept` from the human
identity and require exactly one phase's patch.

### Remaining Work

The seed protocol is generated, never authored: each bypass is one complete-line rewrite of the predicate
source applied to a fresh copy beneath the run root, compiled directly with the pinned compiler together with
the independent driver, and run under the observer; the driver refuses with the case label alone. The seed
role is the one role whose subjects are validator modules and whose closure is the verifier executable's,
because the phase validates the validator's seed and no product binary exists yet. The specification joins
the registry under its capability, and the fenced block in this document equals its rendering. Two acts
remain the human's: the reseed that installs generation 2 at the verifier's content address with the issuer
key beside it, and the reset and `accept` that follow. The agent runs `preview phase 00` and stops.

## Documentation Requirements

**Engineering docs to update when their governed boundary changes:**

- `documents/documentation_standards.md` — only if governed document mechanics change.
- `documents/engineering/gate_runner_doctrine.md` — only if the runner's vocabulary, refusals, or commands change.
- `documents/engineering/repository_layout_doctrine.md` — only if the finite source boundary changes.
- `documents/engineering/validation_frame_doctrine.md` — only if `GenesisTrust` or the host precondition changes.

**Cross-references to add:**

- Actual inbound links discovered by the Haskell link-graph checker, reconciled in the same change.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 1 toolchain spike](phase_01_toolchain_spike.md) — authenticated reproducible acquisition after the seed
- [Phase 2 repository layout conformance](phase_02_repository_layout_conformance.md) — source closure
- [Phase 3 typed spine](phase_03_typed_spine.md) — the first product specification
- [Development-plan standards](development_plan_standards.md)
- [Canonical phase model](development_plan_phase_model.md)
- [Gate integrity](development_plan_gate_integrity.md)
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [Decision log](../documents/decision_log.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
- [Validation-frame doctrine](../documents/engineering/validation_frame_doctrine.md)
- [Repository-layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
- [Behavioural verification doctrine](../documents/engineering/behavioural_verification_doctrine.md) — a verdict never rests on how a subject presents itself
