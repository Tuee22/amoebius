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

🔄 Active — NOT VALIDATED.

The verifier revoked the selected receipt and reopened the documentation gate after finding the missing
inherited legacy analyzer/evidence join. Historical spine runs remain immutable observations beneath
`validation-records/`; they do not establish a current complete gate pass. This phase requires fresh
numerical qualification after the earlier boundary is repaired.

The binary oracle selects the active constructor from independently parsed, typechecked, import-free
Dhall. It therefore distinguishes Kind from rke2 even when the shared union schema names both arms;
missing or unsupported input emits a named refusal. The complete gate includes the runner's nonce-bearing
compile/apply challenge and exact fake-process observations. Cross-generation receipt revocation and the
kernel ratchet have component regression coverage and require current predecessor qualification. Later edits within the closure require fresh
replay under [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase). The gate's explicit
residue keeps the remaining DSL and live-system claims outside this scope.

**Preview checkpoint on 2026-11-11.** Phase 2 was accepted (receipt
`3a41a20c39f33dd7f1421f41ccf83c3c98617887c59543a3d1f11be2c51d887d`) after a complete ordered Phase-0/1
replay, a complete preview and a separate acceptance. The first Phase-3 preview then refused before running
its gate, with exit 1 and no receipt: `PredecessorNotCommitted` (the predecessor ancestry, publication
binding or complete re-derivation was unavailable; the Phase-2 bundle and status postimage are not yet
committed) and `LEGACY-ANALYZER-UNAVAILABLE` for `LTD-SRC-002`, `LTD-SRC-003`, `LTD-VAL-005`,
`LTD-DOC-001`, `LTD-DSL-001`, `LTD-DSL-002` and `LTD-DSL-009`. The runner's
`legacyQualificationSupported` had no qualification for those seven bindings at that checkpoint. It now
supports six of them; `LTD-SRC-003` remains unavailable pending the source-bound binding qualification below.
No Phase-3 product stage has been judged by a gate.

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
subjects: Amoebius.Vocabulary, Amoebius.Dsl.Spec, Amoebius.Dsl.Import, Amoebius.Dsl.Decode, Amoebius.Dsl.Lower, Amoebius.Kernel.Step, Amoebius.Kernel.Interpret, Amoebius.Dsl.Pipeline, Amoebius.Pulsar.Wire, Amoebius.Pulsar.Wire.Descriptor, Amoebius.Pulsar.Wire.Generate, Amoebius.Pulsar.Wire.Plugin, Amoebius.Internal.Process.FileInput, Amoebius.Pulsar.Internal.Protocol, Pulsar.Protocol.Commands, Amoebius.Pulsar.Compat.RoundTrip, Amoebius.Toolchain.SourceOwnership
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
mutants: stages=Amoebius.Vocabulary,Amoebius.Dsl.Spec,Amoebius.Dsl.Import,Amoebius.Dsl.Decode,Amoebius.Dsl.Lower,Amoebius.Kernel.Step,Amoebius.Kernel.Interpret,Amoebius.Dsl.Pipeline,Amoebius.Pulsar.Wire,Amoebius.Pulsar.Wire.Descriptor,Amoebius.Pulsar.Wire.Generate,Amoebius.Pulsar.Wire.Plugin,Amoebius.Internal.Process.FileInput,Amoebius.Pulsar.Internal.Protocol,Pulsar.Protocol.Commands,Amoebius.Pulsar.Compat.RoundTrip,Amoebius.Toolchain.SourceOwnership per-module=8 cap=40 kill-ratio=3/5 artefacts=Amoebius.Vocabulary:vocab.,Amoebius.Vocabulary:lanes.,Amoebius.Vocabulary:case:lanes-of,Amoebius.Dsl.Spec:spec.,Amoebius.Dsl.Import:freeze.,Amoebius.Dsl.Decode:decode.,Amoebius.Dsl.Lower:lower.,Amoebius.Kernel.Step:chain.,Amoebius.Kernel.Interpret:dry-run.,Amoebius.Kernel.Interpret:fake-apply.,Amoebius.Pulsar.Wire:wire.,Amoebius.Pulsar.Wire.Descriptor:wire.,Amoebius.Pulsar.Wire.Generate:wire-schema.,Amoebius.Pulsar.Wire.Plugin:wire-schema.,Amoebius.Internal.Process.FileInput:wire-schema.,Amoebius.Pulsar.Internal.Protocol:wire-native.,Pulsar.Protocol.Commands:wire-fork.,Amoebius.Pulsar.Compat.RoundTrip:wire-roundtrip.,Amoebius.Toolchain.SourceOwnership:wire-schema.,Amoebius.Dsl.Pipeline:plan.,Amoebius.Dsl.Pipeline:provision.,Amoebius.Dsl.Pipeline:render.,Amoebius.Dsl.Pipeline:pipeline.,Amoebius.Dsl.Pipeline:endpoint.
binary-fact: command=compile --input {input} --out {run}/compiled | input=root.dhall | perturbation=staged(pre=render-examples --example kind-single-objectstore --output {input} post=apply --executor fake --input {input} --out {run}/applied;dev observe-pulsar-wire native --output {run}/wire/native.tsv;dev observe-pulsar-wire fork --output {run}/wire/fork.tsv;dev observe-pulsar-wire roundtrip --output {run}/wire/roundtrip.tsv then=sentinel-to-nonce(0b5e17e11a0c0ffee0de1e9a7e5ba5ed),replica-count(1->3)) | outputs={run}/compiled/frozen.dhall,{run}/compiled/decoded.dump,{run}/compiled/lowered.dump,{run}/compiled/plan.dump,{run}/compiled/provisioned.dump,{run}/compiled/manifest.json,{run}/compiled/chain.dump,{run}/compiled/dry-run.dump,{run}/applied/fake/stdin.combined
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
| `Mutants` | Runner-generated from the fixed operator catalogue over the named stage modules, eight per module, at most forty per gate, kill ratio at least 0.6, stillborn excluded, each recorded with its operator, production locus, and applied-change witness. A kill requires a red oracle row whose name begins with a prefix the mutated module owns (the `artefacts` of the gate specification): a crash, an empty ledger, or a red row owned by another module leaves the mutant a survivor, and every stage module must be killed at least once. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the corpus example count equals the rendered file count; empty discovery refuses. |
| `Challenge` | After the run starts, the runner renders the example, rewrites its sentinel to the run's nonce and its replica count from one to three, and runs `compile` and `apply` on the result. The oracle discovers the nonce in the decoded dump, finds the sentinel absent from every output, and judges every artefact from literals that substitute the nonce and the changed count; the nonce must also appear in the manifest and in the fake's stdin, and every declared stage family must have a green oracle row. |
| `Observer` | `ProcessObserver` records argv, environment policy, exit, and complete output of every build and run of the suite and the oracle and of the three product commands. The fake `kubectl` is a grandchild of the apply command and the same program image invoked under another name, so the runner does not spawn it: it is observed through the transcript it writes (argv, environment keys, and stdin of each call), which the oracle judges, and through the digest cross-check of the applied bytes. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` refuses a subject outside the executable's closure; the oracle stanza's hygiene refuses a product dependency; no `BoundDeployment` may be constructed outside `Amoebius.Dsl.Lower`: the public `Amoebius.Capability.Types` exports the type without its constructor, the constructor's module is hidden from every other component, and the oracle's compile-negative twins and source scan check the boundary. |
| `Freshness` | A unique run root; a fresh render every run; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The generated-mutant matrix over the named stage modules precedes the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-03/**` and is absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-DSL-001`, `LTD-DSL-002`, `LTD-DSL-009`, `LTD-SRC-002`, `LTD-VAL-005`, and the consumer-deletion half of `LTD-DOC-001` close for the spine here; `LTD-SRC-003` closes its tracked-schema half (the declared messages render a schema that is judged and no Proto is tracked) and `LTD-DSL-004` its vocabulary share, the hygiene row refusing a second definition of any vocabulary type anywhere beneath `src/`, with its unit share in Phase 4. The scope of each is bounded in `Residue`. |
| `Predecessor` | The Phase-2 receipt in certification generation 2, chained by the digest of Phase 2's product closure plus the verifier and governance digests. |
| `Residue` | Phases 4 through 9 and every phase from 50 onward remain explicit limitations; `LTD-HELPER-001` remains visible residue until Phase 50. The illegal-state catalogue entries that name this phase as delivery owner are covered only as far as the paired refusals, the smart-constructor boundaries, and the compile-negative twins reach; the covering relation itself, and the entries whose feature does not exist yet, remain owed to the phases that introduce the feature. `LTD-SRC-003`'s bindings half is open: both clients consume freshly generated bindings in component builds, but the verifier's preparation chain and their use in the gate are not yet qualified. The endpoint's HTTP wiring is judged by a source scan and by the rows of `endpointOutcome`, not by a generated mutant, because the runner mutates library modules only; Phase 9 re-verifies it with the endpoint as a subject. The fake is the product's own program image, so a fault the stages share with the fake is outside what the gate observes. The application's capacity check is the legacy fit check over one node's steady demand and execution epochs; cluster and host fields reach the lowered and plan artefacts and the refusal boundaries, not the wire, until a later phase renders placement. The sprint's `ui-core` split is owned by Phase 8. The other eight capability arms, the remaining planner arms, the activation stages, and runtime accounting stay component suites that this gate does not record. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and `accept` records it. |

## Doctrine adopted

- [`dsl_doctrine.md` §4 — total composability](../documents/engineering/dsl_doctrine.md#4-total-composability) — the typed spec records this phase realises.
- [`dsl_doctrine.md` §5 — the illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) — the three foreclosure layers the refused set exercises.
- [`app_vs_deployment_doctrine.md` §3 — the deployment-rules surface](../documents/engineering/app_vs_deployment_doctrine.md#3-the-deployment-rules-surface--how-the-same-app-runs) — `DeploymentRules` as the binding site.
- [`manifest_generation_doctrine.md` §1 — types render manifests](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) — no string templating on the spine.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` and `SpineFact` this phase carries.
- [`testing_doctrine.md` §9 — derivation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) — the example corpus rule.

## Sprints

## Sprint 3.1: Vocabulary and ui-core split 🔄

**Status**: Active — NOT VALIDATED
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

## Sprint 3.2: The typed root specification ⏸️

**Status**: Blocked — NOT VALIDATED
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

## Sprint 3.3: Import, decode, encode, and examples ⏸️

**Status**: Blocked — NOT VALIDATED
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

## Sprint 3.4: Lowering into the bind input ⏸️

**Status**: Blocked — NOT VALIDATED
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

## Sprint 3.5: Steps as data and the product subcommands ⏸️

**Status**: Blocked — NOT VALIDATED
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

## Sprint 3.6: The pipeline and the control-plane endpoint ⏸️

**Status**: Blocked — NOT VALIDATED
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

## Sprint 3.7: The Phase-3 gate specification and front-half deletions ⏸️

**Status**: Blocked — NOT VALIDATED
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

The specification is registered and the front half is deleted. Fresh binding generation, both client builds,
the linked wire observations, and the constructor oracle have component coverage. The remaining work is to
qualify the verifier-owned generation and plugin boundary, both clients' use of the generated bindings, and the
changed-source controls inside the complete gate. Reproduce the predecessor gates under the current verifier,
preserve the existing spine controls, and run the separate successful `accept` required to end this phase.

The complete declarations and an independent schema expectation are now present. As a component diagnostic,
`protoc` produced byte-identical descriptors for the rendered schema and the former maintained-fork schema.
Fresh bindings generated from that schema also compiled the native client in an isolated diagnostic project with
an adjusted source path. The source-bound preparation executable generates them in fresh `.build/proto/**`
directories; component checks refuse a failed compiler, missing files, and reuse. The later component builds and
linked observations are described below; the verifier still refuses `LTD-SRC-003` until their gate qualification.
Phase 0–2
replay succeeded before the subsequent verifier change; their receipts must be reproduced by the current verifier
before the Phase 3 gate can advance.

A separate component probe now round-trips the default value of all 64 generated message types and one populated
message; an independently implemented protobuf encoder judged all 66 discovery and value rows green. A
field-number change in a separately rendered diagnostic schema produced four red rows. These observations do
not exercise every field or constitute the gate's required changed-production-subject mutant, and the probe is
not yet integrated into the source-bound build and gate.

An isolated diagnostic build also compiled all 17 maintained fork modules against the fresh bindings. The real
fork command and frame encoders emitted independently expected ping, flow, and send bytes. In a separate
rebuilt diagnostic image, changing the fork's flow-permit producer to zero made only the flow oracle row red;
the clean and changed executable hashes differed. This is a component observation, not the shipped binary or
the gate's source-bound qualification, and neither build integration nor compatibility validation is closed.

The shipped binary now materializes a fresh compatibility project from its maintained module inventory and
generated bindings. A serial build of that project compiled all 17 fork modules; the copied source tree and
bindings matched their inputs byte for byte. Its `dev build-pulsar-fork` command now performs generation,
project preparation, and compilation in one invocation through the serial Cabal transport. A component run
compiled all 17 modules with `--jobs=1` and GHC `-j1`; a missing Cabal executable was refused. The phase gate
still needs to own that build, observe the pure consumers through the shipped binary, and qualify its
independent controls.

The shipped binary's `dev build-pulsar-clients` command now stages the native client with the authored Cabal
description and the same fresh bindings, then builds it and the fork sequentially through the serial transport.
A component run compiled both projects with Cabal `--jobs=1` and GHC `-j1`; the staged Cabal description,
native sources, fork sources, and both copies of each binding matched their inputs byte for byte. A missing
Cabal executable stopped the native build and did not start the fork build. The Phase-2 source map and its
independent expectation also name the two standalone wire probes; a neighboring unlisted source remains
refused. These are component checks, and the gate still owes its captured-source and consumer observations.

A separate native-client diagnostic now encodes and decodes the actual connect frame against freshly generated
bindings. Its independently stated wire bytes and decoded summary matched; changing the staged client's protocol
version from 15 to 14 and rebuilding made the oracle reject the frame. This is a component diagnostic: the
shipped binary and phase gate do not yet link or exercise that consumer, and this observation is not a gate pass.

The native client now owns that pure observation, and its staged project includes a separately generated observer
package without changing the copied Cabal description. The shipped binary's client-build command built that observer
and the maintained fork sequentially from fresh bindings. The observer's actual output passed the independent
three-row oracle, and the staged native Cabal description, diagnostic source, and bindings matched their inputs.
The shipped binary still does not link the clients or carry these observations through its phase gate.

The product's fresh client build now also stages and builds a separate fork observer that calls the maintained
fork's real ping, flow, and send encoders. Its output passed all four independent fork-oracle rows. Rebuilding
the staged fork with a zero flow-permit producer made only the flow row red. This is a component diagnostic;
the shipped binary still needs to link the consumers, and the phase gate must own both observations and negatives.

The client-build command now locates both staged observer executables inside their owned build directories, runs
them, and writes their observations into the fresh run. A separate full command run exited successfully and the
independent native and fork oracles judged all seven rows green. These subprocess observations do not yet satisfy
the requirement that the shipped executable link both consumers or the source-bound phase-gate qualification.
Reusing that run was refused. A fake Cabal returning success without an executable path was also refused before
either observation was written or the fork build started. A separate fake Cabal that redirected the native build
directory through a symlink was likewise refused before either observation or the fork build.

The typed-spine oracle now has full and binary gate completion profiles, with independently enumerated row names
and a missing-primary-input refusal. In component diagnostics, the declared inventories matched all 882 rows of
a clean suite and all 922 rows including a perturbed shipped-binary compile and fake apply. Missing capacity tables
now leave every corresponding declared row red instead of replacing them with aggregate fallback names. The
generic verifier selects these profiles for the spine suite; the new completion boundary still needs source-bound
qualification and does not constitute a phase pass. A missing-capacity-table diagnostic retained the same gate
inventory and made all nine corresponding rows red; the existing transcript-parser and oracle-isolation component
checks also passed. The runner now forwards its selected Cabal and compiler paths to the spine oracle's compiler
twins. A component run with Cabal absent from `PATH` passed through the explicit path; substituting a missing
selected Cabal or GHC made all 18 twin rows red without changing the declared inventory.
The completion producer also refuses an empty semantic result, and the wire-generation component suite passed
after these changes. A fresh documentation check reported zero findings; neither check is a phase gate.

A source-bound `amoebius-wire-prepare` executable can now generate fresh bindings before the client is built,
without depending on that client. The native client's Cabal stanza names the generated source directory, and a
clean serial build compiled all 18 native modules from the product tree and those bindings. The preparation
command refused a reused output directory and a relative generator path. A layout-suite subject run completed,
but its full independent oracle was stopped before a verdict, so layout conformance is not claimed from that
diagnostic. The shipped executable still does not link either client, and the gate still must own preparation,
both client builds, the observations, and their negatives.

The product package now declares the maintained fork as a library over the same generated bindings, and a
serial component build compiled its 17 maintained modules. The `amoebius` executable's source now imports
both clients and exposes their pure observations. The preparation executable now reads the maintained fork's
existing provenance identity for the generated version module; the gate still has to qualify that binding in
a clean source copy.
The gate still fails closed on `LTD-SRC-003`.

The combined `amoebius` executable has now built with both client libraries linked. Invoking its native and
fork observation commands produced three and four independently green wire rows respectively. This is a
component diagnostic: a fresh captured-source build does not yet run the preparation prerequisite, and the
gate has not observed the linked consumers or qualified their changed-source negatives. That prerequisite
also applies when reproducing predecessor gates that build `amoebius`; it must be integrated before replay.
In a separate source-copy diagnostic, rebuilding the linked executable with the fork's flow permits forced to
zero made exactly `wire-fork.flow` red; restoring the source and rebuilding produced a different image and four
green rows. Changing the native connect protocol version similarly made only `wire-native.connect` red; its
restored rebuild produced a different image and three green rows. These paired observations are not the
verifier-owned mutation matrix and do not close the remaining gate work.

The preparation executable can now generate into a fresh source copy and then build and locate `amoebius`
through the serial Cabal transport. A component run returned an image confined to that copy's build tree;
its linked native and fork observations passed all seven independent wire rows. Reusing the generated directory
was refused, as was a fake successful Cabal that returned no executable path. The verifier has not yet built
and observed this preparation executable from its own captured
source, so predecessor replay and Phase 3 qualification remain open.

The Haskell schema now also projects a protobuf file descriptor without invoking `protoc`; in a component
comparison that descriptor matched the `protoc` descriptor byte for byte. The proto-lens plugin accepted the
Haskell-produced request, and bindings generated from it compiled and passed all 66 independent constructor
round-trip rows. The field module matched the earlier generated file; the main module omitted embedded source
locations that are not present in the Haskell-produced descriptor. Truncated and error plugin responses were
refused. The preparation executable can invoke the plugin directly and is being checked as a product-build
prerequisite. Source-bound plugin acquisition, gate ownership, and the paired generator negatives remain open.

The preparation executable now also builds the compatible Haskell plugin from Cabal's source graph in an
owned directory, projects the descriptor, generates bindings, and builds the product serially. A source-copy
component run with explicit Cabal and GHC paths and no plugin on `PATH` completed without `protoc`; the
resulting linked image passed all seven independent client-wire rows. The verifier must still build the
preparation executable from its captured source, observe and qualify the complete child-build chain, and run
the generator and client negatives before this can support predecessor replay or the Phase 3 gate.
The preparation executable now declares the Haskell plugin as a Cabal tool dependency and selects its exact
image from the plan that names the local preparation image and its dependency. Component controls refuse
missing, duplicated, incompatible, malformed, and unbound plan entries, while accepting the minimum compatible
version and a later patch version. The expanded `wire-plan` component suite passed. In a fresh source copy, the source-admission
transport built the helper, the helper generated from the plan-selected plugin with no plugin on `PATH`, and
the source-admission transport built `amoebius`; both compiler journals closed and the linked image passed
all seven independent wire rows. This does not yet establish verifier ownership or phase qualification.
The verifier now has a separately implemented selector for the local preparation image and its one compatible
plugin dependency. Component controls cover the selected image, an out-of-build helper, a relative plugin,
duplicate JSON keys and units, incompatible versions, missing entries, and dependency mismatches; the selector
also accepted the actual native Cabal plan. Redundant runner and custody re-export modules were consolidated
without moving validator behavior outside the kernel, which remains at its accepted line-count ceiling. The
selector checks alone do not qualify the phase gate.
The runner now builds and locates the helper through matched compiler journals, checks the independently
selected plan entry, invokes generation, and compares the plan and helper and plugin images around that
invocation before reading the generated files. It calls this stage for the main captured-source product build.
A fresh captured-source component diagnostic exercised the stage and product build using a runner copy changed
only to expose private functions; the independent wire oracle accepted all 3 native, 4 fork, and 67 round-trip
rows. A repeat attempt in that copy refused the existing generation directory and left its four outputs
unchanged. An earlier successful fake Cabal without a journal was refused. The runner now requests fresh
preparation for spine mutation copies, source-sibling builds, and the source-graph and spine legacy copies.
The legacy path retains its preparation and compiler-journal evidence and checks both subject and oracle
images against the captured build plan. These paths still need independent qualification; the source-migration
qualification remains fail-closed, and the component checks do not establish a phase-gate pass.
A direct call to the legacy qualifier now also refuses an unsupported binding before creating its work directory;
the runner's earlier unsupported-analyzer check remains in force. A focused diagnostic confirmed the direct
refusal and the absent work directory; the runner suite and independent oracle now carry the same control.
The focused suite and oracle passed both rows. Altering the observed refusal made the oracle red, and an
isolated build that removed the actual guard created a work directory and made both independent rows red.
These are component diagnostics, not the integrated mutation matrix or a phase-gate result.
The field-number negative now changes the typed `MessageIdData.ledgerId` declaration and renders that value
through the product renderer, rather than editing the rendered Proto text. The independent wire-schema oracle
accepted all eight rows and checked the complete changed schema. An isolated build that made the renderer ignore
its supplied declarations turned the field-number negative and completeness rows red. This exercises the typed
rendering boundary; source-bound binding generation and the complete `LTD-SRC-003` qualification remain open.
The same typed twin now reaches the product descriptor projector. The independent oracle decodes both complete
descriptors against its own schema, requiring field numbers 1 and 99 respectively. All eight legacy rows passed;
an isolated changed-source projector that ignored the twin made the completeness row red. This component check
does not yet establish that the verifier observed the plugin child or that both clients consumed those bindings.
The typed twin also reaches the plugin request encoder. The independent oracle checks its complete request and
descriptor for both field numbers; all eight rows and the wire-generation component checks passed. An isolated
changed-source request encoder that ignored the twin made the completeness row red. Actual plugin execution and
the source-bound client-binding qualification remain open.
Before the subsequent request-retention change, the full spine component diagnostic and its independent oracle
completed all 965 declared rows green. It was not a verifier-owned phase gate and recorded no phase status.
The direct-plugin generator now retains the request it sends, and the runner requires both that request and the
plugin response as nonempty files in the source copy. A subprocess fake confirmed that its received input equals
the retained request. The independent oracle accepted a real plan-selected plugin's request, rejected a changed
request and a missing request, and returned green after restoration. An isolated changed-source generator that
omitted retention still generated bindings, but the independent oracle refused the missing request. A fresh
captured-source diagnostic using an export-only runner copy retained both files, and the independent wire oracle
accepted the captured request. The runner now compares all six generated files after the clean, mutation,
source-sibling, and legacy observations. An export-only component check refused changes to each file and a
missing file, then passed after restoration; bypassing the actual comparison in an isolated changed-source build
made that check fail. A fresh captured-source product build also passed the closing check after its wire
observations, which the independent oracle judged green across 3 native, 4 fork, and 67 round-trip rows.
Plugin-child observation and the complete source-bound binding qualification remain open.
The product preparation has since been split into request creation and response materialization, and the
runner now invokes the plan-selected plugin directly between them. A binary-file transport component check
preserved input, output, stderr, exit codes, and spawn failures; an export-only runner component check also
retained the direct process observations. An isolated changed-source transport that wired the wrong stdin
failed that check, and the restored transport passed. The split helper was also exercised with the real
plan-selected plugin and reproduced the existing generated bindings. The product generator now shares the
file-backed transport with the verifier, and schema output is written as explicit UTF-8 bytes. A fresh
captured-source component run observed the selected plugin directly, built and ran the product, and verified
the generated files at closing; the independent oracle accepted 3 native, 4 fork, 67 linked round-trip,
and 8 wire-schema rows. A changed-source transport routing stderr into stdout made the wire-schema
completeness row red. A subsequent serialized full spine diagnostic on this captured tree returned all
965 independent rows green. The typed-spine subject closure and suite dependency closure also passed their
component check. A second captured-source run changed only `MessageIdData.ledgerId` from field 1 to 99,
observed the changed real plugin request, and built the product from those generated bindings. The independent
wire-schema completeness row and four linked round-trip rows rejected that changed product. The complete
source-bound qualification and gate remain open.
An initial one-mutant matrix diagnostic stopped before mutation because its clean, non-binary oracle profile
was incorrectly required to declare `case:shipped-binary`, a row reserved for the separate binary profile.
The matrix now excludes that one binary-only row from its non-binary control requirements; the integrated gate
still requires it. A fresh one-mutant diagnostic passed its clean control, preserved the source and generated
files, and killed a changed `unknown-arch` product refusal through the independent `vocab.host-grid` row with a
changed suite image. This verifies one matrix row only; the complete matrix remains outstanding.
Inspection of the full selection found that the shared process module also contained an unrelated empty-input
operation. The file-backed transport now has its own subject module and rejects colliding named stream paths
before opening output. Its generation test and eight independent wire-schema rows passed; an isolated product
source mutation matching the new matrix selection made the completeness row red. The complete matrix remains
unrun against this change. A fresh source-captured run then observed the real plugin, built and ran the
product, and passed its source and generated-file closing checks; the independent oracle accepted its 3 native,
4 fork, 67 linked round-trip, and 8 wire-schema rows.
The complete matrix diagnostic passed its clean control and began the selected mutations, but stopped at the
descriptor mutation: the changed plugin request caused the real plugin to fail before the suite oracle ran,
and the runner aborted with `WirePluginObservationMismatch`. This is not a kill or a matrix pass. The runner
still needs a fail-closed, independently judged way to handle source mutations that prevent preparation.
The runner now retains a nonzero plugin exit as a failed preparation instead of aborting the whole matrix. A
fresh captured-source diagnostic reproduced the changed descriptor, retained the real plugin refusal and stderr,
and verified the source copy. This remains a failed row, not an oracle kill; independent judgment and a complete
matrix rerun remain open.
A focused one-mutant matrix diagnostic then passed its clean control and retained the failed descriptor
preparation as a survivor, with the matrix red. A standalone independent request oracle accepts the clean
captured request and rejects both the changed request and an absent request. It is not yet connected to the
matrix's complete inventory and image-bound attribution, so it does not close the descriptor stage.
The preparation diagnostic also compares the prepared schema independently: both clean rows were green, the
changed descriptor left the schema row green and made the request row red, and an absent owner made both red.
The verifier now re-reads the helper, plugin, inputs, and plan on a refused plugin run. A fresh source-captured
diagnostic retained all four closing observations; matrix integration remains open.
A product-linked preparation suite and separately declared two-row oracle profile now run through the standard
runner's inventory, missing-input, image, and source-copy checks. In fresh clean and changed source copies, the
clean profile was green; the changed descriptor produced a different suite image, kept the schema row green,
and made the request row red. Both observed requests matched the corresponding real plugin inputs. This is a
component diagnostic, not a full-corpus matrix result.
The matrix now invokes that profile after a refused plugin run and binds its schema and request to the actual
plugin inputs. A focused changed-source diagnostic retained the green schema and red request rows, refused a
cross-suite image witness, and left the matrix red because the full suite inventory was unavailable. The
complete matrix and an admissible full-corpus attribution remain open.
The attribution audit also found that an absent stage policy accepted any red row, and that a mixture of owned
and unrelated red rows could count as a kill. The runner now requires a nonempty red set entirely covered by the
stage's declared row families. The toolchain and layout specifications now declare candidate row families;
their changed-source coverage and receipts must be reproduced under this verifier. Existing Done lines are
unchanged.
The independent wire oracle also decodes the retained plugin response and compares both complete generated module
bodies with it, while accepting well-formed optional protocol metadata. It accepted the real captured output and
a controlled subprocess output. An isolated changed-source generator that altered the written bodies still
reported success, but the oracle rejected the mismatch. This does not itself observe which child executed.
The spine subject now exercises the shipped generator through one clean and nine refused plugin-process cases.
The independent oracle checks the exact response stimuli, the request actually received by each fake, the
reported outcome, and the absence of unwanted files. All eight legacy rows passed. Isolated changed-source
generator and decoder builds each made the completeness row red; the latter accepted an empty generated file.
The generator, decoder, and their shared binary process transport are now named mutation subjects for Phase 3
and its inherited barrier. Their complete sampled matrix remains unrun, and the barrier's stage-count mismatch
remains recorded in Phase 9.
A subsequent full component oracle run overlapped a separate compiler-bearing build in error. The later build
was stopped; neither overlapping run is accepted as validation evidence, and the full check must be repeated
with compiler work serialized. A fresh serialized repeat completed all 965 independent rows green; it remains
a component diagnostic and does not advance phase status. The product preparation path is now being split so
the verifier can directly invoke the selected plugin; that later change requires fresh checks.
A fresh source-graph legacy diagnostic built its subject and oracle after observed preparation; the source copy
and image checks and all 13 independent oracle rows passed. A second fresh run also decoded the retained
evidence and found the expected generation, image-window, and matched compiler-journal observations. That run
preceded the later direct-refusal guard and request-retention changes; it is component evidence, not a phase-gate result.
The main and source-sibling product builds now use the runner's journal-bound Cabal observer for both build and
binary lookup, refusing either operation when its matching journal window is unavailable. Each image must match
the captured build plan and retain the same bytes and plan across its observation; plan reads use the same
physical-path and regular-file checks as image reads. Source-sibling preparation and legacy qualification
still need the complete observed chain; these runner changes require their own qualification.
An isolated component check of the binding logic observed stable and changed images and refused a plan that
selected another image and a symlinked plan. Its source copy changed only exports to reach the private helper;
it is not an observed captured-source build or a phase-gate result.
A separate native component diagnostic exercised the journal-bound product build and lookup, then ran the
resulting executable between matching plan and image reads. A successful fake Cabal with no journal was
refused. The positive used the live worktree and existing generated bindings, so it does not establish fresh
captured-source preparation or predecessor reproduction.
In a source-copy diagnostic, changing the declared `MessageIdData.ledgerId` number changed the Haskell
descriptor; the changed descriptor also matched `protoc`'s independent descriptor. Direct-plugin bindings
from that changed schema compiled, and the independent round-trip oracle marked four rows red. Restoring the
declaration and rebuilding changed the producer image and reproduced the clean descriptor. These observations
are component evidence, not the verifier-owned source mutation or a gate pass.
The wire-generation component suite passes with explicit empty, truncated, and error plugin-response refusals.
A documentation check after these changes reported zero findings; the corrected full layout diagnostic and
the complete phase gate remain outstanding.

The direct-plugin component check now sends the descriptor request across an actual subprocess boundary. It
accepts the expected two file bodies and refuses empty, truncated, error, missing, duplicate, foreign-path,
insertion-point, empty-content, and failed-process responses without writing either generated binding. The
preparation command also checks the physical `.build` and `proto` parents before generating. A separate
component diagnostic generated with the real compatible plugin in a clean directory and refused both a
redirected `.build` and a redirected `proto` directory without writing into either target. In separate
source-copy component builds, bypassing either physical-parent check made its corresponding control fail;
restoring the source and rebuilding returned the suite to green with a different test image. These are
component observations; the verifier-owned source-copy preparation and complete phase gate remain outstanding.

The `vendor-attribution-duplicated` legacy control now observes the actual source join instead of comparing
message names. Product-owned examples plant ordinary, maintained-vendor, and former top-level-vendor Proto
paths in a fresh tree; the shipped vendor classifier attributes them, and the independent oracle checks the
complete path-to-owner table and the duplicate attribution. A changed-source component build that assigned
vendor Proto to the wire owner made the independent completion control red; restoring the source produced a
different suite image and eight green rows. This diagnostic does not establish the verifier-owned legacy
qualification, generated-binding preparation, or the complete phase gate.
The normal spine suite and its separately declared independent inventory now include those eight attribution
rows. A fresh full component diagnostic matched all 965 declared rows and was green. The Phase 3 and inherited
barrier specifications now name the shipped source-ownership module and attribute its mutations to those rows.
The rebuilt product's observation command returned the expected owners, and the static Phase 3 subject-closure
check accepted the module.
For the current Phase 3 specification, the sampler selects a vendor-input truncation in that module; an
isolated component build of that changed source made the `wire-schema` completion row red, and the restored
build had a different image and eight green rows. The subject still needs verifier-owned changed-source
qualification as part of the complete gate.

The spine suite now emits the product descriptor, and the independent oracle decodes all of its messages,
fields, enums, defaults, and type references against the separate wire inventory. A clean component run
retained all 883 declared oracle rows; a changed descriptor and a truncated descriptor made its new row red.
In a source-copy diagnostic, changing the descriptor producer's `uint64` type code made that row red; restoring
and rebuilding yielded a different image and a green row. The Phase 3 and inherited barrier specifications now
name the descriptor producer as a mutation subject. The verifier-owned mutation matrix has not yet run.

The corrected full layout diagnostic was rerun with an absolute output path. Its previous fork ownership and
compiler-surface rows passed, but graph discovery was red because two components attributed a tuple-constructor
application in the new descriptor oracle as opaque. The oracle now uses an explicit tuple expression, and its
focused descriptor check remains green. The full layout diagnostic still needs a clean rerun after the remaining
build integration changes.

The Phase 3 binary fact now runs the linked native and fork wire observations, and the independent binary
oracle requires all seven wire rows. A gate-profile component diagnostic retained all 930 declared rows and
was green. Removing the native observation kept that inventory and made its three native rows and the shipped
binary case red. This diagnostic reused an earlier staged binary artefact and is not a verifier-run phase gate;
the captured-source preparation chain and its qualifications remain required.

The full spine suite now links and observes both clients, and the Phase 3 mutation specification names the
native protocol and maintained fork command producers with their own independent row families. A clean full
oracle diagnostic retained all 890 rows. In separate source-copy builds, changing the native connect version
made only its connect row red, and changing fork flow permits made only its flow row red; restoring the sources
produced a third image and seven green client rows. The complete verifier-owned matrix has not yet run.

The shipped executable and spine suite now also link constructor round-trip observations for all 64 messages,
one populated message, and a truncated-message control. The independent oracle judged all 67 rows green; a
source-copy mutation forcing every recovery result to `True` made only the malformed-message row red, and the
restored build produced a different image and 67 green rows. Full and binary-profile component diagnostics
matched their separately declared inventories of 957 and 1,071 green rows respectively; the latter reused an
earlier staged binary artefact. A missing round-trip file produced 67 red rows. These checks do not replace the
source-bound gate or its complete mutation matrix.

The layout subject now records generated bindings for both product client libraries and the fork's generated
version module. Its independent full diagnostic initially returned red: three ownership expectations still
treated the fork as standalone, and the compiler-surface diagnostic had been invoked with a relative output
path. The ownership expectations now require the fork's declared imports and real external call, and a separate
absolute-path compiler-surface run passed its independent oracle. The corrected full layout diagnostic has not
yet been rerun and is not evidence of a phase pass.

A changed-source diagnostic now rebuilds `amoebius` after changing the product's `MessageIdData.ledgerId` field
number from 1 to 99, generates bindings with that changed executable, and compiles the constructor round-trip
probe against them. The independent oracle marked four rows red. Restoring the original source and rebuilding in
the same source copy produced a different executable and 66 green oracle rows. This is a component observation;
the gate does not yet own the source witness, rebuild, or negative attribution.

The Phase 3 mutation specification now names the shipped `Amoebius.Pulsar.Wire` declaration module and
attributes its mutations to the independent `wire.*` rows. The inherited barrier specification carries the
same subject. The complete source-bound matrix has not yet run, and this does not close `LTD-SRC-003`.
An isolated spine-suite build with the field-number change produced exactly two red rows, `wire.declarations`
and `wire.schema`, under the full 882-row inventory. Rebuilding the same suite after restoring the source
changed its executable image and yielded 882 green rows. This is a component attribution check, not the
verifier-owned matrix or its complete client-binding qualification.

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
