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
peer config), and it **precedes** Phase 28 geo-replication and Phase 29 gateway migration (which repoints the
WireGuard hub).

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
control server, no MQTT push channel, no second state store. The fabric is not free host overhead: the pure
`NetworkFabricSystemDemand` supplies a finite packet-rate, queue-byte bound, rotated-log policy, and versioned
cost model. Provisioning joins it to the exact topology-expanded node/peer graph and derives finite per-node
kernel/listener CPU and memory reservation+ceiling plus nodefs bytes before any interface, peer, queue, or
listener mutation.

The design half of the render obligation is discharged in the pre-cluster band (Registers 1–2, substrate
`none`): the typed decoder (Phase 5), the illegal-state corpus (Phase 6), and the pure `renderAll` manifest goldens
(Phase 9) already establish, in-process, that a keyless peer will not construct and an overlapping-IP peer set
will not decode. Phase 27 adds the **runtime residue**: a real `wg0` interface on each node, brought up by the
singleton reconcile, over which a spoke actually reaches the hub at its VPN IP. VPN-IP allocation is by disjoint
per-cluster sub-ranges of the fabric CIDR — the same disjoint-namespace allocation the failover doctrine uses,
so two clusters can never mint the same VPN IP (confluent by construction). The cross-cluster **broker↔broker**
geo-replication wire is *not* delivered here — its per-peer `render()` obligation is deferred to Phase 28; the
two spans this phase renders are the remote-worker↔home attach carrier and the fabric-bound listener boundary.
The gateway-migration hub *repoint* is Phase 29; this phase establishes the static fabric it will
later move.

**Substrate:** linux-cpu — the single-node `kind` host of Phases 14–22, whose kernel provides the WireGuard
module; the representative fabric is two peers (a gateway-role hub node and one spoke) each in its own Linux
network namespace on that host. No apple, linux-cuda, or windows substrate is exercised by this phase's gate.

**Register:** 3 — live infrastructure (§K). The type-foreclosed and decode-foreclosed layers were proven for
the model in the pre-cluster band; the runtime layer (the tunnel coming up and carrying traffic) and live
resource-control/readback layer are **tested** on linux-cpu, never *proven*.

**Gate:** on the linux-cpu host, the singleton renders each peer config from **Vault-KV Curve25519 keys named
by `SecretRef` only** and reconciles **raw-kernel WireGuard** so every peer draws its VPN IP from the
gateway-role hub and the hub peer is reachable across the fabric; the exact topology-expanded fabric-system
demand fits the current node residual and yields a snapshot-bound single-use enactment token before any
`ip`/`wg`/traffic-control/listener change; a **committed golden** pins the rendered peer
config; the **hub-role attach is asserted by an external-observer reachability probe over the VPN IP** (an
OS-level connect + underlay packet capture, never a singleton self-report); **≥2 committed seeded mutants** — a
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
- **Capacity admission precedes every fabric effect.** The topology-expanded
  `ProvisionedNetworkFabricSystemDemand` has exactly the representative node ids and each node's exact rendered
  peer ids; its finite `HostResources` carry CPU/memory reservation+ceiling and its nodefs debit includes the
  bounded rotated logs. The queue-byte ceiling is an operand of the memory/cost derivation. Provisioning
  subtracts each result once as the named `InfrastructureReserve.NetworkFabric` before pod placement and
  proves it fits the enclosing kind-node runtime; it is neither an invented pod nor added again to the host
  engine reserve. A validated result mints one `ValidatedFabricEnactment` bound to the complete topology,
  resource, nodefs, kernel-interface, queue, and listener fingerprint. The singleton re-observes that
  fingerprint immediately before the first `ip`/`wg`/traffic-control/listener mutation; mismatch or overdraw
  discards the plan with zero such effects.
- **Phase-0-pinned oracle (§M.1).** The positive fixture `dhall/examples/wireguard_fabric.dhall`, the committed
  rendered-config golden `test/fixtures/phase27/expected-peer-config.golden` (key fields carried as `SecretRef`
  names, *not* key material — with the AllowedIPs, per-peer VPN-IP, and hub `Endpoint` pinned), the expected
  topology/resource expansion `test/fixtures/phase27/expected-fabric-demand.json`, the reachability matrix
  `test/fixtures/phase27/reachability-expected.json`, and the negative corpus's expected
  foreclosure-tag table `test/fixtures/phase27/negative-expected-tags.tsv` (hand-authored, independent of the
  renderer's own output — §M.3) are all **committed in Phase 0 before** `Fabric.hs`/`WgRender.hs`/`WgReconcile.hs`
  exist; none is regenerated from implementation output.
- **External-observer reachability, not a self-report (§M.5).** The hub-attach claim is read from an observer at
  the OS boundary: (a) the spoke netns issues a real transport probe (an ICMP echo *and* a TCP connect) to the
  hub's VPN-IP and the connect succeeds; (b) a `tcpdump` capture on the **underlay** interface shows the traffic
  as WireGuard UDP (encrypted), never cleartext application bytes; (c) the effective interface state is read
  from the kernel via `wg show` (the OS boundary), never from a status line the singleton emits about itself. A
  run in which reachability is asserted only by a singleton log/metric fails.
- **External-observer resource enforcement.** The same OS-boundary artifact reads the listener cgroup's
  CPU/memory reservation and hard ceilings, effective `tc` packet-rate and queue-byte controls, rotated-log
  maximum/count/age and nodefs high-water mark, and the effective interface/peer state. Rate/queue enforcement
  bounds kernel WireGuard work under the versioned cost model; no unobservable per-interface kernel cgroup is
  assumed. Every value must equal the provisioned per-node operands, and a stress pass must remain within the
  admitted high-water marks.
- **Committed seeded mutants (§M.2).** The gate names **≥2 committed seeded mutants** that MUST turn it red: a
  **missing/rotated peer key** mutant `test/fixtures/phase27/mutants/missing-peer-key.patch` (the spoke's
  `SecretRef` resolves to no live Vault-KV entry — reconcile cannot bring `wg0` up and the reachability probe
  fails), and a **dropped-field** mutant `test/fixtures/phase27/mutants/hub-no-endpoint.patch` (the hub-role
  peer config omits its `Endpoint`, so the spoke has no address to reach and the probe fails). Both are committed
  and re-run each gate. The same Phase-0 bundle pins `drop-resource-envelope.patch` and
  `early-listener-replacement.patch`; they must fail resource projection/readback even when reachability would
  otherwise succeed.
- **Specific-reason negatives + secrets-in-Dhall foreclosed (§M.8).** Each negative fixture asserts **why** it
  fails against the Phase-0 oracle: an **inline key literal** (a raw Curve25519 key written into the `.dhall`
  instead of a `SecretRef` name) is rejected with its committed expected tag — secrets never live in Dhall; an
  **overlapping VPN-IP** pair and an **`AllowedIPs` outside the fabric CIDR** are decode-foreclosed with their
  committed `DecodeError` tags. Each negative is paired with a positive differing only in the foreclosed
  dimension.

## Complete resource provision for the fabric transition

The two kernel interfaces and their listeners are host execution units, not resource-free infrastructure.
Before `wg`, `ip`, `tc`, a socket bind, a key read, or a log write, binding expands one pure fabric transition
demand over the exact peer graph. For each node it retains the content digest and installed bytes of the
host listener executable (there is no OCI image for this host process), Linux-cgroup-v2 CPU/memory
reservation and ceiling, queue memory, bounded temporary/writable state, active-plus-rotated log bytes and
their nodefs backing, packet/queue concurrency, and the interface/listener identity. The small amount of
fabric-render/diff work performed by the already-existing Phase-22 singleton is added to that singleton's
existing container CPU/memory/ephemeral/log/mapped-file envelope; it does **not** create a fabric controller
pod or a second pod/IP/CSI debit. The Vault server is a surviving service whose full envelope/storage is
already in the same live snapshot; key mint/read request buffers and CPU are charged to Vault and the
singleton client, not to a fictitious key-agent Pod. The phase introduces no durable volume, cache,
accelerator, or VRAM demand.

The v1 transition is in-place for peer/config changes: one interface and one listener remain live. A listener
binary replacement is `RecreateAfterObservedExit`; the old executable, process, cgroup, socket, and log extent
remain charged until the external observer sees them gone, and only then may the replacement start. Thus no
unmodelled old/new process overlap is hidden in the steady-state row. The gate harness is itself a bounded
linux-cpu host process with an executable digest, CPU/memory reservation+ceiling, packet-capture buffer,
temporary capture/log bytes on a named host backing, and finite probe concurrency; the ICMP/TCP clients are
operations inside that envelope, not invented pods.

After controller expansion, the binder serializes exhaustive `desiredObjects` for **all** rendered and derived
Kubernetes objects, not a selected kind list, and joins observed survivors with old/new/apply-before-prune.
`EtcdLogicalDemand { desiredObjects, churn, model }` includes revision, Lease and Event churn; only private
`ProvisionedEtcdLogicalDemand.derivedPeak <= backendQuotaBytes` may continue. Separately, physical capacity fits
backend-at-quota plus WALs, retained/saving snapshots and defrag old+new workspace. Live object serialization,
logical quota and backend/WAL/snapshot state must equal the witness. One-byte logical/physical shortages and
`drop_fabric_api_object_demand.patch`, `drop_fabric_etcd_churn.patch` or `drop_fabric_etcd_model.patch` reject
before kernel mutation.

Only the opaque whole-deployment provision result may project the listener cgroup, executable path, `tc`
settings, log policy, and singleton resource delta. Immediately before enactment, and again after it, the
gate reads the live process/cgroup, executable digest, nodefs high-water, interface/socket, and singleton Pod
resources and compares them exactly with that projection. Independent one-unit-short CPU reservation,
CPU ceiling, memory reservation, memory ceiling, queue, writable/log/nodefs, host-process-slot, and harness
capture-space fixtures return their tagged `Left` with zero fabric effects. A committed dropped-envelope
mutant that starts the listener or probe without its resource row
(`test/fixtures/phase27/mutants/drop-resource-envelope.patch`), and a replacement-overlap mutant that starts
the new listener before the old PID is observed absent (`early-listener-replacement.patch`), must both turn
the gate red.

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
  phase stands up the static hub; Phase 29 later repoints it on migration.
- [`network_fabric_doctrine.md §5` — The security boundary generalizes: localhost → authenticated fabric](../documents/engineering/network_fabric_doctrine.md#5-the-security-boundary-generalizes-localhost--authenticated-fabric):
  fabric-bound listeners bind to `wg0`, never `0.0.0.0`/LAN/WAN, so the host-comms security property moves from
  "reachable only from localhost" to "reachable only over the authenticated WireGuard fabric" — Curve25519 peer
  auth + ChaCha20-Poly1305 encryption supply what the WAN removed, with no in-cluster mTLS tax reintroduced.
- [`network_fabric_doctrine.md §6` — The service-mesh verdict: no Linkerd for v1](../documents/engineering/network_fabric_doctrine.md#6-the-service-mesh-verdict-no-linkerd-for-v1):
  a service mesh is **not** adopted; the fabric this phase delivers is WireGuard, and no Linkerd sidecar fleet is
  introduced. (Cited for the boundary; no mesh component is built here.)
- [`resource_capacity_doctrine.md` §3–§4](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget):
  the raw `NetworkFabricSystemDemand` is an input to provisioning, not a free fixed subtraction; its private
  topology-expanded result is admitted as a named infrastructure reserve against the same node/candidate
  ledger used for workloads before the host reconcile may mutate anything.

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
control-plane singleton whose reconcile loop this reconcile plugs into); Phase 9 (the pure `renderAll` manifest goldens
discipline this render extends).
**Independent Validation**: `render(wireguard_fabric.dhall)` produces per-peer config **byte-identical to the
committed golden** `test/fixtures/phase27/expected-peer-config.golden` (key fields carried as `SecretRef`
names, with per-peer VPN-IP, `AllowedIPs`, and the hub `Endpoint` pinned) — the golden is the Phase-0 oracle,
authored before `WgRender.hs` exists, so it cannot be a regenerated tautology (§M.1). The reconcile is
idempotent: a first pass brings `wg0` to the rendered peer set (observed via `wg show` read from the kernel, the
OS boundary — §M.5), and a second pass is a no-op (zero `wg set` mutations). Overlapping-VPN-IP and
`AllowedIPs`-outside-CIDR negatives are decode-foreclosed with their committed tags. Before either pass may
mutate the kernel or a listener, provisioning expands the raw finite `NetworkFabricSystemDemand` over exactly
the rendered topology and matches `expected-fabric-demand.json`; one-byte CPU/memory/nodefs overdraw and a
changed-snapshot fixture yield zero `ip`/`wg`/traffic-control/listener effects.
**Docs to update**: `documents/engineering/network_fabric_doctrine.md`,
`documents/engineering/manifest_generation_doctrine.md`,
`documents/engineering/resource_capacity_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

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
- The exact capacity boundary:
  `renderTopology → provision NetworkFabricSystemDemand → validateSnapshot → Either ProvisionError
  ValidatedFabricEnactment`. The raw demand contains finite `maxPacketsPerSecond`, `maxQueuedBytes`, rotated
  log size/count/retention, and a `NetworkFabricCostModelVersion`; expansion must produce exactly one private
  per-node row for every topology node and exactly its rendered peer ids. The cost model derives kernel +
  listener `HostResources { reservation, ceiling }` and nodefs log bytes; missing/extra peers, unlimited
  rate/queue/log state, or a caller-authored fixed aggregate rejects.
- Each private per-node row is charged exactly once as `InfrastructureReserve.NetworkFabric`: it is subtracted
  from effective node/candidate CPU, memory, and layout-routed nodefs before workload placement, while the same
  reserve fits inside the enclosing kind-node/RKE2 runtime. It is not rendered as a pod, included in
  `EngineSystemReserve`, or added again at the physical host. The single-use token binds the expanded graph and
  complete resource/kernel/listener fingerprint, is rechecked immediately before the first effect, and alone
  authorizes the ordered interface/peer/queue/listener reconcile.
- Effective OS controls and readback: the listener process cgroup projects reservation through
  `cpu.weight`/`memory.low` and ceilings through `cpu.max`/`memory.max`; `tc`/interface controls enforce the
  packet-rate and queue-byte bounds that cap modelled kernel work; finite rotation enforces
  `(maxBackups + 1) × maxBytesPerFile` and retention on the witnessed nodefs backing. An independent observer
  reads those cgroup files, qdisc/interface settings, log policy/high-water, listener socket binding, and
  `wg show`, comparing every value with the provisioned row.

### Validation
1. `render(wireguard_fabric.dhall)` is byte-identical to `expected-peer-config.golden`; the overlapping-VPN-IP
   and out-of-CIDR-`AllowedIPs` negatives are rejected with their committed `DecodeError` tags, each paired with
   a positive differing only in the foreclosed dimension.
2. On the linux-cpu host the reconcile brings `wg0` to the rendered peer set on each node (confirmed by `wg show`
   read from the kernel), and a second reconcile pass issues zero `wg set` mutations (idempotent) — the compute
   path is re-run (not memoized), its `discover` observed to re-read live kernel state before concluding the
   empty diff (§M.6). Before the first pass, assert the topology/resource expansion is byte-identical to
   `expected-fabric-demand.json`, then read back the listener cgroup, rate/queue controls, log rotation and
   nodefs high-water, interface peers, and socket binding. All identities, reservations, ceilings, bounds, and
   peer sets must equal the admitted row; stress at the declared rate/queue boundary remains inside it.
3. Increase CPU reservation, CPU ceiling, memory reservation, memory ceiling, queue memory, and rotated nodefs
   demand independently by one unit beyond current residual. Remove one topology peer from the expansion and
   change one live commitment after validation. Each case must fail with its pinned reason before the first
   effect, while external `ip monitor`, `wg show`, qdisc/cgroup/log-policy observers and the listener process
   table prove zero interface creation, `wg set`, queue/cgroup/log mutation, listener bind/restart, and nodefs
   writes. The matched fitting case differs only in the reduced field and enacts. Committed mutants that admit
   against the pre-expansion aggregate, reuse a stale token, or double-charge the named reserve must turn this
   validation red.

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
never a singleton self-report. The gate also proves the exact topology-expanded fabric reserve was admitted
against a fresh fingerprint before mutation and that its cgroup/rate/queue/log controls are effective by OS
readback; one-byte and stale-snapshot negatives have zero fabric effects. Teardown tears down `wg0` on each
node and leaks no interface, peer, cgroup, qdisc, or log allocation. The run emits a **Register-3**
proven/tested/assumed ledger naming the live linux-cpu substrate.
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
  capacity-expanded byte-identically to `expected-fabric-demand.json`, admitted through
  `ValidatedFabricEnactment`, and reconciled onto real `wg0` interfaces; its OS-enforced per-node
  CPU/memory/rate/queue/log controls read back exactly, the spoke→hub reachability probe is green over the hub
  VPN-IP, and teardown is leak-free — expressed as a test-topology `.dhall` with a teardown obligation.
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
  `dhall/examples/wireguard_fabric.dhall`, `expected-peer-config.golden`,
  `expected-fabric-demand.json`, `reachability-expected.json`, and `negative-expected-tags.tsv` (under
  `test/fixtures/phase27/`).
- The pre-effect negative bundle: CPU reservation/ceiling, memory reservation/ceiling, queue-state memory, and
  rotated nodefs demand each exceed the current residual by exactly one unit; an expansion omits one rendered
  peer; and a validated fingerprint changes before enactment. Each must return its committed specific reason
  and an external observer must prove zero interface/peer/qdisc/cgroup/log/listener effects.
- A **Register-3** proven/tested/assumed ledger recording the live-reachability result (the spoke reached the
  hub over the VPN IP) and marking the deferred / out-of-register surfaces UNVERIFIED: the cross-cluster
  **broker↔broker** geo-replication render obligation (Phase 28), the **gateway-migration hub repoint**
  (Phase 29), and the stretched kubelet↔apiserver `ControlPlanePeer` span (owned by cluster_topology). The
  ledger marks the runtime tunnel and resource-control/readback layers **tested**, never *proven*; the
  keyless-peer (type-foreclosed) and
  overlapping-IP / out-of-CIDR (decode-foreclosed) layers are recorded as already proven-for-model in the
  pre-cluster band.

### Validation
1. From `wireguard_fabric.dhall` the singleton renders config byte-identical to `expected-peer-config.golden` and
   expands capacity byte-identically to `expected-fabric-demand.json`; the provisioned node/peer rows exactly
   cover the topology; and the current-residual fingerprint yields one `ValidatedFabricEnactment`. It reconciles
   `wg0` on both peers; the spoke's external-observer probe reaches the hub at its VPN-IP matching
   `reachability-expected.json` (ICMP + TCP connect succeed, underlay `tcpdump` shows WireGuard UDP only, `wg show`
   confirms the peer set). Read back CPU/memory cgroup controls, packet-rate/queue bounds, rotated-log policy
   and nodefs high-water, listener bind, and peer graph exactly; the `missing-peer-key` and `hub-no-endpoint`
   mutants each turn this red.
2. Every negative fixture, submitted through the same render entry the positive used, is rejected at Gate 1/Gate 2
   with its emitted tag equal to the committed `negative-expected-tags.tsv` oracle (secrets-in-Dhall foreclosed,
   overlapping IPs and out-of-CIDR `AllowedIPs` decode-foreclosed); the positives decode; teardown leaves no
   leaked `wg0` interface or peer; and the ledger honestly classifies each layer (no deferred surface —
   broker↔broker geo-replication, the gateway-migration repoint — reported as proven, and the runtime tunnel
   marked *tested*, not *proven*).
3. Run every one-unit overdraw, omitted-peer, and changed-fingerprint fixture through the same live admission
   boundary. Assert its exact committed reason and use `ip monitor`, `wg show`, cgroup/qdisc/log-policy
   readback, listener process/socket observation, and nodefs byte accounting to prove zero fabric effects.
   Re-run the fitting control and require enactment. A mutant that calls `ip link`, `wg set`, or binds/restarts
   the listener before consuming a freshly rechecked token must turn the gate red.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/network_fabric_doctrine.md` — the §2–§5 "Phase 0 design intent" honesty note flips from
  design intent to a delivered raw-kernel WireGuard fabric with its Register-3 ledger attached: the rendered
  peer config, the `wg show → diff → wg set` reconcile, the Vault-KV Curve25519 key custody, and the
  localhost→fabric listener boundary are live on linux-cpu; the broker↔broker geo-replication render and the
  gateway-migration hub repoint remain deferred (Phase 29).
- `documents/engineering/vault_pki_doctrine.md` — record that WireGuard peer keys landed as a Vault-KV
  Curve25519 secret class named by `SecretRef` (not PKI certs, not an unseal gate), minted and parent-injected.
- `documents/engineering/manifest_generation_doctrine.md` — record that the peer config is a pure-`render()`
  product reconciled by the singleton like any other manifest, with keyless / overlapping-IP peers foreclosed.
- `documents/engineering/testing_doctrine.md` — record the Register-3 ledger variant this gate emits (runtime
  tunnel and resource-control/readback *tested*; broker↔broker geo-replication and gateway-migration repoint
  UNVERIFIED).
- `documents/engineering/resource_capacity_doctrine.md` — record the live producer/consumer evidence for the
  topology-expanded `NetworkFabricSystemDemand`, named infrastructure-reserve debit, snapshot token, and OS
  control readback without changing its pure contract.

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
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — the pure fabric-system
  demand, topology expansion, one-time named reserve debit, and pre-effect admission contract
- [phase_18](phase_18_vault_pki.md) — the root Vault + `SecretRef`-by-name client custodying the peer keys
- [phase_22](phase_22_live_dsl_singleton.md) — the control-plane singleton whose reconcile enacts the fabric
- [phase_28](phase_28_multicluster_spawn_georepl.md) — the gateway migration that later repoints the WireGuard hub
