# amoebius

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: documents/engineering/daemon_topology_doctrine.md
**Generated sections**: none

> **Purpose**: Entry point for amoebius — an everything-orchestrator whose Dhall DSL makes illegal cluster
> state unrepresentable.

amoebius is a single Haskell binary that runs as a **CLI**, a **sudo-capable host daemon**, and an
**in-cluster singleton service**. It manages Kubernetes cluster lifecycle and interprets a `.dhall` DSL
into opinionated deployments whose coherence is enforced by the type system at author and decode time — a
spec that mis-binds a PVC, opens a backdoor ingress, or mis-substrates a workload does not type-check. That
is a design-time guarantee about the spec, not a runtime claim that a live cluster enforces it; the boundary
is stated precisely in the [verification doctrine](./documents/engineering/testing_doctrine.md) and its
[honesty rule](./documents/documentation_standards.md#6-honesty-the-proventestedassumed-discipline).
Its constituent capabilities are unified libraries, not
separate products: **prodbox** (root control-plane behaviour), **infernix** + **jitML** (ML extensions,
each shipping a demo web app that is amoebius's application-logic demonstrator), and **hostbootstrap**
(bootstrap + DSL core).

Every amoebius-managed Kubernetes cluster — root, child, self-managed, or provider-managed — has
**ephemeral infrastructure** and independently retained durable backing. Ephemeral means replaceable, not
TTL-bound or automatically torn down: a rebuilt cluster reconciles toward the persistent root `InForceSpec`
and reattaches retained backing
([cluster lifecycle](./documents/engineering/cluster_lifecycle_doctrine.md),
[storage lifecycle](./documents/engineering/storage_lifecycle_doctrine.md)).

## Where to start

- **The plan:** [`DEVELOPMENT_PLAN/README.md`](./DEVELOPMENT_PLAN/README.md) — the single, authoritative,
  numerically-ordered phased plan that delivers the vision. Phase 0 is the complete documentation suite.
- **The doctrine:** [`documents/README.md`](./documents/README.md) — the top-level index of all doctrine:
  the engineering family (the DSL, platform services, storage, secrets, runtime, verification) and the
  illegal-state catalog family.
- **How docs work:** [`documents/documentation_standards.md`](./documents/documentation_standards.md).
- **How amoebius is tested:** [`documents/engineering/testing_doctrine.md`](./documents/engineering/testing_doctrine.md)
  — a test *is* an amoebius deployment: a spec composed with a chaos schedule, a typed expectation surface,
  and a mandatory teardown. Validation runs in four named registers (1 pure/golden · 2 boundary-with-fakes ·
  2.5 deterministic-simulation · 3 live), and every gate emits a committed proven/tested/assumed ledger that
  states which layer it reached and marks the rest UNVERIFIED.

## Toolchain

GHC 9.12.4, Cabal 3.16.1.0 (one shared pin across all packages).

## Working agreement

LLMs/assistants must not run `git add`, `git commit`, or `git push`; staging and committing are reserved
for the human (see [`CLAUDE.md`](./CLAUDE.md)).
