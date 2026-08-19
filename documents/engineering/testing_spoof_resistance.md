# Testing spoof resistance

> **Purpose**: Define spoof-resistant evidence — the rule that a gate must observe an unforgeable effect
> produced after the gate started, never a value the system under test supplied.
> **Read this if**: a gate reports success and you need to know whether what it observed could have been
> fabricated by the thing it was testing.

This document owns one rule and its per-phase application: what counts as independent evidence. It does not
own the registers, the execution lane, or the ledger — owned by
[testing_doctrine.md](./testing_doctrine.md), of which this is a slice.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_31_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_32_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_33_ui_local_composition.md, DEVELOPMENT_PLAN/phase_45_app_tenancy.md, DEVELOPMENT_PLAN/phase_47_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_49_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_51_ui_program_release.md, DEVELOPMENT_PLAN/phase_60_infernix_lift.md, DEVELOPMENT_PLAN/phase_63_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_64_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_65_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_66_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_67_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_70_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_71_jitml_lift_cuda.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/testing_doctrine.md, documents/glossary.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Phase-run and implementation-result statements predate the 2026-08-11 reopen unless the owning phase is Done; target doctrine remains normative, and current state is in the [tracker](../../DEVELOPMENT_PLAN/README.md).

---

## 12. Spoof-resistant evidence: a gate observes an unforgeable fresh effect

A gate can report success while observing only values supplied by the system under test. A self-reported
compliance trace, a caller-supplied identity header, a golden regenerated from current output, or a canned
response matching a fixed fixture can therefore make an absent or bypassed behaviour appear present. The
result is not independent evidence.

Treating a signed self-report as sufficient does not solve the problem. A signature authenticates the emitter;
it does not establish that the emitter performed the claimed effect, used the claimed authority, or observed the
claimed provider state.

amoebius gates use a **fresh-challenge witness envelope**:

```text
GateChallenge =
  { runNonce
  , fixtureDigest
  , subjectBinaryDigest
  , observerIdentity
  , issuedAfterSubjectStart
  }

ObservedEvidence =
  { challenge
  , rawObservationDigest
  , observerTimestamp
  , authorityIdentity
  }
```

The harness, never the subject, generates `runNonce` after the subject starts and injects nonce-bearing canaries
through the public boundary being tested. The independent observer must recover the same nonce from the actual
effect or provider state. A fixed response recorded before challenge issuance cannot satisfy the gate.

The evidence rules are:

1. **Observer independence.** Pure gates compare against a separately authored predicate, model, table, or
   golden that does not call the implementation under test. Boundary and live gates read raw evidence from an
   observer outside the subject process: an argv-recording shim, browser network trace, kernel/audit trace,
   Kubernetes API readback, provider API, broker/store readback, or another named authority boundary.
2. **Freshness binding.** Every effectful gate carries a fresh harness-generated nonce or unpredictable canary
   through the requested operation and recovers it from the external observation. The ledger records the
   challenge and raw-observation digests. Cached output is admitted only when cache reuse is the property under
   test; determinism gates force an independently observed recomputation.
3. **Authority authenticity.** Authentication and isolation gates obtain real, least-privilege credentials
   from the authority under test. Raw subject, tenant, role, or gateway headers supplied by the harness are
   hostile inputs, never authentication evidence. The gate includes a paired own-scope success and
   foreign-scope denial under distinct credentials.
4. **Two-sided path testing.** A positive reaches the sanctioned path. Its paired negative differs only in the
   authority, scope, route, or lifecycle witness under test and proves zero forbidden effect through external
   readback. Security-sensitive live gates also probe direct Service/Pod/provider paths so success through the
   intended edge cannot hide a bypass.
5. **Fail-closed observation.** An unavailable, incomplete, unauthenticated, or challenge-mismatched observer is
   a gate failure. No fallback accepts a subject-emitted compliance event or a stale ledger row.
6. **Independent evidence custody.** The party or generator that writes the implementation cannot be the sole
   author or reviewer of the oracle or observer adapter. The phase contract declares fixture provenance,
   challenge shape, expected locus, mutant, and evidence parser. Unestablished chronology is labelled a
   regression fixture until independent review or replacement.

Every applicable gate names its observer, fresh challenge, authority source, paired negative, committed mutant,
and independent oracle in its `## Gate integrity` section. A pure gate marks fresh challenge and authority
credentials not applicable and names the independent reference predicate instead; it does not fabricate an
effectful observer.

**Owner-projection multi-observer instance.** Phase 49 combines three freshly introspected Keycloak sessions,
separate native Haskell consumers for workflow/projection/receipt messages, broker-admin counters and compaction
status, and an OS-side scoped-query transcript. The observers agree on owner-qualified keys, original commands,
watermarks, denials, and zero foreign subscription effect before authenticated Keycloak/Pulsar/Kubernetes
inventories return empty. The evidence retains only challenge/issuer/topic/raw-observation digests; three
committed scope-collapse mutants turn the unchanged Phase-0 oracle red.

**Atomic UI-release multi-observer instance.** Phase 51 obtains a fresh Keycloak token through Envoy after the
gate-only servers start, then sends fresh canaries through two exact paired releases. MinIO pointer/object
history, the external append-only action journal, Envoy/Keycloak counters, and Kubernetes/containerd image
inventory agree that exactly the A/A and B/B actions occurred, all eight stale/missing/mixed/bypass cases had
zero effect, and both revisions used one generic image. Phase-0-authored matrices and three committed mutants
prevent the projector or subject from defining its own success.

**Raw-kernel fabric multi-observer instance.** [Phase 52](../../DEVELOPMENT_PLAN/phase_52_network_fabric_wireguard.md) resolves fresh Vault-custodied keypairs through the
current Haskell Kubernetes-auth client, starts two real `wg0` interfaces, and sends a fresh canary from the
spoke to the gateway-role hub. Independent `wg show`, ICMP/TCP, underlay `tcpdump`, cgroup-v2, `tc`, log/nodefs,
process/socket, and cleanup observers agree with five pre-pinned oracles. The capture must contain WireGuard
UDP/51820 and not the plaintext canary; four committed key/endpoint/resource/replacement mutants must fail at
their exact locus. The ledger marks the static tunnel and resource controls tested while geo-replication,
hub repoint, and stretched control-plane peering remain UNVERIFIED.

**Scoped provider-checkpoint multi-observer instance.** Phase 55 combines Kubernetes Deployment/Job
readback, OS `execve`, Vault seal/Transit APIs, MinIO object inventory/readback, exact cleanup, and independent
Phase-0 Dhall/JSON/TSV/process oracles. It observed two concurrent executor Jobs, an absolute Pulumi 3.228.0
process with zero environment entries, sealed-Vault HTTP 503 before checkpoint PUT, and six opaque objects
that recovered only through direct Transit decrypt; three mutants turned the pinned assertions red. AWS
returned `InvalidClientTokenId`, so the ledger marks provider-account observation, control-plane daemon provider `up`,
EKS, the managed node group, CloudTrail, AWS-plugin `execve`, pod-filesystem observation, and direct-S3 denial
UNVERIFIED. A green scoped receipt is not a green full provider gate. Every hardware substrate can always run
the linux-cpu parent lane; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows.

**Scoped provider-child multi-observer instance.** Phase 56 combines independently authored Dhall/text/JSON/
TSV oracles, pure contract refusals, retained Kubernetes API readback, a sealed live-evidence reader, exact
cleanup, and a committed public-pull mutant. It observed the scheduler and initially non-Serving control-plane daemon,
four cutovers, one-Lease parent→absence→child handoff, sixteen Service objects, zero second-pass Kubernetes
mutations, private `Never` image policy, and namespace cleanup. The ledger marks EKS, managed-node and cloud
LoadBalancer materialization, full reachability/HA, provider ingress, cloud/network/OS audit, actual Managed
EKS topology readback, and the Phase-58 leak sweep UNVERIFIED. Retained kind is named as a scoped Kubernetes
child-shape boundary and never accepted as EKS evidence. Substrate portability is asserted separately by the
universal CPU and pristine-host route oracles, rather than inferred from this retained cluster.

**Scoped provider-EBS multi-observer instance.** Phase 57 combines six Phase-0 oracles, a pure admission/
credential/static-CSI/scaling contract, five separately compiled red mutants, Kubernetes StorageClass/PV
readback, a marker written through two retained PV identities, Vault-Transit-enveloped MinIO keys for distinct
checkpoint classes, a sealed Haskell evidence reader, and exact cleanup. Its ledger leaves all AWS EBS, IAM,
CSI execution, provider attachment/reattachment, raw/usable geometry, provider migration/cloud audit, and
elevated reclamation surfaces UNVERIFIED. The retained hostPath marker is explicitly an analogue and cannot
satisfy an EBS acceptance row. CPU portability and pristine-host routes are separately enumerated obligations.

**Scoped provider-node and teardown multi-observer instance.** Phase 58 combines seven Phase-0 oracles, pure
signal/quota/capability/identity/join/teardown contracts, eight separately compiled red mutants, a retained-
Kubernetes signal reconcile, broadened ownership-metadata enumeration, a sealed Haskell reader, and exact
cleanup. The ownership analogue catches two untagged run-owned objects missed by tag-only enumeration, but it
cannot satisfy the AWS sweep or ephemeral leak-freedom rows. The ledger therefore leaves EKS, managed-node,
RunInstances correlation, provider quota/root-EBS/supply/scheduler readback, cloud no-op audit, AWS run-owned
sweep, durable sole-survivor, and the second provider cycle UNVERIFIED. Every hardware substrate can always
run the `linux-cpu` parent lane; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on
Windows.

**Determinism and Tier-1 JIT-cache multi-observer instance.** Phase 59 has 23 pre-existing Phase-0 oracles and
19 committed mutants: seven separately compiled production mutants turn the pure contract red, while twelve
resource-shape mutants remain under direct custody. Four fresh compute Jobs write retained MinIO outputs;
out-of-band reads establish equal bytes for equal seed/input and unequal bytes for altered seed or input. A real replaceable cache owner, two clients with no cache mount, an in-cluster `distribution` registry, first-
miss convergence, warm HIT, pruning, resource high-water observation, exact namespace/object cleanup, and an
independent Haskell evidence reader provide the live layers. The executable is a pinned resolver fixture, not
production model inference. Cross-substrate equality, cross-node reuse, Tier-2 models, and Tier-3 CUDA kernels
remain UNVERIFIED. Every hardware substrate can always run `linux-cpu`; a pristine Linux host uses Incus on
Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows.

**Scoped infernix artifact-lift multi-observer instance.** Phase 60 combines authored oracles, frozen sibling hashes, one compiled sibling module, closed constructors, pure contracts, four red mutants, and a sealed reader.
Retained services observe MinIO publication, Pulsar dedup, two deterministic Jobs, cache reuse, and cleanup.
The micro-model does not verify production TinyLlama, the full engine, end-to-end worker causality, general
isolation, or cross-substrate equality. The CPU lane is universal; clean guests use Incus, Lima, or WSL2.

**Scoped jitML CUDA-artifact instance.** Phase 71 combines five Phase-0 oracles, one compiled sibling CUDA generator, a constructor-hidden adapter, four independently red mutants, and a sealed reader. A fresh 24-byte challenge drives 200 `libcuda` kernel launches across ten million floats; `nvidia-smi`, full 40 MB byte comparison, and retained-MinIO blob/manifest/pointer readback are independent observers. The 412 conflict, unchanged pointer, unauthenticated 403, allocation release, and bucket cleanup are tested. Kubernetes GPU ownership, native CBOR/Pulsar, Vault authority, the complete sibling trainer/checkpoint format, mutable ETag-CAS, failover, and general correctness/isolation remain UNVERIFIED. Every substrate retains a `linux-cpu` execution path. For pristine Linux, select Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows.

This contract prevents spoofing of gate evidence at the modeled boundary. It does not prove that the kernel, identity provider, provider API, observer, or hardware is uncompromised. Those trust assumptions remain named in the proven/tested/assumed ledger.

**Realtime and offline application gates specialize the same rule.** A cross-pod WebSocket gate terminates a
fresh authenticated socket on replica A, originates the challenged event or receipt through replica B, and
uses Gateway/Kubernetes/Redis plus durable Pulsar/provider observers to distinguish live routing from durable
truth. It injects Redis flush/failover, stale registration, socket loss, and pod drain; recovery must come from
the pinned cursor or durable receipt, never a subject-emitted delivery claim or sticky route.

An offline gate additionally inspects raw browser stores/caches, drives distinct real tenant/subject sessions,
and observes the authoritative effect owner. Its paired cases cover plaintext/private-field persistence,
cross-partition access, two-tab replay, quota/eviction, local-clock/lease boundary, lost response after effect,
dependent blob upload, and an old record crossing a release. Browser encryption is evidence of ciphertext at
the inspected boundary, not proof that the browser/OS is uncompromised.

---

Phase 66's scoped evidence uses a fresh challenge, three independently addressable host-process roles, and a separate durable receipt/cursor file while forcing one role down. It deliberately records provider isolation, off-cluster OIDC, managed placement, Kubernetes/CNI, and provider data/audit readers as UNVERIFIED. Every hardware substrate can always run `linux-cpu`; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows.

Phase 34 exercises the browser boundary with a fresh canary and a second Chrome process that reads the same raw IndexedDB/cache profile. It checks ciphertext, recovery, isolation, fencing, immutable assets, and quota outcomes independently of the Haskell model. PureScript production compilation and server replay remain UNVERIFIED. Every hardware substrate can always run `linux-cpu`; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows.

Phase 67 issues fresh scalar/infernix command ids through two local UI endpoints, drops one response after commit, clears transient route state, and lets a separate SQLite reader establish exactly one effect plus the original durable receipt. Real OIDC, Redis, broker, provider, Kubernetes, and CNI evidence remains UNVERIFIED. Every hardware substrate can always run `linux-cpu`; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows.

Phase 68 uses a fresh Chrome-encrypted blob, a second browser process, raw ciphertext inspection, interrupted/resumed upload, server hashing, independent filesystem readback, and paired denial to test the scoped dependency boundary. Real MinIO audit, Keycloak/Gateway, Kubernetes/CNI, and production PureScript remain UNVERIFIED. Every hardware substrate can always run `linux-cpu`; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows.

Phase 69 uses separate Chrome processes for A seed, B stage, crash inspection, B resume, reload, rollback, and final A inspection. A separate append-only local ledger observes A→B→A and one effect. Real Gateway/Pulsar/provider/Keycloak/Kubernetes/CNI and production PureScript remain UNVERIFIED. Every hardware substrate can always run `linux-cpu`; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows. Phase 70 uses real Chrome, three host-local endpoint roles, an actual role stop, SQLite and filesystem observers, route loss, current-authority denial/admission, exact retry, and eight red mutants. Provider whole-zone isolation, managed topology, real Redis/Sentinel and other platform services, Kubernetes/CNI, production PureScript, and offline jitML/CUDA remain UNVERIFIED. Every hardware substrate can always run `linux-cpu`; when a pristine Linux host is needed, use Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows.

## Related Documents
- [Testing Doctrine](./testing_doctrine.md) — the hub this slice belongs to.
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md)
- [Engineering Doctrine Index](./README.md)
