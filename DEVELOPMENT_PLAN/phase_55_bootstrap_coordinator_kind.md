# Phase 55: Haskell substrate coordinator + single kind cluster

> **Purpose**: Define the first live cluster claim after the hardware-free DSL barrier: the Haskell binary
> observes one `linux-cpu/amd64` host, preflights declared capacity, and idempotently reconciles one empty
> single-node kind cluster.
> **Read this if**: Phase 55 is next in numeric order or a later live phase depends on its cluster boundary.

This phase never expands `pb`: `pb validate phase 55` only ensures, builds, and replaces itself with the
Haskell binary. Substrate detection, planning, tool resolution, effects, observation, and candidate verdict
are Haskell responsibilities. The live gate remains forbidden until Phase 49 and every intervening phase have
separate human approvals.

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
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 55.1: Substrate observation and classification ⏸️](#sprint-551-substrate-observation-and-classification-)
- [Sprint 55.2: Pure kind preflight and reconcile plan ⏸️](#sprint-552-pure-kind-preflight-and-reconcile-plan-)
- [Sprint 55.3: Live single-node reconciliation ⏸️](#sprint-553-live-single-node-reconciliation-)
- [Sprint 55.4: Independent observation, replay, and teardown ⏸️](#sprint-554-independent-observation-replay-and-teardown-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by the current Phase 54 contract, independent validation, and human approval, plus the exact approval
chain from Phase 0 through Phase 54. In particular, Phase 49's no-hardware DSL promotion receipt is mandatory
before this live gate may start. All earlier Phase-55 pass, seal, evidence, or implementation claims are
permanently invalid for promotion; existing code is an **Observed footprint / Known partial** only.

## Phase Summary

The target Haskell coordinator must consume only the host and tool capabilities supplied by future
human-approved predecessor phases. It must classify one real `linux-cpu/amd64` substrate from raw observations,
compare declared kind-engine and node demand with observed capacity, render a run-local configuration beneath
`.build/**`, and reconcile one empty
kind cluster. A repeat run must observe an empty diff, while deliberately damaged but repairable state must
produce a bounded repair plan rather than a second cluster. No registry, platform service, workload, storage
service, secret service, GPU claim, or provider deployment is in scope.

**Phase scope:** one cohesive claim — the Haskell binary safely and idempotently reconciles one capacity-compatible empty kind cluster on one natural `linux-cpu/amd64` host; split if a second substrate, cluster, or platform service is required.
**Substrate:** `linux-cpu`
**Lane:** `linux-cpu/amd64`
**Register:** 3
**Depends on:** [Phase 54](phase_54_windows_engine_bringup.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 55`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED. The criteria below are the required replacement contract;
production entry points, independent oracle custody, live observer, and human reviewer remain unresolved, so
the command cannot produce an admissible candidate.

| Key | Contract |
|---|---|
| `Claim` | On one natural `linux-cpu/amd64` host, the Haskell subject rejects incompatible declarations before mutation, reconciles exactly one empty single-node kind cluster, repairs named partial states, repeats with an empty diff, and tears down without owned residue. No later platform behavior is claimed. |
| `Subject` | Planned Haskell entry points `Amoebius.Substrate.observe`, `Amoebius.Cluster.Kind.preflight`, `plan`, and `reconcile`; exact production call graph remains `UNRESOLVED` and blocks validation. |
| `Command` | `pb validate phase 55`; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged. The Haskell binary owns discovery, plan, effects, observation, cleanup, and verdict. |
| `Oracle` | A separately authored Haskell capacity/reconcile oracle plus an outside process/resource observer. Module, author, custody boundary, and independent human reviewer are `UNRESOLVED` and block validation. |
| `Positive controls` | Closed Haskell values for one fitting declaration, already-converged state, stopped-node repair, and missing-context repair, with exact plans and observations independently pinned. Live success requires one Ready node and no platform workload. |
| `Paired negatives` | Minimally different declarations cover CPU, memory, node storage, engine reserve, backing identity, architecture, and forbidden accelerator mismatch; each must refuse at its named preflight locus with zero cluster mutation. |
| `Mutants` | Changed-subject operators skip preflight, use a bare executable name, turn reconcile into create-only, ignore a damaged node, suppress a diff, or skip teardown. Applied Haskell-source witnesses and unaffected controls are mandatory. |
| `Discovery` | Expected cluster/container/context/resource sets are derived independently and compared in both directions with live discovery. Empty, partial, duplicate, or extra discovery refuses the candidate. |
| `Challenge` | After initial convergence the harness introduces one run-local, named repairable divergence selected after startup; the same subject must observe and repair it, then re-observe an empty diff. |
| `Observer` | An outside observer reads raw process execution, container identity/state, kind membership, kubeconfig bytes, node readiness/capacity, writes, and owned residue; subject-emitted summaries are not authoritative. |
| `Authority/bypass` | All external tools are invoked through the prior Haskell `AbsExe` boundary. Bare-name, alternate socket/context, foreign-cluster, over-capacity, direct-create, and `pb`-implemented behavior probes must fail at distinct loci. |
| `Freshness` | Use a fresh `.build/**` run root and a marker-owned cluster identity bound to the current source, contract, predecessor receipt, host observation, and run challenge. Stale kubeconfig, observations, plans, or evidence are unusable. |
| `Qualification` | Before live mutation, the same harness must reject the fixed sabotage corpus: constant success, no-op subject, wrong output, empty discovery, missing subject/oracle, skipped/no-op mutant, wrong-locus failure, stale evidence, self-observer, authority bypass, residue, and smuggled generated/legacy input. |
| `Cleanroom` | Begin with generated outputs absent and no owned cluster. Generate configuration, cases, plans, and observations lazily beneath one `.build/**` run root; do not read a tracked generated fixture or write beside source. |
| `Legacy closure` | `LTD-RUN-001` must have zero findings and its second-executable/obsolete-identity reintroduction negatives must fail. The source classifier must also report exact accounting and zero rows owned by Phase 55 or earlier. |
| `Predecessor` | The exact current Phase 54 human approval and full receipt chain, including Phase 49, must verify. No receipt currently exists; this blocks execution and validation. |
| `Residue` | `UNVERIFIED`: all Phase-55 behavior until the contract is implemented and reviewed; every registry, image publication, platform service, storage service, workload, GPU, multi-node, provider, and second-substrate claim remains outside scope. |
| `Human authority` | `human-only`: automation and LLMs may emit a candidate bundle but may not start premature hardware validation, create approval, or mark this sprint/phase Done. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. The seven-label draft below is
> non-operative capability inventory until its Haskell `ResourceProvisionContract`, interpreter, independent
> observer, custody boundary, and human review exist.

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
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence) supplies harness qualification, changed-subject proof, outside observation, and human-only promotion.

## Sprints

## Sprint 55.1: Substrate observation and classification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Substrate/Observe.hs`, `src/Amoebius/Substrate/Classify.hs`
**Blocked by**: Phase 54 human approval
**Requires**: `natural-linux-cpu-amd64-host`
**Independent Validation**: A separately authored Haskell decision table checks every closed OS/architecture/accelerator cell; paired reason-specific negatives and a changed-classifier mutant must fail without cluster effects.
**Oracle**: planned `test/Amoebius/Substrate/ClassifyOracle.hs`; separate author and human reviewer unresolved
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

Implement the subject and oracle, assign independent custody, and obtain human review. No live run is allowed.

## Sprint 55.2: Pure kind preflight and reconcile plan ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Cluster/Kind/Preflight.hs`, `src/Amoebius/Cluster/Kind/Plan.hs`
**Blocked by**: Sprint 55.1 candidate and human sprint review
**Independent Validation**: Haskell oracles compare exact plans for absent, converged, and repairable states; one-field capacity negatives refuse at named loci, and skip-preflight/create-only mutants redden while unaffected cases stay green.
**Oracle**: planned `test/Amoebius/Cluster/Kind/PlanOracle.hs`; separate author and reviewer unresolved
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

Implement and independently review the pure seam and close every unresolved contract field.

## Sprint 55.3: Live single-node reconciliation ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Cluster/Kind/Reconcile.hs`
**Blocked by**: Sprint 55.2 candidate and human sprint review; Phase 49 human approval
**Requires**: `disposable-linux-cpu-amd64-host`
**Independent Validation**: The Haskell subject reconciles one marker-owned cluster while an outside observer proves absolute-path effects, zero mutation on rejected preflight, one Ready node, no platform workload, and a changed bypass mutant turning red.
**Oracle**: planned `test/Amoebius/Cluster/Kind/LiveOracle.hs` plus outside observer; custody unresolved
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

Resolve the subject, outside observer, reviewer, and disposable-host procedure. Hardware execution is forbidden
at the current status.

## Sprint 55.4: Independent observation, replay, and teardown ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Cluster/Kind/Observe.hs`, `src/Amoebius/Cluster/Kind/Teardown.hs`
**Blocked by**: Sprint 55.3 candidate and human sprint review
**Independent Validation**: Outside observation proves exact discovery, empty-diff replay, selected divergence repair without recreation, scoped teardown, and zero owned residue; no-op-observer and skip-cleanup mutants must fail.
**Oracle**: planned `test/Amoebius/Cluster/Kind/LifecycleOracle.hs` plus outside observer; custody unresolved
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

Implement and independently review the observer and teardown seam; obtain the human decision for the complete
Phase-55 candidate. Until then this phase remains NOT VALIDATED.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/substrate_doctrine.md` — reconcile raw observation and Haskell classification.
- `documents/engineering/cluster_lifecycle_doctrine.md` — reconcile kind ownership, replay, repair, and teardown.
- `documents/engineering/resource_capacity_doctrine.md` — reconcile declared-versus-observed preflight.

**Cross-references to add:**

- [README.md](README.md) — keep the Phase 55 title, blockers, and status synchronized.
- [substrates.md](substrates.md) — retain the one `linux-cpu/amd64` Register-3 lane.
- [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) — close `LTD-RUN-001` only after its Haskell predicate and reintroduction negatives pass and the human approves.

## Related Documents

- [Development-plan tracker](README.md)
- [Development-plan standards](development_plan_standards.md)
- [Phase 49 no-hardware DSL barrier](phase_49_self_referential_gates.md)
- [Phase 54 Windows engine bring-up](phase_54_windows_engine_bringup.md)
- [Substrate doctrine](../documents/engineering/substrate_doctrine.md)
- [Cluster lifecycle doctrine](../documents/engineering/cluster_lifecycle_doctrine.md)
- [Resource-capacity doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
