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

✅ Done.
**Receipt**: 10af51a4dfc8c3fbfaa4a3af684b21d5a26fd8df47d8e7f1e7d900fef917e67b

The complete qualified gate for the exact source passed and `accept` recorded the receipt above; the
observations are the immutable bundle beneath `validation-records/`. The change that registered this gate also
changed the verifier (the staged perturbation, the own-family kill attribution, the per-stage observation, and the
product-wide vocabulary check), and [DL-0023](../documents/decision_log.md#dl-0023--phase-3-accepted-its-owed-by-paragraphs-become-observed-implementations)
re-mooded the paragraphs that had named this phase as owing; that is a verifier change, so `replay` must
re-derive the receipts of Phases 0 through 3 under the resulting generation before the next `accept`. The gate's
`Residue` row lists what the receipt does not
establish. Any later edit to a `.hs` file beneath `src/` reopens this receipt and its predecessors under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) until the next replay; an edit beneath
`test/` changes the Phase-2 oracle's whole-tree counts, so an uncommitted predecessor bundle stops re-deriving.

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
`amoebius render-examples`. Nothing it renders is tracked. It carries three distinguishing pairs, a twin, and
one refused set:

| Example | Distinguishes | Expected delta or refusal |
|---|---|---|
| `kind-single-objectstore` | the baseline | eleven objects: the application's namespace, Deployment, and Service, each named after the authored application; four global objects; four for the object-store provider, one of them the claim its StatefulSet member owns. Identities equal the authored names |
| shape-swap sibling | the capability binding's shape | provider objects four to ten, seventeen in all; application and global bytes identical |
| replicas-3 sibling | the authored replica count | `spec.contents[1].podReplicas` of the application Deployment changes and nothing else |
| local-import twin | a local import of one name | freezes to the baseline hash and renders the baseline bytes |
| refused set | one illegal dimension each | twenty refused examples, each at its exact tag and stage: `freeze` (`ForbiddenImport` for an environment import, a remote import, a fallback wrapping a remote import, and a transitive local environment import; `AbsolutePath`, `HomePath`, `NonCodeMode`, `ParseFailure`, `IllTyped`), `decode` (`RequestsAboveLimits`, `EmptyNeeds`, `ZeroReplicas`, `HeadroomAllZero`, and `DhallFailure` for a product named in the application and for a shape authored in the application), `lower` (`UnboundNeed`, `DanglingBinding`, `UnknownDeployment`), `plan` (`InfrastructureDemandExceeded`), and `provision` (`PostBindExpansionOvercommit`) |

New tags: `kind`, `objectstore`, `single-node`. The oracle's literals are typed from this contract and the
doctrine, never read from product output; the suite's differential refuses an authored field that reaches no
byte and is not refused. The authored replica count reaches the wire as `spec.contents[1].podReplicas` of the
application Deployment; the real Kubernetes spec projection belongs to the phase that applies objects to a
cluster ([Phase 4](phase_04_witness_manifests_capacity_storage.md) for witness-driven fields).

### Gate specification

```gate-spec
capability: typed_spine
role: ordinary
claim: From one operator-authored Dhall specification the shipped render-examples, compile, and apply commands freeze, decode, lower, plan, provision, render, chain, dry-run, and apply it through a separate fake kubectl process image. The runner rewrites the rendered example after the run starts, planting a nonce in the authored names and changing the replica count, and recovers the nonce from every stage artefact. The independent oracle judges every stage artefact of the corpus examples and of that run from literals, the fake's per-step stdin bytes concatenate to the compile output, and every refusal is observed at its exact tag and stage. Witness-driven rendering, capacity over application workloads beyond fit, substrates other than kind on one host, extensions, children, and the UI language are excluded.
subjects: Amoebius.Vocabulary, Amoebius.Dsl.Spec, Amoebius.Dsl.Import, Amoebius.Dsl.Decode, Amoebius.Dsl.Lower, Amoebius.Kernel.Step, Amoebius.Kernel.Interpret, Amoebius.Dsl.Pipeline
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
mutants: stages=Amoebius.Vocabulary,Amoebius.Dsl.Spec,Amoebius.Dsl.Import,Amoebius.Dsl.Decode,Amoebius.Dsl.Lower,Amoebius.Kernel.Step,Amoebius.Kernel.Interpret,Amoebius.Dsl.Pipeline per-module=8 cap=40 kill-ratio=3/5 artefacts=Amoebius.Vocabulary:vocab.,Amoebius.Dsl.Spec:spec.,Amoebius.Dsl.Import:freeze.,Amoebius.Dsl.Decode:decode.,Amoebius.Dsl.Lower:lower.,Amoebius.Kernel.Step:chain.,Amoebius.Kernel.Interpret:dry-run.,Amoebius.Kernel.Interpret:fake-apply.,Amoebius.Dsl.Pipeline:plan.,Amoebius.Dsl.Pipeline:provision.,Amoebius.Dsl.Pipeline:render.,Amoebius.Dsl.Pipeline:pipeline.,Amoebius.Dsl.Pipeline:endpoint.
binary-fact: command=compile --input {input} --out {run}/compiled | input=root.dhall | perturbation=staged(pre=render-examples --example kind-single-objectstore --output {input} post=apply --executor fake --input {input} --out {run}/applied then=sentinel-to-nonce(0b5e17e11a0c0ffee0de1e9a7e5ba5ed),replica-count(1->3)) | outputs={run}/compiled/frozen.dhall,{run}/compiled/decoded.dump,{run}/compiled/lowered.dump,{run}/compiled/plan.dump,{run}/compiled/provisioned.dump,{run}/compiled/manifest.json,{run}/compiled/chain.dump,{run}/compiled/dry-run.dump,{run}/applied/fake/stdin.combined
spine-fact: rendered=compiled/manifest.json | stages=freeze,decode,lower,plan,provision,render,chain,dry-run,fake-apply | applied-digest=applied/fake/applied.sha256
substrate: none
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | A `RootInForceSpec` rendered from the corpus, rewritten by the runner with a nonce and a changed replica count, passes through `amoebius compile` and `amoebius apply --executor fake`; the fake `kubectl` process image receives one call per step, its stdin bytes concatenate to the compile output byte for byte and, parsed by the independent oracle executable, carry the authored identities, the application's namespace, and the nonce. The stage modules' generated mutants are judged by each stage's own oracle rows. Witness-driven fields, substrates, extensions, children, and UI are excluded. |
| `Subject` | The eight stage modules named in the gate specification; the `render-examples`, `compile`, and `apply` subcommands dispatched by `app/amoebius/Main.hs` and implemented by `Amoebius.Dsl.Commands`; and the control-plane endpoint in `app/amoebius/Amoebius/Entry/ControlPlane.hs`, whose decision is `Amoebius.Dsl.Pipeline.endpointOutcome`. Every subject is inside the closure of `executable amoebius`. |
| `Command` | Future public spelling is `pb validate phase 03`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 03`; then `amoebius-validate accept --phase 03` records the receipt and applies one phase's status patch. The runner spawns the shipped `amoebius` binary as a child three times for its challenge: `render-examples --example kind-single-objectstore --output <input>`, then `compile --input <input> --out <run>/compiled` on the perturbed input, then `apply --executor fake --input <input> --out <run>/applied`; it then runs the suite and the oracle with those outputs beneath the suite directory. |
| `Oracle` | `test/oracle/dsl/Main.hs`, with its modules beside it, reads the suite's tables and stage artefacts and the runner's own outputs and prints the ledger from literals typed in `test/oracle/dsl/DslTables.hs`. It parses the manifest arrays with its own code, recomputes every digest with its own hash, re-normalises each frozen artefact and typechecks each rendered positive against its own literal schema with the `dhall` library, and writes and compiles its own compile-negative twins; it depends on no `amoebius` library. |
| `Positive controls` | The baseline, the shape-swap sibling, the replicas-3 sibling, and the local-import twin render, chain, dry-run, and apply; the host grid's lane table is total; every corpus example round-trips and its rendered positives typecheck against the contract's schema; the step sequence is frame-major then identity; a dry run executes nothing; the fake receives each step's bytes; the endpoint's digest equals the digest of the manifest; every authored leaf reaches a byte or a refusal; the rendered inventory equals the contract's; and the runner's perturbed run judges the nonce and the changed replica count in every artefact. |
| `Paired negatives` | Twenty-six, each differing from the baseline in one dimension and each refused at its exact tag and stage with the positive twin accepted: an Apple host on amd64 and a Windows host on arm64 (`NotNaturalArchitecture`); the nine freeze refusals; the six decode refusals; `UnboundNeed`, `DanglingBinding`, and `UnknownDeployment`; `InfrastructureDemandExceeded` and `PostBindExpansionOvercommit`; and four compile-negative twins the oracle writes and compiles itself (`Detected Apple Amd64`, a `BoundDeployment` built outside lowering, a `Step` carrying `IO`, and a two-server quorum). |
| `Mutants` | Runner-generated from the fixed operator catalogue over the eight stage modules, eight per module, at most forty per gate, kill ratio at least 0.6, stillborn excluded, each recorded with its operator, production locus, and applied-change witness. A kill requires a red oracle row whose name begins with a prefix the mutated module owns (the `artefacts` of the gate specification): a crash, an empty ledger, or a red row owned by another module leaves the mutant a survivor, and every stage module must be killed at least once. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the corpus example count equals the rendered file count; empty discovery refuses. |
| `Challenge` | After the run starts, the runner renders the example, rewrites its sentinel to the run's nonce and its replica count from one to three, and runs `compile` and `apply` on the result. The oracle discovers the nonce in the decoded dump, finds the sentinel absent from every output, and judges every artefact from literals that substitute the nonce and the changed count; the nonce must also appear in the manifest and in the fake's stdin, and every declared stage family must have a green oracle row. |
| `Observer` | `ProcessObserver` records argv, environment policy, exit, and complete output of every build and run of the suite and the oracle and of the three product commands. The fake `kubectl` is a grandchild of the apply command and the same program image invoked under another name, so the runner does not spawn it: it is observed through the transcript it writes (argv, environment keys, and stdin of each call), which the oracle judges, and through the digest cross-check of the applied bytes. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` refuses a subject outside the executable's closure; the oracle stanza's hygiene refuses a product dependency; no `BoundDeployment` may be constructed outside `Amoebius.Dsl.Lower`: the public `Amoebius.Capability.Types` exports the type without its constructor, the constructor's module is hidden from every other component, and the oracle's compile-negative twins and source scan check the boundary. |
| `Freshness` | A unique run root; a fresh render every run; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The generated-mutant matrix over the eight stage modules precedes the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-03/**` and is absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-DSL-001`, `LTD-DSL-002`, `LTD-DSL-009`, `LTD-SRC-002`, `LTD-VAL-005`, and the consumer-deletion half of `LTD-DOC-001` close for the spine here; `LTD-SRC-003` closes its tracked-schema half (the declared messages render a schema that is judged and no Proto is tracked) and `LTD-DSL-004` its vocabulary share, the hygiene row refusing a second definition of any vocabulary type anywhere beneath `src/`, with its unit share in Phase 4. The scope of each is bounded in `Residue`. |
| `Predecessor` | The Phase-2 receipt in certification generation 2, chained by the digest of Phase 2's product closure plus the verifier and governance digests. |
| `Residue` | Phases 4 through 9 and every phase from 50 onward remain explicit limitations; `LTD-HELPER-001` remains visible residue until Phase 50. The illegal-state catalogue entries that name this phase as delivery owner are covered only as far as the paired refusals, the smart-constructor boundaries, and the compile-negative twins reach; the covering relation itself, and the entries whose feature does not exist yet, remain owed to the phases that introduce the feature. `LTD-SRC-003`'s bindings half is open: no bindings are generated and the maintained client's use of them is not exercised, because the client cannot be built without its generated transport. The endpoint's HTTP wiring is judged by a source scan and by the rows of `endpointOutcome`, not by a generated mutant, because the runner mutates library modules only; Phase 9 re-verifies it with the endpoint as a subject. The fake is the product's own program image, so a fault the stages share with the fake is outside what the gate observes. The application's capacity check is the legacy fit check over one node's steady demand and execution epochs; cluster and host fields reach the lowered and plan artefacts and the refusal boundaries, not the wire, until a later phase renders placement. The sprint's `ui-core` split is owned by Phase 8. The other eight capability arms, the remaining planner arms, the activation stages, and runtime accounting stay component suites that this gate does not record. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and `accept` records it. |

## Doctrine adopted

- [`dsl_doctrine.md` §4 — total composability](../documents/engineering/dsl_doctrine.md#4-total-composability) — the typed spec records this phase realises.
- [`dsl_doctrine.md` §5 — the illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) — the three foreclosure layers the refused set exercises.
- [`app_vs_deployment_doctrine.md` §3 — the deployment-rules surface](../documents/engineering/app_vs_deployment_doctrine.md#3-the-deployment-rules-surface--how-the-same-app-runs) — `DeploymentRules` as the binding site.
- [`manifest_generation_doctrine.md` §1 — types render manifests](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) — no string templating on the spine.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` and `SpineFact` this phase carries.
- [`testing_doctrine.md` §9 — derivation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) — the example corpus rule.

## Sprints

## Sprint 3.1: Vocabulary and ui-core split ✅

**Status**: Done
**Implementation**: `src/vocabulary/Amoebius/Vocabulary.hs`
**Blocked by**: [Phase 2](phase_02_repository_layout_conformance.md) gate pass
**Forward-deferred**: the `ui-core` split of the `Amoebius.Ui.*` value types — [Phase 8](phase_08_ui_program_language_binding.md) `ui_program_language_binding`
**Independent Validation**: One definition per axis — `Substrate`, `Architecture`, `Detected`, `Lane`, `ComputeEngine`, `EngineRuntime`, `CapabilityArm`, `ExtensionId`, `Quantity` — with a total `lanesOf` is the positive control; a second definition of any axis anywhere under `src/` is the paired negative refused by the hygiene row. `Detected Apple Amd64` is a compile-negative twin.
**Oracle**: `test/oracle/dsl/Main.hs` states the `(os, arch, gpu)` table from literals and compares it with the classification and `lanesOf` output the suite writes.
**Legacy IDs**: `LTD-DSL-004` — duplicated vocabularies, vocabulary share
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Give every closed axis exactly one definition in a small library that depends on no product code, so the spine can be
typed without the product core.

### Deliverables

- `Amoebius.Vocabulary` with a private `Detected` constructor, `mkDetected` refusing Apple on non-arm64 and Windows on non-amd64, and `isLabel`. The library depends on `base`, `deepseq`, and `text`, so the moved types keep their `NFData` instances and their `Text` payloads.
- `lanesOf` total over the catalogue; `hostEnvironment` as the total `(os, arch, gpu)` classification.
- `Quantity (u :: Unit)` for later use by the capacity fold.
- Every duplicate definition deleted: the substrate and compute-engine types of the topology library, the capability-arm and engine-runtime types of the bind library (whose `LinuxCpu` runtime arm is now `CpuRuntime`), the host classification's substrate, the Pulsar topology's lane, and the JIT resolver's engine runtime (now `JitEngine`).

### Validation

Write the classification and `lanesOf` table from the suite and compare it with the oracle's literal table; require the
compile-negative twin to fail at the constructor; require the hygiene row to refuse a second definition anywhere beneath `src/`.

### Remaining Work

The library and the consolidation are implemented; the gate is the remaining work. Re-homing the UI value types under a
`ui-core` library is owned by Phase 8, which is the first phase that needs them apart from the product core.

## Sprint 3.2: The typed root specification ✅

**Status**: Done
**Implementation**: `src/dsl-spine/Amoebius/Dsl/Spec.hs`
**Blocked by**: Sprint 3.1
**Independent Validation**: `RootInForceSpec` with `ClusterSpec`, `TopologySpec = KindTopology HostSpec KindReplicas`, `AppSpec` with a non-empty need list and a typed `WorkloadSpec`, and `DeploymentRules` with its dials is the positive control; a two-server quorum, an app with an empty need list, and a deployment naming an unknown app are compile-negative or refused twins at their exact loci.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected record shapes as literal encodings.
**Legacy IDs**: `LTD-DSL-002` — no typed root specification
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Spell the typed records once in code, matching the one spelling in the DSL doctrine.

### Deliverables

- `RootInForceSpec`, `ClusterSpec`, `TopologySpec`, `HostSpec`, `AppSpec`, `WorkloadSpec`, and `DeploymentRules`, each exported with its selectors and without its constructor, so a record exists only through its smart constructor.
- The `ExecutionUnit` GADT collapsed into `WorkloadSpec`: the application is always the runtime Deployment, so its refusals are re-homed as `ZeroReplicas`, `RequestsAboveLimits`, `HeadroomAllZero`, `DistributedShape`, and `KindReplicasZero`, and the controller arms the provider owns are unspellable here.

### Validation

Encode each record through the smart constructors and compare with the oracle's literal encoding; require
each twin to fail at its named locus.

### Remaining Work

The module is implemented; the compile-negative twin for a two-server quorum is the oracle's own, written and compiled at run time.
The gate is the remaining work.

## Sprint 3.3: Import, decode, encode, and examples ✅

**Status**: Done
**Implementation**: `src/dsl-spine/Amoebius/Dsl/Import.hs`, `src/dsl-spine/Amoebius/Dsl/Decode.hs`, `src/dsl-spine/Amoebius/Dsl/Encode.hs`, and `src/dsl-spine/Amoebius/Dsl/Examples/Spine.hs`
**Blocked by**: Sprint 3.2
**Independent Validation**: Encode-then-decode returns the authored value for every corpus example, and the Dhall schema rendered from the decoder typechecks every rendered positive; the four `ForbiddenImport` twins are refused before resolution under an empty environment; an import written with an absolute or home path is refused by the freeze, and a document that does not typecheck is refused by name.
**Oracle**: `test/oracle/dsl/Main.hs`; its rows for the three examples are authored from the intended Dhall text before the decoder exists.
**Legacy IDs**: `LTD-SRC-002` — tracked Dhall retired for rendered examples; `LTD-DOC-001` — behavioral Markdown consumers retired
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Make `decodeFrozen` the one front door, derive the schema from the decoder, and put the examples in code.

### Deliverables

- `freezeFile` and `freezeText` refusing environment, remote, absolute, and home imports, non-code modes, parse failures, and ill-typed documents, every import judged (both sides of a fallback, transitively through local files) before any is resolved.
- `decodeRoot` and `decodeFrozen`, and the schema, which is the decoder's own expected type, written by `render-examples` beneath the directory it is given (`.build/dhall/**` by default) and never tracked.
- `Amoebius.Dsl.Examples.Spine` with the three pairs, the twin, and the refused set.

### Validation

Round-trip every example; typecheck every rendered positive; refuse every twin at its tag.

### Remaining Work

The four modules are implemented and the substring import policy, the toy decoder, and the hand-written schema strings
are deleted. The gate is the remaining work.

## Sprint 3.4: Lowering into the bind input ✅

**Status**: Done
**Implementation**: `src/dsl-spine/Amoebius/Dsl/Lower.hs`
**Blocked by**: Sprint 3.3
**Independent Validation**: `lowerDeployment` produces the `Topology`, `BoundDeployment`, and target supply for each corpus example equal to the oracle rows; `UnboundNeed`, `DanglingBinding`, and `UnknownDeployment` are refused at the lowering stage; no `BoundDeployment` can be constructed outside this module, checked by a compile-negative twin.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected bound identities per deployment from literals.
**Legacy IDs**: `LTD-DSL-001` — the decode-to-bind edge
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Build the missing edge: a typed lowering from the decoded root into the bind input.

### Deliverables

- `lowerTopology` and `lowerDeployment` with typed refusals.
- `assembleBoundDeployment` moved behind a link boundary so lowering is the single constructor path: the public `Amoebius.Capability.Types` exports `BoundDeployment` with its selectors and without its constructor, the constructor lives in a hidden module, and `Amoebius.Capability.Assemble` is imported by `Amoebius.Dsl.Lower` alone.

### Validation

Lower every example and compare with the oracle; refuse every twin at the lowering stage.

### Remaining Work

The module and the link boundary are implemented. The gate is the remaining work.

## Sprint 3.5: Steps as data and the product subcommands ✅

**Status**: Done
**Implementation**: `src/kernel-steps/Amoebius/Kernel/Step.hs`, `src/kernel-steps/Amoebius/Kernel/Interpret.hs`, `src/dsl-spine/Amoebius/Dsl/Commands.hs`, and `app/amoebius/Main.hs`
**Blocked by**: Sprint 3.4
**Independent Validation**: `Step` is closed data with no function slot, `Amoebius.Kernel.Interpret` is its only executor, and a dry run executes zero steps; `amoebius compile`, `amoebius apply --executor fake`, `amoebius render-examples`, `amoebius toolchain-report`, and `amoebius layout-report` exist as subcommands of the shipped binary; a `Step` carrying `IO` is a compile-negative twin.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected step sequence per example from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Close the step algebra and expose the product commands the runner drives.

### Deliverables

- `StepKind` with `ApplyObjects`, `DockerBuild`, `DockerPush`, `PulumiUp`, and `HostProcess` arms.
- The interpreter as the only executor, with one admitted executor: the fake, which is the running program invoked under the name `kubectl`; the five subcommands.

### Validation

Chain every example and compare the step sequence with the oracle; require the dry run to execute nothing.

### Remaining Work

The modules and subcommands are implemented and the legacy step carrying a function slot is deleted. The gate is the remaining work.

## Sprint 3.6: The pipeline and the control-plane endpoint ✅

**Status**: Done
**Implementation**: `src/dsl-spine/Amoebius/Dsl/Pipeline.hs` and `app/amoebius/Amoebius/Entry/ControlPlane.hs`
**Blocked by**: Sprint 3.5
**Forward-deferred**: the endpoint as a generated-mutant subject — [Phase 9](phase_09_dsl_barrier.md) `dsl_barrier`
**Independent Validation**: `compileDeployment` composes decode, lower, plan, provision, render, and chain for each example equal to the oracle; the control-plane endpoint's decision, `endpointOutcome`, calls it and returns the rendered digest, which the oracle recomputes from the manifest; a mutant in the pipeline that discards the decoded value is killed by the oracle's stage rows and its digest comparison.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected endpoint digest per example from literals.
**Legacy IDs**: `LTD-DSL-009` — the endpoint discards the decoded spec; `LTD-SRC-003` — tracked wire schema retired
**Docs to update**: `documents/engineering/daemon_topology_doctrine.md`

### Objective

Make the shipped binary's only consumer of the decoder consume its result.

### Deliverables

- `Amoebius.Dsl.Pipeline.compileDeployment`, `compileText`, `compileToDirectory`, `applyToDirectory`, and `endpointOutcome`.
- The endpoint wired to the pipeline through `endpointOutcome`; the constant demand record and the desired-object list deleted.

### Validation

Compile every example through `endpointOutcome` and compare the digest with the oracle's; the endpoint module's wiring is checked by a source scan.

### Remaining Work

The pipeline is implemented and the endpoint rewired. The runner mutates library modules only, so the endpoint
module itself is not a generated-mutant subject here; its decision logic is the subject `Amoebius.Dsl.Pipeline`, and Phase 9
re-verifies the endpoint as a subject. The untracked runtime helper on the deploy path stays visible as `LTD-HELPER-001` until Phase 50.

## Sprint 3.7: The Phase-3 gate specification and front-half deletions ✅

**Status**: Done
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs` and `amoebius.cabal`
**Blocked by**: Sprint 3.6
**Independent Validation**: The compiled specification equals the fenced block above; `verifySpec` accepts it; the old front half — the structural node tree, the toy decoder, the hand-written schema strings, the covering fixture library, the barrier report checker — is absent from the package description, and the oracle's source scan is red if any returns; the vocabulary duplicates it carried are refused by the hygiene row.
**Oracle**: `test/oracle/runner/Main.hs` states the staged perturbation's rendering, the kill-attribution cases, and the vocabulary list from literals.
**Legacy IDs**: `LTD-VAL-005` — the barrier's hand-built bind, closed here for the spine and re-run at Phase 9
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Author the specification the runner executes and delete what it replaces.

### Deliverables

- The Phase-3 `GateSpec` with its staged `BinaryFact` and its `SpineFact`, registered in place in `Registry.hs`, which is the one place the registry lives.
- The verifier changes the contract needs: the staged perturbation, the own-family kill attribution, the per-stage observation, the binary run before the clean run inside the suite directory, the product-wide vocabulary check, and the rename of the validator's own substrate type.
- Deletion of the DSL front half and the barrier libraries.

### Validation

Run `preview phase 03` and require every row green; require `accept` to record exactly one
phase's patch.

### Remaining Work

The specification is registered and the front half is deleted. The complete gate is the remaining work; the `accept` ends this phase.

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
