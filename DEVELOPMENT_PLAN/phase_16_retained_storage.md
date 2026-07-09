# Phase 16: No-provisioner retained storage + lossless rebind

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, overview.md, phase_17_vault_pki.md
**Generated sections**: none

> **Purpose**: Install the single inert `no-provisioner`/`Retain` StorageClass and the deterministic
> `<namespace>/<statefulset>/pv_<integer>` retained-PV bind on the live linux-cpu kind cluster, then prove the
> lossless-teardown guarantee — durable bytes rebind across a cluster delete + recreate with a Postgres row
> and a MinIO object marker round-tripping unchanged.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. The phase runs on the **linux-cpu** substrate in
**Register 3** (live infrastructure) — a single-node `kind` cluster brought up by the Phase 13 midwife, and
it opens only after the Phase 15 gate (the typed renderer + live SSA reconciler) closes, because the
StorageClass, the retained PVs, and their `claimRef` pins are rendered from pure Haskell and applied through
that reconciler. The single-node host-path retained-storage scheme this phase generalizes is proven in the
sibling prodbox project (`prodbox/documents/engineering/storage_lifecycle_doctrine.md`); read that as
**sibling evidence, not an amoebius result** — amoebius has not yet built the storage layer. Status
transitions are recorded reverse-chronologically here once work begins.

## Phase Summary

This phase makes durable storage a *different kind of thing* from the cluster that mounts it. It installs the
one inert StorageClass amoebius allows — `provisioner: kubernetes.io/no-provisioner`, `reclaimPolicy: Retain`,
`volumeBindingMode: WaitForFirstConsumer` — and removes every other StorageClass and competing default
annotation, so a claim can never fall through to a dynamic provisioner. It renders retained PVs whose names
and `claimRef`s are pure functions of `(namespace, statefulset, ordinal)`, each pinned to the exact
`(namespace, PVC-name)` it serves and (for host-backed volumes) node-affine to the node holding its bytes,
each carrying an explicit capacity against an explicitly-sized claim. It closes with the load-bearing proof:
write a marker row into a Postgres witness and a marker object into a MinIO witness, `cluster delete` (claims
released, PVs Retained), `cluster recreate`, and read the same bytes back — the deterministic rebind.

The scope deliberately stops at *standing the retained-storage substrate up and proving it rebinds*. The
witness workloads are minimal single-ordinal StatefulSets that exercise the bind; the full HA
Patroni-via-Percona Postgres and distributed MinIO chart is Phase 18, the Vault-enveloping of secrets is
Phase 17, and the Keycloak-owned edge is Phase 19 — none of which this phase requires. The control plane
itself is out of the retained-storage picture by construction: it is a stateless Deployment `replicas=1` that
holds **no PVC**, its durable state exclusively the Vault-enveloped MinIO bucket, so MinIO here is a retained
volume holder while the control plane is only a client of that bucket.

**Substrate:** linux-cpu — the whole gate runs on a single-node `kind` cluster on a linux-cpu host, in
Register 3 (live infrastructure); no apple, linux-cuda, or windows substrate is touched, and no live
infrastructure is required to *render* the StorageClass or PV objects (that stays pure, Registers 1–2).

**Gate:** durable **storage rebinds after a cluster delete + recreate with no data loss** — a marker row
written into a Postgres witness StatefulSet and a marker object written into a MinIO witness bucket both
round-trip byte-for-byte after the cluster is deleted (claims released, PVs `Retained`) and recreated (the
same StatefulSet identities recompute the same claims, which re-bind to the same still-living
`claimRef`-pinned PVs), demonstrating the lossless-teardown guarantee on the linux-cpu substrate.

## Doctrine adopted

This phase is the first live amoebius realization of the storage-lifecycle contract. Each bullet names the
section it implements; individual sprints cite the same sections where they adopt them.

- [`storage_lifecycle_doctrine.md §2`](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing)
  — *one storage class, and it provisions nothing*: the single inert `no-provisioner` / `Retain` /
  `WaitForFirstConsumer` StorageClass, with every other class removed and every competing default annotation
  stripped, so there is no second way to get a volume.
- [`storage_lifecycle_doctrine.md §4`](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind)
  — *deterministic PV naming and the explicit bind*: PV names on the `<namespace>/<statefulset>/pv_<integer>`
  scheme, an explicit `claimRef` to the exact `(namespace, PVC-name)`, and node affinity to the host-path
  node for host-backed volumes.
- [`storage_lifecycle_doctrine.md §5`](../documents/engineering/storage_lifecycle_doctrine.md#5-sizes-are-explicit-hard-capped-and-one-volume-per-claim)
  — *sizes are explicit, hard-capped, one-volume-per-claim*: every PVC declares a minimum size and every PV a
  capacity; the host-side hard-cap enforcement mechanism is adopted as *design intent* (host caps stay
  advisory until it lands), and this phase asserts the explicit-size shape, not the enforcement mechanism.
- [`storage_lifecycle_doctrine.md §3`](../documents/engineering/storage_lifecycle_doctrine.md#3-pvcs-are-born-only-from-statefulsets)
  — *PVCs are born only from StatefulSets*: the witness claims exist only as StatefulSet `volumeClaimTemplate`
  claims; there are no bare PVCs, no Deployment- or Job-mounted claims.
- [`storage_lifecycle_doctrine.md §6`](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind)
  — *the lossless-teardown guarantee: deterministic rebind*: the phase's gate — a destroyed-then-recreated
  cluster recomputes the same claims which re-bind to the same retained volumes, nothing restored from a
  backup because nothing was released.
- [`storage_lifecycle_doctrine.md §7`](../documents/engineering/storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation)
  and [`§7.2`](../documents/engineering/storage_lifecycle_doctrine.md#72-amoebius-own-control-plane-state-is-the-minio-bucket-not-a-pvc)
  — *deleting durable data is forbidden under normal operation* / *the control plane holds no PVC*: the
  cluster delete in the gate releases claims and never reclaims volumes; the sole actor that may destroy the
  test-flagged witness bytes is the elevated harness; MinIO sits on a retained PV while the stateless
  control-plane singleton keeps its durable state in the Vault-enveloped MinIO bucket, holding no volume of
  its own.
- [`cluster_lifecycle_doctrine.md §7`](../documents/engineering/cluster_lifecycle_doctrine.md#7-ephemeral-spin-updown-with-deterministic-rebind)
  (cross-reference, not adopted here) — the ephemeral spin-up/down whose teardown *frees compute, never
  storage*, which the rebind gate exercises; and
  [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
  (delivered in Phase 15) — the SSA reconciler that renders and applies the StorageClass and PV objects.

## Sprints

## Sprint 16.1: The one inert `no-provisioner` StorageClass 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Storage/StorageClass.hs` (target path; not yet built)
**Blocked by**: Phase 15 gate (the typed renderer + live SSA reconciler that renders and applies the
StorageClass object); Phase 13 gate (an idempotent single-node `kind` cluster to install it into).
**Independent Validation**: after bring-up `kubectl get storageclass` shows **exactly one** class —
`provisioner: kubernetes.io/no-provisioner`, `reclaimPolicy: Retain`, `volumeBindingMode: WaitForFirstConsumer`
— and no other class and no `storageclass.kubernetes.io/is-default-class` annotation survives; a PVC created
with no PV to bind stays `Pending` (never dynamically provisioned).
**Docs to update**: `documents/engineering/storage_lifecycle_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`, this document.

### Objective
Adopt [`storage_lifecycle_doctrine.md §2 — one storage class, and it provisions nothing`](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing):
render the single inert StorageClass and delete the dynamic-provisioning machinery outright, so volumes exist
only because amoebius placed them and nothing in the normal cluster lifecycle can mint or reclaim one.

### Deliverables
- A single rendered StorageClass — `provisioner: kubernetes.io/no-provisioner`, `reclaimPolicy: Retain`,
  `volumeBindingMode: WaitForFirstConsumer` — applied through the Phase-15 reconciler under the `amoebius`
  field manager.
- Removal of every other StorageClass the base `kind` image ships and stripping of any competing default-class
  annotation, so a claim can never silently fall through to a dynamic provisioner.

### Validation
1. Assert post-bring-up there is exactly one StorageClass, it provisions nothing, and no default annotation
   points at any other class; a claim with no matching PV stays `Pending` rather than being provisioned.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 16.2: Deterministic retained-PV generation + the explicit bind 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Storage/RetainedPV.hs` (target path; not yet built)
**Blocked by**: Sprint 16.1 (the inert class the retained PVs bind under); Phase 15 gate (the reconciler
applies the rendered PVs and the witness StatefulSet).
**Independent Validation**: a one-ordinal StatefulSet `volumeClaimTemplate` claim binds to the PV named
`<namespace>/<statefulset>/pv_0`, whose `claimRef` names the exact `(namespace, PVC-name)` and whose capacity
matches the claim's declared minimum; deleting the PVC leaves the PV `Released` with its bytes intact and
re-bindable; no bare PVC or Deployment-/Job-mounted claim exists.
**Docs to update**: `documents/engineering/storage_lifecycle_doctrine.md`, `documents/engineering/manifest_generation_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`storage_lifecycle_doctrine.md §4 — deterministic PV naming and the explicit bind`](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind),
[`§5 — sizes are explicit, hard-capped, one-volume-per-claim`](../documents/engineering/storage_lifecycle_doctrine.md#5-sizes-are-explicit-hard-capped-and-one-volume-per-claim),
and [`§3 — PVCs are born only from StatefulSets`](../documents/engineering/storage_lifecycle_doctrine.md#3-pvcs-are-born-only-from-statefulsets):
compute both ends of the bind from stable identity so rebinding is never assigned by a race, and confine the
PVC creation path to exactly one shape.

### Deliverables
- Deterministic PV generation from `(namespace, statefulset, ordinal)`: PV name
  `<namespace>/<statefulset>/pv_<integer>`, explicit `claimRef` to the exact `(namespace, PVC-name)`, and node
  affinity to the host-path node for host-backed volumes (the trivial single-node case on this substrate).
- Explicit per-PVC minimum size and per-PV capacity, one volume per claim; the host-side hard-cap enforcement
  mechanism is flagged as design intent, not built (host caps stay advisory).
- The invariant that a PVC is only ever born from a StatefulSet `volumeClaimTemplate` — no bare PVCs, no
  Deployment- or Job-mounted claims — exercised with a minimal one-ordinal witness StatefulSet.

### Validation
1. Deploy a one-ordinal witness StatefulSet; assert its claim binds to the identity-named, `claimRef`-pinned
   PV of the matching capacity, and that node affinity pins the host-backed volume to its node.
2. Delete the PVC; assert the PV drops to `Released`, retains its bytes, and is re-bindable; assert no PVC
   exists outside a StatefulSet `volumeClaimTemplate`.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 16.3: The lossless-rebind gate — Postgres row + MinIO marker round-trip 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Storage/Rebind.hs`, `test/live/RebindSpec.hs` (target paths; not yet built)
**Blocked by**: Sprint 16.2 (the retained PVs + deterministic bind the round-trip depends on); Phase 14 gate
(the baked-binary Postgres and MinIO images served only from the in-cluster `distribution` registry — the
witnesses pull nothing from a public registry); Phase 13 gate (the midwife `cluster delete` + `recreate` the
gate drives).
**Independent Validation**: the marker row written into the Postgres witness and the marker object written
into the MinIO witness bucket read back byte-for-byte after a `cluster delete` + `recreate`; between the two
the PVs are observed `Released` with bytes intact and the recreated cluster re-binds the *same* PVs by
identity; the only actor that ultimately deletes the test-flagged witness volumes is the elevated harness.
**Docs to update**: `documents/engineering/storage_lifecycle_doctrine.md`, `documents/engineering/cluster_lifecycle_doctrine.md`, `DEVELOPMENT_PLAN/README.md`.

### Objective
Adopt [`storage_lifecycle_doctrine.md §6 — the lossless-teardown guarantee: deterministic rebind`](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind),
[`§7 — deleting durable data is forbidden under normal operation`](../documents/engineering/storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation),
and [`§7.2 — the control plane holds no PVC`](../documents/engineering/storage_lifecycle_doctrine.md#72-amoebius-own-control-plane-state-is-the-minio-bucket-not-a-pvc):
prove that a destroyed-then-recreated cluster finds its durable bytes unchanged because the original bytes
were never released — nothing is restored from a backup — while the cluster delete never reclaims a volume and
no normal-operation path can.

### Deliverables
- Minimal single-ordinal Postgres and MinIO witness StatefulSets on retained PVs (from Sprint 16.2), served
  from baked-binary images; these are rebind witnesses, not the HA Patroni-via-Percona / distributed-MinIO
  charts (Phase 18) and carry no Vault-enveloping (Phase 17).
- The `Rebind.hs` gate harness: write a marker row into the Postgres witness and a marker object into the
  MinIO witness bucket, `cluster delete` (claims released, PVs `Retained`), `cluster recreate`, then read the
  same bytes back — with the delete driven by the ordinary safe teardown that frees compute and never storage.
- A live `RebindSpec` that asserts the round-trip and, honestly, that this phase never deletes durable bytes:
  the eventual reclaim of the test-flagged witness volumes is the elevated harness's sole prerogative, kept
  out of the normal path.

### Validation
1. Run the marker write → `cluster delete` → observe PVs `Released`/bytes intact → `cluster recreate` → read
   cycle; assert the Postgres row and the MinIO object are byte-for-byte unchanged and re-bound by identity.
2. Assert the delete released claims but reclaimed no volume, and that no normal-operation code path deletes a
   retained PV or its bytes; the control-plane singleton mounts no PVC across the whole cycle.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/storage_lifecycle_doctrine.md` — the §6 lossless-rebind guarantee gains its first
  amoebius proof on linux-cpu; the §5 host-side hard-cap enforcement mechanism is recorded as still design
  intent (host caps advisory) or as delivered; the §10 planning-ownership pointer resolves to delivered
  Phase-16 sprints.
- `documents/engineering/cluster_lifecycle_doctrine.md` — the §7 ephemeral-rebind claim gains its first
  amoebius witness (teardown frees compute, never storage) on this substrate.
- `documents/engineering/manifest_generation_doctrine.md` — the §5 reconciler is recorded as the applier of
  the StorageClass and retained-PV objects, not just service workloads.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-16 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 16's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Storage/StorageClass.hs`,
  `src/Amoebius/Storage/RetainedPV.hs`, `src/Amoebius/Storage/Rebind.hs`, and the `RebindSpec` live suite as
  Phase-16 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase ordering this document sits under
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (no-provisioner retained
  PVs; no unbounded storage; the control plane holds no PVC)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — the no-provisioner
  retained-PV model, the deterministic bind, and the lossless-rebind guarantee adopted here
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — the ephemeral
  spin-up/down whose teardown the rebind gate exercises (cross-reference)
- [Manifest Generation & the Typed Reconciler](../documents/engineering/manifest_generation_doctrine.md) — the
  Phase-15 SSA reconciler that applies the StorageClass and retained-PV objects
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — Register 3 (live) and the elevated harness
  as the sole sanctioned deleter of test-flagged durable storage
- [phase_15](phase_15_renderer_reconciler.md) — the typed renderer + live SSA reconciler this phase builds on
- [phase_17](phase_17_vault_pki.md) — the root Vault whose durable KV rebinds on the retained storage proven here
- [phase_18](phase_18_platform_services.md) — the HA Postgres/MinIO platform stack that supersedes the witnesses
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
