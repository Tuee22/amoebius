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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_03_typed_spine.md, DEVELOPMENT_PLAN/phase_05_substrates_lanes_image_recipe.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/validation_frame_doctrine.md
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

🔄 Active — NOT VALIDATED.

The contract is reopened under [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) by
[DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice): the subject moves
from the validator into product code and absorbs the source queries of the retired tool-generation phase.
Under §N step 3, every generation-1 receipt for this phase was incompatible with certification generation 2 and
supplied no authority. Earlier verifier runs recorded receipts and immutable observations beneath
`validation-records/`, including replays after
[DL-0022](../documents/decision_log.md#dl-0022--phase-2-accepted-its-owed-by-paragraphs-become-observed-implementations)
re-mooded the paragraphs that had named this phase as owing. A subsequent audit found the missing
inherited legacy analyzer/evidence join. The verifier revoked the selected receipts and reopened the
documentation gate; this phase now requires fresh numerical qualification.

The historical layout runs remain bounded source and mutation observations. They do not establish a
current complete gate pass or discharge the inherited legacy obligations.

The independent oracle requires all 294 external class-method contracts, including the exact
`NFData Detected` and `NFData SubstrateProfile` contracts from `Control.DeepSeq`. Per-contract interface,
package, import, and source-membership checks remain mandatory, with no uncontracted method admitted.
Later closure changes require fresh replay under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase).

## Phase Summary

Phase 2 closes the tracked source boundary. `Amoebius.Layout.Classify` assigns every tracked path exactly one
class from the closed rule in the repository-layout doctrine; `Amoebius.Layout.PbGrammar` admits the bounded
bootstrap through a deny-by-default syntax, import, call, and effect graph; `amoebius layout-report` prints the
classification for the oracle to judge. No Markdown row, count, or tracker status is an input to any of them.

The admitted non-Haskell tracked **metadata** set is exactly six files, named by class rather than by name:
the package description and the project description, the two ignore files, the licence text, and one
packaging-metadata file. Markdown is excluded from that count, and `pb/__main__.py` is the separately admitted
bounded bootstrap. Accepted bundles and red-replay void markers under the exact `validation-records/**` archive grammar are a
separate non-source class. A seventh metadata file or an unexpected archive file is a refusal, whatever its
extension or claimed role ([DL-0018](../documents/decision_log.md#dl-0018--plan-claims-follow-the-keyless-gates-observed-scope),
[DL-0019](../documents/decision_log.md#dl-0019--red-replay-leaves-an-immutable-revocation-record)).

This phase absorbs the source queries the retired tool-generation phase owned: the tool root, the Pulumi
program root, and the non-Haskell test inputs are refused here as paired negatives. Dhall, Proto, and UI roots
are classified to their owners — Phase 3 for Dhall and Proto, Phase 8 for the UI language share, and Phase 72 for the UI generated-artifact share — and reported as owed, never admitted.

**Phase scope:** One cohesive claim — the shipped binary's layout report classifies every tracked path against the closed rule, the admitted non-Haskell metadata set is exactly six files plus the exact accepted historical-evidence class, every Phase-2 source query is zero, and a compiler-backed graph resolves Haskell imports, calls, control flow, potential effects, content roles, provenance, dynamic loads, sinks, and consumers across the complete source inventory. Product behaviour and host effects remain with their later owners.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 1](phase_01_toolchain_spike.md)
**Forward-deferred:** Dhall and Proto declarations rendered from Haskell — [Phase 3](phase_03_typed_spine.md) `typed_spine` / `LTD-SRC-002`, `LTD-SRC-003`; UI language share — [Phase 8](phase_08_ui_program_language_binding.md) `ui_program_language_binding` / `LTD-SRC-004`; UI generated-artifact share — [Phase 72](phase_72_ui_program_release.md) `ui_program_release` / `LTD-UI-001`
**Gate:** `pb validate phase 02`; see [Gate integrity](#gate-integrity).

### Gate specification

```gate-spec
capability: repository_layout_conformance
role: ordinary
claim: The shipped layout-report classifies every present source path, enforces the six admitted metadata paths and bounded bootstrap bytes, and resolves the compiler-backed whole-source graph; the independent oracle judges planted foreign inputs and typed legacy ownership. Archive custody remains verifier-owned.
subjects: Amoebius.Layout.Classify, Amoebius.Layout.PackageMap, Amoebius.Layout.PbGrammar, Amoebius.Layout.Report, Amoebius.Layout.SourceGraph
suite: layout-suite
oracle: oracle-layout
positive: case:positive.bootstrap | input=pb/__main__.py | expected=admitted
positive: case:six-metadata-files | input=six metadata paths | expected=six classes
positive: case:positive.archive | input=accepted bundle path | expected=historical-evidence
positive: case:graph-qualified | input=whole source inventory | expected=resolved
negative: case:negative.python | input=src/example.py | tag=NonHaskellSource | stage=classify
negative: case:negative.dhall | input=dhall/example.dhall | tag=ForeignSourceOwed | stage=classify
negative: case:negative.pulumi | input=pulumi/Pulumi.yaml | tag=TrackedPulumiProgram | stage=classify
negative: case:negative.test-table | input=test/layout/expected.tsv | tag=NonHaskellTestInput | stage=classify
negative: case:negative.ignore-root | input=ui/output | tag=RetiredIgnoreRoot | stage=classify
negative: case:negative.ordinal | input=src/Amoebius/Phase42Runtime.hs | tag=OrdinalRuntimeIdentity | stage=classify
negative: case:graph.ambiguous-import | input=ambiguous import fixture | tag=AmbiguousSourceImport | stage=graph
negative: case:graph.module-path-mismatch | input=misdeclared module fixture | tag=ModuleDeclarationPathMismatch | stage=graph
mutants: stages=Amoebius.Layout.Classify,Amoebius.Layout.PackageMap,Amoebius.Layout.PbGrammar,Amoebius.Layout.Report,Amoebius.Layout.SourceGraph per-module=8 cap=40 kill-ratio=3/5
binary-fact: command=layout-report --root {tree} --paths-file {input} --output {run}/layout-report.tsv | input=paths.txt | perturbation=plant-foreign-paths(src/Challenge{nonce}.py=NonHaskellSource,dhall/Challenge{nonce}.dhall=ForeignSourceOwed,pulumi/Pulumi{nonce}.yaml=TrackedPulumiProgram) | outputs={run}/layout-report.tsv
substrate: none
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

**Current gap:** All seven owning bindings have component qualification. The whole-snapshot
`bootstrap-source` factory passes nine focused oracle checks and all forty-three independent
qualification-join checks. The captured-bootstrap regression passes all twenty-eight independent join
checks, including refusal to borrow its proof for the whole-snapshot owner. The complete layout
regression passes 1,424 independent checks and the runner regression passes 745; documentation checking
reports zero findings. Fresh numerical predecessor replay, phase preview and phase acceptance remain
required; these component results do not advance status. The source-bound `source-graph` factory passes thirteen focused oracle checks and all
fifty-two independent qualification-join checks. The source-bound `ignore-context`
factory passes seven focused oracle checks and forty-two independent qualification-join checks. The source-bound `runtime-identity`
factory passes nine focused oracle checks and forty-seven independent qualification-join checks. The `pulumi-source`
factory passes seven focused oracle checks and thirty-two independent qualification-join checks. The `tool-source`
factory passes seven focused oracle checks and thirty-two independent qualification-join checks. The
`test-source` factory passes thirteen focused checks and thirty-seven qualification-join checks, including
exact original-tree discovery and four changed-production-source refusals. The complete phase
still requires all seven canonical bindings in one numerical gate.
The Phase-1 gate has passed; its three closed declarations are retired under
[DL-0036](../documents/decision_log.md#dl-0036--phase-1-acceptance-retires-its-qualified-toolchain-bindings),
with retained guards and fresh numerical replay before successor acceptance. Existing layout components
and historical receipts cannot supply those missing qualifications.

The first fresh layout baseline after Phase-1 acceptance produced 1,312 green independent oracle rows
and two red rows: `compiler-residual-ownership-control` and `case:graph-qualified`. It left two imports
qualified with the package name `amoebius` unresolved, producing three opaque calls and keeping the graph
at `partial-calls`. A subsequent source-bound build and complete layout diagnostic passed all 1,339
independent rows, including both original failures. Its report is `resolved`, with no unresolved imports
or opaque calls. These are component observations and supply no phase evidence.

The package-import component passes 23 independent checks over eleven source fixtures. Named source
imports retain their requested package, declared library provider and exact compiler-plan unit. Aliases
distinguish a colliding home module; class, constructor, selector and re-export routes retain that binding.
Wrong packages, absent or ambiguous metadata, ambiguous providers, undeclared source dependencies and
missing compiler-unit dependencies refuse. The missing-unit negative first produced its assigned red
row with the other 22 checks green; after the fix all 23 passed. The oracle checks source literals, exact
call spans and raw graph rows. The existing graph's open-declaration and refusal conditions remain required.

The compiled specification requires every named case to have a green
independent oracle row, and `case:graph-qualified` requires the report's graph stage to be `resolved` — a stage
the product derives from its own rows, with zero unresolved imports, zero unscanned expressions, zero open
declaration rows, and zero opaque call sites. Native GHCup/GHC versions must be compatible; the compiler-backed graph also needs a dependency store with
exactly one registered unit of each pinned version of the maintained fork's three declared external packages
(`logging-3.0.6`, `managed-1.0.11`, and `unagi-chan-0.4.1.4`), installed from Hackage into the user-level Cabal
store (for example with `cabal install --lib`) because no tracked file can carry them. A missing or ambiguous pinned unit is the
named finding `ForkDependencyUnregistered`, never a silent degradation; other versions of the same packages in the
store are ignored. The graph claim is bounded by the limits in the `Residue` row below.

| Key | Contract |
|---|---|
| `Claim` | `amoebius layout-report` classifies every tracked path exactly once against the closed rule: behavioural source is `.hs` outside `pb/**`, the admitted non-Haskell metadata set is exactly six files, the exact `validation-records/**` accepted bundles and void markers are non-source historical evidence, the bounded bootstrap admits through the deny-by-default grammar, and the source query for every Phase-2 identifier is zero. The Phase-2 gate also resolves the compiler-backed whole-source graph required by the frozen gate-integrity rule. Product behaviour and hardware remain later claims ([DL-0018](../documents/decision_log.md#dl-0018--plan-claims-follow-the-keyless-gates-observed-scope), [DL-0019](../documents/decision_log.md#dl-0019--red-replay-leaves-an-immutable-revocation-record)). |
| `Subject` | The layout stage modules, including `Amoebius.Layout.PackageMap` and the compiler-backed `Amoebius.Layout.SourceGraph`, plus the `layout-report` subcommand in `app/amoebius/Main.hs`. Every subject must be inside the closure of `executable amoebius`. |
| `Command` | Future public spelling is `pb validate phase 02`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 02`; then `amoebius-validate accept --phase 02` records the receipt and applies one phase's status patch. The runner spawns the shipped `amoebius` binary as a child for `layout-report` over the tracked tree and over each planted copy. |
| `Oracle` | `test/oracle/layout/Main.hs` restates the classification rule, the six metadata-file classes, the exact accepted-bundle and void-marker archive classes, the grammar's refused node families, and the expected finding per planted negative from literals; its own text scanner `test/oracle/layout/SourceScan.hs` recounts derivation clauses, standalone derivings, instance declarations, sink uses, and each use's consumer literals from raw source; it holds its own sink catalogue and expected fixture rows as literals and depends on no `amoebius` library. |
| `Positive controls` | The tracked tree classifies with zero findings; the bootstrap admits through the grammar; the metadata set matches the oracle's six classes, exact accepted bundles and void markers classify as non-source evidence, the ordinal-identity query is zero, and the whole-source graph is `resolved` with both import partitions closed. |
| `Paired negatives` | A seventh metadata file, an unexpected archive file, a tracked `.py` outside `pb/`, a tracked `.dhall`, a tracked Pulumi YAML, a tracked mutant body, a retired generated root re-admitted in an ignore file, an ordinal-bearing runtime identity, and one forbidden node per grammar family — each refused at its exact locus with the positive twin accepted. For the graph stage, one fixture per way it can stay open (an unresolved import, an unresolved standalone import, an unresolved derivation route, an opaque call site, an unscanned expression, an unscanned declaration) beside a clean twin that is `resolved`, and fork-registration fixtures for a missing, duplicated, wrong-version, and unrelated-version unit. The report's own refusals are fixtures too: an unreadable paths file and a failing Git inventory each exit 2, a bad option exits 2, a finding exits 1, and `--no-graph` states `graph-stage not-computed`; a declared module whose source is absent and is not the forward-owned generated Proto pair is a finding and is never recorded as owed. |
| `Mutants` | Runner-generated from the fixed operator catalogue over the five stage modules, eight per module, at most forty per gate, kill ratio at least 0.6; a mutant in `Amoebius.Layout.Classify` that admits a foreign extension is killed by the planted negatives. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the report's path set equals the present cached-and-untracked Git source inventory, with deleted index paths bound separately by source-snapshot capture; empty discovery refuses. |
| `Challenge` | After the run starts, the runner stages one file whose name carries a nonce into a run-local copy of the tracked tree — once as a `.py` outside `pb/`, once as `.dhall`, once as Pulumi YAML — and the report must refuse each by class with the nonce in the finding. |
| `Observer` | `ProcessObserver` over the shipped binary; executable identity, argv, environment policy, exit, and complete output are runner-captured. No subject log is trusted. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` refuses a subject outside the executable's closure; the oracle stanza's hygiene refuses a product dependency; `pb` is inadmissible as transport; no Markdown row, count, or tracker status reaches the classifier, checked by a compile-negative twin. |
| `Freshness` | A unique run root; a fresh copy of the tracked tree per planted negative; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The runner-generated mutant matrix over the five stage modules — eight per module, at most forty, kill ratio at least 0.6 — precedes the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-02/**` and is absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-SRC-000`, `LTD-SRC-001`, `LTD-SRC-005`, `LTD-SRC-006`, `LTD-SRC-008`, `LTD-META-001`, and `LTD-NAME-001` close here through the compiled inventory. `LTD-SRC-002` and `LTD-SRC-003` are reported as owed by Phase 3 and `LTD-SRC-004` as owed by Phase 72; none is closed here. |
| `Predecessor` | The Phase-1 receipt in certification generation 2, chained by the digest of Phase 1's product closure plus the verifier and governance digests. |
| `Residue` | The runtime handoff of the bootstrap remains Phase 50's claim; Phases 3 through 9 and every phase from 50 onward remain explicit limitations. The graph is a potential-route model over the resolved imports and compiler interfaces, and every attribution in it is at the level of names: a call, derivation, or import is attributed to a candidate that could supply it, never proven to be the one that runs. Runtime dispatch, higher-order flow, the internals of external packages (interfaces are digest-recorded, bodies and instance lists are not read), and the values of non-literal path expressions remain explicit `UNVERIFIED` limitations. A forward-owned, deferred-seed, or available-unit import records an absence or an ownership, not a resolution; a non-buildable component (`lib:infernix`, `lib:jitml`) and the maintained fork are accounted, not compiled. An `external-instance` derivation route records that the delegate's instance is presumed to come from the class's external provider, not that it was found; derived-instance delegation is recorded as routes without being folded into potential-effect reachability. The sink catalogue is a closed list of effect primitives (process, file, environment, network, dynamic-load, and unsafe entities) authored separately in the product and the oracle rather than derived from the libraries' interfaces, so an effect outside it, including ambient clock, randomness, and standard-stream use, is not a sink; a consumer is only a literal path fragment at a catalogued argument position read through path-preserving forms, and a fragment behind a non-literal operand is `dynamic-root`. The graph stage is judged on the report the suite produces from the same library the shipped binary links; the gate's shipped-binary runs plant foreign paths and judge their classification, and their own graph rows are computed but not judged. Native version-compatible tools and the declared dependency units are explicit inputs; the retired bootstrap archive set is not required. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and `accept` records it. |

## Doctrine adopted

- [`repository_layout_doctrine.md` §1 — classification rule](../documents/engineering/repository_layout_doctrine.md#1-classification-rule) — the closed rule the classifier realises.
- [`repository_layout_doctrine.md` §2 — complete repository structure](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) — the final tree and its fixed roots.
- [`repository_layout_doctrine.md` §2.1 — when a unit warrants its own build package](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package) — the criterion a package-only root fails.
- [`repository_layout_doctrine.md` §6 — `.gitignore` contract](../documents/engineering/repository_layout_doctrine.md#6-gitignore-contract) and [§7 — `.dockerignore` contract](../documents/engineering/repository_layout_doctrine.md#7-dockerignore-contract) — the ignore policy derived from the closed roots.
- [`jit_artifact_doctrine.md` §2 — the rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every foreign or generated product is derived lazily beneath `.build/**`.
- [`generated_artifacts_doctrine.md` §3 — the rule](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule) — a generated destination cannot hold bytes until its generator runs.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` this phase carries.

## Sprints

## Sprint 2.1: `test/**` is Haskell modules only 🔄

**Status**: Active — NOT VALIDATED
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

Retain the qualified `test-source` factory and its guards in the complete phase gate while implementation
continues with Sprint 2.2. The shipped classifier exposes its complete test-tree query and
fourteen typed foreign-input examples for the five canonical reintroductions: script, table, expected output,
patch and mutant body. The shipped report projects the example identities. `test/layout/TestSourceCases.hs`
copies the actual test inventory into fresh scratch, acquires each planted file and its bytes, and records
the classifier's results beside a Haskell twin. The separate `test/oracle/layout/TestSourceOracle.hs` states
all paths, bytes, findings and discovery from independent literals. Its focused component has thirteen green
rows, including empty/duplicate inventory and cleanup controls, and independently matched all 398 test
sources observed in that run in both directions. The verifier's factory requires the same
captured source, exact native images, complete oracle ledger and source-copy cleanup; these component rows
alone do not close the binding or validate the phase.

The strengthened source-bound qualification passed thirty-seven independent join checks. The permissive
classifier produced exactly the five required negative refusals; missing empty/duplicate checks each
produced exactly their inventory refusal. A fourth production weakening omitted
`test/layout/ClassEffectRoute.hs`: the subject reported 397 paths, and the independent original-tree walk
found 398, naming that exact missing path with only the discovery row red. All four changed native subject
images were bound to their source witnesses and refused, and all copied source trees were removed. Wrong
source, owner, lifecycle, duplicate evidence and forged observations also refused. The complete layout
regression passed all 1,355 rows after the original-tree strengthening, with a resolved graph and no layout
findings. The runner regression exposed four stale expectations that still listed the now-supported
`LTD-SRC-006` as unavailable. Correcting only that literal list preserves the early refusals for the thirteen
remaining unavailable analyzers in those later-phase fixtures; all 745 runner oracle checks then passed.

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

Retain the qualified `tool-source` factory for the tracked Python gate and renamed tool root in the complete
phase gate while implementation continues with Sprint 2.3. The current complete layout regression passes
all 1,365 independent oracle rows with a resolved graph and no layout findings; the runner regression passes
all 745 oracle checks.
Its five typed product examples cover Python in the original and renamed roots, Haskell in a renamed root,
an extensionless renamed program, and a regular file named `dist-newstyle`. `test/layout/SourcePathCases.hs` materializes each negative beneath
fresh scratch and observes the shipped classifier over the complete protected source inventory; the
separate `test/oracle/layout/ToolSourceOracle.hs` independently walks the original snapshot, compares the
inventory in both directions and requires each exact path, byte sequence and finding. Three changed
`Amoebius.Layout.Classify` builds must independently demonstrate sensitivity to the old tool root, Python
outside the bootstrap and arbitrary renamed roots. The focused suite and independent oracle pass seven
rows over ten positive/negative observations and an exactly matched 1,040-path protected source inventory.
The regular `dist-newstyle` file remains visible and is refused. The shared test-source acquisition also
passes thirteen checks, independently matching all 400 test files in that run. The source-bound factory
passed its seven native oracle rows. Three changed classifier builds each produced exactly their assigned
negative refusal with the other six rows green: admitting the old tool root, admitting Python outside
`pb`, and admitting unknown renamed roots. All thirty-two independent join checks passed, binding each
changed source and native image and confirming wrong-source, owner, lifecycle, duplicate-evidence and forged
observation refusals. All copied source trees were removed.

The shared acquisition encodes canonical slash-separated paths on every native platform and checks directory
kind before excluding state or archive roots; a regular file with a state-root name remains observable.
The test-source apparatus uses that canonical acquisition and retains its separate original-test-tree walk.

The existing product classifier refuses tracked tool roots and admits the one package
description and the probe exception. `Amoebius.Layout.PackageMap` parses both Cabal descriptions with Cabal's own
parser and maps their declared modules against the present Haskell inventory in both directions; the two absent
generated Proto bindings appear as exact `package-owed` rows that the independent oracle checks as forward-owned by
Phase 3. Standalone test inputs and the maintained fork set are bound by source role, and the fork set is
cross-checked against toolchain provenance.

The shipped report parses every Haskell source with the version-compatible GHC parser and joins it to the build. Each
component-owned import is accounted as exactly one of an internal provider, a selected external unit, an available
unit, a forward-owned generated module, a deferred seed module, or an open unresolved row; each import of a
source with no component (a standalone source) is accounted as a source provider, an available registered unit,
a recorded owed module, or an open unresolved row. An external account attributes the import to the module's
registered unit and reads the compiler's interface files for the Prelude and for imported names, recording their
digests; a forward-owned, deferred-seed, or available-unit account records an absence or an ownership, not a
resolution to a definition.

The maintained fork has no Cabal component, so its three external packages are declared once in
`Amoebius.Layout.PackageMap` with the versions the fork tracks (`logging-3.0.6`, `managed-1.0.11`,
`unagi-chan-0.4.1.4`). The loader requires exactly one registered unit of each pinned version, ignores other
versions in the store, treats the unit as an available unit for standalone sources, and reports
`ForkDependencyUnregistered` otherwise; the suite exercises the same seam with a missing, a duplicated, a
wrong-version, and an unrelated-version unit. Adding the packages to a planned component would re-solve the whole
project, so they are deliberately not build dependencies and the units are restored into the user-level store from
Hackage by the operator.

Every call site is attributed to a candidate or explicitly accounted (compiler-rejected, closed-export refusal),
and the reported opaque count is zero. The independent oracle recomputes the two import partitions, the call-site
partition, the lexical and record joins, the class-method dispatch routes, and the potential-effect closure from
the report's own rows and, where it can, from raw source text through its own scanner.

## Sprint 2.3: Tracked foreign roots enter typed ownership ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/Classify.hs`, the separate Phase-2 suite, and `src/plan-decisions/Amoebius/Plan/Legacy.hs`
**Blocked by**: Sprint 2.2
**Independent Validation**: A tracked Pulumi YAML is refused at the layout locus, closing `LTD-SRC-005`. A tracked Dhall file, a tracked Proto schema, and a tracked UI root are each classified to their typed owner — Phase 3 for `LTD-SRC-002` and `LTD-SRC-003`, Phase 8 for `LTD-SRC-004` — and reported as owed, never admitted. Phase 72 owns the generated-artifact share under `LTD-UI-001`.
**Oracle**: `test/oracle/layout/Main.hs` states the owner-by-class table from literals.
**Legacy IDs**: `LTD-SRC-005`; `LTD-SRC-002`, `LTD-SRC-003`, `LTD-SRC-004`, and `LTD-UI-001` reported as owed
**Docs to update**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`

### Objective

Account for every foreign root through the compiled owner map without admitting any of them as source or
treating PureScript, Dhall, Proto, or YAML as an admitted language.

### Deliverables

- The product classifier reports the foreign class without importing validator code. The Phase-2
  suite joins its observed class to `Amoebius.Plan.Legacy` and the separate oracle's owner table.
- The Pulumi refusal; provider declarations render beneath `.build/pulumi/**`.

### Validation

Classify each foreign class; compare the owner with the oracle's table; refuse the Pulumi negative.

### Remaining Work

Retain the qualified `pulumi-source` factory for tracked YAML and renamed YAML, TypeScript and Python
programs. Four typed product inputs feed the shared whole-source apparatus; the separate
`test/oracle/layout/PulumiSourceOracle.hs` owns their expected paths, bytes, findings and discovery. The
source-bound factory and three changed classifier builds must demonstrate sensitivity to the original
Pulumi root, arbitrary renamed roots and Python outside `pb`. The focused suite and independent oracle
pass all seven rows over eight positive/negative observations and an exactly matched 1,041-path source
inventory. The source-bound factory also passes its seven native rows. Three changed classifier builds
each produce exactly their assigned negative refusal with the other six rows green: admitting the original
Pulumi root, admitting unknown renamed roots, and admitting Python outside `pb`. All thirty-two independent
join checks pass, binding source witnesses and changed native images, refusing wrong source, owner,
lifecycle, duplicate evidence and forged observations, and confirming removal of every copied source tree.
The current complete layout regression passes all 1,374 independent oracle rows with a resolved graph
and no layout findings, and the runner regression passes all 745 oracle checks. Implementation can
continue with Sprint 2.4; the complete numerical phase gate remains required. Later-owned source findings
remain explicit debt.

The existing classifier refuses Pulumi paths and reports Dhall, Proto, and UI paths as owed, the
suite joins those classes to typed legacy owners with literals in the separate oracle, and the runner's
shipped-binary challenge plants fresh Python, Dhall, and Pulumi paths in separate copied trees and requires the
exact nonce-bearing finding for each. The owners close their own rows in their own gates.

## Sprint 2.4: Every authored name loses its phase ordinal ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/Classify.hs`, `src/Amoebius/Layout/PackageMap.hs`, the separate layout suite, and `src/plan-decisions/Amoebius/Plan/PhaseIdentity.hs`
**Blocked by**: Sprint 2.3
**Independent Validation**: Zero ordinal-bearing runtime identities is the positive control; a runtime path, build component, or product diagnostic name carrying a phase ordinal is refused; a phase-labelled validation contract is the unaffected control.
**Oracle**: `test/oracle/layout/RuntimeIdentityOracle.hs` states source, component and validation-only expectations from literals; `test/oracle/layout/Main.hs` includes it in the complete suite.
**Legacy IDs**: `LTD-NAME-001`
**Docs to update**: `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`

### Objective

Strip the ordinal from every product and runtime identity and replace it with a capability name derived from
the compiled phase-identity table, which is what makes
[§U](development_plan_gate_integrity.md#u-the-final-repository-layout) clause 3 true.

### Deliverables

- The ordinal arm of the product classifier, with the separate Phase-2 suite checking
  capability names against `Amoebius.Plan.PhaseIdentity`; the product has no validator dependency.
- Phase-labelled validation contracts left phase-labelled and forbidden as runtime identities.

### Validation

Run the ordinal query; plant an ordinal-bearing name; require the refusal at that path and no other.

### Remaining Work

Retain the qualified `runtime-identity` factory for stale, copied and phase-named runtime identities in the
complete phase gate while implementation continues with Sprint 2.5. The current complete layout regression
passes all 1,386 independent oracle rows with a resolved graph and no layout findings; the runner regression
passes all 745 oracle checks.
Fifteen typed product inputs cover runtime text, copied paths with mixed-case and separator spellings,
executable/library/benchmark/foreign-library names, empty disabled components and conditional source roots.
The product parses Cabal component identities independently of module claims, so empty components remain
observable. A root such as `test/../src` cannot grant a validation-only exemption. Separate source and component
controls preserve phase-labelled validation contracts, and malformed package bytes must refuse.

`test/layout/RuntimeIdentityCases.hs` observes the shipped path, text and parsed-Cabal checks over fresh copies
of the complete protected source inventory. Its separate oracle owns exact paths, bytes, line/component loci,
original-tree discovery and cleanup. Six changed product builds must independently demonstrate sensitivity
to text ordinals, path ordinals, component ordinals, case folding, validation-component exemptions and
foreign-library component discovery. An initial focused run found two block-comment references and an actual
runtime diagnostic still carrying an ordinal. The product now excludes nested block and inline comments
while retaining quoted comment-looking text; the diagnostic names the content-addressed cache capability.
A paired comment/literal control checks this distinction. The fresh focused suite and independent oracle
pass all nine rows over thirty positive/negative observations, four separate controls and an exactly matched
1,043-path source inventory. The source-bound factory also passes its nine native rows. All six changed
product builds produce exactly their independently assigned refusals: stale text, copied paths, component
names, both text and path case folding, the validation-only component control, and foreign-library
component discovery. All forty-seven join checks pass, binding changed source and native images, preserving
the required context/evidence refusals and confirming removal of every copied source tree.

## Sprint 2.5: Ignore policy from the closed roots ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/Classify.hs`
**Blocked by**: Sprint 2.4
**Independent Validation**: Both ignore files derived from the closed roots `.build/**`, `.data/**`, and `.test_data/**` are the positive control; a retired generated-root pattern in either file and an ignored path beside authored source are paired negatives refused by name.
**Oracle**: `test/oracle/layout/IgnoreContextOracle.hs` states exact policy edits and refusals from literals; `test/oracle/layout/Main.hs` includes it in the complete suite.
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

Retain the qualified `ignore-context` factory for retired generated roots and undeclared state roots
in both ignore policies. Sixteen typed product edits cover all six retired roots in both files and
undeclared source-adjacent and scratch roots. The shared original snapshot and each file's actual bytes
are acquired separately by the suite and independent oracle. Seven further controls cover missing state
patterns, missing tool-spill patterns, hidden validation records and comment-only edits.

`test/layout/IgnoreContextCases.hs` edits policies in a fresh complete-source copy and records the exact
bytes of both files and the shipped classifier's findings. The independent oracle compares those bytes
against its own acquisition of the original files and requires two-way source discovery and cleanup.
Five changed classifier builds independently demonstrate sensitivity to retired roots, undeclared
roots, required roots, required patterns and validation-archive visibility. The focused suite and independent
oracle pass all seven rows over thirty-two positive/negative observations, seven additional controls and an
exactly matched 1,045-path source inventory. All forty-two independent qualification-join checks pass;
each changed product produces exactly its assigned red row with the other six rows green. The source
witnesses, changed binaries, refusal loci and teardown are checked independently, and no copied source
tree remains. These component results supply no phase evidence. The original policy files are unchanged.

## Sprint 2.6: The layout report, the bounded bootstrap, and the six-file admitted set ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/PbGrammar.hs`, `src/Amoebius/Layout/Report.hs`, `app/amoebius/Main.hs`, `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs`, and `amoebius.cabal`
**Blocked by**: Sprint 2.5
**Independent Validation**: `amoebius layout-report` classifies every tracked path exactly once and reports the admitted non-Haskell set as exactly six files by class; `pb/__main__.py` admits through the deny-by-default grammar; one forbidden node per family and a seventh non-Haskell file are refused; the compiled specification equals the fenced block above.
**Oracle**: `test/oracle/layout/Main.hs` and its source scanner `test/oracle/layout/SourceScan.hs` for the report and the grammar; `test/oracle/runner/Main.hs` for the specification digest.
**Legacy IDs**: `LTD-SRC-000`, `LTD-SRC-008`
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Make the classifier a product subcommand whose output the oracle judges, and close static source admission for
the bootstrap so that Phase 50 can observe its runtime handoff.

### Deliverables

- The six-file admitted set as a Haskell value: the package description and the project description, the two ignore files, the licence text, and one packaging-metadata file; Markdown excluded; `pb/__main__.py` as the separately admitted bounded bootstrap.
- `Amoebius.Layout.PbGrammar`: a closed syntax, import, resolved-direct-call, control-flow, and effect graph that rejects dynamic execution, reflection, import hooks, decorators, metaclasses, and any effect outside the injected `BootstrapAdapter`.
- `layout-report` as a subcommand of the shipped binary; the Phase-2 `GateSpec` with its `BinaryFact`.
- Deletion of the validator-side layout runner and its oracle.

### Validation

Run `preview phase 02` and require every row green; require `accept` to record exactly one
phase's patch.

### Remaining Work

Retain the qualified whole-snapshot `source-graph` binding and implement and independently qualify
`bootstrap-source`. The source-graph comparator and independent oracle cover path omission, mode change,
byte change, disguised foreign behavior and unattributed effects. All thirteen focused rows and fifty-two
independent source-bound qualification-join checks pass over an exact 1,047-path original and copied
inventory. Seven changed production builds produce exactly their assigned red rows; source witnesses,
changed binaries, refusal loci, binding audits and cleanup are checked independently. No copied source
tree remains. These are component observations, not a complete phase pass.

The shipped report exposes path, kind, complete permission mode and byte digest observations and accepts
an independently supplied snapshot reference. Its matching reference succeeds and its changed-mode twin
refuses at the exact path. Mode and kind negatives use supplied Haskell values; no host chmod behavior
is required. The complete graph uses the exact built source root and its native package inputs, while
the separate copy supplies file-change observations. A parse failure keeps the graph stage incomplete.
The first source-bound attempt exposed source-adjacent Cabal state and correctly refused
`SourceCopyInventoryChanged`; the package-catalog query now uses
`cabal path --jobs=1 --builddir=.build/dist-native`, and fresh qualification passes with the original custody
guards intact. Their operands remain recorded for diagnosis.

The whole-bootstrap implementation and independent oracle pass all nine focused checks for changed
bootstrap bytes, an extra bootstrap role and rewritten argv, over an exact 1,049-path source inventory.
Six positive/negative observations preserve actual copied bytes and complete inventory projections.
Missing and extra bootstrap files and duplicate and empty input inventories refuse exactly; cleanup is
verified. Five changed production builds produce exactly their assigned red rows, and all forty-three
independent qualification-join rows pass, including the explicit snapshot-scope check. Source, binary and
cleanup witnesses are verified, and no copied source tree remains. The captured-bootstrap scope regression passes all twenty-eight independent join checks;
its scope swap and attempted proof borrowing remain refused. Complete layout and runner regressions
pass all 1,424 and 745 independent checks respectively; documentation checking has zero findings. Fresh
numerical predecessor replay, phase preview and phase acceptance remain required. Its typed scope is separate from the Phase-0 captured
bootstrap; that earlier proof cannot qualify or retire the whole-snapshot binding. The protected source
inventory, actual copied bytes, independently authored graph expectations, exact source joins, changed
production subjects and cleanup remain required. Python is inspected statically and is not executed.
Only the complete numerical gate may close these bindings.

The shipped `layout-report`, its five named product stages, the layout suite, the separate
oracle, and the compiled gate specification are present, and the report's graph stage is derived from its rows:
it is `resolved` only when no import, standalone import, expression, declaration, route, or call site remains
open, and each of those six conditions has a paired fixture. `layout-report --no-graph` skips the graph and states
`graph-stage not-computed`; the suite uses it only for reports whose exit or classification it judges (option
handling, nested output, the shebang refusal, the default inventory, and the challenges that are not judged by the
graph), while the oracle's report and the gate's shipped-binary runs always compute the graph.

The declaration families are accounted by routes rather than left as open rows. Every derived instance, standalone
deriving declaration, and class instance is accounted against the provider of its class — declared locally, in a
source module, in an interface-checked external module, or in the Prelude interface — and every derivation to the
body it routes to: stock-generated; delegated to the representation type's instance (newtype or via) at a source
instance, at an external one (an `external-instance` row records that the instance is presumed to come from the
class's external provider, not that it was found), or through the context when the delegate is a type variable
(`context-instance`); or the default methods of a source or external class (anyclass). The strategy written by
no clause follows GHC's rules for the extensions the scanner reads. A class with no provider, or a delegate of an
own class with no source instance, is a named open row (`DerivedClassUnresolved`,
`StandaloneDerivingClassUnresolved`, `InstanceClassUnresolved`, `DerivedDelegateUnresolved`) that keeps the stage
`partial-calls`. The independent oracle recounts the derived-clause, standalone-deriving, and instance-declaration
counts of every file from raw source text through its own scanner, reads the wrapped type of every newtype
derivation from the newtype's own text, and requires both to equal the routed rows; it judges a planted route
fixture (stock, newtype-inferred, list, tuple, type-variable, via, anyclass, and standalone forms) and an
unresolved fixture by exact expected rows.

The graph also carries sinks and consumers. A sink is a use of a catalogued external effect primitive — process
execution, file read, write, open or query, environment, network, dynamic load, or unsafe effect — resolved
through the module's imports; a use that resolves through several modules exporting one entity (for example
`Prelude.readFile` and `System.IO.readFile`) is one sink, and a nested application is reported once. The catalogue
names, for each primitive, the argument positions that carry a path, an executable, or a command line. A consumer
is a literal fragment at one of those positions, read through path-preserving forms only (string literals,
parentheses, `</>`, `<.>`, `<>`, and `++` chains, and a few string conversions, including after a dollar or with an
infix function name), with a content role from its final component and a provenance origin (tracked, generated,
state, external, or unclassified) from its leading component, or `dynamic-root` when it follows a non-literal
operand; a position with no representable literal is a dynamic consumer, and a primitive that takes no path is a
sink with no consumer. The oracle holds its own catalogue with the same positions, recomputes the sink set of every
file from source text, recomputes every use's consumer rows from the raw text of the use's own span through its
own tokenizer, and judges a planted sink fixture (a shadowed name that must produce no sink, a variable path with
a content literal, nested process configuration, dollar and infix forms, a dynamic middle component, and control
characters in a literal) by exact expected rows. Template-Haskell splices and the one foreign import remain
dynamic-load and foreign-sink rows.

The graph is a potential-route model. Calls, class dispatch, derived-instance delegation, and effects are
candidate routes over the resolved imports and compiler interfaces. They are not runtime dispatch or higher-order
flow, they do not describe the internals of external packages, derived-instance delegation is not folded into
potential-effect reachability, and the value of a non-literal path expression is not recovered. Those limits stay
`UNVERIFIED` residue.

Before running this gate, check native GHCup/GHC versions and restore the dependency inputs, including one registered unit each of `logging-3.0.6`, `managed-1.0.11`, and `unagi-chan-0.4.1.4` in the
user-level store (for example `cabal install --lib` from Hackage). No toolchain byte pin, signature, fixed OS/CPU architecture, or physical substrate is required under DL-0025. The predecessor must have a current complete Phase-1 pass and an
exact-readable accepted bundle; if its historical evidence is missing, run the source-bound verifier's
`replay --through 1` to produce new receipts in numerical order. A diagnostic build or a digest alone cannot
replace that replay. The complete `preview` and then `accept` remain required; only `accept` changes Phase-2 and
sprint statuses ([DL-0018](../documents/decision_log.md#dl-0018--plan-claims-follow-the-keyless-gates-observed-scope)).

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
