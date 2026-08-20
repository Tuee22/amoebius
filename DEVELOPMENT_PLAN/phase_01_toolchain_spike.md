# Phase 1: Toolchain spike

> **Purpose**: Resolve the current compatible pre-cluster toolchain dynamically and prove that the decoder,
> simulator, resolver, browser, and protocol-codegen probes build without committing solver output, package
> integrity pins, or host-specific paths.
> **Read this if**: phase 1 is next in the queue, or a later phase depends on what its gate establishes.

Phase 1 delivers the toolchain spike; its design is owned by [conformance_harness_doctrine.md](../documents/engineering/conformance_harness_doctrine.md), [testing_doctrine.md](../documents/engineering/testing_doctrine.md), [dsl_doctrine.md](../documents/engineering/dsl_doctrine.md), and the plan for reaching it is owned here.
Register 1: an in-process battery, no cluster.
Runtime, cluster, and gadt-decode semantic fidelity remain UNVERIFIED.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/content_addressing_determinism.md, documents/engineering/dsl_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 1.1: Historical shared-resolution spike 📋](#sprint-11-historical-shared-resolution-spike-)
- [Sprint 1.2: `dhall` in-process decoder build probe (gadt-decode dependency) 📋](#sprint-12-dhall-in-process-decoder-build-probe-gadt-decode-dependency-)
- [Sprint 1.3: `io-sim` + `io-classes` simulation build probe 📋](#sprint-13-io-sim--io-classes-simulation-build-probe-)
- [Sprint 1.4: jit-build resolver deps + `purescript-bridge` + consolidated probe gate 📋](#sprint-14-jit-build-resolver-deps--purescript-bridge--consolidated-probe-gate-)
- [Sprint 1.5: `supernova` fork + `proto-lens` codegen build probe 📋](#sprint-15-supernova-fork--proto-lens-codegen-build-probe-)
- [Sprint 1.6: Dynamic resolution and generated-output migration 📋](#sprint-16-dynamic-resolution-and-generated-output-migration-)
- [Sprint 1.7: Discover, then ensure — the resolver acquires what it needs 📋](#sprint-17-discover-then-ensure--the-resolver-acquires-what-it-needs-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-0 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

**The first 2026-08-17 seal, on the amended contract.** `python3 tools/toolchain_spike_gate.py` passes all
twelve sides on substrate `none`, lane `none`, natural `arm64`, untranslated: 17 authored requirements resolve
with none expected on the host, both resolutions admit the same 225 packages, the same graph resolves from the
1989-file source snapshot alone, the representative set builds from an empty package store, every probe matches
its independently authored expectation, both committed mutants redden, all eight seeded negatives redden their
own check and no other, 40 surfaces join completely to 62 enumerated items, and the outside-host inventory is
unchanged. The run left no authored path created, changed, or removed, and published attestation
`sha256:836c137384ac75a75dc76349bc4bb9d088667a9a35c231c7d32af47056b62528` against source snapshot
`sha256:9ba00b2d7a4ba69a…`.

**Reopened 2026-08-16 by the natural-architecture amendment**, and open for work since Phase 0 resealed on
2026-08-17.

**Amended 2026-08-17 by the host-ensure change.** The gate adopts clause 15 — it records the substrate, the
lane, and the architecture it executes on, refuses a translated process, and enumerates that observation as a
check of its own — and on the current host that side passes: `darwin/arm64`, natural `arm64`, untranslated.
Resolution then stopped, because four tools were declared "expected on the developer host" and two of them
were absent. That declaration was the defect, not the host: a tool with a supported install plan is ensured,
never written down as a prerequisite
([`substrate_doctrine.md` §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)).
[Sprint 1.7](#sprint-17-discover-then-ensure--the-resolver-acquires-what-it-needs-) replaces that source kind
with acquisition, and narrows what the phase requires to the floor
([`substrate_doctrine.md` §3.1](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply)).

**Sprint 1.7 closed that gap on the same host that exposed it, which is the point.** The two tools the previous
run declared missing are acquired rather than expected: `dhall` from its publisher's own release into
`.build/toolchain/runtime/`, `chromium` from the resolved Playwright driver, which is asked where it put it.
`ghc` and `cabal` come from `ghcup` into a contained `HOME`, so the run leaves no compiler outside the
checkout. `git`, `node`, and `npm` — invoked bare and undeclared before — are declared, version-checked, and
resolved through the floor's own package-manager query. The floor itself is authored data, evaluated before
resolution and decidable for substrates this host is not, so an unsupportable host is named along with its
remedy rather than discovered as a symptom four requirements deep.

[§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 15 requires a run to record
the natural architecture it proved and to execute no artifact of another. Every gate before 2026-08-17 recorded
no architecture, so each of those seals is invalidated as a current result and stands only as history; this run
differs from them by naming the lane and architecture it actually used. A sprint marker below records what that
sprint achieved before the amendment; under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) it is a diagnostic, not surviving closure.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Done (invalidated) — resealed 2026-08-15 under the containment amendment. `python3 tools/toolchain_spike_gate.py`
resolved the same 225-package graph twice and from the source snapshot, built the representative set from an
empty project-local store, passed every probe and mutant, left the outside-host inventory unchanged, and
published attestation `sha256:915a26a7b76634ac544f9a3c81296b0699ad26193b76b5548d3f6a5d6133438f`.
The global artifact audit has zero Phase-1-owned deferrals.

**Pre-containment status record (invalidated where it claims completion):**

Done (invalidated) — sealed 2026-08-12. The redesigned nine-sided gate passed against source snapshot
`sha256:6ee45846d4d5066b…` (1927 non-ignored files) and published a verified pre-containment external attestation
`sha256:353cafb9d60d6e4205d84fef33dd92ea4c0f198c5dfcdf16455c5a217e95bb24`.

**Observed progress — 2026-08-12:** **Policy-conformant.** `toolchain/pins.json` is deleted; the authored half
is `tools/toolchain_requirements.json`, which carries compatibility ranges, release channels, and asset patterns and
no path, resolved version, URL, or checksum. `tools/toolchain.py` resolves all ten requirements per run into
ignored `.build/toolchain/resolved.json`, acquiring the released tools from their current upstream releases rather
than from pinned URLs. `cabal.project` names a release channel instead of a revision, carries no developer path
and no frozen `index-state`, and applies the tracked `patches/supernova_ghc_9_12.patch`; the superseded `dual`
patch is deleted and `vendor/dual/PROVENANCE.md` records that package's provenance instead. The gate resolves
twice to the same 225-package graph, resolves the same graph from non-ignored source alone, builds the
representative set from an empty package store, executes every probe against its authored expectation, reddens
both seeded mutants, joins 29 surfaces to 48 run-time enumerated items, and leaves every authored path
unchanged. Twenty-two downstream gate scripts now consume run-local resolution.

**Two corrections this closure made, both recorded rather than absorbed.** The gate's predecessor built `all`,
which made a Phase-1 gate depend on packages phases 9–70 own — the forward dependency
[§E](development_plan_standards.md#e-one-canonical-phase-model) forbids. Narrowing it to the representative set
exposed that `lib:dsl-core` does not compile, because the UI-server boundary ABI
`src/Amoebius/Ui/Server/Main.hs` imports does not exist anywhere in the tree; that seam is Phase 43's and is
recorded in [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md). Separately, the
`source-closure` seeded negative had stopped firing because path normalization stripped the leading dot from
its ignored root, so it proved nothing; it now seeds a non-dotted ignored root.

**Invalidated historical record:**

Done (invalidated). The consolidated clean-store gate passed on 2026-08-08 with
`python3 tools/toolchain_spike_gate.py`, emitting ledger
`dynamically-resolved`. This is a tested buildability result,
not a runtime or gadt-decode-semantics result. This phase opened after the Phase 0 documentation lint passed and ran on **no substrate**
(`none`): it stands up no host and no cluster, resolving and building only Hackage packages on the developer
toolchain. It is a de-risking pre-flight for the pre-cluster in-process band (Phases 9–25), whose
integrity checks all rest on the dependencies probed here.

## Phase Summary

This phase settles buildability without freezing a dependency graph into Git. The authored project files state
package names, source channels, and compatibility requirements. A clean gate resolves the current compatible
compiler, libraries, browser tools, protocol generator, and transitive graph into `.build/toolchain/` and
`.build/locks/`.

The probe covers the in-process Dhall decoder, `io-sim`/`io-classes`, jit-build resolver dependencies,
PureScript contract generation, and the native Pulsar client's protocol code generation. Resolved versions,
source identities, compatibility adjustments, observed checksums, executable paths, and transcripts are run
evidence. They are attested beneath `.build/evidence-store/**` and never copied into Markdown or a tracked manifest.

**Phase scope:** one cohesive claim — *the toolchain is a resolved observation, never a committed pin*. Five probes exist only to show the resolution reaches everything a later phase needs.

**Substrate:** `none` — no host, no cluster; the gate resolves and compiles Hackage packages on the developer
toolchain only.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure/build, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 0](phase_00_documentation_suite.md) — documentation suite (whole DSL), which this phase consumes rather than rebuilds.

**Gate:** against its source snapshot, `python3 tools/toolchain_spike_gate.py` dynamically resolves a compatible graph,
builds and runs every named probe and mutant, verifies every reviewed patch is tracked under an authored root,
writes only ignored run output, leaves authored paths unchanged, and publishes a verified repository-local attestation.

## Gate integrity

The representative set is `dhall`, `io-sim`, `io-classes`, the jit-build resolver dependencies,
`purescript-bridge`, PureScript/Spago/browser tooling, the native Pulsar client, `supernova`, `proto-lens`,
and `protoc`. The authored Dhall positive/negative pair, independent simulation expectation, schedule mutant,
dependency-resolution mutant, and protocol round-trip fixture remain the oracle side.


The gate builds that set and nothing later: the `probe` executables plus the Pulsar `proto` package, which
between them link every member. It does not build the packages phases 9–70 own. A Phase-1 gate that built the
whole tree would consume what a later phase delivers — the forward dependency
[§E](development_plan_standards.md#e-one-canonical-phase-model) forbids — and would report a toolchain failure
whenever a later phase's source stopped compiling, which is exactly what it did on 2026-08-12
([legacy register](legacy_tracking_for_deletion.md)).

The gate starts with empty `.build/cabal-store/**`, `.build/dist-newstyle/**`, `.build/node_modules/**`, and
tool caches for the probed graph, with subprocess temp/cache variables resolved to `.build/tmp/**`. It
generates solver results, bindings, transcripts, enumerations, and ledgers beneath `.build/` and proves from a
host inventory that no tool wrote outside the checkout. The repository-local attestation records actual versions,
sources, integrity observations, compatibility changes, and tool paths. A hard blocker is a red gate with
external diagnostics, never a prose substitute for success.

The source-closure check rejects a project or gate that references an ignored patch. Retained compatibility
patches are reviewed external/authored inputs beneath `patches/**` or `vendor/**`; generated patch application
results remain under `.build/`. The semantic scan also rejects a fixed dependency commit, package integrity hash,
or developer path even when no ignore pattern matches the file containing it.

```mermaid
flowchart LR
  %% register: orientation
  req[authored compatibility requirements] --> resolve[dynamic resolver]
  resolve --> gen[ignored .build output]
  gen --> probe[probe and committed seeded mutants]
  probe --> attest[repository-local attestation]
```
*Design intent. Phase 1 resolves a current compatible graph per run and retains only repository-local evidence, as owned by [repository-layout doctrine §4](../documents/engineering/repository_layout_doctrine.md#4-dependency-and-toolchain-resolution).*
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`conformance_harness_doctrine.md §2 — the registers`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
  and its [§3](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure) load-bearing invariant that **rendering never touches live infrastructure**: this phase is a pure
  Register-1 check ([register definitions](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)),
  building and running in-process with no cluster, no credentials, and no broker.
- [`dsl_doctrine.md §9 — Toolchain note`](../documents/engineering/dsl_doctrine.md#9-toolchain-note), read
  with [§5's gadt-decode](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  the in-process `dhall` decoder — the gadt-decode structural leg of the later
  `decode → bind/expand → plan/resolve infrastructure → provision → ProvisionedSpec → renderAll` contract — needs `allow-newer` against the
  pinned GHC; this phase is where that exact set is proven or the blocker recorded, before any later phase
  promises an executable gadt-decode.
- [`gateway_migration_model_doctrine.md §4 — Simulate and prove`](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove):
  amoebius's **one** formal obligation drives the gateway-migration `Model` (both `Planned` and `Failover`
  branches) against `io-classes`/`IOSimPOR`'s deterministic scheduler; this phase de-risks that build
  dependency, while the version-stable JVM TLC half stays unaffected by the GHC pin.
- [`formal_model_doctrine.md §7 — Prototype validation`](../documents/engineering/formal_model_doctrine.md#7-prototype-validation):
  the reifiable-`Model` mechanism — one value rendering both `interpret` (runtime) and `emitTLA` (a generated,
  never-committed `.tla`) — was prototyped in a throwaway spike; that is **sibling evidence, not an amoebius result**, and its Haskell side must build on the pin before Phase 11 authors it.
- [`content_addressing_determinism.md §4.5 — the ML-asset lifecycle`](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
  ML engines/models/kernels are never baked or URL-fetched — the shared `jit-build` resolver materializes each
  **named catalog identity** on first miss into a `CacheBudget`-bounded content-addressed cache; the resolver's
  own Haskell dependencies are folded into this probe.

## Sprints

> **How to read the sprint bodies.** Sprints 1.1–1.5 record the pre-amendment resolution experiment. Their
> *functional* outcomes — the compiler builds, the Dhall decode pair, the IOSim terminal oracle, the resolver
> dependency surface, the Supernova fork and its codegen — are re-established by the 2026-08-12 gate and are
> what closes them. Their *mechanics* are not: every historical date, repository-resident evidence path,
> committed transcript, frozen `index-state`, pinned version, and integrity hash below is superseded by dynamic
> resolution, and no instruction to retain any of them governs future work. Sprint 1.6 is the replacement
> contract and states what the current gate actually does.

## Sprint 1.1: Historical shared-resolution spike 📋
**Status**: Planned
**Implementation**: `cabal.project`, `cabal.project.freeze`, and `toolchain/pins.json` — the **pin
manifest**: the resolved absolute paths of `ghc`/`cabal`/`dhall` (invoked by absolute path from
[Phase 26](phase_26_gadt_decode_ir.md) on) and of `spago`/`purs` + Chromium (the browser toolchain the UI
phases from [Phase 42](phase_42_ui_browser_interpreter.md) on drive) — implemented and version-checked by the gate.
**Blocked by**: reopened numeric predecessor gates.
**Requires**: `host-floor` — the package-manager root and the substrate's own build prerequisites. Every
tool this sprint names is acquired rather than assumed.
**Independent Validation**: `cabal build` of a trivial library succeeds
on **GHC 9.12.4 / Cabal 3.16.1.0** from a clean store (`rm -rf dist-newstyle` first), with the retained
transcript echoing `ghc --version` and `cabal --version` in-band and showing the shell-observed exit 0; the
compiler and a frozen Hackage `index-state` are captured in one shared committed project file.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (Toolchain — the shared pin),
`DEVELOPMENT_PLAN/system_components.md`.

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
None. Validated by the consolidated Phase-1 gate on 2026-08-08.

## Sprint 1.2: `dhall` in-process decoder build probe (gadt-decode dependency) 📋
**Status**: Planned
**Implementation**: `probe/probe.cabal` (a `dhall` build-depends), `probe/app/Decode.hs`
(decode a trivial `.dhall` in-process) — implemented as the retained gate harness.
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: a `dhall`-dependent probe builds from a clean store and `cabal run probe:decode`
decodes its oracle-pinned fixture and exits 0, while the one-field-mistyped twin fails with the committed
type-error tag. The numbered `### Validation` list below carries the transitive-dependency set and the
evidentiary branch rule.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (the `allow-newer` set),
`documents/engineering/dsl_doctrine.md` (§9 backlink).

### Objective
Adopt [`dsl_doctrine.md §9 — Toolchain note`](../documents/engineering/dsl_doctrine.md#9-toolchain-note) with
its [§5 gadt-decode](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract): prove
the in-process `dhall` decoder — the structural gadt-decode leg that must precede Phase-30/18 bind/provision — is
buildable on the pin before Phase 26 promises an executable decoder. `dhall` historically lags new GHC releases, so
`allow-newer` alone may be insufficient and a source patch or fork may be required.

### Deliverables
- A recorded resolution: the concrete `allow-newer`/patch/fork/pin that makes `dhall` build on GHC 9.12.4, with
  the retained green `cabal build` + `cabal run probe:decode` transcripts produced under exactly that set,
  **or** a recorded blocker carrying the verbatim failing output and one failing transcript per remediation
  class (bare `allow-newer`, source patch, fork/pin).
- The committed Phase-0 fixtures `probe/fixtures/ok.dhall` (+ its expected decoded value) and
  `probe/fixtures/bad-type.dhall` (+ its expected `dhall` type-error tag).

### Validation
1. A probe depending on `dhall` builds under the pin from a clean store, and `cabal run probe:decode` decodes
   `probe/fixtures/ok.dhall` into its committed expected Haskell value and exits 0. A green `cabal build`
   alone does **not** satisfy this: an executed, exit-checked run is required.
2. The same binary on `probe/fixtures/bad-type.dhall` — the negative half of a pair differing from
   `ok.dhall` only in one mistyped field — fails with the committed `dhall` type-error tag (§M.8: the failure
   is asserted by its specific tag, not by "fails"); the exit-checked transcripts are retained.
3. The exact `allow-newer`/source-patch/fork required by `dhall`'s transitive deps (`template-haskell`,
   `aeson`, `megaparsec`, `prettyprinter`) is recorded **together with** the green transcript produced with
   exactly that set. **The "or recorded" branch is evidentiary** per the Gate line — a remediation set counts
   only with its matching green transcript; a blocker counts only with verbatim failing output per remediation
   class. Prose alone never passes.

### Remaining Work
None. The positive decode matched byte-for-byte and the negative failed at `DHALL_TYPE_ERROR` in the retained
2026-08-08 gate evidence.

## Sprint 1.3: `io-sim` + `io-classes` simulation build probe 📋
**Status**: Planned
**Implementation**: extend `probe/probe.cabal` (`io-sim`, `io-classes` build-depends),
`probe/app/Sim.hs` (a trivial `IOSimPOR` run that **emits the terminal state it reaches on stdout** in the
committed serialization), the external harness `probe/oracle/check-sim-terminal`, the Phase-0 oracle
`probe/fixtures/sim-terminal.expected`, and the seeded mutant `probe/mutants/perturb-sim-schedule` — implemented
as the retained gate harness.
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: a probe depending on `io-sim`/`io-classes` builds from a clean store, and the
terminal state `cabal run probe:sim` emits matches the external `check-sim-terminal` oracle byte-for-byte
while the seeded schedule mutant reddens it. The numbered `### Validation` list below carries the stub
negative, the mutant operator, and the evidentiary branch rule.
**Docs to update**: `DEVELOPMENT_PLAN/README.md`, `documents/engineering/gateway_migration_model_doctrine.md` (§4
backlink), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`gateway_migration_model_doctrine.md §4 — Simulate and prove`](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove):
amoebius's one formal obligation drives the gateway-migration `Model` against `io-classes`/`IOSimPOR`'s
deterministic, partial-order-reduced scheduler. Prove that toolchain builds on the pin before Phase 17 authors
the simulation. TLC (`tla2tools.jar`) is pure JVM and version-stable, so the Phase-11/10 TLC path is **not** gated
by this probe.

### Deliverables
- A recorded resolution for `io-sim` + `io-classes` on the pin with its retained green build + `cabal run
  probe:sim` transcripts, **or** a recorded blocker with verbatim failing output per remediation class.
- The oracle-pinned `IOSimPOR` schedule name and its expected terminal state serialized as
  `probe/fixtures/sim-terminal.expected`, the external comparison harness `probe/oracle/check-sim-terminal`, and
  the seeded sim-path mutant `probe/mutants/perturb-sim-schedule`.

### Validation
1. A probe depending on `io-sim`/`io-classes` builds under the pin from a clean store, and `cabal run
   probe:sim` runs the Phase-0-named `IOSimPOR` schedule and **emits the terminal state it reaches on
   stdout**; the external `check-sim-terminal` harness confirms a byte-exact match against the committed
   `probe/fixtures/sim-terminal.expected` oracle. The leg greens **only** on that match, never on the probe's
   self-reported exit 0 — a `main = exitSuccess` stub emits no terminal state and fails the diff.
2. The seeded mutant `probe/mutants/perturb-sim-schedule` (the schedule's step ordering perturbed, one
   fairness step dropped) is re-run and MUST turn `probe:sim` red at a terminal-state mismatch against the
   same oracle (§M.2: the mutant is named by path + operator and paired with the terminal-state positive it
   breaks).
3. The transcript is retained, **or** the exact remediation/blocker is recorded evidentiarily per the Gate
   line (matching green transcript, or verbatim failing output per remediation class — prose alone never
   passes).

### Remaining Work
None. The external terminal-state oracle passed and the schedule perturbation mutant was killed on 2026-08-08.

## Sprint 1.4: jit-build resolver deps + `purescript-bridge` + consolidated probe gate 📋
**Status**: Planned
**Implementation**: `probe/probe.cabal` and its single consolidated `probe` executable, plus the
recorded-resolution ledger in `DEVELOPMENT_PLAN/README.md` — implemented and retained as gate evidence.
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: one probe package carrying the entire Representative set builds and links from a
clean store, `probe:decode` and `probe:sim` pass their committed fixture and external oracle, and both seeded
mutants redden the gate. The numbered `### Validation` list below carries the exact clause, locus, and
evidentiary-branch obligations.
**Docs to update**:
`DEVELOPMENT_PLAN/README.md` (Toolchain — the consolidated pin/`allow-newer` set),
`documents/engineering/content_addressing_doctrine.md` (§4.5 resolver-deps backlink),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`content_addressing_determinism.md §4.5 — the ML-asset lifecycle`](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
the shared `jit-build` resolver that materializes named catalog identities into the `CacheBudget`-bounded
content-addressed cache carries its own Haskell dependencies. Fold them into one probe that also links `dhall`
+ `io-sim` + `io-classes`, so the whole pre-cluster in-process surface is proven buildable as **one**
dependency universe — the phase gate.

### Deliverables
- The consolidated throwaway probe executable whose `build-depends` matches the Representative-set list
  exactly — all five clauses (i)–(v): `dhall` + `io-sim` + `io-classes` + the eight `jit-build` resolver
  packages (`cryptohash-sha256`, `http-client`, `http-client-tls`, `typed-process`, `tar`, `zlib`,
  `directory`, `filepath` — content-hashing, download-or-build, and process control) + the build-only
  `purescript-bridge` contract generator + the `supernova` fork with its `proto-lens` codegen (the last
  folded in from Sprint 1.5).
- The recorded-resolution ledger (the `allow-newer`/patch/fork set with its matching green transcripts, or the
  hard blocker with verbatim per-remediation-class failing output) in the tracker's Toolchain section.
- The retained `cabal.project` + freeze file, all `cabal build`/`cabal run` transcripts, the external
  `probe/oracle/check-sim-terminal` harness with its `probe/fixtures/sim-terminal.expected` oracle, and **both**
  seeded mutants `probe/mutants/drop-allow-newer` and `probe/mutants/perturb-sim-schedule`, under
  `DEVELOPMENT_PLAN/evidence/phase_1/` (or CI-archived and linked), kept until Phase 26 supersedes them.
- A first-class proven/tested/assumed ledger artifact ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)) — naming **Register 1**, recording the green build +
  executed-fixture results as *tested*, and marking every runtime, cluster, and gadt-decode-semantics layer
  **UNVERIFIED** — retained even though the probe package itself is deleted after resolution.

### Validation
1. The consolidated probe's `build-depends` matches the Representative-set list exactly — all five clauses
   (i)–(v); a category description, or a set already in the stock closure, does not satisfy this. It builds
   and links under GHC 9.12.4 / Cabal 3.16.1.0 from a clean store.
2. `cabal run probe:decode` exits 0 on its committed fixture, and `cabal run probe:sim`'s reported terminal
   state passes the external `check-sim-terminal` diff against the committed
   `probe/fixtures/sim-terminal.expected` oracle, never the probe's self-exit.
3. **Both** seeded mutants are re-run and turn the gate red — `probe/mutants/drop-allow-newer` at a
   version-mismatch/compile-fail locus and `probe/mutants/perturb-sim-schedule` at a terminal-state mismatch —
   together proving the gate detects an unbuildable config and a wrong-terminal-state sim rather than
   rubber-stamping a green one.
4. **Or** the consolidated `allow-newer`/patch/fork set is recorded with its matching green transcripts
   (branch-1), or the exact blocker with verbatim per-remediation-class failing output (branch-2), in the
   tracker's Toolchain section. All transcripts are retained and the proven/tested/assumed ledger is emitted —
   the Phase-1 acceptance condition. Prose in the tracker without matching retained transcripts never passes.

### Remaining Work
None. The probe remains only as a re-runnable gate harness; it is not a durable amoebius runtime module.

## Sprint 1.5: `supernova` fork + `proto-lens` codegen build probe 📋
**Status**: Planned
**Implementation**: extend `probe/probe.cabal` (the native Pulsar client's `supernova`
fork + its `proto-lens` codegen, build-only), plus the generated protobuf modules the `proto-lens` codegen
emits — implemented and retained as gate evidence.
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: the `supernova` fork and its `proto-lens` codegen resolve and compile under the
pin from a clean store — the hardest single leg, a source fork plus a codegen step, not a stock Hackage pull
— and the consolidated `drop-allow-newer` mutant reddens it. The numbered `### Validation` list below carries
the transcript, locus, and evidentiary-branch obligations.
**Docs to update**: `DEVELOPMENT_PLAN/README.md`
(the `supernova` fork ref + codegen `allow-newer`/patch set),
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
  retained transcript, under `DEVELOPMENT_PLAN/evidence/phase_1/`.

### Validation
1. The `supernova` fork + `proto-lens` codegen resolve and compile green under the pin from a clean store,
   with the retained `cabal build` transcript echoing `ghc --version`/`cabal --version` in-band and showing
   the shell-observed exit 0; the exact fork ref + `allow-newer`/patch/pin is recorded **together with** that
   green transcript (branch-1 evidentiary rule).
2. The consolidated seeded mutant `probe/mutants/drop-allow-newer` — a §M.2 dependency-resolution operator,
   and the committed mutant this build-only leg is paired against — is re-run with the fork ref/patch removed
   and turns `cabal build` red at the `supernova`/`proto-lens` resolution locus.
3. **Or** the blocker is recorded with the verbatim failing `cabal build` output **plus one failing transcript
   per remediation class** (bare `allow-newer`, source patch, fork/pin), each naming the failing package and
   the compile-fail locus. Prose alone never passes.

### Remaining Work
None. The observed fork identity, compatibility patch application, clean-store transcript, and generated
protobuf module digests are retained in the Phase-1 run bundle beneath `.build/runs/phase_1/**`.

## Sprint 1.6: Dynamic resolution and generated-output migration 📋
**Status**: Planned
**Implementation**: `cabal.project`, `tools/toolchain_requirements.json`, `tools/toolchain.py`,
`tools/toolchain_spike_gate.py`, `tools/toolchain_spike_negative_corpus.py`, `test/oracle/toolchain_spike_surfaces.tsv`,
`patches/supernova_ghc_9_12.patch`, `vendor/dual/PROVENANCE.md`; generated `.build/{toolchain,locks,proto,runs,test-surfaces,test-corpora}/**`
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: a clean run resolves twice, builds and executes every probe, produces equivalent
admissible graphs, changes no authored file, and passes tracked-path and Docker-context scans.
**Docs to update**: `DEVELOPMENT_PLAN/README.md`,
`DEVELOPMENT_PLAN/system_components.md`, and
`documents/engineering/repository_layout_doctrine.md`

### Objective

Replace permanent pins, lock/freeze files, hard-coded package/library SHA values, developer-home paths, and
committed generated evidence with dynamic run-local resolution and repository-local attestation.

### Deliverables

- Authored compatibility requirements containing no resolved path, package checksum, or solver graph.
- A tracked, reviewed disposition for both Phase-1 patch files: relocate each still-required patch to
  `patches/**` or `vendor/**`, record non-SHA upstream provenance, and delete any superseded patch.
- A `cabal.project` that references only tracked authored inputs and compatibility requirements, with no
  developer path, fixed dependency commit, or ignored evidence path.
- Replacement of `toolchain/pins.json`: keep only authored compatibility requirements in a clearly named
  source manifest and generate every resolved path, version, URL, identity, and integrity observation.
- A resolver that writes the selected graph and tools only beneath `.build/`.
- Generated protocol bindings and checksums only beneath `.build/proto/` or the build tree.
- An authored-root write guard and repository-local attestation covering every probe and mutant.
- Tracked-path and container-context checks that reject every legacy generated class.

### Validation

1. Begin from the source snapshot — non-ignored files only — and empty probe caches.
2. Resolve, build, and execute the complete representative set twice.
3. Confirm that all generated output is ignored and every authored path is unchanged.
4. Confirm that no lock/freeze file, package integrity pin, or developer-home path is tracked.
5. Confirm every referenced patch exists in the clone beneath an authored root; a seeded ignored-patch
   reference and a seeded fixed dependency commit both fail at the source-closure/provenance locus.
6. Verify the repository-local attestation and all positive, negative, and mutant outcomes.

### Remaining Work

None. Both ignored patches are dispositioned — `supernova_ghc_9_12.patch` relocated to `patches/` with non-SHA
provenance, the superseded `dual` patch deleted in favour of `vendor/dual/PROVENANCE.md`. `toolchain/pins.json`
is gone, split into authored `tools/toolchain_requirements.json` and run-local `.build/toolchain/resolved.json`.
`cabal.project` carries no developer path, frozen `index-state`, fixed revision, or ignored input. The gate
resolves twice to the same graph, resolves it again from non-ignored source alone, and publishes a verified
repository-local attestation. Cabal metadata, its package store, build roots, npm dependencies, tool downloads,
and all temp/cache homes are confined to `.build/**`; the host inventory is unchanged.

## Sprint 1.7: Discover, then ensure — the resolver acquires what it needs 📋
**Status**: Planned
**Implementation**: `tools/toolchain_requirements.json`, `tools/toolchain.py`,
`tools/host_platform.py`, `tools/gate_common.py`, `tools/toolchain_spike_gate.py`,
`tools/toolchain_spike_negative_corpus.py`,
`test/oracle/toolchain_spike_surfaces.tsv`, `pb/pb/bootstrap_toolchain.py`
**Blocked by**: Sprint 1.6
**Requires**: `host-floor` — the package-manager root and the substrate's own build prerequisites
**Independent Validation**: a run on a host carrying none of the acquirable tools resolves every requirement
and completes; a second run is a verified no-op; a requirement whose publisher offers no asset for the host's
architecture refuses rather than selecting another's.
**Docs to update**: `documents/engineering/substrate_doctrine.md`,
`documents/engineering/repository_layout_doctrine.md`, `DEVELOPMENT_PLAN/README.md`,
`DEVELOPMENT_PLAN/system_components.md`

### Objective

Adopt [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)
in the pre-binary resolver: an absent tool with a supported install plan is installed, and the only things the
host must already supply are the floor of
[§3.1](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply).

### Deliverables

- The `host` source kind retired, so no requirement can mean "expected on the developer host".
- A `managed` source kind — a tool installed by another resolved tool, which is asked what it can supply —
  generalizing the `ghcup-managed` kind the authored vocabulary already names but the resolver never
  implemented.
- The floor expressed as authored data and checked before resolution, with each failure carrying its remedy.
- One canonical `<os>-<arch>` platform token, replacing the three divergent normalizers and the inconsistent
  authored keys they compensate for.
- `node`, `npm`, and `git` declared, having been invoked bare and undeclared.
- A seeded-negative corpus for resolution behaviour, which today has none: absent tool, out-of-range version,
  and no asset for the host's architecture.

### Validation

1. Run the phase command on a host missing every acquirable tool and confirm it completes without an operator
   install, with the outside-host inventory unchanged.
2. Confirm each seeded resolution negative reddens its own check and no other.
3. Confirm the architecture refusal fires when the publisher offers no asset for the host's architecture,
   rather than a foreign asset being selected.
4. Confirm the surface join stays total after the newly declared tools are added.

### Remaining Work

The gate run that seals the phase. What is built:

| Deliverable | Where it landed |
|---|---|
| `host` retired | Three providers replace it — `ghc`/`cabal` from `ghcup`, `chromium` from the resolved Playwright driver, `dhall` from its publisher's release. The `no-host-source` check refuses a manifest that reintroduces the kind |
| `managed` kind | `provider` names one of `ghcup`, `playwright`, `package-manager`; each adapter probes, installs when absent, and asks the provider where it put the tool. `managed-idempotent` requires a second pass to install nothing |
| Floor as authored data | A `floor` section per substrate, each entry a probe and the remedy that clears it. `floor-decidable` runs every substrate's floor — including ones this host is not — and `floor-satisfied` runs this host's |
| One platform token | `tools/host_platform.py` owns the architecture vocabulary, the system vocabulary, and their join; the gate module, the resolver, and the pre-binary coordinator all read it, and every authored `platform_map` key is spelled in it |
| `node`, `npm`, `git` declared | All three are `managed` by the floor's package-manager root, version-checked, resolved to an absolute path, and joined at `toolchain.floor_supplied` |
| Resolution negatives | `choose_release` and `choose_offer` are pure and refuse in three distinguishable classes; the corpus drives both selectors with two positive controls and three negatives |

Two defects the sprint found and fixed on the way. The Temurin JRE is an application bundle on macOS, so one
authored `archive_member` resolved a path that exists on exactly one of the three platforms — the member is now
per-platform, keyed by the same canonical token. And the release-tarball unpacker stripped the first member's
first path segment unconditionally, which is right for an archive that unpacks into one versioned directory and
throws away `bin/` for one that does not.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/substrate_doctrine.md` — **done 2026-08-17.** §3.1 records that the floor tables are
  authored data evaluated before resolution, and that every substrate's floor is decided on every run,
  including the ones the running host is not.
- `documents/engineering/repository_layout_doctrine.md` — **done 2026-08-17.** §4 records the one `<os>-<arch>`
  platform vocabulary, the single normalizer that produces it, and the rule that a publisher with no asset for
  the host's token is a refusal rather than a fallback.
- `documents/engineering/repository_layout_doctrine.md` — **done 2026-08-12.** The migration table records
  `toolchain/pins.json` as split into authored `tools/toolchain_requirements.json` and run-local
  `.build/toolchain/resolved.json`; the tree drops `cabal.project.freeze` and names the requirements manifest.
- `documents/engineering/dsl_doctrine.md` — §9's Toolchain note gets a backlink to the recorded `dhall`
  `allow-newer`/patch set once Sprint 1.2/1.4 lands.
- `documents/engineering/gateway_migration_model_doctrine.md` — §4's io-sim instrument gets a backlink to the
  proven `io-sim`/`io-classes` build.
- `documents/engineering/content_addressing_doctrine.md` — §4.5's `jit-build` resolver gets a backlink to the
  proven resolver-deps build.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — the Toolchain section records only the authored compatibility policy or a
  current blocker; resolved `allow-newer`, patch application, source identity, and graph observations remain
  in the run bundle. Flip the Phase 1 status only when the gate passes.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-1 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `cabal.project` and the throwaway `probe/` package as
  Phase-1 pre-flight rows, marked deleted-after-resolution.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves; the sole home of the
  current phase status. Resolved tool and dependency observations live only in each generated run bundle.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the Register-1 honesty token: a green build is a buildability result, never a runtime claim).
- [overview.md](overview.md) — target architecture and the dynamically resolved toolchain policy.
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — the Register-1
  pre-cluster spine and the rendering-never-touches-live-infrastructure invariant.
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — the in-process `dhall` decoder (gadt-decode) and the
  Toolchain note this probe de-risks.
- [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) — the one
  formal obligation whose io-sim simulation depends on this build.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — the `Model`→{`interpret`,
  `emitTLA`} mechanism whose spike is sibling evidence, not an amoebius result.
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md) — the `jit-build`
  resolver and the `CacheBudget`-bounded cache whose deps this probe includes.
- [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md) — the
  authored requirements, generated resolution, repository-local evidence, and ignore/context contract that Sprint 1.6
  implements.
