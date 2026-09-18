# Phase 3: The typed spine from one spec to fake-applied bytes

> **Purpose**: Make one operator-authored specification reach fake-applied manifest bytes through the shipped `amoebius` binary, with every stage typed and every stage's output consumed by the next.
> **Read this if**: the first product claim of the plan must be judged, or a later slice phase needs to know what the spine already carries.

This phase owns the first product specification: the vocabulary, the typed root specification, the decoder,
the lowering into the bind input, the closed step algebra, and the one pipeline that composes them. It does
not own witness-driven rendering, substrates, extensions, child clusters, or the UI language, which the later
slice phases own in order. Its predecessor is [Phase 2](phase_02_repository_layout_conformance.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_04_witness_manifests_capacity_storage.md, DEVELOPMENT_PLAN/phase_09_dsl_barrier.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/system_components.md, documents/decision_log.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/content_addressing_determinism.md, documents/engineering/dsl_doctrine.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/engineering/testing_doctrine.md, documents/illegal_state/illegal_state_catalog.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 3.1: Vocabulary and ui-core split](#sprint-31-vocabulary-and-ui-core-split-)
- [Sprint 3.2: The typed root specification](#sprint-32-the-typed-root-specification-)
- [Sprint 3.3: Import, decode, encode, and examples](#sprint-33-import-decode-encode-and-examples-)
- [Sprint 3.4: Lowering into the bind input](#sprint-34-lowering-into-the-bind-input-)
- [Sprint 3.5: Steps as data and the product subcommands](#sprint-35-steps-as-data-and-the-product-subcommands-)
- [Sprint 3.6: The pipeline and the control-plane endpoint](#sprint-36-the-pipeline-and-the-control-plane-endpoint-)
- [Sprint 3.7: The Phase-3 gate specification and front-half deletions](#sprint-37-the-phase-3-gate-specification-and-front-half-deletions-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Gate execution is held shut by the Phase-2 predecessor receipt in certification generation 2. Hardware-free
implementation may proceed ahead of the frontier as component diagnostics under
[§O](development_plan_phase_model.md#o-sprint-sized-seams-and-bounded-phase-gates); it mints no evidence.

## Phase Summary

Phase 3 replaces the disconnected front half of the DSL — a text node tree, a nine-field toy decoder, and a
bind stage hand-built from a challenge string — with one typed path
([DL-0004](../documents/decision_log.md#dl-0004--the-typed-spec-records-are-spelled-once)). An operator-authored
Dhall file is frozen, decoded into `RootInForceSpec`, lowered into `BoundDeployment`, planned, provisioned,
rendered, chained into closed `Step` data, and applied through a fake `kubectl` whose stdin bytes must equal
the rendered output. The runner rewrites the example after the run starts; the nonce it plants must be
recovered from the decoded dump, the manifest, and the fake's stdin.

The claim is deliberately narrow: one cluster, one application needing one capability, one deployment, and
the two siblings that distinguish a shape swap and a replica change. Placement, storage, substrates,
extensions, children, and the UI language are later slices over the same growing corpus.

**Phase scope:** One cohesive claim — a `RootInForceSpec` authored as Dhall reaches fake-applied bytes through the shipped binary with every stage typed and consumed; it splits if a witness-driven manifest field, a second substrate, or an extension seam is needed to settle it.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 2](phase_02_repository_layout_conformance.md)
**Forward-deferred:** witness-driven rendering and unit-tagged capacity — [Phase 4](phase_04_witness_manifests_capacity_storage.md) `witness_manifests_capacity_storage` / `LTD-DSL-003`; the untracked runtime helper on the control-plane path — [Phase 50](phase_50_host_assert_cli.md) `host_assert_cli` / `LTD-HELPER-001`
**Gate:** `pb validate phase 03`; see [Gate integrity](#gate-integrity).

### Corpus

The corpus module is `Amoebius.Dsl.Examples.Spine`, linked by the `amoebius` executable and rendered by
`amoebius render-examples`. It carries at least three distinguishing pairs and one refused set:

| Example | Distinguishes | Expected delta or refusal |
|---|---|---|
| `kind-single-objectstore` | the baseline | one Deployment, one Service, one namespace; identities equal the authored names |
| shape-swap sibling | the capability binding's shape | provider object count changes; application bytes unchanged |
| replicas-3 sibling | the authored replica count | `spec.replicas` changes and nothing else |
| refused set | one illegal dimension each | `UnboundNeed`, `DanglingBinding`, `UnknownDeployment`, `ForbiddenImport`, requests above limits, empty needs — each at its exact tag and stage |

New tags: `kind`, `objectstore`, `single-node`. Oracle rows are authored before the pipeline stage exists;
`AuthoredFieldUnconsumed` refuses a field that reaches no byte.

### Gate specification

```gate-spec
capability: typed_spine
subjects:
  - Amoebius.Vocabulary
  - Amoebius.Dsl.Spec
  - Amoebius.Dsl.Import
  - Amoebius.Dsl.Decode
  - Amoebius.Dsl.Lower
  - Amoebius.Kernel.Step
  - Amoebius.Kernel.Interpret
  - Amoebius.Dsl.Pipeline
suite: spine-suite
oracle: oracle-dsl
positives: [kind-single-objectstore, shape-swap-sibling, replicas-3-sibling]
negatives: [UnboundNeed, DanglingBinding, UnknownDeployment, ForbiddenImport, RequestsAboveLimits, EmptyNeeds]
mutants: { perModule: 8, perGateCap: 40, killRatio: 0.6 }
binaryFact:
  command: amoebius compile
  perturbation: sentinel-to-nonce
  outputs: [decoded-dump, manifest, fake-kubectl-stdin]
spineFact:
  rendered: root.dhall
  stages: [freeze, decode, lower, plan, provision, render, chain, dry-run, fake-apply]
  appliedDigestFile: applied.sha256
substrate: HardwareFree
corpus: { module: Amoebius.Dsl.Examples.Spine, minimumPairs: 3 }
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | A `RootInForceSpec` rendered from the corpus, rewritten by the runner with a nonce and a changed replica count, passes through `amoebius compile` and `amoebius apply --executor fake`; the fake `kubectl` stdin byte-equals the compile output and, parsed by the independent oracle executable, carries the authored identities, namespace, and the nonce. One generated mutant per stage module is killed at the following stage. Witness-driven fields, substrates, extensions, children, and UI are excluded. |
| `Subject` | The eight stage modules named in the gate specification, the product subcommands in `app/amoebius/Main.hs`, and the control-plane endpoint in `app/amoebius/Amoebius/Entry/ControlPlane.hs`. Every subject is inside the closure of `executable amoebius`. |
| `Command` | Future public spelling is `pb validate phase 03`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 03`; then `amoebius-validate accept --phase 03` records the receipt and applies one phase's status patch. The runner spawns the shipped `amoebius` binary as a child for `render-examples`, `compile`, and `apply --executor fake`. |
| `Oracle` | `test/oracle/dsl/Main.hs` parses the decoded dump, the manifest, and the fake's stdin and prints the ledger from literal rows; it depends on no `amoebius` library. |
| `Positive controls` | Every accepted corpus example decodes to a value equal to its oracle row; the fake's stdin byte-equals the compile output; the nonce is recovered from all three outputs. |
| `Paired negatives` | `UnboundNeed`, `DanglingBinding`, `UnknownDeployment`, four `ForbiddenImport` twins (`env:`, remote, `?` fallback wrapping remote, transitive local `env:`), requests above limits, and empty needs — each refused at its exact tag and stage with the positive twin accepted. |
| `Mutants` | Runner-generated from the fixed operator catalogue, eight per stage module, at most forty per gate, kill ratio at least 0.6; at least one kill per stage observed at the following stage's artefact. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the corpus example count equals the rendered file count; empty discovery refuses. |
| `Challenge` | After the run starts, the runner rewrites the rendered example's sentinel to a nonce and changes the replica count; the nonce must appear in the decoded dump, the manifest, and the fake's stdin. |
| `Observer` | `ProcessObserver` over the shipped binary and the fake `kubectl`, which is a separate process image; argv, environment policy, exit, and complete output are runner-captured. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` refuses a subject outside the executable's closure; the oracle stanza's hygiene refuses a product dependency; no `BoundDeployment` may be constructed outside `Amoebius.Dsl.Lower`, checked by a compile-negative twin. |
| `Freshness` | A unique run root; a fresh render every run; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The generated-mutant matrix over the eight stage modules precedes the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-03/**` and is absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-DSL-001`, `LTD-DSL-002`, `LTD-DSL-009`, `LTD-SRC-002`, `LTD-SRC-003`, `LTD-DOC-001`, and `LTD-VAL-005` close here; `LTD-DSL-004` closes its vocabulary share here and its unit share in Phase 4. |
| `Predecessor` | The Phase-2 receipt in certification generation 2, chained by the digest of Phase 2's product closure plus the verifier and governance digests. |
| `Residue` | Phases 4 through 9 and every phase from 50 onward remain explicit limitations; `LTD-HELPER-001` remains visible residue until Phase 50. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and `accept` records it. |

## Doctrine adopted

- [`dsl_doctrine.md` §4 — total composability](../documents/engineering/dsl_doctrine.md#4-total-composability) — the typed spec records this phase realises.
- [`dsl_doctrine.md` §5 — the illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) — the three foreclosure layers the refused set exercises.
- [`app_vs_deployment_doctrine.md` §3 — the deployment-rules surface](../documents/engineering/app_vs_deployment_doctrine.md#3-the-deployment-rules-surface--how-the-same-app-runs) — `DeploymentRules` as the binding site.
- [`manifest_generation_doctrine.md` §1 — types render manifests](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) — no string templating on the spine.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` and `SpineFact` this phase carries.
- [`testing_doctrine.md` §9 — derivation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) — the example corpus rule.

## Sprints

## Sprint 3.1: Vocabulary and ui-core split ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/vocabulary/Amoebius/Vocabulary.hs` and `src/ui-core/Amoebius/Ui/Source.hs`
**Blocked by**: [Phase 2](phase_02_repository_layout_conformance.md) gate pass
**Independent Validation**: One definition per axis — `Substrate`, `Architecture`, `Detected`, `Lane`, `ComputeEngine`, `EngineRuntime`, `CapabilityArm`, `ExtensionId`, `Quantity` — with a total `lanesOf` is the positive control; a second definition of any axis anywhere under `src/` is the paired negative refused by the hygiene row. `Detected Apple Amd64` is a compile-negative twin.
**Oracle**: `test/oracle/dsl/Main.hs` states the `(os, arch, gpu)` table from literals and compares it with `lanesOf` output written by the suite.
**Legacy IDs**: `LTD-DSL-004` — duplicated vocabularies, vocabulary share
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Give every closed axis exactly one definition in a base-only library, and move the UI value types out of the
product core so the spine can be typed without them.

### Deliverables

- `Amoebius.Vocabulary` with a private `Detected` constructor and `naturalArchitecture` refusing Apple on non-arm64 and Windows on non-amd64.
- `lanesOf` total over the catalog; `hostEnvironment` as a total function.
- `Quantity (u :: Unit)` for later use by the capacity fold.
- `Amoebius.Ui.*` re-homed under `library ui-core`.

### Validation

Write the `lanesOf` table from the suite and compare it with the oracle's literal table. Require the
compile-negative twin to fail at the constructor.

### Remaining Work

Implement the library and delete every duplicate definition.

## Sprint 3.2: The typed root specification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Dsl/Spec.hs`
**Blocked by**: Sprint 3.1
**Independent Validation**: `RootInForceSpec` with `ClusterSpec`, `TopologySpec = KindTopology HostSpec KindReplicas`, `AppSpec` with a non-empty need list and a typed `WorkloadSpec`, and `DeploymentRules` with its dials is the positive control; a two-server quorum, an app with an empty need list, and a deployment naming an unknown app are compile-negative or refused twins at their exact loci.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected record shapes as literal encodings.
**Legacy IDs**: `LTD-DSL-002` — no typed root specification
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Spell the typed records once in code, matching the one spelling in the DSL doctrine.

### Deliverables

- `RootInForceSpec`, `ClusterSpec`, `TopologySpec`, `HostSpec`, `AppSpec`, `WorkloadSpec`, and `DeploymentRules`.
- The `ExecutionUnit` GADT collapsed into `WorkloadSpec` with its five refusals re-homed as smart constructors.

### Validation

Encode each record through the smart constructors and compare with the oracle's literal encoding; require
each twin to fail at its named locus.

### Remaining Work

Implement the module and the compile-negative twins.

## Sprint 3.3: Import, decode, encode, and examples ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Dsl/Import.hs`, `src/Amoebius/Dsl/Decode.hs`, `src/Amoebius/Dsl/Encode.hs`, and `src/Amoebius/Dsl/Examples/Spine.hs`
**Blocked by**: Sprint 3.2
**Independent Validation**: Encode-then-decode returns the authored value for every corpus example, and the Dhall schema rendered from the decoder typechecks every rendered positive; the four `ForbiddenImport` twins are refused before resolution under an empty environment; an absolute or home path is refused by `freezeFile`.
**Oracle**: `test/oracle/dsl/Main.hs`; its rows for the three examples are authored from the intended Dhall text before the decoder exists.
**Legacy IDs**: `LTD-SRC-002` — tracked Dhall retired for rendered examples; `LTD-DOC-001` — behavioral Markdown consumers retired
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Make `decodeFrozen` the one front door, derive the schema from the decoder, and put the examples in code.

### Deliverables

- `freezeFile` and `freezeText` refusing absolute and home paths, non-code modes, and parse failures; a remote-refusing import status.
- `rootDecoder`, `decodeRoot`, and the schema rendered beneath `.build/dhall/**` from the decoder.
- `Amoebius.Dsl.Examples.Spine` with the three pairs and the refused set.

### Validation

Round-trip every example; typecheck every rendered positive; refuse every twin at its tag.

### Remaining Work

Implement the four modules; delete the substring import policy.

## Sprint 3.4: Lowering into the bind input ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Dsl/Lower.hs`
**Blocked by**: Sprint 3.3
**Independent Validation**: `lowerDeployment` produces the `Topology`, `BoundDeployment`, and target supply for each corpus example equal to the oracle rows; `UnboundNeed`, `DanglingBinding`, and `UnknownDeployment` are refused at the lowering stage; no `BoundDeployment` can be constructed outside this module, checked by a compile-negative twin.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected bound identities per deployment from literals.
**Legacy IDs**: `LTD-DSL-001` — the decode-to-bind edge
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Build the missing edge: a typed lowering from the decoded root into the bind input.

### Deliverables

- `lowerTopology` and `lowerDeployment` with typed refusals.
- `assembleBoundDeployment` moved behind a link boundary so lowering is the single constructor path.

### Validation

Lower every example and compare with the oracle; refuse every twin at the lowering stage.

### Remaining Work

Implement the module and the link boundary.

## Sprint 3.5: Steps as data and the product subcommands ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Kernel/Step.hs`, `src/Amoebius/Kernel/Interpret.hs`, and `app/amoebius/Main.hs`
**Blocked by**: Sprint 3.4
**Independent Validation**: `Step` is closed data with no function slot, `Amoebius.Kernel.Interpret` is its only executor, and a dry run executes zero steps; `amoebius compile`, `amoebius apply --executor fake`, `amoebius render-examples`, `amoebius toolchain-report`, and `amoebius layout-report` exist as subcommands of the shipped binary; a `Step` carrying `IO` is a compile-negative twin.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected step sequence per example from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Close the step algebra and expose the product commands the runner drives.

### Deliverables

- `StepKind` with `ApplyObjects`, `DockerBuild`, `DockerPush`, `PulumiUp`, and `HostProcess` arms.
- The interpreter as the only executor; the five subcommands.

### Validation

Chain every example and compare the step sequence with the oracle; require the dry run to execute nothing.

### Remaining Work

Implement the modules; remove the function slot from anything sanctioned.

## Sprint 3.6: The pipeline and the control-plane endpoint ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Dsl/Pipeline.hs` and `app/amoebius/Amoebius/Entry/ControlPlane.hs`
**Blocked by**: Sprint 3.5
**Independent Validation**: `compileDeployment` composes lower, plan, provision, render, and chain for each example equal to the oracle; the control-plane endpoint calls it and returns the rendered digest; a mutant that discards the decoded value at the endpoint is killed by the oracle's digest comparison.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected endpoint digest per example from literals.
**Legacy IDs**: `LTD-DSL-009` — the endpoint discards the decoded spec; `LTD-SRC-003` — tracked wire schema retired
**Docs to update**: `documents/engineering/daemon_topology_doctrine.md`

### Objective

Make the shipped binary's only consumer of the decoder consume its result.

### Deliverables

- `Amoebius.Dsl.Pipeline.compileDeployment`.
- The endpoint wired to the pipeline; the constant demand record deleted.

### Validation

Compile every example through the endpoint and compare the digest with the oracle; kill the discard mutant.

### Remaining Work

Implement the pipeline and rewire the endpoint. The untracked runtime helper on the deploy path stays visible
as `LTD-HELPER-001` until Phase 50.

## Sprint 3.7: The Phase-3 gate specification and front-half deletions ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Spine.hs` and `amoebius.cabal`
**Blocked by**: Sprint 3.6
**Independent Validation**: The compiled specification equals the fenced block above; `verifySpec` accepts it; the old front half — the structural node tree, the toy decoder, the hand-written schema strings, the covering fixture library, the barrier report checker — is absent from the package description; re-adding any one is refused at the closure or hygiene locus.
**Oracle**: `test/oracle/runner/Main.hs` states the expected specification digest and closure from literals.
**Legacy IDs**: `LTD-VAL-005` — the barrier's hand-built bind, closed here for the spine and re-run at Phase 9
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Author the specification the runner executes and delete what it replaces.

### Deliverables

- The Phase-3 `GateSpec` with its `BinaryFact` and `SpineFact`.
- Deletion of the DSL front half and the barrier libraries.

### Validation

Run `preview phase 03` and require every row green; require `accept` to record exactly one
phase's patch.

### Remaining Work

Everything above. The `accept` ends this phase.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes, never before):**

- `documents/engineering/dsl_doctrine.md` — only if the typed spec records or the foreclosure layers change.
- `documents/engineering/substrate_doctrine.md` — only if the vocabulary's closed axes change.
- `documents/engineering/daemon_topology_doctrine.md` — only if the control-plane endpoint's contract changes.

**Cross-references to add:**

- Phase 2 predecessor gate pass and Phase 4 consumer links.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 2 repository layout conformance](phase_02_repository_layout_conformance.md) — the predecessor
- [Phase 4 witness-driven manifests](phase_04_witness_manifests_capacity_storage.md) — the next slice over the same corpus
- [Phase 9 DSL barrier](phase_09_dsl_barrier.md) — re-runs this corpus through the shipped binary
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [DSL doctrine](../documents/engineering/dsl_doctrine.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
- [Testing doctrine](../documents/engineering/testing_doctrine.md)
- [Behavioural verification doctrine](../documents/engineering/behavioural_verification_doctrine.md) — oracle rows judge bytes, never labels
