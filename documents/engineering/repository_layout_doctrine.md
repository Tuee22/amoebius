# Repository Layout and Artifact Provenance

> **Purpose**: Define the complete tracked-tree grammar, generated-output classes, local-state roots, and
> `.gitignore` and `.dockerignore` contracts.
> **Read this if**: a file is being added, generated, moved, ignored, packaged into a container context, or
> considered for version control.

This document owns repository placement and the closed tracked-source classification. Generator semantics
belong to the subsystem that declares each artifact. Phase order and validation status live only in
[`../../DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md). Executable migration identity,
ownership, and closure live in reviewed Haskell; the single
[`legacy_tracking_for_deletion.md`](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md) register explains
that active inventory to readers.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: AGENTS.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/documentation_standards.md, documents/engineering/README.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/glossary.md, documents/reading_order.md, pb/README.md, pb/stubs/README.md, vendor/dual/PROVENANCE.md, vendor/supernova/PROVENANCE.md
**Generated sections**: none

</details>

## Contents
- [1. Classification rule](#1-classification-rule)
- [2. Complete repository structure](#2-complete-repository-structure)
- [3. Complete generated-output inventory](#3-complete-generated-output-inventory)
- [4. Dependency and toolchain resolution](#4-dependency-and-toolchain-resolution)
- [5. Run evidence and phase status](#5-run-evidence-and-phase-status)
- [6. `.gitignore` contract](#6-gitignore-contract)
- [7. `.dockerignore` contract](#7-dockerignore-contract)
- [8. Enforcement and source-snapshot acceptance](#8-enforcement-and-source-snapshot-acceptance)
- [9. Migration boundary](#9-migration-boundary)
- [Related Documents](#related-documents)

---

## 1. Classification rule

The tracked-source rule is closed:

> **Every version-controlled product, runtime, test, gate, generator, checker, fixture, oracle, and mutant
> source file is Haskell and ends in `.hs`. Python source beneath `pb/**` is the sole source-language
> exception.**

The rule is about a file's role as well as its suffix. An executable, shebang-bearing file, embedded program,
serialized predicate, command table, or interpreter input does not become metadata by losing its extension or
moving into `test/`. A tracked `.json`, `.tsv`, `.yaml`, `.dhall`, `.purs`, `.js`, `.mjs`, `.sh`, `.proto`,
Pulumi program, Dockerfile, golden, expected-diagnostic file, mutation body, or executable without an extension
is prohibited when it carries behavior, a test case, or a validation decision.

The non-source input set is also closed:

| Class | Admitted tracked content |
|---|---|
| Haskell source | `.hs` under the Haskell roots in [§2](#2-complete-repository-structure) |
| Bootstrap source | Python under `pb/**`, limited to the minimum platform distinction needed to establish the contained toolchain, build the source-bound Haskell binary, and `exec` that exact binary with every argument unchanged; `pb validate phase NN` is opaque argv, not Python dispatch |
| Governance prose | Markdown under the root, `documents/**`, and `DEVELOPMENT_PLAN/**` |
| Build metadata | Cabal package/project descriptions and the minimal `pb` packaging metadata required before Haskell can build |
| Repository metadata | ignore files, attributes, licence, and editor-neutral repository policy |

`pb` is not a general scripting exception. It cannot implement product behavior, calculate or reinterpret a
gate verdict, host an oracle, select phase status, or remain in control after the Haskell binary exists. Phase
0 admits its source only through a Haskell-owned static AST/import/resolved-call/control-flow/potential-effect
proof. Phase 0 through Phase 49 invoke Haskell directly; Phase 50 alone uses Haskell tests and an independent
OS-boundary observer to validate `pb` as an external process.

Governance prose is not an executable registry. A checker may inspect Markdown structure, links, and status
syntax, but no product, generator, corpus, semantic oracle, or validation verdict may derive behavioural
values from a Markdown table, tag, list, or code block. The corresponding executable declarations and
independent expectations are Haskell.

The legacy register has a narrower semantic boundary. Its legacy-specific structural seam may require exactly
one tracked canonical `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`, require UTF-8 readability, and
reject the forbidden archive path or an alias. The general documentation checker may separately enforce
ordinary orientation metadata, headings, links, and anchors. Neither seam may derive a legacy identity,
owner, observation, closure, source-finding join, predicate, or count from row content. Changing any row,
cell, ID spelling, owner phrase, predicate-shaped string, order, or row count cannot change a source-closure
verdict. A human reviewer owns correspondence with the closed Haskell legacy inventory and its independently
authored oracle.

Operator-supplied values are neither generated source nor repository source. They enter through an explicit
runtime input, secret store, or ignored local test-input path. They are never committed merely because the
runtime language happens to be Dhall, JSON, YAML, or another non-Haskell format.

All other files are one of these untracked classes:

| Class | Required location |
|---|---|
| Lazily generated artifact | `.build/**` |
| Run evidence | `.build/runs/**` or `.build/evidence-store/**` |
| Resolved dependency or tool | `.build/toolchain/**`, `.build/locks/**`, or `.build/vendor/**` |
| Production runtime state | `.data/**` |
| Harness-owned runtime state | `.test_data/**` |
| External operator input | Outside Git; copied or streamed into a run without becoming source |

Copying, renaming, hand-formatting, or independently typing generated bytes does not change their class.
Independent expectations are separately reviewed Haskell values; any textual or binary encoding of those
values is generated lazily.

## 2. Complete repository structure

The following tree is the exhaustive final layout. It contains no transitional source root.

```text
amoebius/
├── .git/**                               local version-control metadata
├── .build/**                             generated artifacts, tools, tests, and evidence; ignored
├── .data/**                              operator-retained production state; ignored
├── .test_data/**                         harness-owned disposable state; ignored
├── .dockerignore                         authored container-context policy
├── .gitignore                            authored worktree policy
├── AGENTS.md                             authored agent policy
├── CLAUDE.md                             import-only entry point to AGENTS.md
├── LICENSE*                              authored licence text, when present
├── README.md                             authored repository entry point
├── amoebius.cabal                        authored Haskell package description
├── cabal.project                         authored Haskell project/compatibility description
├── DEVELOPMENT_PLAN/**                   authored plan and validation contracts; Markdown only
├── documents/**                          authored doctrine; Markdown only
├── src/**/*.hs                           product and runtime Haskell
│   └── vendor/**/*.hs                    maintained Haskell forks, when required
├── app/**/*.hs                           the single executable's Haskell entry modules
├── test/**/*.hs                          Haskell specs, fixtures, oracles, mutants, and harnesses
├── probe/**/*.hs                         separately resolved Haskell probe source, when required
└── pb/**                                 bounded Python bootstrap plus minimal packaging metadata
```

`dhall/`, `proto/`, `ui/`, `pulumi/`, `tools/`, top-level `vendor/`, and non-Haskell fixture trees are absent
from the final tracked tree. Their materialized forms belong under `.build/**`; their declarations, recipes,
test expectations, and checking logic belong in Haskell modules.

The Haskell roots may contain Markdown provenance beside a maintained fork only when that prose is required to
identify upstream authorship or licensing. Such prose is repository metadata, never executable input. A
non-Haskell upstream program is resolved lazily into `.build/vendor/**`; it is not vendored into Git.

`app/` contains one executable entry point. Runtime roles are decoded Haskell values, not separate programs.
`test/` contains only Haskell modules: a positive fixture is a typed Haskell value, an oracle is a separately
reviewed Haskell predicate or expected value, and a mutant is a Haskell transformation or alternate module.
Their serialized forms exist only during a run.

### 2.1 When a unit warrants its own build package

There is one authored Haskell package unless a separately resolved Haskell probe needs an isolated compiler or
dependency graph. A different flag set, module namespace, warning set, test group, or runtime role is not a
reason to create a package or executable. Cabal already expresses those distinctions within one package.

A third-party program invoked by amoebius does not acquire a tracked reader-language root. Haskell declares
what is required, the resolver materializes the program beneath `.build/toolchain/**` or `.build/vendor/**`,
and Haskell invokes the resolved absolute path. Generated source for an external compiler or interpreter is
materialized beneath `.build/**` immediately before use.

### 2.2 Present-day roots and their required destination

Any current path outside the target tree is a migration surface, not an exception. A closed typed Haskell
legacy inventory owns each migration identity, owner, observation binding, closure binding, and reintroduction
negative. The single Markdown register explains those bindings to readers and owns no deletion condition. The
canonical destinations are:

| Present content | Required destination |
|---|---|
| `tools/**/*.py`, shell tools, and extensionless executables | Haskell mechanisms under `src/**` or `test/**`; any emitted helper under `.build/tools/**` |
| `dhall/**/*.dhall` | Haskell schema/value declarations; emitted Dhall under `.build/dhall/**` |
| `proto/**/*.proto` and generated bindings | Haskell protocol declarations; emitted Proto/bindings under `.build/proto/**` |
| `ui/**/*.{purs,js,mjs,ts,css,html}` | Haskell client-runtime declarations; emitted language source and bundles under `.build/ui/**` |
| `pulumi/**` | Haskell infrastructure declarations; emitted Pulumi programs under `.build/pulumi/**` |
| tracked Dockerfiles and bake catalogs | Haskell bake declarations; emitted recipes under `.build/docker/**` |
| serialized fixtures, oracles, expectations, inventories, and mutants | independently reviewed Haskell values/operators; emitted encodings under `.build/test-corpora/**` |
| non-Haskell vendored source | lazy acquisition beneath `.build/vendor/**`; Haskell adapter or transformation declarations remain tracked |
| `package.json` and other generated-language package inputs | generated beneath the owning `.build/**` materialization root |
| plan-tree evidence and ledgers | `.build/runs/**` and `.build/evidence-store/**` |
| operator/test `.dhall`, JSON, YAML, or secret values | external or ignored input; never tracked |

No migration surface may receive new content. Removing its final file and its obsolete ignore rule is one
change; leaving an empty placeholder root would preserve ambiguity.

### 2.3 The closed local-state roots

`.build/`, `.data/`, and `.test_data/` are the only repository-contained state roots.

- `.build/**` is reproducible or evidentiary and may be deleted when no run is using it.
- `.data/**` is production runtime state and is removed only by the operator's explicit lifecycle action.
- `.test_data/**` is owned by the harness and must be safe for that harness to delete after a run.

No generated or runtime command writes to the repository root, a source root, a system temporary directory, a
user home, or host-global engine state. A tool that insists on another location is invoked through an isolated
root below the appropriate contained-state directory.

## 3. Complete generated-output inventory

Every non-Haskell program, test encoding, rendered configuration, compiler product, resolved dependency, and
run observation is generated beneath `.build/**`.

### 3.1 Canonical `.build/` tree

```text
.build/
├── artifacts/<content-address>/**        JIT materializations
├── cabal-store/**                        repository-local Cabal store
├── checkers/**                           emitted formal-checker inputs
├── dist-newstyle/**                      Cabal build root
├── dhall/**/*.dhall                      reflected schemas and runtime/test values
├── docker/**/Dockerfile                  rendered image recipes
├── docs/**                               generated reports and indexes
├── evidence-store/**                     content-addressed receipts admitted after independent review
├── locks/**                              resolver observations
├── manifests/**/*.{yaml,yml,json}        rendered Kubernetes/provider objects
├── metal/**                              emitted Objective-C/C bridge and Metal shader source
├── proto/**                              emitted Proto and generated bindings
├── pulumi/**                             emitted provider programs
├── runs/<phase>/<run-id>/**              logs, ledgers, receipts, traces, and observations
├── sql/**                                emitted schema, statements, and policies
├── test-corpora/**                       encoded positives, negatives, oracles, and mutants
├── test-surfaces/**                      generated coverage enumeration
├── tla/**/*.{tla,cfg}                    emitted formal-model inputs
├── toolchain/<os>-<arch>/**              acquired tools and dependency graphs
├── tools/**                              emitted external-language helper programs
├── ui/**                                 emitted PureScript/JavaScript/assets and bundles
└── tmp/**                                bounded disposable scratch space
```

### 3.2 Build, compiler, package-manager, and cache output

Compiler objects, interfaces, coverage, package stores, language package trees, browser profiles, reports,
screenshots, logs, sockets, and caches are generated. Commands redirect them beneath `.build/**`. This includes
Python bytecode, virtual environments, and caches created by `pb`; no source-adjacent cache exception exists.

### 3.3 Dependency-resolution output

Lock files, freeze files, solver plans, checksums, resolved versions, package graphs, downloaded archives, and
absolute executable paths are run observations. They are emitted beneath `.build/locks/**` or
`.build/toolchain/**` and never committed.

### 3.4 Generated source, tests, and documentation

Generated source is still generated. Dhall, PureScript, JavaScript, shell, Proto, Pulumi, SQL, TLA+, checking
tools, Dockerfiles, test programs in another language, and serialized fixture/oracle/mutant files remain
untracked even when a third-party compiler requires them.

Governed Markdown is an authored non-source input. Generated Markdown, tables, diagrams, dashboards, and
reports go to `.build/docs/**`; governed documents declare `**Generated sections**: none`.

### 3.5 TSV inventory and provenance

TSV, JSON, YAML, CSV, golden, expected-output, and diagnostic text are transport formats, never tracked source
classes. Haskell may render them beneath `.build/**` for a consumer. A semantic expectation that needs one of
those formats is authored as Haskell and encoded only for the duration of the check.

### 3.6 Authored negative corpora and their audit scope

Negative corpora have no file-format exemption. A mutation retained in Git is an exact Haskell value or
`.hs` source transformation with an independently reviewed expected failure. Applying it produces a disposable negative
under `.build/test-corpora/**`. The gate must prove that the transformation changed the intended production
locus and that the clean control still succeeds; a copied bad file is not an oracle.

## 4. Dependency and toolchain resolution

amoebius records compatibility requirements in Haskell or the minimal bootstrap metadata. Each clean run
resolves current compatible tools and dependencies, verifies publisher-provided authenticity material, and
records the result beneath `.build/**`. A missing tool is acquired rather than treated as an undeclared host
prerequisite.

No tracked file contains a developer-home path, host-specific executable path, resolved archive digest, or
dependency graph. Standard guest paths are contractual only when the generated guest image owns them.

### 4.1 A compatibility edit is fixed source, not a patch against a moving head

The previous tracked-vendor rule is retired for non-Haskell source. A required external program is acquired
into `.build/vendor/**` at a recorded identity. If compatibility requires a transformation, Haskell declares
and applies that transformation after acquisition; any patch text is generated under `.build/**`. A maintained
Haskell fork may live under `src/vendor/**` because it still satisfies the `.hs` source rule.

This preserves reviewable intent without introducing a second tracked implementation language. A dependency
that cannot be acquired, transformed, and verified under this rule is unsupported rather than silently
vendored.

## 5. Run evidence and phase status

A gate emits candidate evidence beneath `.build/runs/**` and may install a content-addressed receipt beneath
`.build/evidence-store/**`. Git contains neither. A digest establishes provenance only; it does not establish
correctness or authorize a status change.

Only the human user may promote a phase or sprint to Done or Validated. The plan records that decision after
the gate, oracle-independence review, sabotage controls, predecessor chain, typed Haskell legacy closures, and
human review of their reader-facing correspondence have all been inspected. Doctrine does not record current
validation results.

## 6. `.gitignore` contract

`.gitignore` excludes all of `.build/`, `.data/`, and `.test_data/`, plus tool-specific spill classes that a
misdirected command might create. Source-adjacent `__pycache__/` or Python bytecode is a containment failure,
even when a defensive ignore pattern catches it. An ignore rule does not
make a path conforming: the source-boundary audit must still reject an ignored source input used to complete a
build or gate.

Migration-only ignore rules retire with their paths. An obsolete rule is a finding because it can conceal a
reintroduced root.

## 7. `.dockerignore` contract

`.dockerignore` excludes version-control metadata, all three contained-state roots, secrets, evidence, caches,
resolved dependencies, and every tool-specific spill class. A generated artifact needed by an image build is
regenerated in a staged build or passed explicitly from the current `.build/**` materialization; the context is
never broadened to include local state.

## 8. Enforcement and source-snapshot acceptance

Every candidate phase gate inherits these fail-closed checks:

1. Classify every tracked path by role, extension, executable bit, shebang, and content signature.
2. Reject behavioral source that is not `.hs`, except bounded Python under `pb/**`, unless the finding joins
   in both directions to one typed Haskell migration binding owned by a strictly later phase. That temporary
   accounting rule admits no new input and expires at the typed owner phase; the Markdown register is not an
   operand.
3. Reject `pb` logic that decides a validation result or continues past Haskell `exec` handoff.
4. Reject tracked serialized fixtures, oracles, expected outputs, mutants, or checking programs.
5. Materialize every required non-Haskell input from Haskell into a fresh `.build/**` tree.
6. Run clean-room checks with the condemned tracked copies physically absent.
7. Reject any generator or test write beneath an authored root.
8. Reject any required ignored or untracked worktree input.
9. Reject generated, evidentiary, secret, cache, or runtime-state bytes in the effective container context.
10. Leave tracked files unchanged and no unignored output behind.
11. Require zero findings for Haskell bindings owned by the candidate or any earlier phase, exact two-way
    equality between remaining findings and strictly-later typed bindings, and no stale, duplicate,
    reassigned, missing, or unbound Haskell entry. Row content and count in the reader-facing register cannot
    affect this result.
12. Treat receipts and hashes as provenance, never as correctness or promotion authority.

The audit must include no-op, constant-success, extension-renaming, shebang-without-extension, misplaced-source,
empty-discovery, missing-oracle, skipped-mutant, stale-evidence, and tracked-copy-present sabotage cases. Each
applicable sabotage must make the audit red for the intended reason before a clean run can be considered.

Hardware discovery and live infrastructure are prohibited until the human user accepts the hardware-free DSL
promotion barrier and every predecessor. A container cannot establish the semantics of the DSL that generates
its own recipe or runtime inputs.

## 9. Migration boundary

The target grammar above does not assert that the current tree conforms. Every current non-Haskell source
family outside `pb/**`, every serialized behavioral input, and every obsolete source root is an active
divergence until its typed Haskell closure binding reaches zero, its independent Haskell reintroduction case
fails at the intended locus, and the human accepts the evidence. The corresponding row in
[`legacy_tracking_for_deletion.md`](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md) is then reconciled
or removed as a reader-facing change; editing or deleting it cannot close the executable binding.

Documentation adoption, a passing legacy command, or the presence of Haskell wrappers supplies no migration
evidence. A phase may close only after its old source is absent and its clean-room Haskell materialization is
independently reviewed. Human review also confirms that the one reader-facing register still corresponds to
the compiled inventory. Git history is the archive; no second legacy-register file is admitted.

## Related Documents

- [JIT Artifact Doctrine](./jit_artifact_doctrine.md) — artifact recipes, addresses, and lifetimes
- [Generated Artifacts](./generated_artifacts_doctrine.md) — the semantic no-commit rule
- [Testing Doctrine](./testing_doctrine.md) — Haskell expectations and generated test encodings
- [Documentation Standards](../documentation_standards.md) — governed Markdown as an authored non-source input
- [Development Plan Standards](../../DEVELOPMENT_PLAN/development_plan_standards.md) — phase-gate adoption
- [Legacy Tracking](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md) — the sole reader-facing
  divergence explanation; reviewed Haskell owns executable bindings
