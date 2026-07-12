# Phase 1: Toolchain spike

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md
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

This phase settles the buildability questions at the front of the plan so that no later phase discovers,
mid-implementation, that its load-bearing library does not compile on the shared pin. The load-bearing
third-party Haskell risks are: the in-process `dhall` decoder that Gate 2 rests on; the `io-sim`/`io-classes`
scheduler that amoebius's one formal obligation (the gateway-migration `Model`) is simulated against; the shared
`jit-build` resolver's own dependencies; and — de-risked here rather than discovered later — the
`purescript-bridge` contract generator that the SPA-composition phase depends on, and the native Pulsar client's
`supernova` fork plus its `proto-lens` codegen that the Pulsar-client phase depends on. `dhall` in particular
historically lags new GHC releases — it pulls `template-haskell`, `aeson`, `megaparsec`, and `prettyprinter` —
so `allow-newer` alone may be insufficient and a source patch or fork may be required. This phase stands up a
throwaway probe package that depends on all of them, resolves them against one shared `index-state`, and either
builds clean or records the precise `allow-newer`/patch/fork set. The TLA+/TLC side is a JVM toolchain, not a
GHC-pin risk: a **pinned `tla2tools.jar` version and a JRE floor are recorded in the tracker's Toolchain
section** and located by the Phase-2/3 harness, so the Phase-2/3 TLC path has a named, version-pinned
acquisition path even though its buildability is not gated by this GHC probe.

The whole check is a pure Register-1 in-process battery, analogous to the Phase-0 documentation lint: it
touches no live infrastructure and produces no durable amoebius *module* — the probe package is deleted once
its resolution is recorded, but its evidence (the `cabal.project` + freeze file, the `cabal build`/`cabal run`
transcripts, the committed fixtures, and the seeded mutant) is retained under `DEVELOPMENT_PLAN/evidence/phase_01/`
until Phase 5 supersedes it, so the gate is closed by artifacts, never by tracker prose alone. That the `Model`→{`interpret`, `emitTLA`} mechanism and the pure-suite discipline have already been
exercised end to end is **sibling evidence** (a removed formal-model spike; prodbox's ~940-behaviour pure
suite), not an amoebius result.

**Substrate:** `none` — no host, no cluster; the gate resolves and compiles Hackage packages on the developer
toolchain only.

**Register:** 1 — pure/build, in-process, no cluster (§K).

**Gate:** a single throwaway probe package that build-depends on `dhall`, `io-sim`, `io-classes`, **and** the
enumerated `jit-build` resolver Haskell dependencies (the concrete Hackage list fixed under "Representative set"
below — the probe's `build-depends` stanza must match that list exactly, not a category or a subset already in
the stock closure) compiles and links under **GHC 9.12.4 / Cabal 3.16.1.0** from a clean package store
(`cabal build` run after `rm -rf dist-newstyle` and against a `--store-dir` that holds none of the probed
packages, so a stale store hit cannot mask an unbuildable config), **and** the two committed executable probes
run green: `cabal run probe:decode` in-process decodes the Phase-0-committed positive fixture
`probe/fixtures/ok.dhall` into its committed expected Haskell value and exits 0, and `cabal run probe:sim`
completes the named `IOSimPOR` schedule and exits 0. Evidence, not prose, closes the gate: the green outcome
counts only with the retained `cabal build`/`cabal run` transcripts that echo `ghc --version` and
`cabal --version` in-band and show the shell-observed exit statuses; the probe's `cabal.project` + freeze file
and those transcripts are retained (committed under `DEVELOPMENT_PLAN/evidence/phase_01/` or CI-archived and
linked) until Phase 5 supersedes them. **The disjunct is evidentiary, never prose:** (a) a build that greens
**only** with `allow-newer`/patch/fork is a **branch-1 green** — it passes only when a transcript produced with
exactly that recorded set is retained (a recorded set with no green transcript does not pass); (b) a **hard
blocker** (branch 2) passes only when the record carries the verbatim failing `cabal build` output **plus one
failing transcript per attempted remediation class** (bare `allow-newer`, source patch, and fork/pin), each
naming the failing package and the compile-fail locus — a one-sentence "package X fails" does not pass. The
Phase-0-seeded mutant `probe/mutants/drop-allow-newer` (the resolution's `allow-newer`/patch removed, or a
bogus upper bound injected) MUST turn `cabal build` red with a version-mismatch/compile-fail locus, and the
committed negative fixture `probe/fixtures/bad-type.dhall` MUST make `cabal run probe:decode` fail with its
committed `dhall` type-error tag (not a parse or missing-file error); both are re-run each gate, not once. The
gate emits the retained proven/tested/assumed ledger (§K) naming **Register 1** and marking every runtime,
cluster, and Gate-2-semantics layer **UNVERIFIED** — a green build is a buildability result only, never a
runtime or deployability claim (Register 1).

**Representative set (concrete corpus, §M.7):** the probe's third-party surface is exactly these named risks —
(i) `dhall` and its transitive lag-prone deps `template-haskell`, `aeson`, `megaparsec`, `prettyprinter`;
(ii) `io-sim` + `io-classes`; and (iii) the `jit-build` resolver's Haskell dependencies, enumerated as the
concrete Hackage packages **`cryptohash-sha256` (content-hashing), `http-client` + `http-client-tls`
(download), `typed-process` (process control), `tar`, `zlib`, `directory`, and `filepath`**. This list is the
authoritative "resolver Haskell dependencies" for the whole phase; `base`/`bytestring`/`process` and other
stock-closure packages do **not** count toward it, and any change to the resolver's real dep set updates this
list in the same change (mirrored in `DEVELOPMENT_PLAN/system_components.md`). Committed Phase-0 oracles (§M.1),
authored before the probe exists: `probe/fixtures/ok.dhall` with its committed expected-decode Haskell value,
`probe/fixtures/bad-type.dhall` with its committed expected `dhall` type-error tag, the named `IOSimPOR`
schedule and its expected terminal state, and the seeded mutant `probe/mutants/drop-allow-newer`.

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
**Independent Validation**: `cabal build` of a trivial library succeeds on **GHC 9.12.4 / Cabal 3.16.1.0** from
a clean store (`rm -rf dist-newstyle` first), with the retained transcript echoing `ghc --version` and
`cabal --version` in-band and showing the shell-observed exit 0; the compiler and a frozen Hackage `index-state`
are captured in one shared committed project file.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (Toolchain — the shared pin), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt the shared-pin discipline recorded in the tracker's Toolchain note — one **GHC 9.12.4 / Cabal 3.16.1.0**
pin across every package, and a single `index-state` that fixes the Hackage snapshot — so every later sprint in
this phase resolves against one dependency universe rather than a drifting one.

### Deliverables
- A `cabal.project` naming the compiler and freezing an `index-state`, plus a trivial library that compiles
  clean against a stock package set — the baseline, with **no** `allow-newer` yet.

### Validation
1. `cabal build` is green on the pin with a stock package set, run from a clean `dist-newstyle`; the retained
   transcript echoes `ghc --version`/`cabal --version` and the exit-0 status observed by the shell, and the
   `index-state` is committed as the shared snapshot.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 1.2: `dhall` in-process decoder build probe (Gate-2 dependency) 📋

**Status**: Planned
**Implementation**: `probe/probe.cabal` (a `dhall` build-depends), `probe/app/Decode.hs` (decode a trivial
`.dhall` in-process) — target paths, not yet built.
**Blocked by**: Sprint 1.1.
**Independent Validation**: a probe depending on `dhall` builds under the pin from a clean store, and
`cabal run probe:decode` decodes the Phase-0-committed `probe/fixtures/ok.dhall` into its committed expected
Haskell value and exits 0 (a green `cabal build` alone does **not** satisfy this — an executed, exit-checked run
is required); paired with it, `probe/fixtures/bad-type.dhall` — a positive/negative pair differing only in one
mistyped field — makes `cabal run probe:decode` fail with its committed `dhall` type-error tag (§M.8: the
failure is asserted by its specific tag, not by "fails"). The exact `allow-newer`/source-patch/fork required by
`dhall`'s transitive deps (`template-haskell`, `aeson`, `megaparsec`, `prettyprinter`) is recorded **together
with** the green transcript produced with exactly that set (branch-1 evidentiary rule above); or the blocker is
recorded with the verbatim failing output and one failing transcript per remediation class.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (the `allow-newer` set), `documents/engineering/dsl_doctrine.md` (§9 backlink).

### Objective
Adopt [`dsl_doctrine.md §9 — Toolchain note`](../documents/engineering/dsl_doctrine.md#9-toolchain-note) with
its [§5 Gate 2](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract): prove
the in-process `dhall` decoder — the entire "if it decodes, it is deployable" Gate-2 claim — is buildable on
the pin before Phase 5 promises an executable decoder. `dhall` historically lags new GHC releases, so
`allow-newer` alone may be insufficient and a source patch or fork may be required.

### Deliverables
- A recorded resolution: the concrete `allow-newer`/patch/fork/pin that makes `dhall` build on GHC 9.12.4, with
  the retained green `cabal build` + `cabal run probe:decode` transcripts produced under exactly that set,
  **or** a recorded blocker carrying the verbatim failing output and one failing transcript per remediation
  class (bare `allow-newer`, source patch, fork/pin).
- The committed Phase-0 fixtures `probe/fixtures/ok.dhall` (+ its expected decoded value) and
  `probe/fixtures/bad-type.dhall` (+ its expected `dhall` type-error tag).

### Validation
1. `cabal run probe:decode` decodes `probe/fixtures/ok.dhall` into its committed expected value and exits 0,
   and the same binary on `probe/fixtures/bad-type.dhall` fails with the committed `dhall` type-error tag; the
   exit-checked transcripts are retained. **The "or recorded" branch is evidentiary** per the Gate line — a
   remediation set counts only with its matching green transcript; a blocker counts only with verbatim failing
   output per remediation class. Prose alone never passes.

### Remaining Work
The whole sprint (📋 Planned). **If it fails:** every Gate-2-dependent phase (5+) is blocked and the blocker is
recorded here; the JVM-only TLC path (Phases 2/3) is unaffected.

## Sprint 1.3: `io-sim` + `io-classes` simulation build probe 📋

**Status**: Planned
**Implementation**: extend `probe/probe.cabal` (`io-sim`, `io-classes` build-depends), `probe/app/Sim.hs` (a
trivial `IOSimPOR` run) — target paths, not yet built.
**Blocked by**: Sprint 1.1.
**Independent Validation**: a probe depending on `io-sim`/`io-classes` builds under the pin from a clean store,
and `cabal run probe:sim` runs the Phase-0-named `IOSimPOR` schedule to its committed expected terminal state
and exits 0 (an executed, exit-checked run — a green `cabal build` alone does not satisfy this); the exact
`allow-newer`/pin is recorded together with the green transcript produced under it (branch-1 rule), or the
blocker is recorded with verbatim failing output per remediation class.
**Docs to update**: `DEVELOPMENT_PLAN/README.md`, `documents/engineering/gateway_migration_model_doctrine.md`
(§4 backlink), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`gateway_migration_model_doctrine.md §4 — Simulate and prove`](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove):
amoebius's one formal obligation drives the gateway-migration `Model` against `io-classes`/`IOSimPOR`'s
deterministic, partial-order-reduced scheduler. Prove that toolchain builds on the pin before Phase 3 authors
the simulation. TLC (`tla2tools.jar`) is pure JVM and version-stable, so the Phase-2/3 TLC path is **not** gated
by this probe.

### Deliverables
- A recorded resolution for `io-sim` + `io-classes` on the pin with its retained green build + `cabal run
  probe:sim` transcripts, **or** a recorded blocker with verbatim failing output per remediation class.
- The Phase-0-committed `IOSimPOR` schedule name and its expected terminal state.

### Validation
1. `cabal run probe:sim` completes the named `IOSimPOR` schedule to its committed expected terminal state and
   exits 0, transcript retained, **or** the exact remediation/blocker is recorded evidentiarily per the Gate
   line (matching green transcript, or verbatim failing output per remediation class — prose alone never
   passes).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 1.4: jit-build resolver deps + consolidated probe gate 📋

**Status**: Planned
**Implementation**: extend `probe/probe.cabal` (the `jit-build` resolver's Haskell deps — content-hashing,
download-or-build, process control) and a single `probe` executable linking `dhall` + `io-sim` + `io-classes`
+ resolver deps; the recorded-resolution ledger in `DEVELOPMENT_PLAN/README.md` — target paths, not yet built.
**Blocked by**: Sprint 1.2, Sprint 1.3.
**Independent Validation**: one probe package whose `build-depends` matches the "Representative set" list
exactly — `dhall`, `io-sim`, `io-classes`, **and** the enumerated resolver packages `cryptohash-sha256`,
`http-client`, `http-client-tls`, `typed-process`, `tar`, `zlib`, `directory`, `filepath` (a category
description or a set already in the stock closure does not satisfy this) — builds and links under GHC 9.12.4 /
Cabal 3.16.1.0 from a clean store, and both `cabal run probe:decode` and `cabal run probe:sim` exit 0 on their
committed fixtures. The seeded mutant `probe/mutants/drop-allow-newer` is re-run and MUST turn `cabal build`
red at a version-mismatch/compile-fail locus (proving the gate detects an unbuildable config, not just
rubber-stamps a green one). The consolidated `allow-newer`/patch/fork set is recorded with its matching green
transcripts (branch-1), or the exact blocker with verbatim per-remediation-class failing output (branch-2), in
the tracker's Toolchain section.
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
- The consolidated throwaway probe executable whose `build-depends` matches the Representative-set list exactly.
- The recorded-resolution ledger (the `allow-newer`/patch/fork set with its matching green transcripts, or the
  hard blocker with verbatim per-remediation-class failing output) in the tracker's Toolchain section.
- The retained `cabal.project` + freeze file, all `cabal build`/`cabal run` transcripts, and the seeded mutant
  `probe/mutants/drop-allow-newer`, under `DEVELOPMENT_PLAN/evidence/phase_01/` (or CI-archived and linked),
  kept until Phase 5 supersedes them.
- A first-class proven/tested/assumed ledger artifact (§K) — naming **Register 1**, recording the green build +
  executed-fixture results as *tested*, and marking every runtime, cluster, and Gate-2-semantics layer
  **UNVERIFIED** — retained even though the probe package itself is deleted after resolution.

### Validation
1. The consolidated probe's `build-depends` matches the Representative-set list exactly; `cabal build` is green
   on the pin from a clean store; `cabal run probe:decode` and `cabal run probe:sim` exit 0 on their committed
   fixtures; and the mutant `probe/mutants/drop-allow-newer` turns `cabal build` red at a compile-fail locus —
   **or** the exact remediation/blocker is recorded evidentiarily per the Gate line. All transcripts are
   retained and the proven/tested/assumed ledger is emitted — the Phase-1 acceptance condition. Prose in the
   tracker without matching retained transcripts never passes.

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
