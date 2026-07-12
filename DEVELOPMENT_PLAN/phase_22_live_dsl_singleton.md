# Phase 22: Live DSL deploy via the replicas=1 singleton

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_10_chain_kernel_dryrun.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_16_renderer_reconciler.md, DEVELOPMENT_PLAN/phase_19_platform_backbone.md, DEVELOPMENT_PLAN/phase_20_platform_services_2.md, DEVELOPMENT_PLAN/phase_23_app_tenancy.md, DEVELOPMENT_PLAN/phase_26_release_lifecycle.md, DEVELOPMENT_PLAN/phase_27_network_fabric_wireguard.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Turn the pre-cluster-proven DSL into a live deploy — the Deployment-`replicas=1` control-plane singleton decodes one `.dhall` and reconciles the platform plus a trivial app onto a real cluster, with single-instance delegated to k8s/etcd and no amoebius election.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 21 gate (Keycloak-owned
ingress) and runs on the **linux-cpu** substrate in **Register 3** — live infrastructure: the single-node
`kind` cluster of Phases 13–19, its standard platform-service stack (Phase 19) already reconciled by the
Phase-15 typed renderer + SSA reconciler onto the Phase-16 retained storage. The control-plane singleton
role generalizes the prodbox root single-node control-plane behaviour and rides the shared daemon spine
proven in prodbox — but that is **sibling evidence, not an amoebius result**; amoebius has not yet built any
sprint here, and single-instance is a k8s/etcd property with nothing for amoebius to prove.

## Phase Summary

This phase makes the DSL **run live**. Its design half is already discharged in the pre-cluster band
(Registers 1–2, substrate `none`): the two typed gates — Gate 1, the Dhall typechecker (Phase 4), and Gate 2,
the in-process `Dhall.inputFile auto` decoder (Phase 5) — the illegal-state corpus and its per-entry
validation-locus ledger (Phase 6), the capacity/topology folds (Phase 7), the capability→provider→shape
binder (Phase 8), the pure `render` goldens (Phase 9), and the `chain`/`--dry-run` plan (Phase 10) were all
authored and proven **in-process, with no cluster**. Phase 22 adds the runtime residue: the in-cluster
**control-plane singleton** deployed as a Kubernetes **Deployment with `replicas=1`** — exactly one brain per
cluster, holding total cluster + secret authority — that decodes the already-proven `InForceSpec` and runs the
idempotent `discover → diff → enact → re-observe` reconcile loop driving a **real** linux-cpu cluster toward
it, applying the standard platform stack plus a trivial app through the Phase-15 reconciler to convergence with
a leak-free teardown.

Single-instance of that singleton is **delegated to k8s/etcd**: the Deployment controller and etcd guarantee
convergence to one running pod and reschedule it on node loss, and where strict at-most-one-writer must survive
a rolling update or partition the mechanism is a Kubernetes `Lease` (the etcd-backed client-go leader-election
object) — **never a bespoke amoebius election, no ranked-failover rule, no warm-standby candidate population,
no signed-commit-log protocol**. The singleton is **stateless at the pod level** — it holds no PVC; its
durable state is exclusively the Vault-enveloped MinIO bucket — so a lost pod loses nothing. As a regression
belt, the pre-cluster negative corpus of Phase 6 is re-run against this live deploy path and each fixture still
fails to type-check or decode — but that type/decode result was **already proven in the pre-cluster band**;
here it is a live guard, not the proof. Full app tenancy (own namespace, `<app>/<bucket>` ObjectStore,
in-namespace Sql) is deliberately deferred to Phase 23; the app here is trivial.

**Substrate:** linux-cpu — the single-node `kind` cluster from Phases 13–19; no apple, linux-cuda, or windows
substrate is exercised by this phase's gate.

**Register:** 3 — live infrastructure (§K).

**Gate:** on a single-node linux-cpu `kind` cluster, one `.dhall` decodes and the **Deployment-`replicas=1`
control-plane singleton** — single-instance delegated to k8s/etcd, with **no amoebius election** — reconciles
the standard platform-service stack plus a trivial app to convergence and tears down leak-free, while the
pre-cluster (Phase-6) negative corpus, re-run against the same live deploy path, still fails at Gate 1 or
Gate 2 — a **Register-3** live-infrastructure check.

**Gate-integrity clauses (§M).** The gate is hardened as follows and passes only when every clause below holds:

- **Attribution via an OS-boundary observer (§M.5, forecloses the decorative-singleton cheat).** The gate
  harness (`test/integration/Phase20Gate.hs`) runs under a kubeconfig whose RBAC (a committed
  `test/fixtures/phase20/harness-rbac.yaml`) grants it exactly: `create`/`get`/`delete` on the singleton's own
  `Deployment`, `ServiceAccount`, and `RoleBinding`, and cluster-wide read-only (`get`/`list`/`watch`) —
  **and no write verb on any platform/app object kind**. Every platform-service and trivial-app object mutation
  observed in the gate window is read from the **apiserver audit log** (the OS-boundary observer — never a
  trace the singleton emits about itself) and each such write's `user.username` /
  `user.extra.authentication.kubernetes.io/…` MUST resolve to the singleton pod's in-cluster ServiceAccount;
  the audit log MUST record **zero** platform/app-object writes attributed to the harness principal. A run in
  which the harness principal issued any platform/app write, or in which the singleton SA issued none, fails.
- **Concrete representative set (§M.7).** "the standard platform-service stack" is exactly the Phase-18
  backbone: **MetalLB, MinIO (distributed), Pulsar (broker+bookie), Prometheus+Grafana, the Percona operator,
  and the named per-consumer Patroni Postgres clusters with pgAdmin**; the "trivial app" is exactly the
  single-service Deployment+Service+HTTPRoute of `dhall/examples/platform_plus_trivial_app.dhall`. No other
  service set satisfies the gate.
- **Phase-0-pinned oracle (§M.1).** The positive fixture `dhall/examples/platform_plus_trivial_app.dhall`, the
  expected per-pass enact sets (`test/fixtures/phase20/expected-enact-pass1.json`,
  `…/expected-enact-pass2.json`), the perturbation target list (`…/perturb-targets.txt`), and the negative
  corpus's expected Gate-1/Gate-2 rejection-tag table (`…/negative-expected-tags.tsv`, hand-authored,
  independent of the singleton's own decoder output — §M.3) are all **committed in Phase 0 before
  `Singleton.hs`/`Reconcile.hs`/`Deploy.hs` exist**; none is regenerated from implementation output.
- **Committed seeded mutant (§M.2).** The gate names **≥1 committed seeded mutant** that MUST turn it red:
  the **dropped-effect** mutant `Reconcile.hs::enact` that returns success without issuing the SSA patch (so
  the perturbed platform component is never restored) — committed under
  `test/fixtures/phase20/mutants/enact-noop.patch` and re-run each gate, asserted red because pass-1 restores
  nothing. A second **effect-swap** mutant (the harness principal, not the singleton SA, issues the writes)
  MUST also go red via the attribution clause above.

## Doctrine adopted

- [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)
  — *the control-plane singleton*: every cluster has exactly one brain holding total authority over the cluster
  and its secrets. Per [§3.1](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election)
  ("exactly one pod" is a k8s/etcd property, not an amoebius election), the singleton is a **Deployment
  `replicas=1`**, **stateless** at the pod level (no PVC; durable state exclusively the Vault-enveloped MinIO
  bucket), and single-instance is **delegated to k8s/etcd** — a `Lease` where a hard lock is needed, never a
  bespoke election. This phase delivers that role live; prodbox's root single-node control-plane behaviour is
  **sibling evidence, not an amoebius result**.
- [`daemon_topology_doctrine.md §5`](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected)
  — *single-instance and coordination — delegated, not elected*: amoebius builds no ranked-failover rule, no
  signed-commit-log election, and no warm-standby candidate population; re-deriving consensus etcd already
  provides would add a second coordination plane to prove correct and deadlock at cold-start. This phase honors
  that posture — the only intra-cluster single-writer machinery is the Deployment plus an optional `Lease`.
- [`daemon_topology_doctrine.md §6`](../documents/engineering/daemon_topology_doctrine.md#6-the-shared-daemon-spine)
  — *the shared daemon spine*: the singleton runs the `load → prereq → acquire → ready → serve → drain → exit`
  lifecycle (nested `bracket`/`withAsync`, no `forkIO`), serves `/healthz` / `/readyz` / `/metrics`, logs
  structured JSON, and takes no `PATH` or environment-variable precedence; readiness is a witnessed condition,
  never a `threadDelay` or filesystem marker. The spine is **proven in prodbox** — inherited design intent, not
  a tested amoebius result.
- [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
  — *the illegal-state-unrepresentable contract* and its **two typed gates** (Gate 1, the Dhall typechecker;
  Gate 2, the in-process Haskell decoder): "if it decodes, it is deployable" was discharged in-process in the
  pre-cluster band. This phase runs the **runtime residue** — the same two gates guard the **live** deploy
  path, and the decoded IR is what the singleton reconciles — proving the apiserver actually admits what the
  decoder blessed, without re-establishing the type discipline itself.

## Sprints

## Sprint 20.1: The control-plane singleton — a Deployment replicas=1, single-instance from k8s/etcd 📋

**Status**: Planned
**Implementation**: `src/Amoebius/ControlPlane/Singleton.hs` (the in-cluster singleton role + the shared
daemon spine); `src/Amoebius/ControlPlane/Reconcile.hs` (the `discover → diff → enact → re-observe` loop
wrapping the Phase-15 typed reconciler); the singleton's own generated `Deployment replicas=1` manifest,
rendered and applied by the Phase-15 reconciler (no Helm) — target paths, not yet built.
**Blocked by**: Phase 16 gate (the typed renderer + SSA reconciler — the singleton is itself a rendered,
applied object); Phase 18 gate (root Vault — the singleton is the in-cluster principal that operates Vault);
Phase 14 gate (the `kind` cluster + the host-daemon→singleton handoff the midwife begins).
**Independent Validation**: on the single-node linux-cpu cluster the singleton manifest is a **Deployment with
`replicas=1`** carrying **no PVC**; the pod comes up, runs the daemon spine, and serves `/healthz` / `/readyz`
/ `/metrics`; deleting the pod causes k8s to reschedule exactly one replacement (never two live) with no data
loss; the manifest contains **no amoebius election controller, no ranked-failover config, and no standby
pod**. **"Never two live" is observed concretely (§M.5):** a `kubectl get pods -l <singleton-selector> --watch`
stream (or an equivalent apiserver watch — the OS-boundary observer, not the singleton's own log) is recorded
across the full delete→reschedule window, and the count of pods in phase `Running` with `Ready=True` for the
singleton selector MUST never exceed 1 at any sampled point. **"No data loss" names the durable state
probed:** before the delete the singleton's `InForceSpec` object is written to the Vault-Transit-enveloped
MinIO bucket; after the replacement reports `/readyz` ready it reads that object back and the decrypted bytes
are byte-identical to the pre-delete write (a stateless pod losing its durable MinIO state would fail this).
**Docs to update**: `documents/engineering/daemon_topology_doctrine.md`,
`documents/engineering/manifest_generation_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton),
[`§3.1`](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election),
[`§5`](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected),
and [`§6`](../documents/engineering/daemon_topology_doctrine.md#6-the-shared-daemon-spine): deliver the
in-cluster control-plane singleton as a Deployment-`replicas=1` role that holds total cluster + secret
authority and runs the reconcile loop, with single-instance delegated to k8s/etcd and no amoebius election.

### Deliverables
- A control-plane singleton deployed as a **generated typed `Deployment replicas=1`** by the Phase-15
  reconciler, **stateless** (no PVC; its durable `InForceSpec` state is the Vault-Transit-enveloped MinIO
  object), running the shared daemon spine (`load → prereq → acquire → ready → serve → drain → exit`, no
  `forkIO`, structured JSON logs, no env / `PATH`).
- The `discover → diff → enact → re-observe` reconcile loop that decodes the `InForceSpec` in-process
  (Phase-5 decoder), binds capabilities (Phase-8 binder), and applies the resulting manifests through the
  Phase-15 typed reconciler — idempotently, driven only by observed cluster state.
- Single-instance **delegated to k8s/etcd**: the Deployment controller keeps one pod; a Kubernetes `Lease` (the
  etcd-backed client-go leader-election object) is the sole mechanism where strict at-most-one-writer must
  survive a rolling update or partition — **no bespoke election, no signed commit log, no standby population**.
- Secret authority fused to the role (operates root Vault as the single in-cluster writer) and the admin-REST
  control surface stub through which the operator `pb` client later drives the cluster.

### Validation
1. The singleton manifest is a `Deployment replicas=1` with no PVC; the pod runs the spine and reports
   `/readyz` ready; a pod delete reschedules exactly one replacement (Ready-pod cardinality never exceeds 1
   across the watched reschedule window) with the MinIO-held `InForceSpec` read back byte-identical afterward.
2. The reconcile loop runs one idempotent pass to convergence from a decoded spec and a re-run is a no-op,
   where **"no-op" is defined observably (§M.6) as: the second pass's apiserver audit log records zero mutating
   writes (`create`/`update`/`patch`/`delete`) under the singleton field manager** — unchanged end-state
   readiness alone does not satisfy this. To prove the compute path actually ran on the second pass (not a
   skipped/memoized short-circuit), the second pass executes with any reconcile result cache bypassed and its
   `discover` step is observed to have re-read live cluster state before concluding the empty diff. The
   codebase contains no election/ranked-failover module and no standby pod is ever scheduled.

> **Honesty.** This sprint delivers the singleton *role* and reconcile *loop*. Single-instance
> ("never two simultaneous active singletons") is **not an amoebius proof obligation** — it is a k8s/etcd
> property ([daemon_topology_doctrine.md §3.1](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election));
> the one amoebius simulation/proof obligation is the cross-cluster gateway migration, owned and gated in the
> multi-cluster phase, never asserted here.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 20.2: Live reconcile of the platform + a trivial app from one `.dhall` 📋

**Status**: Planned
**Implementation**: `dhall/examples/platform_plus_trivial_app.dhall` (the positive deploy fixture);
`src/Amoebius/ControlPlane/Deploy.hs` (the singleton's platform + trivial-app reconcile entry) — target paths,
not yet built.
**Blocked by**: Sprint 20.1 (the running singleton + reconcile loop); Phase 19 gate (the standard
platform-service stack the `.dhall` deploys); Phase 5 (the Gate-2 decoder producing the in-memory IR the loop
consumes).
**Independent Validation**: one `.dhall` decodes through `Dhall.inputFile auto` to its IR and the singleton
reconciles the standard platform stack plus a trivial single-service app to ready on the linux-cpu cluster.
**Because Phases 13–19 leave the platform pre-converged, the harness first perturbs it (§M.6, forecloses the
pre-converged-ride cheat):** before the first pass it deletes the named components in
`test/fixtures/phase20/perturb-targets.txt` (at minimum one platform `Deployment` and its `Service` — e.g. the
Prometheus `Deployment`+`Service`), then asserts **per-pass enact records read from the apiserver audit log
(§M.5), not the singleton's self-report:** the **first** pass's created/patched set is **non-empty** and
matches `expected-enact-pass1.json` (it restores the deleted components to Ready), and the **second**
invocation's enact set is **empty** and matches `expected-enact-pass2.json` — a `no-op` meaning **zero mutating
writes under the singleton field manager in the audit log**, not merely unchanged end-state readiness. A
teardown then leaves **no leaked resources**: the postflight sweep is scoped explicitly to **this run's
provisioned objects, identified by the run-unique label `amoebius.dev/phase20-run=<run-id>` the singleton
stamps on every object it creates** (Phase-31 flag-at-creation machinery is not assumed; this label set is
authored here), and the sweep is empty over that label set; separately, every platform component perturbed by
the harness is asserted back at Ready so the shared Phase-18 stack is left as found.
**Docs to update**: `documents/engineering/dsl_doctrine.md`,
`documents/engineering/manifest_generation_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
at the runtime layer: the two typed gates guard the **live** deploy, and the decoded IR is what the singleton
reconciles onto a real cluster — proving "if it decodes, it is deployable" holds live, that the apiserver
admits what the decoder blessed. The type/decode integrity itself was proven in-process in the pre-cluster
band; here it is exercised, not re-established.

### Deliverables
- A positive deploy `.dhall` composing the standard platform-service stack (Phase 19) and a **trivial**
  single-service app — deliberately narrower than the Phase-21 tenancy projection (no per-app namespace,
  ObjectStore, or in-namespace Sql fanout).
- The singleton's live reconcile of that spec: decode → capability-bind → render → SSA-apply → wait-to-ready,
  each edge a witnessed condition — **the witness for each apply/ready edge is externally observable apiserver
  evidence (the object's live `status`/managed-fields and the audit-log write record), never a log line or
  metric the singleton emits about itself (§M.5)** — with a re-run proven idempotent (no drift, no re-apply)
  under the audit-log no-op definition above.
- A leak-free teardown obligation carried by the deploy fixture — a test-topology `.dhall` whose postflight
  sweep asserts every provisioned object (the run-unique-labelled set defined in Independent Validation) was
  reclaimed, while the pre-existing Phase-18 platform stack is restored to Ready rather than swept.

### Validation
1. After the harness perturbs the named platform components, the `.dhall` reconcile's first pass restores them
   and brings the platform + trivial app up on the linux-cpu cluster (first-pass audit-log enact set non-empty,
   matching `expected-enact-pass1.json`); the app is reachable through the Phase-19 Keycloak-owned edge; a
   re-run is a no-op (second-pass audit-log enact set empty, matching `expected-enact-pass2.json`).
2. Teardown leaves no leaked resources (the postflight sweep over the run-unique label set is empty and the
   perturbed platform components are back at Ready); the apiserver audit log records that **every** platform/app
   write was issued by the singleton's in-cluster ServiceAccount and none by the harness principal.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 20.3: Phase gate harness — live deploy + the pre-cluster negative corpus as a live regression guard 📋

**Status**: Planned
**Implementation**: `test/integration/Phase20Gate.hs` (linux-cpu spin-up / reconcile / teardown + the negative
regression assertions); the reused Phase-6 negative corpus under `dhall/examples/illegal_*.dhall` (re-run, not
re-authored) — target paths, not yet built.
**Blocked by**: Sprint 20.1, Sprint 20.2; Phase 6 (the pre-cluster illegal-state negative corpus +
validation-locus ledger, already proven in Registers 1–2); Phase 21 gate (the Keycloak-owned edge the deployed
app must route through).
**Independent Validation**: the harness deploys the platform + trivial app from one `.dhall` on linux-cpu
(under the perturbation + attribution regime of the Gate-integrity clauses and Sprint 20.2) and tears down
leak-free, then re-runs each Phase-6 negative fixture against the live deploy path and asserts each still
**fails at Gate 1 or Gate 2**, and each positive fixture still decodes; the run emits a **Register-3**
proven/tested/assumed ledger naming the live substrate. **"The live deploy path" is pinned to the identical
entry point the positive fixture used (§M.3, forecloses the host-side re-run cheat):** each negative `.dhall`
is submitted through the exact same singleton spec-ingestion/`Deploy.hs` entry the positive gate fixture flowed
through (not a separate host-side CorpusSpec decoder), and each yields a **structured Gate-1 (`dhall type`
error) or Gate-2 (`DecodeError` tag) rejection whose emitted tag equals the Phase-0-committed expected tag for
that fixture in `test/fixtures/phase20/negative-expected-tags.tsv` (§M.8)** — a bare "it failed" does not
satisfy this. **"No fixture reaches the apiserver" is proven, not assumed (§M.5):** across the entire negative
corpus run the apiserver audit log shows **zero** platform/app-object writes, and a full-cluster
`resourceVersion` snapshot taken before and after the corpus run is equal — cluster state is byte-for-byte
unchanged.
**Docs to update**: `DEVELOPMENT_PLAN/substrates.md`, `documents/engineering/testing_doctrine.md`,
`DEVELOPMENT_PLAN/README.md` (flip the Phase-20 status when the gate passes).

### Objective
Adopt [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
assemble the phase's single live acceptance gate — one `.dhall` deploys the platform + a trivial app on
linux-cpu and the live apiserver admits the rendered manifests — and, as a regression guard, re-run the
pre-cluster (Phase-6) negative corpus so each deliberately-illegal `.dhall` still fails to type-check or decode
against the live path, and the positive fixtures still decode. That type/decode result was proven in-process in
the pre-cluster band; here the guard confirms the live deploy path never admits an illegal spec.

### Deliverables
- The positive gate: the Sprint-20.2 platform + trivial-app deploy driven to ready by the singleton and torn
  down leak-free, expressed as a test-topology `.dhall` with a teardown obligation.
- The negative regression guard: the Phase-6 corpus (a bad PVC↔PV pairing, a Keycloak-bypassing open ingress, a
  product named in application logic, and the capacity/topology/bounded-storage set) **re-run** against the
  live deploy path (the same singleton `Deploy.hs` entry the positive fixture used), each asserted to fail at
  Gate 1 or Gate 2 **with its specific foreclosure tag matching the Phase-0-committed hand-authored oracle
  `test/fixtures/phase20/negative-expected-tags.tsv`** (each row: fixture → expected `dhall type` error or
  `DecodeError` tag, authored independently of the singleton's decoder — §M.3/§M.8), and each paired with a
  positive that differs only in the foreclosed dimension — **never re-establishing** the type discipline, only
  guarding that the deploy path inherits it.
- **Committed seeded mutants (§M.2):** at least `test/fixtures/phase20/mutants/enact-noop.patch` (the
  dropped-effect `Reconcile.hs::enact`, red because the perturbed component is never restored) and an
  attribution mutant (harness principal issues the writes, red because the audit clause detects a non-singleton
  writer) — both committed and re-run each gate, each asserted to turn the gate red.
- The **Phase-0-pinned oracle bundle** committed before any implementation exists:
  `dhall/examples/platform_plus_trivial_app.dhall`, `expected-enact-pass1.json`, `expected-enact-pass2.json`,
  `perturb-targets.txt`, `negative-expected-tags.tsv`, and `harness-rbac.yaml` (under `test/fixtures/phase20/`).
- A **Register-3** proven/tested/assumed ledger recording the live-enforcement result (the apiserver admitted
  the rendered manifests) and marking the deferred surfaces — full app tenancy (Phase 23), and the
  cross-cluster gateway-migration correspondence (the multi-cluster phase) — as UNVERIFIED, never green.

### Validation
1. After perturbation, the positive `.dhall` restores and brings the platform + trivial app up (first-pass
   audit-log enact set matches `expected-enact-pass1.json`, all writes attributed to the singleton SA), the app
   is reachable through the Keycloak edge, and teardown leaves no leaked resources over the run-unique label
   set; the committed `enact-noop` mutant turns this red.
2. Every Phase-6 negative fixture, submitted through the same singleton `Deploy.hs` entry the positive used, is
   rejected at Gate 1/Gate 2 with its emitted tag equal to the committed `negative-expected-tags.tsv` oracle;
   the apiserver audit log shows zero writes and the pre/post full-cluster `resourceVersion` snapshot is equal
   across the corpus run; the positive fixtures decode; and the ledger honestly classifies each foreclosure (no
   runtime-checked or deferred claim — tenancy, gateway-migration — is reported as proven).

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/daemon_topology_doctrine.md` — the §3 / §3.1 control-plane-singleton and the §5
  delegated-single-instance honesty notes flip from "design intent for the live-DSL-deploy phase" to a
  delivered Deployment-`replicas=1` singleton with its Register-3 ledger attached; record that single-instance
  landed as a k8s/etcd property with no amoebius election built.
- `documents/engineering/dsl_doctrine.md` — the §5 contract's runtime-enforcement note flips from "design
  intent" to live-enforced only once the gate runs — the two gates now guard the live deploy path.
- `documents/engineering/manifest_generation_doctrine.md` — record that the control-plane singleton is the role
  that runs the typed reconciler's loop, and that its own manifest is a generated `Deployment replicas=1`.
- `documents/engineering/testing_doctrine.md` — record the Register-3 ledger variant this gate emits (tenancy
  and gateway-migration correspondence UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-20 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — confirm the Phase-20 linux-cpu gate row (the replicas=1 singleton, no
  election).
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/ControlPlane/{Singleton,Reconcile,Deploy}.hs`
  as Phase-20 design-first rows, and re-anchor the in-cluster-singleton row to the current
  `#3-the-control-plane-singleton` (no election).

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (the replicas=1 singleton)
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map (the linux-cpu gate row)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — the control-plane singleton
  as a Deployment `replicas=1`, single-instance delegated to k8s/etcd, and the shared daemon spine
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — the two typed gates and the illegal-state contract
  guarding the live deploy path
- [phase_16](phase_16_renderer_reconciler.md) — the typed renderer + SSA reconciler that renders and applies
  the singleton and its manifests
- [phase_19](phase_19_platform_backbone.md) — the standard platform-service stack the live `.dhall` deploys
- [phase_21](phase_21_keycloak_ingress.md) — the Keycloak-owned edge the trivial app routes through
- [phase_23](phase_23_app_tenancy.md) — the app-tenancy projection (namespace + ObjectStore + Sql) deferred
  from this phase
