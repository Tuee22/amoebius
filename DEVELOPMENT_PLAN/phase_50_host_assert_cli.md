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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/substrate_doctrine.md
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
- [Sprint 50.4: Bounded-bootstrap candidate](#sprint-504-bounded-bootstrap-candidate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

🔄 Active — NOT VALIDATED.

Blocked by the redesigned Phase 49 no-hardware DSL barrier and its gate pass, including zero
`LTD-SRC-008` findings. Every prior `pb` quality
gate or implementation result is invalidated as a current gate result. Existing implementation is an
**Observed footprint / Known partial** only.

---

## Phase Summary

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

**Phase scope:** one cohesive claim — the Phase-0-classified `pb` handoff establishes the contained Haskell toolchain, builds the exact source-bound binary, forwards every argv unchanged, and terminates through the single observed exec adapter without retaining control. It splits if Python is asked to interpret a user command or perform any post-handoff capability.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 49](phase_49_self_referential_gates.md)
**Gate:** `pb validate phase 50`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED; implementation and independent execution remain open.

| Key | Contract |
|---|---|
| `Claim` | Given the already accepted `PbBootstrapGrammar`, `pb` makes only the platform distinction required to establish the contained toolchain, builds the exact source-bound Haskell executable offline and serially, and execs it with every user argument unchanged. Python never interprets a public command, host-floor policy, help/version behavior, product result, evidence, or verdict. Real-host capability claims are excluded. |
| `Subject` | The exact Phase-0-classified `pb/__main__.py` bytes and their single injected `BootstrapAdapter`, exercised by the acquired `Amoebius.Validation.PbBoundary` Haskell supervisor. No other tracked `pb/**` path or packaging file is admitted. |
| `Command` | The candidate starts the exact absolute source-built Haskell OS supervisor directly. It invokes the authenticated absolute interpreter as `-I`, `-S`, `-B`, the absolute snapshot `pb` directory, and the opaque `validate phase 50` tail. A fresh inherited challenge selects the Haskell observation continuation after exec, so `pb validate phase 50` never supervises itself. |
| `Oracle` | `test/validation-kernel/PbBoundaryOracle.hs`, authored without importing the production boundary implementation, states the exact adapter transcript, containment, unchanged argv, process replacement, and exit expectations. |
| `Positive controls` | Haskell-authored fake-adapter cases cover all four supported platform choices, absent/present verified acquisition, contained environment, exact serial offline build, locator, empty/help/version/validation/unknown/adversarial argv, and one concrete OS-observed `main` handoff. |
| `Paired negatives` | Minimal pairs cover unsupported platform, ambient executable selection, external writes, skipped ensure, stale or non-source-built binary, missing `--offline`/`--jobs=1`, no exec, rewritten/dropped argv, self-supervision, forged observation, and swallowed exit. |
| `Mutants` | Each changed `pb` subject is materialized only under the run-owned source snapshot. Skipped ensure, ambient Cabal, external write, stale locator, non-serial/network-capable build, return instead of exec, argv rewrite, and forced-zero exit each redden one named row while the clean subject remains green. |
| `Discovery` | Static `PbBootstrapGrammar` discovery is joined to the exact tracked byte/mode/path identity; the runtime supervisor independently inventories every fake-adapter request and the concrete interpreter, filesystem, process, executable, argv, challenge, replacement, and exit observations. Empty, partial, unresolved, or unclassified observations refuse. |
| `Challenge` | After the concrete `pb` process starts, the supervisor publishes a fresh unpredictable canary through a run-owned challenge path. Only the execed source-built Haskell continuation can acknowledge it while the parent independently observes that process. |
| `Observer` | The Haskell parent records the child PID before handoff and independently reads the live OS executable and argv after the continuation blocks for acknowledgement, then checks exact binary digest and final exit propagation. Subject-authored summaries alone are insufficient. |
| `Authority/bypass` | The run admits only the authenticated interpreter, verified `ghcup`, exact contained GHC/Cabal paths, offline serial Cabal, run-owned filesystem effects, and the final exact Haskell executable. It rejects ambient `PATH`, network, host package managers, containers, providers, hardware, and recursive Phase-50 supervision. |
| `Freshness` | The copied indexed source and phase-specific toolchain/build/observation roots are unique and absent at acquisition; the post-start canary is unique; first and converged observations identify their exact products; opening and closing tracked-source identities match. |
| `Qualification` | The Haskell harness rejects constant success, no-op bootstrap, wrong binary, incomplete discovery, missing oracle, skipped/no-op/wrong-locus mutants, stale challenge, subject-forged process evidence, argv bypass, external writes, and incorrect exit. |
| `Cleanroom` | Mutations and all generated source, toolchain, build, transcript, challenge, and observation material remain under the uniquely owned `.build/runs/phase-50/**` root; no source-adjacent Python cache or tracked-tree write is permitted; cleanup proves zero owned processes and explicit retained evidence only. |
| `Legacy closure` | Phase 50 owns no migration binding. It consumes the exact refreshed Phase-49 pass whose source snapshot has zero source-migration queries and refuses any mismatch or reintroduction. |
| `Predecessor` | Exact `ImmediatePredecessorPass` for Phase 49; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | `UNVERIFIED`: other native platforms, real package-manager and permission fidelity, Phase-51 host ensure, container engines, VMs, clusters, images, registry, hardware, and all product behavior after the Haskell handoff. |
| `Pass criterion` | `qualified-gate-pass` — all eighteen rows pass in one source-bound qualified candidate, the external observer sees the clean concrete handoff, and every named changed-subject mutant is red. |

## Resource provision

> The typed `ResourceProvisionContract` binds these seven fields to the Phase-50 Haskell supervisor. They are
> gate-ready contract terms, not evidence that the still-open gate has passed.

- **Owner marker:** a run-local Haskell value binds the source snapshot, Phase-49 gate pass, supervisor identity,
  authenticated interpreter, contained toolchain/build root, fake executable, and run identifier.
- **Preflight:** fresh read-only checks bind the exact source-built supervisor, passed `pb` bytes, interpreter,
  absent run root, process scope, and writable-path boundary before the subject starts.
- **Allowed mutations:** only marker-owned processes and files beneath the one fresh `.build/**` run root needed
  for contained toolchain establishment, source-bound build, fake executable creation, and observations.
- **Forbidden mutations:** hardware, container engines, VMs, clusters, registries, networks, credentials,
  source-adjacent caches, tracked-tree writes, foreign processes, ambient tool selection, and paths outside the
  marked run root.
- **External observer:** the exact source-built Haskell supervisor records raw process, executable, argv,
  environment, file-effect, replacement, and exit observations without trusting Python or child logs.
- **Scoped cleanup:** on success, failure, interruption, or ambiguous outcome, terminate and remove only
  processes and run paths bound to the exact owner marker; never use a wildcard or ambient process match.
- **Zero-owned-residue:** after cleanup, the external observer requires every marker-owned process, toolchain
  scratch path, build output, fake executable, observation pipe, and run path to be absent; no retained resource
  is declared.

## Doctrine adopted

- [`repository_layout_doctrine.md` §2 — complete repository structure](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) — the sole non-Haskell source exception and its closed role.
- [`substrate_doctrine.md` §6 — the pre-binary handoff contract](../documents/engineering/substrate_doctrine.md#6-the-pre-binary-handoff-contract) — minimal platform adapter selection, contained establishment, source-bound build, and unchanged-argv exec only.
- [`validation_frame_doctrine.md` §2 — the bootstrap boundary](../documents/engineering/validation_frame_doctrine.md#2-the-bootstrap-boundary) — Haskell owns every validation verdict.
- [`testing_spoof_resistance.md` §12 — spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence) — external process observation and pass criterion.

## Sprints

## Sprint 50.1: Bind the already-bounded bootstrap surface 🔄

**Status**: Active — NOT VALIDATED
**Implementation**: `src/Amoebius/Validation/PbBoundary.hs`
**Blocked by**: [Phase 49](phase_49_self_referential_gates.md) gate pass
**Independent Validation**: A valid bounded module is accepted, a one-node forbidden dynamic-execution variant is refused at the grammar locus, a changed indexed-snapshot bypass mutant reddens only its named row, and runtime/toolchain behavior remains explicit residue.
**Oracle**: planned `test/Amoebius/Validation/PbBoundaryOracle.hs`; separate authorship, exact run binding, and independent complete gate execution are required and currently missing.
**Legacy IDs**: none — the Phase-49-bound zero-source-debt query must remain zero
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/substrate_doctrine.md`

### Objective

Consume the exact Phase-49 gate pass and bind the already-bounded `pb/**` snapshot, grammar, and adapter
identity without changing bootstrap source or reopening source migration.

### Deliverables

- Exact binding to the Phase-49-passed `PbBootstrapGrammar`, source identities, zero-source-debt result,
  and adapter contract.
- Refusal on any `pb/**` byte, mode, path, grammar, or effect-boundary mismatch.
- A no-write postcondition for the sole `pb/__main__.py` subject and the Git index/worktree.

### Validation

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
**Implementation**: `src/Amoebius/Validation/PbBoundary.hs`
**Blocked by**: Sprint 50.1
**Independent Validation**: An absent-toolchain positive reaches the exact source-built binary, a minimally different ambient-path case refuses, a changed adapter-bypass mutant reddens the containment row, and real package-manager/permission behavior remains residue.
**Oracle**: `test/Amoebius/Validation/PbBoundaryOracle.hs`; oracle independence required.
**Legacy IDs**: none — the Phase-49-bound zero-source-debt query must remain zero
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `documents/engineering/validation_frame_doctrine.md`

### Objective

Externally observe that the already-bounded bootstrap establishes the minimal Haskell toolchain and builds
the one executable without ambient paths or source-adjacent output.

### Deliverables

- Haskell-owned observation of probe-first contained toolchain establishment.
- Haskell-owned observation of the source-snapshot-bound build and exact executed binary identity.
- First/converged run observations with no tracked-tree mutation.

### Validation

The fake host externally records every read/write/process action and catches skipped probes, ambient paths,
stale binaries, unconditional copy, and writes outside `.build/**`.

### Remaining Work

Implement and qualify the external Haskell observation. A discovered bootstrap defect reopens its Phase-0
`LTD-SRC-008` owner and consequently invalidates and reruns the chain through Phase 49; it is not repaired or
reclassified inside this phase.

## Sprint 50.3: Exec-only validation handoff ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Validation/PbBoundary.hs`
**Blocked by**: Sprint 50.2
**Independent Validation**: An opaque-argv positive reaches the fresh exact fake binary, a one-argument rewrite is refused, a changed return-instead-of-exec mutant reddens the process row, and native platform replacement semantics remain explicit residue.
**Oracle**: `test/Amoebius/Validation/PbBoundaryOracle.hs`; oracle independence required.
**Legacy IDs**: none — the Phase-49-bound zero-source-debt query must remain zero
**Docs to update**: `documents/engineering/testing_spoof_resistance.md`

### Objective

Observe every `pb <argv...>` invocation as the already-bounded platform-discriminate/establish/build/opaque-
exec handoff, never as a Python command parser or gate.

### Deliverables

- Verbatim handoff of every argv, including empty/help/version/validation/unknown cases.
- Exact binary-identity and process-replacement observation.
- No Python verdict parsing, wrapping, fallback, or status mutation.

### Validation

Changed-subject mutants rewrite argv, select another binary, return instead of exec, swallow failure, force
success, or parse evidence; each fails at its named external observation.

### Remaining Work

Implement and independently check the external handoff observer. Any needed bootstrap-source change reopens
its Phase-0 `LTD-SRC-008` owner and consequently invalidates and reruns the chain through Phase 49 rather than
becoming Phase-50 work.

## Sprint 50.4: Bounded-bootstrap candidate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Validation/PbBoundary.hs`, `app/amoebius/Main.hs`
**Blocked by**: Sprint 50.3
**Independent Validation**: One cleanroom positive exercises every adapter path, a minimally different forbidden effect refuses, a changed exec-bypass mutant reddens its named row, and real-host plus post-handoff residue remains explicit while Python cannot produce the gate verdict.
**Oracle**: Separate authorship and an independent observation seam are required and currently missing; the complete qualified gate result is final.
**Legacy IDs**: none — the Phase-49-bound zero-source-debt query must remain zero
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only after gate pass

### Objective

Produce a candidate for complete gate execution without treating a successful handoff as gate pass.

### Deliverables

- Qualification and clean raw process observations.
- Candidate evidence bound to the Phase-49 gate pass, its zero-source-debt snapshot, and the exact source/harness.
- Explicit real-host residue.

### Validation

The complete gate checks the source exception, oracle independence, qualification, raw process trace,
legacy closure, and residue and alone decides whether Phase 50 passes.

### Remaining Work

All implementation, qualification, independent check, legacy closure, and complete gate result remain open.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/substrate_doctrine.md` — only if the bounded bootstrap roles or adapter seam change.
- `documents/engineering/repository_layout_doctrine.md` — only if the source exception changes.
- `documents/engineering/validation_frame_doctrine.md` — only if validation handoff changes.

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
