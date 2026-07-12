# Legacy Tracking for Deletion

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_14_midwife_bootstrap_kind.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

> **Purpose**: The migration-removal ledger for the convergence — the single record of every sibling-project
> artifact (standalone product, third-party chart, retired transport, single-arch image) that the amoebius
> convergence deliberately does **not** carry forward, with the doctrine that supersedes it and the owning
> phase that makes the removal real.

---

## Ledger Status

📋 **Planned — greenfield.** Nothing has been removed yet, because amoebius has no implementation yet: the
suite is greenfield and every phase is 📋 Planned (see [README.md](README.md)). This ledger is therefore not
a list of deletions from an existing amoebius tree. It is a forward record of artifacts that live in the
**sibling projects** (prodbox, infernix, jitML, hostbootstrap) whose *role* amoebius absorbs as
a library or whose *mechanism* amoebius supersedes — so they are intentionally never reproduced here. A row
graduates from 📋 Planned to ✅ Done only when its **owning phase** gate actually passes on its substrate and
the superseding mechanism is the live one; until then every "removed" verb below is design intent, not a
tested amoebius result.

Where a row leans on the sibling prodbox/infernix/jitML system as justification, that is **evidence from a
sibling system, not proof in amoebius** (the honesty rule, [development_plan_standards.md](development_plan_standards.md) §K).

---

## Pending Removal

"Location" names the **sibling-project artifact** being supplanted (amoebius has no `src/` yet); the target
amoebius module that absorbs or replaces it is owned by [system_components.md](system_components.md). "Why
slated" cites the governing doctrine section by name. "Owning phase" is the amoebius phase whose adoption
work performs the removal.

| Item | Location (sibling artifact) | Why slated | Owning phase |
|------|-----------------------------|------------|--------------|
| **prodbox** as a standalone product / CLI | sibling `prodbox/` — `app/prodbox/Main.hs`, `src/Prodbox/` | prodbox is absorbed as the **root single-node control-plane behaviour** — a library + the in-cluster control-plane singleton (a Deployment `replicas=1`, single-instance from k8s/etcd, no election) under the one amoebius binary, not a separate product; see [`daemon_topology_doctrine.md` §3 — the control-plane singleton](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton) and the convergence framing in [README.md](README.md) | [Phase 14](phase_14_midwife_bootstrap_kind.md) – [Phase 22](phase_22_live_dsl_singleton.md) |
| **The shell `bootstrap.sh` igniter** | sibling hostbootstrap `bootstrap.sh` (the substrate shell script) | Retired for the **Python `pb` midwife CLI** — one Python CLI, two modes (midwife bring-up + admin-REST client); amoebius owns no shell script; see [`substrate_doctrine.md` §6 — the midwife contract](../documents/engineering/substrate_doctrine.md#6-the-midwife-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off) | [Phase 14](phase_14_midwife_bootstrap_kind.md) |
| **infernix** as a standalone product / image | sibling `infernix/` — `Infernix.Runtime.*` | infernix becomes an **ML extension library** linked into the amoebius binary (and a shared library at the app surface), never a separate product; see [`app_vs_deployment_doctrine.md` §7 — infernix is a shared library, the inference substrate is a deployment rule](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule) | [Phase 33](phase_33_infernix_lift.md) |
| **jitML** as a standalone product | sibling `jitML/` — `JitML.*` | jitML becomes an **ML extension library** whose single-writer trainer fails over via a **Pulsar Failover subscription + content-store CAS** (no bespoke election), not a separate product | [Phase 34](phase_34_jitml_lift_cuda.md) |
| **Baked / Poetry-venv ML engine payloads** | sibling infernix per-engine Poetry venvs + curl-tar-at-image-build (`docker/Dockerfile`, `model_cache.py`) | Retired for the shared **jit-build resolver + `CacheBudget`-bounded content-addressed cache**: each engine is a named catalog identity resolved on first miss, never baked or URL-fetched; see [`content_addressing_doctrine.md` §4.5 — the ML-asset lifecycle](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss) and [`image_build_doctrine.md` §7](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain) | [Phase 32](phase_32_jitbuild_engine_cache.md) |
| **All third-party Helm charts + the Helm binary** | sibling prodbox chart platform (`Prodbox.Lib.ChartPlatform`, vendored charts); `helm` baked in the hostbootstrap base image | No-Helm: platform and app manifests are **pure typed Haskell rendered and applied by the typed reconciler** (server-side apply, ApplySet prune, wait), so neither charts nor the `helm` dependency survive; see [`manifest_generation_doctrine.md` §1 — why this doctrine exists: types render manifests, Helm does not](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) | [Phase 19](phase_19_platform_backbone.md) (platform) → [Phase 22](phase_22_live_dsl_singleton.md) (app DSL) |
| The **five upstream operator charts** — Harbor, MetalLB, Envoy Gateway, cert-manager, Percona — *as charts* | vendored Helm charts in sibling prodbox | Operators are **generated as typed CRs**, and their binaries **baked into the base container**, not installed via operator charts: no-third-party-charts ≠ no-third-party-software; see [`manifest_generation_doctrine.md` §4 — no third-party charts ≠ no third-party software: operators are generated](../documents/engineering/manifest_generation_doctrine.md#4-no-third-party-charts--no-third-party-software-operators-are-generated) and [`image_build_doctrine.md` §7 — what amoebius bakes vs builds](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain) | [Phase 19](phase_19_platform_backbone.md) |
| **Harbor** itself (the registry) | sibling prodbox in-cluster Harbor + mirror-into-registry pipeline | Replaced by the single-binary **`distribution` (`registry:2`)** registry — itself a baked binary, no relational DB, no public-registry pulls; see [`image_build_doctrine.md` §2 — the single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster) and [`platform_services_doctrine.md` §3 — the registry, the single image source](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source) | [Phase 15](phase_15_base_image_registry.md) |
| **jitML Node.js-subprocess WebSocket** Pulsar transport | sibling jitML — the Node subprocess owning the WebSocket client (`JitML.*`) | Retired for the **native `amoebius-pulsar`** TCP binary-protocol client: one client, one wire, **no WebSockets**, no Node runtime; see [`pulsar_client_doctrine.md` §1 — one client, one wire, no WebSockets](../documents/engineering/pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets) and [`pulsar_client_doctrine.md` §8 — what this client replaces](../documents/engineering/pulsar_client_doctrine.md#8-what-this-client-replaces) | [Phase 24](phase_24_pulsar_client.md) (native client) → [Phase 34](phase_34_jitml_lift_cuda.md) (jitML cutover) |
| **infernix in-process WebSocket gateway** Pulsar transport | sibling `Infernix.Runtime.Pulsar` (WebSocket gateway, one-producer-per-publish, base64-in-JSON) | Same native-client replacement; infernix stops shipping its own transport and consumes `amoebius-pulsar`; see [`pulsar_client_doctrine.md` §8 — what this client replaces](../documents/engineering/pulsar_client_doctrine.md#8-what-this-client-replaces) | [Phase 24](phase_24_pulsar_client.md) (native client) → [Phase 33](phase_33_infernix_lift.md) (infernix cutover) |
| **infernix single-arch (amd64-only)** image publication | sibling infernix image-build pipeline | Replaced by **multi-arch (`amd64` + `arm64`) baked binaries** under one manifest list; see [`image_build_doctrine.md` §3 — buildx multi-arch, amd64 and arm64, one manifest list](../documents/engineering/image_build_doctrine.md#3-buildx-multi-arch--amd64-and-arm64-one-manifest-list) | [Phase 15](phase_15_base_image_registry.md) |
| **Per-substrate chart / image re-pins** | sibling prodbox substrate-aware version/image-ref pinning | Forbidden by **substrate equivalence**: one release/image-ref value across every substrate, with a build-time check that no code path re-pins conditionally on the active substrate; see [`platform_services_doctrine.md` §12 — substrate equivalence as a structural invariant](../documents/engineering/platform_services_doctrine.md#12-substrate-equivalence-as-a-structural-invariant). This bars per-substrate divergence of chart **versions** and **image refs** only; per-cluster **shape** divergence (single-node vs distributed) is permitted by [`service_capability_doctrine.md`](../documents/engineering/service_capability_doctrine.md) | [Phase 19](phase_19_platform_backbone.md) |

---

## Notes

- **"Removed" rarely means "deleted code."** For the three standalone products, the convergence retires their
  *product / packaging / transport identity*, not their domain logic. prodbox's control-plane behaviour,
  infernix's and jitML's ML logic (each with a demo web app) are **preserved as libraries** linked
  into the one amoebius binary; what disappears is the separate CLI, the separate image, and the separate
  release. This is why these rows are tracked here (the standalone artifact is slated) rather than as plain
  feature work.

- **Charts vs software (the Helm rows).** Dropping the five operator charts does **not** drop the five
  operators. Harbor is the one operator/service that is genuinely *replaced* (by `distribution`); MetalLB,
  Envoy Gateway, cert-manager, and Percona survive as **baked binaries with generated CRs**. Only the Helm
  *delivery mechanism* — the charts and the `helm` dependency — is removed. The distinction is the whole
  point of [`manifest_generation_doctrine.md` §4 — no third-party charts ≠ no third-party software](../documents/engineering/manifest_generation_doctrine.md#4-no-third-party-charts--no-third-party-software-operators-are-generated).

- **Why two phases on the transport rows.** The native `amoebius-pulsar` client lands in
  [Phase 24](phase_24_pulsar_client.md), but the sibling transports are only *deleted* when
  each library is migrated onto it — infernix's WebSocket gateway at [Phase 33](phase_33_infernix_lift.md)
  and jitML's Node-subprocess client at [Phase 34](phase_34_jitml_lift_cuda.md), one subsystem at a time
  behind reversible adapter seams. The "client-lands → library-cutover" pair is captured so neither half is
  marked Done prematurely.

- **The substrate-equivalence row is a standing prohibition, not a one-time deletion.** "Per-substrate
  re-pins" is removed in the structural sense that no amoebius code path is allowed to express one; the
  enforcing build-time check is itself a [Phase 19](phase_19_platform_backbone.md) deliverable,
  and the substrate catalog it ranges over is owned by [substrates.md](substrates.md). It belongs on this
  ledger because it forecloses a prodbox-era pattern (substrate-conditional image refs) by construction.

- **Sibling evidence, not amoebius proof.** Every justification above that points at prodbox / infernix /
  jitML behaviour is evidence from a sibling system. None of it is an amoebius result, because no amoebius
  phase has been built. Read each "Why slated" as design intent (the honesty rule,
  [development_plan_standards.md](development_plan_standards.md) §K).

- **No fractional phases, no forward dependencies.** Owning-phase assignments above respect the one-phase
  model and strict numeric order ([development_plan_standards.md](development_plan_standards.md) §E): every
  removal is pinned to an existing, contiguously-numbered phase, never to a fractional or later-than-its-cause
  id.

---

## Related Documents
- [README.md](README.md) — the live tracker: phase order, status, and gates that drive every owning-phase column
- [development_plan_standards.md](development_plan_standards.md) — the rulebook (status vocabulary §C, one-phase model §E, doctrine-citation §H, honesty §K) this ledger obeys
- [system_components.md](system_components.md) — the target amoebius modules that absorb or replace each slated artifact
- [substrates.md](substrates.md) — the substrate registry the substrate-equivalence row ranges over
- [phase_19_platform_backbone.md](phase_19_platform_backbone.md) — owns the no-Helm platform render, the baked operators, `distribution`, multi-arch, and the substrate-equivalence check
- [phase_24_pulsar_client.md](phase_24_pulsar_client.md) — owns the native `amoebius-pulsar` client that retires the WebSocket transports
- [`manifest_generation_doctrine.md`](../documents/engineering/manifest_generation_doctrine.md) — no-Helm rendering + generated operators
- [`image_build_doctrine.md`](../documents/engineering/image_build_doctrine.md) — baked binaries, `distribution`, multi-arch
- [`platform_services_doctrine.md`](../documents/engineering/platform_services_doctrine.md) — the registry and substrate-equivalence invariants
- [`pulsar_client_doctrine.md`](../documents/engineering/pulsar_client_doctrine.md) — the native client and what it replaces
- [`app_vs_deployment_doctrine.md`](../documents/engineering/app_vs_deployment_doctrine.md#6-the-proof-case-a-demo-web-app-as-application-logic-only) — infernix/jitML-as-library and their demo web apps as application-logic-only
- [`daemon_topology_doctrine.md`](../documents/engineering/daemon_topology_doctrine.md) — prodbox absorbed as the control-plane singleton
