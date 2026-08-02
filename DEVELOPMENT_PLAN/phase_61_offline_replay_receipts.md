# Phase 61: Offline replay and durable receipts

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Reconnect an encrypted browser outbox to current authority and prove that an accepted offline
> command is established by its durable effect owner, never merely by Redis delivery.

## Phase Status

📋 Planned. No live offline replay or durable-receipt lookup exists.

## Phase Summary

This phase implements current-session reauthentication, scope/program compatibility checks, bounded ordered
replay, typed outcomes, and durable idempotency/receipt lookup for SQL, object, and workflow effects. The
browser reconnects by authenticated WebSocket; any UI-server replica can recover an outcome from durable
provider/Pulsar projections. Redis routes live outcomes only. Flushing Redis or dropping a socket may delay a
result but cannot lose, invent, or duplicate an accepted effect.

**Session scope:** Gate scalar commands and workflow starts with small result payloads; offline blob transfer is
deferred to Phase 62.

**Substrate:** `linux-cpu`.

**Register:** 3 — live infrastructure.

**Gate:** `cabal test offline-replay-receipts-live` queues fresh commands while disconnected, reconnects to a
different UI-server replica, faults Redis and the socket between effect and response, and externally proves
the exact typed outcome and zero duplicate/foreign effect for every challenged command.

## Gate integrity

Phase 0 pins the command/dependency trace, replay concurrency and timeout budgets, typed outcome table, and
same-owner/non-owner/foreign-tenant matrix. Distinct real OIDC identities issue fresh nonces. Independent SQL,
MinIO, Pulsar, workflow, gateway, and Redis observers establish durable effect, route loss, and recovery.
Mutants acknowledge on Redis publish, omit durable lookup, drop current-membership validation, replay from two
tabs, discard pending after disconnect, and remove scope from idempotency keys. Direct service/provider probes
must remain denied.

**Committed fixtures/goldens:** the replay trace, outcome table, budgets, and access matrix. **Independent
oracle:** provider/Pulsar readback and the separately authored command-to-effect/outcome table.

## Resource provision — bounded reconnect and receipt recovery

The provision seal includes at least two UI-server replicas, WebSocket connections and buffers, Redis
connections/keys/fanout, replay concurrency, receipt retention/lookups, provider transaction overlap, cursor
repair, and the declared reconnect storm. No unbounded outbox, output buffer, or retry queue is admitted.

## Doctrine adopted

- Adopt [Browser Offline Runtime §9](../documents/engineering/browser_offline_runtime_doctrine.md#9-authoritative-replay-and-typed-outcomes): replay always revalidates current authority.
- Adopt [UI Realtime Coordination §6](../documents/engineering/ui_realtime_coordination_doctrine.md#6-durable-commands-receipts-and-replay): Redis is never durable acceptance evidence.
- Adopt [Testing Doctrine §12](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): external fresh-effect observation.

## Sprints

## Sprint 61.1: Gate durable replay across replicas 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Ui/Offline/{Replay,Receipt,Outcome}.hs`, `ui/src/Amoebius/Ui/Offline/Replay.purs`, `test/live/Phase61OfflineReplaySpec.hs` (planned; not built)
**Blocked by**: Phases 58 and 60
**Independent Validation**: `cabal test offline-replay-receipts-live` with provider/broker observers and Redis/socket fault injection
**Docs to update**: `documents/engineering/browser_offline_runtime_doctrine.md`, `documents/engineering/ui_realtime_coordination_doctrine.md`, `documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Prove that every accepted replay has one recoverable durable receipt and current authorization.

### Deliverables

- Typed replay session and outcomes with current-authority validation.
- Scope-qualified idempotency and durable receipt adapters.
- Cross-replica outcome routing and cursor repair after Redis/socket loss.
- Live challenge, denial, and mutant harness.

### Validation

1. Run `cabal test offline-replay-receipts-live`; require canonical green, all faults repaired, and all mutants red.

### Remaining Work

The whole sprint is planned.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/browser_offline_runtime_doctrine.md` — record tested replay outcomes and limits.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record receipt repair across Redis loss.
- `documents/engineering/resource_capacity_doctrine.md` — record exact live demand operands.
- `documents/engineering/testing_doctrine.md` — link provider-observed fresh-effect evidence.

**Cross-references to add:**
- The tracker, substrate map, and component inventory must identify replay and receipt modules.

## Related Documents

- [Development Plan](README.md)
- [Development Plan Standards](development_plan_standards.md)
- [Browser Offline Runtime](../documents/engineering/browser_offline_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
