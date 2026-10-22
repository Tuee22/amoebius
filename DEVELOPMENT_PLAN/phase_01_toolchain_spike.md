# Phase 1: Haskell toolchain and probe-source closure

> **Purpose**: Check native GHCup/GHC versions, exercise the retained decoder, simulator, codegen, dependency and provenance probes, and report observations through the shipped binary without requiring toolchain byte pins or a particular OS/CPU architecture.
> **Read this if**: Phase 1 is next in the queue, or a later phase depends on what its gate establishes.

Phase 1 specifies native tool-version admission and the retained probe-source boundary. Two fresh
observations select compatible installed GHCup/GHC tools, and the shipped `amoebius` binary reports their
versions and the probe results. No toolchain archive or executable pin is required. Its predecessor is
[Phase 0](phase_00_documentation_suite.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, documents/decision_log.md, documents/engineering/content_addressing_determinism.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/pulsar_client_doctrine.md
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

✅ Done.
**Receipt**: 5f560ee8899da1b21e85fb5edb4fac599b18b09a4932e4db8b52638471143d6b

The complete preview and separate acceptance passed at the exact source snapshot recorded by the receipt.
All eighteen gate categories and 116 independent clean oracle rows are green. The owning source/admission
qualifications passed all 32 rows. The generated matrix killed 36 of 38 viable production mutants, with a
kill in every subject; two non-buildable mutants supplied no kill. The shipped report retained the nonce
and refused the unsupported requested compiler version. Both runs reproduced the complete predecessor gate.

The earlier reset and failed mutation run remain historical observations. Their missing inherited authority
was repaired through the exact-source predecessor handle in
[DL-0035](../documents/decision_log.md#dl-0035--retired-legacy-checks-inherit-an-exact-source-predecessor-pass).
The accepted owning bindings now retire under
[DL-0036](../documents/decision_log.md#dl-0036--phase-1-acceptance-retires-its-qualified-toolchain-bindings),
with their identities, queries and independent reintroduction cases retained. Subsequent source or governance
changes require current compatibility or numerical replay before the next gate can use this evidence.

Native GHCup/GHC version admission requires no toolchain byte pin, particular host architecture or hardware.
Compiler correctness and publisher identity remain assumptions. Complete source closure, DSL validation and
live hardware retain their later owners; this receipt establishes only the toolchain gate's bounded claim.

## Phase Summary

Phase 1 requires `Amoebius.Toolchain.Versions` and `Amoebius.Toolchain.Acquire` to admit native GHCup and
GHC solely by compatible version reports. Missing tools, failed version commands, malformed reports, and
unsupported versions are refused independently. Cabal is an available build tool whose version is recorded;
no archive, signature, manifest, executable digest, OS, architecture, device, container/VM, or privileged
host is a prerequisite. Installed tool paths are explicit read-only inputs.

The retained decoder, deterministic simulator, codegen runtime, browser-contract generator, dependency
resolver, pure ensure planner, and maintained-fork provenance probes retain their independent expectations.
Every build remains serial. Planner platform values are supplied fixtures, not discoveries of the host.
Compiler correctness and publisher identity remain assumptions. Source/dependency integrity and receipt
hashes retain their separate purpose under [DL-0025](../documents/decision_log.md#dl-0025--native-version-checks-replace-toolchain-pins-before-the-dsl-barrier).

**Phase scope:** One cohesive claim — native version admission and the retained toolchain probes are judged through the shipped report and independent oracle, with exact version/refusal boundaries and no physical substrate requirement.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 0](phase_00_documentation_suite.md)
**Forward-deferred:** compiler-backed source closure — [Phase 2](phase_02_repository_layout_conformance.md) `repository_layout_conformance` / `LTD-SRC-000`; the re-run of every hardware-free gate through the shipped binary — [Phase 9](phase_09_dsl_barrier.md)
**Gate:** `pb validate phase 01`; see [Gate integrity](#gate-integrity).

### Gate specification

```gate-spec
capability: toolchain_spike
role: ordinary
claim: The shipped toolchain-report accepts native GHCup and GHC by their declared version requirements, with no toolchain digest pin, signature, archive, operating-system, architecture, or device prerequisite. Two observations agree on versions; the independent oracle judges version boundaries, actual missing/malformed/failed tools, retained decoder/simulator/codegen/provenance probes, and pure planning from supplied platform fixtures. The runner plants a nonce and requests an unsupported compiler version, which the shipped binary reports as refused. Builds remain serial. Compiler correctness and publisher identity remain assumptions.
subjects: Amoebius.Toolchain.Versions, Amoebius.Toolchain.Acquire, Amoebius.Toolchain.Probe, Amoebius.Toolchain.Resolve, Amoebius.Toolchain.Provenance, Amoebius.Toolchain.Report
suite: toolchain-suite
oracle: oracle-toolchain
positive: version-compatible-native-tools | input=GHCup and GHC version reports | expected=accepted without an OS, architecture, archive, signature, or executable digest requirement
positive: second-observation | input=same compatible versions | expected=agree
positive: version-boundaries | input=separately authored version grid | expected=exact admitted and refused boundaries
positive: probe-decode | input=positive.dhall | expected=decoded amoebius/3/True
positive: probe-sim | input=clean schedule | expected=b:2
positive: probe-codegen | input=probe.proto | expected=Proto/Probe.hs,Proto/Probe_Fields.hs
positive: probe-bridge | input=ProbeContract | expected=Amoebius/Toolchain/Probe.purs
positive: probe-plan | input=empty inventory | expected=four ensure steps
positive: provenance-acquired | input=supernova-0.0.3 | expected=tree digest equal
negative: MissingTool | input=absent compiler | tag=ToolMissing | stage=versions
negative: MalformedVersion | input=malformed GHCup output | tag=ToolVersionMalformed | stage=versions
negative: UnsupportedGhcupVersion | input=GHCup 0.1.50.1 | tag=ToolVersionMismatch | stage=versions
negative: UnsupportedVersion | input=GHC 9.10.1 | tag=ToolVersionMismatch | stage=versions
negative: FailedVersionCommand | input=nonzero version command | tag=ToolCommandFailed | stage=versions
negative: MistypedDecode | input=mistyped.dhall | tag=type-error | stage=probe
negative: PerturbedSchedule | input=perturbed schedule | tag=a:1 | stage=probe
negative: MissingDependency | input=absent package | tag=MissingDependency | stage=resolve
negative: TrackedResolutionOutput | input=cabal.project.freeze | tag=TrackedResolutionOutput | stage=resolve
negative: TrackedProbeInput | input=probe.dhall | tag=TrackedProbeInput | stage=resolve
negative: MutableIdentity | input=git branch | tag=MutableIdentity | stage=provenance
negative: TopLevelVendor | input=vendor/ | tag=TopLevelVendor | stage=provenance
negative: UpstreamDigestMismatch | input=altered tree digest | tag=DigestMismatch | stage=provenance
negative: AbsentTool | input=absent-tool | tag=AbsentTool | stage=plan
negative: OutOfRangeVersion | input=ghc 9.10.1 | tag=OutOfRangeVersion | stage=plan
negative: NoPlatformAsset | input=unsupported-unknown | tag=NoPlatformAsset | stage=plan
mutants: stages=Amoebius.Toolchain.Versions,Amoebius.Toolchain.Acquire,Amoebius.Toolchain.Probe,Amoebius.Toolchain.Resolve,Amoebius.Toolchain.Provenance,Amoebius.Toolchain.Report per-module=8 cap=40 kill-ratio=3/5
binary-fact: command=toolchain-report --request {input} --output {run}/toolchain-report.tsv --probe-root {run}/probe | input=toolchain-request.tsv | perturbation=staged(pre=toolchain-report --write-request {input} post= then=sentinel-to-nonce(0b5e17e11a0c0ffee0de1e9a7e5ba5ed),rewrite(ghc.requested-version	9.12.4 => ghc.requested-version	9.10.1)) | outputs={run}/toolchain-report.tsv
substrate: none
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | The shipped report checks native GHCup/GHC versions and retained probes. Supplied version boundaries and actual missing, malformed, unsupported, and failed tools are judged independently. Compiler correctness remains assumed; no toolchain byte pins or specific host are required. |
| `Subject` | The six stage modules named in the gate specification and the `toolchain-report` subcommand in `app/amoebius/Main.hs`; the maintained fork modules beneath `src/vendor/**` are verified present by `Amoebius.Toolchain.Provenance`, and their own compilation is owed to the Pulsar-client phase. Every subject is inside the closure of `executable amoebius`. |
| `Command` | Future public spelling is `pb validate phase 01`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 01`; then `amoebius-validate accept --phase 01` records the receipt and applies one phase's status patch. The runner spawns the shipped `amoebius` binary for an ordinary `toolchain-report` without `--acquire`; the separate suite calls `acquireTwice` and elaborates two plans. Every Cabal child the suite starts carries `--offline` and `--jobs=1`. |
| `Oracle` | `test/oracle/toolchain/Main.hs` restates native version requirements, the expected probe outputs, and the refusal loci from literals; it depends on no `amoebius` library. |
| `Positive controls` | Compatible native versions, a second observation agreeing on versions, each admitted range boundary, decoder/simulation/codegen probes, dependency elaboration, maintained upstream provenance, and supplied ensure-planner inputs. |
| `Paired negatives` | MissingTool, MalformedVersion, UnsupportedVersion, and FailedVersionCommand refuse at versions. Retained dependency, provenance, malformed-decode, simulation, tracked-output and pure-planning negatives keep their exact tags and stages. |
| `Mutants` | Runner-generated from the fixed operator catalogue over the six stage modules, eight per module, at most forty per gate, kill ratio at least 0.6; a mutant in `Amoebius.Toolchain.Versions` is killed by the oracle's version comparison. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the probe entry points the report exercises equal the oracle's set; empty discovery refuses. |
| `Challenge` | The runner renders a request, replaces its label sentinel with a nonce, and changes the requested compiler version from 9.12.4 to unsupported 9.10.1. The shipped report must carry the nonce and report ToolVersionMismatch for that request while observing native tool versions. |
| `Observer` | Separate child processes capture native version commands and retained build/codegen tools. Every compiler-bearing command is serial. Host/substrate/provider inputs are supplied fixtures; no hardware discovery occurs. |
| `Authority/bypass` | The oracle imports no product library. Version commands must succeed, parse unambiguously, and satisfy the declared range. Source identity, independent expectations, changed-subject mutants, and receipt custody remain required. Version output is not a proof of compiler semantics. |
| `Freshness` | A unique run root; both acquisition roots absent at acquisition; the verifier digest equals the seed's; opening and closing source identities are equal; no prior candidate can satisfy the nonce. |
| `Qualification` | The runner-generated mutant matrix over the six stage modules — eight per module, at most forty, kill ratio at least 0.6 — precedes the clean candidate in the same run. |
| `Cleanroom` | Fresh run-owned outputs beneath `.build/**`; native installed tools are declared read-only inputs. No seven-file bootstrap directory or fixed toolchain archive is required. Source, dependency-source and receipt hashes retain their distinct custody purpose. |
| `Legacy closure` | `LTD-BOOT-001`, `LTD-SRC-007`, and `LTD-SRC-009` close here through the compiled inventory; the due-count for every other identifier is zero. |
| `Predecessor` | The Phase-0 receipt in certification generation 2, chained by the digest of Phase 0's product closure plus the verifier and governance digests. |
| `Residue` | Compiler correctness, honest version reports, and publisher identity remain assumptions. Toolchain byte identity and cross-host identical build output are not acceptance claims. Phase-2 source closure, the complete DSL barrier, and all live hardware claims retain their separate owners. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and `accept` records it. |

## Resource provision

- **Owner marker:** the source snapshot, the Phase-0 receipt, the unique Phase-1 run root, and the two acquisition-root identities.
- **Preflight:** a fresh run root, native GHCup/GHC versions meeting the declared requirements, and available build/probe dependencies; no fixed host or archive inputs.
- **Allowed mutations:** compiler products, rendered probe cases, and observations beneath `.build/runs/phase-01/**`; installed native tool paths are read-only inputs.
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

## Sprint 1.1: GenesisTrust-bound toolchain acquisition ✅

**Status**: Done
**Implementation**: `src/Amoebius/Toolchain/Versions.hs` and `src/Amoebius/Toolchain/Acquire.hs`
**Blocked by**: [Phase 0](phase_00_documentation_suite.md) gate pass
**Independent Validation**: Compatible native GHCup/GHC versions are the positive control. Missing tools, failed version commands, malformed reports, and out-of-range versions refuse at their exact version tags. The independent oracle supplies range boundaries; a changed version predicate must be killed at those rows. Compiler correctness remains explicit residue.
**Oracle**: `test/oracle/toolchain/VersionExpectations.hs`, `test/oracle/toolchain/Admission.hs` and `test/oracle/toolchain/Main.hs`; the independent source/evidence join is in `test/oracle/runner/LegacyAudit.hs`.
**Legacy IDs**: `LTD-BOOT-001` — version admission and explicit compiler trust
**Docs to update**: `documents/engineering/validation_frame_doctrine.md`

### Objective

Admit compatible native GHCup/GHC versions without toolchain byte pins or a hardware-specific prerequisite.

### Deliverables

- The version requirements and unambiguous parser in `Amoebius.Toolchain.Versions`.
- Native executable selection and separate version-command observations in `Amoebius.Toolchain.Acquire`.
- Specific missing, malformed, failed-command and unsupported-version refusals with their positive twins.

### Validation

Run the independently authored version boundary grid and child-process negatives. Keep source and receipt
identity checks separate from toolchain admission. GHCup >=0.1.50.2 and <0.3, and GHC 9.12.4,
are the current Haskell requirements; they do not select an OS or CPU architecture.

### Remaining Work

None within this sprint's bounded scope: the complete preview and subsequent acceptance passed.
The receipt above owns the integrated result. The component observations below describe the checks that
preceded it; later source changes still require compatibility or numerical replay.

The native admission component now passes ten independent oracle rows. Its four canonical fault groups
each exercise GHCup and GHC with both positive and negative controls. Every positive also tolerates an
unavailable Cabal version report; toolchain byte identity supplies no admission verdict. The examples are
Haskell values linked from the product version module, and the boundary fakes are copied Haskell executables.
The source-bound factory retains the observations and image identities and removes its copied source tree.
Its qualified diagnostic removes the owning admission refusal while retaining the other due and inherited
refusals. The serial qualification matrix now passes all forty-two independent evidence-binding controls.
Five compiled production weakenings each produce exactly their assigned red row while preserving the other
nine green rows: missing-tool detection, command-exit checking, malformed-version rejection, exact-version
checking and range checking. The independent audit binds the full source rewrite, changed executable
identities, complete ledger discovery, source-tree cleanup and owner/source correspondence; missing, reused,
duplicate, forged and other-analyzer evidence refuse. A current query qualification cannot retire an earlier
owner. These admission-component results supplied no phase authority on their own. The subsequent complete
preview and acceptance separately established the integrated result recorded above.

## Sprint 1.2: `dhall` in-process decoder build probe (gadt-decode dependency) ✅

**Status**: Done
**Implementation**: `src/Amoebius/Toolchain/Probe.hs`
**Blocked by**: Sprint 1.1
**Independent Validation**: The positive decode case yields the oracle's literal value through the in-process `dhall` decoder linked into the shipped binary; the one-field-mistyped twin is refused with the decoder's type-error tag. Both cases are rendered beneath `.build/probe/**` after the run starts.
**Oracle**: `test/oracle/toolchain/Main.hs` states the expected decoded value and the rejection tag from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Adopt [`dsl_doctrine.md` §9 — toolchain note](../documents/engineering/dsl_doctrine.md#9-toolchain-note): prove
that the in-process decoder dependency builds and executes with compatible native tools before Phase 3 promises a typed decoder.

### Deliverables

- The decode probe as a module the report exercises, with one positive and one mistyped case.
- The compatibility requirement that makes the decoder build on the version-compatible compiler, authored as a Haskell value and never as a freeze file.

### Validation

Decode the positive and refuse the twin; compare both outcomes with the oracle's literals.

### Remaining Work

None within this sprint's bounded scope: the complete preview and subsequent acceptance passed.
The receipt above owns the integrated result. The component observations below describe the checks that
preceded it; later source changes still require compatibility or numerical replay.

## Sprint 1.3: `io-sim` + `io-classes` simulation build probe ✅

**Status**: Done
**Implementation**: `src/Amoebius/Toolchain/Probe.hs`
**Blocked by**: Sprint 1.2
**Independent Validation**: The unperturbed two-writer schedule reaches the oracle's literal terminal state; the perturbed schedule reaches a different literal state; a probe that exits without printing a terminal state is refused.
**Oracle**: `test/oracle/toolchain/Main.hs` states both terminal states from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/gateway_migration_model_doctrine.md`

### Objective

Adopt [`gateway_migration_model_doctrine.md` §4 — simulate and prove](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove):
prove that the deterministic-simulation dependency builds and runs with compatible native tools before the gateway-migration
model is authored.

### Deliverables

- The simulation probe with a clean arm and a perturbed arm, the schedule as a Haskell value.
- A terminal state printed by the probe, never a self-reported exit alone.

### Validation

Run both arms; compare the terminal states with the oracle's literals.

### Remaining Work

None within this sprint's bounded scope: the complete preview and subsequent acceptance passed.
The receipt above owns the integrated result. The component observations below describe the checks that
preceded it; later source changes still require compatibility or numerical replay.

## Sprint 1.4: `supernova` fork + `proto-lens` codegen build probe ✅

**Status**: Done
**Implementation**: `src/Amoebius/Toolchain/Probe.hs` and `src/Amoebius/Toolchain/Provenance.hs`
**Blocked by**: Sprint 1.3
**Independent Validation**: The codegen runtime links into the shipped binary and the report prints the oracle's literal link token; the codegen tool, materialised by the acquired package tool, renders the generated bindings beneath the run's probe root; the fork's upstream identity is a Haskell value whose absent or mutable form is refused at the provenance locus.
**Oracle**: `test/oracle/toolchain/Main.hs` states the link token and the expected generated-module set from literals.
**Legacy IDs**: none — `LTD-SRC-009` is owed by Sprint 1.7
**Docs to update**: `documents/engineering/pulsar_client_doctrine.md`

### Objective

De-risk the native Pulsar client's fork and its codegen with compatible native tools before the Pulsar-client phase
promises it, so a fork that will not compile is found here rather than mid-implementation.

### Deliverables

- The codegen probe as a module the report exercises.
- The fork identity as a Haskell value; generated bindings beneath the run root only.

### Validation

Build and link; compare the token and the generated set with the oracle; refuse the removed identity.

### Remaining Work

None within this sprint's bounded scope: the complete preview and subsequent acceptance passed.
The receipt above owns the integrated result. The component observations below describe the checks that
preceded it; later source changes still require compatibility or numerical replay.

## Sprint 1.5: Dynamic resolution and generated-output migration ✅

**Status**: Done
**Implementation**: `src/Amoebius/Toolchain/Resolve.hs` and `src/Amoebius/Toolchain/Probe.hs`
**Blocked by**: Sprint 1.4
**Independent Validation**: A compatibility declaration that names no resolved path, checksum, or solver graph resolves to a plan beneath `.build/toolchain/**`; a tracked freeze file, a tracked package pin, and a tracked developer-home path are paired negatives refused at the source-closure locus. Explicit read-only native tool paths are permitted inputs.
**Oracle**: `test/oracle/toolchain/Main.hs` and `test/oracle/toolchain/ProbeSource.hs` state path, generated-byte and probe-inventory expectations independently; `test/oracle/runner/LegacyAudit.hs` judges the source/evidence join.
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

Resolve twice with compatible native tools; confirm every generated output is ignored and every authored path is
unchanged; refuse each tracked artefact by name.

### Remaining Work

None within this sprint's bounded scope: the complete preview and subsequent acceptance passed.
The receipt above owns the integrated result. The component observations below describe the checks that
preceded it; later source changes still require compatibility or numerical replay.

The probe-source component currently passes nine independent oracle rows over fifteen paired inputs:
three script forms, six foreign fixture formats, and omission of each of the report's six typed cases.
The oracle also checks missing source files, empty inventory, duplicate and unexpected cases, actual
generated bytes, and removal of the copied source tree. Missing observations produce nine red rows.
Its source-bound qualification and three changed-production-source builds now pass all thirty-two
independent join checks. Removing foreign-input detection makes both foreign-input negative rows red;
removing case-omission detection makes its canonical negative red; removing source-presence detection
makes the inventory control red. Each changed executable is refused qualification, its source witness
is checked independently, and each copied source tree is absent afterward. These component observations
mint no phase evidence and do not retire `LTD-SRC-007`.

## Sprint 1.6: Pure discovery/ensure planning over injected inputs ✅

**Status**: Done
**Implementation**: `src/Amoebius/Toolchain/Resolve.hs`
**Blocked by**: Sprint 1.5
**Independent Validation**: The plan over an injected empty inventory and an supplied provider catalogue equals the oracle's literal step list; an absent tool, an out-of-range version, and a platform with no asset are refused rather than substituted. The plan reads no host.
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
- An abstract supplied platform fixture that imposes no OS/CPU requirement on the executing host.

### Validation

Evaluate the plan; compare with the oracle; refuse each negative without selecting a foreign asset.

### Remaining Work

None within this sprint's bounded scope: the complete preview and subsequent acceptance passed.
The receipt above owns the integrated result. The component observations below describe the checks that
preceded it; later source changes still require compatibility or numerical replay.

## Sprint 1.7: Remove top-level vendor source and own the Haskell fork ✅

**Status**: Done
**Implementation**: `src/Amoebius/Toolchain/Provenance.hs` and the maintained fork modules beneath `src/vendor/**`
**Blocked by**: Sprint 1.6
**Independent Validation**: A clean build from the immutable upstream identity is the positive control; a mutable reference, an absent identity, a developer-home path, and a digest that does not match the acquired bytes are refused; a reintroduced top-level `vendor/**` path is refused at the layout locus.
**Oracle**: `test/oracle/toolchain/Main.hs` and `test/oracle/toolchain/VendorSource.hs` state upstream, source-inventory, generated-byte and refusal expectations independently; `test/oracle/runner/LegacyAudit.hs` judges source/evidence binding.
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

Build with compatible native tools; refuse each negative at its named locus.

### Remaining Work

None within this sprint's bounded scope: the complete preview and subsequent acceptance passed.
The receipt above owns the integrated result. The component observations below describe the checks that
preceded it; later source changes still require compatibility or numerical replay.

The vendor-source component passes thirteen independent oracle rows over ten paired reintroductions
covering the five canonical groups, with actual generated-file discovery and independently restated
bytes. Its fork inventory is checked against seventeen literal module names and each module's removal.
Missing observations produce thirteen red rows. The source-bound qualification and all six
changed-production-source builds now pass forty-seven independent join checks. Weakening each of the
five refusal groups makes its canonical negative red; disabling fork-presence checks makes the fork
control red. Each changed executable is refused qualification, its source witness and binary delta are
checked independently, and each copied source tree is removed. These component observations record no
phase result and do not retire `LTD-SRC-009`; upstream acquisition and fork compilation retain the scope
stated in the gate contract.

## Sprint 1.8: jit-build resolver deps + `purescript-bridge` + consolidated probe gate ✅

**Status**: Done
**Implementation**: `src/Amoebius/Toolchain/Report.hs`, `app/amoebius/Main.hs`, `src/gate-spec/Amoebius/Validation/GateSpec/Toolchain.hs`, and `amoebius.cabal`
**Blocked by**: Sprint 1.7
**Independent Validation**: `amoebius toolchain-report` prints version observations and probe outputs the oracle restates; the compiled specification equals the fenced block above; a dropped compatibility allowance is refused at the resolution locus; a stanza whose module map disagrees with the subjects is refused at discovery.
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
- No validator-side toolchain runner or oracle: the generic runner executes the specification.

### Validation

Run `preview phase 01` and require every row green; require `accept` to record exactly one
phase's patch.

### Remaining Work

None within this sprint's bounded scope: the complete preview and subsequent acceptance passed.
The receipt above owns the integrated result. The component observations below describe the checks that
preceded it; later source changes still require compatibility or numerical replay.

An earlier complete toolchain component run passed 112 independent oracle rows on fresh generated outputs.
It covers native version admission and negatives, retained decoder/simulator/codegen/bridge probes,
offline dependency elaboration, cached immutable upstream acquisition and digest mismatch, pure ensure
planning, shipped-report CLI behavior and exact probe discovery, and both new source-boundary corpora.
That run was a component diagnostic. The subsequent complete gate additionally judged the shipped-binary
challenge, reproduced the predecessor and recorded acceptance with 116 clean oracle rows.

The runner regression after integrating the source qualifiers and lifecycle handoff passes all 745
independent rows. The validation kernel is 3,354 lines, below the 3,357-line cap used for these checks. Nine native API
pairs admit legal use and reject construction or deserialization of opaque source, qualification, collection
and predecessor handles. The missing-predecessor diagnostic refuses before gate execution. The documentation
suite passes all 41 independent rows, including its nine named negatives.

[DL-0035](../documents/decision_log.md#dl-0035--retired-legacy-checks-inherit-an-exact-source-predecessor-pass)
records the eight Phase-0 retirements. The generic runner now issues an opaque handle only for a complete
green gate. Custody reproduces the accepted predecessor at the current verifier, governance and closure;
the next gate requires the immediate predecessor and exact captured source before inheriting its retained
snapshot qualifications. Raw digests and component collections do not create that handle. Current Phase-0
replay and the complete Phase-1 preview and acceptance subsequently passed; the component checks alone
supplied no integrated phase authority.

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
- [Phase 0 documentation suite](phase_00_documentation_suite.md) — the predecessor and the `GenesisTrust` version assumption
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
