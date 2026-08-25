# Phase 75: Multi-cluster spawn + geo-replication

> **Purpose**: Turn the single-cluster control plane into a recursive forest — a parent spawns two children,
> hands each only its own `project(subtree)`, and geo-replicates a `command → event* → result` workflow between
> the siblings — establishing the asynchronous cross-cluster boundary (and its invariant-confluence classifier)
> over which [Phase 76](phase_76_gateway_migration_drills.md) drives the gateway-migration runtime.
> **Read this if**: phase 75 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_74_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_76_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_77_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 75.1: Amoebic spawn — `project(subtree)` handoff + per-child unseal / Transit key / secret injection ⏸️](#sprint-751-amoebic-spawn--projectsubtree-handoff--per-child-unseal--transit-key--secret-injection-)
- [Sprint 75.2: Geo-replication of two siblings + invariant-confluence classification ⏸️](#sprint-752-geo-replication-of-two-siblings--invariant-confluence-classification-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 74, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-50 barrier is invalidated and non-operative.

## Phase Summary

This phase crosses the line the chaos/failover doctrine calls the **Second Axis**: the moment a parent spawns a
child and the two geo-replicate, the system stops being one strongly-consistent cluster and becomes a forest
with an **asynchronous** boundary between its clusters. It does two things and stops there. First, **amoebic spawn** — a parent provisions two child `kind` clusters via SSH-key Pulumi run from inside the parent against
a Vault-enveloped MinIO backend and hands each child exactly its own subtree:
the value a child receives is, by construction, `project(subtree)` — a typed `ChildInForceSpec` in which no
sibling or ancestor-only branch can appear — with the child's Vault unsealing in one of two sanctioned modes,
its subtree enveloped under a per-child Transit key, and named secrets injected directly into the child's Vault.
Second, **geo-replication** — the two siblings replicate a `command → event* → result` workflow over
native-protocol Pulsar, write-once content-addressed MinIO blobs, and Patroni Postgres; the bulk of that data
plane is **confluent by construction** and crosses freely, and every crossing mutable multi-record invariant is
sorted by the invariant-confluence classifier — into *confluent* (crosses freely) or *non-confluent* (held by
bounded authority) — before a mechanism is chosen, an unclassified invariant defaulting to non-confluent. The
classifier's output — in particular, that the gateway authority and any CAS "latest" pointer land in the
non-confluent bucket — is precisely the boundary hand-off the [Phase 76](phase_76_gateway_migration_drills.md)
gateway-migration runtime consumes.

The Pulumi path is the `ChildCluster.EnsurePresent` specialization of the canonical conditional
infrastructure pipeline, not a second forest-specific mutation protocol. After child bind/expansion,
`planInfrastructure` derives each child demand from its exact `BoundDeployment` plus disjoint
`ForestMember ClusterBudget`. The required arm is one `ProvisionedInfrastructurePlan`; its single
`ProvisionedProviderActionBatch` owns every child action, the one Pulumi graph, checkpoints, dependencies,
bounded concurrency, and quota partition. Forest-named values below are opaque projections/refinements of
that plan, batch, validated actions, and their canonical tokens—never parallel authorities. The Pulumi path
is provisioned under the canonical
[`resource_capacity_types.md §3.1`](../documents/engineering/resource_capacity_types.md#31-the-systematic-provision-matrix)
matrix and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
sealed boundary, not treated as free control-plane work. The
two child stacks produce exact `PulumiCheckpointObjectDemand` values whose state-entry/field and revision
identities, storage budgets, failure/orphan exposure, and exclusive mutation admissions enter the parent's
MinIO capacity fold. Their independent deploy graph produces one bounded `PulumiExecutionDemand`; its
executor-Job CPU, memory, pod-ephemeral, image, log, writable-root, mapped-input, plugin-cache, and workspace
peaks must fit the parent — including parallel, retry, rollout, and terminating overlap — before either SSH or
checkpoint effect is possible. The batch is snapshot-validated and CAS-consumed once; only its
receipt-bound child-cluster readbacks construct `ObservedInfrastructureMaterialization`, each child's
`ProvisionContext`, and then its opaque `ProvisionedSpec` for `renderAll`.
The first absent→present spawn takes `InfrastructureRequired`. A converged rerun may take
`NoInfrastructureRequired` only with the explicit already-materialized child state and performs no child,
checkpoint, or executor mutation.

This phase consumes only future human-approved predecessors and does not re-implement them: Phase 56's
Haskell coordinator bootstrap of a `kind` cluster after the bounded `pb` handoff, Phase 62's root Vault/PKI
trust anchor, Phases 63–65's platform services and authenticated edge (including MinIO, Pulsar, and Patroni Postgres),
Phase 66's live DSL deploy via the `replicas=1` control-plane daemon, Phase 68's native Pulsar client, and Phase 70's
content-addressed store + workflow runtime. A **stretched cluster is not geo-replication**: one etcd, one
boundary, one `Topology` whose nodes merely span network `Site`s owes no R9 budget and no Second-Axis obligation
and is out of scope here.

The pure `Rke2ServerNode`/`Rke2AgentNode` and reserve/template folds are predecessor obligations in Phases 12–17, but no live
multi-node rke2 acceptance gate is assigned. This phase does not silently supply one: its only child-engine
fixture is `kind`, and the rke2 mutation continuation remains unavailable until a future Phase-N host-
admission/join/enforcement gate is promoted.

**Phase scope:** one cohesive target claim — *a parent must hand each child only its own subtree, and the boundary
between them must be asynchronous*. The future confluence classifier must make that boundary reasoned about
rather than assumed.

**Substrate:** linux-cpu — the future gate must spin up the parent and both child clusters as `kind` clusters on a
single linux-cpu host; no accelerator and no provider cluster is in scope (provider-managed clusters are
[Phase 77](phase_77_provider_deploy_checkpoint.md)). Before either child may be created, the target parent-owned
`SharedSupplyLedger` must carve disjoint cluster-engine/VM and named physical-backing budgets from that one host;
each child must then derive its logical pod-ephemeral demand and route pod/image/content/snapshot/workspace bytes
through its closed kubelet filesystem layout. Independent child `place` proofs cannot reuse the same host
bytes. The parent cluster also places the Pulumi executor Jobs and debits their plugin/workspace volumes and
checkpoint object peaks; proving the child VMs fit does not pay those parent-side resources. Partition
tolerance is exercised at the boundary by the
[Phase 76](phase_76_gateway_migration_drills.md) drills; the future Phase-75 gate must first establish and
classify the boundary here.
This CPU-only Linux lane is always available on every hardware substrate.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure: a real parent and two real child clusters and a real geo-replicated
workflow crossing an asynchronous boundary.

**Depends on:** [Phase 74](phase_74_network_fabric_wireguard.md)
**Gate:** `pb validate phase 75`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive claim — *a parent hands each child only its own subtree, and the boundary between them is asynchronous*. The confluence classifier is what makes that boundary reasoned about rather than assumed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 75` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 74; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [`workflow_calculus_doctrine.md` §3 — Teardown is a type obligation](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation) — multi-cluster spawn + geo-replication provisions, and a teardown obligation it cannot discharge is a value it cannot construct.
- [`cluster_lifecycle_doctrine.md` §3 — Amoebic spawning — the recursive forest](../documents/engineering/cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest)
  and [`cluster_lifecycle_doctrine.md` §9 — How bring-up and teardown are implemented: the reconciler, not a state machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)
  — the `project(subtree)` handoff of amoebic spawning, enacted as `discover → diff → enact → re-observe`
  reconciles over a managed-resource registry (never a bespoke lifecycle state machine), so the leak-free child
  teardown of this phase's gate is one `reconcileAbsent` loop with "cannot observe" never collapsed to "absent."
  The teardown-with-cleanup-vs-chaos distinction ([`cluster_lifecycle_doctrine.md` §5 — Teardown-with-cleanup vs chaos-failover (the central distinction)](../documents/engineering/cluster_lifecycle_doctrine.md#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction)) and the unsatisfiable Haskell-declared `InForceSpec` push-back ([`cluster_lifecycle_doctrine.md` §6 — Push-back when teardown would break the root `InForceSpec`](../documents/engineering/cluster_lifecycle_doctrine.md#6-push-back-when-teardown-would-break-the-root-inforcespec)) belong to the
  gateway-migration drills of [Phase 76](phase_76_gateway_migration_drills.md).
- [`pulumi_iac_doctrine.md` §1 — Pulumi runs only from inside an existing amoebius cluster](../documents/engineering/pulumi_iac_doctrine.md#1-pulumi-runs-only-from-inside-an-existing-amoebius-cluster),
  [`pulumi_iac_doctrine.md` §2 — The backend: every byte of state is a Vault-enveloped object in MinIO](../documents/engineering/pulumi_iac_doctrine.md#2-the-backend-every-byte-of-state-is-a-vault-enveloped-object-in-minio), and
  [`pulumi_iac_doctrine.md` §7 — Applicative parallelism for independent deploys](../documents/engineering/pulumi_iac_doctrine.md#7-applicative-parallelism-for-independent-deploys)
  — the in-cluster-only engine, exact Vault-enveloped checkpoint objects, and finite applicative fan-out:
  checkpoint state fields/revisions and failed-partial/orphan extents consume an attached `StorageBudgetId`
  through the sole mutation gateway, while the parent places complete executor-Job envelopes and typed
  plugin/workspace peaks before either independent child deploy may mutate.
- [`vault_pki_doctrine.md` §6 — Parent/child unseal: two sanctioned modes](../documents/engineering/vault_pki_doctrine.md#6-parentchild-unseal-two-sanctioned-modes)
  and [`vault_pki_doctrine.md` §7 — Parent injects secrets into the child's Vault](../documents/engineering/vault_pki_doctrine.md#7-parent-injects-secrets-into-the-childs-vault)
  — the recursive parent/child spawn unseal (self-unseal from a k8s secret, or parent-held unlock with the brick
  cascading down a sealed subtree), the per-child Transit key (`transit/amoebius-<child-id>-config`) that makes a
  sibling's subtree cryptographically undecryptable even under an unsealed parent, and the
  parent-injects-named-secrets path (Dhall names only; the parent materializes the bytes).
- [`content_addressing_doctrine.md` §5 — Confluence: content-addressed data crosses cluster boundaries safely](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely)
  — the confluent data plane: content-addressed write-once blobs (identical content ⇒ identical key ⇒ idempotent
  cross-cluster write) and the work-id-keyed Pulsar fold land in bucket (i) and cross freely, leaving only the
  gateway authority and any CAS "latest" pointer in bucket (ii) for the [Phase 76](phase_76_gateway_migration_drills.md) migration runtime.
- [`chaos_failover_second_axis.md` §16 — The Second Axis — when one cluster becomes a forest](../documents/engineering/chaos_failover_second_axis.md#16-the-second-axis--when-one-cluster-becomes-a-forest)
  and [`chaos_failover_second_axis.md` §17 — The boundary and its classifier](../documents/engineering/chaos_failover_second_axis.md#17-the-boundary-and-its-classifier)
  — the Second Axis (one cluster becomes a forest) and the invariant-confluence classifier (R1/[`chaos_failover_second_axis.md` §17 — The boundary and its classifier](../documents/engineering/chaos_failover_second_axis.md#17-the-boundary-and-its-classifier)) that sorts
  every crossing mutable invariant into confluent (crosses freely) or non-confluent (held by bounded authority),
  the unclassified default = non-confluent — with the
  [`chaos_failover_doctrine.md` §12 — The moral core — proven, tested, assumed](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed) kept
  honest. The R7/R8/R9 boundary rules and the [`chaos_failover_second_axis.md` §19 — The cross-boundary ledger and conformance rows](../documents/engineering/chaos_failover_second_axis.md#19-the-cross-boundary-ledger-and-conformance-rows) cross-boundary ledger are consumed by [Phase 76](phase_76_gateway_migration_drills.md).
- [`testing_doctrine.md` §3 — The test-topology contract: spin up → run → always tear down](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down)
  (the test-as-`InForceSpec` spin-up → run → always-tear-down contract) and
  [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
  (the per-run proven/tested/assumed ledger): the register this gate reaches and the ledger it emits.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and a human tracker change.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in reviewed Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 75.1: Amoebic spawn — `project(subtree)` handoff + per-child unseal / Transit key / secret injection ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 74](phase_74_network_fabric_wireguard.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`cluster_lifecycle_doctrine.md §3`](../documents/engineering/cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest)/[`§9`](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)
and [`vault_pki_doctrine.md §6`](../documents/engineering/vault_pki_doctrine.md#6-parentchild-unseal-two-sanctioned-modes)/[`§7`](../documents/engineering/vault_pki_doctrine.md#7-parent-injects-secrets-into-the-childs-vault):
implement the spawn as a Pulumi deploy run from inside an existing cluster, tracked in a Vault-enveloped MinIO
backend, delivering the structural `project(subtree)` projection so a child receives exactly its own subtree
and nothing about siblings, with per-child unseal, a per-child Transit key, parent→child secret injection, and a
managed-resource registry entry so teardown is a reconcile, not a state machine.

### Deliverables

- A parent-owned `SharedSupplyLedger` keyed by `HostId`/`BackingId` and the pre-spawn
  `observeSharedSupply → allocateForestSupply → planInfrastructure → validateForestSpawn` boundary that
  subtracts non-cluster
  commitments, carves disjoint parent/child engine/VM and named physical-backing budgets, proves each child's
  logical pod-ephemeral allocation, closed nodefs/imagefs/containerfs layout, OCI content/snapshot/import
  workspace, and routed backing peaks, and
  returns one opaque `ValidatedForestSpawn` refinement of the canonical `ValidatedInfrastructurePlan`, bound
  to the complete host/backing/process fingerprint. It does not mint a forest token: the canonical fresh
  infrastructure-plan token and per-action SSH-host tokens are the only authorities. The fingerprint is re-read
  immediately before the first Pulumi/child mutation; change invalidates those tokens and exposes no
  child-create continuation.

  ```text
  BoundChildInfrastructureFromForestBudget = -- opaque ChildCluster request specialization
    { request        : ProvisionedChildClusterRequest
    , forestMember   : request.budget.cluster == request.cluster
    , budgetEquality :
        ChildTopologyBoundIntentAccountBackingDeviceBudgetEqualityWitness request
    }
  -- request contains only cluster/budget/topology/BoundDeployment plus Required post-materialization seal.
  -- It cannot contain ProvisionContext or ProvisionedSpec.

  ChildScopedSshHostMaterialization = -- opaque projection of canonical providerResults; no cloud inventory
    { state           : MaterializedInfrastructureState
    , host            : HostId
    , child           : ClusterId
    , action          : InfrastructureProviderActionId
    , childIndex      : state.childClusters[child] == action
    , resultArm       :
        MaterializedProviderResultIsExactSshHostChildClusterPresentWitness state action host child
    , sourceEquality  :
        SshHostChildActionResultMaterializationIdentityEqualityWitness
    }

  ForestChildInfrastructureMaterialization = -- opaque exact child projection
    { forest         : ObservedInfrastructureMaterialization
    , child          : ClusterId
    , providerState  : ChildScopedSshHostMaterialization
    , exactProjection:
        ForestReceiptSshHostChildActionResultProjectionWitness
    }

  MaterializedChildFromForestBudget =
    { source          : BoundChildInfrastructureFromForestBudget
    , infrastructure  : ForestChildInfrastructureMaterialization
    , context         : ProvisionContext -- exact ForestMember budget + observed infrastructure
    , provisioned     : ProvisionedSpec
    , sourceEquality  :
        ChildBoundIntentBudgetMaterializationContextProvisionSealEqualityWitness
    }

  ForestChildSshHostActionProjection = -- opaque projection; never owns an action or executor graph
    { child          : BoundChildInfrastructureFromForestBudget
    , action         : ProvisionedSshHostProviderAction
    , operationArm   :
        SshHostActionIsCreateOfExactChildRequestAndHostIdentityWitness
    , sourceEquality :
        ForestChildRequestSshHostActionDeployCheckpointDigestBudgetEqualityWitness
    }

  ForestInfrastructurePlan = -- opaque ChildCluster-only refinement; no public constructor
    { canonical       : ProvisionedInfrastructurePlan
    , allocation      : ForestSupplyAllocationDigest
    , ledger          : SharedSupplyLedgerId
    , budgets         : Map ClusterId ClusterBudget
    , children        : NonEmptyMap ClusterId ForestChildSshHostActionProjection
    , actionDomain    :
        ForestChildrenExactlyEqualCanonicalBatchActionDomainWitness
    , operationDomain :
        EveryCanonicalBatchActionIsSshHostChildClusterCreateWitness
    , disjointness    : ClusterBudgetDisjointnessWitness
    , sourceEquality  :
        ForestAllocationBudgetChildCanonicalInfrastructurePlanEqualityWitness
    }
  -- canonical.batch is the sole ProvisionedProviderActionBatch. It alone owns actions, execution,
  -- checkpoints, dependencies, BoundedParallel 2 admission, and quota partition.

  ForestPulumiBoundedConcurrencyProjection = -- read-only projection of canonical batch admission
    { deploy         : PulumiDeployId
    , slot           : Natural
    , ceiling        : PositiveNatural -- exactly 2 for this gate
    , sourceEquality :
        ForestDeploySlotEqualsCanonicalBatchBoundedParallelAdmissionWitness
    }

  ForestChildPulumiDeployProjection = -- private read-only view of canonical.batch
    { child          : ForestChildSshHostActionProjection
    , deploy         : child.action.deploy
    , executorPod    : PodResourceEnvelope
    , dependencies   : Set PulumiDeployId
    , plugins        : NonEmptyMap PulumiPluginId PulumiPluginDemand
    , cache          : ProvisionedCacheDemand InClusterCacheOwner
    , checkpoint     : ProvisionedPulumiCheckpointObjectDemand
    , checkpointEquality :
        ForestDeployActionStackEqualsBatchDeployCheckpointAndDemandStackWitness
    , concurrency    : ForestPulumiBoundedConcurrencyProjection
    , sourceEquality :
        ForestChildActionExactBatchExecutionPluginCacheCheckpointConcurrencyProjectionWitness
    }

  ForestPulumiExecutionProjection = -- compatibility view, explicitly not an owner
    { plan           : ForestInfrastructurePlan
    , childDeploys   : NonEmptyMap ClusterId ForestChildPulumiDeployProjection
    , boundedTwo     :
        plan.canonical.batch.execution.source.concurrency == BoundedParallel 2
    , sourceEquality :
        ForestChildDeployDomainEqualsCanonicalBatchActionDeployDomainWitness
    }

  -- There is deliberately no ForestExecutionToken. The only plan token is
  -- SingleUseInfrastructurePlanToken and the only action tokens are SingleUseSshHostMutationToken values
  -- inside the canonical ValidatedInfrastructurePlan.

  ValidatedForestSpawn = -- opaque refinement/projection, not a parallel mutation authority
    { plan             : ForestInfrastructurePlan
    , canonical        : ValidatedInfrastructurePlan
    , children         : NonEmptyMap ClusterId ValidatedSshHostProviderAction
    , childDomain      :
        ForestValidatedChildrenExactlyEqualCanonicalValidatedBatchActionDomainWitness
    , childArms        : EveryValidatedForestActionIsExactSshHostChildClusterProjectionWitness
    , observedShared   : SharedSupplySnapshotFingerprint
    , sharedSupplyFit  : ForestAllocationFreshObservedSharedSupplyFitWitness
    , canonicalEquality:
        ForestPlanBatchActionsSnapshotEqualsValidatedInfrastructurePlanBatchWitness
    , sourceEquality   :
        ForestBudgetChildCanonicalFreshPlanAndActionTokenSnapshotEqualityWitness
    }
  -- children is an exact small projection of canonical.validatedBatch.actions; each value carries only the
  -- canonical batch id, never the batch's Pulumi execution/checkpoint graph.

  AdmittedForestChildMutation = -- private exact projection of one canonical validated action
    { action            : ValidatedSshHostProviderAction
    , childArm          : action.action.operation == Create
    , deployProjection  : ForestChildPulumiDeployProjection
    , checkpointGateway :
        ProvisionedObjectStoreAdmissionGateway -- projection of canonical batch checkpoint
    , tokenProjection   : action.singleUse == SingleUseSshHostMutationToken Fresh
    , equality          :
        ForestChildValidatedSshActionBatchDeployCheckpointGatewayTokenEqualityWitness
    }

  ManagedResourceRegistryEntryId =
    { parentDeployment : DeploymentId
    , child            : ClusterId
    , generation       : ProvisionGenerationDigest
    , action           : InfrastructureProviderActionId
    }

  ManagedChildResource =
    { child              : MaterializedChildFromForestBudget
    , deploy             : PulumiDeployId
    , stack              : PulumiStackId
    , checkpointDigest   : ContentAddress
    , provisionedDigest  : ProvisionGenerationDigest
    , managedRegistryRef : ManagedResourceRegistryEntryId
    , sourceEquality     : ManagedChildResultSourceEqualityWitness
    }

  ForestSpawnValidationError =
    < CanonicalInfrastructurePlanInvalid : ProvisionError
    | ForestSharedSupplySnapshotMismatch
    | ForestSshHostSnapshotMismatch
    | ForestChildActionDomainMismatch
    | ForestBudgetDisjointnessMismatch
    >

  validateForestSpawn
    :: ObservedSharedSupplySnapshot
    -> ObservedSshHostInfrastructureSnapshot
    -> ForestInfrastructurePlan
    -> Either ForestSpawnValidationError ValidatedForestSpawn
  -- validateForestSpawn wraps the SSH snapshot in the generic non-empty
  -- ObservedInfrastructureProviderSnapshot with cloud = None, then refines validateInfrastructurePlan; it
  -- cannot mint another token family.

  ForestPreEnactmentError =
    < CanonicalInfrastructurePreEnactmentError : InfrastructurePreEnactmentError
    | SharedSupplySnapshotChanged
    >

  ForestSpawnResult =
    < Materialized :
        { infrastructure : InfrastructureEnactmentResult.Materialized
        , children       : NonEmptyMap ClusterId ManagedChildResource
        , sourceEquality :
            ForestReceiptMaterializationContextProvisionedChildrenEqualityWitness
        }
    | OutcomeUnknown : InfrastructureEnactmentResult.OutcomeUnknown
    >

  spawnForest
    :: ValidatedForestSpawn
    -> Either ForestPreEnactmentError ForestSpawnResult
  -- The Materialized arm's enactment receipt contains the Consumed infrastructure-plan token plus every
  -- Consumed SSH-host action token. OutcomeUnknown exposes only re-observation and cannot return children.
  -- No forest-specific consumed token exists.

  ChildSpawnError =
    < ChildSnapshotChangedBeforeTokenCas
    | ChildActionTokenAlreadyConsumed
    | ChildSshHostCapabilityUnavailable
    | ChildCheckpointAdmissionUnavailable
    >

  ChildSpawnWorkerResult =
    < Materialized :
        { actionToken  : SingleUseSshHostMutationToken Consumed
        , deploy       : PulumiDeployId
        , checkpoint   : InfrastructureDeployOutcome.Completed
        , child        : ObservedSshHostChildClusterMaterialization
        , sourceEquality:
            ChildConsumedActionDeployCompletedCheckpointMaterializationEqualityWitness
        }
    | OutcomeUnknown :
        { actionToken : SingleUseSshHostMutationToken Consumed
        , deploy       : PulumiDeployId
        , checkpoint   : InfrastructureDeployOutcome.OutcomeUnknown
        , reobserve    :
            RequireFreshWholeProviderCheckpointAndParentInventoryObservation
        , noReplay     : Required
        , sourceEquality:
            ChildConsumedActionDeployCheckpointUnknownOutcomeEqualityWitness
        }
    >

  spawnChild -- private worker called only by the canonical batch's bounded executor
    :: AdmittedForestChildMutation
    -> Either ChildSpawnError ChildSpawnWorkerResult
  -- ChildSpawnError is pre-action-token CAS and proves zero child/checkpoint effects. Once the canonical
  -- action token is consumed, both worker arms return that Consumed token and the exact completed/unknown
  -- deploy-checkpoint outcome. The canonical batch enactor aggregates them with the consumed plan and
  -- other-action tokens into the outer InfrastructureEnactmentReceipt; any unknown member selects
  -- InfrastructureEnactmentResult.OutcomeUnknown. The worker cannot return Left or a replayable action after
  -- CAS.
  ```

  Checked construction proves every returned budget-map key equals its embedded `ClusterBudget.cluster` and
  every pre-infrastructure child request carries that exact `ForestMember` budget. The forest plan is an
  opaque `ChildCluster.Create`-only refinement of the canonical `ProvisionedInfrastructurePlan`; its child,
  action, deploy, and checkpoint domains equal the sole `ProvisionedProviderActionBatch` domains. Each child
  view is only a projection of that batch's executor pod, dependencies, plugins, cache, checkpoint, and
  `BoundedParallel 2` admission—never a copied full graph or a new action authority. `spawnForest` consumes the
  canonical plan/action tokens through the canonical batch enactor; its private worker receives one exact
  `ValidatedSshHostProviderAction` projection. The checkpoint gateway is projected from the batch checkpoint
  carrier, never duplicated. Only receipt-bound observed action results construct each matching
  `ProvisionContext`, after which `provision` seals the child `ProvisionedSpec`. A replay or sibling
  substitution fails the canonical token, action-domain, and source-equality witnesses; there is no
  forest-specific token to bypass them.
- One `PulumiCheckpointObjectDemand` per child stack: an attached `StorageBudgetId`; exact
  `PulumiResourceStateId` entries and `(PulumiStateFieldPath, maxCanonicalBytes, Plain | Secret)` fields;
  finite retained revisions; serial update; a finite failed-write/orphan-GC budget; pinned checkpoint model;
  and exclusive `ObjectStoreMutationAdmission`. The pure object-store fold derives canonical/envelope bytes,
  current/old/new overlap, revision identities, and failed-partial/orphan extents into a private peak before
  Vault unwrap, MinIO PUT/CAS, SSH, or child creation. Only the admitted mutation gateway can write these
  identities; its concurrency/rate model supplies a complete placed proxy `PodResourceEnvelope`, and direct
  S3 mutation credentials/routes are absent.
- One parent-side `PulumiExecutionDemand` whose deploy graph marks the two child stacks independent and uses
  an explicit `BoundedParallel 2` ceiling. It joins every plugin identity to content digest,
  installed bytes, and peak-install bytes; names disk-backed plugin-cache and workspace volumes; and derives
  complete executor-Job `PodResourceEnvelope`s (image, CPU/memory requests and limits, pod-ephemeral request/
  limit, logs, writable root, mapped inputs, retry, rollout, and termination overlap). Only the private
  `ProvisionedPulumiExecutionDemand { source, executorPods, deployGraph, pluginObjects,
  pluginVolume : ProvisionedPulumiExecutionVolume PluginVolume,
  workspaceVolume : ProvisionedPulumiExecutionVolume WorkspaceVolume, caches, sourceEquality, witness }`
  placed under the sole `ProvisionedInfrastructurePlan.batch` exposes the deploy continuation after canonical
  validation. Its typed volume carriers derive provisioned raw debits from required-usable peaks before
  either fresh raw/usable fit. The
  batch owns that value once and gives each child action only its exact private deploy projection. The
  parent's `BoundDeployment` carries only the unprovisioned `PulumiExecutionDemand`; it cannot carry or expose
  a `Provisioned*` projection, and a parent `ProvisionedSpec` is not a second owner of the initial-infrastructure
  graph.
- A `ChildInForceSpec` type that is, by construction, the projection of a parent spec onto one subtree — no
  field admits a sibling or ancestor-only branch, and a grandchild path proves the projection composes to
  arbitrary depth.
- A `spawnChild` action: SSH-key `kind` Pulumi deploy from inside the parent, registered as a typed
  managed resource carrying its own `discover`/`destroy`, so a re-run is a no-op and a teardown is one
  `reconcileAbsent` loop.
- A `SealMode` (`SelfUnseal` | `ParentHeldUnlock`) decoded from the child's Haskell-declared configuration;
  any Dhall projection is generated lazily beneath `.build/**`. Per-child Transit key
  provisioning with a decrypt-on-that-key-alone policy, and an `injectSecret` action materializing named
  secrets into the child's Vault (in-cluster consumers read via Vault k8s auth).

### Validation

1. The reviewed Haskell shared-host-overdraw fixture exceeds the one host's image/disk budget by one byte; it returns
   `SharedSupplyOvercommit`, exposes no child-create continuation, and the external runtime/cloud audit contains
   zero child mutations and zero checkpoint PUTs. Its paired fitting parent+two-child carve returns three
   owner-distinct budgets.
   A changed-snapshot fixture consumes host/disk headroom after validation and before Pulumi; the immediate
   token recheck refuses with zero Pulumi calls, child containers, or backing allocations.
2. Paired one-short fixtures remove only one executor/admission-gateway millicore, one byte of executor/gateway
   memory/pod-ephemeral, plugin-cache, workspace, or checkpoint `StorageBudget`; each returns the
   dimension-specific provision error — `PulumiExecutionOvercommit` on the executor, plugin, and workspace
   dimensions — before a Job, checkpoint write, SSH call, or child create. In the fitting case, Kubernetes API readback of
   both rendered executor Jobs exactly matches the witnessed image, requests/limits, ephemeral/log/writable
   allowances, volumes, and `BoundedParallel 2` live set; MinIO `LIST`/`HEAD` plus gateway admission records
   match the exact stack/revision object identities and extents. Injecting a failed checkpoint CAS retains the
   bounded partial/orphan object until the declared GC horizon and keeps it charged. A direct checkpoint PUT
   outside the gateway is denied.
3. The Haskell-authored changed-subject `drop-parallel-executor` mutant charges only one of the two simultaneously runnable
   executor Jobs (or serializes after admitting the parallel declaration) and MUST go red against a parent
   fixture that fits either Job alone but not both. This proves applicative parallelism is represented in the
   resource peak, not merely exercised opportunistically after admission.
4. A parent brings up two empty child `kind` clusters on linux-cpu; re-running the spawn is a no-op (observed at
   the OS boundary via `pulumi stack ls`); the "no total function producing a `ChildInForceSpec` containing a
   sibling's branch" claim is discharged by reviewed Haskell compile-fail fixtures (not a
   code-review/parametricity argument). Compiler inputs and diagnostics are materialized lazily beneath
   `.build/test-corpora/compile_fail/ChildInForceSpec/**`; the Haskell corpus holds at least two negatives
   that each attempt to construct a `ChildInForceSpec` carrying a sibling or ancestor-only branch and **must fail to typecheck**, each asserting its **specific expected compile-fail locus/message** (the type error
   naming the absent constructor/field), paired with a positive fixture that differs only in projecting the
   child's own subtree and **must** compile — authored and independently reviewed as Haskell `.hs` before `ChildInForceSpec.hs`
   exists; the Haskell-authored changed-subject `project-identity` mutant ([Gate integrity](#gate-integrity)) makes a sibling branch appear in a child's delivered
   spec and the runtime subtree-inspection assertion goes red; mode (b) bricks with the parent sealed and
   unseals with it available; cross-child Transit decrypt fails; a graceful child teardown leaves zero surviving
   stacks by the OS-boundary observer, retained backing stores exempt.
5. The read-only prefix completes before any effect. `allocateForestSupply` reads the observed single host
   together with the parent and both child engine/backing demands, returns three disjoint opaque
   `ClusterBudget`s, and provisions the exact checkpoint object peak for each stack and the bounded-parallel
   Pulumi execution peak for both parent-side executor Jobs, their plugins, and their workspaces; only then
   may the parent spawn a child from inside itself. Each admitted child then comes up empty, reconciles
   toward its spec, unseals in each of the two sanctioned modes, resolves a named `SecretRef` to bytes the
   parent injected rather than to a Dhall fragment or an env var, and — registered as a managed resource
   carrying its own `destroy` — tears down leak-free through one `reconcileAbsent` loop.

### Remaining Work

None inside the sealed `kind`-child boundary. Child-local Vault processes remain explicitly UNVERIFIED.

## Sprint 75.2: Geo-replication of two siblings + invariant-confluence classification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 75.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`chaos_failover_second_axis.md §16`](../documents/engineering/chaos_failover_second_axis.md#16-the-second-axis--when-one-cluster-becomes-a-forest)/[`§17`](../documents/engineering/chaos_failover_second_axis.md#17-the-boundary-and-its-classifier)
over the confluent data plane of
[`content_addressing_doctrine.md §5`](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely):
wire asynchronous geo-replication between two siblings and run the invariant-confluence test (R1) on every
crossing mutable invariant *before* assigning a mechanism — so content-addressed blobs and the work-id-keyed
Pulsar log cross freely, while the gateway authority and any CAS "latest" pointer are correctly held in bucket
(ii) for the [Phase 76](phase_76_gateway_migration_drills.md) migration runtime.

### Deliverables

- Pulsar geo-replication (native binary protocol, no WebSockets) between two siblings, with the consumer
  decision a **pure fold keyed by a replication-surviving work-id** that absorbs duplication, reordering, and
  late-after-heal arrival (R3 cross-boundary).
- Content-addressed write-once MinIO blob replication (idempotent duplicate cross-cluster write) and Patroni
  Postgres replication for relational state.
- A `ConfluenceClass` value per crossing invariant — confluent (deterministic total merge) vs non-confluent
  (control-plane daemon claim/yield, escrow/reservation, or disjoint-namespace allocation) — with the unclassified default
  = non-confluent, rejecting an "active-active on a non-confluent invariant" wiring.

### Validation

1. A workflow round-trips between the two siblings; replaying a duplicate or reordered batch produces the same
   fold result and identical blob keys against a separately authored Haskell content-address expectation
   ([Gate integrity](#gate-integrity)). The classifier's output is checked against an independent Haskell
   classification table rather than its own re-derivation; any serialized view is generated lazily beneath
   `.build/test-corpora/**`. An unclassified invariant defaults to non-confluent,
   and the classifier refuses active-active on a non-confluent invariant; the applied Haskell changed-subject
   `classifier-default-confluent` mutant ([Gate integrity](#gate-integrity)) — which flips the unclassified default to confluent — wrongly
   admits the unclassified fixture and the classification oracle goes red; the forest tears down leak-free by
   the OS-boundary observer of [Gate integrity](#gate-integrity), retained backing stores exempt.

### Remaining Work

No work remains for the retained HA data-plane boundary sealed here. Physically independent child-local
Pulsar brokers are UNVERIFIED and must not be inferred from this phase.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/cluster_lifecycle_doctrine.md` — §3/§9 gain the realized module paths for the spawn,
  the `project(subtree)` handoff, and the reconciler/registry (the teardown-vs-chaos distinction and push-back
  land with [Phase 76](phase_76_gateway_migration_drills.md)).
- `documents/engineering/vault_pki_doctrine.md` — §6/§7 gain the realized per-child Transit-key and
  secret-injection module paths (prodbox's transit-seal tree remains the evidence, not the proof).
- `documents/engineering/content_addressing_doctrine.md` — §5 gains the realized cross-cluster idempotent-write
  path (identical content ⇒ identical key) as a live datapoint.
- `documents/engineering/chaos_failover_doctrine.md` — §16/§17 gain the realized invariant-confluence classifier
  and the amoebius-tested linux-cpu Second-Axis boundary; cross-reference the realized `Multicluster/*` module
  paths.
- `documents/engineering/pulumi_iac_doctrine.md` — record the child-cluster spawn program and its
  Vault-enveloped MinIO backend as realized spawn owners.
- `documents/engineering/testing_doctrine.md` — record the Register-3 spawn + geo-replication live-gate ledger
  this phase emits.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-75 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/system_components.md` — register the `src/Amoebius/Multicluster/Spawn.hs`,
  `GeoReplication.hs`, `ConfluenceClass.hs`, `ChildUnseal.hs`, `SecretInjection.hs` modules,
  `src/Amoebius/Vault/TransitChildKey.hs`, `src/Amoebius/Dsl/ChildInForceSpec.hs`, and the spawn + geo-replication
  gate suites as Phase-75 rows.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-75 → linux-cpu row in the per-phase substrate map.

## Related Documents

- [README.md](README.md) — the live tracker; Phase 75 objective, gate, and substrate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — target architecture and the one-formal-obligation constraint
- [system_components.md](system_components.md) — target component inventory (the `Multicluster/*` module paths)
- [substrates.md](substrates.md) — substrate registry and per-phase map
- [Chaos & Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the invariant-confluence Second Axis and the proven/tested/assumed cross-boundary ledger
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — amoebic spawning and the reconciler/registry
- [Vault, PKI & Secret Injection Doctrine](../documents/engineering/vault_pki_doctrine.md) — parent/child unseal + per-child Transit keys + secret injection
- [Pulumi IaC Doctrine](../documents/engineering/pulumi_iac_doctrine.md) — exact in-cluster executor and Vault-enveloped checkpoint resource demands
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md) — the confluent, content-addressed cross-boundary data plane
- [phase_74](phase_74_network_fabric_wireguard.md) — the prior phase (the WireGuard fabric); its gate opens this one
- [phase_76](phase_76_gateway_migration_drills.md) — the next phase; the gateway-migration runtime and correspondence over this forest
- [phase_77](phase_77_provider_deploy_checkpoint.md) — the forest extended to provider-managed clusters
