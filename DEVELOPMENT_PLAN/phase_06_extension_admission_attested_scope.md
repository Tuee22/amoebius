# Phase 6: Extension admission and attested scope

> **Purpose**: Make an extension one linked `ExtensionSpec` record, admit its Haskell surface by AST node rather than by substring, and make attestation the only way a scope is introduced.
> **Read this if**: the extension claim of the plan must be judged, or a later phase needs to know which capabilities the shipped binary links and how a scope is entered.

This phase owns the extension seam of the spine: the `extension-spec` library, `LinkedExtensions`, the
GHC-parser AST checker, attested-only scope with one `reenter`, and the calculi linked into the executable.
It does not own child clusters or the UI language, which the later slice phases own in order. Its
predecessor is [Phase 5](phase_05_substrates_lanes_image_recipe.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_05_substrates_lanes_image_recipe.md, DEVELOPMENT_PLAN/phase_07_child_clusters_obligation_teardown.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/extension_conformance_security.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_tenancy.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 6.1: The extension-spec library and LinkedExtensions](#sprint-61-the-extension-spec-library-and-linkedextensions-)
- [Sprint 6.2: The gate-side GHC-parser AST checker](#sprint-62-the-gate-side-ghc-parser-ast-checker-)
- [Sprint 6.3: Attested-only scope and reenter](#sprint-63-attested-only-scope-and-reenter-)
- [Sprint 6.4: Calculi linked into the executable](#sprint-64-calculi-linked-into-the-executable-)
- [Sprint 6.5: The Phase 6 gate specification](#sprint-65-the-phase-6-gate-specification-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Gate execution is held shut by the Phase 5 predecessor receipt in certification generation 2. Hardware-free
implementation may proceed ahead of the frontier as component diagnostics under
[§O](development_plan_phase_model.md#o-sprint-sized-seams-and-bounded-phase-gates); it mints no evidence.

## Phase Summary

Phase 6 makes infernix one `ExtensionSpec` record linked into the shipped binary
([DL-0002](../documents/decision_log.md#dl-0002--one-extensionspec-record-is-the-extension-seam)). An app
needing a capability that no linked extension provides is refused as `UnboundCapability` at the exact app.
A Cuda demand on a linux-cpu host is refused as `LaneUnavailable` at lowering. The extension AST checker
parses with the GHC parser and rejects each named evasion form by node, so a substring scan no longer stands
between an extension and the binary.

Scope introduction is attested: no code path constructs a scope except `attest`, and `reenter` is the one
re-entry into an attested scope. The calculi the extension algebra needs are linked into the executable
rather than parked beside it. This phase folds the former scope-index and extension-conformance slices into
one claim ([DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice)).

**Phase scope:** One cohesive claim — an app needing inference bound to the linked infernix shape reaches fake-applied bytes, its unlinked twin is refused at the exact app, and every admitted extension surface is judged by AST node; it splits if a child cluster or a UI program is needed to settle it.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 5](phase_05_substrates_lanes_image_recipe.md)
**Gate:** `pb validate phase 06`; see [Gate integrity](#gate-integrity).

### Corpus

The corpus module is `Amoebius.Dsl.Examples.Extensions`, linked by the `amoebius` executable and rendered by
`amoebius render-examples`. It contains the Phase 5 corpus and adds at least three distinguishing pairs:

| Example | Distinguishes | Expected delta or refusal |
|---|---|---|
| `infernix-linked` | an app needing `Inference` bound to the linked infernix shape | provider objects for the engine runtime; application bytes carry the binding; the attested scope label on every object |
| unlinked twin | the same app with infernix absent from `LinkedExtensions` | `UnboundCapability` refused at the exact app and need |
| `cuda-on-cpu` and its cuda sibling | a Cuda demand against the host's lane set | `LaneUnavailable` refused at lowering on a linux-cpu host; the linux-cuda sibling accepted with the cuda lane label |
| refused set | one evasion form each and one unattested scope | each evasion rejected at `extension-astcheck` by node with the admitted twin accepted; `UnattestedScope` refused at the constructor |

New tags: `extension`, `infernix`, `attested`. Oracle rows for the provider objects and the scope labels are
authored before the extension-spec library exists.

### Gate specification

```gate-spec
capability: extension_admission_attested_scope
subjects:
  - Amoebius.Extension.Spec
  - Amoebius.Extension.Linked
  - Amoebius.Extension.AstCheck
  - Amoebius.Scope.Attested
  - Amoebius.Extension.Calculi
  - Amoebius.Dsl.Lower
suite: extensions-suite
oracle: oracle-dsl
positives: [infernix-linked, cuda-on-cuda-sibling, attested-scope]
negatives: [UnboundCapability, LaneUnavailable, AstEvasion, UnattestedScope]
mutants: { perModule: 8, perGateCap: 40, killRatio: 0.6 }
binaryFact:
  command: amoebius compile
  perturbation: sentinel-to-nonce
  outputs: [decoded-dump, manifest, astcheck-verdict, fake-kubectl-stdin]
substrate: HardwareFree
corpus: { module: Amoebius.Dsl.Examples.Extensions, minimumPairs: 3 }
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | The infernix corpus example, rewritten by the runner with a nonce, passes through `amoebius compile` and `amoebius apply --executor fake` with infernix as one `ExtensionSpec` in `LinkedExtensions`. The unlinked twin is refused as `UnboundCapability` at the exact app; the Cuda-on-cpu twin is refused as `LaneUnavailable`; every evasion form is rejected by AST node; every object carries an attested scope. Children and UI are excluded. |
| `Subject` | The six modules named in the gate specification, every one inside the closure of `executable amoebius`. `Amoebius.Dsl.Lower` is re-subjected because binding now resolves needs against the linked set. |
| `Command` | Future public spelling is `pb validate phase 06`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 06`; the human runs `sudo amoebius-validate accept --phase 06`. The runner spawns the shipped `amoebius` binary as a child for `render-examples`, `compile`, `astcheck`, and `apply --executor fake`. |
| `Oracle` | `test/oracle/dsl/Main.hs` parses the decoded dump, the manifest, the astcheck verdict, and the fake's stdin; it states the provider objects, the scope labels, and the per-node verdict from literal rows and depends on no `amoebius` library. |
| `Positive controls` | Every accepted corpus example renders provider objects equal to its oracle row; the fake's stdin byte-equals the compile output; the nonce is recovered from all outputs; the admitted extension surface passes the AST checker with an empty rejection list. |
| `Paired negatives` | `UnboundCapability` refused at the exact app with the linked twin accepted; `LaneUnavailable` refused at lowering with the cuda sibling accepted; each named evasion form rejected at its AST node with the admitted twin accepted; `UnattestedScope` refused at the constructor with the attested twin accepted. |
| `Mutants` | Runner-generated from the fixed operator catalogue, eight per subject module, at most forty per gate, kill ratio at least 0.6. A linked set that admits an unlinked spec is killed at the app refusal; a checker that accepts one evasion form is killed at the verdict; a scope constructed without `attest` is killed at the label. No authored mutant seam exists in any subject. |
| `Discovery` | The package description's stanza module map is compared two-way with the subjects; the corpus example count equals the rendered file count; the linked extension count equals the `LinkedExtensions` value's length; empty discovery refuses. |
| `Challenge` | After the run starts, the runner rewrites the rendered example's sentinel to a nonce and removes infernix from the linked set of one sibling. The nonce must appear in the decoded dump, the manifest, and the fake's stdin; the removal must produce `UnboundCapability` at the same app. |
| `Observer` | `ProcessObserver` over the shipped binary and the fake `kubectl`, which is a separate process image; argv, environment policy, exit, and complete output are runner-captured. The AST checker runs inside the shipped binary and its verdict is a captured output. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` refuses a subject outside the executable's closure; the oracle stanza's hygiene refuses a product dependency; `Scope` has no constructor outside `attest`, `LinkedExtensions` is built only at link time, and the checker is not bypassable by a string-built identifier, each checked by a compile-negative or refused twin. |
| `Freshness` | A unique run root; a fresh render every run; the verifier digest equals the seed's; opening and closing source identities are equal. |
| `Qualification` | The generated-mutant matrix over the six subject modules and the evasion-form matrix over the AST checker precede the clean candidate in the same run. |
| `Cleanroom` | Everything generated lives beneath `.build/runs/phase-06/**` and is absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-DSL-005`, `LTD-DSL-007`, and `LTD-DSL-008` close here. |
| `Predecessor` | The Phase 5 receipt in certification generation 2, chained by the digest of Phase 5's product closure plus the verifier and governance digests. |
| `Residue` | Phases 7 through 9 and every phase from 50 onward remain explicit limitations; the parked calculi that no subject links remain visible under `LTD-LIB-001` until Phase 9 decides them; `LTD-HELPER-001` remains visible until Phase 50. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and the human's `accept` records it. |

## Doctrine adopted

- [`dsl_doctrine.md` §8 — the Haskell extension DSL](../documents/engineering/dsl_doctrine.md#8-the-haskell-extension-dsl--the-constrained-surface-extension-astcheck-admits) — the constrained surface the checker admits.
- [`dsl_doctrine.md` §5 — extension-astcheck](../documents/engineering/dsl_doctrine.md#extension-astcheck--the-extension-ast-checker) — the third foreclosure layer this phase realises by AST node.
- [`extension_conformance_doctrine.md` §2 — what an extension is](../documents/engineering/extension_conformance_doctrine.md#2-what-an-extension-is) — one record, linked, not loaded.
- [`extension_conformance_doctrine.md` §7 — link-time union closure](../documents/engineering/extension_conformance_doctrine.md#7-link-time-union-closure) — `LinkedExtensions` is the closure.
- [`capability_extension_doctrine.md` §3 — the PROVIDE and REQUIRE contract](../documents/engineering/capability_extension_doctrine.md#3-the-provide-and-require-contract) — the edge `UnboundCapability` refuses.
- [`capability_extension_doctrine.md` §6 — the merge is total, acyclic, and anti-shadow](../documents/engineering/capability_extension_doctrine.md#6-the-merge-total-acyclic-anti-shadow) — the linked set's merge law.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` this phase carries.
- [`testing_doctrine.md` §9 — derivation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) — the evasion forms as a generated enumeration against authored verdicts.

## Sprints

## Sprint 6.1: The extension-spec library and LinkedExtensions ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/extension-spec/Amoebius/Extension/Spec.hs` and `src/Amoebius/Extension/Linked.hs`
**Blocked by**: [Phase 5](phase_05_substrates_lanes_image_recipe.md) gate pass
**Independent Validation**: `ExtensionSpec` is one record with its provided capabilities, required capabilities, shapes, and engine runtime, and infernix is one value of it. `LinkedExtensions` is built at link time from the values the executable names, and binding a need against it yields the provider objects of the oracle row. An app whose need no linked value provides is refused as `UnboundCapability` at the exact app with the linked twin accepted.
**Oracle**: `test/oracle/dsl/Main.hs` states the provided and required capability sets and the provider objects per example from literals.
**Legacy IDs**: `LTD-DSL-005` — calculi and extension algebra not linked, extension share
**Docs to update**: `documents/engineering/extension_conformance_doctrine.md`

### Objective

Make the extension seam one record type in a base-only library and the linked set its only closure.

### Deliverables

- `library extension-spec` with `ExtensionSpec` and its smart constructor.
- `LinkedExtensions` with a total, acyclic, anti-shadow merge and `UnboundCapability` as its refusal.
- infernix as one `ExtensionSpec` value linked by the executable.

### Validation

Bind each example against the linked set and compare the provider objects with the oracle; require the
unlinked twin to be refused at the exact app.

### Remaining Work

Implement the library and the linked set; delete every second extension record.

## Sprint 6.2: The gate-side GHC-parser AST checker ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Extension/AstCheck.hs`
**Blocked by**: Sprint 6.1
**Independent Validation**: `astcheck` parses an extension module with the GHC parser and admits only the constrained surface the DSL doctrine names. Seven evasion forms — a qualified-alias import, a re-exported forbidden name, a Template Haskell splice, a CPP-guarded definition, a foreign import, a string-built identifier, and a comment-split token — are each rejected at their AST node with the admitted twin accepted. A checker that scans substrings admits at least one form and is the changed-subject mutant the verdict kills.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected verdict per evasion form, naming the node kind, from literals.
**Legacy IDs**: `LTD-DSL-007` — astcheck is a substring scanner
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Replace the substring scanner with a checker that judges the parsed tree.

### Deliverables

- `astcheck :: ModuleSource -> Either Rejection Admitted` over the GHC parser's AST.
- The seven evasion forms as corpus values with authored verdicts.
- `amoebius astcheck` as a product subcommand whose verdict the runner captures.

### Validation

Run the checker over the admitted surface and each evasion form; compare each verdict and node kind with the
oracle.

### Remaining Work

Implement the module and the subcommand; delete the substring scanner.

## Sprint 6.3: Attested-only scope and reenter ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Scope/Attested.hs`
**Blocked by**: Sprint 6.2
**Independent Validation**: `Scope` has no constructor outside `attest`, which records the attesting extension and the need it serves; `reenter` is the one re-entry and requires an existing attested scope. Every rendered object carries its scope label equal to the oracle row. A scope constructed elsewhere is a compile-negative twin, and an object rendered without a scope is refused as `UnattestedScope`.
**Oracle**: `test/oracle/dsl/Main.hs` states the scope label per object and the attesting extension per scope from literals.
**Legacy IDs**: `LTD-DSL-008` — scope introduction not attested
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Make attestation the only way a scope enters the system.

### Deliverables

- `attest` and `reenter` as the two entries into `Scope`, with the constructor private.
- The scope label rendered onto every object by the Phase-4 render entry.
- `UnattestedScope` as a typed refusal at render.

### Validation

Render each example and compare every scope label with the oracle; require the outside constructor to fail
at the type and the unlabeled object to be refused at its tag.

### Remaining Work

Implement the module and delete every scope introduction that does not attest.

## Sprint 6.4: Calculi linked into the executable ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Extension/Calculi.hs` and `amoebius.cabal`
**Blocked by**: Sprint 6.3
**Independent Validation**: The calculi the extension algebra consumes — the workflow calculus and the capability merge — are modules inside the closure of `executable amoebius`, and `Amoebius.Extension.Calculi` is the one import site. A calculus library that no subject links is listed under `LTD-LIB-001` and is not a subject. Re-adding a parked calculus as a dependency without a consuming subject is refused at the closure locus.
**Oracle**: `test/oracle/runner/Main.hs` states the expected closure of the executable from literals.
**Legacy IDs**: `LTD-DSL-005` — calculi and extension algebra not linked, calculus share
**Docs to update**: `documents/engineering/workflow_calculus_doctrine.md`

### Objective

Link what the binary consumes and leave what it does not consume visibly parked.

### Deliverables

- `Amoebius.Extension.Calculi` as the one import site for the consumed calculi.
- The executable's closure containing the workflow calculus for Phase 7 to consume.
- The parked libraries listed under `LTD-LIB-001` for Phase 9 to decide.

### Validation

Compare the executable's closure with the oracle's literal closure; require the unconsumed dependency to be
refused.

### Remaining Work

Implement the import site and the closure check.

## Sprint 6.5: The Phase 6 gate specification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Extensions.hs` and `amoebius.cabal`
**Blocked by**: Sprint 6.4
**Independent Validation**: The compiled specification equals the fenced block above; `verifySpec` accepts it; the corpus module contains the Phase 5 corpus. A specification whose negatives omit `AstEvasion` is refused as `SPEC-WEAKENED`.
**Oracle**: `test/oracle/runner/Main.hs` states the expected specification digest and closure from literals.
**Legacy IDs**: none
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through the human's `accept`

### Objective

Author the specification the runner executes for this phase.

### Deliverables

- The Phase 6 `GateSpec` with its `BinaryFact`, the astcheck verdict output, and the six subjects.
- The `extensions-suite` stanza writing the verdict and scope bytes the oracle judges.

### Validation

Run `preview phase 06` and require every row green; require the human's `accept` to record exactly one
phase's patch.

### Remaining Work

Everything above. The `accept` ends this phase.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes, never before):**

- `documents/engineering/dsl_doctrine.md` — only if the admitted extension surface or the scope entries change.
- `documents/engineering/extension_conformance_doctrine.md` — only if the `ExtensionSpec` record or the link-time closure changes.
- `documents/engineering/workflow_calculus_doctrine.md` — only if the set of linked calculi changes.

**Cross-references to add:**

- Phase 5 predecessor gate pass and Phase 7 consumer links.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 5](phase_05_substrates_lanes_image_recipe.md) — the predecessor
- [Phase 7](phase_07_child_clusters_obligation_teardown.md) — the next slice, consuming the linked workflow calculus
- [Phase 9](phase_09_dsl_barrier.md) — re-runs this corpus and decides `LTD-LIB-001`
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [DSL doctrine](../documents/engineering/dsl_doctrine.md)
- [Extension conformance doctrine](../documents/engineering/extension_conformance_doctrine.md)
- [Capability extension doctrine](../documents/engineering/capability_extension_doctrine.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
