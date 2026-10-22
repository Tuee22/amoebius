# Phase 4: Witness-driven manifests, capacity, and storage

> **Purpose**: Make the manifest a projection of the placement, capacity, and storage witnesses, so that node names, replicas, requests, and PVC bytes on the wire equal decisions the pipeline already made.
> **Read this if**: the second product claim of the plan must be judged, or a later slice phase needs to know which witnesses the render stage already consumes.

This phase owns the witness edge of the spine: rendering after placement and epochs, the StatefulSet and its
storage witness, unit-tagged capacity, and the total `fits` fold. It does not own substrates, lanes,
extensions, child clusters, or the UI language, which the later slice phases own in order. Its predecessor is
[Phase 3](phase_03_typed_spine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_03_typed_spine.md, DEVELOPMENT_PLAN/phase_05_substrates_lanes_image_recipe.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/content_addressing_determinism.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/substrate_node_inventory.md, documents/illegal_state/illegal_state_catalog.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 4.1: renderCandidates after placement and epochs](#sprint-41-rendercandidates-after-placement-and-epochs-)
- [Sprint 4.2: StatefulSet and the storage witness to PVC](#sprint-42-statefulset-and-the-storage-witness-to-pvc-)
- [Sprint 4.3: Unit-tagged ResourceVector and the fits differential](#sprint-43-unit-tagged-resourcevector-and-the-fits-differential-)
- [Sprint 4.4: The Phase-4 gate specification](#sprint-44-the-phase-4-gate-specification-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

The verifier revoked the selected receipt and reopened the documentation gate after finding the missing
inherited legacy analyzer/evidence join. Historical capacity, placement, storage and rendering runs remain
immutable observations beneath `validation-records/`; they do not establish a current complete gate pass.
This phase requires fresh numerical qualification after the earlier boundary is repaired.

The runner's binary challenge plants a nonce and raises one host's capacity by one unit. The independent
oracle checks the resulting placement change, witness-driven manifest and claim bytes, and the fake's
exact stdin. This phase's scope covers the declared capacity, placement, storage, and rendering claim;
substrates, extensions, children, UI, and live enforcement retain their later owners. Later closure changes
require fresh replay under [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase).

## Phase Summary

Phase 4 makes the render stage consume the witnesses the pipeline already computes
([DL-0004](../documents/decision_log.md#dl-0004--the-typed-spec-records-are-spelled-once)). On the Phase-3
spine the render stage reads the bound deployment alone, so placement, capacity, and storage decisions reach
no byte. Here the provision stage returns a `Placed` witness, which only the first-fit-decreasing fold can
construct, and an `Epoch`; `renderCandidates` takes both, a workload names the node the fold assigned it, a
StatefulSet carries the claim its `VolumeWitness` sizes, and every capacity is a `Quantity` that carries its unit in
its type. The corpus grows by six examples over the same shipped binary, and the runner raises one host's
capacity by one unit as well as planting the nonce, so the application's placement flips.

The claim adds a second capability with a distributed shape and an application with two needs, so the shape swap
of Phase 3 is re-observed with provider objects that differ in count while application bytes stay unchanged.
This phase folds the former capacity, formal-model, and manifest slices into one claim
([DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice)).

**Phase scope:** One cohesive claim — a corpus example with two hosts reaches fake-applied bytes whose `nodeName`, replicas, requests, and PVC bytes equal the placement, envelope, and storage witnesses; it splits if a second substrate, a taint, or an extension seam is needed to settle it.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 3](phase_03_typed_spine.md)
**Gate:** `pb validate phase 04`; see [Gate integrity](#gate-integrity).

### Corpus

The corpus module is `Amoebius.Dsl.Examples.Capacity`, linked by the `amoebius` executable and rendered by
`amoebius render-examples`. Nothing it renders is tracked. It contains the Phase-3 corpus unchanged and adds
four distinguishing rows, the boundary row carrying two refused twins:

| Example | Distinguishes | Expected delta or refusal |
|---|---|---|
| `kind-two-nodes` | placement across two nodes | two kind nodes of three processors: the provider's member, the heaviest workload, fills the first node and the application lands on the second; the eleven identities equal the baseline's and the application Deployment's `podNodeName` is the one differing path |
| `exact-fit-sibling` and its refused twins | capacity on the boundary | three nodes of eight ephemeral units each is accepted with every node full on that axis; `one-short-twin` at seven units is refused at provision as `OneShort`, and `over-capacity-twin`, four nodes of three units, as `OverCapacity` |
| `kind-sql-distributed3` | a second capability with a distributed shape | eighteen objects: the application's three and four global objects, and eleven for the relational provider — three StatefulSet members, each with one claim whose bytes equal the storage witness, the schema-bootstrap Job, and the provider's discovery and quorum objects |
| `kind-two-needs` | one application needing two capabilities | sixteen objects: both providers' object sets beside the application's three and the four global objects; the application's bytes carry both bindings |

The shape-swap sibling now renders seventeen objects and the baseline eleven, because each StatefulSet
member carries its claim. New tags: `sql`, `distributed`, `pvc`. The oracle's literals are typed from this
contract and the doctrine, never read from product output; the suite's differential refuses an authored
field that reaches no byte and is not refused.

### Gate specification

```gate-spec
capability: witness_manifests_capacity_storage
role: ordinary
claim: The two-node corpus example reaches fake-applied bytes whose node names, replica counts, resource requests, and claim bytes equal the placement, envelope, and storage witnesses, and every capacity is a unit-tagged quantity. The runner rewrites the rendered example after the run starts, planting a nonce and raising one host capacity by one unit so the application's placement flips, and the oracle judges every stage artefact from literals. The total fit over every pair of three-valued vectors, the volume identities, and the render of a claim without a StatefulSet are judged from the suite's bytes, and the over-capacity twins are refused at provision with the exact-fit twin accepted. Substrates, taints, extensions, children, and the UI language are excluded.
subjects: Amoebius.Capacity.Vector, Amoebius.Capacity.Fits, Amoebius.Placement.Witness, Amoebius.Storage.Witness, Amoebius.Manifest.StatefulSet, Amoebius.Manifest.Render
suite: spine-suite
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
mutants: stages=Amoebius.Capacity.Vector,Amoebius.Capacity.Fits,Amoebius.Placement.Witness,Amoebius.Storage.Witness,Amoebius.Manifest.StatefulSet,Amoebius.Manifest.Render per-module=8 cap=40 kill-ratio=3/5 artefacts=Amoebius.Capacity.Vector:fits.,Amoebius.Capacity.Fits:fits.,Amoebius.Placement.Witness:place.,Amoebius.Placement.Witness:provision.,Amoebius.Storage.Witness:volume.,Amoebius.Storage.Witness:claims.,Amoebius.Manifest.StatefulSet:claims.,Amoebius.Manifest.StatefulSet:render.,Amoebius.Manifest.Render:render.,Amoebius.Manifest.Render:claims.
binary-fact: command=compile --input {input} --out {run}/compiled | input=root.dhall | perturbation=staged(pre=render-examples --example kind-two-nodes --output {input} post=apply --executor fake --input {input} --out {run}/applied then=sentinel-to-nonce(0b5e17e11a0c0ffee0de1e9a7e5ba5ed),rewrite(hostCpu = 3 => hostCpu = 4)) | outputs={run}/compiled/frozen.dhall,{run}/compiled/decoded.dump,{run}/compiled/lowered.dump,{run}/compiled/plan.dump,{run}/compiled/provisioned.dump,{run}/compiled/manifest.json,{run}/compiled/chain.dump,{run}/compiled/dry-run.dump,{run}/applied/fake/stdin.combined
spine-fact: rendered=compiled/manifest.json | stages=freeze,decode,lower,plan,provision,render,chain,dry-run,fake-apply | applied-digest=applied/fake/applied.sha256
substrate: none
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | The two-node corpus example, rewritten by the runner with a nonce and one host's processors raised by one unit, passes through `amoebius compile` and `amoebius apply --executor fake`. Each workload on the wire carries the `podNodeName` the placement witness assigns, so the application's node flips with the raised capacity; replicas and requests equal the authored envelope through unit-tagged quantities; claim bytes equal the storage witness; the over-capacity twins are refused at provision with the exact-fit sibling accepted. The total `fits`, the volume identities, and the render of a claim without a StatefulSet are judged from the suite's bytes. Substrates, taints, extensions, children, and UI are excluded. |
| `Subject` | The six modules named in the gate specification, every one inside the closure of `executable amoebius`. The render stage reaches the witnesses through `Amoebius.Manifest.Render`; `Amoebius.Dsl.Pipeline` stays a Phase-3 subject and its stage rows are re-judged here. |
| `Command` | Future public spelling is `pb validate phase 04`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 04`; then `amoebius-validate accept --phase 04` records the receipt and applies one phase's status patch. The runner spawns the shipped `amoebius` binary as a child three times for its challenge: `render-examples --example kind-two-nodes --output <input>`, then `compile --input <input> --out <run>/compiled` on the perturbed input, then `apply --executor fake --input <input> --out <run>/applied`; it then runs the shared spine suite and the oracle with those outputs beneath the suite directory. |
| `Oracle` | `test/oracle/dsl/Main.hs`, with its modules beside it, reads the suite's tables and stage artefacts and the runner's own outputs and prints the ledger from literals typed in `test/oracle/dsl/DslTables.hs` and `test/oracle/dsl/DslCapacity.hs`. It states the placement rows, the envelope, the claim bytes, and the `fits` predicate itself, reads the nodes, host capacity, and replica count of the challenge from the input the runner authored, and writes and compiles its own compile-negative twins; it depends on no `amoebius` library. |
| `Positive controls` | The Phase-3 positives are re-judged over the changed objects. `kind-two-nodes` puts the application on the second node and renders the baseline's identities; the exact-fit sibling is accepted at provision; the SQL example renders one claim per member; the two-needs example renders both providers' objects; `fits` agrees with the oracle's predicate over every pair of three-valued four-axis vectors, and its sum and zero are the componentwise sum and the identity; the volume witness names every volume from its identity and refuses the identities that could collide; a StatefulSet renders its claim and a bare one renders none. |
| `Paired negatives` | Thirty-three, each differing from its positive twin in one dimension and each refused at its exact tag and stage: the twenty-six of Phase 3, and seven added here — `OneShort` and `OverCapacity` at provision with the exact-fit sibling accepted; `PvcWithoutStatefulSet` at render with the StatefulSet twin accepted; and four compile-negative twins the oracle writes and compiles itself (a sum of two units, a render without a placement witness, a `Placed` built outside the fold, and a `VolumeWitness` built outside its constructor). |
| `Mutants` | Runner-generated from the fixed operator catalogue over the six subject modules, eight per module, at most forty per gate, kill ratio at least 0.6, stillborn excluded, each recorded with its operator, production locus, and applied-change witness. A kill requires a red oracle row whose name begins with a prefix the mutated module owns (the `artefacts` of the gate specification): the vector and fit modules own the `fits.` rows, the placement witness the `place.` and `provision.` rows, the volume witness the `volume.` and `claims.` rows, and the StatefulSet and render modules the `claims.` and `render.` rows. A crash, an empty ledger, or a red row owned by another module leaves the mutant a survivor, and every subject module must be killed at least once. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the corpus example count equals the rendered file count; the `fits` enumeration's cardinality equals the product of its axis arities and its pairs are every pair exactly once; empty discovery or an empty enumeration refuses. |
| `Challenge` | After the run starts, the runner renders `kind-two-nodes`, rewrites its sentinel to the run's nonce and `hostCpu = 3` to `hostCpu = 4`, and runs `compile` and `apply` on the result. The oracle discovers the nonce in the decoded dump, finds the sentinel absent from every output, reads the node count, host capacity, and replica count from the perturbed input, and judges every artefact from literals that substitute the nonce and those numbers, so the application lands on the first node where the shipped example puts it on the second; the nonce must also appear in the manifest and in the fake's stdin, and every declared stage family must have a green oracle row. |
| `Observer` | `ProcessObserver` records argv, environment policy, exit, and complete output of every build and run of the suite and the oracle and of the three product commands. The fake `kubectl` is a grandchild of the apply command and the same program image invoked under another name, so it is observed through the transcript it writes, which the oracle judges, and through the digest cross-check of the applied bytes. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` refuses a subject outside the executable's closure; the oracle stanza's hygiene refuses a product dependency and a second definition of any vocabulary type, including the resource vector, anywhere beneath `src/`. `renderCandidates` takes a `Placed` witness and an `Epoch` and nothing that can stand in for them; `Placed` and `VolumeWitness` have private constructors and the claim body's constructor sits in a hidden module, so no placement, volume, or claim is constructible outside its owner, each checked by a compile-negative twin the oracle writes. |
| `Freshness` | A unique run root; a fresh render every run; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The generated-mutant matrix over the six subject modules and the `fits` enumeration precede the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-04/**` and is absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-DSL-003` closes here; `LTD-DSL-004` closes its unit share here, after its vocabulary share in Phase 3 and before its substrate-enum share in Phase 5. |
| `Predecessor` | The Phase 3 receipt in certification generation 2, chained by the digest of Phase 3's product closure plus the verifier and governance digests. |
| `Residue` | Phases 5 through 9 and every phase from 50 onward remain explicit limitations; the substrate-enum share of `LTD-DSL-004` remains visible until Phase 5; `LTD-HELPER-001` remains visible until Phase 50. The corpus reaches the fixed-supply arm of the placement fold on kind hosts only: taints, anti-affinity, attach limits, bounded processor overcommit, elastic growth, and the accelerator and Pulumi execution folds stay component suites that this gate does not record. The fake is the product's own program image, so a fault the stages share with the fake is outside what the gate observes. The volume sizes of the five capability arms the corpus does not author, and those arms' provider objects, are not judged from the suite's bytes. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and `accept` records it. |

## Doctrine adopted

- [`manifest_generation_doctrine.md` §2 — `renderAll` is the sole public pure function](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects) — the witnesses enter through its typed arguments, never through a template.
- [`substrate_doctrine.md` §8 — the node inventory](../documents/engineering/substrate_doctrine.md#8-the-node-inventory-the-single-owner-of-hosts-capacity-and-taints) — the single owner of the capacity the placement witness reads.
- [`resource_capacity_folds.md` §4 — the total fold](../documents/engineering/resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting) — `fits`, `carve`, and `place` as total functions over unit-tagged vectors.
- [`storage_lifecycle_doctrine.md` §3 — PVCs are born only from StatefulSets](../documents/engineering/storage_lifecycle_doctrine.md#3-pvcs-are-born-only-from-statefulsets) — the constructor boundary the `PvcWithoutStatefulSet` twin exercises.
- [`storage_lifecycle_doctrine.md` §5 — sizes are explicit and hard-capped](../documents/engineering/storage_lifecycle_doctrine.md#5-sizes-are-explicit-hard-capped-and-one-volume-per-claim) — the storage witness carries a size, never a default.
- [`dsl_doctrine.md` §4 — total composability](../documents/engineering/dsl_doctrine.md#4-total-composability) — the witness records extend the spec records spelled once.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` this phase carries.
- [`testing_doctrine.md` §9 — derivation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) — the generated `fits` enumeration against an authored expectation.

## Sprints

## Sprint 4.1: renderCandidates after placement and epochs ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/manifest-render/Amoebius/Manifest/Render.hs` and `src/capacity-topology/Amoebius/Placement/Witness.hs`
**Blocked by**: [Phase 3](phase_03_typed_spine.md) gate pass
**Independent Validation**: `renderCandidates` accepts only a `Placed` witness and an `Epoch`; every workload on the wire carries the `podNodeName` the witness assigns and every object the epoch label `amoebius.io/epoch`; `kind-two-nodes` renders the baseline's eleven identities with the application Deployment's node the one differing path. A render without a placement witness and a `Placed` built outside the fold are compile-negative twins the oracle writes and compiles. A mutant that ignores the witness or drops the epoch is killed by the oracle's render and placement rows.
**Oracle**: `test/oracle/dsl/DslStages.hs` states the expected `podNodeName` per workload and the epoch label from literals.
**Legacy IDs**: `LTD-DSL-003` — `renderAll` ignores witnesses, placement share
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`

### Objective

Move rendering after placement so the manifest is a projection of a decision, not a re-derivation of one.

### Deliverables

- `Placed`, a witness whose constructor is private to `Amoebius.Placement.Witness`, produced only by `place`, the first-fit-decreasing fold over the node inventory; `placedNode` answers which node a workload was assigned.
- `Epoch`, named by the provision stage from its generation and stamped on every rendered object.
- `renderCandidates :: Placed -> Epoch -> ProvisionedRenderSourceSet -> Either RenderRefusal [K8sObject]` as the one entry into rendering, with the provision stage returning the `Placed` and `Epoch` the pipeline renders through.

### Validation

Render the two-node example and compare each row's `podNodeName` and epoch label with the oracle; require the
witness-free render and the `Placed` built outside the fold to fail at the type.

### Remaining Work

None within this sprint. The complete qualified gate checks the placement/envelope witnesses and the
rendering path that consumes them; the receipt is recorded above.

## Sprint 4.2: StatefulSet and the storage witness to PVC ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/manifest-render/Amoebius/Manifest/StatefulSet.hs` and `src/storage-geometry-folds/Amoebius/Storage/Witness.hs`
**Blocked by**: Sprint 4.1
**Independent Validation**: `kind-sql-distributed3` renders three StatefulSet members, each with one claim whose bytes equal the volume witness's size, storage class, owner, and deterministic names; `kind-single-objectstore` renders its one. The volume witness names each volume from its identity and refuses a volume of zero bytes and an identity whose parts could make two witnesses name one volume. A claim on any source that is not a StatefulSet is refused as `PvcWithoutStatefulSet`, and a `VolumeWitness` built outside its constructor is a compile-negative twin. A mutant that drops a claim, its size, or its owner is killed at the claim rows.
**Oracle**: `test/oracle/dsl/DslCapacity.hs` and `test/oracle/dsl/DslStages.hs` state the claim names, sizes, classes, owners, and pre-bound volume names from literals.
**Legacy IDs**: `LTD-DSL-003` — `renderAll` ignores witnesses, storage share
**Docs to update**: `documents/engineering/storage_lifecycle_doctrine.md`

### Objective

Give the second capability a distributed shape whose storage is born from the StatefulSet and nowhere else.

### Deliverables

- `VolumeWitness` with an explicit size, the one storage class `amoebius-retained`, and names that are pure functions of identity — the claim `data-<member>-<ordinal>` and the volume `<namespace>.<member>.pv-<ordinal>` — constructed only by `mkVolumeWitness`, which refuses an empty volume and a non-label identity.
- `renderStatefulSet` producing the StatefulSet and the claim of its one ordinal; the claim body's constructor lives in a hidden module, so no other module can build a claim.
- The volume size each capability's members receive, and the `sql` capability with a `distributed3` shape in the corpus.

### Validation

Render the example and compare the claim bytes with the oracle; require the claim on a Deployment to be refused
at its tag and the volume built outside its constructor to fail at the type.

### Remaining Work

None within this sprint. The complete qualified gate checks the storage-witness and StatefulSet/PVC
observations, including their paired refusals.

## Sprint 4.3: Unit-tagged ResourceVector and the fits differential ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/capacity-topology/Amoebius/Capacity/Vector.hs` and `src/capacity-topology/Amoebius/Capacity/Fits.hs`
**Blocked by**: Sprint 4.2
**Independent Validation**: `ResourceVector` carries a `Quantity (u :: Unit)` per axis, so a sum of two units is a compile-negative twin. `fits` is total and agrees with the oracle's authored predicate over every pair of three-valued four-axis vectors, 6,561 pairs written by the suite; the oracle judges the verdict, the first exceeded axis in a fixed order, the headroom, the exact fit, the componentwise sum, and the zero identity. `OverCapacity` and `OneShort` are refused at provision with the exact-fit sibling accepted.
**Oracle**: `test/oracle/dsl/DslCapacity.hs` states the `fits` predicate independently from literal axis values and compares it case by case with the output the suite writes.
**Legacy IDs**: `LTD-DSL-004` — unitless quantities, unit share
**Docs to update**: `documents/engineering/resource_capacity_folds.md`

### Objective

Make capacity arithmetic total and unit-safe, and settle `fits` by differential rather than by example.

### Deliverables

- `ResourceVector` over the `Quantity` type introduced in Phase 3, with a saturating difference and `carve` total.
- `fits` with the boundary twins `OverCapacity` and `OneShort` in the corpus, the provision stage naming a shortfall of exactly one unit as `OneShort`.
- The enumeration generated in the suite and judged by the oracle's independent predicate.

### Validation

Run the enumeration and require every case to agree; require the sum of two units to fail at the type.

### Remaining Work

None within this sprint. The complete qualified gate checks the unit boundary, all 6,561 fit pairs,
componentwise sums, zero identity, and capacity refusals.

## Sprint 4.4: The Phase-4 gate specification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs` and `amoebius.cabal`
**Blocked by**: Sprint 4.3
**Independent Validation**: The compiled specification equals the fenced block above; `verifySpec` accepts it; the corpus module contains the Phase-3 corpus. A specification whose negatives omit `OverCapacity` is refused as `SPEC-WEAKENED`.
**Oracle**: `test/oracle/runner/Main.hs` states the rewrite perturbation's rendering, the kill-attribution cases, and the vocabulary list from literals.
**Legacy IDs**: none
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Author the specification the runner executes for this phase.

### Deliverables

- The Phase-4 `GateSpec` with its `BinaryFact` carrying the rewrite perturbation, its six subjects, and the artefact prefixes each owns, registered in `Registry.hs`.
- The capacity section of the shared spine suite writing the enumeration, volume, and claim bytes the oracle judges.

### Validation

Run `preview phase 04` and require every row green; require `accept` to record exactly one
phase's patch.

### Remaining Work

None within this sprint. The registered specification passed its complete gate, and numerical replay
refreshed the recorded receipt under the current verifier and governance digests.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes, never before):**

- `documents/engineering/manifest_generation_doctrine.md` — only if the witness arguments of the render entry change.
- `documents/engineering/storage_lifecycle_doctrine.md` — only if the storage witness or the PVC constructor boundary changes.
- `documents/engineering/resource_capacity_folds.md` — only if the total fold's signatures change.

**Cross-references to add:**

- Phase 3 predecessor gate pass and Phase 5 consumer links.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 3](phase_03_typed_spine.md) — the predecessor
- [Phase 5](phase_05_substrates_lanes_image_recipe.md) — the next slice over the same corpus
- [Phase 9](phase_09_dsl_barrier.md) — re-runs this corpus through the shipped binary
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [Manifest generation doctrine](../documents/engineering/manifest_generation_doctrine.md)
- [Storage lifecycle doctrine](../documents/engineering/storage_lifecycle_doctrine.md)
- [Resource capacity folds](../documents/engineering/resource_capacity_folds.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
