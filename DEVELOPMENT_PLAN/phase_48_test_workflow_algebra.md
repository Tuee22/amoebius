# Phase 48: The test-workflow algebra

> **Purpose**: Specify the pure test-workflow algebra target: a phantom-state teardown obligation, deterministic
> `suggest-test` projections, named flagged-authority values, and an honest evidence model.
> **Read this if**: phase 48 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — deferred](#resource-provision--deferred)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 48.1: The test-topology type — a deployment-rules layer that always tears down ⏸️](#sprint-481-the-test-topology-type--a-deployment-rules-layer-that-always-tears-down-)
- [Sprint 48.2: Pure `suggestTest` over supplied models and lazy proposal projection ⏸️](#sprint-482-pure-suggesttest-over-supplied-models-and-lazy-proposal-projection-)
- [Sprint 48.3: Flagged-authority and test-owned tagging vocabulary ⏸️](#sprint-483-flagged-authority-and-test-owned-tagging-vocabulary-)
- [Sprint 48.4: Phase-90 transfer for destructive cleanup and leak observation ⏸️](#sprint-484-phase-90-transfer-for-destructive-cleanup-and-leak-observation-)
- [Sprint 48.5: Pure evidence algebra and Phase-90 failover transfer ⏸️](#sprint-485-pure-evidence-algebra-and-phase-90-failover-transfer-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 47, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** Phase 48 owns only a pure Haskell `TestTopology` algebra. Its
phantom states require a teardown continuation, its bounded fault/expectation schedule is deployment-rules
data, and its `suggestTest` function maps a supplied Haskell capacity/authority model to either a proposed
topology or a structured refusal. Haskell declarations own all representative cases and expectations. If an
external Dhall proposal or other serialized form is useful, Haskell generates it lazily beneath
`.build/test-corpora/**`; no `.dhall`, fixture, golden, mutant, script, credential, or evidence file is tracked.

Phase 48 performs no substrate detection, credential probe, resource creation, fault injection, teardown,
inventory readback, browser action, hardware observation, or cluster validation. Those effectful and
destructive responsibilities belong to Phase 90 after the Phase-49 hardware-free DSL promotion barrier and
after their own numerical predecessors. The pure types may describe those later epochs, but a modeled
inventory or capacity value is never represented here as a live observation.

**Phase scope:** one target claim — a Haskell test-topology value cannot reach its terminal state without a
typed teardown continuation, and `suggestTest` is a pure proposal function over supplied model values.

**Substrate:** `none` — Haskell values only; no host, browser, provider, cluster, credential, or hardware.

**Lane:** `none` — live per-test lanes belong to Phase 90.

**Register:** 1 target only; live execution, cleanup, and evidence remain UNVERIFIED.
**Depends on:** [Phase 47](phase_47_tool_and_mutant_generation.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 48`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target only — a pure Haskell test-topology value carries a typed teardown continuation, and pure Haskell `suggestTest` maps supplied model values to a proposal or structured refusal. Generated external forms remain beneath `.build/**`; live execution, deletion, and observation belong to Phase 90. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 48` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | MISSING — blocks validation: the current Phase 47 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — deferred

Everything effectful formerly described in this section is a Phase-90 target, not Phase-48 work or
evidence. Phase 48 may define Haskell constructors for capacity epochs, resource branches, flagged authority,
inventory snapshots, and teardown outcomes only so the later interpreter has a closed input language. It may
not read a host, credential, provider, Kubernetes API, backing store, device, or process boundary.

All cases, expectations, and mutation operators are Haskell. Any Dhall proposal, serialized inventory, fake
client, mutation body, or rendered topology is generated beneath `.build/test-corpora/**` during a candidate run.
The target closure condition rejects any tracked non-Haskell behavioral input and any attempt to treat a
supplied model value as authenticated live readback.

## Doctrine adopted

- [`jit_artifact_doctrine.md` §2 — The rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every serialized test
  topology is a lazy content-addressed projection beneath `.build/**`, never authored repository source.
- [`testing_doctrine.md` §1 — A test is an amoebius spec](../documents/engineering/testing_doctrine.md#1-a-test-is-an-amoebius-spec) and
  [`testing_doctrine.md` §3 — The test-topology contract: spin up → run → always tear down](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down)
  — Phase 48 owns the Haskell algebra and typed teardown obligation only; Phase 90 owns spin-up, run, teardown,
  and leak observation.
- [`testing_doctrine.md` §5 — `suggest-test`: detect the world, emit a representative test `.dhall`](../documents/engineering/testing_doctrine.md#5-suggest-test-detect-the-world-emit-a-representative-test-dhall)
  — `suggestTest` is pure over supplied Haskell model values here. Live detection and authority inspection are
  Phase-90 work; any Dhall proposal is generated under `.build/test-corpora/**` for human review.
- [`testing_doctrine.md` §6 — Flagged test credentials](../documents/engineering/testing_doctrine.md#6-flagged-test-credentials) and
  [`testing_doctrine.md` §7 — The elevated harness is the sole automated deleter of test-owned durable storage; leak-free cycles](../documents/engineering/testing_doctrine.md#7-the-elevated-harness-is-the-sole-automated-deleter-of-test-owned-durable-storage-leak-free-cycles)
  — flagged authority, destructive cleanup, and independent inventory are represented as closed Haskell
  terms but are not exercised before the post-barrier live phase.
- [`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — Phase 48 may compose pure capacity terms over supplied model values; it cannot establish live fit.
- [`testing_doctrine.md` §8 — One substrate per validation](../documents/engineering/testing_doctrine.md#8-one-substrate-per-validation)
  — Phase 48 has no substrate. Phase 90 must name and observe exactly one live substrate when it eventually
  seeks promotion.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanently invalidated historical split.** Any `Done`, completion, or live-validation wording in the
> sprint bodies below is rejected as current status. They inventory pure Haskell value-level targets and
> effectful obligations transferred to Phase 90 only. Generated output stays beneath `.build/**`; Protocol and
> Runtime remain UNVERIFIED.

## Sprint 48.1: The test-topology type — a deployment-rules layer that always tears down ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`testing_doctrine.md §3 — the test-topology contract: spin up → run → always tear down`](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down)
and the framing of [`§1 — a test is an amoebius spec`](../documents/engineering/testing_doctrine.md#1-a-test-is-an-amoebius-spec):
define a `TestTopology` Dhall type that is an ordinary deployment-rules layer over a production app/platform
spec, adding three things production omits — a chaos/failover schedule, a typed expectation surface, and a
mandatory teardown — and a
Haskell runner whose structured `bracket`/`finally` cleanup makes "always tears down" a property of the type,
not of operator diligence, with the chaos injection on the deployment-rules surface so the app under test is
none the wiser ([`app_vs_deployment_doctrine.md §3`](../documents/engineering/app_vs_deployment_doctrine.md#3-the-deployment-rules-surface--how-the-same-app-runs)).

### Deliverables

- A `TestTopology` Dhall type wrapping any app/platform spec with the **three** things a test adds to a
  production deployment — a `chaosSchedule`, an `expectations` surface (the typed `Expectation` values of
  [`chaos_failover_doctrine.md §11.2`](../documents/engineering/chaos_failover_doctrine.md#112-the-typed-expectation-surface-expectation)),
  and a non-optional `teardown` — reusing the production DSL so an illegal cluster (bad PVC↔PV, open ingress,
  mis-substrated workload) is unrepresentable in a test exactly as in production and every execution unit
  carries the same complete `ResourceEnvelope` as production, including `PodRuntimeMetadataSource` and the
  closed `CudaOwnerDemand`/`MetalOwnerDemand` accelerator arm where applicable.
- A `runTestTopology` interpreter that spins up, runs the workflow + injects the scheduled faults, **evaluates each `Expectation`'s witness** and tears
  down inside structured cleanup so a crash or Ctrl-C still reclaims what it built. It accepts only the opaque
  provisioned topology returned after placement/storage/capability/quota checks, never the unchecked decoded
  value. The two UNVERIFIED triggers of
  [`§11.2`](../documents/engineering/chaos_failover_doctrine.md#112-the-typed-expectation-surface-expectation) —
  a derived invariant with no authored witness, and a declared invariant no scheduled fault stresses — are
  recorded per that section, the first in the ledger's `coverage` array, the second as a Runtime-layer
  UNVERIFIED.
- Idempotent destroy (re-running converges to "nothing left", never errors on already-gone resources) and a
  cleanup-failure-is-a-real-failure result type: a passed workflow with a leaked teardown reports failure,
  with the workflow failure surfaced first when both fail.

### Validation

1. Forced-failure and SIGINT-abort runs both reach teardown (Register 3); the pre-/post-run substrate-scope
   inventory diff of Gate criterion 1 is empty afterward, not merely an empty test-owned-tag query.
2. A second teardown over an already-half-torn-down world is a clean no-op (idempotence), recomputed in a
   fresh namespace with any content-addressed store bypassed so a store hit cannot substitute for the
   destroy path executing.
3. A deliberately-illegal test `.dhall` fails to type-check before any resource is allocated, failing with a
   Dhall type error at the specific illegal locus (e.g. the PVC↔PV binding), paired with a positive differing
   only at that locus that type-checks.
4. Each committed resource negative (CPU, memory, pod-local ephemeral storage, in-cluster-cache nesting,
   selected-platform content/snapshots/import workspace and filesystem layout, presented durable backing,
   optional native-host-cache backing, planned/observed runtime-metadata components and node aggregate under the pinned model,
   accelerator source/workload key equality, coexistence-policy class-domain equality, every policy-derived
   coexistence epoch, CUDA residency placement/shard integrity and co-resident per-device net-allocatable
   fit, Metal co-resident shared-memory fit, and quota)
   reaches its specific provision error with zero
   Kubernetes, host, or cloud mutating calls; the paired positive differing only on that axis reaches the
   runner.

### Remaining Work

The pre-reset `None` claim is permanently invalid; this sprint remains blocked and NOT VALIDATED. Phase 90 owns every live execution and reclamation obligation described above.

## Sprint 48.2: Pure `suggestTest` over supplied models and lazy proposal projection ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`testing_doctrine.md §5 — suggest-test: detect the world, emit a representative test .dhall`](../documents/engineering/testing_doctrine.md#5-suggest-test-detect-the-world-emit-a-representative-test-dhall):
turn amoebius's existing introspection into a starting-point test topology. `suggest-test` reads the substrate
via the same pure classification owned by the substrate doctrine, inventories its full capacity/capability
shape, probes what SSH + AWS credentials may do (can they create EBS? a hosted zone? how much?), and writes a
representative test `.dhall` whose worst-case shape provisions inside that supply and authority — a proposal
the operator reviews, never a self-certifying run. Where the doctrine's prose still
names "leadership election", amoebius delegates single-instance to k8s/etcd and worker takeover to Pulsar, so
the emitted chaos schedule injects a *delegated* failover.

### Deliverables

- A `suggest-test` generator consuming
  `(SubstrateClassification, ObservedCapacity, CredentialAuthority)` and producing a `TestTopology` value
  sized on every applicable dimension: CPU requests/limits, memory requests/limits, pod-local
  ephemeral-storage requests/limits, image content/snapshot/import artifacts and filesystem backing, presented
  durable volumes/backing, cache budget/backing, one structural `PodRuntimeMetadataSource` per Pod, one derived
  planned-slot metadata shape under the selected node's pinned model, exact component roles/layout backings,
  and the scope-indexed node domain/ownership/grouping witness,
  plus any `CudaOwnerDemand`/`MetalOwnerDemand` and provider quota. Accelerator `sources` and `workloads`
  must have equal keys; both coexistence-policy maps must have domains exactly equal to the source classes,
  and provisioning derives all permitted epochs. CUDA keeps structural
  `Unsharded | ReplicatedPerDevice | Sharded` residencies (including exact unique-shard sum/count
  constraints) and sums every co-resident residency on each device against net-allocatable VRAM; Metal sums
  every co-resident component against shared host memory. Inapplicable accelerator demand is an explicit
  `None`, not an omitted field.
- Three independent closed emitted fields, exactly as defined by the complete resource contract:
  `NoRegistryPublication | RegistryPublication` retains the exact platform `ImageArtifact`, structural
  `RegistryStorageDemand`, backend/budget/admission and full proxy Pod, and its inner build arm carries the
  named engine/static-process reserve plus complete `BuildExecutionEnvelope`;
  `NoPulumi | Pulumi` retains the exact deploy/plugin/concurrency/volume `PulumiExecutionDemand`, complete
  derived executor Jobs, plugin-cache/workspace and exact `PulumiCheckpointObjectDemand` plus mutation
  admission; and `NoMigration | StorageMigration` retains the old private volume, replacement and structural
  policy from which old+new+workspace/provider overlap and the complete copy/verify Job are derived. Each
  negative arm means that effect is absent; an insufficient positive arm returns "no representative topology
  fits" before emission or review apply.
- A credential-probe step that *reads* SSH/AWS authority but writes only `SecretRef`-by-name into the output —
  the secrets-never-in-Dhall contract owned by
  [`vault_pki_doctrine.md §3`](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value).
- An emitted chaos schedule that simulates an HA failover appropriate to the detected substrate — kill the
  active worker, observe a Pulsar-delegated name-ordered standby take over, with no bespoke election —
  attached on the deployment-rules surface (the app under test is unaware).

### Validation

1. The emitted `.dhall` type-checks as a `TestTopology` and obeys the [§3](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down) teardown contract unconditionally.
   It provisions inside the detected CPU, memory, pod-local logical ephemeral and layout-routed node storage
   (planned-slot metadata components, their roles and backings, and the exact scope-indexed node aggregate
   included), presented durable and cache backing, identity-complete policy-derived CUDA/Metal owner epochs,
   and the distinct provider-quota envelope. It carries explicit `NoRegistryPublication | RegistryPublication`,
   `NoPulumi | Pulumi`, and `NoMigration | StorageMigration` resource branches, contains a delegated-failover
   chaos schedule, and references every credential by name only — an inlined credential is unrepresentable.
2. Property tests perturb each supply axis independently.
   - Lowering CPU, memory, local ephemeral storage (thereby also reducing in-cluster cache headroom),
     presented durable backing, native-host-cache backing on a host-worker lane, pinned-model SplitRuntime
     kubelet-role nodefs headroom, CRI-role imagefs/containerfs headroom, nodefs/imagefs content/snapshot
     residual, an accelerator device's net allocatable VRAM, Metal shared-memory supply,
     engine/control-plane/fabric reserve, build CPU/memory/scratch/cache, or one provider quota class either
     shrinks the emitted representative shape on that axis or yields a structured "no representative
     topology fits" result; it never emits an overcommitted topology.
   - Doubling only the durable-storage quota doubles only the permitted representative volume bound.
   - Removing the selected OS/arch image metadata or reducing the layout-routed content/snapshot backing
     below the deduplicated resident-plus-pull/import peak rejects.
   - Removing one planned slot's runtime-metadata demand, charging an alias twice, changing the pinned
     model, dropping/swapping a role, resolving a role to the wrong backing, mismatching a planned/observed
     domain, creating a qualified Pod/image ownership hole/overlap, or shortening either SplitRuntime
     backing by one metadata byte rejects against the independent fixture.
   - Unified and SplitImage alias controls accept only when their grouped carve is debited once.
   - A CUDA- or Metal-classified fake target must retain equal source/workload key sets and exact
     coexistence policy-class domains and derive every allowed source epoch.
   - CUDA cases exercise indivisible unsharded placement, per-device replication, exact unique shard
     sum/count/link constraints, co-resident per-device aggregation, and raw-fits-but-net-is-one-byte-short
     rejection;
   - Metal cases exercise the co-resident shared-memory peak.
   - Omitting one source/work item or selecting only a favorable epoch rejects, while the canonical
     linux-cpu target emits `accelerator = None`.
   - Reject-branch coverage — that the structured "no representative topology fits" result actually fires —
     is not left to a randomized generator floor: it is discharged by the enumerated committed one-short
     mutants (the pinned `phase_77_resource_overcommit_*`/`phase_77_missing_capability` and `drop_*`
     variants of Validation 3), each of which forces a specific reject before any effect, rather than by a
     cover/classify fraction over the perturbation generator.
3. Exercise the closed optional-branch fixture matrix over its four fixed-input shapes — all-three-negative,
   registry-publication-only, Pulumi-only, and storage-migration-only — where no selected positive arm may be
   ignored. For registry publication, independently shorten OCI
   stored bytes, upload workspace/failed-partial retention, backing/quota, build scratch/cache or proxy
   CPU/memory/ephemeral/image/pod/IP/CSI supply. For Pulumi, shorten executor CPU/memory/ephemeral/log/
   writable/mapped/image supply, plugin installed/install-peak/cache bytes, workspace, checkpoint object/count/
   retained/failure bytes, admission-gateway resources or provider quota. For migration, shorten old or
   replacement backing, workspace, provider volume-count/bytes, copy-Job CPU/memory/ephemeral/image/pod/IP/CSI
   supply, or retain the old backing while claiming its capacity. Every one-short case returns the pinned
   provision error with zero effects; the paired exact-fit case equals
   `phase_77_optional_resource_shapes.json`. The committed
   `drop_registry_publication_envelope.dhall`, `drop_pulumi_executor_envelope.dhall`,
   `drop_pulumi_checkpoint_demand.dhall`, `drop_migration_copy_envelope.dhall`, and
   `drop_migration_old_new_workspace.dhall` mutants each leave their corresponding action present and must
   turn this validation red before any registry, checkpoint, provider or backing mutation.
4. The emitted value is immediately passed through `provision`; the canonical generated
   placement/storage/capability/quota witness matches `test/golden/test_topology_dsl/resource_shape.json`, while every
   perturbed output independently satisfies the same fold. The overcommit/missing-capability mutants fail with
   zero effects.
5. No emitted output contains credential material; every credential is a name, and the chaos schedule names a
   Pulsar-delegated failover rather than a bespoke election.
6. Two emits from the same fixed input, over a bypassed content-addressed store, are byte-identical, and the
   emit path is shown to have executed on the second run rather than served from a memoized store hit (Gate
   criterion 5). The Register-3 Gate, not this sprint, exercises the credential probe against real SSH/AWS and
   records the emitted-to-reviewed provenance.

### Remaining Work

The pre-reset `None` claim is permanently invalid; this sprint remains blocked and NOT VALIDATED. Phase 90 owns host probing, generated Dhall emission, and live reprovisioning.

## Sprint 48.3: Flagged-authority and test-owned tagging vocabulary ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`testing_doctrine.md §6 — flagged test credentials`](../documents/engineering/testing_doctrine.md#6-flagged-test-credentials):
generalize the prodbox `aws_admin_for_test_simulation` pattern into a distinct, marked test-simulation identity
that holds the elevated authority a test needs and a running cluster must never hold, and tag every resource a
topology allocates test-owned at creation so the harness can later find *exactly* what it created. The destroy
authority itself is withheld from normal operation and granted only to this flagged identity — the testing-side
requirement of the create-vs-delete model owned by
[`pulumi_ebs_credential_model.md §6`](../documents/engineering/pulumi_ebs_credential_model.md#6-the-ebs-create-vs-delete-credential-model).

### Deliverables

- A `TestCredential` type marking an identity as test-simulation, distinct in the type system from the
  normal-operation credential; normal operation cannot acquire it and the harness never runs workloads under
  the everyday credential.
- A test-owned tag applied to every allocated resource (cluster, PV, Pulumi stack, workload) at creation,
  forming the basis of the leak-free sweep.
- The flagged credential resolved by name only through Vault (Phase 61) — flagging changes *which* credential
  and *what it may do*, not *where the secret lives*.

### Validation

1. The flagged and normal identities are non-interchangeable at the type level; a topology attempting to run
   a workload under the everyday, non-flagged credential is rejected at type-check with a Dhall type error at
   the credential field — its specific reason, not an unrelated error — paired with a positive using the
   flagged credential that type-checks and differs only in that field.
2. A topology run under the flagged identity tags every resource it allocates test-owned at creation: every
   resource the [Gate integrity](#gate-integrity) representative-set topology allocates carries that tag, and
   an untagged allocation is rejected at type-check with a Dhall type error at the missing-tag field, paired
   with a tagged positive that type-checks and differs only in the present tag.
3. The flagged credential's material never appears in any `.dhall`; it is resolvable only as a Vault
   `SecretRef`, never inlined.

### Remaining Work

The pre-reset `None` claim is permanently invalid; this sprint remains blocked and NOT VALIDATED. Phase 90 owns secret resolution, allocation tagging, and authority readback.

## Sprint 48.4: Phase-90 transfer for destructive cleanup and leak observation ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`testing_doctrine.md §7 — the elevated harness is the sole automated deleter of test-owned durable storage; leak-free cycles`](../documents/engineering/testing_doctrine.md#7-the-elevated-harness-is-the-sole-automated-deleter-of-test-owned-durable-storage-leak-free-cycles),
the named exception delegated by
[`storage_lifecycle_doctrine.md §7.1 — the single exception: the elevated test harness`](../documents/engineering/storage_lifecycle_doctrine.md#71-the-single-exception-the-elevated-test-harness):
make the elevated harness the *one automated* actor that may destroy durable storage — and only storage
flagged test-owned — via a flag-then-sweep cycle. The DSL surface exposes no "delete this durable volume"
primitive at all; deletion is an act of the harness, not a value in a `.dhall`. A non-empty flagged sweep or independent
postflight inventory diff is a hard failure, strengthening the prodbox postflight tag-sweep pattern so
untagged and backing-only leaks are visible.

### Deliverables

- A delete path reachable only by the elevated harness under the flagged credential of Sprint 48.3, scoped to
  test-owned resources, with no normal-operation or non-harness test code path able to destroy retained
  backing bytes; PVC/PV API objects may still disappear through ordinary cluster lifecycle.
- A postflight sweep that, after teardown, asserts leak-freedom by the implementation-independent inventory
  diff of Gate criterion 1 — a substrate-scope enumeration (`kubectl get all,pv,pvc`; the external
  `${RETAINED_ROOT}` allocation inventory; the oracle-pinned service-native AWS `List*`/`Describe*` inventory
  plus Resource Explorer `tag:none`) taken pre- and post-run and compared, not merely a query for the harness's
  own test-owned tag — surfacing any resource present post-run but absent pre-run as a leak (with the leak list
  in the record) while correctly *not* flagging a retained, by-design resource present in both enumerations.
  The Resource Groups Tagging API is metadata-only here because it does not return untagged resources. The
  committed seeded mutants
  `test/mutant/test_topology_dsl/leak_untyped.dhall` (an API resource allocated outside the typed path) and
  `test/mutant/test_topology_dsl/leak_host_backing.dhall` (API bindings removed, host backing left behind) are the
  standing red-tests proving this is neither the circular tag query nor an API-object-only check.
- An explicit scope boundary: this harness reclaims **test-owned** backing only. Production
  `create-new → verified-migrate → retire-old` emits `ReclaimEligible` and leaves physical deletion to an
  external privileged operator action
  ([`storage_lifecycle_doctrine.md §8`](../documents/engineering/storage_lifecycle_doctrine.md#8-shrinking-storage-without-representing-data-destruction));
  Phase 48 neither holds nor tests authority over production backing.

### Validation

1. **Binding-object boundary:** a targeted `kubectl delete pv` from an unrelated everyday workload identity
   receives a live Kubernetes RBAC `403`, while the scoped lifecycle reconciler may delete the test PV/PVC API
   bindings during teardown. In both cases the external host-backing inventory and marker bytes remain
   unchanged. This validates least-privilege Kubernetes object access without pretending the PV object is the
   durable data.
2. **Backing boundary:** under the normal identity, the substrate-specific backing-delete operation is denied
   at the real external boundary — host `${RETAINED_ROOT}` reclaim returns `EACCES`/`EPERM`, and cloud
   `ec2:DeleteVolume` returns AWS `AccessDenied`; no in-process typed refusal counts. Under the elevated
   harness, the same operation against the same test-flagged target succeeds. Each negative/positive pair
   differs only in credential identity; host and EBS pairs are evaluated separately rather than treating a PV
   API delete as equivalent to deleting backing bytes.
3. Leak detection uses the Gate-criterion-1 inventory diff, not a test-owned tag query: the committed seeded
   mutant `test/mutant/test_topology_dsl/leak_untyped.dhall` — a resource allocated *outside* the typed path, hence
   never tagged — MUST fail the run as a leak (proving the sweep is not circular), while a clean run's pre-/
   post-run enumeration diff is empty. The committed
   `test/mutant/test_topology_dsl/leak_host_backing.dhall`, which removes API bindings but leaves the new host backing,
   MUST also fail on the `${RETAINED_ROOT}` allocation diff. On this `linux-cpu` gate the AWS/cloud leg
   allocates nothing and is recorded UNVERIFIED in the ledger (never green); its committed red-test — the
   untagged-AWS-resource mutant `test/mutant/test_topology_dsl/cloud_leak_untyped.dhall` that MUST surface via
   `List*`/`Describe*` + Resource Explorer `tag:none`, paired with a clean run whose AWS enumeration diff is
   empty — is carried by a provider-substrate generated test in the sanctioned parent-drives-provider form
   (Phase 76), keeping this single-substrate `linux-cpu` run's own scope intact ([§L](development_plan_standards.md#l-one-substrate-discipline)).
4. A retained-by-design (unflagged) volume present in *both* the pre-run and post-run enumeration is not
   reported as a leak; a resource absent pre-run but present post-run is.

### Remaining Work

None in this phase. The entire implementation and validation surface belongs to Phase 90.

## Sprint 48.5: Pure evidence algebra and Phase-90 failover transfer ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`testing_doctrine.md §4 — no skips, fail fast, and the per-run ledger artifact`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
and [`§8 — one substrate per validation`](../documents/engineering/testing_doctrine.md#8-one-substrate-per-validation):
make every topology run emit a first-class proven/tested/assumed ledger beside its pass/fail, fail fast on
missing prerequisites, and record an applicable-but-unperformed move as UNVERIFIED. The ledger's *grammar* —
the Extract → Model → Inject moves and the proven/tested/assumed strengths — is owned by
[`chaos_failover_doctrine.md §12`](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
and the live-fault Inject move by
[`§11`](../documents/engineering/chaos_failover_doctrine.md#11-move-iii--inject-break-the-running-thing-on-purpose);
this sprint owns only the *per-run artifact contract* and the gate topology that exercises it. The failover it
injects is delegated to Pulsar (Phase 69), never a bespoke amoebius election.

### Deliverables

- A `Ledger` emitter producing, per run, a record of which correctness layers were reached and at what strength
  (proven / tested / assumed / UNVERIFIED), as a first-class output beside pass/fail, whose applicable-move set
  is **derived** from the topology's `ChaosSchedule`/`FaultTarget` projections and the chaos_failover_doctrine
  [§11.1](../documents/engineering/chaos_failover_doctrine.md#111-the-typed-fault-schedule-chaosschedule--faulttarget) `FaultKind`→invariant map — never a set the emitter declares for itself. The externally hand-authored
  expected-move table `test/oracles/phase_76_expected_moves.json`, authored independently of `Ledger.hs`, is
  the oracle against which the emitted ledger's applicability/strength projection is matched.
- A fail-fast prerequisite check: a missing substrate input, credential, or tool fails the run with a message
  naming what is missing — never a pass-with-skip.
- The pre-reset committed gate topology and review allowlist are condemned source, not a target deliverable.
  Phase 48's future pure gate must use a Haskell-declared topology value and may serialize it only beneath
  `.build/**`; `suggest-test` may emit an external/untracked proposal but neither that proposal nor a diff is an
  oracle. Live substrate allocation, failover injection, teardown, and Runtime-layer evidence belong to Phase
  90 after the hardware-free barrier.
- The finite `suggest-test` and elevated-harness host envelopes and the exact failover epoch (terminating
  active + promoted standby + policy-authorized replacement) from the phase resource contract, including every
  image, mapped/local/durable/cache byte, planned-slot/observed-Pod-UID runtime-metadata component/role/backing
  row and scope-indexed node aggregate, private
  accelerator owner-epoch witness and pod/IP/CSI/provider-quota debit. The host harness performs the chaos
  call; no unprovisioned chaos/client Pod is permitted.

### Validation

1. The gate topology — captured as the raw `suggest-test` emitted `.dhall` (pre-review), the reviewed `.dhall`,
   and their diff in the per-run record — runs the failover simulation, the name-ordered standby takes over the
   Pulsar subscription — confirmed by the external broker subscription/consumer-stats observer of Gate
   criterion 7 against `test/golden/test_topology_dsl/failover_takeover.json`, not the operator-authored
   `ExpectationWitness` — and teardown leaves an empty inventory-diff sweep (Gate criterion 1). The pre-review
   emitted output MUST type-check as a `TestTopology` and carry the delegated-failover chaos schedule, and the
   emitted→reviewed diff MUST be empty or confined to the committed allowlist
   `test/fixture/dhall/phase_76_review_allowlist.json`. The simulation kills the active worker and observes the
   name-ordered standby take over with no bespoke election.
   Before spin-up, both values' CPU, memory, logical Pod-local ephemeral storage, layout-routed
   content/snapshot storage, runtime-metadata component/role/backing maps plus node scope/domain/ownership/grouping, presented durable, cache,
   identity-complete policy-derived CUDA/Metal owner epochs, and quota fields must pass the pure provision fold
   and the snapshot-bound live preflight and
   match the pinned witness, all before any allocation; any review edit that breaks resource feasibility fails
   before allocation even if the field is review-allowlisted.
2. The run emits a ledger whose applicable-move set is derived (from `ChaosSchedule`/`FaultTarget` + [§11.1](../documents/engineering/chaos_failover_doctrine.md#111-the-typed-fault-schedule-chaosschedule--faulttarget) `FaultKind`→invariant map, not emitter-declared) and whose applicability/strength projection matches `test/oracles/phase_76_expected_moves.json`;
   the run-local ledger records the Runtime-layer move *tested on that substrate*, and the fixture's
   declared-but-unfaulted invariant — an applicable move the run omits — is recorded UNVERIFIED, never green;
   the cardinal rule "never report tested or assumed as proven" holds. The committed seeded mutant
   `test/mutant/test_topology_dsl/ledger_all_tested.dhall` (an emitter marking every applicable move tested) MUST fail
   this field-for-field match.
3. A run with a deliberately-absent prerequisite fails fast with a naming error, with no silent skip.
4. The committed overcommit and missing-capability fixtures fail with an empty external mutating-effects trace;
   no test resource is created merely to discover that the target cannot host it.
5. Independently make the generator/harness, controller, active, standby, replacement, selected images,
   Pod/IP/CSI slots, mapped/local/durable/cache storage, either SplitRuntime metadata backing, any derived
   accelerator epoch/device, or quota short by one unit/byte. Each returns its specific pre-effect `Left`;
   dropped-harness/standby/replacement-envelope, dropped accelerator source/work item/co-resident debit,
   favorable-epoch-only, metadata model/role/domain/ownership/alias, premature-run-2-credit, and the
   structural-takeover-defeat `phase_77_failover_standby_wrong_subscription.dhall` (caught by the external
   broker-stats observer of Gate criterion 7) mutants turn the gate red. The
   exact-fit run's live resources and failover epoch equal the opaque projection before teardown can earn any
   capacity credit.

> **Honesty.** This gate exercises the **intra-cluster** Pulsar `Exclusive`/`Failover` takeover only; the
> asynchronous cross-cluster gateway-migration obligation (both Planned and Failover branches) is the one
> formal simulation/proof, owned by
> [`chaos_failover_second_axis.md §16`](../documents/engineering/chaos_failover_second_axis.md#16-the-second-axis--when-one-cluster-becomes-a-forest)
> and must be delivered by human-approved Phase 75 gateway-migration drills, not here. The delegated-failover shape is proven in the sibling `infernix`
> ML-workflow runtime — sibling evidence, not an amoebius result.

### Remaining Work

The pre-reset `None` claim is permanently invalid; this sprint remains blocked and NOT VALIDATED. Phase 90 owns the live ledger artifact and delegated-failover topology.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/testing_doctrine.md` — record the pure teardown, suggestion, credential, and evidence
  module and leave generated/live topology, harness, sweep, and per-run evidence explicitly to Phase 90.
- `documents/engineering/app_vs_deployment_doctrine.md` — retain the deployment-rules target while recording
  that Phase 48 validates only its pure workflow value.
- `documents/engineering/resource_capacity_doctrine.md` — retain the full live provision target while
  distinguishing Phase 48's nine-axis pure suggestion projection from Phase 90's allocation/readback proof.
- `documents/engineering/storage_lifecycle_doctrine.md` — leave §7.1's automated test-reclaim owner UNVERIFIED
  until Phase 90; Phase 48 owns no delete authority.
- `documents/engineering/pulumi_iac_doctrine.md` — §6's create-vs-delete credential model gains the testing-side
  realization: the flagged test-simulation identity is the sole automated holder of destroy authority for
  test-owned durable storage. Production backing is outside this harness and remains reclaimable only by the
  external human-operated break-glass path.
- `documents/engineering/chaos_failover_doctrine.md` — record the §12 per-run proven/tested/assumed ledger for
  the intra-cluster failover injection, and that the §16 cross-cluster (gateway-migration) obligation stays in
  Phase 74.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-48 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/system_components.md` — record `lib:test-workflow-algebra-core` as Phase 48's Decision-layer
  component and keep live `Amoebius/Test/*` ownership at Phase 90.
- `DEVELOPMENT_PLAN/substrates.md` — retain Phase 48 at `none`/`none`; Phase 90 owns the generated test's live substrate.

## Related Documents

- [README.md](README.md) — the live tracker; Phase 48 objective, gate, and substrate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (skeleton, sprint format, the doctrine-citation rule, the register + honesty + one-substrate disciplines)
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (no bespoke election; single-instance delegated to k8s/etcd; the no-normal-operation-deletion storage rule)
- [system_components.md](system_components.md) — the target component inventory for the `Amoebius/Test/*` modules
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — the test-as-a-topology contract,
  `suggest-test`, flagged credentials, the elevated harness, and the per-run ledger this phase implements
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — the retained PV model,
  the no-normal-operation-deletion rule, and the elevated-harness exception this phase realizes
- [Chaos / Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the proven/tested/assumed
  ledger this phase records against and the deferred cross-cluster gateway-migration obligation
- [Application Logic vs Deployment Rules](../documents/engineering/app_vs_deployment_doctrine.md) — the
  deployment-rules surface the chaos schedule attaches to
- [Vault / PKI Doctrine](../documents/engineering/vault_pki_doctrine.md) — the `SecretRef`-by-name contract the
  flagged credential obeys
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — single-instance delegated
  to k8s/etcd and worker takeover delegated to Pulsar, never a bespoke election
- [phase_69](phase_69_content_store_workflow.md) — the Pulsar-`Failover` worker takeover this phase's gate injects
- [phase_75](phase_75_gateway_migration_drills.md) — the cross-cluster gateway-migration obligation, distinct
  from this phase's intra-cluster failover
- [phase_79](phase_79_provider_dynamic_nodes.md) — the leak-free provider teardown this harness extends to test cycles
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
