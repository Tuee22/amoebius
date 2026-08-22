# Extension Conformance — The Transaction Laws

> **Purpose**: The slice of the extension family owning **P1–P6**, the laws governing the relational data
> plane: no general query surface, the scope as a required field, the schema derived from the row types, the
> statement and the row policy derived from one declaration, results indexed by the scope that produced them,
> and schema change as a typed transition. It also fixes Postgres's **two distinct roles** — a provisioned backend amoebius never reads, and
> a typed data plane amoebius owns every statement of.
> **Read this if**: relational storage is being added to an extension, or the absence of an ORM has to be
> justified.

This slice owns the P family and the two-roles distinction. Four of the six sharpen a law stated elsewhere and
two do not, so the attribution is given per law rather than as a range:

| Law | Sharpens | |
|---|---|---|
| P1 | L1 (totality) | a general query surface is an open vocabulary, not a scope defect |
| P2 | S3 | the scope is carried, not supplied by the caller |
| P3 | — | a derivation rule: the schema is generated from the row types. It sharpens no law; it is why P1 and P4 are checkable at all |
| P4 | — | a single-declaration rule. Statement and policy come from one source so the two cannot disagree; no L- or C-law reaches a *second* statement of one thing |
| P5 | L4 (scope propagation) | at the boundary where the index is erased and reconstructed |
| P6 | — | reuses the destructive-verb foreclosure of [`inforcespec_migration_doctrine.md`](./inforcespec_migration_doctrine.md) |

P3, P4 and P6 are therefore **additional** obligations, on the terms
[`extension_conformance_doctrine.md` §4](./extension_conformance_doctrine.md#4-the-four-law-families) states for
the family: the closure argument does not carry them across a seam. The algebra belongs to
[`extension_conformance_laws.md`](./extension_conformance_laws.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/system_components.md, documents/README.md, documents/engineering/README.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/extension_conformance_security.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/platform_services_doctrine.md
**Generated sections**: none

</details>

## Contents
- [1. Scope](#1-scope)
- [2. Postgres has two roles, and only one of them is amoebius's](#2-postgres-has-two-roles-and-only-one-of-them-is-amoebiuss)
- [3. Why there is no ORM](#3-why-there-is-no-orm)
- [4. P1–P6](#4-p1p6)
- [5. What this costs](#5-what-this-costs)
- [Related Documents](#related-documents)

---

## 1. Scope

This document is a **family slice**. It owns the six transaction laws and the role split of [§2](#2-postgres-has-two-roles-and-only-one-of-them-is-amoebiuss). It does not own
the provisioning of a Postgres instance, its backup and recovery, its capacity accounting, or the tenant model
the scope index expresses; each is named where it is used. [Phase 36](../../DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md)
delivers the bounded pure instance: three row declarations, five scope-indexed transactions, two additive
generation transitions, four compiler barriers, and three paired semantic mutants. That Register-1 result
does not install SQL or exercise a database role; live catalog, policy, and executor fidelity remain
UNVERIFIED, and status lives only in the [tracker](../../DEVELOPMENT_PLAN/README.md).

---

## 2. Postgres has two roles, and only one of them is amoebius's

Postgres appears twice in an amoebius deployment, and conflating the two is how the discipline below gets
argued away.

**Role one: a provisioned backend for a platform service.** Keycloak keeps its realms, clients, and users in
Postgres. amoebius provisions that database, sizes it, backs it up, monitors it, and tears it down — and never
issues a statement against it. Its schema belongs to Keycloak, its migrations arrive with Keycloak upgrades,
and amoebius reading or writing it would be a second owner of one state
([`platform_services_doctrine.md`](./platform_services_doctrine.md)). For this role Postgres is a capability
instance like any other, and none of P1–P6 applies to its contents.

**Role two: the typed data plane.** An application's own rows — belonging to tenants, subjects, and audiences —
live in a database whose every statement amoebius emits from its own types. This is the role the laws govern,
and the distinction is load-bearing: the first role's existence is the standing argument for installing a
general query surface ("we already talk to Postgres"), and it is not one, because amoebius does not talk to the
first database at all.

---

## 3. Why there is no ORM

An object-relational mapper, a query builder, and a raw statement API are all the same thing from the
composition proof's point of view: **a language for writing any statement**. Every safety property such a
surface has is a property of the statements somebody remembered to write, which is exactly the class of
guarantee this corpus exists to replace.

The specific failure is not hypothetical. A general surface makes an un-scoped query *expressible*, so the
scoping becomes a discipline rather than a type, and the discipline is applied by whoever writes the next
handler. It also makes the schema, the row policy, and the query three independent statements of one fact,
which is the divergence the generated-artifact discipline forecloses everywhere else
([`generated_artifacts_doctrine.md`](./generated_artifacts_doctrine.md)).

So the data plane is a **closed union of the transactions the domain actually has**. Each arm is a constructor
with required fields, and the set of arms is a declaration in the extension's vocabulary. Adding a transaction
is a change to the program that re-derives the schema, the policy, and the statement together. It is not
something an application does while running, and it is not something a handler author can do locally.

---

## 4. P1–P6

### P1 There is no general query surface

**Hazard.** Any arm accepting statement text, any predicate combinator, and any reflective mapper reintroduces
the whole space of un-scoped statements, and the composition proof cannot reason about a language.

**Guideline.** The database module exports transaction constructors and an executor. It exports no way to build
a statement, no way to pass one, and no escape hatch for "just this once". If a transaction you need does not
exist, add the arm.

**Discharge.** The exported surface is asserted against an independently authored expectation, and compile-fail
fixtures attempt to pass statement text and to build a predicate. **Residue:** an extension could shell out to a
database client; the ambient-authority scan of C4 is what covers that, not this law.

### P2 The scope is a required field of every transaction

**Hazard.** A transaction whose scope is optional is [S3](./extension_conformance_security.md#s3-refusal-is-the-default-not-the-fallback)'s
hazard with a database behind it: a forgotten argument becomes every tenant's rows.

**Guideline.** Take the request context, not a tenant identifier, and pass it to the constructor. A transaction
you cannot construct without a scope is a transaction you cannot run without one.

**Discharge.** No transaction arm is applicable without its scope field, so the un-scoped statement has no
inhabitant; the emitted statement is additionally parsed and required to bind the scope to a mandatory
parameter. Foreclosed state:
[§3.92](../illegal_state/illegal_state_tenancy.md#392-a-scope-filter-whose-absent-value-means-every-scope).

### P3 The schema is derived from the row types

**Hazard.** A hand-authored schema drifts from the code that reads it. The acute case is a nullable scope
column, which admits a row belonging to nobody and matching every tenant's policy.

**Guideline.** Declare the row type in Haskell with the scope as an ordinary required field. Do not write DDL.
The column types, the `NOT NULL` constraints, the composite foreign key back to the scope table, and the
indexes all follow from the row type, and anything you would have added by hand is either derivable or a
finding.

**Discharge.** The emitted DDL is compared against an independently authored expectation, and a live catalog
oracle enumerates every scope-bearing table and requires the constraint and the composite key on each.
Foreclosed state:
[§3.96](../illegal_state/illegal_state_tenancy.md#396-a-scope-column-that-admits-null).

### P4 The statement and the row policy come from one declaration

**Hazard.** A row-level security policy and the queries it guards, written separately, disagree — usually
because the policy filters one column and the query joins another. Both look right in isolation, and the
disagreement is a leak or an outage depending on which way it falls.

**Guideline.** You do not write policies either. The policy for a table is emitted from the same declaration
that emits its statements, so the predicate is the same expression in both.

**Discharge.** The gate requires the policy predicate and the statement predicate to be derived from one term,
and a live probe runs each transaction as the application role with the policy enabled and again with a foreign
scope, requiring the second to return nothing. **Residue:** that the deployed policy is the emitted one is a
`live-effect` check, not a type property.

### P5 A result is indexed by the scope that produced it

**Hazard.** A row set that has lost its scope index can be serialized into a response, a log, a message, or a
cache belonging to a different scope, and nothing in its type objects. This is the leak that happens *after*
the query was correct.

**Guideline.** Do not unwrap a result to a bare record to make it fit a serializer. The serializer takes the
scoped type. If a value must cross into a broader audience, that crossing is a named, policy-owned release
edge with its own constructor.

**Discharge.** L4's flow relation is instantiated over the extension's declared database sources and its sinks,
and every path reaching a wider sink is reported. Foreclosed state:
[§3.81](../illegal_state/illegal_state_security.md#381-a-ui-value-flowing-to-an-incompatible-tenant-subject-or-audience-scope).

### P6 A schema change is a typed transition, never an edit

**Hazard.** An ad-hoc migration is a statement outside the vocabulary, executed with more authority than any
handler has, against data that cannot be recovered if it is wrong. It is where the destructive verbs live.

**Guideline.** A schema change is a transition between two declared generations, expressed in the same
vocabulary as everything else. There is no `DROP`, no `TRUNCATE`, and no `DELETE` arm to reach for, because the
mutation union has none
([`inforcespec_migration_doctrine.md` §3](./inforcespec_migration_doctrine.md#3-the-dsl-exposes-no-destructive-verb--the-closed-storagemutation-union)).
A retired column is unreferenced by the new generation and its bytes stay.

**Discharge.** The generation transition is total over the declared row types, and the no-orphan fold requires
every retained coordinate in the old generation to be reachable from the new one; the emitted migration is
compared against an independently authored expectation. Foreclosed states:
[§3.85](../illegal_state/illegal_state_storage.md#385-a-spec-verb-that-destroys-durable-bytes),
[§3.86](../illegal_state/illegal_state_storage.md#386-a-new-generation-that-orphans-a-retained-coordinate).

---

## 5. What this costs

The discipline is expensive in exactly one place, and saying so is part of stating it honestly.

**Ad-hoc questions become code changes.** With an ORM, answering "how many of these are there per tenant this
week" is a query somebody writes at a console. Here it is a new transaction arm, a re-derivation, and a
deployment. That is the intended trade — the console query is the same mechanism as the un-scoped statement —
but it is a real cost and it lands on whoever is trying to answer a question quickly.

**The mitigation is not an escape hatch.** It is that analytical reads are a *different capability* with their
own scope discipline: a read-only replica, a declared projection, and an audience that is not the tenant's live
data plane. What is foreclosed is reaching the operational database through a general surface; what is
provided is a place for the question to live.

**What is not claimed.** These laws say nothing about the database enforcing what was emitted, about the
connection carrying the role it should, or about an operator with superuser access. Those are
`runtime-checked` residues, recorded per law above and covered — to the extent they can be — by live probes
rather than by types.

---

## Related Documents
- [Extension Conformance Doctrine](./extension_conformance_doctrine.md) — the hub: the obligation surface, the generated gate, and the verdict seal
- [Extension Conformance Laws](./extension_conformance_laws.md) — L4 and C6, which [P5](#p5-a-result-is-indexed-by-the-scope-that-produced-it) instantiates
- [Extension Conformance Security](./extension_conformance_security.md) — S3, which [P2](#p2-the-scope-is-a-required-field-of-every-transaction) sharpens at the relational seam
- [Platform Services Doctrine](./platform_services_doctrine.md) — owner of the provisioned-backend role of [§2](#2-postgres-has-two-roles-and-only-one-of-them-is-amoebiuss)
- [Tenancy Doctrine](./tenancy_doctrine.md) — owner of the tenant model and the derived RBAC transaction
- [InForceSpec Migration Doctrine](./inforcespec_migration_doctrine.md) — the closed mutation union [P6](#p6-a-schema-change-is-a-typed-transition-never-an-edit) reuses
- [Storage Lifecycle Doctrine](./storage_lifecycle_doctrine.md) — durable-byte retention, which [P6](#p6-a-schema-change-is-a-typed-transition-never-an-edit) inherits
- [Generated Artifacts Doctrine](./generated_artifacts_doctrine.md) — why DDL and policies are emitted rather than authored
- [Backup / Recovery Doctrine](./backup_recovery_doctrine.md) — the recovery obligations both Postgres roles carry
- [Illegal States — Tenancy, Scope & Authentication](../illegal_state/illegal_state_tenancy.md) — the catalogued states these laws foreclose
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
