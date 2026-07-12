# Phase 32: jit-build engine resolver + CacheBudget cache

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_08_capability_binder.md, DEVELOPMENT_PLAN/phase_15_base_image_registry.md, DEVELOPMENT_PLAN/phase_31_determinism_kernel.md, DEVELOPMENT_PLAN/phase_33_infernix_lift.md, DEVELOPMENT_PLAN/phase_34_jitml_lift_cuda.md, DEVELOPMENT_PLAN/phase_35_apple_metal_host_daemon.md
**Generated sections**: none

> **Purpose**: Prove on live linux-cpu that the shared jit-build resolver materializes a named `EngineRuntime`
> catalog identity on first miss into the `CacheBudget`-bounded content-addressed cache, that a second pod on the
> same host reuses the cache-resident copy, and that "more cached than fits" is decode-rejected by the capacity
> fold — engines jit-resolved into a bounded cache, never baked and never fetched by URL.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 31 gate (the
determinism kernel — the `ContentAddress` primitive and the content-addressed store the cache is keyed against)
and runs on the **linux-cpu** substrate in **Register 3** (live infrastructure): a single-node `kind` cluster
brought up by the Phase 14 midwife, whose base image (Phase 15) already bakes the shared **jit-build resolver
and its build toolchain** but **no** ML engine payload. Where a shape below is already exercised in a sibling
system — jitML's `Engines/Loader.hs` (the lazy per-kernel JIT: cache HIT → handle, MISS → compile-then-store)
is the shape this round generalizes to all three asset kinds, and infernix's `Runtime/Worker.hs` *selects* the
engine by `adapterType` and never fetches it — that is **sibling evidence, not an amoebius result**; infernix's
`docker/Dockerfile` `curl`-tar-at-image-build and its `model_cache.py` `minioadmin` fallback are the
baked/URL/second-secret-store anti-patterns this phase deliberately **replaces**, not inherits. Status
transitions are recorded reverse-chronologically here once work begins.

## Phase Summary

This phase delivers the first live amoebius realization of the ML-asset lifecycle's Tier 1 — the **engine** — as
one bounded, content-addressed, resolve-on-first-miss cache, and proves it against a minimal linux-cpu engine
identity. It does three things and stops there. First, it builds the **`CacheBudget`-bounded content-addressed
cache**: a bounded typed pool on the host, content-addressed by the resolved asset's SHA, carrying an explicit
`CacheBudget` (a `Quantity`) `≤` host storage, with pin-aware pruning — and the decode-time
`Σ(resident) ≤ CacheBudget` check is the *same* capacity fold Phase 7 built (`fits`/`carve`), so "more cached
than fits" is not a runtime disk-full but a decode rejection. Second, it builds the **jit-build resolver** —
`resolve = {download | build}` on first miss — that takes a named `EngineRuntime` catalog identity, returns a
handle on a cache HIT, and on a MISS downloads a prebuilt engine or builds it from source (using the Phase-14
baked toolchain) into the content-addressed cache; there is no arm to author a URL, because the identity is
drawn from the closed catalog, never authored. Third, it proves **host-level reuse**: the cache is host-scoped
and shared across pods, so a second pod on the same host that names the same identity hits the cache-resident
copy and pays no re-materialization — the first-miss cost is amortized across every later use.

The scope deliberately stops at the engine tier (Tier 1) and one live first-miss/reuse/over-budget proof. The
`ModelArtifact` staging tier (Tier 2) and the JIT kernel tier (Tier 3) are named as the same cache shape but are
not exercised here; the infernix CPU-inference lift that rides this resolver is [Phase 33](phase_33_infernix_lift.md),
and the CUDA/jitML lift is [Phase 34](phase_34_jitml_lift_cuda.md). The cache is **ephemeral and host-scoped** —
re-materializable on first miss, deliberately *not* the durable state of the stateless `replicas=1` control-plane
singleton (whose only durable state is the Vault-enveloped MinIO bucket); evicting the cache costs a
re-resolve, never data loss. The engine lane exercised here is `linux-cpu` only; the Apple-Metal and `Cuda`
lanes are out of contract for this gate.

```mermaid
flowchart LR
  dhall[EngineRuntime named catalog identity, substrate-selected] --> resolver[jit-build resolver]
  resolver -->|"cache HIT: return handle"| handle[Engine handle]
  resolver -->|"cache MISS: resolve = download or build"| cache[CacheBudget-bounded content-addressed cache]
  cache -->|"host-scoped: second pod reuses resident copy"| handle
  budget[CacheBudget Quantity ≤ host storage] -->|"Σ resident ≤ CacheBudget, Phase-7 fold"| cache
  overbudget[more cached than fits] -->|decode-rejected| reject[structured Left]
```

**Substrate:** linux-cpu — the whole gate runs on a single-node `kind` cluster on a linux-cpu host in Register 3;
no apple, linux-cuda, or windows substrate is touched, while the `Σ(resident) ≤ CacheBudget` decode rejection is
a pure fold that needs no live infrastructure (it is the Phase-7 fold applied to `CacheBudget`).

**Register:** 3 — live infrastructure; the first-miss materialization and the second-pod reuse run against real
pods on the live cluster, and the run emits a proven/tested/assumed ledger naming that register.

**Gate:** on the single-node linux-cpu `kind` cluster, the **one named representative identity**
`EngineRuntime.LlamaCppCpu@<pinned-ver>` (§25.0 concrete corpus) resolves on **first miss** into the
`CacheBudget`-bounded content-addressed cache (`resolve = {download | build}`, using the Phase-14 baked
resolver/toolchain, with **no** public-registry pull authored by URL), and the materialized bytes
**sha256-match the Phase-0-committed catalog pin** (`test/oracle/phase_32_oracle.dhall`: expected
`ContentAddress`, byte size, and `--version` string) — proving the named arm actually ran, not that a marker
blob was written: on the `build` arm the baked toolchain compiled the pinned source recipe (attested by an
`strace`/argv-shim record of the absolute-path `g++` invocation, §M.5), on the `download` arm the bytes were
served by the in-cluster `distribution` registry (attested by its access log), and the returned handle is
**live** (the resolved binary executes and reports the pinned `--version`). A **second pod on the same host**
that names the identity reuses the **cache-resident copy** with **no re-materialization**, proven by an
**OS-boundary observer** — the resident entry's inode/mtime is unchanged across the second lookup and the
registry access log and egress capture record **zero** new pull — never by a resolver-emitted counter. A cache
spec that would place **`Σ(declared-Quantity resident) > CacheBudget`** ("more cached than fits") is
**decode-rejected** by the Phase-7 capacity fold before any resolve runs, and each materialized artifact's
measured on-disk size is asserted `≤` its declared `Quantity` so a real resolve cannot silently bust the
budget. The gate turns **red** when the committed seeded mutant `resolve _ = <fixed-marker-bytes>` (identity
resolver, §M.2) is substituted — the sha256/version/arm-executed assertions fail — and when the `prune = pure
()` mutant is substituted (the pin-eviction assertion fails). The run emits a Register-3
proven/tested/assumed ledger recording first-miss resolution, cross-pod reuse, and pin-aware eviction as
*tested on linux-cpu*, the URL-foreclosure and `CacheBudget` shape as *proven-in-types*, and the
model/kernel tiers (Phases 26/27) and cross-host/cross-substrate reuse as **UNVERIFIED**.

## §25.0 Concrete corpus + Phase-0-pinned oracle (§M.1, §M.3, §M.7)

The gate's "representative set" is **exactly one** closed-catalog identity: `EngineRuntime.LlamaCppCpu@<pinned-ver>`
(a linux-cpu `llama.cpp` engine arm), exercised on **both** resolve arms — `build` (from the pinned source
recipe compiled by the baked toolchain) and `download` (the same bytes served by the in-cluster `distribution`
registry). Its oracle is **authored and committed in Phase 0, before `src/Amoebius/Jit/*` exists**, in
`test/oracle/phase_32_oracle.dhall`, a hand-authored table (independent of the SUT — never regenerated from the
resolver's own output, §M.3) carrying, per identity: the expected `ContentAddress` (`sha256` of the
materialized engine bytes), the expected on-disk byte `Quantity`, and the expected `--version` string the live
binary reports. The over-budget negative fixture, the pinned source recipe, and the compile-fail negative
(§25.1) are committed alongside it in the same Phase-0 pass. The committed seeded mutants the gate must turn red
(§M.2), drawn from the operator set: **(a)** `resolve _ = <fixed 16-byte marker>` (effect swap — the resolver
does no real work); **(b)** `prune = pure ()` (dropped effect — pruning is dead code); **(c)** an
identity-resolver whose stored bytes are one byte short of the pin (guard weakening). Each is committed under
`test/mutants/phase_32/` and re-run every gate, not hand-run once.

## Doctrine adopted

- [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)
  — *the ML-asset lifecycle: one bounded content-addressed cache, resolved on first miss*: the central adoption —
  Tier 1's `EngineRuntime` is a **named, jit-resolved** identity (never baked, never URL-fetched), the cache is a
  bounded typed pool with an explicit `CacheBudget` and pin-aware pruning, and the trade is stated plainly (baking
  gave no-network-at-boot; the cache pays a first-miss materialization amortized across every later use).
- [`service_capability_doctrine.md` §4.1](../documents/engineering/service_capability_doctrine.md)
  — *the `InferenceEngine` capability — the engine is substrate-selected and jit-resolved, never authored*: the
  closed `EngineRuntime` union has **no arbitrary-`Url`/`Download` arm**; the `.dhall` *selects* an arm by the
  detected substrate and can never *author* a fetch, and the shared jit-build resolver materializes the named
  identity on first miss — the engine-as-a-capability side this phase realizes at runtime.
- [`resource_capacity_doctrine.md §3`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)
  and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — *the `Quantity` types and the total `fits`/`carve` fold*: `CacheBudget` is a `Quantity` `≤` host storage, and
  the `Σ(resident) ≤ CacheBudget` bound is the **same** decode-foreclosed capacity fold Phase 7 built — "more
  cached than fits" is rejected by that fold, not discovered as a runtime disk-full.
- [`image_build_doctrine.md §7`](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain)
  — *what amoebius bakes vs builds*: the base image bakes the jit-build **resolver + toolchain** (the
  build-from-source path this phase drives on a MISS) but holds the ML **engine payloads** out as named cache
  identities — the Phase-14 split this phase exercises live for the first time.
- [`illegal_state_catalog.md §3.25`](../documents/illegal_state/illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model)
  — *an ML asset named by arbitrary URL is unrepresentable*: the foreclosure shifted from the old "no `Download`
  arm (baked)" to **"no arbitrary-URL arm (a closed named catalog) + a `CacheBudget`-bounded cache"** — the engine
  identity has no URL syntax (type-foreclosed, Gate 1) and the over-budget cache is decode-foreclosed (Gate 2).
- [`content_addressing_doctrine.md §2`](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers)
  — *the content-addressed store*: the cache keys resolved engine payloads by `sha256(bytes)` (the Phase-24
  `ContentAddress` primitive), so a MISS-then-store and a HIT are the write-once, self-naming discipline of the
  store, applied to the ephemeral host cache rather than the durable MinIO bucket.
- [`testing_doctrine.md` §2](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing)
  — *three registers of amoebius testing*: this phase's gate reaches **Register 3** (live infrastructure) and
  emits a proven/tested/assumed ledger naming that register, with the model/kernel tiers (26/27) marked deferred.

## Sprints

## Sprint 25.1: The `CacheBudget`-bounded content-addressed cache + the `Σ(resident) ≤ CacheBudget` decode fold 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Jit/Cache.hs` (the bounded typed pool — content-addressed by resolved-asset
SHA, pin-aware pruning, HIT/MISS lookup) and `src/Amoebius/Jit/CacheBudget.hs` (the `CacheBudget` as a
`Quantity` `≤` host storage + the `Σ(resident) ≤ CacheBudget` decode fold reusing `Amoebius.Capacity.Fold`) —
target paths, not yet built.
**Blocked by**: Phase 7 gate (the `fits`/`carve` capacity fold this bound reuses); Phase 31 gate (the
`ContentAddress` primitive the cache keys against); Phase 25 gate (the content-addressed store shape).
**Independent Validation**: a property + boundary suite shows the cache admits no key from a free string,
proven by a **committed compile-fail negative fixture** `test/negative/phase_32_freestring_key.hs` (registered
in the Phase-6 negative corpus, authored in Phase 0) whose expected failure is asserted **by locus** — it must
fail to typecheck at the attempt to construct a cache key from a `String`/`Text`/`Url` with the specific
"no instance / no exported constructor" compile error — paired with a positive that differs only in keying from
`sha256(real bytes)` and compiles. A QuickCheck property shows every resident entry is reachable only by hashing
real bytes and a lookup is a total HIT/MISS, with `cover`/`classify` obligations forcing **≥30% MISS** and
**≥30% HIT** cases (§M.4) so the generator does not emit one near-constant shape. The `Σ(resident) ≤ CacheBudget`
decode fold is exercised against the **Phase-0-committed** over-budget fixture: `Σ` is computed over the
declared catalog `Quantity`s (the fold runs *before any resolve*, on declared sizes); a resident set within
budget decodes, and a set summing over `CacheBudget` returns the structured `Left` whose **tag** is asserted
(the Phase-7 `fits` rejection tag, not merely "a `Left`"). The independent oracle for the fold is the committed
fixture's hand-authored expected verdict, not the fold's own output. No cluster required.
**Docs to update**: `documents/engineering/content_addressing_doctrine.md`,
`documents/engineering/resource_capacity_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)'s
bounded-typed-pool and [`resource_capacity_doctrine.md §3/§4`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget):
build the `CacheBudget`-bounded content-addressed cache so that "more cached than fits" is **unrepresentable** —
the same decode-foreclosed capacity fold that bounds every other budget rejects a `Σ(resident) > CacheBudget`
before the resolver ever materializes an asset.

### Deliverables
- `Amoebius.Jit.Cache` — a bounded typed pool keyed by `sha256(resolved-bytes)` (the Phase-24 `ContentAddress`),
  with a total HIT/MISS lookup and pin-aware pruning (a pinned resident is never evicted; unpinned residents are
  pruned to keep under budget).
- `CacheBudget` as a `Quantity` `≤` host storage, and the `Σ(resident) ≤ CacheBudget` decode fold delegating to
  `Amoebius.Capacity.Fold` — an over-budget cache spec returns the tagged `Left`, not a runtime disk-full.
- An in-file honesty note: the cache is **ephemeral and host-scoped**, not the singleton's durable state; the
  `CacheBudget ≤ host storage` shape is type/decode-foreclosed, while *actual* on-disk residency under
  concurrent resolves is the runtime residue deferred to the live gate.

### Validation
1. There is no exported path to a cache key from a free string; the only path to a resident entry is content
   addressing — asserted by the committed compile-fail negative `test/negative/phase_32_freestring_key.hs`
   (Phase-6 corpus, Phase-0-authored) failing *at the key-construction locus* with the "no exported
   constructor" error, paired with the sha256-keyed positive that compiles.
2. A resident set within budget decodes; a set whose declared-`Quantity` residents sum over `CacheBudget`
   returns the **tagged** `Left` (the Phase-7 `fits` rejection tag) at the fold, run before any resolve. The
   committed seeded mutant `prune = pure ()` (§25.0-b) turns this suite's pin-eviction property (see 25.3)
   red; the fold's expected verdict is the Phase-0 fixture's hand-authored table, never the fold's own output.
3. **Pin-aware pruning is exercised, not declared:** a cache filled to `CacheBudget` with a mix of pinned and
   unpinned residents, then asked to admit one more resident, **evicts an unpinned resident, never a pinned
   one**, and leaves `Σ(resident) ≤ CacheBudget`; the property asserts a pinned resident is present and a
   named unpinned resident is absent post-prune. The committed seeded mutant `prune = pure ()` (§25.0-b) must
   turn this clause red (the over-budget residency survives). This is the pure-pool property; its live on-disk
   counterpart is the 25.4 postflight residency measurement.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 25.2: The jit-build resolver — `resolve = {download | build}` on first miss, no URL arm 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Jit/Resolver.hs` (the shared resolver: a named `EngineRuntime` catalog
identity → cache HIT → handle, or MISS → download-a-prebuilt-engine / build-from-source → store → handle) —
target path, not yet built.
**Blocked by**: Sprint 25.1 (the cache the resolver stores into); Phase 15 gate (the base image baking the
resolver + its build toolchain — `g++` / pinned compilers for the linux-cpu build path); Phase 8 gate (the
`InferenceEngine` binder + the closed, substrate-selected `EngineRuntime` union the resolver keys on).
**Independent Validation**: a boundary suite drives the resolver against a Phase-0-committed backend fixture
whose served/compiled bytes **sha256-match the `test/oracle/phase_32_oracle.dhall` pin** — not an arbitrary
"fake" blob: a backend returning unpinned bytes must fail the suite, foreclosing a resolver that stores fixed
marker bytes. A cold cache triggers exactly one `resolve` (download-or-build) then stores, and the stored
`ContentAddress` **equals the committed pin**. A warm cache returns a handle with **no** resolve, proven by an
argv-recording shim / `strace` observer at the OS boundary (§M.5) capturing **zero** toolchain-or-backend
subprocess on the warm path — never inferred from a resolver-emitted counter. The resolver has no code path
that accepts a free URL, proven by the committed compile-fail negative `test/negative/phase_32_url_arm.hs`
(Phase-6 corpus, Phase-0-authored) failing *at the constructor locus* with "no `Url`/free-string constructor",
paired with a closed-catalog-identity positive that compiles. Every subprocess is absolute-path-resolved,
asserted by the shim capturing the full absolute `argv[0]` (never a bare `PATH`-relative name). The committed
seeded mutant `resolve _ = <fixed 16-byte marker>` (§25.0-a) turns the stored-`ContentAddress` assertion red.
**Docs to update**: `documents/engineering/content_addressing_doctrine.md`,
`documents/engineering/service_capability_doctrine.md`, `documents/engineering/image_build_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)'s
Tier-1 resolve-on-miss and [`service_capability_doctrine.md` §4.1](../documents/engineering/service_capability_doctrine.md):
implement the shared jit-build resolver so a named engine identity is materialized on first miss into the
bounded cache — downloaded prebuilt or built from source with the Phase-14 baked toolchain — with **no arm to
author a URL**, replacing infernix's `curl`-tar-at-image-build with the one shared resolve-on-miss path.

### Deliverables
- `Amoebius.Jit.Resolver` — `resolve :: EngineRuntime -> IO EngineHandle` that returns a handle on a cache HIT
  and, on a MISS, runs `download | build` (the recipe carried by the closed-catalog identity, never an authored
  URL), stores the result content-addressed into `Amoebius.Jit.Cache`, then returns the handle.
- The build-from-source path invoking the Phase-14 baked toolchain by absolute path (no `PATH`, no env), and the
  download path resolving a named prebuilt identity — neither exposing a free-URL or free-string constructor.
- An in-file honesty note: URL-foreclosure and identity-from-closed-catalog are **proven-in-types** (Gate 1); the
  first-miss materialization *succeeding* on real infrastructure is the live residue proven at the phase gate; the
  model (Tier 2) and kernel (Tier 3) tiers reuse this resolver but land in Phases 26/27.

### Validation
1. A cold cache triggers exactly one `resolve` and stores the result, **and the stored `ContentAddress`
   equals the `test/oracle/phase_32_oracle.dhall` pin**; a warm cache returns a handle with no resolve,
   proven by the argv-shim/`strace` observer recording zero backend subprocess on the warm path; there is no
   path that accepts a URL or free string, asserted by the committed compile-fail negative
   `test/negative/phase_32_url_arm.hs` failing at the constructor locus with its named error, paired with the
   closed-catalog positive that compiles. The committed seeded mutant `resolve _ = <fixed-marker>` (§25.0-a)
   must turn the stored-address assertion red.
2. Every subprocess the resolver spawns is invoked by absolute path, never resolved against `PATH` — asserted
   by an OS-boundary argv-recording shim capturing the full absolute `argv[0]`, not a resolver self-report.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 25.3: Host-scoped cache-resident reuse across pods 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Jit/HostCache.hs` (the host-scoped shared cache mount + the concurrency
discipline that makes a second pod's lookup a HIT against the first pod's resolved copy) — target path, not yet
built.
**Blocked by**: Sprint 25.1, Sprint 25.2; Phase 16 gate (the typed SSA reconciler that renders the pods sharing
the host cache); Phase 19 gate (the platform stack the pods schedule onto).
**Independent Validation**: on the live single-node `kind` cluster, two pods scheduled to the same host name the
same `EngineRuntime` identity; the **first** pod's `resolve` is a MISS that materializes into the shared host
cache (stored bytes sha256-matching the `test/oracle/phase_32_oracle.dhall` pin), the **second** pod's lookup
is a **HIT** that reuses the resident copy with **no re-materialization** — proven by an **OS-boundary
observer**, not a resolver counter: the resident entry's inode and mtime are unchanged across the second
lookup, and the in-cluster `distribution` registry access log plus an egress capture record **zero** new pull
or build subprocess for the second pod. The concurrent-first-miss race is **operationalized** so the two writes
provably overlap: both pods block on a shared barrier (a rendezvous file/lease) and materialization is
deliberately slowed (a payload-size floor or an injected delay in the fixture backend) so **both provably
observe MISS before either store commits** — then the suite asserts exactly one final resident entry, that its
bytes hash to the catalog pin, and that **no partial/temp file remains** in the cache directory. A race that
never overlaps (serialized by accident) does not satisfy this clause.
**Docs to update**: `documents/engineering/content_addressing_doctrine.md`,
`documents/engineering/daemon_topology_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)'s
"every later pod on that host reuses the cache-resident copy": make the bounded cache **host-scoped and shared**,
so the first-miss materialization cost is paid once per host per identity and amortized across every pod that
later names it — the amortization the whole resolve-on-miss trade is premised on.

### Deliverables
- `Amoebius.Jit.HostCache` — the host-scoped shared cache location and the read/write discipline that lets a
  second pod HIT the first pod's resident copy, with two concurrent first-misses converging to one stored,
  content-addressed copy (idempotent write-once, the store's confluence applied to the ephemeral cache).
- The pod wiring (rendered by the Phase-15 reconciler) that mounts the shared host cache into each engine pod
  and keeps the cache host-scoped, not per-pod.
- An in-file honesty note: cross-pod reuse and the idempotent concurrent-miss convergence are **tested on
  linux-cpu** at the gate; cross-host reuse is out of contract (the cache is host-scoped by design — a different
  host is a legitimate first miss).

### Validation
1. Pod A's first `resolve` is a MISS that materializes bytes hashing to the catalog pin; Pod B on the same host
   HITs the resident copy with no re-materialization, proven by the OS-boundary observer — unchanged resident
   inode/mtime and zero new registry pull / build subprocess for Pod B — never by a resolver-emitted counter.
2. Two concurrent first-misses, **forced to overlap by a shared barrier and slowed materialization so both
   observe MISS before either commits**, converge to exactly one stored copy whose bytes hash to the catalog
   pin; no partial/temp file remains and no torn or duplicate resident entry exists.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 25.4: The live first-miss / reuse / over-budget gate + Register-3 ledger 📋

**Status**: Planned
**Implementation**: `test/dhall/phase_32_engine_cache.dhall` (the gate workflow naming a linux-cpu engine
identity) and `test/live/EngineCacheGate.hs` (the Register-3 gate harness) — target paths, not yet built.
**Blocked by**: Sprint 25.1, Sprint 25.2, Sprint 25.3; Phase 14 gate (the live `kind` cluster + substrate
detect); Phase 15 gate (the baked resolver/toolchain and the in-cluster `distribution` registry proving no
public pull).
**Independent Validation**: the gate `.dhall` names the one representative identity
`EngineRuntime.LlamaCppCpu@<pinned-ver>` (§25.0); the harness asserts the first pod's resolve is a first-miss
materialization into the `CacheBudget`-bounded cache whose stored bytes **sha256-match the
`test/oracle/phase_32_oracle.dhall` pin**, the named arm **actually executed** (the argv-shim/`strace`
observer recorded the absolute-path `g++` compile on the `build` arm, or the `distribution` registry access log
recorded the in-cluster serve on the `download` arm), and the returned handle is **live** (the binary runs and
reports the pinned `--version`). "**Zero public-registry pull authored by URL**" is discharged by **live
network observation** (a CNI/egress capture plus the `distribution` audit log showing no request to any public
registry host), **in addition to** the Gate-1 type-level foreclosure — the type check alone does not satisfy
this clause. A second pod on the same host reuses the cache-resident copy with the reuse proven by the
OS-boundary observer (unchanged resident inode/mtime, zero new pull for the second pod). A **postflight on-disk
residency measurement** confirms pin-aware eviction: with the cache filled to budget, a pinned resident
survives and an unpinned resident is evicted, and the measured `Σ(on-disk bytes) ≤ CacheBudget` (measured on
disk, not self-reported). An over-budget cache spec is **decode-rejected** by the Phase-7 fold before any
resolve, and each materialized artifact's measured on-disk size is asserted `≤` its declared `Quantity`. The
committed seeded mutants `resolve _ = <fixed-marker>` (§25.0-a) and `prune = pure ()` (§25.0-b) must turn the
gate red. The run emits a Register-3 proven/tested/assumed ledger.
**Docs to update**: `documents/engineering/content_addressing_doctrine.md`, `DEVELOPMENT_PLAN/README.md`
(flip the Phase-25 status when the gate passes), `DEVELOPMENT_PLAN/substrates.md`.

### Objective
Adopt [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)
end-to-end under [`testing_doctrine.md` §2 — Register 3](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing):
wire the resolver, the bounded cache, and host-scoped reuse through one live linux-cpu workload and prove the
three-clause gate — first-miss resolution, second-pod reuse, and the decode-rejected over-budget spec — without
overclaiming the model/kernel tiers (Phases 26/27).

### Deliverables
- The gate `.dhall` naming exactly the one representative identity `EngineRuntime.LlamaCppCpu@<pinned-ver>`
  (§25.0 concrete corpus), driving a first pod, a second pod on the same host, and the Phase-0-committed
  over-budget `CacheBudget` fixture.
- The Phase-0-committed oracle `test/oracle/phase_32_oracle.dhall` (expected `ContentAddress`, byte `Quantity`,
  `--version`) and the committed seeded mutants under `test/mutants/phase_32/` (`resolve _ = <marker>`,
  `prune = pure ()`, one-byte-short store), authored before `src/Amoebius/Jit/*` exists.
- The gate harness asserting: (i) first-miss materialization whose stored bytes sha256-match the committed pin,
  the named arm actually ran (OS-boundary argv-shim/`strace` or registry audit log), the handle is live
  (reports the pinned `--version`), and **zero public-registry pull** by live egress/CNI capture plus the
  `distribution` audit log; (ii) a second-pod cache HIT with no re-materialization, proven by unchanged resident
  inode/mtime and zero new pull for the second pod; (iii) a postflight on-disk residency measurement showing the
  pinned resident survived, the unpinned resident was evicted, and measured `Σ(on-disk) ≤ CacheBudget`; (iv) the
  over-budget spec's **tagged** decode `Left` at the Phase-7 fold, with each artifact's measured size `≤` its
  declared `Quantity`. The gate must turn red under the committed mutants.
- A Register-3 ledger recording: URL-foreclosure and the `CacheBudget` shape as **proven-in-types**, first-miss
  resolution and cross-pod reuse as **tested on linux-cpu**, and the Tier-2 model / Tier-3 kernel reuse as
  **deferred** (Phases 26/27), with cross-host and cross-substrate reuse explicitly not asserted.

### Validation
1. On the live linux-cpu `kind` cluster, the first pod resolves `EngineRuntime.LlamaCppCpu@<pinned-ver>` on
   first miss into the cache, the stored bytes sha256-match the committed `test/oracle/phase_32_oracle.dhall`
   pin, the named arm actually ran (attested by the OS-boundary argv-shim/`strace` on `build` or the
   `distribution` audit log on `download`), and the handle is live (reports the pinned `--version`); "zero
   public-registry pull" is proven by live egress/CNI capture and the registry audit log, not by the type check
   alone. A second pod on the host reuses the resident copy with no resolve, proven by unchanged resident
   inode/mtime and zero new pull for the second pod. The committed seeded mutant `resolve _ = <marker>`
   (§25.0-a) must turn this clause red.
2. A postflight on-disk residency measurement confirms pin-aware eviction (pinned resident survives, unpinned
   evicted, measured `Σ(on-disk) ≤ CacheBudget`); the committed mutant `prune = pure ()` (§25.0-b) must turn
   this red. An over-budget cache spec returns the **tagged** `Left` at the Phase-7 fold before any resolve
   runs, and each materialized artifact's measured on-disk size is `≤` its declared `Quantity`.
3. The Register-3 ledger is emitted and marks first-miss resolution, cross-pod reuse, and pin-aware eviction as
   *tested on linux-cpu*, URL-foreclosure and the `CacheBudget` shape as *proven-in-types*, and the
   model/kernel tiers (Phases 26/27) and cross-host/cross-substrate reuse as **UNVERIFIED**.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/content_addressing_doctrine.md` — §4.5's Tier-1 engine cache gains its first amoebius
  live datapoint (first-miss resolve + host-scoped reuse on linux-cpu) alongside the existing jitML/infernix
  sibling-evidence rows; annotate that the bounded-cache resolve-on-miss path replaces infernix's
  `curl`-tar-at-image-build, and that the Tier-2/Tier-3 realizations remain Phase 33/27 targets.
- `documents/engineering/service_capability_doctrine.md` — annotate §4.1 that the `EngineRuntime`
  substrate-selected, no-URL provider is first resolved live here; the alternate lanes (Apple-Metal, `Cuda`)
  stay design intent.
- `documents/engineering/resource_capacity_doctrine.md` — record that the §3/§4 `Quantity`/`fits` fold is reused
  as the `Σ(resident) ≤ CacheBudget` bound, keeping "more cached than fits" a decode-foreclosed check.
- `documents/engineering/image_build_doctrine.md` — the §7 bake-vs-build split (resolver/toolchain baked, engine
  payloads not) gains its first live exercise: the resolver's build-from-source path runs against the baked
  toolchain.
- `documents/illegal_state/illegal_state_catalog.md` — annotate §3.25 that the URL-foreclosure holds live and the
  over-budget-cache rejection reached its decode-foreclosed layer on linux-cpu.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-25 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 32's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Jit/Cache.hs`,
  `src/Amoebius/Jit/CacheBudget.hs`, `src/Amoebius/Jit/Resolver.hs`, `src/Amoebius/Jit/HostCache.hs`, the
  `EngineCacheGate` live suite, and the Phase-0-committed oracle/negative/mutant artifacts
  (`test/oracle/phase_32_oracle.dhall`, `test/negative/phase_32_freestring_key.hs`,
  `test/negative/phase_32_url_arm.hs`, `test/mutants/phase_32/`) as Phase-25 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase ordering this document sits under
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and the cross-cutting invariant that ML engines are
  jit-resolved into a bounded cache, never baked or URL-fetched
- [system_components.md](system_components.md) — the target component inventory for the `Amoebius.Jit.*` module paths above
- [Content Addressing & Determinism Doctrine](../documents/engineering/content_addressing_doctrine.md) — §4.5 the
  ML-asset lifecycle (Tier-1 engine cache) and §2 the content-addressed store this cache reuses
- [Service Capabilities Doctrine](../documents/engineering/service_capability_doctrine.md) — §4.1 the
  `InferenceEngine` capability whose provider is substrate-selected and jit-resolved, never authored
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — §3/§4 the `Quantity`
  types and the `fits`/`carve` fold reused as the `Σ(resident) ≤ CacheBudget` bound
- [Image Build & Registry Doctrine](../documents/engineering/image_build_doctrine.md) — §7 the base image bakes
  the resolver + toolchain but not the engine payloads
- [Illegal-State Catalog](../documents/illegal_state/illegal_state_catalog.md) — §3.25 an ML asset named by
  arbitrary URL (and an over-budget cache) made unrepresentable
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 the three registers (Register 3 reached here)
- [phase_15](phase_15_base_image_registry.md) — the base image that bakes the jit-build resolver + toolchain this phase drives live
- [phase_31](phase_31_determinism_kernel.md) — the determinism kernel + `ContentAddress` primitive the cache keys against
- [phase_33](phase_33_infernix_lift.md) — the infernix CPU-inference lift that rides this resolver next
- [phase_34](phase_34_jitml_lift_cuda.md) — the jitML/CUDA lift whose kernel tier reuses this resolver
