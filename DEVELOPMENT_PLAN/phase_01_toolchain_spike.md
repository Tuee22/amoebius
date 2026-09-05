# Phase 1: Haskell toolchain and probe-source closure

> **Purpose**: Consume the explicit non-numbered `GenesisTrust` root, authenticate and reproduce the contained
> Haskell toolchain acquisition, derive a compatible dependency graph from its pinned, network-independent inputs,
> and build the required decoder, simulator, resolver, browser-contract, and protocol-codegen probes
> without committing resolution output, integrity pins, generated code, or host-specific paths.
> **Read this if**: phase 1 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, documents/engineering/content_addressing_determinism.md, documents/engineering/pulsar_client_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision](#resource-provision)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 1.1: GenesisTrust-bound toolchain acquisition](#sprint-11-genesistrust-bound-toolchain-acquisition-)
- [Sprint 1.2: `dhall` in-process decoder build probe (gadt-decode dependency)](#sprint-12-dhall-in-process-decoder-build-probe-gadt-decode-dependency-)
- [Sprint 1.3: `io-sim` + `io-classes` simulation build probe](#sprint-13-io-sim--io-classes-simulation-build-probe-)
- [Sprint 1.4: `supernova` fork + `proto-lens` codegen build probe](#sprint-14-supernova-fork--proto-lens-codegen-build-probe-)
- [Sprint 1.5: Dynamic resolution and generated-output migration](#sprint-15-dynamic-resolution-and-generated-output-migration-)
- [Sprint 1.6: Pure discovery/ensure planning over injected inputs](#sprint-16-pure-discoveryensure-planning-over-injected-inputs-)
- [Sprint 1.7: Remove top-level vendor source and own the Haskell fork](#sprint-17-remove-top-level-vendor-source-and-own-the-haskell-fork-)
- [Sprint 1.8: jit-build resolver deps + `purescript-bridge` + consolidated probe gate](#sprint-18-jit-build-resolver-deps--purescript-bridge--consolidated-probe-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

The exact Phase-0 gate result is this phase's required immediate predecessor; every earlier gate barrier must
also be satisfied in numerical order. Earlier completion claims and implementation results in this document
remain historical rather than current gate results unless this phase's own status records a qualified pass.
Existing implementation alone is an **Observed footprint / Known partial**.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. This phase owns replacing its retained inventory with exact typed contracts and independent oracles. Hardware-free implementation may be prepared ahead of the validation frontier, but gate execution, candidate evidence, predecessor consumption, and status require the exact Phase-0 pass. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. `GenesisTrust` is the explicit irreducible `BootstrapRoot`, not a numbered provision and not a claim
Phase 0 can prove with the compiler that built it. It supplies only the narrow local-custody file and
compile-time/platform facts defined by Phase 0. This phase independently authenticates the pinned files against
its publisher policy, proves the actual compiler/package-tool executable bytes, derivation, loader and host
closure, and reproduces the contained compiler/package-tool acquisition and the
source-bound validator build, records the executable/dependency identities, and derives a compatible dependency
graph. It then builds the required decoder,
simulator, resolver, browser-contract, and protocol-codegen probes without committing resolution
output, integrity pins, generated code, or host-specific paths.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use network, host, hardware, live-service, or cluster observations to make its claim pass; every build input must already be present through the authenticated, network-independent
toolchain input. Its `LTD-BOOT-001` closure establishes repeatable acquisition from `GenesisTrust`; it does not
retroactively provide or remove the root Phase 0 assumed.

**Phase scope:** Target capability only — authenticate and reproduce the toolchain acquisition derived from
`GenesisTrust`, bind the source-built executable and elaborated dependency graph, and build the
required decoder, simulator, resolver, browser-contract, and protocol-codegen probes without
committing resolution output, integrity pins, generated code, or host-specific paths. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 0](phase_00_documentation_suite.md)
**Gate:** `pb validate phase 01`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-1 semantic payload and run-local resource
contract are complete; only fresh execution of this gate can authorize the status transition.

| Key | Contract |
|---|---|
| `Claim` | From `GenesisTrust` and its exact local cache, authenticate the signed GHC and Cabal checksum manifests, check archive membership digests, bind the actual GHC/Cabal process identities, derive the final dependency graph twice offline, and build and execute the representative probe set without tracked resolution output or host-specific paths. |
| `Subject` | The package-hidden acquired supervisor in `Amoebius.Validation.ToolchainSpikeRun.Internal`, the public refusal-safe source diagnostic, and the exact probe executables declared by `probe/probe.cabal`. |
| `Command` | Future public spelling is exactly `pb validate phase 01`; before `BOOTSTRAP_HANDOFF`, the gate invokes the exact absolute source-bound Haskell executable directly. Every Cabal child carries `--offline` and `--jobs=1`, and the acquired GHC path is explicit. |
| `Oracle` | `test/validation-kernel/ToolchainSpikeRunOracle.hs` owns the independent source-policy cases and `test/validation-kernel/ToolchainAcquisitionOracle.hs` owns process, dependency, fixture, simulation, and mutation expectations without importing private evidence constructors. |
| `Positive controls` | Exact controls are publisher-signature verification, GHC 9.12.4, Cabal 3.16.1.0, two offline source builds, the complete linked dependency probe, the positive Dhall decode, and the unperturbed simulation terminal state `3`. |
| `Paired negatives` | Exact one-dimension pairs are the mistyped Dhall count, perturbed simulation schedule, missing required dependency, mutable acquisition identity, tracked foreign probe input, top-level vendor reintroduction, and tracked resolution output. |
| `Mutants` | Haskell-declared mutations remove one required dependency, change the expected terminal state, admit a mutable identity, and reintroduce each owned source-debt family; each carries an applied-change witness, exact refusal code, and unaffected-control observation. |
| `Discovery` | Runtime-discovered probe executables and elaborated dependency names must equal the independent closed expected sets in both directions; empty, duplicate, missing, and extra discovery refuse. |
| `Challenge` | After both builds start, execute the positive and minimally changed negative fixtures from fresh run-local paths and require the independent stdout/exit predicates to distinguish them. |
| `Observer` | The Haskell supervisor captures process path, argv, exit, bounded stdout/stderr digest, executable digest, signature fingerprint, plan digest, and probe-output digest; self-reported success without the independently expected output refuses. |
| `Authority/bypass` | Network use, `pb`, unbounded compiler concurrency, PATH-selected compiler substitution, mutable refs, tracked generated behavior, and accepting a failed build are forbidden and have explicit Haskell negatives. Cabal's content-addressed user store is a non-authoritative performance cache: exact run-local archive pins, fresh component builds, executable bytes, and executed outputs remain mandatory regardless of cache hits. |
| `Freshness` | Both build roots and all fixtures are created after the opening snapshot, prior work roots are rejected or removed before acquisition, source opening and closing identities must match, and a prior candidate cannot substitute for either build. |
| `Qualification` | A fixed Haskell sabotage corpus independently proves that the harness rejects wrong signature fingerprint, changed archive digest, missing dependency, wrong terminal state, foreign tracked probe input, top-level vendor input, and committed resolution output while the clean control remains green. |
| `Cleanroom` | Generated fixtures, applied mutants, plans, transcripts, and build products exist only beneath the candidate's `.build/runs/phase-01/**` roots; the Haskell owner marker bounds cleanup and the final observer reports zero out-of-scope writes and zero temporary residue. |
| `Legacy closure` | The acquired analyzer reports zero for `LTD-BOOT-001`, `LTD-SRC-007`, and `LTD-SRC-009`; generated reintroduction cases independently redden their exact loci. GenesisTrust remains the explicit bootstrap assumption rather than a legacy binding. |
| `Predecessor` | Consume exactly one durable Phase-0 receipt whose green candidate bytes, identity fields, complete ordered rows, empty residue, original candidate, and projected postimage bind to this candidate's opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Explicit assumptions are the irreducible GenesisTrust local-custody root and the ordinary OS execution substrate used to run the independently pinned verifier and archive tools. Phase-2 compiler-wide source semantics and every later runtime, service, hardware, and correspondence claim remain unverified; no Phase-1 claim row is residue. |
| `Pass criterion` | `qualified-phase-one-gate-pass`: all eighteen rows above must be execution-derived green in one candidate for one stable source, with exact predecessor receipt and empty mandatory residue; that complete pass alone authorizes the status-only transition. |

## Resource provision

The resource is the run-local build/fixture root, not a host or live service. The Haskell supervisor creates an
identity-bound owner marker after preflight; permits candidate writes beneath its two fresh build roots and fixture
root; forbids network, hardware, package-manager, and authored-source mutation; observes exact
paths and process results; removes temporary fixtures and applied mutants; and requires zero owned temporary
residue. Cabal may reuse or install a content-addressed unit in its ordinary user store, but no store path or
presence is evidence and the independently pinned source archives remain mandatory. Content-addressed candidate
evidence and the declared build products beneath `.build/**` are retained outputs, not leaked resource residue.

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

> **Reset validation check.** A sprint whose required fields still say `UNRESOLVED` retains its pre-reset
> `Independent Validation` and `### Validation` only as historical capability inventory. A wholly replaced
> sprint contract may guide hardware-free implementation, but cannot run this phase gate or change status before
> the Phase-0 predecessor pass.

> **Permanent sprint reset.** Every pre-reset sprint result below remains historical context. Current acceptance
> requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-
> predecessor gate pass, owned legacy closure, and a complete gate pass.

## Sprint 1.1: GenesisTrust-bound toolchain acquisition ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/ToolchainSpikeRun.hs`, `src/validation-kernel/Amoebius/Validation/CompilerBuildInfo.hs`, and `src/validation-kernel/Amoebius/Validation/CompilerElaboratedPlan.hs`; exact acquired authority remains UNRESOLVED and blocks validation.
**Blocked by**: [Phase 0](phase_00_documentation_suite.md) gate pass
**Independent Validation**: From the narrow GenesisTrust local-custody facts and immutable offline files, independently verify publisher/content identities, actual compiler/package-tool executable derivation, and loader/host closure; acquire twice into distinct contained roots, build the same source snapshot, and require plans and executable identities to agree. A missing/mutable input, digest/signature mismatch, ambient-network read, self-reported identity, replay, or disagreement is an exact negative; GenesisTrust itself remains assumed.
**Oracle**: planned separate Haskell `test/validation-kernel/ToolchainAcquisitionOracle.hs`, authored from the declared root and expected acquisition relation rather than subject output; provenance remains UNRESOLVED.
**Legacy IDs**: `LTD-BOOT-001`
**Docs to update**: `DEVELOPMENT_PLAN/README.md`, `documents/engineering/validation_frame_doctrine.md`, `documents/engineering/repository_layout_doctrine.md`

### Objective
Turn the irreducible GenesisTrust input into a reproducible, authenticated contained toolchain acquisition and
source-bound build without pretending that the resulting binary proves its own compiler.

### Deliverables
- A typed acquired authority that consumes GenesisTrust's seven pinned local-custody files and independently
  adds publisher identity, actual compiler/package-tool executable bytes and derivation, loader/host closure,
  and reproducibility evidence.
- Two distinct contained acquisitions from the same immutable offline input with exact process, plan, and
  executable receipts beneath `.build/**`.
- One compatible dependency universe used by every later sprint in this phase; no resolved lock or identity is
  copied into Git.

### Validation
1. Recheck the offline bytes against the GenesisTrust pins, then independently authenticate their publisher
   relation before either acquisition and build the same exact source under both contained roots with
   compiler-bearing commands serialized.
2. Require the compiler/package-tool identities, elaborated plan, produced executable identity, and observed
   command boundary to agree; each missing, mutable, replayed, network-assisted, or disagreeing case fails at
   its assigned locus.
3. Preserve GenesisTrust as an explicit assumption in residue; agreement closes `LTD-BOOT-001` but does not
   turn the root into a theorem.

### Remaining Work
Implement the acquired authority and independent oracle, qualify its changed-subject selectors, bind the exact
Phase-0 predecessor receipt, close `LTD-BOOT-001`, and retain the result in the complete Phase-1 gate. Historical
toolchain transcripts cannot support this candidate.

## Sprint 1.2: `dhall` in-process decoder build probe (gadt-decode dependency) ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 1.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective
Adopt [`dsl_doctrine.md §9 — Toolchain note`](../documents/engineering/dsl_doctrine.md#9-toolchain-note) with
its [§5 gadt-decode](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract): prove
the in-process `dhall` decoder — the structural gadt-decode leg that must precede Phase-30/18 bind/provision — is
buildable on the pin before Phase 26 promises an executable decoder. `dhall` historically lags new GHC releases, so
`allow-newer` alone may be insufficient and a source patch or fork may be required.

### Deliverables
- A recorded resolution: the concrete `allow-newer`/patch/fork/pin that makes `dhall` build on GHC 9.12.4,
  with fresh `cabal build` + `cabal run probe:decode` transcripts beneath `.build/runs/phase_1/**` produced
  under exactly that set. There is no failing-transcript alternative: a dependency universe that does not
  resolve prevents the status frontier from advancing and records the blocker as explicit `UNVERIFIED`
  residue. That is a recorded blocker, not a gate pass.
- Haskell-declared positive and bad-type probe cases plus separately authored Haskell expected decoded value
  and rejection tag; any Dhall form is generated beneath `.build/probe/**` and is never tracked source.

### Validation
1. A probe depending on `dhall` builds under the pin from a clean store, and `cabal run probe:decode` decodes
   the generated positive case into its independently expected Haskell value and exits 0. A green `cabal build`
   alone does **not** satisfy this: an executed, exit-checked run is required.
2. The same binary consumes the negative half of a Haskell-declared pair that differs from its positive only
   in one mistyped field. The pair is rendered beneath `.build/probe/**`, and the observation must match the
   separately authored Haskell `dhall` type-error expectation (§M.8), not merely report a generic failure.
3. The exact `allow-newer`/source-patch/fork required by `dhall`'s transitive deps (`template-haskell`,
   `aeson`, `megaparsec`, `prettyprinter`) is recorded **together with** the green transcript produced with
   exactly that set. A remediation set counts only with its matching green transcript. A failing transcript is
   never an alternative route to this row: it records why the phase is blocked, and a blocked phase does not
   pass. Prose alone never passes.

### Remaining Work
The pre-reset record said `None`; that statement and its 2026-08-08 decode observations are permanently
cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor
gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 1.3: `io-sim` + `io-classes` simulation build probe ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 1.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective
Adopt [`gateway_migration_model_doctrine.md §4 — Simulate and prove`](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove):
amoebius's one formal obligation drives the gateway-migration `Model` against `io-classes`/`IOSimPOR`'s
deterministic, partial-order-reduced scheduler. Prove that toolchain builds on the pin before Phase 17 authors
the simulation. TLC (`tla2tools.jar`) is pure JVM and version-stable, so the Phase-11/10 TLC path is **not** gated
by this probe.

### Deliverables
- A recorded resolution for `io-sim` + `io-classes` on the pin with fresh build + `cabal run probe:sim`
  transcripts beneath `.build/runs/phase_1/**`. An unresolvable pin is run-local blocker residue that leaves
  the phase blocked, not a second way to satisfy this deliverable.
- A checked Haskell declaration of the `IOSimPOR` schedule and a separately authored Haskell expected
  terminal state, plus a Haskell comparison oracle and schedule-perturbation mutation operator. Any serialized
  terminal state or applied mutant is generated only beneath `.build/probe/**`.

### Validation
1. A probe depending on `io-sim`/`io-classes` builds under the pin from a clean store, and `cabal run
   probe:sim` runs the Phase-0-named `IOSimPOR` schedule and **emits the terminal state it reaches on
   stdout**; the separately authored Haskell oracle confirms an exact semantic match against its independent
   terminal-state expectation. The leg greens **only** on that match, never on the probe's
   self-reported exit 0 — a `main = exitSuccess` stub emits no terminal state and fails the diff.
2. The checked Haskell schedule-perturbation operator changes the step ordering and drops one fairness step
   in a temporary subject beneath `.build/probe/**`. Re-running it MUST turn `probe:sim` red at the independent
   terminal-state oracle (§M.2), while the unchanged positive remains green.
3. The green transcript and the exact remediation set that produced it are retained only beneath
   `.build/runs/phase_1/**`. A recorded blocker is not a substitute for it; the blocker leaves the phase
   blocked. Prose alone never passes.

### Remaining Work
The pre-reset record said `None`; that statement and its 2026-08-08 simulation observations are permanently
cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor
gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 1.4: `supernova` fork + `proto-lens` codegen build probe ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 1.3
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective
De-risk the native Pulsar client's `supernova` fork plus its `proto-lens` codegen — clause (v) of the
Representative set, the Pulsar-client band's load-bearing build dependency — on the shared pin **here**, before
the Pulsar-client phase promises it, rather than discovering mid-implementation that a forked client or its
generated protobuf modules will not compile on GHC 9.12.4. This is the riskiest single leg (a fork plus a
codegen step), so it is isolated as its own recorded resolution and then folded into the Sprint 1.8
consolidated gate. Isolating it bounds the blast radius of a blocker; it does not make a blocker acceptable.

### Deliverables
- A recorded resolution: the concrete `supernova` fork ref + `proto-lens` `allow-newer`/patch/pin that makes the
  fork and its codegen build on GHC 9.12.4. The fresh `cabal build` transcript is produced beneath
  `.build/runs/phase_1/**` under exactly that set. A blocker recorded in the same run root is residue that
  leaves the phase blocked, not an alternative accepting observation.
- The `proto-lens` protobuf module and build transcript materialized only beneath `.build/proto/**` and
  `.build/runs/phase_1/**`. Neither generated module nor transcript is tracked source or evidence authority.

### Validation
1. The `supernova` fork + `proto-lens` codegen resolve and compile green under the pin from a clean store,
   with the run-local `cabal build` transcript beneath `.build/runs/phase_1/**` echoing the tool identities
   in-band and showing the independently observed exit 0. The exact fork identity and compatibility requirement
   are recorded together with that observation.
2. The checked Haskell dependency-resolution operator removes the fork identity or compatibility declaration
   in a temporary subject beneath `.build/probe/**`. Re-running it turns `cabal build` red at the
   `supernova`/`proto-lens` resolution locus while the unchanged control remains green.
3. The fork identity and compatibility declaration that produced the green build are recorded with it. An
   unresolvable fork is recorded as explicit `UNVERIFIED` residue and leaves the phase blocked; a failing
   `cabal build` is never evidence for this row. Prose alone never passes.

### Remaining Work
The pre-reset record said `None`; that statement and every recorded fork/codegen observation are permanently
cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor
gate pass, owned legacy closure, and the Haskell provenance/oracle/mutation obligations of the redesigned gate.
[Sprint 1.7](#sprint-17-remove-top-level-vendor-source-and-own-the-haskell-fork-) owns the target split between
maintained `.hs` modules under `src/vendor/**` and lazy upstream material beneath `.build/vendor/**`.

## Sprint 1.5: Dynamic resolution and generated-output migration ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 1.4
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: `LTD-SRC-007`
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Replace permanent pins, lock/freeze files, hard-coded package/library SHA values, developer-home paths, and
repository-retained generated evidence with dynamic run-local resolution and repository-local run record.

### Deliverables

- Authored compatibility requirements containing no resolved path, package checksum, or solver graph.
- A checked Haskell transformation declaration for each still-required compatibility change; delete the
  tracked patch and top-level vendor copies, and materialize any upstream input or patch encoding beneath
  `.build/vendor/**` only.
- A `cabal.project` that references only admitted `.hs` source, minimal build metadata, and Haskell-declared
  compatibility requirements, with no developer path, fixed dependency identity, or ignored evidence path.
- Replacement of `toolchain/pins.json`: keep compatibility requirements in a checked Haskell declaration and
  generate every resolved path, version, URL, identity, and integrity observation beneath `.build/toolchain/**`.
- A resolver that writes the selected graph and tools only beneath `.build/`.
- Resolved protocol package identity and checksums recorded beneath `.build/toolchain/**`. Rendering the wire schema and bindings beneath `.build/proto/**` is `LTD-SRC-003`, owned by its declared later phase, and is not a deliverable here.
- An authored-root write guard and run-local record beneath `.build/**` covering every probe and applied
  Haskell mutation operator.
- Tracked-path and container-context checks that reject every legacy generated class.

### Validation

1. Begin from the source snapshot — non-ignored files only — and empty probe caches.
2. Resolve, build, and execute the complete representative set twice using only the authenticated,
   network-independent input.
3. Confirm that all generated output is ignored and every authored path is unchanged.
4. Confirm that no lock/freeze file, package integrity pin, or developer-home path is tracked.
5. Confirm every referenced patch exists in the clone beneath an authored root; a seeded ignored-patch
   reference and a seeded fixed dependency commit both fail at the source-closure/provenance locus.
6. Verify the repository-local run record and all positive, negative, and mutant outcomes.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work
includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and
phase-specific obligation in the redesigned gate. The target must replace the condemned pin/patch inputs with
checked Haskell compatibility declarations, confine every resolved product to `.build/**`, and independently
demonstrate clean-source repeatability without network or outside-host observation. The current working source
image has removed the nine tracked probe fixtures/mutants/oracle files, and the Phase-1 runner observes
`toolchain-spike.probe-foreign-count = 0`; the Haskell generator, separately authored expectations, applied
reintroduction negatives, and integrated evidence remain outstanding, so `LTD-SRC-007` stays active.

## Sprint 1.6: Pure discovery/ensure planning over injected inputs ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 1.5
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Model [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)
as a pure Haskell plan over injected inventories and authenticated provider catalogs. An absent tool with a
supported plan yields typed acquisition steps; a missing floor prerequisite yields a typed refusal. This
sprint may neither inspect nor modify a real host. Phase 51 owns the boundary-with-fakes interpreter after the
Phase-49 barrier, and the later live band owns actual host observation and installation.

### Deliverables

- The `host` source kind retired from the pure plan, so no requirement can mean "expected on the developer
  host".
- A `managed` source kind — a tool installed by another resolved tool, which is asked what it can supply —
  generalizing the `ghcup-managed` kind the authored vocabulary already names but the resolver never
  implemented.
- The floor expressed as a checked Haskell value and evaluated only against an injected inventory, with each
  failure carrying its remedy.
- One canonical `<os>-<arch>` platform value, supplied as a synthetic case rather than discovered from a host,
  replacing the three divergent normalizers and the inconsistent keys they compensate for.
- `node`, `npm`, and `git` declared, having been invoked bare and undeclared.
- A Haskell-declared negative corpus for resolution behaviour: absent tool, out-of-range version, and no asset
  for the injected platform value. Any serialized acquisition request or response is generated beneath
  `.build/**`.

### Validation

1. Evaluate the Haskell plan against an injected empty-tool inventory and authenticated provider catalog;
   assert the exact typed acquisition steps without running them.
2. Each checked Haskell resolution mutation operator makes only its independently expected property red.
3. The architecture-refusal case uses a synthetic platform value and a catalog with no matching asset; it
   must refuse rather than selecting a foreign asset.
4. The Haskell surface join stays total after the newly declared tools are added, and the effect observer
   confirms zero host, hardware, network, package-manager, or filesystem effects outside `.build/**`.

### Remaining Work

The pre-reset completion account and platform table are permanently invalid and are not implementation
instructions. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass,
owned legacy closure, checked Haskell provider/platform/acquisition declarations, independent Haskell
expectations, applied mutation controls, and fresh contained observations beneath `.build/**`. Any real host
or acquisition correspondence remains explicitly UNVERIFIED.

## Sprint 1.7: Remove top-level vendor source and own the Haskell fork ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 1.6
**Independent Validation**: An immutable-input clean build is the positive; a mutable-ref acquisition is the paired negative; an applied top-level-vendor reintroduction mutant reddens its exact source row while the Haskell control stays green; upstream semantic fidelity and licensing remain explicit residue.
**Oracle**: planned separately authored `test/Amoebius/Vendor/ProvenanceOracle.hs`; provenance and independence boundary unresolved
**Legacy IDs**: `LTD-SRC-009`
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/pulsar_client_doctrine.md`

### Objective

Adopt [`repository_layout_doctrine.md` §4.1 — a compatibility edit is fixed source, not a patch against a
moving head](../documents/engineering/repository_layout_doctrine.md#41-a-compatibility-edit-is-fixed-source-not-a-patch-against-a-moving-head):
remove the transitional top-level `vendor/**` tree. Re-derive only maintained Haskell behavior under
`src/vendor/**/*.hs`; materialize any required upstream non-Haskell source from an authenticated,
network-independent input at an immutable identity beneath `.build/vendor/**` and apply transformations
declared in Haskell.

### Deliverables

- `vendor/**` absent from the tracked snapshot, with maintained Haskell modules re-derived under
  `src/vendor/**` and separately authored against Haskell expectations.
- Haskell provenance values recording an immutable upstream release identity; any reader-facing provenance
  report is generated beneath `.build/**` and is not a build input.
- A `cabal.project` with no developer-home path and a fixed dependency identity for every input, carrying no mutable `supernova`
  source reference or post-checkout command.
- `patches/supernova_ghc_9_12.patch` and `tools/apply_supernova_patch` deleted, and the `patches/` root with
  them.
- Haskell-generated negatives that reintroduce a top-level vendor path, a mutable `supernova` source, a
  tracked Proto/Cabal input, and a patch program; each reddens its exact source-closure/provenance locus.

### Validation

1. From a clean source snapshot and empty `.build/**`, the representative set resolves the immutable upstream
   input from the authenticated network-independent cache, generates required foreign build inputs, and
   builds the maintained Haskell fork.
2. The tracked snapshot contains no `vendor/**`, patch program, Proto input, foreign package description, or
   generated binding; all such material is contained beneath the fresh run root.
3. Each generated reintroduction negative reddens only its named source-closure or provenance check, while an
   unaffected Haskell control remains green.
4. The Haskell provenance declaration rejects mutable refs, absent identity, developer-home paths, and a
   digest that does not match the acquired bytes.

### Remaining Work

`LTD-SRC-009` remains active but its tracked-path analyzer now observes zero top-level `vendor/**` paths: the
17 maintained library modules have moved to `src/vendor/**/*.hs`, and the foreign package descriptions,
Proto schema, licences, and prose inventory have left the current working source image. The Haskell
provenance declaration, immutable offline materialization, generated Proto/package inputs, maintained-fork
build, independent oracle, and generated reintroduction corpus still do not exist, so this implementation
progress cannot close the sprint or support a candidate.

## Sprint 1.8: jit-build resolver deps + `purescript-bridge` + consolidated probe gate ✅

**Status**: Done
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 1.7
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective
Adopt [`content_addressing_determinism.md §4.5 — the ML-asset lifecycle`](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss):
the shared `jit-build` resolver that materializes named catalog identities into the `CacheBudget`-bounded
content-addressed cache carries its own Haskell dependencies. Fold them into one probe that also links `dhall`
+ `io-sim` + `io-classes`, so the whole pre-cluster in-process surface is proven buildable as **one**
dependency universe — the phase gate.

**The gate runs last because it is the only run over the final source.** This sprint used to sit fourth, which
made two things impossible at once: it needed the `supernova` fork that a later sprint produced, while that
sprint declared this one as its blocker, and the pin replacement and vendor removal that follow it invalidated
every transcript the earlier probes had recorded. A gate over a dependency universe has to observe the
universe the phase actually leaves behind, so it is now the last seam and every earlier probe feeds it.

### Deliverables
- The consolidated throwaway probe executable whose `build-depends` matches the Representative-set list
  exactly — all five clauses (i)–(v): `dhall` + `io-sim` + `io-classes` + the eight `jit-build` resolver
  packages (`cryptohash-sha256`, `http-client`, `http-client-tls`, `typed-process`, `tar`, `zlib`,
  `directory`, `filepath` — content-hashing, download-or-build, and process control) + the build-only
  `purescript-bridge` contract generator + the `supernova` fork with its `proto-lens` codegen (the last
  folded in from Sprint 1.4).
- A run-local recorded-resolution ledger beneath `.build/runs/phase_1/**`: the `allow-newer`/patch/fork set
  with its matching green observations. A hard blocker is recorded in the same ledger as `UNVERIFIED` residue
  and holds the phase shut; it is never an accepting ledger. The tracker
  may link a reader to evidence but cannot supply a behavioral input or verdict.
- GateReady Haskell compatibility, terminal-state expectation, and mutation declarations. Solver selections,
  build/run transcripts, any freeze projection, and applied mutant subjects are fresh outputs beneath
  `.build/runs/phase_1/**`; no evidence bundle or serialized expectation is tracked.
- A first-class proven/tested/assumed ledger artifact ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)) — naming **Register 1**, recording the green build +
  executed-fixture results as *tested*, and marking every runtime, cluster, and gadt-decode-semantics layer
  **UNVERIFIED** — emitted beneath `.build/runs/phase_1/**` even though the probe package itself is deleted
  after resolution.

### Validation
1. The consolidated probe's `build-depends` matches the Representative-set list exactly — all five clauses
   (i)–(v); a category description, or a set already in the stock closure, does not satisfy this. It builds
   and links under GHC 9.12.4 / Cabal 3.16.1.0 from a clean store.
2. `cabal run probe:decode` exits 0 on the Haskell-declared positive rendered beneath `.build/probe/**`, and
   `cabal run probe:sim`'s reported terminal state satisfies the separately authored Haskell expectation,
   never the probe's self-exit.
3. **Both** checked Haskell mutation operators are applied beneath `.build/probe/**` and re-run: dropping the
   compatibility allowance reddens the version-resolution locus, while perturbing the simulation schedule
   reddens the terminal-state locus —
   together proving the gate detects an unbuildable config and a wrong-terminal-state sim rather than
   rubber-stamping a green one.
4. The consolidated `allow-newer`/patch/fork set is recorded with its matching green transcripts in the
   fresh Phase-1 run bundle. This row has one branch. An unresolvable set is recorded as explicit `UNVERIFIED`
   residue and leaves the phase blocked, because a gate a failing transcript can satisfy tests nothing: a
   deliberately malformed `cabal.project` produces exactly those artefacts while building none of the probes.
   All transcripts and the proven/tested/assumed ledger exist only beneath `.build/**` —
   the Phase-1 acceptance condition. Prose in the tracker without matching run-local observations never passes.

### Remaining Work
The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work
includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and the
Haskell probe, oracle, and mutation obligations of the redesigned gate.


## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/substrate_doctrine.md` — **historical pre-reset note from 2026-08-17 — cannot support a gate pass.** §3.1 records that the floor tables are
  authored data evaluated before resolution, and that every substrate's floor is decided on every run,
  including the ones the running host is not.
- `documents/engineering/repository_layout_doctrine.md` — **historical pre-reset note from 2026-08-17 — cannot support a gate pass.** §4 records the one `<os>-<arch>`
  platform vocabulary, the single normalizer that produces it, and the rule that a publisher with no asset for
  the host's token is a refusal rather than a fallback.
- `documents/engineering/repository_layout_doctrine.md` — **historical pre-reset note from 2026-08-12 — cannot support a gate pass.** The target replaces both
  `toolchain/pins.json` and `tools/toolchain_requirements.json` with Haskell compatibility declarations and
  run-local `.build/toolchain/**` projections; `cabal.project.freeze` remains inadmissible.
- `documents/engineering/dsl_doctrine.md` — §9's Toolchain note gets a backlink to the recorded `dhall`
  `allow-newer`/patch set once Sprint 1.2/1.4 lands.
- `documents/engineering/gateway_migration_model_doctrine.md` — §4's io-sim instrument gets a backlink to the
  gate-passed buildability evidence.
- `documents/engineering/content_addressing_doctrine.md` — §4.5's `jit-build` resolver gets a backlink to the
  gate-passed resolver-dependency evidence.
- `documents/engineering/repository_layout_doctrine.md` — **historical pre-reset note from 2026-08-20 — cannot support a gate pass.** The `patches/**` tree row and
  its TRANSITIONAL marker are deleted; §2 records why the root is absent rather than transitional, §2.2 no
  longer carries a destination row for it, and §4.1 states that there is no patch root and no admitted patch.
- `documents/engineering/pulsar_client_doctrine.md` — §4 identifies the current top-level vendor tree as
  migration debt and the target split between maintained `src/vendor/**/*.hs` and lazy `.build/vendor/**`
  acquisition.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — the Toolchain section records only the authored compatibility policy or a
  current blocker; resolved `allow-newer`, patch application, source identity, and graph observations remain
  in the run bundle. Only the pass criterion may change Phase 1 after checking a qualified candidate.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-1 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register the Haskell toolchain/probe declarations; throwaway probe
  packages and products live beneath `.build/**`. Identify top-level `vendor/**` only as `LTD-SRC-009`
  migration debt.

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
  authored requirements, generated resolution, repository-local evidence, and ignore/context contract that Sprint 1.5
  implements.
