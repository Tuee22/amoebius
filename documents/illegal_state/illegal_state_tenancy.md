# Illegal States — Tenancy, Scope & Authentication

> **Purpose**: The themed slice of the illegal-state catalog covering the states in which *whose data this is*
> is decided at run time — an unauthenticated route taking its scope from the caller, a filter whose absent
> value widens instead of refusing, a locally rebuilt session wearing an attested session's type, two
> exchangeable identifiers, an unscoped replay key, a nullable scope column, and a key rendering that collides
> two scopes into one.
> **Read this if**: an isolation boundary between tenants or subjects has to hold for scopes nobody knew about
> when the program was compiled.

This slice covers the scope boundary as it exists in a running multi-tenant application, where the tenant is
not a name in a fixture but a value that arrives with a request. Its numbering belongs to
[illegal_state_catalog.md](./illegal_state_catalog.md) and its construction patterns to
[illegal_state_techniques.md](./illegal_state_techniques.md), whose skolem scope
([§4.8](./illegal_state_techniques.md#48-the-skolem-scope--a-runtime-tenant-becomes-a-compile-time-index)) and
closed transaction vocabulary
([§4.9](./illegal_state_techniques.md#49-the-closed-transaction-vocabulary--only-valid-transactions-have-a-constructor))
exist for the entries below. The tenant model itself is owned by
[tenancy_doctrine.md](../engineering/tenancy_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_08_scope_index.md, documents/engineering/extension_conformance_laws.md, documents/engineering/extension_conformance_security.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Every phase-run or implementation-result statement in this document is permanently invalidated diagnostic history. It cannot establish or reactivate current status, even if a phase later advances. Target doctrine remains normative; current status is solely in the [tracker](../../DEVELOPMENT_PLAN/README.md).

## Contents
- [1. Scope](#1-scope)
- [2. The tenancy, scope & authentication illegal states](#2-the-tenancy-scope--authentication-illegal-states)
- [Related Documents](#related-documents)

---

## 1. Scope

This document is a **themed slice** of the illegal-state catalog. Its entries share one shape: the value that
decides which tenant, subject, or audience a piece of data belongs to is learned while the program runs, so a
foreclosure written against names known at compile time does not reach them. The
[security slice](./illegal_state_security.md) covers the ingress, secrets, and authority boundaries; this slice
covers what remains once a request has crossed them and has to be served under exactly one scope.

The **catalog index** (the enumerated list of every illegal state) and the **honesty limit** (that a type-check
proves the specification composes, never that the running cluster enforces it) are owned by
[`illegal_state_catalog.md`](./illegal_state_catalog.md). The **nine typing techniques**, the **coverage
matrix**, the **three foreclosure layers**, and the **validation-locus axis** are owned by
[`illegal_state_techniques.md`](./illegal_state_techniques.md) — referenced here, not restated. Each entry
below names its owning doctrine, which remains the SSoT for the normative rule.

Everything below states the target type discipline. [Phase 8](../../DEVELOPMENT_PLAN/phase_08_scope_index.md)
owns its lexical request-index kernel; authentication, persisted re-entry, provider enforcement, replay,
and other entry-specific residues remain with their delivery owners. Status and gates live only in
[`../../DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md).

---

## 2. The tenancy, scope & authentication illegal states

### 3.91 An unauthenticated route whose scope comes from the request

**Delivery-owner:** `Phase-44`

**Case-family:** `security`

**Cells:** `type-foreclosed`×`gadt-decode` · `decode-foreclosed`×`provision-seal` · `runtime-checked`×`live-effect`

A route mounted outside the authentication boundary that still reads a tenant, organization, or account
identifier out of its path, query string, or body performs an anonymous read of scoped data under a scope the
caller chose. This is not a forgotten check. It is a handler whose entire notion of *whose data this is*
arrives from the party it is protecting the data from, and nothing in such a handler's type distinguishes it
from an authorized one, so it reviews as ordinary code. amoebius gives a handler no way to have that shape. A
handler is not a function from a request; it is a function from a `RequestContext s`, and the only introduction
of that type is `withRequestScope`, which consumes a `ValidatedIdentity` and skolemises the scope. Every data
operation in the closed transaction vocabulary takes that witness as a required field, so a handler holding no
witness has no operation it can call: a public route can serve constants and nothing else. The route table
carries its authentication mode as an index, and a route declared public whose handler is typed at a scope does
not decode. **Owner:**
[`tenancy_doctrine.md` §7](../engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit)
(the isolation layers) +
[`low_code_ui_runtime_doctrine.md` §9](../engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge)
(routes, identity, and the edge). **Technique:**
[§4.8](./illegal_state_techniques.md#48-the-skolem-scope--a-runtime-tenant-becomes-a-compile-time-index)
(the scope exists only inside an authenticated continuation) +
[§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(the handler is indexed by authentication state).

**Layer:** `type-foreclosed` for a scoped operation reached without a witness; `decode-foreclosed` for a route
table whose declared mode disagrees with its handler index; `runtime-checked` residue — that the gateway
actually terminates authentication ahead of every mounted route.
**Validation-locus:** `gadt-decode` (a handler with no `RequestContext` cannot name a scoped operation) +
`provision-seal` (route mode and handler index must agree across the whole table before a served program
exists) + `live-effect` residue (an unauthenticated probe of every route returns refusal, and returns it
without disclosing whether the named scope exists).

**Independent oracle and mutants.** A compile-fail fixture calls a scoped operation from a public handler, and
a second constructs a `RequestContext` directly. A route oracle independent of the router enumerates every
mounted path from the built artifact and requires each to carry a mode, then drives an unauthenticated request
at each with a scope identifier the harness owns. Mutants mark one scoped route public, admit a body-supplied
scope in place of the witness, and return a distinguishable error for an existing versus absent scope; each
must turn the matrix red before any response body is produced.

### 3.92 A scope filter whose absent value means every scope

**Delivery-owner:** `Phase-37`

**Case-family:** `security`

**Cells:** `type-foreclosed`×`gadt-decode` · `decode-foreclosed`×`rendered-artifact-oracle` · `runtime-checked`×`live-effect`

A query surface in which the scope predicate is optional, and in which omitting it selects every scope rather
than refusing, converts a forgotten argument into a full disclosure. The idiom is common and it reads as
defensive: a parameterized predicate that passes when the parameter is null, so one code path serves both the
administrative and the tenant case. Its failure mode is silent, because the widened result is well formed and
the caller cannot tell it apart from a correct one. amoebius has no query surface of that kind. The data plane
is a closed union of the transactions the domain actually has, and each arm takes the scope witness as a
required field rather than as a filter; a statement without its scope is an unapplied constructor and does not
exist as a value. There is no combinator that builds a predicate, and no arm that accepts statement text, so
the widening has no syntax to be written in. **Owner:**
[`tenancy_doctrine.md` §5.1](../engineering/tenancy_doctrine.md#51-the-transaction-is-tenant-qualified-exhaustive-and-may-become-empty)
(the transaction is tenant-qualified, exhaustive, and may legitimately return nothing). **Technique:**
[§4.9](./illegal_state_techniques.md#49-the-closed-transaction-vocabulary--only-valid-transactions-have-a-constructor)
(the scope is a field of the constructor) +
[§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally)
(one derivation owns the emitted row policy).

**Layer:** `type-foreclosed` — the transaction arm cannot be applied without its scope, so the widened
statement has no inhabitant; `runtime-checked` residue — that the database enforces the emitted row policy for
the role the application connects as. The emitted statement and its row policy are `decode-foreclosed`, compared by a total predicate over rendered output.
**Validation-locus:** `gadt-decode` (a transaction value missing its scope does not typecheck) +
`rendered-artifact-oracle` (the emitted statement text and its row-level security policy both carry the scope
predicate, compared against the separately reviewed Haskell `scopedTransactionExpectation`, implemented
without calling the statement/policy emitter) + `live-effect` residue (that the database
enforces the emitted row policy for the role the application connects as).

**Independent oracle and mutants.** A tracked Haskell negative declaration lazily materializes a module that
partially applies a transaction arm and passes it to the executor beneath `.build/test-corpora/**`, then
requires its exact GHC refusal. The Haskell `scopedTransactionExpectation` parses the emitted projection and
requires a scope predicate bound to a parameter that the transaction type makes mandatory. No SQL, fixture
module, or encoded expected value is tracked. Haskell mutants make the scope field
optional, default it to a match-all comparison, and emit a policy for a different column than the statement
filters on.

### 3.93 A locally reconstructed session bearing the type of an attested one

**Delivery-owner:** `Phase-42`

**Case-family:** `security`

**Cells:** `type-foreclosed`×`gadt-decode` · `decode-foreclosed`×`provision-seal` · `runtime-checked`×`live-effect`

An offline-capable client that rebuilds its session, bootstrap, or entitlement value from browser-held storage
produces a value of the same type the server produces, and hands it to code that cannot tell the two apart.
Every downstream authorization decision then rests on a structure the user can edit, because browser storage is
writable by whoever holds the browser. The defect is not the offline path; it is that the offline path and the
attested path share one type. amoebius indexes attestation into the type. An identity is
`Identity 'Claimed` or `Identity 'Attested`, the offline reconstruction can only produce the former, and there
is no function from one to the other: the sole introduction of `'Attested` is signature verification against an
issuer key the browser does not hold. A scope is minted only from an attested identity, so an offline session
can render what it has already been given and can queue intents, and can reach no operation that requires a
scope. **Owner:**
[`browser_offline_runtime_doctrine.md` §7](../engineering/browser_offline_runtime_doctrine.md#7-offline-identity-and-partitioning)
(offline identity and partitioning) +
[`tenancy_doctrine.md` §7.1](../engineering/tenancy_doctrine.md#71-offline-browser-partitions-preserve-scope-but-cannot-prove-revocation-while-disconnected)
(what an offline partition can and cannot prove). **Technique:**
[§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
(verification is the only transition into the attested state) +
[§4.8](./illegal_state_techniques.md#48-the-skolem-scope--a-runtime-tenant-becomes-a-compile-time-index)
(the scope is minted by that transition and by nothing else).

**Layer:** `type-foreclosed` for an authority-bearing operation applied to a claimed identity;
`decode-foreclosed` for a stored envelope whose signature does not verify; `runtime-checked` residue — that
revocation reaches a partition that has been disconnected, which it provably cannot until the partition
reconnects.
**Validation-locus:** `gadt-decode` (no total function produces `Identity 'Attested` from stored bytes) +
`provision-seal` (every authority-bearing operation in the bound program is typed at the attested index) +
`live-effect` residue (a tampered storage entry yields refusal rather than a session).

**Independent oracle and mutants.** A compile-fail fixture applies a scoped operation to a reconstructed
identity, and a second exports a promotion function. A browser harness rewrites the stored envelope — its
scope, its entitlements, its expiry — reloads, and requires that every scoped surface refuse. Mutants accept an
unverified envelope, verify against a key read from the same storage, and treat an expired attestation as
current.

### 3.94 Two same-typed scope identifiers exchangeable at a call site

**Delivery-owner:** `Phase-8`

**Case-family:** `security`

**Cells:** `type-foreclosed`×`gadt-decode`

A function taking a tenant identifier and a subject identifier as adjacent parameters of the same type accepts
them in either order. Both call sites typecheck, one of them is a cross-scope read, and the compiler has
nothing to say about it. Real code reaches this state by transporting identifiers as strings or as a single
UUID type across a boundary, at which point every downstream signature loses the distinction. amoebius does not
transport a scope identifier as a value of a shared type. Each identifier kind is its own newtype with a
private constructor, and a resolved reference is a `Handle s kind` whose `s` is the skolem of the enclosing
request, so a handle from one request cannot be applied where a handle from another is expected — not because
the values differ but because the types do. Adjacent parameters of one shape do not arise, and a transposition
is a unification failure rather than a review finding. **Owner:**
[`tenancy_doctrine.md` §4](../engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--subjectspec--membership--owner--rolebinding)
(the typed tenant, subject, membership, and owner shapes). **Technique:**
[§4.8](./illegal_state_techniques.md#48-the-skolem-scope--a-runtime-tenant-becomes-a-compile-time-index)
(the per-request index no two scopes share) +
[§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(one newtype per identifier kind, with no re-tagging function).

**Layer:** `type-foreclosed` — the transposed application does not unify, and no residue remains, because the
distinction is carried by the type rather than by a comparison.
**Validation-locus:** `gadt-decode` (transposition and re-tagging fixtures fail to compile, and the identifier
newtypes export no constructor that would reconstruct one from text).

**Independent oracle and mutants.** Compile-fail fixtures transpose each adjacent identifier pair in the scoped
API, construct a handle from a raw string, and coerce a handle from one request scope into another. A signature
oracle independent of the API walks every exported scoped function and requires that no two adjacent parameters
share a type. Mutants collapse two identifier newtypes into one, export a raw constructor, and add a coercion
between scopes.

**Permanently invalidated Phase-8 run report.** The Register-1 kernel gives tenant and subject distinct private types and introduces a
fresh request index through one rank-2 eliminator. Legal twins compile; scope retagging, request-index escape,
and forged scope construction fail at pinned reasons. Constructor scans reject a second introduction or
retagging rule. Live authentication and persisted-value re-entry remain `UNVERIFIED`. See
[Phase 8](../../DEVELOPMENT_PLAN/phase_08_scope_index.md).

### 3.95 A replay key that does not name its scope

**Delivery-owner:** `Phase-42`

**Case-family:** `security`

**Cells:** `type-foreclosed`×`gadt-decode` · `runtime-checked`×`live-effect`

An offline queue, an idempotency table, or a response cache keyed only by a client-chosen identifier puts two
scopes in one keyspace. A replay then returns the record written by whoever used that key first, and the
disclosure looks like a cache hit. The client chooses the key, so the collision is reachable on purpose as well
as by accident. amoebius does not let a key be a string a caller supplies. A key is derived by one total
function from the request scope and the intent identity, its type is indexed by that scope, and a lookup in one
scope cannot be applied to a key minted in another. The same derivation produces the queue key, the idempotency
record, and any cache entry, so the three cannot disagree about what a repeat means. **Owner:**
[`browser_offline_runtime_doctrine.md` §9](../engineering/browser_offline_runtime_doctrine.md#9-authoritative-replay-and-typed-outcomes)
(authoritative replay and typed outcomes). **Technique:**
[§4.8](./illegal_state_techniques.md#48-the-skolem-scope--a-runtime-tenant-becomes-a-compile-time-index)
(the key carries the scope index) +
[§4.5](./illegal_state_techniques.md#45-content-address-totality--names-are-total-functions-of-content)
(the key is a total function of scope and intent, never an argument).

**Layer:** `type-foreclosed` for a lookup crossing scopes; `runtime-checked` residue — that the store holding
the keyspace is the one the derivation addressed, and that no operator-authored key reaches it.
**Validation-locus:** `gadt-decode` (a key value cannot be constructed from caller-supplied text, and a
cross-scope lookup does not typecheck) + `live-effect` residue (two scopes replaying the same client identifier
observe independent outcomes).

**Independent oracle and mutants.** A compile-fail fixture builds a key from a request field and looks it up
under a different scope. A live oracle drives the same client-chosen identifier from two scopes concurrently
and requires two independent records and two independent outcomes. Mutants drop the scope from the derivation,
accept a caller-supplied key, and share one idempotency table across scopes without the derived prefix.

### 3.96 A scope column that admits null

**Delivery-owner:** `Phase-67`

**Case-family:** `security`

**Cells:** `type-foreclosed`×`gadt-decode` · `decode-foreclosed`×`rendered-artifact-oracle` · `runtime-checked`×`live-effect`

A table whose scope column is nullable admits a row belonging to nobody, and a row belonging to nobody matches
a row-level policy written as an equality against a caller's scope in whichever direction the database's
three-valued logic happens to take it. Such rows arrive from backfills, from imports, and from an earlier
schema that predates the scope; they are rarely written deliberately and are almost never noticed. amoebius
does not author the schema. The scope-bearing row type is a Haskell type in which the scope is an ordinary
required field, and the schema, its `NOT NULL` constraint, its composite foreign key back to the scope table,
and its row-level policy are all emitted from that one declaration. A nullable scope column is not forbidden by
review; it is not derivable from any row type that has a scope. **Owner:**
[`tenancy_doctrine.md` §5.1](../engineering/tenancy_doctrine.md#51-the-transaction-is-tenant-qualified-exhaustive-and-may-become-empty)
(the tenant-qualified transaction the schema must support). **Technique:**
[§4.9](./illegal_state_techniques.md#49-the-closed-transaction-vocabulary--only-valid-transactions-have-a-constructor)
(schema and policy emitted from the transaction declaration) +
[§4.5](./illegal_state_techniques.md#45-content-address-totality--names-are-total-functions-of-content)
(the emission is total, so every scope-bearing type yields its constraint).

**Layer:** `type-foreclosed` in the row type — a scope field of optional type is a different type with no
transactions defined over it; `runtime-checked` residue — that the deployed schema is the emitted one and that
no out-of-band migration has relaxed it. The emitted DDL the oracle compares is `decode-foreclosed`.
**Validation-locus:** `gadt-decode` (a row type whose scope column is optional is a different
type, and no transaction is defined over it) +
`rendered-artifact-oracle` (the emitted DDL carries `NOT NULL` and the composite key for
every scope-bearing table, compared against the separately reviewed Haskell
`schemaConstraintExpectation`, implemented without calling the DDL emitter) + `live-effect` residue (an
insert of a scope-less row is rejected by the live database, and the deployed schema matches what was emitted).

**Independent oracle and mutants.** A Haskell live-catalog observer reads typed catalog observations and
compares them with `schemaConstraintExpectation`, enumerating every table carrying a scope column and requiring
the constraint, composite foreign key, and enabled policy on each. Serialized catalog observations exist only
beneath `.build/test-corpora/**`. A live probe attempts a scope-less insert under the application role. Haskell mutants make the scope
field optional in the row type, emit the column without the constraint, and disable the policy for the
application role.

### 3.97 A scope key whose rendering is not injective

**Delivery-owner:** `Phase-37`

**Case-family:** `security`

**Cells:** `type-foreclosed`×`gadt-decode` · `decode-foreclosed`×`gadt-decode` · `decode-foreclosed`×`rendered-artifact-oracle` · `runtime-checked`×`live-effect`

An object prefix, a topic name, or a cache key built by concatenating a scope and a resource name collides
whenever the separator can occur inside either part. Two distinct scopes then address one location, and the
first writer's bytes are served to the second scope. Concatenation is how these keys are almost always built,
the collision needs no privilege to trigger, and it survives every test whose fixtures happen to use names
without the separator. amoebius renders a key through one total function whose encoding is injective by
construction — each component length-prefixed rather than delimited — and proves it by requiring that parsing
recovers exactly the components that were rendered. No other code path constructs a key for these namespaces,
so there is nowhere for a second, weaker rendering to live. **Owner:**
[`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) (names as total functions of
content) +
[`tenancy_doctrine.md` §7](../engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit)
(the isolation the derived namespaces defend). **Technique:**
[§4.5](./illegal_state_techniques.md#45-content-address-totality--names-are-total-functions-of-content)
(injective content-derived naming) +
[§4.9](./illegal_state_techniques.md#49-the-closed-transaction-vocabulary--only-valid-transactions-have-a-constructor)
(one emitter owns every keyspace).

**Layer:** `type-foreclosed` for a key assembled anywhere but the renderer, since the key type exports no other
constructor; `decode-foreclosed` for a stored key that does not parse back to its components;
`runtime-checked` residue — that no pre-existing key in a live store predates the renderer.
**Validation-locus:** `gadt-decode` (a key cannot be constructed by concatenation, and the round-trip property
holds for every generated component pair) + `rendered-artifact-oracle` (the emitted prefixes, topic names, and
policies all use the one rendering, compared against the separately reviewed Haskell
`scopedKeyExpectation`, implemented independently of the production renderer) + `live-effect`
residue (that no pre-existing key in a live store predates the renderer).

**Independent oracle and mutants.** The Haskell `scopedKeyExpectation` covers adversarial component pairs —
names containing the separator, empty components, and shared prefixes — and requires that rendering is
injective and parsing is its inverse. A separate Haskell scanner checks the emitted typed manifest projection
for any key-shaped literal built by concatenation. Any serialized manifests or observations are materialized
only beneath `.build/test-corpora/**`. Haskell mutants replace the length-prefixed encoding with a delimiter, drop the round-trip property, and
add a second renderer for one namespace.

---

## Related Documents
- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the catalog index, the honesty limit ([§2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)),
  and the covering obligation ([§6.2](./illegal_state_techniques.md#62-the-covering-obligation--exhaustive-relative-to-a-declared-taxonomy)) this slice is one part of.
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — the nine typing techniques, the coverage
  matrix, the foreclosure layers, and the validation-locus axis every entry above cites.
- [`illegal_state_security.md`](./illegal_state_security.md) — the adjacent slice owning ingress, secrets,
  RBAC, and the authority-bearing UI boundary; this slice takes over once a request is inside them.
- [`tenancy_doctrine.md`](../engineering/tenancy_doctrine.md) — owner of the tenant model, the derived RBAC
  transaction, and the honest limit on what an offline partition can prove.
- [`browser_offline_runtime_doctrine.md`](../engineering/browser_offline_runtime_doctrine.md) — owner of
  offline identity, the queued-intent protocol, and authoritative replay.
- [`low_code_ui_runtime_doctrine.md`](../engineering/low_code_ui_runtime_doctrine.md) — owner of routes,
  identity, and the edge that terminates authentication ahead of a handler.
- [`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) — owner of the totality
  discipline the injective key rendering reuses.
- [`documentation_standards.md` §16](../documentation_standards.md#16-the-illegal-state-catalogue-is-a-covering-not-a-list) — the covering obligation these entries are measured against.
