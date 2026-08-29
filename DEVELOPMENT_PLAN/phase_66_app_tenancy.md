# Phase 66: Tenant/provider provisioning

> **Purpose**: Materialize one checked tenant graph as tenant-qualified control-plane objects in every required
> provider, and establish by independent provider readback that no arm was omitted, collapsed, or hand-authored.
> **Read this if**: phase 66 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 66.1: Derive, apply, and externally read back tenant provider policy ⏸️](#sprint-661-derive-apply-and-externally-read-back-tenant-provider-policy-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 65, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and reviewer-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

Phase 66 binds a checked `TenantSpec` containing issuer-qualified `SubjectSpec`, `Membership`, `Owner`, and
`RoleBinding` references to one total `TenantPolicyDerivation`. The derivation has a closed provider index:
Keycloak, Vault, Pulsar, MinIO, Kubernetes API (including NetworkPolicy), and Postgres. Each provider object,
target, executor attachment, persistence demand, and cleanup action retains its `AppId` and `TenantId`; there
is no unqualified resource coordinate and no DSL constructor for a provider-native grant.

The future gate must apply that sealed derivation to the reviewer-approved Phase-65 cluster and read each provider back through
a separately authenticated observer. The boundary tests whether checked policy was projected completely and
faithfully for the representative corpus. It does **not** establish that a user request is confined by those
policies: Phase 68 owns the real-credential, own-subject/foreign-subject and own-tenant/foreign-tenant
application-data-path gate.

**Phase scope:** one provider-projection transaction. The `tenant-provider-provisioning-live` Haskell
component suite can supply supporting observations only; the sole acceptance command is `pb validate phase 66`. Split the phase if
work adds an application data operation, UI interaction, another cluster, HA failover, a second substrate, or
a separately useful provider feature.
**Substrate:** `linux-cpu` — future live cluster observation only after the Phase-49 barrier and every predecessor approval.
**Lane:** `linux-cpu/amd64`.
**Register:** 3 — live provider materialization and independent readback; NOT VALIDATED.

**Depends on:** [Phase 65](phase_65_live_dsl_deploy.md)
**Gate:** `pb validate phase 66`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive claim — *a tenant graph materializes into every required provider, or the phase fails*. Independent readback is what distinguishes materialization from intention. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 66` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 65; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

- Whole-deployment binding admits the app namespace, provider persistence, provider executor, API-object,
  etcd, object-metadata, SQL-role, Pulsar-metadata, observer, teardown, and failure-retention demands before the
  first live mutation.
- `TenantPolicyDerivation` is an immutable pure intermediate. Private `ProvisionedTenantPolicyAction` values
  retain source digest, `AppId`, `TenantId`, provider, operation, old/new target, canonical payload digest,
  executor identity, persistence high-water, rollback retention, and cleanup predicate.
- The provider index is closed and exhaustive. NetworkPolicy is a Kubernetes-API payload; Postgres roles and
  grants are Postgres provider outputs; MinIO IAM and bucket policy are provider metadata rather than app
  objects. Pulsar application produce/consume is owned by Phase 67 and scoped end-to-end enforcement by Phase
  68.
- The enactors accept only provisioned actions paired with a fresh validated live target. They do not accept a
  `TenantSpec`, caller-authored policy, raw provider coordinate, or previously serialized `Provisioned*` value.
- Deletes are explicit actions over desired and observed identity, including observed-only tenants. Old and
  new targets remain charged until authenticated readback confirms the replacement and cleanup confirms the old
  object absent.

## Doctrine adopted

- [`workflow_calculus_doctrine.md` §3 — Teardown is a type obligation](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation) — tenant/provider provisioning provisions, and a teardown obligation it cannot discharge is a value it cannot construct.
- [`tenancy_doctrine.md` §4 — The typed shapes: `TenantSpec` / `SubjectSpec` / `Membership` / `Owner` / `RoleBinding`](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--subjectspec--membership--owner--rolebinding): consume the Phase-8 identity
  values without reintroducing an unqualified subject, tenant, owner, membership, or resource reference.
- [`tenancy_doctrine.md` §5 — RBAC is derived, never authored](../documents/engineering/tenancy_doctrine.md#5-rbac-is-derived-never-authored): a checked tenant/role graph is the only source of provider policy.
- [`service_capability_doctrine.md` §4 — Capability → provider → shape: the binding](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding): provider bindings supply mechanism, never caller authority.
- [`platform_services_doctrine.md` §8 — Postgres — Patroni-via-Percona, one cluster per consumer, with pgAdmin; “Tenant policy persistence is one provider-indexed transaction”](../documents/engineering/platform_services_doctrine.md#tenant-policy-persistence-is-one-provider-indexed-transaction): apply the
  provider-indexed transaction through least-authority enactors and authenticated readback.
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): bind the claim to post-ready challenges,
  authority separation, raw external observations, paired cases, bypass probes, and killed mutants.
- [`illegal_state_security.md` §3.80 — A subject resolving or mutating another subject's resource without a grant](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant): Phase 66 provisions the policy
  precondition but leaves its live request-enforcement residue to Phase 68.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and an authorized-reviewer tracker change.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in reviewed Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 66.1: Derive, apply, and externally read back tenant provider policy ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 65](phase_65_live_dsl_deploy.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Turn one sealed checked tenant graph into a complete live provider transaction without claiming that provider
provisioning alone establishes application request isolation.

### Deliverables

- The closed, total tenant-policy derivation and private provisioned-action boundary.
- Provider enactors for the six required arms plus independent normalized read-only observers.
- Reviewed Haskell projection/oracle fixtures, paired illegal inputs, post-ready challenge protocol,
  zero-effect checks, authenticated cleanup inventory, and a Haskell-schema-checked Register-3 ledger. Any
  serialized corpus or ledger view is generated lazily beneath ignored `.build/**`.
- Applied Haskell changed-subject `drop_provider_arm` and `collapse_tenant_key` mutation operators.

### Validation

1. Rejected historical observation: the `tenant-provider-provisioning-live` Cabal suite expected every
   challenge-qualified object and relation in
   the independently authored Haskell provider-projection expectation exactly once under the correct
   app/tenant parent. Any TSV projection is a lazy `.build/test-corpora/**` product.
2. Require the hand-authored-grant and tenant-mismatched twins to fail before mutation and externally establish their distinct
   forbidden nonces absent through every provider observer.
3. Run both Haskell-authored changed-subject mutants against the unchanged gate and require the pinned missing-arm and tenant-key
   failures.
4. Tear down and require authenticated provider inventories to equal preflight; persist only hashed evidence
   and explicitly mark application data-path isolation `UNVERIFIED (Phase 68)`.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. Phase 68 retains the application request-isolation residue.

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

- `documents/engineering/tenancy_doctrine.md` and `platform_services_doctrine.md` — record tested provider
  projection/readback only.
- `documents/engineering/testing_doctrine.md` — register the six-observer transaction pattern.
- `documents/illegal_state/illegal_state_security.md` — attach the killed hand-authored/tenant-collapse evidence
  while retaining Phase 68's live enforcement residue.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — index the narrowed
  provider-provisioning claim.
- `DEVELOPMENT_PLAN/phase_67_pulsar_client.md` and `phase_68_user_tenant_isolation_live.md` — consume provider
  readiness without treating it as user authorization evidence.

## Related Documents

- [Phase 38 — UI authorization kernel](phase_38_ui_authorization_kernel.md)
- [Phase 65 — live DSL control-plane daemon](phase_65_live_dsl_deploy.md)
- [Phase 67 — Pulsar client](phase_67_pulsar_client.md)
- [Phase 68 — live subject/tenant isolation](phase_68_user_tenant_isolation_live.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
