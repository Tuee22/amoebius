# Phase 9: Capacity core fold + topology relation

> **Purpose**: Deliver the pure base-capacity fold and compute-engine/topology relation that refuse
> overcommitted or incompatible placements before any host or cluster exists.
> **Read this if**: Phase 9 is the open contract, or a later phase consumes its base placement witness.

Phase 9 owns CPU, memory, logical pod-ephemeral, pod-slot, CSI-slot, eligibility, and fixed/elastic placement
over declared capacity. Storage geometry and execution/accelerator/provider-root expansion belong to Phases 28
and 29; live inventory and scheduling belong to the live band.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/substrate_node_inventory.md, documents/engineering/testing_doctrine.md, documents/illegal_state/illegal_state_catalog.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 9.1: Base capacity and topology witness ✅](#sprint-91-base-capacity-and-topology-witness-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. The eleven-sided gate passed on natural `arm64`, untranslated: fifteen exact
negative/twin folds, two constructed placement positives, seven compiler pairs, four coverage-bound
properties, and all nineteen mutants passed. All fourteen metrics matched and 25 surfaces joined completely.
Attestation `sha256:1e30df2732e6d8075017d84ac061c64850adedc8919919b5f00396cb164acf86` binds source
`sha256:014a86815113e09e…` over 2,149 files.

**Phase-26 integration regression — 2026-08-21.** Phase 26 made this library the sole owner of
`Amoebius.Capacity.{Types,Fold}` and `Amoebius.Dsl.Topology`, relocating the three modules beneath
`src/capacity-topology/` without changing their API. This entire gate was rerun after the move: all eleven
sides remained green at attestation `sha256:35d089fb2dcc3f521b2e25ecbf5614879f9a6d805f6a98971bf0df00a9fa0bd3`,
bound to source `sha256:df8136496ef04daa…` over 2,260 files.

## Phase Summary

This phase provides total `fits`, `podFits`, `carve`, and `place` folds over a closed base resource vector and
a closed `ComputeEngine`/`Topology` relation. A placement result carries either a fixed-node assignment
witness or a bounded elastic growth envelope; incompatible engines, hosts, quotas, taints, and resource axes
return structured errors.

**Phase scope:** One Register-1 base capacity/topology decision kernel, accepted by
`python3 tools/capacity_topology_gate.py`; split if work adds physical storage, execution epochs,
accelerators, provider roots, a live inventory, a second register, or a substrate.
**Substrate:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 1 — pure/golden
**Depends on:** [Phase 3](phase_03_artifact_calculus.md) — its artifact recipes provide the demands that later
consumers size with this index; the scope index is orthogonal and is not imported.
**Gate:** `python3 tools/run_phase_gate.py 09` passes the committed representative corpus, independent
compatibility and placement predicates, exact compiler pairs, coverage floors, all mutants, catalogue join,
ledger, and universal artifact-hygiene checks described in [Gate integrity](#gate-integrity).

## Gate integrity

- **Representative set:** fifteen isolated fold negatives with fifteen distinct legal twins; two constructed
  and placed positive topologies; a complete 3×3 engine/environment matrix; and seven Haskell compiler pairs.
- **Oracle provenance:** the fold, compatibility, and compiler expectations predate this reconciliation and
  are committed independently of the current run. The retained Dhall cases belong to Phase 25 and are not
  consumed here. Expected values are not regenerated from observed failures.
- **Independent predicates:** `referenceCompatibility` is distinct from `engineAcceptsEnvironment`.
  `validatePlacement` recomputes resource, slot, CSI-deduplication, and topology obligations without calling
  `place`; five validator mutants prove those axes matter.
- **Specific negatives:** each fold row asserts its exact structured error and names one legal twin. Each
  compiler negative has a positive twin and pins text identifying the intended type barrier.
- **Generator coverage:** four QuickCheck properties cover both accepted and rejected inputs at 30% or more.
  Infinite-domain properties are `TESTED (sampled)`; only the finite 3×3 compatibility matrix is exhausted.
- **Totality:** exhaustive-pattern warnings are errors, and source scans reject partial tokens in
  `Amoebius.Capacity.{Types,Fold}` and `Amoebius.Dsl.Topology`.
- **Catalogue join:** the gate reads eleven `Phase-9` rows, discharges the eight pure-fold/GADT loci, and marks
  three Dhall-typecheck loci deferred to Phase 25. Storage, execution/accelerator/provider-root, binding,
  render, model, and runtime surfaces remain `UNVERIFIED`.
- **Seeded mutants:** nineteen registry rows weaken one fold, compatibility, eligibility, quota, storage,
  witness, or independent-validator axis. Every selected mutant must fail with its own red token.
- **Fresh challenge, authenticated observer, authority pairing, and bypass probes:** not applicable to a pure
  in-process arithmetic phase. No runtime or external enforcement claim is inferred.
- **Extension conformance (§M.13).** Not applicable because this phase supplies a core index, not a domain,
  provider, or hardware extension.

The gate establishes finite-table agreement, sampled arithmetic properties, compiler barriers, and a separate
witness validation. It does not establish live allocatable truth, kubelet accounting, actual placement,
autoscaler behavior, or provider correspondence.

## Doctrine adopted

- [`resource_capacity_doctrine.md` §1 — capacity is a budget the fold consumes](../documents/engineering/resource_capacity_doctrine.md#1-capacity-is-a-budget-the-fold-consumes-and-overcommit-is-a-checked-rejection): demand admission returns a witness or a structured refusal.
- [`resource_capacity_doctrine.md` §2 — the load-bearing honesty limit](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed): pure capacity arithmetic is a checked decision, never proof of live enforcement.
- [`resource_capacity_folds.md` §4 — the total fold](../documents/engineering/resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting): base vectors nest through total fit, carve, and placement operations.
- [`resource_capacity_folds.md` §4.1 — place branches](../documents/engineering/resource_capacity_folds.md#41-place-branches-static-proves-a-placement-dynamic-proves-a-growth-envelope): fixed supply returns assignments while elastic supply returns a quota-bounded envelope.
- [`cluster_topology_doctrine.md` §2 — ComputeEngine](../documents/engineering/cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm): Kind, rke2, and managed EKS form the closed engine set.
- [`cluster_topology_doctrine.md` §5 — the compatibility relation](../documents/engineering/cluster_topology_doctrine.md#5-the-compatibility-relation-technique-47-only-compatible-pairs-have-a-constructor): the finite engine/environment relation rejects incompatible pairs.
- [`testing_doctrine.md` §9 — generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): runtime surface enumeration joins to separately authored expected decisions.

## Sprints

## Sprint 9.1: Base capacity and topology witness ✅

**Status**: Done
**Implementation**: the `capacity-topology` Cabal library, `src/capacity-topology/Amoebius/Capacity/{Types,Fold}.hs`, `src/capacity-topology/Amoebius/Dsl/Topology.hs`,
`test/spec/dsl/CapacityTopology{Fixtures,Props,Mutants,Gate,Spec}.hs`,
`test/spec/dsl/capacity_topology_compile_fail/**`, `test/oracle/capacity_topology/**`, and
`tools/capacity_topology_{compile_fail,gate}.py`.
**Blocked by**: None.
**Independent Validation**: Fifteen fold twins, nine compatibility cells, and seven compiler pairs supply
authored expectations. Four coverage-bound properties, a separate witness validator, and nineteen mutants
exercise generalized and weakened implementations.
**Docs to update**: `documents/engineering/{cluster_topology_doctrine,resource_capacity_doctrine,resource_capacity_folds,substrate_node_inventory,testing_doctrine}.md` and `documents/illegal_state/illegal_state_catalog.md`.

### Objective

Adopt [`resource_capacity_folds.md` §4 — the total fold](../documents/engineering/resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting)
and [`cluster_topology_doctrine.md` §5 — the compatibility relation](../documents/engineering/cluster_topology_doctrine.md#5-the-compatibility-relation-technique-47-only-compatible-pairs-have-a-constructor): return a checked witness only for base demands that fit compatible supply.

### Deliverables

- A closed base resource vector with explicit request, limit, reserve, headroom, slot, and logical ephemeral axes.
- Total fit and zero-capable subtraction operations with stable axis-specific errors.
- Fixed-node placement assignments and bounded elastic growth-envelope witnesses.
- A closed compute-engine, host-environment, node-supply, and topology compatibility model.
- Fifteen exact fold negative/twin pairs and two positive topology cases.
- Seven Haskell specific-reason compiler pairs.
- Four coverage-bound properties with a separately implemented placement validator.
- Nineteen registry-backed mutants and an eight-current/three-deferred validation-locus join.
- A contained Register-1 gate with architecture, source-snapshot, ledger, surface, and attestation evidence.

### Validation

1. Require all fifteen fold cases to return their exact errors and every distinct legal twin to succeed.
2. Construct and place both positive topologies; exhaust all nine compatibility pairs against the independent
   relation; validate every returned witness through `validatePlacement`.
3. Compile each Haskell legal twin and reject its illegal twin at the pinned reason.
4. Meet both-direction coverage floors for all four properties and require all nineteen mutations, including
   five validator weakenings, to turn red at their declared loci.
5. Join all eleven Phase-9 catalogue subcases, requiring eight discharged and three Phase-25 deferrals; join
   every test surface, keep output generated, and bind the result to the natural architecture and snapshot.

### Remaining Work

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/resource_capacity_doctrine.md` and `resource_capacity_folds.md` — record the current pure fold result and preserve the runtime residue.
- `documents/engineering/cluster_topology_doctrine.md` — record the finite compatibility and placement result without claiming a node join.
- `documents/engineering/substrate_node_inventory.md` — distinguish authored capacity fixtures from live inventory observation.
- `documents/engineering/testing_doctrine.md` — retain sampled-versus-exhausted honesty and exact catalogue ownership.
- `documents/illegal_state/illegal_state_catalog.md` — record the eleven Phase-9 loci and their bounded evidence.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md`, `overview.md`, and `system_components.md` — reconcile status, sequence, and concrete paths.
- `DEVELOPMENT_PLAN/phase_10_calculus_composition.md` — consume the sealed resource index before composition.
- `DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md` and `phase_29_execution_accelerator_folds.md` — retain the physical and expanded-vector seams.

## Related Documents

- [Development Plan Standards](development_plan_standards.md) — the phase and gate contract.
- [Gate Integrity](development_plan_gate_integrity.md) and [Phase Model](development_plan_phase_model.md) — universal gate and sequencing rules.
- [Development Plan Tracker](README.md) — numeric order and current status.
- [Overview](overview.md) — the algebra-band architecture.
- [Artifact Calculus](phase_03_artifact_calculus.md) — the demand-producing algebra this index sizes.
- [GADT Decode](phase_26_gadt_decode_ir.md) and [Illegal-State Covering](phase_27_illegal_state_covering.md) — later schema and catalogue consumers.
- [Storage Geometry](phase_28_storage_geometry_folds.md) and [Execution/Accelerator Folds](phase_29_execution_accelerator_folds.md) — later capacity-vector extensions.
- [Capability Bind](phase_30_capability_bind.md) and [Provision Seal](phase_31_provision_seal.md) — later whole-deployment consumers.
- [Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — the authoritative capacity model and honesty limit.
- [Capacity Folds](../documents/engineering/resource_capacity_folds.md) — the detailed total arithmetic.
- [Cluster Topology Doctrine](../documents/engineering/cluster_topology_doctrine.md) — engine, host, topology, and compatibility ownership.
- [Budget Doctrine](../documents/engineering/jit_budget_doctrine.md) — the bounded budget that later capacity projections consume.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — Register-1 and derivation discipline.
- [Illegal-State Catalog](../documents/illegal_state/illegal_state_catalog.md) — catalogue ownership and validation loci.
- [Illegal-State Capacity](../documents/illegal_state/illegal_state_capacity.md), [Security](../documents/illegal_state/illegal_state_security.md), [Storage](../documents/illegal_state/illegal_state_storage.md), [Techniques](../documents/illegal_state/illegal_state_techniques.md), and [Topology](../documents/illegal_state/illegal_state_topology.md) — the foreclosed states and reusable mechanisms consumed by the corpus.
