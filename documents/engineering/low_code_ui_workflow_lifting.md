# Low-code UI workflow lifting

> **Purpose**: Define how workflows and their artifacts are lifted into the low-code UX — what a workflow contributes to the program surface and what it may not.
> **Read this if**: a workflow has to appear in the UI, or an artifact it produces has to be reachable from one.

This document owns workflow and artifact lifting into the UX. It does not own the surrounding subject — owned by
[low_code_ui_runtime_doctrine.md](./low_code_ui_runtime_doctrine.md), of which this is a slice.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_40_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_45_ui_local_composition.md, DEVELOPMENT_PLAN/phase_93_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_95_jitml_ui_rederivation.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/content_addressing_determinism.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/illegal_state/illegal_state_ml_asset.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Every phase-run or implementation-result statement in this document is permanently invalidated diagnostic history. It cannot establish or reactivate current status, even if a phase later advances. Target doctrine remains normative; current status is solely in the [tracker](../../DEVELOPMENT_PLAN/README.md).

---

## 12. Workflows and artifact lifting into the UX

Workflow UI is expressed through typed lifecycle ports rather than transport details:

- `StartWorkflow` consumes a public input and returns an owned `WorkflowHandle`;
- `ObserveWorkflow` returns a bounded status/progress projection and resumable cursor;
- `SignalWorkflow` and `CancelWorkflow` require operations admitted by the workflow contract; and
- terminal output is introduced through a typed completion event.

The UI cannot choose a Pulsar topic, forge a workflow identity, change ownership, or infer success from a
progress string. Duplicate starts are deduplicated by the server's idempotency contract. Reconnect uses an
authenticated resume cursor; no UI-server replica owns the durable workflow truth.

An artifact becomes interactive only through the following checked/runtime-checked chain:

```text
owned WorkflowHandle
  -> committed successful checkpoint
  -> provenance and content identity verified
  -> ownership or GrantHandle verified
  -> artifact kind and serving-engine compatibility verified
  -> ReadyArtifactHandle scope artifactKind
  -> typed InvokeArtifact port
```

`ReadyArtifactHandle` is server-issued and opaque. A digest displayed for provenance is plain presentation data
and cannot be converted into authority. Failed, incomplete, uncommitted, incompatible, revoked, or foreign-scope
artifacts cannot be supplied to `InvokeArtifact`.

Inference and generative-model output is untrusted content, even when it came from a ready artifact and decoded
against a public output contract. It may be rendered as escaped content within its admitted audience. It cannot
select a port, route, policy, grant, tenant, owner, provider operation, workflow signal, or other
authority-bearing value. A server-side named validator may convert a bounded model proposal into validated
domain data, but the original output cannot acquire that witness by client assertion.

infernix and jitML expose their workflow, artifact, inference-input, inference-output, and public-error contracts
through linked Haskell adapters. A UI module can bind forms and views to those contracts and use catalog
components such as `WorkflowProgress`, `ArtifactProvenance`, and `ModelInteractor`. For example, a completed
jitML training run yields a `ReadyArtifactHandle Model`; `ModelInteractor` combines that handle with a typed
model input, invokes the bound inference port, and renders the typed result. It never receives a model path,
engine address, storage credential, or unchecked response.

The initial ML adapter offline classification is closed and opt-in:

| Adapter operation | Offline classification | Required behavior |
|-------------------|------------------------|-------------------|
| infernix artifact/workflow start | Eligible `QueuedPort` | Replay the original normalized public input and immutable client `RequestId`; after validation the server derives the scoped `CommandId` and returns the existing workflow/receipt on exact replay. |
| jitML training start | Eligible `QueuedPort` | Replay only after every declared dataset/local-blob dependency has an accepted verified-upload receipt; return the existing training workflow/receipt on exact replay. |
| infernix/jitML workflow progress | Cached projection, not a queued read | Resume from the last server-validated cursor and repair from the authoritative projection. |
| infernix/jitML signal or cancellation | `OnlineOnly` | Revalidate current workflow state and authority synchronously; the initial contract does not deliver a stale queued control operation. |
| infernix/jitML artifact/model invocation | `OnlineOnly` | Require a current server-resolved `ReadyArtifactHandle`; the initial contract does not retain model inputs or inference results as offline commands. |

“Eligible” does not make every application offline-capable. The checked program must explicitly select
`UiSource.continuity = Offline` and attach a complete queue contract. The browser stores an immutable opaque
`RequestId` inside its authenticated offline partition; it does not author scope. On replay the server derives
the trusted `CommandId` from `(AppId, TenantId, Owner, PortId, RequestId)` and retains a normalized-input digest.
Exact identity plus equal digest returns the same `WorkflowHandle` and durable receipt; equal identity plus a
different digest yields a typed conflict before Pulsar publication. Starts are independent unless the
authored bounded dependency DAG orders them; no same-owner global FIFO is inferred. Count, encoded-byte, and
age limits are positive finite values in the bound port contract, never adapter defaults. Expiry produces
`Expired` before publish. Reconnect rechecks the current program/ABI, authentication, membership, policy,
scope, catalog identities, and dependency receipts before replay. `Accepted` comes only from the Phase-71
effect-owner-derived receipt carrying the same command/workflow identity; Redis and WebSocket delivery remain
non-authoritative.

A specialized infernix or jitML interaction that the core algebra cannot express requires a named trusted
component implemented in the generic PureScript runtime and a matching Haskell contract witness. Extension
Dhall configures that component; it does not ship arbitrary JavaScript or a separately trusted browser bundle.

The scoped Phase-93 infernix target owns the first concrete adapter for this rule. A constructor-hidden ready
handle must flow through a bounded Dhall program into trusted, owner/tenant/port-qualified start and invoke
operations; exact resend must return the original Phase-71-style receipt, changed input must conflict before an
effect, and scope/terminal-identity mutants must turn red. The target challenge uses real Chrome, fresh
Keycloak tenant sessions, retained Pulsar and MinIO, and a fresh Kubernetes reference worker for one
own-tenant interaction and a foreign-tenant zero-effect denial; a second loopback server origin must read the
terminal receipt from MinIO.
This is a `reference-uppercase` computation, not the full Phase-92 output path. Browser-through-Envoy UI
routing, Kubernetes UI-server replicas, Phase-93 native CBOR, production inference, Redis/socket recovery,
direct-service isolation, and general noninterference remain UNVERIFIED. The portable fallback is always
`linux-cpu`, regardless of the hardware substrate; where a clean Linux environment is required, select Incus
for Linux or Linux-CUDA hosts, Lima for Apple hosts, and WSL2 for Windows hosts.

The scoped Phase-95 jitML target supplies the second adapter. Its hidden Ready-model constructor must accept
only a matching Phase-94 committed artifact; pure tests must pin owner, tenant, scope, identity, idempotency,
transient-route loss, durable repair, and five mutation loci. The target browser challenge covers Ready,
in-flight, failed, same-tenant non-owner, and foreign-tenant cases across two loopback origins; a temporary
durable-file observer and physical CUDA must provide the bounded live observation. Fresh Keycloak, retained
MinIO/Pulsar/Redis, Envoy, Kubernetes UI replicas, native CBOR, complete sibling serving, and same-flow training
remain UNVERIFIED. CPU-only Linux execution stays available for every host kind.

Workflow monitoring remains mandatory. A workflow view consumes the authenticated workflow-monitor projection
or a typed monitoring link. The UI cannot introduce a public monitoring surface or redefine workflow health.

---

## Related Documents
- [Low-code UI workflow lifting hub](./low_code_ui_runtime_doctrine.md) — the document this slice belongs to.
- [Engineering Doctrine Index](./README.md)
