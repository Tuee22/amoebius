# Illegal States — Readiness, Promotion & Monitoring

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/platform_services_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_ml_asset.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: The themed slice of the illegal-state catalog covering the lifecycle band — the readiness
> race (condition, never duration), unverified environment promotion, and unmonitored workflows/extensions —
> with the honest limit that a type-check proves the *spec composes*, not that the *running cluster enforces it*.

---

## 1. Scope

This document is a **themed slice** of the illegal-state catalog: the lifecycle illegal states — the
duration-gated / hand-ordered bring-up race ([§3.41](#341-a-duration-gated--hand-ordered-bring-up-sequence-a-readiness-race)),
the unverified environment promotion ([§3.26](#326-an-unverified-environment-promotion-promote--prod-without-the-required-evidence)),
and the unmonitored workflow or extension ([§3.43](#343-an-unmonitored-workflow-or-extension-or-an-unauthenticated-monitoring-surface)).
It owns nothing of the catalog's framing.

- The **catalog index** and the **load-bearing honesty limit** (a type-check proves the spec composes, not
  that the cluster enforces it) are owned by
  [`illegal_state_catalog.md`](./illegal_state_catalog.md) — referenced, not restated.
- The **seven typing techniques**, the **coverage matrix**, the **three foreclosure layers**, and the new
  **validation-locus axis** (`Gate-1-editor` / `Gate-2-decoder` / `rendered-output-golden` / `live-effect`,
  orthogonal to the foreclosure layer) are owned by
  [`illegal_state_techniques.md`](./illegal_state_techniques.md) — referenced, not restated.
- The *normative rule* behind each entry lives in that entry's owning doctrine (readiness/ordering, release
  lifecycle, monitoring, …). This doc names the owner and never restates its content.

Everything below is **design intent** for the type discipline, per the honesty discipline the catalog states
([`illegal_state_techniques.md` §6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)):
a green type-check proves the *specification* composes into something internally coherent — the spec value is
well-formed, every reference resolves, every required field is present — and proves **nothing** about whether the
*running cluster* renders, admits, schedules, and reconciles it. Read every "unrepresentable" and
"uninhabitable" below as design intent for the type discipline, never as a tested amoebius behaviour; the
runtime-enforcement proof is deferred on purpose to
[`chaos_failover_doctrine.md`](../engineering/chaos_failover_doctrine.md) and the testing tier.

Each entry keeps its **original catalog number and heading** verbatim — inbound links depend on the slug — and
adds one new **Validation-locus** line naming where the illegal state is caught along the validation-locus axis.

---

## 2. The readiness, promotion & monitoring illegal states

### 3.41 A duration-gated / hand-ordered bring-up sequence (a readiness race)

Raw tooling makes the bring-up race the default: a chart assumes its database is up, an initContainer polls a
port in a `sleep`-loop, a bootstrap script runs `sleep 30 && kubectl apply` and hopes the apiserver answered —
each substituting a **duration** for a **condition**, so it passes on a fast host and flakes on a slow one, then
strands a half-applied cluster. amoebius forecloses the *shape* that races on two axes. **(a) The gate is a
condition, never a duration.** The sanctioned sequencing gate carries a typed `Readiness` (`Reachable | Serving |
Condition | Unsealed | Committed`) with **no `AfterDuration` arm**, so "wait N then assume ready" has no
constructor — the same no-illegal-arm idiom as `Rke2Servers`/`StorageBacking`/`Growable`
([§3.24](./illegal_state_topology.md#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain), [§3.18](./illegal_state_storage.md#318-unbounded-storage-anywhere),
[§3.21](./illegal_state_storage.md#321-capacity-growth-without-an-amoebius-owned-scaling-policy)). **(b) The order is a derived, acyclic
readiness DAG.** Bring-up edges are *derived* from the declared dependency graph — a dependent's start-handle
exists only once its dependency's `Ready` edge does — never hand-sequenced per installer, the same
derive-don't-author discipline as NetworkPolicy ([§3.6](./illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other))
and tolerations ([§3.22](./illegal_state_capacity.md#322-a-hand-authored-un-derived-toleration)); a total `mkBringUpOrder` fold rejects a
cycle or an undeclared dependency at decode. The honest limit (the [§2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)
limit, applied to readiness): the type **cannot** prove a port is responsive — that the observed condition
becomes true, in bounded time, is `runtime-checked`, owned by the reconciler and the chaos doctrine. The special
**initial-bootstrap** case (before the in-cluster SSA/Pulsar machinery exists) is closed by the host tier's local
observed primitives — the three-valued `discover` (Present/Absent/Unreachable, `Unreachable → refuse`) and the
`RuntimeWitness` file/socket facts — never a timer. **Owner:**
[`readiness_ordering_doctrine.md`](../engineering/readiness_ordering_doctrine.md) (the readiness-edge discipline) reading the
bring-up edges of [`platform_services_doctrine.md` §11](../engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
and enacted by the reconciler of [`cluster_lifecycle_doctrine.md` §9](../engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine).
**Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (closed
`Readiness` union — no duration arm) + [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
(a start-handle exists only once its dependency's readiness edge does) + [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally)
(the dependency graph is the single owner of order) + [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)-shape
total fold (`mkBringUpOrder` acyclic/complete). **Layer:** `type-foreclosed` for the no-duration-arm gate shape
and the derived-edge handle; `decode-foreclosed` for the acyclic/complete DAG fold; `runtime-checked` residue —
that the observed condition actually resolves (owned by [`readiness_ordering_doctrine.md` §6](../engineering/readiness_ordering_doctrine.md#6-the-runtime-enactor-the-reconciler-observes-never-sleeps),
[`cluster_lifecycle_doctrine.md` §9](../engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine),
and [`chaos_failover_doctrine.md`](../engineering/chaos_failover_doctrine.md)). *(Honesty: the `type-foreclosed` claim scopes
to the sanctioned `Readiness`-typed surface, not the whole `IO` monad — a raw `threadDelay` is caught one layer
out by the [`daemon_topology_doctrine.md` §6](../engineering/daemon_topology_doctrine.md#6-the-shared-daemon-spine) ban, a
`runtime-checked` discipline.)*

**Validation-locus:** `Gate-1-editor` (the closed `Readiness` union with no `AfterDuration` arm — "wait N then
assume ready" fails `dhall type` at authoring time) + `Gate-2-decoder` (a start-handle exists only once its
dependency's `Ready` edge does, and the total `mkBringUpOrder` fold returns `Left` on a cycle or an undeclared
dependency) + `live-effect` (that the observed condition actually resolves in bounded time — the port becomes
responsive — owned by the reconciler and the chaos doctrine). Per the validation-locus axis of
[`illegal_state_techniques.md`](./illegal_state_techniques.md), orthogonal to the foreclosure layer above.

### 3.26 An unverified environment promotion (promote → prod without the required evidence)

Raw delivery permits pointing prod at any build — tested, untested, or actively red. amoebius makes
`Environment = < Dev | Staging | Prod >` advance through a typed `PromotionGate`: advancing an environment's
ETag-CAS pointer to a `Release` **requires** that the `Release`'s test-topology ledger
([`testing_doctrine.md`](../engineering/testing_doctrine.md) proven/tested/assumed) meet that environment's required evidence
strength (Prod requires the chaos layer). The advance constructor demands an **evidence witness**, so
"promote-unverified → prod" has no inhabitant — the same constructor-gating shape as the `.ready`-gated
`ArtifactRef` ([§3.25](./illegal_state_ml_asset.md#325-an-ml-asset-named-by-arbitrary-url-or-an-unready--unlanded-model)), applied to release evidence rather than model bytes. **Owner:**
[`release_lifecycle_doctrine.md` §4](../engineering/release_lifecycle_doctrine.md#4-promotiongate-promote-unverifiedprod-is-unrepresentable) (the `PromotionGate` precondition + the
immutable release ledger). **Technique:** [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (a promotion handle exists only once its evidence edge does).
**Layer:** type-foreclosed uninhabitable; runtime-checked residue — that the tests actually ran and that prod actually converged
on the promoted `Release`, owned by [`chaos_failover_doctrine.md`](../engineering/chaos_failover_doctrine.md) and the testing
doctrine.

**Validation-locus:** `Gate-2-decoder` (the `PromotionGate` advance constructor demands an evidence witness; the
total decoder returns `Left` when the `Release`'s test-topology ledger fails to meet the target environment's
required evidence strength — a value-level ledger fold, not a Dhall type index) + `live-effect` (that the tests
actually ran and that prod actually converged on the promoted `Release`, owned by the chaos and testing
doctrines). Per the validation-locus axis of [`illegal_state_techniques.md`](./illegal_state_techniques.md),
orthogonal to the foreclosure layer above.

### 3.43 An unmonitored workflow or extension (or an unauthenticated monitoring surface)

Raw k8s treats monitoring as an optional add-on: a Deployment can run with no scrape target, no alert rule, and
no dashboard, and a metrics or debug endpoint can be published to the wild with no authentication — so a
workflow compiles, deploys, and then goes dark, and a monitoring surface can leak. amoebius makes monitoring a
**mandatory, non-vacuous property of the workflow and extension types**: a `Workflow` requires a
`WorkflowMonitor`, every `RouteEntry` requires a `Liveness`, and an `ExtensionSpec` requires a `NonEmpty`
`extMonitoring` (jitML → TensorBoard) — each an absent-arm required field, so an unmonitored workflow or
extension has no inhabitant. Every renderable surface carries a mandatory `AccessScope` with **no** `Public`
arm — the same `ExposeToWild`-only-Keycloak discipline as [§3.7](./illegal_state_security.md#37-accidental-insecure--backdoor-ingress) —
so an unauthenticated monitoring surface is uninhabitable (`AccessScope` is `AdminGlobal`, the single admin
identity, or `UserScoped`, a Keycloak-backed app-logic filter). Coverage of the derived rules/panels across a
workflow's topics, non-vacuousness of the SLO bounds, and feasibility (freshness ≥ scrape interval, Σ rule cost
≤ the `Observability` workload's `Capacity`) are total decode-time folds. **Owner:**
[`monitoring_doctrine.md`](../engineering/monitoring_doctrine.md) (the obligation types, derivation, access model, and
parent-monitoring posture) + [`pulsar_client_doctrine.md` §6](../engineering/pulsar_client_doctrine.md#6-the-declarative-topology-algebra) (the
`validateTopology` fold that carries it). **Technique:** [§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction) (the mandatory
`monitor` / `liveness` / `extMonitoring` fields + the absent `Off`/`Public` arms — no forever-unmonitored arm) +
[§4.7](./illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection) (the coverage fold over the
workflow/topic collection) + [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
(the recording-rule feasibility Σ). **Layer:** `type-foreclosed` for the mandatory-field presence, the absent
`Off`/`Public` arms, and the `NonEmpty` lists; `decode-foreclosed` for coverage, non-vacuousness, feasibility,
and the `routes[].workflow`-vs-`name` reconciliation; `runtime-checked` residue — that the SLO is actually met,
the alert fires, the named `/metrics` series exists, and a `UserScoped` filter actually excludes another user's
data — owned by [`chaos_failover_doctrine.md`](../engineering/chaos_failover_doctrine.md) and the review tier.

**Validation-locus:** `Gate-1-editor` (the mandatory `monitor` / `liveness` / `extMonitoring` fields, the
`NonEmpty` `extMonitoring` list, and the absent `Off`/`Public` arms fail `dhall type` at authoring time) +
`Gate-2-decoder` (the coverage, non-vacuousness, and feasibility Σ folds and the `routes[].workflow`-vs-`name`
reconciliation return `Left` at decode) + `rendered-output-golden` (that the emitted monitoring surface renders
behind the Keycloak-owned edge with no `Public` listener — the no-backdoor-ingress analog of
[§3.7](./illegal_state_security.md#37-accidental-insecure--backdoor-ingress), caught by a golden test on the rendered manifest rather than a
cluster) + `live-effect` (that the SLO is actually met, the alert fires, the named `/metrics` series exists, and
a `UserScoped` filter actually excludes another user's data). Per the validation-locus axis of
[`illegal_state_techniques.md`](./illegal_state_techniques.md), orthogonal to the foreclosure layer above.

---

## Cross-references

- [The Illegal-State Catalog](./illegal_state_catalog.md) — the catalog index and the load-bearing honesty
  limit this slice inherits (§1 framing, §2 the honesty limit, §6 the three foreclosure layers)
- [Illegal States — Typing Techniques](./illegal_state_techniques.md) — the seven typing techniques, the
  coverage matrix, the foreclosure layers, and the **validation-locus axis** each entry above cites
- [DSL Doctrine](../engineering/dsl_doctrine.md) — the contract this catalog enumerates (a valid `InForceSpec` cannot
  represent illegal state)
- [Readiness Ordering Doctrine](../engineering/readiness_ordering_doctrine.md) — [§3.41](#341-a-duration-gated--hand-ordered-bring-up-sequence-a-readiness-race)
  the readiness-edge discipline (readiness is a condition/edge, not a wait)
- [Platform Services Doctrine](../engineering/platform_services_doctrine.md) — the bring-up/dependency ordering
  ([§11](../engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)) and the derived-rules / wild-ingress edge
- [Cluster Lifecycle Doctrine](../engineering/cluster_lifecycle_doctrine.md) — the reconciler that enacts bring-up
  ([§9](../engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine))
- [Daemon Topology Doctrine](../engineering/daemon_topology_doctrine.md) — the shared daemon spine and the `threadDelay` ban
  ([§6](../engineering/daemon_topology_doctrine.md#6-the-shared-daemon-spine))
- [Release Lifecycle Doctrine](../engineering/release_lifecycle_doctrine.md) — [§3.26](#326-an-unverified-environment-promotion-promote--prod-without-the-required-evidence)
  the `PromotionGate` precondition + the immutable release ledger
- [Testing Doctrine](../engineering/testing_doctrine.md) — the proven/tested/assumed test-topology ledger the `PromotionGate`
  evidence witness reads
- [Monitoring Doctrine](../engineering/monitoring_doctrine.md) — [§3.43](#343-an-unmonitored-workflow-or-extension-or-an-unauthenticated-monitoring-surface)
  the obligation types, derivation, access model (`AccessScope`), and parent-monitoring posture
- [Pulsar Client Doctrine](../engineering/pulsar_client_doctrine.md) — the `validateTopology` fold
  ([§6](../engineering/pulsar_client_doctrine.md#6-the-declarative-topology-algebra)) that carries the monitoring coverage check
- [Content Addressing Doctrine](../engineering/content_addressing_doctrine.md) — the `.ready`-gated `ArtifactRef` whose
  constructor-gating shape [§3.26](#326-an-unverified-environment-promotion-promote--prod-without-the-required-evidence) mirrors
- [Chaos / Failover Doctrine](../engineering/chaos_failover_doctrine.md) — the runtime-enforcement proof (the honest limit)
  every `runtime-checked` / `live-effect` residue above defers to
