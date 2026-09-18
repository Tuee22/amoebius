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

Gate execution is held shut by the Phase-3 predecessor receipt in certification generation 2. Hardware-free
implementation may proceed ahead of the frontier as component diagnostics under
[§O](development_plan_phase_model.md#o-sprint-sized-seams-and-bounded-phase-gates); it mints no evidence.

## Phase Summary

Phase 4 makes the render stage consume the witnesses the pipeline already computes
([DL-0004](../documents/decision_log.md#dl-0004--the-typed-spec-records-are-spelled-once)). On the Phase-3
spine the render stage reads the bound deployment alone, so placement, capacity, and storage decisions reach
no byte. Here `renderCandidates` takes a `Placed` witness and an `Epoch`, the StatefulSet takes a storage
witness that becomes PVC bytes, and every quantity carries its unit in its type. The corpus grows by four
pairs over the same shipped binary, and the runner perturbs one host's capacity as well as the sentinel.

The claim adds a second capability with a distributed shape and an app with two needs, so the shape swap of
Phase 3 is re-observed with provider objects that differ in count while application bytes stay unchanged.
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
`amoebius render-examples`. It contains the Phase-3 corpus and adds at least four distinguishing pairs:

| Example | Distinguishes | Expected delta or refusal |
|---|---|---|
| `kind-two-hosts` pair | placement across two hosts | two rows on the wire with the same identities; `nodeName` differs per row and equals the placement witness |
| `kind-sql-distributed3` | a second capability with a distributed shape | one StatefulSet with three replicas, one headless Service, and PVC objects whose bytes equal the storage witness |
| `kind-two-needs` | one app needing two capabilities | two provider object sets; application bytes carry both bindings and nothing else changes |
| exact-fit sibling and its refused twins | capacity on the boundary | the exact fit is accepted; `OverCapacity` and `OneShort` are refused at provision with the same identities |

New tags: `sql`, `distributed`, `pvc`. Oracle rows are authored before the witness edge exists; a field the
witness supplies that reaches no byte is refused as `AuthoredFieldUnconsumed`, as on the Phase-3 spine.

### Gate specification

```gate-spec
capability: witness_manifests_capacity_storage
subjects:
  - Amoebius.Manifest.Render
  - Amoebius.Manifest.StatefulSet
  - Amoebius.Placement.Witness
  - Amoebius.Storage.Witness
  - Amoebius.Capacity.Vector
  - Amoebius.Capacity.Fits
  - Amoebius.Dsl.Pipeline
suite: capacity-suite
oracle: oracle-dsl
positives: [kind-two-hosts, kind-sql-distributed3, kind-two-needs, exact-fit-sibling]
negatives: [OverCapacity, OneShort, PvcWithoutStatefulSet, UnitMismatch]
mutants: { perModule: 8, perGateCap: 40, killRatio: 0.6 }
binaryFact:
  command: amoebius compile
  perturbation: sentinel-to-nonce
  outputs: [decoded-dump, manifest, fake-kubectl-stdin]
substrate: HardwareFree
corpus: { module: Amoebius.Dsl.Examples.Capacity, minimumPairs: 4 }
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | The two-host corpus example, rewritten by the runner with a nonce and a capacity one unit lower on one host, passes through `amoebius compile` and `amoebius apply --executor fake`. Each row on the wire carries the `nodeName` the placement witness assigns; replicas and requests equal the authored envelope through unit-tagged quantities; PVC bytes equal the storage witness; the over-capacity twin is refused at provision. Substrates, taints, extensions, children, and UI are excluded. |
| `Subject` | The seven modules named in the gate specification, every one inside the closure of `executable amoebius`. `Amoebius.Dsl.Pipeline` is re-subjected because its render stage now takes the witnesses. |
| `Command` | Future public spelling is `pb validate phase 04`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 04`; then `amoebius-validate accept --phase 04` records the receipt and applies one phase's status patch. The runner spawns the shipped `amoebius` binary as a child for `render-examples`, `compile`, and `apply --executor fake`. |
| `Oracle` | `test/oracle/dsl/Main.hs` parses the decoded dump, the manifest, and the fake's stdin; it states the placement rows, the envelope, the PVC bytes, and the `fits` predicate from literal rows and depends on no `amoebius` library. |
| `Positive controls` | Every accepted corpus example renders to objects equal to its oracle row; the fake's stdin byte-equals the compile output; the nonce is recovered from all three outputs; the exact-fit sibling is accepted at provision. |
| `Paired negatives` | `OverCapacity` and `OneShort` refused at provision with the exact-fit twin accepted; `PvcWithoutStatefulSet` refused at render with the StatefulSet twin accepted; `UnitMismatch` as a compile-negative twin of a well-typed sum — each at its exact tag and stage. |
| `Mutants` | Runner-generated from the fixed operator catalogue, eight per subject module, at most forty per gate, kill ratio at least 0.6. A render that ignores the placement witness is killed at the `nodeName` row; a StatefulSet that drops the storage witness is killed at the PVC bytes; a `fits` that widens one axis is killed by the differential. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the corpus example count equals the rendered file count; the `fits` enumeration's cardinality equals the product of its axis arities; empty discovery or an empty enumeration refuses. |
| `Challenge` | After the run starts, the runner rewrites the rendered example's sentinel to a nonce and lowers one host's capacity by one unit. The nonce must appear in the decoded dump, the manifest, and the fake's stdin; the lowered capacity must flip the boundary twin from accepted to `OneShort`. |
| `Observer` | `ProcessObserver` over the shipped binary and the fake `kubectl`, which is a separate process image; argv, environment policy, exit, and complete output are runner-captured. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` refuses a subject outside the executable's closure; the oracle stanza's hygiene refuses a product dependency; `renderCandidates` takes a `Placed` witness only and no PVC is constructible outside `Amoebius.Manifest.StatefulSet`, each checked by a compile-negative twin. |
| `Freshness` | A unique run root; a fresh render every run; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The generated-mutant matrix over the seven subject modules and the `fits` differential component row precede the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-04/**` and is absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-DSL-003` closes here; `LTD-DSL-004` closes its unit share here, after its vocabulary share in Phase 3 and before its substrate-enum share in Phase 5. |
| `Predecessor` | The Phase 3 receipt in certification generation 2, chained by the digest of Phase 3's product closure plus the verifier and governance digests. |
| `Residue` | Phases 5 through 9 and every phase from 50 onward remain explicit limitations; the substrate-enum share of `LTD-DSL-004` remains visible until Phase 5; `LTD-HELPER-001` remains visible until Phase 50. |
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
**Implementation**: `src/Amoebius/Manifest/Render.hs` and `src/Amoebius/Placement/Witness.hs`
**Blocked by**: [Phase 3](phase_03_typed_spine.md) gate pass
**Independent Validation**: `renderCandidates` accepts only a `Placed` witness and an `Epoch`, and every Deployment on the wire carries the `nodeName` the witness assigns; the two-host example yields two rows with the same identities. A render that reads the bound deployment without the witness is a compile-negative twin. A mutant that ignores the witness is killed by the oracle's placement row.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected `nodeName` per row and the epoch label from literals.
**Legacy IDs**: `LTD-DSL-003` — `renderAll` ignores witnesses, placement share
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`

### Objective

Move rendering after placement so the manifest is a projection of a decision, not a re-derivation of one.

### Deliverables

- `Placed` as a witness constructible only by `Amoebius.Placement.Witness.place` over the node inventory.
- `Epoch` threaded from provision into every rendered object's labels.
- `renderCandidates :: Placed -> Epoch -> BoundDeployment -> Objects` as the one entry into rendering.

### Validation

Render the two-host example and compare each row's `nodeName` and epoch label with the oracle; require the
witness-free render to fail at the type.

### Remaining Work

Implement the two modules and delete the render path that reads the bound deployment alone.

## Sprint 4.2: StatefulSet and the storage witness to PVC ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Manifest/StatefulSet.hs` and `src/Amoebius/Storage/Witness.hs`
**Blocked by**: Sprint 4.1
**Independent Validation**: `kind-sql-distributed3` renders one StatefulSet, one headless Service, and PVC objects whose bytes equal the storage witness's size, class, and deterministic name. A PVC rendered from any object other than a StatefulSet is refused as `PvcWithoutStatefulSet`. A mutant that drops the witness's size is killed at the PVC bytes.
**Oracle**: `test/oracle/dsl/Main.hs` states the PVC names, sizes, and `claimRef` values from literals.
**Legacy IDs**: `LTD-DSL-003` — `renderAll` ignores witnesses, storage share
**Docs to update**: `documents/engineering/storage_lifecycle_doctrine.md`

### Objective

Give the second capability a distributed shape whose storage is born from the StatefulSet and nowhere else.

### Deliverables

- `StorageWitness` with an explicit size, the one storage class, and the deterministic PV name.
- `renderStatefulSet` producing the StatefulSet, its headless Service, and its PVC objects from the witness.
- The `sql` capability with a `distributed3` shape in the corpus.

### Validation

Render the example and compare the PVC bytes with the oracle; require the free-standing PVC to be refused
at its tag.

### Remaining Work

Implement the two modules and the corpus additions.

## Sprint 4.3: Unit-tagged ResourceVector and the fits differential ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Capacity/Vector.hs` and `src/Amoebius/Capacity/Fits.hs`
**Blocked by**: Sprint 4.2
**Independent Validation**: `ResourceVector` carries `Quantity (u :: Unit)` per axis, so cross-unit arithmetic is a compile-negative twin. `fits` is total and agrees with the oracle's authored predicate over a generated enumeration of 6,561 cases, three values on each of eight axes, run as a component row within the gate. `OverCapacity` and `OneShort` are refused at provision with the exact-fit twin accepted.
**Oracle**: `test/oracle/dsl/Main.hs` states the `fits` predicate independently from literal axis bounds and compares it case by case with the output the suite writes.
**Legacy IDs**: `LTD-DSL-004` — unitless quantities, unit share
**Docs to update**: `documents/engineering/resource_capacity_folds.md`

### Objective

Make capacity arithmetic total and unit-safe, and settle `fits` by differential rather than by example.

### Deliverables

- `ResourceVector` over the `Quantity` type introduced in Phase 3, with `carve` and `place` total.
- `fits` with the boundary twins `OverCapacity` and `OneShort` in the corpus.
- The enumeration generated in the suite and judged by the oracle's independent predicate.

### Validation

Run the enumeration as a component row and require every case to agree; require the cross-unit sum to fail
at the type.

### Remaining Work

Implement the two modules and delete every unitless quantity path.

## Sprint 4.4: The Phase-4 gate specification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Capacity.hs` and `amoebius.cabal`
**Blocked by**: Sprint 4.3
**Independent Validation**: The compiled specification equals the fenced block above; `verifySpec` accepts it; the corpus module contains the Phase-3 corpus. A specification whose negatives omit `OverCapacity` is refused as `SPEC-WEAKENED`.
**Oracle**: `test/oracle/runner/Main.hs` states the expected specification digest and closure from literals.
**Legacy IDs**: none
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Author the specification the runner executes for this phase.

### Deliverables

- The Phase-4 `GateSpec` with its `BinaryFact` and the seven subjects.
- The `capacity-suite` stanza writing the enumeration bytes the oracle judges.

### Validation

Run `preview phase 04` and require every row green; require `accept` to record exactly one
phase's patch.

### Remaining Work

Everything above. The `accept` ends this phase.

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
