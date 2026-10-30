# Gate-Runner Doctrine

> **Purpose**: Specify the one generic gate runner that judges every numbered phase, the gate specification it consumes, and the commands through which a reproducible result becomes status.
> **Read this if**: a phase gate must be specified, the validator's mechanics must be changed, or the boundary between `preview`, `accept`, and `replay` must be settled.

This document owns the validator's mechanics: the gate-specification vocabulary, the runner, the oracle
protocol, preflight refusals, commands, and receipts. It does not own the eighteen-row contract shape, which
belongs to [gate integrity §M.1](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md#m1-the-fixed-gate-contract),
nor bootstrap trust, which belongs to the
[validation-frame doctrine](./validation_frame_doctrine.md). Qualification is phase-scoped: the finite
seed retains its accepted boundary. The repaired
[Phase-1 observations](../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md#phase-status) establish the bounded
toolchain product qualification at its recorded source, verifier and governance; they establish no later
source-closure, DSL-spine or hardware claim. The earlier contaminated matrix remains historical evidence,
and DL-0037's unmodified-control rule remains normative ([DL-0038](../decision_log.md#dl-0038--a-qualified-repaired-toolchain-pass-retires-its-three-bindings)).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: documents/engineering/conformance_harness_doctrine.md
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_typed_spine.md, DEVELOPMENT_PLAN/phase_04_witness_manifests_capacity_storage.md, DEVELOPMENT_PLAN/phase_05_substrates_lanes_image_recipe.md, DEVELOPMENT_PLAN/phase_06_extension_admission_attested_scope.md, DEVELOPMENT_PLAN/phase_07_child_clusters_obligation_teardown.md, DEVELOPMENT_PLAN/phase_08_ui_program_language_binding.md, DEVELOPMENT_PLAN/phase_09_dsl_barrier.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/system_components.md, documents/decision_log.md, documents/engineering/README.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/validation_frame_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md, documents/reading_order.md
**Generated sections**: none

</details>

## Contents

- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. The gate-specification vocabulary](#2-the-gate-specification-vocabulary)
- [3. The runner](#3-the-runner)
- [4. Runner-held verdicts and the oracle protocol](#4-runner-held-verdicts-and-the-oracle-protocol)
- [5. Preflight refusals and predecessor chaining](#5-preflight-refusals-and-predecessor-chaining)
- [6. Commands, generations, and receipts](#6-commands-generations-and-receipts)
- [7. The example corpus and the hardware rule](#7-the-example-corpus-and-the-hardware-rule)
- [8. What the runner does not prove](#8-what-the-runner-does-not-prove)
- [9. Planning ownership](#9-planning-ownership)
- [Related Documents](#related-documents)

## 1. Why this doctrine exists

**The problem.** A validator that judges a product by running the validator's own suites measures itself.
Six validation cycles reached a hardware-ready gate with a green barrier whose bind stage was hand-built from
a challenge string, whose mutants all lived in the checker, and whose verdicts were substring matches on the
suites' own output. No DSL value reached bytes, and status authority sat with whichever process ran the
validator. The defect surfaced only at each reset, after hardware work had been scheduled on its evidence
([DL-0007](../decision_log.md#dl-0007--certification-generation-2-replaces-the-validation-kernel)).

**Why the obvious alternative fails.** Hardening the same kernel again adds rows, selectors, and sabotage
corpora to the validator, which grows it without changing what it measures. A per-phase runner can always
re-derive the eighteen rows from its own suite, because nothing outside that runner supplies the subject, the
input, or the verdict.

**The rule.** A gate is green only when the shipped product binary, fed an input the runner perturbed after
the run started, produces bytes that an independent oracle executable accepts, and when runner-generated
mutants in shipped modules change those bytes. One generic runner consumes one typed `GateSpec` per phase;
no phase has a runner of its own, and the runner holds every verdict.

**What it forecloses.** A green gate for a stage that has not been wired into the shipped binary, a
validator-only test corpus counting as product coverage, and a self-authored ledger counting as an
observation. It also forecloses a validator large enough to hide any of those: the kernel budget in
[§3](#3-the-runner) is a line count, not a review.

## 2. The gate-specification vocabulary

A `GateSpec` is a Haskell value in the gate-specification library, which depends on nothing beyond the base
libraries. Its fields are:

| Field | Meaning |
|---|---|
| `ProductionModule` | A module inside the transitive closure of the shipped `amoebius` executable. A validator module is refused by the smart constructor. |
| `OracleExecutable` | The separate oracle executable for the area, with no dependency on any product or validator library. |
| `CabalTarget` | The suite that writes bytes for the oracle to judge. |
| `ExactCase` | One positive control or paired negative: its input, the exact tag and stage of the expected refusal, or the expected manifest delta. |
| `MutantPolicy` | `stageModules`, `perModule = 8`, `perGateCap = 40`, `killRatio = 0.6`. Stillborn mutants that fail to compile are excluded from the ratio. |
| `BinaryFact` | A public `amoebius` command, the perturbation the runner applies to its input, and the output files the runner digests. Mandatory for every non-seed specification. |
| `SpineFact` | The rendered example file, the ordered stages, and the applied-digest file that must equal the render digest. Mandatory for the `DSL_BARRIER` specification. |
| `Substrate` | `HardwareFree` or one catalog member; a hardware token is refused before the barrier receipt exists. |
| `gateSeed` | `Maybe SeedSpec`; present only for the finite Phase-0 bootstrap seed. |

The smart constructors refuse a kernel subject, a non-seed specification without a `BinaryFact`, and a
barrier specification without a `SpineFact`. A phase document renders its specification in a fenced
`gate-spec` block; the documentation checker compares that block with the compiled value, so a phase cannot
describe a gate the runner will not execute.

## 3. The runner

**Qualification boundary** ([DL-0034](../decision_log.md#dl-0034--phase-0-acceptance-qualifies-the-finite-seed-boundary)).

The generic runner must execute the finite seed protocol, collect the source-bound legacy qualifications
serially, capture all eighteen gate rows and verify owned-root cleanup at the accepted kernel ratchet.
[Phase 0](../../DEVELOPMENT_PLAN/phase_00_documentation_suite.md#sprint-04-gate-specification-and-runner-core-) owns
this finite boundary; a component observation or historical receipt cannot establish its current pass
([DL-0039](../decision_log.md#dl-0039--recursive-custody-preserves-accepted-completed-prefixes)).

The toolchain gate must run a complete green unmodified control through the same matrix context, retain
its source guard and every raw process observation in `candidate.tsv` at `matrix.control.raw`, and grant
no generated-mutant kill if that control is red or mismatched. Its fixed policy selects at most forty
changed-subject loci over the six shipped subjects, requires at least three fifths of viable mutants killed
and a named product kill in every subject, and retains stillborn and surviving outcomes. The separate
clean oracle must contain the complete control-row inventory plus all four shipped-binary checks, with
every required row green. [Phase 1](../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md#phase-status)
owns the complete toolchain gate and links its immutable historical candidate and `oracle-ledger.tsv`;
those observations do not establish a pass at a changed source or governance baseline
([DL-0039](../decision_log.md#dl-0039--recursive-custody-preserves-accepted-completed-prefixes)).

The accepted historical records contain actual offline install repository/local-plan and child observations, selected
version/source hash, copied-cache hashes, owned-project input and executable-byte checks. The codegen
records contain the actual child and streams, schema and complete generated bytes, with independent
process, argv, module, field, tag and lens checks. The oracle inspected physical archive, executable and
generated-output bytes during the run; owned cleanup removed them afterward. The archive retains the
observations and embedded bytes, not those deleted physical artifacts. These bounded implementation
observations require fresh numerical replay after the lifecycle/governance amendment ([DL-0038](../decision_log.md#dl-0038--a-qualified-repaired-toolchain-pass-retires-its-three-bindings)).

The following ordered stages define the product-gate protocol. Qualification remains bounded to each
accepted subject and source; spine perturbation
retains its [DSL-barrier owner](../../DEVELOPMENT_PLAN/phase_09_dsl_barrier.md):

1. **`verifySpec`.** Map every `ProductionModule` to exactly one library stanza, compute the executable's
   closure from the package description, and refuse any subject outside it. Check the oracle stanza's hygiene:
   no product or validator dependency, no conditional compilation, no Template Haskell, no foreign imports.
2. **Clean run.** Build the suite serially and run it under a `ProcessObserver`, capturing argv, environment
   policy, exit, and complete output. The suite writes bytes; it prints no verdict.
3. **Generated mutants.** Apply operators from a fixed catalogue (constant flip, boundary shift, branch swap,
   field drop, list truncation) with deterministic sampling to copies of the stage modules beneath
   `.build/runs/**`, rebuild serially, and rerun. First require an unmodified source control with a complete
   green ledger under the same matrix context and admitted output-root policy. A mutant is killed when the
   oracle refuses its changed bytes at the following stage while unrelated controls remain green; context
   failure supplies no kill. The control observations and kill table are part of the receipt
   ([DL-0037](../decision_log.md#dl-0037--an-unmodified-matrix-control-prevents-harness-only-kills)).
4. **Binary and spine perturbation.** Rewrite the `BinaryFact` input (sentinel to nonce, replica count
   changed), run the public command through the shipped binary, and recover the nonce from every declared
   output. For a `SpineFact`, rewrite the rendered example and require the fake-applied digest to equal the
   render digest.
5. **Hygiene row.** Record the kernel line count and refuse when it exceeds the smaller of fourteen thousand
   and the last accepted count; refuse any conditional-compilation line, any per-phase run module (a path
   segment ending in `Run`; the generic runner is not one), any phase-number literal, or a second phase table
   in the kernel; refuse a second definition of any vocabulary type inside the validator roots and observe
   duplicates elsewhere under `src/` as debt owed to the vocabulary library's phase
   ([DL-0012](../decision_log.md#dl-0012--the-hygiene-rows-roots-run-module-pattern-and-run-directory-convention)).
6. **Capture.** Fill the eighteen-row candidate from the observations above; no row is caller-supplied.

The kernel budget covers the runner, the gate-specification library, and the retained custody core together:
every Haskell line under `src/validation-kernel` and `src/gate-spec`. The documentation checker under
`src/doc-check` carries its own recorded cap. The count only ratchets down once accepted.

## 4. Runner-held verdicts and the oracle protocol

**Qualification boundary** ([DL-0034](../decision_log.md#dl-0034--phase-0-acceptance-qualifies-the-finite-seed-boundary)).

The finite seed execution must bind observed subject exits, complete raw oracle ledgers, nonzero
missing-output rejection, complete required-row discovery and all finite custody controls. Its required
boundary is [Phase 0](../../DEVELOPMENT_PLAN/phase_00_documentation_suite.md#gate-integrity); these
requirements remain in force while its custody repair is qualified
([DL-0039](../decision_log.md#dl-0039--recursive-custody-preserves-accepted-completed-prefixes)).

The source audit behind [DL-0041](../decision_log.md#dl-0041--runner-authority-reopens-for-image-and-oracle-completion-witnesses) reopens the existing
runner-authority binding at Phase 0: the actual seed and ordinary matrices lack rebuilt subject-image
byte-change witnesses, and complete oracle rows alone do not establish normal completion. Their
recorded green results remain historical observations, not current qualification of these missing
boundaries. Existing M.3/M.4 requirements, normal semantic-red exits, complete independent ledgers,
source admission, same-context controls and numeric order remain. Actual executed suite-linked
product images may carry the required witness; a source-only hash, executable path or clean main
BinaryFact cannot supply a numbered mutant's missing image. The finite supplied/fake claim adds
no external OS supervisor, hardware prerequisite or claim of hostile-host lifetime enforcement.

The toolchain gate must exercise its separate oracle, require the missing-output probe to exit nonzero,
retain the complete raw control ledger, discover every required oracle row and observe runner-generated
changed-subject mutants. Its unmodified control must use the same matrix context and admitted output roots
so unrelated suite-output contamination cannot count as a product refusal or mutant kill. The accepted
`candidate.tsv` must retain control observations and name their complete green ledger; the separate clean
`oracle-ledger.tsv` must judge every shipped-binary check. [Phase 1](../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md#phase-status)
owns this gate; its historical observations, later-owned scope and the normative unmodified-control rule
retain their limits ([DL-0038](../decision_log.md#dl-0038--a-qualified-repaired-toolchain-pass-retires-its-three-bindings),
[DL-0039](../decision_log.md#dl-0039--recursive-custody-preserves-accepted-completed-prefixes)).

A suite must produce bytes. Its area's separately authored oracle executable must judge them from literals
in its own source, with no product import or regenerated expectation. Each area must have one exclusive
source directory and a named entry module; naming the directory alone is insufficient. The suite must
receive one run-local directory argument and write its observations there.
The oracle must receive that same directory and print its ledger to standard output. The runner must bind
the suite output, oracle ledger and kill table into the receipt. A `PASS` token, count or matching substring
in suite output must never supply a verdict. Every subsequent product gate must qualify this protocol for
its own subjects and independently authored expectations.

Oracle rows are authored from the requirement before the pipeline stage exists. A row derived from subject
output, or added after a stage was written to match it, is a contract change under
[gate integrity §M.2](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md#m2-oracle-independence).

## 5. Preflight refusals and predecessor chaining

Before any subject runs, the runner refuses with a typed reason when:

| Refusal | Condition |
|---|---|
| `StatusSurfaceDirty` | The tracker, phase, or sprint status surface differs from the postimage of the last accepted receipt. |
| `PredecessorNotCommitted` | The predecessor lacks current-source ancestry or an admissible exact-read publication binding under the whole-postimage and completed-prefix rule below; its complete gate must still re-derive under current verifier and governance digests ([DL-0039](../decision_log.md#dl-0039--recursive-custody-preserves-accepted-completed-prefixes)). |
| `STATUS-WITHOUT-RECEIPT` | A status line is Done without a receipt digest beside it in the phase document. |
| `PredecessorNotReproduced` | A Done phase's recorded digest has no valid tracked current bundle for the current verifier and governance digests, or exact-read, artifact, predecessor, compatibility, or void-marker checks fail. A red replay writes an immutable void marker and the Done predecessor cannot advance the next gate until a later green replay or explicit reset ([DL-0019](../decision_log.md#dl-0019--red-replay-leaves-an-immutable-revocation-record)). |
| `HARDWARE-BEFORE-BARRIER` | The specification names a hardware substrate and no `DSL_BARRIER` receipt exists. |
| `SUBSTRATE-ABSENT` | The declared substrate is not the host's natural substrate. |
| `KernelOverBudget` | The hygiene row would fail. |
| `SPEC-WEAKENED` | The specification drops a case, a stage module, or a fact that the last accepted specification carried. |

Predecessor binding is the digest of the predecessor's product closure plus the verifier and governance
digests. An edit outside that closure keeps the predecessor receipt valid; an edit inside it reopens the
predecessor. A receipt refresh is an identity projection that cannot weaken a specification.
For same-worktree uncommitted predecessors, the latest uniquely selected, exact-read current-generation
publication's whole-status postimage must equal the entire current status surface. Each recursively used
predecessor must either retain that exact whole postimage or carry its own accepted-completed-prefix digest
matching the current canonical tracker, phase, sprint and receipt rows through its own Done phase. Only
publication computes that optional digest, from its exact-read, structurally consistent postimage after the
verified status patch; the full postimage remains recorded. Later Done phases may change the whole surface
without changing an earlier completed prefix. A changed earlier receipt invalidates a later prefix.

The verifier still requires the current selected non-reset, non-void receipt, source ancestry, exact archive
and canonical format, current verifier/governance/specification compatibility and the accepted closure
re-derived from current source. It runs the complete predecessor gate again before creating an opaque
source-bound pass. Neither prefix metadata nor a matching closure creates that pass. Legacy receipts
without the optional prefix retain only committed-ancestry or exact-whole-postimage admission, and their
archived bytes remain unchanged. The human commit makes the series durable; it is not an intermediate gate
([DL-0039](../decision_log.md#dl-0039--recursive-custody-preserves-accepted-completed-prefixes),
[DL-0016](../decision_log.md#dl-0016--acceptance-and-replay-publish-the-archive-with-the-status-projection)).

## 6. Commands, generations, and receipts

Every command is agent-run; none requires a privilege the agent lacks
([DL-0013](../decision_log.md#dl-0013--validation-authority-is-mechanical-and-receipts-are-reproducible)). They are:

- `amoebius-validate preview phase NN` — runs the complete gate, prints the would-be receipt, and mints
  nothing;
- `amoebius-validate accept --phase NN` — runs the complete gate again and, when every row is green, prints
  the Claim, specification digest, kill table, spine outcome, and corpus delta, applies exactly one phase's
  status patch and receipt line, and publishes the immutable accepted bundle against that status postimage;
- `amoebius-validate replay [--through NN]` — re-runs each Done phase in table order whose tracked bundle is
  absent, malformed, incompatible, or recorded under another verifier or governance digest; a green re-run
  publishes a new immutable bundle and refreshes the digest beside Done status as an identity status
  projection, then re-acquires that status before the next phase; a red re-run appends a void marker for the
  current bundle and makes it and dependent later receipts unusable while the Done line awaits green replay
  or explicit reset ([DL-0019](../decision_log.md#dl-0019--red-replay-leaves-an-immutable-revocation-record));
- `amoebius-validate reset --decision DL-NNNN --product-gap LTD-XXX-NNN` — records a receipt-bearing reset
  whose `ResetCause` names a validator gap and a product-gap legacy identifier with an owning phase, and moves
  the frontier no higher than that phase;
- `amoebius-validate demo --file <path>` — records the digest of an operator-authored input for the barrier's
  `OperatorDemonstration`.

A generation identifier is the content address of the verifier; a generation is entered by the first
`accept` or `replay` under that verifier. The canonical accepted store is the tracked archive
`validation-records/generation-<verifier16>/receipts/phase-NN-<reproducible64>-<bundle64>/`; any
`.build/certification/**` copy is a disposable cache. The exact allowed files are `receipt.tsv`,
`receipt.tsv.sha256`, `candidate.tsv`, `kill-table.tsv`, `outcome.tsv`, `oracle-ledger.tsv`, and
`observer.tsv`. The bundle digest names the final exact receipt and evidence bytes, allowing separate
immutable directories for distinct runs with the same reproducible digest. The first two files identify and
checksum the receipt; the others retain the bounded ordered gate
results, independent oracle ledger, changed-subject mutant witnesses, and observed process digests needed to
inspect the run. The archive is non-source historical evidence and cannot supply an oracle or current verdict.
A governance change needs no separate act: the governance digest is part of every reproducible digest, so
receipts recorded under an older baseline fail to reproduce until replayed
([DL-0015](../decision_log.md#dl-0015--accepted-validation-records-are-tracked-historical-evidence)).

A red replay publishes one immutable marker at
`validation-records/generation-<verifier16>/voids/phase-NN-<targetBundle64>-<void64>.tsv`. Its canonical
bytes bind the target bundle path, phase, old reproducible digest, current verifier and governance digests,
failure observation digest and reason, and issuance time; `void64` hashes those bytes. The archive reader
selects the unique latest `receiptIssuedAt` bundle for each phase in the current generation before applying
void markers. Reader/preflight refuses ties or a replay bundle whose issuance is not newer than the current
bundle; it cannot become the current pointer. A marker for the
selected bundle prevents fallback to any older same-digest bundle. A later green replay creates a distinct
bundle with later issuance and becomes current even if the receipt digest remains unchanged
([DL-0019](../decision_log.md#dl-0019--red-replay-leaves-an-immutable-revocation-record)).

A receipt carries the reproducible digest (specification digest, closure digest, verifier digest, governance
digest, ordered row verdicts, oracle ledger digest, kill-table loci and outcomes), the run-specific chain of
observed process digests, the `SubjectChangeWitness` for every mutant, the `ResetCause` when it is a reset,
the `OperatorDemonstration` when it is the barrier, the whole-status postimage, and optionally its own
accepted-completed-prefix digest ([DL-0039](../decision_log.md#dl-0039--recursive-custody-preserves-accepted-completed-prefixes)).
Its authority is that any run can re-derive it by re-running the gate, not that anyone signed it.

Candidate execution and `preview` leave the tracked tree unchanged. Only after the verified pass and status
postimage may `accept` or green `replay` publish the closed archive bundle; red `replay` may append its exact
void marker after the failed gate without editing Done status. The verifier exact-reads every required
file and refuses missing, altered, extra, ambiguous, or mismatched records before relying on a predecessor.
Publication never replaces an older bundle. The phase status and archive are one reviewable worktree change;
the human commits them together for durability. A later phase in the same worktree may use the just-produced
bundle before that commit only after the full current predecessor gate re-derives its result and binds the
exact archive, status postimage, and accepted closure. If the ignored scratch store was lost, the old receipt digest cannot
reconstruct observations: fresh gates in numerical order produce new receipts
([DL-0016](../decision_log.md#dl-0016--acceptance-and-replay-publish-the-archive-with-the-status-projection)).

## 7. The example corpus and the hardware rule

The examples a gate consumes are Haskell values in the corpus modules linked by the shipped executable, as
specified in [testing doctrine §9](./testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation).
A phase's corpus contains its predecessor's corpus; the `DSL_BARRIER` re-runs the union.

Every hardware specification binds the `DSL_BARRIER` receipt digest and runs a corpus command through its own
subject. Hardware evidence that does not consume a barrier example is refused as
`HARDWARE-BEFORE-BARRIER`.

## 8. What the runner does not prove

- Oracle authorship independence. The build graph proves the oracle imports no product module; it cannot
  detect product code copied into an oracle. Authorship stays a human boundary, mitigated by authoring rows
  before stages.
- Coverage by generated mutants. A killed sample is evidence about the sampled operators at the sampled
  loci; a stillborn mutant is excluded, not counted.
- Toolchain provenance, which belongs to [Phase 1](../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md), and
  source closure, which belongs to
  [Phase 2](../../DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md).

## 9. Planning ownership

The finite seed qualification obligation belongs to [Phase 0](../../DEVELOPMENT_PLAN/phase_00_documentation_suite.md).
The first product-gate qualification belongs to [Phase 1](../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md);
the typed DSL spine belongs to [Phase 3](../../DEVELOPMENT_PLAN/phase_03_typed_spine.md). The `SpineFact`
and `OperatorDemonstration` retain [Phase 9](../../DEVELOPMENT_PLAN/phase_09_dsl_barrier.md) as their owner.

## Related Documents

- [Gate integrity](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md) — the eighteen-row contract this runner fills
- [Validation-frame doctrine](./validation_frame_doctrine.md) — bootstrap trust and native execution
- [Testing spoof resistance](./testing_spoof_resistance.md) — the threat model the refusals answer
- [Testing doctrine](./testing_doctrine.md) — registers and the example corpus
- [Conformance harness doctrine](./conformance_harness_doctrine.md) — superseded by this document
- [Decision log](../decision_log.md) — DL-0007, DL-0009, DL-0012, DL-0013
