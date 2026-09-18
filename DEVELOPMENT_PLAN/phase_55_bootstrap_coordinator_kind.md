# Phase 55: Haskell substrate coordinator + single kind cluster

> **Purpose**: Define the first live cluster claim after the hardware-free DSL barrier: the Haskell binary
> observes one `linux-cpu/amd64` host, preflights declared capacity, and idempotently reconciles one empty
> single-node kind cluster.
> **Read this if**: Phase 55 is next in numeric order or a later live phase depends on its cluster boundary.

This phase never expands `pb`: `pb validate phase 55` only ensures, builds, and replaces itself with the
Haskell binary. Substrate detection, planning, tool resolution, effects, observation, and candidate verdict
are Haskell responsibilities. The live gate remains forbidden until the DSL barrier (Phase 9) and every intervening phase have
separate gate passs.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/resource_capacity_sources.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision](#resource-provision)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 55.1: Substrate observation and classification](#sprint-551-substrate-observation-and-classification-)
- [Sprint 55.2: Pure kind preflight and reconcile plan](#sprint-552-pure-kind-preflight-and-reconcile-plan-)
- [Sprint 55.3: Live single-node reconciliation](#sprint-553-live-single-node-reconciliation-)
- [Sprint 55.4: Independent observation, replay, and teardown](#sprint-554-independent-observation-replay-and-teardown-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Gate execution is held shut by the predecessor's receipt in certification generation 2; the generation-2 reset is
recorded in [DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice).

Gate execution remains blocked by the qualified Phase-54 predecessor and its compatible evidence chain.
Live effects also require the preceding named barriers in [the phase model](development_plan_phase_model.md#l-one-substrate-discipline).

## Phase Summary

The target Haskell coordinator must consume only the host and tool capabilities supplied by future
gate-passed predecessor phases. It must classify one real `linux-cpu/amd64` substrate from raw observations,
compare declared kind-engine and node demand with observed capacity, render a run-local configuration beneath
`.build/**`, and reconcile one empty
kind cluster. A repeat run must observe an empty diff, while deliberately damaged but repairable state must
produce a bounded repair plan rather than a second cluster. No registry, platform service, workload, storage
service, secret service, GPU claim, or provider deployment is in scope.

**Phase scope:** one cohesive claim — the Haskell binary safely and idempotently reconciles one capacity-compatible empty kind cluster on one natural `linux-cpu/amd64` host; split if a second substrate, cluster, or platform service is required.
**Substrate:** `linux-cpu`
**Lane:** `linux-cpu/amd64`
**Register:** 3
**Depends on:** [Phase 54](phase_54_windows_engine_bringup.md)
**Gate:** `pb validate phase 55`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — the replacement certification generation, protected accepted baseline,
authenticated phase receipt, and current compatibility closure are Haskell-owned inputs. Execution evidence
remains phase-local and cannot be supplied by this prose.

| Key | Contract |
|---|---|
| `Claim` | On one natural `linux-cpu/amd64` host, `amoebius apply --executor real` applies a corpus deployment from the DSL barrier's union corpus to one marker-owned single-node kind cluster: the subject rejects incompatible declarations before mutation, reconciles the empty cluster to the applied deployment, and `kubectl get -o json`, compared by the oracle, equals the Phase-3 rows for that example. The real-apply input digest equals the Phase-3 fake-apply digest. Live platform workloads, registries, storage services, and multi-node clusters are excluded. |
| `Subject` | `Amoebius.Substrate.observe`, `Amoebius.Cluster.Kind.preflight`, `plan`, and `reconcile` in `src/Amoebius/Cluster/Kind.hs`, plus the real executor arm of `Amoebius.Kernel.Interpret`; every subject is inside the closure of `executable amoebius`, and the runner owns the cluster's lifecycle. |
| `Command` | Future public spelling is `pb validate phase 55`, admissible only while binding the Phase-50 receipt. The agent runs `amoebius-validate preview phase 55`; then `amoebius-validate accept --phase 55` records the receipt and applies one phase's status patch. The runner spawns the shipped binary for `apply --executor real` with a corpus example and owns the kind cluster from creation through destruction. |
| `Oracle` | `test/oracle/cluster/Main.hs` compares `kubectl get -o json` with the Phase-3 rows for the corpus example and states the expected preflight refusals, reconcile plans, and teardown ledger from literals; it depends on no `amoebius` library. |
| `Positive controls` | Closed Haskell values for one fitting declaration, already-converged state, stopped-node repair, and missing-context repair, with exact plans and observations independently pinned. Live success requires one Ready node and no platform workload. |
| `Paired negatives` | Minimally different declarations cover CPU, memory, node storage, engine reserve, backing identity, architecture, and forbidden accelerator mismatch; each must refuse at its named preflight locus with zero cluster mutation. |
| `Mutants` | Runner-generated from the fixed operator catalogue over `Amoebius.Cluster.Kind` and `Amoebius.Substrate`, eight per module, at most forty per gate, kill ratio at least 0.6. A mutant that skips preflight, uses a bare executable name, turns reconcile into create-only, ignores a damaged node, or suppresses a diff is killed at its assigned observation while unrelated controls stay green; no authored mutant seam exists. |
| `Discovery` | Expected cluster/container/context/resource sets are derived independently and compared in both directions with live discovery. Empty, partial, duplicate, or extra discovery refuses the candidate. |
| `Challenge` | After initial convergence the harness introduces one run-local, named repairable divergence selected after startup; the same subject must observe and repair it, then re-observe an empty diff. |
| `Observer` | An outside observer reads raw process execution, container identity/state, kind membership, kubeconfig bytes, node readiness/capacity, writes, and owned residue; subject-emitted summaries are not authoritative. |
| `Authority/bypass` | All external tools are invoked through the prior Haskell `AbsExe` boundary. Bare-name, alternate socket/context, foreign-cluster, over-capacity, direct-create, and `pb`-implemented behavior probes must fail at distinct loci. |
| `Freshness` | Use a fresh `.build/**` run root and a marker-owned cluster identity bound to the current source, contract, predecessor receipt, host observation, and run challenge. Stale kubeconfig, observations, plans, or evidence are unusable. |
| `Qualification` | The generated-mutant matrix precedes the clean candidate in the same run; the runner refuses a candidate whose matrix misses the kill ratio before any live mutation begins. |
| `Cleanroom` | Begin with generated outputs absent and no owned cluster. Generate configuration, cases, plans, and observations lazily beneath one `.build/**` run root; refuse repository-retained generated behavioral transport material and writes beside source. |
| `Legacy closure` | `LTD-RUN-001` closes here through the compiled inventory: exactly one product executable identity and no obsolete runtime identity are discovered, and the second-product-stanza reintroduction is refused. The due-count for every other identifier is zero. |
| `Predecessor` | The Phase-54 receipt in certification generation 2, chained by the digest of Phase 54's product closure plus the verifier and governance digests, and the DSL-barrier (Phase 9) receipt digest bound as the corpus source. |
| `Residue` | `UNVERIFIED`: multi-node clusters, platform workloads, registries, storage services, providers, and every later live phase; the Apple and Windows routes remain their own phases. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run on the declared substrate, the applied bytes equal the Phase-3 rows, cleanup reports zero owned residue, and `accept` records it. |

## Resource provision

> The typed `ResourceProvisionContract` binds these seven labels to the Phase-55 subject and the runner's
> observer. They are gate-ready contract terms, not evidence that the still-open gate has passed.

- **Owner marker:** a run-local Haskell value binds the cluster name, container runtime endpoint, kubeconfig,
  source snapshot, predecessor receipt, and run identifier.
- **Preflight:** all declared demand must be checked against raw host observations before a mutating cluster command.
- **Allowed mutations:** one marker-owned kind cluster, its one node container, and its run-local kubeconfig.
- **Forbidden mutations:** foreign clusters/contexts, platform workloads, registries, storage services, host paths
  outside the declared run root, and any mutation following a failed preflight.
- **External observer:** an outside Haskell supervisor reads raw engine, process, cluster, node, context, and
  filesystem state before, during, and after the run; subject logs and self-reported deletion are not evidence.
- **Scoped cleanup:** on success, failure, interruption, or ambiguous outcome, teardown targets only resources
  bound to the exact owner marker and never a wildcard, current context, or foreign cluster.
- **Zero-owned-residue:** the outside observer requires the marker-owned cluster, node container, kubeconfig,
  processes, mounts, volumes, networks, and run paths to be absent; this phase declares no retained resource
  and makes no claim that unrelated host state disappeared.

## Doctrine adopted

- [`substrate_doctrine.md` §2 — Detection: a pure classification over three reads](../documents/engineering/substrate_doctrine.md#2-detection-a-pure-classification-over-three-reads) supplies the raw-observation boundary; all classification and decisions remain Haskell.
- [`cluster_lifecycle_doctrine.md` §2 — bring-up and bootstrap](../documents/engineering/cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap) supplies reconcile, re-observe, and idempotence semantics.
- [`cluster_lifecycle_doctrine.md` §9 — How bring-up and teardown are implemented: the reconciler, not a state machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine) supplies discovery, diff, enactment, and bounded repair.
- [`resource_capacity_doctrine.md` §8 — Where the numbers come from: declared in pure input, provisioned before render, cross-checked at runtime](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime) supplies the pre-mutation capacity comparison.
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence) supplies harness qualification, changed-subject proof, outside observation, and qualified-gate pass.

## Sprints

## Sprint 55.1: Substrate observation and classification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Substrate/Observe.hs`, `src/Amoebius/Substrate/Classify.hs`
**Blocked by**: [Phase 54](phase_54_windows_engine_bringup.md) gate pass
**Requires**: `natural-linux-cpu-amd64-host`
**Independent Validation**: A separately authored Haskell decision table checks every closed OS/architecture/accelerator cell; paired reason-specific negatives and a changed-classifier mutant must fail without cluster effects.
**Oracle**: planned `test/Amoebius/Substrate/ClassifyOracle.hs`; separate authorship unresolved
**Legacy IDs**: `LTD-RUN-001`
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Turn raw host reads into one typed substrate result without `PATH`, environment, Python, or cluster mutation.

### Deliverables

- Haskell raw-observation adapter and pure classifier.
- Closed, independently authored classification table.
- Reason-specific negatives and an applied changed-subject mutant.

### Validation

Qualify the Haskell harness, exercise the complete table, demonstrate the production mutant changed the
intended branch and reddened its oracle row, and prove the observer saw zero cluster mutation.

### Remaining Work

Implement the subject and oracle, assign source snapshot integrity, and obtain complete gate execution. No live run is allowed.

## Sprint 55.2: Pure kind preflight and reconcile plan ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Cluster/Kind/Preflight.hs`, `src/Amoebius/Cluster/Kind/Plan.hs`
**Blocked by**: Sprint 55.1
**Independent Validation**: Haskell oracles compare exact plans for absent, converged, and repairable states; one-field capacity negatives refuse at named loci, and skip-preflight/create-only mutants redden while unaffected cases stay green.
**Oracle**: planned `test/Amoebius/Cluster/Kind/PlanOracle.hs`; separate authorship unresolved
**Legacy IDs**: `LTD-RUN-001`
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/cluster_lifecycle_doctrine.md`

### Objective

Make capacity refusal, discovery, diff, and bounded repair pure Haskell values before any live effect.

### Deliverables

- Complete declared-demand and observed-capacity comparison.
- Closed reconcile plan algebra for absent, converged, and named repairable states.
- Exact no-mutation refusals for every capacity dimension.

### Validation

Run only the qualified hardware-free Haskell seam here; compare exact values with the independent oracle and
require applied mutation witnesses. This sprint does not create a cluster.

### Remaining Work

Implement and independently check the pure seam and close every unresolved contract field.

## Sprint 55.3: Live single-node reconciliation ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Cluster/Kind/Reconcile.hs`
**Blocked by**: Sprint 55.2
**Requires**: `disposable-linux-cpu-amd64-host`
**Independent Validation**: The Haskell subject reconciles one marker-owned cluster while an outside observer proves absolute-path effects, zero mutation on rejected preflight, one Ready node, no platform workload, and a changed bypass mutant turning red.
**Oracle**: planned `test/Amoebius/Cluster/Kind/LiveOracle.hs` plus outside observer; exact run binding unresolved
**Legacy IDs**: `LTD-RUN-001`
**Docs to update**: `documents/engineering/cluster_lifecycle_doctrine.md`

### Objective

Interpret the accepted plan against one disposable host without widening resource ownership.

### Deliverables

- Marker-bounded Haskell effect interpreter.
- One empty single-node kind cluster.
- Raw outside observations of effects and resulting state.

### Validation

Only after all blockers clear, run positive and paired-negative cases against the same qualified harness and
retain raw observer data. A self-authored trace or command exit code cannot discharge the claim.

### Remaining Work

Resolve the subject, outside observer, oracle independence, and disposable-host procedure. Hardware execution is forbidden
at the current status.

## Sprint 55.4: Independent observation, replay, and teardown ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Cluster/Kind/Observe.hs`, `src/Amoebius/Cluster/Kind/Teardown.hs`
**Blocked by**: Sprint 55.3
**Independent Validation**: Outside observation proves exact discovery, empty-diff replay, selected divergence repair without recreation, scoped teardown, and zero owned residue; no-op-observer and skip-cleanup mutants must fail.
**Oracle**: planned `test/Amoebius/Cluster/Kind/LifecycleOracle.hs` plus outside observer; exact run binding unresolved
**Legacy IDs**: `LTD-RUN-001`
**Docs to update**: `documents/engineering/cluster_lifecycle_doctrine.md`

### Objective

Prove that convergence is repeatable, repair is real, and ownership-bounded cleanup is observable outside the
subject.

### Deliverables

- Independent expected/discovered set comparison.
- Post-start divergence challenge and non-recreating repair.
- Marker-scoped teardown and external residue report.

### Validation

Require non-empty two-way discovery, byte/identity-stable replay where specified, an applied divergence
challenge, observed cleanup, and changed-subject/observer mutants before a candidate bundle can exist.

### Remaining Work

Implement and independently check the observer and teardown seam; obtain the complete gate result for the complete
Phase-55 candidate. Until then this phase remains NOT VALIDATED.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/substrate_doctrine.md` — reconcile raw observation and Haskell classification.
- `documents/engineering/cluster_lifecycle_doctrine.md` — reconcile kind ownership, replay, repair, and teardown.
- `documents/engineering/resource_capacity_doctrine.md` — reconcile declared-versus-observed preflight.

**Cross-references to add:**

- [README.md](README.md) — keep the Phase 55 title, blockers, and status synchronized.
- [substrates.md](substrates.md) — retain the one `linux-cpu/amd64` Register-3 lane.
- [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) — close `LTD-RUN-001` only after its Haskell predicate and reintroduction negatives pass and the complete gate passes.

## Related Documents

- [Development-plan tracker](README.md)
- [Development-plan standards](development_plan_standards.md)
- [Phase 9](phase_09_dsl_barrier.md)
- [Phase 54 Windows engine bring-up](phase_54_windows_engine_bringup.md)
- [Substrate doctrine](../documents/engineering/substrate_doctrine.md)
- [Cluster lifecycle doctrine](../documents/engineering/cluster_lifecycle_doctrine.md)
- [Resource-capacity doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
