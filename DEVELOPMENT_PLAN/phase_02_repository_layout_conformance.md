# Phase 2: Repository layout conformance and source closure

> **Purpose**: Specify the Haskell capability that classifies every tracked path: behavioural source is `.hs` outside `pb/**`, the admitted non-Haskell set is exactly six files, the bounded bootstrap is admitted through a deny-by-default grammar, and every generated foreign product is absent from the tracked tree.
> **Read this if**: Phase 2 is next in the queue, or a later phase depends on what its gate establishes.

Phase 2 moves the layout classifier out of the validator and into the product. `amoebius layout-report`
classifies every tracked path, and the independent oracle compares the report with the layout rule it restates
from literals. Its predecessor is [Phase 1](phase_01_toolchain_spike.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_03_typed_spine.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 2.1: `test/**` is Haskell modules only](#sprint-21-test-is-haskell-modules-only-)
- [Sprint 2.2: The package-only roots become cabal stanzas](#sprint-22-the-package-only-roots-become-cabal-stanzas-)
- [Sprint 2.3: Tracked foreign roots enter typed ownership](#sprint-23-tracked-foreign-roots-enter-typed-ownership-)
- [Sprint 2.4: Every authored name loses its phase ordinal](#sprint-24-every-authored-name-loses-its-phase-ordinal-)
- [Sprint 2.5: Ignore policy from the closed roots](#sprint-25-ignore-policy-from-the-closed-roots-)
- [Sprint 2.6: The layout report, the bounded bootstrap, and the six-file admitted set](#sprint-26-the-layout-report-the-bounded-bootstrap-and-the-six-file-admitted-set-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

The contract is reopened under [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) by
[DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice): the subject moves
from the validator into product code and absorbs the source queries of the retired tool-generation phase.
Under §N step 3, every generation-1 receipt for this phase is incompatible with certification generation 2 and
supplies no authority. Gate execution is held shut by the Phase-1 predecessor receipt in certification
generation 2.

## Phase Summary

Phase 2 closes the tracked source boundary. `Amoebius.Layout.Classify` assigns every tracked path exactly one
class from the closed rule in the repository-layout doctrine; `Amoebius.Layout.PbGrammar` admits the bounded
bootstrap through a deny-by-default syntax, import, call, and effect graph; `amoebius layout-report` prints the
classification for the oracle to judge. No Markdown row, count, or tracker status is an input to any of them.

The admitted non-Haskell tracked set is exactly six files, named by class rather than by name: the package
description and the project description, the two ignore files, the licence text, and one packaging-metadata
file. Markdown is excluded from the count, and `pb/__main__.py` is the separately admitted bounded bootstrap.
A seventh non-Haskell file is a refusal, whatever its extension or claimed data role.

This phase absorbs the source queries the retired tool-generation phase owned: the tool root, the Pulumi
program root, and the non-Haskell test inputs are refused here as paired negatives. Dhall, Proto, and UI roots
are classified to their owners — Phase 3 and Phase 72 — and reported as owed, never admitted.

**Phase scope:** One cohesive claim — the shipped binary's layout report classifies every tracked path against the closed rule, the admitted non-Haskell set is exactly six files, and every Phase-2 source query is zero; it splits if a claim needs compiler-wide call or effect semantics, product behaviour, or a host.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 1](phase_01_toolchain_spike.md)
**Forward-deferred:** Dhall and Proto declarations rendered from Haskell — [Phase 3](phase_03_typed_spine.md) `typed_spine` / `LTD-SRC-002`, `LTD-SRC-003`
**Gate:** `pb validate phase 02`; see [Gate integrity](#gate-integrity).

### Gate specification

```gate-spec
capability: repository_layout_conformance
subjects:
  - Amoebius.Layout.Classify
  - Amoebius.Layout.PbGrammar
  - Amoebius.Layout.Report
suite: layout-suite
oracle: oracle-layout
positives: [tracked-tree, bounded-bootstrap, six-file-admitted-set]
negatives: [TrackedPythonOutsidePb, TrackedDhall, TrackedPulumiYaml, TrackedMutantBody, RetiredIgnoreRoot, OrdinalRuntimeIdentity]
mutants: { perModule: 8, perGateCap: 40, killRatio: 0.6 }
binaryFact:
  command: amoebius layout-report
  perturbation: planted-path-to-nonce
  outputs: [layout-report]
substrate: HardwareFree
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | `amoebius layout-report` classifies every tracked path exactly once against the closed rule: behavioural source is `.hs` outside `pb/**`, the admitted non-Haskell set is exactly six files, the bounded bootstrap admits through the deny-by-default grammar, and the source query for every Phase-2 identifier is zero. Compiler call and effect semantics, product behaviour, and hardware are excluded. |
| `Subject` | The three stage modules named in the gate specification and the `layout-report` subcommand in `app/amoebius/Main.hs`. Every subject is inside the closure of `executable amoebius`. |
| `Command` | Future public spelling is `pb validate phase 02`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 02`; the human runs `sudo amoebius-validate accept --phase 02`. The runner spawns the shipped `amoebius` binary as a child for `layout-report` over the tracked tree and over each planted copy. |
| `Oracle` | `test/oracle/layout/Main.hs` restates the classification rule, the six-file set by class, the grammar's refused node families, and the expected finding per planted negative from literals; it depends on no `amoebius` library. |
| `Positive controls` | The tracked tree classifies with zero findings; the bootstrap admits through the grammar; the admitted non-Haskell set matches the oracle's six classes; the ordinal-identity query is zero. |
| `Paired negatives` | A tracked `.py` outside `pb/`, a tracked `.dhall`, a tracked Pulumi YAML, a tracked mutant body, a retired generated root re-admitted in an ignore file, an ordinal-bearing runtime identity, and one forbidden node per grammar family — each refused at its exact locus with the positive twin accepted. |
| `Mutants` | Runner-generated from the fixed operator catalogue over the three stage modules, eight per module, at most forty per gate, kill ratio at least 0.6; a mutant in `Amoebius.Layout.Classify` that admits a foreign extension is killed by the planted negatives. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the report's path set equals the index's path set; empty discovery refuses. |
| `Challenge` | After the run starts, the runner stages one file whose name carries a nonce into a run-local copy of the tracked tree — once as a `.py` outside `pb/`, once as `.dhall`, once as Pulumi YAML — and the report must refuse each by class with the nonce in the finding. |
| `Observer` | `ProcessObserver` over the shipped binary; executable identity, argv, environment policy, exit, and complete output are runner-captured. No subject log is trusted. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` refuses a subject outside the executable's closure; the oracle stanza's hygiene refuses a product dependency; `pb` is inadmissible as transport; no Markdown row, count, or tracker status reaches the classifier, checked by a compile-negative twin. |
| `Freshness` | A unique run root; a fresh copy of the tracked tree per planted negative; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The runner-generated mutant matrix over the three stage modules — eight per module, at most forty, kill ratio at least 0.6 — precedes the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-02/**` and is absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-SRC-000`, `LTD-SRC-001`, `LTD-SRC-005`, `LTD-SRC-006`, `LTD-SRC-008`, `LTD-META-001`, and `LTD-NAME-001` close here through the compiled inventory. `LTD-SRC-002` and `LTD-SRC-003` are reported as owed by Phase 3 and `LTD-SRC-004` as owed by Phase 72; none is closed here. |
| `Predecessor` | The Phase-1 receipt in certification generation 2, chained by the digest of Phase 1's product closure plus the verifier and governance digests. |
| `Residue` | The runtime handoff of the bootstrap remains Phase 50's claim; consumer, effect, and call-graph semantics are not classified here, and the stanza module map is the only compiler-facing relation; Phases 3 through 9 and every phase from 50 onward remain explicit limitations. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and the human's `accept` records it. |

## Doctrine adopted

- [`repository_layout_doctrine.md` §1 — classification rule](../documents/engineering/repository_layout_doctrine.md#1-classification-rule) — the closed rule the classifier realises.
- [`repository_layout_doctrine.md` §2 — complete repository structure](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) — the final tree and its fixed roots.
- [`repository_layout_doctrine.md` §2.1 — when a unit warrants its own build package](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package) — the criterion a package-only root fails.
- [`repository_layout_doctrine.md` §6 — `.gitignore` contract](../documents/engineering/repository_layout_doctrine.md#6-gitignore-contract) and [§7 — `.dockerignore` contract](../documents/engineering/repository_layout_doctrine.md#7-dockerignore-contract) — the ignore policy derived from the closed roots.
- [`jit_artifact_doctrine.md` §2 — the rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every foreign or generated product is derived lazily beneath `.build/**`.
- [`generated_artifacts_doctrine.md` §3 — the rule](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule) — a generated destination cannot hold bytes until its generator runs.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` this phase carries.

## Sprints

## Sprint 2.1: `test/**` is Haskell modules only ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/Classify.hs`
**Blocked by**: [Phase 1](phase_01_toolchain_spike.md) gate pass
**Independent Validation**: Every path beneath `test/**` classifying as a Haskell module is the positive control; a tracked script, table, golden, patch, or mutant body beneath `test/**` is a paired negative refused by name. A generated mutant that widens the test-tree arm is killed by the planted negatives.
**Oracle**: `test/oracle/layout/Main.hs` states the test-tree rule from literals.
**Legacy IDs**: `LTD-SRC-006` — non-Haskell test inputs
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`

### Objective

Make the test tree Haskell only: a fixture is a typed value, an oracle a separately authored predicate, and a
mutant a runner-applied operator. Serialized forms exist only beneath `.build/test-corpora/**` during a run.

### Deliverables

- The `test/**` arm of the classifier, with one refusal per non-Haskell class.
- No filename-based exemption for any behavioural test input.

### Validation

Classify the tree; plant each negative in a run-local copy; compare the findings with the oracle.

### Remaining Work

Implement the arm.

## Sprint 2.2: The package-only roots become cabal stanzas ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/Classify.hs` and `amoebius.cabal`
**Blocked by**: Sprint 2.1
**Independent Validation**: One authored package description whose stanzas cover every Haskell source root is the positive control; a second package description outside the probe exception, an `hs-source-dirs` reaching outside the repository, and a tracked tool root are paired negatives refused by name.
**Oracle**: `test/oracle/layout/Main.hs` states the package-root rule from literals.
**Legacy IDs**: `LTD-SRC-001` — the tool root
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`

### Objective

Adopt [`repository_layout_doctrine.md` §2.1](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package):
one authored package, and a third-party program declared in Haskell and materialized beneath `.build/tools/**`
rather than tracked under a root of its own.

### Deliverables

- The package-description arm of the classifier.
- The tool-root refusal; any emitted helper lives beneath `.build/tools/**`.

### Validation

Classify the package description; plant each negative; compare with the oracle.

### Remaining Work

Implement the arm.

## Sprint 2.3: Tracked foreign roots enter typed ownership ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/Classify.hs` and `src/plan-decisions/Amoebius/Plan/Legacy.hs`
**Blocked by**: Sprint 2.2
**Independent Validation**: A tracked Pulumi YAML is refused at the layout locus, closing `LTD-SRC-005`. A tracked Dhall file, a tracked Proto schema, and a tracked UI root are each classified to their owner — Phase 3 for `LTD-SRC-002` and `LTD-SRC-003`, Phase 72 for `LTD-SRC-004` — and reported as owed, never admitted.
**Oracle**: `test/oracle/layout/Main.hs` states the owner-by-class table from literals.
**Legacy IDs**: `LTD-SRC-005`; `LTD-SRC-002`, `LTD-SRC-003`, and `LTD-SRC-004` reported as owed
**Docs to update**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`

### Objective

Account for every foreign root through the compiled owner map without admitting any of them as source or
treating PureScript, Dhall, Proto, or YAML as an admitted language.

### Deliverables

- The owner-by-class arm joined to `Amoebius.Plan.Legacy`.
- The Pulumi refusal; provider declarations render beneath `.build/pulumi/**`.

### Validation

Classify each foreign class; compare the owner with the oracle's table; refuse the Pulumi negative.

### Remaining Work

Implement the arm. The owners close their rows in their own gates.

## Sprint 2.4: Every authored name loses its phase ordinal ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/Classify.hs` and `src/plan-decisions/Amoebius/Plan/PhaseIdentity.hs`
**Blocked by**: Sprint 2.3
**Independent Validation**: Zero ordinal-bearing runtime identities is the positive control; a runtime path, build component, or product diagnostic name carrying a phase ordinal is refused; a phase-labelled validation contract is the unaffected control.
**Oracle**: `test/oracle/layout/Main.hs` states the ordinal rule and the unaffected control from literals.
**Legacy IDs**: `LTD-NAME-001`
**Docs to update**: `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`

### Objective

Strip the ordinal from every product and runtime identity and replace it with a capability name derived from
the compiled phase-identity table, which is what makes
[§U](development_plan_gate_integrity.md#u-the-final-repository-layout) clause 3 true.

### Deliverables

- The ordinal arm of the classifier, reading capability names from `Amoebius.Plan.PhaseIdentity`.
- Phase-labelled validation contracts left phase-labelled and forbidden as runtime identities.

### Validation

Run the ordinal query; plant an ordinal-bearing name; require the refusal at that path and no other.

### Remaining Work

Implement the arm.

## Sprint 2.5: Ignore policy from the closed roots ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/Classify.hs`
**Blocked by**: Sprint 2.4
**Independent Validation**: Both ignore files derived from the closed roots `.build/**`, `.data/**`, and `.test_data/**` are the positive control; a retired generated-root pattern in either file and an ignored path beside authored source are paired negatives refused by name.
**Oracle**: `test/oracle/layout/Main.hs` states the admitted pattern set from literals.
**Legacy IDs**: `LTD-META-001`
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`

### Objective

Adopt [`repository_layout_doctrine.md` §6](../documents/engineering/repository_layout_doctrine.md#6-gitignore-contract)
and [§7](../documents/engineering/repository_layout_doctrine.md#7-dockerignore-contract): ignoring a path cannot
make it an authorized state root.

### Deliverables

- The ignore-policy arm of the classifier.
- No generated material gaining an additional home through metadata.

### Validation

Classify both ignore files; plant each negative; compare with the oracle.

### Remaining Work

Implement the arm.

## Sprint 2.6: The layout report, the bounded bootstrap, and the six-file admitted set ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/PbGrammar.hs`, `src/Amoebius/Layout/Report.hs`, `app/amoebius/Main.hs`, `src/gate-spec/Amoebius/Validation/GateSpec/Layout.hs`, and `amoebius.cabal`
**Blocked by**: Sprint 2.5
**Independent Validation**: `amoebius layout-report` classifies every tracked path exactly once and reports the admitted non-Haskell set as exactly six files by class; `pb/__main__.py` admits through the deny-by-default grammar; one forbidden node per family and a seventh non-Haskell file are refused; the compiled specification equals the fenced block above.
**Oracle**: `test/oracle/layout/Main.hs` for the report and the grammar; `test/oracle/runner/Main.hs` for the specification digest.
**Legacy IDs**: `LTD-SRC-000`, `LTD-SRC-008`
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through the human's `accept`

### Objective

Make the classifier a product subcommand whose output the oracle judges, and close static source admission for
the bootstrap so that Phase 50 can observe its runtime handoff.

### Deliverables

- The six-file admitted set as a Haskell value: the package description and the project description, the two ignore files, the licence text, and one packaging-metadata file; Markdown excluded; `pb/__main__.py` as the separately admitted bounded bootstrap.
- `Amoebius.Layout.PbGrammar`: a closed syntax, import, resolved-direct-call, control-flow, and effect graph that rejects dynamic execution, reflection, import hooks, decorators, metaclasses, and any effect outside the injected `BootstrapAdapter`.
- `layout-report` as a subcommand of the shipped binary; the Phase-2 `GateSpec` with its `BinaryFact`.
- Deletion of the validator-side layout runner and its oracle.

### Validation

Run `preview phase 02` and require every row green; require the human's `accept` to record exactly one
phase's patch.

### Remaining Work

Everything above. The `accept` ends this phase.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes, never before):**

- `documents/engineering/repository_layout_doctrine.md` — only if the classification rule, the admitted set, or the ignore contract changes.
- `documents/engineering/substrate_doctrine.md` — only if the bounded bootstrap's admitted grammar changes.

**Cross-references to add:**

- Phase 1 predecessor gate pass and Phase 3 consumer links.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 1 toolchain spike](phase_01_toolchain_spike.md) — the predecessor
- [Phase 3](phase_03_typed_spine.md) — the owner of the Dhall and Proto declarations this phase reports as owed
- [Phase 50 bounded handoff](phase_50_host_assert_cli.md) — the runtime claim over the bootstrap this phase admits statically
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Generated artifacts doctrine](../documents/engineering/generated_artifacts_doctrine.md)
- [JIT artifact doctrine](../documents/engineering/jit_artifact_doctrine.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
