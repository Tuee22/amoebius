# Phase 1: Haskell toolchain and probe-source closure

> **Purpose**: Specify the target Haskell capability to derive a compatible toolchain at run time
> and build the required decoder, simulator, resolver, browser-contract, and protocol-codegen probes
> without committing resolution output, integrity pins, generated code, or host-specific paths.
> **Read this if**: phase 1 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, documents/engineering/content_addressing_determinism.md, documents/engineering/pulsar_client_doctrine.md, vendor/dual/PROVENANCE.md, vendor/supernova/PROVENANCE.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 1.1: Historical shared-resolution spike ⏸️](#sprint-11-historical-shared-resolution-spike-)
- [Sprint 1.2: `dhall` in-process decoder build probe (gadt-decode dependency) ⏸️](#sprint-12-dhall-in-process-decoder-build-probe-gadt-decode-dependency-)
- [Sprint 1.3: `io-sim` + `io-classes` simulation build probe ⏸️](#sprint-13-io-sim--io-classes-simulation-build-probe-)
- [Sprint 1.4: jit-build resolver deps + `purescript-bridge` + consolidated probe gate ⏸️](#sprint-14-jit-build-resolver-deps--purescript-bridge--consolidated-probe-gate-)
- [Sprint 1.5: `supernova` fork + `proto-lens` codegen build probe ⏸️](#sprint-15-supernova-fork--proto-lens-codegen-build-probe-)
- [Sprint 1.6: Dynamic resolution and generated-output migration ⏸️](#sprint-16-dynamic-resolution-and-generated-output-migration-)
- [Sprint 1.7: Discover, then ensure — the resolver acquires what it needs ⏸️](#sprint-17-discover-then-ensure--the-resolver-acquires-what-it-needs-)
- [Sprint 1.8: Remove top-level vendor source and own the Haskell fork ⏸️](#sprint-18-remove-top-level-vendor-source-and-own-the-haskell-fork-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 0, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to derive a compatible toolchain at run time and build the required decoder,
simulator, resolver, browser-contract, and protocol-codegen probes without committing resolution
output, integrity pins, generated code, or host-specific paths.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to validate or
promote its claim.

**Phase scope:** Target capability only — derive a compatible toolchain at run time and build the
required decoder, simulator, resolver, browser-contract, and protocol-codegen probes without
committing resolution output, integrity pins, generated code, or host-specific paths. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 0](phase_00_documentation_suite.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 01`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target capability only — derive a compatible toolchain at run time and build the required decoder, simulator, resolver, browser-contract, and protocol-codegen probes without committing resolution output, integrity pins, generated code, or host-specific paths. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 01` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: Phase-1-owned `LTD-SRC-007` and `LTD-SRC-009` remain active; their exact zero-finding checks, reintroduction negatives, and independently reviewed Haskell bindings have not been accepted. Sprint 1.8 names `LTD-SRC-009`, but no rewritten sprint owns `LTD-SRC-007`; that missing assignment is itself blocking. |
| `Predecessor` | MISSING — blocks validation: the current Phase 00 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`conformance_harness_doctrine.md` §2 — The registers, as amoebius uses them for pre-cluster validation](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
  and its [`conformance_harness_doctrine.md` §3 — The load-bearing invariant: rendering never touches live infrastructure](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure):
  the target is Register 1 and cannot consult live infrastructure, credentials, or a broker.
- [`dsl_doctrine.md §9 — Toolchain note`](../documents/engineering/dsl_doctrine.md#9-toolchain-note), read
  with [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  the target Haskell probe must resolve the in-process decoder dependency dynamically; any foreign decoder
  input or output is generated lazily beneath `.build/**`, and no compatible set is currently established.
- [`gateway_migration_model_doctrine.md §4 — Simulate and prove`](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove):
  the target probe covers the Haskell deterministic-simulation dependency only; it makes no model-checking
  result or runtime-fidelity claim.
- [`formal_model_doctrine.md §7 — Prototype validation`](../documents/engineering/formal_model_doctrine.md#7-prototype-validation):
  any TLA+ representation is a lazy `.build/**` product of a Haskell model value; historical sibling-spike
  observations are permanently inadmissible as amoebius validation evidence.
- [`content_addressing_determinism.md` §4.5 — The ML-asset lifecycle: one bounded content-addressed cache, resolved on first miss](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
  the target Haskell probe must cover the resolver dependencies without tracking materialized engines,
  models, kernels, solver output, or pins.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and a human tracker change.

## Sprint 1.1: Historical shared-resolution spike ⏸️

**Status**: Blocked — NOT VALIDATED

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
The pre-reset record said `None` and claimed validation by a consolidated Phase-1 gate on 2026-08-08; both
statements are permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING`
contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 1.2: `dhall` in-process decoder build probe (gadt-decode dependency) ⏸️

**Status**: Blocked — NOT VALIDATED

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
- Haskell-declared positive and bad-type probe cases plus separately authored Haskell expected decoded value
  and rejection tag; any Dhall form is generated beneath `.build/probe/**` and is never tracked source.

### Validation
1. A probe depending on `dhall` builds under the pin from a clean store, and `cabal run probe:decode` decodes
   the generated positive case into its independently expected Haskell value and exits 0. A green `cabal build`
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
The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The positive decode matched byte-for-byte and the negative failed at `DHALL_TYPE_ERROR` in the retained
2026-08-08 gate evidence.

## Sprint 1.3: `io-sim` + `io-classes` simulation build probe ⏸️

**Status**: Blocked — NOT VALIDATED

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
The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The external terminal-state oracle passed and the schedule perturbation mutant was killed on 2026-08-08.

## Sprint 1.4: jit-build resolver deps + `purescript-bridge` + consolidated probe gate ⏸️

**Status**: Blocked — NOT VALIDATED

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
The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The probe remains only as a re-runnable gate harness; it is not a durable amoebius runtime module.

## Sprint 1.5: `supernova` fork + `proto-lens` codegen build probe ⏸️

**Status**: Blocked — NOT VALIDATED

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
The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The observed fork identity, compatibility patch application, clean-store transcript, and generated
protobuf module digests are retained in the Phase-1 run bundle beneath `.build/runs/phase_1/**`.
[Sprint 1.8](#sprint-18-remove-top-level-vendor-source-and-own-the-haskell-fork-) supersedes the first two of
those: a maintained Haskell fork has amoebius-owned modules under `src/vendor/**`, while any upstream
non-Haskell inputs and transformation products are resolved lazily beneath `.build/vendor/**`.

## Sprint 1.6: Dynamic resolution and generated-output migration ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Replace permanent pins, lock/freeze files, hard-coded package/library SHA values, developer-home paths, and
committed generated evidence with dynamic run-local resolution and repository-local attestation.

### Deliverables

- Authored compatibility requirements containing no resolved path, package checksum, or solver graph.
- A reviewed Haskell transformation declaration for each still-required compatibility change; delete the
  tracked patch and top-level vendor copies, and materialize any upstream input or patch encoding beneath
  `.build/vendor/**` only.
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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. The pre-reset patch and pin dispositions are historical inventory only. The target keeps toolchain compatibility requirements in Haskell declarations and may render resolution input/output only beneath `.build/toolchain/**`; neither `toolchain/pins.json` nor `tools/toolchain_requirements.json` is admitted source.
`cabal.project` carries no developer path, frozen `index-state`, fixed revision, or ignored input. The gate
resolves twice to the same graph, resolves it again from non-ignored source alone, and publishes a verified
repository-local attestation. Cabal metadata, its package store, build roots, npm dependencies, tool downloads,
and all temp/cache homes are confined to `.build/**`; the host inventory is unchanged.

## Sprint 1.7: Discover, then ensure — the resolver acquires what it needs ⏸️

**Status**: Blocked — NOT VALIDATED

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
| One platform token | Historical inventory only: `tools/host_platform.py` formerly supplied a shared token to condemned gates and the pre-binary handoff. This is non-operative source debt; the replacement vocabulary and decisions must be Haskell, while Python may make only its minimal adapter-selection distinction. |
| `node`, `npm`, `git` declared | All three are `managed` by the floor's package-manager root, version-checked, resolved to an absolute path, and joined at `toolchain.floor_supplied` |
| Resolution negatives | `choose_release` and `choose_offer` are pure and refuse in three distinguishable classes; the corpus drives both selectors with two positive controls and three negatives |

Two defects the sprint found and fixed on the way. The Temurin JRE is an application bundle on macOS, so one
authored `archive_member` resolved a path that exists on exactly one of the three platforms — the member is now
per-platform, keyed by the same canonical token. And the release-tarball unpacker stripped the first member's
first path segment unconditionally, which is right for an archive that unpacks into one versioned directory and
throws away `bin/` for one that does not.

## Sprint 1.8: Remove top-level vendor source and own the Haskell fork ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/vendor/**/*.hs`, reviewed Haskell provenance/acquisition declarations
**Blocked by**: Sprint 1.7 replacement contract and Phase 0 human approval
**Independent Validation**: An immutable-input clean build is the positive; a mutable-ref acquisition is the paired negative; an applied top-level-vendor reintroduction mutant reddens its exact source row while the Haskell control stays green; upstream semantic fidelity and licensing remain explicit residue.
**Oracle**: planned separately authored `test/Amoebius/Vendor/ProvenanceOracle.hs`; provenance, independence boundary, and human reviewer unresolved
**Legacy IDs**: `LTD-SRC-009`
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/pulsar_client_doctrine.md`

### Objective

Adopt [`repository_layout_doctrine.md` §4.1 — a compatibility edit is fixed source, not a patch against a
moving head](../documents/engineering/repository_layout_doctrine.md#41-a-compatibility-edit-is-fixed-source-not-a-patch-against-a-moving-head):
remove the transitional top-level `vendor/**` tree. Re-derive only maintained Haskell behavior under
`src/vendor/**/*.hs`; acquire any required upstream non-Haskell source at an immutable identity beneath
`.build/vendor/**` and apply transformations declared in Haskell.

### Deliverables

- `vendor/**` absent from the tracked snapshot, with maintained Haskell modules re-derived under
  `src/vendor/**` and separately reviewed against Haskell expectations.
- Haskell provenance values recording an immutable upstream release identity; any reader-facing provenance
  report is generated beneath `.build/**` and is not a build input.
- A `cabal.project` that reaches only admitted tracked Haskell packages and carries no mutable `supernova`
  source reference or post-checkout command.
- `patches/supernova_ghc_9_12.patch` and `tools/apply_supernova_patch` deleted, and the `patches/` root with
  them.
- Haskell-generated negatives that reintroduce a top-level vendor path, a mutable `supernova` source, a
  tracked Proto/Cabal input, and a patch program; each reddens its exact source-closure/provenance locus.

### Validation

1. From a clean source snapshot and empty `.build/**`, the representative set resolves the immutable upstream
   input, generates required foreign build inputs, and builds the maintained Haskell fork.
2. The tracked snapshot contains no `vendor/**`, patch program, Proto input, foreign package description, or
   generated binding; all such material is contained beneath the fresh run root.
3. Each generated reintroduction negative reddens only its named source-closure or provenance check, while an
   unaffected Haskell control remains green.
4. The Haskell provenance declaration rejects mutable refs, absent identity, developer-home paths, and a
   digest that does not match the acquired bytes.

### Remaining Work

`LTD-SRC-009` remains open: the top-level vendor tree is still tracked and the Haskell provenance,
materialization, independent oracle, and generated reintroduction corpus do not yet exist. This sprint cannot
become a candidate until Phase 0 is human-approved and the row's exact Haskell closure predicate is green.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/substrate_doctrine.md` — **historical pre-reset note from 2026-08-17 — permanently invalid for promotion.** §3.1 records that the floor tables are
  authored data evaluated before resolution, and that every substrate's floor is decided on every run,
  including the ones the running host is not.
- `documents/engineering/repository_layout_doctrine.md` — **historical pre-reset note from 2026-08-17 — permanently invalid for promotion.** §4 records the one `<os>-<arch>`
  platform vocabulary, the single normalizer that produces it, and the rule that a publisher with no asset for
  the host's token is a refusal rather than a fallback.
- `documents/engineering/repository_layout_doctrine.md` — **historical pre-reset note from 2026-08-12 — permanently invalid for promotion.** The target replaces both
  `toolchain/pins.json` and `tools/toolchain_requirements.json` with Haskell compatibility declarations and
  run-local `.build/toolchain/**` projections; `cabal.project.freeze` remains inadmissible.
- `documents/engineering/dsl_doctrine.md` — §9's Toolchain note gets a backlink to the recorded `dhall`
  `allow-newer`/patch set once Sprint 1.2/1.4 lands.
- `documents/engineering/gateway_migration_model_doctrine.md` — §4's io-sim instrument gets a backlink to the
  proven `io-sim`/`io-classes` build.
- `documents/engineering/content_addressing_doctrine.md` — §4.5's `jit-build` resolver gets a backlink to the
  proven resolver-deps build.
- `documents/engineering/repository_layout_doctrine.md` — **historical pre-reset note from 2026-08-20 — permanently invalid for promotion.** The `patches/**` tree row and
  its TRANSITIONAL marker are deleted; §2 records why the root is absent rather than transitional, §2.2 no
  longer carries a destination row for it, and §4.1 states that there is no patch root and no admitted patch.
- `documents/engineering/pulsar_client_doctrine.md` — §4 identifies the current top-level vendor tree as
  migration debt and the target split between maintained `src/vendor/**/*.hs` and lazy `.build/vendor/**`
  acquisition.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — the Toolchain section records only the authored compatibility policy or a
  current blocker; resolved `allow-newer`, patch application, source identity, and graph observations remain
  in the run bundle. Flip the Phase 1 status only when the gate passes.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-1 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `cabal.project` and the throwaway `probe/` package as
  Phase-1 pre-flight rows, marked deleted-after-resolution; identify top-level `vendor/**` only as
  `LTD-SRC-009` migration debt.

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
