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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, documents/decision_log.md, documents/engineering/content_addressing_determinism.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/pulsar_client_doctrine.md
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
**Receipt**: 84cf31fc6b2d5feaa6c086f59a616e188cec82ee77725396beb108093709c235

**Historical predecessor repair — DL-0042.** The complete repaired Phase-0 preview passed,
and its separate acceptance issued the [owning receipt](phase_00_documentation_suite.md#phase-status)
at 2026-10-26 22:11:40.134788 UTC. It qualified the image/completion boundary reopened under DL-0041
and mechanically activated this phase. [DL-0042](../documents/decision_log.md#dl-0042--qualified-image-and-completion-custody-retires-runner-authority) retires exactly `LTD-VAL-001` while preserving its identity, five canonical cases, explicit extension,
source-bound qualification and inherited guards. At that checkpoint, the changed governance required
complete Phase-0 replay before this phase's fresh complete preview and separate acceptance. Those gates
were prerequisites for Phase 2. The earlier Phase-1 receipts below retain their recorded scope; status and receipt
fields remain the verifier's mechanical projection.

The complete ordered reproduction on 2026-10-28 issued the receipt recorded above after all eighteen
categories passed. Its forty attempts contained thirty-six kills among thirty-nine viable mutants and one
stillborn, with a named kill for every subject. Later Phase-2 repairs changed the verifier and shared
source. Their ordered reproduction published a green Phase-0 record on 2026-10-30, but its own Phase-1
run was interrupted at the user's request with controller exit 130 before a new receipt was published.
The [Phase-2 handoff](phase_02_repository_layout_conformance.md#phase-status) records the remaining work.
The older complete result supplies no current-source reproduction; fresh affected-closure replay is
required before the next Phase-2 gate.

At the 2026-10-27 mutation-evidence checkpoint, the complete preview reproduced its predecessor and
completed all forty sampled attempts. Fifteen gate categories were green; mutation completeness,
qualification and the pass criterion were red, so no acceptance was attempted. The unmodified control
had 135 green judgments, the clean candidate had 139, and thirty-three mutations had named kills across
all six subjects. One compiler-negative lacked its stillborn classification, two actual CLI refusals
shortened the oracle namespace, and a discovery mutation made fixture setup copy a directory as a file.
The repair preserves complete semantic judgments for absent product outputs, enumerates fixture-copy
and unchanged-source inputs independently, and requires a known changed-source compiler diagnostic,
a closed failing compiler record and an unchanged source copy before excluding a stillborn attempt.
Missing native or oracle boundaries remain failures. This checkpoint supplied no phase pass: the changed
verifier still required predecessor replay and this phase's complete preview and separate acceptance.

The same checkpoint retained an approximately 84 MB candidate diagnostic projection, above the existing
16 MiB archive record bound. At that checkpoint, large native diagnostic fields used an explicit `interned-gzip-utf8-hex.v1`
envelope: a Haskell token dictionary and reference list, compressed and hex-encoded, reconstruct their
complete UTF-8 projection; observations and judgments remain complete before encoding.
Small diagnostic fields retain their existing representation. Preview checks the archive's record-size
bound before reporting a pass. Lossless round trips, the retained full projection's encoded size and
source-bound native cases required checking before the subsequent complete gates; the archive size limit
and historical bundles remain unchanged. The subsequent Phase-2 repair uses the lossless
`interned-gzip-utf8-base64.v2:` representation for large retained native diagnostic fields; historical
archives retain their original bytes. Its component checks and pending complete-gate qualification are
described in the linked handoff rather than supplying a new Phase-1 result here.

The focused repair checks completed with nineteen oracle-protocol checks, eight paired CLI-output
absence, I/O-refusal and restoration checks and five lossless/archive-size checks green. The fresh native 135-row control
was green; the compiler-negative was correctly retained as stillborn, and its actual positive plus nine
missing/mismatched observation negatives were green. Each of the three runtime subjects completed the
135-row namespace, known process returns, source guard and stable actual images, with the specific CLI
or discovery refusal and a suite image differing from the matching control. An earlier focused process
was interrupted by signal 15 and supplied no runtime pass; separate serial processes completed the cases.
The first runtime's final binary comparison was completed against its retained observation after replacing
a source-size-bounded diagnostic reader. None of these diagnostics minted phase evidence. At that
checkpoint, the complete predecessor replay, fresh complete preview and separate acceptance remained due.

The framed oracle integration now declares two explicit Haskell namespaces: `toolchain.full.v1` has
the existing 135 core judgments, and `toolchain.gate.v1` adds the four existing shipped-binary judgments.
The declaration is authored from the independent oracle's existing checks, not from subject output.
The generic runner selects the latter only for the clean candidate with a compiled `BinaryFact`;
matrix and component observations use the core profile. Inventory, missing-primary probe and normal
completion retain separate challenges. This preserves the matrix's suite-linked product subjects and
the clean candidate's separate shipped-binary obligation. Legacy file/directory and specialized
diagnostics retain their previous routes. The counted kernel remains twenty files and 3,353 lines.
The integration built serially. A source-bound native component run retained the actual seven process
observations, three complete frames, 135 green judgments and stable suite/oracle images. Nineteen
independent component checks passed, including both inventory declarations, missing-primary probes,
malformed requests and a specific semantic refusal followed by exact restoration. The source-built
shipped executable then completed the fresh nonce/version-request challenge. Its independent oracle
returned all 139 gate judgments green; the explicit core profile still returned 135, and both executable
images remained stable. These were component diagnostics only. Numerical progression then required a
complete green Phase-0 replay followed by this phase's fresh complete preview and separate acceptance; its
predecessor's recorded receipt and any replay revocation are described in [Phase 0](phase_00_documentation_suite.md#phase-status).

Historical custody checkpoint and its then-current successor requirement: numerical replay through Phase 1 completed on 2026-10-23 at 16:20:40 UTC,
publishing Phase-0 receipt `62e40f509f659bcf35b03708801d157fbdf6e0a4af18b87cc74ccb862d20f6b7` and Phase-1 receipt
`c6d4a39786a4050aad934eaabdc8c6b55497e977e21a0714e117aefe16238d47`. The subsequent Phase-2 preview refused before its gate
with `PredecessorNotCommitted` and `PREDECESSOR-GATE-UNAVAILABLE`; it exposed recursive predecessor
custody comparing Phase 0's older whole-status postimage with the later Phase-1 surface. The new
source-bound verifier completed the [reset receipt](../validation-records/generation-d7ecfa4c132f6845/receipts/phase-00-35b097c8a6c5efe44b0d0e0966c92b1e04a3b333fa26fe67086e630733951e26-35c947452b34e28599086c516ec4b4fbc7bbbb34ccc038ef52643625495251b7/receipt.tsv)
on 2026-10-23 at 17:41:25 UTC under [DL-0039](../documents/decision_log.md#dl-0039--recursive-custody-preserves-accepted-completed-prefixes), naming product gap `LTD-VAL-003` and validator gap
`recursive uncommitted predecessor postimage admission`. This is a nongate reset to the earliest owner,
Phase 0. Focused custody components recorded 67 green oracle rows, 52 green independent evidence-binding
checks and exact expected red-row sets for all seven changed production subjects. They do not establish a
complete owning gate pass. The subsequent distinct complete Phase-0 acceptance is recorded by
[receipt `6d072c6371298209b4b1baaf77be7e6010a77e6ad84bdb17e71e137ec8bf02ee`](../validation-records/generation-d7ecfa4c132f6845/receipts/phase-00-6d072c6371298209b4b1baaf77be7e6010a77e6ad84bdb17e71e137ec8bf02ee-dd94cde77cf45d3cbe84a0cbf6b43c1623e00bb60dfa1dd6186a016d3b16f8e4/receipt.tsv), issued at 2026-10-23 19:25:31.985079 UTC
and completed at 2026-10-23 19:25:32 UTC; its [bounded observations](phase_00_documentation_suite.md#phase-status)
qualify the reopened binding. [DL-0040](../documents/decision_log.md#dl-0040--qualified-recursive-custody-retires-its-reopened-binding) retires exactly that binding and requires complete numerical Phase-0 replay
at the amended source and governance before a fresh complete Phase-1 preview and separate acceptance,
and only then Phase 2. No owning Phase-0 pass or historical result below supplies the fresh Phase-1 gate.

At the earlier DL-0038 checkpoint, the repaired complete preview finished on 2026-10-23 at 08:22:36 UTC with all eighteen categories green
and minted nothing. The separate complete acceptance finished at 11:50:45 UTC after re-deriving its
immediate predecessor and recorded receipt `1d571c43452ba121ef5c3b17c29502dc1dc85ab6a9b20a767531580f02d96d20`. The
[accepted candidate](../validation-records/generation-73b9725848c60d62/receipts/phase-01-1d571c43452ba121ef5c3b17c29502dc1dc85ab6a9b20a767531580f02d96d20-cdababd6c28a3033b58d644e2613df53fa84708f06beb969ba4b58abdcc97b97/candidate.tsv),
[clean oracle ledger](../validation-records/generation-73b9725848c60d62/receipts/phase-01-1d571c43452ba121ef5c3b17c29502dc1dc85ab6a9b20a767531580f02d96d20-cdababd6c28a3033b58d644e2613df53fa84708f06beb969ba4b58abdcc97b97/oracle-ledger.tsv) and
[receipt](../validation-records/generation-73b9725848c60d62/receipts/phase-01-1d571c43452ba121ef5c3b17c29502dc1dc85ab6a9b20a767531580f02d96d20-cdababd6c28a3033b58d644e2613df53fa84708f06beb969ba4b58abdcc97b97/receipt.tsv)
retain the bounded observations described here. The preview and acceptance used specification
`bbf321ff3fa847360eaad59dc7847b3c8e68e7e3c343accb642dd48cfbf67611` and identical forty-locus mutation witnesses.

That historical accepted candidate recorded all eighteen categories green. The same-context unmodified matrix control had 135 unique
green rows, a successful source guard and five full process records retained in `matrix.control.raw`.
The clean independent oracle had the same 135 names plus four shipped-binary input/nonce/version checks,
all 139 green. Forty selected mutations yielded thirty-two kills among thirty-nine viable, one stillborn
and seven survivors. The six subjects' killed/survived/stillborn counts were Versions 6/0/1, Acquire 4/3/0,
Probe 7/0/0, Resolve 6/1/0, Provenance 6/0/0 and Report 3/3/0. Each subject had a recorded named product
kill; the later M.3 image-witness audit prevents treating that record as current qualified mutation evidence. The six Provenance loci were refused by the fork, unsafe-archive diagnostic or exact public-renderer
checks, rather than layout contamination.

The eleven source-bound qualification transcripts contain 231 green rows: the three owning bindings
contribute 32 (probe-source 9, vendor-source 13 and native admission 10), and eight inherited Phase-0
bindings contribute 199. All forty-four reports and retained guards remain. The accepted kernel count
and cap are 3,353. Opening and closing source identities agree at
`26931ae88e6ad290bda2b1334dfe26ab33556492748d3348806da166fbd2e982`; the verifier is
`73b9725848c60d62206cafccd3e152ba5e629b04b9f4853652ea3572f439072b`, governance
`cdf54628d937a8b0aecc69507d963c214533f3680eb81e8de639f87672931528` and reproducible core
`76ced110592c1681574f9c491b1789e1009c5a5eaf7ff8222b5482bc7f7103f2`.

The accepted candidate's raw control-oracle stdout and clean ledger retain the actual toolchain evidence.
The isolated offline install records contain the repository dry-run child and plan, selected
`proto-lens-protoc` version 0.9.0.1/source hash, 448 copied-cache entries with matching observed hashes,
the verified local archive/project input, a separate local-install child/plan and installed executable
checks. The two plans each contain 55 units, including the configured root library and executable;
equality of repository/local graphs or compressed archives is not assumed. The missing-package dry-run
records its precise unknown-package refusal, no installed executable/local-install observations and
owned-cache cleanup. Native configuration, caches and the installed package database were read-only
inputs; generated configuration, stores, temporaries and output belonged to physical owned roots.

Codegen observations contain the actual `(ChildRecord, stdout, stderr)`, matching returned child, schema
and complete generated paths, hashes and bytes. The independent oracle joined actual protoc identity and
argv to the installed plugin and checked both generated modules, message fields, tags and lenses.
Upstream observations contain both actual public eight-field renderers, immutable identity, archive/tree
hashes, 22 extracted files, optional native cache-query child and 31 read/create/write actions per
acquisition. The wrong-release twin retains the real `CachedArchiveInvalid: unsafe archive path
supernova-0.0.3` refusal and no created destination. Malformed declared fork names remain observable
through all clean-plus-seventeen fork records. The oracle checked physical inputs/outputs during the
run; cleanup removed the owned artifacts. The accepted archive retains records and embedded bytes, not
a claim that deleted binaries or archives can now be physically rehashed.

This amendment retires exactly `LTD-BOOT-001`, `LTD-SRC-007` and `LTD-SRC-009` while retaining all identities,
owners, analyzers, source queries, independent expectations, canonical reintroductions and inherited
guards ([DL-0038](../documents/decision_log.md#dl-0038--a-qualified-repaired-toolchain-pass-retires-its-three-bindings)). The earlier contaminated acceptance, receipt-bearing reset,
red per-module preview and focused components remain historical observations; they supply none of this
acceptance's authority. DL-0037's same-context control rule remains normative.

Native version admission requires no toolchain byte pin, particular host architecture or hardware.
Compiler correctness and publisher identity remain assumptions. The finite predecessor's captured
bootstrap scope does not close the whole-snapshot bootstrap query; its binding remains active and the
runtime handoff belongs to Phase 50. Complete source closure, maintained-fork compilation in Phase 67,
the DSL spine and live hardware retain their later owners. The exact-source predecessor handle under
[DL-0035](../documents/decision_log.md#dl-0035--retired-legacy-checks-inherit-an-exact-source-predecessor-pass)
remains required. The numerical replay required by the DL-0038 lifecycle/governance amendment completed
through Phase 1 at 16:20:40 UTC on 2026-10-23. The later custody refusal, completed earliest-owner reset
and new Phase-0 owning acceptance are recorded above. The separate retirement under
[DL-0040](../documents/decision_log.md#dl-0040--qualified-recursive-custody-retires-its-reopened-binding) requires complete Phase-0 replay, then fresh Phase-1 preview and separate acceptance before Phase 2.
This prose changes no status or receipt line.

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
negative: case:simulation.terminal-pair | input=completed simulation without a terminal value | tag=SimulationNoOutput with clean terminal control | stage=probe
negative: case:planner.paired-remedies | input=missing tool, unsupported version and absent platform asset | tag=exact actionable remedies with supported controls | stage=plan
negative: case:resolution.source-pairs | input=tracked freeze, package pin and developer-home metadata | tag=named source refusals with contained controls | stage=resolve
positive: case:build.fixed-serial-arguments | input=caller concurrency and compiler options, native configuration pairs, and actual successful and absent-package tool installs | expected=fixed offline serial native invocation, preserved payload, owned configuration and temporary paths, read-only native inputs, complete cache-copy evidence and cleanup
positive: case:resolution.first-plan | input=first native compatible resolution | expected=actual plan units, packages and digest agree with independent JSON decoding
positive: case:resolution.second-plan | input=second native compatible resolution | expected=actual plan units, packages and digest agree with independent JSON decoding
positive: case:resolution.agreement | input=two independently observed native resolutions | expected=equal complete unit graphs, package sets and digests
negative: case:resolution.disagreement | input=changed observed units, packages and digest | tag=PlansDisagree at each changed field | stage=resolve
negative: case:resolution.dropped-allowance | input=removed decoder dependency declaration | tag=MissingCompatibilityAllowance before effects | stage=resolve
negative: case:resolution.outside-root | input=resolution output outside the build root | tag=ResolutionRootOutsideBuild before effects | stage=resolve
positive: case:resolution.authored-unchanged | input=two actual resolutions | expected=complete authored source identity unchanged
positive: case:resolution.generated-ignored | input=actual generated resolution files | expected=every output is beneath the admitted ignored root
positive: case:upstream.cache-positive | input=native package cache archive | expected=actual local extraction, source digest and complete action projection
positive: case:upstream.supplied-cache-positive | input=explicit cached archive input with outside-root and ancestor-symlink twins | expected=same source identity without any child process; unsafe destinations refused before effects
positive: case:upstream.cache-only-query | input=native cache discovery | expected=only the read-only offline package-cache query executes
negative: case:upstream.digest-negative | input=wrong upstream source digest | tag=DigestMismatch before destination creation | stage=provenance
negative: case:upstream.missing-cache-negative | input=absent cached upstream archive | tag=CachedArchiveMissing without fallback or destination creation | stage=provenance
negative: case:upstream.absent-identity | input=empty release name or version | tag=AbsentIdentity before acquisition effects | stage=provenance
positive: case:report.cli.plan-a | input=public acquisition report first plan | expected=actual JSON units, compatible packages and digest match report
positive: case:report.cli.plan-b | input=public acquisition report second plan | expected=actual JSON units, compatible packages and digest match report
positive: case:report.cli.plans-agree | input=public acquisition report repeated plans | expected=observed complete plans agree
positive: case:report.cli.source | input=public report source inspection | expected=no tracked resolution findings
mutants: stages=Amoebius.Toolchain.Versions,Amoebius.Toolchain.Acquire,Amoebius.Toolchain.Probe,Amoebius.Toolchain.Resolve,Amoebius.Toolchain.Provenance,Amoebius.Toolchain.Report per-module=8 cap=40 kill-ratio=3/5 artefacts=Amoebius.Toolchain.Versions:version.,Amoebius.Toolchain.Versions:versions.,Amoebius.Toolchain.Versions:case:planner.paired-remedies,Amoebius.Toolchain.Versions:negative.MalformedVersion,Amoebius.Toolchain.Versions:negative.UnsupportedVersion,Amoebius.Toolchain.Versions:negative.UnsupportedGhcupVersion,Amoebius.Toolchain.Acquire:admission.,Amoebius.Toolchain.Acquire:child.,Amoebius.Toolchain.Acquire:second.,Amoebius.Toolchain.Acquire:versions.,Amoebius.Toolchain.Acquire:case:build.fixed-serial-arguments,Amoebius.Toolchain.Acquire:negative.MissingTool,Amoebius.Toolchain.Acquire:negative.FailedVersionCommand,Amoebius.Toolchain.Acquire:negative.MalformedVersion,Amoebius.Toolchain.Acquire:negative.UnsupportedVersion,Amoebius.Toolchain.Acquire:negative.UnsupportedGhcupVersion,Amoebius.Toolchain.Probe:probe.,Amoebius.Toolchain.Probe:report.probe.,Amoebius.Toolchain.Probe:probe-source.,Amoebius.Toolchain.Probe:case:simulation.terminal-pair,Amoebius.Toolchain.Probe:negative.TrackedProbeInput,Amoebius.Toolchain.Probe:negative.MissingDependency,Amoebius.Toolchain.Resolve:plan.,Amoebius.Toolchain.Resolve:report.plan.,Amoebius.Toolchain.Resolve:report.resolution.,Amoebius.Toolchain.Resolve:case:resolution.,Amoebius.Toolchain.Resolve:case:report.cli.plan-,Amoebius.Toolchain.Resolve:case:planner.paired-remedies,Amoebius.Toolchain.Resolve:negative.TrackedResolutionOutput,Amoebius.Toolchain.Resolve:negative.MissingDependency,Amoebius.Toolchain.Provenance:fork.,Amoebius.Toolchain.Provenance:upstream.,Amoebius.Toolchain.Provenance:vendor-source.,Amoebius.Toolchain.Provenance:report.provenance.,Amoebius.Toolchain.Provenance:case:upstream.,Amoebius.Toolchain.Provenance:layout.problems,Amoebius.Toolchain.Provenance:negative.MutableIdentity,Amoebius.Toolchain.Provenance:negative.TopLevelVendor,Amoebius.Toolchain.Provenance:negative.UpstreamDigestMismatch,Amoebius.Toolchain.Report:report.,Amoebius.Toolchain.Report:case:report.cli.,Amoebius.Toolchain.Report:negative.ReportUnknownArgument
binary-fact: command=toolchain-report --request {input} --output {run}/toolchain-report.tsv --probe-root {run}/probe | input=toolchain-request.tsv | perturbation=staged(pre=toolchain-report --write-request {input} post= then=sentinel-to-nonce(0b5e17e11a0c0ffee0de1e9a7e5ba5ed),rewrite(ghc.requested-version	9.12.4 => ghc.requested-version	9.10.1)) | outputs={run}/toolchain-report.tsv
substrate: none
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

The current verifier refuses missing stage attribution and mixed owned and unowned red rows. Explicit
toolchain row families are now declared above; their changed-source coverage and this phase's receipt must be
reproduced under the current verifier. The existing Done status remains historical until verifier action.
Each declared family matches at least one row in the independently declared full oracle inventory, and every
stage has a family; that inventory check is not mutation coverage or a replay.
The complete current-verifier replay reproduced Phase 0, then returned red for Mutants, Qualification, and
Pass criterion in this phase. The verifier retained the Phase 1 void and did not advance the frontier. The
changed-source matrix must be inspected and repaired before another complete replay.
A source-bound diagnostic of that specification retained 13 kills, 36 viable mutations, and four compiler
refusals; the 13/36 ratio is below the required threshold. Independent transcripts showed that several observed
planner, resolution, upstream, simulation, and serial-build rows were absent from their owning families. Those
specific families are now declared above. The changed specification selects a new deterministic sample, so a
fresh complete matrix and replay are required; the prior diagnostic does not establish a pass.
The next sample produced 26 kills from 40 viable rows, but its matrix completeness was red: a generated list
truncation deleted a pattern binder and the compiler reported the missing variable on later lines, outside the
required mutation locus. The list operator now excludes patterns followed by an arrow, and the independent
runner oracle passed all 1,083 component rows including that control. A fresh complete matrix and replay must
verify the change; the incomplete diagnostic is not a pass.

The next full diagnostic recorded 25 attributable kills from 40 viable rows, but remained incomplete: a
field-drop mutant caused a record-construction exception before the suite could publish its upstream
observations. The suite now retains that exception at the observation boundary. The unchanged control passed
all 135 independent toolchain rows, and the changed-source case completed the same inventory with six upstream
rows red. These paired component observations are not a complete matrix or a phase-gate pass.

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

Preserve the [current evidence boundary](#phase-status) and this sprint's independent expectations.
The sprint closes only through this phase's complete current acceptance after its predecessor has been
reproduced. Component diagnostics and historical receipts do not close it.

Native-version admission must retain the actual missing, malformed, failed and unsupported twins, with discovery and cleanup in its ten-row owning admission qualification.

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

Preserve the [current evidence boundary](#phase-status) and this sprint's independent expectations.
The sprint closes only through this phase's complete current acceptance after its predecessor has been
reproduced. Component diagnostics and historical receipts do not close it.

The gate must independently judge the linked decoder result and the precise mistyped-input refusal.

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

Preserve the [current evidence boundary](#phase-status) and this sprint's independent expectations.
The sprint closes only through this phase's complete current acceptance after its predecessor has been
reproduced. Component diagnostics and historical receipts do not close it.

The gate must independently judge deterministic terminal values and the successful simulation without a terminal value, including its named refusal.

## Sprint 1.4: `supernova` fork + `proto-lens` codegen build probe ✅

**Status**: Done
**Implementation**: `src/Amoebius/Toolchain/Probe.hs` and `src/Amoebius/Toolchain/Provenance.hs`
**Blocked by**: Sprint 1.3
**Independent Validation**: The codegen runtime links into the shipped binary and the report prints the oracle's literal link token; the codegen tool, materialised by the acquired package tool, renders the generated bindings beneath the run's probe root; the fork's upstream identity is a Haskell value whose absent or mutable form is refused at the provenance locus.
**Oracle**: `test/oracle/toolchain/Main.hs` states the link token and the expected generated-module set from literals.
**Legacy IDs**: none — `LTD-SRC-009` is owed by Sprint 1.7
**Docs to update**: `documents/engineering/pulsar_client_doctrine.md`

### Objective

De-risk the native Pulsar client's immutable upstream identity and codegen with compatible native tools
before the Pulsar-client phase promises runtime integration. Maintained-fork compilation remains owned by
Phase 67; this sprint qualifies the retained runtime token, generated bindings and provenance boundary.

### Deliverables

- The codegen probe as a module the report exercises.
- The fork identity as a Haskell value; generated bindings beneath the run root only.

### Validation

Build and link; compare the token and the generated set with the oracle; refuse the removed identity.

### Remaining Work

Preserve the [current evidence boundary](#phase-status) and this sprint's independent expectations.
The sprint closes only through this phase's complete current acceptance after its predecessor has been
reproduced. Component diagnostics and historical receipts do not close it.

The gate must join the actual offline executable install, runtime token, codegen child, schema and complete generated bytes to the absent-identity twins. Maintained-fork compilation remains Phase 67's claim.

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

Preserve the [current evidence boundary](#phase-status) and this sprint's independent expectations.
The sprint closes only through this phase's complete current acceptance after its predecessor has been
reproduced. Component diagnostics and historical receipts do not close it.

The gate must retain both actual resolutions and independently decoded plans, physical-root controls, unchanged authored-source inventories, tracked package-pin/home-path negatives and the nine-row probe-source qualification.

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

Preserve the [current evidence boundary](#phase-status) and this sprint's independent expectations.
The sprint closes only through this phase's complete current acceptance after its predecessor has been
reproduced. Component diagnostics and historical receipts do not close it.

The gate must independently judge planning over supplied inventory/catalogue inputs and every named refusal with its actionable remedy. These supplied values require no host discovery.

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

Preserve the [current evidence boundary](#phase-status) and this sprint's independent expectations.
The sprint closes only through this phase's complete current acceptance after its predecessor has been
reproduced. Component diagnostics and historical receipts do not close it.

The gate must join cache-only extraction, both public renderers, source/archive/tree/action observations, the wrong-release unsafe-archive/no-output twin and the thirteen-row vendor-source qualification. Publisher identity remains an assumption; maintained-fork compilation remains Phase 67's claim.

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

Preserve the [current evidence boundary](#phase-status) and this sprint's independent expectations.
The sprint closes only through this phase's complete current acceptance after its predecessor has been
reproduced. Component diagnostics and historical receipts do not close it.

The gate must bind the shipped report challenge, both public plan observations, dropped compatibility allowance, complete discovery and the exact compiled specification. It requires the 135-row unmodified matrix control, forty sampled production loci and the separate 139-row clean candidate; component diagnostics do not supply that qualification.

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
