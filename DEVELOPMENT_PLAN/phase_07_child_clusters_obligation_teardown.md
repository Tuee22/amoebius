# Phase 7: Child clusters and obligation-indexed teardown

> **Purpose**: Make a child cluster's specification a typed projection of its parent's, and make every provisioning step in the chain carry a teardown obligation the type system discharges.
> **Read this if**: a forest of clusters must compile from one root, or a chain that provisions without releasing must be shown not to compile.

This phase owns the recursion edge of the spine — forest adjacency, the typed child projection, and the
obligation-indexed chain — and consumes the workflow calculus that already carries linear obligations. It does
not own the UI language, which [Phase 8](phase_08_ui_program_language_binding.md) owns, nor live child
bring-up, which the multi-cluster phases own. Its predecessor is
[Phase 6](phase_06_extension_admission_attested_scope.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_06_extension_admission_attested_scope.md, DEVELOPMENT_PLAN/phase_08_ui_program_language_binding.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/dsl_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 7.1: Forest adjacency and the typed child projection](#sprint-71-forest-adjacency-and-the-typed-child-projection-)
- [Sprint 7.2: The obligation-indexed chain](#sprint-72-the-obligation-indexed-chain-)
- [Sprint 7.3: The Phase-7 gate specification](#sprint-73-the-phase-7-gate-specification-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Gate execution is held shut by the Phase-6 predecessor receipt in certification generation 2. Hardware-free
implementation may proceed ahead of the frontier as component diagnostics under
[§O](development_plan_phase_model.md#o-sprint-sized-seams-and-bounded-phase-gates); it mints no evidence.

## Phase Summary

Phase 7 adds two facts to the spine over the corpus Phases 3 through 6 already carry. First, a root
specification may name child clusters, and compiling over the projected child subtree byte-equals compiling
over the root for the child's deployment: a child is a typed subtree projection, never a second file. Second,
`chain` returns a workflow whose obligation index is empty, so a chain that provisions a resource without a
matching release step is refused by the compiler, not by a test.

The test-topology ledger is the same fact at run time: a spin-up, a workflow, and a tear-down over the corpus
balance to zero owned resources, and the fake boundary observes the release steps in order.

**Phase scope:** One cohesive claim — a forest compiles from one root with child projections byte-equal to root compilation, and the chain's obligation index is empty at every accepted example; it splits if a live child or a UI value is needed to settle it.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 6](phase_06_extension_admission_attested_scope.md)
**Gate:** `pb validate phase 07`; see [Gate integrity](#gate-integrity).

### Corpus

The corpus module is `Amoebius.Dsl.Examples.ChildClusters`, which contains the Phase-6 corpus and adds at
least two distinguishing pairs:

| Example | Distinguishes | Expected delta or refusal |
|---|---|---|
| forest root and child | compilation over the root versus over the projected child subtree | identical bytes for the child's deployment |
| test-topology up, workflow, down | a chain with release steps versus one without | the release-less chain is a compile-negative twin; the balanced ledger reports zero owned resources |

New tags: `child`, `teardown`.

### Gate specification

```gate-spec
capability: child_clusters_obligation_teardown
role: ordinary
claim: The predecessor corpus and the forest-root-child and test-topology examples compile through the shipped binary. Projecting a child as a root preserves that child's deployment bytes; the obligation-indexed chain refuses a release-less workflow, and the separate fake executor observes reverse release order and zero owned resources. Live child clusters, spawn and the UI runtime are excluded.
subjects: Amoebius.Dsl.Children, Amoebius.Dsl.Lower, Amoebius.Kernel.Step, Amoebius.Calculus.Workflow.Obligation
suite: children-suite
oracle: oracle-dsl
positive: case:kind-single-objectstore | input=kind-single-objectstore.dhall | expected=objects equal the oracle rows
positive: case:shape-swap-sibling | input=shape-swap-sibling.dhall | expected=provider objects change, application bytes do not
positive: case:replicas-3-sibling | input=replicas-3-sibling.dhall | expected=one differing path
positive: case:local-import-twin | input=local-import-twin.dhall | expected=freezes to the baseline
positive: case:lanes-of | input=host grid | expected=total lane table
positive: case:round-trip | input=encode then decode | expected=equal values
positive: case:step-sequence | input=chain order | expected=frame then identity
positive: case:dry-run-zero | input=dry run | expected=no step executed
positive: case:fake-relay | input=fake kubectl | expected=stdin equals payload
positive: case:endpoint-digest | input=control-plane endpoint | expected=manifest digest
positive: case:fields-consumed | input=authored leaves | expected=each reaches a byte
positive: case:corpus-discovery | input=rendered files | expected=equals inventory
positive: case:shipped-binary | input=perturbed run | expected=nonce in every artefact
positive: case:kind-two-nodes | input=kind-two-nodes.dhall | expected=application on the second node
positive: case:exact-fit-sibling | input=exact-fit-sibling.dhall | expected=accepted on the boundary
positive: case:kind-sql-distributed3 | input=kind-sql-distributed3.dhall | expected=one claim per member
positive: case:kind-two-needs | input=kind-two-needs.dhall | expected=both providers' objects
positive: case:fits-total | input=three-valued vectors | expected=every pair judged
positive: case:volume-witness | input=volume identities | expected=names from identity
positive: case:statefulset-claims | input=statefulset render | expected=claim bytes equal the witness
negative: case:AppleNeedsArm64 | input=darwin amd64 | tag=NotNaturalArchitecture | stage=vocabulary
negative: case:WindowsNeedsAmd64 | input=windows arm64 | tag=NotNaturalArchitecture | stage=vocabulary
negative: case:ForbiddenImportEnv | input=forbidden-env.dhall | tag=ForbiddenImport | stage=freeze
negative: case:ForbiddenImportRemote | input=forbidden-remote.dhall | tag=ForbiddenImport | stage=freeze
negative: case:ForbiddenImportAlternative | input=forbidden-alternative.dhall | tag=ForbiddenImport | stage=freeze
negative: case:ForbiddenImportTransitive | input=forbidden-transitive.dhall | tag=ForbiddenImport | stage=freeze
negative: case:AbsoluteImport | input=forbidden-absolute.dhall | tag=AbsolutePath | stage=freeze
negative: case:HomeImport | input=forbidden-home.dhall | tag=HomePath | stage=freeze
negative: case:NonCodeImport | input=non-code-import.dhall | tag=NonCodeMode | stage=freeze
negative: case:ParseFailure | input=parse-failure.dhall | tag=ParseFailure | stage=freeze
negative: case:IllTypedAlternative | input=ill-typed-alternative.dhall | tag=IllTyped | stage=freeze
negative: case:RequestsAboveLimits | input=requests-above-limits.dhall | tag=RequestsAboveLimits | stage=decode
negative: case:EmptyNeeds | input=empty-needs.dhall | tag=EmptyNeeds | stage=decode
negative: case:ZeroReplicas | input=zero-replicas.dhall | tag=ZeroReplicas | stage=decode
negative: case:HeadroomAllZero | input=headroom-all-zero.dhall | tag=HeadroomAllZero | stage=decode
negative: case:ProductNamedInApp | input=product-named-in-app.dhall | tag=DhallFailure | stage=decode
negative: case:ShapeInApp | input=shape-in-app.dhall | tag=DhallFailure | stage=decode
negative: case:UnboundNeed | input=unbound-need.dhall | tag=UnboundNeed | stage=lower
negative: case:DanglingBinding | input=dangling-binding.dhall | tag=DanglingBinding | stage=lower
negative: case:UnknownDeployment | input=unknown-deployment.dhall | tag=UnknownDeployment | stage=lower
negative: case:HostShort | input=host-short.dhall | tag=InfrastructureDemandExceeded | stage=plan
negative: case:ReplicasOverCapacity | input=replicas-over-capacity.dhall | tag=PostBindExpansionOvercommit | stage=provision
negative: case:DetectedAppleAmd64 | input=Detected Apple Amd64 | tag=ConstructorNotExported | stage=compile
negative: case:BoundDeploymentOutsideLower | input=BoundDeployment construction | tag=ConstructorNotExported | stage=compile
negative: case:StepCarriesIO | input=Step with IO | tag=StepHasNoFunctionSlot | stage=compile
negative: case:TwoServerQuorum | input=two-server quorum | tag=EvenQuorumUnspellable | stage=compile
negative: case:OneShort | input=one-short-twin.dhall | tag=OneShort | stage=provision
negative: case:OverCapacity | input=over-capacity-twin.dhall | tag=OverCapacity | stage=provision
negative: case:UnitMismatch | input=cpu plus memory | tag=UnitsDoNotMix | stage=compile
negative: case:RenderWithoutWitness | input=render without a placement | tag=WitnessRequired | stage=compile
negative: case:PlacedOutsideFold | input=Placed construction | tag=ConstructorNotExported | stage=compile
negative: case:PvcWithoutStatefulSet | input=claim on a Deployment | tag=PvcWithoutStatefulSet | stage=render
negative: case:VolumeOutsideWitness | input=VolumeWitness construction | tag=ConstructorNotExported | stage=compile
positive: case:rke2-three-agent | input=rke2-three-agent.dhall | expected=substrates, placement, and recipe equal the independent rows
positive: case:rke2-cuda-three-agent | input=rke2-cuda-three-agent.dhall | expected=substrates, placement, and recipe equal the independent rows
positive: case:apple-lima-rke2-arm64 | input=apple-lima-rke2-arm64.dhall | expected=substrates, placement, and recipe equal the independent rows
positive: case:untainted-sibling | input=untainted-sibling.dhall | expected=substrates, placement, and recipe equal the independent rows
positive: case:taint-move | input=tainted-first-agent.dhall + tainted-second-agent.dhall | expected=substrates, placement, and recipe equal the independent rows
positive: case:substrate-profile | input=complete catalog and architecture product | expected=substrates, placement, and recipe equal the independent rows
positive: case:native-image-argv | input=flavor and observed/requested architecture product | expected=substrates, placement, and recipe equal the independent rows
positive: case:recipe-resource-bytes | input=exact catalog and stage resources | expected=substrates, placement, and recipe equal the independent rows
positive: case:base-resolutions | input=two distinct supplied resolutions | expected=substrates, placement, and recipe equal the independent rows
negative: case:Rke2TwoServers | input=two-server quorum | tag=EvenQuorumUnspellable | stage=compile
negative: case:DuplicateHostId | input=duplicate-host-id.dhall | tag=DuplicateHostId | stage=lower
negative: case:TaintedOnlyHost | input=tainted-only-host.dhall | tag=TaintedOnlyHost | stage=provision
negative: case:UnrequiredLaneStep | input=unrequired lane | tag=UnrequiredLaneStep | stage=recipe
negative: case:BaseChannelDigest | input=digest-bearing channel | tag=BaseChannelContainsDigest | stage=recipe
negative: case:BuildArchitectureMismatch | input=mismatched supplied architectures | tag=BuildArchitectureMismatch | stage=build-argv
negative: case:BaseResolutionDigestInvalid | input=short or uppercase digest | tag=BaseResolutionDigestInvalid | stage=resolution
negative: case:ProfileOutsideCatalog | input=SubstrateProfile construction | tag=ConstructorNotExported | stage=compile
negative: case:BaseChannelOutsideCatalog | input=BaseChannel construction or record update | tag=ConstructorNotExported | stage=compile
negative: case:BaseResolutionOutsideFactory | input=BaseResolution construction or record update | tag=ConstructorNotExported | stage=compile
positive: case:infernix-linked | input=infernix-linked | expected=provider objects and application binding
positive: case:cuda-on-cuda-sibling | input=cuda-on-cuda-sibling | expected=cuda lane and DaemonSet
positive: case:attested-scope | input=attested-scope | expected=one attested scope on every object
negative: case:UnboundCapability | input=same app and need in a recompiled unlinked sibling | tag=UnboundCapability | stage=lower
negative: case:LaneUnavailable | input=cuda request with only cpu lanes | tag=LaneUnavailable | stage=lower
negative: case:AstEvasion | input=located native AST or pragma node | tag=AstEvasion | stage=extension-astcheck
negative: case:UnattestedScope | input=unlabeled object | tag=UnattestedScope | stage=render
positive: case:forest-root-child | input=forest-root-child.dhall | expected=root and projected-child manifests equal the independent rows
positive: case:test-topology-up-workflow-down | input=test-topology.dhall | expected=reverse releases and zero owned resources
negative: case:ReleaseLessChain | input=release-less workflow | tag=ReleaseLessChain | stage=compile
negative: case:ChildNamesUnknownParent | input=unknown parent twin | tag=ChildNamesUnknownParent | stage=forest
negative: case:CyclicForest | input=cyclic forest twin | tag=CyclicForest | stage=forest
mutants: stages=Amoebius.Dsl.Children,Amoebius.Dsl.Lower,Amoebius.Kernel.Step,Amoebius.Calculus.Workflow.Obligation per-module=8 cap=40 kill-ratio=3/5 artefacts=Amoebius.Dsl.Children:child.,Amoebius.Dsl.Lower:child.,Amoebius.Kernel.Step:teardown.,Amoebius.Calculus.Workflow.Obligation:teardown.
binary-fact: command=compile --input {input} --out {run}/compiled | input=root.dhall | perturbation=staged(pre=render-examples --example forest-root-child --output {input} post=compile --input {run}/compiled/projected-child.dhall --out {run}/child;apply --executor fake --input {input} --out {run}/applied then=sentinel-to-nonce(0b5e17e11a0c0ffee0de1e9a7e5ba5ed)) | outputs={run}/compiled/manifest.json,{run}/child/manifest.json,{run}/applied/fake/release-ledger.tsv
substrate: none
```

## Gate integrity

**Contract check**: BOUND — the capability is registered in
`src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs`; the fenced block is its compiled rendering.
This declaration does not establish subject implementation, oracle coverage or a gate pass. Execution
evidence remains phase-local and requires the immediate predecessor gate pass.

| Key | Contract |
|---|---|
| `Claim` | For every corpus example with children, `amoebius compile` over the projected child subtree byte-equals `amoebius compile` over the root for the child's deployment; `chain` is typed `ProvisionedSpec -> Workflow '[] '[] [Step]`, so a chain provisioning without release does not compile; the test-topology ledger balances. Live children, multi-cluster spawn, and UI are excluded. |
| `Subject` | `Amoebius.Dsl.Children`, `Amoebius.Dsl.Lower`, `Amoebius.Kernel.Step`, and `Amoebius.Calculus.Workflow.Obligation`, all inside the closure of `executable amoebius`. |
| `Command` | Future public spelling is `pb validate phase 07`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 07`; then `amoebius-validate accept --phase 07` records the receipt and applies one phase's status patch. The runner spawns the shipped binary for `compile` over the root and over each projected child. |
| `Oracle` | `test/oracle/dsl/Main.hs` compares the child and root manifests and reads the release ledger; it depends on no `amoebius` library. |
| `Positive controls` | The forest example: child and root compilation byte-equal; the test-topology example: the ledger reports zero owned resources and the release steps appear in reverse provisioning order. |
| `Paired negatives` | `ReleaseLessChain` is a compile-negative twin at the obligation index; `ChildNamesUnknownParent` and `CyclicForest` are refused at the forest stage with their exact tags, each with an accepted twin. |
| `Mutants` | Runner-generated over the four subjects, eight per module, at most forty per gate, kill ratio at least 0.6; a mutant that drops a release step is killed by the ledger; a mutant that projects the wrong subtree is killed by the byte comparison. |
| `Discovery` | The stanza module map is compared two-way with the subjects; every child named in the corpus is compiled once; empty discovery refuses. |
| `Challenge` | The runner plants a nonce in the child's deployment name after the run starts; the nonce must appear in both manifests and in the ledger. |
| `Observer` | `ProcessObserver` over the shipped binary and the fake boundary; the ledger is read from the fake's output, not from the subject. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` and oracle stanza hygiene as in Phase 3; no `Workflow` value with a non-empty obligation index may be produced by `chain`, checked by the compile-negative twin. |
| `Freshness` | A unique run root; a fresh render every run; the verifier digest equals the seed's. |
| `Qualification` | The generated-mutant matrix precedes the clean candidate in the same run. |
| `Cleanroom` | `.build/runs/phase-07/**`, absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | No new identifier closes here; the due-count for every identifier is zero. The workflow calculus is consumed as a linked library. |
| `Predecessor` | The Phase-6 receipt in certification generation 2, chained by the digest of Phase 6's product closure plus the verifier and governance digests. |
| `Residue` | Phases 8 and 9 and every phase from 50 onward remain explicit limitations. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and `accept` records it. |

## Doctrine adopted

- [`dsl_doctrine.md` §5 — recursion: a child's spec is a typed subtree projection](../documents/engineering/dsl_doctrine.md#recursion-a-childs-spec-is-a-typed-subtree-projection) — the projection this phase realises.
- [`workflow_calculus_doctrine.md` §3 — teardown is a type obligation](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation) — the linear obligation the chain carries.
- [`workflow_calculus_doctrine.md` §4 — a test is a workflow with an assertion](../documents/engineering/workflow_calculus_doctrine.md#4-a-test-is-a-workflow-with-an-assertion) — the test-topology example.
- [`testing_doctrine.md` §3 — the test-topology contract](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down) — spin up, run, always tear down.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` this phase carries.

## Sprints

## Sprint 7.1: Forest adjacency and the typed child projection ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/dsl-spine/Amoebius/Dsl/Children.hs` and `src/dsl-spine/Amoebius/Dsl/Lower.hs`
**Blocked by**: [Phase 6](phase_06_extension_admission_attested_scope.md) gate pass
**Independent Validation**: The forest example's child projection lowers to the same `BoundDeployment` as the root for the child's deployment; `ChildNamesUnknownParent` and `CyclicForest` are refused at the forest stage by name; a mutant that projects the parent's deployments into the child is killed by the byte comparison.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected child manifest per example from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Make `ChildInForceSpec` a typed projection of the root rather than a text fixture, with forest adjacency
checked at lowering.

### Deliverables

- `Amoebius.Dsl.Children` with the forest, its adjacency check, and `projectChild`.
- `lowerDeployment` accepting a projected child as an ordinary root.

### Validation

Compile the child through the projection and through the root; compare bytes. Refuse each twin at its tag.

### Remaining Work

Implement the module and the forest refusals.

## Sprint 7.2: The obligation-indexed chain ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/kernel-steps/Amoebius/Kernel/Step.hs` and `src/Amoebius/Calculus/Workflow/Obligation.hs`
**Blocked by**: Sprint 7.1
**Independent Validation**: `chain` returns `Workflow '[] '[] [Step]` for every corpus example; the release-less twin does not compile at the obligation index; the fake boundary observes the release steps in reverse provisioning order and the ledger balances to zero.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected step and release order from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/workflow_calculus_doctrine.md`

### Objective

Index the chain by the obligations it holds so that provisioning without release is unrepresentable.

### Deliverables

- `chain :: ProvisionedSpec -> Workflow '[] '[] [Step]` with `Release` steps for every provisioned resource.
- The compile-negative twin for a chain that omits a release.

### Validation

Chain every example; compare the step order with the oracle; require the twin to fail at the index.

### Remaining Work

Implement the index and the twin.

## Sprint 7.3: The Phase-7 gate specification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs`
**Blocked by**: Sprint 7.2
**Independent Validation**: The compiled specification equals the fenced block above; `verifySpec` accepts it; the corpus contains the Phase-6 corpus and at least two new pairs.
**Oracle**: `test/oracle/runner/Main.hs` states the expected specification digest from literals.
**Legacy IDs**: none
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Author the specification the runner executes for this phase.

### Deliverables

- The Phase-7 `GateSpec` with its `BinaryFact`.

### Validation

Run `preview phase 07` and require every row green; require `accept` to record exactly one
phase's patch.

### Remaining Work

The declaration and its compiled documentation rendering exist. The preceding subject and corpus work,
independent oracle coverage, `verifySpec` admission and qualified gate execution remain required. Run this
gate only after the Phase-6 gate passes; `accept` alone ends this phase.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes, never before):**

- `documents/engineering/dsl_doctrine.md` — only if the child projection changes.
- `documents/engineering/workflow_calculus_doctrine.md` — only if the obligation index changes.

**Cross-references to add:**

- Phase 6 predecessor gate pass and Phase 8 consumer links.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 6 extension admission](phase_06_extension_admission_attested_scope.md) — the predecessor
- [Phase 8 UI program language](phase_08_ui_program_language_binding.md) — the next slice
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [DSL doctrine](../documents/engineering/dsl_doctrine.md)
- [Workflow calculus doctrine](../documents/engineering/workflow_calculus_doctrine.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
