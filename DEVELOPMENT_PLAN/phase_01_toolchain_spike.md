# Phase 1: Haskell toolchain and probe-source closure

> **Purpose**: Consume the explicit non-numbered `GenesisTrust` root, reproduce the contained Haskell toolchain acquisition, report its digests through the shipped binary, and build the retained probe set from pinned network-independent inputs without tracking resolution output or host-specific paths.
> **Read this if**: Phase 1 is next in the queue, or a later phase depends on what its gate establishes.

Phase 1 specifies the first reproducibility claim of the plan. The toolchain Phase 0 assumed is acquired
twice from the pinned files, and the shipped `amoebius` binary reports digests equal to the pins spelled once
in product code. Its predecessor is [Phase 0](phase_00_documentation_suite.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, documents/engineering/content_addressing_determinism.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/pulsar_client_doctrine.md
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

## Phase Status

🔄 Active — NOT VALIDATED.

The contract is reopened under [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) by
[DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice): the subject moves
from the validator into product code. Under §N step 3, every generation-1 receipt for this phase is
incompatible with certification generation 2 and supplies no authority. Gate execution is held shut by the
Phase-0 predecessor receipt in certification generation 2.

## Phase Summary

Phase 1 moves the toolchain claim out of the validator and into the product. `Amoebius.Toolchain.Pins` spells
the seven `GenesisTrust` pins and the compiler and package-tool identities once; `amoebius toolchain-report`
prints the digests of what it observes; the independent oracle restates the pins from literals and compares.
Two contained acquisitions from the same pinned files must agree on executable identity and elaborated plan.

The probe set is retained. The in-process decoder, the deterministic simulator, the resolver dependencies, the
browser-contract generator, and the maintained fork with its codegen link into the shipped binary and are
exercised by the same report. No resolution output, package-integrity pin, generated code, or host-specific
path is tracked; every derived product is rendered beneath `.build/**` during the run.

`GenesisTrust` remains the explicit assumption. Agreement between two acquisitions closes `LTD-BOOT-001`; it
does not turn the root into a theorem, and it does not authenticate the publisher keyring the signature check
consults.

**Phase scope:** One cohesive claim — the shipped binary's toolchain report equals the product-side pins for two contained acquisitions, and the retained probe set builds and executes offline; it splits if a claim needs compiler-wide source semantics, product behaviour, or a host.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 0](phase_00_documentation_suite.md)
**Forward-deferred:** compiler-backed source closure — [Phase 2](phase_02_repository_layout_conformance.md) `repository_layout_conformance` / `LTD-SRC-000`; the re-run of every hardware-free gate through the shipped binary — [Phase 9](phase_09_dsl_barrier.md)
**Gate:** `pb validate phase 01`; see [Gate integrity](#gate-integrity).

### Gate specification

```gate-spec
capability: toolchain_spike
subjects:
  - Amoebius.Toolchain.Pins
  - Amoebius.Toolchain.Acquire
  - Amoebius.Toolchain.Probe
  - Amoebius.Toolchain.Resolve
  - Amoebius.Toolchain.Provenance
  - Amoebius.Toolchain.Report
suite: toolchain-suite
oracle: oracle-toolchain
positives: [pinned-acquisition, second-acquisition, probe-decode, probe-sim, probe-deps]
negatives: [MistypedDecode, PerturbedSchedule, MissingDependency, MutableIdentity, TrackedProbeInput, TopLevelVendor, TrackedResolutionOutput]
mutants: { perModule: 8, perGateCap: 40, killRatio: 0.6 }
binaryFact:
  command: amoebius toolchain-report
  perturbation: archive-copy-to-nonce
  outputs: [toolchain-report]
substrate: HardwareFree
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | From `GenesisTrust` and its seven pinned files, two contained acquisitions produce the pinned compiler and package tool, and `amoebius toolchain-report` prints executable, archive, and plan digests equal to the pins the oracle restates. The retained probe set builds offline and serially and prints the oracle's expected outputs. Network, host, product, and source-closure claims are excluded. |
| `Subject` | The six stage modules named in the gate specification, the `toolchain-report` subcommand in `app/amoebius/Main.hs`, and the maintained fork modules beneath `src/vendor/**`. Every subject is inside the closure of `executable amoebius`. |
| `Command` | Future public spelling is `pb validate phase 01`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 01`; then `amoebius-validate accept --phase 01` records the receipt and applies one phase's status patch. The runner spawns the shipped `amoebius` binary as a child for `toolchain-report`; every Cabal child carries `--offline` and `--jobs=1`. |
| `Oracle` | `test/oracle/toolchain/Main.hs` restates the seven pins, the compiler and package-tool identities, the expected probe outputs, and the refusal loci from literals; it depends on no `amoebius` library. |
| `Positive controls` | Publisher-signature verification of the pinned manifests, two contained acquisitions agreeing on executable identity and plan, the probe set linked and executed, the positive decode, and the unperturbed simulation terminal state. |
| `Paired negatives` | A mistyped decode case, a perturbed simulation schedule, a missing required dependency, a mutable acquisition identity, a tracked foreign probe input, a top-level vendor reintroduction, and a tracked resolution output — each refused at its exact locus with its twin accepted. |
| `Mutants` | Runner-generated from the fixed operator catalogue over the six stage modules, eight per module, at most forty per gate, kill ratio at least 0.6; a mutant in `Amoebius.Toolchain.Pins` is killed by the oracle's pin comparison. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the probe entry points the report exercises equal the oracle's set; empty discovery refuses. |
| `Challenge` | After the run starts, the runner copies one pinned archive beneath the run root and rewrites one byte to a nonce; the report over that copy must carry the changed digest, and the pin comparison must refuse at exactly that archive. |
| `Observer` | `ProcessObserver` over the shipped binary, the signature verifier, and every Cabal child; executable identity, argv, environment policy, exit, and complete output are runner-captured. No subject log is trusted. |
| `Authority/bypass` | Network, `pb`, compiler concurrency above one, a `PATH`-selected compiler, a mutable reference, and tracked generated behaviour are refused by name. `SUBJECT-NOT-SHIPPED` refuses a subject outside the executable's closure; the oracle stanza's hygiene refuses a product dependency. Cabal's user store is a cache, never evidence. |
| `Freshness` | A unique run root; both acquisition roots absent at acquisition; the verifier digest equals the seed's; opening and closing source identities are equal; no prior candidate can satisfy the nonce. |
| `Qualification` | The runner-generated mutant matrix over the six stage modules — eight per module, at most forty, kill ratio at least 0.6 — precedes the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-01/**` and is absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-BOOT-001`, `LTD-SRC-007`, and `LTD-SRC-009` close here through the compiled inventory; the due-count for every other identifier is zero. |
| `Predecessor` | The Phase-0 receipt in certification generation 2, chained by the digest of Phase 0's product closure plus the verifier and governance digests. |
| `Residue` | `GenesisTrust` remains the explicit local-custody assumption, and the publisher keyring is an operator-supplied input that is trusted rather than authenticated. Phase-2 source closure and every product and hardware claim remain explicit limitations. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and `accept` records it. |

## Resource provision

- **Owner marker:** the source snapshot, the Phase-0 receipt, the unique Phase-1 run root, and the two acquisition-root identities.
- **Preflight:** the run root and both acquisition roots are absent; the seven pinned files are present at their pinned sizes and digests.
- **Allowed mutations:** compiler products, extracted toolchains, rendered probe cases, and observations beneath `.build/runs/phase-01/**`.
- **Forbidden mutations:** network, host package managers, ambient `PATH`, authored source, and any path outside the owner root.
- **External observer:** the runner's `ProcessObserver` records every child executable, argv, exit, and transcript digest.
- **Scoped cleanup:** the owner root is removed on every exit path; Cabal's user store is neither created nor removed as evidence.
- **Zero-owned-residue:** the owner root is absent afterward and no authored path changed.

## Doctrine adopted

- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` this phase carries.
- [`validation_frame_doctrine.md` §2.1 — `GenesisTrust` is an irreducible root](../documents/engineering/validation_frame_doctrine.md#21-genesistrust-is-an-irreducible-root) — the assumption this phase reproduces from but never proves.
- [`dsl_doctrine.md` §9 — toolchain note](../documents/engineering/dsl_doctrine.md#9-toolchain-note) — the in-process decoder dependency the probe set carries.
- [`gateway_migration_model_doctrine.md` §4 — simulate and prove](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove) — the deterministic-simulation dependency; no model-checking result is claimed.
- [`content_addressing_determinism.md` §4.5 — the ML-asset lifecycle](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss) — the resolver dependencies, without tracking any materialized asset.
- [`repository_layout_doctrine.md` §4.1 — a compatibility edit is fixed source](../documents/engineering/repository_layout_doctrine.md#41-a-compatibility-edit-is-fixed-source-not-a-patch-against-a-moving-head) — the maintained fork and the absence of a patch root.

## Sprints

## Sprint 1.1: GenesisTrust-bound toolchain acquisition 🔄

**Status**: Active — NOT VALIDATED
**Implementation**: `src/Amoebius/Toolchain/Pins.hs` and `src/Amoebius/Toolchain/Acquire.hs`
**Blocked by**: [Phase 0](phase_00_documentation_suite.md) gate pass
**Independent Validation**: Two contained acquisitions from the seven pinned files that agree on compiler and package-tool executable identity and on the elaborated plan are the positive control. A missing pin, a digest mismatch, a signature mismatch, an ambient-network read, and a disagreeing second acquisition are paired negatives refused by name. A generated mutant in `Amoebius.Toolchain.Pins` is killed by the oracle's pin comparison.
**Oracle**: `test/oracle/toolchain/Main.hs` states the seven pins and the expected executable identities from literals; it imports no `amoebius` module.
**Legacy IDs**: `LTD-BOOT-001` — authenticated reproducible acquisition
**Docs to update**: `documents/engineering/validation_frame_doctrine.md`

### Objective

Turn the irreducible `GenesisTrust` input into a reproducible, authenticated contained acquisition whose
identities are spelled once in product code, without pretending that the resulting binary proves its own
compiler.

### Deliverables

- `Amoebius.Toolchain.Pins` with the seven pins and the compiler and package-tool identities.
- `Amoebius.Toolchain.Acquire` verifying the publisher signatures, extracting into two contained roots, and building the same source under both with `--offline --jobs=1`.
- A typed acquisition receipt per root, rendered beneath `.build/**` and never tracked.

### Validation

Acquire twice; compare identities and plans with the oracle's literals; refuse each negative at its named
locus. Preserve `GenesisTrust` as an explicit assumption in the residue row.

### Remaining Work

Implement the two modules. The validator-side acquisition supervisor is deleted in Sprint 1.8.

## Sprint 1.2: `dhall` in-process decoder build probe (gadt-decode dependency) ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Toolchain/Probe/Decode.hs`
**Blocked by**: Sprint 1.1
**Independent Validation**: The positive decode case yields the oracle's literal value through the in-process `dhall` decoder linked into the shipped binary; the one-field-mistyped twin is refused with the decoder's type-error tag. Both cases are rendered beneath `.build/probe/**` after the run starts.
**Oracle**: `test/oracle/toolchain/Main.hs` states the expected decoded value and the rejection tag from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Adopt [`dsl_doctrine.md` §9 — toolchain note](../documents/engineering/dsl_doctrine.md#9-toolchain-note): prove
that the in-process decoder dependency builds and executes on the pin before Phase 3 promises a typed decoder.

### Deliverables

- The decode probe as a module the report exercises, with one positive and one mistyped case.
- The compatibility requirement that makes the decoder build on the pinned compiler, authored as a Haskell value and never as a freeze file.

### Validation

Decode the positive and refuse the twin; compare both outcomes with the oracle's literals.

### Remaining Work

Implement the probe module and its compatibility declaration.

## Sprint 1.3: `io-sim` + `io-classes` simulation build probe ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Toolchain/Probe/Sim.hs`
**Blocked by**: Sprint 1.2
**Independent Validation**: The unperturbed two-writer schedule reaches the oracle's literal terminal state; the perturbed schedule reaches a different literal state; a probe that exits without printing a terminal state is refused.
**Oracle**: `test/oracle/toolchain/Main.hs` states both terminal states from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/gateway_migration_model_doctrine.md`

### Objective

Adopt [`gateway_migration_model_doctrine.md` §4 — simulate and prove](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove):
prove that the deterministic-simulation dependency builds and runs on the pin before the gateway-migration
model is authored.

### Deliverables

- The simulation probe with a clean arm and a perturbed arm, the schedule as a Haskell value.
- A terminal state printed by the probe, never a self-reported exit alone.

### Validation

Run both arms; compare the terminal states with the oracle's literals.

### Remaining Work

Implement the probe module.

## Sprint 1.4: `supernova` fork + `proto-lens` codegen build probe ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Toolchain/Probe/Codegen.hs` and the maintained fork modules beneath `src/vendor/**`
**Blocked by**: Sprint 1.3
**Independent Validation**: The fork and its protobuf codegen link into the shipped binary and the report prints the oracle's literal link token; the generated bindings are rendered beneath `.build/proto/**`; a removed fork identity is refused at the resolution locus.
**Oracle**: `test/oracle/toolchain/Main.hs` states the link token and the expected generated-module set from literals.
**Legacy IDs**: none — `LTD-SRC-009` is owed by Sprint 1.7
**Docs to update**: `documents/engineering/pulsar_client_doctrine.md`

### Objective

De-risk the native Pulsar client's fork and its codegen on the shared pin before the Pulsar-client phase
promises it, so a fork that will not compile is found here rather than mid-implementation.

### Deliverables

- The codegen probe as a module the report exercises.
- The fork identity as a Haskell value; generated bindings beneath `.build/proto/**` only.

### Validation

Build and link; compare the token and the generated set with the oracle; refuse the removed identity.

### Remaining Work

Implement the probe and bind the fork identity.

## Sprint 1.5: Dynamic resolution and generated-output migration ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Toolchain/Resolve.hs`
**Blocked by**: Sprint 1.4
**Independent Validation**: A compatibility declaration that names no resolved path, checksum, or solver graph resolves to a plan beneath `.build/toolchain/**`; a tracked freeze file, a tracked package pin, and a developer-home path are paired negatives refused at the source-closure locus.
**Oracle**: `test/oracle/toolchain/Main.hs` states the refused path set from literals.
**Legacy IDs**: `LTD-SRC-007` — foreign probe inputs
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`

### Objective

Replace permanent pins, lock files, hard-coded package checksums, developer-home paths, and repository-retained
generated evidence with run-local resolution from authored Haskell requirements.

### Deliverables

- Authored compatibility requirements as Haskell values containing no resolved path, package checksum, or solver graph.
- A resolver that writes the selected graph and tools only beneath `.build/**`.
- Probe cases rendered beneath `.build/probe/**` from Haskell declarations.

### Validation

Resolve twice from the pinned input; confirm every generated output is ignored and every authored path is
unchanged; refuse each tracked artefact by name.

### Remaining Work

Implement the resolver and the refusals.

## Sprint 1.6: Pure discovery/ensure planning over injected inputs ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Toolchain/Plan.hs`
**Blocked by**: Sprint 1.5
**Independent Validation**: The plan over an injected empty inventory and an authenticated provider catalogue equals the oracle's literal step list; an absent tool, an out-of-range version, and a platform with no asset are refused rather than substituted. The plan reads no host.
**Oracle**: `test/oracle/toolchain/Main.hs` states the expected step list and the refusals from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Model [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)
as a pure plan over injected inventories, ahead of the boundary-with-fakes interpreter
[Phase 51](phase_51_host_ensure_kernel.md) owns.

### Deliverables

- A `managed` source kind — a tool installed by another resolved tool — and no `host` source kind.
- The floor as a Haskell value evaluated only against an injected inventory, each failure carrying its remedy.
- One canonical `<os>-<arch>` platform value, supplied as a case rather than discovered.

### Validation

Evaluate the plan; compare with the oracle; refuse each negative without selecting a foreign asset.

### Remaining Work

Implement the planner.

## Sprint 1.7: Remove top-level vendor source and own the Haskell fork ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Toolchain/Provenance.hs` and the maintained fork modules beneath `src/vendor/**`
**Blocked by**: Sprint 1.6
**Independent Validation**: A clean build from the immutable upstream identity is the positive control; a mutable reference, an absent identity, a developer-home path, and a digest that does not match the acquired bytes are refused; a reintroduced top-level `vendor/**` path is refused at the layout locus.
**Oracle**: `test/oracle/toolchain/Main.hs` states the upstream identity and the refusals from literals.
**Legacy IDs**: `LTD-SRC-009`
**Docs to update**: `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/pulsar_client_doctrine.md`

### Objective

Adopt [`repository_layout_doctrine.md` §4.1 — a compatibility edit is fixed source](../documents/engineering/repository_layout_doctrine.md#41-a-compatibility-edit-is-fixed-source-not-a-patch-against-a-moving-head):
maintained Haskell beneath `src/vendor/**`, upstream material beneath `.build/vendor/**` at an immutable
identity, and no patch root.

### Deliverables

- `Amoebius.Toolchain.Provenance` recording the immutable upstream identity as a Haskell value.
- No top-level `vendor/**`, no patch program, no tracked foreign package description, and no post-checkout command.
- Acquired upstream material beneath `.build/vendor/**` is a verified archive extraction at the recorded
  identity and never a nested version-control checkout, so `git clean -fxd` alone restores a pristine tree.

### Validation

Build from the pinned input; refuse each negative at its named locus.

### Remaining Work

Implement the provenance value and the refusals.

## Sprint 1.8: jit-build resolver deps + `purescript-bridge` + consolidated probe gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Toolchain/Report.hs`, `app/amoebius/Main.hs`, `src/gate-spec/Amoebius/Validation/GateSpec/Toolchain.hs`, and `amoebius.cabal`
**Blocked by**: Sprint 1.7
**Independent Validation**: `amoebius toolchain-report` prints the digests and probe outputs the oracle restates; the compiled specification equals the fenced block above; a dropped compatibility allowance is refused at the resolution locus; a stanza whose module map disagrees with the subjects is refused at discovery.
**Oracle**: `test/oracle/toolchain/Main.hs` for the report; `test/oracle/runner/Main.hs` for the specification digest.
**Legacy IDs**: none due here beyond the closures recorded above
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Fold the resolver dependencies and the browser-contract generator into the one report, so the whole
pre-cluster in-process surface is proven buildable as one dependency universe. The gate runs last because it
is the only run over the final source.

### Deliverables

- `toolchain-report` as a subcommand of the shipped binary, exercising every probe module.
- The Phase-1 `GateSpec` with its `BinaryFact`.
- Deletion of the validator-side toolchain runner and its oracle.

### Validation

Run `preview phase 01` and require every row green; require `accept` to record exactly one
phase's patch.

### Remaining Work

Everything above. The `accept` ends this phase.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes, never before):**

- `documents/engineering/validation_frame_doctrine.md` — only if the `GenesisTrust` boundary or the acquisition contract changes.
- `documents/engineering/repository_layout_doctrine.md` — only if the dependency-resolution or vendor-provenance rule changes.
- `documents/engineering/dsl_doctrine.md` — only if the toolchain note's decoder dependency changes.
- `documents/engineering/pulsar_client_doctrine.md` — only if the maintained fork's identity or split changes.

**Cross-references to add:**

- Phase 0 predecessor gate pass and Phase 2 consumer links.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 0 documentation suite](phase_00_documentation_suite.md) — the predecessor and the `GenesisTrust` pins
- [Phase 2 repository layout conformance](phase_02_repository_layout_conformance.md) — source closure over the toolchain this phase establishes
- [Phase 9](phase_09_dsl_barrier.md) — re-runs this gate through the shipped binary
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
- [Validation-frame doctrine](../documents/engineering/validation_frame_doctrine.md)
- [DSL doctrine](../documents/engineering/dsl_doctrine.md)
- [Gateway migration model doctrine](../documents/engineering/gateway_migration_model_doctrine.md)
- [Content addressing and determinism](../documents/engineering/content_addressing_determinism.md)
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Pulsar client doctrine](../documents/engineering/pulsar_client_doctrine.md)
