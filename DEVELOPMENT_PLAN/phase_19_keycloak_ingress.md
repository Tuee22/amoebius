# Phase 19: Keycloak-owned ingress

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_18_platform_services.md, DEVELOPMENT_PLAN/phase_20_live_dsl_singleton.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Wire the single Keycloak-owned wild-ingress door — LoadBalancer → Envoy/Gateway API →
> Keycloak — on the standard service stack, prove no workload can publish its own wild ingress, and confirm the
> retained-storage rebind regression still holds behind the new edge.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is design intent and every prescriptive
statement is a target shape, never a tested amoebius result. The gate has not run on any substrate. The
substrate is **linux-cpu**: the edge is wired and gated on the single-node `kind` cluster carrying the Phase-18
standard service stack. Keycloak owning all wild ingress is **sibling evidence, not an amoebius result** —
prodbox proved a Keycloak-as-the-only-door edge, and its Patroni-backed Keycloak is the proven relational
consumer — while the Envoy + Gateway API L7 data plane and the derived-from-the-dependency-graph east-west
NetworkPolicy posture are amoebius-shaped and unproven here. Per
[development_plan_standards.md §K](development_plan_standards.md), no sprint is marked Done — or 🧪
Live-proof-pending — until its proof actually runs live on `linux-cpu`. Status transitions are recorded
reverse-chronologically here once work begins.

## Phase Summary

This phase closes the last opening in the platform cluster: it makes **Keycloak the sole authenticated door**
for every wild request. It composes the LoadBalancer address published by Phase 18 (MetalLB on `linux-cpu`)
with an **Envoy + Gateway API L7 data plane** and **Keycloak OIDC/JWT enforcement**, rendered as typed
manifests by the Phase-15 reconciler and applied to the live cluster, so that WAN, LAN, and even a
localhost-browser connection reach a platform or app surface only after traversing
`LoadBalancer → Envoy/Gateway API → Keycloak`. It then proves the harder, structural half of the invariant:
**no workload publishes its own wild ingress and no chart opens a backdoor NodePort** — the sole carve-out is
the host-origin, localhost-only NodePort that is a *different type* of endpoint, not a wild one. The
default-deny east-west NetworkPolicy posture, with allow-edges **derived from the declared dependency graph**,
is applied and exercised live. Finally the phase re-runs the Phase-16 lossless-rebind proof behind the new
edge, confirming the storage guarantee did not regress when the ingress door was added.

The scope stops at *the ingress door and its guarantees*. The DSL deploy through the `replicas=1` singleton,
app tenancy, and the Pulsar/workflow runtime are Phase 20+ concerns; this phase exercises the edge from the
host binary against the fixed standard service set that Phase 18 stood up. The one genuinely new-vs-prodbox
piece — the Envoy + Gateway API data plane replacing a hand-configured proxy — is the least evidence-backed
part of the set.

**Substrate:** linux-cpu (§L) — the edge is wired and gated on a single-node `kind` cluster on a linux-cpu
host, tracked in [substrates.md](substrates.md); no apple, linux-cuda, or windows substrate is touched.

**Register:** 3 (live infrastructure) — the gate drives a real edge on a real cluster and re-exercises a live
delete + recreate; a Register-1/2 in-process check cannot discharge it (though the *render-time*
impossibility of a self-published ingress was already golden-locked pre-cluster in Phase 9).

**Gate:** on the live `linux-cpu` cluster carrying the standard service stack, every wild route — WAN, LAN,
and localhost-browser — reaches a platform or app surface **only** through `LoadBalancer → Envoy/Gateway API →
Keycloak`; an unauthenticated request to any surface is rejected at that edge; **no workload or chart can
publish its own wild ingress** or open a backdoor NodePort (the sole exception being the host-origin,
localhost-only NodePort, a distinct endpoint type); and the **Phase-16 storage-rebind regression still holds**
— a marker row in the Keycloak Patroni DB and a marker object in MinIO survive a cluster delete + recreate
byte-for-byte.

## Doctrine adopted

- [`platform_services_doctrine.md` §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
  — **the LoadBalancer and the single wild-ingress path**: this phase materializes the one sanctioned ingress
  shape (`LoadBalancer → Envoy/Gateway API → Keycloak`), its **east-west connectivity derived from the declared
  dependency graph** subsection, and the [§11 bring-up ordering edges](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
  that place the LB address before the Gateway listener and Keycloak before the edge admits wild traffic.
- [`illegal_state_catalog.md` §3.7](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)
  — **accidental insecure / backdoor ingress**: a workload cannot publish its own wild ingress because
  `WildIngress` is a Keycloak-edge-only construct and the host-origin, localhost-only NodePort is a distinct
  `HostLocalPeer` endpoint that does not interconvert; this phase is the live realization of that
  render-foreclosed impossibility (and of [§3.6](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other),
  the derived-allow-edge NetworkPolicy rule).
- [`manifest_generation_doctrine.md` §5](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)
  — **the apply/reconcile engine**: the Gateway, `HTTPRoute`, Keycloak, and the derived NetworkPolicies are
  typed `K8sObject`s rendered by `render` and enacted by the Phase-15 server-side-apply reconciler under the
  fixed `amoebius` field manager — no Helm, no hand-authored YAML.
- [`pulumi_iac_doctrine.md` §5](../documents/engineering/pulumi_iac_doctrine.md#5-dns-route53-and-tls-zerossl-the-provider-integrations-this-doctrine-owns)
  — **DNS (route53) and TLS (zerossl)**: the public-edge TLS wired through the edge is *referenced*, not
  re-specified here; certificate provisioning is owned by the Pulumi/IaC doctrine, and the ZeroSSL EAB material
  is a Vault `SecretRef`, never a Dhall literal.
- [`storage_lifecycle_doctrine.md` §6](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind)
  — **the lossless-teardown guarantee: deterministic rebind**: the gate re-runs the Phase-16 marker-bytes
  round-trip across a delete + recreate to confirm adding the edge introduced no storage regression.

## Sprints

## Sprint 19.1: The Keycloak-owned edge — LoadBalancer → Envoy/Gateway API → Keycloak 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Edge.hs`, `src/Amoebius/Platform/Keycloak.hs` (target paths; not yet built)
**Blocked by**: Phase 18 gate (external prereq — the standard service stack is HA-up, publishing a MetalLB LB address and a Keycloak Patroni DB), Phase 17 gate (external prereq — Vault serves Keycloak's DB password and the edge TLS material as `SecretRef`s)
**Independent Validation**: the only reachable wild path is `LoadBalancer → Envoy/Gateway API → Keycloak`; an unauthenticated request to a platform browser surface (e.g. Grafana) is rejected/redirected at the edge, never served; the readiness DAG observes the LB address before the Gateway publishes its listener and Keycloak ready before the edge admits wild traffic.

**Docs to update**: `documents/engineering/platform_services_doctrine.md`

### Objective
Adopt [`platform_services_doctrine.md` §9 — the LoadBalancer and the single wild-ingress path](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path):
make Keycloak the single authenticated ingress point, fronted by Envoy + the Gateway API, atop the
MetalLB LoadBalancer — the one substrate-driven difference — with the [§11 ordering edges](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
observed as readiness conditions, not durations.

### Deliverables
- Envoy + Gateway API rendered as the L7 edge (a `Gateway` listener plus `HTTPRoute`s as typed `K8sObject`s),
  terminating TLS and routing, applied by the Phase-15 reconciler.
- Keycloak deployed against its Phase-18 Patroni DB, owning OIDC/JWT enforcement in front of every platform
  browser surface, so an unauthenticated request never reaches a workload.
- The readiness edges wired into the derived DAG: MetalLB address before the Gateway listener; Keycloak ready
  before the edge admits wild traffic — never a `threadDelay`.

### Validation
1. Assert `LoadBalancer → Envoy/Gateway API → Keycloak` is the only reachable wild path.
2. Send an unauthenticated request to a platform surface; assert it is rejected/redirected at the edge.
3. Assert the bring-up honoured the ordering edges (LB address, then Gateway listener; Keycloak, then wild admit).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 19.2: No self-published wild ingress + public-edge TLS 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Edge.hs`, `src/Amoebius/Platform/Tls.hs` (target paths; not yet built)
**Blocked by**: Sprint 19.1
**Independent Validation**: a live scan finds no non-Keycloak wild path — no service exposes a backdoor NodePort to WAN/LAN; the render layer cannot express a workload-owned wild `Ingress` (`WildIngress` is a Keycloak-edge-only construct); the sole carve-out is the host-origin, localhost-only NodePort, a distinct `HostLocalPeer` endpoint; public-edge TLS chains via ZeroSSL with the EAB material read from Vault.

**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/illegal_state/illegal_state_catalog.md`, `documents/engineering/pulumi_iac_doctrine.md`

### Objective
Adopt [`illegal_state_catalog.md` §3.7 — accidental insecure / backdoor ingress](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)
live, together with the public-edge TLS integration of
[`pulumi_iac_doctrine.md` §5 — DNS (route53) and TLS (zerossl)](../documents/engineering/pulumi_iac_doctrine.md#5-dns-route53-and-tls-zerossl-the-provider-integrations-this-doctrine-owns):
prove on the running cluster that the render-time impossibility of a self-published ingress holds, and that the
one carve-out really is a *different type* of endpoint, not a wild one.

### Deliverables
- A live audit proving there is no non-Keycloak wild path: no chart opens a backdoor NodePort to the wild, and
  no workload publishes its own `Ingress` — the `WildIngress` constructor is reachable only from the Keycloak
  edge, per the render invariant golden-locked in Phase 9.
- The sole carve-out exercised as a distinct `HostLocalPeer` endpoint (host-origin, localhost-only NodePort, no
  mTLS, no WAN/LAN reach) — owned in full by [`host_cluster_comms_doctrine.md`](../documents/engineering/host_cluster_comms_doctrine.md)
  and referenced here, not re-specified.
- Public-edge TLS (ZeroSSL via DNS, route53) wired through the edge, with the EAB material a Vault `SecretRef`;
  the provisioning itself is owned by the Pulumi/IaC doctrine and referenced.

### Validation
1. Scan the live cluster; assert no exposed backdoor NodePort and no non-Keycloak wild route.
2. Assert the host-origin, localhost-only NodePort is unreachable off the host (no WAN/LAN access).
3. Assert the public edge presents a ZeroSSL-issued certificate whose EAB material came from Vault, not Dhall.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 19.3: East-west NetworkPolicy posture — derived default-deny 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/NetworkPolicy.hs`, `src/Amoebius/Platform/Edge.hs` (target paths; not yet built)
**Blocked by**: Sprint 19.1
**Independent Validation**: after apply, a pod that declares consuming service `B` reaches `B`, a pod that does not is denied, and a probe to an undeclared edge times out; the applied policy set is byte-derived from the declared dependency graph, never hand-authored.

**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/illegal_state/illegal_state_catalog.md`

### Objective
Adopt the **east-west connectivity is derived from the dependency graph** subsection of
[`platform_services_doctrine.md` §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
and [`illegal_state_catalog.md` §3.6 — blocking NetworkPolicy, services can't reach each other](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other):
apply the default-deny + derived-allow NetworkPolicy posture live, so exactly the declared edges are allowed
and every other is denied.

### Deliverables
- A default-deny east-west baseline plus allow-edges derived from the declared dependency graph, rendered by
  the Phase-15 reconciler and applied to the live cluster — no hand-authored policy.
- The live posture: a service that does not declare consuming `B` cannot reach `B`, and a declared edge is not
  severed — the two shapes [§3.6](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other)
  makes unrepresentable at authoring time, now confirmed on the running cluster.

### Validation
1. Assert a declared consumer reaches its provider through the applied policy.
2. Assert a probe to an undeclared east-west edge is denied (times out).
3. Assert the applied policy set is derived from the dependency graph, not hand-edited.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 19.4: The single-door + storage-rebind regression gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Edge.hs`, `test/live/IngressRebindGate.hs` (target paths; not yet built)
**Blocked by**: Sprint 19.1, Sprint 19.2, Sprint 19.3, Phase 16 gate (external prereq — the no-provisioner retained-storage lossless rebind the regression reuses)
**Independent Validation**: the gate harness proves both halves in one run — the single-door invariant end-to-end (unauthenticated request rejected at the edge, no non-Keycloak wild path) and the marker-bytes round-trip surviving a cluster delete + recreate (the Phase-16 regression).

**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/storage_lifecycle_doctrine.md`

### Objective
Adopt [`storage_lifecycle_doctrine.md` §6 — the lossless-teardown guarantee: deterministic rebind](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind)
alongside [`platform_services_doctrine.md` §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path):
close the phase by proving the single Keycloak door end-to-end **and** that adding the edge did not regress the
deterministic storage rebind.

### Deliverables
- The phase-gate harness: assert an unauthenticated request to any platform surface is rejected at the edge and
  there is no non-Keycloak wild path (no exposed backdoor NodePort).
- The storage-rebind regression: write a marker row into the Keycloak Patroni DB and a marker object into a
  MinIO bucket, `cluster delete` (claims released, PVs `Retained`), `cluster recreate`, then read the same
  bytes back — the Phase-16 guarantee re-run behind the new edge.

### Validation
1. Assert the single-door invariant holds end-to-end (unauthenticated request rejected; no backdoor wild path).
2. Run the marker-bytes write → delete → recreate → read cycle; assert the bytes are unchanged.
3. Assert the full stack is still up, reachable only through the Keycloak edge, and HA-shaped after the recreate.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update:**
- `documents/engineering/platform_services_doctrine.md` — when this phase lands, the §9 single-wild-ingress
  honesty note and the §11 ordering edges flip from "design intent" to a delivered-status pointer (status stays
  in the plan); the east-west-derived-NetworkPolicy subsection gains its first live amoebius realization.
- `documents/illegal_state/illegal_state_catalog.md` — record that §3.7 (backdoor ingress) and §3.6 (blocking
  NetworkPolicy) gain their first *live* confirmation here, complementing the render-time golden lock from
  Phase 9.
- `documents/engineering/pulumi_iac_doctrine.md` — note that the §5 public-edge TLS (ZeroSSL/route53)
  integration is first wired through a live edge in this phase, with the EAB material sourced from Vault.
- `documents/engineering/storage_lifecycle_doctrine.md` — record that the §6 lossless-rebind guarantee is
  re-exercised behind the ingress edge as a regression check.

**Cross-references to add:**
- [README.md](README.md) — flip the Phase 19 row status once work begins, and link this document from the
  Phase 19 paragraph.
- [substrates.md](substrates.md) — record `linux-cpu` as the Phase 19 gate substrate in the per-phase map.
- [system_components.md](system_components.md) — register the target paths named in the sprint `Implementation`
  fields (`Amoebius.Platform.Edge`, `Amoebius.Platform.Keycloak`, `Amoebius.Platform.Tls`,
  `Amoebius.Manifest.NetworkPolicy`).

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 19 row is the authoritative one-line gate and status.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  Register-3 honesty token: a passed gate is a live-substrate result, never a compile claim).
- [overview.md](overview.md) — the target architecture and the cross-cutting "Keycloak owns all wild ingress"
  invariant this phase realizes.
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — §9 the single
  wild-ingress path and §11 the bring-up ordering adopted here.
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — §3.7 backdoor ingress and §3.6
  blocking NetworkPolicy, the impossibilities confirmed live here.
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — the typed renderer
  + server-side-apply reconciler that enacts the edge (delivered in Phase 15).
- [Pulumi IaC Doctrine](../documents/engineering/pulumi_iac_doctrine.md) — §5 the DNS/TLS provider integration
  referenced for the public edge.
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — §6 the lossless-rebind
  guarantee re-exercised as the regression clause.
- [Host ↔ Cluster Comms Doctrine](../documents/engineering/host_cluster_comms_doctrine.md) — the sole
  host-origin, localhost-only carve-out from "Keycloak owns all wild ingress".
