# Validation execution doctrine

> **Purpose**: Define native validation, its bootstrap assumptions, and the execution boundary separating
> candidate code from tools, expectations, observations, and evidence.
> **Read this if**: a validation process needs an admissible toolchain, isolated inputs, or bounded effects.

This document owns execution placement, tool acquisition, privilege separation, and run-state containment.
The complete language pipeline belongs to
[`conformance_harness_doctrine.md`](./conformance_harness_doctrine.md); observation adequacy belongs to
[`testing_spoof_resistance.md`](./testing_spoof_resistance.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: the image-first validation-frame rule previously carried by this file
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, README.md, documents/engineering/README.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/glossary.md
**Generated sections**: none

</details>

## Contents

- [1. Native Haskell is the validation environment](#1-native-haskell-is-the-validation-environment)
- [2. The bootstrap boundary](#2-the-bootstrap-boundary)
- [3. Why native validation is `Substrate: none`](#3-why-native-validation-is-substrate-none)
- [4. Generated output and cleanroom execution](#4-generated-output-and-cleanroom-execution)
- [5. Container execution is later parity evidence](#5-container-execution-is-later-parity-evidence)
- [Related Documents](#related-documents)

- [2.1 GenesisTrust is an irreducible root](#21-genesistrust-is-an-irreducible-root)
  - [2.2 The bounded `pb` handoff](#22-the-bounded-pb-handoff)
  - [2.3 The handoff supervisor is resource-bounded](#23-the-handoff-supervisor-is-resource-bounded)

---

## 1. Native Haskell is the validation environment

All product, DSL, generator, validation, test, oracle, fake, and mutation logic is tracked as Haskell source.
The Haskell binary validates the language directly, before a container engine, base image, registry, cluster,
accelerator, or cloud account exists.

This ordering is mandatory:

```text
GenesisTrust records exact prepared local-custody bytes plus narrow compile-time/platform facts
  → Phase 0 qualifies a finite governance, source-classification, and gate seed
  → Phase 1 authenticates and reproduces the toolchain acquisition derived from that root
  → Phase 2 closes the compiler-backed semantic source graph
  → Haskell DSL/proof/generator validation
  → Phase 49 no-hardware gate barrier
  → Phase 50 externally observes the already source-bounded pb handoff
  → Phase 51 Haskell host-ensure against fake boundaries
  → Phase 52 first hardware work
  → optional image parity replay
```

A phase may not require a container merely because a compiler or interpreter used to be packaged in one.
Haskell generates external-language artifacts lazily beneath `.build/**`. Their actual compiler or interpreter
remains necessary when the claim includes valid or executable generated code. The Haskell source rule does
not permit replacing that consumer with a token scan.

Numerical order governs phase-gate execution, predecessor evidence, and status. It does not forbid preparing a
later `Substrate: none` implementation after that sprint's exact typed contract and independent oracle exist.
Such preparation is only a component observation: it cannot mint phase evidence, invoke an unavailable
predecessor, use `pb` before its handoff gate, or touch a live, host, image, container, cluster, accelerator, or
provider boundary.

---

## 2. The bootstrap boundary

### 2.1 `GenesisTrust` is an irreducible root

`GenesisTrust` is the explicit non-numbered `BootstrapRoot` below Phase 0. It records local custody of seven
exact prepared compiler/package-tool archive and signature files, compile-time GHC `9.12.4`, absolute reported
`ghc` and library-directory paths, and Linux/`x86_64`. The signature files are opaque pinned bytes, not a
publisher-verification result. Those facts enter as a named operator input outside Git; they are neither
generated source nor a capability supplied by a numbered phase.

Phase 0 must bind that narrow input to its invocation and evidence. It cannot authenticate the compiler's
derivation, publisher, loader, host, or reproducibility by inspecting only the binary that compiler produced.
These are named root assumptions, not silently discharged proof obligations.

Phase 1 owns broader acquisition and provenance; Phase 2 owns compiler-backed source closure. The DSL barrier
owns universal qualification. These later obligations must not become recursive prerequisites for the finite
Phase-0 seed. Exact root inputs and supported build platform are owned by the
[Phase-0 contract](../../DEVELOPMENT_PLAN/phase_00_documentation_suite.md).

### 2.2 The bounded `pb` handoff

`pb/**` is the sole tracked non-Haskell source exception. It may:

1. make the minimum platform distinction needed to select the toolchain-establishment adapter;
2. establish the pinned Haskell toolchain into `.build/**`;
3. build the single source-bound Haskell binary; and
4. replace itself with that binary while forwarding every user argument unchanged.

It may not discover tests, define expectations, interpret evidence, decide a gate verdict, generate product
or host-floor policy, implement help/version or another public command, perform phase work, or set Done status.
`pb validate phase NN`, `pb --help`, `pb --version`, unknown verbs, and every other argv are opaque to Python;
after establish/build, the exact argv reaches Haskell by exec. A Python exit-code wrapper around another gate
is prohibited.

Phase 0 requires the exact current captured bootstrap bytes to pass the non-empty, deny-by-default Haskell-owned
admission predicate. Its scoped `SourcePb` result must be zero for that snapshot, but the finite seed does not
qualify the complete `VALIDATION_PB_GRAMMAR` selector/oracle suite, run the Phase-2 owner analyzer, or retire
`LTD-SRC-008`. Phase 2 owns that full grammar qualification together with compiler-backed source closure. This
static source-admission result does not establish that an effect or exec occurred.
Phase 49 invokes Haskell directly; the Phase-50 candidate starts the exact source-built Haskell OS supervisor
directly, which invokes `pb` as its observed child and records the adapter plus ensure/build/executable-identity/
unchanged-argv/exec runtime handoff. The future public spelling cannot supervise itself. A keyword scan or
command listing cannot establish semantic scope. Any
new `pb/**` behaviour outside the four admitted operations is a source-closure failure even if its extension
remains `.py`.

### 2.3 The handoff supervisor is resource-bounded

Phase 50 applies the general [fresh-observation resource rule](./testing_spoof_resistance.md#125-fresh-external-observation)
to the Haskell process that supervises `pb`. The challenge is exactly 32 unpredictable bytes obtained by a
fixed-count cryptographic entropy operation. The supervisor refuses any other length before publishing the
run-owned challenge and never performs a strict whole-stream read from `/dev/urandom` or another
non-terminating source.

The complete handoff must run beneath an outer Haskell-owned containment envelope. Its typed budget binds
memory, swap, monotonic deadline, process-tree identity, termination classification, and marker-scoped cleanup.
The exact limits belong to the [Phase-50 contract](../../DEVELOPMENT_PLAN/phase_50_host_assert_cli.md), rather
than a second numerical table in doctrine.

Missing enforcement, memory exhaustion, deadline, signal, orphan, or unexplained termination produces the
assigned red observation. A clean run exceeding its bound does not automatically widen it from host resources.
Changing the bound changes the contract and invalidates affected evidence.

The independent Phase-50 oracle owns exact positive and negative expectations. It requires the 32-byte
challenge, acknowledgement, bounded peak-memory observation, and completion within the declared deadline. It
also rejects the former strict-read-then-truncate expression, wrong-length entropy, an endless entropy source,
omitted containment, and retained processes or files after forced termination. The limits are independently
restated Haskell values bound into candidate evidence; host defaults cannot choose or widen them.

The [development-plan audit](../../DEVELOPMENT_PLAN/README.md#current-implementation-audit) owns historical
resource failures and current repair progress. This rule states required behaviour and does not attribute a
passing handoff or completed repair.

---

## 3. Why native validation is `Substrate: none`

`Substrate: none` means that the claim does not depend on a hardware-specific or live-infrastructure fact.
For Phase 0, the compiler version/path and platform carried by the narrow GenesisTrust token are assumed build
facts, not authenticated toolchain provenance; Phase 1 makes subsequent acquisition authenticated and
reproducible. Through Phase 49 that toolchain remains a build prerequisite, not
evidence about Linux, Apple, Windows, CUDA, Metal, a container engine, or a published image. Phase 50 separately observes the
bounded `pb` runtime handoff; it cannot retroactively strengthen an earlier semantic result.

Pure and fake-boundary gates therefore remain Register 1 or 2 and `Substrate: none`. They record the compiler
and source snapshot used for provenance, but no toolchain version or host identity strengthens the semantic
claim. Hardware-specific phases begin only after the complete no-hardware DSL barrier receives a passing gate
result.

---

## 4. Generated output and cleanroom execution

**The problem.** A fresh output directory can still consume a stale executable, ambient package store, or
candidate-written success transcript. Shared write authority also lets the candidate change a supposedly
independent expectation after its identity was recorded.

**Why the obvious alternative fails.** An absolute path and version string identify neither executable bytes
nor their provenance. A digest recorded after candidate execution can authenticate substituted bytes. A
read-only copy without an enforced privilege boundary can still be replaced by its effective owner.

**The rule.** The supervising runner acquires and binds the source snapshot, requirement and expectation
baseline, qualification corpus, tools, dependencies, and predecessor receipt before candidate execution.
Candidate code receives only declared read capabilities and run-owned write capabilities. It cannot replace
those authorities, their parent directories, their process identities, or the runner's observations.

Outside the explicitly assumed `GenesisTrust` root, tools must be bound to authenticated acquisition and
actual executable bytes, including the interpreter, loader,
configuration, and dependency closure required by the claim. A wrapper reporting the expected compiler version
cannot qualify as that compiler. Tool identity must survive replacement, symlink, and race challenges at the
consumption boundary.

The privilege separation must be enforced by the execution environment, with its mechanism recorded and
qualified. Directory permissions under the same unrestricted principal do not establish an adversarial
boundary. If the required protection cannot be enforced, the gate refuses that claim rather than silently
assuming protection from candidate tampering.

The canonical source checkout and separately acquired oracle baseline remain readable inputs. Generated
materializations, protected runner state, toolchains, dependency caches, and evidence stay beneath physical
repository-owned roots. Separate ownership or process capabilities do not authorize state outside the checkout.
The [repository-layout doctrine](./repository_layout_doctrine.md) owns those roots and their lifecycles.

Each candidate begins with an absent run namespace under `.build/runs/**`. Retained inputs are explicit and
read-only: authenticated toolchain/package inputs, protected expectations, source snapshot, and the exact
required predecessor receipt. Their presence is part of the acquisition contract; unlisted ignored artifacts
or ambient caches are unavailable. Production `.data/**` is inaccessible and must never be deleted for validation.

Phase 0 retains its bounded `GenesisTrust` exception and one uniquely owned qualification leaf. It records
only its declared input closure and verifies its own leaf cleanup. Universal cleanroom and adversarial
input-closure qualification remain assigned to the DSL barrier. All deliberate output goes beneath `.build/**`,
including:

- compiled objects and dependency stores;
- generated Dhall, PureScript, JavaScript, shell, Proto, Pulumi, Dockerfile, manifest, and serialized views;
- fixtures, negatives, mutation worktrees, inventories, and discovered surfaces;
- raw observations, ledgers, and candidate bundles; and
- `pb` interpreter caches or tool environments.

The runner records actual process exits, streams, read inputs, observed effects, and cleanup. Candidate reports
are data to validate, not authority to mint observations. Qualification must expose transcript replay,
executable replacement, expectation edits, fabricated process identities, and missing dependency observations.

Every validator leaves tracked files unchanged. After a qualified success, it emits the exact status-only
patch beneath the protected run root. A human, agent, or CI job may apply that patch after checking its bound
preimage. Automated progression then continues without routine sprint or phase approval.

**What it forecloses.** A current source digest cannot compensate for an untrusted tool or a candidate-owned
oracle. File containment cannot compensate for missing privilege separation. Even an enforced boundary still
assumes the supervising kernel, privilege authority, and selected cryptographic mechanisms behave correctly.
Those residual assumptions must be explicit in the root and each dependent claim.

---

## 5. Container execution is later parity evidence

After host and image phases pass their qualified gates, the same Haskell validation command may be replayed inside the
published runtime image. That replay can test toolchain packaging, architecture, library availability, and
host/image parity. It cannot:

- establish an earlier DSL phase;
- replace the native pre-hardware run;
- turn a model or fake-boundary result into live evidence;
- make another architecture validated; or
- hide a difference by selecting a stale fixed-name image.

The image phase records its own source and recipe identity and leaves semantic language claims attributed to
the earlier barrier. Browser or other specialized test images follow the same rule: they are later execution
substrates for the behaviour they uniquely expose, not general validation authorities.

Current phase status is reported only by the
[development-plan tracker](../../DEVELOPMENT_PLAN/README.md#phase-overview). This doctrine states the target
execution order and makes no current image, host, or phase-result claim.

---

## Related Documents

- [No-cluster conformance harness](./conformance_harness_doctrine.md)
- [Testing doctrine](./testing_doctrine.md)
- [Testing spoof resistance](./testing_spoof_resistance.md)
- [Image-build doctrine](./image_build_doctrine.md)
- [Substrate doctrine](./substrate_doctrine.md)
- [Generated-artifacts doctrine](./generated_artifacts_doctrine.md)
- [Development-plan phase model](../../DEVELOPMENT_PLAN/development_plan_phase_model.md)
- [Development-plan gate integrity](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md)
