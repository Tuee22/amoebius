# Phase 47: Generated checking tools and mutants

> **Purpose**: Establish the deterministic materialization boundary for the repository's checking-tool and mutation corpora.
> **Read this if**: a checking tool or a mutant has to be added, changed, or trusted, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned the closed inventory or deterministic
materialization of the repository's checking tools and mutation declarations. This phase establishes that
boundary. The current authored mechanism bytes remain independent reference inputs; replacing phase gates
with derived workflow values is the distinct self-referential seam owned by Phase 49.
The rule behind generated checking tools and mutants is owned by [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 47.1: Generated checking tools and mutants ✅](#sprint-471-generated-checking-tools-and-mutants-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-22. The thirteen-sided Register-1 gate passed on natural `arm64`, untranslated:
234 checking-tool sources and 371 mutation declarations materialized twice as 605 byte-identical artifacts,
all four whole-corpus equivalence checks passed under network isolation, all three seeded generator mutants
reddened, all 14 metrics matched, and 639 surfaces joined to 645 runtime items. Attestation
`sha256:9bfeffd694b2b854c0d742de1acb40dbc6ec3f5e9f3573bba2598f29b131d04e` binds source
`sha256:fae4b04ece44c0a5…` over 2,296 files. Mechanism derivation and removal of the authored gate copies remain
the Phase-49 boundary; protocol and live runtime behavior are UNVERIFIED.

## Phase Summary

Materialize a closed checking-tool and mutation corpus deterministically beneath the caller-owned build tree,
with authored mechanism bytes retained as the independent reference until the self-referential gate seam.

**Phase scope:** one cohesive claim — *the repository's complete checking corpus has a typed, deterministic materializer whose output reproduces the current authored mechanisms and mutation bodies exactly*. Deriving runnable gates from workflow declarations, switching consumers, and deleting authored gate copies belongs to Phase 49.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 3](phase_03_artifact_calculus.md) — the artifact calculus, which is what a tool becomes an instance of, and [Phase 7](phase_07_evidence_calculus.md), which fixes which half of a checker may be generated at all.
**Gate:** `python3 tools/run_phase_gate.py 47` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** The existing authored tools are reference inputs. Four representative whole-corpus
  checkers execute from both the authored tree and a workspace containing only the materialized tool corpus;
  their return codes and scoped verdicts must agree.
- **Committed mutants.** Mutants emit a tool missing one rule, drop an operator from the corpus, and commit an emitted artifact.
- **Specific-reason negatives.** The three build-flag mutants fail only at `checker-rule-missing`,
  `mutation-operator-missing`, or `generated-artifact-tracked`; the clean configuration is rebuilt afterward.
- **Fresh challenge.** Not applicable — this gate is pure. Two clean materializations, exact content-address
  observations, and execution of the materialized representative tools provide the independent challenge.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md) — the rule behind generated checking tools and mutants.

## Sprints

## Sprint 47.1: Generated checking tools and mutants ✅

**Status**: Done
**Implementation**: `src/tool-and-mutant-generation/Amoebius/Generate/CheckingCorpus.hs`,
`test/spec/generation/ToolAndMutantGenerationSpec.hs`, `tools/tool_and_mutant_generation_gate.py`
**Blocked by**: None.
**Independent Validation**: Two 605-artifact renders are byte-identical; four materialized checkers equal the authored whole-corpus verdicts; three generator mutants fail at exact loci.
**Docs to update**: `documents/engineering/jit_artifact_doctrine.md`

### Objective

Establish a typed materializer over the repository's closed tool-source and mutation declarations.

### Deliverables

- A closed 234-row tool-source inventory and 371-row mutation inventory.
- A total Haskell recipe that materializes all 605 declared artifacts beneath a caller-owned destination.
- Two-render byte determinism and content addresses for every artifact.
- Four whole-corpus checker comparisons plus network-isolated materialized execution.
- Three exact-locus generator mutants covering omitted rules, omitted operators, and authored-tree output.

### Validation

`python3 tools/tool_and_mutant_generation_gate.py` passed on 2026-08-22: all thirteen sides, all 14 metrics,
all three mutants, and the complete authored/runtime surface join were green.

### Remaining Work

None. Phase 49 owns deriving gate mechanisms as workflow values, switching their consumers, and removing the
transitional authored copies; those are not silently credited to this materialization seam.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md) — the rule behind generated checking tools and mutants.
