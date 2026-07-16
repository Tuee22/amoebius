# Phase 21: Keycloak-owned ingress

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_19_platform_backbone.md, DEVELOPMENT_PLAN/phase_20_platform_services_2.md, DEVELOPMENT_PLAN/phase_22_live_dsl_singleton.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Wire the single Keycloak-owned wild-ingress door — LoadBalancer → Envoy/Gateway API →
> Keycloak — on the standard service stack, prove no workload can publish its own wild ingress, and confirm the
> retained-storage rebind regression still holds behind the new edge.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is design intent and every prescriptive
statement is a target shape, never a tested amoebius result. The gate has not run on any substrate. The
substrate is **linux-cpu**: the edge is wired and gated on the single-node `kind` cluster carrying the
Phase-19/20 standard service stack. Keycloak owning all wild ingress is **sibling evidence, not an amoebius result** —
prodbox proved a Keycloak-as-the-only-door edge, and its Patroni-backed Keycloak is the proven relational
consumer — while the Envoy + Gateway API L7 data plane and the derived-from-the-dependency-graph east-west
NetworkPolicy posture are amoebius-shaped and unproven here. Per
[development_plan_standards.md §K](development_plan_standards.md), no sprint is marked Done — or 🧪
Live-proof-pending — until its proof actually runs live on `linux-cpu`. Status transitions are recorded
reverse-chronologically here once work begins.

## Phase Summary

This phase closes the last opening in the platform cluster: it makes **Keycloak the sole authenticated door**
for every wild request. It composes the LoadBalancer address published by Phase 19 (MetalLB on `linux-cpu`)
with an **Envoy + Gateway API L7 data plane** and **Keycloak OIDC/JWT enforcement**, rendered as typed
manifests by the Phase-16 reconciler and applied to the live cluster, so that WAN, LAN, and even a
localhost-browser connection reach a platform or app surface only after traversing
`LoadBalancer → Envoy/Gateway API → Keycloak`. It then proves the harder, structural half of the invariant:
**no workload publishes its own wild ingress and no chart opens a backdoor NodePort** — the sole carve-out is
the host-origin, localhost-only NodePort that is a *different type* of endpoint, not a wild one. The
default-deny east-west NetworkPolicy posture, with allow-edges **derived from the declared dependency graph**,
is applied and exercised live. Finally the phase re-runs the Phase-17 lossless-rebind proof behind the new
edge, confirming the storage guarantee did not regress when the ingress door was added.

The scope stops at *the ingress door and its guarantees*. The DSL deploy through the `replicas=1` singleton,
app tenancy, and the Pulsar/workflow runtime are Phase 22+ concerns; this phase exercises the edge from the
host binary against the fixed standard service set that Phases 19–20 stood up. The one genuinely new-vs-prodbox
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
localhost-only NodePort, a distinct endpoint type); and the **Phase-17 storage-rebind regression still holds**
— a marker row in the Keycloak Patroni DB and a marker object in MinIO survive a cluster delete + recreate
byte-for-byte.

The gate is not discharged by a deny-all edge, a self-authored clean scan, a circular "derived" assertion, or
a skipped teardown. It positively exercises OIDC enforcement, validates its own scanners against committed
seeded violations, oracles "derived" against an independent graph-walk, and witnesses that a genuinely new
cluster came up. See **Gate integrity** below.

### Representative set (concrete corpus, §M.7)

The gate's "every wild route / every surface" quantifies over an **explicitly enumerated, Phase-0-committed
route inventory** — `test/fixtures/phase21/route-inventory.golden` — listing every browser surface on the
Phase-19/20 standard service stack that the edge fronts: **Grafana, the Keycloak admin console, the Vault UI, the
MinIO console, and the platform API surface** (the exact set is the golden; if the stack's surface set changes,
the golden is re-authored and re-committed, never regenerated from the running edge). The three origin classes
— WAN, LAN, localhost-browser — are each probed from a **distinct Linux network namespace / sidecar container**
attached to a separate veth with a non-loopback source address for WAN/LAN and the host loopback for
localhost-browser; a single host-side `curl` of the MetalLB address is **not** an acceptable stand-in for all
three. The "test-realm user" is the Phase-0-committed `phase21-tester` realm/user fixture
(`test/fixtures/phase21/realm.json`), authored before the edge exists.

### Gate integrity (§M)

- **Oracle-pinning (§M.1):** the route inventory (`route-inventory.golden`), the test realm/user
  (`realm.json`), the expected derived-NetworkPolicy set (`netpol-expected.json`, see 21.3), and the marker
  payloads (`marker-row.sql`, `marker-object.bin`) are authored and committed in Phase 0 before
  `Amoebius.Platform.Edge`/`Keycloak`/`NetworkPolicy` exist; none is regenerated from the implementation.
- **Committed seeded mutants (§M.2):** at least three committed mutants must go red — (a) an edge variant that
  removes the Keycloak OIDC/JWT filter (guard delete) so an unauthenticated probe reaches a surface; (b) a
  `derive` variant that drops one allow-edge and adds one undeclared allow-edge (union-arm swap) so the
  independent graph-walk set-equality fails; (c) a regression-harness variant that no-ops `cluster delete`
  (dropped effect) so the recreate-witness check finds an identical cluster identity. Each is committed and
  re-run, not a one-off strawman.
- **Independent oracle (§M.3):** the derived-NetworkPolicy check and the route-coverage check compare against
  the committed hand tables / an independent graph-walker (a code path distinct from `render`), never the
  reconciler's own fold.
- **External-observer traces (§M.5):** reachability, off-host-unreachability, ordering-enforcement, and
  EAB-provenance assertions read from OS-boundary observers (per-origin netns probe exit codes, an argv/env
  recording shim on the ACME client, a readiness-withholding harness), never a compliance trace the edge emits
  about itself.

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
  typed `K8sObject`s rendered by `render` and enacted by the Phase-16 server-side-apply reconciler under the
  fixed `amoebius` field manager — no Helm, no hand-authored YAML.
- [`pulumi_iac_doctrine.md` §5](../documents/engineering/pulumi_iac_doctrine.md#5-dns-route53-and-tls-zerossl-the-provider-integrations-this-doctrine-owns)
  — **DNS (route53) and TLS (zerossl)**: the public-edge TLS wired through the edge is *referenced*, not
  re-specified here; certificate provisioning is owned by the Pulumi/IaC doctrine, and the ZeroSSL EAB material
  is a Vault `SecretRef`, never a Dhall literal.
- [`storage_lifecycle_doctrine.md` §6](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind)
  — **the lossless-teardown guarantee: deterministic rebind**: the gate re-runs the Phase-17 marker-bytes
  round-trip across a delete + recreate to confirm adding the edge introduced no storage regression.

## Sprints

## Sprint 21.1: The Keycloak-owned edge — LoadBalancer → Envoy/Gateway API → Keycloak 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Edge.hs`, `src/Amoebius/Platform/Keycloak.hs` (target paths; not yet built)
**Blocked by**: Phase 19 gate (external prereq — the backbone is HA-up and publishes a MetalLB address), Phase
20 gate (external prereq — the Percona/Patroni database layer is HA-up), Phase 18 gate (external prereq — Vault
serves Keycloak's DB password and the edge TLS material as `SecretRef`s)
**Independent Validation**: for every surface in the committed `route-inventory.golden`, a real OIDC login as the Phase-0 `phase21-tester` user yields the surface's content (2xx) **only** after traversing Keycloak, while an unauthenticated probe to the same route is rejected/redirected to the Keycloak login (positive enforcement, not a vacuous deny-all); the only reachable wild path is `LoadBalancer → Envoy/Gateway API → Keycloak`, confirmed per origin class from a distinct netns probe; the readiness DAG is proven by an **enforced-gating** experiment — the LB address and Keycloak readiness are withheld and the dependent step is observed (by an external harness) to block rather than proceed — not by post-hoc reading the implementation's own event log.

**Docs to update**: `documents/engineering/platform_services_doctrine.md`

### Objective
Adopt [`platform_services_doctrine.md` §9 — the LoadBalancer and the single wild-ingress path](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path):
make Keycloak the single authenticated ingress point, fronted by Envoy + the Gateway API, atop the
MetalLB LoadBalancer — the one substrate-driven difference — with the [§11 ordering edges](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
observed as readiness conditions, not durations.

### Deliverables
- Envoy + Gateway API rendered as the L7 edge (a `Gateway` listener plus `HTTPRoute`s as typed `K8sObject`s),
  terminating TLS and routing, applied by the Phase-16 reconciler.
- Keycloak deployed against its Phase-20 Patroni DB, owning OIDC/JWT enforcement in front of every platform
  browser surface, so an unauthenticated request never reaches a workload.
- The readiness edges wired into the derived DAG: MetalLB address before the Gateway listener; Keycloak ready
  before the edge admits wild traffic — never a `threadDelay`.
- The Phase-0-committed oracle fixtures this sprint checks against: `test/fixtures/phase21/route-inventory.golden`
  (the explicit surface set) and `test/fixtures/phase21/realm.json` (the `phase21-tester` realm/user), both
  authored before `Amoebius.Platform.Edge`/`Keycloak` exist; plus committed mutant (a) — an OIDC-filter-removed
  edge variant the gate must show going red.

### Validation
1. For each surface enumerated in the committed `route-inventory.golden`, complete a real OIDC login as
   `phase21-tester` and assert the surface's content is served (2xx) only after the request traversed Keycloak;
   assert `LoadBalancer → Envoy/Gateway API → Keycloak` is the only reachable wild path, probed once per origin
   class (WAN, LAN, localhost-browser) from a distinct netns/sidecar with the origin-appropriate source address.
2. Send an unauthenticated request to each surface; assert it is redirected to the Keycloak login (a specific
   302/401 to the Keycloak authorize endpoint), never served the surface — this fails against committed mutant
   (a) (OIDC filter removed), which the gate must show turning red.
3. Assert the bring-up honoured the ordering edges by an **enforced-gating** experiment: withhold the MetalLB LB
   address and assert (via an external readiness harness) the Gateway listener step blocks; withhold Keycloak
   readiness and assert the wild-admit step blocks; then release each and assert progress. A post-hoc scan of
   the render source shows **no `threadDelay`** on these edges. Passing by ordering the implementation's own
   happy-path event log is not sufficient.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 21.2: No self-published wild ingress + public-edge TLS 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Edge.hs`, `src/Amoebius/Platform/Tls.hs` (target paths; not yet built)
**Blocked by**: Sprint 21.1
**Independent Validation**: the live scan is itself validated against a **committed seeded violation** — an out-of-band NodePort/`Ingress` applied via raw `kubectl` (bypassing the DSL) makes the scan go red and the ledger record it, and its removal restores green — so a scan that greps a label the renderer never emits cannot pass vacuously; with the seed removed, the scan finds no non-Keycloak wild path (no service exposes a backdoor NodePort reachable from a WAN/LAN netns probe); the render layer cannot express a workload-owned wild `Ingress` (`WildIngress` is a Keycloak-edge-only construct); the sole carve-out is the host-origin, localhost-only NodePort, proven unreachable by a **real probe from a non-host source IP** (a distinct netns with a non-loopback address), not by inspecting the Service/listener bind config; public-edge TLS chains through an ACME issuance whose EAB material is proven — by an **argv/env-recording shim on the ACME client** — to be read from a Vault `SecretRef`, with the rendered Dhall grepped to confirm no EAB literal.

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
- The committed scanner-validation seed (`test/fixtures/phase21/backdoor-seed.yaml`, a raw-`kubectl`
  NodePort/`Ingress` bypass authored in Phase 0) and the argv/env-recording ACME shim used to observe EAB
  provenance from the OS boundary.

### Validation
1. First validate the scanner: apply a committed out-of-band NodePort/`Ingress` seed via raw `kubectl` (not the
   DSL) that opens a WAN/LAN-reachable bypass; assert the scan turns **red** and the ledger records the
   violation; remove the seed and assert **green**. Then, with no seed present, scan the live cluster and assert
   no exposed backdoor NodePort and no non-Keycloak wild route.
2. Assert the host-origin, localhost-only NodePort is unreachable off the host by an **actual probe from a
   distinct network namespace with a non-loopback source IP** (which must fail/time out) paired with a
   host-loopback probe that succeeds — differing only in origin; inspecting the bind config alone is not
   sufficient.
3. Assert the ACME client obtained its EAB material from a Vault `SecretRef`, observed via an **argv/env
   recording shim** on the client process (the shim shows the SecretRef path, never a literal), and grep the
   rendered Dhall to assert no EAB literal appears. **Scope for the linux-cpu kind gate:** a staging/stand-in
   ACME chain is acceptable in place of live public ZeroSSL/route53 issuance (no public DNS zone is required);
   the load-bearing assertion is the **provenance of the EAB material (Vault, not Dhall)**, not that the cert
   was signed by production ZeroSSL.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 21.3: East-west NetworkPolicy posture — derived default-deny 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/NetworkPolicy.hs`, `src/Amoebius/Platform/Edge.hs` (target paths; not yet built)
**Blocked by**: Sprint 21.1
**Independent Validation**: "derived" is oracled two ways that a hardcoded static allow-list cannot satisfy. (1) **Graph variation:** the gate deploys a scratch consumer workload, adds a declared consuming edge to a provider, re-renders/re-applies, and asserts both the applied policy set **and** live reachability flip on; then removes the edge and asserts denial returns — so the policy must be a total function of the graph, not the fixed Phase-19/20 service names. (2) **Independent set-equality:** the applied policies are compared for set equality against the Phase-0-committed `netpol-expected.json` and against a **separate graph-walker** over the declared dependency edges (a code path distinct from `render`), never the reconciler's own fold. After apply, a pod declaring consumer of `B` reaches `B`, a pod that does not is denied, and a probe to an undeclared edge times out.

**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/illegal_state/illegal_state_catalog.md`

### Objective
Adopt the **east-west connectivity is derived from the dependency graph** subsection of
[`platform_services_doctrine.md` §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
and [`illegal_state_catalog.md` §3.6 — blocking NetworkPolicy, services can't reach each other](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other):
apply the default-deny + derived-allow NetworkPolicy posture live, so exactly the declared edges are allowed
and every other is denied.

### Deliverables
- A default-deny east-west baseline plus allow-edges derived from the declared dependency graph, rendered by
  the Phase-16 reconciler and applied to the live cluster — no hand-authored policy.
- The live posture: a service that does not declare consuming `B` cannot reach `B`, and a declared edge is not
  severed — the two shapes [§3.6](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other)
  makes unrepresentable at authoring time, now confirmed on the running cluster.
- The Phase-0-committed expected-policy oracle `test/fixtures/phase21/netpol-expected.json`, an independent
  graph-walker (a code path distinct from `render`) that recomputes the expected allow-set from the declared
  dependency edges, and committed mutant (b) — a `derive` variant that drops one allow-edge and adds one
  undeclared allow-edge, which the set-equality check must show going red.

### Validation
1. Assert a declared consumer reaches its provider through the applied policy.
2. Assert a probe to an undeclared east-west edge is denied (times out).
3. Prove "derived" by **graph variation**: deploy a scratch consumer, add a declared edge to a provider,
   re-render/re-apply, and assert the applied policy set gains exactly the corresponding allow and live
   reachability flips on; remove the edge and assert the allow is withdrawn and reachability flips off. This
   fails against committed mutant (b) (drop one allow, add one undeclared allow), which the gate must show going
   red.
4. Assert set equality between the applied policies and the Phase-0-committed `netpol-expected.json` **and** the
   output of an **independent graph-walker** (distinct from `render`) over the declared dependency edges — not
   by re-running the implementation's own `derive`.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 21.4: The single-door + storage-rebind regression gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Edge.hs`, `test/live/IngressRebindGate.hs` (target paths; not yet built)
**Blocked by**: Sprint 21.1, Sprint 21.2, Sprint 21.3, Phase 17 gate (external prereq — the no-provisioner retained-storage lossless rebind the regression reuses)
**Independent Validation**: the gate harness proves both halves in one run — the single-door invariant
end-to-end (unauthenticated request rejected at the edge, positive OIDC round-trip served for the committed
route inventory, no non-Keycloak wild path) and the marker-bytes round-trip surviving a **witnessed** cluster
delete + recreate. Before full cluster deletion, the harness performs Phase 17's intermediate PVC-delete
observation against the still-running old apiserver: it quiesces the witnesses, drives each through its
**owning resource's supported stop path** (the operator-owned Patroni witness through its
`PerconaPGCluster`/operator path, never by mutating the operator's child StatefulSet; the directly owned MinIO
witness through its StatefulSet), waits until no Pod references the PVCs, then deletes the PVCs; the PVCs
disappear, the old-cluster PV objects report `Released`, and the backing bytes remain intact. It then performs
`cluster delete` and confirms from the host boundary that the old cluster, node container, and apiserver are absent.
After `cluster recreate`, it records a **recreate witness** in the ledger — the recreated cluster's identity
differs (new cluster CA / kube-system pod UIDs / `kind` node container ID) — before the read-back counts. A
harness that skips the delete or reads back from the same never-torn-down cluster fails this witness.

**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/storage_lifecycle_doctrine.md`

### Objective
Adopt [`storage_lifecycle_doctrine.md` §6 — the lossless-teardown guarantee: deterministic rebind](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind)
alongside [`platform_services_doctrine.md` §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path):
close the phase by proving the single Keycloak door end-to-end **and** that adding the edge did not regress the
deterministic storage rebind.

### Deliverables
- The phase-gate harness: assert an unauthenticated request to any platform surface is rejected at the edge and
  there is no non-Keycloak wild path (no exposed backdoor NodePort).
- The storage-rebind regression: write the committed marker row (`marker-row.sql`) into the Keycloak Patroni DB
  and the committed marker object (`marker-object.bin`) into a MinIO bucket; perform the Phase-17 intermediate
  observation while the old apiserver is still running by quiescing the witnesses, stopping each through its
  owning resource's supported path (operator-mediated for Patroni; directly owned StatefulSet for MinIO),
  waiting until no Pod references the PVCs, deleting the PVCs, and observing the old PV objects `Released`;
  then `cluster delete` and prove the old cluster absent; `cluster recreate`,
  re-render/re-apply fresh PV objects over the retained backing, record the new cluster identity, and read the
  same bytes back — the Phase-17 guarantee re-run behind the new edge; plus committed mutant (c), a
  delete-no-op harness variant the recreate-witness check must show going red.

### Validation
1. Assert the single-door invariant holds end-to-end: an unauthenticated request is rejected at the edge, a real
   OIDC login as `phase21-tester` serves each surface in `route-inventory.golden`, and there is no backdoor wild
   path (scanner first validated against the committed `backdoor-seed.yaml`, per 21.2).
2. Run the marker-bytes (committed `marker-row.sql` / `marker-object.bin`) write → quiesce/owner-mediated stop
   → wait for zero Pod references → live PVC-delete/`Released` observation → full cluster delete/absence
   witness → recreate/re-apply → read cycle. Observe `Released` only after the consuming Pods have terminated
   and while the old apiserver remains live; after full deletion, assert from the host boundary that the
   cluster is absent and the retained backing bytes remain. Record the recreate witness (new cluster CA /
   kube-system pod UIDs / `kind` node container ID differ from pre-delete) in the ledger, then assert the
   read-back bytes are unchanged. This fails against committed mutant (c) (delete no-op'd), which the gate
   must show going red because the recreate witness finds an identical cluster identity.
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
- [README.md](README.md) — flip the Phase 21 row status once work begins, and link this document from the
  Phase 21 paragraph.
- [substrates.md](substrates.md) — record `linux-cpu` as the Phase 21 gate substrate in the per-phase map.
- [system_components.md](system_components.md) — register the target paths named in the sprint `Implementation`
  fields (`Amoebius.Platform.Edge`, `Amoebius.Platform.Keycloak`, `Amoebius.Platform.Tls`,
  `Amoebius.Manifest.NetworkPolicy`).

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 21 row is the authoritative one-line gate and status.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  Register-3 honesty token: a passed gate is a live-substrate result, never a compile claim).
- [overview.md](overview.md) — the target architecture and the cross-cutting "Keycloak owns all wild ingress"
  invariant this phase realizes.
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — §9 the single
  wild-ingress path and §11 the bring-up ordering adopted here.
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — §3.7 backdoor ingress and §3.6
  blocking NetworkPolicy, the impossibilities confirmed live here.
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — the typed renderer
  + server-side-apply reconciler that enacts the edge (delivered in Phase 16).
- [Pulumi IaC Doctrine](../documents/engineering/pulumi_iac_doctrine.md) — §5 the DNS/TLS provider integration
  referenced for the public edge.
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — §6 the lossless-rebind
  guarantee re-exercised as the regression clause.
- [Host ↔ Cluster Comms Doctrine](../documents/engineering/host_cluster_comms_doctrine.md) — the sole
  host-origin, localhost-only carve-out from "Keycloak owns all wild ingress".
