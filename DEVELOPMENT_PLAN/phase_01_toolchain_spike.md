# Phase 1: Toolchain spike

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_14_chain_kernel_boundary.md
**Generated sections**: none

> **Purpose**: Prove — before any later phase promises an executable decoder, simulator, or resolver — that
> the pre-cluster Haskell surface builds on the pinned toolchain, or record the exact remediation or blocker.

---

## Phase Status

📋 Planned. Every sprint below is 📋 Planned and every prescriptive statement is design intent, never a tested
amoebius result. This phase opens after the Phase 0 documentation lint passes and runs on **no substrate**
(`none`): it stands up no host and no cluster, resolving and building only Hackage packages on the developer
toolchain. It is a de-risking pre-flight for the whole pre-cluster band after this phase (Phases 2–16), whose
in-process integrity checks all rest on the dependencies probed here.

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

**Gate:** a single throwaway probe package that build-depends on `dhall`, `io-sim`, `io-classes`, the
`purescript-bridge` contract generator, the native Pulsar client's `supernova` fork plus its `proto-lens`
codegen, **and** the enumerated `jit-build` resolver Haskell dependencies (the concrete Hackage list fixed under
"Representative set" below — the probe's `build-depends` stanza must match that list exactly, not a category or a
subset already in the stock closure) compiles and links under **GHC 9.12.4 / Cabal 3.16.1.0** from a clean
package store
(`cabal build` run after `rm -rf dist-newstyle` and against a `--store-dir` that holds none of the probed
packages, so a stale store hit cannot mask an unbuildable config), **and** the two committed executable probes
run green: `cabal run probe:decode` in-process decodes the Phase-0-committed positive fixture
`probe/fixtures/ok.dhall` into its committed expected Haskell value and exits 0, and `cabal run probe:sim` runs the named `IOSimPOR` schedule and **emits the terminal state it reaches on
stdout in the committed serialization**, which the external harness `probe/oracle/check-sim-terminal` byte-diffs
against the Phase-0-committed oracle `probe/fixtures/sim-terminal.expected` — this leg greens **only** on a
byte-exact match, never on the probe's self-reported exit 0 (a `main = exitSuccess` stub emits no terminal state
and so fails the diff). Evidence, not prose, closes the gate: the green outcome
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
bogus upper bound injected — this being a buildability gate, §M.2's mutation-operator set is applied here as a
dependency-resolution operator rather than a spec/impl one) MUST turn `cabal build` red with a
version-mismatch/compile-fail locus, and the
committed negative fixture `probe/fixtures/bad-type.dhall` MUST make `cabal run probe:decode` fail with its
committed `dhall` type-error tag (not a parse or missing-file error); and the Phase-0-seeded sim-path mutant
`probe/mutants/perturb-sim-schedule` (the named schedule's step ordering perturbed / one fairness step dropped —
a §M.2 schedule-perturbation operator) MUST drive `probe:sim` to a **different** terminal state so the external
`check-sim-terminal` harness fails at a terminal-state mismatch — the mutant that gives the `probe:sim` leg its
teeth, turning it red at the oracle diff independent of the probe's exit code; all three are re-run each gate,
not once. The
gate emits the retained proven/tested/assumed ledger (§K) naming **Register 1** and marking every runtime,
cluster, and Gate-2-semantics layer **UNVERIFIED** — a green build is a buildability result only, never a
runtime or deployability claim (Register 1).

**Representative set (concrete corpus, §M.7):** the probe's third-party surface is exactly these named risks —
(i) `dhall` and its transitive lag-prone deps `template-haskell`, `aeson`, `megaparsec`, `prettyprinter`;
(ii) `io-sim` + `io-classes`; (iii) the `jit-build` resolver's Haskell dependencies, enumerated as the
concrete Hackage packages **`cryptohash-sha256` (content-hashing), `http-client` + `http-client-tls`
(download), `typed-process` (process control), `tar`, `zlib`, `directory`, and `filepath`**; (iv) the
`purescript-bridge` contract generator (build-only, the SPA-composition phase's dependency); and (v) the native
Pulsar client's `supernova` fork plus its `proto-lens` codegen (build-only, the Pulsar-client phase's
dependency). This list is the
authoritative "resolver Haskell dependencies" for the whole phase; `base`/`bytestring`/`process` and other
stock-closure packages do **not** count toward it, and any change to the resolver's real dep set updates this
list in the same change (mirrored in `DEVELOPMENT_PLAN/system_components.md`). Committed Phase-0 oracles (§M.1),
authored before the probe exists: `probe/fixtures/ok.dhall` with its committed expected-decode Haskell value,
`probe/fixtures/bad-type.dhall` with its committed expected `dhall` type-error tag, the named `IOSimPOR`
schedule with its expected terminal state serialized as the Phase-0 oracle `probe/fixtures/sim-terminal.expected`
(diffed by the external harness `probe/oracle/check-sim-terminal`, which is independent of the probe under
test — §M.1/§M.3), and the two seeded mutants `probe/mutants/drop-allow-newer` (a dependency-resolution operator)
and `probe/mutants/perturb-sim-schedule` (a sim-schedule-perturbation operator, paired with the `probe:sim`
terminal-state positive it breaks — §M.2).

## Doctrine adopted

- [`conformance_harness_doctrine.md §2 — the registers`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
  and its §3 load-bearing invariant that **rendering never touches live infrastructure**: this phase is a pure
  Register-1 check ([three-register definitions](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing)),
  building and running in-process with no cluster, no credentials, and no broker.
- [`dsl_doctrine.md §9 — Toolchain note`](../documents/engineering/dsl_doctrine.md#9-toolchain-note), read
  with [§5's Gate 2](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  the in-process `dhall` decoder — the Gate-2 structural leg of the later
  `decode → bind/expand → plan/resolve infrastructure → provision → ProvisionedSpec → renderAll` contract — needs `allow-newer` against the
  pinned GHC; this phase is where that exact set is proven or the blocker recorded, before any later phase
  promises an executable Gate 2.
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
the in-process `dhall` decoder — the structural Gate-2 leg that must precede Phase-10 bind/provision — is
buildable on the pin before Phase 5 promises an executable decoder. `dhall` historically lags new GHC releases, so
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
trivial `IOSimPOR` run that **emits the terminal state it reaches on stdout** in the committed serialization),
the external harness `probe/oracle/check-sim-terminal`, the Phase-0 oracle `probe/fixtures/sim-terminal.expected`,
and the seeded mutant `probe/mutants/perturb-sim-schedule` — target paths, not yet built.
**Blocked by**: Sprint 1.1.
**Independent Validation**: a probe depending on `io-sim`/`io-classes` builds under the pin from a clean store,
and `cabal run probe:sim` runs the Phase-0-named `IOSimPOR` schedule and **emits the terminal state it reaches
on stdout**, which the external harness `probe/oracle/check-sim-terminal` byte-diffs against the Phase-0-committed
oracle `probe/fixtures/sim-terminal.expected` — the leg greens **only** on a byte-exact match, **not** on the
probe's self-reported exit 0 (a `main = exitSuccess` stub emits no terminal state and fails the diff); paired
with it, the seeded mutant `probe/mutants/perturb-sim-schedule` (the schedule's step ordering perturbed / one
fairness step dropped) MUST turn `probe:sim` **red at a terminal-state mismatch** against the same oracle (§M.2:
the mutant is named by path + operator and paired with the terminal-state positive it breaks); the exact
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
- The Phase-0-committed `IOSimPOR` schedule name and its expected terminal state serialized as
  `probe/fixtures/sim-terminal.expected`, the external comparison harness `probe/oracle/check-sim-terminal`, and
  the seeded sim-path mutant `probe/mutants/perturb-sim-schedule`.

### Validation
1. `cabal run probe:sim` emits its reached terminal state and the external `check-sim-terminal` harness confirms
   a byte-exact match against the committed `probe/fixtures/sim-terminal.expected` oracle (never the probe's
   self-exit); the seeded mutant `probe/mutants/perturb-sim-schedule` is re-run and MUST turn `probe:sim` red at
   a terminal-state mismatch; transcript retained, **or** the exact remediation/blocker is recorded evidentiarily
   per the Gate line (matching green transcript, or verbatim failing output per remediation class — prose alone
   never passes).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 1.4: jit-build resolver deps + `purescript-bridge` + consolidated probe gate 📋

**Status**: Planned
**Implementation**: extend `probe/probe.cabal` (the `jit-build` resolver's Haskell deps — content-hashing,
download-or-build, process control — **plus** the build-only `purescript-bridge` contract generator, **plus**
the `supernova` fork + `proto-lens` codegen whose recorded resolution Sprint 1.5 lands) and a single `probe`
executable whose `build-depends` enumerates the **entire** Representative set — `dhall` + `io-sim` +
`io-classes` + the eight resolver packages + `purescript-bridge` + `supernova`/`proto-lens`; the
recorded-resolution ledger in `DEVELOPMENT_PLAN/README.md` — target paths, not yet built.
**Blocked by**: Sprint 1.2, Sprint 1.3, Sprint 1.5 (the consolidated probe cannot link until every leaf leg —
decoder, simulator, resolver deps, `purescript-bridge`, and the `supernova`/`proto-lens` fork+codegen — has its
recorded resolution).
**Independent Validation**: one probe package whose `build-depends` matches the "Representative set" list
exactly — `dhall`, `io-sim`, `io-classes`, the eight enumerated resolver packages `cryptohash-sha256`,
`http-client`, `http-client-tls`, `typed-process`, `tar`, `zlib`, `directory`, `filepath`, **the build-only
`purescript-bridge` contract generator, and the `supernova` fork + `proto-lens` codegen** (all five clauses
(i)–(v) of the Representative set; a category description or a set already in the stock closure does not satisfy
this) — builds and links under GHC 9.12.4 / Cabal 3.16.1.0 from a clean store; `cabal run probe:decode` exits 0
on its committed fixture; and `cabal run probe:sim` emits its reached terminal state, which the external
`check-sim-terminal` harness confirms byte-exact against the committed `probe/fixtures/sim-terminal.expected`
oracle (never the probe's self-exit). **Both** seeded mutants are re-run: `probe/mutants/drop-allow-newer` MUST
turn `cabal build` red at a version-mismatch/compile-fail locus, and `probe/mutants/perturb-sim-schedule` MUST
turn `probe:sim` red at a terminal-state mismatch (together proving the gate detects both an unbuildable config
and a wrong-terminal-state sim, not just rubber-stamps a green one). The consolidated `allow-newer`/patch/fork
set is recorded with its matching green transcripts (branch-1), or the exact blocker with verbatim
per-remediation-class failing output (branch-2), in the tracker's Toolchain section.
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
- The consolidated throwaway probe executable whose `build-depends` matches the Representative-set list
  exactly — all five clauses (i)–(v): `dhall` + `io-sim` + `io-classes` + the eight resolver packages +
  `purescript-bridge` + `supernova`/`proto-lens` (the last folded in from Sprint 1.5).
- The recorded-resolution ledger (the `allow-newer`/patch/fork set with its matching green transcripts, or the
  hard blocker with verbatim per-remediation-class failing output) in the tracker's Toolchain section.
- The retained `cabal.project` + freeze file, all `cabal build`/`cabal run` transcripts, the external
  `probe/oracle/check-sim-terminal` harness with its `probe/fixtures/sim-terminal.expected` oracle, and **both**
  seeded mutants `probe/mutants/drop-allow-newer` and `probe/mutants/perturb-sim-schedule`, under
  `DEVELOPMENT_PLAN/evidence/phase_01/` (or CI-archived and linked), kept until Phase 5 supersedes them.
- A first-class proven/tested/assumed ledger artifact (§K) — naming **Register 1**, recording the green build +
  executed-fixture results as *tested*, and marking every runtime, cluster, and Gate-2-semantics layer
  **UNVERIFIED** — retained even though the probe package itself is deleted after resolution.

### Validation
1. The consolidated probe's `build-depends` matches the Representative-set list exactly (all five clauses
   (i)–(v)); `cabal build` is green on the pin from a clean store; `cabal run probe:decode` exits 0 on its
   committed fixture; `cabal run probe:sim`'s reported terminal state passes the external `check-sim-terminal`
   diff against the committed oracle; and **both** mutants turn the gate red — `probe/mutants/drop-allow-newer`
   at a compile-fail locus and `probe/mutants/perturb-sim-schedule` at a terminal-state mismatch — **or** the
   exact remediation/blocker is recorded evidentiarily per the Gate line. All transcripts are retained and the
   proven/tested/assumed ledger is emitted — the Phase-1 acceptance condition. Prose in the tracker without
   matching retained transcripts never passes.

### Remaining Work
The whole sprint (📋 Planned). This is a throwaway probe: it is deleted once the resolution is recorded, exactly
like the removed formal-model spike; nothing here is a durable amoebius module.

## Sprint 1.5: `supernova` fork + `proto-lens` codegen build probe 📋

**Status**: Planned
**Implementation**: extend `probe/probe.cabal` (the native Pulsar client's `supernova` fork + its `proto-lens`
codegen, build-only), plus the generated protobuf module the `proto-lens` codegen emits — target paths, not yet
built.
**Blocked by**: Sprint 1.1.
**Independent Validation**: the `supernova` fork and its `proto-lens` codegen resolve and compile under the pin
from a clean store — the hardest single leg, a source **fork** plus a codegen step, not a stock Hackage pull —
with the retained green `cabal build` transcript echoing `ghc --version`/`cabal --version` in-band and showing
the shell-observed exit 0; the exact fork ref + `allow-newer`/patch/pin is recorded **together with** that green
transcript (branch-1 evidentiary rule), **or** the blocker is recorded with the verbatim failing `cabal build`
output **plus one failing transcript per remediation class** (bare `allow-newer`, source patch, fork/pin), each
naming the failing package and the compile-fail locus. The consolidated gate's seeded mutant
`probe/mutants/drop-allow-newer` (a §M.2 dependency-resolution operator) covers this leg too: with the fork
ref/patch removed, `cabal build` MUST turn red at the `supernova`/`proto-lens` resolution locus — the committed
mutant this build-only leg is paired against.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (the `supernova` fork ref + codegen `allow-newer`/patch set),
`documents/engineering/content_addressing_doctrine.md` (the Pulsar-client dependency backlink),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
De-risk the native Pulsar client's `supernova` fork plus its `proto-lens` codegen — clause (v) of the
Representative set, the Pulsar-client band's load-bearing build dependency — on the shared pin **here**, before
the Pulsar-client phase promises it, rather than discovering mid-implementation that a forked client or its
generated protobuf modules will not compile on GHC 9.12.4. This is the riskiest single leg (a fork plus a
codegen step), so it is isolated as its own recorded resolution-or-blocker and then folded into the Sprint 1.4
consolidated gate.

### Deliverables
- A recorded resolution: the concrete `supernova` fork ref + `proto-lens` `allow-newer`/patch/pin that makes the
  fork and its codegen build on GHC 9.12.4, with the retained green `cabal build` transcript produced under
  exactly that set, **or** a recorded blocker carrying the verbatim failing output and one failing transcript
  per remediation class (bare `allow-newer`, source patch, fork/pin).
- The generated `proto-lens` protobuf module committed as the codegen's build-only deliverable, plus the
  retained transcript, under `DEVELOPMENT_PLAN/evidence/phase_01/`.

### Validation
1. The `supernova` fork + `proto-lens` codegen build green under the pin from a clean store, transcript retained;
   and the consolidated `probe/mutants/drop-allow-newer`, re-run with the fork ref/patch removed, turns
   `cabal build` red at the `supernova`/`proto-lens` locus — **or** the exact remediation/blocker is recorded
   evidentiarily per the Gate line (matching green transcript, or verbatim failing output per remediation class —
   prose alone never passes).

### Remaining Work
The whole sprint (📋 Planned). **If it fails:** the Pulsar-client phase is blocked and the blocker is recorded
here; the `dhall`/`io-sim`/resolver legs (Sprints 1.2–1.4) are unaffected. This is a throwaway probe leg,
deleted once its resolution is recorded; nothing here is a durable amoebius module.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
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
