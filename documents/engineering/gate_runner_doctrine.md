# Gate-Runner Doctrine

> **Purpose**: Specify the one generic gate runner that judges every numbered phase, the gate specification it consumes, and the human commands through which a result becomes status.
> **Read this if**: a phase gate must be specified, the validator's mechanics must be changed, or the boundary between an agent's `preview` and the human's `accept` must be settled.

This document owns the validator's mechanics: the gate-specification vocabulary, the runner, the oracle
protocol, preflight refusals, commands, and receipts. It does not own the eighteen-row contract shape, which
belongs to [gate integrity §M.1](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md#m1-the-fixed-gate-contract),
nor bootstrap trust, which belongs to the
[validation-frame doctrine](./validation_frame_doctrine.md). Every mechanism below is owed by
[Phase 0](../../DEVELOPMENT_PLAN/phase_00_documentation_suite.md); nothing here is an observed result.

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

The runner is one library, `Amoebius.Validation.Runner`, with these stages in order:

1. **`verifySpec`.** Map every `ProductionModule` to exactly one library stanza, compute the executable's
   closure from the package description, and refuse any subject outside it. Check the oracle stanza's hygiene:
   no product or validator dependency, no conditional compilation, no Template Haskell, no foreign imports.
2. **Clean run.** Build the suite serially and run it under a `ProcessObserver`, capturing argv, environment
   policy, exit, and complete output. The suite writes bytes; it prints no verdict.
3. **Generated mutants.** Apply operators from a fixed catalogue (constant flip, boundary shift, branch swap,
   field drop, list truncation) with deterministic sampling to copies of the stage modules beneath
   `.build/runs/**`, rebuild serially, and rerun. A mutant is killed when the oracle refuses its bytes at the
   following stage. The kill table is part of the receipt.
4. **Binary and spine perturbation.** Rewrite the `BinaryFact` input (sentinel to nonce, replica count
   changed), run the public command through the shipped binary, and recover the nonce from every declared
   output. For a `SpineFact`, rewrite the rendered example and require the fake-applied digest to equal the
   render digest.
5. **Hygiene row.** Record the kernel line count and refuse when it exceeds the smaller of fourteen thousand
   and the last accepted count; refuse any conditional-compilation line, any `*Run*` module, any phase-number
   literal, or a second phase table in the kernel; refuse a second definition of any vocabulary type.
6. **Capture.** Fill the eighteen-row candidate from the observations above; no row is caller-supplied.

The kernel budget covers the runner, the gate-specification library, and the retained custody core together.
The count only ratchets down once accepted.

## 4. Runner-held verdicts and the oracle protocol

A suite is a byte producer. The oracle executable for an area reads those bytes and prints a ledger derived
from literals in its own source; it imports no product module, so it cannot regenerate an expectation from
the subject. Each area has one exclusive source directory whose entry module is named exactly, for example
`test/oracle/dsl/Main.hs`; the directory is never named alone. The runner digests the suite output, the
oracle ledger, and the kill table into the receipt. A `PASS` token, a count, or a matching substring in a
suite's output is not a verdict.

Oracle rows are authored from the requirement before the pipeline stage exists. A row derived from subject
output, or added after a stage was written to match it, is a contract change under
[gate integrity §M.2](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md#m2-oracle-independence).

## 5. Preflight refusals and predecessor chaining

Before any subject runs, the runner refuses with a typed reason when:

| Refusal | Condition |
|---|---|
| `StatusSurfaceDirty` | The tracker, phase, or sprint status surface differs from the postimage of the last accepted receipt. |
| `PredecessorNotCommitted` | The immediate predecessor's receipt names a postimage that is not an ancestor of the current tree. |
| `STATUS-WITHOUT-RECEIPT` | A status line is Done without a receipt in the current generation. |
| `KERNEL-VERIFIER-DIVERGED` | The tree's verifier digest differs from the accepted seed's. |
| `GOVERNANCE-UNACCEPTED` | A frozen document changed without a decision-log entry, or the governance digest differs from the seed's. |
| `HARDWARE-BEFORE-BARRIER` | The specification names a hardware substrate and no `DSL_BARRIER` receipt exists. |
| `SUBSTRATE-ABSENT` | The declared substrate is not the host's natural substrate. |
| `KernelOverBudget` | The hygiene row would fail. |
| `SPEC-WEAKENED` | The specification drops a case, a stage module, or a fact that the last accepted specification carried. |

Predecessor binding is the digest of the predecessor's product closure plus the verifier and governance
digests. An edit outside that closure keeps the predecessor receipt valid; an edit inside it reopens the
predecessor. A receipt refresh is an identity projection that cannot weaken a specification.

## 6. Commands, generations, and receipts

The agent command is `amoebius-validate preview phase NN`. It runs the complete gate, prints the would-be
receipt, and mints nothing. The human commands are:

- `sudo amoebius-validate accept --phase NN` — prints the Claim, specification digest, kill table, spine
  outcome, and corpus delta, then signs the receipt and applies exactly one phase's status patch;
- `sudo amoebius-validate reset --decision DL-NNNN --product-gap LTD-XXX-NNN` — issues a receipt-bearing reset
  whose `ResetCause` names a validator gap and a product-gap legacy identifier with an owning phase;
- `sudo amoebius-validate govern --decision DL-NNNN` — accepts a governance change and re-seals the frozen
  baseline;
- `sudo amoebius-validate demo --file <path>` — signs an operator-authored input for the barrier's
  `OperatorDemonstration`;
- the reseed continuation, which archives the current generation and installs the next.

A generation identifier is the content address of the verifier. A reseed requires a decision identifier,
archives the prior store, and never deletes it. The supervisor refuses to issue when agent environment
markers are present ([DL-0010](../decision_log.md#dl-0010--host-precondition-for-agent-sessions)).

A receipt carries the verifier digest, the governance digest, the `SubjectChangeWitness` for every mutant,
the `ResetCause` when it is a reset, the `OperatorDemonstration` when it is the barrier, and the status
postimage.

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

The runner, the gate-specification library, the custody edits, and the human commands are owed by
[Phase 0](../../DEVELOPMENT_PLAN/phase_00_documentation_suite.md). The first product specification is owed by
[Phase 3](../../DEVELOPMENT_PLAN/phase_03_typed_spine.md). The `SpineFact` and `OperatorDemonstration` are owed
by [Phase 9](../../DEVELOPMENT_PLAN/phase_09_dsl_barrier.md).

## Related Documents

- [Gate integrity](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md) — the eighteen-row contract this runner fills
- [Validation-frame doctrine](./validation_frame_doctrine.md) — bootstrap trust and native execution
- [Testing spoof resistance](./testing_spoof_resistance.md) — the threat model the refusals answer
- [Testing doctrine](./testing_doctrine.md) — registers and the example corpus
- [Conformance harness doctrine](./conformance_harness_doctrine.md) — superseded by this document
- [Decision log](../decision_log.md) — DL-0007, DL-0009, DL-0010
