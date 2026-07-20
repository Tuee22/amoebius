# The No-Cluster Conformance Harness

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_09_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_10_chain_kernel_dryrun.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_12_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_13_spa_composition_representational.md, DEVELOPMENT_PLAN/phase_16_renderer_reconciler.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/test_derivation_analysis.md
**Generated sections**: none

> **Purpose**: Single source of truth for the discipline that lets amoebius validate the overwhelming majority
> of its behaviour **before any cluster exists** — the pre-cluster conformance spine that exercises
> decode → bind/expand → plan/resolve infrastructure → provision → `renderAll` → plan → dry-run end to end in Registers 1 and 2, and the
> load-bearing invariant that **rendering a plan must never require live infrastructure**.

---

## 1. Why this doctrine exists

A deployment system is tempting to treat as untestable without the thing it deploys — the position that the
manifests cannot be known correct until a cluster admits them. Taken at face value that defers almost all
validation to the one setting that is slowest, most expensive, and least reproducible — a live cluster — and
leaves the design unverifiable until late.

That framing is false for amoebius because amoebius's behaviour is, by construction, **a pure value that is
rendered**: the reconcile plan is `chain :: cfg -> [Step]`, the manifests are
deployment-global `renderAll :: ProvisionedSpec -> [K8sObject]`, the DSL is decoded and then fully provisioned against its
target by total functions, and the formal model is a `Model` value. Everything up to the point of *applying*
an effect is a pure function of committed source plus an explicit authenticated observation fixture; no
pure test contacts infrastructure. The sibling projects already prove
this at scale — prodbox validates ~940 behaviours in a pure, no-process suite plus byte-for-byte dry-run
goldens, with a single thin IO seam.

Amoebius adopts that as a rule: **build so that decode → bind/expand → `planInfrastructure` → either
golden-lock the non-renderable infrastructure batch or supply its authenticated materialization fixture →
provision → `renderAll` → plan → dry-run is exercised in-process and golden-locked before any
live-infrastructure work, for every feature.** What this forecloses is
a design whose correctness is unknown until a cluster is stood up; the cluster is reserved for the residue that
genuinely requires it (that pods schedule, that the LB comes up, that a partition heals).

The register *definitions* — Pure, Boundary-integration, Test-`.dhall`-topology — are owned by
[testing_doctrine.md §2](./testing_doctrine.md#2-three-registers-of-amoebius-testing). This document owns the
**pre-cluster spine**: how Registers 1 and 2 are composed into a conformance harness, and the invariant that
keeps them honest.

---

## 2. The registers, as amoebius uses them for pre-cluster validation

Naming the three registers (definitions owned by [testing_doctrine.md §2](./testing_doctrine.md#2-three-registers-of-amoebius-testing)):

- **Register 1 — pure / golden (no cluster, no processes).** DSL decode and every illegal-state foreclosure the
  decoder enforces; whole-deployment `renderAll` and the correctness of the emitted objects (a hardened `securityContext`, a route
  from a live service handle, a derived NetworkPolicy — golden-tested on the *rendered* output); the `[Step]`
  plan and its `--dry-run`; the capability→provider→shape binder; the capacity/topology folds; the formal
  `Model` explorer + the emitted `.tla` checked by TLC ([formal_model_doctrine.md](./formal_model_doctrine.md));
  the representational SPA composition.
- **Register 2 — boundary integration with fakes (no cluster).** The real amoebius binary run with fake
  `helm`/`kubectl`/`docker`/`pulumi` (or a fake interpreter over the `[Step]`/effect data) that record their
  argv and applied bytes, asserting the exact commands and manifests — plus the demo SPAs run locally against a
  faked backend, driven end to end.
- **Register 2.5 — deterministic simulation (no cluster).** The *real* daemon/reconciler code, lifted onto
  `io-classes`, run under `IOSim`/`IOSimPOR` against a modeled, fault-injectable environment (fake
  Pulsar/MinIO/apiserver/route53/Vault/clock) — concurrent schedules and injected partition/reorder/redelivery/
  crash, deterministically replayable. This exercises the daemon's real *schedule* under faults, which Registers
  1 and 2 structurally cannot reach; owned by
  [deterministic_simulation_doctrine.md](./deterministic_simulation_doctrine.md) (register definition in
  [testing_doctrine.md §2](./testing_doctrine.md#2-three-registers-of-amoebius-testing)).
- **Register 3 — live infrastructure only.** The residue that cannot be settled by inspecting source or by
  simulation: the apiserver admitting and the scheduler placing pods, the LoadBalancer coming up, etcd forming
  quorum, a VM interposing, a broker offloading, geo-replication lag, DNS propagation, chaos/partition healing —
  and that the real substrates behave as Register 2.5 models them.

The conformance harness is Registers 1, 2, and 2.5. Register 3 is the acceptance gate of each live phase, not
part of the harness.

## 3. The load-bearing invariant: rendering never touches live infrastructure

**Rendering a plan, a manifest set, a `--dry-run`, or a `.tla` MUST NOT require, contact, or depend on live
infrastructure.** A render is a pure function of committed source and completes in-process with no apiserver, no
cloud credentials, no broker, no Vault. This is the invariant that makes Register 1 possible at all, and the
sibling prodbox enforces it explicitly ("rendering a plan must not require live infrastructure — `charts
reconcile --dry-run` renders without a cluster"). Prerequisite checks (is a cluster reachable, are credentials
present) belong on the *apply* path, never the *render* path.

Two consequences follow directly:

- The `--dry-run` preview is **byte-for-byte** what a live apply would submit, because both consume the same
  rendered value ([generated_artifacts_doctrine.md](./generated_artifacts_doctrine.md)); the preview is a golden
  fixture of the renderer, not a committed artifact.
- A large share of the illegal-state catalog is caught here, not at runtime: the **rendered-output-golden**
  validation locus ([illegal_state_catalog.md](../illegal_state/illegal_state_catalog.md)) — an unsafe manifest is not a value
  `renderAll` can return, and a golden test over the emitted objects proves it without a cluster.

---

<a id="4-the-spine-decode--validate--render--plan--dry-run"></a>

## 4. The spine: decode → bind/expand → plan/resolve infrastructure → provision → `renderAll` → plan → dry-run

For every feature, the harness exercises the full pure pipeline and locks it:

1. **Decode** — an authored `InForceSpec` fixture passes Gate 1 (`dhall type`) and Gate 2 (the total decoder),
   or a negative fixture is rejected at its tagged locus.
2. **Bind and source-expand** — capability/provider/shape selection emits every app/init/sidecar, standard
   platform service, volume/cache owner, and accelerator need into one `BoundDeployment`. Each ordinary
   runnable remains an unprovisioned `BoundExecutionUnit` with stable id/revision and arm-specific
   cardinality/rollout; no replica/per-node identity or epoch is materialized yet.
3. **Plan or resolve infrastructure** — `planInfrastructure` derives the exact demand from that
   `BoundDeployment` and the declared standalone supply or forest budget. `InfrastructureRequired` yields one
   non-renderable `ProvisionedInfrastructurePlan` whose `ProvisionedProviderActionBatch` owns the closed
   cloud-provider/SSH-host actions, Pulumi graph, checkpoints, dependencies, concurrency, and
   cloud-quota/SSH-child-budget partition; those bytes are golden-locked. The Kubernetes branch supplies a
   committed authenticated-materialization fixture (including a consumed receipt for the required-plan case),
   constructing the exact `ProvisionContext`; the explicit already-materialized arm covers fixtures needing
   no initial provider or SSH-host mutation.
4. **Provision** — topology/distinctness, placement, reservation/finite-limit/physical-peak,
   named-storage-pool, quota,
   accelerator, and per-device-memory folds first materialize exact source/revision/ordinal
   `MaterializedExecutionInstance`s and every planned steady/rollout `ExecutionEpoch`, each keyed by
   `PlannedExecutionSlotId`. A separate normalized-observation fixture algebra is keyed by
   `ObservedExecutionId = PodUid | HostProcessInstanceId | HostReservationId`; it never turns live UIDs or
   ledger-only host reservations into planned slots. Provision derives one model-pinned
   `KubeletRuntimeMetadataDemand` per applicable planned or observed identity and then runs over the complete
   expansion. Failure returns a structured `Left`; success alone constructs the opaque whole
   `ProvisionedSpec` and its sealed identity-keyed `ProvisionedRenderSourceSet`.
5. **`renderAll`** — the sole public manifest function,
   `renderAll :: ProvisionedSpec -> [K8sObject]`, privately total-maps that equal-keyed source set; a golden
   test pins the complete typed
   object set byte-for-byte and asserts the by-construction safety properties on the output. The root-ledger
   CAS state and Lease holder/renewal state are absent from the generic SSA projection and remain typed-action
   fields. `renderAll` contains all four `RenderActivation` classes; the plan preserves their disjoint
   identity partition so later-stage objects are visible in desired output without becoming early-stage apply
   actions.
6. **Plan** — `chain` receives a checked plan config containing the whole `ProvisionedSpec`, produces the
   `[Step]` value, and `--dry-run` renders it; a golden test pins the plan.
7. **Fake apply (Register 2)** — the binary runs the plan against fake tools; the recorded commands and applied
   bytes are asserted.
8. **Simulate (Register 2.5)** — where a feature carries real concurrency (a reconcile loop, a failover
   takeover, a dedup fold), the real code runs under `IOSim`/`IOSimPOR` against the modeled faulty environment,
   asserting its invariants under injected schedules and faults ([deterministic_simulation_doctrine.md](./deterministic_simulation_doctrine.md)).

Nothing in steps 1–8 requires a cluster. The single IO seam (the step that would actually invoke a real tool or
the real apiserver) is the only thing deferred to Register 3 — and even its *behaviour under faults* is
exercised against modeled substrates in step 8, so what Register 3 uniquely adds is **fidelity** (that the real
substrates behave as modeled), not first exposure.

---

## 5. Honesty: what the harness does and does not establish

Per [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)
and [chaos_failover_doctrine.md](./chaos_failover_doctrine.md):

- A green harness proves the spec **decodes, fully expands, produces the exact infrastructure plan or validates
  its materialization fixture, provisions, renders coherently, and produces an
  exact plan** — the
  spec-composition and rendered-output layers.
- It proves **nothing** about whether the physical effects converge (Register 3). A green harness is quoted as
  "decodes + provisions + renders coherently + plan is exact," never as "the cluster is correct."
- A green **Register 2.5** run proves the *real code upholds its invariants under the modeled schedules and
  faults* — a genuinely stronger claim than the fake-tool boundary — but says **nothing** about whether the real
  Pulsar/apiserver/route53 behave as modeled; that fidelity is an assumed premise, discharged by a narrow
  Register-3 conformance check ([deterministic_simulation_doctrine.md §5](./deterministic_simulation_doctrine.md#5-what-dst-establishes-and-the-one-premise-it-buys)).
- The blindness between registers is load-bearing: a green Register-1 suite says nothing about what Register 3
  would find, a fake-tool Register-2 run says nothing about a real broker's behaviour, and a green Register-2.5
  run says nothing about whether the modeled broker matches the real one.

---

## 6. Planning ownership

This document is normative only. The harness is stood up across the pre-cluster phases; each live phase adds its
Register-3 gate. Phase order, status, and gates live only in
[DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md); the requirement that every phase's ledger records
which register it reached is owned by [development_plan_standards.md](../../DEVELOPMENT_PLAN/development_plan_standards.md).
Every statement here is design intent, never a tested amoebius result.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Testing Doctrine](./testing_doctrine.md) — owns the three-register definitions ([§2](./testing_doctrine.md#2-three-registers-of-amoebius-testing))
- [Generated Artifacts Doctrine](./generated_artifacts_doctrine.md) — why the render is pure and its output uncommitted
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — `renderAll` and the reconcile/apply seam
- [Formal Model Doctrine](./formal_model_doctrine.md) — the in-process `Model` explorer that mirrors TLC
- [Illegal State Catalog](../illegal_state/illegal_state_catalog.md) — the rendered-output-golden validation locus
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
