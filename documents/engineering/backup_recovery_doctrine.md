# Backup & Recovery

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/illegal_state/illegal_state_storage.md, documents/illegal_state/illegal_state_multicluster.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: Single source of truth for amoebius's backup and recovery surface — the closed
> `BackupPolicy` deployment rule (remote, append-only/WORM, and air-gapped media), the write-but-never-delete
> credential boundary that keeps retention and deletion out of band, the verified content-addressed
> `BackupArtifact`, the bounded-no-overcommit sizing fold, and the restore/seed path that populates a fresh
> coordinate under a consistency-over-availability posture — never an in-place overwrite of live data.

---

## 1. Why this doctrine exists

**The problem this doctrine prevents.** Durability under
[`storage_lifecycle_doctrine.md`](./storage_lifecycle_doctrine.md) is delivered by *retaining bytes and
deterministically rebinding* them across cluster teardown — the backing store is never deleted, so
"nothing is restored from a backup"
([`storage_lifecycle_doctrine.md` §6](./storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind)).
That guarantee covers the routine case and only the routine case: it assumes the original backing store still
exists and is attachable. It says nothing about the loss of the backing itself — a destroyed host disk, a
deleted or corrupted cloud volume, a region that is gone, or a primary cluster that is down while its standby
was never deployed. Without a backup surface, those disaster cases have no data-preserving path, and an
operator reaching for one finds either no primitive or an ad-hoc one whose sizing, deletion authority, and
consistency guarantees are unmodelled — exactly the review-and-discipline layer the amoebius illegal-state
contract rejects ([`dsl_doctrine.md` §5](./dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)).

**Why the obvious alternatives fail.** A general "backup anything, anywhere, delete on a schedule" surface
re-admits the states the storage and credential doctrines forbid: an amoebius credential that can delete
durable copies (contradicting
[`storage_lifecycle_doctrine.md` §7](./storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation)),
an unbounded backup history (contradicting the no-unbounded-storage invariant), and a restore that overwrites
live bytes (a destruction verb by another name). Folding backup into the retained-storage model instead —
"just keep more copies on retained PVs" — fails the opposite way: it cannot leave the source's failure domain,
so it protects against node loss but not against the domain-scoped disaster a backup exists to survive.

**The chosen rule.** A backup is a **deployment rule** — a closed `BackupPolicy` authored beside HA replicas
and the PACELC surface ([`app_vs_deployment_doctrine.md`](./app_vs_deployment_doctrine.md)), never application
logic — that names a **bounded** medium in a **distinct failure domain**, a **write regime**, and a **bounded
retention**. Amoebius holds a **put-only** credential over that medium: retention and deletion are out of band
and amoebius never authenticates as an actor that can delete a backup. A completed backup is a verified,
content-addressed `BackupArtifact`. Recovery **seeds a fresh coordinate** from such an artifact — it never
overwrites live durable bytes — and a backup-seeded cluster may take the wild-ingress gateway only after its
data freshness is proven, choosing consistency over availability
([§8](#8-the-gateway-dovetail-seed-from-backup-under-consistency-over-availability)).

**What it forecloses.** Amoebius gives up the ability to *reclaim* backup storage on its own initiative: it
cannot delete, expire, or lifecycle a backup, so an operator who wants space reclaimed performs an out-of-band,
audited action or relies on the medium's own object-lock/retention policy. It also gives up
availability-first recovery for the cold-seed posture: a secondary whose seeded state cannot prove freshness
stays down rather than serving stale data. The residual tension, stated honestly
([§9](#9-honesty-proventestedassumed)): the type surface proves a backup plan is *bounded, put-only, and
verified-before-it-counts*; it cannot prove the medium honors its object-lock, that the copied bytes match, or
that an out-of-band retention actor behaves — those are runtime-checked or assumed.

Backups are **complementary to** the retained-rebind guarantee, not a replacement for it. Routine graceful
teardown remains lossless by retention and deterministic rebind; the backup/restore path is the
disaster / backing-loss / cold-seed path only. (Shorthand: rebind survives a torn-down cluster; backups
survive a lost backing.)

---

## 2. The backup surface — a closed `BackupPolicy` deployment rule

A `BackupPolicy` is authored on a durable-data-owning capability instance — an `ObjectStore` bucket, a `Sql`
database, or a `MessageBus` topic offload ([`service_capability_doctrine.md`](./service_capability_doctrine.md))
— on the deployment-rules surface. It is not a tenth service capability: it changes how robustly the data
survives, not what the app is ([`app_vs_deployment_doctrine.md` §1](./app_vs_deployment_doctrine.md#1-two-surfaces-one-app-written-once)).

```dhall
-- WHERE backups land. A closed union; each arm names its own BOUNDED backing in a distinct failure domain.
let BackupMedium =
      < RemoteObjectStore : { backing : StorageBacking, domain : FailureDomain }  -- off-site S3/MinIO, distinct domain
      | AirGapMedia       : { library : AirGapLibrary, handling : Handling }       -- offline tape/optical/removable
      >

-- Air-gap only. A phantom index that gates whether a RESTORE may be initiated by automation (§7).
let Handling = < Manual | Automatic >

-- Whether EXISTING backups may ever be expired — always by an out-of-band actor, never by amoebius (§4).
let WriteRegime =
      < AppendOnly     -- WORM / object-lock: existing backups immutable; no delete/overwrite is representable
      | RetainManaged  -- an EXTERNAL retention actor amoebius never authenticates as may expire generations
      >

-- Bounded retention; no keep-forever / unbounded-history arm (mirrors the RetentionPolicy / Growable idiom).
let BackupRetention = < KeepN : Natural | KeepWindow : PosDuration | Growable : ScalingPolicy >

let BackupPolicy =
      { medium    : BackupMedium
      , regime    : WriteRegime
      , cadence   : PosDuration       -- how often a generation is produced
      , retention : BackupRetention
      }
```

The closed-union / no-arm shape is the technique owned by
[`illegal_state_techniques.md` §4.2](../illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable);
this section records the backup instance. Every `StorageBacking` arm is bounded by construction — it is the
same closed `HostDisk | Ebs | CloudQuota` union owned by
[`storage_lifecycle_doctrine.md` §5.2](./storage_lifecycle_doctrine.md#52-the-storage-backing-is-bounded--the-closed-storagebacking-union),
with no unbounded arm — so a backup medium can never denote unbounded storage, and `BackupRetention` has no
keep-forever arm, so backup history is bounded by the same discipline the Pulsar retention surface uses
([`pulsar_client_doctrine.md` §6.1](./pulsar_client_doctrine.md#61-topic-storage-lifecycle-bounded-tiered-retained--and-the-hot-tier-never-overflows)).

---

## 3. The three strategies

The medium union and the write regime together express the three named strategies without a strategy scalar:

- **Remote backup** — `RemoteObjectStore { backing, domain }`, an off-site object store (a second MinIO, a
  cloud bucket) whose `domain` is **distinct** from the source it protects. Domain distinctness is a decode
  fold ([§5](#5-sizing-and-the-no-overcommit-fold), [`illegal_state_storage.md`](../illegal_state/illegal_state_storage.md)),
  the same distinctness technique the gateway migration graph uses to reject a reused cluster
  ([`gateway_migration_model_doctrine.md` §5](./gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)):
  a "remote" backup landing in the source's own host disk, cluster, EBS availability zone, or cloud account is
  not a backup and has no accepted representation.
- **Append-only / WORM** — `regime = AppendOnly`, a write-once medium (object-lock, a WORM tape pool) on
  which existing generations are immutable. No mutation or deletion verb reaches an append-only backup — not
  from amoebius (which holds no delete authority, [§4](#4-the-write-but-never-delete-credential-boundary)) and
  not, within the lock window, from the out-of-band retention actor. `RetainManaged` is the weaker regime
  where an external actor may expire generations; amoebius still holds no delete authority under either regime,
  and the distinction is only whether the medium *permits* out-of-band expiry.
- **Air-gapped media** — `AirGapMedia { library, handling }`, offline media (tape, optical, removable) with no
  live network path. The `AirGapMedia` arm carries **no credential field** — only `RemoteObjectStore` does — so
  an "air-gapped" medium that is actually reachable over the network has no inhabitant. Egress to and ingress
  from an air-gap medium is a witnessed handoff, not a live credential. `handling` selects whether restore may
  be driven by automation (`Automatic`) or requires a human-attested media load (`Manual`), which is the teeth
  of the manual/automatic recovery foreclosure ([§7](#7-recovery-restore-seeds-a-fresh-coordinate)).

---

## 4. The write-but-never-delete credential boundary

The load-bearing rule: **amoebius never holds a credential that can delete, expire, or lifecycle a backup.**
Retention and deletion are out of band. This is the backup instance of the create-but-not-delete credential
model owned by
[`pulumi_iac_doctrine.md` §6](./pulumi_iac_doctrine.md#6-the-ebs-create-vs-delete-credential-model) and the
"deleting durable data is forbidden under normal operation" posture of
[`storage_lifecycle_doctrine.md` §7](./storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation).

The write credential is a specialization of the `CloudAccountMutationCapability` owned by
[`resource_capacity_doctrine.md`](./resource_capacity_doctrine.md) whose `allowedActions` is a **closed
put-only record** — there is no field into which a `DeleteObject`, `ExpireObject`, `PutBucketLifecycle`, or
`DeleteObjectVersion` action could be placed:

```haskell
-- The write capability's allowedActions is a closed record of exactly the put/write actions, in the shape of
-- SoleHostBootstrapMutationCapability's two-Required-actions record. "amoebius deletes a backup" is
-- uninhabitable — there is no constructor for a delete action on this surface — not merely denied at runtime.
data BackupWriteCapability = MkBackupWriteCapability
  { account        :: CloudAccountId
  , credential     :: SecretRef                 -- resolved from Vault by name, never inline
  , allowedActions :: BackupPutOnlyActions      -- closed record: { putObject :: Required, … }; no delete field
  , medium         :: BackupMediumRef
  }
```

Three consequences:

- **Deletion authority lives elsewhere, by class.** Retention and expiry are a distinct lifetime and
  credential class ([`pulumi_iac_doctrine.md` §3](./pulumi_iac_doctrine.md#3-state-lifetime-matches-resource-lifetime-per-class)),
  owned by the medium's own object-lock/retention policy set once at medium creation by a privileged action, by
  a separate external account, or by an audited human break-glass. No amoebius reconciler, `.dhall` value, or
  elevated test harness deletes a production backup, exactly as none deletes a production durable backing.
- **`AppendOnly` is enforced at two layers.** The surface exposes no delete verb (type-foreclosed), and the
  medium enforces WORM/object-lock so even the out-of-band actor cannot delete within the lock window. A backup
  policy that paired `AppendOnly` with a mutable medium is rejected by the medium-capability fold.
- **Secrets stay names.** The credential is a `SecretRef`
  ([`vault_pki_doctrine.md` §3](./vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value)), never
  an inline value, and a backup of durable data is written to the medium **Vault-Transit-enveloped**, the same
  posture as the control-plane state object ([`storage_lifecycle_doctrine.md` §7.2](./storage_lifecycle_doctrine.md#72-amoebius-own-control-plane-state-is-the-minio-bucket-not-a-pvc)):
  a plaintext backup at rest, especially on a medium that leaves the trust boundary, has no constructor. The
  envelope key must be recoverable independently of the coordinate the backup protects; a backup whose only
  decryption key is escrowed in the domain it protects is a self-defeating loop, foreclosed at its honest layer
  ([§9](#9-honesty-proventestedassumed)).

---

## 5. Sizing and the no-overcommit fold

A backup consumes storage, so it is folded into the capacity accounting owned by
[`resource_capacity_doctrine.md`](./resource_capacity_doctrine.md) at the post-bind `provision-seal` locus, the
[§4.6](../illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
capacity-accounting technique. Before a `ProvisionedSpec` exists, the fold proves that the projected backup
working set, the copy/verify executor's workspace, and the **full bounded retained generation set** fit the
medium's backing:

```text
Σ( working-set + copy-verify-Job workspace + retained generations ) ≤ medium backing
```

- **Append-only history grows monotonically.** Under `AppendOnly`, generations cannot be deleted to reclaim
  space, so the retained set is `cadence`-many generations across the retention window; a policy whose
  window × cadence bytes exceed the medium's bounded quota is rejected at `provision-seal` unless it declares a
  `Growable` retention whose ceiling is itself a quota
  ([`resource_capacity_doctrine.md` §6](./resource_capacity_doctrine.md#6-growable--scalingpolicy-the-escape-valve-amoebius-owns)).
  Backing up more data than the medium holds returns a `ProvisionError`, constructs no `ProvisionedSpec`, and
  cannot render — the same mechanism as durable-backing overcommit.
- **The medium is a disjoint backing.** The backup medium's bytes are a distinct `StorageBacking` from the
  source's durable backing and from node ephemeral/cache pools; the same physical bytes cannot satisfy both the
  live-data budget and the backup budget, so a plan cannot appear to fit by pretending backup and primary share
  bytes ([`storage_lifecycle_doctrine.md` §5.2](./storage_lifecycle_doctrine.md#52-the-storage-backing-is-bounded--the-closed-storagebacking-union)).
- **The copy/verify executor is charged.** The `Job` that copies and verifies a generation carries a complete
  `PodResourceEnvelope` and is admitted before render, exactly like the shrink-migration copy/verify Job
  ([`storage_lifecycle_doctrine.md` §8](./storage_lifecycle_doctrine.md#8-shrinking-storage-without-representing-data-destruction),
  [`inforcespec_migration_doctrine.md` §4](./inforcespec_migration_doctrine.md#4-shrink-is-create-new--verified-migrate--retire-old-backing-reclaim-is-external-and-privileged)).

---

## 6. The verified, content-addressed `BackupArtifact`

A completed backup is an immutable, content-addressed artifact carrying a provenance witness and the commit
watermark it captured. It is branded opaque at Gate 2, materialized only at `provision-seal`, and **counts only
once verified** — the same discipline as the `ReclaimEligible` artifact
([`storage_lifecycle_doctrine.md` §8](./storage_lifecycle_doctrine.md#8-shrinking-storage-without-representing-data-destruction))
and the `.ready`-gated `ArtifactRef`
([`content_addressing_doctrine.md` §4.5](./content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)):

```haskell
data BackupArtifact (v :: Verified) where
  MkBackupArtifact ::
    { digest    :: Digest                 -- content address of the captured bytes (content_addressing_doctrine §4.5)
    , source    :: Ref tenant DurableCoordinate   -- the phantom tenant tag travels with the backup (§4.2)
    , watermark :: CommitWatermark        -- the RPO point this backup captured, DERIVED from content, not asserted
    , medium    :: BackupMediumRef
    , verified  :: VerifiedBackupContentAndExtentWitness
    } -> BackupArtifact 'Verified
```

- **The watermark is derived, not asserted.** `watermark` is a total function of the captured content
  ([§4.5](../illegal_state/illegal_state_techniques.md#45-content-address-totality--names-are-total-functions-of-content)),
  never an operator claim, so the freshness gate of
  [§8](#8-the-gateway-dovetail-seed-from-backup-under-consistency-over-availability) cannot be spoofed by a
  backup that claims a freshness it did not capture.
- **The tenant tag travels with the bytes.** `source :: Ref tenant DurableCoordinate` is phantom-tagged, and
  there is no `Ref t1 → Ref t2` coercion, so a cross-tenant backup or a restore of one tenant's backup into
  another has no inhabitant. Sharing a backup is the append-only revocable capability edge owned by
  [`inforcespec_migration_doctrine.md` §7](./inforcespec_migration_doctrine.md#7-sanctioned-sharing-is-an-append-only-revocable-capability-edge),
  never a re-tag.
- **Unverified means it does not count.** A backup whose copy cannot be verified emits no
  `BackupArtifact 'Verified`, fails loud, and is never a valid restore source — the copy-equivalence residue is
  runtime-checked ([§9](#9-honesty-proventestedassumed)), exactly as it is for the verified-shrink migration.

---

## 7. Recovery: restore seeds a fresh coordinate

Recovery is a phase-indexed GADT state machine
([`illegal_state_techniques.md` §4.3](../illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)),
and it **only ever targets a fresh coordinate** — an empty durable backing, or a newly stood-up cluster's
backing. There is no constructor for restore-into-occupied-backing, so restore can never denote "overwrite
these live bytes," and it composes with the no-destruction contract of
[`inforcespec_migration_doctrine.md` §3](./inforcespec_migration_doctrine.md#3-the-dsl-exposes-no-destructive-verb--the-closed-storagemutation-union)
rather than becoming a disguised delete. This is also why restore does not contradict
[`storage_lifecycle_doctrine.md` §6](./storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind):
routine rebind reattaches bytes that were never deleted; restore populates a coordinate that is empty because
its backing was lost.

```haskell
data RestorePhase = Requested | MediumOnline | Seeded | FreshnessProven

-- Obtaining MediumOnline for a Manual air-gap medium requires a human-attested MediaLoaded token recorded
-- through the admin channel; NO constructor mints it automatically. An AUTOMATIC restore from a Manual
-- air-gap medium therefore has no inhabitant (§4.2 phantom Handling index + §4.3 phase gating).
mediumOnlineAuto   :: (handling ~ 'Automatic) => AirGapMedia -> Restore 'MediumOnline
mediumOnlineManual :: MediaLoadedWitness       -> AirGapMedia -> Restore 'MediumOnline
```

- **A manual air-gap medium cannot be recovered automatically.** For `handling = Manual`, the only path to
  `MediumOnline` is `mediumOnlineManual`, which consumes a `MediaLoadedWitness` that only a recorded human
  action mints. An unattended reconcile cannot manufacture the witness, so "automatically recovering from a
  manual air-gapped system" has no representation. `handling = Automatic` (a robotic library) may reach
  `MediumOnline` without a human, but still only after an observed media-availability edge, never a timer
  ([`readiness_ordering_doctrine.md`](./readiness_ordering_doctrine.md)).
- **The restore fit is provisioned.** The seed target is created new, sized from the artifact's witnessed
  extent, and its presentation must be compatible with the backup; a restore into a target smaller than or
  presentation-incompatible with the backup extent is rejected at `provision-seal`.
- **No serving before freshness.** An app's data-plane binding to a seeded store is uninhabitable until the
  restore reaches `FreshnessProven`, so no traffic is served from a half-seeded store — the data-plane gating
  idiom of [`single_logical_data_plane_doctrine.md`](./single_logical_data_plane_doctrine.md).

---

## 8. The gateway dovetail: seed-from-backup under consistency over availability

The recovery story the operator most needs is the down-primary case: a primary cluster is down and its
secondary was never deployed, so the secondary's data plane must be **seeded from backups** before it can serve.
Amoebius chooses **consistency over availability** here — it would rather stay down than promote a secondary
whose seeded state cannot prove its freshness. This extends three surfaces, each staying with its owner.

**The deployment-rule (owned by [`consistency_pacelc_doctrine.md`](./consistency_pacelc_doctrine.md)).** The
PACELC surface gains a recovery-source shape:

```dhall
let RecoverySource =
      < WarmReplica                                              -- a standby already deployed + async-replicating
      | ColdSeedFromBackup : { backup : BackupPolicyRef, freshnessBound : PosDuration }
      >
```

`ColdSeedFromBackup` is the cross-cluster **cold-DR seed** posture: the standby is not deployed until needed,
and when it is, its backing is seeded from the latest `Verified` `BackupArtifact`. The `freshnessBound` is the
maximum staleness the seed may carry and still be promotable; a `freshnessBound` below the backup `cadence` is
statically unsatisfiable — a seed can never be fresher than the newest generation — and is rejected at Gate 2,
the same shape as the existing `rto ≥ dnsTtl + headroom` fold
([`consistency_pacelc_doctrine.md` §3.5](./consistency_pacelc_doctrine.md#35-the-upload-time-feasibility-push-back)).
Like `Planned`/`Failover`, the `Seed` recovery is a **world-triggered event** classified at the recovery edge,
never an authored `mode` field ([`consistency_pacelc_doctrine.md` §3.4](./consistency_pacelc_doctrine.md#34-the-mode-is-world-triggered-not-authored)).

**The proof obligation (owned by [`gateway_migration_model_doctrine.md`](./gateway_migration_model_doctrine.md),
built in the formal-model phase).** The gateway migration model already makes cutover reachable only after an
observed `verify-caught-up` edge (`PlannedIsLossless`). That precondition is **generalized** to a
`FreshnessWitness` guard on the promote / gateway-take transition, dischargeable two ways: a warm replica that
is caught up (today), or a cold seed proven within `freshnessBound` (new). The model gains one safety
invariant — **`NoTakeWithoutProvenFreshness`**: no cluster takes the wild-ingress role from a data plane whose
freshness is unproven. Because a stalled state with zero gateway owners satisfies safety and only violates
liveness, the consistency-over-availability choice is exactly this shape: staying down is *safe*, and liveness
convergence requires freshness to become reachable. The invariant is proven for safety and, under the fairness
assumption, for liveness (TLC), with io-sim agreement and a per-invariant mutant, and the structural-fit fold
gains the `freshnessBound` parameter-envelope check — never a per-spec model-check
([`gateway_migration_model_doctrine.md` §5](./gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)).

**The enactment (owned by [`cluster_lifecycle_doctrine.md`](./cluster_lifecycle_doctrine.md)).** Standing up
the cold secondary on demand and seeding its fresh backing from the latest `Verified` `BackupArtifact` is a
reconcile enactment ([`cluster_lifecycle_doctrine.md` §9](./cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine));
the seed produces the `FreshnessWitness` the model's guard consumes. This step is the `live-effect` residue —
that the seeded bytes are correct and the observed watermark is truthful is runtime-checked, never proven by
the spec.

Net: the promote guard, the `NoTakeWithoutProvenFreshness` safety invariant, and the stay-down-rather-than-
serve-stale property are proven in amoebius's one formal obligation
([`gateway_migration_model_doctrine.md` §1](./gateway_migration_model_doctrine.md#1-the-one-obligation)); the
deploy-and-seed mechanics are honestly runtime-checked.

---

## 9. Honesty (proven/tested/assumed)

Per [`documentation_standards.md` §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline):

- **The type surface proves a backup plan is bounded, put-only, and verified-before-it-counts.** It cannot
  prove the medium honors its object-lock, that an out-of-band retention actor behaves, or that the copied
  bytes match the source — those are `live-effect` / runtime-checked residue, the same layer as the
  verified-shrink copy equivalence.
- **The write-but-never-delete boundary is decode-foreclosed at the credential shape and runtime-enforced at
  the cloud API.** The `allowedActions` record has no delete field (a spec-layer guarantee); that the cloud
  account actually denies delete is the runtime backstop owned by
  [`pulumi_iac_doctrine.md` §6](./pulumi_iac_doctrine.md#6-the-ebs-create-vs-delete-credential-model).
- **The key-independence premise is assumed.** That the envelope key is recoverable independently of the
  protected coordinate is a named premise, monitored, never proven by the type.
- **The cold-seed freshness guarantee is proven-for-the-model, tested by drill, and assumed at the physics.**
  `NoTakeWithoutProvenFreshness` is proven at the model scope; the RTO of an actual cold-seed recovery is
  validated by drill; that the observed watermark faithfully reflects real replication/backup lag is a
  monitored, assumed premise ([`consistency_pacelc_doctrine.md` §4](./consistency_pacelc_doctrine.md#4-honesty-proven--tested--assumed)).
- **Everything here is design intent.** No statement is a tested amoebius result. Phase order, status, and
  gates live only in [`../../DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md).

---

## 10. Boundaries this doc owns vs defers

| Owned here (SSoT) | Owned elsewhere (referenced) |
|---|---|
| The `BackupPolicy` / `BackupMedium` / `WriteRegime` / `BackupRetention` surface, the three strategies, and the verified `BackupArtifact` | The closed `StorageBacking` union and the delete-forbidden posture → [`storage_lifecycle_doctrine.md`](./storage_lifecycle_doctrine.md) |
| That a backup is put-only for amoebius and deletion is out of band | The create-vs-delete credential classes and `CloudAccountMutationCapability` → [`pulumi_iac_doctrine.md` §6](./pulumi_iac_doctrine.md#6-the-ebs-create-vs-delete-credential-model), [`resource_capacity_doctrine.md`](./resource_capacity_doctrine.md) |
| The no-overcommit backup fold operands (working set + Job + retained generations) | The aggregate `Σ ≤ backing` fold and the `Growable` escape valve → [`resource_capacity_doctrine.md`](./resource_capacity_doctrine.md) |
| That restore seeds a fresh coordinate and that a manual air-gap medium has no automatic-restore path | The no-destruction verb union and the reconcile enactment → [`inforcespec_migration_doctrine.md`](./inforcespec_migration_doctrine.md), [`cluster_lifecycle_doctrine.md`](./cluster_lifecycle_doctrine.md) |
| The `RecoverySource` cold-seed posture and its consistency-over-availability choice | The PACELC posture surface and the `FreshnessWitness`/`NoTakeWithoutProvenFreshness` proof → [`consistency_pacelc_doctrine.md`](./consistency_pacelc_doctrine.md), [`gateway_migration_model_doctrine.md`](./gateway_migration_model_doctrine.md) |
| The enumerated backup illegal states' owning rule | The catalog entries, techniques, and coverage matrix → [`illegal_state_storage.md`](../illegal_state/illegal_state_storage.md), [`illegal_state_multicluster.md`](../illegal_state/illegal_state_multicluster.md), [`illegal_state_techniques.md`](../illegal_state/illegal_state_techniques.md) |

---

## 11. Planning ownership

This document is normative backup-and-recovery doctrine only. It states the target shape; every statement is
design intent, not a built or tested amoebius capability. Delivery sequencing, completion status, and
validation gates — the pure representation folded into the Phase 4–8 gates, the `FreshnessWitness` proof
extension in the formal-model phase, and the live backup/restore/cold-seed gates riding on the Vault, MinIO,
provider-credential, multicluster, and test-topology phases — live only in
[`../../DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md). This doc never maintains a competing
status ledger; it links back for status.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Storage Lifecycle Doctrine](./storage_lifecycle_doctrine.md) — the retained-rebind guarantee backups complement, the closed `StorageBacking` union, and the delete-forbidden posture
- [Pulumi IaC Doctrine](./pulumi_iac_doctrine.md) — the create-vs-delete credential model the put-only backup credential specializes
- [Resource Capacity Doctrine](./resource_capacity_doctrine.md) — the capacity fold and `CloudAccountMutationCapability` the backup sizing and write credential reuse
- [Consistency & PACELC Doctrine](./consistency_pacelc_doctrine.md) — the `RecoverySource` cold-seed posture and the consistency-over-availability choice
- [Gateway Migration Model Doctrine](./gateway_migration_model_doctrine.md) — the `FreshnessWitness` guard and `NoTakeWithoutProvenFreshness` invariant extending the one proof obligation
- [Gateway Migration Doctrine](./gateway_migration_doctrine.md) — the `<Planned | Failover>` taxonomy the cold-seed posture composes with
- [InForceSpec Migration Doctrine](./inforcespec_migration_doctrine.md) — the no-destruction verb union and append-only revocable sharing edge
- [Content Addressing Doctrine](./content_addressing_doctrine.md) — the content-addressed, provenance-witnessed artifact idiom the `BackupArtifact` follows
- [Vault / PKI Doctrine](./vault_pki_doctrine.md) — the `SecretRef`-by-name credential and Vault-Transit envelope
- [Illegal State — Storage](../illegal_state/illegal_state_storage.md) / [Illegal State — Multicluster](../illegal_state/illegal_state_multicluster.md) — the enumerated backup illegal states
- [Illegal-State Techniques](../illegal_state/illegal_state_techniques.md) — the seven techniques the foreclosures reuse
- [Development Plan](../../DEVELOPMENT_PLAN/README.md) — phase order, status, and gates
- [Documentation Standards](../documentation_standards.md) — header, SSoT, and the proven/tested/assumed honesty rule
