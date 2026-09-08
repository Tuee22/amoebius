# The No-Cluster Conformance Harness

> **Purpose**: Define the hardware-free Haskell harness that validates the complete DSL pipeline before any
> host, image, registry, cluster, accelerator, or cloud work may open.
> **Read this if**: a language, generator, planner, renderer, or dry-run claim must be validated without using
> later infrastructure as a proxy.

This document owns the pre-hardware spine and its gate barrier. Register definitions belong to
[`testing_doctrine.md`](./testing_doctrine.md); gate qualification and gate pass belong to the
[development-plan gate standard](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/validation_frame_doctrine.md, documents/engineering/workflow_calculus_doctrine.md
**Generated sections**: none

</details>

## Contents

- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. The registers, as amoebius uses them for pre-cluster validation](#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
- [3. The load-bearing invariant: rendering never touches live infrastructure](#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
- [4. The spine: decode → legality → bind/expand → plan/resolve → provision → `renderAll` → plan → dry-run → fake apply](#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply)
- [5. The pre-hardware gate barrier](#5-the-pre-hardware-gate-barrier)
- [6. Honesty: what the harness does and does not establish](#6-honesty-what-the-harness-does-and-does-not-establish)
- [7. Planning ownership](#7-planning-ownership)
- [Related Documents](#related-documents)

## 1. Why this doctrine exists

**The problem.** A language can appear complete while its integrated test exercises a second implementation
that merely reports the names of the production stages. A successful cluster or accelerator run cannot expose
that missing semantic connection.

**Why the obvious alternative fails.** Separately green component tests and a nine-row pipeline report do not
show that the actual decoder output reaches the binder, renderer, planner, and effect boundary. Comparing
matching labels leaves constant stages and ignored inputs undetected.

**The rule.** The hardware-free harness must invoke the real production entry points and pass their typed
outputs into their real consumers. Independent expectations cover the complete declared language surface and
its required compositions. Live phases later test provider fidelity and physical effects.

**What it forecloses.** A surrogate pipeline, stage count, generated success report, or live deployment cannot
substitute for this integration. The result remains bounded by its explicit cases, models, and assumptions;
covering the declared language does not prove every program correct.

The tracked source boundary is closed. Product, DSL, generator, test, oracle, fake, and harness logic is
Haskell. `pb/**` exists only to ensure/build/exec the binary. Any Dhall, PureScript, JavaScript, shell, Proto,
Pulumi program, manifest, fixture, golden, inventory, or other serial form used by the harness is generated
when consumed beneath `.build/**`. Operator-authored runtime input is external data, not repository source.

---

## 2. The registers, as amoebius uses them for pre-cluster validation

The conformance harness uses two final registers and one supporting activity:

- **Register 1** runs the real Haskell value pipeline with separately authored Haskell semantic oracles. It
  uses no live service, container, registry, cluster, credential, or hardware-specific tool.
- **Register 2** runs the real Haskell binary against fake effect boundaries observed outside the subject. The
  fakes record argv, request bytes, ordering, and cleanup; they do not decide the expected behaviour.
- **Register 2.5** may run real concurrent Haskell code under a deterministic modeled environment. It is a
  supporting activity, never a phase's final register and never evidence of real-provider fidelity.

Register 3 is deliberately absent. Live infrastructure is the residue tested by later phases only after the
pre-hardware gate barrier passes.

A compiler or model checker invoked as a deterministic tool does not by itself make a run Register 2. What
matters is the claim: a fake standing in for an effect boundary is Register 2; a pure semantic check remains
Register 1. Neither register requires `amoebius-base` or any other published image.

---

## 3. The load-bearing invariant: rendering never touches live infrastructure

Decode, legality, bind/expand, infrastructure planning, provision from explicit observations, `renderAll`,
plan construction, and `--dry-run` must complete without contacting a container engine, registry, cluster,
provider, broker, Vault, DNS authority, GPU, or other live service.

Every ambient fact is either:

1. an authored Haskell input to the pure claim;
2. an authenticated observation represented by a Haskell value at a named boundary; or
3. an effect deferred to the apply interpreter and marked `UNVERIFIED` by the pre-hardware result.

No render path probes credentials or availability. The live apply consumes the same rendered value that
dry-run exposes. A later image replay may confirm environmental parity, but it cannot change the
language semantics established here.

---

<a id="4-the-spine-decode--validate--render--plan--dry-run"></a>

## 4. The spine: decode → legality → bind/expand → plan/resolve → provision → `renderAll` → plan → dry-run → fake apply

One cleanroom run exercises every stage, in order, through production entry points:

1. **Decode.** Independent Haskell declarations supply legal and illegal external inputs for the production
   decoder. Production encoding is an additional round-trip subject, never the sole author of decoder inputs.
   Paired negatives pin exact diagnostic code and locus. Required serializations are generated lazily beneath
   `.build/**` without importing the production encoder into the expectation.
2. **Legality.** The decoded value passes the complete illegal-state and extension-law checks. Each
   unrepresentability claim has a minimally different positive/compile-fail pair, and runtime refusals have
   exact tags rather than generic failure.
3. **Bind and expand.** Capability, provider, shape, identity, service, storage, and accelerator declarations
   expand into the closed bound vocabulary. The oracle independently enumerates the expected semantic facts;
   it does not reuse the binder's fold.
4. **Plan or resolve infrastructure.** Demand, supply, provider actions, dependencies, concurrency, and
   materialization requirements become an explicit Haskell plan. A non-renderable requirement remains typed
   as such; no live probe resolves it during rendering.
5. **Provision.** Explicit, authenticated observation values satisfy the plan and produce the opaque
   provisioned specification. Missing, stale, mismatched, over-capacity, or foreign observations are paired
   negatives.
6. **`renderAll`.** The sole public renderer maps the complete provisioned specification to semantic objects.
   Separately authored predicates check identity, kind, activation, reconcile mode, safety fields, routes,
   storage, isolation, and completeness. Serialized manifests are lazy `.build/**` outputs only.
7. **Plan.** The production planner consumes the provisioned value and produces the complete ordered effect
   program. A separate Haskell oracle checks operations, dependencies, absolute-tool requirements, and
   teardown obligations.
8. **Dry-run.** The real binary renders that plan without executing effects. The run proves zero effect
   boundary calls through an external observer and checks semantic equality with the plan from step 7.
9. **Fake apply.** The same plan runs through observed fake boundaries. Fresh challenges, exact argv/request
   observations, paired failures, bypass probes, and cleanup show which effects the binary attempted. This
   establishes boundary protocol, not live-provider fidelity.

Every edge carries the preceding stage's actual output. The harness must reject replacement with an empty,
constant, stale, foreign, or independently reconstructed value, even if the next stage and final report retain
their expected names. A separately declared pipeline type is insufficient without this production connection.

Discovery reconciles the independent obligation set with constructors, legality families, capability/provider
and shape arms, folds, render classes, plan operations, and generated-language consumers. It includes required
interactions between those dimensions. Filtering discovery to a preselected file list cannot establish that
an omitted production arm has no obligation.

Each meaningful stage decision and connection has an applied production mutation. The unchanged expectation
must observe the assigned semantic difference downstream while unrelated controls remain green. Mutating only
a report label, test-side branch, counter, or disconnected stage copy does not challenge the production path.

The run uses the isolated namespace and authenticated read-only inputs defined by
[validation_frame_doctrine.md](./validation_frame_doctrine.md#4-generated-output-and-cleanroom-execution).
It derives all candidate products lazily, records actual inputs, and refuses unlisted generated fallbacks.
Production `.data/**` is neither an input nor a cleanup target.

---

## 5. The pre-hardware gate barrier

[Phase 49](../../DEVELOPMENT_PLAN/phase_49_self_referential_gates.md) owns the integrated no-hardware barrier.
Its candidate is admissible only when one qualified Haskell harness run demonstrates all nine stages from an
isolated generated tree and joins the complete earlier DSL/capability surface in both directions. Nine stage
names are navigation labels; they do not define the semantic coverage set.

The barrier additionally requires:

- qualification against constant-success, no-op, wrong-output, empty-discovery, missing-oracle, skipped/no-op
  mutant, stale-evidence, self-observer, bypass, and residue sabotage;
- separately authored Haskell oracles for every stage with recorded provenance;
- a subject-change witness and intended red locus for every required mutant;
- explicit `UNVERIFIED` live/runtime residue;
- zero active legacy findings owned by Phases 0–49; and
- one complete qualified pass bound to the source, contract, harness, and raw observations.

The self-referential workflow representation is itself a subject of this barrier. It must agree with the
independently authored runner under clean and sabotaged cases; only the complete qualified barrier result may
set Done status.

The language target includes generated artifacts consumed outside Haskell. Their required syntax, compilation,
and semantic correspondence must be checked against the actual generated products at their assigned owners.
Undefined browser bindings, bare identifier lists, and placeholder recipes cannot satisfy an executable
projection claim merely because their files are deterministic.

Moving an obligation between phases preserves its identity, coverage, and barrier deadline under the
[phase-amendment rule](../../DEVELOPMENT_PLAN/development_plan_phase_model.md#n-reopening-and-amending-a-phase).
Real device effects may remain later-owned. Pure interpreter semantics, generated-source validity, or a missing
production connection cannot be relabelled hardware fidelity to remove them from this barrier.

Later gate execution remains blocked until the barrier and immediate predecessors pass. Hardware-free
implementation preparation follows the separate numerical-frontier rules in the plan. A successful container build,
registry push/pull, host setup, accelerator calculation, kind cluster, or live deployment cannot substitute
for or backfill this barrier.

---

## 6. Honesty: what the harness does and does not establish

A qualified passing barrier establishes that the connected production pipeline produced independently expected
semantic values and boundary requests for its declared corpus and source snapshot. It also establishes the
observed mutation sensitivity, harness refusals, and cleanup. Each claim retains its actual evidence strength.

It does not establish:

- that a live API admits or enforces the generated requests;
- that a provider, cluster, network, storage system, browser, or accelerator behaves as modeled;
- correctness beyond the tested oracle and corpus;
- future repeatability or another architecture; or
- that the compiler, kernel, or test environment is uncompromised.

Formal evidence follows
[formal_model_doctrine.md](./formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not).
Type rejection, finite model proof, sampled testing, and tested model/code correspondence remain distinct.
Shared model names or fixture counts establish none of those connections by themselves.

Unreached applicable layers remain `UNVERIFIED`; environmental fidelity is an explicit assumption until its
owning gate observes it. Hardware work adds fidelity evidence and never upgrades an omitted language claim.

---

## 7. Planning ownership

This doctrine owns the target pipeline. The
[development-plan tracker](../../DEVELOPMENT_PLAN/README.md) owns the validation reset, dated implementation
audit, current status, and remaining work. This document makes no current gate-pass claim.

The bootstrap seed remains finite. The complete language corpus and universal harness qualification are
barrier obligations, not prerequisites recursively imposed on Phase 0. After a qualified gate and exact
status-only update, automated work continues in numerical order without an intermediate approval ritual.

---

## Related Documents

- [Testing doctrine](./testing_doctrine.md)
- [Testing spoof resistance](./testing_spoof_resistance.md)
- [Evidence calculus](./evidence_calculus_doctrine.md)
- [Generated artifacts doctrine](./generated_artifacts_doctrine.md)
- [Validation execution doctrine](./validation_frame_doctrine.md)
- [Development-plan phase model](../../DEVELOPMENT_PLAN/development_plan_phase_model.md)
- [Development-plan gate integrity](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md)
