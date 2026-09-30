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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_03_typed_spine.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/validation_frame_doctrine.md
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
Under §N step 3, every generation-1 receipt for this phase is incompatible with certification generation 2 and
supplies no authority. Phase 1 now has an accepted generation-2 receipt and a green replay; Phase 2 remains Active
because its compiler-backed whole-source graph remains unfinished.

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

**Current gap:** The compiled specification now names the whole-source graph and requires each named case to
have a green independent oracle row. The oracle now requires the `resolved` stage, zero unresolved import
and unscanned-source rows, and a compiler package identity for its planted external-import control. A
run-local report with only the stage changed to `resolved` still failed that check. The required resolved
call, effect, content-role, provenance, sink, and consumer edges remain unfinished. The runner now
stages three foreign paths in separate copied trees and requires the exact findings. A direct runner diagnostic
observed three product runs, nonce recovery in all three reports, and no binary challenge problems; it is
component evidence only. The selected external-unit join and component-scoped import
links remain diagnostics until the residual imports and semantic graph close. A gate
run cannot pass while these gaps remain.

| Key | Contract |
|---|---|
| `Claim` | `amoebius layout-report` classifies every tracked path exactly once against the closed rule: behavioural source is `.hs` outside `pb/**`, the admitted non-Haskell metadata set is exactly six files, the exact `validation-records/**` accepted bundles and void markers are non-source historical evidence, the bounded bootstrap admits through the deny-by-default grammar, and the source query for every Phase-2 identifier is zero. The Phase-2 gate also resolves the compiler-backed whole-source graph required by the frozen gate-integrity rule. Product behaviour and hardware remain later claims ([DL-0018](../documents/decision_log.md#dl-0018--plan-claims-follow-the-keyless-gates-observed-scope), [DL-0019](../documents/decision_log.md#dl-0019--red-replay-leaves-an-immutable-revocation-record)). |
| `Subject` | The layout stage modules, including `Amoebius.Layout.PackageMap` and the pending compiler graph, plus the `layout-report` subcommand in `app/amoebius/Main.hs`. Every subject must be inside the closure of `executable amoebius`. |
| `Command` | Future public spelling is `pb validate phase 02`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 02`; then `amoebius-validate accept --phase 02` records the receipt and applies one phase's status patch. The runner spawns the shipped `amoebius` binary as a child for `layout-report` over the tracked tree and over each planted copy. |
| `Oracle` | `test/oracle/layout/Main.hs` restates the classification rule, the six metadata-file classes, the exact accepted-bundle and void-marker archive classes, the grammar's refused node families, and the expected finding per planted negative from literals; it depends on no `amoebius` library. |
| `Positive controls` | The tracked tree classifies with zero findings; the bootstrap admits through the grammar; the metadata set matches the oracle's six classes, exact accepted bundles and void markers classify as non-source evidence, and the ordinal-identity query is zero. |
| `Paired negatives` | A seventh metadata file, an unexpected archive file, a tracked `.py` outside `pb/`, a tracked `.dhall`, a tracked Pulumi YAML, a tracked mutant body, a retired generated root re-admitted in an ignore file, an ordinal-bearing runtime identity, and one forbidden node per grammar family — each refused at its exact locus with the positive twin accepted. |
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
| `Residue` | The runtime handoff of the bootstrap remains Phase 50's claim; Phases 3 through 9 and every phase from 50 onward remain explicit limitations. Static Haskell consumer, effect, and call-graph semantics must close in this phase before acceptance. |
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

The path classifier now rejects non-Haskell entries beneath `test/**`, and the layout suite's
independent oracle checks paired script and table examples. The complete Phase-2 gate still must
qualify this arm against the source-bound product and generated mutant matrix; this component
diagnostic does not change sprint status.

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

The product classifier refuses tracked tool roots and admits the one package description
and probe exception. The suite checks these path classes. `Amoebius.Layout.PackageMap`
parses both Cabal descriptions and maps their declared modules against the present Haskell
inventory. A diagnostic layout run is green after removing an unused toolchain source;
planted unowned `src/` and vendor modules are refused. Two absent generated Proto bindings
appear as exact `package-owed` rows, independently checked as forward-owned by Phase 3.
Standalone test inputs and the maintained fork
set are bound by source role and the latter is cross-checked against toolchain provenance.
The complete compiler-backed call, effect, and consumer graph and Phase-2 gate still remain.
The shipped report parses every Haskell source with the pinned GHC parser, associates
declared modules with Cabal components and their direct library dependencies, checks parsed
module declarations against owned source paths, and emits component-scoped import links and
explicit unresolved rows. The earlier component diagnostic
(`.build/diagnostic-layout-suite-157b`) observed 780 parsed source files, 5,191 import
rows, 1,811 component-scoped links, 2,932 imports joined to a selected external
package unit, 75 imports bound to a unique available unit and its digest-checked
compiler interface in deliberately disabled seed components, 11 imports bound to
the two forward-owned Phase-3 generated Proto bindings through Cabal
`autogen-modules`, two exact deferred seed-module ownership rows, and zero unresolved
imports. The available-unit rows retain a
separate selection status: those components have no selected build plan. The
independent oracle checks each row against the declared dependency, candidate,
interface, and disjoint import partition. `Infernix.Topic.Metadata` and
`JitML.Codegen.RuntimeOperationsCuda` remain absent seed-package modules owned by
later rederivation; an exact module/component/package relation and a declared
dependency chain account for them without claiming present implementation. Paired
wrong-owner and missing-dependency fixtures keep other imports unresolved. No tracked
internal import lacks a
declared component dependency: direct
dependencies were added to the shipped executable and twelve test stanzas, and four
local oracle modules were declared in `dsl-spec`. All twelve affected test components
build serially. A planted missing dependency now produces the exact
`InternalImportDependencyMissing` finding; its paired oracle check is green. The
package mapper also emits 1,205 distinct component/package dependency declarations
from the Cabal descriptions. The product joins the executable-anchored Cabal plan's
selected direct units to GHC's registered exposed modules, and reports both input
digests. Paired Haskell controls reject a plan/declaration mismatch and a missing
selected unit, while a positive control resolves one external import. The
138 files without a Cabal component each have a product-reported standalone role
checked against the independent oracle's role rule. These observations do not
establish a resolved whole-source graph or Haskell effects. The diagnostic projects
105,777 located call sites, 54,761 with one internal candidate after local-binding
precedence, 119,671 located value-reference sites, 27,771 control edges, and 6,529
top-level type signatures. The report identifies 1,489 signatures whose parsed
result head is `IO` as potential-effect candidates. Unique internal-call candidates
reach 1,518 functions from those seeds; the independent oracle recomputes the complete
reachability set from the reported edges and a planted two-step route, with a shadowed
call excluded. The report also attributes 16,664 call-site candidates to selected
external package units and 225 to interface-checked available units in disabled seed
components. An open unqualified import requires an exported name in the exact compiler
interface; paired exported/absent fixtures check both selection classes, and the oracle
binds each available-unit candidate to a reported call site, import, and interface.
The report reads the pinned base unit's exact `Prelude.hi`, checks its unit and module
identity, and records its content digest and 259 exported names. For 686 eligible
selected component/module pairs it records the implicit Prelude import, and attributes
36,011 call-site candidates to that compiler interface. Fourteen disabled seed-module
uses of the same available base unit add 612 separately labelled Prelude call-site
candidates. Paired `NoImplicitPrelude` fixtures check suppression under both selection
classes; the independent oracle checks the interface identity, candidate anchors,
and both fixture outcomes. It also reads and digests 175 external
module interfaces, following registered package reexports to their physical units.
Those interfaces expose 7,306 parent/member relations; 202 member call-site
candidates require the exact imported parent and exported member. Paired matching
and wrong-parent fixtures and the independent oracle check that join.
External candidates now require a compiler-exported symbol for open, qualified, and
explicit-name imports; a paired fixture checks exported and absent names in open and
qualified calls. A value-only `hiding` import is checked against the interface and
the named exclusions; a paired fixture keeps an exported but hidden name out of the
candidate set. GHC's wired-in `(:)` name accounts for 331 call sites even under
`NoImplicitPrelude`; the independent oracle checks its module and unit identity and
the paired fixture. GHC's wired `(,)` constructor accounts for five further calls,
with a paired fixture and independent identity check. The scanner also carries lexical binder spans through `let`,
`where`, patterns, and statement scopes. It records 5,789 local binder declarations,
21,739 parameter-pattern binder rows, and 7,758 located lexical-binding call
candidates; shadowing and parameter fixtures and the independent oracle match each
candidate to a declaration by file, owner, name, and site.
For a single unguarded variable right-hand side, it records 141 aliases and 966
call-through-alias routes. Of those routes, 710 call sites reach an unshadowed
same-module value, 239 reach imported Haskell source declarations, and 10 reach a
selected external module export; the independent effect-route closure includes the
same-module and uniquely resolved imported edges. Paired fixtures check an imported
value and an imported `IO` seed reached through an alias across a component
dependency; the independent oracle binds each imported alias row to a reported
lexical route, component import link, and provider declaration. The external alias
fixture checks an exported and absent name.
A paired parameter-alias fixture keeps a parameter from becoming a same-module call;
a tuple-pattern fixture prevents projection binders from being treated as aliases of
the whole right-hand side. A qualified-alias fixture records its imported target
without promoting it to a same-module call.
Other local binding values and potential effects remain open. Six calls into the absent
Infernix seed module now have candidate rows only when their names appear in an explicit
import list and the exact module/component/package is assigned to later rederivation.
A paired named/missing fixture and the independent oracle check those bounds; source
binding remains deferred. In standalone Haskell sources, 206 call sites now have
same-file declaration candidates and 57 have local or parameter binder candidates.
The paired shadowing fixture and independent oracle check both joins. For 137
standalone files with implicit Prelude, a unique available pinned `base` interface
supplies 628 further call candidates; the paired `NoImplicitPrelude` fixture and
independent oracle check that boundary. A further 763 standalone calls have one
parsed source provider whose exported declaration is permitted by the import list;
a paired hidden-name fixture and the oracle check source, import, and provider
anchors. Another 401 standalone calls join a unique available package unit and
a digest-checked compiler module interface. The 139 standalone available-unit import
rows account for the extra interfaces; the oracle checks the exact interface/import
partition. A paired exported/absent fixture and the oracle check the call boundary.
Parent/member matching has a paired fixture, with no current whole-tree candidate.
Six standalone `(:)` calls now join GHC's wired constructor identity, with a paired
`NoImplicitPrelude` fixture and independent oracle check. An earlier report left 59
standalone call sites opaque: 19 in maintained-fork source, 39 in compile-negative
inputs, and one in a compile-fail fixture. They require explicit provider or
independently observed rejection semantics. The oracle recomputes this
complete complement from reported call sites and candidate edges; qualification now
requires it to be empty.
These are possible routes only; external symbol exports, higher-order dispatch, external
effects, and full effect interpretation remain unresolved.
The 5,636 derived-instance rows now each carry a parser-derived class head; the
independent oracle checks one-to-one coverage and the applied `MonadReader PulsarCtx`
case. Generated method dispatch remains open.
The parsed class heads now join 17,689 exact compiler interface-member candidates
through explicit or implicit imports, covering 5,635 of 5,636 derived instances.
A paired `NoImplicitPrelude`/explicit-`Eq(..)` fixture and the oracle check those
routes. The remaining `MonadManaged` deriving instance is in the maintained fork;
interface membership alone does not establish the generated method bodies or effects.
The current complete-suite diagnostic (`.build/diagnostic-layout-suite-168`) observes
780 parsed files, 5,210 imports, 109,271 call sites, 489 declaration-family gaps,
19 opaque standalone calls, 37 compiler-rejected call sites, three parser-backed
closed-export refusals, and zero unresolved imports. The suite completed, and the
direct shipped report (`.build/diagnostic-layout-shipped-167.tsv`) matches its
report byte for byte. Its independent oracle
(`.build/diagnostic-layout-oracle-168.tsv`) is green for the exact three-site refusal
partition and red only for `case:graph-qualified`. These are component diagnostics,
not a qualified phase gate.
The report records the four located `type family` declarations as type-level-only
source nodes and the sole foreign import as a potential external-effect sink.
The oracle checks the source declarations, locations, exact rows, and absence of
the two former declaration gaps.
It also projects
parser-derived class heads for all 13 standalone deriving declarations and 34
digest-checked compiler interface-member candidates, with at least one candidate for
each head. Paired implicit Prelude, `NoImplicitPrelude`, and explicit `Eq(..)` fixtures
and the independent oracle check the head, interface member, import provenance, and
complete head coverage. This is a possible member route, not generated method dispatch.
The shipped `layout-report` output exactly matches the suite report for the current
source snapshot; the independent oracle has only `case:graph-qualified` red.
Five maintained-fork imports of `Control.Monad.Managed` now have a separately labelled
registered-only unit and a digest-checked compiler interface. Its five exported call
sites are diagnostic candidates; they remain among the 22 opaque calls because the
`managed` unit is absent from the executable Cabal plan. A paired registered-only
fixture checks exported and missing names and requires the exported site to remain
opaque. The independent oracle checks each candidate against its call site, import,
interface, and opaque row. No ambient registered unit is promoted to a selected
dependency by this observation.
The report also locates 28 standalone calls at a declared source symbol
denied by the provider's export list; a paired exported/hidden source fixture and
the oracle check provider, import, call site, and rejection provenance. The oracle
compiles the legal and illegal `Grant` twins serially with GHC 9.12.4. The legal
source succeeds, and the illegal source returns one structured code-1928 error
at line 31, column 3 naming `Grant` and its defining source. This is one exact
compiler rejection observation. The product now serially compiles each of the 11
source files with a denied constructor, verifies the pinned compiler's structured
code-1928 diagnostic and unchanged source bytes, and emits a rejection only for
call sites within that rejected expression. The independent oracle recompiles all
11 files, checks exact source, diagnostic position, constructor, defining provider,
source digest, and the complete 28-site constructor partition. Another seven
compile-negative files have exact structured GHC scope/export rejections: five
code-88464 errors at missing variables or constructors and two code-76037 errors
at qualified names the provider does not export. The product binds those results
to nine more call sites within the rejected expressions; the independent oracle
recompiles all seven, checks their positions, names, source digests, and exact
nine-site partition. Three more calls in two Pulsar negatives now have a distinct
closed-export refusal: `Topology` exports `Topic` abstractly, and `Producer` omits
`produceRaw` from its explicit export list. The source graph requires an explicit
consumer import-list entry and a closed, locally bounded provider export list;
the oracle checks the three exact sites, source headers, import clauses, and the
underlying `Topic` constructor. This is source-export evidence, not a compiler
rejection: direct compilation of these files still stops at Phase-3-owned Proto
bindings. The remaining 19 opaque calls are in the maintained Pulsar fork.
A serial GHC diagnostic survey (`.build/diagnostic-phase2-denial-survey`) now reaches
the denied constructor in all 11 files that supply those 28 source-denial rows. Each
file reports code 1928 at its constructor use once the selected project package
environment and required source directories are supplied. Bare GHC stopped earlier
on package visibility in five files, so the survey records the exact invocation
boundary. The two mutant-named source inputs were compiled only against
the current production source, not against a changed production subject.
To close the graph, account for all 487 declaration-family rows through compiler-derived
dispatch or an explicit potential-call route, and resolve the remaining 19 opaque
call sites, including standalone sources, with independently checked
binding and effect propagation. The 7,846 lexical-binding candidates also require
value and effect propagation before graph qualification. Content roles, provenance,
dynamic loads, sinks, and
consumers still need complete graph edges and paired negatives before the full gate.
Imported candidates account for parsed qualifiers, export and import lists,
constructor and selector membership, `module` reexports, and explicit imported
`Type(..)` reexports to a defining source. Planted cases check
those relations and lexical shadows in `let`, parameters, case, `do`, and guards.
Five class-method declarations are projected as callable names; a paired
`Class(method)`/`Class` import fixture checks method visibility. Instance dispatch
remains a separate declaration gap.
The parser now applies each file's language pragmas before parsing. Its 459
`GetField` sites and one projection site have explicit AST observations; 1,095
potential selector-provider rows join them to parsed record declarations, with
paired field, projection, and missing-field controls. No expression form is left
unscanned in the current inventory.
Plain data declarations without deriving now project their constructors and selectors
without a generic declaration gap; a planted no-deriving example and the oracle's
derived-type/gap equality check are green. The graph still has 487 unscanned
declaration-family rows: 416 generated data deriving dispatch, 66 class instances,
and five standalone deriving declarations. The parser now
projects 323 class-instance heads and 300 explicit instance methods, with a paired
fixture and independent oracle joining methods to their instance heads. An earlier
direct report (`.build/diagnostic-layout-shipped-171.tsv`) adds 297 selected-unit
external class contracts for 294 distinct methods. With five source-class contracts,
all 299 explicit methods in that report had a contract. The current report adds
the fixture's source-class contract, covering all 300 explicit methods. The later-phase `LiveDslDeployGate`
test imported `FromJSON` abstractly while defining `parseJSON`; the pinned GHC
rejected that import with code 54721, and the corrected method import compiles.
Its independent oracle (`.build/diagnostic-layout-oracle-171.tsv`) checks both
compiler twins, the empty uncontracted complement, import, package unit, and
interface membership; only `case:graph-qualified` is red. The direct report has
109,545 call sites, 489 declaration-family gaps, and 19 opaque calls. These
contracts are potential routes and do not close instance dispatch.
Four parsed class declarations have five named methods, five projected signatures,
one superclass constraint, and no default bodies in the current tree. The parser
keeps `ClassDispatch` for a class with a default body, associated declaration,
functional dependency, or unmodeled signature; a paired default/signature-only
fixture and the independent oracle check this boundary. Six explicit instance methods now join a parsed
source class through a local declaration or a permitted import, with a hidden-method
negative and independent oracle. Ten calls to uniquely resolved source class methods
now have potential instance-dispatch candidates; the oracle independently joins each
call to an instance contract. The last complete-suite report
(`.build/diagnostic-layout-suite-176/layout.tsv`) binds six of those calls to instance
method bodies in the caller's declared component dependency closure. The
`ClassEffectRoute` fixture is Cabal-owned and compiles; its instance applies an
`IO`-typed function while its caller has a pure signature. The independent oracle
(`.build/diagnostic-layout-oracle-176.tsv`) checks all six body edges, excludes
four library-to-test instance candidates, and recomputes the 1,526 potential
`IO` routes through the instance and caller. The fixture adds one class and one
instance declaration, leaving 487 declaration-family gaps and 19 opaque calls
in that report. A direct shipped-binary run over the same path inventory
(`.build/diagnostic-layout-shipped-176.tsv`) is byte-identical to the suite report.
The newer direct shipped report (`.build/diagnostic-layout-shipped-178.tsv`) adds
`DirectIoRoute.runDirectIo :: a -> IO Int` as a class-method effect seed and carries
that potential effect through `directCaller :: DirectIoRoute a => a -> Int`.
The non-`IO` `RouteAction.runRoute` is a paired negative. The independent direct
oracle (`.build/diagnostic-layout-oracle-178.tsv`) checks the exact one-row class
effect set and all 1,528 potential effect routes; its sole red row is the unchanged
`case:graph-qualified` with 487 declaration gaps and 19 opaque calls. The new class
has signatures but no default body and adds no declaration gap. A fresh full-suite
run for this source snapshot remains pending.
Type-specific dispatch is still open. Indirect calls,
dispatch, broader monadic flow, effects, sinks, provenance, and consumers remain
unresolved. The bounded bootstrap parser emits 37 parsed direct-call sites and 16
effect sites with their enclosing methods; the independent oracle checks that exact
projection. The oracle still refuses the `partial-calls` stage.

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

The classifier refuses Pulumi paths and reports Dhall, Proto, and UI paths as owed. The
suite joins those classes to typed legacy owners, with literals in the separate oracle.
The runner still needs shipped-binary foreign-path challenges at each exact locus. The
owners close their rows in their own gates.

## Sprint 2.4: Every authored name loses its phase ordinal ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/Classify.hs`, the separate Phase-2 suite, and `src/plan-decisions/Amoebius/Plan/PhaseIdentity.hs`
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

- The ordinal arm of the product classifier, with the separate Phase-2 suite checking
  capability names against `Amoebius.Plan.PhaseIdentity`; the product has no validator dependency.
- Phase-labelled validation contracts left phase-labelled and forbidden as runtime identities.

### Validation

Run the ordinal query; plant an ordinal-bearing name; require the refusal at that path and no other.

### Remaining Work

Product source paths and non-comment runtime text now refuse ordinal-bearing identities;
the source names and runtime values found by the query have capability names. A run-local
ordinal diagnostic is checked at its exact line by the separate oracle. The complete gate
must qualify this changed source snapshot before the sprint can close.

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

Both ignore files now have closed pattern sets in the product classifier, and the suite
checks retired-root and source-adjacent ignore negatives. The complete Phase-2 gate must
qualify this changed source snapshot before the sprint can close.

## Sprint 2.6: The layout report, the bounded bootstrap, and the six-file admitted set ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Layout/PbGrammar.hs`, `src/Amoebius/Layout/Report.hs`, `app/amoebius/Main.hs`, `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs`, and `amoebius.cabal`
**Blocked by**: Sprint 2.5
**Independent Validation**: `amoebius layout-report` classifies every tracked path exactly once and reports the admitted non-Haskell set as exactly six files by class; `pb/__main__.py` admits through the deny-by-default grammar; one forbidden node per family and a seventh non-Haskell file are refused; the compiled specification equals the fenced block above.
**Oracle**: `test/oracle/layout/Main.hs` for the report and the grammar; `test/oracle/runner/Main.hs` for the specification digest.
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

The shipped `layout-report`, its five named product stages, the layout suite, the separate
oracle, and the compiled gate specification are present. The product report classifies the
present inventory, maps both Cabal descriptions against present Haskell sources, and uses
GHC's parser to emit source, import, call, value-reference, and control-edge rows. The
earlier diagnostic (`.build/diagnostic-layout-suite-157b`) observed 780 parsed Haskell files,
5,191 import rows, 1,811 component-scoped links, 2,934 selected external-unit imports,
75 available-unit imports in non-buildable seed components, 11 exact forward-owned
generated Proto imports, two exact deferred seed-module ownership rows, zero unresolved
imports, zero inaccessible internal imports,
and no layout findings. Each available-unit row is bound to a unique declared package
unit and digest-checked compiler module interface without claiming that the disabled
component was selected. The two deferred imports name absent seed-specific modules,
with exact later rederivation owners and independently checked component/package
dependency chains. The
product binds the generated Proto
imports to the Cabal `autogen-modules` declarations and the independent oracle checks
the exact forward-owned rows and the remaining unresolved ownership.
A new product finding rejects
an internal import without a declared direct dependency, and the independent oracle
checks a planted counterexample. The report also projects 1,205 distinct Cabal
component/package dependencies and binds the selected-unit join to digests of the
Cabal plan and GHC package database. Paired controls reject a mismatched plan and
missing unit metadata. Its 54,761 unique internal call candidates remain a subset of
105,777 syntax call sites; indirect targets remain unresolved. The 16,664 selected-unit
and 225 available-unit external call-site candidates retain the package unit and
require the imported symbol to appear in its compiler interface; open, qualified,
and explicit-name imports are checked against their parsed import lists. An exact
site partition exposes 59 opaque standalone calls (19 maintained-fork, 39
compile-negative, one compile-fail fixture); the independent oracle recomputes
the complement and the complete gate
requires zero. The report reads and digests the pinned base unit's `Prelude.hi`,
verifies 259 exported names, records 686 selected and 14 available-unit implicit
Prelude imports, and attributes 36,011 selected and 612 available-unit call-site
candidates to those exports. Paired `NoImplicitPrelude` fixtures cover both routes.
The scanner now distinguishes dotted
operators from qualified module names; the paired `(.)` fixture and independent
oracle check that relation. It also checks and digests 175
selected or uniquely available external module interfaces, following registered reexports to their
physical units. Open, qualified, and explicit-name imports now yield a candidate
only for a compiler-exported symbol; the paired positive/absent fixture and independent
oracle check that edge. The 7,306 compiler interface member rows bind 202
`Type(..)` member-call candidates to an exported parent; paired matching and
wrong-parent fixtures check the relation. A value-only `hiding` list has a paired exported-but-hidden
control. The compiler's wired-in `(:)` name accounts for 331 call sites, and its
wired `(,)` constructor accounts for five; each has a paired fixture. The scanner records 5,789 local binder rows,
21,739 parameter-pattern binder rows, and 7,758 lexical-binding call candidates
with pattern or local declaration sites, paired with shadowing and parameter
fixtures and an independent binder join;
141 simple aliases yield 966 call-through-alias routes, 710 of them to same-module
values, 239 to imported Haskell declarations, and 10 to compiler-exported external
values. The independent effect closure includes the same-module and uniquely
resolved imported routes; paired imported-call and cross-component `IO` fixtures
and the oracle check those edges. A paired exported/absent external alias fixture
checks the external routes. The paired parameter alias remains lexical;
tuple-pattern and qualified-alias negatives filter
false same-module routes.
For standalone Haskell inputs, 206 same-file call candidates join parsed top-level
values, constructors, selectors, class methods, or foreign symbols; 57 lexical
call candidates join a local or parameter binder. A paired shadowing fixture and
the independent oracle check those joins without assigning a Cabal component.
Another 137 standalone files have an implicit Prelude route to the unique available
pin-checked `base` unit, accounting for 628 call-site candidates. A paired
`NoImplicitPrelude` fixture suppresses that route; the oracle joins each candidate
to its source call and exact Prelude unit.
Another 763 standalone call sites have one matching parsed source module and an
import-list-permitted exported declaration. The paired hidden-name fixture checks
the exclusion, and the oracle binds each candidate to the reported source call,
import, unique provider module, and declaration.
For standalone imports whose module has no parsed source provider, 401 call sites
join one available package unit and a loaded compiler export interface. The report
projects 139 standalone available-unit imports, and the oracle requires the exact
interface row set to match component and standalone imports.
Paired exported/absent and matching/wrong-parent fixtures check the value and
member paths; the current whole-tree report has no member candidate. The oracle
checks source call, import, and interface anchors.
Six standalone `(:)` calls join GHC's wired `GHC.Types` constructor in `ghc-prim`;
the paired `NoImplicitPrelude` fixture and oracle check its identity.
Broader value and effect flow remains open. The graph records six
`module` reexports and traces internal
values through module, explicit-name, and explicit imported `Type(..)` reexports to
their defining source. Paired fixtures check unqualified aliases, qualified aliases,
selected hidden values, and
same-named hidden data constructors. Direct GHC compile-negative checks confirmed the
qualified-alias and constructor-hiding semantics. The 138 files without a Cabal component
have exact standalone roles checked by the independent oracle. The scanner applies
file-local language pragmas and records 459 record-field sites, one projection site,
and 1,095 potential selector-provider joins, all checked by a paired fixture and
oracle. There are no unscanned expression rows and 487 unscanned declaration-family
rows: 416 generated data deriving dispatch, 66 class instances, and five standalone
deriving declarations. Plain data declarations
without deriving now project constructors and selectors without a generic gap;
323 class-instance heads and 300 explicit instance methods are independently checked
against each other and the instance-gap file set; dispatch remains open.
Four class declarations expose five callable method names with exact signatures,
one superclass constraint, and no default bodies in the current tree. A paired fixture
retains the class gap for a default body while suppressing it for a signature-only class;
the independent oracle checks the exact current class contracts;
six explicit instance methods join source class declarations through a local binding
or a permitted import, with a hidden-method negative and independent oracle.
Ten uniquely resolved class-method calls have potential dispatch candidates to
those instances; the oracle recomputes the complete join. The candidate set includes
instances in compile-negative inputs and does not claim a runtime type choice.
Each of 5,636 derived-instance rows also has a parser-derived class head, with
one-to-one oracle coverage and an applied-class control. Generated methods and
effects remain unproved. The report joins 17,689 derived-class member candidates
to digest-checked compiler interfaces through explicit or implicit imports;
the oracle checks every member and import route. Those rows cover 5,635 of 5,636
derived instances; the unmatched `MonadManaged` instance is in the maintained fork.
Paired implicit, suppressed, and explicit Prelude fixtures are green. Located `if`, `case`, `do`,
and guarded-body edges contribute to 29,242 control rows; independent fixtures check
them. One foreign symbol and one dynamic load belong solely to compile-negative
fixtures. In the last complete suite, 6,576 top-level type signatures include 1,495
parsed `IO` result-head effect candidates with planted and shipped-source literal
oracle controls. Its 1,526 potential routes close uniquely resolved internal call edges
and component-reachable
instance method-body edges back from those seeds;
the oracle independently recomputes that closure. Full effect interpretation,
indirect calls, external effects, exceptions, and broader monadic flow remain
unresolved. The suite plants
nonce-named Python, Dhall, Pulumi, ordinal-bearing, unowned Haskell, unowned vendor, and
syntactically invalid Haskell sources in fresh run-local copies; the independent oracle
checks each exact refusal. A separate owned-module challenge checks a declaration/path
mismatch. The latest full-suite oracle (`.build/diagnostic-layout-oracle-176.tsv`)
has one red check, deliberately
`case:graph-qualified`: the shipped report states `partial-calls` and retains 487
unscanned declaration-family rows and 19 opaque call
sites. An earlier diagnostic copy with
only the stage label changed to `resolved` remained red. Therefore this phase cannot
be accepted yet.

The generic runner's shipped-binary challenge now covers fresh Python, Dhall, and Pulumi paths in
separate copied trees, with exact nonce-bearing findings required. The bootstrap admission parses a bounded
expression tree for the pinned source and checks nested calls and class-scoped effect routes
before the exact source digest. The report emits 37 direct-call sites and 16 adapter-owned
effect sites that the separate oracle checks against literal expectations. Its complete call/effect provenance
proof and independent gate qualification remain owed. The classifier checks archive
filename shape; verifier custody owns bundle-content admission. Phases 0 and 1 were
replayed successfully at the then-current digests; the later gate-specification change
requires predecessor reproduction again before a full Phase-2 gate. An earlier
Phase-2 preview was green with twenty-two of twenty-four viable mutants killed, but that
candidate preceded the package and graph changes and did not establish the full contract.
The graph must resolve calls, control flow, potential effects, content roles, provenance,
dynamic loads, sinks, and consumers over the whole Haskell inventory, and the complete gate
must independently challenge those relations. The exact two absent generated Proto bindings
in `pulsar-client` remain forward-owned by Phase 3. After these gaps close, a fresh full
preview and separate accept must run before any status changes.

Before running this gate, supply the seven bootstrap files beneath `.build/bootstrap-inputs/`, verify their
fixed sizes and SHA-256 digests and both pinned manifest archive entries, and restore the offline dependency
inputs. No publisher keyring or GPG verification is required. The predecessor must have a current complete
Phase-1 pass and an exact-readable accepted bundle; if its historical evidence is missing, run the source-bound
verifier's `replay --through 1` to produce new receipts in numerical order. A diagnostic build or a digest
alone cannot replace that replay. The complete `preview` and then `accept` remain required; only `accept`
changes Phase-2 and sprint statuses
([DL-0018](../documents/decision_log.md#dl-0018--plan-claims-follow-the-keyless-gates-observed-scope)).

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
