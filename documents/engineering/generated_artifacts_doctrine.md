# Generated Artifacts: emitted from Haskell, never committed

> **Purpose**: State the semantic rule that every non-Haskell behavioral artifact is emitted lazily from
> Haskell and never committed.
> **Read this if**: it has to be settled whether an artifact is tracked or materialized for a consumer.

This document owns the semantic generated-artifact boundary. The closed tracked-tree grammar, path inventory,
ignore contracts, and enforcement rules belong to
[`repository_layout_doctrine.md`](./repository_layout_doctrine.md). Generator-specific meaning remains with
the doctrine that defines each output.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_37_ui_program_schema.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/formal_model_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/tla_modelling_assumptions.md, documents/engineering/validation_frame_doctrine.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

</details>

## Contents
- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. What is generated (and from what)](#2-what-is-generated-and-from-what)
- [3. The rule](#3-the-rule)
- [4. What this buys](#4-what-this-buys)
- [5. Authored vs generated: the committed source](#5-authored-vs-generated-the-committed-source)
- [6. Planning ownership](#6-planning-ownership)
- [Related Documents](#related-documents)

---

## 1. Why this doctrine exists

A committed generated artifact is a second source of truth. It can be edited independently of its generator,
and both copies can remain well formed while disagreeing. Review cannot reliably determine whether the output
or generator is authoritative.

amoebius removes the second copy. A consumer obtains a fresh deterministic materialization from Haskell at the
moment it is needed. The artifact is stamped, content-addressed where its lifecycle requires identity, written
beneath `.build/**`, and reaped with its region. A generated file never moves back into an authored root.

The stronger tracked-source rule belongs to
[`repository_layout_doctrine.md` §1](./repository_layout_doctrine.md#1-classification-rule): all tracked
behavioral source is `.hs`, with bounded Python under `pb/**` as the sole source-language exception. This
document explains the generated side of that boundary.

## 2. What is generated (and from what)

| Generated artifact | Tracked Haskell source of truth | Lazy materialization |
|---|---|---|
| Dhall schema, prelude, examples, frame values, and test values | checked intermediate-representation and external-input projection types | `.build/dhall/**` |
| Explicit-state, symbolic, and refinement-checker inputs | Haskell model, formula, and named-invariant declarations | `.build/checkers/**` |
| TLA+ module and TLC configuration | reifiable `Model` and semantic renderer | `.build/tla/**` |
| Kubernetes/provider objects | opaque checked and provisioned deployment values | `.build/manifests/**` |
| Dockerfile and bake inputs | typed Haskell bake catalog and recipe renderer | `.build/docker/**` |
| SQL schema, statements, constraints, and policies | scope-bearing Haskell transaction declarations | `.build/sql/**` |
| Proto, generated bindings, and protocol fixtures | Haskell protocol declarations and recipes | `.build/proto/**` |
| Pulumi programs and provider inputs | Haskell infrastructure declarations | `.build/pulumi/**` |
| PureScript/JavaScript client runtime, codecs, CSS/HTML/assets, and bundle | Haskell client-runtime and public-contract declarations | `.build/ui/**` |
| Objective-C/C Metal bridge and Metal shader source | Haskell host-worker ABI and shader declarations | `.build/metal/**` |
| Test enumeration and encoded fixtures/oracles | Haskell declarations and separately reviewed Haskell expectations | `.build/test-surfaces/**`, `.build/test-corpora/**` |
| Python outside `pb/**`, shell, and other external-language check helpers | Haskell checker/workflow declarations | `.build/tools/**` |
| Mutated source and negative corpora | Haskell mutation operators and positive Haskell seeds | `.build/test-corpora/**` |
| Rendered plans, reports, ledgers, receipts, and traces | Haskell execution and observation values | `.build/runs/**`, `.build/docs/**` |

Operator-authored runtime values are a distinct case. They are external or untracked inputs supplied to the
binary; they are not repository examples, fixtures, or application source. A gate may
copy such a value into its run root, but that copy remains untracked input or run evidence.

## 3. The rule

1. A Haskell value declares the complete semantic source of every generated artifact.
2. Materialization occurs only when a typed workflow reaches a consumer that needs the artifact.
3. Output is written beneath the owning `.build/**` subtree and never into a tracked root.
4. A clean materialization is deterministic for the same declared and resolved inputs.
5. An emitted external-language program has no authority to decide its own validation result.
6. A separately reviewed Haskell oracle judges semantic properties of the output.
7. A serializer or compiler round trip is a consistency check, not an independent oracle.
8. The run records resolved compilers, dependencies, paths, and integrity observations without committing them.
9. Materialized output is reaped at the end of its artifact region unless a typed retention grant transfers it.
10. The tracked-source audit rejects an emitted copy regardless of its filename, location, or hand edits.

### 3.1 The retired image-recipe allowlist

There is no tracked image-recipe allowlist. A Dockerfile and every non-Haskell bake-catalog projection are
generated beneath `.build/docker/**` from Haskell. Adding a digest, comment, or hand-maintained stanza does not
make the recipe source.

Image behavior is constrained by Haskell semantic expectations over stages, acquisition choices, parent
identity, command structure, and outputs. A copied Dockerfile golden is prohibited because it compares the
renderer with its own previous bytes.

## 4. What this buys

- A generated schema cannot silently lag the Haskell decoder because no tracked schema copy exists.
- A manifest or Dockerfile cannot receive an unreviewed hand edit because no tracked output exists to edit.
- A toolchain refresh produces a new run observation instead of a permanent lock-table edit.
- A new union arm regenerates the test-surface enumeration, exposing an unbound expectation rather than
  relying on a hand-maintained inventory.
- A generated client and its server plan can share one typed source without tracking either projection.

These properties do not prove that a renderer is correct. Correctness depends on independent Haskell
expectations, adversarial controls, and the gate-integrity contract. Content addressing proves which bytes an
artifact name denotes; it does not prove that those bytes satisfy a requirement.

## 5. Authored vs generated: the committed source

The committed behavioral sources are Haskell only:

- product and runtime modules;
- typed DSL, protocol, model, renderer, and client-runtime declarations;
- test topology declarations and positive values;
- independently reviewed oracle predicates and expected semantic values;
- mutation operators and their expected failure identities; and
- Haskell harnesses that observe the subject and external boundaries.

The sole source-language exception is Python beneath `pb/**`, bounded to the minimum platform distinction
needed for contained toolchain establishment, source-bound Haskell build, and `exec` of that exact binary
with every argument unchanged. `pb validate phase NN`, help, version, unknown verbs, and all future argv are
opaque to Python; Haskell alone interprets them and owns every verdict. Governance Markdown and minimal
build/repository metadata are non-source inputs.

No Dhall, PureScript, JavaScript, shell, Proto, Pulumi, Dockerfile, serialized fixture, expected-output table,
expected diagnostic, materialized mutant body, generated Markdown, or external-language checking tool is
retained in Git. Independent authorship changes where the Haskell expectation comes from; it does not
authorize a second tracked file format.

### 5.1 When the reflected schema changes under an operator's `.dhall`

An operator's `.dhall` is external input, not repository source. The Haskell types reflect the current schema
on demand. An additive change may preserve the external value's meaning; a narrowing may require an explicit
operator migration; an ambiguous semantic change is rejected.

amoebius never silently rewrites the operator's source value and never commits a migrated copy. A migration
tool may emit a candidate beside the run's external-input staging area, but the operator retains authority to
accept and store it outside Git.

Repository tests for schema evolution use Haskell values that render old and new Dhall inputs under
`.build/test-corpora/**`. The expected compatibility classification is an independently reviewed Haskell
value, not a committed `.dhall` corpus.

## 6. Planning ownership

This doctrine carries no implementation or validation status. The development plan owns which phases deliver
each renderer, source migration, clean-room check, oracle, and sabotage control. A phase cannot produce a
candidate while its typed Haskell legacy observation still finds an owned tracked copy. The single Markdown
register only explains that binding to readers and cannot alter closure.

## Related Documents

- [Repository Layout and Artifact Provenance](./repository_layout_doctrine.md) — the closed path/source grammar
- [JIT Artifact Doctrine](./jit_artifact_doctrine.md) — typed targets, recipes, addresses, regions, and reaping
- [Formal Model Doctrine](./formal_model_doctrine.md) — generated TLA+/TLC inputs
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — generated Kubernetes/provider objects
- [Low-Code UI Runtime](./low_code_ui_runtime_doctrine.md) — generated client runtime and paired plans
- [Testing Doctrine](./testing_doctrine.md) — independent Haskell expectations and generated test encodings
- [Development Plan](../../DEVELOPMENT_PLAN/README.md) — delivery and validation status
