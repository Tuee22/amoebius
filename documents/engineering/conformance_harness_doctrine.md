# The No-Cluster Conformance Harness

> **Purpose**: Define the hardware-free Haskell harness that validates the complete DSL pipeline before any
> host, image, registry, cluster, accelerator, or cloud work may open.
> **Read this if**: a language, generator, planner, renderer, or dry-run claim must be validated without using
> later infrastructure as a proxy.

This document owns the pre-hardware spine and its promotion barrier. Register definitions belong to
[`testing_doctrine.md`](./testing_doctrine.md); gate qualification and human promotion belong to the
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
- [4. The spine: decode → legality → bind/expand → plan/resolve → provision → renderAll → plan → dry-run → fake apply](#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply)
- [5. The pre-hardware promotion barrier](#5-the-pre-hardware-promotion-barrier)
- [6. Honesty: what the harness does and does not establish](#6-honesty-what-the-harness-does-and-does-not-establish)
- [7. Planning ownership](#7-planning-ownership)
- [Related Documents](#related-documents)

---

## 1. Why this doctrine exists

A deployment language becomes hard to validate when its first complete execution requires the platform it is
supposed to describe. That dependency invites a dangerous shortcut: a container, cluster, or GPU comes up, so
the language is described as valid even though decode, legality, binding, planning, rendering, or dry-run was
never independently challenged.

amoebius instead makes every pre-effect stage a Haskell value and validates their composition before any
hardware-specific work. The live platform later tests fidelity and real effects; it does not supply first
evidence that the language means what its contract says.

The tracked source boundary is closed. Product, DSL, generator, test, oracle, fake, and harness logic is
Haskell. `pb/**` exists only to ensure/build/exec the binary. Any Dhall, PureScript, JavaScript, shell, Proto,
Pulumi program, manifest, fixture, golden, inventory, or other serial form used by the harness is generated
when consumed beneath `.build/**`. Operator-authored runtime input is external data, not repository source.

---

## 2. The registers, as amoebius uses them for pre-cluster validation

The conformance harness uses two final registers and one supporting activity:

- **Register 1** runs the real Haskell value pipeline with separately reviewed Haskell semantic oracles. It
  uses no live service, container, registry, cluster, credential, or hardware-specific tool.
- **Register 2** runs the real Haskell binary against fake effect boundaries observed outside the subject. The
  fakes record argv, request bytes, ordering, and cleanup; they do not decide the expected behaviour.
- **Register 2.5** may run real concurrent Haskell code under a deterministic modeled environment. It is a
  supporting activity, never a phase's final register and never evidence of real-provider fidelity.

Register 3 is deliberately absent. Live infrastructure is the residue tested by later phases only after the
pre-hardware promotion barrier is human-approved.

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
dry-run exposes. A later image replay may confirm environmental parity, but it cannot change or authorize the
language semantics established here.

---

<a id="4-the-spine-decode--validate--render--plan--dry-run"></a>

## 4. The spine: decode → legality → bind/expand → plan/resolve → provision → `renderAll` → plan → dry-run → fake apply

One cleanroom run exercises every stage, in order, through production entry points:

1. **Decode.** A Haskell-authored source value is encoded through the production codec where serialization is
   part of the contract and decoded through the production entry point. Paired negatives pin exact diagnostic
   code and locus. No checked-in serialized fixture is read.
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
   Independently reviewed predicates check identity, kind, activation, reconcile mode, safety fields, routes,
   storage, isolation, and completeness. Serialized manifests are lazy `.build/**` outputs only.
7. **Plan.** The production planner consumes the provisioned value and produces the complete ordered effect
   program. A separate Haskell oracle checks operations, dependencies, absolute-tool requirements, and
   teardown obligations.
8. **Dry-run.** The real binary renders that plan without executing effects. The run proves zero effect
   boundary calls through an external observer and checks semantic equality with the plan from step 7.
9. **Fake apply.** The same plan runs through observed fake boundaries. Fresh challenges, exact argv/request
   observations, paired failures, bypass probes, and cleanup show which effects the binary attempted. This
   establishes boundary protocol, not live-provider fidelity.

The run starts with `.build/**`, `.data/**`, `.test_data/**`, generated formats, and condemned legacy copies
absent. It generates everything it consumes lazily, records actual read paths, and fails if discovery is empty
or a stage is skipped. Each stage has a changed-production-subject mutant whose applied change is witnessed and
whose named oracle row turns red while unrelated controls stay green.

---

## 5. The pre-hardware promotion barrier

[Phase 49](../../DEVELOPMENT_PLAN/phase_49_self_referential_gates.md) owns the integrated no-hardware barrier.
Its candidate is admissible only when one qualified Haskell harness run demonstrates all nine stages from an
empty generated tree and joins the complete earlier DSL/capability surface in both directions.

The barrier additionally requires:

- qualification against constant-success, no-op, wrong-output, empty-discovery, missing-oracle, skipped/no-op
  mutant, stale-evidence, self-observer, bypass, and residue sabotage;
- separately reviewed Haskell oracles for every stage and recorded reviewer provenance;
- a subject-change witness and intended red locus for every required mutant;
- explicit `UNVERIFIED` live/runtime residue;
- zero active legacy findings owned by Phases 0–49; and
- an external human approval bound to the source, contract, harness, and raw observations.

The self-referential workflow representation is itself a subject of this barrier, not its authority. It must
agree with the independently reviewed runner under clean and sabotaged cases, and neither representation may
promote status.

Phase 50 and all later work remain blocked until the human approval exists. A successful container build,
registry push/pull, host setup, accelerator calculation, kind cluster, or live deployment cannot substitute
for or backfill this barrier.

---

## 6. Honesty: what the harness does and does not establish

A human-approved barrier establishes that, for the reviewed corpus and source snapshot, the complete Haskell
pipeline produced the independently expected semantic values and boundary requests, caught its specified
mutants, refused its sabotage cases, and left no observed residue.

It does not establish:

- that a live API admits or enforces the generated requests;
- that a provider, cluster, network, storage system, browser, or accelerator behaves as modeled;
- correctness beyond the reviewed oracle and corpus;
- future repeatability or another architecture; or
- that compiler, kernel, reviewer, or human approval key is uncompromised.

Those layers remain explicit assumptions or `UNVERIFIED` and are discharged only by their later numerical
owners. Hardware work adds fidelity evidence; it never upgrades an omitted language claim.

---

## 7. Planning ownership

This doctrine is normative. The development plan owns current status and the exact phase contracts. All
numbered phases are presently NOT VALIDATED. Earlier scoped runs, attestations, seals, hashes, or implementation
claims are invalidated and are not current instances of this doctrine.

---

## Related Documents

- [Testing doctrine](./testing_doctrine.md)
- [Testing spoof resistance](./testing_spoof_resistance.md)
- [Evidence calculus](./evidence_calculus_doctrine.md)
- [Generated artifacts doctrine](./generated_artifacts_doctrine.md)
- [Validation execution doctrine](./validation_frame_doctrine.md)
- [Development-plan phase model](../../DEVELOPMENT_PLAN/development_plan_phase_model.md)
- [Development-plan gate integrity](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md)
