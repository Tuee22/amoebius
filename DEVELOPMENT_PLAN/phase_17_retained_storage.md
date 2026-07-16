# Phase 17: No-provisioner retained storage + lossless rebind

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_18_vault_pki.md
**Generated sections**: none

> **Purpose**: Install the single inert `no-provisioner`/`Retain` StorageClass and the deterministic
> `<namespace>/<statefulset>/pv_<integer>` retained-PV bind on the live linux-cpu kind cluster, then prove the
> lossless-teardown guarantee — durable bytes rebind across a cluster delete + recreate with a Postgres row
> and a MinIO object marker round-tripping unchanged.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. The phase runs on the **linux-cpu** substrate in
**Register 3** (live infrastructure) — a single-node `kind` cluster brought up by the Phase 14 midwife, and
it opens only after the Phase 16 gate (the typed renderer + live SSA reconciler) closes, because the
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
write a marker row into a Postgres witness and a marker object into a MinIO witness, `cluster delete` (the
apiserver/etcd and PVC/PV API objects disappear while the external retained backing bytes remain), `cluster
recreate` (fresh PV objects whose pre-bound `claimRef` omits `uid`/`resourceVersion` point at that backing),
and read the same bytes back — the deterministic rebind.

The scope deliberately stops at *standing the retained-storage substrate up and proving it rebinds*. The
witness workloads are minimal single-ordinal StatefulSets that exercise the bind; distributed MinIO lands in
Phase 19 and HA Patroni-via-Percona Postgres in Phase 20, the Vault-enveloping of secrets is Phase 18, and the
Keycloak-owned edge is Phase 21 — none of which this phase requires. The control plane
itself is out of the retained-storage picture by construction: it is a stateless Deployment `replicas=1` that
holds **no PVC**, its durable state exclusively the Vault-enveloped MinIO bucket, so MinIO here is a retained
volume holder while the control plane is only a client of that bucket.

**Substrate:** linux-cpu — the whole gate runs on a single-node `kind` cluster on a linux-cpu host, in
Register 3 (live infrastructure); no apple, linux-cuda, or windows substrate is touched, and no live
infrastructure is required to *render* the StorageClass or PV objects (that stays pure, Registers 1–2).

**Register:** 3 — live infrastructure (§K).

**Gate:** durable **storage rebinds after a cluster delete + recreate with no data loss** — a marker row
written into a Postgres witness StatefulSet and a marker object written into a MinIO witness bucket both
round-trip byte-for-byte after the cluster is deleted (the cluster and its PVC/PV API objects are gone while
the retained backing remains) and recreated (the same StatefulSet identities recompute the same claims, which
bind to freshly rendered PV objects whose pre-bound `claimRef` omits `uid`/`resourceVersion` and points at the
same backing bytes), demonstrating the lossless-teardown guarantee on the linux-cpu substrate.

The gate is passed only when all of the following hold, checked against the Phase-0-pinned oracle corpus and
seeded mutants named in [§N](#n-gate-integrity-provisions):

- **Real teardown, not soft delete.** After `cluster delete`, an OS-boundary observer on the host (not the
  apiserver, which is destroyed) confirms the kind cluster is genuinely absent: `kind get clusters` lists no
  cluster, `docker ps` shows no kind node container, and the apiserver endpoint is unreachable. `recreate` is a
  fresh Phase-14 `pb bootstrap` producing a **new** apiserver/etcd (verified by a changed apiserver
  server-CA / cluster UID against run 1), into which the retained-PV objects are **re-rendered and re-applied**
  before any rebind is asserted. A `cluster delete` that leaves the node container or apiserver alive turns the
  committed mutant **M-soft-delete** red.
- **Bytes survive on the host, not in a surviving apiserver.** "Bytes intact between delete and recreate" is
  observed by inspecting the host retained-storage root directory (`${RETAINED_ROOT}`) **outside** any node
  container, while `kind get clusters` is empty — never by querying a PV status object that a real teardown has
  destroyed. The PV `Released` *status* is observed only in Sprint 17.2's live PVC-delete step against the
  still-running apiserver, not after `cluster delete`.
- **Run-unique marker, no seed path.** The marker content is a fresh random nonce generated by the harness per
  run (clause: Phase-0 pins the nonce-generation and absence-check contract, not the nonce value). The harness
  asserts the nonce is **absent** from both witnesses before the write, present byte-for-byte after recreate,
  and that **no write path executes post-recreate** (verified from the apiserver audit log / a `strace` argv
  observer on the witness process, not a self-emitted trace). The witness pod specs and images are asserted to
  carry **no init/seed/bootstrap step** that could reproduce the marker; a witness manifest that seeds the
  marker turns the committed mutant **M-seed-marker** red.
- **Committed mutants go red.** The gate re-runs the committed seeded mutants of [§N](#n-gate-integrity-provisions)
  (**M-soft-delete**, **M-seed-marker**, **M-reclaim-delete**, **M-no-rebind**) and passes only if every one of
  them turns the gate red; a green mutant fails the gate.
- **Honest ledger.** The gate still emits its proven/tested/assumed ledger; the host-side hard-cap enforcement
  (§5) and the Phase-22 control-plane singleton's no-PVC property (which has no realized subject at Phase 17)
  stay marked **UNVERIFIED**, not asserted as passing.

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
  cluster recomputes the same claims which re-bind to the same retained backing, with nothing restored from a
  backup because the backing bytes were never deleted.
- [`storage_lifecycle_doctrine.md §7`](../documents/engineering/storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation)
  and [`§7.2`](../documents/engineering/storage_lifecycle_doctrine.md#72-amoebius-own-control-plane-state-is-the-minio-bucket-not-a-pvc)
  — *deleting durable data is forbidden under normal operation* / *the control plane holds no PVC*: the
  cluster delete in the gate discards the cluster-local API objects and never reclaims backing volumes; the
  sole automated actor that may destroy the test-flagged witness bytes is the elevated harness; MinIO sits on
  a retained PV while the stateless control-plane singleton keeps its durable state in the Vault-enveloped
  MinIO bucket, holding no volume of its own.
- [`cluster_lifecycle_doctrine.md §7`](../documents/engineering/cluster_lifecycle_doctrine.md#7-ephemeral-spin-updown-with-deterministic-rebind)
  (cross-reference, not adopted here) — the ephemeral spin-up/down whose teardown removes ephemeral
  infrastructure and never durable backing, which the rebind gate exercises; and
  [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
  (delivered in Phase 16) — the SSA reconciler that renders and applies the StorageClass and PV objects.

## Sprints

## Sprint 17.1: The one inert `no-provisioner` StorageClass 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Storage/StorageClass.hs` (target path; not yet built)
**Blocked by**: Phase 16 gate (the typed renderer + live SSA reconciler that renders and applies the
StorageClass object); Phase 14 gate (an idempotent single-node `kind` cluster to install it into).
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
  `volumeBindingMode: WaitForFirstConsumer` — applied through the Phase-16 reconciler under the `amoebius`
  field manager.
- Removal of every other StorageClass the base `kind` image ships and stripping of any competing default-class
  annotation, so a claim can never silently fall through to a dynamic provisioner.

### Validation
1. Assert post-bring-up the live `kubectl get storageclass -o yaml` is byte-equal to the Phase-0-pinned golden
   `test/live/fixtures/storageclass_expected.yaml` (an independently hand-authored oracle, not regenerated from
   the renderer): exactly one class, `provisioner: kubernetes.io/no-provisioner`, `reclaimPolicy: Retain`,
   `volumeBindingMode: WaitForFirstConsumer`, and no `storageclass.kubernetes.io/is-default-class` annotation on
   any object.
2. Specific-reason negatives, each paired with the positive differing only in the foreclosed dimension: (a) a
   PVC with no matching PV stays `Pending` **with the specific event reason `WaitForFirstConsumer`** (no
   provisioner attempted) — asserting the reason string, not merely the `Pending` phase; the paired positive is
   an identical PVC that binds once its PV exists. (b) The negative fixture `two_storageclasses` (a second class
   plus a default-class annotation, committed in Phase 0) makes assertion 1 fail with the **specific reason
   `count != 1` / `default-class annotation present`**, distinguishing it from an unrelated golden mismatch.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 17.2: Deterministic retained-PV generation + the explicit bind 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Storage/RetainedPV.hs` (target path; not yet built)
**Blocked by**: Sprint 17.1 (the inert class the retained PVs bind under); Phase 16 gate (the reconciler
applies the rendered PVs and the witness StatefulSet).
**Independent Validation**: a one-ordinal StatefulSet `volumeClaimTemplate` claim binds to the PV whose
metadata and `claimRef` match the Phase-0-pinned independent oracle table `test/live/fixtures/claimref_table.csv`
(hand-authored from `(namespace, statefulset, ordinal)`, never derived from the renderer's own naming helper).
Because the logical identity `<namespace>/<statefulset>/pv_<integer>` is not a legal `metadata.name` (`/` and
`_` are forbidden), the scheme is realized as: `metadata.name` is the DNS-1123 encoding
`<namespace>-<statefulset>-pv-<integer>`, and the verbatim logical identity is carried in the label
`amoebius.io/pv-identity`; the table pins **both**, and the assertion checks both against it. The `claimRef`
names the exact `(namespace, PVC-name)`, and the PV capacity is **exactly equal** (`==`, not merely `>=`) to
the claim's declared minimum from the table. Deleting the PVC leaves the PV `Released`; the suite then
**re-creates the identical PVC** (via the same `volumeClaimTemplate` identity) and asserts it re-binds to the
same identity-named PV — including whatever `claimRef.uid` reconciliation the reconciler performs to clear the
stale bind — and that the bytes written before the delete read back through the re-bound claim. No bare PVC or
Deployment-/Job-mounted claim exists.
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
1. Deploy a one-ordinal witness StatefulSet; assert its claim binds to the PV whose `metadata.name`,
   `amoebius.io/pv-identity` label, `claimRef` `(namespace, PVC-name)`, and **exactly-equal** capacity all
   match the Phase-0-pinned `test/live/fixtures/claimref_table.csv` row, and that node affinity pins the
   host-backed volume to its node.
2. Write a nonce byte-string through the claim, then delete the PVC; assert the PV drops to `Released`. **Then
   exercise re-bind for real:** re-create the identical PVC and assert it re-binds to the same
   identity-named/`claimRef`-pinned PV and that the nonce reads back unchanged through the re-bound claim.
   Assert no PVC exists outside a StatefulSet `volumeClaimTemplate`.
3. The committed mutant **M-no-rebind** (a reconciler variant that leaves the PV `Released` but never clears the
   stale `claimRef.uid`, so a re-created PVC cannot bind) must turn assertion 2 red; a validation that checked
   only `.status.phase == Released` would leave it green and is therefore insufficient. The committed mutant
   **M-reclaim-delete** (PV rendered with `reclaimPolicy: Delete`) must turn assertion 2 red (the PV vanishes on
   PVC delete instead of going `Released`). Negative fixture `pv_capacity_mismatch` (capacity `>` the claim
   minimum) must fail assertion 1 with the **specific reason `capacity != declared minimum`**, paired with the
   equal-capacity positive that passes — foreclosing an oversized PV silently satisfying the bind.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 17.3: The lossless-rebind gate — Postgres row + MinIO marker round-trip 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Storage/Rebind.hs`, `test/live/RebindSpec.hs` (target paths; not yet built)
**Blocked by**: Sprint 17.2 (the retained PVs + deterministic bind the round-trip depends on); Phase 15 gate
(the baked-binary Postgres and MinIO images served only from the in-cluster `distribution` registry — the
witnesses pull nothing from a public registry); Phase 14 gate (the midwife `cluster delete` + `recreate` the
gate drives).
**Independent Validation**: the marker (a fresh per-run random nonce) written as a Postgres row and as a MinIO
object reads back byte-for-byte after a `cluster delete` + `recreate`. The nonce is asserted **absent** from
both witnesses before the write and present after recreate, with **no witness write path executed
post-recreate** (read from the apiserver audit log and a `strace`/argv observer on the witness process, never a
self-emitted compliance trace). "Bytes intact between delete and recreate" is observed by inspecting the host
retained-storage root `${RETAINED_ROOT}` **outside** any node container while `kind get clusters` is empty — a
real `cluster delete` destroys the apiserver, so the PV `Released` *status* is observed only in Sprint 17.2's
live PVC-delete step, not here. `recreate` is a fresh Phase-14 bootstrap (new apiserver/etcd, changed cluster
UID) into which the PV objects are re-rendered and re-applied before rebind is asserted; the recreated cluster
re-binds the *same backing bytes* through fresh PV objects computed by identity (matched against
`test/live/fixtures/claimref_table.csv`). The only actor
that ultimately deletes the test-flagged witness volumes is the elevated harness.
**Docs to update**: `documents/engineering/storage_lifecycle_doctrine.md`, `documents/engineering/cluster_lifecycle_doctrine.md`, `DEVELOPMENT_PLAN/README.md`.

### Objective
Adopt [`storage_lifecycle_doctrine.md §6 — the lossless-teardown guarantee: deterministic rebind`](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind),
[`§7 — deleting durable data is forbidden under normal operation`](../documents/engineering/storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation),
and [`§7.2 — the control plane holds no PVC`](../documents/engineering/storage_lifecycle_doctrine.md#72-amoebius-own-control-plane-state-is-the-minio-bucket-not-a-pvc):
prove that a destroyed-then-recreated cluster finds its durable bytes unchanged because the original backing
bytes were never deleted — nothing is restored from a backup — while the cluster delete never reclaims
durable backing and no normal-operation path can.

### Deliverables
- Minimal single-ordinal Postgres and MinIO witness StatefulSets on retained PVs (from Sprint 17.2), served
  from baked-binary images; these are rebind witnesses, not distributed MinIO (Phase 19) or HA
  Patroni-via-Percona (Phase 20), and carry no Vault-enveloping (Phase 18).
- The `Rebind.hs` gate harness: write a marker row into the Postgres witness and a marker object into the
  MinIO witness bucket, `cluster delete` (cluster/PVC/PV API objects gone, retained backing bytes intact),
  `cluster recreate` (fresh PV objects over the same backing), then read the same bytes back — with the delete
  driven by the ordinary safe teardown that frees compute and never storage.
- A live `RebindSpec` that asserts the round-trip and, honestly, that this phase never deletes durable bytes:
  the eventual reclaim of the test-flagged witness volumes is the elevated harness's sole prerogative, kept
  out of the normal path.
- The Phase-0-committed gate-integrity artifacts of [§N](#n-gate-integrity-provisions): the two-witness
  representative set, the `claimref_table.csv` / `storageclass_expected.yaml` oracles, the
  `no_retained_delete.sh` static check, and the seeded mutants **M-soft-delete**, **M-seed-marker**,
  **M-reclaim-delete**, **M-no-rebind** the gate re-runs and requires red.

### Validation
1. Run the cycle on the concrete representative set of [§N](#n-gate-integrity-provisions) (exactly two
   witnesses): generate a per-run nonce, assert its absence, write it as the Postgres row and the MinIO object,
   `cluster delete`, confirm via the host OS-boundary observer that the cluster is genuinely absent
   (`kind get clusters` empty, no kind node container in `docker ps`, apiserver unreachable) while
   `${RETAINED_ROOT}` still holds the bytes, `cluster recreate` as a fresh Phase-14 bootstrap (new apiserver
   UID, PV objects re-rendered and re-applied), then read back; assert the nonce is byte-for-byte unchanged,
   re-bound by identity against `claimref_table.csv`, and that no witness write path executed post-recreate
   (apiserver audit log + `strace` observer). The committed mutants **M-soft-delete** and **M-seed-marker** must
   both turn this assertion red.
2. Assert the full deletion reclaimed no backing volume (fresh PV objects re-appear post-recreate and
   `${RETAINED_ROOT}` bytes persist throughout). The "no normal-operation code path destroys retained backing
   bytes" universal negative is discharged two concrete ways: (a) a committed static/CI check asserts no
   non-harness module in `src/` issues a backing-store reclaim/destruction call (grep-level, committed as
   `test/ci/no_retained_delete.sh`; scoped PVC/PV binding-object deletion and whole-cluster deletion are
   allowed because neither deletes the external backing), and (b) post-cycle the fresh PV objects exist and
   host bytes are present. The control-plane singleton is a Phase-22 subject with **no realized instance at
   Phase 17**, so its "mounts
   no PVC" property is **not asserted as passing here** — it is recorded **UNVERIFIED** in the honesty ledger,
   not treated as a vacuously-true pass.

### Remaining Work
The whole sprint (📋 Planned).

## N. Gate-integrity provisions

This section pins the concrete corpus, the Phase-0-committed oracles, and the seeded mutants the Gate and each
sprint Validation above reference. Everything named here is authored and committed in Phase 0, before any
implementation exists.

**Representative set (concrete corpus).** Exactly two witnesses, no more: (1) a single-ordinal Postgres
StatefulSet in namespace `retained-witness` with one PVC `pgdata` on one retained PV, marker = a single row in
table `rebind_witness(nonce text)`; (2) a single-ordinal MinIO StatefulSet in namespace `retained-witness` with
one PVC `miniodata` on one retained PV, marker = one object `rebind/nonce` in bucket `rebind-witness`. Each
witness image is a Phase-15 baked binary served only from the in-cluster `distribution` registry (an
OS-boundary containerd/registry-log observer confirms zero public-registry pull during the cycle).

**Phase-0-committed oracles (independent of the implementation).**
- `test/live/fixtures/storageclass_expected.yaml` — the exact single-StorageClass golden (Sprint 17.1),
  hand-authored, not regenerated from the renderer.
- `test/live/fixtures/claimref_table.csv` — the independent reference table mapping
  `(namespace, statefulset, ordinal)` to the expected `metadata.name`, `amoebius.io/pv-identity` label,
  `claimRef` `(namespace, PVC-name)`, and exact capacity; authored by hand, never by the renderer's naming
  helper (Sprints 17.2, 17.3).
- `test/ci/no_retained_delete.sh` — the committed static check that no non-harness `src/` module issues a
  backing-store reclaim/destruction call. Scoped PVC/PV binding-object deletion and whole-cluster deletion are
  explicitly outside this check because the backing lives outside the cluster (Sprint 17.3 Validation 2a).
- Negative fixtures with pinned failure reasons: `two_storageclasses` (reason `count != 1` /
  `default-class annotation present`), `pv_capacity_mismatch` (reason `capacity != declared minimum`), each
  paired with a positive differing only in the foreclosed dimension.

**Committed seeded mutants (must go red).** Each is committed under `test/live/mutants/` and re-run by the gate;
a green mutant fails the gate.
- **M-soft-delete** (dropped-effect operator) — a `cluster delete` that deletes only the witness
  StatefulSets/PVCs and leaves the kind node container + apiserver alive. Must go red on the "cluster genuinely
  absent" OS-boundary assertion (Gate; 17.3 V1).
- **M-seed-marker** (union-arm addition) — a witness manifest carrying an init/seed step that reproduces the
  marker nonce on fresh start. Must go red on the absence-before-write / no-post-recreate-write-path assertion
  (Gate; 17.3 V1).
- **M-reclaim-delete** (guard weakening) — a PV rendered with `reclaimPolicy: Delete` instead of `Retain`. Must
  go red on the `Released`/rebind assertion (17.2 V2/V3).
- **M-no-rebind** (dropped-effect operator) — a reconciler variant that leaves the PV `Released` but never
  clears the stale `claimRef.uid`, so a re-created PVC cannot re-bind. Must go red on the actual re-bind step
  (17.2 V2/V3).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/storage_lifecycle_doctrine.md` — the §6 lossless-rebind guarantee gains its first
  amoebius proof on linux-cpu; the §5 host-side hard-cap enforcement mechanism is recorded as still design
  intent (host caps advisory) or as delivered; the §10 planning-ownership pointer resolves to delivered
  Phase-17 sprints.
- `documents/engineering/cluster_lifecycle_doctrine.md` — the §7 ephemeral-rebind claim gains its first
  amoebius witness (teardown frees compute, never storage) on this substrate.
- `documents/engineering/manifest_generation_doctrine.md` — the §5 reconciler is recorded as the applier of
  the StorageClass and retained-PV objects, not just service workloads.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-17 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 17's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Storage/StorageClass.hs`,
  `src/Amoebius/Storage/RetainedPV.hs`, `src/Amoebius/Storage/Rebind.hs`, and the `RebindSpec` live suite as
  Phase-17 design-first rows.

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
  Phase-16 SSA reconciler that applies the StorageClass and retained-PV objects
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — Register 3 (live) and the elevated harness
  as the sole sanctioned deleter of test-flagged durable storage
- [phase_16](phase_16_renderer_reconciler.md) — the typed renderer + live SSA reconciler this phase builds on
- [phase_18](phase_18_vault_pki.md) — the root Vault whose durable KV rebinds on the retained storage proven here
- [phase_19](phase_19_platform_backbone.md) / [phase_20](phase_20_platform_services_2.md) — the HA
  MinIO/Postgres platform stack that supersedes the witnesses
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
