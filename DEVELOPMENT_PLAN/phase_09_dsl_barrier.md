# Phase 9: The DSL barrier through the shipped binary

> **Purpose**: Re-run the union corpus of every slice through the shipped `amoebius` binary, prove the control-plane endpoint compiles what it decodes, and let a human-signed operator-authored specification reach fake-applied bytes before any hardware phase opens.
> **Read this if**: the `DSL_BARRIER` role must be judged, or a hardware phase needs to know what receipt it binds.

This phase is `DSL_BARRIER`. It owns the union-corpus fact, the `SpineFact`, the control-plane endpoint as a
subject, and the operator demonstration. It owns no new pipeline stage; every stage belongs to Phases 3 through
8. Its predecessor is [Phase 8](phase_08_ui_program_language_binding.md), and its successor in table order is
[Phase 50](phase_50_host_assert_cli.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_03_typed_spine.md, DEVELOPMENT_PLAN/phase_04_witness_manifests_capacity_storage.md, DEVELOPMENT_PLAN/phase_05_substrates_lanes_image_recipe.md, DEVELOPMENT_PLAN/phase_06_extension_admission_attested_scope.md, DEVELOPMENT_PLAN/phase_08_ui_program_language_binding.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/workflow_calculus_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 9.1: The union corpus on current source](#sprint-91-the-union-corpus-on-current-source-)
- [Sprint 9.2: The control-plane endpoint as subject](#sprint-92-the-control-plane-endpoint-as-subject-)
- [Sprint 9.3: The operator demonstration](#sprint-93-the-operator-demonstration-)
- [Sprint 9.4: Hygiene rows and legacy closure](#sprint-94-hygiene-rows-and-legacy-closure-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Gate execution is held shut by the Phase-8 predecessor receipt in certification generation 2. No hardware
discovery, container-engine bring-up, cluster creation, or image execution may begin until this phase's
receipt exists; the runner refuses such work as `HARDWARE-BEFORE-BARRIER`.

## Phase Summary

Phase 9 replaces the self-referential gate suite that checked a list of caller-supplied stage observations.
Its claim is the spine fact stated in [`AGENTS.md`](../AGENTS.md#validation-outcome-and-ordering): an
operator-authored value reaches fake-applied bytes through the shipped `amoebius` binary. Three facts compose
it. The union corpus of Phases 3 through 8 re-runs green on the current source, so no later slice regressed an
earlier one. The control-plane endpoint compiles through `compileDeployment`, so the shipped binary's only
consumer of the decoder consumes its result. An untracked Dhall file, authored by the operator outside the
corpus and signed by the human with `amoebius-validate demo`, adds a tag not in the corpus tag set and reaches
fake-applied bytes whose digest equals the render digest.

Every hardware specification from Phase 50 onward binds this phase's receipt digest and runs a corpus example
through its own subject
([`gate_runner_doctrine.md` §7](../documents/engineering/gate_runner_doctrine.md#7-the-example-corpus-and-the-hardware-rule)).

**Phase scope:** One cohesive claim — the union corpus, the endpoint, and a human-signed operator specification all reach fake-applied bytes through the shipped binary on the current source; it splits if any hardware, container, cluster, or live host is needed to settle it.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 8](phase_08_ui_program_language_binding.md)
**Gate:** `pb validate phase 09`; see [Gate integrity](#gate-integrity).

### Corpus

The corpus is the union of `Amoebius.Dsl.Examples.Spine`, `Capacity`, `Substrates`, `Extensions`,
`ChildClusters`, and `Ui`, re-exported by `Amoebius.Dsl.Examples.Union`. The human's `demo` file is not a
corpus member; it must carry at least one tag outside the union's tag set, and its acceptance is recorded as
`OperatorDemonstration` in the receipt. No new distinguishing pair is required; the minimum is the union.

### Gate specification

```gate-spec
capability: dsl_barrier
subjects:
  - Amoebius.Dsl.Pipeline
  - Amoebius.Dsl.Examples.Union
  - Amoebius.Entry.ControlPlane
suite: barrier-suite
oracle: oracle-dsl
positives: [union-corpus]
negatives: [EndpointDiscardsDecodedValue, DemoInsideCorpusTagSet, DemoUnsigned]
mutants: { perModule: 8, perGateCap: 40, killRatio: 0.6 }
binaryFact:
  command: amoebius compile
  perturbation: sentinel-to-nonce
  outputs: [decoded-dump, manifest, fake-kubectl-stdin, endpoint-digest]
spineFact:
  rendered: root.dhall
  stages: [freeze, decode, lower, plan, provision, render, chain, dry-run, fake-apply]
  appliedDigestFile: applied.sha256
substrate: HardwareFree
corpus: { module: Amoebius.Dsl.Examples.Union, minimumPairs: 15 }
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | On the current source, every member of the union corpus reaches fake-applied bytes through the shipped binary with the runner's nonce recovered from the decoded dump, the manifest, and the fake's stdin; the control-plane endpoint returns the digest `compileDeployment` produces for the same input; the human-signed operator file with a tag outside the corpus tag set reaches fake-applied bytes whose digest equals the render digest. Hardware, containers, clusters, and live hosts are excluded. |
| `Subject` | `Amoebius.Dsl.Pipeline`, `Amoebius.Dsl.Examples.Union`, and `Amoebius.Entry.ControlPlane` in `app/amoebius/Amoebius/Entry/ControlPlane.hs`, all inside the closure of `executable amoebius`; the stage modules of Phases 3 through 8 are re-mutated through their own specifications. |
| `Command` | Future public spelling is `pb validate phase 09`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 09`; the human runs `sudo amoebius-validate demo --file <path>` and then `sudo amoebius-validate accept --phase 09`. The runner spawns the shipped binary for `render-examples`, `compile`, and `apply --executor fake`, and drives the endpoint in-process through the shipped binary's control-plane entry. |
| `Oracle` | `test/oracle/dsl/Main.hs` parses every output and prints the ledger from literal rows for the whole union; it depends on no `amoebius` library. |
| `Positive controls` | Every union member equal to its oracle row; the endpoint digest equal to the pipeline digest; the operator file's applied digest equal to its render digest. |
| `Paired negatives` | `EndpointDiscardsDecodedValue` (a build in which the endpoint ignores the decoded value is refused by the digest comparison), `DemoInsideCorpusTagSet` (a demonstration whose tags are all in the corpus set is refused), and `DemoUnsigned` (a demonstration without the human's signature is refused). |
| `Mutants` | Runner-generated over the three subjects plus every stage module of Phases 3 through 8, at most forty per gate, kill ratio at least 0.6; the mutant class "endpoint discards the decoded value" must have at least one kill. |
| `Discovery` | The union's member count equals the sum of the six corpus modules' counts; the stanza module map is compared two-way; empty discovery refuses. |
| `Challenge` | The runner rewrites the rendered `root.dhall` of every member and the operator file after the run starts; the nonce must be recovered from all three outputs of every member. |
| `Observer` | `ProcessObserver` over the shipped binary and the fake `kubectl`; the endpoint digest is read from the binary's response bytes. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED`; oracle stanza hygiene; the demonstration is signed only by the human account through the supervisor, which refuses agent environment markers. |
| `Freshness` | A unique run root; a fresh render of every member; the verifier digest equals the seed's; every `LTD-SRC-*` query is zero. |
| `Qualification` | The generated-mutant matrix over the union precedes the clean candidate in the same run. |
| `Cleanroom` | `.build/runs/phase-09/**`, absent afterward; the kernel ratchet is recorded; the hygiene row records no `_MUTANT` symbol, no conditional compilation, and one definition per vocabulary type. |
| `Legacy closure` | Every `LTD-DSL-*` identifier is closed or listed in Residue; every `LTD-SRC-*` query is zero; `LTD-LIB-001` is decided here — each parked calculus library is either linked into the executable or deleted, and the decision is recorded in the receipt. |
| `Predecessor` | The Phase-8 receipt in certification generation 2, chained by the digest of Phase 8's product closure plus the verifier and governance digests. |
| `Residue` | Every phase from 50 onward; `LTD-HELPER-001` until Phase 50; `LTD-UI-001` until Phases 70 and 72; `LTD-LIB-002` until the proof-assistant track is promoted. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, the `OperatorDemonstration` is present, and the human's `accept` records it. |

## Doctrine adopted

- [`development_plan_phase_model.md` §E — one canonical phase model](development_plan_phase_model.md#e-one-canonical-phase-model) — the role this phase occupies.
- [`gate_runner_doctrine.md` §6 — commands, generations, and receipts](../documents/engineering/gate_runner_doctrine.md#6-commands-generations-and-receipts) — `demo` and the `OperatorDemonstration` receipt field.
- [`gate_runner_doctrine.md` §7 — the example corpus and the hardware rule](../documents/engineering/gate_runner_doctrine.md#7-the-example-corpus-and-the-hardware-rule) — the union corpus and hardware consumption.
- [`dsl_doctrine.md` §5 — the illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) — the three layers the union exercises.
- [`testing_spoof_resistance.md` §12.5 — fresh external observation](../documents/engineering/testing_spoof_resistance.md#125-fresh-external-observation) — the nonce and the fake boundary.

## Sprints

## Sprint 9.1: The union corpus on current source ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Dsl/Examples/Union.hs`
**Blocked by**: [Phase 8](phase_08_ui_program_language_binding.md) gate pass
**Independent Validation**: Every member of the union reaches fake-applied bytes equal to its oracle row on the current source; a member dropped from the union is refused by the count comparison; a stage mutant from any earlier phase is killed at its following stage.
**Oracle**: `test/oracle/dsl/Main.hs` holds the union's rows from literals.
**Legacy IDs**: `LTD-VAL-005` — the barrier's hand-built bind, re-run here over the union
**Docs to update**: `documents/engineering/testing_doctrine.md`

### Objective

Re-run everything the slices established, on one source, through one binary.

### Deliverables

- `Amoebius.Dsl.Examples.Union` re-exporting the six corpus modules with a count witness.

### Validation

Render, compile, and fake-apply every member; compare with the oracle; kill the re-run mutants.

### Remaining Work

Implement the union module.

## Sprint 9.2: The control-plane endpoint as subject ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `app/amoebius/Amoebius/Entry/ControlPlane.hs` and `src/Amoebius/Dsl/Pipeline.hs`
**Blocked by**: Sprint 9.1
**Independent Validation**: The endpoint's response digest equals the pipeline's digest for every union member; the mutant class "endpoint discards the decoded value" has at least one kill; a request body that fails `decodeFrozen` is refused with the decoder's tag, never with a constant demand.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected endpoint digest per member from literals.
**Legacy IDs**: `LTD-DSL-009` — the endpoint discards the decoded spec, re-verified here
**Docs to update**: `documents/engineering/daemon_topology_doctrine.md`

### Objective

Make the shipped binary's entry point a gate subject, not a wrapper.

### Deliverables

- The endpoint driven through the shipped binary's control-plane entry with the union as input.

### Validation

Drive every member through the endpoint and compare digests; kill the discard mutant.

### Remaining Work

Implement the endpoint driver in the specification.

## Sprint 9.3: The operator demonstration ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Barrier.hs` and `src/validation-kernel/Amoebius/Validation/Runner/Binary.hs`
**Blocked by**: Sprint 9.2
**Independent Validation**: A human-signed operator file with a tag outside the corpus set reaches fake-applied bytes whose digest equals the render digest, and the receipt carries `OperatorDemonstration`; `DemoInsideCorpusTagSet` and `DemoUnsigned` are refused by name.
**Oracle**: `test/oracle/runner/Main.hs` states the expected demonstration receipt fields from literals.
**Legacy IDs**: `LTD-DSL-001` — the decode-to-bind edge, demonstrated on an input no corpus author wrote
**Docs to update**: `documents/engineering/gate_runner_doctrine.md`

### Objective

Show the spine on an input the corpus never saw, signed by the human.

### Deliverables

- The `SpineFact` in the Phase-9 specification.
- The `demo` command path through the runner's binary-fact stage.

### Validation

Sign a demonstration file from the human account; run the barrier; require the receipt field and the digest
equality; refuse the two twins.

### Remaining Work

Implement the specification and the demonstration path.

## Sprint 9.4: Hygiene rows and legacy closure ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Barrier.hs` and `amoebius.cabal`
**Blocked by**: Sprint 9.3
**Independent Validation**: Every `LTD-SRC-*` query is zero; every `LTD-DSL-*` identifier is closed or named in Residue; each parked calculus library is linked or deleted and the decision is in the receipt; the hygiene row is green at the ratchet.
**Oracle**: `test/oracle/runner/Main.hs` states the expected inventory join and closure from literals.
**Legacy IDs**: `LTD-LIB-001` — parked calculi decided here; `LTD-DSL-002` through `LTD-DSL-008` confirmed closed
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through the human's `accept`

### Objective

Close the pre-hardware ledger.

### Deliverables

- The two-way typed inventory join over every `LTD-SRC-*` and `LTD-DSL-*` identifier.
- The `LTD-LIB-001` decision recorded in the specification.

### Validation

Run `preview phase 09` and require every row green; require the human's `accept` to record exactly one
phase's patch, after which `HARDWARE-BEFORE-BARRIER` lifts.

### Remaining Work

Everything above. The `accept` ends this phase and opens Phase 50.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes, never before):**

- `documents/engineering/gate_runner_doctrine.md` — only if the `SpineFact` or the demonstration path changes.
- `documents/engineering/testing_doctrine.md` — only if the union rule changes.

**Cross-references to add:**

- Phase 8 predecessor gate pass and the Phase 50 consumer link.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 8 UI program language](phase_08_ui_program_language_binding.md) — the predecessor
- [Phase 50 bounded handoff](phase_50_host_assert_cli.md) — the first consumer of this receipt
- [Phase 3 typed spine](phase_03_typed_spine.md) — the first slice this phase re-runs
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
- [DSL doctrine](../documents/engineering/dsl_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
