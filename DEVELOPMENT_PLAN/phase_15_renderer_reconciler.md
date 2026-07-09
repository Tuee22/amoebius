# Phase 15: Typed renderer + live SSA reconciler

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, overview.md, phase_09_render_manifest_goldens.md, phase_11_boundary_fake_tool_harness.md, phase_14_base_image_registry.md, phase_16_retained_storage.md, phase_17_vault_pki.md, phase_20_live_dsl_singleton.md, system_components.md
**Generated sections**: none

> **Purpose**: Take the Phase-9 pure `render`'s object set and apply it to a live single-node `kind`
> cluster with amoebius's own server-side-apply reconciler — owned field manager, ApplySet prune, and
> wait-for-ready — converging the generation and proving an immediate re-run is a no-op.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 14 gate (the
multi-arch base image + jit-build resolver + in-cluster `distribution` registry) and runs on the
**linux-cpu** substrate in **Register 3** — the first phase whose gate actually *applies* rendered objects
to a live cluster. It builds the **live half** of the manifest doctrine: Phase 9 already stood up the pure,
total `render :: ServiceSpec -> [K8sObject]` and golden-locked its output in Register 1; this phase wires
that same output through the `discover → diff → enact` reconciler onto the single-node `kind` cluster from
Phase 13. The reconciler is exercised here **from the host binary against a scratch namespace**, against a
fixed hand-assembled object set — the in-cluster **control-plane singleton** that will eventually *own* it
(a Kubernetes Deployment `replicas=1` whose single-instance guarantee is delegated to k8s/etcd with **no
bespoke election** and no standby pods) arrives in Phase 20. Where a shape below is already exercised in a
sibling — prodbox renders a slice of its object set from typed Haskell records and applies it with
`kubectl apply -f`, stamping every object with an owner label — that is **sibling evidence, not an amoebius
result**; the SSA field-manager model, the ApplySet prune, and the unified wait-for-ready are amoebius's new
code.

## Phase Summary

This phase delivers amoebius's idempotent apply engine. It takes the pure Phase-9 `render` output as the
**desired** object set, reads the cluster's **observed** state from etcd through server-side apply, forms a
**typed diff**, and enacts it: every object is applied under a fixed `amoebius` server-side-apply field
manager (declare-owned-fields, never GET-modify-PUT, so a drifted owned field is forced back on the next
apply and never clobbers another manager's fields); every rendered object carries an `amoebius/owner` label
so the engine can list the prior ApplySet and **prune** any owned object no longer in the desired set; and
each applied object is waited to its live readiness condition — a rollout completing, a `Ready`/`Available`
status, a CR `status` going healthy — observed from the live object and **never** a `threadDelay`. There is
**no release store**: desired state is always exactly `render(spec)`, recomputed rather than stored, so
there is nothing to desync. The immutable content-addressed release ledger and rollback of the manifest
doctrine's §6.1 compose with the later content-store phase and are **out of scope** here; this phase proves
only convergence and idempotence. The reconciler runs from the host binary against a throwaway namespace on
the live `kind` cluster; the Deployment-`replicas=1` singleton that will own it (single-instance delegated
to k8s/etcd, no election) is Phase 20.

**Substrate:** linux-cpu — the whole gate runs on the single-node `kind` cluster on a linux-cpu host from
Phase 13; no apple, linux-cuda, or windows substrate is touched.

**Gate:** in **Register 3**, the Phase-9 pure `render` output for a representative hand-assembled service
set is applied to a scratch namespace on the live single-node `kind` cluster by the amoebius reconciler
under the fixed `amoebius` server-side-apply field manager; prior-owned objects absent from the desired set
are ApplySet-pruned; each applied object is waited to its live readiness condition (never a `threadDelay`)
so the generation converges; and an immediate re-run of the same spec is a **no-op** — zero further
mutations, the same converged live state.

## Doctrine adopted

- [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
  — **the apply/reconcile engine: server-side apply, owned field manager, prune, wait.** This phase is the
  first amoebius realization of that engine's four mechanisms: SSA under a fixed `amoebius` field manager,
  owner-label / ApplySet pruning, and wait-for-ready observed from the live object. Rollback (its fourth
  mechanism) and the content-addressed release ledger stay deferred.
- [`manifest_generation_doctrine.md §6`](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderinforcespec-observed-is-etcd-a-diff-is-typed)
  — **the reconcile state model: desired is `render(spec)`, observed is etcd, a diff is typed.** amoebius
  keeps **no release store**: desired state is recomputed from the spec, observed state is read from etcd
  through SSA, and a replica change is a typed spec-generation diff (declare-new, no need to read the old),
  so there is no stored desired-state blob to desync.
- [`manifest_generation_doctrine.md §2`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects)
  — **the typed manifest model** (the pure renderer half): this phase *consumes* the Phase-9 pure, total
  `render :: ServiceSpec -> [K8sObject]` as the desired set and does not re-derive it; the object set applied
  live is byte-for-byte the value the `--dry-run` previews.
- [`readiness_ordering_doctrine.md §6`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps)
  — **the runtime enactor: the reconciler observes, never sleeps.** The wait-for-ready this phase builds is
  the runtime enactor of a readiness edge — the live condition is read from the object, never assumed by a
  fixed sleep.
- [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)
  — **the control-plane singleton.** The reconciler is, at steady state, run by the in-cluster singleton — a
  Deployment `replicas=1`, stateless (no PVC), single-instance delegated to k8s/etcd (a `Lease` only if a
  hard lock is ever needed), **no bespoke election**. This phase drives the reconciler from the host binary
  as a precursor; standing it up *inside* the singleton is Phase 20.
- [`conformance_harness_doctrine.md §3`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
  — **rendering never touches live infrastructure.** The boundary this phase honors from the other side:
  the render/plan/`--dry-run` stayed cluster-free through Phase 11, and **apply is the first live step** — so
  live prerequisites (a reachable cluster, credentials) belong here, never on the render path.
- [`generated_artifacts_doctrine.md §3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)
  — the applied `[K8sObject]` set is emitted from the Haskell source of truth and **never committed**; what
  reaches the cluster is generated at apply time, not a checked-in manifest.
- [`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing)
  — **Register 3** (live infrastructure): the register this phase's gate reaches; and
  [`§4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact),
  the per-run proven/tested/assumed ledger the live convergence emits (no skips, fail fast; the scratch
  namespace is torn down leak-free).

## Sprints

## Sprint 15.1: The typed reconcile state model — `desired = render(spec)`, observed via SSA, a typed diff 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/Reconcile.hs` (the `discover → diff → enact` driver), `src/Amoebius/Manifest/Diff.hs` (the typed desired/observed diff) — target paths, not yet built.
**Blocked by**: Phase 9 gate (the pure `render :: ServiceSpec -> [K8sObject]` whose output is the desired set); Phase 13 gate (the live single-node `kind` cluster the observed state is read from); Phase 14 gate (the in-cluster `distribution` registry the applied workloads resolve their images against).
**Independent Validation**: against a scratch namespace, the engine computes `desired = render(spec)`, reads the live objects and their `amoebius`-managed fields through SSA, and produces a typed diff whose adds/updates/prunes match a hand-checked expectation; there is **no** on-disk or in-cluster release-store artifact anywhere in the path (a source/inspection gate confirms desired state is recomputed, never stored).
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md` (backlink §6 to the Phase-15 live state model), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`manifest_generation_doctrine.md §6`](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderinforcespec-observed-is-etcd-a-diff-is-typed):
make desired state a pure function of the spec (`desired = render(spec)`, reusing the Phase-9 renderer
unchanged), observed state the live etcd objects read through SSA, and the diff a typed value — with **no
release store** to drift out of sync, so a replica bump is a declare-new-owned-field change that never needs
to read the old value.

### Deliverables
- The `discover → diff → enact` reconcile driver over one cluster's Kubernetes objects: `desired` from
  `render(spec)`, `observed` from a live read through the `amoebius` field manager, `diff` typed.
- A typed diff distinguishing objects to apply (add/update) from prior-owned objects to prune, computed
  without a stored desired-state blob — the Phase-9 render is the only source of desired.

### Validation
1. On a scratch namespace, the diff over `render(spec)` vs. the live read equals a hand-checked
   add/update/prune set; a source/inspection gate confirms no release store exists on the path.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 15.2: Server-side apply under the fixed `amoebius` field manager + drift self-heal 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/Apply.hs` (the SSA writer declaring the `amoebius` field manager) — target paths, not yet built.
**Blocked by**: Sprint 15.1.
**Independent Validation**: applying a generation to a scratch namespace records, per field, that the `amoebius` manager owns exactly the declared fields; a controller-populated field owned by another manager is **not** clobbered; mutating a field amoebius owns and re-applying forces it back to the declared value (drift self-heals), while an unrelated foreign-owned field is left untouched.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md` (the §5 SSA-field-manager honesty note flips from design intent to a delivered live apply), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait):
apply every object with server-side apply declaring the fixed `amoebius` field manager — declare the fields
amoebius intends and let the apiserver merge, never GET-modify-PUT — so drift on an amoebius-owned field
self-heals on re-apply and fields owned by other managers are never overwritten. The prodbox owner-label
seed is *sibling evidence, not an amoebius result*; the SSA field-manager model is amoebius's new code.

### Deliverables
- The SSA apply path: each rendered object applied with `fieldManager=amoebius` and force-conflicts on
  amoebius-owned fields only; every object stamped with the `amoebius/owner` label identifying its
  generation.
- Declare-owned-fields semantics: a replica or image change is asserted as an owned field without reading
  the prior value; a hand-mutated amoebius-owned field is corrected on the next apply.

### Validation
1. Apply a generation; assert per-field `amoebius` ownership on the live objects. Mutate an owned field and
   re-apply; assert it is forced back while a foreign-owned field is untouched.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 15.3: Owner-label / ApplySet prune of prior-owned objects no longer desired 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/Prune.hs` (list-prior-owned-set + prune-absent) — target paths, not yet built.
**Blocked by**: Sprint 15.2.
**Independent Validation**: after applying a desired set that drops a previously-present service, the engine lists the prior ApplySet by the `amoebius/owner` label and deletes exactly the owned objects no longer desired — reconstructing the prior set from the live cluster, never from a stored release manifest; a foreign object without the owner label is never pruned.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md` (the §5 ApplySet-prune honesty note gains its first amoebius validation), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait):
after applying the desired set, list the previously-owned objects (the prior ApplySet, found by the
`amoebius/owner` label on the live objects, per [`§6`](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderinforcespec-observed-is-etcd-a-diff-is-typed))
and **prune** any owned object no longer in the desired set — garbage-collecting a removed service's objects
without any release store. This generalizes the prodbox `prodbox.io/id` owner-label seed (*sibling evidence,
not an amoebius result*) into a real ApplySet prune.

### Deliverables
- The prune pass: list live objects carrying the `amoebius/owner` label, subtract the current desired set,
  and delete the remainder — the prior object set reconstructed from etcd, never a Helm release blob.
- A safety boundary: only objects carrying the amoebius owner label are ever prune candidates; unlabeled or
  foreign-owned objects are out of scope.

### Validation
1. Apply a set, then apply a set with one service removed; assert exactly that service's owned objects are
   pruned and every other object (including a hand-created unlabeled object) survives.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 15.4: Wait-for-ready + the idempotent-convergence gate (re-run no-op) 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/Wait.hs` (readiness observed from the live object), `test/live/ReconcileConvergeSpec.hs` (the Register-3 convergence + no-op battery, torn down leak-free) — target paths, not yet built.
**Blocked by**: Sprint 15.3, Sprint 15.2.
**Independent Validation**: after apply, the engine waits for each object's live readiness condition (rollout complete, `Ready`/`Available`, CR `status` healthy) read from the object — a source gate confirms **no `threadDelay`** stands in for a readiness observation; the generation converges; an immediate re-run of the same spec applies zero mutations (a byte-stable no-op) and prunes nothing; the scratch namespace tears down leak-free.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`, `documents/engineering/readiness_ordering_doctrine.md` (the §6 runtime-enactor claim gains its first amoebius validation), `DEVELOPMENT_PLAN/README.md` (flip the Phase-15 status when the gate passes).

### Objective
Adopt [`manifest_generation_doctrine.md §5`](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
(wait-for-ready) and [`readiness_ordering_doctrine.md §6`](../documents/engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps):
gate convergence on each applied object's live readiness condition observed from the object (never a fixed
sleep), then prove the whole engine idempotent — a re-run of the same `render(spec)` is a no-op — and emit a
Register-3 proven/tested/assumed ledger, tearing the scratch namespace down leak-free
([`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)).

### Deliverables
- Wait-for-ready: the engine blocks on the live readiness condition per applied object, read from the object;
  no `threadDelay` substitutes for a readiness observation.
- The convergence battery: apply `render(spec)` to a scratch namespace → converge → re-apply the identical
  spec and assert **zero** mutations and **zero** prunes (the no-op) → tear the namespace down with no
  leaked objects; a Register-3 ledger records the live convergence, marking the release-ledger/rollback
  residue UNVERIFIED (deferred).

### Validation
1. `cabal test reconcile-converge` (Register 3, linux-cpu `kind`) is green — the generation converges under
   observed readiness, the immediate re-run is a byte-stable no-op, and the namespace tears down leak-free;
   a source gate confirms no `threadDelay` gates readiness.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/manifest_generation_doctrine.md` — the §5 SSA/ApplySet/wait honesty note flips from
  "design intent" to a delivered live reconciler with the Register-3 ledger attached; §6's "desired is
  `render(spec)`, no release store" gains its first amoebius validation. Keep §6.1's content-addressed
  release ledger and §5's rollback explicitly as the deferred content-store-phase residue.
- `documents/engineering/readiness_ordering_doctrine.md` — the §6 runtime-enactor claim (observe, never
  sleep) gains its first amoebius proof.
- `documents/engineering/daemon_topology_doctrine.md` — record that Phase 15 drives the reconciler from the
  host binary; the §3 singleton that *owns* it (Deployment `replicas=1`, delegated single-instance, no
  election) is stood up in Phase 20.
- `documents/engineering/generated_artifacts_doctrine.md` — note that the applied `[K8sObject]` set is
  generated at apply time and never committed.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-15 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 15's gate substrate (linux-cpu) in the per-phase substrate
  map.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Manifest/{Reconcile,Diff,Apply,Prune,Wait}.hs`
  and the `reconcile-converge` live suite as Phase-15 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  live-proof acceptance token: *converges and re-run is a no-op*, proven in Register 3)
- [overview.md](overview.md) — target architecture and the no-Helm / no-release-store reconciler posture
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — §5 the apply/reconcile
  engine adopted here; §6 the reconcile state model; §2 the pure renderer consumed from Phase 9
- [Readiness Ordering Doctrine](../documents/engineering/readiness_ordering_doctrine.md) — §6 the runtime
  enactor (observe, never sleep) the wait-for-ready realizes
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — §3 the Deployment-`replicas=1`
  singleton (delegated single-instance, no election) that will own this reconciler in Phase 20
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — §3 the invariant
  that rendering never touches live infrastructure; apply is the first live step
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — why the applied
  object set is generated and never committed
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 3 (live), §4 the per-run ledger
- [phase_09](phase_09_render_manifest_goldens.md) — the pure `render` + rendered-output goldens this phase applies
- [phase_11](phase_11_boundary_fake_tool_harness.md) — the Register-2 fake-apply this phase replaces with real tools
- [phase_13](phase_13_midwife_bootstrap_kind.md) — the live single-node `kind` cluster this phase applies to
- [phase_14](phase_14_base_image_registry.md) — the in-cluster registry the applied workloads resolve images against
- [phase_20](phase_20_live_dsl_singleton.md) — the Deployment-`replicas=1` singleton that stands the reconciler up in-cluster
