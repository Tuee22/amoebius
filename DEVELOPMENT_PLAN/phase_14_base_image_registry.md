# Phase 14: Multi-arch base image + jit-build resolver + distribution registry

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, later_phases.md, legacy_tracking_for_deletion.md, overview.md, phase_15_renderer_reconciler.md, phase_25_jitbuild_engine_cache.md, system_components.md
**Generated sections**: none

> **Purpose**: Build the multi-arch amoebius base image — every third-party service binary plus the shared
> jit-build resolver and its toolchain, but no ML engine payloads — and publish it atomically into the
> in-cluster single-binary `distribution` registry so the live cluster pulls only from itself.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 13 gate (the
Python `pb` midwife + substrate detect + an empty single-node `kind` cluster) and runs on the **linux-cpu**
substrate in **Register 3** — a live gate on real infrastructure. Where a shape below is already exercised in a
sibling system — prodbox's `local_registry_pipeline.md` (mirror-into-registry, deterministic tags, retry-then-fail-loud
publication), hostbootstrap's baked-binary asset map (Go/helm/mc/pulumi installed by absolute path), and
jitML's engine resolver — that is **sibling evidence, not an amoebius result**; infernix's per-engine
Poetry-venv + `curl`-tar-at-build is the shape this phase deliberately **replaces**, not inherits. Status
transitions are recorded reverse-chronologically here once work begins.

## Phase Summary

This phase turns the empty `kind` cluster delivered by Phase 13 into a cluster that pulls only from itself. It
delivers the **multi-arch base image** — every third-party platform-service binary (the `distribution`
registry, MinIO, Vault, Pulsar, Keycloak, Prometheus/Grafana, Patroni/Percona Postgres, Envoy, MetalLB, and
the rest) baked in by the supply-chain preference ladder (apt → official binary/tarball → build-from-source,
including a multi-arch Temurin JRE for the JVM services), **plus the shared jit-build resolver and its build
toolchain** (`nvcc`, `g++`, the Apple-Metal bridge, the pinned compilers). The ML **engine payloads**
(`llama.cpp`, `whisper.cpp`, the ONNX runtime, Audiveris, the adapters) are the deliberate exception: each is a
**named catalog identity** the shared jit-build resolver materializes on first miss into the
`CacheBudget`-bounded content-addressed cache — none is baked and none is authored by URL. The image is built
as **one `buildx` OCI manifest list** covering `linux/amd64` and `linux/arm64`, side-loaded onto the node, and
**published atomically** into the in-cluster single-binary `distribution` registry (which replaces Harbor), the
sole in-cluster pull source.

The scope deliberately stops at *baking the image and publishing it fail-closed with no public pull*. The typed
SSA reconciler that will eventually own the registry manifest is a Phase 15 concern; `no-provisioner` retained
storage is Phase 16 and MinIO is Phase 18, so in this phase the registry stands up from a **raw manifest applied
by `pb`** against **interim node-local (filesystem-driver) blob storage** — the MinIO-backed S3 driver and the
reconciler-owned rendering are named as later-phase targets, honestly, not built here. Vault does not yet exist
(Phase 17), so the host-only registry endpoint is reached credential-free on the node; the Vault-sourced push
credential is likewise a later-phase hardening.

**Substrate:** linux-cpu (§L) — the whole gate runs on a single-node `kind` cluster on a linux-cpu host; no
apple, linux-cuda, or windows substrate is touched in Phase 14. This is a **Register 3** (live-infrastructure)
gate.

**Gate:** on the single-node linux-cpu `kind` cluster, the multi-arch base image — carrying every third-party
service binary and the jit-build resolver + its toolchain, but **no** ML engine payload — is built as one
`buildx` OCI manifest list covering `linux/amd64` and `linux/arm64`, side-loaded onto the node, and **published
atomically** (all-or-nothing; a partial-arch push leaves the tag un-advertised) into the in-cluster
single-binary `distribution` registry, with a deny-all egress test to `docker.io`/`quay.io`/`ghcr.io` proving
**zero public-registry pulls** during registry standup or publication and both arches resolving under the one
digest-pinned tag.

## Doctrine adopted

- [`image_build_doctrine.md` §7 — what amoebius bakes vs builds: the base container is the supply chain](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain):
  the central adoption — the base image bakes every third-party **service binary** and the **jit-build resolver
  + toolchain**, while the ML **engine payloads** are jit-resolved on first miss and never baked; the
  amoebius runtime image (GHC 9.12.4) is the one image amoebius *builds*, with infernix/jitML linked in as
  extension libraries.
- [`image_build_doctrine.md` §2 — the single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster):
  the in-cluster `distribution` registry (replacing Harbor) is the sole pull source, and no workload ever pulls
  from a public registry.
- [`image_build_doctrine.md` §3 — buildx multi-arch: `amd64` and `arm64`, one manifest list](../documents/engineering/image_build_doctrine.md#3-buildx-multi-arch--amd64-and-arm64-one-manifest-list):
  one `docker buildx` invocation builds both arches as a single OCI manifest list under one tag.
- [`image_build_doctrine.md` §4 — atomic publication: a partial multi-arch upload is a failed upload](../documents/engineering/image_build_doctrine.md#4-atomic-publication--a-partial-multi-arch-upload-is-a-failed-upload):
  fail-closed atomic publication — the single `--push` lands the complete manifest list or the tag stays
  un-advertised, and re-run is idempotent.
- [`image_build_doctrine.md` §5 — versioning vs `:latest`](../documents/engineering/image_build_doctrine.md#5-versioning-vs-latest--development_plan-decision-recommended-default-immutable-never-latest)
  and [`§8` — build mechanics under the no-env / no-`PATH` contract](../documents/engineering/image_build_doctrine.md#8-build-mechanics-under-the-no-env--no-path-contract):
  immutable, digest-pinned refs (never `:latest` as a deployment reference) and the ephemeral
  `docker --config` build mechanics with no environment variable and no `docker login`.
- [`image_build_doctrine.md` §9 — bring-up ordering: the registry chicken-and-egg dissolves](../documents/engineering/image_build_doctrine.md#9-bring-up-ordering--the-registry-chicken-and-egg-dissolves):
  the registry is itself a baked binary, so the base image is loaded before the cluster serves and there is no
  pre-registry public-pull window to bootstrap.
- [`platform_services_doctrine.md` §3 — the registry, the single image source](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source):
  the `distribution` registry as a standard service, reached at the host-only registry endpoint.
- [`content_addressing_doctrine.md` §4.5 — the ML asset lifecycle: one bounded content-addressed cache, resolved on first miss](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
  the reversal this phase upholds — engine payloads are named catalog identities resolved into a
  `CacheBudget`-bounded content-addressed cache, with no arbitrary-`Url` arm, never OCI-baked.
- [`testing_doctrine.md` §2 — three registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing):
  this phase's gate reaches **Register 3** (live infrastructure) and emits a proven/tested/assumed ledger
  naming that register.

## Sprints

## Sprint 14.1: Multi-arch base image bake — services + jit-build resolver/toolchain, not engine payloads 📋

**Status**: Planned
**Implementation**: `docker/base/Dockerfile`, `src/Amoebius/Image/Build.hs`, `src/Amoebius/Image/BakeInventory.hs` (the per-arch asset map + version resolver, hostbootstrap-style) — target paths, not yet built.
**Blocked by**: Phase 13 gate (external prereq — `pb bootstrap --distro=kind` brings up an empty single-node `kind` cluster on a linux-cpu host and provides the `pb` CLI); Phase 1's recorded GHC 9.12.4 / Cabal pin for the amoebius runtime layer.
**Independent Validation**: `docker buildx imagetools inspect <tag>` lists both `linux/amd64` and `linux/arm64` under one manifest list; a bake-inventory lint asserts the image contains **every** named service binary and the jit-build resolver + its toolchain (`nvcc`/`g++`/Metal bridge/pinned compilers) and contains **no** ML engine payload (`llama.cpp`/`whisper.cpp`/ONNX/Audiveris absent).
**Docs to update**: `documents/engineering/image_build_doctrine.md`, `documents/engineering/content_addressing_doctrine.md`.

### Objective
Adopt [`image_build_doctrine.md` §7 — what amoebius bakes vs builds](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain)
and [§3 — buildx multi-arch, one manifest list](../documents/engineering/image_build_doctrine.md#3-buildx-multi-arch--amd64-and-arm64-one-manifest-list):
bake every third-party service binary by the apt → official-binary → build-from-source ladder (including a
multi-arch Temurin JRE for the JVM services) **and** the shared jit-build resolver + its build toolchain, while
holding the ML engine payloads out of the image as named catalog identities resolved on first miss into the
`CacheBudget`-bounded cache ([`content_addressing_doctrine.md` §4.5](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)) —
the shape jitML's resolver evidences and infernix's `curl`-tar-at-build is *sibling evidence being replaced*.

### Deliverables
- A multi-arch base `Dockerfile` baking each platform binary by the supply-chain preference order, plus the
  jit-build resolver and its toolchain layer; the amoebius runtime image built at GHC 9.12.4 with infernix/jitML
  linked as extension libraries.
- A `docker buildx --platform linux/amd64,linux/arm64` build producing **one** OCI manifest list per tag.
- The `BakeInventory` asset map (per-arch pinned versions) driving logic-free `ARG`/`RUN … install` blocks, and
  a bake-inventory lint proving the resolver/toolchain are present and every ML engine payload is **absent**.

### Validation
1. `docker buildx imagetools inspect <tag>` lists both `linux/amd64` and `linux/arm64` under one manifest list.
2. The bake-inventory lint is green: services + resolver + toolchain present, engine payloads absent.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 14.2: Node side-load + the single-binary `distribution` registry standup 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Image/NodeLoad.hs`, `src/Amoebius/Image/Registry.hs` (the raw registry manifest applied by `pb`, pre-reconciler) — target paths, not yet built.
**Blocked by**: Sprint 14.1 (the built base image to load); Phase 13 gate (the `kind` node + the `pb` CLI that applies the raw manifest, since the typed SSA reconciler is Phase 15).
**Independent Validation**: the base image is imported into the node's containerd; the `distribution` (`registry:2`) pod runs **from the on-node image** with zero registry pull; the host-only registry endpoint resolves on the `kind` node via the per-distro registry wiring; interim node-local (filesystem-driver) blob storage is used, with the MinIO S3 driver named as the Phase-18 target.
**Docs to update**: `documents/engineering/image_build_doctrine.md`, `documents/engineering/platform_services_doctrine.md`.

### Objective
Adopt [`image_build_doctrine.md` §2 — the single distribution rule](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster),
[§9 — the registry chicken-and-egg dissolves](../documents/engineering/image_build_doctrine.md#9-bring-up-ordering--the-registry-chicken-and-egg-dissolves),
and [`platform_services_doctrine.md` §3 — the registry, the single image source](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source):
stand up the single-binary `distribution` registry as the sole in-cluster pull source. Because the SSA
reconciler (Phase 15), retained storage (Phase 16), and MinIO (Phase 18) do not yet exist, the registry comes up
from a raw manifest applied by `pb` against interim node-local blob storage; §9's dissolution holds — the
registry is a baked binary, so there is no pre-registry public-pull window.

### Deliverables
- A node side-load path importing the base image into the `kind` node's containerd (no public pull).
- A minimal raw `distribution` manifest (Deployment + Service) applied by `pb`, reachable at the host-only
  registry endpoint via the per-distro registry plumbing (owned by
  [`substrate_doctrine.md`](../documents/engineering/substrate_doctrine.md) §on host-node registry wiring —
  the `registries.yaml`/containerd-mirror rewrite), with interim filesystem-driver blob storage flagged as
  replaced by the MinIO S3 driver in Phase 18 and re-homed under the typed reconciler in Phase 15.

### Validation
1. Assert the `distribution` pod runs from the on-node image and the registry endpoint resolves on the node.
2. Assert no public-registry pull occurred during registry standup (recorded for the Sprint 14.4 gate).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 14.3: Atomic multi-arch publication + immutable digest-pinned refs 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Image/Publish.hs`, `src/Amoebius/Image/Ref.hs` (the single-`--push` publisher + the immutable, source/content-derived ref scheme) — target paths, not yet built.
**Blocked by**: Sprint 14.2 (the running registry to push into), Sprint 14.1 (the manifest list to publish).
**Independent Validation**: one `buildx … --push` lands the complete manifest list or errors; a simulated partial (one-arch) push leaves the tag **un-advertised**; a re-run against a fully-published tag is a **no-op**; refs are immutable digest-pinned (never `:latest` as a deployment reference); the build uses an ephemeral `docker --config <dir>` with **no** environment variable and **no** `docker login`.
**Docs to update**: `documents/engineering/image_build_doctrine.md`.

### Objective
Adopt [`image_build_doctrine.md` §4 — atomic publication](../documents/engineering/image_build_doctrine.md#4-atomic-publication--a-partial-multi-arch-upload-is-a-failed-upload),
[§5 — versioning vs `:latest`](../documents/engineering/image_build_doctrine.md#5-versioning-vs-latest--development_plan-decision-recommended-default-immutable-never-latest),
and [§8 — build mechanics under the no-env / no-`PATH` contract](../documents/engineering/image_build_doctrine.md#8-build-mechanics-under-the-no-env--no-path-contract):
publish the base-image manifest list into the registry as one indivisible artifact — fail-closed on a partial
arch, idempotent on re-run — under immutable digest-pinned refs, with the `buildx` binary full-path-invoked
against an ephemeral config directory. Vault does not yet exist (Phase 17), so the host-only endpoint is reached
credential-free here; the Vault-sourced push credential is named as the later-phase hardening, not built now.

### Deliverables
- The publish path: a single `buildx … --push` of the manifest list that lands both arches or fails, recording
  the tag as published only when every target arch is present.
- The immutable ref scheme: a deterministic source/content-derived tag consumed by digest; `:latest` is never a
  deployment reference.
- The no-env build mechanics: an ephemeral `docker --config <dir>` created per build and scrubbed afterward, the
  `docker`/`buildx` binary resolved to an absolute path via the substrate package manager (never `PATH`), no
  `docker login`; the Vault `SecretRef` push credential flagged as the Phase-17+ target.

### Validation
1. A single push lands the complete manifest list; a simulated one-arch failure leaves the tag un-advertised.
2. Re-run against a fully-published tag is a no-op; the ref is digest-pinned and never `:latest`.
3. The build uses the ephemeral config directory with no environment variable and no `docker login`.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 14.4: The no-public-registry-pull gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Image/Gate.hs` / a `pb` gate subcommand + `test/live/RegistryGate.hs` (the Register-3 gate harness) — target paths, not yet built.
**Blocked by**: Sprint 14.3 (the atomically-published tag), Sprint 14.2 (the running registry).
**Independent Validation**: with a deny-all egress NetworkPolicy to `docker.io`/`quay.io`/`ghcr.io`, the registry stands up and the base-image manifest list publishes and resolves with **zero** requests leaving for a public registry; both `linux/amd64` and `linux/arm64` resolve under the one digest-pinned tag; a re-run of the whole build → side-load → standup → publish flow is idempotent.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (flip the Phase-14 status when the gate passes), `documents/engineering/image_build_doctrine.md`, `DEVELOPMENT_PLAN/substrates.md`.

### Objective
Adopt [`image_build_doctrine.md` §2](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster)
and [§4](../documents/engineering/image_build_doctrine.md#4-atomic-publication--a-partial-multi-arch-upload-is-a-failed-upload)
under [`testing_doctrine.md` §2 — Register 3](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing):
run the whole flow on the live `kind` cluster and prove no public-registry pull and atomic multi-arch
publication, then emit a Register-3 proven/tested/assumed ledger — the model↔runtime correspondence with the
later reconciler-owned rendering (Phase 15) and the MinIO-backed blob store (Phase 18) marked UNVERIFIED here.

### Deliverables
- The gate harness applying the deny-all public-registry egress policy, driving the build → side-load →
  standup → publish flow, and asserting zero public pulls, both-arch resolution, and idempotent re-run.
- A Register-3 ledger naming the substrate (linux-cpu) and the register, with the interim-storage and
  reconciler-rehoming residue flagged UNVERIFIED, never green.

### Validation
1. The deny-all egress policy breaks no registry standup, publication, or in-cluster pull.
2. Both `linux/amd64` and `linux/arm64` resolve under the one digest-pinned tag; the whole flow re-runs as a no-op.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/image_build_doctrine.md` — the §2/§4 single-distribution and atomic-publication claims
  gain their first amoebius validation; the §5 (versioning) / §6 (host vs in-pod builder) decisions are recorded
  as taken; the §7 bake-vs-build split (services + resolver/toolchain baked, engine payloads not) is annotated
  as delivered on linux-cpu.
- `documents/engineering/content_addressing_doctrine.md` — annotate §4.5 that the base image contributes the
  jit-build resolver + toolchain by OCI digest while the engine payloads remain content-addressed cache assets,
  resolved on first miss (the resolver's own live proof lands in Phase 25).
- `documents/engineering/platform_services_doctrine.md` — the §3 registry-as-single-image-source note flips from
  design intent to a delivered `distribution` standup, with the MinIO-backed S3 driver still a Phase-18 target.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-14 row from Planned to its delivered status and link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 14's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register `docker/base/Dockerfile`, `src/Amoebius/Image/*`, and the
  `distribution` registry standup as Phase-14 design-first rows, reconciled against the component inventory.

## Related Documents
- [README.md](README.md) — the live tracker and phase ordering this document sits under
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [overview.md](overview.md) — the target architecture and cross-cutting invariants
- [Image Build & Registry](../documents/engineering/image_build_doctrine.md) — the baked-binary base container + `distribution` registry adopted here (§2, §3, §4, §5, §7, §8, §9)
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md) — §4.5 the jit-resolved engine cache the base image does *not* bake
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — §3 the registry as the single in-cluster image source
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) — the per-distro registry plumbing and the lazy-tool-ensure contract the build obeys
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 the three registers (Register 3 reached here)
- [phase_13](phase_13_midwife_bootstrap_kind.md) — the `pb` midwife + empty `kind` cluster this phase publishes into
- [phase_15](phase_15_renderer_reconciler.md) — the typed SSA reconciler that re-homes the registry manifest
- [phase_18](phase_18_platform_services.md) — the standard service stack whose MinIO backs the registry's S3-driver blob store
- [phase_25](phase_25_jitbuild_engine_cache.md) — the live jit-build engine resolver + `CacheBudget` cache the toolchain here feeds
