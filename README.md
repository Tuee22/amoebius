# amoebius

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: documents/engineering/daemon_topology_doctrine.md
**Generated sections**: none

> **Purpose**: Entry point for amoebius — an everything-orchestrator and bounded low-code UI runtime whose
> Dhall DSLs make illegal deployment and application states unrepresentable where their modeled boundaries
> permit that claim.

amoebius has one Haskell **runtime binary** with closed responsibilities for its bootstrap/host command mode,
**sudo-capable host daemon**, **in-cluster control-plane singleton**, **capacity scheduler**, and **unelected
workers**. A separate thin Python `pb` program is the pre-binary midwife and post-handoff admin-REST client; it
is an operator frontend, not another runtime role or control plane. The worker set
includes the generic UI server and owner-scoped UI projector as well as linked workflow and ML roles; an
application does not introduce another executable or privileged server.

The binary manages Kubernetes cluster lifecycle and interprets checked `.dhall` values into opinionated
deployments and bounded low-code applications. A low-code app is finite `UiSource` data compiled into matching
client and server plans: one generic PureScript interpreter renders it, while the UI-server responsibility
mediates every effect through current authorization, trusted tenant/subject scope, and typed capabilities.
A spec that mis-binds a PVC, opens a backdoor ingress, exposes a raw browser effect, omits authorization, or
crosses a checked tenant/owner boundary is rejected at its declared validation or enforcement layer. That is a
design claim about the modeled surface, not a claim that a live provider or implementation is defect-free; the boundary is
stated precisely in the [verification doctrine](./documents/engineering/testing_doctrine.md), the
[low-code UI doctrine](./documents/engineering/low_code_ui_runtime_doctrine.md), and the
[honesty rule](./documents/documentation_standards.md#6-honesty-the-proventestedassumed-discipline).

Its constituent capabilities are unified libraries, not separate products: **prodbox** supplies root
control-plane behaviour, **infernix** and **jitML** supply trusted ML/workflow adapters, and **hostbootstrap**
supplies the bootstrap and DSL core. The sibling demo SPAs are UX evidence and migration fixtures; they are not
amoebius application code or authority surfaces.

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
  and a mandatory teardown. Validation runs in three phase-gate registers (1 pure/golden · 2
  boundary-with-fakes · 3 live), plus the Register-2.5 deterministic-simulation activity, which is never
  itself a phase gate; every gate emits a committed proven/tested/assumed ledger that
  states which layer it reached and marks the rest UNVERIFIED.
- **How low-code applications work:**
  [`documents/engineering/low_code_ui_runtime_doctrine.md`](./documents/engineering/low_code_ui_runtime_doctrine.md)
  — bounded Dhall UI programs, one checked value projected into client/server plans, typed effects,
  single-/multi-tenant isolation, workflow/model lifting, rollout, and the honest HA boundary.

## Toolchain

GHC 9.12.4, Cabal 3.16.1.0 (one shared pin across all packages). Python `pb` is the pre-binary launcher and
post-handoff operator client.

## Working agreement

LLMs/assistants must not run `git add`, `git commit`, or `git push`; staging and committing are reserved
for the human (see [`CLAUDE.md`](./CLAUDE.md)).
