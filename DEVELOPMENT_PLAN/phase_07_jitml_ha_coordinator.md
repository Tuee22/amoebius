# Phase 7: jitML migration + HA coordinator

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, legacy_tracking_for_deletion.md, overview.md
**Generated sections**: none

> **Purpose**: Specify the phase that migrates the `jitML` training/JIT library onto the amoebius runtime —
> content-addressed checkpoints, determinism-by-construction on a GPU host, an elected HA training coordinator,
> and CUDA confined behind a default-off cabal flag — gated by a bit-deterministic training run plus a
> coordinator failover on `linux-cuda`.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is design intent, and every
`Implementation` field names a **target** module path in the intended layout, not an existing one. The gate
has not run on any substrate. The mechanisms this phase reuses come from two working sibling libraries
(`jitML/src/JitML/Checkpoint/Format.hs`, `jitML/src/JitML/Engines/Rng.hs`, and the sibling
`jitML/documents/engineering/determinism_contract.md`) — that is **evidence the design is realizable, not an
amoebius proof**. Per [development_plan_standards.md §K](development_plan_standards.md), no sprint is marked
Done — or 🧪 Live-proof-pending — until its proof actually runs on `linux-cuda`.

## Phase Summary

This phase takes `jitML` — the sibling training + JIT-codegen ML library — and makes it an amoebius extension
*library* rather than a standalone product: its checkpoints land in the Phase-5 content-addressed MinIO store,
its training runs are made deterministic-by-construction using the Phase-6 determinism kernel (`experimentHash`
+ SplitMix seed derivation), its CUDA backend is confined behind a cabal flag that is **off by default** (so
the ordinary build stays CPU-only and portable), it composes as a shared library whose own `.dhall` nests
inside the `InForceSpec`, and — the genuinely new distributed piece — a `jitML` **training coordinator**
gains HA failover from the kernel election. The coordinator's HA is the *First Axis* (one cluster's
single-writer election); the heavy synchronous consensus underneath it (object-store CAS, single-consumer
subscriptions, relational replication) is **delegated** to the standard services and never re-proved here.

This phase is the first to require a GPU host, which is exactly why it is sequenced after the `linux-cpu`
determinism kernel (Phase 6) rather than alongside it: the determinism *contract* is built and proven on CPU,
then **applied and re-validated on `linux-cuda`** here, where the substrate fingerprint changes and float
reduction order differs.

The **jitML demo web app** — the result-rendering single-page app shipped with `~/jitML` that illustrates its
training/JIT workflow and renders its output — deploys in this phase as **application-logic-only**: it is authored
once as application logic that *uses* the jitML extension, while its HA replica count, substrate, and compute
binding are an orthogonal deployment-rules surface. It is this phase's app-vs-deployment demonstrator — the proof
case that an app is written once as logic while its deployment shape is a separate dial — and per
[`app_vs_deployment_doctrine.md` §8 — shared-library use is application logic](../documents/engineering/app_vs_deployment_doctrine.md#8-shared-library-use-is-application-logic)
a demo web app that *uses* an extension is application logic, not itself an extension, so the closed extension set
stays {infernix, jitML}.

Scope **in**: mapping the `jitML` blob/manifest/pointer checkpoint format onto the amoebius three-tier
content-addressed store (Phase 5); binding `experimentHash` to the `linux-cuda` substrate fingerprint and
deriving per-stream SplitMix seeds for `jitML` training; the default-off `cuda` cabal flag and the
CPU/CUDA engine split; `jitML` as a shared library whose `.dhall` nests under the `InForceSpec`; the
elected, single-writer HA training coordinator and its ranked failover; the bit-determinism + failover gate.
Scope **out**: building the `ContentAddress` typeclass / `experimentHash` / SplitMix primitives themselves
(Phase 6, `linux-cpu`); the content-addressed store + native Pulsar client themselves (Phase 5); Apple Metal /
Windows host compute daemons (Phase 8); the demo-web-app application-logic-only demonstrations (Phases 6–7); and the
**Second Axis** async cross-cluster geo-replication / gateway failover and its TLA+/io-sim proof (Phase 9).
The honest ceiling is adopted verbatim: same-substrate (`linux-cuda`) bit-equality is the contract;
cross-substrate bit-equality is **not asserted**, and off-policy RL is downgraded to a tested first-N-step
prefix.

**Substrate:** linux-cuda (the single gate substrate; the first GPU substrate in the plan, tracked in
[substrates.md](substrates.md), per [development_plan_standards.md §L](development_plan_standards.md)). The
Apple Metal and Windows CUDA host substrates named in the substrate doctrine are explicitly **not** exercised
by this gate; they land in Phase 8.

**Gate:** on a `linux-cuda` host, a `jitML` training run is **bit-deterministic per its determinism contract**
(the same `experimentHash` ⇒ the same checkpoint manifest SHA on the same `linux-cuda` substrate; off-policy RL
asserted only on the first-N-step prefix, two fresh runs compared against each other), **and** the elected
training **coordinator fails over** when the lead is killed — a ranked candidate takes the single-writer role
and the run continues from the last adopted `latest` pointer with no torn checkpoint.

## Doctrine adopted

- **Content addressing & determinism — content-addressed `jitML` checkpoints made reproducible by
  construction.** This phase implements
  [`content_addressing_doctrine.md` §2 — the three-tier store: blobs ← manifests ← pointers](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers)
  (the `jitML` checkpoint blob/manifest/pointer keys become entries in the amoebius store, with write-once
  content-addressed blobs/manifests and a single CAS `latest` commit point),
  [`content_addressing_doctrine.md` §3 — `experimentHash`: identity is what was requested ‖ where it ran](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran)
  (a training run's identity folds the resolved `.dhall` with the **`linux-cuda`** substrate fingerprint, so a
  GPU run never collides with a CPU run) and
  [`content_addressing_doctrine.md` §4 — determinism by construction: pinned inputs + pure stages + derived seed](../documents/engineering/content_addressing_doctrine.md#4-determinism-by-construction-pinned-inputs--pure-stages--derived-seed)
  (pinned content-addressed inputs + pure training stages + per-stream SplitMix seeds), bounded honestly by
  [`content_addressing_doctrine.md` §6 — the honest ceiling: types make the bookkeeping total, not the physics deterministic](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic)
  (same-substrate bit-equality is the contract; off-policy RL is a tested first-N-step prefix; cross-substrate
  equality is not asserted).
- **Application logic vs deployment rules — `jitML` as a shared library, the substrate as a deployment dial.**
  This phase implements
  [`app_vs_deployment_doctrine.md` §8 — shared-library use is application logic](../documents/engineering/app_vs_deployment_doctrine.md#8-shared-library-use-is-application-logic)
  (that an app builds on `jitML` is part of what the app *is*; the `jitML` `.dhall` nests inside the amoebius
  `.dhall` rather than living as a parallel system) and
  [`app_vs_deployment_doctrine.md` §7 — infernix is a shared library; the inference substrate is a deployment rule](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule)
  (the same classification applied to `jitML`: *which* substrate the compute runs on — CUDA on the cluster vs
  `linux-cpu` — is a placement choice, which is exactly why CUDA is confined behind a default-off cabal flag
  and not welded into the library).
- **Chaos hardening & cross-cluster failover — the coordinator is a First-Axis intra-cluster election, NOT the
  Second Axis.** This phase implements the failover side of
  [`chaos_failover_doctrine.md` §6 — the concentration principle: where the obligation lives](../documents/engineering/chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives):
  the `jitML` HA training coordinator is the *First Axis* single-writer election within **one** cluster's
  consistency boundary, and the synchronous consensus it rests on (object-store CAS on the `latest` pointer,
  Pulsar single-consumer subscription semantics, Postgres replication) is **delegated** to the standard
  services rather than re-proved. The coordinator is explicitly **not** the
  [`chaos_failover_doctrine.md` §16 — the Second Axis: when one cluster becomes a forest](../documents/engineering/chaos_failover_doctrine.md#16-the-second-axis--when-one-cluster-becomes-a-forest)
  async cross-cluster boundary, whose TLA+/io-sim proof obligation is Phase 9, not here.
- **Producer→precondition and the training-run topology — jitML checkpoints are the witnessed producer
  (doctrine this round introduces; forward design intent).** This round's doctrine makes a serveable infernix
  `ModelArtifact` require a **provenance witness**
  ([`content_addressing_doctrine.md` §4.5 — The three-tier ML-asset lifecycle: engine baked, model staged, kernel JIT'd](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)):
  a **committed jitML checkpoint** produced in this phase (Sprint 6.1's `latest`/`best` pointer CAS) is exactly
  the **producer** that satisfies the infernix serve gate consumed in
  [Phase 6](phase_06_determinism_infernix.md) / Phase 9 (a `producer→precondition` edge across the
  `jitml-checkpoints/` → `infernix-models/` buckets, adopted by manifest SHA). The round also introduces the
  **training-run topology** — fine-tune chains (`Continue` from a witnessed `ModelArtifact`) and continuous/online
  feeds ([§4.6 — The training-run topology: fine-tune chains and continuous feeds without an unbounded arm](../documents/engineering/content_addressing_doctrine.md#46-the-training-run-topology-fine-tune-chains-and-continuous-feeds-without-an-unbounded-arm)):
  a `Continuous` feed trainer is the **existing jitML HA coordinator** (Sprint 6.5) parameterized with a `Feed`
  source, its single-writer role **delegated** to a Pulsar exclusive/failover subscription + the content-store
  CAS/`AdvancePredicate`, not a new elected worker kind. This is doctrine this round introduces, tracked here as a
  forward cross-reference, not a tested result of the Phase-7 gate.
- **[`monitoring_doctrine.md` §5 — Extensible surfaces: TensorBoard](../documents/engineering/monitoring_doctrine.md#5-extensible-surfaces-tensorboard):**
  jitML's `ExtensionSpec` declares a **mandatory** `TensorBoard` monitoring surface backed by MinIO
  ([§2.3 — Per-extension surfaces](../documents/engineering/monitoring_doctrine.md#23-per-extension-surfaces--extensionspecextmonitoring)),
  so an unmonitored jitML run is unrepresentable; jitML emits `tfevents` to the per-experiment `tb/` prefix, the
  one shared TensorBoard pod declares CPU/RAM and folds via `place`, and a per-user view is a `UserScoped`
  claim-filter over that shared instance
  ([§4 — Access](../documents/engineering/monitoring_doctrine.md#4-access-one-admin-delegated-per-user-scope-no-public-arm)).

## Sprints

## Sprint 6.1: jitML checkpoints onto the content-addressed store 📋

**Status**: Planned
**Implementation**: `src/Amoebius/JitML/Checkpoint/Store.hs`, `src/Amoebius/JitML/Checkpoint/Manifest.hs`
(target: the `jitML` blob/manifest/pointer key renderers and the canonical-CBOR manifest encoder, mapped onto
the Phase-5 three-tier store and native Pulsar client)
**Blocked by**: the Phase-5 content-addressed MinIO store and native Pulsar client (earlier-phase prerequisite)
**Independent Validation**: pure tests that two writers with equal logical checkpoint content emit the same
blob and manifest SHAs (canonical CBOR), and that the pure CAS decision returns `PointerWritten` /
`PointerConflict` correctly — no live MinIO required for the pure layer.
**Docs to update**: `documents/engineering/content_addressing_doctrine.md`

### Objective

Adopt [`content_addressing_doctrine.md` §2 — the three-tier store: blobs ← manifests ← pointers](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers):
move the sibling `jitML` checkpoint format (`jitML/src/JitML/Checkpoint/Format.hs`, evidence not proof) onto
the amoebius content-addressed store so a `jitML` checkpoint is write-once content-addressed blobs (weights,
optimizer, RNG, replay) named by `sha256(bytes)`, a canonical-CBOR manifest named by
`sha256(canonical-cbor)`, and a single mutable `latest` pointer advanced only by an `If-Match` CAS.

### Deliverables

- `blobKey` / `manifestKey` / `latestPointerKey` / `bestPointerKey` / `trialPointerKey` renderers producing
  the fixed prefix schema under one project bucket (`jitml-checkpoints/<experiment-hash>/…`).
- A **canonical** `encodeManifestCbor` (tensors sorted by name, optimizer blobs by kind, RNG blobs by stream
  id, metrics by name) so equal logical content ⇒ byte-identical CBOR ⇒ the same manifest SHA.
- The two write protocols wired through the Phase-5 store: blob/manifest PUTs with `If-None-Match: *` treating
  `412` as success, and the pointer `If-Match` CAS as the single atomic commit point, with the pure
  `applyPointerWrite` decision (`PointerWritten` vs `PointerConflict`) and a typed `AdvancePredicate`.
- Checkpoint adopt/resume events carried over the native-protocol Pulsar client (no WebSockets), at-least-once
  + dedup, the manifest SHA as the `--resume <checkpoint-id>` identity.

### Validation

1. Pure property test: two encoders given equal logical checkpoints emit identical blob and manifest SHAs;
   reordering tensors/optimizer/RNG inputs does not change the SHA.
2. Pure test of `applyPointerWrite` over a matrix of (current ETag, proposed manifest) inputs, asserting the
   CAS winner/loser and that the loser re-applies the typed advance predicate.
3. On `linux-cuda`, write a `jitML` checkpoint to the live store and read it back by manifest SHA; assert a
   re-PUT of identical bytes returns `412`-as-success (a no-op).

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 6.2: CUDA engine behind a default-off cabal flag 📋

**Status**: Planned
**Implementation**: `amoebius.cabal` (a `cuda` flag, `default: False`), `src/Amoebius/JitML/Engine/Cpu.hs`,
`src/Amoebius/JitML/Engine/Cuda.hs` (target: the CPU engine always built; the CUDA engine compiled only under
the flag, behind one engine interface)
**Blocked by**: none
**Independent Validation**: the default `cabal build` (flag off) compiles and links the CPU engine on a host
with no CUDA toolchain; a `+cuda` build compiles the CUDA engine on the `linux-cuda` host; both satisfy one
shared `Engine` interface.
**Docs to update**: `documents/engineering/app_vs_deployment_doctrine.md`

### Objective

Adopt [`app_vs_deployment_doctrine.md` §7 — infernix is a shared library; the inference substrate is a deployment rule](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule),
applied to `jitML`: *which* substrate the training/JIT compute runs on (CUDA on the cluster vs `linux-cpu`) is
a **placement/deployment** choice, never library logic — so the CUDA backend must be confinable, compiled in
only when the deployment selects a GPU substrate, with the default build staying CPU-only and portable.

### Deliverables

- A `cuda` cabal flag, `default: False`, gating the CUDA engine module and its native dependencies so that the
  ordinary (no-GPU) build never requires a CUDA toolchain.
- A single `Engine` interface implemented by `Engine/Cpu.hs` (always built) and `Engine/Cuda.hs` (built only
  under `+cuda`); the chosen engine is selected by the resolved substrate, not by an env var or `PATH` (the
  no-environment / no-`PATH` invariant holds).
- A fail-fast error when a deployment selects CUDA but the binary was built without `+cuda`, naming the
  required build flag (no silent fallback to CPU that would change `experimentHash`).

### Validation

1. `cabal build` with the flag off compiles and links on a host with no CUDA libraries present.
2. `cabal build -f +cuda` compiles the CUDA engine on the `linux-cuda` host; both engines typecheck against
   the shared `Engine` interface.
3. Selecting CUDA on a flag-off binary fails fast with an actionable build-flag diagnostic, touching no store.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 6.3: jitML training determinism on linux-cuda 📋

**Status**: Planned
**Implementation**: `src/Amoebius/JitML/Determinism.hs` (target: the `jitML` binding of the Phase-6
`experimentHash` and SplitMix seed-stream primitives to the `linux-cuda` substrate fingerprint and the
training stream set)
**Blocked by**: Sprint 6.1, Sprint 6.2 (and the Phase-6 determinism kernel as an earlier-phase prerequisite)
**Independent Validation**: pure tests that `experimentHash` changes when the substrate fingerprint changes
and when any identity-bearing `.dhall` field changes (e.g. a metric `direction` flip), and that a stream's
seed is a pure function of `(masterSeed, streamIndex)` independent of worker count.
**Docs to update**: `documents/engineering/content_addressing_doctrine.md`

### Objective

Adopt [`content_addressing_doctrine.md` §3 — `experimentHash`: identity is what was requested ‖ where it ran](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran)
and [`content_addressing_doctrine.md` §4 — determinism by construction: pinned inputs + pure stages + derived seed](../documents/engineering/content_addressing_doctrine.md#4-determinism-by-construction-pinned-inputs--pure-stages--derived-seed):
make a `jitML` training run deterministic-by-construction on `linux-cuda` by folding the resolved `.dhall` with
the `linux-cuda` substrate fingerprint into `experimentHash`, pinning every stage input as a content address,
and deriving every RNG stream (per-experiment, per-game RL self-play, per-HPO-trial, MCTS root noise) from
`(masterSeed, streamIndex)` alone — bounded by
[`content_addressing_doctrine.md` §6 — the honest ceiling](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic).

### Deliverables

- A `jitML` `experimentHash` binding that consumes the Phase-6 `deriveExperimentHash` over
  `(resolved-dhall, linux-cuda substrate fingerprint)`, so a `linux-cuda` run occupies a distinct namespace
  from any CPU run and a metric `direction` flip defines a different experiment.
- Per-stream SplitMix seeds for the full `jitML` training stream set via the Phase-6 `deriveSplitMixSeed`, with
  the proven-in-types property that a stream's seed is independent of worker count, scheduling, and assignment.
- The honest ceiling encoded as the determinism *contract* this run is checked against: same-substrate
  bit-equality for SL / on-policy RL / per-game AlphaZero; a first-N-step prefix (default `rl_steps / 10`) for
  off-policy RL, asserted by comparing **two fresh runs against each other**, never a stored fixture; no
  cross-substrate equality claim.

### Validation

1. Pure tests: `experimentHash` differs across `linux-cpu` vs `linux-cuda` fingerprints and across a
   `direction`-flipped `.dhall`; identical inputs reproduce the same hash.
2. Pure test: `deriveSplitMixSeed (masterSeed, k)` yields identical seeds at 1 worker and at N workers in any
   dispatch order.
3. On `linux-cuda`, run an SL / on-policy training to a checkpoint twice with the same `experimentHash`; assert
   identical manifest SHAs. For an off-policy algorithm, run twice and assert first-N-step prefix equality of
   two fresh runs (sibling-evidence contract, reported as tested, not proven).

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 6.4: jitML as a shared library nested under the InForceSpec 📋

**Status**: Planned
**Implementation**: `src/Amoebius/JitML/Library.hs`, `dhall/jitml/package.dhall` (target: the `jitML` library
surface and the nested `jitML` `.dhall` package composed into the larger amoebius spec)
**Blocked by**: Sprint 6.1
**Independent Validation**: a fixture amoebius app `.dhall` that depends on `jitML` type-checks with the
`jitML` `.dhall` nested inside it; the `jitML` configuration carries no replica count, region, or substrate
selector (those fields do not exist on its surface).
**Docs to update**: `documents/engineering/app_vs_deployment_doctrine.md`, `documents/engineering/dsl_doctrine.md`

### Objective

Adopt [`app_vs_deployment_doctrine.md` §8 — shared-library use is application logic](../documents/engineering/app_vs_deployment_doctrine.md#8-shared-library-use-is-application-logic):
treat *that an app uses `jitML`* as application logic — the library call graph travels with the app — while the
*placement* of the workload (CUDA vs CPU, replica count) stays a deployment rule, so the `jitML` `.dhall`
**nests inside** the `InForceSpec` rather than living as a parallel product, unifying `jitML` as a library
under the DSL.

### Deliverables

- A `jitML` library surface (`Library.hs`) exposing the training/JIT call graph an app composes, with no
  field for replicas, region, failover, chaos, or substrate.
- A nested `jitml/package.dhall` whose configuration is composed into a parent amoebius app `.dhall`; the
  substrate/replica dials live only in the deployment-rules layer that joins with the app.
- A worked fixture: one app `.dhall` that declares "uses `jitML`" (application logic) and a separate
  deployment-rules layer that selects the `linux-cuda` substrate (deployment rule), demonstrating the litmus
  split end-to-end.

### Validation

1. The fixture app `.dhall` type-checks with the `jitML` `.dhall` nested inside it; removing the deployment
   layer leaves the app spec byte-identical.
2. A negative test: attempting to write a replica count or substrate selector on the `jitML`/app-logic surface
   fails to type-check (the field is unrepresentable).

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 6.5: HA training coordinator elected via the kernel election 📋

**Status**: Planned
**Implementation**: `src/Amoebius/JitML/Coordinator.hs` (target: the elected single-writer `jitML` training
coordinator and its ranked failover, riding the kernel election and the delegated coordination plane)
**Blocked by**: Sprint 6.1
**Independent Validation**: a pure model of the coordinator's single-writer decision (capture inputs → decide →
fence → act) shows that at most one candidate ever holds the `latest`-pointer write lease; an injected
lead-kill on `linux-cuda` shows a ranked candidate adopting the role with no torn checkpoint.
**Docs to update**: `documents/engineering/chaos_failover_doctrine.md`, `documents/engineering/daemon_topology_doctrine.md`

### Objective

Adopt the First-Axis side of [`chaos_failover_doctrine.md` §6 — the concentration principle: where the obligation lives](../documents/engineering/chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives):
make the `jitML` training coordinator a **single-writer, elected** role within one cluster's consistency
boundary, riding the kernel leadership election ([`daemon_topology_doctrine.md` §5 — leadership election: the mechanism](../documents/engineering/daemon_topology_doctrine.md#5-leadership-election--the-mechanism-the-proof-lives-elsewhere)),
and **delegate** the synchronous consensus underneath it (the `latest`-pointer CAS, Pulsar single-consumer
subscription semantics, Postgres replication) to the standard services rather than re-proving it. The
coordinator is explicitly **not** the
[`chaos_failover_doctrine.md` §16 — the Second Axis](../documents/engineering/chaos_failover_doctrine.md#16-the-second-axis--when-one-cluster-becomes-a-forest)
cross-cluster boundary (that is Phase 9).

### Deliverables

- A coordinator whose checkpoint-advance branch is **extracted into a pure decision** over captured, typed
  inputs with an explicit freshness/fence contract — never computed mid-race — so that adopting a manifest as
  `latest` is gated by both the CAS and the election lease.
- Ranked-failover wiring on the kernel election: when the lead coordinator dies, a ranked candidate assumes
  the single-writer role and resumes from the last adopted `latest` pointer; candidates share no in-memory
  state and coordinate only through the delegated plane (Pulsar + the content-addressed store).
- An explicit non-goal note in the module and docs: this is intra-cluster (First Axis); cross-cluster
  geo-replication/failover and its proof live in Phase 9 and are not introduced here.

### Validation

1. Model/property test: across interleavings of capture/decide/fence/act, at most one candidate holds the
   write lease, and a lost CAS never produces a torn or double-adopted `latest`.
2. On `linux-cuda`, start a training run, kill the lead coordinator mid-run, and assert a ranked candidate
   takes over and the run continues from the last adopted checkpoint (no duplicated or lost step).
3. Emit a proven/tested/assumed ledger row for the failover run; skipping the inject move marks the runtime
   layer UNVERIFIED, never green.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 6.6: Phase gate — bit-determinism + coordinator failover on linux-cuda 📋

**Status**: Planned
**Implementation**: `test/integration/JitMLGate.hs`, `src/Amoebius/JitML/Validation.hs` (target: the
end-to-end gate validation — a deterministic training run plus an injected coordinator failover, emitting the
ledger)
**Blocked by**: Sprint 6.3, Sprint 6.5
**Independent Validation**: the gate is the validation — it runs on `linux-cuda` and emits a
proven/tested/assumed ledger artifact; it cannot pass on `compiles`.
**Docs to update**: `documents/engineering/content_addressing_doctrine.md`, `documents/engineering/chaos_failover_doctrine.md`

### Objective

Compose the bit-determinism contract of
[`content_addressing_doctrine.md` §6 — the honest ceiling](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic)
with the First-Axis failover of
[`chaos_failover_doctrine.md` §6 — the concentration principle](../documents/engineering/chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives)
into the single Phase-7 acceptance gate: on `linux-cuda`, a `jitML` training run is bit-deterministic per its
determinism contract **and** the elected coordinator fails over — the two claims this phase must demonstrate,
each recorded honestly in the ledger.

### Deliverables

- A gate `.dhall` (per the plan's preferred gate shape) that spins up a `linux-cuda` `jitML` run, asserts the
  determinism contract, injects a lead-coordinator kill, asserts failover, and tears the resources down.
- A determinism assertion that compares **two fresh runs** at matching `experimentHash`: equal manifest SHAs
  for SL / on-policy / per-game AlphaZero; equal first-N-step prefix for off-policy RL — with cross-substrate
  equality explicitly *not* asserted.
- A failover assertion that the run survives a lead kill via ranked election and resumes from the last adopted
  `latest` pointer, plus a proven/tested/assumed ledger artifact for the run.

### Validation

1. **Gate (determinism).** Two fresh `linux-cuda` runs at the same `experimentHash` produce equal manifest
   SHAs (or equal first-N-step prefix for off-policy), with the ceiling's not-asserted rows recorded.
2. **Gate (failover).** Killing the lead coordinator mid-run triggers ranked failover; the run completes from
   the last checkpoint with no torn or duplicated state.
3. The ledger artifact is emitted and green for every applicable move; any skipped applicable test move marks
   its correctness layer UNVERIFIED rather than passing.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update:**
- `documents/engineering/content_addressing_doctrine.md` — when the `jitML` checkpoint store, the
  `linux-cuda`-bound `experimentHash`, and the determinism contract land, confirm the §2/§3/§4 mechanisms and
  the §6 ceiling are exercised on a GPU substrate (status stays in the plan; the doctrine keeps only the target
  shape and its sibling-evidence framing).
- `documents/engineering/app_vs_deployment_doctrine.md` — record that the §7 substrate-as-deployment-rule and
  §8 shared-library-is-app-logic classifications are demonstrated for `jitML` (the `jitML` `.dhall` nests under
  the `InForceSpec`; CUDA is a default-off build flag).
- `documents/engineering/chaos_failover_doctrine.md` — confirm the §6 First-Axis intra-cluster coordinator
  election (delegated synchronous consensus) is exercised, and that this phase makes **no** §16 Second-Axis
  cross-cluster claim; add the Phase-7 failover row to the conformance matrix when the gate runs.
- `documents/engineering/daemon_topology_doctrine.md` — note the §5 kernel election now carries the `jitML`
  training-coordinator single-writer role.

**Cross-references to add:**
- [README.md](README.md) — set the Phase 7 row status from "not started" once work begins, and link this
  document from the Phase 7 paragraph.
- [substrates.md](substrates.md) — record `linux-cuda` as the Phase 7 gate substrate (the first GPU substrate)
  in the per-phase substrate map.
- [system_components.md](system_components.md) — register the target module paths named in the sprint
  `Implementation` fields (`Amoebius.JitML.Checkpoint.*`, `Amoebius.JitML.Engine.*`,
  `Amoebius.JitML.Determinism`, `Amoebius.JitML.Library`, `Amoebius.JitML.Coordinator`,
  `Amoebius.JitML.Validation`).

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 7 paragraph is the authoritative objective and gate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [substrates.md](substrates.md) — the substrate registry and per-phase map (Phase 7: `linux-cuda`)
- [system_components.md](system_components.md) — the target component inventory the `Implementation` paths map to
- [README.md → Phase 5](README.md) — the content-addressed store + native Pulsar client this phase builds on
- [README.md → Phase 6](README.md) — the determinism kernel (`experimentHash` + SplitMix) this phase applies to `jitML`
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md) — content-addressed checkpoints + determinism by construction + the honest ceiling
- [App vs Deployment Doctrine](../documents/engineering/app_vs_deployment_doctrine.md) — `jitML` as a shared library; the substrate as a deployment rule
- [Chaos / Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the concentration principle (First-Axis intra-cluster election, NOT the Second Axis)
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — the kernel leadership-election mechanism the coordinator rides
