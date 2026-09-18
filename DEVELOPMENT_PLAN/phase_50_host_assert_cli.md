# Phase 50: Validate the bounded `pb` → Haskell handoff

> **Purpose**: Validate the runtime behaviour of the bounded non-Haskell exception: launched by the runner, `pb` makes the minimal platform distinction, establishes the contained Haskell toolchain, builds the exact binary, and execs it with a corpus compile command unchanged.
> **Read this if**: the DSL barrier (Phase 9) has been gate-passed, or a bare checkout's bounded handoff must be observed without making Python interpret commands or produce verdicts.

Phase 2 owns static source admission for `pb/**`, and the DSL barrier (Phase 9) requires every source query to
be zero before this phase can run. This phase does not migrate or pardon source. It observes the effectful
runtime handoff of the bounded exception without moving product, test, oracle, gate, host-policy, help, or
version logic into Python.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_typed_spine.md, DEVELOPMENT_PLAN/phase_09_dsl_barrier.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/substrate_doctrine.md, documents/engineering/validation_frame_doctrine.md
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

The contract is reopened under [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) by
[DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice): the predecessor edge
moves to the DSL barrier and the observation logic moves from the deleted per-phase runner into product code.
Under §N step 3, every generation-1 receipt for this phase is incompatible with certification generation 2 and
supplies no authority. Gate execution is held shut by the Phase 9 predecessor receipt in certification
generation 2.

## Phase Summary

Phase 50 is `BOOTSTRAP_HANDOFF`. The runner's `ProcessObserver` launches `pb` as the child subject. `pb`
makes only the platform distinction needed to select its adapter, establishes the pinned toolchain beneath
`.build/**`, builds the single source-bound `amoebius`, and replaces itself with that binary while forwarding
`compile <corpus example>` unchanged. `amoebius validate` delegates by exec to `amoebius-validate`, so a public
`pb validate` spelling reaches the verifier only once this handoff is validated.

`Amoebius.Host.Handoff` carries the SHA-256 pin of `pb/__main__.py`, the adapter contract, the challenge
length, and the resource envelope as product values the runner reads. The observation logic the deleted
per-phase runner held lives there now, so the generic runner observes and the product declares. The candidate
binds the Phase 9 receipt digest and consumes a corpus example; the compile output through the handoff must
byte-equal the output the barrier recorded for that example.

Empty argv, help, version, bootstrap, validation, unknown verbs, and future commands are all interpreted after
handoff by Haskell. A keyword scan or public-help inventory cannot satisfy this contract; the observer reads
process identities, argv, environment, replacement, and exit from outside the child.

**Phase scope:** One cohesive claim — launched by the runner, `pb` establishes the contained toolchain, builds the exact source-bound binary, forwards a corpus compile argv unchanged, and terminates through the single resource-bounded exec adapter; it splits if Python is asked to interpret a user command or perform any post-handoff capability.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 9](phase_09_dsl_barrier.md)
**Gate:** `pb validate phase 50`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — certification generation 2, the protected accepted baseline, the authenticated
phase receipt, and the closure-based compatibility decision are Haskell-owned inputs. Execution evidence
remains phase-local and cannot be supplied by this prose.

| Key | Contract |
|---|---|
| `Claim` | Given the Phase 9 receipt digest, `pb` launched by the runner makes only the platform distinction, establishes the contained toolchain offline and serially, builds the exact source-bound `amoebius`, and execs it with `compile <corpus example>` unchanged. The compile output byte-equals the barrier's recorded output for that example, and the SHA-256 of the `pb` bytes equals the pin in `Amoebius.Host.Handoff`. Python never interprets a command, policy, result, or verdict. |
| `Subject` | `Amoebius.Host.Handoff` in `src/Amoebius/Host/Handoff.hs` — the pin, the adapter contract, the challenge length, and the resource envelope — the exact `pb/__main__.py` bytes with their single injected `BootstrapAdapter`, and the `validate` exec-delegation in `app/amoebius/Main.hs`. No other tracked `pb/**` path is admitted. |
| `Command` | Future public spelling is `pb validate phase 50`, which cannot supervise its own handoff. The agent runs `amoebius-validate preview phase 50`; the human runs `sudo amoebius-validate accept --phase 50`. The runner's `ProcessObserver` launches `pb` as the child with `compile <corpus example>`; `pb` forwards it unchanged; `amoebius validate` delegates by exec to `amoebius-validate`. |
| `Oracle` | `test/oracle/host/Main.hs` restates the pin, the expected argv, the process-replacement transcript, the challenge length, the resource envelope, and the corpus example's compile digest from literals; it depends on no `amoebius` library. |
| `Positive controls` | The clean handoff on the host platform; absent and present verified acquisition; the contained environment; the exact serial offline build; the corpus compile through the handoff; empty, help, version, and unknown argv forwarded unchanged. |
| `Paired negatives` | A changed `pb` byte, an ambient `PATH`, a network read, a rewritten argv, a return instead of exec, a wrong-length challenge, an endless entropy source, and a missing resource limit — each refused with its exact constructor and zero forbidden effects, with the twin accepted. |
| `Mutants` | Runner-generated from the fixed operator catalogue over `Amoebius.Host.Handoff`, eight per module, at most forty per gate, kill ratio at least 0.6; a mutant that alters the pin, the challenge length, or the envelope is killed by the oracle. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the observer's inventory of interpreter, child, executable, argv, challenge, replacement, and exit observations is complete; an empty or unclassified observation refuses. |
| `Challenge` | After the `pb` process starts, the runner obtains exactly 32 bytes through a fixed-count cryptographic operation and publishes them through a run-owned path; only the execed source-bound continuation can acknowledge them. The runner selects the corpus example after the run starts. |
| `Observer` | `ProcessObserver` over the interpreter, the toolchain children, the build, and the execed binary; executable identity, argv, environment, replacement, exit, peak memory, and termination reason are runner-captured. No Python or child log is trusted. |
| `Authority/bypass` | Only the authenticated interpreter, the verified `ghcup`, the exact contained GHC and Cabal, an explicit contained `PATH`, offline serial Cabal, fixed-count entropy, and enforced memory and deadline limits are admitted. Ambient `PATH`, network, host package managers, containers, providers, hardware, and recursive supervision are refused; `SUBJECT-NOT-SHIPPED` refuses a subject outside the closure. |
| `Freshness` | A unique run root; a copied indexed source; a challenge unique after the child starts; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The runner-generated mutant matrix over `Amoebius.Host.Handoff` — eight per module, at most forty, kill ratio at least 0.6 — precedes the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-50/**` and is absent afterward; marker-scoped cleanup proves zero owned processes on every exit path; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-VAL-007`, `LTD-VAL-008`, and `LTD-HELPER-001` close here through the compiled inventory; the gate consumes the Phase 9 receipt whose source snapshot has zero source-migration queries. |
| `Predecessor` | The Phase 9 receipt in certification generation 2, chained by the digest of Phase 9's product closure plus the verifier and governance digests. |
| `Residue` | Other native platforms, real package-manager and permission fidelity, Phase-51 host ensure, container engines, VMs, clusters, images, registry, hardware, and every product claim after the handoff remain explicit limitations. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and the human's `accept` records it. |

## Resource provision

- **Owner marker:** a run-local value binding the source snapshot, the Phase 9 receipt, the authenticated interpreter, the contained toolchain and build root, the process-tree identity, the resource budget, and the run identifier.
- **Preflight:** fresh read-only checks bind the `pb` bytes to the pin, the interpreter, an absent run root, the writable-path boundary, the memory-limit mechanism, and a monotonic clock before the child starts.
- **Allowed mutations:** only marker-owned processes and files beneath the one fresh `.build/**` run root needed for contained toolchain establishment, the source-bound build, and observations.
- **Forbidden mutations:** hardware, container engines, VMs, clusters, registries, networks, credentials, source-adjacent caches, tracked-tree writes, foreign processes, ambient tool selection, and paths outside the marked run root.
- **External observer:** the runner's `ProcessObserver` records raw process, executable, argv, environment, file-effect, replacement, resource-limit, peak-memory, termination, and exit observations without trusting Python or child logs.
- **Scoped cleanup:** on success, failure, interruption, or ambiguous outcome, terminate and remove only processes and run paths bound to the exact owner marker; memory exhaustion and deadline use the same path.
- **Zero-owned-residue:** after cleanup, every marker-owned process, toolchain scratch path, build output, observation pipe, and run path is absent; no retained resource is declared.

## Doctrine adopted

- [`repository_layout_doctrine.md` §2 — complete repository structure](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) — the sole non-Haskell source exception and its closed role.
- [`substrate_doctrine.md` §6 — the pre-binary handoff contract](../documents/engineering/substrate_doctrine.md#6-the-pre-binary-handoff-contract) — minimal platform adapter selection, contained establishment, source-bound build, and unchanged-argv exec only.
- [`validation_frame_doctrine.md` §2.3 — the handoff supervisor is resource-bounded](../documents/engineering/validation_frame_doctrine.md#23-the-handoff-supervisor-is-resource-bounded) — fixed-count entropy plus memory and deadline containment.
- [`gate_runner_doctrine.md` §3 — the runner](../documents/engineering/gate_runner_doctrine.md#3-the-runner) — the `ProcessObserver` that launches the child and holds every verdict.
- [`testing_spoof_resistance.md` §12.5 — fresh external observation](../documents/engineering/testing_spoof_resistance.md#125-fresh-external-observation) — bounded challenge acquisition, external observation, and forced-termination cleanup.

## Sprints

## Sprint 50.1: Bind the already-bounded bootstrap surface ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Host/Handoff.hs`
**Blocked by**: [Phase 9](phase_09_dsl_barrier.md) gate pass
**Independent Validation**: The exact `pb/__main__.py` bytes whose SHA-256 equals the pin, together with the adapter contract, are the positive control. A changed byte, a changed mode, a second tracked `pb/**` path, and a grammar node outside the Phase-2 admission are paired negatives refused by name. A generated mutant that alters the pin is killed by the oracle.
**Oracle**: `test/oracle/host/Main.hs` states the pin and the admitted path set from literals.
**Legacy IDs**: none — the Phase 9-bound zero-source-query result must remain zero
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/substrate_doctrine.md`

### Objective

Consume the Phase 9 receipt and bind the bounded `pb/**` snapshot, grammar, and adapter identity without
changing bootstrap source or reopening source migration.

### Deliverables

- The SHA-256 pin of `pb/__main__.py` and the adapter contract as product values.
- A no-write postcondition for the sole `pb/__main__.py` subject and the Git index and worktree.

### Validation

Compare the bytes with the pin; refuse each negative at its named locus; observe the tracked tree unchanged.

### Remaining Work

Implement the module. Any required `pb/**` change reopens its Phase-2 owner and reruns the chain through
Phase 9; this phase cannot make that change or close a source row.

## Sprint 50.2: Ensure and build in the contained root ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Host/Handoff.hs`
**Blocked by**: Sprint 50.1
**Independent Validation**: The observed contained ensure and build succeed with an explicit `PATH` naming only run-owned toolchain directories and every required baseline variable. An absent `PATH`, an ambient path, a foreign executable, a reordered precedence, and an undeclared variable are paired negatives refused at their exact loci before exec.
**Oracle**: `test/oracle/host/Main.hs` states the expected child environment and the selected executables from literals.
**Legacy IDs**: `LTD-VAL-008` — the contained child environment
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `documents/engineering/validation_frame_doctrine.md`

### Objective

Externally observe that the bounded bootstrap establishes the minimal Haskell toolchain and builds the one
executable without ambient paths or source-adjacent output.

### Deliverables

- The contained environment baseline as a product value: an explicit `PATH` for the verified `ghcup`, GHC, and Cabal children, with no ambient executable lookup.
- Observation of probe-first contained toolchain establishment and of the source-snapshot-bound build and exact binary identity.

### Validation

Observe every child's environment and executable; refuse each negative; reject a control whose acquisition did
not first succeed.

### Remaining Work

Implement the environment declaration. A discovered bootstrap defect reopens its Phase-2 owner rather than
being repaired inside this phase.

## Sprint 50.3: Exec-only validation handoff ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Host/Handoff.hs` and `app/amoebius/Main.hs`
**Blocked by**: Sprint 50.2
**Independent Validation**: The execed source-bound binary replaces the Python process with `compile <corpus example>` unchanged, and `amoebius validate` delegates by exec to `amoebius-validate`. A wrong binary, a rewritten argv, a return instead of exec, a swallowed failure, and a parsed verdict are paired negatives refused at their exact observation.
**Oracle**: `test/oracle/host/Main.hs` states the expected argv, replacement, and exit from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/testing_spoof_resistance.md`

### Objective

Observe every `pb <argv...>` invocation as the discriminate, establish, build, and opaque-exec handoff, never as
a command parser or gate.

### Deliverables

- Verbatim handoff of every argv, including empty, help, version, validation, and unknown cases.
- Exact binary-identity and process-replacement observation in one opaque receipt.
- The `validate` subcommand delegating by exec to `amoebius-validate`, so `pb` and its pin are untouched.

### Validation

Forge an observed argv or identity field without changing the child invocation and require custody failure.

### Remaining Work

Implement the delegation and the observation values.

## Sprint 50.4: Bound entropy and supervisor resources ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Host/Handoff.hs`
**Blocked by**: Sprint 50.3
**Independent Validation**: Exactly 32 bytes reach the continuation within the declared budget; wrong-length and endless entropy cases refuse; a child exceeding the memory ceiling or the deadline is stopped inside the runner-owned envelope at its assigned row; cleanup leaves zero owned residue.
**Oracle**: `test/oracle/host/Main.hs` restates the challenge length, the memory ceiling, the swap allowance, and the deadline from literals.
**Legacy IDs**: `LTD-VAL-007` — bounded entropy and resources
**Docs to update**: `documents/engineering/validation_frame_doctrine.md`, `documents/engineering/testing_spoof_resistance.md`

### Objective

Make the handoff finite in entropy consumption, memory, elapsed time, and cleanup before it can contribute an
observation.

### Deliverables

- The challenge as a fixed-count cryptographic operation returning exactly 32 bytes, failing closed on any other length.
- An 8,589,934,592-byte memory ceiling, zero swap allowance, and 1,800-second monotonic deadline declared in `Amoebius.Host.Handoff` and enforced by the runner over the whole process tree.
- Termination reason, peak memory, challenge length, and acknowledgement as external observations.
- One marker-scoped cleanup path for success, refusal, signal, memory exhaustion, deadline, interruption, and ambiguity.

### Validation

Run the legal bounded control, then the short-read, endless-stream, missing-limit, and forced-cleanup cases;
require each to finish inside the envelope with its assigned reason.

### Remaining Work

Implement the envelope declaration.

## Sprint 50.5: Bounded-bootstrap candidate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Handoff.hs` and `amoebius.cabal`
**Blocked by**: Sprint 50.4
**Independent Validation**: The compiled specification verifies and its `BinaryFact` names `amoebius compile` through the handoff; the complete handoff succeeds with exact custody; the corpus compile digest equals the barrier's; no interpreter other than `pb` appears on the control-plane deploy path in the observer's trace.
**Oracle**: `test/oracle/runner/Main.hs` for the specification; `test/oracle/host/Main.hs` for the compile digest.
**Legacy IDs**: `LTD-HELPER-001` — the untracked helper on the control-plane deploy path
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through the human's `accept`

### Objective

Produce a candidate for complete gate execution without treating a successful handoff as a gate pass, and
retire the untracked helper by reaching the deploy path only through the shipped binary.

### Deliverables

- The Phase-50 `GateSpec` with its `BinaryFact`.
- Deletion of the per-phase boundary runner and its oracle.
- The control-plane deploy path reached only through `compile` and `apply` of the shipped binary.

### Validation

Run `preview phase 50` and require every row green; require the human's `accept` to record exactly one
phase's patch.

### Remaining Work

Everything above. The `accept` ends this phase.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes, never before):**

- `documents/engineering/validation_frame_doctrine.md` — only if the challenge or the resource envelope changes.
- `documents/engineering/substrate_doctrine.md` — only if the bounded bootstrap roles or the adapter seam change.
- `documents/engineering/repository_layout_doctrine.md` — only if the source exception changes.

**Cross-references to add:**

- Phase 9 predecessor gate pass and Phase 51 consumer links.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 9](phase_09_dsl_barrier.md) — the predecessor
- [Phase 2 repository layout conformance](phase_02_repository_layout_conformance.md) — static admission of the bootstrap
- [Phase 51 host-ensure kernel](phase_51_host_ensure_kernel.md) — the consumer
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Substrate doctrine](../documents/engineering/substrate_doctrine.md)
- [Validation-frame doctrine](../documents/engineering/validation_frame_doctrine.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
