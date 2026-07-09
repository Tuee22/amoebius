# Phase 1: Toolchain spike

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, overview.md, phase_02_formal_model_kernel.md
**Generated sections**: none

> **Purpose**: Prove — before any later phase promises an executable decoder, simulator, or resolver — that
> the pre-cluster Haskell surface builds on the pinned toolchain, or record the exact remediation or blocker.

---

## Phase Status

📋 Planned. Every sprint below is 📋 Planned and every prescriptive statement is design intent, never a tested
amoebius result. This phase opens after the Phase 0 documentation lint passes and runs on **no substrate**
(`none`): it stands up no host and no cluster, resolving and building only Hackage packages on the developer
toolchain. It is a de-risking pre-flight for the whole pre-cluster band (Phases 2–12), whose in-process
integrity checks all rest on the dependencies probed here.

## Phase Summary

This phase settles a single buildability question at the front of the plan so that no later phase discovers,
mid-implementation, that its load-bearing library does not compile on the shared pin. The pre-cluster band has
exactly three third-party Haskell risks: the in-process `dhall` decoder that Gate 2 rests on, the
`io-sim`/`io-classes` scheduler that amoebius's one formal obligation (the gateway-migration `Model`) is
simulated against, and the shared `jit-build` resolver's own dependencies. `dhall` in particular historically
lags new GHC releases — it pulls `template-haskell`, `aeson`, `megaparsec`, and `prettyprinter` — so
`allow-newer` alone may be insufficient and a source patch or fork may be required. This phase stands up a
throwaway probe package that depends on all three, resolves them against one shared `index-state`, and either
builds clean or records the precise `allow-newer`/patch/fork set. The TLA+/TLC side (`tla2tools.jar`, pure JVM,
version-stable) is independent of the GHC pin and is not gated here.

The whole check is a pure Register-1 in-process battery, analogous to the Phase-0 documentation lint: it
touches no live infrastructure and produces nothing durable — the probe is deleted once its resolution is
recorded. That the `Model`→{`interpret`, `emitTLA`} mechanism and the pure-suite discipline have already been
exercised end to end is **sibling evidence** (a removed formal-model spike; prodbox's ~940-behaviour pure
suite), not an amoebius result.

**Substrate:** `none` — no host, no cluster; the gate resolves and compiles Hackage packages on the developer
toolchain only.

**Gate:** a single throwaway probe package that build-depends on `dhall`, `io-sim`, and `io-classes` **and**
the `jit-build` resolver's Haskell dependencies compiles and links under **GHC 9.12.4 / Cabal 3.16.1.0** with
a green `cabal build`; **or** the exact `allow-newer` set, source patch, fork/pin, or hard blocker that the
build requires is recorded in the tracker's Toolchain section (Register 1).

## Doctrine adopted

- [`conformance_harness_doctrine.md §2 — the registers`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
  and its §3 load-bearing invariant that **rendering never touches live infrastructure**: this phase is a pure
  Register-1 check ([three-register definitions](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing)),
  building and running in-process with no cluster, no credentials, and no broker.
- [`dsl_doctrine.md §9 — Toolchain note`](../documents/engineering/dsl_doctrine.md#9-toolchain-note), read
  with [§5's Gate 2](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  the in-process `dhall` decoder — the whole "if it decodes, it is deployable" claim — needs `allow-newer`
  against the pinned GHC; this phase is where that exact set is proven or the blocker recorded, before any
  later phase promises an executable Gate 2.
- [`gateway_migration_model_doctrine.md §4 — Simulate and prove`](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove):
  amoebius's **one** formal obligation drives the gateway-migration `Model` (both `Planned` and `Failover`
  branches) against `io-classes`/`IOSimPOR`'s deterministic scheduler; this phase de-risks that build
  dependency, while the version-stable JVM TLC half stays unaffected by the GHC pin.
- [`formal_model_doctrine.md §7 — Prototype validation`](../documents/engineering/formal_model_doctrine.md#7-prototype-validation):
  the reifiable-`Model` mechanism — one value rendering both `interpret` (runtime) and `emitTLA` (a generated,
  never-committed `.tla`) — was prototyped in a throwaway spike; that is **sibling evidence, not an amoebius
  result**, and its Haskell side must build on the pin before Phase 2 authors it.
- [`content_addressing_doctrine.md §4.5 — the ML-asset lifecycle`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
  ML engines/models/kernels are never baked or URL-fetched — the shared `jit-build` resolver materializes each
  **named catalog identity** on first miss into a `CacheBudget`-bounded content-addressed cache; the resolver's
  own Haskell dependencies are folded into this probe.

## Sprints

## Sprint 1.1: Shared toolchain pin + `cabal.project` skeleton 📋

**Status**: Planned
**Implementation**: `cabal.project`, `cabal.project.freeze` — target paths, not yet built.
**Blocked by**: Phase 0 gate.
**Independent Validation**: `cabal build` of a trivial library succeeds on **GHC 9.12.4 / Cabal 3.16.1.0**; the
compiler and a frozen Hackage `index-state` are captured in one shared project file.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (Toolchain — the shared pin), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt the shared-pin discipline recorded in the tracker's Toolchain note — one **GHC 9.12.4 / Cabal 3.16.1.0**
pin across every package, and a single `index-state` that fixes the Hackage snapshot — so every later sprint in
this phase resolves against one dependency universe rather than a drifting one.

### Deliverables
- A `cabal.project` naming the compiler and freezing an `index-state`, plus a trivial library that compiles
  clean against a stock package set — the baseline, with **no** `allow-newer` yet.

### Validation
1. `cabal build` is green on the pin with a stock package set; the `index-state` is committed as the shared
   snapshot.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 1.2: `dhall` in-process decoder build probe (Gate-2 dependency) 📋

**Status**: Planned
**Implementation**: `probe/probe.cabal` (a `dhall` build-depends), `probe/app/Decode.hs` (decode a trivial
`.dhall` in-process) — target paths, not yet built.
**Blocked by**: Sprint 1.1.
**Independent Validation**: a probe depending on `dhall` builds under the pin and decodes a trivial expression
in-process; the exact `allow-newer`/source-patch/fork required by `dhall`'s transitive deps
(`template-haskell`, `aeson`, `megaparsec`, `prettyprinter`) is recorded, or the blocker is.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (the `allow-newer` set), `documents/engineering/dsl_doctrine.md` (§9 backlink).

### Objective
Adopt [`dsl_doctrine.md §9 — Toolchain note`](../documents/engineering/dsl_doctrine.md#9-toolchain-note) with
its [§5 Gate 2](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract): prove
the in-process `dhall` decoder — the entire "if it decodes, it is deployable" Gate-2 claim — is buildable on
the pin before Phase 5 promises an executable decoder. `dhall` historically lags new GHC releases, so
`allow-newer` alone may be insufficient and a source patch or fork may be required.

### Deliverables
- A recorded resolution: the concrete `allow-newer`/patch/fork/pin that makes `dhall` build on GHC 9.12.4,
  **or** a recorded blocker.

### Validation
1. The probe builds and round-trips a trivial `dhall` decode in-process, **or** the exact remediation/blocker
   is recorded.

### Remaining Work
The whole sprint (📋 Planned). **If it fails:** every Gate-2-dependent phase (5+) is blocked and the blocker is
recorded here; the JVM-only TLC path (Phases 2/3) is unaffected.

## Sprint 1.3: `io-sim` + `io-classes` simulation build probe 📋

**Status**: Planned
**Implementation**: extend `probe/probe.cabal` (`io-sim`, `io-classes` build-depends), `probe/app/Sim.hs` (a
trivial `IOSimPOR` run) — target paths, not yet built.
**Blocked by**: Sprint 1.1.
**Independent Validation**: a probe depending on `io-sim`/`io-classes` builds under the pin and runs a trivial
deterministic schedule; the exact `allow-newer`/pin is recorded, or the blocker is.
**Docs to update**: `DEVELOPMENT_PLAN/README.md`, `documents/engineering/gateway_migration_model_doctrine.md`
(§4 backlink), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`gateway_migration_model_doctrine.md §4 — Simulate and prove`](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove):
amoebius's one formal obligation drives the gateway-migration `Model` against `io-classes`/`IOSimPOR`'s
deterministic, partial-order-reduced scheduler. Prove that toolchain builds on the pin before Phase 3 authors
the simulation. TLC (`tla2tools.jar`) is pure JVM and version-stable, so the Phase-2/3 TLC path is **not** gated
by this probe.

### Deliverables
- A recorded resolution for `io-sim` + `io-classes` on the pin, **or** a recorded blocker.

### Validation
1. The probe builds and runs a trivial `IOSimPOR` schedule, **or** the exact remediation/blocker is recorded.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 1.4: jit-build resolver deps + consolidated probe gate 📋

**Status**: Planned
**Implementation**: extend `probe/probe.cabal` (the `jit-build` resolver's Haskell deps — content-hashing,
download-or-build, process control) and a single `probe` executable linking `dhall` + `io-sim` + `io-classes`
+ resolver deps; the recorded-resolution ledger in `DEVELOPMENT_PLAN/README.md` — target paths, not yet built.
**Blocked by**: Sprint 1.2, Sprint 1.3.
**Independent Validation**: one probe package depending on `dhall`, `io-sim`, `io-classes`, **and** the
jit-build resolver deps builds and links under GHC 9.12.4 / Cabal 3.16.1.0; the consolidated
`allow-newer`/patch/fork set (or the exact blocker) is recorded in the tracker's Toolchain section.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (Toolchain — the consolidated pin/`allow-newer` set),
`documents/engineering/content_addressing_doctrine.md` (§4.5 resolver-deps backlink),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`content_addressing_doctrine.md §4.5 — the ML-asset lifecycle`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
the shared `jit-build` resolver that materializes named catalog identities into the `CacheBudget`-bounded
content-addressed cache carries its own Haskell dependencies. Fold them into one probe that also links `dhall`
+ `io-sim` + `io-classes`, so the whole pre-cluster in-process surface is proven buildable as **one**
dependency universe — the phase gate.

### Deliverables
- The consolidated throwaway probe executable, and the recorded-resolution ledger (the `allow-newer`/patch/fork
  set, or the hard blocker) in the tracker's Toolchain section.

### Validation
1. `cabal build` of the consolidated probe is green on the pin, **or** the exact remediation/blocker is
   recorded — the Phase-1 acceptance condition.

### Remaining Work
The whole sprint (📋 Planned). This is a throwaway probe: it is deleted once the resolution is recorded, exactly
like the removed formal-model spike; nothing here is a durable amoebius module.

## Documentation Requirements

**Engineering docs to update:**
- `documents/engineering/dsl_doctrine.md` — §9's Toolchain note gets a backlink to the recorded `dhall`
  `allow-newer`/patch set once Sprint 1.2/1.4 lands.
- `documents/engineering/gateway_migration_model_doctrine.md` — §4's io-sim instrument gets a backlink to the
  proven `io-sim`/`io-classes` build.
- `documents/engineering/content_addressing_doctrine.md` — §4.5's `jit-build` resolver gets a backlink to the
  proven resolver-deps build.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — the Toolchain section records the consolidated `allow-newer`/patch/fork set
  (or the blocker); flip the Phase 1 status when the gate passes.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-1 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `cabal.project` and the throwaway `probe/` package as
  Phase-1 pre-flight rows, marked deleted-after-resolution.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves; the sole home of the
  recorded Toolchain `allow-newer`/pin set.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  Register-1 honesty token: a green build is a buildability result, never a runtime claim).
- [overview.md](overview.md) — target architecture and the GHC 9.12.4 / Cabal 3.16.1.0 toolchain pin.
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — the Register-1
  pre-cluster spine and the rendering-never-touches-live-infrastructure invariant.
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — the in-process `dhall` decoder (Gate 2) and the
  Toolchain note this probe de-risks.
- [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) — the one
  formal obligation whose io-sim simulation depends on this build.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — the `Model`→{`interpret`,
  `emitTLA`} mechanism whose spike is sibling evidence, not an amoebius result.
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md) — the `jit-build`
  resolver and the `CacheBudget`-bounded cache whose deps this probe includes.
</content>
</invoke>
