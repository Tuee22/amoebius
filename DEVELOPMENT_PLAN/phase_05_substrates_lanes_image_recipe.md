# Phase 5: Substrates, lanes, rke2 quorum, and the image recipe

> **Purpose**: Make the substrate a detected fact on every node, the rke2 quorum a payload-bearing type, placement taint-respecting, and the image recipe a rendering of the specification rather than an authored file.
> **Read this if**: the substrate claim of the plan must be judged, or a later phase needs to know which lane labels, taints, and recipe steps the corpus already carries.

This phase owns the substrate edge of the spine: `Detected` on every node, lanes derived by `lanesOf`, the
payload-bearing `Rke2Quorum`, taints in the node inventory, and the `ImageRecipe` rendered from the spec. It
does not own extensions, child clusters, or the UI language, and it renders an image recipe without
publishing an image; publication is owed by Phase 56. Its predecessor is
[Phase 4](phase_04_witness_manifests_capacity_storage.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_04_witness_manifests_capacity_storage.md, DEVELOPMENT_PLAN/phase_06_extension_admission_attested_scope.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 5.1: Payload-bearing Rke2Quorum, taints, and DuplicateHostId](#sprint-51-payload-bearing-rke2quorum-taints-and-duplicatehostid-)
- [Sprint 5.2: Detected and lanes on nodes](#sprint-52-detected-and-lanes-on-nodes-)
- [Sprint 5.3: The image recipe rendered from the spec](#sprint-53-the-image-recipe-rendered-from-the-spec-)
- [Sprint 5.4: The Phase 5 gate specification](#sprint-54-the-phase-5-gate-specification-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

The verifier revoked the selected receipt and reopened the documentation gate after finding the missing
inherited legacy analyzer/evidence join. Earlier runs observed native constructor and factory refusals,
mutation kills and nonce-bearing compiled/fake-applied bytes. Those immutable observations do not
establish a current complete gate pass or close `LTD-DSL-004`. Fresh numerical qualification is required.

The implementation consolidates natural architecture, lane offers, and Linux frame in one private
`SubstrateProfile`. Lowering and host policy consume that catalog. The independent oracle covers the complete
catalog/architecture product, native image argv and mismatches, digest-bearing base-channel refusals,
distinct supplied resolutions, exact resource fields, and opaque factory boundaries.

The fake-process contract permits
only its transcript variable and the named runtime-added
`__CF_USER_TEXT_ENCODING` marker. GHCup/GHC version checks admit the native tools under DL-0025; no prepared
Linux bootstrap directory, compiler byte pin, hardware discovery, or particular validation host is required.

The acceptance run fully reproduced its Phase-4 predecessor after the numerical replay of Phases 0 through
4. [Phase 2](phase_02_repository_layout_conformance.md#phase-status) had 1,246 green independent oracle
verdicts, including the opaque vocabulary types' explicit class-method contracts; Phases 3 and 4 each had
920. The bounded doctrine reconciliation under
[DL-0029](../documents/decision_log.md#dl-0029--phase-5-documentation-follows-its-accepted-substrate-and-recipe-scope)
requires current numerical replay through Phase 5 before Phase 6 can mint integrated evidence.
The DL-0029 replay completed Phases 0–3; Phases 4–5 await requalification with the combined source.
Isolated hardware-free preparation continues under the agent ordering rule. Image execution and publication remain unobserved and later-owned.

## Phase Summary

Phase 5 puts the closed substrate catalog on the wire
([DL-0001](../documents/decision_log.md#dl-0001--substrates-are-a-closed-catalog-with-one-profile-site)).
Every host in the topology carries a `Detected` value that `classify` produces from three reads; lanes are
derived by `lanesOf`, never authored. `TopologySpec` gains an rke2 arm whose quorum is payload-bearing, so a
two-server quorum has no constructor. Taints enter the node inventory, and the placement witness of Phase 4
respects them. The bake catalog and the `ImageRecipe` steps are rendered from the spec rather than authored,
and the corpus grows by three pairs.

One corpus example runs on an Apple host with a Lima-synthesized Linux node; it is decoded and lowered but
not fake-applied, because this phase is hardware-free and the Apple substrate is absent by design. This phase
folds the former image-recipe slice into the substrate claim
([DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice)).

**Phase scope:** One cohesive claim — an rke2 topology with a three-server quorum and one agent reaches fake-applied bytes whose lane labels, taint-respecting placement, and rendered recipe steps equal the substrates oracle; it splits if an extension seam, a child cluster, or a UI program is needed to settle it.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 4](phase_04_witness_manifests_capacity_storage.md)
**Forward-deferred:** publication of the base images the rendered recipe describes — [Phase 56](phase_56_base_image_registry.md) `base_image_registry`
**Gate:** `pb validate phase 05`; see [Gate integrity](#gate-integrity).

### Corpus

The corpus module is `Amoebius.Dsl.Examples.Substrates`, linked by the `amoebius` executable and rendered by
`amoebius render-examples`. It contains the Phase-4 corpus and adds at least three distinguishing pairs:

| Example | Distinguishes | Expected delta or refusal |
|---|---|---|
| `rke2-three-agent` | the rke2 topology with a three-server quorum and one agent | four node rows with server and agent roles; lane `linux-cpu/amd64` on each; the recipe carries the rke2 binaries |
| `apple-lima-rke2-arm64` | an Apple host with a Lima-synthesized Linux node | decode and lower only; lane `linux-cpu/arm64`; no fake apply; the recipe selects the arm64 tag |
| taint pair | a tainted host and its untainted sibling | placement moves off the tainted host; identities and replica counts unchanged |
| refused set | one illegal substrate dimension each | `Detected Apple Amd64` and `rke2_two_servers` do not compile; `DuplicateHostId` is refused at lowering; `TaintedOnlyHost` is refused at provision |

New tags: `rke2`, `arm64`, `lane`. Oracle rows for the lane labels and the recipe steps are authored before
`classify` returns `Detected` and before the recipe module exists.

### Gate specification

```gate-spec
capability: substrates_lanes_image_recipe
role: ordinary
claim: Supplied host observations determine every node's substrate, architecture, and lanes through one profile that also owns the Linux frame. A payload-bearing three-server rke2 quorum and agents reach fake-applied bytes with control-plane and maintenance taints respected. Required lanes determine ordered recipe steps, exact resource fields, the bake catalog, and Dockerfiles; unrequired lanes and digest-bearing base channels refuse. Pure native build argument vectors cover both image flavors and architectures and refuse observed/requested mismatches. Distinct run-local resolutions leave recipe bytes unchanged. Profiles, base channels, and base resolutions cannot be forged by construction or record update. The Apple arm64 example stops after lowering and recipe rendering. The runner plants a nonce and moves a maintenance taint between agents without changing identities or replicas, and the independent oracle judges resulting placement from that input. Extensions, children, UI, hardware discovery, image execution, and publication are excluded.
subjects: Amoebius.Vocabulary, Amoebius.Substrate.Classify, Amoebius.Topology.Rke2, Amoebius.Topology.Lanes, Amoebius.Placement.Taints, Amoebius.Image.Recipe, Amoebius.Image.Bake, Amoebius.Image.BaseChannel, Amoebius.Image.BuildArgv
suite: substrates-suite
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
mutants: stages=Amoebius.Vocabulary,Amoebius.Substrate.Classify,Amoebius.Topology.Rke2,Amoebius.Topology.Lanes,Amoebius.Placement.Taints,Amoebius.Image.Recipe,Amoebius.Image.Bake,Amoebius.Image.BaseChannel,Amoebius.Image.BuildArgv per-module=8 cap=40 kill-ratio=3/5 artefacts=Amoebius.Vocabulary:vocab.,Amoebius.Substrate.Classify:lanes.,Amoebius.Topology.Rke2:quorum.,Amoebius.Topology.Lanes:lanes.,Amoebius.Placement.Taints:taints.,Amoebius.Image.Recipe:recipe.,Amoebius.Image.Bake:bake.,Amoebius.Image.BaseChannel:recipe.,Amoebius.Image.BuildArgv:build-argv.
binary-fact: command=compile --input {input} --out {run}/compiled | input=root.dhall | perturbation=staged(pre=render-examples --example tainted-first-agent --output {input} post=apply --executor fake --input {input} --out {run}/applied then=sentinel-to-nonce(0b5e17e11a0c0ffee0de1e9a7e5ba5ed),rewrite(hostName = "agent-a" => hostName = "taint-moving"),rewrite(hostName = "agent-b" => hostName = "agent-a"),rewrite(hostName = "taint-moving" => hostName = "agent-b")) | outputs={run}/compiled/frozen.dhall,{run}/compiled/decoded.dump,{run}/compiled/lowered.dump,{run}/compiled/image-recipe.tsv,{run}/compiled/bake-catalog.tsv,{run}/compiled/image-build-arguments.tsv,{run}/compiled/images/cpu-amd64.Dockerfile,{run}/compiled/plan.dump,{run}/compiled/provisioned.dump,{run}/compiled/manifest.json,{run}/compiled/chain.dump,{run}/compiled/dry-run.dump,{run}/applied/fake/stdin.combined
spine-fact: rendered=compiled/manifest.json | stages=freeze,decode,lower,recipe,bake,plan,provision,render,chain,dry-run,fake-apply | applied-digest=applied/fake/applied.sha256
substrate: none
```

## Gate integrity

**Contract check**: BOUND — the block above is the compiled specification rendered by
`amoebius-validate spec phase 05`. Native `verifySpec` accepts the actual package closure and oracle hygiene;
the documentation checker reports no contract mismatch. Generated-mutant qualification and the complete
gate remain required before this contract can supply a phase pass.

| Key | Contract |
|---|---|
| `Claim` | The rke2 corpus example, rewritten by the runner with a nonce and a taint moved to a different host, passes through `amoebius compile` and `amoebius apply --executor fake`. Every node row carries the lane `lanesOf` derives from its `Detected` value; placement respects the moved taint; the rendered `ImageRecipe` steps equal the substrates oracle. The Apple example is decoded and lowered only. `Detected Apple Amd64` and `rke2_two_servers` do not compile. Extensions, children, and UI are excluded. |
| `Subject` | The nine modules named in the gate specification, every one inside the closure of `executable amoebius`. `Amoebius.Vocabulary` is re-subjected because `Detected` and `Lane` now reach the wire. |
| `Command` | Future public spelling is `pb validate phase 05`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 05`; then `amoebius-validate accept --phase 05` records the receipt and applies one phase's status patch. The runner spawns the shipped `amoebius` binary as a child for `render-examples`, `compile`, and `apply --executor fake`. |
| `Oracle` | `test/oracle/dsl/Main.hs`, `DslSubstrates.hs`, `DslRecipe.hs`, `DslTwins.hs`, and `DslBinarySubstrates.hs` independently judge the supplied profile grid, decoded dump, manifest, exact recipe budgets, catalog, emitted build arguments, base-channel and resolution boundaries, compiler twins, and fake stdin. Literal expectations import no product declarations. |
| `Positive controls` | Every accepted example yields its independently stated lane labels, placement, recipe steps, resource fields, and build-argument vector. The eight substrate/architecture pairs name their required architecture and frame. CPU/CUDA build argv cover both architectures. Two distinct supplied resolutions preserve recipe bytes. Fake stdin equals compile output; Apple stops after lowering and recipe rendering. |
| `Paired negatives` | Illegal natural-architecture and two-server quorum twins refuse; duplicate hosts and tainted-only placement refuse at their named stages. Unrequired lanes, digest-bearing channels, invalid resolution digests, and supplied architecture mismatches have accepted siblings. Direct construction, record updates, and generic construction cannot forge opaque profiles or observations; base-channel and resolution constructors and record updates are compiler-negative twins. |
| `Mutants` | Runner-generated from the fixed operator catalogue, at most eight per subject module and forty per gate, kill ratio at least 0.6. A changed classifier GPU branch must be killed by the detection table; a changed taint predicate by the placement row; a recipe dropping a step by the ordered recipe rows. Each subject must have an attributed viable kill. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the corpus example count equals the rendered file count; the substrate catalog's arity equals the vocabulary's; empty discovery refuses. |
| `Challenge` | After the run starts, the runner rewrites the rendered example's sentinel to a nonce and moves the taint to a different host. The nonce must appear in the decoded dump, the manifest, and the fake's stdin; the moved taint must move the placement. |
| `Observer` | `ProcessObserver` over the shipped binary and the fake `kubectl`, which is a separate process image; argv, environment policy, exit, and complete output are runner-captured. No real host is read: the three reads `classify` consumes are supplied as fake inputs. |
| `Authority/bypass` | Subjects must belong to the shipped executable closure; the oracle has no product dependency. Opaque profile, observation, channel, and resolution factories are paired with constructor/update/generic negatives where applicable. The shipped compiler consumes the build-argument generator and emits its plan without starting an engine. Hardware work refuses before its barrier receipt. |
| `Freshness` | A unique run root; a fresh render every run; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The generated-mutant matrix over the nine subject modules precedes the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-05/**` and is absent afterward; no image is built or pushed; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-DSL-004` closes its substrate-enum share here, the last of its three shares. |
| `Predecessor` | The Phase 4 receipt in certification generation 2, chained by the digest of Phase 4's product closure plus the verifier and governance digests. |
| `Residue` | Phases 6 through 9 and every phase from 50 onward remain explicit limitations. Until the human rebuilds and repushes the four `amoebius-base-{cpu,cuda}-{amd64,arm64}` tags from the rendered recipe, this row states that the rendered recipe is not the published one. `LTD-HELPER-001` remains visible until Phase 50. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and `accept` records it. |

## Doctrine adopted

- [`substrate_doctrine.md` §1 — the substrate is a fact about the host](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob) — no authored substrate reaches the spec.
- [`substrate_doctrine.md` §2 — detection as a pure classification](../documents/engineering/substrate_doctrine.md#2-detection-a-pure-classification-over-three-reads) — `classify` over three reads returns `Detected`.
- [`substrate_doctrine.md` §8 — the node inventory](../documents/engineering/substrate_doctrine.md#8-the-node-inventory-the-single-owner-of-hosts-capacity-and-taints) — taints have one owner.
- [`cluster_topology_doctrine.md` §4 — a cluster is a fold over its nodes](../documents/engineering/cluster_topology_doctrine.md#4-topology-a-cluster-is-a-fold-over-its-nodes-and-cardinality-is-by-construction) — the payload-bearing quorum fixes cardinality by construction.
- [`image_build_doctrine.md` §2 — the single distribution rule](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster) — the recipe bakes binaries and the cluster only pulls.
- [`image_build_doctrine.md` §2.1 — a published tag is a cache warm-up](../documents/engineering/image_build_doctrine.md#21-a-published-tag-is-a-cache-warm-up-and-its-name-is-the-content-address) — the reason the rebuild prompt applies until the tag is a content address.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` this phase carries and the hardware token it refuses.
- [`testing_doctrine.md` §9 — derivation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) — the example corpus rule.

## Sprints

## Sprint 5.1: Payload-bearing Rke2Quorum, taints, and DuplicateHostId ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/capacity-topology/Amoebius/Topology/Rke2.hs`, `src/capacity-topology/Amoebius/Placement/Taints.hs`, and `src/dsl-spine/Amoebius/Dsl/Lower.hs`
**Blocked by**: [Phase 4](phase_04_witness_manifests_capacity_storage.md) gate pass
**Independent Validation**: `Rke2Quorum` carries its server hosts as payload in `Three` and `Five` arms, so `rke2_two_servers` is a compile-negative twin of the accepted three-server value. A topology naming one host twice is refused at lowering as `DuplicateHostId` with the distinct-id twin accepted. A tainted host receives no placement, and a topology whose only host is tainted is refused at provision as `TaintedOnlyHost`.
**Oracle**: `test/oracle/dsl/DslSubstrates.hs` states the node roles, host identities, and taint-respecting placement per example from literals.
**Legacy IDs**: `LTD-DSL-004` — duplicated vocabularies, substrate-enum share
**Docs to update**: `documents/engineering/cluster_topology_doctrine.md`

### Objective

Make the rke2 quorum and its taints representable only in their legal cardinalities.

### Deliverables

- `TopologySpec` extended with `Rke2Topology Rke2Quorum [AgentSpec]`; `Rke2Quorum` with payload-bearing `Three` and `Five` arms.
- `Taint` in the node inventory and `place` refusing a tainted host.
- `DuplicateHostId` and `TaintedOnlyHost` as typed refusals at their stages.

### Validation

Lower and provision the rke2 example and the taint pair; compare the roles and placement with the oracle;
require each twin to fail at its named locus.

### Remaining Work

None within this sprint's accepted scope. The complete gate qualified the three quorum payloads,
duplicate-host twins, tolerated and untolerated placement, and the rke2 corpus through the shipped binary.

## Sprint 5.2: Detected and lanes on nodes ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/capacity-topology/Amoebius/Substrate/Classify.hs`, `src/capacity-topology/Amoebius/Topology/Lanes.hs`, `src/vocabulary/Amoebius/Vocabulary.hs`, `src/vocabulary/Amoebius/Vocabulary/Frame.hs`, `src/Amoebius/Host/Frame.hs`, and `src/Amoebius/Host/Substrate.hs`
**Blocked by**: Sprint 5.1
**Independent Validation**: `classify` is a pure function of three reads and returns either the `Detected` value of Phase 3's vocabulary or its typed `HostRefusal`; every node row on the wire carries the lane `lanesOf` derives from it. A `classify` that constructs `Detected` outside the vocabulary is a compile-negative twin. The Apple example lowers to lane `linux-cpu/arm64` and is not fake-applied.
**Oracle**: `test/oracle/dsl/DslSubstrates.hs` states the `(os, arch, gpu)` reads and expected lane per node from literals.
**Legacy IDs**: `LTD-DSL-004` — duplicated vocabularies, substrate-enum share
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Make the detected substrate, not an authored label, the source of every lane on the wire.

### Deliverables

- `classify :: Reads -> Either HostRefusal Detected` over the fake-supplied reads.
- One private `SubstrateProfile` catalog for required architecture, lane offers, and Linux frame; lowering and host policy project it.
- `laneLabels` rendering the derived lane onto each node object.
- The `apple-lima-rke2-arm64` example as a decode-and-lower-only positive.

### Validation

Classify each example's fake reads and compare the lane labels with the oracle; require the outside
constructor to fail at the type.

### Remaining Work

None within this sprint's accepted scope. The complete gate qualified supplied-read classification,
the shared profile and frame catalog, derived lane labels, and opaque construction boundaries. The Apple
example stops at the public lowering and recipe boundary; live provider realization remains later-owned.

## Sprint 5.3: The image recipe rendered from the spec ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Image/Recipe.hs`, `src/Amoebius/Image/Bake.hs`, `src/Amoebius/Image/BaseChannel.hs`, and `src/Amoebius/Image/BuildArgv.hs`
**Blocked by**: Sprint 5.2
**Independent Validation**: `renderRecipe` produces the ordered `ImageRecipe` steps and the bake catalog from the spec's substrate and lane set, equal to the oracle's rows for each example; the Apple example selects the arm64 tag. A recipe carrying a step for a lane no node requires is refused as `UnrequiredLaneStep`. A mutant that drops a step is killed at the recipe digest.
**Oracle**: `test/oracle/dsl/DslRecipe.hs` states the ordered recipe steps, catalog entries, Dockerfile requirements, and unrequired-lane refusals from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/image_build_doctrine.md`

### Objective

Render the image recipe and the bake catalog from the specification so that the recipe cannot drift from the
substrates the corpus names.

### Deliverables

- `ImageRecipe` as closed step data rendered by `renderRecipe`.
- The bake catalog projected from the recipe beneath `.build/**`; no authored catalog remains.
- `image-build-arguments.tsv` emitted by the shipped compiler from the same pure generator that forms native build invocations; it binds no engine and runs no build.
- Private base-channel and resolution factories, exact resource-field observations, and supplied architecture-mismatch refusals.
- `UnrequiredLaneStep` as a typed refusal.

### Validation

Render the recipe for each example and compare with the oracle; require the unrequired step to be refused at
its tag. The four `amoebius-base-{cpu,cuda}-{amd64,arm64}` tags require a human rebuild and repush before
consumption, after `DSL_BARRIER` and at the Phase-56 publication boundary. No image build, rebuild,
publication, engine, or particular hardware is a prerequisite for this phase's `accept`. Its `Residue` row
states that the rendered recipe is not the published one.

### Remaining Work

None within this sprint's accepted pure scope. The complete gate qualified ordered steps, exact resource
fields, CPU/CUDA architecture cases, native build argv, rke2 recipe bytes, and the base-channel/resolution
factories. The former catalog module is a compatibility projection with no authored inventory. The human
has been prompted to rebuild and repush all four tags after `DSL_BARRIER` at the Phase-56 publication
boundary. Image execution and publication remain explicit residue.

## Sprint 5.4: The Phase 5 gate specification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs` and `amoebius.cabal`
**Blocked by**: Sprint 5.3
**Independent Validation**: The compiled specification equals the fenced block above; `verifySpec` accepts it; the corpus module contains the Phase-4 corpus; the substrate token is `HardwareFree` and a catalog member in its place is refused before the barrier receipt exists.
**Oracle**: `test/oracle/runner/Main.hs` judges the generic smart-constructor and package-graph controls from literals; `Amoebius.Doc.Governance.checkGateSpecBlocks` checks the documentation block against the compiled contract. Native actual-package `verifySpec` is a component diagnostic, not a phase pass.
**Legacy IDs**: none
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Author the specification the runner executes for this phase.

### Deliverables

- The Phase 5 `GateSpec` with its `BinaryFact`, the recipe output, and the nine subjects.
- The `substrates-suite` stanza writing the lane and recipe bytes the oracle judges.

### Validation

Run `preview phase 05` and require every row green; require `accept` to record exactly one
phase's patch.

### Remaining Work

The complete gate and predecessor reproduction passed on the version-compatible native toolchain, and
`accept` applied exactly one phase's status patch. The nonce-bearing taint challenge qualified all thirteen
outputs, including `image-build-arguments.tsv`, and matching compile/apply digests. The independent oracle
derived the untainted agent from the rewritten input without resolving imports. The subsequent DL-0029
documentation amendment requires fresh prefix replay before Phase 6 can produce integrated evidence; it changes no gate subject,
status field, or image-publication claim by hand.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes, never before):**

- `documents/engineering/substrate_doctrine.md` — only if the detection reads or the lane derivation change.
- `documents/engineering/cluster_topology_doctrine.md` — only if the quorum arms or the taint model change.
- `documents/engineering/image_build_doctrine.md` — only if the recipe steps or the bake catalog projection change.

**Cross-references to add:**

- Phase 4 predecessor gate pass, Phase 6 consumer links, and the Phase 56 publication owner.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 4](phase_04_witness_manifests_capacity_storage.md) — the predecessor
- [Phase 6](phase_06_extension_admission_attested_scope.md) — the next slice over the same corpus
- [Phase 9](phase_09_dsl_barrier.md) — re-runs this corpus through the shipped binary
- [Phase 56 base image registry](phase_56_base_image_registry.md) — publishes the images the recipe describes
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [Substrate doctrine](../documents/engineering/substrate_doctrine.md)
- [Cluster topology doctrine](../documents/engineering/cluster_topology_doctrine.md)
- [Image build doctrine](../documents/engineering/image_build_doctrine.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
