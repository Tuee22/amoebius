# Phase 27: jitML lift + checkpoints + coordinator + CUDA

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_25_jitbuild_engine_cache.md, DEVELOPMENT_PLAN/phase_26_infernix_lift.md, DEVELOPMENT_PLAN/phase_28_apple_metal_host_daemon.md
**Generated sections**: none

> **Purpose**: Lift the sibling `jitML` training/JIT library onto the amoebius seams — checkpoints on the
> Phase-23 content store, a `linux-cuda`-bound determinism contract, a Feed-sourced single-writer trainer whose
> failover is **delegated** to a Pulsar Failover subscription plus the content-store CAS (never an
> amoebius election), and a jit-resolved CUDA engine — gated live on `linux-cuda` by a bit-deterministic run, a
> delegated trainer failover, and a demo web app that deploys as application-logic-only.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. The phase runs on the **linux-cuda** substrate —
the first GPU substrate in the plan, tracked in [substrates.md](substrates.md) — in **Register 3** (live
infrastructure), on a single-node cluster whose linux-cuda node carries NVIDIA GPUs, and it opens only after
the Phase 26 gate (the infernix CPU-inference lift and its application-logic-only demo web app). It consumes
earlier phases rather than re-implementing them: Phase 23's three-tier content-addressed store and the
Pulsar-Failover single-writer workflow runtime, Phase 24's determinism kernel (`deriveExperimentHash` +
SplitMix seed derivation), Phase 25's jit-build engine resolver and `CacheBudget`-bounded content-addressed
cache, and Phase 22's native Pulsar CBOR client. The mechanisms it lifts exist only as **sibling evidence, not
amoebius results**: the checkpoint blob/manifest/pointer format in `jitML/src/JitML/Checkpoint/Format.hs`, the
SplitMix RNG in `jitML/src/JitML/Engines/Rng.hs`, the determinism contract in
`jitML/documents/engineering/determinism_contract.md`, and the Failover-subscription trainer path proven over
WebSockets in the sibling infernix runtime. None has been built or run as amoebius. Per
[development_plan_standards.md](development_plan_standards.md), no sprint is Done — or 🧪 Live-proof-pending —
until its proof actually runs on `linux-cuda`. Status transitions are recorded reverse-chronologically here
once work begins.

## Phase Summary

This phase makes `jitML` — the sibling training + JIT-codegen ML library — an amoebius extension *library*
rather than a standalone product, and stands its training loop up on a GPU substrate for the first time. It
lifts the proven numerical/checkpoint core and re-homes it onto amoebius seams
([`lift_and_compose_doctrine.md` §2](../documents/engineering/lift_and_compose_doctrine.md)): the `jitML`
checkpoint blob/manifest/pointer format becomes entries in the Phase-23 three-tier content-addressed store; the
`jitML` `.dhall` **nests inside** the `InForceSpec` as a shared library whose surface carries no replica count,
region, substrate selector, or failover field; and the SplitMix determinism kernel is consumed from Phase 24
rather than rebuilt. Its CUDA compute is **not** welded into the library or baked into the base image: which
substrate the training/JIT compute runs on is a **deployment rule**, so the CUDA engine is substrate-selected
and **jit-resolved** — a named catalog identity the Phase-25 resolver materializes on first miss into the
`CacheBudget`-bounded content-addressed cache, never a baked payload and never a URL fetch — and it runs under
the node's wholesale accelerator-owner worker, which multiplexes training, serving, and Tier-3 JIT on the
linux-cuda node.

The genuinely distributed piece is recast from the legacy design. A **Feed-sourced continuous trainer** needs a
single authoritative writer per feed so the committed model pointer never regresses, and this phase places that
role with **no new machinery and no election**: the trainer is the **existing ML batch coordinator worker**
([`daemon_topology_doctrine.md` §4.3](../documents/engineering/daemon_topology_doctrine.md#43-the-feed-sourced-continuous-trainer-single-writer-delegated))
parameterized with a `Feed` data source — not a new elected worker kind, and not folded into the control-plane
singleton. Single-writer is **delegated, not elected**: liveness (at most one active trainer per feed) is a
Pulsar **Failover** subscription with automatic ranked failover on death and resume-from-`latest`;
safety (a race-free `latest` pointer) is the content store's ETag-CAS single atomic commit point plus the typed
`AdvancePredicate`, a monotone idempotent join that absorbs a bounded two-writer failover overlap. There is no
bespoke ranked-failover election, no signed-commit-log kernel, no "First Axis" election, and no warm-standby
singleton — the durable state remains the Vault-enveloped MinIO bucket of the stateless Deployment-`replicas=1`
control-plane singleton (single-instance delegated to k8s/etcd). Finally, the **jitML demo web app** deploys as
**application-logic-only** — a PureScript SPA that *uses* the jitML extension, its contract types regenerated
from the amoebius-composed Haskell ADTs and never committed — the phase's app-vs-deployment demonstrator.

The honest ceiling is adopted verbatim: same-substrate (`linux-cuda`) bit-equality is the contract;
cross-substrate bit-equality is **not asserted**, and off-policy RL is downgraded to a tested first-N-step
prefix compared between two fresh runs. The asynchronous **cross-cluster** geo-replication / gateway-migration
boundary and its TLA+/io-sim proof are **not** this phase — that is amoebius's one formal obligation, owned by
[Phase 29](phase_29_multicluster_gateway_migration.md); a Continuous run here is single-cluster, and other
clusters serve by replication of the immutable checkpoints, never by training a second authority on the feed.

```mermaid
flowchart LR
  dhall[InForceSpec: jitML nested as a shared library] --> up[Bring up on linux-cuda: content store, Pulsar, MinIO already HA]
  up --> engine[CUDA engine jit-resolved into the Phase-25 CacheBudget cache: not baked, no URL]
  engine --> owner[Accelerator-owner worker: wholesale per-node GPU, Tier-3 JIT]
  owner --> train[jitML training run: experimentHash bound to the linux-cuda fingerprint]
  train --> ckpt[Checkpoints written to the Phase-23 three-tier content store]
  ckpt --> det[Assert bit-determinism: two fresh runs, equal manifest SHA per contract]
  det --> feed[Feed-sourced single-writer trainer on a Pulsar Failover subscription]
  feed --> kill[Kill the active trainer]
  kill --> failover[Pulsar promotes the name-ordered standby: CAS plus AdvancePredicate keep latest safe, NO election]
  failover --> spa[Demo web app deploys application-logic-only: contracts regenerated from Haskell]
  spa --> teardown[Idempotent leak-free teardown plus per-run ledger]
```

**Substrate:** linux-cuda — the whole gate runs on a linux-cuda host in Register 3 (live infrastructure); no
apple, linux-cpu, or windows substrate is touched by the gate. The structurally identical **windows-CUDA host
worker** (a host subprocess because CUDA does not run performantly under WSL2) is named only as target shape,
not exercised here.

**Register:** 3 — live infrastructure; the gate spins up a linux-cuda cluster, runs a real training workflow,
injects a trainer kill, and tears down, emitting a per-run proven/tested/assumed ledger. It cannot pass on
"it compiles".

**Gate:** a `jitML` run is **bit-deterministic per its determinism contract** (two fresh runs at the same
`experimentHash` produce equal checkpoint manifest SHAs on the same linux-cuda substrate; off-policy RL asserted
only on the first-N-step prefix; no cross-substrate equality claim), the **single-writer Feed trainer fails
over via a Pulsar Failover subscription plus the content-store ETag-CAS + `AdvancePredicate`** — a
name-ordered standby takes over with no torn or regressed `latest` and **no amoebius election of any kind** —
and the **jitML demo web app deploys as application-logic-only**, all on `linux-cuda` with a leak-free
idempotent teardown and an emitted ledger.

## Doctrine adopted

- [`lift_and_compose_doctrine.md` §2 / §3 / §5](../documents/engineering/lift_and_compose_doctrine.md) — *what
  lifts (the reuse map)* / *the friction envelope* / *evidence, not proof*: the jitML numerical core, the
  SplitMix determinism kernel, and the content-addressed CBOR checkpoint store lift largely intact onto amoebius
  seams; the rewritten envelope is the WebSocket/base64-JSON Pulsar bridge → the native CBOR client and the
  Python engine-fork/baked engine → the jit-build bounded cache; that jitML trains reproducibly today is sibling
  evidence, never an amoebius result until this gate runs.
- [`app_vs_deployment_doctrine.md` §7](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule)
  and [`§8`](../documents/engineering/app_vs_deployment_doctrine.md#8-shared-library-use-is-application-logic)
  — *the compute substrate is a deployment rule* / *shared-library use is application logic*: *which* substrate
  the jitML compute runs on (CUDA on the cluster vs linux-cpu) is a placement choice, never library logic —
  which is exactly why the CUDA engine is substrate-selected and jit-resolved rather than welded into the
  library — while *that* an app uses jitML travels with the app; the demo web app that uses the extension is
  application logic, so the closed extension set stays {infernix, jitML}
  ([`§6` — the proof case: a demo web app as application-logic-only](../documents/engineering/app_vs_deployment_doctrine.md#6-the-proof-case-a-demo-web-app-as-application-logic-only)).
- [`content_addressing_doctrine.md` §2](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers),
  [`§3`](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran) /
  [`§3.1`](../documents/engineering/content_addressing_doctrine.md#31-producing-substrate-vs-serving-substrate-a-distinct-serving-run-fingerprint),
  [`§4`](../documents/engineering/content_addressing_doctrine.md#4-determinism-by-construction-pinned-inputs--pure-stages--derived-seed),
  and [`§6`](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic)
  — *the three-tier store* / *`experimentHash`: what was requested ‖ where it ran* / *determinism by
  construction* / *the honest ceiling*: jitML checkpoints become blobs ← manifests ← pointers keyed under an
  `experimentHash` that folds the resolved `.dhall` with the **linux-cuda** substrate fingerprint (so a GPU run
  never collides with a CPU run), each stage input pinned as a content address and each RNG stream derived from
  `(masterSeed, streamIndex)` alone — bounded by same-substrate bit-equality, off-policy RL as a first-N-step
  prefix, no cross-substrate claim.
- [`content_addressing_doctrine.md` §4.5](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)
  and [`§4.6`](../documents/engineering/content_addressing_doctrine.md#46-the-training-run-topology-fine-tune-chains-and-continuous-feeds-without-an-unbounded-arm)
  — *the ML-asset lifecycle: one bounded content-addressed cache, resolved on first miss* / *the training-run
  topology*: the CUDA engine is a named catalog identity the Phase-25 resolver materializes on first miss into
  the `CacheBudget`-bounded cache — never baked, never URL-fetched — and the Feed-sourced continuous trainer is
  the training-run topology's continuous arm without an unbounded arm.
- [`daemon_topology_doctrine.md` §4.2](../documents/engineering/daemon_topology_doctrine.md#42-the-accelerator-owner-worker-wholesale-per-node-ownership-a-typed-per-node-singleton)
  and [`§4.1`](../documents/engineering/daemon_topology_doctrine.md#41-the-engine-offering-vs-the-node-hardware-in-cluster-pod-or-host-subprocess)
  — *the accelerator-owner worker: wholesale per-node ownership, a typed per-node singleton*: the linux-cuda
  node's GPUs are owned wholesale by one typed per-node-singleton accelerator-owner worker (a DaemonSet-like
  node-affinity, at most one per node — a **k8s placement property, not an amoebius election**), which
  multiplexes training, serving, and Tier-3 JIT; a `Cuda` offering on linux-cuda hardware is an in-cluster pod.
- [`daemon_topology_doctrine.md` §4.3](../documents/engineering/daemon_topology_doctrine.md#43-the-feed-sourced-continuous-trainer-single-writer-delegated),
  [`§4`](../documents/engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected),
  [`§5`](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected) /
  [`§5.2`](../documents/engineering/daemon_topology_doctrine.md#52-the-coordination-plane-is-for-worker-events-and-audit-not-leadership),
  and [`§3.1`](../documents/engineering/daemon_topology_doctrine.md#31-exactly-one-pod-is-a-k8setcd-property-not-an-amoebius-election)
  — *the Feed-sourced continuous trainer: single-writer delegated* / *workers, N, unelected* / *single-instance
  and coordination — delegated, not elected*: the trainer is the existing ML batch coordinator worker plus a
  `Feed` source; liveness is a Pulsar Failover subscription and safety is the store's ETag-CAS +
  `AdvancePredicate`; single-instance of the control-plane singleton that schedules it is a k8s/etcd property,
  so nothing in this phase runs an election.
- [`chaos_failover_doctrine.md` §12](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
  (cross-reference) — *proven, tested, assumed*: each gate run emits a proven/tested/assumed ledger; skipping an
  applicable trainer-kill injection marks that layer UNVERIFIED, never green. The asynchronous **cross-cluster**
  failover boundary and its formal gateway-migration model are owned by
  [`§16`](../documents/engineering/chaos_failover_doctrine.md#16-the-second-axis--when-one-cluster-becomes-a-forest)
  and scheduled for Phase 29, not here.
- [`testing_doctrine.md` §2](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing),
  [`§3`](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down),
  [`§4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
  — Register 3 (live), the spin-up → run → always-tear-down contract, and the per-run ledger this gate emits.

## Sprints

## Sprint 27.1: jitML lifted as a shared library — checkpoints on the Phase-23 content store 📋

**Status**: Planned
**Implementation**: `src/Amoebius/JitML/Library.hs`, `dhall/jitml/package.dhall`,
`src/Amoebius/JitML/Checkpoint/Store.hs`, `src/Amoebius/JitML/Checkpoint/Manifest.hs` (target paths; not yet
built) — the jitML library surface, its nested `.dhall` package, and the checkpoint key renderers + canonical
manifest encoder mapped onto the Phase-23 store.
**Blocked by**: Phase 23 gate (external prereq — the three-tier content-addressed MinIO store and its
blob/manifest/pointer write protocols); Phase 22 gate (external prereq — the native Pulsar CBOR client the
checkpoint adopt/resume events ride).
**Independent Validation**: a fixture amoebius app `.dhall` type-checks with the jitML `.dhall` nested inside
it, and the jitML surface carries no replica count, region, substrate selector, or failover field (those fields
do not exist on it); two writers with equal logical checkpoint content emit identical blob and manifest SHAs
(canonical CBOR), and the pure CAS decision returns `PointerWritten`/`PointerConflict` correctly — no live
MinIO required for the pure layer.
**Docs to update**: `documents/engineering/lift_and_compose_doctrine.md`,
`documents/engineering/app_vs_deployment_doctrine.md`, `documents/engineering/content_addressing_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`, this document.

### Objective
Adopt [`lift_and_compose_doctrine.md` §2](../documents/engineering/lift_and_compose_doctrine.md) and
[`app_vs_deployment_doctrine.md` §8](../documents/engineering/app_vs_deployment_doctrine.md#8-shared-library-use-is-application-logic):
re-home the sibling jitML checkpoint format onto the Phase-23 store and expose the training/JIT call graph as a
shared library whose `.dhall` nests inside the `InForceSpec`, so *that* an app uses jitML is application logic
while the workload's placement stays a separate deployment-rules dial.

### Deliverables
- A jitML library surface exposing the training/JIT call graph an app composes, with **no** field for replicas,
  region, failover, chaos, or substrate; and a nested `jitml/package.dhall` composed into a parent amoebius app
  `.dhall`, the substrate/replica dials living only in the deployment-rules layer that joins with the app.
- `blobKey`/`manifestKey`/`latestPointerKey`/`bestPointerKey`/`trialPointerKey` renderers producing the fixed
  prefix schema under the app's Phase-21 ObjectStore bucket (`jitml-checkpoints/<experiment-hash>/…`), and a
  **canonical** `encodeManifestCbor` (tensors sorted by name, optimizer blobs by kind, RNG blobs by stream id,
  metrics by name) so equal logical content ⇒ byte-identical CBOR ⇒ the same manifest SHA, written through the
  Phase-23 blob/manifest PUT + pointer CAS protocols.
- The mandatory `TensorBoard` monitoring surface on the jitML `ExtensionSpec` (per
  [`monitoring_doctrine.md` §5](../documents/engineering/monitoring_doctrine.md#5-extensible-surfaces-tensorboard)),
  so an unmonitored jitML run is unrepresentable; `tfevents` land in the per-experiment `tb/` prefix on MinIO.

### Validation
1. The fixture app `.dhall` type-checks with the jitML `.dhall` nested inside it; a negative test attempting to
   write a replica count or substrate selector on the jitML surface fails to type-check (the field is
   unrepresentable).
2. Two encoders given equal logical checkpoints emit identical blob and manifest SHAs; reordering
   tensors/optimizer/RNG inputs does not change the SHA; the pure `applyPointerWrite` decision resolves the CAS
   winner/loser correctly.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 27.2: CUDA engine — substrate-selected, jit-resolved, run under the accelerator-owner worker 📋

**Status**: Planned
**Implementation**: `src/Amoebius/JitML/Engine/Cuda.hs`, `src/Amoebius/JitML/Engine/Select.hs`,
`src/Amoebius/Accelerator/Owner.hs` (target paths; not yet built) — the CUDA engine binding behind the shared
engine interface, the substrate-driven engine selector, and the typed per-node accelerator-owner worker.
**Blocked by**: Phase 25 gate (external prereq — the jit-build engine resolver + `CacheBudget`-bounded
content-addressed cache the CUDA engine identity resolves into); Phase 24 gate (external prereq — the
determinism kernel the engine dispatch respects); Sprint 27.1 (the jitML library the engine backs).
**Independent Validation**: on a linux-cuda node the named CUDA engine identity resolves on **first miss** into
the `CacheBudget`-bounded cache and a second pod reuses it; the engine is **never** baked into the base image
and **never** fetched by URL; engine selection is a pure function of the resolved substrate (no env var, no
`PATH`); the node's GPUs are reached only through the single per-node accelerator-owner worker, and a second
owner on the same node has no constructor.
**Docs to update**: `documents/engineering/app_vs_deployment_doctrine.md`,
`documents/engineering/content_addressing_doctrine.md`, `documents/engineering/daemon_topology_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`app_vs_deployment_doctrine.md` §7](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule),
[`content_addressing_doctrine.md` §4.5](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss),
and [`daemon_topology_doctrine.md` §4.2](../documents/engineering/daemon_topology_doctrine.md#42-the-accelerator-owner-worker-wholesale-per-node-ownership-a-typed-per-node-singleton):
make the CUDA backend a substrate-selected deployment concern that is jit-resolved into the bounded cache and
run under the node's wholesale accelerator owner, so no CUDA payload is welded into the library or baked into
the image.

### Deliverables
- A CUDA engine implementing the shared jitML `Engine` interface, selected by the **resolved substrate** (a
  `Cuda` offering projected from linux-cuda hardware, [`§4.1`](../documents/engineering/daemon_topology_doctrine.md#41-the-engine-offering-vs-the-node-hardware-in-cluster-pod-or-host-subprocess)),
  with a fail-fast diagnostic when CUDA is selected on a node whose substrate does not project it — never a
  silent CPU fallback that would change `experimentHash`.
- The CUDA engine payload delivered as a **named catalog identity** the Phase-25 resolver materializes on first
  miss into the `CacheBudget`-bounded content-addressed cache; no arbitrary `Url` arm and no baked per-engine
  image layer, so a second pod on the node reuses the cached artifact and "more cached than fits" stays
  decode-rejected.
- The typed **per-node-singleton accelerator-owner worker** that owns the linux-cuda node's GPUs wholesale and
  multiplexes training, serving, and Tier-3 JIT compilation of the CUDA kernel; the "one owner per node"
  invariant is a k8s node-affinity property, and "two owners contending for one node" is type-foreclosed.

### Validation
1. `cabal build` on a host with no CUDA toolchain compiles and links the CPU path; on the linux-cuda host the
   CUDA engine resolves its named identity into the Phase-25 cache on first miss and a second pod reuses it —
   verifying nothing was baked or URL-fetched.
2. Selecting CUDA where the substrate does not project it fails fast with an actionable diagnostic, touching no
   store; engine selection reads only the resolved substrate, never an env var or `PATH`.
3. A `.dhall` placing two accelerator-owner workers on one node, or a fractional/straddled GPU claim, fails to
   type-check.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 27.3: jitML training bit-determinism on linux-cuda 📋

**Status**: Planned
**Implementation**: `src/Amoebius/JitML/Determinism.hs` (target path; not yet built) — the jitML binding of the
Phase-24 `deriveExperimentHash` and SplitMix seed streams to the linux-cuda substrate fingerprint and the
training stream set.
**Blocked by**: Sprint 27.1 (checkpoints on the store), Sprint 27.2 (the CUDA engine the run dispatches on);
Phase 24 gate (external prereq — the determinism kernel: `experimentHash` + SplitMix seed derivation).
**Independent Validation**: pure tests that `experimentHash` changes when the substrate fingerprint changes
(linux-cpu vs linux-cuda) and when any identity-bearing `.dhall` field changes (e.g. a metric `direction`
flip), and that a stream's seed is a pure function of `(masterSeed, streamIndex)` independent of worker count,
scheduling, and assignment.
**Docs to update**: `documents/engineering/content_addressing_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`content_addressing_doctrine.md` §3](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran),
[`§4`](../documents/engineering/content_addressing_doctrine.md#4-determinism-by-construction-pinned-inputs--pure-stages--derived-seed),
and the honest ceiling of [`§6`](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic):
make a jitML training run deterministic-by-construction on linux-cuda by folding the resolved `.dhall` with the
linux-cuda substrate fingerprint into `experimentHash`, pinning every stage input as a content address, and
deriving every RNG stream from `(masterSeed, streamIndex)` alone.

### Deliverables
- A jitML `experimentHash` binding over `(resolved-dhall, linux-cuda substrate fingerprint)` so a linux-cuda run
  occupies a distinct namespace from any CPU run and a metric `direction` flip defines a different experiment.
- Per-stream SplitMix seeds for the full jitML training stream set (per-experiment, per-game RL self-play,
  per-HPO-trial, MCTS root noise) via the Phase-24 `deriveSplitMixSeed`, with the in-types property that a
  stream's seed is independent of worker count, scheduling, and assignment.
- The honest ceiling encoded as the determinism *contract* this run is checked against: same-substrate
  bit-equality for SL / on-policy RL / per-game AlphaZero; a first-N-step prefix (default `rl_steps / 10`) for
  off-policy RL asserted by comparing **two fresh runs against each other**, never a stored fixture; no
  cross-substrate equality claim.

### Validation
1. Pure tests: `experimentHash` differs across linux-cpu vs linux-cuda fingerprints and across a
   `direction`-flipped `.dhall`; identical inputs reproduce the same hash; `deriveSplitMixSeed (masterSeed, k)`
   yields identical seeds at 1 worker and at N workers in any dispatch order.
2. On linux-cuda, run an SL / on-policy training to a checkpoint twice at the same `experimentHash` and assert
   identical manifest SHAs; for an off-policy algorithm, run twice and assert first-N-step prefix equality of
   two fresh runs (sibling-evidence contract, reported as tested, not proven).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 27.4: Feed-sourced single-writer trainer — delegated failover, never elected 📋

**Status**: Planned
**Implementation**: `src/Amoebius/JitML/FeedTrainer.hs` (target path; not yet built) — the existing ML batch
coordinator worker parameterized with a `Feed` source, riding a Pulsar Failover subscription and the
content-store CAS commit point.
**Blocked by**: Sprint 27.1 (the checkpoint store and its `latest` pointer CAS); Phase 23 gate (external prereq
— the orchestrator/worker workflow runtime and the Failover standby-takeover path); Phase 22 gate
(external prereq — the subscription surface and at-least-once + dedup).
**Independent Validation**: a pure model of the single-writer decision (capture inputs → decide → fence → act)
shows at most one active trainer per feed and that a lost CAS never produces a torn or double-adopted `latest`;
an injected trainer-kill on linux-cuda shows a name-ordered standby adopting the role and resuming from the last
adopted `latest` with no torn checkpoint; **no code path performs a leadership election or holds cluster-wide
authority**.
**Docs to update**: `documents/engineering/daemon_topology_doctrine.md`,
`documents/engineering/content_addressing_doctrine.md`, `documents/engineering/chaos_failover_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`daemon_topology_doctrine.md` §4.3](../documents/engineering/daemon_topology_doctrine.md#43-the-feed-sourced-continuous-trainer-single-writer-delegated),
[`§5`](../documents/engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected),
and [`content_addressing_doctrine.md` §5](../documents/engineering/content_addressing_doctrine.md#5-confluence-content-addressed-data-crosses-cluster-boundaries-safely):
place the single authoritative writer per feed with no new machinery — the existing coordinator worker plus a
`Feed` source — and delegate liveness to a Pulsar Failover subscription and safety to the store's
ETag-CAS + `AdvancePredicate`, so single-writer is a **delegation, never an election**.

### Deliverables
- The Feed trainer as the existing ML batch coordinator worker parameterized with a `Feed` data source — **not**
  a new elected worker kind and **not** folded into the control-plane singleton; its checkpoint-advance branch
  is an extracted pure decision over captured typed inputs, never computed mid-race.
- Liveness — at most one active trainer per feed — from a **Pulsar Failover subscription** on the feed
  topic (automatic name-ordered ranked failover on death, resume-from-`latest`); safety — a race-free `latest` —
  from the content store's ETag-CAS single atomic commit point plus the typed `AdvancePredicate`, a monotone
  idempotent join so a bounded two-writer failover overlap cannot corrupt or regress HEAD.
- An explicit non-goal note in the module and docs: this is single-cluster and **not** an election, **not** the
  legacy "First Axis" elected coordinator, and **not** the cross-cluster gateway-migration boundary (owned by
  Phase 29); candidates share no in-memory state and coordinate only through Pulsar + the content store.

### Validation
1. Model/property test: across interleavings of capture/decide/fence/act, at most one trainer holds the write
   role and a lost CAS never yields a torn or double-adopted `latest`; a static/audit check confirms no code
   path runs a leadership election.
2. On linux-cuda, start a Feed run, kill the active trainer mid-run, and assert a name-ordered standby takes
   over the subscription and resumes from the last adopted `latest` with no duplicated or lost step and no torn
   checkpoint.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 27.5: Demo web app application-logic-only + the linux-cuda gate 📋

**Status**: Planned
**Implementation**: `web/jitml/` (the lifted PureScript SPA shell), `src/Amoebius/JitML/Contracts.hs` (the
purescript-bridge contract source), `test/dhall/phase_27_jitml_cuda.dhall`, `test/live/JitMLCudaGate.hs`
(target paths; not yet built) — the demo app deployment and the end-to-end gate topology.
**Blocked by**: Sprint 27.3 (bit-determinism), Sprint 27.4 (the delegated Feed trainer failover); Phase 26 gate
(external prereq — the infernix demo web app pattern this reuses); Phase 12 (the representational SPA-composition
fixtures).
**Independent Validation**: the jitML PureScript demo SPA deploys as an app-spec that *uses* the jitML extension
(no extension logic in the app), its contract types regenerated from the amoebius-composed Haskell ADTs and
present only as a build artifact (never committed); the gate `.dhall` runs the full bit-deterministic + delegated
failover + demo-deploy workflow end-to-end on linux-cuda and tears down leak-free, emitting a
proven/tested/assumed ledger.
**Docs to update**: `documents/engineering/lift_and_compose_doctrine.md`,
`documents/engineering/app_vs_deployment_doctrine.md`, `documents/engineering/chaos_failover_doctrine.md`,
`DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`.

### Objective
Adopt [`app_vs_deployment_doctrine.md` §6](../documents/engineering/app_vs_deployment_doctrine.md#6-the-proof-case-a-demo-web-app-as-application-logic-only)
/ [`§8`](../documents/engineering/app_vs_deployment_doctrine.md#8-shared-library-use-is-application-logic),
[`lift_and_compose_doctrine.md` §4](../documents/engineering/lift_and_compose_doctrine.md), and
[`testing_doctrine.md` §3](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down):
deploy the jitML demo web app as application-logic-only and compose the three gate claims — bit-determinism,
delegated trainer failover, and the application-logic-only demo — into the single linux-cuda acceptance gate.

### Deliverables
- The lifted jitML PureScript SPA deployed as an amoebius app-spec that *uses* the jitML extension, its frontend
  contract types **regenerated** from the amoebius-composed Haskell ADTs via purescript-bridge as a build
  artifact that is never committed ([`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md)),
  with its HA replica count and substrate binding in the orthogonal deployment-rules layer.
- The gate `.dhall` (`test/dhall/phase_27_jitml_cuda.dhall`, emitted from Haskell, never committed): bring up
  the linux-cuda cluster, jit-resolve the CUDA engine, run a jitML training to a checkpoint at a fixed
  `experimentHash`, assert bit-determinism (two fresh runs; first-N-step prefix for off-policy RL), inject a
  Feed-trainer kill, assert Pulsar Failover standby takeover with the CAS + `AdvancePredicate` keeping
  `latest` intact, deploy the demo app, and tear everything down.
- A proven/tested/assumed ledger artifact per [`chaos_failover_doctrine.md` §12](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed):
  same-substrate bit-equality *tested*; delegated (no-election) failover *tested*; cross-substrate equality and
  the cross-cluster boundary *not asserted* (deferred to Phase 29); GPU-float physics *assumed* (sibling
  evidence, not an amoebius measurement).

### Validation
1. **Gate (determinism).** Two fresh linux-cuda runs at the same `experimentHash` produce equal manifest SHAs
   (or equal first-N-step prefix for off-policy), with the ceiling's not-asserted rows recorded.
2. **Gate (delegated failover).** Killing the active Feed trainer triggers Pulsar Failover standby
   takeover — no amoebius election — and the run resumes from the last adopted `latest` with no torn or
   duplicated state.
3. **Gate (app-logic-only).** The demo web app deploys as an app that uses the extension, its contracts a
   regenerated uncommitted build artifact; the topology tears down leak-free, re-runs idempotently, and the
   ledger is emitted and green for every applicable move (skips mark UNVERIFIED, never green).

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/lift_and_compose_doctrine.md` — record that the jitML numerical/checkpoint core and the
  SplitMix kernel are lifted onto the amoebius seams (Phase-23 store, Phase-24 kernel, native CBOR client), the
  substance intact and only the envelope re-homed; keep the sibling-evidence framing.
- `documents/engineering/app_vs_deployment_doctrine.md` — record that the §7 substrate-as-deployment-rule, §8
  shared-library-is-app-logic, and §6 application-logic-only demo classifications are demonstrated for jitML
  (the jitML `.dhall` nests under the `InForceSpec`; CUDA is substrate-selected and jit-resolved, not welded in).
- `documents/engineering/content_addressing_doctrine.md` — confirm §2/§3/§4 and the §6 ceiling are exercised on
  a GPU substrate, and that the §4.5 CUDA engine stayed jit-resolved into the Phase-25 cache (never baked, never
  URL-fetched) and §4.6's continuous-feed arm was realized.
- `documents/engineering/daemon_topology_doctrine.md` — confirm the §4.3 Feed-sourced trainer is single-writer
  **delegated** (Pulsar Failover + CAS/`AdvancePredicate`), that the §4.2 accelerator-owner worker
  owns the linux-cuda node's GPUs wholesale, and that **no** election was introduced anywhere.
- `documents/engineering/chaos_failover_doctrine.md` — record the §12 per-run ledger for the intra-cluster
  trainer-kill injection, and that the §16 cross-cluster boundary stays deferred to Phase 29.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-27 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 27's gate substrate (linux-cuda, the first GPU substrate) in
  the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register the `Amoebius.JitML.*`, `Amoebius.Accelerator.Owner`, and
  the CUDA engine + Feed-trainer + gate modules as Phase-27 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker; the Phase 27 row is the authoritative one-line gate and status
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  Register-3 honesty token: a passed gate is a live-substrate result, never a compile claim)
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (jit-resolved engine
  payloads; single-writer delegated, never elected; the stateless `replicas=1` singleton)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md) — jitML is lifted and
  re-homed onto amoebius seams, not reimplemented; the demo web app is application logic, not an extension
- [App vs Deployment Doctrine](../documents/engineering/app_vs_deployment_doctrine.md) — jitML as a shared
  library; the CUDA compute substrate as a deployment rule; the application-logic-only demo proof case
- [Content Addressing & Determinism Doctrine](../documents/engineering/content_addressing_doctrine.md) — the
  three-tier checkpoint store, the linux-cuda-bound `experimentHash`, the jit-resolved engine, and the honest
  ceiling
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — §4.3 the Feed-sourced
  single-writer trainer delegated to Pulsar + CAS (never elected), §4.2 the wholesale per-node accelerator owner
- [Chaos / Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the proven/tested/assumed
  ledger and the deferred cross-cluster (Second Axis) boundary
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — Register 3 (live), the spin-up → run →
  always-tear-down contract, and the per-run ledger
- [phase_23](phase_23_content_store_workflow.md) — the content store + Pulsar-Failover workflow runtime this
  phase's checkpoints and Feed trainer build on
- [phase_24](phase_24_determinism_kernel.md) — the `experimentHash` + SplitMix determinism kernel this phase
  binds to the linux-cuda fingerprint
- [phase_25](phase_25_jitbuild_engine_cache.md) — the jit-build engine resolver + `CacheBudget` cache the CUDA
  engine is materialized into
- [phase_26](phase_26_infernix_lift.md) — the adjacent infernix CPU-inference lift and its application-logic-only
  demo web app
- [phase_28](phase_28_apple_metal_host_daemon.md) — the Apple-Metal host worker; the windows-CUDA host worker
  named here is its structurally identical case on a different substrate
- [phase_29](phase_29_multicluster_gateway_migration.md) — the cross-cluster gateway-migration boundary and its
  formal proof, deferred out of this phase
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
