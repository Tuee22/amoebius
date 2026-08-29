# Phase 64: Keycloak-owned ingress

> **Purpose**: Wire the single Keycloak-owned wild-ingress door — LoadBalancer → Envoy/Gateway API →
> Keycloak — on the standard service stack, prove no workload can publish its own wild ingress, and confirm the
> retained-storage rebind regression still holds behind the new edge.
> **Read this if**: phase 64 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/vault_pki_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 64.1: The Keycloak-owned edge — LoadBalancer → Envoy/Gateway API → Keycloak ⏸️](#sprint-641-the-keycloak-owned-edge--loadbalancer--envoygateway-api--keycloak-)
- [Sprint 64.2: No self-published wild ingress + public-edge TLS ⏸️](#sprint-642-no-self-published-wild-ingress--public-edge-tls-)
- [Sprint 64.3: East-west NetworkPolicy posture — derived default-deny ⏸️](#sprint-643-east-west-networkpolicy-posture--derived-default-deny-)
- [Sprint 64.4: The single-door + storage-rebind regression gate ⏸️](#sprint-644-the-single-door--storage-rebind-regression-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 63, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase must close the last opening in the platform cluster by making **Keycloak the sole authenticated
door** for every wild request. It may compose only future gate-passed results: the Phase-62 LoadBalancer
address, the **Envoy + Gateway API L7 data plane**, **Keycloak OIDC/JWT enforcement**, and typed manifests
applied by the Phase-58 reconciler. The target is that WAN, LAN, and even a
localhost-browser connection reach a platform or app surface only after traversing
`LoadBalancer → Envoy/Gateway API → Keycloak`. Its redesigned gate must also test the structural half:
**no workload publishes its own wild ingress and no chart opens a backdoor NodePort** — the sole carve-out is
the host-origin, localhost-only NodePort that is a *different type* of endpoint, not a wild one. The
default-deny east-west NetworkPolicy posture, with allow-edges **derived from the declared dependency graph**,
must be applied and exercised live. Finally, the phase must re-run the Phase-60 lossless-rebind target behind
the new edge; no current storage proof or ingress result is claimed.
The same authenticated route machinery explicitly admits the UI server's HTTP upgrade: a WebSocket handshake
must traverse Keycloak/Envoy, exact-match Origin and the versioned subprotocol, and bind the secure session plus
single-use nonce before Envoy forwards it. There is no unauthenticated, direct-Service, or alternate SSE route.

The scope stops at *the ingress door and its guarantees*. The DSL deploy through the `replicas=1` control-plane daemon,
app tenancy, and the Pulsar/workflow runtime are Phase 65+ concerns; this phase exercises the edge from the
host binary against the fixed standard service set targeted by Phases 62–63. The one genuinely new-vs-prodbox
piece — the Envoy + Gateway API data plane replacing a hand-configured proxy — is the least evidence-backed
part of the set.

**Phase scope:** one cohesive claim — *there is exactly one door, and it is Keycloak's*. A workload that tries to publish its own wild ingress must fail rather than be checked.

**Substrate:** linux-cpu ([§L](development_plan_standards.md#l-one-substrate-discipline)) — the edge is wired and gated on a single-node `kind` cluster on a linux-cpu
host, recorded in [substrates.md](substrates.md). The future gate does not exercise an accelerator lane, but
`linux-cpu` remains available on every hardware substrate.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 (live infrastructure) — the gate drives a real edge on a real cluster and re-exercises a live
delete + recreate; a Register-1/2 in-process check cannot discharge it (though the *render-time*
impossibility of a self-published ingress must first receive Phase-33 and Phase-49 gate pass).

**Depends on:** [Phase 63](phase_63_platform_services_2.md)
**Gate:** `pb validate phase 64`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *there is exactly one door, and it is Keycloak's*. A workload that tries to publish its own wild ingress must fail rather than be checked. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 64` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance have been established. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not yet been demonstrated by a passing gate for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not yet been demonstrated by a passing gate. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not yet been demonstrated by a passing gate. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a checked pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or checked non-applicability have not yet been demonstrated by a passing gate. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 63; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

This phase instantiates the canonical resource matrix and sealed whole-deployment provision boundary from
[`resource_capacity_types.md §3.1`](../documents/engineering/resource_capacity_types.md#31-the-systematic-provision-matrix)
and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting);
the names below are phase-specific source composites that must flatten to those canonical execution atoms.

The edge is not a resource-free collection of CRs. Before any certificate request, database mutation, or
apiserver apply, gadt-decode yields the pure source that binding expands into an `EdgeResourceDemand` containing
the Envoy Gateway controller, every operator-derived Envoy data-plane child, Keycloak, the ACME
issuance/renewal Job, and the Keycloak `PatroniSqlDemand`. Every runnable unit carries a complete
`PodResourceEnvelope`: immutable image artifact and
its image-store/import bytes; per-container CPU, memory, and ephemeral-storage requests and limits; runtime
working-set evidence; writable-root and log headroom; disk- or memory-backed `emptyDir`, projected
ConfigMap/Secret/service-account-token bytes, durable claims, bounded cache population or explicit `None`, and
`accelerator = None` on this linux-cpu gate. Controller operands also declare replicas and `Recreate` or rolling
old/new/surge/terminating overlap. `Gateway` and `HTTPRoute` objects consume apiserver/etcd capacity but do not
pretend to be extra Pods; the Envoy Gateway controller's private `ControllerChildEnvelope` is what enumerates
the actual data-plane Pods. After exhaustive controller expansion, every desired/live/old/new/apply object
identity contributes a `KubernetesApiObjectDemand` to the complete map in
`EtcdLogicalDemand { desiredObjects, churn, model }`. Only private
`ProvisionedEtcdLogicalDemand.derivedPeak <= ControlPlaneStorageDemand.etcd.backendQuotaBytes` may continue;
the separate backend-at-quota plus WAL/snapshot/serialized-defrag peak must then fit its physical backing.

`PatroniSqlDemand` is the pure Keycloak database input and `ProvisionedPatroniSql` has a private constructor.
The demand names the operator-derived `ControllerChildEnvelope`, complete Patroni/Postgres child execution,
the exact non-empty `SchemaObjectDemand` set, WAL, checkpoint, failover-replay and recovery-workspace bounds,
a `DeclaredVolumeDemand`, failover and rollout overlap, its `StorageBudgetId`, and
`SqlMutationAdmission`. Binding expands those logical terms through
filesystem/allocation geometry into per-backing debits and a witness; a failed transition keeps
the old database, WAL, and replacement resident until verified recovery, never credits them early. ACME
declares its bounded order/challenge/retry set, temporary key/CSR workspace, certificate/key revision count,
issuer concurrency/rate admission, and resulting Vault Raft/audit delta; the complete issuer Job envelope and
Vault high-water are checked together.

The private SQL result also contains the complete admission-proxy `PodResourceEnvelope` and admission witness.
Keycloak's mutating SQL route goes through that snapshot-bound proxy; direct or over-connection/transaction/
WAL-budget writes are denied before the database mutates. The proxy is included in rollout and live readback,
not treated as free middleware.

The whole-deployment provisioner admits the edge only after these demands, namespace quotas, pod slots, volume
attachments, kubelet image/nodefs headroom, Vault backing, and the live-snapshot residual all fit. Rendering
accepts only the resulting private provisioned projections. Readback normalizes every live Pod, PVC, operator
child, certificate revision, and provider object to that projection; an unexplained child or byte is an
`UnknownCommitment`, not free capacity. Haskell boundary cases make each CPU, memory, ephemeral, image, log,
pod-slot, attachment, API-object/revision/Event/etcd, SQL object/WAL/recovery/proxy, and ACME/Vault term one unit short
in turn. Haskell changed-production-subject omission mutants that drop the Envoy child, Keycloak Pod, ACME Job,
old/new rollout overlap, or Patroni WAL/recovery term, and Haskell API/etcd changed-production-subject mutants
that drop one desired object, churn operand, or model, must refuse
before the first effect, while their exact-fit twins render and reconcile.

## Doctrine adopted

- [`workflow_calculus_doctrine.md` §3 — Teardown is a type obligation](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation) — keycloak-owned ingress provisions, and a teardown obligation it cannot discharge is a value it cannot construct.
- [`ui_realtime_coordination_doctrine.md §3 — one browser transport contract`](../documents/engineering/ui_realtime_coordination_doctrine.md#3-one-browser-transport-contract):
  Envoy/Gateway API carries authenticated same-origin WebSocket upgrades through the same Keycloak-owned edge,
  with exact Origin, session nonce, and versioned subprotocol checks and no direct backend route.

- [`platform_services_doctrine.md` §9 — The LoadBalancer and the single wild-ingress path](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
  — **the LoadBalancer and the single wild-ingress path**: this phase materializes the one sanctioned ingress
  shape (`LoadBalancer → Envoy/Gateway API → Keycloak`), its **east-west connectivity derived from the declared dependency graph** subsection, and the [`platform_services_doctrine.md` §11 — Bring-up and dependency ordering](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
  that place the LB address before the Gateway listener and Keycloak before the edge admits wild traffic.
- [`illegal_state_security.md` §3.7 — Accidental insecure / backdoor ingress](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)
  — **accidental insecure / backdoor ingress**: a workload cannot publish its own wild ingress because
  `WildIngress` is a Keycloak-edge-only construct and the host-origin, localhost-only NodePort is a distinct
  `HostLocalPeer` endpoint that does not interconvert; this phase is the live realization of that
  render-foreclosed impossibility (and of [`illegal_state_security.md` §3.6 — Blocking NetworkPolicy (services can't reach each other)](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other), the derived-allow-edge NetworkPolicy rule).
- [`pulumi_iac_doctrine.md` §5 — DNS (route53) and TLS (zerossl): the provider integrations this doctrine owns](../documents/engineering/pulumi_iac_doctrine.md#5-dns-route53-and-tls-zerossl-the-provider-integrations-this-doctrine-owns)
  — **DNS (route53) and TLS (zerossl)**: the public-edge TLS wired through the edge is *referenced*, not
  re-specified here; certificate provisioning is owned by the Pulumi/IaC doctrine, and the ZeroSSL EAB material
  is a Vault `SecretRef`, never a Dhall literal.
- [`storage_lifecycle_doctrine.md` §6 — The lossless-teardown guarantee: deterministic rebind](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind)
  — **the lossless-teardown guarantee: deterministic rebind**: the gate re-runs the Phase-60 marker-bytes
  round-trip across a delete + recreate to confirm adding the edge introduced no storage regression.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.

## Sprint 64.1: The Keycloak-owned edge — LoadBalancer → Envoy/Gateway API → Keycloak ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 63](phase_63_platform_services_2.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/ui_realtime_coordination_doctrine.md`

### Objective

Adopt [`platform_services_doctrine.md` §9 — the LoadBalancer and the single wild-ingress path](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path):
make Keycloak the single authenticated ingress point, fronted by Envoy + the Gateway API, atop the
MetalLB backend selected for this phase's self-managed `kind` engine, with the [§11 ordering edges](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
observed as readiness conditions, not durations.

### Deliverables

- Envoy + Gateway API rendered as the L7 edge (a `Gateway` listener plus `HTTPRoute`s as typed `K8sObject`s),
  terminating TLS and routing, applied by the Phase-58 reconciler.
- Keycloak deployed against its Phase-63 Patroni DB, owning OIDC/JWT enforcement in front of every platform
  browser surface, so an unauthenticated request never reaches a workload.
- An authenticated WebSocket `HTTPRoute`/upgrade policy using the same host and TLS edge: secure session cookie,
  exact Origin, single-use session nonce, and fixed versioned subprotocol are all required before forwarding;
  direct-Service and alternate unauthenticated upgrade paths are absent.
- The pure `EdgeResourceDemand` bound to complete envelopes for the Gateway controller, all derived Envoy
  children, Keycloak, and the ACME Job, plus a `PatroniSqlDemand` whose private provisioned result retains exact
  SQL objects, WAL, checkpoint/recovery, volume, admission proxy, failover, and rollout operands. No CR or Service stands in
  for its children, and no scalar "database bytes" stands in for the storage structure.
- The readiness edges wired into the derived DAG: MetalLB address before the Gateway listener; Keycloak ready
  before the edge admits wild traffic — never a `threadDelay`.
- Separately authored Haskell route-inventory and realm case declarations, subject to recorded independent
  check, plus Haskell changed-production-subject mutant (a) — an OIDC-filter-removed edge variant the gate
  must show going red. Any serialized representation is generated lazily beneath `.build/**` and untracked.

### Validation

1. For each surface enumerated in the separately authored Haskell route inventory, complete a real OIDC login as
   `phase32-tester` and assert the surface's content is served (2xx) only after the request traversed Keycloak;
   assert `LoadBalancer → Envoy/Gateway API → Keycloak` is the only reachable wild path, probed once per origin
   class (WAN, LAN, localhost-browser) from a distinct netns/sidecar with the origin-appropriate source address.
2. Send an unauthenticated request to each surface; assert it is redirected to the Keycloak login (a specific
   302/401 to the Keycloak authorize endpoint), never served the surface — this fails against Haskell
   changed-production-subject mutant (a) (OIDC filter removed), which the gate must show turning red.
3. Assert the bring-up honoured the ordering edges by an **enforced-gating** experiment: withhold the MetalLB LB
   address and assert (via an external readiness harness) the Gateway listener step blocks; withhold Keycloak
   readiness and assert the wild-admit step blocks; then release each and assert progress. A post-hoc scan of
   the render source shows **no `threadDelay`** on these edges. Passing by ordering the implementation's own
   happy-path event log is not sufficient.
4. Run the exact-fit/one-short resource corpus before apply, including one case for each Gateway/Envoy/Keycloak
   CPU, memory, ephemeral, image/log, pod-slot and rollout term and each Patroni data/WAL/recovery/attachment
   and SQL-proxy/admission term. Compare rendered requests, limits, claims, rollout controls, operator children,
   proxy envelope, and admission witness with live readback;
   the Haskell changed-production-subject omission mutants named in the phase contract must reject before any certificate, SQL, or apiserver
   mutation.
5. Upgrade the platform-owned WebSocket probe with a valid Keycloak session and fresh nonce, exchange a fresh
   challenge, then pair wrong-Origin, replayed-nonce, wrong-subprotocol, unauthenticated, and direct-Service
   attempts. The independent backend/CNI trace observes the challenge only for the valid tuple.

### Remaining Work

Independently check the separately authored Haskell route inventory and realm case corpus before any future
validation candidate.

## Sprint 64.2: No self-published wild ingress + public-edge TLS ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 64.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/illegal_state/illegal_state_catalog.md`, `documents/engineering/pulumi_iac_doctrine.md`

### Objective

Adopt [`illegal_state_catalog.md` §3.7 — accidental insecure / backdoor ingress](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)
live — the running-cluster realization of the single sanctioned wild-ingress path of
[`platform_services_doctrine.md` §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
— together with the public-edge TLS integration of
[`pulumi_iac_doctrine.md` §5 — DNS (route53) and TLS (zerossl)](../documents/engineering/pulumi_iac_doctrine.md#5-dns-route53-and-tls-zerossl-the-provider-integrations-this-doctrine-owns):
prove on the running cluster that the render-time impossibility of a self-published ingress holds, and that the
one carve-out really is a *different type* of endpoint, not a wild one.

### Deliverables

- A live audit proving there is no non-Keycloak wild path: no chart opens a backdoor NodePort to the wild, and
  no workload publishes its own `Ingress` — the `WildIngress` constructor is reachable only from the Keycloak
  edge, per the Haskell render invariant owned by Phase 33.
- The sole carve-out exercised as a distinct `HostLocalPeer` endpoint (host-origin, localhost-only NodePort, no
  mTLS, no WAN/LAN reach) — owned in full by [`host_cluster_comms_doctrine.md`](../documents/engineering/host_cluster_comms_doctrine.md)
  and referenced here, not re-specified.
- Public-edge TLS (ZeroSSL via DNS, route53) wired through the edge, with the EAB material a Vault `SecretRef`;
  the provisioning itself is owned by the Pulumi/IaC doctrine and referenced.
- An ACME execution demand with a complete issuer-Job `PodResourceEnvelope`, bounded challenge/order/retry and
  key/CSR workspace, certificate/key revision retention, and the resulting Vault Raft/audit high-water; this
  demand is provisioned before the ACME client or Vault mutation can run.
- A Haskell-declared scanner-validation seed that lazily renders a raw-`kubectl` NodePort/`Ingress` bypass
  beneath `.build/test-corpora/**`, plus a Haskell-authored argv/env-recording ACME observer whose executable
  form is generated lazily beneath `.build/**` and used to observe EAB provenance from the OS boundary. Neither
  serialized form is tracked source or an oracle.

### Validation

1. First qualify the scanner: apply the Haskell-declared, run-local out-of-band NodePort/`Ingress` seed via raw `kubectl` (not the
   DSL) that opens a WAN/LAN-reachable bypass; assert the scan turns **red** and the ledger records the
   violation; remove the seed and assert **green**. Then, with no seed present, scan the live cluster and assert
   no exposed backdoor NodePort reachable from a WAN/LAN netns probe, and no non-Keycloak wild route.
2. Assert the host-origin, localhost-only NodePort is unreachable off the host by an **actual probe from a distinct network namespace with a non-loopback source IP** (which must fail/time out) paired with a
   host-loopback probe that succeeds — differing only in origin; inspecting the bind config alone is not
   sufficient.
3. Assert the ACME client obtained its EAB material from a Vault `SecretRef`, observed via an **argv/env recording
   observer** on the client process (the observer shows the SecretRef path, never a literal), and have the
   Haskell validator inspect the complete lazily rendered DSL bytes to assert no EAB literal appears. A Haskell
   seeded literal-injection negative must turn that check red. **Scope for the linux-cpu kind gate:** a staging/stand-in
   ACME chain is acceptable in place of live public ZeroSSL/route53 issuance (no public DNS zone is required);
   the load-bearing assertion is the **provenance of the EAB material (Vault, not Dhall)**, not that the cert
   was signed by production ZeroSSL.
4. Make the issuer Job CPU, memory, ephemeral workspace, image/import bytes, log headroom, and Vault revision
   high-water one unit short in turn; each case refuses before an ACME order is opened. A Haskell
   changed-production-subject omission mutant that
   drops retry-temporary bytes or the prior certificate revision turns red, while live Job/Vault readback for
   the exact-fit twin equals the provisioned projection.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 64.3: East-west NetworkPolicy posture — derived default-deny ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 64.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/illegal_state/illegal_state_catalog.md`

### Objective

Adopt the **east-west connectivity is derived from the dependency graph** subsection of
[`platform_services_doctrine.md` §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
and [`illegal_state_catalog.md` §3.6 — blocking NetworkPolicy, services can't reach each other](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other):
apply the default-deny + derived-allow NetworkPolicy posture live, so exactly the declared edges are allowed
and every other is denied.

### Deliverables

- A default-deny east-west baseline plus allow-edges derived from the declared dependency graph, rendered by
  the Phase-58 reconciler and applied to the live cluster — no hand-authored policy.
- The live posture: a service that does not declare consuming `B` cannot reach `B`, and a declared edge is not
  severed — the two shapes [§3.6](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other)
  makes unrepresentable at authoring time, now confirmed on the running cluster.
- A separately authored Haskell expected-policy declaration, subject to independent check; an independent
  Haskell graph-walker that recomputes the expected allow-set from the declared dependency edges; and Haskell
  changed-production-subject mutant (b) — a `derive` variant that drops one allow-edge and adds one undeclared
  allow-edge, which the set-equality check must show going red. Any serialized policies are generated lazily
  beneath `.build/**` and untracked.

### Validation

1. Assert a declared consumer reaches its provider through the applied policy.
2. Assert a probe to an undeclared east-west edge is denied (times out).
3. Prove "derived" by **graph variation**: deploy a scratch consumer, add a declared edge to a provider,
   re-render/re-apply, and assert the applied policy set gains exactly the corresponding allow and live
   reachability flips on; remove the edge and assert the allow is withdrawn and reachability flips off. The
   applied set must therefore be a total function of the declared graph, not of the fixed Phase-62/42 service
   names. This fails against Haskell changed-production-subject mutant (b) (drop one allow, add one undeclared
   allow), which the gate must
   show going red.
4. After independent check, assert set equality between the applied policies, the separately authored Haskell
   expected-policy declaration, and the output of an **independent Haskell graph-walker** (distinct from
   `renderAll`) over the declared dependency edges — not by re-running the implementation's own `derive`.

### Remaining Work

Independently check the separately authored Haskell expected-policy declaration before any future validation
candidate.

## Sprint 64.4: The single-door + storage-rebind regression gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 64.3
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/storage_lifecycle_doctrine.md`

### Objective

Adopt [`storage_lifecycle_doctrine.md` §6 — the lossless-teardown guarantee: deterministic rebind](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind)
alongside [`platform_services_doctrine.md` §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path):
close the phase by proving the single Keycloak door end-to-end **and** that adding the edge did not regress the
deterministic storage rebind.

### Deliverables

- The phase-gate harness: assert an unauthenticated request to any platform surface is rejected at the edge and
  there is no non-Keycloak wild path (no exposed backdoor NodePort).
- Run-local image provenance that consumes the verified Phase-56 identity and current registry catalog; a
  copied expected-digest input is condemned residue and cannot be recreated.
- The storage-rebind regression: derive run-unique marker bytes in Haskell, write them as a row into the
  Keycloak Patroni DB and as an object into a MinIO bucket, and retain the expectation only in the independent
  run-local observer. Perform the Phase-60 intermediate
  observation while the old apiserver is still running, quiescing the witnesses and stopping each through its
  owning resource's supported stop path — the operator-owned Patroni witness through its
  `PerconaPGCluster`/operator path, never by mutating the operator's child StatefulSet, and the directly owned
  MinIO witness through its StatefulSet. Wait until no Pod references the PVCs, delete them, and observe the
  PVCs gone, the old PV objects `Released`, and the backing bytes intact. Then `cluster delete`, proving from
  the host boundary that the old cluster, its node container, and its apiserver are absent; `cluster recreate`,
  re-render/re-apply fresh PV objects over the retained backing, record the new cluster identity, and read the
  same bytes back — the Phase-60 guarantee re-run behind the new edge. Plus applied Haskell mutant (c), a
  delete-no-op harness variant the recreate-witness check must show going red.

### Validation

1. Assert the single-door invariant holds end-to-end: an unauthenticated request is rejected at the edge, a real
   OIDC login as `phase32-tester` serves each Haskell-declared route expectation, and there is no backdoor wild
   path (scanner first qualified against the generated run-local backdoor seed, per 28.2).
2. Run Haskell-declared marker bytes, materialized beneath `.build/test-corpora/**`, through write → quiesce/owner-mediated stop
   → wait for zero Pod references → live PVC-delete/`Released` observation → full cluster delete/absence
   witness → recreate/re-apply → read cycle. Observe `Released` only after the consuming Pods have terminated
   and while the old apiserver remains live; after full deletion, assert from the host boundary that the
   cluster is absent and the retained backing bytes remain. Record the recreate witness (new cluster CA /
   kube-system pod UIDs / `kind` node container ID differ from pre-delete) in the ledger, then assert the
   read-back bytes are unchanged. This fails against Haskell changed-production-subject mutant (c) (delete
   no-op'd), which the gate
   must show going red because the recreate witness finds an identical cluster identity.
3. Assert the full stack is still up, reachable only through the Keycloak edge, and HA-shaped after the recreate.
4. Re-run provision against the fresh live snapshot before recreate apply and prove the transition peak includes
   the old and replacement edge Pods, Keycloak Patroni data/WAL/checkpoint state, and ACME/Vault revisions.
   Removing any one of those operands must fail the Haskell changed-production-subject omission-mutant corpus
   rather than relying on the successful recreate as evidence of capacity.
5. Compare CRI-observed image identities with the verified Phase-56 run input and current registry catalog;
   a seeded gate variant that reads an expected-digest file and a side-loaded public image each fail.

### Remaining Work

The historical copied expected-base-digest input is condemned residue and cannot be recreated. A future
candidate must receive the Phase-56 identity directly as authenticated run input.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/platform_services_doctrine.md` — when this phase lands, the §9 single-wild-ingress
  honesty note and the §11 ordering edges flip from "design intent" to a delivered-status pointer (status stays
  in the plan); the east-west-derived-NetworkPolicy subsection gains its first live amoebius realization.
- `documents/illegal_state/illegal_state_catalog.md` — record that §3.7 (backdoor ingress) and §3.6 (blocking
  NetworkPolicy) gain their first *live* confirmation here, complementing the Haskell render-time invariant
  from Phase 33.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record the live edge proof for authenticated
  WebSocket upgrade routing; cross-pod routing and Redis failure behavior remain later gates.
- `documents/engineering/pulumi_iac_doctrine.md` — note that the §5 public-edge TLS (ZeroSSL/route53)
  integration is first wired through a live edge in this phase, with the EAB material sourced from Vault.
- `documents/engineering/storage_lifecycle_doctrine.md` — record that the §6 lossless-rebind guarantee is
  re-exercised behind the ingress edge as a regression check.

**Cross-references to add:**

- [README.md](README.md) — flip the Phase 64 row status once work begins, and link this document from the
  Phase 64 paragraph.
- [substrates.md](substrates.md) — record `linux-cpu` as the Phase 64 gate substrate in the per-phase map.
- [system_components.md](system_components.md) — register the target paths named in the sprint `Implementation`
  fields (`Amoebius.Platform.Edge`, `Amoebius.Platform.Keycloak`, `Amoebius.Platform.Tls`,
  `Amoebius.Manifest.NetworkPolicy`).

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 64 row is the authoritative one-line gate and status.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the Register-3 honesty token: a passed gate is a live-substrate result, never a compile claim).
- [overview.md](overview.md) — the target architecture and the cross-cutting "Keycloak owns all wild ingress"
  invariant this phase realizes.
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — [§9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path) the single
  wild-ingress path and [§11](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering) the bring-up ordering adopted here.
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — [§3.7](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress) backdoor ingress and [§3.6](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other)
  blocking NetworkPolicy, the impossibilities confirmed live here.
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — the typed renderer
  + server-side-apply reconciler that enacts the edge (delivered in Phase 58).
- [Pulumi IaC Doctrine](../documents/engineering/pulumi_iac_doctrine.md) — [§5](../documents/engineering/pulumi_iac_doctrine.md#5-dns-route53-and-tls-zerossl-the-provider-integrations-this-doctrine-owns) the DNS/TLS provider integration
  referenced for the public edge.
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — [§6](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind) the lossless-rebind
  guarantee re-exercised as the regression clause.
- [Host ↔ Cluster Comms Doctrine](../documents/engineering/host_cluster_comms_doctrine.md) — the sole
  host-origin, localhost-only carve-out from "Keycloak owns all wild ingress".
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md) — the fixed
  authenticated browser-WebSocket handshake and direct-backend prohibition projected into this edge gate
