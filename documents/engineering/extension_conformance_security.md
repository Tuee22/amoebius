# Extension Conformance — The Security Laws

> **Purpose**: The slice of the extension family owning **S1–S6** — the laws under which an insecure state
> stops being representable rather than being checked for: authentication as a type index, the skolemised
> request scope, refusal as the default, indistinguishable refusal, derived namespaces, and honest revocation
> bounds. Each law names the hazard, the guideline, the discharge, and the seed observation that motivated it.
> **Read this if**: a boundary between tenants, subjects, or authenticated and anonymous callers has to be
> shown impossible to cross by construction.

This slice owns the S family. It is a set of *instances*: every S-law is L4 or C6 applied at the identity seam,
and the algebra it rests on belongs to
[`extension_conformance_laws.md`](./extension_conformance_laws.md). The tenant model belongs to
[`tenancy_doctrine.md`](./tenancy_doctrine.md), and the states these laws foreclose are catalogued in
[`../illegal_state/illegal_state_tenancy.md`](../illegal_state/illegal_state_tenancy.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_08_scope_index.md, DEVELOPMENT_PLAN/phase_23_extension_security_laws.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md, DEVELOPMENT_PLAN/system_components.md, documents/README.md, documents/engineering/README.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/reading_order.md
**Generated sections**: none

</details>

## Contents
- [1. Scope](#1-scope)
- [2. Why a security family exists at all](#2-why-a-security-family-exists-at-all)
- [3. The skolem scope](#3-the-skolem-scope)
- [4. S1–S6](#4-s1s6)
- [5. What the seed observation is worth](#5-what-the-seed-observation-is-worth)
- [Related Documents](#related-documents)

---

## 1. Scope

This document is a **family slice**. It owns S1–S6 and the skolem-scope mechanism they share. It does not own
the tenant model, the gateway and identity edge, the offline runtime, or the relational data plane; each S-law
names the doctrine that does. [Phase 8](../../DEVELOPMENT_PLAN/phase_08_scope_index.md) supplies the lexical
pure mechanism; the laws and live boundaries retain their own delivery owners, and status lives only in the
[tracker](../../DEVELOPMENT_PLAN/README.md).

The bounded pure implementation is `Amoebius.Extension.Laws.Security`. It distinguishes claimed and attested
identities, eliminates an attested identity through Phase 8's fresh request scope, requires that scope at the
operation and derived-key boundaries, represents only revocation-edge or positive-staleness-bound authority
layers, and evaluates S1–S6 over explicit observations. Its evidence covers one valid and one tampered fixture
envelope, fifteen operations in a two-tenant/two-subject store, five foreign/absent refusal pairs, five
namespace transpositions, two authority layers, 42 authored verdicts, four compiler negatives, and six exact
mutants. This is bounded Register-1 evidence: the fixture SHA-256 check is not production cryptographic
verification, equal modeled steps are not wall-clock timing, the layer pair is not a runtime inventory, and no
compositional S-law or persisted-value re-entry path is thereby discharged.

---

## 2. Why a security family exists at all

L4 (scope propagation) and C6 (scope conjunction) say that a value cannot reach a wider scope than its inputs.
S2, S3 and S5 are that pair sharpened at a particular seam, and each says so below.

**Three of the six are not.** S1 introduces a distinction between a claimed identity and an attested one, and
no L-law indexes that difference. S4 asks that two refusals be indistinguishable to an observer, including in
the time they take — a property of what can be measured from outside, which no law about index propagation
reaches. S6 forecloses nothing at all; it requires that a staleness bound be declared. Calling these instances
of L4 would be a convenient fiction.

That has a structural consequence, stated here because it is easy to miss. The closure argument of
[`extension_conformance_doctrine.md` §7](./extension_conformance_doctrine.md#7-link-time-union-closure) runs
over the L and C families. **It does not carry this family across a seam.** Two extensions can each satisfy S4
and L1–L5, and the composite can leak a distinguishing timing or error channel that neither part had, with no
C-law violated. Nothing in this corpus closes that; a compositional S-law is owed work.

The family also exists for a reason about people. A security reviewer must be able to read the guarantee
without first reading the algebra: "the composite's sink set admits no path from a narrower source" is correct
and unreadable at the moment it matters, where "an unauthenticated caller cannot name a tenant" is checkable by
someone who has never opened this corpus. And these are the laws where a `runtime-checked` residue is least
acceptable — elsewhere a residue is a cost to record honestly, here it is a hole — so the family's own slice
forces every residue to be written beside the law that leaves it.

---

## 3. The skolem scope

Five of the six laws rest on one mechanism, so it is stated once here rather than five times below. The
technique is owned by
[`../illegal_state/illegal_state_techniques.md` §4.8](../illegal_state/illegal_state_techniques.md#48-the-skolem-scope--a-runtime-tenant-becomes-a-compile-time-index).

A phantom tenant tag forecloses cross-tenant reference only while the tenants are known when the program is
compiled. A deployed system learns its tenant from a request, and a value that arrives at run time cannot index
a type — which is why the tag technique demonstrates beautifully on a two-tenant fixture and does nothing at
all for a real server, where every scope check degrades back into a comparison somebody has to remember to
write.

The fix is to stop *naming* the tenant and start **skolemising** it. A verified identity is eliminated by a
single rank-2 combinator whose continuation is polymorphic in a fresh type variable, so that variable is
unforgeable, unique to the request, and confined to it. Every scoped value the request derives — a resolved
handle, a statement, a replay key, a rendered namespace — carries that variable, and two values minted under
different identities are specified to have types that do not unify, so a cross-scope use is not a check that
fails — it is an expression the compiler rejects. The fixture establishing that is owed by the phase that
builds the scope index; none exists.

Two properties are specified to make this work rather than merely look elegant. The context type exports no
constructor, so authentication is the sole introduction rule and no test, migration, or admin path has a second
one. And the escape argument that makes the region pattern safe in its original setting carries: a scoped value
cannot outlive the continuation that minted it, so it cannot be stashed and reused under another identity.
Phase 8 exercises those claims with legal/illegal compiler pairs for constructor forgery, retagging, and
request-index escape, plus a constructor-closure scan. The bounded security-law kernel reuses that eliminator;
its adjacent compiler twins additionally reject claimed-as-attested use, an explicit promotion, a missing
scope argument, and a key minted by another request.

**The residue this mechanism leaves, and it is the largest in this document.** The region argument protects a
lexically nested, in-memory scope. Every law below involves a value crossing an asynchronous boundary where the
type index is erased and must be reconstructed: a replay key rendered into a queue and read back (S5), an
authority decision cached and read by another process (S6), a row set arriving from Postgres as bytes and then
"indexed by the scope that produced it" (P5). Something has to re-tag those values with the current request's
variable, and no total, safe function can — the only implementations are an unchecked coercion or a runtime
comparison, which is the scope check this section opened by saying the tag technique degrades into.

That re-entry combinator is unavoidable and it is the mechanism's one back door. It is named here rather than
left implicit, and the obligation it carries is that it appear exactly once, be audited as carefully as the
authentication path, and be the only unchecked coercion in the scoped surface. Phase 8 deliberately contains
no persisted-value re-entry combinator; no later gate yet establishes the required single audited back door.

Two further limits. Skolemisation is a **static** distinctness property, not a runtime identity: type variables
are erased, so nothing at run time distinguishes two scopes. And two requests from the *same* identity also get
non-unifying types, which forecloses legitimate reuse across requests for one tenant — a real cost, paid to
keep the introduction rule single.

---

## 4. S1–S6

### S1 Authentication is an index, not a check

**Hazard.** When an authenticated session and a locally reconstructed one share a type, every downstream
authorization decision rests on a structure the caller can edit, and no signature in the system records the
difference.

**Guideline.** Attestation is part of the type: an identity is claimed or attested, verification is the only
way to obtain the second, and there is no promotion function. Offline and degraded paths produce claimed
identities and can only reach operations typed for them.

**Discharge.** The bounded fixture applies an attested-only consumer to a claimed identity and attempts to
export a promotion function; both fail at the claimed/attested type mismatch. Its tampered-envelope probe
requires refusal rather than an identity, and the corresponding executable mutant reddens only S1. Foreclosed state:
[§3.93](../illegal_state/illegal_state_tenancy.md#393-a-locally-reconstructed-session-bearing-the-type-of-an-attested-one).

**Seed observation.** In `mattandjames`, the offline bootstrap path reconstructs the server's own bootstrap
value from browser-writable local storage. The reconstructed value has the type the server's value has, so
every consumer downstream of it treats browser-held bytes as server-attested facts.

### S2 The scope is skolemised, not passed

**Hazard.** A scope carried as an ordinary value can be forwarded, defaulted, stored, or swapped with another
scope of the same type, and each of those is a silent cross-tenant read.

**Guideline.** Obtain the scope from the request eliminator of [§3](#3-the-skolem-scope), thread the resulting context, and never
convert it to a plain value. If you want to pass "the tenant id" to a helper, pass the context.

**Discharge.** Phase 8's compile-fail fixtures construct a context directly, retag one scope as another, and
let a scoped handle escape its continuation. The bounded S2 fixture rejects a key from another rank-2 request,
and the source oracle requires a `RequestScope scope` at scoped operations rather than two exchangeable plain
identifiers. Foreclosed states:
[§3.91](../illegal_state/illegal_state_tenancy.md#391-an-unauthenticated-route-whose-scope-comes-from-the-request),
[§3.94](../illegal_state/illegal_state_tenancy.md#394-two-same-typed-scope-identifiers-exchangeable-at-a-call-site).

**Seed observation.** In `mattandjames`, one tenant identifier is seeded as a constant and used throughout, so
the tenancy scoping in the code has never been exercised against a second tenant by reality. Separately, a
family of observability routes is mounted outside the authentication middleware and takes its tenant from the
URL.

### S3 Refusal is the default, not the fallback

**Hazard.** An optional scope filter whose absent value means "every scope" turns a forgotten argument into a
full disclosure, and the widened result is well formed, so nothing downstream can tell.

**Guideline.** A missing scope is a missing constructor argument. Never write a predicate that passes when the
scope is null; never give a scope parameter a default. If an operation genuinely spans scopes, it is a
different operation with its own name, its own authority requirement, and its own audit obligation.

**Discharge.** The bounded operation kernel exposes no arm that omits its scope argument, so its widened call
has no inhabitant; the adjacent negative fails at `RequestScope`, and a finite source scan rejects optional
scope shapes. This does not yet parse statements from a production data plane. Foreclosed state:
[§3.92](../illegal_state/illegal_state_tenancy.md#392-a-scope-filter-whose-absent-value-means-every-scope).
P1–P3 are this law at the relational seam
([`extension_conformance_transactions.md`](./extension_conformance_transactions.md)).

**Seed observation.** In `mattandjames`, the null-means-all predicate idiom appears in the query layer — a
scope parameter compared as "is null, or equals" — so a caller that fails to supply the tenant receives every
tenant's rows rather than an error.

### S4 A refusal reveals nothing

**Hazard.** If "you may not see this" and "this does not exist" are distinguishable, an attacker enumerates the
resource space without ever reading a resource, which is the disclosure the isolation was protecting.

**Guideline.** Resolve and authorize in one step. A handler has no API that looks a resource up first and
decides second, so it never holds the knowledge that would let it answer differently. The refusal value for a
foreign resource and for an absent one is the same value, including its timing envelope where that is
achievable.

**Discharge.** A cross-scope probe over all five bounded operations requires byte-identical refusals for
foreign and absent resources and no mutation; the distinguishable-refusal mutant reddens only S4. **Residue:**
the current timing evidence is equality of three modeled steps under a declared zero-step difference. No
wall-clock measurement or production timing envelope is established. Foreclosed state:
[§3.80](../illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant).

**Seed observation.** In `mattandjames`, the resolve-then-authorize order appears in the handler layer, so a
foreign identifier and an unknown one take different paths and can be told apart from outside.

### S5 Every namespace is derived, and the derivation is injective

**Hazard.** Rows, object prefixes, topic names, cache keys, and replay keys are all keyspaces, and any of them
built by concatenation collides when a separator appears inside a component. One collision is one scope reading
another's bytes, and it needs no privilege to trigger.

**Guideline.** Never build a key by concatenation, and never accept a key from a caller. Ask the renderer for
the key; it takes the scope context and the domain identity and returns a scope-indexed key type. If you need a
new keyspace, add it to the renderer rather than beside it.

**Discharge.** Five authored component-transposition pairs—one per bounded keyspace—require length-framed
rendering to remain distinct and parsing to invert it; Python independently recomputes the emitted renderings.
A lookup typed at one request cannot consume a key minted by another. This finite corpus is not a proof of
injectivity over all text and no production emitted-output scanner is claimed. Foreclosed states:
[§3.95](../illegal_state/illegal_state_tenancy.md#395-a-replay-key-that-does-not-name-its-scope),
[§3.97](../illegal_state/illegal_state_tenancy.md#397-a-scope-key-whose-rendering-is-not-injective).

**Seed observation.** In `mattandjames`, the offline queue's idempotency keyspace is keyed by a client-chosen
identifier that does not name the scope, and derived cache keys are assembled by string concatenation rather
than by an injective encoding.

### S6 Revocation reaches every layer, or the layer states its bound

**Hazard.** A cache, an offline partition, or a long-lived socket that keeps serving an authority decision
after it was revoked is a privilege that outlives its grant. Pretending otherwise is worse than the gap,
because it removes the pressure to bound it.

**Guideline.** Every layer that caches an authority decision either subscribes to revocation or declares the
maximum staleness it can exhibit. A disconnected partition cannot learn about revocation, so it says so: its
type carries the bound, and operations that cannot tolerate the bound are unavailable to it.

**Discharge.** The bounded authority-layer value has only a revocation-edge constructor and a positive-bound
constructor. Its corpus observes the `membership-epoch` edge for a socket cache and models enforcement of a
300-unit bound for an offline partition; omission reddens only S6. **Residue:** this is not a discovered
runtime layer inventory, live revocation probe, clock, or reconnection implementation. A disconnected client
provably cannot observe revocation, so the live obligation remains to declare and enforce its bound.
Related state:
[§3.93](../illegal_state/illegal_state_tenancy.md#393-a-locally-reconstructed-session-bearing-the-type-of-an-attested-one),
and the honest limit in
[`tenancy_doctrine.md` §7.1](./tenancy_doctrine.md#71-offline-browser-partitions-preserve-scope-but-cannot-prove-revocation-while-disconnected).

**Seed observation.** In `mattandjames`, the Redis cache that lets the socket tier stay stateless is bounded by
expiry rather than by a revocation channel. Whether any authority decision reaches that cache was not
established by the survey, which is itself the point this law makes: the staleness bound is not stated anywhere
a reader could check.

---

## 5. What the seed observation is worth

Each law above carries an observation from `mattandjames`. The observations come from a **design survey of the
seed's shapes**, not from a security audit: each records that a state is *representable* in that codebase, and
none records that it has been exercised, exploited, or even reached. That is the claim the laws need and the
only one made. They do real work at that strength: a hazard a running, maintained, competently written
application can express is worth a law, where a hazard nobody has ever shipped is worth a paragraph.

They do not establish that these are the *right* six, or six at all. Five observations in one codebase cannot
show a law set complete or minimal, and S6's own observation concedes that whether any authority decision
reaches the cache was not established by the survey. The count is a human choice on the terms
[`extension_conformance_doctrine.md` §9](./extension_conformance_doctrine.md#9-what-conformance-does-not-prove)
states for the law set as a whole.

They are also evidence and not proof, on the terms
[`lift_and_compose_doctrine.md` §3](./lift_and_compose_doctrine.md#3-a-seed-is-a-reference-implementation)
fixes. That a state is representable in a seed makes it worth foreclosing; it does not establish that anything
has ever reached it. And it says nothing about
whether an arbitrary amoebius runtime forecloses it. The bounded pure gate described in [§1](#1-scope) has run
against its finite kernel and corpus; it does not promote that result to production cryptography, wall-clock
behavior, persistence, composition, or live provider enforcement. The seed is also under no obligation to
satisfy these laws — it predates them, and its own guarantees are its own to set.

---

## Related Documents
- [Extension Conformance Doctrine](./extension_conformance_doctrine.md) — the hub: the obligation surface, the generated gate, and the verdict seal
- [Extension Conformance Laws](./extension_conformance_laws.md) — L4 and C6, which S1–S6 instantiate at the identity seam
- [Extension Conformance Transactions](./extension_conformance_transactions.md) — P1–P6, which instantiate [S3](#s3-refusal-is-the-default-not-the-fallback) and [S5](#s5-every-namespace-is-derived-and-the-derivation-is-injective) at the relational seam
- [Tenancy Doctrine](./tenancy_doctrine.md) — owner of the tenant model, derived RBAC, and the offline honesty limit
- [Low-Code UI Runtime Doctrine](./low_code_ui_runtime_doctrine.md) — owner of routes, identity, and the edge that terminates authentication
- [Browser Offline Runtime Doctrine](./browser_offline_runtime_doctrine.md) — owner of offline identity and authoritative replay
- [UI Realtime Coordination Doctrine](./ui_realtime_coordination_doctrine.md) — the cached stateless socket tier [S6](#s6-revocation-reaches-every-layer-or-the-layer-states-its-bound) bounds
- [Vault / PKI Doctrine](./vault_pki_doctrine.md) — secrets by name, never by value
- [Illegal States — Tenancy, Scope & Authentication](../illegal_state/illegal_state_tenancy.md) — the catalogued states these laws foreclose
- [Illegal-State Techniques §4.8](../illegal_state/illegal_state_techniques.md#48-the-skolem-scope--a-runtime-tenant-becomes-a-compile-time-index) — the skolem-scope technique
- [Lift and Compose](./lift_and_compose_doctrine.md) — what a seed observation is worth
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
