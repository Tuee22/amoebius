# Repository Layout and Artifact Provenance

> **Purpose**: Define the complete amoebius repository layout, the authored-versus-derived classification,
> every generated-output class, and the required `.gitignore` and `.dockerignore` contracts.
> **Read this if**: a file is being added, generated, moved, ignored, packaged into a container context, or
> considered for version control.

This document owns repository placement and artifact provenance. It does not own a generator's domain
semantics, which remain with that subsystem's doctrine. Phase sequencing and migration status live in
[`../../DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md). Familiarity with the generated-artifact
rule in [`generated_artifacts_doctrine.md`](./generated_artifacts_doctrine.md) is useful but not required.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/engineering/README.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/reading_order.md, documents/engineering/substrate_doctrine.md
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

Every repository path has exactly one provenance class.

| Class | Meaning | Version-controlled |
|---|---|---|
| Authored input | A human-maintained source, contract, independent fixture, or policy | Yes |
| External immutable input | Reviewed vendored source or patch whose upstream provenance is recorded | Yes |
| Derived output | Any file reproducible from another file, command, compiler, resolver, renderer, or test | No |
| Run evidence | Logs, receipts, ledgers, traces, reports, screenshots, and machine observations from one execution | No |
| Runtime state | Secrets, credentials, caches, downloaded tools, browser profiles, databases, and local service state | No |

A file's extension does not decide its class. An independently authored `.json`, `.tsv`, `.dhall`, or golden
may be source. The same extension emitted by a command is derived output. Copying, renaming, or reformatting a
derived file does not convert it into authored input.

The classification question is mechanical: if repository inputs plus a documented command can reproduce the
file, the file is generated and cannot be version-controlled. A generated result may be inspected in `gen/`
or retained in the external evidence store, but it never moves back into an authored root. Python interpreter
bytecode is the sole location exception: it may be cached beside imported source, but both ignore contracts
exclude it and it is never an authored input, tracked file, or container-context input.

## 2. Complete repository structure

The tree below is exhaustive by ownership. `**` denotes every descendant of the named root. A new top-level
root requires an amendment here before code is added.

```text
amoebius/
├── .git/**                               local VCS metadata; never a build/context input
├── .dockerignore                         authored container-context policy
├── .gitignore                            authored worktree policy
├── AGENTS.md                             authored agent policy
├── CLAUDE.md                             authored agent policy
├── README.md                             authored repository entry point
├── amoebius.cabal                        authored root package declaration
├── cabal.project                         authored package set and resolver constraints
├── package.json                          authored JavaScript tool requirements
├── package-lock.json                    present generated migration file; delete and ignore
├── DEVELOPMENT_PLAN/                     authored plan suite
│   ├── README.md
│   ├── development_plan_standards.md
│   ├── later_phases.md
│   ├── legacy_tracking_for_deletion.md
│   ├── overview.md
│   ├── substrates.md
│   ├── system_components.md
│   └── phase_00_*.md ... phase_64_*.md
├── documents/                            authored doctrine suite
│   ├── README.md
│   ├── documentation_standards.md
│   ├── glossary.md
│   ├── reading_order.md
│   ├── engineering/**
│   └── illegal_state/**
├── app/**                                authored executable entry points
├── src/**                                authored root Haskell source
├── dhall/**                              authored schemas, examples, and independent fixtures
├── pb/**                                 authored Python bootstrap coordinator and bootstrap inputs
├── ui/**                                 authored UI Haskell/PureScript sources
├── ui-live/**                            authored live UI package sources and tests
├── ui-runtime/**                         authored generic browser-runtime source
├── offline-runtime/**                    authored offline-runtime package
├── apple-host/**                         authored Apple host-worker package
├── amoebius-pulsar/**                    authored Pulsar package and source `.proto`
├── amoebius-pulumi/**                    authored Pulumi package
├── amoebius-release/**                   authored release package
├── amoebius-runtime/**                   authored runtime package
├── amoebius-store/**                     authored store package
├── infernix/**                           authored lifted infernix library
├── infernix-ui/**                        authored infernix UI adapter
├── jitml/**                              authored lifted jitML library
├── jitml-ui/**                           authored jitML UI adapter
├── probe/**                              authored toolchain/build probes and independent inputs
├── pulumi/**                             authored infrastructure programs
├── test-topology/**                      authored topology package
├── test/**                               authored tests, fixtures, oracles, and mutants
├── tests/**                              authored legacy test layout pending convergence
├── mutants/**                            authored seeded mutants
├── tools/**                              authored gates, generators, lints, seeds, and mutation recipes
├── vendor/**                             reviewed external source and local compatibility edits
├── patches/**                            reviewed authored compatibility patches
├── docker/**                             authored image inputs only; rendered recipes go to `gen/docker/`
├── toolchain/requirements.json           authored compatibility requirements; no path, version, URL, or digest
├── gen/**                                all canonical reproducible local output; never version-controlled
├── dist-newstyle/**                      present Cabal output; never version-controlled
└── node_modules/**                       present package-manager output; never version-controlled
```

The following present-day roots are migration surfaces, not additional canonical source classes:

| Present path | Required destination |
|---|---|
| `DEVELOPMENT_PLAN/evidence/**` | `gen/runs/**` plus the external evidence store |
| `DEVELOPMENT_PLAN/ledgers/**` | authored reasoning retained in a phase doc; generated ledger views move to `gen/docs/**` |
| `test/enumeration/**` | `gen/test-surfaces/**` |
| `test/golden/phase_*_ledger.json` | `gen/runs/<phase>/<run-id>/ledger.json` |
| root dependency lock/freeze files | `gen/locks/**` |
| `toolchain/pins.json` | **migrated.** The authored half is `toolchain/requirements.json` — compatibility ranges, release channels, and asset patterns, no paths; the resolved half is `gen/toolchain/resolved.json`, written per run by `tools/toolchain.py` |
| `tools/doc_lint_corpus/**/negative_*` and `negative_multi_*` | keep authored positive seeds and mutation recipes; materialize negative copies under `gen/test-corpora/**` |
| `test/golden/phase_53/job_*.expected` | retain the reference program and authored inputs; produce expected results under the run bundle |
| Phase-49 frozen-source and expected-hash tables | resolve the reviewed sibling source boundary at run time and record observations under `gen/runs/**` |
| fixed versions, URLs, paths, or integrity fields in bootstrap/toolchain envelopes | split authored compatibility requirements from run-local resolution under `gen/toolchain/**` |
| generated digest, checksum, trace, and expected-output fixtures | independently author and review the expectation, or regenerate it under the owning run bundle |

The `test/` and `tests/` roots may coexist during migration. A fixture remains version-controlled only when
its expectation was authored independently. A generated snapshot, reference-program output, enumeration,
coverage table, or run ledger cannot remain in either root.

## 3. Complete generated-output inventory

Every generated file belongs to one of the paths below, including the explicitly source-adjacent Python cache
patterns in §3.2. A generator requiring a new output class must amend this inventory before it writes the file.

### 3.1 Canonical `gen/` tree

```text
gen/
├── tla/**/*.tla                          emitted TLA+ modules
├── tla/**/*.cfg                          emitted TLC configurations
├── manifests/**/*.{yaml,yml,json}        rendered Kubernetes and provider objects
├── dhall/**/*.dhall                      reflected or projected Dhall
├── dsl/**                                decoder/fold/bind battery observations and locus ledgers
├── ui/**                                 client/server/offline plans and compiled browser output
│   ├── client-plans/**
│   ├── server-plans/**
│   ├── contracts/**
│   ├── codecs/**
│   ├── migrations/**
│   ├── service-workers/**
│   └── bundles/**
├── docker/**/Dockerfile                  rendered image recipes
├── proto/**/*.hs                         generated protobuf Haskell modules
├── proto/**/*.{hi,o,dyn_hi,dyn_o}        protobuf compiler output
├── test-surfaces/phase_*.json            runtime test enumeration
├── test-corpora/**                       materialized negatives derived from authored seeds/recipes
├── locks/**                              dependency solver output
│   └── phase_*/resolution-*.json
├── toolchain/**                          downloaded/resolved tool state
│   ├── resolved.json
│   ├── downloads/**
│   ├── bin/**
│   └── runtime/**
├── runs/<phase>/<run-id>/**              one-run evidence
│   ├── ledger.{json,tsv}
│   ├── receipt.{json,tsv}
│   ├── commands.json
│   ├── environment.json
│   ├── toolchain.json
│   ├── substrate.json
│   ├── checks.{json,tsv}
│   ├── mutants.{json,tsv}
│   ├── coverage.{json,tsv,xml}
│   ├── junit.xml
│   ├── traces/**
│   ├── logs/**
│   ├── screenshots/**
│   ├── browser-profile/**
│   └── topology/**
├── docs/**                               generated dashboards and reports
└── tmp/**                                disposable generator scratch space
```

### 3.2 Build, compiler, package-manager, and cache output

| Pattern | Generated content |
|---|---|
| `dist-newstyle/**`, `.cabal-sandbox/**`, `.ghc.environment.*` | Cabal/GHC plans, builds, indexes, objects, interfaces |
| `**/*.{o,hi,dyn_o,dyn_hi,hie}` | Haskell compiler output |
| `node_modules/**` | npm-installed dependency trees and their nested lock metadata |
| `ui-runtime/.spago/**`, `ui-runtime/output/**`, `ui-runtime/dist/**` | Spago and PureScript build state |
| `**/__pycache__/**`, `**/*.{pyc,pyo,pyd}` | Source-adjacent Python interpreter caches; permitted locally only because both ignore contracts exclude them |
| `.pytest_cache/**`, `.coverage*`, `htmlcov/**`, `coverage/**` | Python and general coverage state |
| `toolchain/bin/**`, `toolchain/runtime/**`, `toolchain/downloads/**`, `toolchain/cache/**` | acquired tools and archives |
| `.phase*-build/**`, `phase*-build/**`, `build/**`, `_build/**`, `out/**`, `output/**`, `dist/**` | phase and language build roots |
| `.cache/**`, `tmp/**`, `temp/**` | local caches and temporary files |
| `playwright-report/**`, `test-results/**`, `screenshots/**` | browser/test reports |
| browser profiles, SQLite run databases, PID files, sockets, logs | ephemeral runtime state |

### 3.3 Dependency-resolution output

No `.lock` or `.freeze` file is version-controlled. The rule covers, without exception:

- `cabal.project.freeze`, `*.freeze`, and `*.lock`;
- `package-lock.json`, `npm-shrinkwrap.json`, `yarn.lock`, and `pnpm-lock.yaml`;
- `spago.lock`, `flake.lock`, `poetry.lock`, `Pipfile.lock`, `Gemfile.lock`, `composer.lock`, and `mix.lock`;
- `go.sum` and any package-manager checksum database;
- any generated package graph, solver plan, downloaded-package manifest, or dependency SHA table.

### 3.4 Generated source, tests, and documentation

The prohibition includes generated source code. Protobuf bindings, reflected codecs, generated PureScript,
test enumerations, expected outputs produced by a reference program, generated Markdown, tables, diagrams,
contents blocks, and copied command output remain untracked. The original `.proto`, authored reference
implementation, authored expectation, or authored prose remains the source.

A generated negative corpus follows the same rule. Version control retains the smallest independently
meaningful source: positive seed files, an explicit mutation definition, and the checker. Mutated copies,
Cartesian expansions, and other mechanically materialized negatives are emitted under `gen/test-corpora/`
or a temporary directory. Their number, path layout, or usefulness as test input does not make them source.

Generated Markdown is written only under `gen/docs/**`. Governed Markdown under `documents/` and
`DEVELOPMENT_PLAN/` always declares `**Generated sections**: none`.

### 3.5 TSV inventory and provenance

TSV is a transport format, not a source class. The repository audit classifies the present TSV families as
follows:

| Path or filename family | Classification and destination |
|---|---|
| `DEVELOPMENT_PLAN/evidence/**/*.tsv` | Generated run evidence; relocate to `gen/runs/<phase>/<run-id>/**`, attest externally, and remove from the plan tree |
| `gen/**/*.tsv` | Canonical local generated output; ignored and never version-controlled |
| `phase-results.tsv`, `validation-locus-ledger.tsv`, `live-*.tsv`, `sprint-*.tsv`, `*-red-before-correction.tsv` in any root | Generated observation or report; canonicalize beneath the owning run bundle |
| `dhall/examples/locus_registry.tsv`, `test/fixtures/**/*.tsv`, `test/formal/**/oracle/**/*.tsv`, non-ledger `test/golden/**/*.tsv`, `test/oracle/**/*.tsv`, `tests/oracle/**/*.tsv` | Candidate authored fixture/oracle; version-control only with independent authorship or review provenance |
| `mutants/**/*.tsv`, `test/mutants/**/*.tsv`, `tests/mutants/**/*.tsv`, `tools/ledger_lint_corpus/**/*.tsv` | Candidate authored negative corpus; version-control only when rows are intentionally authored and not emitted by the system under test |
| Any `expected_hashes.tsv`, `expected_digests.tsv`, `reference_traces.tsv`, expected-output table, or copied inventory | Ambiguous migration input; the owning phase must establish independent authorship or regenerate it under `gen/**` |

Renaming a run ledger to “golden” or an emitted table to “oracle” does not make it source. Phase 0 records the
provenance decision for shared corpora; each later phase owns its domain-specific tables before revalidation.

## 4. Dependency and toolchain resolution

amoebius records requirements, not resolver output. An authored requirement may state a compiler/API
compatibility range, a package name, a release channel, or a minimum feature set. It does not contain a
library archive SHA, package checksum, transitive solver graph, local executable path, or user-home path.

Each clean run resolves the current compatible set dynamically. The resolver writes versions, source
identities, download URLs, observed checksums, signatures, executable paths, and the complete dependency graph
to `gen/toolchain/**` and `gen/locks/**`. Those observations are attached to external run evidence, not copied
into Markdown or a tracked manifest.

Transport authentication and upstream signatures are verified when an ecosystem supplies them. A checksum
computed after resolution detects corruption within that run; it is not promoted into a permanent package
pin. This policy deliberately trades repository-embedded frozen resolution for continuously refreshed
compatibility evidence.

No tracked file may contain an absolute path beneath a developer home directory. Gates resolve logical tool
names through the run-local toolchain record. Standard guest paths may be contractual only when the guest
image itself owns them.

## 5. Run evidence and phase status

A gate emits its evidence under `gen/runs/**` and uploads an immutable attestation to an external evidence
store. Git contains neither the ledger nor a copy of the receipt. The attestation binds the source tree,
phase contract, command, resolved dependency graph, toolchain, substrate, checks, mutants, coverage, cleanup,
and raw-observation digests.

The development-plan tracker records the human status decision and an external run reference when needed. It
does not embed a generated ledger hash or duplicate run output. A Done decision requires a run whose recorded
source-snapshot digest still matches the tree; editing the source afterwards invalidates the binding and needs
a fresh run. Commit timing is orthogonal and is never a gate condition.

## 6. `.gitignore` contract

The tracked `.gitignore` must cover every generated class. The following block is normative content implemented
by the current policy; order and stricter additions may differ, but coverage may not regress.

```gitignore
# Canonical generated roots
/gen/
/DEVELOPMENT_PLAN/evidence/
/DEVELOPMENT_PLAN/ledgers/
/test/enumeration/
/test/golden/phase_*_ledger.json
/test/golden/phase_54_expected_run_ledger.json

# Dependency resolver output
*.lock
*.freeze
package-lock.json
npm-shrinkwrap.json
pnpm-lock.yaml
go.sum

# Haskell
/dist-newstyle/
/.cabal-sandbox/
.ghc.environment.*
cabal.project.local
*.o
*.hi
*.dyn_o
*.dyn_hi
*.hie

# JavaScript and PureScript
/node_modules/
/ui-runtime/.spago/
/ui-runtime/output/
/ui-runtime/dist/

# Python
__pycache__/
*.py[cod]
.pytest_cache/
.mypy_cache/
.ruff_cache/
.coverage
.coverage.*
htmlcov/
coverage/

# Tool acquisition and phase builds
/toolchain/bin/
/toolchain/runtime/
/toolchain/downloads/
/toolchain/cache/
/.phase*-build/
/phase*-build/
/build/
/_build/
/out/
/output/
/dist/
/.cache/
/tmp/
/temp/

# Test and runtime output
/playwright-report/
/test-results/
/screenshots/
/browser-profile/
*.log
*.pid
*.sock

# Local credentials and runtime state
/.env
/.env.*
!/.env.example
/.secrets/
/.credentials/
/kubeconfig
```

A generic ignore pattern never substitutes for the provenance check. CI must also reject a tracked file whose
header or generator registry classifies it as derived.

## 7. `.dockerignore` contract

The Docker context excludes every derived, evidentiary, secret, and runtime-state class. It is at least as
strict as `.gitignore` for generated content.

```dockerignore
.git
.git/**
gen
gen/**
DEVELOPMENT_PLAN/evidence
DEVELOPMENT_PLAN/evidence/**
DEVELOPMENT_PLAN/ledgers
DEVELOPMENT_PLAN/ledgers/**
test/enumeration
test/enumeration/**
test/golden/phase_*_ledger.json
test/golden/phase_54_expected_run_ledger.json
**/*.lock
**/*.freeze
**/package-lock.json
**/npm-shrinkwrap.json
**/pnpm-lock.yaml
**/go.sum
dist-newstyle
dist-newstyle/**
cabal.project.local
node_modules
node_modules/**
ui-runtime/.spago
ui-runtime/.spago/**
ui-runtime/output
ui-runtime/output/**
ui-runtime/dist
ui-runtime/dist/**
**/__pycache__
**/__pycache__/**
**/*.pyc
**/*.pyo
**/*.pyd
.pytest_cache
.mypy_cache
.ruff_cache
htmlcov
coverage
toolchain/bin
toolchain/bin/**
toolchain/runtime
toolchain/runtime/**
toolchain/downloads
toolchain/downloads/**
.phase*-build
phase*-build
build
build/**
_build
_build/**
out
out/**
output
output/**
dist
dist/**
.cache
.cache/**
tmp
tmp/**
temp
temp/**
playwright-report
test-results
screenshots
browser-profile
browser-profile/**
**/*.log
**/*.pid
**/*.sock
.env
.env.*
.secrets
.secrets/**
.credentials
.credentials/**
kubeconfig
```

An image build that needs a derived artifact regenerates it inside a staged build or receives it as an
explicit build input from the current run. It never broadens the context to include local caches or evidence.

## 8. Enforcement and source-snapshot acceptance

Every phase gate inherits these postconditions:

1. The run binds to its source snapshot: every non-ignored file as it stands when the gate starts.
2. Every deliberate generator writes only to `gen/`, a declared build root, or a temporary directory; normal
   source-adjacent Python interpreter caches are the sole location exception.
3. Test enumeration is regenerated and joined to independently authored expectations by stable identity.
4. No test or generator writes beneath an authored root except for Python's ignored interpreter cache.
5. `git ls-files` contains no derived path, generated header, lock/freeze file, bytecode, or run evidence.
6. The gate leaves every tracked file unchanged and creates no unignored generated file.
7. The Docker context audit contains no derived output, evidence, cache, credential, or runtime state.
8. The external attestation verifies before the phase can be marked Done.
9. The source snapshot contains every authored input referenced by a build, test, or gate; an ignored
   worktree file can never complete the repository's source closure.
10. The tracked-tree audit classifies files semantically, not only by ignore-pattern or path match, and rejects
    reproducible copies even when they live in an otherwise authored root.

Python commands run with ordinary bytecode caching enabled. The cache may remain beside source on a developer
worktree because `.gitignore` excludes `__pycache__/` and all Python bytecode suffixes, while `.dockerignore`
excludes the same paths from every build context. Phase 0 rejects missing patterns, tracked bytecode, Docker
context leakage, and command-level bytecode suppression; it does not require deleting a valid ignored cache.

Phase 0 audits two different boundaries. The current-tree audit covers tracked, ignored, untracked, and
effective Docker-context paths, then repeats the documented verifier against the source snapshot alone. The revision-history
audit separately scans reachable commits for secrets, credentials, generated artifacts, obsolete names, and
other files that current ignore rules cannot remove retroactively. Unreachable local objects are reported as
local state and are not treated as part of the shared repository closure.

A secret or credential found in history requires immediate rotation and a coordinated history purge. A
non-secret generated or obsolete historical blob requires forward removal plus an explicit recorded decision:
retain the old history, or perform an operator-approved coordinated rewrite. A documentation or cleanup phase
must never rewrite shared history implicitly.

When a pristine Linux host is required, every hardware substrate supplies the `linux-cpu` lane. Incus is used
on Linux and Linux-CUDA hosts, Lima on Apple, and WSL2 on Windows. A specialized Apple or Linux-CUDA gate may
add its one specialized lane without removing the baseline.

## 9. Migration boundary

The repository does not yet satisfy this doctrine. The current generated ledgers, evidence, enumeration,
derived test corpora, reference-program outputs, checksum/digest fixtures, resolved paths, and hard-coded
package integrity values are migration inputs, not exceptions. Ignored authored compatibility patches and
human reasoning in ignored phase ledgers must be relocated before their old paths are deleted. Their exact
disposition is tracked in
[`../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md).

Documentation adoption alone supplies no implementation evidence. The 2026-08-11 source-closure audit found the
Phase-0 verifier depending on ignored inputs; as of 2026-08-12 the provenance classifier, semantic tracked-path
and effective Docker-context audits, authored-root write guard, history audit, fresh-clone gate,
dynamic-resolution audit, and external attestation are implemented and pass two-sided from a clone. Phase 0
is sealed: the gate publishes an attestation bound to the source snapshot it ran against.

The migration surface those checks reveal is not closed by them. Each finding outside the running phase's
ownership is deferred to the phase named in
[`../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md),
reported on every run, and cleared by that phase's gate. Every later phase remains reopened until its gate
uses the new output paths, produces external evidence, and passes the source-snapshot acceptance above.

## Related Documents

- [Generated Artifacts](./generated_artifacts_doctrine.md) — semantic rule for projections and authored inputs
- [Testing Doctrine](./testing_doctrine.md) — enumeration, independent expectations, and external evidence
- [Documentation Standards](../documentation_standards.md) — governed Markdown remains authored
- [Development Plan Standards](../../DEVELOPMENT_PLAN/development_plan_standards.md) — phase-gate adoption
- [Legacy Tracking](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md) — migration work and deletion owners
- [Substrate Doctrine](./substrate_doctrine.md) — universal `linux-cpu` and pristine-host routing
