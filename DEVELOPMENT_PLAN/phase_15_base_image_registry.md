# Phase 15: Multi-arch base image + jit-build resolver + distribution registry

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_16_renderer_reconciler.md, DEVELOPMENT_PLAN/phase_19_platform_backbone.md, DEVELOPMENT_PLAN/phase_32_jitbuild_engine_cache.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Build the multi-arch amoebius base image — every third-party service binary plus the shared
> jit-build resolver and its toolchain, but no ML engine payloads — and publish it atomically into the
> in-cluster single-binary `distribution` registry so the live cluster pulls only from itself.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 14 gate (the
Python `pb` midwife + substrate detect + an empty single-node `kind` cluster) and runs on the **linux-cpu**
substrate in **Register 3** — a live gate on real infrastructure. Where a shape below is already exercised in a
sibling system — prodbox's `local_registry_pipeline.md` (mirror-into-registry, deterministic tags, retry-then-fail-loud
publication), hostbootstrap's baked-binary asset map (Go/helm/mc/pulumi installed by absolute path), and
jitML's engine resolver — that is **sibling evidence, not an amoebius result**; infernix's per-engine
Poetry-venv + `curl`-tar-at-build is the shape this phase deliberately **replaces**, not inherits. Status
transitions are recorded reverse-chronologically here once work begins.

## Phase Summary

This phase turns the empty `kind` cluster delivered by Phase 14 into a cluster that pulls only from itself. It
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
SSA reconciler that will eventually own the registry manifest is a Phase 16 concern; `no-provisioner` retained
storage is Phase 17 and MinIO is Phase 19, so in this phase the registry stands up from a **raw manifest applied
by `pb`** against **interim node-local (filesystem-driver) blob storage** — the MinIO-backed S3 driver and the
reconciler-owned rendering are named as later-phase targets, honestly, not built here. Vault does not yet exist
(Phase 18), so the host-only registry endpoint is reached credential-free on the node; the Vault-sourced push
credential is likewise a later-phase hardening.

**Substrate:** linux-cpu (§L) — the whole gate runs on a single-node `kind` cluster on a linux-cpu host; no
apple, linux-cuda, or windows substrate is touched in Phase 15. This is a **Register 3** (live-infrastructure)
gate.

**Register:** 3 — live infrastructure (§K).

**Gate:** on the single-node linux-cpu `kind` cluster, the multi-arch base image — carrying every third-party
service binary and the jit-build resolver + its toolchain, but **no** ML engine payload — is built as one
`buildx` OCI manifest list covering `linux/amd64` and `linux/arm64`, side-loaded onto the node, and **published
atomically** (all-or-nothing; a partial-arch push leaves the tag un-advertised) into the in-cluster
single-binary `distribution` registry, with a deny-all egress test to `docker.io`/`quay.io`/`ghcr.io` proving
**zero public-registry pulls** during registry standup or publication and both arches resolving under the one
digest-pinned tag.

The gate's oracles are pinned and committed in **Phase 0**, before any implementation exists (§M.1), and are
listed in [§N](#n-committed-gate-corpus) below; every equivalence check names an
independent reference side (§M.3) and every negative asserts its specific failure reason (§M.8). The gate is
not passed unless, in addition to the above:
- **Inventory reconciled, not self-authored (§M.1/§M.3/§M.7):** the "every third-party service binary" set is
  the Phase-0-committed **canonical standard-platform-services inventory** — the `DEVELOPMENT_PLAN/README.md`
  standard-platform-services list as ratified in
  [`platform_services_doctrine.md`](../documents/engineering/platform_services_doctrine.md), copied verbatim
  into the committed fixture `test/fixtures/phase14/bake_inventory_expected.dhall` — and the bake-inventory
  lint reconciles the image's contents against **that** committed table automatically, never against the
  implementer's own `BakeInventory` value.
- **Per-arch execution, not presence (§M.5):** each baked service binary and each toolchain binary
  (`nvcc`/`g++`/Metal-bridge/pinned compilers) is executed **on each arch** — natively for the host arch and
  under `binfmt`/QEMU for the non-native arch — by **absolute path** with `<bin> --version` matching the
  Phase-0-pinned version in `bake_inventory_expected.dhall`, and each arch's layer passes an ELF `e_machine`
  check proving its binaries are genuinely that arch's (not amd64 bytes copied into the arm64 layer).
- **Enforcement proven by negative control (§M.8):** under the *same* egress policy, a canary pod referencing
  `docker.io/library/busybox` **FAILS `ImagePull`** (its committed expected failure reason: `ErrImagePull` /
  `ImagePullBackOff` from a connection-timeout to the public endpoint), paired with the positive that the
  in-cluster `distribution` pull of the same shape succeeds — foreclosing the unenforced-`NetworkPolicy`
  no-op by forcing an enforcing CNI or node-level host firewall into the harness.
- **OS-boundary observation (§M.5):** "zero public-registry pulls" is read from an **observer at the OS
  boundary** — the `kind` node's `containerd` logs plus a node-level packet capture (`tcpdump`/eBPF) spanning
  the entire standup-and-publish window — asserting **zero** TCP connections to the resolved endpoints of
  `docker.io`/`quay.io`/`ghcr.io` (the concrete set in [§N](#n-committed-gate-corpus)); never a
  compliance trace the publisher emits about itself. The denial scope covers in-cluster registry standup,
  publication, and pull; the **host-side `buildx` build legitimately reaches upstream** (§2/§9) and is
  explicitly outside the denied boundary.
- **Atomicity observed at the registry boundary (§M.3/§M.8):** the partial-arch failure is induced by a
  **fault-injecting proxy** in front of the registry that fails one arch's blob/manifest upload **mid-push**
  (never an exception thrown inside amoebius's own publisher), and "un-advertised" is asserted via the
  registry HTTP API — `GET /v2/<repo>/tags/list` **omits** the tag and the manifest-list `GET` returns
  **404** — not by inspecting amoebius's own published-set record.
- **Idempotence as zero writes (§M.6):** "re-run is a no-op" is defined as **zero mutating requests**
  (`PUT`/`POST`/`PATCH`) in the registry access log during the second run — not merely exit-0-twice or a
  permitted full rebuild-and-re-push.
- **Committed seeded mutants (§M.2):** the mutants named in [§N](#n-committed-gate-corpus) are committed and
  re-run each gate pass and **must go red**.

## Doctrine adopted

- [`image_build_doctrine.md` §7 — what amoebius bakes vs builds: the base container is the supply chain](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain):
  the central adoption — the base image bakes every third-party **service binary** and the **jit-build resolver
  + toolchain**, while the ML **engine payloads** are jit-resolved on first miss and never baked; the
  amoebius runtime image (GHC 9.12.4) is the one image amoebius *builds* — **this phase bakes and publishes the
  amoebius binary alone**; infernix and jitML are linked into the runtime image only when their lifts land (the
  image is rebuilt and republished at [Phase 33](phase_33_infernix_lift.md) /
  [Phase 34](phase_34_jitml_lift_cuda.md), never here), so Phase 15 carries no forward dependency on the
  extension lifts.
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
**Blocked by**: Phase 14 gate (external prereq — `pb bootstrap --distro=kind` brings up an empty single-node `kind` cluster on a linux-cpu host and provides the `pb` CLI); Phase 1's recorded GHC 9.12.4 / Cabal pin for the amoebius runtime layer.
**Independent Validation**: `docker buildx imagetools inspect <tag>` lists both `linux/amd64` and `linux/arm64` under one manifest list; a bake-inventory lint asserts the image contains **every** service binary named in the Phase-0-committed canonical inventory `test/fixtures/phase14/bake_inventory_expected.dhall` (a verbatim copy of the `DEVELOPMENT_PLAN/README.md` standard-platform-services list as ratified in `platform_services_doctrine.md`, reconciled **automatically** against that committed table — never against the implementer's own `BakeInventory` value, §M.3) and the jit-build resolver + its toolchain (`nvcc`/`g++`/Metal bridge/pinned compilers) and contains **no** ML engine payload (`llama.cpp`/`whisper.cpp`/ONNX/Audiveris absent). Presence alone is insufficient (§M.5): for **each** arch — natively for the host arch and under `binfmt`/QEMU for the non-native arch — every baked binary is executed by **absolute path** with `<bin> --version` matching the version pinned in `bake_inventory_expected.dhall`, and each arch's layer passes an ELF `e_machine` check confirming its binaries carry that arch's machine type (foreclosing zero-byte stubs and amd64 bytes copied into the arm64 layer). The committed seeded mutants `mutant/phase14/stub-arm64-binary` (a zero-byte binary at a baked path) and `mutant/phase14/wrong-arch-layer` (amd64 bytes in the arm64 layer) MUST turn this lint red (§M.2).
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
- The Phase-0-committed oracle `test/fixtures/phase14/bake_inventory_expected.dhall` (the canonical
  standard-platform-services set + pinned per-arch versions, independent of `BakeInventory`) and the committed
  mutants `mutant/phase14/stub-arm64-binary` and `mutant/phase14/wrong-arch-layer`.

### Validation
1. `docker buildx imagetools inspect <tag>` lists both `linux/amd64` and `linux/arm64` under one manifest list.
2. The bake-inventory lint is green **against the committed `bake_inventory_expected.dhall`** (services +
   resolver + toolchain present, engine payloads absent), reconciled automatically — not against the SUT's own
   inventory.
3. For each arch (host arch native; non-native under `binfmt`/QEMU), every baked binary runs by absolute path
   with `--version` matching the pinned version, and each arch layer passes the ELF `e_machine` check.
4. The committed mutants `mutant/phase14/stub-arm64-binary` and `mutant/phase14/wrong-arch-layer` turn the
   validation red (§M.2).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 14.2: Node side-load + the single-binary `distribution` registry standup 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Image/NodeLoad.hs`, `src/Amoebius/Image/Registry.hs` (the raw registry manifest applied by `pb`, pre-reconciler) — target paths, not yet built.
**Blocked by**: Sprint 14.1 (the built base image to load); Phase 14 gate (the `kind` node + the `pb` CLI that applies the raw manifest, since the typed SSA reconciler is Phase 16).
**Independent Validation**: the base image is imported into the node's containerd; the `distribution` (`registry:2`) pod runs **from the on-node image** with zero registry pull; the host-only registry endpoint resolves on the `kind` node via the per-distro registry wiring; interim node-local (filesystem-driver) blob storage is used, with the MinIO S3 driver named as the Phase-18 target. "Zero registry pull" is read from an **OS-boundary observer** (§M.5) — the node's `containerd` logs plus a node-level packet capture spanning the standup window — asserting no image-layer fetch and no TCP connection to the resolved endpoints of `docker.io`/`quay.io`/`ghcr.io` ([§N](#n-committed-gate-corpus)), never a self-emitted trace.
**Docs to update**: `documents/engineering/image_build_doctrine.md`, `documents/engineering/platform_services_doctrine.md`.

### Objective
Adopt [`image_build_doctrine.md` §2 — the single distribution rule](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster),
[§9 — the registry chicken-and-egg dissolves](../documents/engineering/image_build_doctrine.md#9-bring-up-ordering--the-registry-chicken-and-egg-dissolves),
and [`platform_services_doctrine.md` §3 — the registry, the single image source](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source):
stand up the single-binary `distribution` registry as the sole in-cluster pull source. Because the SSA
reconciler (Phase 16), retained storage (Phase 17), and MinIO (Phase 19) do not yet exist, the registry comes up
from a raw manifest applied by `pb` against interim node-local blob storage; §9's dissolution holds — the
registry is a baked binary, so there is no pre-registry public-pull window.

### Deliverables
- A node side-load path importing the base image into the `kind` node's containerd (no public pull).
- A minimal raw `distribution` manifest (Deployment + Service) applied by `pb`, reachable at the host-only
  registry endpoint via the per-distro registry plumbing (owned by
  [`substrate_doctrine.md`](../documents/engineering/substrate_doctrine.md) §on host-node registry wiring —
  the `registries.yaml`/containerd-mirror rewrite), with interim filesystem-driver blob storage flagged as
  replaced by the MinIO S3 driver in Phase 19 and re-homed under the typed reconciler in Phase 16.

### Validation
1. Assert the `distribution` pod runs from the on-node image and the registry endpoint resolves on the node.
2. Assert no public-registry pull occurred during registry standup **from the OS-boundary observer** (node
   `containerd` logs + packet capture; zero TCP connections to the [§N](#n-committed-gate-corpus) public
   endpoints), recorded for the Sprint 14.4 gate — never from a self-emitted compliance trace.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 14.3: Atomic multi-arch publication + immutable digest-pinned refs 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Image/Publish.hs`, `src/Amoebius/Image/Ref.hs` (the single-`--push` publisher + the immutable, source/content-derived ref scheme) — target paths, not yet built.
**Blocked by**: Sprint 14.2 (the running registry to push into), Sprint 14.1 (the manifest list to publish).
**Independent Validation**: one `buildx … --push` lands the complete manifest list or errors; the partial (one-arch) push is induced by a **fault-injecting proxy** in front of the registry that fails one arch's blob/manifest upload **mid-push** (§M.3 — a registry-boundary fault, never an exception thrown inside amoebius's own publisher), and the tag is asserted **un-advertised at the registry HTTP API**: `GET /v2/<repo>/tags/list` omits the tag and the manifest-list `GET` returns **404** (§M.8 — the observable is the registry's state, not amoebius's own published-set record); a re-run against a fully-published tag is a **no-op**, defined as **zero mutating requests** (`PUT`/`POST`/`PATCH`) in the registry access log during the second run (§M.6 — not exit-0-twice, not a permitted rebuild-and-re-push); refs are immutable digest-pinned (never `:latest` as a deployment reference); the build uses an ephemeral `docker --config <dir>` with **no** environment variable and **no** `docker login`. The committed mutant `mutant/phase14/record-before-push` (records the tag as published before the manifest list lands) MUST turn the un-advertised assertion red (§M.2).
**Docs to update**: `documents/engineering/image_build_doctrine.md`.

### Objective
Adopt [`image_build_doctrine.md` §4 — atomic publication](../documents/engineering/image_build_doctrine.md#4-atomic-publication--a-partial-multi-arch-upload-is-a-failed-upload),
[§5 — versioning vs `:latest`](../documents/engineering/image_build_doctrine.md#5-versioning-vs-latest--development_plan-decision-recommended-default-immutable-never-latest),
and [§8 — build mechanics under the no-env / no-`PATH` contract](../documents/engineering/image_build_doctrine.md#8-build-mechanics-under-the-no-env--no-path-contract):
publish the base-image manifest list into the registry as one indivisible artifact — fail-closed on a partial
arch, idempotent on re-run — under immutable digest-pinned refs, with the `buildx` binary full-path-invoked
against an ephemeral config directory. Vault does not yet exist (Phase 18), so the host-only endpoint is reached
credential-free here; the Vault-sourced push credential is named as the later-phase hardening, not built now.

### Deliverables
- The publish path: a single `buildx … --push` of the manifest list that lands both arches or fails, recording
  the tag as published only when every target arch is present.
- The immutable ref scheme: a deterministic source/content-derived tag consumed by digest; `:latest` is never a
  deployment reference.
- The no-env build mechanics: an ephemeral `docker --config <dir>` created per build and scrubbed afterward, the
  `docker`/`buildx` binary resolved to an absolute path via the substrate package manager (never `PATH`), no
  `docker login`; the Vault `SecretRef` push credential flagged as the Phase-17+ target.
- The fault-injecting registry proxy (fails one arch's blob/manifest upload mid-push) and the committed mutant
  `mutant/phase14/record-before-push`, plus the registry access-log capture used for the zero-writes re-run
  assertion.

### Validation
1. A single push lands the complete manifest list; a **proxy-induced** one-arch mid-push failure leaves the tag
   un-advertised **at the registry HTTP API** (`tags/list` omits it; manifest-list `GET` 404s).
2. Re-run against a fully-published tag is a no-op, asserted as **zero `PUT`/`POST`/`PATCH` requests** in the
   registry access log during the second run; the ref is digest-pinned and never `:latest`.
3. The build uses the ephemeral config directory with no environment variable and no `docker login`.
4. The committed mutant `mutant/phase14/record-before-push` turns Validation 1 red (§M.2).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 14.4: The no-public-registry-pull gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Image/Gate.hs` / a `pb` gate subcommand + `test/live/RegistryGate.hs` (the Register-3 gate harness) — target paths, not yet built.
**Blocked by**: Sprint 14.3 (the atomically-published tag), Sprint 14.2 (the running registry).
**Independent Validation**: the egress denial is realized as a **node-level host firewall / IP-CIDR blackhole** of the resolved public-registry endpoints (or an enforcing-CNI FQDN policy) — **not** a vanilla `kindnetd` `NetworkPolicy`, which `kindnetd` does not enforce and which cannot match FQDNs (§M ambiguity resolution). Its enforcement is proven by a **negative control** (§M.8): under the *same* policy, a canary pod referencing `docker.io/library/busybox` **FAILS `ImagePull`** with the committed expected reason (`ErrImagePull`/`ImagePullBackOff` from a connection-timeout to the public endpoint), paired with the positive that an in-cluster `distribution` pull of the same shape succeeds. Under that enforced denial the registry stands up and the base-image manifest list publishes and resolves with **zero** requests leaving for a public registry, asserted from the **OS-boundary observer** (§M.5) — node `containerd` logs + a packet capture spanning the entire standup-and-publish window, showing zero TCP connections to the resolved endpoints of the [§N](#n-committed-gate-corpus) public-registry set; never a self-emitted compliance trace. The denial scope covers in-cluster standup/publication/pull; the **host-side `buildx` build is outside it** and legitimately reaches upstream (§2/§9). Both `linux/amd64` and `linux/arm64` resolve under the one digest-pinned tag; a re-run of the whole build → side-load → standup → publish flow is idempotent, defined as **zero mutating (`PUT`/`POST`/`PATCH`) requests** in the registry access log during the second run (§M.6 — not a permitted full rebuild-and-re-push). The committed mutant `mutant/phase14/noop-egress-policy` (a vanilla unenforced `NetworkPolicy` substituted for the enforcing firewall) MUST turn the negative-control assertion red (§M.2).
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (flip the Phase-14 status when the gate passes), `documents/engineering/image_build_doctrine.md`, `DEVELOPMENT_PLAN/substrates.md`.

### Objective
Adopt [`image_build_doctrine.md` §2](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster)
and [§4](../documents/engineering/image_build_doctrine.md#4-atomic-publication--a-partial-multi-arch-upload-is-a-failed-upload)
under [`testing_doctrine.md` §2 — Register 3](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing):
run the whole flow on the live `kind` cluster and prove no public-registry pull and atomic multi-arch
publication, then emit a Register-3 proven/tested/assumed ledger — the model↔runtime correspondence with the
later reconciler-owned rendering (Phase 16) and the MinIO-backed blob store (Phase 19) marked UNVERIFIED here.

### Deliverables
- The gate harness applying the **enforced** node-level egress denial (host firewall / IP-CIDR blackhole or
  enforcing-CNI FQDN policy), the `docker.io/library/busybox` negative-control canary, the OS-boundary observer
  (node `containerd` logs + packet capture), and the registry access-log capture; driving the build →
  side-load → standup → publish flow and asserting the negative-control `ImagePull` failure, zero public pulls
  from the observer, both-arch resolution, and zero-writes idempotent re-run.
- The committed oracle `test/fixtures/phase14/public_registry_endpoints.txt` (the concrete public-registry
  endpoint set the observer checks against) and the committed mutant `mutant/phase14/noop-egress-policy`.
- A Register-3 ledger naming the substrate (linux-cpu) and the register, attaching the OS-boundary observer
  evidence, with the interim-storage and reconciler-rehoming residue flagged UNVERIFIED, never green.

### Validation
1. The **enforced** egress denial breaks no registry standup, publication, or in-cluster pull, **while** the
   `docker.io/library/busybox` negative-control canary FAILS `ImagePull` (proving enforcement); zero public
   pulls are observed at the OS boundary (node `containerd` logs + packet capture) against the committed
   endpoint set.
2. Both `linux/amd64` and `linux/arm64` resolve under the one digest-pinned tag; the whole flow re-runs as a
   no-op, asserted as **zero mutating requests** in the registry access log during the second run.
3. The committed mutant `mutant/phase14/noop-egress-policy` (unenforced vanilla `NetworkPolicy`) turns
   Validation 1's negative-control assertion red (§M.2).

### Remaining Work
The whole sprint (📋 Planned).

## N. Committed gate corpus

Per [`development_plan_standards.md` §M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub),
the oracles below are authored and **committed in Phase 0** — before the Phase 15 implementation exists — and
their reference sides are defined independently of the code under test. This section is the phase doc's explicit
"representative set" (§M.7).

**Pinned oracles (Phase-0-committed):**
- `test/fixtures/phase14/bake_inventory_expected.dhall` — the canonical standard-platform-services inventory
  (a verbatim copy of the `DEVELOPMENT_PLAN/README.md` standard-platform-services list as ratified in
  [`platform_services_doctrine.md`](../documents/engineering/platform_services_doctrine.md)) with the per-arch
  pinned version each `<bin> --version` must match; authored independently of `BakeInventory` (§M.3).
- `test/fixtures/phase14/public_registry_endpoints.txt` — the concrete public-registry endpoint set the
  OS-boundary observer asserts zero connections to: `registry-1.docker.io`, `auth.docker.io`,
  `production.cloudflare.docker.com`, `quay.io`, `cdn.quay.io`, `ghcr.io`, `pkg-containers.githubusercontent.com`
  (and their resolved IP CIDRs at gate time).
- `test/fixtures/phase14/expected_pull_failure.txt` — the negative-control canary's expected reason
  (`ErrImagePull`/`ImagePullBackOff`, connection-timeout to the public endpoint), paired with the positive
  in-cluster pull that must succeed (§M.8).

**Committed seeded mutants (each MUST go red at the named gate, §M.2):**
- `mutant/phase14/stub-arm64-binary` — a zero-byte binary at a baked path; red at Sprint 14.1 (execution +
  ELF check).
- `mutant/phase14/wrong-arch-layer` — amd64 bytes placed in the arm64 layer; red at Sprint 14.1 (`e_machine`
  check).
- `mutant/phase14/record-before-push` — records the tag as published before the manifest list lands; red at
  Sprint 14.3 (registry-API un-advertised assertion).
- `mutant/phase14/noop-egress-policy` — a vanilla unenforced `kindnetd` `NetworkPolicy` substituted for the
  enforcing firewall; red at Sprint 14.4 (negative-control canary must fail `ImagePull`).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/image_build_doctrine.md` — the §2/§4 single-distribution and atomic-publication claims
  gain their first amoebius validation; the §5 (versioning) / §6 (host vs in-pod builder) decisions are recorded
  as taken; the §7 bake-vs-build split (services + resolver/toolchain baked, engine payloads not) is annotated
  as delivered on linux-cpu.
- `documents/engineering/content_addressing_doctrine.md` — annotate §4.5 that the base image contributes the
  jit-build resolver + toolchain by OCI digest while the engine payloads remain content-addressed cache assets,
  resolved on first miss (the resolver's own live proof lands in Phase 32).
- `documents/engineering/platform_services_doctrine.md` — the §3 registry-as-single-image-source note flips from
  design intent to a delivered `distribution` standup, with the MinIO-backed S3 driver still a Phase-18 target.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-14 row from Planned to its delivered status and link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 15's gate substrate (linux-cpu) in the per-phase substrate map.
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
- [phase_14](phase_14_midwife_bootstrap_kind.md) — the `pb` midwife + empty `kind` cluster this phase publishes into
- [phase_16](phase_16_renderer_reconciler.md) — the typed SSA reconciler that re-homes the registry manifest
- [phase_19](phase_19_platform_backbone.md) — the standard service stack whose MinIO backs the registry's S3-driver blob store
- [phase_32](phase_32_jitbuild_engine_cache.md) — the live jit-build engine resolver + `CacheBudget` cache the toolchain here feeds
