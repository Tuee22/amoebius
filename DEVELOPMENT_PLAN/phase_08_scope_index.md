# Phase 8: Scoped identity kernel

> **Purpose**: Deliver the pure scope index and information-flow relation that prevent values and handles from
> being forged, retagged, widened, or exchanged across request scopes.
> **Read this if**: Phase 8 is the open contract, or a later phase needs the type-level scope boundary it
> establishes.

Phase 8 owns the standalone scope index below the UI language and every live identity or provider boundary.
The tenant model belongs to [tenancy_doctrine.md](../documents/engineering/tenancy_doctrine.md); the pure
security mechanism belongs here, and provider enforcement remains later work.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_37_ui_program_schema.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/extension_conformance_security.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/testing_doctrine.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_tenancy.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 8.1: Rank-2 scope index and total flow checking ✅](#sprint-81-rank-2-scope-index-and-total-flow-checking-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. `python3 tools/scoped_identity_gate.py` passes all thirteen sides on natural
`arm64`: 45 surfaces join to 59 items, all eleven metrics match, five compile pairs hold, the mutant reddens,
and containment is clean. Attestation `sha256:05f9c2f19d07c604d0ec425ae5761d36495e28e2bf034c4f0e71d84834e97ded`
binds source snapshot `sha256:3783dab57707c462…` (2,149 files). Live layers remain `UNVERIFIED`.

## Phase Summary

This phase supplies a constructor-private request scope whose rank-2 eliminator introduces one fresh type
index. Scoped values, resolved handles, labels, and flow witnesses retain that index. A total pure checker
decides owner/grant joins and direct or transitive confidentiality and integrity flows with stable errors.

**Phase scope:** One Register-1 scope-index/flow kernel, accepted by `python3 tools/scoped_identity_gate.py`;
split if work needs a live identity, provider, runtime interpreter, second register, or substrate.
**Substrate:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 1 — pure/golden
**Depends on:** [Phase 7](phase_07_evidence_calculus.md) — its claim-to-fixture calculus binds every gate
surface to an observed locus.
**Gate:** `python3 tools/run_phase_gate.py 08` passes the committed representative corpus, independent
predicates, exact compile pairs, generated coverage floors, network-observed pure run, seeded mutant, ledger,
and universal artifact-hygiene checks described in [Gate integrity](#gate-integrity).

## Gate integrity

- **Representative set:** tenants `t-a` and `t-b`; subjects Alice and Bob in `t-a` and Carol in `t-b`;
  subject-owned, tenant-owned, actively granted, revoked, and absent-grant resources; direct, transitive,
  subject-mismatched, cyclic, incomplete-member, and missing-path flow graphs.
- **Oracle provenance:** the owner, swap, and flow decisions predate the replacement kernel. The diagnostic
  and compile expectations transcribe the pre-existing phase contract and doctrine; they are authored from
  intended errors, never copied from a failing run.
- **Independent predicates:** `owner_join_table.tsv`, `owner_tenant_swaps.tsv`, and `flow_matrix.tsv` are read
  as finite relations by tests that share no resolver, label relation, or graph traversal with production.
  `flow_diagnostics.tsv` owns exact tags and paths.
- **Specific negatives:** five legal/illegal twins separately pin raw identifier construction, scope
  retagging, general declassification, request-index escape, and forged request scope. Each illegal twin must
  fail at its own compiler reason while its legal twin compiles.
- **Generator coverage:** QuickCheck forces tenant, subject, grant, audience, integrity, transitive,
  subject-flow, cycle, and missing-member rejection classes to meet a 5% floor.
- **External observation:** the pure suite runs with networking denied by macOS `sandbox-exec`, Linux network
  namespaces, or injected Linux socket failure. No credential source is available to the contained process.
- **Seeded mutant:** the registry-backed `drop_owner_equality` build flag removes subject-owner equality. Both
  same-tenant and cross-tenant swap pins must redden it at its declared locus.
- **Fresh challenge and authority pairing:** not applicable to this pure phase. Runtime identity, real
  credentials, provider enforcement, and live noninterference remain `UNVERIFIED` for their later live gates.
- **Extension conformance (§M.13).** Not applicable because the phase delivers a core index, not a domain,
  provider, or hardware extension.

The gate proves agreement with finite authored relations and compiler-enforced lexical scope separation. It
does not prove identity-provider truth, persisted-value re-entry, provider row policy, browser behavior, or
live handler noninterference.

## Doctrine adopted

- [`extension_conformance_security.md` §3 — the skolem scope](../documents/engineering/extension_conformance_security.md#3-the-skolem-scope): a rank-2 eliminator mints one fresh request index and private constructors prevent a second introduction rule.
- [`low_code_ui_runtime_doctrine.md` §10.3 — information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels): labels preserve subject audience and integrity across direct and transitive pure flows.
- [`tenancy_doctrine.md` §4 — the typed shapes](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--subjectspec--membership--owner--rolebinding): tenant, subject, membership, owner, and grant distinctions are constructor-private.
- [`illegal_state_security.md` §3.80 — foreign resource resolution](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant): paired owner and tenant swaps exercise exact denial reasons.
- [`illegal_state_security.md` §3.81 — incompatible UI value flow](../documents/illegal_state/illegal_state_security.md#381-a-ui-value-flowing-to-an-incompatible-tenant-subject-or-audience-scope): the finite flow relation and total graph diagnostics exercise the pure foreclosure layer.
- [`illegal_state_tenancy.md` §3.94 — same-typed scope identifiers](../documents/illegal_state/illegal_state_tenancy.md#394-two-same-typed-scope-identifiers-exchangeable-at-a-call-site): distinct private identity types and the request skolem reject transposition and cross-scope reuse.

## Sprints

## Sprint 8.1: Rank-2 scope index and total flow checking ✅

**Status**: Done
**Implementation**: `src/Amoebius/Scope/{Index,Flow}.hs`, the `scope-index` Cabal library,
`test/spec/ui/ScopeSpec.hs`, `test/fixture/ui_scope/**`, `test/oracle/scoped_identity/**`, and
`tools/scoped_identity_gate.py`.
**Blocked by**: None.
**Independent Validation**: Five finite tables and five compiler-positive twins provide expectations outside
the subject. Nine generated reject classes and the real build-flag mutant exercise branches the tables alone
cannot establish.
**Docs to update**: `documents/engineering/{extension_conformance_security,low_code_ui_runtime_doctrine,tenancy_doctrine,testing_doctrine}.md` and `documents/illegal_state/{illegal_state_security,illegal_state_tenancy}.md`.

### Objective

Adopt [`extension_conformance_security.md` §3 — the skolem scope](../documents/engineering/extension_conformance_security.md#3-the-skolem-scope)
and [`low_code_ui_runtime_doctrine.md` §10.3 — information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels): make trusted scope introduction singular and every pure value flow explicit.

### Deliverables

- A constructor-private rank-2 request-scope index and scope-preserving value operations.
- Constructor-private tenant, subject, membership, owner, grant, resource, and resolved-handle types.
- Indexed flow labels and witnesses with a total direct and graph-path checker.
- Stable structured errors for owner, grant, subject-flow, audience, integrity, cycle, missing-member, missing-path, and transitive failures.
- Five specific-reason compiler-negative fixtures, each paired with a legal twin.
- An independent finite corpus, nine-class generated coverage, and one registry-backed build-flag mutant.
- A contained Register-1 gate with architecture, source-snapshot, ledger, surface-join, and artifact-hygiene evidence.

### Validation

1. Match all six owner rows, both exact swap errors, four flow decisions, and four exact flow diagnostic
   tag/path rows against independently read fixtures.
2. Compile every legal twin and require each illegal twin to fail at its pinned compiler reason.
3. Meet all nine QuickCheck reject-class floors and require `drop_owner_equality` to redden on both swaps.
4. Run the suite with OS-observed network denial, scan the public API for twelve closed constructors and no
   retag/declassification escape, and reject partial or unsafe source tokens.
5. Join every enumerated item and surface, keep all outputs generated, bind the result to the natural
   architecture and source snapshot, and record provider/runtime layers as `UNVERIFIED`.

### Remaining Work

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/extension_conformance_security.md` — record the delivered lexical skolem mechanism and retain the persisted-value re-entry residue.
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the pure label/index result without promoting live enforcement.
- `documents/engineering/tenancy_doctrine.md` — distinguish the pure request index from later provider isolation.
- `documents/engineering/testing_doctrine.md` — record the exact authored-expectation/generated-enumeration split.
- `documents/illegal_state/illegal_state_security.md` and `illegal_state_tenancy.md` — refresh the Phase-8 evidence at the type and pure-decision loci.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md`, `overview.md`, and `system_components.md` — reconcile status, sequence, and concrete module paths.
- `DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md` — consume Phase 8 rather than present a reverse dependency.

## Related Documents

- [Development Plan Standards](development_plan_standards.md) — the phase shape and gate contract.
- [Development Plan Tracker](README.md) — numeric order and current status.
- [Evidence Calculus](phase_07_evidence_calculus.md) — the preceding claim-to-fixture boundary.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) — the authored-expectation and generated-enumeration split.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — the later UI consumer and information-flow rule.
- [Extension Security Laws](../documents/engineering/extension_conformance_security.md) — the shared skolem mechanism and its honest residue.
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md) — the authoritative tenant and subject model.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — foreign-resource and incompatible-flow states.
- [Illegal-State Tenancy Slice](../documents/illegal_state/illegal_state_tenancy.md) — run-time scope-index states.
