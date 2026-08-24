# Shared Host Resource Protocol Analysis

> **Purpose**: Analyze the proposed Finite Resource Execution Authority Protocol, reconcile it with accepted
> project decisions, identify its weaknesses and ambiguities, and describe its expected impact on Amoebius.
> **Nature**: Reference-only proposal analysis. This document is not architectural doctrine, an executable
> contract, a development-phase status decision, validation evidence, or promotion authority.

This root-level review artifact uses code-formatted repository paths rather than links into the governed
documentation graph. If the proposal is adopted, the doctrine and development-plan work must add its links and
reciprocal metadata in the same reconciliation change.

The requested root-level filename is also outside the exhaustive tracked final tree in
`documents/engineering/repository_layout_doctrine.md` and outside the governed-document inventory. It is therefore
suitable as an untracked review artifact. Landing it as permanent documentation would require either relocating a
snake-case version under `documents/**` with the standard orientation metadata and link-graph update, or explicitly
changing the repository-layout and documentation contracts. This report does neither.

This analysis reviews
`documents/engineering/shared_host_resource_protocol.md` under four accepted
premises:

1. the semantic protocol is shared while participating codebases remain independently implemented;
2. the fixed host-global coordination root is an explicit exception to repository-contained state;
3. the development plan will be refactored in accordance with
   `DEVELOPMENT_PLAN/development_plan_standards.md`, including phase reopening,
   validation-contract revision, and typed legacy tracking; and
4. the accelerator-owner model will be generalized so that a host may carry multiple compatible owners.

No implementation, doctrine, phase status, legacy lifecycle, validation result, or human approval is changed by
this report. All phase and sprint references below describe proposed contracts only. Every phase remains governed
by the current tracker and the human-only promotion rules.

## Contents

- [1. Executive assessment](#1-executive-assessment)
- [2. Reconciled protocol boundary](#2-reconciled-protocol-boundary)
- [3. Strengths of the proposal](#3-strengths-of-the-proposal)
- [4. Weaknesses and ambiguities](#4-weaknesses-and-ambiguities)
- [5. Accelerator-owner generalization](#5-accelerator-owner-generalization)
- [6. Expected impact on Amoebius](#6-expected-impact-on-amoebius)
- [7. Development-plan refactor](#7-development-plan-refactor)
- [8. Validation impact](#8-validation-impact)
- [9. Legacy-tracking impact](#9-legacy-tracking-impact)
- [10. Recommended adoption sequence](#10-recommended-adoption-sequence)
- [11. Final assessment](#11-final-assessment)
- [Related Documents](#related-documents)

---

## 1. Executive assessment

The proposal's central architecture is appropriate for Amoebius. Its intended authority chain is strong:

```text
closed workload demand
  -> finite eligible resource cells
  -> atomic live admission
  -> lifetime kernel locks
  -> applied and read-back enforcement walls
  -> linear execution authority
  -> observed cleanup or quarantine
```

That chain matches the project's preference for closed Haskell values, explicit capability witnesses, bounded
resource arithmetic, fail-closed observation, and separation between semantic proof and live residue. The proposal
also correctly separates three facts that are commonly conflated:

- a workload fits a declared capacity;
- the workload currently owns the relevant physical resources; and
- the operating system or hardware is actually enforcing the required limits.

The approach should therefore be retained. It should not, however, be implemented from the document in its
current form. The principal remaining problems are:

- shared protocol semantics have no single named governance and release authority;
- the daemonless permissions model does not yet match its claimed trust boundary;
- the promised lifetime cell lock is missing from the concrete lock namespace and Haskell sketch;
- recovery can confuse "absent now" with "cannot appear later" for asynchronous external effects;
- quarantine is not yet stated as a host-global resource fence across every parent scope;
- the idempotency and replay API promises more than a crash-recovered workload can generally return;
- authority-mediated compilation is circular unless the first authority binary has a separate bootstrap path;
- artifact enrollment is not authenticated by an OS principal or a self-reported digest alone;
- the phase assignments conflict with the current one-capability and one-substrate rules;
- the accelerator model must move its singleton from the node to the resource cell or physical allocation leaf;
  and
- the current Kubernetes count-only GPU projection cannot establish exact physical-device ownership for multiple
  owners.

The proposal is best treated as the target for a deliberate doctrine and plan refactor, followed by a narrow
Linux-first implementation. It is not yet a directly implementable ABI.

---

## 2. Reconciled protocol boundary

### 2.1 Shared protocol does not mean shared code

The reconciled rule should be:

> Amoebius and the participating projects share one jointly governed Finite Resource Authority protocol and exact
> semantic ABI release. Each repository independently implements that protocol and has no source, package, build,
> library, daemon, executable, or runtime-service dependency on another participating repository.

This narrows, rather than abandons, the independence rule in
`documents/engineering/lift_and_compose_doctrine.md`. Outside the finite-resource
authority boundary, seeds remain evidence and re-derivation inputs rather than product dependencies. At this one
boundary, compatibility is deliberate and jointly governed; it cannot be the accidental result of four projects
independently guessing the same lock, byte, and recovery semantics.

The protocol needs four distinct ownership layers:

| Layer | Owner | Meaning |
|---|---|---|
| Normative protocol | One jointly governed specification | Identifier grammar, canonical encoding, lock namespace and order, state transitions, recovery, versioning, and upgrade rules |
| Repository implementation | Each repository independently | Haskell types, encoder/decoder, adapter, state machine, local semantic oracle, and local gate |
| Interoperability evidence | Cross-project black-box runs | Evidence about the exact independently built artifacts that were exercised together |
| Host admission | Host operator | Enrollment of an exact project identity, OS principal, ABI revision, mechanism set, and any separately authenticated artifact measurement |

The shared Markdown specification remains non-executable. Each repository manually authors and independently
reviews its Haskell projection. Cross-project tests exchange actual bytes and contend on actual lock objects; they
do not import a shared implementation package.

### 2.2 Shared governance is unavoidable

Codebase independence cannot provide protocol-governance independence. A named protocol release authority must
decide:

- which document revision is semantic rather than editorial;
- the exact `ProtocolRevision` and canonical schema for that semantic revision;
- the closed `ProjectId` enrollment registry and retirement rules;
- the minimum mandatory behavior understood by every implementation;
- which mechanism profiles an implementation may decline to advertise;
- the conformance matrix for exact project artifacts; and
- when a host layout may migrate to another revision.

Each product may release unrelated changes independently. A protocol change requires coordinated readiness at a
particular host because one active coordination root can safely serve only one exact semantic ABI revision.

ABI equality, repository validation, and operator authorization must remain separate. A matching digest shows that
a binary claims a revision; it does not prove conformance. A binary-generated conformance receipt is evidence, not
authority. An OS principal also does not prove which executable is currently running. Artifact identity can be an
authorization input only when an OS-specific launcher or measurement boundary authenticates it; otherwise it is
operator bookkeeping inside the cooperative trust model. The enforceable host binding therefore resembles:

```text
ProjectId
  x operating-system principal
  x exact ProtocolRevision
  x advertised MechanismProfile set
  x optional authenticated artifact measurement
```

The protocol should not claim binary attestation merely because the participant reports its own digest. If exact
artifact enforcement is required, the accepted launch and measurement mechanisms become part of each live platform
profile and its external observation.

### 2.3 Host-global root exception

The root should be classified as:

> Operator-owned shared host-protocol coordination state. It is neither Amoebius repository state nor workload,
> cluster, cache, image, secret, VM-disk, or durable application state. It is the only admitted logical host-global
> runtime coordination namespace.

This exception should be owned by `documents/engineering/repository_layout_doctrine.md` and consumed by the protocol,
testing, cluster-lifecycle, and development-plan rules. It must not become a general precedent for writing outside
`.data/**` or `.test_data/**`.

The logical namespace is not necessarily one filesystem object on every platform. On Windows it currently includes
both the fixed ProgramData tree and the fixed volatile
`HKLM\\Software\\FiniteResourceAuthority\\BootSession` key used for boot identity. Both objects must be declared as
parts of this one bounded exception, installed and ACL-protected together, and covered by the same lifecycle and
reprovision rules. If a second global object is unacceptable, boot identity needs a different derivation; it cannot
remain an undocumented exception.

The coordination namespace should:

- be installed only by an explicit privileged host-enrollment action;
- never be created as a runtime fallback or selected from an environment variable;
- survive checkout deletion, routine project teardown, and ordinary participant uninstall;
- contain only the declared filesystem layout, immutable lock objects, bounded journals, enrollment metadata,
  bounded receipts or high-water marks, and the Windows volatile boot key when that profile is used;
- be accessed only by closed protocol adapters;
- never be deleted by a workload or ordinary project test; and
- be reprovisioned only through an operator action after exclusive epoch custody and complete effect
  reconciliation.

Live validation should use a dedicated disposable or dedicated test host and the real fixed root. A fake root under
`.build/**` is appropriate for Register-2 adapter evidence but cannot validate live root identity or permissions.
The inherited validation rule that currently admits production state only under `.data/**` and test state only
under `.test_data/**` must gain this exact typed exception; a prose exception in the protocol cannot override that
gate. The `LTD-HOST-002` analyzer and closure contract must likewise distinguish the one ABI-fixed namespace from
the ambient `/tmp`, `/var/tmp`, home-directory, or caller-selected fallbacks it continues to condemn.

### 2.4 Trust model

The proposal is coherent as a cooperative protocol among enrolled principals, not as protection against a
malicious enrolled implementation.

The intended trust split should be explicit:

- the host administrator and enrolled project anchors are mutually trusted protocol principals;
- workload descendants are untrusted and receive neither protocol-group membership nor inherited lock handles;
- `ProjectId` is bound at enrollment to an OS principal; an artifact identity is binding only when an authenticated
  platform measurement or approved launcher establishes it;
- static layout and lock directories are administrator-owned and nonreplaceable by participants;
- a project principal writes only its own fixed journal area; and
- cross-project destructive recovery and quarantine clearing require a privileged operator role.

If a malicious enrolled anchor must be contained, a group-writable daemonless filesystem protocol is insufficient.
That stronger claim would require a privileged broker or stronger OS principal isolation and should be treated as a
different architecture.

---

## 3. Strengths of the proposal

### 3.1 Authority is gated by both ownership and enforcement

The proposal correctly refuses to equate a durable record with a kernel lock, or a kernel lock with an applied
resource wall. Successful launch requires both live exclusion and effective wall readback. This prevents a static
capacity calculation from being misrepresented as runtime isolation.

### 3.2 Locks name physical domains, not scalar quantities

CPU bandwidth, bytes, IOPS, VRAM, and SM shares are quantities supplied or bounded by physical or service domains;
they are not independently lockable physical objects. This is the right basis for alias-aware accounting and avoids
inventing locks such as a fictitious VRAM-byte lock.

### 3.3 Permanent lock identities avoid namespace splitting

The permanent epoch, parent, cell, and physical-resource lock identities are intended to survive crashes, protocol
upgrades, and catalog retirement. The refusal to delete a stale lock file is sound: deletion could allow an old
holder and a new pathname to become separate lock namespaces.

### 3.4 Kernel lifetime is stronger than clock-based leases

The absence of a TTL avoids unsafe lock stealing after scheduler stalls or clock uncertainty. Process exit and
reboot release kernel custody; durable state then authorizes reconciliation, not immediate reuse.

### 3.5 The guarantee strength is mostly honest

The distinction between participating-project and whole-host guarantees is valuable. The proposed profiles also
recognize important limitations:

- Darwin lacks an accepted native hard aggregate descendant-memory wall;
- Windows Job committed-memory limits are not equivalent to physical-RAM reservation;
- Metal working memory aliases host unified memory;
- MPS is bounded sharing rather than dedicated hardware isolation; and
- a VM does not manufacture a GPU partition.

### 3.6 Typed execution authority is directionally correct

Private constructors, host/boot/epoch brands, linear resource authority, region-scoped sessions, and a closed
effect interpreter provide an appropriate local boundary. They can make raw launch paths unavailable to ordinary
product code even though live OS enforcement remains a runtime claim.

---

## 4. Weaknesses and ambiguities

### 4.1 No single canonical protocol-release authority

The proposal currently describes four independently maintained semantic projections but does not identify who
decides that a revision is frozen. Four codebases may own four implementations; they cannot safely own four
independent definitions of the same ABI.

The document should name one canonical specification and one human governance process. If this Amoebius document
is that canonical specification, it needs joint custody. If a neutral external specification owns the protocol,
this document should become Amoebius's adoption and conformance profile rather than another authoritative copy.

### 4.2 Upgrade semantics are incomplete

Exact ABI refusal is appropriate, but it is not an upgrade procedure. A safe upgrade needs:

1. an operator maintenance gate that stops new admission;
2. exclusive epoch custody;
3. proof that every live and possibly delayed old-revision effect is gone;
4. verification that every enrolled artifact supports the exact target revision;
5. a durable old-to-new migration intent;
6. an exact-pair schema migrator;
7. a new epoch publication; and
8. deterministic refusal by old clients.

Interrupted migration requires a small stable bootstrap envelope readable without trusting either full journal
schema. Rollback is safe only before a new-revision effect starts unless an explicit inverse migration exists.

The document should also distinguish forbidden live lock-mode upgrades from permitted offline ABI upgrades; the
current use of "upgrade" is ambiguous.

### 4.3 The lifetime cell lock is missing

The prose makes per-cell ownership load-bearing, but the concrete root inventory names epoch, admission, parent,
and physical-resource locks without a permanent cell lock. CPU/RAM-only cells or deliberately serialized shared
cells can use compatible shared physical ancestors, so physical-resource locks alone do not necessarily exclude a
second claimant of the same logical cell.

The ABI needs an immutable `cells/<digest>.lock`, an opaque `CellLockKey`, exclusive lifetime acquisition,
canonical acquisition order, file-identity checks, tombstone rules, and crash/recovery tests. The Windows boot-init
lock and any MPS service lock should also appear in one exhaustive lock-kind inventory.

### 4.4 Admission chooses a cell at the wrong API layer

The protocol algorithm derives eligible alternatives and selects one while holding the global admission lock. The
Haskell sketch instead existentially fixes an admitted cell before the session-acquisition operation. That makes it
impossible for acquisition to choose another still-eligible cell after discovering contention without violating
the type indices.

The pure layer should return an opaque nonempty `AdmissionCandidates` or `EligibleOwnerPlan`. The live session
operation should select under `admission.lock` and invoke a continuation quantified over the actual selected cell
and offered capacity.

### 4.5 Recovery does not fence delayed external completion

Durably writing `Prepared` before mutation is necessary but not sufficient for an asynchronous service.

For example:

1. an anchor writes `Prepared`;
2. it submits a VM or container create request;
3. it dies before the service completes the request;
4. recovery queries too early and observes no object;
5. recovery retires the record and releases the locks; and
6. the old service request completes after a new claim has been admitted.

"Absent now" must therefore be joined with "no old operation can still materialize." Each asynchronous backend
needs a durable operation or idempotency identity plus one of:

- a service-enforced monotonically fenced generation;
- a queryable operation whose terminal or cancelled state is proven; or
- a queue/barrier proving that every earlier request has drained.

An adapter that cannot prove this must quarantine the cell. The crash corpus should include completion after
recovery's absence observation.

### 4.6 Quarantine is not explicitly a global admission fence

Recovery is described through the old parent record, but another parent scope may later select the same cell after
the crashed process's kernel locks have disappeared. Normal admission must, while holding `admission.lock`, scan
the complete fixed current-parent record set and subtract every bundle recorded by `Prepared`, `Applied`,
`Running`, `Releasing`, `Recovering`, or `Quarantined` state.

An undecodable record must fail closed. If its resource bundle cannot be recovered independently, fencing may need
to cover the whole host. Quarantine clearing should be a separate privileged and audited operation, never a TTL or
lock-file deletion.

### 4.7 Same-key replay overpromises result recovery

Reservation idempotency is not exactly-once workload execution. Once workload-visible effects may have begun, a
crash can leave their outcome unknown. Reusing the same key must not silently run the workload again unless the
closed workload carries a separate idempotency or resume contract.

The API also permits a session program to return an arbitrary result, while durable replay promises only a resource
receipt. A recovered caller cannot reconstruct an arbitrary result unless that result has a separately typed
durable codec and commit protocol.

The safer return shape is similar to:

```text
Fresh result receipt
| Replayed receipt
| AlreadyActive authenticated-anchor-reference
| OutcomeUnknown receipt
```

The key becomes permanently spent after the workload start linearization point. An intentional rerun receives a
new logical-attempt identity.

### 4.8 Active-anchor attachment is underspecified

A file lock does not disclose a trustworthy owner. PID data alone is intentionally insufficient. Either the
portable result should be only `AlreadyActive`, or attachment needs an authenticated endpoint bound to:

- OS peer credentials;
- epoch, project, parent scope, claim, and generation;
- process-birth identity; and
- an anchor-held challenge secret.

Failure to authenticate while the parent lock remains held is `BusyUnknown`; it is not permission to recover or
steal the claim.

### 4.9 Permissions conflict with immutability

Group-writable POSIX directories allow participants to rename or unlink child pathnames, while the proposal calls
the lock objects immutable. Conversely, a participant without directory write permission cannot create a sibling
and atomically replace its journal record. The Windows description similarly denies replacement while requiring
journal replacement.

The directory tree needs an explicit principal and ACL matrix. A coherent layout would keep installer-owned static
layout and lock directories nonreplaceable, give each project principal a fixed writable journal directory, and
reserve cross-project recovery for a privileged operator principal.

### 4.10 Lock-handle inheritance requires exact spawn behavior

Close-on-exec is not close-on-fork. A forked child can inherit a descriptor and thereby extend a BSD `flock`
lifetime until every duplicated descriptor is closed. "Children inherit none" needs an exact spawn protocol,
including pre-exec closure and failure handling, rather than only an `O_CLOEXEC` flag.

### 4.11 Safety is defined more strongly than progress

All-nonblocking locks and the deliberate absence of a TTL make safety plausible but do not guarantee fairness or
liveness. A stream of admissions can starve an epoch mutation; a live but wedged anchor can hold a cell forever.

The protocol should state that it is an admission/refusal protocol, not a fair scheduler. It needs bounded retry
guidance, a maintenance gate that prevents new readers while leases drain, and an operator revocation procedure
that terminates the exact anchor and then follows normal reconciliation without stealing the lock.

### 4.12 Durable metadata is not currently finite

Permanent lock tombstones and an exact forever-growing set of arbitrary spent claim keys make the root unbounded.
Storage accounting only predicts eventual exhaustion; it does not prevent it.

A finite design needs:

- catalog, parent-scope, and lock-object ceilings;
- bounded detailed-receipt retention;
- monotonic per-scope attempt sequences and durable high-water compaction rather than unordered eternal keys;
- preflighted or reserved journal capacity; and
- an operator-owned whole-root reprovision procedure.

Overflow and `ENOSPC` must refuse before any wall mutation.

### 4.13 Persistent storage does not end with execution

The protocol demand includes persistent storage, but terminal release retires the execution allocation after
enforcement domains become empty. Amoebius durable backing intentionally outlives cluster teardown.

Before releasing the execution cell, retained bytes must either:

- remain under a separately live durable-storage authority; or
- move through a durable prepare/commit/recovery join into a distinct durable allocation whose capacity was
  admitted before the execution authority is released.

The protocol journal and the backing store may not share a transaction manager or filesystem, so “atomic transfer”
must not imply an unavailable cross-store atomic primitive. Both allocations remain fenced through an intent,
destination admission, backing-store transition, readback, commit, and recovery sequence. An unknown outcome keeps
both authorities live or quarantined until reconciliation proves one terminal ownership state.

This relationship should be owned jointly by the protocol and
`documents/engineering/storage_lifecycle_doctrine.md`, with the pure geometry in
the existing storage-fold phase and live rebind behavior in the retained-storage phase.

### 4.14 Native platform claims need narrower honesty

The platform adapters should advertise only the strengths their live gates observe:

- Darwin process groups are an observation and supervision mechanism, not a complete hostile-descendant
  containment boundary. A process capable of detaching must be refused or explicitly trusted not to detach.
- Native Darwin hard aggregate RAM requirements must refuse unless a separately accepted bounded substrate is
  used.
- Windows Job committed-memory limits should remain a distinct profile, not be presented as reserved physical
  RAM.
- WSL guest locking cannot arbitrate a native Windows root; the host anchor must retain the native handles.
- Metal remains exclusive and unified-memory-aliased.

### 4.15 Cross-project conformance is not one repository's phase result

An Amoebius gate can show that an exact Amoebius artifact interoperated with exact independently built peer
artifacts. It cannot validate or promote a sibling project's phase. The joint protocol governance process may
collect a wider compatibility matrix, but each repository retains its own independent oracle, candidate evidence,
and human promotion authority.

### 4.16 The first authority process has a bootstrap recursion

The broad claim that every process and compiler launch requires `ExecutionAuthority` cannot literally include the
launch that creates the first authority-capable process. `pb` must establish the pinned toolchain and build the
source-bound Haskell executable, while Python is forbidden to implement admission. The Phase-52 candidate also
cannot use its own not-yet-running adapter to supervise its own build or initial process creation.

The doctrine must choose and bound a control-plane bootstrap path. The preferred steady-state shape is an
operator-installed, independently authenticated, per-project Haskell anchor that acquires a cataloged bootstrap
cell and launches `pb` or the new source-bound binary as its child. This does not require shared implementation
code or a common scheduling daemon. A first installation that cannot use such an anchor must be an explicit
privileged enrollment or maintenance operation on a quiescent or disposable host, outside the participating-project
guarantee; it cannot be silently treated as an ordinary governed workload.

The bootstrap exception should cover only installing or starting the authority control plane. Once the anchor is
live, toolchain compilation, compiler fan-out, engines, VMs, containers, clusters, and workloads are governed
children. Phase 50 continues to validate the bounded `pb` identity/argv/`exec` handoff from an exact source-bound
Haskell supervisor, and the new live authority phase starts its candidate from an external supervisor rather than
claiming that the candidate authorized its own creation.

### 4.17 Artifact identity is conditional, not inherent

The proposal uses exact artifact identity as though filesystem group membership and an ABI digest authenticated the
calling binary. They do not. In the cooperative profile, the operator may trust the enrolled principal to run only
approved artifacts, but that is a deployment assumption. A stronger artifact-bound claim requires an authenticated
launcher or OS measurement whose observation is part of the platform gate. The ABI should distinguish those two
strengths rather than presenting enrollment metadata as cryptographic process identity.

---

## 5. Accelerator-owner generalization

### 5.1 Move the singleton to the allocation unit

The correct replacement for "one accelerator owner per node" is not an unconstrained list of owners. It is:

> One live holder per resource cell or cross-project allocation leaf. One host may contain a finite opaque set of
> owners whose alias closures, scalar budgets, allocation modes, and mechanism strengths are pairwise compatible.

This retains the useful singleton invariant at the granularity that is actually isolated.

### 5.2 Separate identities currently fused as owner

The current doctrine and implementation conflate three identities:

1. the host-protocol cell holder: `ProjectId`, `ParentScopeId`, `ClaimKey`, and generation;
2. the execution consumer: a container instance or supervised host process; and
3. the internal train, serve, JIT, or library workload multiplexed by that consumer.

They should become nominally distinct. An `ExtensionId` selects linked implementation behavior; it is not a
cross-project host identity and cannot mint another `ProjectId`.

An illustrative target shape is:

```text
CellHolder
  = ProjectId x ParentScopeId x ClaimKey x AttemptGeneration

AcceleratorAllocation
  = WholeCudaDevice CudaGpuUuid
  | MigGpuInstance CudaGpuUuid MigGiUuid
  | MpsClientSlots CudaGpuUuid MpsServerEpoch SlotSet Caps
  | WholeMetalDevice MetalRegistryIdentity

GrantedOwner
  = CellHolder x OwnerId x ExecutionInstanceId
    x ResourceCell x AcceleratorAllocation x MechanismStrength

CompatibleOwnerSet
  = opaque finite collection produced only by the complete compatibility fold
```

The outer cell grant becomes the parent supply for Amoebius `ClusterBudget` and internal placement. Internal
workers consume checked child authorities and never reacquire the host-global locks.

### 5.3 Exact compatibility rules

| Allocation | Compatibility rule |
|---|---|
| Distinct whole CUDA GPU UUIDs | Concurrent owners permitted |
| Same whole CUDA GPU UUID | Exactly one live owner |
| Whole GPU and any MIG or MPS descendant | Conflict |
| Distinct MIG GPU Instances under one GPU | Concurrent owners permitted with hardware-partitioned strength |
| Distinct Compute Instances inside one GI | Not independent cross-project leaves; conflict at the GI |
| MPS clients | One exact server epoch, finite disjoint slots, static aggregate caps and reserve; `BoundedShared`, never exclusive |
| Metal | One live whole-device holder; multiple projects may be eligible but execute serially |

For MPS, “disjoint cells” can mean disjoint ledger slots and admitted caps; it cannot mean disjoint physical
performance domains. The shared GPU ancestor and weaker strength must remain visible in the type and receipt. Mixed
MIG-plus-MPS or MPS-inside-MIG should refuse in v1 unless a later closed constructor and live gate establish the
exact composition.

A multi-GPU owner may hold an alias-closed nonempty bundle acquired atomically. The catalog must prove that every
accelerator root is either reserved, assigned whole, partitioned into compatible children, or placed into one
bounded-sharing pool—never a parent and child at the same time.

Same-key replay is not another owner. The same display name with a different claim or generation is another owner
and must conflict if its allocation overlaps.

### 5.4 What changes in the illegal-state catalog

The current illegal state "two accelerator owners on one node" becomes too broad. It should be replaced by cases
such as:

- two live exclusive grants whose allocation closures overlap;
- a whole-device grant combined with a child partition grant;
- two cross-project claims within one MIG GI;
- a scalar GPU or VRAM quantity presented as a physical lock identity;
- count-only allocation presented as exact device ownership;
- a bounded-sharing mechanism relabeled as strict or hardware-partitioned;
- two distinct claims deduplicated only because their display owner text is equal; and
- a granted owner that is not a child of a live cell authority.

Two disjoint owners on one host becomes a positive case.

### 5.5 Current Haskell model is a useful but insufficient starting point

[`Amoebius.Capacity.Accelerator`](src/Amoebius/Capacity/Accelerator.hs) already contains a flat
owner-to-device-set exclusivity check and accepts different owners when their device sets are disjoint. That is the
right elementary relation, but it currently lacks:

- nominal project, parent, claim, cell, host, boot, and epoch identities;
- a physical parent/child alias graph;
- mechanism and guarantee strength;
- collection-wide integration in the production provision fold;
- an exact distinction between retry identity and display owner name; and
- a runtime execution-authority witness.

Current provisioning also handles inference services independently and can assign the full offering to each before
the separate collection checker is considered. The complete owner collection must be provisioned in one fold and
returned as an opaque `CompatibleOwnerSet`.

### 5.6 Count-only Kubernetes GPU requests are the critical limit

The current whole-offering identity argument is sound for one already-exclusive owner: requesting the selected
node's full GPU count makes the device plugin's choice irrelevant because that owner receives every device. The
current production collection is not thereby sound—independent service provisioning can offer the whole set more
than once before a collection-wide compatibility proof. Once multiple owners request subsets,
`nvidia.com/gpu: 1` does not prove which physical UUID, topology, MIG instance, or protocol cell the pod receives.

The projection should therefore be a closed union resembling:

```text
NoAcceleratorClaim
| WholeCudaExtendedResource FullOfferingCount OfferingClassKey
| ExactCudaResourceClaim CellClassKey
| MigResourceClaim MigProfile ExactAllocationReadback
| MpsClientClaim MpsServerEpoch SlotSet Caps
```

A count-only subset remains refused. Exact subsets require DRA, exact MIG resource identities, CDI or another
exact-device exposure path, or a dedicated VM/node whose visible offering is precisely the grant. Device identity
must be read back before the host record reaches `Running`.

A DaemonSet is also semantically one workload per node, not one per resource cell. Multiple cells on one node need
a cell-aware controller or resource-claim mechanism with deterministic owner identity and exact allocation
readback.

### 5.7 Scheduler and recovery join

The cluster scheduler's reservation is not the host protocol's machine-global authority. In the normal long-lived
cluster shape, the cluster anchor already holds the one parent cell. A pod or inference request consumes a checked
child grant from that held supply and must not reacquire the host-global cell or domain locks:

```text
cluster parent cell and walls already held by the anchor
  -> child budget/allocation selected from that cell
  -> scheduler reservation CAS against the same parent generation
  -> BindingInFlight
  -> Kubernetes binding and exact allocation readback
  -> child record Running beneath the parent authority
```

An unknown CAS or binding result retains the parent authority and scheduler debit until reconciliation. A CAS loser
releases only the unused child debit; it does not release or mutate the parent cell. Recovery binds the parent claim
and generation, child identity, Pod UID, cell, host epoch, and exact allocation identity.

A workload may acquire another host cell before the scheduler CAS only when it uses a separately registered parent
scope whose worst-case concurrency is already charged into the catalog. That less common path performs full host
admission, empty-wall readback, and then the scheduler join; an unknown outcome retains both the new host lease and
the scheduler debit. Keeping these two routes distinct avoids turning every pod into a machine-global claimant.

Mode-specific release is required:

- whole CUDA proves the exact GPU context and exposure empty;
- MIG proves only the exact GI/CI exposure empty and never resets a physical GPU with live sibling GIs;
- MPS proves the exact client slots empty and mutates the server only when all slots are idle; and
- Metal retains the exclusive device drain rule.

### 5.8 Parent-scope discipline

Amoebius should not create one host `ParentScopeId` per pod or inference request. The default remains one live parent
reservation for the project, split into checked child owners. Additional independently reserving scopes are
operator-reviewed catalog weakenings whose worst-case concurrency is charged into the layout.

A long-lived cluster and a later transient accelerator workload therefore need either:

- one cell that reserves both from the beginning; or
- two explicitly registered parent scopes with joint peak accounting.

Live bundle growth after the first cell is granted remains forbidden.

---

## 6. Expected impact on Amoebius

### 6.1 Doctrine impact

The proposal changes or qualifies the following authoritative surfaces:

- `documents/engineering/shared_host_resource_protocol.md`: governance,
  trust, lock inventory, API, recovery, upgrade, conformance, root bounds, and phase routing;
- `documents/engineering/lift_and_compose_doctrine.md`: implementation independence
  plus the single shared-protocol exception;
- `documents/engineering/repository_layout_doctrine.md`: operator-owned external
  coordination state as the sole host-global exception;
- testing and cluster-lifecycle doctrine: dedicated-host use of the real root and exact retained-state accounting;
- `documents/engineering/daemon_topology_doctrine.md`: singleton-per-cell rather
  than singleton-per-node;
- the resource-capacity types, construction, source, fold, schema, and storage family: cell-parent supply,
  allocation graphs, compatible owner sets, mechanism strength, and durable-transfer semantics;
- service capability and substrate doctrine: exact accelerator claim projection and native host-anchor routes;
- the illegal-state catalog and technique index: overlapping allocation rather than multiple owners as such; and
- the formal-model doctrine and DSL model: finite-resource authority as an explicit temporal reservation
  obligation.

The protocol document also needs the canonical closing `## Related Documents` section and backlinks expected by
the documentation standard.

### 6.2 Haskell type and module impact

Likely new or substantially changed Haskell surfaces include:

- protocol revision and canonical encoding;
- observed host, boot, epoch, project, parent, cell, domain, claim, generation, anchor, operation, and receipt
  identities;
- resource-cell catalog decoding and conservation proof;
- an alias-aware physical-domain graph;
- `AdmissionCandidates`, cell selection, lock acquisition, durable journaling, recovery, and quarantine;
- platform-independent effect algebra plus Linux, Darwin, and Windows interpreters;
- a linear or region-scoped execution authority required by every host launch path;
- durable-storage authority transfer;
- accelerator requirement, compatible-owner collection, exact grant, and claim-projection types; and
- independent semantic oracles, compile-fail declarations, mutants, crash schedules, and live observers.

All behavioral source remains Haskell. CBOR vectors, TLA+, platform fixtures, mutant materializations, helper
programs, and serialized observations remain lazy products under `.build/**`. The bounded Python bootstrap gains
no product or validation responsibility.

### 6.3 Runtime impact

After the bounded control-plane bootstrap in [§4.16](#416-the-first-authority-process-has-a-bootstrap-recursion),
every governed host effect becomes authority-mediated:

- process and compiler launches;
- host-native inference and training workers;
- VM and container creation;
- cluster bring-up and teardown;
- device exposure and accelerator contexts;
- resource-wall mutation and readback;
- retained-storage allocation or transfer; and
- recovery or destructive cleanup.

The host anchor must outlive a CLI when the governed workload outlives that CLI. Workload children receive checked
child authority but no host lock handles. Direct OS, Docker, Colima, WSL, VM, CUDA, Metal, or Kubernetes launch
paths that bypass the closed interpreter become legacy findings.

### 6.4 Scheduler and provider impact

The existing capacity scheduler must join its cluster reservation with a host-cell grant and carry structured
accelerator identities rather than flat device strings. Unknown scheduling or binding outcomes retain both sides
until reconciled.

Provider-created nodes cannot become scheduler candidates from template declarations alone. Host enrollment must
install and verify the fixed root, observe actual resources, instantiate a cell catalog and epoch, and publish the
node only after that authority surface is ready. Dynamic node replacement changes host, boot, root, and device
brands and therefore invalidates old grants.

### 6.5 Operational impact

Operators gain responsibilities not present in the repository-contained model:

- privileged host enrollment and root installation;
- project-principal and artifact enrollment;
- finite cell-catalog design and reserve sizing;
- maintenance-mode ABI migration;
- quarantine inspection and privileged clearing;
- bounded receipt/tombstone lifecycle and root capacity monitoring;
- exact decommission/reprovision procedures; and
- acquisition of dedicated hosts for live platform gates.

The daemonless design avoids a permanent common scheduling service, but it does not avoid distributed-protocol
operations. Mixed versions fail closed, which favors safety but can reduce availability during coordinated
upgrades.

### 6.6 Performance and utilization impact

Fixed cells and one-parent defaults can strand capacity. All-nonblocking admission can be unfair. Whole-device
serialization can underutilize GPUs, while aggressive partitioning increases catalog, recovery, and observability
complexity. These are deliberate tradeoffs, not implementation defects, but the protocol should state that it
guarantees exclusion and boundedness rather than optimal packing or fairness.

---

## 7. Development-plan refactor

### 7.1 Standards constraints

The refactor must obey the following existing rules:

- phases remain contiguous and bind the immediate predecessor in numerical order;
- Phase 49 remains the complete hardware-free promotion barrier;
- Phase 50 remains the bounded `pb` handoff gate;
- Phase 51 remains the fake-boundary host-ensure gate;
- Phase 52 remains the first hardware-bearing phase;
- one phase has one final register and one real substrate;
- independently useful engine, resource-authority, MIG, and MPS claims split;
- reordered paths carry a complete old path to new path audit map;
- changed subjects, contracts, or predecessors invalidate affected evidence; and
- only a human may promote a phase or sprint.

The governing rules are in `DEVELOPMENT_PLAN/development_plan_phase_model.md`,
`DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, and
`DEVELOPMENT_PLAN/development_plan_standards.md`.

### 7.2 Recommended v1 phase map

| Old phase range | New phase range | Treatment |
|---|---|---|
| 0–51 | 0–51 | Numbers retained; selected contracts reopened or amended |
| — | 52 | New Linux finite-resource execution-authority phase |
| 52 | 53 | Existing Linux engine phase follows its authority phase |
| — | 54 | New Darwin finite-resource execution-authority phase |
| 53 | 55 | Existing Apple engine phase follows its authority phase |
| — | 56 | New Windows finite-resource execution-authority phase |
| 54–92 | 57–95 | Remaining existing phases shift by three |
| — | 96 | New Linux-CUDA whole-device execution-authority phase |
| 93–95 | 97–99 | Existing phases shift by four |

This extends the closed domain from `0..95` to `0..99`. The range table is explanatory only; the actual plan
change must carry an explicit mapping for every old identifier and file.

Interleaving each native authority immediately before its existing engine consumer preserves the plan's current
Linux-first progression. Placing all three authority phases before the Linux engine would make Linux progress wait
for unrelated Apple and Windows promotion even though those adapters are independently useful capabilities.

Notable mappings are:

| Old | New | Capability |
|---:|---:|---|
| 52 | 53 | Linux engine and native image |
| 53 | 55 | Apple Homebrew/Colima engine |
| 54 | 57 | Windows WSL2 engine |
| 55 | 58 | Substrate coordinator and kind cluster |
| 56 | 59 | Base image and registry |
| 59 | 62 | Capacity scheduler |
| 60 | 63 | Retained storage |
| 79 | 82 | Provider dynamic nodes |
| 89 | 92 | Apple-Metal host daemon |
| 90 | 93 | Live test topology |
| 91 | 94 | Infernix core re-derivation |
| 92 | 95 | Infernix UI re-derivation |
| 93 | 97 | jitML numerical/CUDA re-derivation |
| 94 | 98 | jitML UI re-derivation |
| 95 | 99 | Multi-tenant web application re-derivation |

MIG may become Phase 100 if current-plan live conformance is desired. MPS should be a separate later phase. If they
are not numbered now, the protocol may still define and safely decode their ABI forms, while Amoebius marks the
mechanism rows unadvertised and `UNVERIFIED`.

### 7.3 Existing contracts to reopen or amend

| Phase | Required contract change |
|---:|---|
| 0 | Extend phase-domain/contract registries, documentation cardinality, legacy universe, old-to-new map, and the state-root policy/oracle with the exact host-protocol exception; invalidate prior component diagnostics for the changed contract |
| 2 | Reconcile phase-path and ordinal analyzers after renumbering |
| 9 | Add cell topology, physical-domain hierarchy, alias closure, and host reserve |
| 18 | Add finite-resource temporal model and invariants |
| 19 | Add deterministic crash, delayed-effect, reconciliation, and quarantine schedules |
| 20–24 | Add the closed resource-authority mechanism profiles to extension declaration, per-profile laws, composition/security laws, and generated conformance where the substrate-extension doctrine applies |
| 25 | Project the closed resource-domain, allocation-mode, mechanism-strength, and refusal schema from Haskell |
| 26 | Add exact semantic ABI declarations, canonical CBOR and total decoder |
| 27 | Replace per-node singleton negatives with compatibility, overlap, strength, and authority negatives |
| 28 | Add execution-to-durable allocation transfer semantics |
| 29 | Add complete cell/owner compatibility and resource-vector fold |
| 30–32 | Carry requirements, candidates, parent scopes, allocation modes, and refusal reasons through bind/provision |
| 33 | Render the closed exact-claim projection and refuse unsupported count-only subsets |
| 34 | Require execution authority at the typed effect boundary and probe direct-launch bypasses |
| 47 | Extend the Haskell-owned generated vector, crash-schedule, compile-negative, and changed-subject mutant declarations without making generated artifacts authoritative |
| 48 | Add authority acquisition/release and retained-root treatment to the test workflow |
| 49 | Re-exercise all hardware-free protocol surfaces in the integrated barrier |
| 51 | Preserve host ensure as its only final claim; revise `LTD-HOST-002` and its oracle for the exact fixed-root exception, and update only prerequisites and citations needed by later adapters |
| Every shifted phase | Reopen its path, ordinal, immediate predecessor, status block, first-sprint blocker, typed contract, tracker row, and backlinks; no evidence bound to the former identity survives |
| Old 52–60 → new 53–63 | Make engine, coordinator, object-recovery, capacity-scheduler, and retained-storage effects children of live authority; add direct-launch, unknown-join, and residue criteria where the subject changes |
| Old 61–92 → new 64–95; old 93–95 → new 97–99 | Audit every live capability for raw process, VM, container, cluster, provider, or device effects and substantively reopen each matching consumer; known high-impact loci include old 79, 89–90, and 93–94 |

Phase 0 changes because the closed phase domain and typed registry change. Although the current tracker already marks
the work NOT VALIDATED, every diagnostic tied to the previous Phase-0 contract becomes stale and must be rerun.

The supporting changes in Phases 18–29 do not create separate live protocol products. They extend the final claim
already owned by each formal-model, extension-law, schema, decoder, or fold phase at its existing register. Live
kernel authority remains the independently useful Register-3 claim of the new platform phases. If review finds that
one of those supporting additions is independently useful outside its existing final claim, the phase-model split
rule requires another phase instead of widening that contract.

### 7.4 New phase shapes

#### Phase 52: Linux finite-resource execution authority

- `Substrate`: `linux-cpu`
- `Lane`: `linux-cpu/amd64`
- `Register`: 3
- immediate predecessor: Phase 51 human approval
- environment: existing disposable Linux CPU host requirement

One final claim: on a fresh Linux host, the exact Amoebius artifact launches governed work only while its enrolled
principal holds the selected cell and physical locks and all required Linux walls are applied and read back; crash
and reboot never permit an uncertain cell to be stolen. Independently built peer artifacts are black-box
interoperability observations for this Amoebius candidate, not subjects promoted by the phase.

Suggested seams are protocol binding and fake support, root/identity/lock adapter, cgroup/storage walls, recovery,
and the integrated contention/bypass/residue gate.

#### Phase 54: Darwin finite-resource execution authority

- `Substrate`: `apple`
- `Lane`: `metal`
- `Register`: 3
- immediate predecessor: shifted Linux engine Phase 53 human approval

One final claim: the native Darwin adapter enforces the exact shared root and lock ABI, charges unified memory,
serializes whole Metal ownership, supervises the declared process profile, and refuses requirements stronger than
its observed mechanisms.

#### Phase 56: Windows finite-resource execution authority

- `Substrate`: `windows`
- `Lane`: a new native `windows/amd64` lane
- `Register`: 3
- immediate predecessor: shifted Apple engine Phase 55 human approval

One final claim: the native Windows adapter uses the exact ProgramData root, DACL and file identity, `LockFileEx`,
boot identity and Job Object walls, and keeps native host authority outside WSL.

The current WSL `linux-cpu/amd64` lane cannot honestly validate native Windows handle and Job Object behavior. The
closed lane and environmental-requirement vocabularies therefore need reviewed extensions.

#### Phase 96: Linux-CUDA whole-device execution authority

- `Substrate`: `linux-cuda`
- `Lane`: `cuda`
- `Register`: 3
- immediate predecessor: shifted Phase 95 human approval

One final claim: the adapter binds exact observed GPU UUIDs to whole-device locks and exact exposure, permits
concurrent owners only on distinct devices, refuses count-only exactness and all-device bypass, and recovers without
resetting a foreign or uncertain device.

The gate needs a natural multi-GPU CUDA host if simultaneous disjoint whole-device ownership is part of the claim.
Unavailable hardware blocks the phase; it must not be skipped or simulated into a live result.

---

## 8. Validation impact

### 8.1 Fixed gate contract remains mandatory

Every new or reopened phase uses the existing eighteen-row gate: Claim, Subject, Command, Oracle, Positive
controls, Paired negatives, Mutants, Discovery, Challenge, Observer, Authority/bypass, Freshness, Qualification,
Cleanroom, Legacy closure, Predecessor, Residue, and Human authority.

The protocol may not replace those rows with an ABI digest, receipt count, conformance badge, or top-level success
bit.

### 8.2 Required pure and modeled corpus

The hardware-free corpus should include:

- exact canonical layout and requirement encodings;
- cell conservation and host-reserve bounds;
- every single-axis overflow and integer overflow;
- unified-memory aliasing;
- disjoint owner acceptance and overlapping owner refusal;
- whole-device/child conflict and distinct-MIG-GI compatibility;
- MPS cap, slot, and strength classification even when live support is unadvertised;
- unsupported hardware and weaker-mechanism refusals;
- stale host, boot, epoch, root, catalog and device identity;
- the exact fixed-root exception accepted while arbitrary external state loci refuse;
- same-key replay, different-key parent contention, spent-key reuse and generation exhaustion;
- lock rollback and canonical ordering;
- crash before and after every durable transition;
- delayed effect completion after an absence observation;
- cross-parent quarantine fencing; and
- persistent-storage transfer or refusal before cell release.

Compile-fail cases should target forged or substituted authority, host/boot/domain brands, region escape, linear
reuse, duplicate handle acquisition, phase skip, and mechanism-strength substitution. A raw request for unavailable
hardware remains representable and returns a structured refusal.

### 8.3 Changed-subject mutants

At minimum, independently registered mutants should cover:

- omitted cell lock;
- omitted ancestor lock;
- cell selection before the admission critical section;
- partial-lock leak;
- early release of epoch, cell, parent, or domain locks;
- mutation before durable `Prepared`;
- retirement before delayed-operation fencing;
- quarantine ignored by another parent;
- corrupt record treated as free;
- skipped wall application or readback;
- count-only allocation treated as exact identity;
- same display owner treated as same claim;
- same-key workload rerun after `Running`;
- permissive ABI version range;
- a self-reported digest treated as authenticated artifact identity;
- an authority process treated as authorizing its own initial launch, or the bootstrap exception widened to an
  ordinary post-enrollment workload;
- replaced root or lock object accepted;
- an undeclared second host-global state object accepted;
- an internal child allocation reacquiring host-global locks from its already held parent;
- child lock handle inherited;
- raw launch reaching the strict adapter surface; and
- cleanup deleting a foreign or permanent protocol object.

Each mutant must change the intended production locus, make its assigned exact case red, and leave unrelated
controls green.

### 8.4 External observation and challenge

Live gates require post-start challenges and raw observations outside the subject:

- actual file and lock-object identities;
- competing acquisition behavior;
- cgroup, quota, process-tree, Job Object, VM, container, mount and device state;
- exact exposed device identity;
- before/during/after effect inventory;
- crash/reboot behavior; and
- zero foreign mutation or owned nonterminal residue.

Subject logs and self-reported receipts are supporting diagnostics only.

### 8.5 Root cleanup is retained-resource accounting

The installed layout and permanent lock objects are intended retained resources. A validation gate must not delete
them to manufacture zero residue. It should either run on a disposable host whose outer owner later destroys the
host, or declare the exact installed root objects as retained and prove:

- no nonterminal owned allocations remain;
- no owned workload, wall, VM, container, mount, process, device context, or slot remains;
- no foreign object changed; and
- only the exact permitted terminal receipt or bounded high-water state remains.

---

## 9. Legacy-tracking impact

### 9.1 Executable authority remains Haskell

`DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md` is only the reader-facing
explanation. The executable inventory must remain the closed Haskell `Amoebius.Validation.Legacy` universe with one
stable identity, owner, analyzer key, total dispatch, closure observation, and required reintroduction case per
finding.

Before any new identifier is committed, an exact source-locus audit must determine whether the divergence is
present, where it is present, and which earliest phase must make the replacement true. Markdown must not invent the
executable inventory.

### 9.2 Expected candidate bindings

Subject to that audit, likely active bindings are:

| Candidate ID | Proposed owner | Reader-facing divergence |
|---|---:|---|
| `LTD-ABI-001` | 26 | No complete Haskell projection and total canonical decoder for the shared semantic ABI |
| `LTD-ACC-001` | 29 | Flat/full-offering per-node owner model instead of an opaque compatible singleton-per-cell allocation set |
| `LTD-HOST-003` | 34 | Production effect APIs can be reached without an opaque execution-authority argument |
| `LTD-HOST-004` | 52 | Linux fixed-root, lock, wall, journal and recovery adapter is absent |
| `LTD-HOST-005` | 54 | Native Darwin adapter is absent |
| `LTD-HOST-006` | 56 | Native Windows adapter is absent |
| `LTD-HOST-007` | 96 | Exact whole-device CUDA lock-to-exposure bridge is absent |

The owning phase must discover every matching current locus, bring the finding set to zero, run the independently
authored reintroduction negative, and retain that evidence in its integrated candidate. An unavailable analyzer at
or after its owner refuses.

### 9.3 Existing owner renumbering

`LTD-HOST-001` remains owned by Phase 51. `LTD-HOST-002` also remains owned by Phase 51, but its analyzer,
closure text, oracle, and reintroduction case must be reopened so the exact installed protocol namespace is not
misclassified as the ambient or caller-selected state fallback that the finding is meant to eliminate. Keeping its
ordinal does not preserve evidence for its changed predicate.

The phase refactor changes existing typed owner bindings:

| ID | Current owner | Proposed owner |
|---|---:|---:|
| `LTD-RUN-001` | 55 | 58 |
| `LTD-IMG-001` | 56 | 59 |
| `LTD-SEED-001` | 91 | 94 |
| `LTD-SEED-002` | 93 | 97 |

The compiled reverse map, phase semantic registry, independent oracle map, phase sprint fields, and reader-facing
explanations must move together.

### 9.4 Retirement procedure

A row is not removed when code merely changes or a local check becomes green. After the typed analyzer reaches
zero and its reintroduction case is qualified, the complete owning-phase candidate is reviewed. Only a human may
promote the phase. The successor then records the typed `Retired` transition; the reader-facing active row is
deleted, while the compiled identity, owner, analyzer key, and reintroduction negative remain. Git history is the
only prose archive.

---

## 10. Recommended adoption sequence

### Step 1: Reconcile doctrine and governance

Before implementation, settle the shared-release authority, protocol revision rules, enrollment model, cooperative
trust boundary, authenticated-versus-cooperative artifact identity, fixed-root exception including the Windows boot
key, bounded control-plane bootstrap, root capacity bound, upgrade transaction, and operator recovery role.

### Step 2: Repair the protocol ABI specification

Add the missing `CellLockKey`, exhaustive lock-kind inventory, candidate-selection API, provider operation fencing,
global quarantine rule, bounded key/receipt scheme, explicit replay result, durable-storage transfer, and exact
principal/ACL matrix. Specify durable storage as a fenced prepare/commit/recovery join rather than assuming
cross-store atomicity.

### Step 3: Perform one coherent plan and legacy refactor

Update the phase domain and complete old-to-new map, reopen the affected contracts, update every immediate
predecessor and backlink, extend the native lane and host-requirement vocabularies, add exact typed legacy bindings,
and update the reader-facing register. No implementation work should rely on stale phase numbers or the old
per-node owner SSoT.

### Step 4: Complete the hardware-free semantic surface

Implement the Haskell ABI, resource-cell graph, compatible-owner fold, temporal model, deterministic crash
schedules, total decoder, compile-fail surface, authority-gated effect vocabulary, independent oracles and mutants.
The integrated Phase-49 barrier should re-exercise those surfaces without live infrastructure.

### Step 5: Implement Linux CPU/RAM/storage authority

Use the fixed root, explicit cell lock, kernel-backed lifetime ownership, cgroup/storage walls, applied readback,
durable fencing and quarantine. Exercise independently built peer binaries against the same real root on a
disposable host. Those exact-artifact runs support only Amoebius's candidate; the jointly governed compatibility
matrix and each peer repository's phase authority remain separate. The shifted Linux engine phase follows this
authority phase and consumes it before Apple or Windows authority becomes a predecessor.

### Step 6: Add native Darwin and Windows adapters

Advertise only observed strengths. Darwin hard-memory requirements refuse and its shifted Apple engine follows the
Darwin authority phase. Windows committed-memory remains its own profile, WSL delegates to the native Windows
anchor, and the shifted Windows engine follows that authority phase.

### Step 7: Move engine and cluster phases behind authority

Bring up Docker, Colima, WSL, kind, images, clusters, retained storage, provider nodes and host workers only as
children of a live execution authority. Join the capacity scheduler and retained-storage state machines explicitly.

### Step 8: Generalize accelerators conservatively

First retain whole-device exclusive operation and demonstrate multiple concurrent owners only on exact disjoint
devices. Then add strict MIG GPU-Instance cells as a separate capability. Leave MPS unadvertised until its service
epoch, finite slot/cap accounting, recovery, external observation, and weaker guarantee earn a separate live phase.

---

## 11. Final assessment

The proposal is a strong architectural direction for Amoebius once it is understood as a jointly governed
cross-project protocol rather than four coincidentally similar local designs. The fixed host root is a defensible
exception because safe cross-repository arbitration requires a shared rendezvous point, provided that the exception
is operator-owned, singular, bounded, and inaccessible to ordinary workload code.

The accelerator generalization also makes sense, but only if exclusivity is retained at the resource-cell or
physical-leaf level. Removing the node singleton without introducing exact allocation identity, hierarchy-aware
compatibility, and enforceable device projection would weaken the current safety property. The correct outcome is
many compatible owners per host, never many unqualified owners of the same physical resource.

The expected impact is substantial: doctrine, phase numbering, validation contracts, legacy bindings, resource
types, renderers, scheduler state, provider enrollment, live launch paths, storage lifetime, testing and operations
all change. That cost is justified if shared-host execution is a long-term project requirement. It would not be
justified as a small local optimization or an optional wrapper around existing launch paths.

The recommended adoption criterion is therefore not simply "the protocol compiles." It is that the revised
doctrine and plan establish one exact shared ABI, one bounded logical host namespace, singleton-per-cell ownership,
a bounded non-circular control-plane bootstrap and no raw governed-effect bypass after it, modeled crash safety,
honest platform strengths, exact external observation, and human-reviewed evidence for each advertised live
mechanism.

## Related Documents

- `documents/engineering/shared_host_resource_protocol.md`
- `documents/engineering/lift_and_compose_doctrine.md`
- `documents/engineering/repository_layout_doctrine.md`
- `documents/engineering/daemon_topology_doctrine.md`
- `documents/engineering/resource_capacity_types.md`
- `documents/engineering/resource_capacity_folds.md`
- `documents/engineering/storage_lifecycle_doctrine.md`
- `DEVELOPMENT_PLAN/development_plan_standards.md`
- `DEVELOPMENT_PLAN/development_plan_phase_model.md`
- `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`
- `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`
- `DEVELOPMENT_PLAN/README.md`
