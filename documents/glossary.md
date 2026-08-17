# Amoebius Glossary

> **Purpose**: Routing table from every amoebius term and acronym to the section that owns it.
> **Read this if**: a term met in a doctrine or plan document is unfamiliar and its owning document is unknown.

This document routes; it does not define. Each row links the section that owns a term and adds a gloss short
enough to confirm the reader has the right term — **where a gloss and its owning section disagree, the owning section is correct and the gloss is the defect**, per
[documentation_standards.md §12](./documentation_standards.md#12-naming-what-the-reader-does-not-know). A term
with no owning section is not listed here; its absence is evidence that the concept has no Single Source of
Truth yet. No term row is normative and no rule may cite one. The single exception is the acronym registry of
[§10](#10-governed-acronyms), which
[documentation_standards.md §12](./documentation_standards.md#12-naming-what-the-reader-does-not-know) names
as the set its first-use rule ranges over.

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: README.md, documents/README.md, documents/documentation_standards.md, documents/reading_order.md
**Generated sections**: none

</details>

## Contents
- [1. The spine — from authored spec to running cluster](#1-the-spine--from-authored-spec-to-running-cluster)
- [2. Foreclosure, gates, and where a check lands](#2-foreclosure-gates-and-where-a-check-lands)
- [3. Evidence, testing, and the plan](#3-evidence-testing-and-the-plan)
- [4. Clusters, hosts, and topology](#4-clusters-hosts-and-topology)
- [5. Capabilities and platform services](#5-capabilities-and-platform-services)
- [6. Capacity and storage](#6-capacity-and-storage)
- [7. Content addressing and the formal model](#7-content-addressing-and-the-formal-model)
- [8. Applications, tenancy, and the UI surface](#8-applications-tenancy-and-the-ui-surface)
- [9. Migration, release, and the sibling projects](#9-migration-release-and-the-sibling-projects)
- [10. Governed acronyms](#10-governed-acronyms)
- [Related Documents](#related-documents)

---

## 1. The spine — from authored spec to running cluster

- [`InForceSpec`](./engineering/cluster_lifecycle_doctrine.md#4-the-root-inforcespec-is-the-persistent-contract) — the typed whole-cluster desired-state value every effect is derived from; the central noun of the system.
- [`renderAll`](./engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects) — the sole public pure function from a sealed spec to Kubernetes objects.
- [`ProvisionedSpec`](./engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects) — the constructor-private seal that `renderAll` alone accepts.
- [provision seal](./engineering/resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting) — the whole-deployment fold that mints that seal or returns a typed rejection.
- [capability binding](./engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding) — the stage resolving an abstract capability to a concrete provider and per-cluster shape.
- [`chain` / `Step`](./engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic) — the step algebra whose renderable shape makes a dry run byte-exact.
- [the `Check` algebra](./engineering/preflight_validation_doctrine.md#2-the-check-algebra) — the free structure behind admission, with a short-circuit bind and accumulating combinators.
- [`Lift`](./engineering/preflight_validation_doctrine.md#2-the-check-algebra) — the single effectful probe constructor inside that algebra.
- [the reconciler](./engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine) — the observe-diff-enact loop; explicitly not a state machine.
- [`discover`](./engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine) — the three-valued observation, and how an unreachable result is treated.

## 2. Foreclosure, gates, and where a check lands

- [unrepresentable](./engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) — admitting no value in the type system; the strongest guarantee amoebius claims.
- [illegal state](./illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent) — an enumerated cluster configuration a valid spec must be unable to express.
- [foreclosure layer](./illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force) — the three-valued axis: type-foreclosed, decode-foreclosed, or runtime-checked.
- [validation-locus](./illegal_state/illegal_state_techniques.md#61-the-validation-locus-axis--where-each-illegal-state-is-caught-orthogonal-to-the-foreclosure-layer) — the six-valued axis naming where a state is actually caught; orthogonal to the layer.
- [the typing techniques](./illegal_state/illegal_state_techniques.md#4-the-typing-techniques) — the seven construction patterns by which the catalog's entries are foreclosed.
- [Gate 1](./engineering/dsl_doctrine.md#gate-1--the-dhall-typechecker) — the authoring-time Dhall typecheck, total and pure, before any effect.
- [Gate 2](./engineering/dsl_doctrine.md#gate-2--the-haskell-typed-decoder) — the total Haskell decoder that rejects a well-typed but incoherent value.
- [Gate 3](./engineering/dsl_doctrine.md#gate-3--the-extension-ast-checker) — the syntax-tree check over extension source, run at build time before link.

## 3. Evidence, testing, and the plan

- [honesty (proven / tested / assumed)](./documentation_standards.md#6-honesty-the-proventestedassumed-discipline) — the rule that a claim names the verification layer it actually reaches.
- [validation register](./engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) — the tiers of evidence: pure, boundary-with-fakes, deterministic simulation, and live.
- [the per-run ledger](./engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) — the artifact a validation run emits recording what each layer actually established.
- [derivation](./engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) — the rule that the spec generates the coverage enumeration and a human authors the expectation.
- [spoof-resistant gate](./engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect) — a gate observing an unforgeable post-start effect rather than a self-report.
- [mutant](../DEVELOPMENT_PLAN/development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) — a committed seeded defect; a gate is trusted only once the mutant turns it red.
- [gate integrity](../DEVELOPMENT_PLAN/development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) — the twelve clauses ensuring a gate cannot be passed by a stub.
- [natural architecture](./engineering/substrate_doctrine.md#11-the-natural-architecture-rule) — the architecture a detected host executes without translation; the only one its lanes may be validated at.
- [substrate](./engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob) — the detected hardware platform family; it always derives a `linux-cpu` execution lane at its natural architecture and may add an accelerator lane. A pristine Linux lane uses Incus on Linux, Lima on Apple, or WSL2 on Windows.
- [status vocabulary](../DEVELOPMENT_PLAN/development_plan_standards.md#c-status-vocabulary) — the five phase markers, and the rule confining status to the plan.
- [Single Source of Truth](./documentation_standards.md#1-philosophy) — the rule that exactly one document owns a concept and the rest link to it.

## 4. Clusters, hosts, and topology

- [amoebic spawning](./engineering/cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest) — a parent cluster creating a child, producing the recursive cluster forest.
- [`ComputeEngine`](./engineering/cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm) — the closed union of cluster engines, declared rather than detected.
- [`Topology`](./engineering/cluster_topology_doctrine.md#4-topology-a-cluster-is-a-fold-over-its-nodes-and-cardinality-is-by-construction) — a cluster as a fold over its nodes, with cardinality fixed by construction.
- [context and role](./engineering/daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid) — the orthogonal grid of where the binary runs against what job it does.
- [control-plane singleton](./engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton) — the single-replica pod holding cluster and secret authority under a lease.
- [the bootstrap coordinator](./engineering/substrate_doctrine.md#6-the-bootstrap-coordinator-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off) — the pre-binary Python command that ensures a toolchain, builds the binary, and hands off.
- [in-cluster role](./engineering/daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid) — what job the one binary is doing in a pod: control-plane singleton, capacity scheduler, or a worker of some kind. Not the Kubernetes *node* role, and not an RBAC role; three unrelated senses share the word.
- [worker kind](./engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected) — which worker a `Worker` role is, and the parameters that identify what it serves.
- [frame config](./engineering/dsl_doctrine.md#3-the-orchestration-surface-parameters-context-witness) — the static local `amoebius.dhall` a running copy of the binary reads to learn which frame it inhabits and which role it holds; the second Dhall authority surface, and never the `InForceSpec`.
- [ensure](./engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract) — to probe for a tool, install it when absent, resolve its absolute path, and invoke it by that path.
- [the floor](./engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply) — the per-substrate set of things only the operator can supply: the package-manager root, a hardware or firmware fact, and a credentialed account.
- [a refusal](./engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply) — a floor check's failure carried as a value naming the prerequisite and the remedy, so a plan for one substrate stays decidable on another.
- [the handoff](./engineering/bootstrap_sequence_doctrine.md#4-the-host-daemon--singleton-handoff) — the instant the host daemon stops being the authority and the singleton starts.
- [Channel 1 and Channel 2](./engineering/host_cluster_comms_doctrine.md#1-the-host-origin-surface-two-channels-both-localhost-only) — the two host-origin communication paths and their reach restriction.
- [wild ingress](./engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path) — all traffic originating outside the host, entering by one centralized path.
- [gateway migration](./engineering/gateway_migration_doctrine.md#5-the-migration-as-a-typed-edge-observed-state-machine) — moving wild-ingress ownership between clusters, as an edge-observed state machine.
- [the `Planned` branch](./engineering/gateway_migration_doctrine.md#2-the-planned-branch--a-coordinated-strong-consistency-handover) — the coordinated lossless handover arm of that migration.
- [the `Failover` branch](./engineering/gateway_migration_doctrine.md#3-the-failover-branch--an-availability-first-emergency-takeover) — the emergency survivor-takeover arm, with bounded rather than zero data loss.
- [readiness edge](./engineering/readiness_ordering_doctrine.md#3-readiness-is-a-condition-never-a-duration) — an observed dependency-ready condition; ordering never gates on elapsed time.

## 5. Capabilities and platform services

- [capability](./engineering/service_capability_doctrine.md#2-the-capability-set) — an abstract service role an application names instead of naming a product.
- [canonical provider](./engineering/service_capability_doctrine.md#3-one-canonical-provider-the-type-admits-alternates) — the one implementation a capability binds to by default, with alternates typed.
- [namespace layout](./engineering/namespace_layout_doctrine.md#2-one-namespace-per-platform-capability--the-derived-set) — the derived one-namespace-per-capability set; a namespace is computed, never authored.
- [`SecretRef`](./engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value) — a secret name carried in the spec; values live only in the secret store.
- [bake versus build](./engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain) — the rule fixing which third-party binaries are baked into the base image.

## 6. Capacity and storage

- [`Quantity` / `Capacity` / `Demand` / `Budget`](./engineering/resource_capacity_types.md#3-the-types-quantity-capacity-demand-budget) — the four types the whole resource-provisioning model is expressed in.
- [`fits` / `carve` / `place`](./engineering/resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting) — the nested total folds that admit a deployment or reject it as infeasible.
- [`StorageBudget`](./engineering/resource_capacity_storage.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm) — the closed union of storage ceilings, each naming exactly one owner.
- [`Growable` / `ScalingPolicy`](./engineering/resource_capacity_storage.md#6-growable--scalingpolicy-the-quota-bounded-dynamic-provisioning-arm) — the quota-capped arm through which capacity is allowed to grow.
- [deterministic rebind](./engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind) — recreating a cluster onto preserved bytes with no restore step.
- [shrink as verified migration](./engineering/storage_lifecycle_doctrine.md#8-shrinking-storage-without-representing-data-destruction) — contracting storage without any representable destruction of data.

## 7. Content addressing and the formal model

- [content address](./engineering/content_addressing_doctrine.md#1-a-content-derived-name-that-cannot-be-forged) — a name that is a total function of the bytes it names, so it cannot be forged.
- [blobs, manifests, pointers](./engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers) — the three store tiers, and which of them is mutable.
- [`experimentHash`](./engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran) — the identity joining what was requested to where it ran.
- [the `Model`](./engineering/formal_model_doctrine.md#2-the-model-is-data) — the reifiable value that is the single source for both runtime and model-checking.
- [`interpret` and `emitTLA`](./engineering/formal_model_doctrine.md#3-two-total-renderings) — the two total renderings of that one value.
- [what a green model-check establishes](./engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not) — the boundary between the model's claim and the running code's.

## 8. Applications, tenancy, and the UI surface

- [deployment rules and application logic](./engineering/app_vs_deployment_doctrine.md#1-two-surfaces-one-app-written-once) — the split letting one application be written once and run many ways.
- [tenant](./engineering/tenancy_doctrine.md#3-what-a-tenant-is) — the isolation unit on an axis orthogonal to the cluster axis.
- [`TenantSpec` / `SubjectSpec` / `Membership`](./engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--subjectspec--membership--owner--rolebinding) — the typed shapes from which access control is derived rather than authored.
- [`ClientPlan` and `UiServerPlan`](./engineering/low_code_ui_runtime_doctrine.md#3-one-checked-value-two-runtime-plans) — the public browser projection and the private server projection of one checked program.
- [typed effect port](./engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations) — the declared interface by which application logic reaches an effect.

## 9. Migration, release, and the sibling projects

- [the migration law](./engineering/migration_doctrine.md#2-the-law) — one create-new, verify, retire-old discipline instantiated across the whole system.
- [`Release` and `releaseHash`](./engineering/release_lifecycle_doctrine.md#2-release-and-the-immutable-release-ledger-releasehash) — the immutable ledger entry and the content key identifying it.
- [`Environment`](./engineering/release_lifecycle_doctrine.md#3-environment-and-the-etag-cas-promotion-pointer) — the closed set of promotion targets, each a single compare-and-swap pointer.
- [`PromotionGate`](./engineering/release_lifecycle_doctrine.md#4-promotiongate-promote-unverifiedprod-is-unrepresentable) — the evidence requirement making an unverified promotion to production unrepresentable.
- [lift and compose](./engineering/lift_and_compose_doctrine.md#1-why-this-doctrine-exists) — re-homing proven sibling code onto an amoebius seam rather than reimplementing it.
- [the reuse map](./engineering/lift_and_compose_doctrine.md#2-what-lifts-the-reuse-map) — which shape lifts from which sibling project onto which seam.

## 10. Governed acronyms

A document expands each of these once at its first use in the body, then uses the bare form thereafter, per
[documentation_standards.md §12](./documentation_standards.md#12-naming-what-the-reader-does-not-know).

| Acronym | Expansion | Note |
|---|---|---|
| ABI | application binary interface | |
| CAS | content-addressed storage, **or** compare-and-swap | Two senses. The pointer-update sense is usually written `ETag-CAS`. |
| CBOR | Concise Binary Object Representation | The message bus's only payload encoding. |
| CNI | Container Network Interface | |
| CRD | custom resource definition | |
| CSI | Container Storage Interface | |
| CSP | Content Security Policy | |
| CSRF | cross-site request forgery | |
| DAG | directed acyclic graph | |
| DST | deterministic simulation testing | The activity of validation register 2.5. |
| EBS | Elastic Block Store | The per-volume durable backing on the cloud provider. |
| EKS | Elastic Kubernetes Service | A declared managed engine, not a substrate. |
| FLP | Fischer–Lynch–Paterson | The consensus impossibility result. |
| GADT | generalised algebraic data type | The indexing mechanism behind the total decoder. |
| IR | intermediate representation | |
| mTLS | mutual transport layer security | |
| MSL | Metal Shading Language | |
| OCI | Open Container Initiative | The image and manifest-list format. |
| OIDC | OpenID Connect | |
| PACELC | under a partition, availability or consistency; else latency or consistency | The consistency-tradeoff framing. |
| PKI | public key infrastructure | |
| PV / PVC | PersistentVolume / PersistentVolumeClaim | |
| RBAC | role-based access control | Derived from the tenancy shapes, never authored. |
| RPO / RTO | recovery point objective / recovery time objective | The data-loss and downtime budgets. |
| SBOM | software bill of materials | |
| SKU | stock-keeping unit | A cloud instance type. |
| SLO | service level objective | |
| SPA | single-page application | |
| SSA | server-side apply | The mechanism the object reconciler applies through. |
| SSoT | Single Source of Truth | |
| STS | Security Token Service | The identity join in credential admission. |
| TLA+ / TLC | Temporal Logic of Actions / its model checker | Generated from the `Model`, never committed. |
| TSDB | time-series database | |
| TTL | time to live | |
| VRAM | video random-access memory | Accelerator memory, accounted like every other capacity axis. |
| WAL | write-ahead log | |
| WORM | write once, read many | |
| XSS | cross-site scripting | |

---

## Related Documents
- [Documentation Standards](./documentation_standards.md) — [§12](./documentation_standards.md#12-naming-what-the-reader-does-not-know) governs what this file may and may not contain
- [Reading Order](./reading_order.md) — the sequenced path this glossary supports
- [Engineering Doctrine Index](./engineering/README.md) — the documents most rows point into
- [Illegal State Catalog](./illegal_state/illegal_state_catalog.md) — the enumerated states the foreclosure vocabulary describes
- [Development Plan](../DEVELOPMENT_PLAN/README.md) — phase order and status, which this file never restates
