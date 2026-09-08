# Phase 50: Validate the bounded `pb` → Haskell handoff

> **Purpose**: Validate the runtime behavior of the already source-closed non-Haskell exception: make the
> minimal platform distinction, establish the contained Haskell toolchain, build the exact binary, and exec
> it with opaque user arguments.
> **Read this if**: Phase 49 has been gate-passed or a bare checkout's already-bounded handoff must be
> observed without making Python interpret commands or produce verdicts.

Phase 0 owns source-role closure for `pb/**`, and Phase 49 requires that closure before the no-hardware DSL
barrier can pass. This phase does not migrate or pardon source. It validates the effectful runtime
handoff of the already-bounded exception without moving product, test, oracle, gate, host-policy, help, or
version logic into Python.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/substrate_doctrine.md, documents/engineering/validation_frame_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision](#resource-provision)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 50.1: Bind the already-bounded bootstrap surface](#sprint-501-bind-the-already-bounded-bootstrap-surface-)
- [Sprint 50.2: Ensure and build in the contained root](#sprint-502-ensure-and-build-in-the-contained-root-)
- [Sprint 50.3: Exec-only validation handoff](#sprint-503-exec-only-validation-handoff-)
- [Sprint 50.4: Bound entropy and supervisor resources](#sprint-504-bound-entropy-and-supervisor-resources-)
- [Sprint 50.5: Bounded-bootstrap candidate](#sprint-505-bounded-bootstrap-candidate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

The [2026-09-08 reset](README.md#reopened-numeric-sequence) withdraws prior certification. Existing
implementation is an Observed footprint / Known partial. Retained requirements remain obligations; only this
phase's complete qualified gate under the replacement acceptance baseline can authorize Done.

Gate execution remains blocked by the qualified Phase-49 predecessor and its compatible evidence chain.

## Phase Summary

The audit found that any unsuccessful fake receipt could count as a changed-subject success. This phase must distinguish the expected specific refusal from a broken test setup or unrelated failure and preserve custody of actual process observations. The bounded bootstrap remains a subject of the external Haskell supervisor, never its own validator.

The accepted source role is a Phase-0 precondition, not this phase's conclusion. Python may make only the
minimal platform distinction necessary to select the direct toolchain-establishment adapter, establish the pinned
GHC/Cabal toolchain beneath `.build/**`, build the single Haskell executable, and replace itself with that
exact executable. Every user argument is opaque and forwarded unchanged. Empty argv, help, version,
bootstrap, validation, unknown verbs, and future commands are all interpreted after handoff by Haskell.

The accepted Python grammar is a deny-by-default checked Haskell value, `PbBootstrapGrammar`. Its closed
supported authored syntax/import/resolved-direct-call/control-flow/potential-effect graph rejects every unsupported authored node and, explicitly, `eval`, `exec`, `compile`, dynamic
import, reflection or `getattr` dispatch, import hooks, decorators, metaclasses, monkeypatching, plugin
discovery, shell execution, FFI syntax, and authored direct network/process calls outside the declared adapter.
The graph may contain only the closed authored establishment, build, and exec request nodes exposed by one
injected `BootstrapAdapter`. It does not claim the runtime semantics of imports, standard-library/native calls,
transitive dependencies, or the concrete adapter. Phase 50 observes those runtime boundaries outside Python
and records whether each exercised request performed an effect. A keyword scan or public-help inventory cannot
satisfy this contract.

**Phase scope:** one cohesive claim — the Phase-0-classified `pb` handoff establishes the contained Haskell toolchain, builds the exact source-bound binary, forwards every argv unchanged, and terminates through the single resource-bounded observed exec adapter without retaining control. It splits if Python is asked to interpret a user command or perform any post-handoff capability.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 49](phase_49_self_referential_gates.md)
**Gate:** `pb validate phase 50`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: UNRESOLVED — NOT VALIDATED; the replacement certification-generation and accepted-baseline
binding has not been authored in Haskell. Retained rows specify intended scope and supply no execution evidence.

| Key | Contract |
|---|---|
| `Claim` | Given the already accepted `PbBootstrapGrammar`, `pb` makes only the platform distinction required to establish the contained toolchain, builds the exact source-bound Haskell executable offline and serially, and execs it with every user argument unchanged. Python never interprets a public command, host-floor policy, help/version behavior, product result, evidence, or verdict. Real-host capability claims are excluded. |
| `Subject` | The exact Phase-0-classified `pb/__main__.py` bytes, their single injected `BootstrapAdapter`, and the acquired `Amoebius.Validation.PbBoundaryRun` Haskell supervisor bytes that exercise them. No other tracked `pb/**` path or packaging file is admitted. |
| `Command` | The candidate starts the exact absolute source-built Haskell OS supervisor directly. It invokes the authenticated absolute interpreter as `-I`, `-S`, `-B`, the absolute snapshot `pb` directory, and the opaque `validate phase 50` tail. A fresh inherited challenge selects the Haskell observation continuation after exec, so `pb validate phase 50` never supervises itself. |
| `Oracle` | `test/validation-kernel/PbBoundaryOracle.hs`, authored without importing the production boundary implementation, states the exact adapter transcript, resource containment, challenge length, unchanged argv, process replacement, cleanup, and exit expectations. |
| `Positive controls` | Haskell-authored fake-adapter cases cover all four supported platform choices, absent/present verified acquisition, contained environment, exact serial offline build, locator, empty/help/version/validation/unknown/adversarial argv, and one concrete OS-observed `main` handoff. |
| `Paired negatives` | Every bootstrap/platform/build/argv/exec/entropy/resource negative is paired with a successfully observed legal acquisition under the same setup. Require its independently fixed refusal constructor or exact exit/diagnostic and zero forbidden effects; an arbitrary failed receipt cannot count as the expected refusal. |
| `Mutants` | Each changed bootstrap or Haskell-supervisor subject must visibly alter its declared production behavior and fail the independently assigned exact case/reason after successful setup. Unrelated compiler, adapter, path, timeout or process failures do not kill the mutant. An unaffected observed control must pass. |
| `Discovery` | Static `PbBootstrapGrammar` discovery is joined to the exact tracked byte/mode/path identity; the runtime supervisor independently inventories every fake-adapter request and the concrete interpreter, filesystem, process, executable, argv, challenge, resource envelope, replacement, cleanup, and exit observations. Empty, partial, unresolved, or unclassified observations refuse. |
| `Challenge` | After the concrete `pb` process starts, the supervisor obtains exactly 32 unpredictable bytes through a fixed-count cryptographic entropy operation, checks the returned length, and publishes them through a run-owned challenge path. Only the execed source-built Haskell continuation can acknowledge them while the parent independently observes that process. |
| `Observer` | The external Haskell supervisor retains one opaque receipt owning exact interpreter/child/executable identities, source/build inputs, real argv, readiness/challenge events, process replacement, exits, enforced resource limits and cleanup; reported expected values cannot populate these observations. |
| `Authority/bypass` | The run admits only the authenticated interpreter, verified `ghcup`, exact contained GHC/Cabal paths, an explicit contained `PATH`, offline serial Cabal, fixed-count entropy, enforced memory/deadline limits, run-owned filesystem effects, and the final exact Haskell executable. It rejects ambient `PATH`, unlimited execution, network, host package managers, containers, providers, hardware, and recursive Phase-50 supervision. |
| `Freshness` | The copied indexed source and phase-specific toolchain/build/observation roots are unique and absent at acquisition; the post-start canary is unique; first and converged observations identify their exact products; opening and closing tracked-source identities match. |
| `Qualification` | Reject constant success, arbitrary-failure-as-kill, wrong assigned case, failed setup, missing observations, forged custody, noop/skip mutant, cached challenge, unbounded entropy, removed limits, rewritten argv and residue leaks through acquired exact qualification cases. Both each successful control and its named failure must be observed. |
| `Cleanroom` | Mutations and all generated source, toolchain, build, transcript, challenge, and observation material remain under the uniquely owned `.build/runs/phase-50/**` root. On success, refusal, signal, memory exhaustion, deadline, interruption, or ambiguity, marker-scoped cleanup proves zero owned processes and explicit retained evidence only. |
| `Legacy closure` | Phase 50 owns `LTD-VAL-007` and `LTD-VAL-008` but no source-migration binding. Their typed analyzers must observe zero unbounded entropy/resource and incomplete-contained-environment loci, and both independently authored reintroduction negatives must turn red. The gate also consumes the exact refreshed Phase-49 pass whose source snapshot has zero source-migration queries. |
| `Predecessor` | Authenticated `ImmediatePredecessorPass` for Phase 49 in the admitted certification generation, plus the accepted verifier's current compatibility decision under [§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass). Missing, forged, revoked, incompatible, or wrong-phase evidence refuses before any phase effect. Historical source identity remains recorded; reuse requires unchanged relevant dependency and acceptance closures. |
| `Residue` | `UNVERIFIED`: other native platforms, real package-manager and permission fidelity, Phase-51 host ensure, container engines, VMs, clusters, images, registry, hardware, and all product behavior after the Haskell handoff. |
| `Pass criterion` | `qualified-gate-pass` — all eighteen rows pass in one source-bound qualified candidate, the external observer sees the resource-bounded clean concrete handoff, `LTD-VAL-007` and `LTD-VAL-008` close, cleanup reports zero owned residue, and every named changed-subject mutant is red. |

## Resource provision

> The typed `ResourceProvisionContract` binds these seven fields to the Phase-50 Haskell supervisor. They are
> gate-ready contract terms, not evidence that the still-open gate has passed.

- **Owner marker:** a run-local Haskell value binds the source snapshot, Phase-49 gate pass, supervisor identity,
  authenticated interpreter, contained toolchain/build root, process-tree identity, resource budget, fake
  executable, and run identifier.
- **Preflight:** fresh read-only checks bind the exact source-built supervisor, passed `pb` bytes, interpreter,
  absent run root, process scope, writable-path boundary, memory-limit mechanism, and monotonic clock before the
  subject starts.
- **Allowed mutations:** only marker-owned processes and files beneath the one fresh `.build/**` run root needed
  for contained toolchain establishment, source-bound build, fake executable creation, and observations.
- **Forbidden mutations:** hardware, container engines, VMs, clusters, registries, networks, credentials,
  source-adjacent caches, tracked-tree writes, foreign processes, ambient tool selection, and paths outside the
  marked run root.
- **External observer:** the exact source-built Haskell supervisor records raw process, executable, argv,
  environment, file-effect, replacement, resource-limit, peak-memory, termination, and exit observations
  without trusting Python or child logs.
- **Scoped cleanup:** on success, failure, interruption, or ambiguous outcome, terminate and remove only
  processes and run paths bound to the exact owner marker. Memory exhaustion and deadline use the same path;
  cleanup never uses a wildcard or ambient process match.
- **Zero-owned-residue:** after cleanup, the external observer requires every marker-owned process, toolchain
  scratch path, build output, fake executable, observation pipe, and run path to be absent; no retained resource
  is declared.

## Doctrine adopted

- [`repository_layout_doctrine.md` §2 — complete repository structure](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) — the sole non-Haskell source exception and its closed role.
- [`substrate_doctrine.md` §6 — the pre-binary handoff contract](../documents/engineering/substrate_doctrine.md#6-the-pre-binary-handoff-contract) — minimal platform adapter selection, contained establishment, source-bound build, and unchanged-argv exec only.
- [`validation_frame_doctrine.md` §2.3 — the resource-bounded handoff supervisor](../documents/engineering/validation_frame_doctrine.md#23-the-handoff-supervisor-is-resource-bounded) — fixed-count entropy plus memory/deadline containment.
- [`testing_spoof_resistance.md` §12.5 — fresh external observation](../documents/engineering/testing_spoof_resistance.md#125-fresh-external-observation) — bounded challenge acquisition, external observation, and forced-termination cleanup.

## Sprints

## Sprint 50.1: Bind the already-bounded bootstrap surface ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/PbBoundary.hs`
**Blocked by**: [Phase 49](phase_49_self_referential_gates.md) gate pass
**Independent Validation**: A valid bounded module is accepted, a one-node forbidden dynamic-execution variant is refused at the grammar locus, a changed indexed-snapshot bypass mutant reddens only its named row, and runtime/toolchain behavior remains explicit residue.
**Oracle**: `test/validation-kernel/PbBoundaryOracle.hs`; separate authorship, exact run binding, and independent complete gate execution are required and currently missing.
**Legacy IDs**: none — the Phase-49-bound zero-source-debt query must remain zero
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/substrate_doctrine.md`

### Objective

Consume the exact Phase-49 gate pass and bind the already-bounded `pb/**` snapshot, grammar, and adapter
identity without changing bootstrap source or reopening source migration.

### Deliverables

- An independent Haskell selector-to-case/reason registry binds every changed bootstrap and supervisor locus to the precise expected behavior, successful setup evidence and unaffected control.

- Exact binding to the Phase-49-passed `PbBootstrapGrammar`, source identities, zero-source-debt result,
  and adapter contract.
- Refusal on any `pb/**` byte, mode, path, grammar, or effect-boundary mismatch.
- A no-write postcondition for the sole `pb/__main__.py` subject and the Git index/worktree.

### Validation

- A missing interpreter, failed build, unrelated adapter error and deliberate wrong-case failure must each fail qualification rather than count as a killed bootstrap mutant.

The Haskell audit replays the already-passed grammar against copied mutations beneath `.build/**`, rejects
one minimal member of every forbidden syntax/import/effect family, and refuses any mismatch with the exact
Phase-49 snapshot. It never treats help text or token occurrence as discovery, and the external observer proves
the tracked tree did not change.

### Remaining Work

Implement and independently check the Haskell snapshot/grammar binding. Any required `pb/**` source change
reopens its Phase-0 `LTD-SRC-008` owner and consequently invalidates and reruns the chain through Phase 49;
Phase 50 cannot make that change or close a source row.

## Sprint 50.2: Ensure and build in the contained root ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/PbBoundaryRun/Internal.hs`
**Blocked by**: Sprint 50.1
**Independent Validation**: Observe authenticated contained ensure/build succeeding; paired missing identity/offline/serial inputs refuse at their exact reason before exec; assigned build mutants fail only their mapped case; real host package-manager fidelity remains unverified.
**Oracle**: `test/validation-kernel/PbBoundaryOracle.hs`; oracle independence required.
**Legacy IDs**: `LTD-VAL-008` — typed contained-environment binding and reintroduction witness required
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `documents/engineering/validation_frame_doctrine.md`

### Objective

Externally observe that the already-bounded bootstrap establishes the minimal Haskell toolchain and builds
the one executable without ambient paths or source-adjacent output.

### Deliverables

- Acquire exact successful toolchain/build observations before testing the matched refusal. Tool existence, a marker file or a failed process cannot establish an authenticated source-bound build.

- Haskell-owned observation of probe-first contained toolchain establishment.
- An explicit contained `PATH` and required environment baseline for the verified `ghcup`, GHC, and Cabal
  children, with no ambient executable lookup.
- Haskell-owned observation of the source-snapshot-bound build and exact executed binary identity.
- First/converged run observations with no tracked-tree mutation.

### Validation

- Change only one admitted build input or containment condition and assert the exact rejection and zero handoff effects; reject any control whose acquisition did not first succeed.

The fake host externally records every read/write/process action and catches skipped probes, absent or ambient
`PATH`, stale binaries, unconditional copy, and writes outside `.build/**`.

### Remaining Work

Implement and qualify the external Haskell observation. A discovered bootstrap defect reopens its Phase-0
`LTD-SRC-008` owner and consequently invalidates and reruns the chain through Phase 49; it is not repaired or
reclassified inside this phase. The Haskell supervisor's incomplete child environment is Phase-50 work under
`LTD-VAL-008`; it does not alter `pb/**`.

## Sprint 50.3: Exec-only validation handoff ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/PbBoundary.hs`, `src/validation-kernel/Amoebius/Validation/PbBoundaryRun/Internal.hs`
**Blocked by**: Sprint 50.2
**Independent Validation**: An externally observed exact binary replaces the bootstrap with unchanged argv; wrong binary, rewritten argv or no-exec pairs fail specifically; assigned handoff mutants require real process evidence; product behavior after handoff remains unverified.
**Oracle**: `test/validation-kernel/PbBoundaryOracle.hs`; oracle independence required.
**Legacy IDs**: none — the Phase-49-bound zero-source-debt query must remain zero
**Docs to update**: `documents/engineering/testing_spoof_resistance.md`

### Objective

Observe every `pb <argv...>` invocation as the already-bounded platform-discriminate/establish/build/opaque-
exec handoff, never as a Python command parser or gate.

### Deliverables

- Keep actual process identity, executable identity, exact user argv, exit propagation and child replacement in one opaque acquired receipt; callers cannot splice independent projections into an accepted handoff.

- Verbatim handoff of every argv, including empty/help/version/validation/unknown cases.
- Exact binary-identity and process-replacement observation.
- No Python verdict parsing, wrapping, fallback, or status mutation.

### Validation

- Forge an observed argv/identity field without changing the child invocation and require custody failure. A helper’s self-report or expected transcript is insufficient proof of exec.

Changed-subject mutants rewrite argv, select another binary, return instead of exec, swallow failure, force
success, or parse evidence; each fails at its named external observation.

### Remaining Work

Implement and independently check the external handoff observer. Any needed bootstrap-source change reopens
its Phase-0 `LTD-SRC-008` owner and consequently invalidates and reruns the chain through Phase 49 rather than
becoming Phase-50 work.

## Sprint 50.4: Bound entropy and supervisor resources ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/PbBoundaryRun/Internal.hs`
**Blocked by**: Sprint 50.3
**Independent Validation**: An exact 32-byte fixed-count challenge reaches the continuation within the declared budget; wrong-length and never-ending entropy cases refuse; a strict whole-stream changed-subject mutant is stopped inside the runner-owned envelope at its assigned row; cleanup leaves zero owned residue.
**Oracle**: `test/validation-kernel/PbBoundaryOracle.hs`; independent challenge-length, source-pattern, resource-limit, termination, and cleanup expectations required.
**Legacy IDs**: `LTD-VAL-007` — the reader row exists, but its typed Haskell binding and reintroduction witness remain required
**Docs to update**: `documents/engineering/validation_frame_doctrine.md`, `documents/engineering/testing_spoof_resistance.md`

### Objective

Make the concrete Haskell supervisor finite in entropy consumption, memory, elapsed time, and cleanup before it
can contribute a Phase-50 observation.

### Deliverables

- Replace the strict whole-stream `/dev/urandom` read followed by truncation with
  `Crypto.Random.getRandomBytes 32`, then fail closed unless exactly 32 bytes were returned.
- Bind the complete concrete supervisor and child process tree to an OS-enforced 8,589,934,592-byte memory
  ceiling, zero swap allowance, and 1,800-second monotonic deadline. Independently restate those values in the
  oracle and bind them into candidate evidence.
- Record limit support, peak memory, termination reason, challenge length, acknowledgement, and final exit as
  external observations rather than child summaries.
- Route success, refusal, signal, memory exhaustion, deadline, interruption, and ambiguity through one
  marker-scoped cleanup path that proves zero owned processes and files except declared retained evidence.
- Add the compiled `LTD-VAL-007` owner, analyzer, observation, closure, and reintroduction bindings without
  deriving any of them from the reader-facing Markdown row.

### Validation

- Require the legal bounded entropy/resource control to complete under the same observer, then check exact short-read, never-ending stream, missing-limit and cleanup outcomes. An arbitrary timeout cannot count as the expected resource mutant failure.

The independent oracle requires the fixed-count cryptographic operation and rejects the former strict-read-
then-truncate expression. Dynamic cases cover exact and wrong challenge lengths, an endless entropy provider,
memory pressure, a non-terminating child, and forced termination. Each case must finish inside the outer
resource envelope, report its assigned reason, preserve unrelated controls, and leave zero owner-marked
residue. The concrete positive must publish and acknowledge exactly 32 bytes, stay below the declared ceiling,
finish before the deadline, and preserve exact executable, argv, and exit observations.

### Remaining Work

Implement the fixed-count entropy call, exact-length refusal, outer resource envelope, observations, scoped
cleanup, typed legacy binding, independent expectations, and changed-subject qualification. The 2026-09-07 OOM
attempt is diagnostic evidence only and cannot satisfy any row.

## Sprint 50.5: Bounded-bootstrap candidate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/PbBoundary.hs`, `src/validation-kernel/Amoebius/Validation/PbBoundaryRun/Internal.hs`, `app/amoebius/Main.hs`
**Blocked by**: Sprint 50.4
**Independent Validation**: The complete acquired handoff succeeds with exact custody; each minimally altered authority/argv/resource case refuses for its assigned reason; wrong-case and arbitrary-failure mutant classifiers are rejected; later host/runtime behavior remains unverified.
**Oracle**: Separate authorship and an independent observation seam are required and currently missing; the complete qualified gate result is final.
**Legacy IDs**: `LTD-VAL-007`, `LTD-VAL-008` — closure and independently qualified reintroduction required in the integrated gate
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only after gate pass

### Objective

Produce a candidate for complete gate execution without treating a successful handoff as gate pass.

### Deliverables

- Replace any `changedSubjectPassed = fakeCasePassed` style predicate with comparison of exact acquired outcomes, assigned case/reason, witnessed source change and unaffected control.

- Qualification and clean resource-bounded raw process observations.
- Candidate evidence bound to the Phase-49 gate pass, its zero-source-debt snapshot, and the exact source/harness.
- Explicit real-host residue.

### Validation

- Run qualification cases in which a mutant fails outside its assigned assertion or setup fails before the subject is exercised; neither may authorize a candidate or status update.
- Only the complete qualified gate authorizes the mechanical status update and normal numeric continuation; this repair introduces no approval step.

The complete gate checks the source exception, oracle independence, qualification, bounded challenge and
resource observations, raw process trace, legacy closure, forced-termination cleanup, and residue. It alone
decides whether Phase 50 passes.

### Remaining Work

All integrated qualification, independent check, `LTD-VAL-007`/`LTD-VAL-008` closure, and complete gate result
remain open.

## Documentation Requirements

**Engineering docs updated for the current target contract:**

- `documents/engineering/validation_frame_doctrine.md` — fixed-count challenge entropy and the bounded
  supervisor envelope.
- `documents/engineering/testing_spoof_resistance.md` — the general resource rule for effectful observers.

`documents/engineering/substrate_doctrine.md` changes only if the bounded bootstrap roles or adapter seam
change. `documents/engineering/repository_layout_doctrine.md` changes only if the source exception changes.
Neither condition is introduced by the Phase-50 supervisor repair.

**Cross-references to add:**

- Phase 49 predecessor gate pass and Phase 51 consumer links.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 49 gate barrier](phase_49_self_referential_gates.md)
- [Phase 51 host-ensure kernel](phase_51_host_ensure_kernel.md)
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Substrate doctrine](../documents/engineering/substrate_doctrine.md)
- [Validation execution doctrine](../documents/engineering/validation_frame_doctrine.md)
