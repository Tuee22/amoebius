# Phase 9: The DSL barrier through the shipped binary

> **Purpose**: Re-run the union corpus of every slice through the shipped `amoebius` binary, prove the control-plane endpoint compiles what it decodes, and let a recorded operator-authored specification reach fake-applied bytes before any hardware phase opens.
> **Read this if**: the `DSL_BARRIER` role must be judged, or a hardware phase needs to know what receipt it binds.

This phase is `DSL_BARRIER`. It owns the union-corpus fact, the `SpineFact`, the control-plane endpoint as a
subject, and the operator demonstration. It owns no new pipeline stage; every stage belongs to Phases 3 through
8. Its predecessor is [Phase 8](phase_08_ui_program_language_binding.md), and its successor in table order is
[Phase 50](phase_50_host_assert_cli.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_03_typed_spine.md, DEVELOPMENT_PLAN/phase_04_witness_manifests_capacity_storage.md, DEVELOPMENT_PLAN/phase_05_substrates_lanes_image_recipe.md, DEVELOPMENT_PLAN/phase_06_extension_admission_attested_scope.md, DEVELOPMENT_PLAN/phase_08_ui_program_language_binding.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/illegal_state/illegal_state_lifecycle.md
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
corpus and recorded with `amoebius-validate demo`, adds a tag not in the corpus tag set and reaches
fake-applied bytes whose digest equals the render digest.

Every hardware specification from Phase 52 onward binds this phase's receipt digest and runs a corpus example
through its own subject
([`gate_runner_doctrine.md` §7](../documents/engineering/gate_runner_doctrine.md#7-the-example-corpus-and-the-hardware-rule)).

**Phase scope:** One cohesive claim — the union corpus, the endpoint, and a recorded operator-authored specification all reach fake-applied bytes through the shipped binary on the current source; it splits if any hardware, container, cluster, or live host is needed to settle it.
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
role: barrier
claim: Every member of the union of Spine, Capacity, Substrates, Extensions, ChildClusters and Ui reaches fake-applied bytes through the shipped binary. Independent rows judge every member and consumed stage, the endpoint digest equals compileDeployment for the same input, and a recorded operator-authored demonstration outside the corpus tag set reproduces its render and applied digests. The runner recovers its nonce from decoded values, manifests and the fake executor's stdin. Hardware, container engines, cluster creation and live hosts are excluded.
subjects: Amoebius.Vocabulary, Amoebius.Dsl.Spec, Amoebius.Dsl.Import, Amoebius.Dsl.Decode, Amoebius.Dsl.Lower, Amoebius.Kernel.Step, Amoebius.Kernel.Interpret, Amoebius.Dsl.Pipeline, Amoebius.Capacity.Vector, Amoebius.Capacity.Fits, Amoebius.Placement.Witness, Amoebius.Storage.Witness, Amoebius.Manifest.StatefulSet, Amoebius.Manifest.Render, Amoebius.Substrate.Classify, Amoebius.Topology.Rke2, Amoebius.Topology.Lanes, Amoebius.Placement.Taints, Amoebius.Image.Recipe, Amoebius.Image.Bake, Amoebius.Image.BaseChannel, Amoebius.Image.BuildArgv, Amoebius.Extension.Spec, Amoebius.Extension.Linked, Amoebius.Extension.AstCheck, Amoebius.Scope.Attested, Amoebius.Extension.Calculi, Amoebius.Dsl.Children, Amoebius.Calculus.Workflow.Obligation, Amoebius.Ui.Effect.Catalog, Amoebius.Ui.Expr, Amoebius.Ui.Check, Amoebius.Ui.Bind, Amoebius.Ui.Plan, Amoebius.Dsl.Examples.Union, Amoebius.Entry.ControlPlane
suite: barrier-suite
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
positive: case:approval-threshold | input=approval-threshold.dhall | expected=all effect arms, plans and rendered resources equal independent rows
positive: case:approval-threshold-sibling | input=changed threshold | expected=guard literal changes and all unrelated paths remain equal
negative: case:UnboundPort | input=unbound port twin | tag=UnboundPort | stage=binding
negative: case:RequirementWithoutPort | input=missing port twin | tag=RequirementWithoutPort | stage=binding
negative: case:GuardGap | input=non-total match twin | tag=GuardGap | stage=check
negative: case:TypeMismatch | input=ill-typed comparison twin | tag=TypeMismatch | stage=check
negative: case:UnboundedFuel | input=unbounded list twin | tag=UnboundedFuel | stage=check
negative: case:UnknownFunction | input=unknown function twin | tag=UnknownFunction | stage=check
negative: case:HandlerCarriesIO | input=IO-bearing handler | tag=HandlerCarriesIO | stage=compile
negative: case:IllTypedComparison | input=CmpNat over text | tag=IllTypedComparison | stage=compile
positive: case:union-corpus | input=six complete corpus modules | expected=every member reaches independently judged fake-applied bytes
positive: case:operator-demonstration | input=recorded operator file with an outside tag | expected=render and applied digests reproduce
negative: case:EndpointDiscardsDecodedValue | input=changed endpoint subject | tag=EndpointDiscardsDecodedValue | stage=endpoint
negative: case:DemoInsideCorpusTagSet | input=demonstration with only corpus tags | tag=DemoInsideCorpusTagSet | stage=demo
negative: case:DemoUnrecorded | input=demonstration without a current recorded digest | tag=DemoUnrecorded | stage=demo
mutants: stages=Amoebius.Vocabulary,Amoebius.Dsl.Spec,Amoebius.Dsl.Import,Amoebius.Dsl.Decode,Amoebius.Dsl.Lower,Amoebius.Kernel.Step,Amoebius.Kernel.Interpret,Amoebius.Dsl.Pipeline,Amoebius.Capacity.Vector,Amoebius.Capacity.Fits,Amoebius.Placement.Witness,Amoebius.Storage.Witness,Amoebius.Manifest.StatefulSet,Amoebius.Manifest.Render,Amoebius.Substrate.Classify,Amoebius.Topology.Rke2,Amoebius.Topology.Lanes,Amoebius.Placement.Taints,Amoebius.Image.Recipe,Amoebius.Image.Bake,Amoebius.Image.BaseChannel,Amoebius.Image.BuildArgv,Amoebius.Extension.Spec,Amoebius.Extension.Linked,Amoebius.Extension.AstCheck,Amoebius.Scope.Attested,Amoebius.Extension.Calculi,Amoebius.Dsl.Children,Amoebius.Calculus.Workflow.Obligation,Amoebius.Ui.Effect.Catalog,Amoebius.Ui.Expr,Amoebius.Ui.Check,Amoebius.Ui.Bind,Amoebius.Ui.Plan,Amoebius.Dsl.Examples.Union,Amoebius.Entry.ControlPlane per-module=8 cap=40 kill-ratio=3/5 artefacts=Amoebius.Vocabulary:vocab.,Amoebius.Dsl.Spec:spec.,Amoebius.Dsl.Import:freeze.,Amoebius.Dsl.Decode:decode.,Amoebius.Dsl.Lower:lower.,Amoebius.Kernel.Step:chain.,Amoebius.Kernel.Interpret:dry-run.,Amoebius.Kernel.Interpret:fake-apply.,Amoebius.Dsl.Pipeline:plan.,Amoebius.Dsl.Pipeline:provision.,Amoebius.Dsl.Pipeline:render.,Amoebius.Dsl.Pipeline:pipeline.,Amoebius.Dsl.Pipeline:endpoint.,Amoebius.Capacity.Vector:fits.,Amoebius.Capacity.Fits:fits.,Amoebius.Placement.Witness:place.,Amoebius.Placement.Witness:provision.,Amoebius.Storage.Witness:volume.,Amoebius.Storage.Witness:claims.,Amoebius.Manifest.StatefulSet:claims.,Amoebius.Manifest.StatefulSet:render.,Amoebius.Manifest.Render:render.,Amoebius.Manifest.Render:claims.,Amoebius.Substrate.Classify:lanes.,Amoebius.Topology.Rke2:quorum.,Amoebius.Topology.Lanes:lanes.,Amoebius.Placement.Taints:taints.,Amoebius.Image.Recipe:recipe.,Amoebius.Image.Bake:bake.,Amoebius.Image.BaseChannel:recipe.,Amoebius.Image.BuildArgv:build-argv.,Amoebius.Extension.Spec:extensions.spec.,Amoebius.Extension.Linked:extensions.graph.,Amoebius.Extension.AstCheck:astcheck.,Amoebius.Scope.Attested:scope.,Amoebius.Extension.Calculi:workflow.,Amoebius.Dsl.Lower:extensions.lower.,Amoebius.Dsl.Children:child.,Amoebius.Dsl.Lower:child.,Amoebius.Kernel.Step:teardown.,Amoebius.Calculus.Workflow.Obligation:teardown.,Amoebius.Ui.Effect.Catalog:ui.port.,Amoebius.Ui.Expr:ui.check.,Amoebius.Ui.Check:ui.check.,Amoebius.Ui.Bind:ui.bind.,Amoebius.Dsl.Lower:ui.bind.,Amoebius.Ui.Plan:ui.plan.,Amoebius.Dsl.Examples.Union:union.,Amoebius.Entry.ControlPlane:endpoint.
binary-fact: command=compile --input {input} --out {run}/compiled | input=root.dhall | perturbation=staged(pre=render-examples --example union-corpus --output {input} post=apply --executor fake --input {input} --out {run}/applied;endpoint-digest --input {input} --output {run}/endpoint-digest.tsv then=sentinel-to-nonce(0b5e17e11a0c0ffee0de1e9a7e5ba5ed)) | outputs={run}/compiled/decoded.dump,{run}/compiled/manifest.json,{run}/applied/fake/stdin.combined,{run}/endpoint-digest.tsv
spine-fact: rendered=compiled/manifest.json | stages=freeze,decode,lower,recipe,bake,plan,provision,attest,render,extension-chain,child-projection,ui-check,ui-bind,ui-plan,chain,dry-run,fake-apply | applied-digest=applied/fake/applied.sha256
substrate: none
```

## Gate integrity

**Contract check**: BOUND — the capability is registered in
`src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs`; the fenced block is its compiled rendering.
This declaration does not establish subject implementation, oracle coverage or a gate pass. Execution
evidence remains phase-local and requires the immediate predecessor gate pass.

| Key | Contract |
|---|---|
| `Claim` | On the current source, every member of the union corpus reaches fake-applied bytes through the shipped binary with the runner's nonce recovered from the decoded dump, the manifest, and the fake's stdin; the control-plane endpoint returns the digest `compileDeployment` produces for the same input; the recorded operator-authored file with a tag outside the corpus tag set reaches fake-applied bytes whose digest equals the render digest. Hardware, containers, clusters, and live hosts are excluded. |
| `Subject` | `Amoebius.Dsl.Pipeline`, `Amoebius.Dsl.Examples.Union`, and `Amoebius.Entry.ControlPlane` in `app/amoebius/Amoebius/Entry/ControlPlane.hs`, plus every subject stage of Phases 3 through 8 as enumerated in the compiled block, all required inside the closure of `executable amoebius`; the stage modules are re-mutated in this gate. |
| `Command` | Future public spelling is `pb validate phase 09`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 09`; then `amoebius-validate demo --file <path>` records the operator input and `amoebius-validate accept --phase 09` records the receipt and applies one phase's status patch. The runner spawns the shipped binary for `render-examples`, `compile`, and `apply --executor fake`, and drives the endpoint in-process through the shipped binary's control-plane entry. |
| `Oracle` | `test/oracle/dsl/Main.hs` parses every output and prints the ledger from literal rows for the whole union; it depends on no `amoebius` library. |
| `Positive controls` | Every union member equal to its oracle row; the endpoint digest equal to the pipeline digest; the operator file's applied digest equal to its render digest. |
| `Paired negatives` | `EndpointDiscardsDecodedValue` (a build in which the endpoint ignores the decoded value is refused by the digest comparison), `DemoInsideCorpusTagSet` (a demonstration whose tags are all in the corpus set is refused), and `DemoUnrecorded` (a demonstration without its current recorded input digest is refused). |
| `Mutants` | Runner-generated over the three subjects plus every stage module of Phases 3 through 8, at most forty per gate, kill ratio at least 0.6; the mutant class "endpoint discards the decoded value" must have at least one kill. |
| `Discovery` | The union's member count equals the sum of the six corpus modules' counts; the stanza module map is compared two-way; empty discovery refuses. |
| `Challenge` | The runner rewrites the rendered `root.dhall` of every member and the operator file after the run starts; the nonce must be recovered from all three outputs of every member. |
| `Observer` | `ProcessObserver` over the shipped binary and the fake `kubectl`; the endpoint digest is read from the binary's response bytes. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED`; oracle stanza hygiene; the demonstration's digest is recorded by `demo` in the generation store and must reproduce under `replay`. |
| `Freshness` | A unique run root; a fresh render of every member; the verifier digest equals the seed's; every `LTD-SRC-*` query is zero. |
| `Qualification` | The generated-mutant matrix over the union precedes the clean candidate in the same run. |
| `Cleanroom` | `.build/runs/phase-09/**`, absent afterward; the kernel ratchet is recorded; the hygiene row records no `_MUTANT` symbol, no conditional compilation, and one definition per vocabulary type. |
| `Legacy closure` | Every `LTD-DSL-*` identifier is closed or listed in Residue; every `LTD-SRC-*` query is zero; `LTD-LIB-001` is decided here — each parked calculus library is either linked into the executable or deleted, and the decision is recorded in the receipt. |
| `Predecessor` | The Phase-8 receipt in certification generation 2, chained by the digest of Phase 8's product closure plus the verifier and governance digests. |
| `Residue` | Every phase from 50 onward; `LTD-HELPER-001` until Phase 50; `LTD-UI-001` until Phases 70 and 72; `LTD-LIB-002` until the proof-assistant track is promoted. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, the `OperatorDemonstration` is present, and `accept` records it. |

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
**Implementation**: `app/amoebius/Amoebius/Entry/ControlPlane.hs` and `src/dsl-spine/Amoebius/Dsl/Pipeline.hs`
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
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs` and `src/validation-kernel/Amoebius/Validation/Runner/Binary.hs`
**Blocked by**: Sprint 9.2
**Independent Validation**: A recorded operator-authored file with a tag outside the corpus set reaches fake-applied bytes whose digest equals the render digest, and the receipt carries `OperatorDemonstration`; `DemoInsideCorpusTagSet` and `DemoUnrecorded` are refused by name.
**Oracle**: `test/oracle/runner/Main.hs` states the expected demonstration receipt fields from literals.
**Legacy IDs**: `LTD-DSL-001` — the decode-to-bind edge, demonstrated on an input no corpus author wrote
**Docs to update**: `documents/engineering/gate_runner_doctrine.md`

### Objective

Show the spine on an input the corpus never saw, recorded with `demo`.

### Deliverables

- The `SpineFact` in the Phase-9 specification.
- The `demo` command path through the runner's binary-fact stage.

### Validation

Record the operator-authored demonstration file with `amoebius-validate demo --file <path>`; run the barrier;
require the receipt field and digest equality; refuse the two twins. The input digest supplies custody, not a
cryptographic signature, as specified by the keyless receipt model in
[gate-runner doctrine §6](../documents/engineering/gate_runner_doctrine.md#6-commands-generations-and-receipts).

### Remaining Work

The registered specification declares the `SpineFact` and demonstration controls. Implement the actual
demonstration input path, its independent observations and both exact refusals before running the barrier
after the Phase-8 gate pass.

## Sprint 9.4: Hygiene rows and legacy closure ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs` and `amoebius.cabal`
**Blocked by**: Sprint 9.3
**Independent Validation**: Every `LTD-SRC-*` query is zero; every `LTD-DSL-*` identifier is closed or named in Residue; each parked calculus library is linked or deleted and the decision is in the receipt; the hygiene row is green at the ratchet.
**Oracle**: `test/oracle/runner/Main.hs` states the expected inventory join and closure from literals.
**Legacy IDs**: `LTD-LIB-001` — parked calculi decided here; `LTD-DSL-002` through `LTD-DSL-008` confirmed closed
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Close the pre-hardware ledger.

### Deliverables

- The two-way typed inventory join over every `LTD-SRC-*` and `LTD-DSL-*` identifier.
- The `LTD-LIB-001` decision recorded in the specification.

### Validation

Run `preview phase 09` and require every row green; require `accept` to record exactly one
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
