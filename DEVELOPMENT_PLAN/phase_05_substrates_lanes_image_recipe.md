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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_04_witness_manifests_capacity_storage.md, DEVELOPMENT_PLAN/phase_06_extension_admission_attested_scope.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/dsl_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/substrate_doctrine.md
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

Gate execution is held shut by the Phase-4 predecessor receipt in certification generation 2. Hardware-free
implementation may proceed ahead of the frontier as component diagnostics under
[§O](development_plan_phase_model.md#o-sprint-sized-seams-and-bounded-phase-gates); it mints no evidence.

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
subjects:
  - Amoebius.Vocabulary
  - Amoebius.Substrate.Classify
  - Amoebius.Topology.Rke2
  - Amoebius.Topology.Lanes
  - Amoebius.Placement.Taints
  - Amoebius.Image.Recipe
  - Amoebius.Image.Bake
suite: substrates-suite
oracle: oracle-dsl
positives: [rke2-three-agent, apple-lima-rke2-arm64, untainted-sibling]
negatives: [DetectedAppleAmd64, Rke2TwoServers, DuplicateHostId, TaintedOnlyHost]
mutants: { perModule: 8, perGateCap: 40, killRatio: 0.6 }
binaryFact:
  command: amoebius compile
  perturbation: sentinel-to-nonce
  outputs: [decoded-dump, manifest, image-recipe, fake-kubectl-stdin]
substrate: HardwareFree
corpus: { module: Amoebius.Dsl.Examples.Substrates, minimumPairs: 3 }
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | The rke2 corpus example, rewritten by the runner with a nonce and a taint moved to a different host, passes through `amoebius compile` and `amoebius apply --executor fake`. Every node row carries the lane `lanesOf` derives from its `Detected` value; placement respects the moved taint; the rendered `ImageRecipe` steps equal the substrates oracle. The Apple example is decoded and lowered only. `Detected Apple Amd64` and `rke2_two_servers` do not compile. Extensions, children, and UI are excluded. |
| `Subject` | The seven modules named in the gate specification, every one inside the closure of `executable amoebius`. `Amoebius.Vocabulary` is re-subjected because `Detected` and `Lane` now reach the wire. |
| `Command` | Future public spelling is `pb validate phase 05`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 05`; the human runs `sudo amoebius-validate accept --phase 05`. The runner spawns the shipped `amoebius` binary as a child for `render-examples`, `compile`, and `apply --executor fake`. |
| `Oracle` | `test/oracle/dsl/Main.hs` parses the decoded dump, the manifest, the rendered recipe, and the fake's stdin; it states the lane table, the taint-respecting placement, and the recipe steps from literal rows and depends on no `amoebius` library. |
| `Positive controls` | Every accepted corpus example yields lane labels equal to its oracle row; the fake's stdin byte-equals the compile output for the two Linux examples; the Apple example's lowered dump equals its row; the recipe steps equal the oracle's ordered list. |
| `Paired negatives` | `DetectedAppleAmd64` and `Rke2TwoServers` as compile-negative twins of the accepted arm64 and three-server values; `DuplicateHostId` refused at lowering with the distinct-id twin accepted; `TaintedOnlyHost` refused at provision with the untainted sibling accepted — each at its exact tag and stage. |
| `Mutants` | Runner-generated from the fixed operator catalogue, eight per subject module, at most forty per gate, kill ratio at least 0.6. A `classify` that returns a fixed substrate is killed at the lane row; a placement that ignores taints is killed at the `nodeName` row; a recipe that drops a step is killed at the recipe digest. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the corpus example count equals the rendered file count; the substrate catalog's arity equals the vocabulary's; empty discovery refuses. |
| `Challenge` | After the run starts, the runner rewrites the rendered example's sentinel to a nonce and moves the taint to a different host. The nonce must appear in the decoded dump, the manifest, and the fake's stdin; the moved taint must move the placement. |
| `Observer` | `ProcessObserver` over the shipped binary and the fake `kubectl`, which is a separate process image; argv, environment policy, exit, and complete output are runner-captured. No real host is read: the three reads `classify` consumes are supplied as fake inputs. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` refuses a subject outside the executable's closure; the oracle stanza's hygiene refuses a product dependency; `Detected` has no public constructor and `Rke2Quorum` no two-server arm, each checked by a compile-negative twin; the hardware token is refused before the barrier receipt exists. |
| `Freshness` | A unique run root; a fresh render every run; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The generated-mutant matrix over the seven subject modules precedes the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-05/**` and is absent afterward; no image is built or pushed; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-DSL-004` closes its substrate-enum share here, the last of its three shares. |
| `Predecessor` | The Phase 4 receipt in certification generation 2, chained by the digest of Phase 4's product closure plus the verifier and governance digests. |
| `Residue` | Phases 6 through 9 and every phase from 50 onward remain explicit limitations. Until the human rebuilds and repushes the four `amoebius-base-{cpu,cuda}-{amd64,arm64}` tags from the rendered recipe, this row states that the rendered recipe is not the published one. `LTD-HELPER-001` remains visible until Phase 50. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and the human's `accept` records it. |

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
**Implementation**: `src/Amoebius/Topology/Rke2.hs`, `src/Amoebius/Placement/Taints.hs`, and `src/Amoebius/Dsl/Lower.hs`
**Blocked by**: [Phase 4](phase_04_witness_manifests_capacity_storage.md) gate pass
**Independent Validation**: `Rke2Quorum` carries its server hosts as payload in `Three` and `Five` arms, so `rke2_two_servers` is a compile-negative twin of the accepted three-server value. A topology naming one host twice is refused at lowering as `DuplicateHostId` with the distinct-id twin accepted. A tainted host receives no placement, and a topology whose only host is tainted is refused at provision as `TaintedOnlyHost`.
**Oracle**: `test/oracle/dsl/Main.hs` states the node roles, the host identities, and the taint-respecting placement per example from literals.
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

Implement the three modules and delete every enum-only quorum representation.

## Sprint 5.2: Detected and lanes on nodes ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Substrate/Classify.hs` and `src/Amoebius/Topology/Lanes.hs`
**Blocked by**: Sprint 5.1
**Independent Validation**: `classify` is a pure function of three reads and returns the `Detected` value of Phase 3's vocabulary; every node row on the wire carries the lane `lanesOf` derives from it. A `classify` that constructs `Detected` outside the vocabulary is a compile-negative twin. The Apple example lowers to lane `linux-cpu/arm64` and is not fake-applied.
**Oracle**: `test/oracle/dsl/Main.hs` states the `(os, arch, gpu)` reads and the expected lane per node from literals.
**Legacy IDs**: `LTD-DSL-004` — duplicated vocabularies, substrate-enum share
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Make the detected substrate, not an authored label, the source of every lane on the wire.

### Deliverables

- `classify :: Reads -> Detected` over the fake-supplied reads.
- `laneLabels` rendering the derived lane onto each node object.
- The `apple-lima-rke2-arm64` example as a decode-and-lower-only positive.

### Validation

Classify each example's fake reads and compare the lane labels with the oracle; require the outside
constructor to fail at the type.

### Remaining Work

Implement the two modules and delete every second definition of the detection result.

## Sprint 5.3: The image recipe rendered from the spec ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Image/Recipe.hs` and `src/Amoebius/Image/Bake.hs`
**Blocked by**: Sprint 5.2
**Independent Validation**: `renderRecipe` produces the ordered `ImageRecipe` steps and the bake catalog from the spec's substrate and lane set, equal to the oracle's rows for each example; the Apple example selects the arm64 tag. A recipe carrying a step for a lane no node requires is refused as `UnrequiredLaneStep`. A mutant that drops a step is killed at the recipe digest.
**Oracle**: `test/oracle/dsl/Main.hs` states the ordered recipe steps and the catalog entries from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/image_build_doctrine.md`

### Objective

Render the image recipe and the bake catalog from the specification so that the recipe cannot drift from the
substrates the corpus names.

### Deliverables

- `ImageRecipe` as closed step data rendered by `renderRecipe`.
- The bake catalog projected from the recipe beneath `.build/**`; no authored catalog remains.
- `UnrequiredLaneStep` as a typed refusal.

### Validation

Render the recipe for each example and compare with the oracle; require the unrequired step to be refused at
its tag. Because the catalog is now projected from the recipe, the four `amoebius-base-{cpu,cuda}-{amd64,arm64}`
tags no longer match the repository until the human rebuilds and repushes them. That rebuild precedes this
phase's `accept`; otherwise the `Residue` row states that the rendered recipe is not the published one.

### Remaining Work

Implement the two modules and delete the authored catalog. Prompt the human to rebuild and repush the four
tags once the rendered recipe lands.

## Sprint 5.4: The Phase 5 gate specification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Substrates.hs` and `amoebius.cabal`
**Blocked by**: Sprint 5.3
**Independent Validation**: The compiled specification equals the fenced block above; `verifySpec` accepts it; the corpus module contains the Phase-4 corpus; the substrate token is `HardwareFree` and a catalog member in its place is refused before the barrier receipt exists.
**Oracle**: `test/oracle/runner/Main.hs` states the expected specification digest and closure from literals.
**Legacy IDs**: none
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through the human's `accept`

### Objective

Author the specification the runner executes for this phase.

### Deliverables

- The Phase 5 `GateSpec` with its `BinaryFact`, the recipe output, and the seven subjects.
- The `substrates-suite` stanza writing the lane and recipe bytes the oracle judges.

### Validation

Run `preview phase 05` and require every row green; require the human's `accept` to record exactly one
phase's patch.

### Remaining Work

Everything above. The `accept` ends this phase.

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
