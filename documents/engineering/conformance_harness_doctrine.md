# The No-Cluster Conformance Harness

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_09_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_10_chain_kernel_dryrun.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_12_spa_composition_representational.md, DEVELOPMENT_PLAN/phase_15_renderer_reconciler.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/lift_and_compose_doctrine.md
**Generated sections**: none

> **Purpose**: Single source of truth for the discipline that lets amoebius validate the overwhelming majority of its behaviour **before any cluster exists** — the pre-cluster conformance spine that exercises decode → validate → render → plan → dry-run end to end in Registers 1 and 2, and the load-bearing invariant that **rendering a plan must never require live infrastructure**.

---

## 1. Why this doctrine exists

A deployment system is tempting to treat as untestable without the thing it deploys: "you cannot know the
manifests are right until a cluster admits them." Taken at face value that defers almost all validation to the
one setting that is slowest, most expensive, and least reproducible — a live cluster — and leaves the design
unverifiable until late.

That framing is false for amoebius because amoebius's behaviour is, by construction, **a pure value that is
rendered**: the reconcile plan is `chain :: cfg -> [Step]`, the manifests are `render :: ServiceSpec ->
[K8sObject]`, the DSL is decoded by a total function, and the formal model is a `Model` value. Everything up to
the point of *applying* an effect is a pure function of committed source. The sibling projects already prove
this at scale — prodbox validates ~940 behaviours in a pure, no-process suite plus byte-for-byte dry-run
goldens, with a single thin IO seam.

Amoebius adopts that as a rule: **build so that decode → validate → render → plan → dry-run is exercised
in-process and golden-locked before any live-infrastructure work, for every feature.** What this forecloses is
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
  decoder enforces; `render` and the correctness of the emitted objects (a hardened `securityContext`, a route
  from a live service handle, a derived NetworkPolicy — golden-tested on the *rendered* output); the `[Step]`
  plan and its `--dry-run`; the capability→provider→shape binder; the capacity/topology folds; the formal
  `Model` explorer + the emitted `.tla` checked by TLC ([formal_model_doctrine.md](./formal_model_doctrine.md));
  the representational SPA composition.
- **Register 2 — boundary integration with fakes (no cluster).** The real amoebius binary run with fake
  `helm`/`kubectl`/`docker`/`pulumi` (or a fake interpreter over the `[Step]`/effect data) that record their
  argv and applied bytes, asserting the exact commands and manifests — plus the demo SPAs run locally against a
  faked backend, driven end to end.
- **Register 3 — live infrastructure only.** The residue that cannot be settled by inspecting source: the
  apiserver admitting and the scheduler placing pods, the LoadBalancer coming up, etcd forming quorum, a VM
  interposing, a broker offloading, geo-replication lag, DNS propagation, chaos/partition healing.

The conformance harness is Registers 1 and 2. Register 3 is the acceptance gate of each live phase, not part of
the harness.

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
  `render` can return, and a golden test over the emitted objects proves it without a cluster.

---

## 4. The spine: decode → validate → render → plan → dry-run

For every feature, the harness exercises the full pure pipeline and locks it:

1. **Decode** — an authored `InForceSpec` fixture passes Gate 1 (`dhall type`) and Gate 2 (the total decoder),
   or a negative fixture is rejected at its tagged locus.
2. **Validate** — the decode-time folds (capacity, topology, distinctness, structural-fit) return `Left` on the
   illegal fixtures and `Right` on the legal ones.
3. **Render** — `render` emits the typed object set; a golden test pins it byte-for-byte and asserts the
   by-construction safety properties on the output.
4. **Plan** — `chain` produces the `[Step]` value; `--dry-run` renders it; a golden test pins the plan.
5. **Fake apply (Register 2)** — the binary runs the plan against fake tools; the recorded commands and applied
   bytes are asserted.

Nothing in steps 1–5 requires a cluster. The single IO seam (the step that would actually invoke a tool or the
apiserver) is the only thing deferred to Register 3.

---

## 5. Honesty: what the harness does and does not establish

Per [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)
and [chaos_failover_doctrine.md](./chaos_failover_doctrine.md):

- A green harness proves the spec **decodes, validates, renders coherently, and produces an exact plan** — the
  spec-composition and rendered-output layers.
- It proves **nothing** about whether the physical effects converge (Register 3). A green harness is quoted as
  "decodes + renders coherently + plan is exact," never as "the cluster is correct."
- The blindness between registers is load-bearing: a green Register-1 suite says nothing about what Register 3
  would find, and a fake-tool Register-2 run says nothing about a real broker's behaviour.

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
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — `render` and the reconcile/apply seam
- [Formal Model Doctrine](./formal_model_doctrine.md) — the in-process `Model` explorer that mirrors TLC
- [Illegal State Catalog](../illegal_state/illegal_state_catalog.md) — the rendered-output-golden validation locus
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
