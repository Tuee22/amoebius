# Workflow Calculus Doctrine

> **Purpose**: Single source of truth for the **workflow calculus** — provision, build, deploy, observe, and
> teardown as arms of one algebra rather than five unrelated activities; teardown as a *type obligation* the
> other arms cannot discharge on their own; test-as-workflow, so a test is a deployment with an assertion; and
> the self-referential suite, in which amoebius's own gates are workflows expressed in the same algebra.
> **Read this if**: something has to happen to a running system, or a test's relationship to a deployment has
> to be reasoned about.

This document owns the workflow calculus. The concrete lifecycle mechanics it abstracts — the reconciler, the
readiness discipline, the release gate, the register model — are owned by their own doctrines and referenced
rather than restated.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_06_workflow_calculus.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, documents/engineering/README.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/jit_budget_doctrine.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

## Contents
- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. Five arms, one algebra](#2-five-arms-one-algebra)
- [3. Teardown is a type obligation](#3-teardown-is-a-type-obligation)
- [4. A test is a workflow with an assertion](#4-a-test-is-a-workflow-with-an-assertion)
- [5. The self-referential suite](#5-the-self-referential-suite)
- [6. What the calculus does not decide](#6-what-the-calculus-does-not-decide)
- [7. Planning ownership](#7-planning-ownership)
- [Related Documents](#related-documents)

---

## 1. Why this doctrine exists

Provisioning, building, deploying, observing, and tearing down are usually five separate systems: a
provisioner, a build pipeline, a deployment tool, a monitoring stack, and a cleanup script somebody wrote once.
They share no vocabulary, so nothing can state a property that spans them — and the properties that matter
almost all span them. That a deployed thing is observed. That a built artifact is charged to a budget. That a
provisioned resource is eventually released.

The cleanup script is the tell. It is separate precisely because nothing forces it to exist, so it is written
late, tested rarely, and quietly diverges from what the other four actually created. The orphaned volume and
the abandoned load balancer are usually that defect: teardown was an activity rather than an obligation.

Not always, and the difference matters because this calculus forecloses only the one class. An orphan also
arises when the process dies between the provider creating a resource and the program recording that it did,
and when the provider's own delete call fails. Those are crash and failure classes, addressed in
[§6](#6-what-the-calculus-does-not-decide), and no type discipline reaches them.

So the five are arms of one algebra over one vocabulary. That is what lets teardown be *derived* from what the
other arms did, rather than written alongside them.

---

## 2. Five arms, one algebra

A **workflow** is a value describing a change to a running system, and it has five arms:

- **Provision** — bring a declared resource into existence, yielding a handle that witnesses it.
- **Build** — materialize the artifacts the change needs, against a grant
  ([`jit_artifact_doctrine.md`](./jit_artifact_doctrine.md)).
- **Deploy** — move a system from one declared state to another, which the reconciler enacts
  ([`cluster_lifecycle_doctrine.md`](./cluster_lifecycle_doctrine.md)).
- **Observe** — read the system's actual state, producing evidence rather than a log line.
- **Teardown** — return what provision and build caused to exist.

The arms compose in the usual two ways: in sequence, where each consumes the previous one's witnesses, and in
parallel, where two workflows over disjoint resources may interleave. Both are typed. A sequence whose second
arm needs a witness the first does not produce has no inhabitant, which is how the readiness discipline stops
being a matter of ordering by hand ([`readiness_ordering_doctrine.md`](./readiness_ordering_doctrine.md)) — a
dependency is an argument, not a wait.

The two indices thread through unchanged. A workflow runs at a scope, and everything it provisions and builds
belongs to that scope; a workflow holds grants, and everything it materializes is charged against them.

---

## 3. Teardown is a type obligation

This is the arm the algebra exists for.

**Provision returns two things.** A handle to the resource, and a **teardown obligation** — a value that is
discharged only by tearing that resource down. The obligation is not optional, not defaulted, and not
discardable, and the mechanism is a linear obligation: the value has no discard rule, so it must be consumed
exactly once, and a workflow ending while it still holds one is rejected at compile time. The target shape is
an outstanding-obligation type index — a set of resource names that `provision` adds to and only `teardown`
and `transfer` remove — with a runner that accepts only a workflow whose set is empty at both ends. There is no
combinator that shrinks the set another way. Separately authored Haskell compile-fail cases cover a workflow
that ends owing, a transfer without its condition, and a discharge of an obligation the workflow never held;
current delivery and validation remain in the plan.
This is the same shape as a region that ends holding an unreaped artifact
([`jit_artifact_doctrine.md` §5](./jit_artifact_doctrine.md#5-materialize-consume-reap)).

**Discharging it is a choice between two things, not an option to skip.** Either the workflow tears the
resource down before it ends, or it *transfers* the obligation to something longer-lived — a retained
declaration whose own teardown will discharge it, with a stated condition. Transferring is explicit and
recorded; what has no constructor is ending with the obligation simply dropped.

**Teardown is therefore derived, never authored.** The obligations a workflow accumulated *are* the teardown
plan, so there is nothing to keep in sync and nothing to forget. A resource that was provisioned is a resource
whose release is already typed; a resource nobody can find later is not a thing the calculus can produce.

**The residue is honest and specific.** A provider can fail to delete something amoebius asked it to delete,
and the obligation is discharged from amoebius's side while the resource persists. That is a `live-effect`
check — an independent observation that the thing is gone — and it is the reason teardown assertions appear in
live gates rather than being assumed from the types
([`testing_spoof_resistance.md`](./testing_spoof_resistance.md)).

---

## 4. A test is a workflow with an assertion

A test that deploys something is a deployment. Pretending otherwise produces the two failure modes every
integration suite has: a test path that differs from the production path, so the test proves nothing about
production; and test resources that outlive the test, because the cleanup was a fixture rather than an
obligation.

Under this calculus a test *is* a workflow, in the same algebra, with an observation arm whose evidence is
compared against an expectation. Three things follow:

- **The test path is the production path.** There is one deploy arm. A test cannot take a shortcut through it,
  because there is no second one to take.
- **Test resources are torn down by construction.** The test workflow accumulates the same obligations, so it
  cannot end holding one. A leaked test namespace is not a discipline problem; it is a program that does not
  compile.
- **A test declares its scope and its budget** like any other workflow, so a suite cannot exhaust a shared
  substrate by being a suite.

This is the mechanical form of the position [`testing_doctrine.md` §1](./testing_doctrine.md#1-a-test-is-an-amoebius-spec)
already takes — that a test is a deployment — and this document owns the algebra rather than restating the
argument.

---

## 5. The self-referential suite

amoebius's own gates are workflows in this algebra. A phase gate provisions what it needs, builds what it
tests, deploys, observes, asserts, and tears down; the evidence it seals is the observation arm's output
([`conformance_harness_doctrine.md`](./conformance_harness_doctrine.md)).

The self-reference is deliberate and it earns two things. The calculus is exercised by every gate run, so a
defect in it surfaces in amoebius's own validation before it reaches an extension. And the gates become
inspectable values: what a gate does is derivable from its declaration, which is what allows a gate to be
*generated* from an extension's conformance obligations rather than written by the extension's author
([`extension_conformance_doctrine.md` §5](./extension_conformance_doctrine.md#5-the-conformance-gate-is-generated-not-authored)).

The risk of self-reference is equally real and is named here rather than left implied: a calculus that validates
itself can be consistently wrong. An independent oracle and a few mutants do not close that shared-trust gap.
The gate representation is therefore only a subject. The separately authored Haskell validation kernel first
rejects the fixed qualification sabotage corpus, observes every applied production mutation, and then compares
clean workflow execution with raw external observations. The complete qualified gate pass is sufficient to
record the candidate as Done
([`testing_spoof_resistance.md`](./testing_spoof_resistance.md)).

[Phase 49](../../DEVELOPMENT_PLAN/phase_49_self_referential_gates.md) is the target integrated instance. It
routes the complete hardware-free DSL pipeline through the workflow value after the separately authored
kernel freezes the claim. It does not execute a retained Python command, wrap a supplied exit code, consume a
checked-in command inventory, or seal its own verdict. All serialized declarations, observations, and mutation
worktrees are generated lazily beneath `.build/**`.

---

## 6. What the calculus does not decide

- **It does not decide what to deploy.** The declared desired state is the DSL's business
  ([`dsl_doctrine.md`](./dsl_doctrine.md)); the calculus is about how a change to it happens.
- **It does not replace the reconciler.** Deploy is one arm; how convergence to a declared state actually
  proceeds, including failure and retry, is owned by
  [`cluster_lifecycle_doctrine.md`](./cluster_lifecycle_doctrine.md).
- **It does not make an observation true.** Evidence is only as good as the observer, and an observer inside
  the system under test is worth less than one outside it.
- **It does not survive a crash.** A type-level obligation is discharged within one program run. A `SIGKILL`
  between the provider creating a resource and the program recording the obligation leaks a real resource with
  nothing in the type system to prevent it, and no amount of linearity closes the window — the record and the
  provider-side effect are two writes to two systems. Foreclosing this needs a durable intent log written
  *before* the provider call and reconciled after a restart, which is the reconciler's shape rather than the
  calculus's ([`cluster_lifecycle_doctrine.md`](./cluster_lifecycle_doctrine.md)). Until a phase delivers it,
  crash-orphaned resources are a `live-effect` residue that this calculus does not reduce.
- **It does not make a clean run sufficient by itself.** A workflow value, typed teardown, routed consumer,
  qualification run, and evidence bundle remain candidate observations until every required qualified-gate row
  passes; status lives in the [tracker](../../DEVELOPMENT_PLAN/README.md).

---

## 7. Planning ownership

This document is normative only. Which phase delivers the workflow value, the five arms, the teardown
obligation, and the self-referential gate is owned by
[DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md). All numbered phases are presently NOT
VALIDATED; this doctrine contains no current tested instance.

---

## Related Documents
- [Engineering Doctrine Index](./README.md)
- [Extension Conformance Doctrine](./extension_conformance_doctrine.md) — the obligation surface an extension's workflow component fills, and the generated gate [§5](#5-the-self-referential-suite) makes possible
- [JIT Artifact Doctrine](./jit_artifact_doctrine.md) — the build arm's artifacts and the region whose exit reaps them
- [JIT Budget Doctrine](./jit_budget_doctrine.md) — the grants a workflow holds
- [Cluster Lifecycle Doctrine](./cluster_lifecycle_doctrine.md) — the reconciler the deploy arm delegates to
- [Readiness Ordering Doctrine](./readiness_ordering_doctrine.md) — why a dependency is an argument rather than a wait
- [Evidence Calculus Doctrine](./evidence_calculus_doctrine.md) — the evidence calculus, and the independence test a self-referential gate has to answer
- [Testing Doctrine](./testing_doctrine.md) — the register model and the independent-oracle discipline
- [Testing Spoof Resistance](./testing_spoof_resistance.md) — the independent observation that a teardown actually happened
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — the harness amoebius's own gates run in
- [Monitoring Doctrine](./monitoring_doctrine.md) — the observe arm's standing obligations
- [Release Lifecycle Doctrine](./release_lifecycle_doctrine.md) — the promotion gate a deploy arm may demand
- [DSL Doctrine](./dsl_doctrine.md) — the declared state a workflow moves the system toward
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
