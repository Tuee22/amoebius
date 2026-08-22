# Migration: one law, many instances

> **Purpose**: Single source of truth for the general shape every amoebius migration takes — create-new →
> verified-migrate → retire-old, gated on an observed readiness edge, with no representable destructive verb,
> the old coordinate retained until an out-of-band privileged act, and rollback as a pointer CAS over an
> immutable ledger — naming the law once and citing, never restating, the per-instance mechanisms that
> realize it.
> **Read this if**: anything has to be replaced in place, and the replacement must not be able to destroy what it replaces.

This document owns the general migration law: one create-new, verify, retire-old discipline that every
in-place replacement in the system instantiates. It owns no instance — each is owned by its own doctrine and
listed here only to be recognised as the same shape. Reading it presumes the honesty discipline of
[documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/glossary.md, documents/illegal_state/illegal_state_multicluster.md, documents/illegal_state/illegal_state_storage.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

</details>

---

## 1. Why this doctrine exists

**The problem.** "Migration" names at least eleven different operations in this suite — a typed `InForceSpec`
diff, a volume shrink, a database schema change, a Pulsar retention contraction, a registry-backend rehome, a
cross-cluster gateway handover, a backup restore, a browser record-schema upgrade, a UI program release, a
tenant promotion, and the reflected-schema evolution of the DSL itself. Each of those is owned, specified, and
phased. What is absent is the statement that they are **instances of one discipline**. The consequence is not
theoretical: a reader who has internalized one sense cannot predict the guarantees of another, an author adding
a twelfth kind has no law to conform to, and a defect in the shared shape — a missing abort path, an unstated
resumption semantics — is invisible because it appears in each doc as a local omission rather than as a
violation of anything.

**Why the obvious alternative fails.** The tempting response is that each sense already cites
[storage_lifecycle_doctrine.md §8](./storage_lifecycle_doctrine.md#8-shrinking-storage-without-representing-data-destruction)
for the three-beat shape, so the discipline is "documented by convergence". That is exactly the arrangement
[documentation_standards.md §1](../documentation_standards.md#1-philosophy) rejects: a fact re-derived in six
documents and owned by none has no place to be corrected, no place to be checked, and no place for a new
instance to be measured against. It is the same defect the suite already repaired for readiness ordering — that
discipline was likewise present one site at a time until
[readiness_ordering_doctrine.md §7](./readiness_ordering_doctrine.md#7-one-discipline-many-instances) named it
once — and this document is that repair applied to migration.

**The chosen rule.** **Every amoebius migration is an instance of one law ([§2](#2-the-law)), and every instance declares its position against that law's five clauses ([§3](#3-one-discipline-many-instances)).** This
document owns the law and the instance table. It owns no mechanism: each row's protocol, types, capacity
model, and honesty markers stay with the doctrine that already owns them and are linked, never restated.

**What it forecloses.** A migration kind can no longer be added by describing a bespoke procedure — it must
state its verification gate, its abort path, its rollback, and its foreclosure layer, or record explicitly
that it has none and why. That is a real constraint on future design, and it is the point. What the law does
**not** claim is uniformity of *mechanism*: a gateway handover and a PV shrink share a shape, not an
implementation, and [§4](#4-the-two-stated-exceptions) records the two places the shape genuinely does not
hold.

---

## 2. The law

A migration moves a system from one durable shape to another. Five clauses govern every instance:

1. **Create-new → verified-migrate → retire-old.** The replacement is stood up *beside* the original, the
   content is moved and **verified**, and only a later step retires the original. No step both destroys and
   replaces.
2. **No representable destruction.** The authoring surface exposes no verb denoting "discard these bytes";
   this is a property of the *types*, not of the reconciler's care. Retirement marks eligibility; physical
   reclaim is an out-of-band privileged human act, outside the spec and outside every reconciler.
3. **Gated on an observed edge, never a duration.** Each step begins when the prior step's completion is
   *observed from live state*. A timer is not a gate
   ([readiness_ordering_doctrine.md §3](./readiness_ordering_doctrine.md#3-readiness-is-a-condition-never-a-duration)).
   A bounded *window* (a DNS TTL) may appear as an operand of a budget, but it never stands in for an edge.
4. **Failure retires nothing.** An unverified copy aborts leaving both coordinates live and both charged. The
   fail-closed direction is always "keep the original".
5. **Rollback is an ordinary operation.** Because each generation is an immutable ledger entry, undoing a
   migration is advancing a pointer back and letting the reconciler converge — there is no inverse-migration
   machinery, because there is nothing to invert.

Clauses 1–2 are what make the whole family *no-destruction*; clause 3 is what makes it *composable* with the
bring-up DAG; clauses 4–5 are what make it *recoverable*. An instance that cannot state its clause-4 behaviour
has an unspecified failure mode, and an instance with no clause-5 answer is one-directional — both are
recorded as such in [§3](#3-one-discipline-many-instances) rather than papered over.

Crash-resumption is **not** a sixth clause, because it is not migration-specific: an instance realized by the
ordinary reconcile inherits `discover → diff → enact → re-observe` idempotence and its crash-recovery posture
from [cluster_lifecycle_doctrine.md §9](./cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)
and [manifest_generation_doctrine.md §6](./manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderallprovisionedspec-observed-is-live-inventory-actions-are-typed).
What remains genuinely open — whether a killed copy step resumes from a checkpoint or restarts — is a
mechanism question owned by
[storage_lifecycle_doctrine.md §8](./storage_lifecycle_doctrine.md#8-shrinking-storage-without-representing-data-destruction).

---

## 3. One discipline, many instances

Each row keeps its own SSoT and is cited, never restated. *Abort* is the clause-4 behaviour; *rollback* is the
clause-5 answer.

| Instance | Protocol | Verification gate | Abort / rollback | Layer | Owned by |
|---|---|---|---|---|---|
| `InForceSpec` generation diff | typed diff realized by the ordinary reconcile; no bespoke verb | decode-time no-orphan + retention-floor fold | reject at decode / re-point to prior `Release` | `type-foreclosed` verb union + `decode-foreclosed` fold | [inforcespec_migration §2](./inforcespec_migration_doctrine.md#2-a-migration-is-a-typed-diff-not-a-new-operation) |
| Durable volume shrink / replace | create-new → copy → verify → `ReclaimEligible` | copy verification before detach | keep both coordinates; reclaim is external break-glass | `type-foreclosed` (no `Delete` arm) + `runtime-checked` copy | [storage_lifecycle §8](./storage_lifecycle_doctrine.md#8-shrinking-storage-without-representing-data-destruction) |
| Database schema | a `RolloutPhase`: create-new → verified-migrate → retire-old | readiness gate observed from the live object | old schema stays active; CAS the environment pointer back | `runtime-checked` gate on a `type-foreclosed` phase value | [release_lifecycle §5](./release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply) |
| Topic retention contraction | offload-before-shrink | retained span preserved before contraction | retention-floor rejection at decode | `decode-foreclosed` | [pulsar_client §6.1](./pulsar_client_doctrine.md#61-topic-storage-lifecycle-bounded-tiered-retained--and-the-hot-tier-never-overflows) |
| Registry-backend rehome | reserve source + target + workspace, transfer, verify every digest, cut over | full old-digest-set verification before cutover | source backend remains authoritative | `provision-seal` fit + `runtime-checked` digest verify | [image_build](./image_build_doctrine.md), [DEVELOPMENT_PLAN/phase_62](../../DEVELOPMENT_PLAN/phase_62_platform_backbone.md) |
| Gateway handover (`Planned`) | quiesce → drain → verify-caught-up → cutover → decommission old | `verify-caught-up` edge; RPO=0 | stand down before promote; the old gateway keeps the role | modelled + `runtime-checked` edges | [gateway_migration §2](./gateway_migration_doctrine.md#2-the-planned-branch--a-coordinated-strong-consistency-handover) |
| Gateway takeover (`Failover`) | survivor-wins takeover of a vanished active | freshness guard before the take | no abort — the active is already gone; heal-then-converge | modelled; the one RPO>0 boundary ([§4](#4-the-two-stated-exceptions)) | [gateway_migration §3](./gateway_migration_doctrine.md#3-the-failover-branch--an-availability-first-emergency-takeover) |
| Backup restore / `ColdSeedFromBackup` | seed a **fresh** coordinate; take the gateway only after proven freshness | verified content-addressed artifact + freshness witness | live bytes are never targeted, so there is nothing to undo | `type-foreclosed` fresh-coordinate binding | [backup_recovery §7](./backup_recovery_doctrine.md#7-recovery-restore-seeds-a-fresh-coordinate) |
| Browser record schema | total migration, or a retained decoder + current-authority replay handler | promotion refused without one of the two | atomic per partition, crash-resumable; `ReloadRequired` never clears the outbox | `decode-foreclosed` promotion gate | [browser_offline §11](./browser_offline_runtime_doctrine.md#11-release-schema-and-compatibility-horizon) |
| UI program release | coherent client/server/program generation moved together | projector watermark reached before the traffic shift | `ReloadRequired` and no effect executes; CAS back to the prior `Release` | `runtime-checked` watermark on a `type-foreclosed` release identity | [low_code_ui_runtime §15](./low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts) |
| Tenant promotion to a child cluster | **open** — asserted as a `RolloutPhase`, which is the in-cluster apply; no owner covers moving durable bytes across the cluster boundary | none stated | none stated | unresolved | [tenancy §7](./tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit) |
| DSL schema evolution | widening (optional field / uninhabited arm) is transparent; narrowing is a typecheck rejection the operator resolves by editing the external/untracked value; reinterpretation is inadmissible | Haskell-declared cases lazily render `.build/**` inputs for the generated typechecker | no automatic rewrite of external/untracked `.dhall`; the prior schema is the prior `Release` | `type-foreclosed` + review residue on reinterpretation | [generated_artifacts §5.1](./generated_artifacts_doctrine.md#51-when-the-reflected-schema-changes-under-an-operators-dhall) |

The tenant-promotion row is recorded as **open** rather than omitted. Under
[documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline) an
instance with no stated verification gate and no stated abort path is an unresolved obligation, not a covered
one, and a table that silently dropped it would misreport coverage.

---

## 4. The two stated exceptions

The law is not universal, and the two places it does not hold are named rather than elided.

- **`Failover` can lose committed writes.** Clause 1's "verify before retire" is unavailable when the original
  has vanished: an availability-first takeover accepts RPO > 0, bounded by the declared data-loss budget. This
  is the single boundary at which amoebius trades consistency for availability, fixed by
  [consistency_pacelc_doctrine.md](./consistency_pacelc_doctrine.md), and it is world-triggered rather than
  authored. Every other instance in [§3](#3-one-discipline-many-instances) is consistency-over-availability.
  Placing this exception beside the no-destruction law is deliberate: the law governs what a spec can
  *represent*, and this exception governs what a partition can *destroy* — two different claims that a reader
  can otherwise conflate into a false guarantee.
- **Sibling-project convergence is a homonym.** The "migration fixtures" and the migration-removal ledger that
  track what the convergence retires from prodbox/hostbootstrap/infernix/jitML
  ([lift_and_compose_doctrine.md §3](./lift_and_compose_doctrine.md#3-a-seed-is-a-reference-implementation),
  [DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md))
  are a development-time project activity. They move no durable bytes, take no readiness edge, and are not
  governed by this law.

---

## 5. Foreclosure layers and the honest limit

Per [illegal_state_catalog.md §6](../illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)
and [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline),
the law reaches three different layers and claims no more than each supports:

- **type-foreclosed** — clause 2's absent destructive verb, the fresh-coordinate binding of a restore, and the
  phase and release identities the gated instances are indexed by. These have no syntax and no inhabitant.
- **decode-foreclosed** — clause 1's structural obligations that compare two generations or walk a collection:
  the no-orphan and retention-floor folds, the promotion gate over a compatibility horizon. Per
  [illegal_state_catalog.md §4.7](../illegal_state/illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)
  a relation over a collection degrades to a decode-time fold and is **never** type-foreclosed.
- **runtime-checked** — clause 1's *verification* itself, clause 3's observed edges, and clause 4's
  fail-closed behaviour. A type cannot prove that a copy's bytes match the original, that a replica is caught
  up, or that a live coordinate still holds its data.

The load-bearing limit is therefore that **the law removes the destructive verb and fixes the order; it does not prove the copy.** Every statement here is design intent: no phase has been built, and where a shape is
demonstrated in a sibling project that is sibling evidence, not an amoebius result.

---

## 6. Planning ownership

Phase order, status, and validation gates live only in
[`DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md). Each instance in
[§3](#3-one-discipline-many-instances) is assigned to the phase its owning doctrine names; assignment is not a
completion or validation claim. This document adds no phase of its own and maintains no competing status ledger.

---

## Related Documents
- [Engineering Doctrine Index](./README.md)
- [InForceSpec Migrations and No-Destruction](./inforcespec_migration_doctrine.md) — the spec-evolution instance and the no-destruction verb union
- [Storage Lifecycle Doctrine](./storage_lifecycle_doctrine.md) — the create-new → verified-migrate → retire-old mechanism every byte-touching instance reduces to
- [Release Lifecycle Doctrine](./release_lifecycle_doctrine.md) — the readiness-gated `RolloutPlan`/`RolloutPhase` apply
- [Gateway Migration](./gateway_migration_doctrine.md) — the cross-cluster instance and its two branches
- [Backup & Recovery Doctrine](./backup_recovery_doctrine.md) — restore as a fresh-coordinate seed
- [Readiness & Ordering Doctrine](./readiness_ordering_doctrine.md) — clause 3, and the structural precedent for this document
- [Consistency & PACELC Doctrine](./consistency_pacelc_doctrine.md) — the one availability-over-consistency boundary
- [Illegal State Catalog](../illegal_state/illegal_state_catalog.md)
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
