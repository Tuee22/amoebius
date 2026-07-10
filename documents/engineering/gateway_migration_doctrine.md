# Gateway Migration

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_29_multicluster_gateway_migration.md, documents/engineering/README.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/illegal_state/illegal_state_multicluster.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: Single Source of Truth for how amoebius moves the wild-ingress gateway between clusters — the typed `GatewayMigration = <Planned | Failover>` taxonomy, the planned strong-consistency handover, the unplanned survivor-wins failover, and the client-rebind protocol that keeps a live session bindable throughout.

---

## 1. Why this doctrine exists

**The problem this doctrine prevents.** Two unlike operations were conflated under one label. One is a
coordinated handover of the wild-ingress gateway between two live clusters; the other is an emergency
takeover after the active gateway vanishes. The corpus named them in two vocabularies that never met —
"graceful teardown-with-cleanup vs chaos-failover" ([cluster_lifecycle_doctrine.md §5](./cluster_lifecycle_doctrine.md#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction)),
keyed on turning a cluster *off*, and "planned migration vs failover"
([network_fabric_doctrine.md §6](./network_fabric_doctrine.md#6-the-service-mesh-verdict-no-linkerd-for-v1)),
keyed on a traffic weight-shift. The consequence is a defect at two layers: at author time, a deployment
rule cannot state which migration mode it intends; at runtime, a reader cannot tell which data-loss
guarantee (RPO=0 versus a bounded budget) is in force for a given gateway change, nor whether a live
session is guaranteed to rebind. The planned strong-consistency handover between two running clusters had
no canonical description at all.

**Why the obvious alternative fails.** Folding the taxonomy into
[cluster_lifecycle_doctrine.md §5](./cluster_lifecycle_doctrine.md#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction)
miscategorizes it. That section owns turning a cluster off, and its gateway-handoff step exists because the
source cluster is departing. A gateway migration between two clusters that both keep running is an
ingress-and-consistency operation, not a lifecycle event, and it carries a client-rebind protocol (DNS TTL,
transparent proxy, session portability) that has no home in a lifecycle document. Leaving the taxonomy in
the design notes leaves the concept with no single canonical owner.

**The chosen rule.** A gateway change is a value of the typed sum `GatewayMigration = <Planned | Failover>`.
Amoebius owns one canonical taxonomy here; the two arms carry different, explicitly stated guarantees; and
the mechanics each arm invokes — the traffic weight-shift, the hub-role move, the DNS repoint, and the async
proof — stay with their existing owners and are linked, never restated.

**What it forecloses.** Naming a gateway change without committing to a guarantee. The cost is that a gateway
migration is now a first-class deployment-rules concept an operator must classify as `Planned` or
`Failover`; there is no untyped "repoint DNS and hope" path.

Across both arms one thing is invariant: the strong-consistency boundary *within* a cluster is unchanged —
it is delegated to MinIO, Pulsar, and Percona/Patroni Postgres
([platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path);
[chaos_failover_doctrine.md §17](./chaos_failover_doctrine.md#17-the-boundary-and-its-classifier)). What a
`GatewayMigration` changes is only *which cluster owns the wild ingress*. The two prior vocabularies map onto
the sum: graceful teardown's gateway-handoff step and a planned home→provider migration are both `Planned`;
chaos-failover's emergency DNS repoint is `Failover`.

| Arm | Trigger | Both clusters up? | Data-loss guarantee | Modelled? |
|---|---|---|---|---|
| `Planned` | A new `InForceSpec`, or amoebius automated logic (e.g. a `ScalingPolicy`) | Yes | RPO=0 — no committed write lost (the `PlannedIsLossless` model invariant, proven-for-the-model; [§6](#6-honesty-and-layer-markers)) | Yes — `PlannedIsLossless` (cutover reachable only after `verify-caught-up`); no *async* divergence |
| `Failover` | The active gateway is down or unreachable | No — the active has vanished | RPO>0 — bounded by the declared data-loss budget | Yes — the async "Second Axis" (`FailoverBounded`/`MergeConverges`; [chaos_failover_doctrine.md §16](./chaos_failover_doctrine.md#16-the-second-axis--when-one-cluster-becomes-a-forest)) |

Both branches are modelled as one reifiable `Model` — simulated (io-sim) and proven (TLC) at design time — by
[gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md), amoebius's one proof obligation.

---

## 2. The `Planned` branch — a coordinated strong-consistency handover

A `Planned` migration is driven by a new `InForceSpec` (an operator changes which cluster owns the gateway)
or by amoebius automated logic — for example a `ScalingPolicy` moving the gateway from the home network to
the cloud when incoming traffic exceeds what home hosting should serve. The source and target clusters are
both up throughout.

**The target may be built first.** Because a planned migration is not racing a failure, amoebius has time to
manage a graceful transition: it may stand up the target cluster from scratch and geo-replicate it to a full
copy of the source's state *before* any cutover. Full geo-synchronization completes first; the migration
proper begins only from a target that already holds the source's state.

**The protocol is a coordinated quiesce → drain → verify-caught-up → cutover:**

1. **Quiesce** — briefly freeze writes at the source's consistency boundary (the freeze is on writes, not on
   the ingress; see [§4](#4-client-rebind--a-live-session-must-always-find-the-gateway)).
2. **Drain** — let the async replica catch up to the frozen snapshot.
3. **Verify caught-up** — confirm the target holds the frozen snapshot in full. The freeze is what buys RPO=0
   without steady-state synchronous replication.
4. **Cutover** — repoint the gateway DNS record, the WireGuard hub role
   ([network_fabric_doctrine.md §4](./network_fabric_doctrine.md#4-topology-the-hub-is-the-gateway-role-and-the-fabric-moves-with-it)),
   and the apiserver VPN-IP to the target, then unfreeze.

**Guarantee — RPO=0.** No committed write is lost — the `PlannedIsLossless` model invariant, proven-for-the-model
at scope 2 (the runtime fidelity of the caught-up verification stays assumed until Phase 29;
[§6](#6-honesty-and-layer-markers)) — because writes were frozen and the replica was verified
caught-up before authority moved. This is a coordinated cross-cluster switchover (Patroni-style), **not** an
asynchronous [Second-Axis](./chaos_failover_doctrine.md#16-the-second-axis--when-one-cluster-becomes-a-forest)
event: it presents no async divergence to reconcile. Logged-in sessions persist — Keycloak's session
Postgres is drained to the same snapshot before cutover, and OIDC/JWT bearer tokens are stateless under the
shared realm keys, so a session stays valid across the handover.

**The illegal state this forecloses — a committed transaction lost during a planned migration.** The
quiesce + verify-caught-up gate makes "authority moved to a target that had not received a committed write"
a state the protocol does not enter; the typed migration relation ([§6](#6-honesty-and-layer-markers)) carries
no arm that repoints before the caught-up edge is observed. The foreclosure technique is the GADT-indexed
state machine ([§5](#5-the-migration-as-a-typed-edge-observed-state-machine);
[illegal_state_catalog.md §4.3](../illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)),
and the honest limit is that the caught-up edge is **runtime-observed**, not a constructive impossibility
([§6](#6-honesty-and-layer-markers)).

The in-cluster backend traffic cutover rides Gateway-API `HTTPRoute` weights — the one traffic-split feature
amoebius needs, owned by
[network_fabric_doctrine.md §6](./network_fabric_doctrine.md#6-the-service-mesh-verdict-no-linkerd-for-v1)
and [release_lifecycle_doctrine.md §5](./release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply);
the DNS record itself is provisioned by
[pulumi_iac_doctrine.md §5.1](./pulumi_iac_doctrine.md#51-dns--route53) and mutated on cutover.

---

## 3. The `Failover` branch — an availability-first emergency takeover

A `Failover` happens when the active gateway is down or unreachable, so no freeze or drain is possible. A
sibling cluster promotes from its **last async-replicated state** and hard-repoints DNS. It may be mid
geo-sync, with no knowledge of whether the two clusters were consistent at the instant of partition, and it
continues on a best-effort basis.

**Guarantee — RPO>0, bounded, and eventual reconciliation.** Committed-but-un-replicated writes on the dead
active are the honest loss, bounded by the declared **data-loss budget**. Perfect consistency is impossible
across an async boundary that admits partition (CAP/FLP at cluster scale). What is guaranteed is that when
the failed cluster returns, the histories **reconcile to a single owner**.

This is the asynchronous cross-cluster **"Second Axis"** — the one place a per-system proof obligation
concentrates on amoebius itself. Its correctness is owned, and must not be restated here: the fail-closed
freshness promotion gate (R7), the failover budget (R9), the deterministic total merge of the CAS pointer,
and the reconciliation of divergent histories are owned by
[chaos_failover_doctrine.md §16–§19](./chaos_failover_doctrine.md#16-the-second-axis--when-one-cluster-becomes-a-forest)
and its
[Appendix B](./chaos_failover_doctrine.md#appendix-b--worked-example-fenced-cross-cluster-geo-replication-failover-the-open-cross-cluster-failover-question);
the formal model is [gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md) (Phase 29).

**Reconciliation on the primary's return** (summarized; owned by
[chaos_failover_doctrine.md Appendix B](./chaos_failover_doctrine.md#appendix-b--worked-example-fenced-cross-cluster-geo-replication-failover-the-open-cross-cluster-failover-question)):
Keycloak **configuration** state (realms, clients, roles, users) is a deterministic projection of the
authoritative `InForceSpec` — re-derived on the survivor rather than merged. **Runtime session** state is
held survivor-wins; sessions on the lost fork past the divergence point re-authenticate. The recovered old
active **rewinds to the fork point**, re-syncs as a replica of the new primary, and quarantines its
un-replicated writes to an **audited RPO-gap log** rather than merging them silently. The reconciliation is
therefore guaranteed to converge on a single gateway owner, with the un-replicated suffix accounted for only
by the data-loss budget.

---

## 4. Client rebind — a live session must always find the gateway

Repointing DNS is not sufficient on its own. DNS TTL and resolver caching leave a window in which a client
still resolves the old gateway address; if the old gateway is hard-stopped at the ingress, a mid-session
client is stranded. "A session that cannot rebind to the migrated gateway" is an illegal state
([illegal_state_catalog.md §3.44](../illegal_state/illegal_state_multicluster.md#344-a-session-that-cannot-rebind-on-gateway-migration)).

**On the `Planned` path** a session always has a working endpoint:

- **Freeze writes, not the ingress.** The old gateway stays alive as a transparent reverse proxy to the
  target over the fabric for the whole DNS-drain window; a client still resolving the old address is
  forwarded, its session state already on the target. This is the primary mechanism — no client-visible host
  change, no cookie-scoping dependency.
- **A low steady-state DNS TTL** on the migrating "active" record bounds the split window. A TTL cannot be
  shortened retroactively, so it must already be low. Each cluster also holds a **stable per-cluster address**
  that never migrates — the proxy target and the explicit-redirect fallback.
- **The explicit 307 redirect** to the target's stable per-cluster address is a fallback only: a host change
  drops host-only cookies, so it preserves the session only for parent-domain-scoped cookies or portable
  OIDC/JWT bearers. Amoebius's Keycloak-OIDC sessions are portable, so it works — but the transparent proxy
  avoids the concern entirely and is preferred.
- **Long-lived connections** (WebSocket/SSE) are forwarded by the old-gateway proxy, or sent a graceful close
  so the client reconnects and re-resolves; the in-cluster backend cutover uses `HTTPRoute` weights.

**On the `Failover` path** the active is down, so no old-gateway proxy exists. Clients cached to the dead
address get connection errors, retry, re-resolve within the low TTL, and rebind to the survivor. Rebind is
still reached — the survivor holds the last-replicated session state and OIDC/JWT is portable — but it is
**not seamless**: brief client errors, and post-fork sessions re-authenticate.

---

## 5. The migration as a typed, edge-observed state machine

A `Planned` migration is a GADT-indexed state machine whose transitions are ordered and gated on **observed
edges**, never elapsed timers
([illegal_state_catalog.md §4.3](../illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)):

```mermaid
flowchart LR
  A["stand-up-replica"] --> B["quiesce(source)"]
  B --> C["drain / verify-caught-up"]
  C --> D["promote(target)"]
  D --> E["source-ingress = proxy + repoint DNS to target"]
  E --> F["unfreeze(target)"]
  F --> G["drain-monitor: source traffic to 0"]
  G --> H["decommission(source-ingress)"]
```

The `decommission(source-ingress)` state is reachable **only** from an observed `drain-monitor` edge (source
traffic ≈ 0), so no transition ever removes the last working endpoint for a live session. "A session in limbo
that cannot rebind" therefore has no representable path — it is type-foreclosed by the state machine. The
honest limit is that the `drain-complete` edge is runtime-observed, so the foreclosure is decode/runtime, not
a constructive proof ([illegal_state_catalog.md §6](../illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force);
[§6](#6-honesty-and-layer-markers)).

---

## 6. Honesty and layer markers

Everything in this document is **design intent for Phase 29** (multi-cluster: amoebic spawning +
geo-replication + gateway/DNS failover). Nothing here is built or verified today. Phase order, status, and
the acceptance gate are owned by
[DEVELOPMENT_PLAN/README.md → Phase 29](../../DEVELOPMENT_PLAN/README.md); this document never restates phase
status.

- The `Planned` branch's **RPO=0** is the model invariant **`PlannedIsLossless`** — cutover is reachable only
  after a `verify-caught-up` edge, so no committed write is lost. It is **proven-for-the-model at scope 2**
  ([gateway_migration_model_doctrine.md §3](./gateway_migration_model_doctrine.md#3-the-model),
  [§6](./gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty)), not merely argued. What stays
  **assumed** is the *runtime physics* the model abstracts — that the caught-up verification and the
  MinIO/Pulsar/Patroni lossless delegation actually hold live — a **runtime-observed** caught-up edge, not a
  constructive type-level impossibility, confirmed only by the Register-3 chaos injection of Phase 29. Per the
  honesty rule ([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)),
  the model property is *proven-for-the-model* and the runtime fidelity is *assumed until Phase 29*.
- **Both** branches are the subject of amoebius's one proof obligation, owned by
  [gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md) and set in the concentration
  principle of [chaos_failover_doctrine.md](./chaos_failover_doctrine.md): the `Failover` async correctness via
  `FailoverBounded`/`MergeConverges`/`NoWriteAfterStaleFailover`, and the `Planned` handover via
  `PlannedIsLossless` — one reifiable `Model`, simulated (io-sim) and proven (TLC) at design time, with
  model↔code correspondence **by construction** (no deferred correspondence table). What remains for Phase 29
  is Register-3 chaos injection against the running forest — confirming the abstracted physics hold — never a
  paper correspondence.
- The typed `GatewayFailover { active : ClusterId, standby : ClusterId, dnsRecord, hubRole }` forest relation
  is a **parent-owned** relation in the `RootInForceSpec`, projected read-only into each child's
  `ChildInForceSpec` — the same derive-don't-author, relations-owned-by-the-enclosing-scope pattern the
  fabric peer graph uses (a peering relation has two endpoints and cannot be owned by one child;
  [cluster_lifecycle_doctrine.md §3](./cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest),
  [network_fabric_doctrine.md §4](./network_fabric_doctrine.md#4-topology-the-hub-is-the-gateway-role-and-the-fabric-moves-with-it)).
  A cluster's own gateway presence and routes stay in the child's spec; the failover/migration pairing, DNS
  record, and hub role are the parent's. The **DSL type and its projection are design intent**, authored in
  the DSL phase and not built today ([dsl_doctrine.md](./dsl_doctrine.md#recursion-a-childs-spec-is-a-typed-subtree-projection)).
- Per-upload spec validation does **not** re-run the model: TLA+/TLC proves the gateway-migration protocol —
  **both** the `Planned` and `Failover` branches — once at design time, parameterized over N clusters and
  reduced by the pairwise cutoff; a spec is validated only by the typed, decode-foreclosed check
  that it stays within the proven envelope
  ([chaos_failover_doctrine.md §17](./chaos_failover_doctrine.md#17-the-boundary-and-its-classifier);
  [gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md)).

---

## Cross-references

- [Cluster Lifecycle Doctrine](./cluster_lifecycle_doctrine.md) — teardown-with-cleanup (a `Planned` trigger; §5) and amoebic spawning / parent-owned forest relations (§3).
- [Chaos & Failover Doctrine](./chaos_failover_doctrine.md) — the `Failover` branch's proof obligation: the Second Axis (§16–§19), the fail-closed freshness gate and data-loss budget, and the failover / reconciliation worked example (Appendix B).
- [Network Fabric Doctrine](./network_fabric_doctrine.md) — the hub = gateway role and its move (§4); the Gateway-API `HTTPRoute` weight-shift traffic mechanic (§6).
- [Release Lifecycle Doctrine](./release_lifecycle_doctrine.md) — the `RolloutPhase` / `HTTPRoute` weight shift used for the backend cutover.
- [Pulumi IaC Doctrine](./pulumi_iac_doctrine.md) — the route53 DNS record this migration repoints (§5.1).
- [Platform Services Doctrine](./platform_services_doctrine.md) — Keycloak owns all wild ingress; the single wild-ingress path (§9).
- [Single Logical Data Plane Doctrine](./single_logical_data_plane_doctrine.md) — a genuine second cluster reached by gateway migration, versus remote compute attached to one data plane.
- [Illegal-State Catalog](../illegal_state/illegal_state_catalog.md) — the "session that cannot rebind on migration" entry (§3.44) and the GADT-indexed-state-machine technique (§4.3).
- [DSL Doctrine](./dsl_doctrine.md) — the typed `GatewayFailover` forest relation as a parent-minted, child-projected subtree field.
- [Gateway Migration Model Doctrine](./gateway_migration_model_doctrine.md) — the formal model of the `Failover` branch (Phase 29).
- [Development Plan → Phase 29](../../DEVELOPMENT_PLAN/README.md) — phase order, status, and the failover acceptance gate.
- [Documentation Standards](../documentation_standards.md) — header, SSoT, and the proven/tested/assumed honesty rule.
