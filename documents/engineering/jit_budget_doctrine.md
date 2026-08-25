# JIT Budget Doctrine

> **Purpose**: Single source of truth for the **budget calculus** — the storage grant as the only thing that
> authorises bytes to exist, the inseparability of a ceiling from the concurrency it is shared across, the
> ephemeral/retained split at the budget seam, and fast admission failure (`admit` / `admitFirst`) that refuses
> before a partial write rather than after a full disk.
> **Read this if**: something is about to write bytes that outlive the process, or a build cache, artifact
> store, or working directory has to be bounded.

This document owns the budget calculus. The capacity vocabulary it folds — how much a substrate has, and how a
cluster's demand is summed against it — is owned by
[`resource_capacity_doctrine.md`](./resource_capacity_doctrine.md) and its family, referenced here and never
restated.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_04_budget_calculus.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_29_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_30_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_32_provision_seal.md, DEVELOPMENT_PLAN/phase_60_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_61_retained_storage.md, DEVELOPMENT_PLAN/phase_63_platform_backbone.md, DEVELOPMENT_PLAN/phase_70_content_store_workflow.md, DEVELOPMENT_PLAN/phase_79_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_80_provider_dynamic_nodes.md, README.md, documents/engineering/README.md, documents/engineering/content_addressing_determinism.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Every phase-run or implementation-result statement in this document is permanently invalidated diagnostic history. It cannot establish or reactivate current status, even if a phase later advances. Target doctrine remains normative; current status is solely in the [tracker](../../DEVELOPMENT_PLAN/README.md).

## Contents
- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. The grant is the authority to exist](#2-the-grant-is-the-authority-to-exist)
- [3. A ceiling is inseparable from its concurrency](#3-a-ceiling-is-inseparable-from-its-concurrency)
- [4. Admission fails first, not last](#4-admission-fails-first-not-last)
- [5. Ephemeral and retained at the budget seam](#5-ephemeral-and-retained-at-the-budget-seam)
- [6. Composition sums, and the sum is checked](#6-composition-sums-and-the-sum-is-checked)
- [7. The residue](#7-the-residue)
- [8. Planning ownership](#8-planning-ownership)
- [Related Documents](#related-documents)

---

## 1. Why this doctrine exists

Nothing in this corpus bounds the build cache. Artifacts are materialized on demand, named by content, and
reused across runs — which is the whole point of a just-in-time discipline — and the type that says how many
of them may exist at once does not appear anywhere. The consequence is not subtle: on a shared substrate the
disk fills, and every extension using that substrate fails simultaneously, including the ones that had used
nothing.

The seed evidence is direct. `jitML` compiles kernels on demand and caches them by content, and its cache has
no type that bounds it — growth is managed operationally, by whoever is watching. That works for one project
with one operator. It does not survive an open core, where the extensions sharing a substrate were written by
people who have never met and each believed their own cache was small.

So the budget is a calculus rather than a setting. A grant is a value that must be *held* before bytes may
exist, its ceiling travels with the concurrency it is shared across, and exceeding it is a refusal at
admission rather than an error at write.

---

## 2. The grant is the authority to exist

A **grant** authorises a quantity of storage, at a location, for a purpose. It is not a number in a
configuration file; it is a value that materialization consumes, and there is no way to produce bytes without
one.

Three properties are load-bearing:

- **It is scarce.** A grant is issued from a finite pool, so two holders cannot both believe they have the last
  gigabyte. Issuing is a fold over the substrate's declared capacity
  ([`resource_capacity_doctrine.md`](./resource_capacity_doctrine.md)), not an assumption about free space.
  Scarcity is a property of **one issuer over one pool**, and it is not a type property: two issuers over one
  pool double-count, and amoebius is multi-cluster by construction. The issuer's consistency model — one per
  pool, and what happens when the process holding it dies mid-issue — is therefore part of this calculus and is
  specified by the phase that delivers it. Nothing here supplies it.
- **It is specific.** A grant for a build cache does not authorise writing a model checkpoint. The location and
  purpose are part of the type, so a grant cannot be spent on the wrong thing by accident, and cannot be
  laundered from one purpose to another.
- **It cannot be forged.** The constructor is not exported; only the issuer can call it. There is no
  "unbounded" constructor and no default, which is what stops the discipline from being switched off by a value
  nobody notices. This is a claim about the module boundary, so it holds exactly as far as the module boundary
  does: the fixture establishing that no other introduction rule exists is owed by the phase that builds the
  budget calculus.

What this forecloses is the state the corpus currently allows everywhere: bytes that exist because a program
wrote them, rather than because something authorised them.

---

## 3. A ceiling is inseparable from its concurrency

A storage ceiling stated alone is meaningless, and this is the part that is easy to get wrong.

"This cache may use 40 GB" is a complete sentence and an incomplete specification. If four workers share it, the
question that decides whether the substrate survives is *how much may be in flight at once* — four
simultaneous materializations of a 15 GB artifact overrun a 40 GB ceiling long before any of them finishes, and
each is individually within budget. The ceiling was never the constraint; the ceiling **and** the concurrency
were, together.

So the grant carries both, as one value. There is no constructor that takes a ceiling without a concurrency
bound, and no way to raise one without restating the other. A materialization takes a slot from the grant's
concurrency and the space for its own worst case, and returns both when it completes or fails.

The same argument is why a per-artifact size bound is part of the grant rather than a property of the recipe: a
recipe that renders more than its grant's per-item bound is refused at admission, so the ceiling cannot be
overrun by one item any more than by many.

---

## 4. Admission fails first, not last

Every operation that would consume budget goes through **admission**, and admission is the only place a
*declared* demand can fail. A demand that exceeds its own declaration fails later, at write; that case is
[§7](#7-the-residue)'s, and it is the exception this section is stated against rather than a second normal
path.

- `admit` takes a grant and a demand and returns either a reservation or a refusal. It performs no work and
  writes no bytes, so a refusal costs nothing and leaves nothing behind.
- `admitFirst` is the same operation over a set of candidate demands, returning the first that fits. It exists
  because the common case is a choice — a smaller variant, a lower precision, a shallower cache — and the
  alternative to expressing that choice is a caller that tries and cleans up.

Failing at admission rather than at write is what makes budget errors *recoverable*. A partial write leaves an
artifact that is neither present nor absent, at an address that now names bytes which are not what the address
claims — the one state content addressing cannot tolerate. A refusal at admission leaves the store exactly as
it was.

Because that state is intolerable rather than impossible, materialization owes a recovery rule and it is stated
here: **an artifact is written to a staging location and moved into its address only once its rendering has
completed**, so a mid-write refusal leaves no bytes at any address a consumer can name, and the abandoned
staging bytes are reaped as ordinary ephemeral garbage
([§5](#5-ephemeral-and-retained-at-the-budget-seam)). Without that rule the address would name a partial
artifact, and every claim in [`jit_artifact_doctrine.md` §4](./jit_artifact_doctrine.md#4-the-address-folds-in-the-rendered-text)
would be false of it.

This is the same shape as the capacity fold's placement witness
([`../illegal_state/illegal_state_techniques.md` §4.6](../illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)):
demand is checked against capacity before the thing exists, and the check produces the witness the operation
requires.

---

## 5. Ephemeral and retained at the budget seam

The artifact calculus distinguishes ephemeral from retained by whether an artifact outlives its region
([`jit_artifact_doctrine.md` §6](./jit_artifact_doctrine.md#6-ephemeral-and-retained)). At the budget seam the
distinction is about *who is holding the space*:

- An **ephemeral** artifact holds its space against the region's grant, and the region's exit returns it. The
  worst case is bounded by the region, so the only budget question is whether the region's ceiling admits its
  peak.
- A **retained** artifact holds space against a retention grant indefinitely, so its budget question is
  different in kind: not "does this fit" but "what returns it". That is the **reaper** — a value stating the
  condition under which the space comes back. An eviction policy, a generation bound, a dependent's lifetime.

A retention grant with no reaper has no constructor. This is the mechanical form of the phrase the corpus
currently carries as prose: *deleted once no longer needed*. Making it a field means the decision is taken when
the artifact is promoted, by the person who knows, rather than discovered later by whoever is paged.

---

## 6. Composition sums, and the sum is checked

C5 (budget additivity) says the grant a composition needs is the sum of its parts'
([`extension_conformance_laws.md` §C5](./extension_conformance_laws.md#c5-budget-additivity)). Two consequences
belong here.

**No part can spend another's headroom.** Grants are held, not shared by convention, so an extension that
under-declared its demand fails at its own admission rather than at a neighbour's. Without this, the first
symptom of one extension's greed is a different extension failing, which is the hardest class of production
problem to diagnose.

**A composition can be refused before it is deployed.** The sum is computable from declarations, so "these six
extensions do not fit on this substrate" is a decision made at composition time. That is the difference between
a capacity model and a capacity hope: the fold is total, so the answer exists for every combination in the link
set, including the ones nobody assembled by hand.

---

## 7. The residue

Stated plainly, because a budget calculus reads as stronger than it is:

- **The filesystem is not under the calculus's control.** Something outside amoebius can fill the disk, and
  every grant remains valid while the space it names is gone. What the calculus guarantees is that *amoebius*
  wrote nothing unauthorised — the substrate's actual free space is a `live-effect` observation.
- **A worst case must be declared to be checked.** A recipe whose output size is not bounded in advance is
  admitted against its declared bound, and a recipe that exceeds its own declaration is refused mid-write. That
  refusal is the one place a partial rendering can occur; [§4](#4-admission-fails-first-not-last)'s staging rule
  is what keeps it from becoming a partial *artifact*, and it is why the per-item bound is part of the grant.
- **Phase 4 owns the target grant, admission, and reaper boundary; the rest remains later work.**
  [Phase 4](../../DEVELOPMENT_PLAN/phase_04_budget_calculus.md) must cover the grant issued from a finite pool,
  the ceiling and concurrency as one bound, `admit`/`admitFirst` over a demand, the staging rule of
  [§4](#4-admission-fails-first-not-last), and the retention grant that has no constructor without a reaper —
  all as pure values in Register 1, which would be a decision result and not a runtime one. No phase currently
  claims [§6](#6-composition-sums-and-the-sum-is-checked)'s additivity, which is stated over the lift
  calculus above this one, or any live observation of the free space
  [§7](#7-the-residue) keeps outside the calculus. Status lives only in the
  [tracker](../../DEVELOPMENT_PLAN/README.md).

---

## 8. Planning ownership

This document is normative only. Which phase delivers the grant type, admission, the retention grant, and the
reaper is owned by [DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md). Normative shapes are design
intent. Only a phase-specific, independently reviewed candidate plus external human approval could establish
an amoebius result; every current phase is NOT VALIDATED.

---

## Related Documents
- [Engineering Doctrine Index](./README.md)
- [JIT Artifact Doctrine](./jit_artifact_doctrine.md) — the artifacts a grant authorises, and the region that returns an ephemeral one
- [Resource Capacity Doctrine](./resource_capacity_doctrine.md) — the capacity vocabulary a grant is issued against, referenced rather than restated
- [Extension Conformance Laws](./extension_conformance_laws.md) — L3 and C5, the laws stated over this calculus
- [Extension Conformance Doctrine](./extension_conformance_doctrine.md) — the obligation surface an extension's budget component fills
- [Content Addressing Doctrine](./content_addressing_doctrine.md) — the store a retention grant bounds
- [Storage Lifecycle Doctrine](./storage_lifecycle_doctrine.md) — durable bytes, and why reaping is not deletion of durable data
- [Workflow Calculus Doctrine](./workflow_calculus_doctrine.md) — teardown as a type obligation, the same argument at the workflow seam
- [Illegal States — Capacity](../illegal_state/illegal_state_capacity.md) — the catalogued capacity states
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
