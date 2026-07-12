# Phase 27: WireGuard network fabric

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_28_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Stand up the raw-kernel WireGuard fabric configured directly by amoebius — Vault-KV Curve25519 peer keys named by `SecretRef`, per-peer config *rendered* from the node inventory and reconciled by the singleton, a hub bound to the gateway *role* — so every cluster (root included) draws a VPN IP from the root-deployed gateway and the hub is reachable across the fabric.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase runs on the **linux-cpu** substrate in
**Register 3** — live infrastructure: it configures a real kernel WireGuard interface and asserts reachability
over the VPN with an external-observer probe. It opens after Phase 18 (root Vault/PKI — the KV custody of the
Curve25519 peer keys) and Phase 22 (the control-plane singleton whose reconcile loop renders and enacts the
peer config), and it **precedes** Phase 28 (the gateway migration that repoints the WireGuard hub).

## Phase Summary

This phase delivers the inter-node / inter-cluster network fabric as **raw kernel WireGuard configured directly
by amoebius — never Netmaker**. The root node deploys an HA cluster that configures a WireGuard *gateway*, and
every cluster in the forest — the root included — receives a VPN IP from that gateway; the gateway node is the
**hub**, bound to the gateway *role* rather than to a fixed cluster, so the flattened mesh moves with the
gateway on a later migration.

WireGuard fits the amoebius disciplines because it is a *primitive*, not a platform. Its three obligations map
onto machinery amoebius already owns: (1) **keys** are raw Curve25519 static keypairs custodied as a **Vault-KV
secret class** — Vault mints and holds each keypair, the Dhall names it by `SecretRef` only, and the parent
injects it into a child's Vault (they are *not* X.509 PKI certs, and never gate an unseal); (2) **peer config**
is `render(nodeInventory) -> [WireGuardPeerConfig]`, the pure-`render()` discipline lifted to `wg` config, so a
keyless peer is type-foreclosed (unrepresentable) and overlapping VPN IPs / an `AllowedIPs` outside the fabric
CIDR are decode-foreclosed (a total fold returning `Left`); (3) **distribution** is the singleton's ordinary
`discover (wg show) → diff against render(inventory) → enact (wg set)` reconcile — no Netmaker agent, no second
control server, no MQTT push channel, no second state store.

The design half of the render obligation is discharged in the pre-cluster band (Registers 1–2, substrate
`none`): the typed decoder (Phase 5), the illegal-state corpus (Phase 6), and the pure `render` goldens
(Phase 9) already establish, in-process, that a keyless peer will not construct and an overlapping-IP peer set
will not decode. Phase 27 adds the **runtime residue**: a real `wg0` interface on each node, brought up by the
singleton reconcile, over which a spoke actually reaches the hub at its VPN IP. VPN-IP allocation is by disjoint
per-cluster sub-ranges of the fabric CIDR — the same disjoint-namespace allocation the failover doctrine uses,
so two clusters can never mint the same VPN IP (confluent by construction). The cross-cluster **broker↔broker**
geo-replication wire is *not* delivered here — its per-peer `render()` obligation is deferred to Phase 28; the
two spans this phase renders are the remote-worker↔home attach carrier and the fabric-bound listener boundary.
The gateway-migration hub *repoint* is likewise Phase 28; this phase establishes the static fabric it will
later move.

**Substrate:** linux-cpu — the single-node `kind` host of Phases 14–22, whose kernel provides the WireGuard
module; the representative fabric is two peers (a gateway-role hub node and one spoke) each in its own Linux
network namespace on that host. No apple, linux-cuda, or windows substrate is exercised by this phase's gate.

**Register:** 3 — live infrastructure (§K). The type-foreclosed and decode-foreclosed layers were proven for
the model in the pre-cluster band; the runtime layer (the tunnel coming up and carrying traffic) is **tested**
on linux-cpu, never *proven*.

**Gate:** on the linux-cpu host, the singleton renders each peer config from **Vault-KV Curve25519 keys named
by `SecretRef` only** and reconciles **raw-kernel WireGuard** so every peer draws its VPN IP from the
gateway-role hub and the hub peer is reachable across the fabric; a **committed golden** pins the rendered peer
config; the **hub-role attach is asserted by an external-observer reachability probe over the VPN IP** (an
OS-level connect + underlay packet capture, never a singleton self-report); **≥1 committed seeded mutant** — a
missing/rotated peer key, or a hub-role config that omits its `Endpoint` — MUST turn the gate red; and
**secrets-in-Dhall is foreclosed** (an inline key literal is rejected; peer keys are `SecretRef` names) — a
**Register-3** live-infrastructure check.

**Gate-integrity clauses (§M).** The gate is hardened as follows and passes only when every clause below holds:

- **Concrete representative set (§M.7).** "the fabric" is exactly the two-peer topology of
  `dhall/examples/wireguard_fabric.dhall`: one **gateway-role hub** node (holding a stable hub VPN-IP + stable
  `Endpoint`) and one **spoke** node, each drawing its VPN IP from its cluster's disjoint sub-range of the
  fabric CIDR, each peer keyed by a distinct Vault-KV Curve25519 keypair named by `SecretRef`. No other topology
  satisfies the gate. "reachable across the fabric" is pinned to the spoke opening a socket to the hub's VPN-IP
  on a `wg0`-bound listener.
- **Phase-0-pinned oracle (§M.1).** The positive fixture `dhall/examples/wireguard_fabric.dhall`, the committed
  rendered-config golden `test/fixtures/phase27/expected-peer-config.golden` (key fields carried as `SecretRef`
  names, *not* key material — with the AllowedIPs, per-peer VPN-IP, and hub `Endpoint` pinned), the expected
  reachability matrix `test/fixtures/phase27/reachability-expected.json`, and the negative corpus's expected
  foreclosure-tag table `test/fixtures/phase27/negative-expected-tags.tsv` (hand-authored, independent of the
  renderer's own output — §M.3) are all **committed in Phase 0 before** `Fabric.hs`/`WgRender.hs`/`WgReconcile.hs`
  exist; none is regenerated from implementation output.
- **External-observer reachability, not a self-report (§M.5).** The hub-attach claim is read from an observer at
  the OS boundary: (a) the spoke netns issues a real transport probe (an ICMP echo *and* a TCP connect) to the
  hub's VPN-IP and the connect succeeds; (b) a `tcpdump` capture on the **underlay** interface shows the traffic
  as WireGuard UDP (encrypted), never cleartext application bytes; (c) the effective interface state is read
  from the kernel via `wg show` (the OS boundary), never from a status line the singleton emits about itself. A
  run in which reachability is asserted only by a singleton log/metric fails.
- **Committed seeded mutants (§M.2).** The gate names **≥2 committed seeded mutants** that MUST turn it red: a
  **missing/rotated peer key** mutant `test/fixtures/phase27/mutants/missing-peer-key.patch` (the spoke's
  `SecretRef` resolves to no live Vault-KV entry — reconcile cannot bring `wg0` up and the reachability probe
  fails), and a **dropped-field** mutant `test/fixtures/phase27/mutants/hub-no-endpoint.patch` (the hub-role
  peer config omits its `Endpoint`, so the spoke has no address to reach and the probe fails). Both are committed
  and re-run each gate.
- **Specific-reason negatives + secrets-in-Dhall foreclosed (§M.8).** Each negative fixture asserts **why** it
  fails against the Phase-0 oracle: an **inline key literal** (a raw Curve25519 key written into the `.dhall`
  instead of a `SecretRef` name) is rejected with its committed expected tag — secrets never live in Dhall; an
  **overlapping VPN-IP** pair and an **`AllowedIPs` outside the fabric CIDR** are decode-foreclosed with their
  committed `DecodeError` tags. Each negative is paired with a positive differing only in the foreclosed
  dimension.

## Doctrine adopted

- [`network_fabric_doctrine.md §2` — Raw WireGuard, not Netmaker](../documents/engineering/network_fabric_doctrine.md#2-raw-wireguard-not-netmaker):
  amoebius configures the raw kernel WireGuard *primitive* it owns end to end and runs none of Netmaker's
  machinery — no second control server, no second desired-state DB, no MQTT peer-push broker, no second PKI, no
  second node inventory. This phase configures `wg` directly.
- [`network_fabric_doctrine.md §3` — Keys, config, and distribution](../documents/engineering/network_fabric_doctrine.md#3-keys-config-and-distribution--wireguard-as-just-another-reconcile):
  peer keys are a **Vault-KV Curve25519 secret class** under the secrets-by-name + parent-injection model (not
  PKI certs, never gating an unseal); peer config is the pure `render(nodeInventory) -> [WireGuardPeerConfig]`
  (keyless peer type-foreclosed, overlapping IP / out-of-CIDR `AllowedIPs` decode-foreclosed); distribution is
  the singleton's `wg show → diff → wg set` reconcile, not an agent.
- [`network_fabric_doctrine.md §4` — Topology: the hub is the gateway role](../documents/engineering/network_fabric_doctrine.md#4-topology-the-hub-is-the-gateway-role-and-the-fabric-moves-with-it):
  the hub is bound to the gateway *role* at a stable VPN-IP + `Endpoint`, VPN-IP allocation is by disjoint
  per-cluster ranges (confluent by construction), and for the attach topology the home cluster is the hub. This
  phase stands up the static hub; Phase 28 later repoints it on migration.
- [`network_fabric_doctrine.md §5` — The security boundary generalizes: localhost → authenticated fabric](../documents/engineering/network_fabric_doctrine.md#5-the-security-boundary-generalizes-localhost--authenticated-fabric):
  fabric-bound listeners bind to `wg0`, never `0.0.0.0`/LAN/WAN, so the host-comms security property moves from
  "reachable only from localhost" to "reachable only over the authenticated WireGuard fabric" — Curve25519 peer
  auth + ChaCha20-Poly1305 encryption supply what the WAN removed, with no in-cluster mTLS tax reintroduced.
- [`network_fabric_doctrine.md §6` — The service-mesh verdict: no Linkerd for v1](../documents/engineering/network_fabric_doctrine.md#6-the-service-mesh-verdict-no-linkerd-for-v1):
  a service mesh is **not** adopted; the fabric this phase delivers is WireGuard, and no Linkerd sidecar fleet is
  introduced. (Cited for the boundary; no mesh component is built here.)

## Sprints

## Sprint 27.1: Vault-KV Curve25519 peer keys — secrets by name, minted and custodied in Vault 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Fabric/Keys.hs` (the Curve25519 peer-key KV secret class: mint into Vault-KV,
resolve a peer's key by `SecretRef` name at render time via the Phase-18 Vault client); the Dhall
`WireGuardPeer` schema field carrying the key as a `SecretRef` name only — target paths, not yet built.
**Blocked by**: Phase 18 gate (root Vault + the `SecretRef`-by-name Vault client — the KV store that mints and
holds the Curve25519 keypairs and the by-name reader the renderer uses).
**Independent Validation**: a peer's Curve25519 keypair is minted into Vault-KV and the renderer resolves it by
`SecretRef` name through the Phase-18 client; **no key material appears in any `.dhall`** — the schema field is a
`SecretRef` name, and an attempt to inline a raw key literal is rejected at Gate 1/Gate 2 with the committed
expected tag in `test/fixtures/phase27/negative-expected-tags.tsv`. The rotated/absent-key case (the KV entry a
`SecretRef` names does not resolve) is observable: key resolution returns a specific-reason error, never a
silent empty key.
**Docs to update**: `documents/engineering/network_fabric_doctrine.md`,
`documents/engineering/vault_pki_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`network_fabric_doctrine.md §3`](../documents/engineering/network_fabric_doctrine.md#3-keys-config-and-distribution--wireguard-as-just-another-reconcile):
custody WireGuard peer keys as a **Vault-KV Curve25519 secret class** under the secrets-by-name +
parent-injection model — Vault mints and holds each keypair, the Dhall names it by `SecretRef` only, and no
fabric key is ever an X.509 cert or an unseal gate. This foreclose-secrets-in-Dhall property is the floor the
rendered config (Sprint 27.2) stands on.

### Deliverables
- A `WireGuardPeer` Dhall schema whose key field is a **`SecretRef` name** — key material is unrepresentable in
  the spec (type-foreclosed), so secrets-in-Dhall cannot occur.
- The Curve25519 peer-key KV secret class: mint a keypair into Vault-KV, and resolve a peer's private/public key
  by `SecretRef` name at render time through the Phase-18 built-in Vault client (no agent sidecar).
- The negative fixture + Phase-0 oracle row for the inline-key-literal case (rejected with its committed
  expected tag), paired with the positive `SecretRef`-named peer differing only in that dimension.

### Validation
1. A minted peer keypair is readable from Vault-KV by `SecretRef` name and no key bytes appear in any committed
   `.dhall`; the inline-key-literal negative fixture fails at Gate 1/Gate 2 with the exact committed tag, and its
   matched positive (same peer, key by `SecretRef` name) decodes.
2. A `SecretRef` naming an absent/rotated KV entry yields a specific-reason resolution error (never an empty or
   default key), so the missing-key mutant of the gate (Sprint 27.3) has a defined failure to trip on.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 27.2: Rendered peer config + the wg reconcile — render → wg show/diff/wg set 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Fabric/WgRender.hs` (`render(nodeInventory) -> [WireGuardPeerConfig]`, the
pure total render lifted from the Phase-9 goldens); `src/Amoebius/Fabric/WgReconcile.hs` (the singleton's
`discover (wg show) → diff → enact (wg set)` reconcile of `wg0`) — target paths, not yet built.
**Blocked by**: Sprint 27.1 (the `SecretRef`-named peer keys the render resolves); Phase 22 gate (the
control-plane singleton whose reconcile loop this reconcile plugs into); Phase 9 (the pure `render` goldens
discipline this render extends).
**Independent Validation**: `render(wireguard_fabric.dhall)` produces per-peer config **byte-identical to the
committed golden** `test/fixtures/phase27/expected-peer-config.golden` (key fields carried as `SecretRef`
names, with per-peer VPN-IP, `AllowedIPs`, and the hub `Endpoint` pinned) — the golden is the Phase-0 oracle,
authored before `WgRender.hs` exists, so it cannot be a regenerated tautology (§M.1). The reconcile is
idempotent: a first pass brings `wg0` to the rendered peer set (observed via `wg show` read from the kernel, the
OS boundary — §M.5), and a second pass is a no-op (zero `wg set` mutations). Overlapping-VPN-IP and
`AllowedIPs`-outside-CIDR negatives are decode-foreclosed with their committed tags.
**Docs to update**: `documents/engineering/network_fabric_doctrine.md`,
`documents/engineering/manifest_generation_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`network_fabric_doctrine.md §3`](../documents/engineering/network_fabric_doctrine.md#3-keys-config-and-distribution--wireguard-as-just-another-reconcile)
and [`§4`](../documents/engineering/network_fabric_doctrine.md#4-topology-the-hub-is-the-gateway-role-and-the-fabric-moves-with-it):
render each peer config purely and totally from the node inventory (VPN IPs drawn from disjoint per-cluster
ranges, the hub keyed by the gateway role), and distribute it as the singleton's ordinary `wg show → diff →
wg set` reconcile — no Netmaker agent, no side channel.

### Deliverables
- The pure total `render(nodeInventory) -> [WireGuardPeerConfig]`: keyless peer type-foreclosed; overlapping VPN
  IPs and out-of-fabric-CIDR `AllowedIPs` decode-foreclosed (a total fold returning `Left`); each peer's key a
  `SecretRef` name resolved from Vault-KV (Sprint 27.1). The gateway-role hub renders a stable hub VPN-IP +
  `Endpoint`; VPN-IP allocation is disjoint-per-cluster (confluent by construction).
- The committed golden `expected-peer-config.golden` pinning the rendered config (secrets as `SecretRef` names,
  not key bytes) — the render is asserted byte-identical to it.
- The singleton's `wg` reconcile: `discover` reads live interface state via `wg show`, `diff` against
  `render(inventory)`, `enact` via `wg set` — idempotent, driven only by observed kernel state, with `wg0`-bound
  listeners never bound to `0.0.0.0`/LAN/WAN ([`§5`](../documents/engineering/network_fabric_doctrine.md#5-the-security-boundary-generalizes-localhost--authenticated-fabric)).

### Validation
1. `render(wireguard_fabric.dhall)` is byte-identical to `expected-peer-config.golden`; the overlapping-VPN-IP
   and out-of-CIDR-`AllowedIPs` negatives are rejected with their committed `DecodeError` tags, each paired with
   a positive differing only in the foreclosed dimension.
2. On the linux-cpu host the reconcile brings `wg0` to the rendered peer set on each node (confirmed by `wg show`
   read from the kernel), and a second reconcile pass issues zero `wg set` mutations (idempotent) — the compute
   path is re-run (not memoized), its `discover` observed to re-read live kernel state before concluding the
   empty diff (§M.6).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 27.3: Phase gate harness — live fabric + external-observer reachability over the VPN IP 📋

**Status**: Planned
**Implementation**: `test/integration/Phase27Gate.hs` (linux-cpu two-peer fabric spin-up / reconcile /
reachability probe / teardown); the reused negative corpus under `dhall/examples/illegal_wg_*.dhall` (re-run,
not re-authored) — target paths, not yet built.
**Blocked by**: Sprint 27.1, Sprint 27.2; Phase 22 gate (the singleton whose reconcile enacts the fabric);
Phase 18 gate (the Vault-KV custody of the peer keys).
**Independent Validation**: the harness stands up the two-peer fabric (gateway-role hub + spoke, each in its own
Linux network namespace on the linux-cpu host) from `dhall/examples/wireguard_fabric.dhall`, the singleton
renders + reconciles `wg0` on each, and the **spoke reaches the hub at the hub's VPN-IP** — asserted by an
**external-observer** probe (an OS-level ICMP echo + TCP connect from the spoke netns to the hub VPN-IP, plus a
`tcpdump` underlay capture confirming the traffic is WireGuard UDP, never cleartext — §M.5), matching
`test/fixtures/phase27/reachability-expected.json`; effective peer state is read from `wg show` (the kernel),
never a singleton self-report. Teardown tears down `wg0` on each node and leaks no interface or peer. The run
emits a **Register-3** proven/tested/assumed ledger naming the live linux-cpu substrate.
**Docs to update**: `DEVELOPMENT_PLAN/substrates.md`, `documents/engineering/testing_doctrine.md`,
`DEVELOPMENT_PLAN/README.md` (flip the Phase-27 status when the gate passes).

### Objective
Adopt [`network_fabric_doctrine.md §2`](../documents/engineering/network_fabric_doctrine.md#2-raw-wireguard-not-netmaker)–[`§5`](../documents/engineering/network_fabric_doctrine.md#5-the-security-boundary-generalizes-localhost--authenticated-fabric):
assemble the phase's single live acceptance gate — the singleton renders each peer config from Vault-KV
Curve25519 keys (secrets by name) and reconciles raw-kernel WireGuard so every peer draws its VPN IP from the
gateway-role hub and the hub is reachable across the fabric — and prove that reach with an external-observer
probe over the VPN IP, not a self-report.

### Deliverables
- The positive gate: the two-peer fabric of `wireguard_fabric.dhall` rendered (byte-identical to the golden) and
  reconciled onto real `wg0` interfaces, the spoke→hub reachability probe green over the hub VPN-IP, torn down
  leak-free — expressed as a test-topology `.dhall` with a teardown obligation.
- The negative regression guard: the inline-key-literal (secrets-in-Dhall), overlapping-VPN-IP, and
  out-of-CIDR-`AllowedIPs` fixtures re-run against the same render entry point, each failing at Gate 1/Gate 2
  with its foreclosure tag equal to the Phase-0-committed hand-authored oracle
  `test/fixtures/phase27/negative-expected-tags.tsv` (§M.3/§M.8), each paired with a positive differing only in
  the foreclosed dimension.
- **Committed seeded mutants (§M.2):** `test/fixtures/phase27/mutants/missing-peer-key.patch` (the spoke's
  `SecretRef` resolves to no live Vault-KV entry — `wg0` never comes up, the probe fails red) and
  `test/fixtures/phase27/mutants/hub-no-endpoint.patch` (the hub-role config omits its `Endpoint` — the spoke
  has no hub address, the probe fails red) — both committed and re-run each gate, each asserted to turn the gate
  red.
- The **Phase-0-pinned oracle bundle** committed before any implementation exists:
  `dhall/examples/wireguard_fabric.dhall`, `expected-peer-config.golden`, `reachability-expected.json`, and
  `negative-expected-tags.tsv` (under `test/fixtures/phase27/`).
- A **Register-3** proven/tested/assumed ledger recording the live-reachability result (the spoke reached the
  hub over the VPN IP) and marking the deferred / out-of-register surfaces UNVERIFIED: the cross-cluster
  **broker↔broker** geo-replication render obligation (Phase 28), the **gateway-migration hub repoint**
  (Phase 28), and the stretched kubelet↔apiserver `ControlPlanePeer` span (owned by cluster_topology). The
  ledger marks the runtime tunnel layer **tested**, never *proven*; the keyless-peer (type-foreclosed) and
  overlapping-IP / out-of-CIDR (decode-foreclosed) layers are recorded as already proven-for-model in the
  pre-cluster band.

### Validation
1. From `wireguard_fabric.dhall` the singleton renders config byte-identical to `expected-peer-config.golden` and
   reconciles `wg0` on both peers; the spoke's external-observer probe reaches the hub at its VPN-IP matching
   `reachability-expected.json` (ICMP + TCP connect succeed, underlay `tcpdump` shows WireGuard UDP only, `wg show`
   confirms the peer set); the `missing-peer-key` and `hub-no-endpoint` mutants each turn this red.
2. Every negative fixture, submitted through the same render entry the positive used, is rejected at Gate 1/Gate 2
   with its emitted tag equal to the committed `negative-expected-tags.tsv` oracle (secrets-in-Dhall foreclosed,
   overlapping IPs and out-of-CIDR `AllowedIPs` decode-foreclosed); the positives decode; teardown leaves no
   leaked `wg0` interface or peer; and the ledger honestly classifies each layer (no deferred surface —
   broker↔broker geo-replication, the gateway-migration repoint — reported as proven, and the runtime tunnel
   marked *tested*, not *proven*).

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/network_fabric_doctrine.md` — the §2–§5 "Phase 0 design intent" honesty note flips from
  design intent to a delivered raw-kernel WireGuard fabric with its Register-3 ledger attached: the rendered
  peer config, the `wg show → diff → wg set` reconcile, the Vault-KV Curve25519 key custody, and the
  localhost→fabric listener boundary are live on linux-cpu; the broker↔broker geo-replication render and the
  gateway-migration hub repoint remain deferred (Phase 28).
- `documents/engineering/vault_pki_doctrine.md` — record that WireGuard peer keys landed as a Vault-KV
  Curve25519 secret class named by `SecretRef` (not PKI certs, not an unseal gate), minted and parent-injected.
- `documents/engineering/manifest_generation_doctrine.md` — record that the peer config is a pure-`render()`
  product reconciled by the singleton like any other manifest, with keyless / overlapping-IP peers foreclosed.
- `documents/engineering/testing_doctrine.md` — record the Register-3 ledger variant this gate emits (runtime
  tunnel *tested*; broker↔broker geo-replication and gateway-migration repoint UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — add the Phase-27 row and flip its status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — add the Phase-27 linux-cpu gate row (the raw-kernel WireGuard fabric).
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Fabric/{Keys,WgRender,WgReconcile}.hs` as
  Phase-27 design-first rows against `network_fabric_doctrine.md`.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (the network fabric)
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map (the linux-cpu gate row)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Network Fabric Doctrine](../documents/engineering/network_fabric_doctrine.md) — raw-kernel WireGuard, the
  Vault-KV Curve25519 peer keys, the rendered-config reconcile, and the hub = gateway-role topology
- [Vault / PKI Doctrine](../documents/engineering/vault_pki_doctrine.md) — the KV secret class the peer keys are
  custodied as, named by `SecretRef`
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — the pure `render()`
  discipline the peer config reuses
- [phase_18](phase_18_vault_pki.md) — the root Vault + `SecretRef`-by-name client custodying the peer keys
- [phase_22](phase_22_live_dsl_singleton.md) — the control-plane singleton whose reconcile enacts the fabric
- [phase_28](phase_28_multicluster_spawn_georepl.md) — the gateway migration that later repoints the WireGuard hub
