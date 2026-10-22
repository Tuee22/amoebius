# Phase 6: Extension admission and attested scope

> **Purpose**: Make an extension one linked `ExtensionSpec` record, admit its Haskell surface by AST node rather than by substring, and make attestation the only way a scope is introduced.
> **Read this if**: the extension claim of the plan must be judged, or a later phase needs to know which capabilities the shipped binary links and how a scope is entered.

This phase owns the extension seam of the spine: the `extension-spec` library, `LinkedExtensions`, the
GHC-parser AST checker, attested-only scope with one `reenter`, and the calculi linked into the executable.
It does not own child clusters or the UI language, which the later slice phases own in order. Its
predecessor is [Phase 5](phase_05_substrates_lanes_image_recipe.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_05_substrates_lanes_image_recipe.md, DEVELOPMENT_PLAN/phase_07_child_clusters_obligation_teardown.md, DEVELOPMENT_PLAN/system_components.md, documents/decision_log.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/extension_conformance_security.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_tenancy.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 6.1: The extension-spec library and LinkedExtensions](#sprint-61-the-extension-spec-library-and-linkedextensions-)
- [Sprint 6.2: The gate-side GHC-parser AST checker](#sprint-62-the-gate-side-ghc-parser-ast-checker-)
- [Sprint 6.3: Attested-only scope and reenter](#sprint-63-attested-only-scope-and-reenter-)
- [Sprint 6.4: Calculi linked into the executable](#sprint-64-calculi-linked-into-the-executable-)
- [Sprint 6.5: The Phase 6 gate specification](#sprint-65-the-phase-6-gate-specification-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

An earlier verifier accepted [Phase 5](phase_05_substrates_lanes_image_recipe.md) and activated this phase.
The missing inherited legacy analyzer/evidence join subsequently caused receipt revocation and a
verifier-owned reset to the documentation gate. The implementation below remains component preparation;
its earlier predecessor observations cannot establish current qualification.
The earlier documentation reconciliation and replay results remain historical. DL-0031 through DL-0033
restore specification obligations wherever the doctrines cited withdrawn gates, without weakening their
scope. Current progression requires repair and qualification of the earliest open phase, then separate
complete gates and mechanical acceptance for each numerical predecessor through Phase 5. Hardware-free implementation may be prepared in an
isolated snapshot after its typed contract and independent oracle exist, preserving any active gate's source. Implementation and evidence follow the
[numerical order and sprint seams](development_plan_phase_model.md#o-sprint-sized-seams-and-bounded-phase-gates).
The preparation recorded below minted no Phase-6 gate evidence. Its source delta was promoted to the shared
worktree with verifier-owned status, receipt and archive bytes preserved. These observations are component
diagnostics; the current status is recorded separately above. Component observations do not
replace current-source predecessor qualification or this phase’s complete gate.

Isolated preparation has passed 43 located AST cases with 24 paired controls, four role/coercion
before-and-after checks with a legal control, and seven independent native compiler-transport rows.
The transport checks contributed source before GHC processes options, plugins or Template Haskell;
changed and newly added unsafe sources are refused, and a trusted effect control executes. These are
component diagnostics. The isolated codec run also passed 32 independent rows, and the actual linked
registry passed five rows covering its four specifications and their complete source seals. A native
incremental control exposed stale seals for newly added sources; added, edited and removed helper
controls pass after the cache correction. The temporary helper was removed.

The isolated integrated library, executable and extension suite build natively. An independent component
run passed 114 AST, lowering, codec and registry rows. The shipped executable compiled and fake-applied
the linked CPU example, admitted its emitted source tree, accepted the supplied CUDA sibling and refused
the CPU-only CUDA twin at `lower`. The core component oracle passed 882 rows. A mixed CPU/CUDA input
exposed first-need-only extension instantiation; its correction passed 13 independent per-need scope,
runtime and dependency-consumption checks, and its 33-step fake input byte-equals the compiled manifest.
The bounded conformance model also passed 24 independent rows over the actual four declarations and the
two-member submodel, including exact generated files, declaration/suite/verdict bindings, law faults and
omission controls. Four native conformance scope-index pairs passed. Compiler correctness, universal C1
and observer authentication remain explicit premises or unverified claims. A native component run rebuilt
the actual catalog as empty and observed the exact application-and-need refusal against identical input.
Its six independent source, binary, input and refusal checks passed; seventeen independent runtime,
scope, workflow and fake-process checks also passed over the primary shipped binary’s challenged output.
A fresh integrated component run then passed all 1,233 independent rows, including the four-case
CPU/CUDA and amd64/arm64 runtime grid, mixed runtimes, fourteen scope-index pairs, ten private-API pairs,
source-tree and graph controls, re-entry and Unicode scope framing. The runner regression passed all
145 independent rows. Final monitoring, nonempty-declaration and factory/seal pairs, corpus discovery and
extension-chain stage checks passed 150 focused independent rows, including fourteen private-API pairs.
These component results authorize no status transition; numerical predecessor replay and the qualified
phase gate are the validation boundary.

The fresh numerical replay reproduced Phases 0 and 1, then stopped at a red Phase-2 gate. Its full
mutation matrix of forty attempts qualified, but the clean positive and negative controls exposed missing
direct Cabal dependencies, unscanned trusted quotations, unattributed external constructor re-exports,
and independent expectations that still used the previous source layout. The verifier voided the prior
Phase-2 receipt. Repairs now traverse expression and name quotations, preserve the refusal for unsupported
quotation forms, and attribute constructor re-exports only through checked source export/import boundaries
and selected compiler-interface members. The fresh layout component passed all 1,302 independent rows,
including the complete thirty-nine-call compiler-refusal set, eleven quotation observations and the paired
constructor-facade controls. Its source graph has no findings, unscanned forms or unattributed calls. The
shared spine component also passed all 882 independent rows on the same Haskell source. These component
observations supply no Phase-6 gate evidence; numerical replay and this phase's complete gate remain the
required validation boundary.

The follow-up replay refreshed Phases 0–4, then stopped at a red Phase-5 mutation qualification. All 921
clean oracle rows passed and the aggregate ratio was 25 kills from 33 viable mutants, but the required
`Topology.Lanes` stage had no generated locus: its projection uses string constants beyond the generic
constant-flip operator's previous integer and Boolean cases. The verifier correctly refused the missing
per-stage kill and voided the prior Phase-5 receipt. The generic operator now also handles lexed string
constants, retaining integer and Boolean priority, skipping character literals and stopping its string
fallback at comments or malformed tokens. Its independent runner controls exposed seven failures before
the repair and passed all 160 rows afterward, including actual shipped lane-source discovery and application.
The kernel remains within its accepted 3,357-line cap. A generated lane mutant rebuilt the shipped executable
and was refused at the independent oracle's lane rows while unrelated host-classification control remained
green. Identical input through clean and changed shipped executables also exposed the lane-byte difference
in decoding, lowering, recipes and manifests. These are component diagnostics; current-source numerical
replay through Phase 5 and this phase's complete gate remain the completion criteria.

A subsequent standards audit stopped that replay during Phase 4's twenty-fourth mutant. The current
runner's `Legacy closure` row checked repository hygiene and printed due identifiers, but did not join
typed analyzer observations, lifecycle transitions and independently qualified reintroduction evidence.
Those missing boundaries prevent qualification even where the earlier verifier recorded green rows;
the historical records remain intact. A native regression through the real gate entry point reproduced
four failures: absent legacy evidence still captured a green legacy row and created a run directory,
including with optional hygiene preflight disabled. An explicit unavailable-analyzer guard now refuses
the current and earlier owners before subject execution, and rejects an unknown phase ordinal. The native
rebuild and all 167 independent runner controls pass, including exact unavailable-ID refusals, the disabled
preflight twin and the absence of a created run directory. The kernel remains within its 3,357-line cap.
The complete authenticated analyzer path remains required: this guard is not a completed legacy analyzer
or a phase pass. The final implementation must restore full numerical qualification before this phase
can close.

At registration, the inventory foundation declared all forty-four typed obligations, opaque analyzer and case keys,
Active-only lifecycle values and nonempty case identities. A distinct captured-bootstrap requirement
cannot retire the full snapshot obligation. All 220 independent runner controls pass, including seven
native legal/illegal pairs over the actual public source API. These are declaration and privacy checks,
not owner-analyzer execution. The earliest numerical replay then refused its eight unavailable analyzers;
the verifier mechanically revoked the selected predecessor receipts while preserving their immutable
bundles and recorded status lines. The authenticated observation, reintroduction and lifecycle path must
be completed from that earliest boundary before numerical progression can resume.

The custody repair passed all 305 independent runner controls after fifteen controls reproduced the
previous reset defect. The verifier published a durable nongate reset event, reopened the earliest
affected phase and blocked its successors. Its eight-file status patch preserved all other document
content. The full owner-analyzer and source-bound evidence path remains unfinished.

## Phase Summary

Phase 6 makes infernix one `ExtensionSpec` record linked into the shipped binary
([DL-0002](../documents/decision_log.md#dl-0002--one-extensionspec-record-is-the-extension-seam)). An app
needing a capability that no linked extension provides is refused as `UnboundCapability` at the exact app.
A Cuda demand on a linux-cpu host is refused as `LaneUnavailable` at lowering. The extension AST checker
parses with the GHC parser and rejects each named evasion form by node, so a substring scan no longer stands
between an extension and the binary.

Scope introduction is attested: no code path constructs a scope except `attest`, and `reenter` is the one
re-entry into an attested scope. The calculi the extension algebra needs are linked into the executable
rather than parked beside it. This phase folds the former scope-index and extension-conformance slices into
one claim ([DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice)).

**Phase scope:** One cohesive claim — an app needing inference bound to the linked infernix shape reaches fake-applied bytes, its unlinked twin is refused at the exact app, and every admitted extension surface is judged by AST node; it splits if a child cluster or a UI program is needed to settle it.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 5](phase_05_substrates_lanes_image_recipe.md)
**Gate:** `pb validate phase 06`; see [Gate integrity](#gate-integrity).

### Corpus

The corpus module is `Amoebius.Dsl.Examples.Extensions`, linked by the `amoebius` executable and rendered by
`amoebius render-examples`. It contains the Phase 5 corpus and adds at least three distinguishing pairs:

| Example | Distinguishes | Expected delta or refusal |
|---|---|---|
| `infernix-linked` | an app needing `Inference` bound to the linked infernix shape | provider objects for the engine runtime; application bytes carry the binding; the attested scope label on every object |
| unlinked twin | the same app with infernix absent from `LinkedExtensions` | `UnboundCapability` refused at the exact app and need |
| `cuda-on-cpu` and its cuda sibling | a Cuda demand against the host's lane set | `LaneUnavailable` refused at lowering on a linux-cpu host; the linux-cuda sibling accepted with the cuda lane label |
| refused set | one evasion form each and one unattested scope | each evasion rejected at `extension-astcheck` by node with the admitted twin accepted; `UnattestedScope` refused at the constructor |

New tags: `extension`, `infernix`, `attested`. Oracle rows for the provider objects and the scope labels are
authored before the extension-spec library exists.

### Gate specification

```gate-spec
capability: extension_admission_attested_scope
role: ordinary
claim: A statically linked infernix ExtensionSpec binds inference at the exact application and need, with CPU Deployments and CUDA DaemonSets derived from supplied lanes. Every rendered object has a scope introduced by attestation. The shipped AST checker judges native syntax and pragma nodes against its closed API before contributed source can link. The runner rebuilds a source-changed sibling with infernix removed from the actual linked list and observes UnboundCapability for the same nonce-bearing input. Independent literals judge the complete predecessor corpus, AST evasion pairs, merge refusals, opaque constructors and scope indices, runtime resources, scope labels, and consumed workflow output. Live infrastructure, child clusters, the UI language and compiler correctness are outside this claim.
subjects: Amoebius.Extension.Spec, Amoebius.Extension.Linked, Amoebius.Extension.AstCheck, Amoebius.Scope.Attested, Amoebius.Extension.Calculi, Amoebius.Dsl.Lower
suite: extensions-suite
oracle: oracle-extensions
positive: case:infernix-linked | input=infernix-linked | expected=provider objects and application binding
positive: case:cuda-on-cuda-sibling | input=cuda-on-cuda-sibling | expected=cuda lane and DaemonSet
positive: case:attested-scope | input=attested-scope | expected=one attested scope on every object
negative: case:UnboundCapability | input=same app and need in a recompiled unlinked sibling | tag=UnboundCapability | stage=lower
negative: case:LaneUnavailable | input=cuda request with only cpu lanes | tag=LaneUnavailable | stage=lower
negative: case:AstEvasion | input=located native AST or pragma node | tag=AstEvasion | stage=extension-astcheck
negative: case:UnattestedScope | input=unlabeled object | tag=UnattestedScope | stage=render
mutants: stages=Amoebius.Extension.Spec,Amoebius.Extension.Linked,Amoebius.Extension.AstCheck,Amoebius.Scope.Attested,Amoebius.Extension.Calculi,Amoebius.Dsl.Lower per-module=8 cap=40 kill-ratio=3/5 artefacts=Amoebius.Extension.Spec:extensions.spec.,Amoebius.Extension.Linked:extensions.graph.,Amoebius.Extension.AstCheck:astcheck.,Amoebius.Scope.Attested:scope.,Amoebius.Extension.Calculi:workflow.,Amoebius.Dsl.Lower:extensions.lower.
binary-fact: command=compile --input {input} --out {run}/compiled | input=root.dhall | perturbation=source-sibling(Amoebius.Extension.Linked.linkedExtensions then=staged(pre=render-examples --example infernix-linked --output {input} post=apply --executor fake --input {input} --out {run}/applied;astcheck --source-root {run}/compiled/admitted-source --owner-input {input} --out {run}/astcheck-verdict.tsv then=sentinel-to-nonce(0b5e17e11a0c0ffee0de1e9a7e5ba5ed))) | outputs={run}/compiled/decoded.dump,{run}/compiled/manifest.json,{run}/compiled/extensions.tsv,{run}/compiled/scope.tsv,{run}/compiled/workflow.tsv,{run}/astcheck-verdict.tsv,{run}/applied/fake/stdin.combined,{run}/sibling/compiled/refusal.tsv,{run}/sibling/witness.tsv
spine-fact: rendered=compiled/manifest.json | stages=freeze,decode,lower,recipe,bake,plan,provision,attest,render,extension-chain,dry-run,fake-apply | applied-digest=applied/fake/applied.sha256
substrate: none
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | The infernix corpus example, rewritten by the runner with a nonce, passes through `amoebius compile` and `amoebius apply --executor fake` with infernix as one `ExtensionSpec` in `LinkedExtensions`. The unlinked twin is refused as `UnboundCapability` at the exact app; the Cuda-on-cpu twin is refused as `LaneUnavailable`; every evasion form is rejected by AST node; every object carries an attested scope. Children and UI are excluded. |
| `Subject` | The six modules named in the gate specification, every one inside the closure of `executable amoebius`. `Amoebius.Dsl.Lower` is re-subjected because binding now resolves needs against the linked set. |
| `Command` | Future public spelling is `pb validate phase 06`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 06`; then `amoebius-validate accept --phase 06` records the receipt and applies one phase's status patch. The runner spawns the shipped `amoebius` binary as a child for `render-examples`, `compile`, `astcheck`, and `apply --executor fake`. |
| `Oracle` | `test/oracle/dsl/ExtensionsOracleMain.hs` selects the extended independent contract, including the predecessor corpus and every extension section; missing required boundary rows refuse. It parses the decoded dump, manifest, astcheck verdict and fake stdin from literal expectations and depends on no `amoebius` library. |
| `Positive controls` | Every accepted corpus example renders provider objects equal to its oracle row; the fake's stdin byte-equals the compile output; the nonce is recovered from all outputs; the admitted extension surface passes the AST checker with an empty rejection list. |
| `Paired negatives` | `UnboundCapability` refused at the exact app with the linked twin accepted; `LaneUnavailable` refused at lowering with the cuda sibling accepted; each named evasion form rejected at its AST node with the admitted twin accepted; `UnattestedScope` refused at the constructor with the attested twin accepted. |
| `Mutants` | Runner-generated from the fixed operator catalogue, eight per subject module, at most forty per gate, kill ratio at least 0.6. A linked set that admits an unlinked spec is killed at the app refusal; a checker that accepts one evasion form is killed at the verdict; a scope constructed without `attest` is killed at the label. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the corpus example count equals the rendered file count; the linked extension count equals the `LinkedExtensions` value's length; empty discovery refuses. |
| `Challenge` | After the run starts, the runner rewrites the rendered example's sentinel to a nonce and removes infernix from the linked set of one sibling. The nonce must appear in the decoded dump, the manifest, and the fake's stdin; the removal must produce `UnboundCapability` at the same app. |
| `Observer` | `ProcessObserver` over the shipped binary and the fake `kubectl`, which is a separate process image; argv, environment policy, exit, and complete output are runner-captured. The AST checker runs inside the shipped binary and its verdict is a captured output. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` refuses a subject outside the executable's closure; the oracle stanza's hygiene refuses a product dependency; `Scope` has no constructor outside `attest`, `LinkedExtensions` is built only at link time, and the checker is not bypassable by a string-built identifier, each checked by a compile-negative or refused twin. |
| `Freshness` | A unique run root; a fresh render every run; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The generated-mutant matrix over the six subject modules and the evasion-form matrix over the AST checker precede the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-06/**` and is absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-DSL-005`, `LTD-DSL-007`, and `LTD-DSL-008` close here. |
| `Predecessor` | The Phase 5 receipt in certification generation 2, chained by the digest of Phase 5's product closure plus the verifier and governance digests. |
| `Residue` | Phases 7 through 9 and every phase from 50 onward remain explicit limitations; the parked calculi that no subject links remain visible under `LTD-LIB-001` until Phase 9 decides them; `LTD-HELPER-001` remains visible until Phase 50. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and `accept` records it. |

## Doctrine adopted

- [`dsl_doctrine.md` §8 — the Haskell extension DSL](../documents/engineering/dsl_doctrine.md#8-the-haskell-extension-dsl--the-constrained-surface-extension-astcheck-admits) — the constrained surface the checker admits.
- [`dsl_doctrine.md` §5 — extension-astcheck](../documents/engineering/dsl_doctrine.md#extension-astcheck--the-extension-ast-checker) — the third foreclosure layer this phase realises by AST node.
- [`extension_conformance_doctrine.md` §2 — what an extension is](../documents/engineering/extension_conformance_doctrine.md#2-what-an-extension-is) — one record, linked, not loaded.
- [`extension_conformance_doctrine.md` §7 — link-time union closure](../documents/engineering/extension_conformance_doctrine.md#7-link-time-union-closure) — `LinkedExtensions` is the closure.
- [`capability_extension_doctrine.md` §3 — the PROVIDE and REQUIRE contract](../documents/engineering/capability_extension_doctrine.md#3-the-provide-and-require-contract) — the edge `UnboundCapability` refuses.
- [`capability_extension_doctrine.md` §6 — the merge is total, acyclic, and anti-shadow](../documents/engineering/capability_extension_doctrine.md#6-the-merge-total-acyclic-anti-shadow) — the linked set's merge law.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` this phase carries.
- [`testing_doctrine.md` §9 — derivation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) — the evasion forms as a generated enumeration against authored verdicts.

## Sprints

## Sprint 6.1: The extension-spec library and LinkedExtensions ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/extension-spec/Amoebius/Extension/Spec.hs`, `src/extension-capabilities/Amoebius/Extension/Capability.hs`, and `src/extension-link/Amoebius/Extension/Linked.hs`
**Blocked by**: [Phase 5](phase_05_substrates_lanes_image_recipe.md) gate pass
**Independent Validation**: `ExtensionSpec` is one record with its provided capabilities, required capabilities, shapes, and engine runtime, and infernix is one value of it. `LinkedExtensions` is built at link time from the values the executable names, and binding a need against it yields the provider objects of the oracle row. An app whose need no linked value provides is refused as `UnboundCapability` at the exact app with the linked twin accepted.
**Oracle**: `test/oracle/dsl/ExtensionsOracleMain.hs` states the provided and required capability sets and the provider objects per example from literals.
**Legacy IDs**: `LTD-DSL-005` — calculi and extension algebra not linked, extension share
**Docs to update**: `documents/engineering/extension_conformance_doctrine.md`

### Objective

Make the extension seam one record type in a base-only library and the linked set its only closure.

### Deliverables

- `library extension-spec` with `ExtensionSpec` and its smart constructor.
- `LinkedExtensions` with a total, acyclic, anti-shadow merge and `UnboundCapability` as its refusal.
- infernix as one `ExtensionSpec` value linked by the executable.

### Validation

Bind each example against the linked set and compare the provider objects with the oracle; require the
unlinked twin to be refused at the exact app.

### Remaining Work

The isolated implementation links the four real contributions and resolves their capability graph.
Retain its merge, binding and source-closure controls in the complete gate, including a rebuilt unlinked
sibling over the same challenged input; component observations do not close this sprint.

## Sprint 6.2: The gate-side GHC-parser AST checker ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/extension-admission/Amoebius/Extension/AstCheck.hs`, `src/extension-admission/Amoebius/Extension/SourceClosure.hs`, `test/spine/SpineExtensionRegistry.hs`, and `test/oracle/dsl/DslExtensionRegistry.hs`
**Blocked by**: Sprint 6.1
**Independent Validation**: `astcheck` parses an extension module with the GHC parser and admits only the constrained surface the DSL doctrine names. Seven evasion forms — a qualified-alias import, a re-exported forbidden name, a Template Haskell splice, a CPP-guarded definition, a foreign import, a string-built identifier, and a comment-split token — are each rejected at their AST node with the admitted twin accepted. A checker that scans substrings admits at least one form and is the changed-subject mutant the verdict kills.
**Oracle**: `test/oracle/dsl/ExtensionsOracleMain.hs` states the expected verdict per evasion form, naming the node kind, from literals.
**Legacy IDs**: `LTD-DSL-007` — astcheck is a substring scanner
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Replace the substring scanner with a checker that judges the parsed tree.

### Deliverables

- `astcheck :: ModuleSource -> Either Rejection Admitted` over the GHC parser's AST.
- The seven evasion forms as corpus values with authored verdicts.
- `amoebius astcheck` as a product subcommand whose verdict the runner captures.

### Validation

Run the checker over the admitted surface and each evasion form; compare each verdict and node kind with the
oracle.

### Remaining Work

The isolated native parser, source-closure checker and shipped `astcheck` command are implemented.
Retain all located evasion pairs, complete-tree discovery and pre-GHC transport controls in the full gate;
the seven compiler-transport component rows must not substitute for that gate.

The source-closure checker now has an explicit filesystem-observation boundary. Its compiler and product
entry points retain native queries; supplied observations attest no native file identity. The link-refusal
fixture creates no OS link, while seven ordinary-file cases also execute against native files. All eleven
independent registry rows pass, including exact control discovery and refusal before any byte read through
the supplied link. This component preparation requires no link-creation privilege and supplies no phase
receipt or live Windows result. Native source-capture fixture assumptions remain tracked in
[Phase 0](phase_00_documentation_suite.md#sprint-06-delete-pass-package-rewrite-and-executable-split-).

## Sprint 6.3: Attested-only scope and reenter ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/scope-index/Amoebius/Scope/Attested.hs`
**Blocked by**: Sprint 6.2
**Independent Validation**: `Scope` has no constructor outside `attest`, which records the attesting extension and the need it serves; `reenter` is the one re-entry and requires an existing attested scope. Every rendered object carries its scope label equal to the oracle row. A scope constructed elsewhere is a compile-negative twin, and an object rendered without a scope is refused as `UnattestedScope`.
**Oracle**: `test/oracle/dsl/ExtensionsOracleMain.hs` states the scope label per object and the attesting extension per scope from literals.
**Legacy IDs**: `LTD-DSL-008` — scope introduction not attested
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Make attestation the only way a scope enters the system.

### Deliverables

- `attest` and `reenter` as the two entries into `Scope`, with the constructor private.
- The scope label rendered onto every object by the Phase-4 render entry.
- `UnattestedScope` as a typed refusal at render.

### Validation

Render each example and compare every scope label with the oracle; require the outside constructor to fail
at the type and the unlabeled object to be refused at its tag.

### Remaining Work

The isolated implementation uses canonical attestation and scoped re-entry and stamps the rendered
objects. Retain all native constructor/coercion pairs, re-entry refusals, missing-authority controls and
per-object scope checks in the qualified gate.

## Sprint 6.4: Calculi linked into the executable ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/extension-calculi/Amoebius/Extension/Calculi.hs` and `amoebius.cabal`
**Blocked by**: Sprint 6.3
**Independent Validation**: The calculi the extension algebra consumes — the workflow calculus and the capability merge — are modules inside the closure of `executable amoebius`, and `Amoebius.Extension.Calculi` is the one import site. A calculus library that no subject links is listed under `LTD-LIB-001` and is not a subject. Re-adding a parked calculus as a dependency without a consuming subject is refused at the closure locus.
**Oracle**: `test/oracle/runner/Main.hs` states the expected closure of the executable from literals.
**Legacy IDs**: `LTD-DSL-005` — calculi and extension algebra not linked, calculus share
**Docs to update**: `documents/engineering/workflow_calculus_doctrine.md`

### Objective

Link what the binary consumes and leave what it does not consume visibly parked.

### Deliverables

- `Amoebius.Extension.Calculi` as the one import site for the consumed calculi.
- The executable's closure containing the workflow calculus for Phase 7 to consume.
- The parked libraries listed under `LTD-LIB-001` for Phase 9 to decide.

### Validation

Compare the executable's closure with the oracle's literal closure; require the unconsumed dependency to be
refused.

### Remaining Work

The isolated executable consumes the five-calculus declarations and the actual extension dependency
outputs. Its finite conformance model passed 24 component oracle rows, including exact generated bytes,
independently recomputed digest bindings, law faults and omitted observations. Four native scope-index pairs
also pass. Retain those observations and qualify the complete consuming closure in the parent gate.

## Sprint 6.5: The Phase 6 gate specification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs`, the generic runner boundary, and `amoebius.cabal`
**Blocked by**: Sprint 6.4
**Independent Validation**: The compiled specification equals the fenced block above; `verifySpec` accepts it; the corpus module contains the Phase 5 corpus. A specification whose negatives omit `AstEvasion` is refused as `SPEC-WEAKENED`.
**Oracle**: `test/oracle/runner/Main.hs` states the expected specification digest and closure from literals.
**Legacy IDs**: none
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Author the specification the runner executes for this phase.

### Deliverables

- The Phase 6 `GateSpec` with its `BinaryFact`, the astcheck verdict output, and the six subjects.
- The `extensions-suite` stanza writing the verdict and scope bytes the oracle judges.

### Validation

Run `preview phase 06` and require every row green; require `accept` to record exactly one
phase's patch.

### Remaining Work

The runtime and scope oracle rows, generic source-sibling rebuild boundary, extended oracle and guarded
build transport are implemented. The source delta was promoted with status and archive bytes preserved.
Completion requires the authenticated legacy analyzer repair, then separate complete gates and mechanical
acceptance for every numerical predecessor at the final source. Only then may the complete
`preview phase 06` and `accept` run; the component observations above supply no phase receipt.

## Documentation Requirements

**Normative amendments and delivery updates:**

Closed source-admission, repository-layout and type-boundary amendments land with their decision entry
and independent Haskell baseline before qualification. [DL-0030](../documents/decision_log.md#dl-0030--extension-admission-binds-source-scope-and-dependency-closure)
authorises this phase's bounded changes. Observed delivery claims follow the complete gate pass; the
phase and receipt remain the only current validation-status authority.

**Engineering docs to reconcile after the complete gate passes:**

- `documents/engineering/dsl_doctrine.md` — only if the admitted extension surface or the scope entries change.
- `documents/engineering/extension_conformance_doctrine.md` — only if the `ExtensionSpec` record or the link-time closure changes.
- `documents/engineering/workflow_calculus_doctrine.md` — only if the set of linked calculi changes.

**Cross-references to add:**

- Phase 5 predecessor gate pass and Phase 7 consumer links.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 5](phase_05_substrates_lanes_image_recipe.md) — the predecessor
- [Phase 7](phase_07_child_clusters_obligation_teardown.md) — the next slice, consuming the linked workflow calculus
- [Phase 9](phase_09_dsl_barrier.md) — re-runs this corpus and decides `LTD-LIB-001`
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [DSL doctrine](../documents/engineering/dsl_doctrine.md)
- [Extension conformance doctrine](../documents/engineering/extension_conformance_doctrine.md)
- [Capability extension doctrine](../documents/engineering/capability_extension_doctrine.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
