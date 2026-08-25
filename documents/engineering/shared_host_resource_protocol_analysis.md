# Shared Host Resource Protocol Analysis

> **Purpose**: Record a critical project-specific assessment of the proposed Shared Host Resource Protocol,
> including its strengths, integration conflicts, safety gaps, and prerequisites for adoption by amoebius.
> **Read this if**: the protocol is being reviewed, revised, assigned to phases, or considered for implementation.

This reference-only analysis evaluates the
[Shared Host Resource Protocol](./shared_host_resource_protocol.md) against the present amoebius doctrine and
development-plan shape. It owns no protocol semantics, implementation status, validation result, or phase
promotion. The protocol remains the proposal authority; this document records review findings and a proposed
path for resolving them.

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/shared_host_resource_protocol.md
**Generated sections**: none

</details>

## Contents

- [1. Scope and conclusion](#1-scope-and-conclusion)
- [2. Summary of the proposed architecture](#2-summary-of-the-proposed-architecture)
- [3. Where the proposal fits amoebius well](#3-where-the-proposal-fits-amoebius-well)
- [4. Principal findings](#4-principal-findings)
- [5. Amoebius ownership and ledger integration](#5-amoebius-ownership-and-ledger-integration)
- [6. Threat-model and assurance assessment](#6-threat-model-and-assurance-assessment)
- [7. Required protocol corrections](#7-required-protocol-corrections)
- [8. Recommended plan integration](#8-recommended-plan-integration)
- [9. Recommended disposition](#9-recommended-disposition)
- [Related Documents](#related-documents)

## 1. Scope and conclusion

The proposal addresses a real problem. Several independently evolving projects may execute on one physical
host while accounting for central processing unit (CPU), memory, storage, virtual-machine, build, and
accelerator demand differently. Repository-local locks and project-local schedulers cannot prevent those
projects from spending the same physical capacity simultaneously.

The proposed response is safety-oriented and generally well shaped. It separates a small interoperability
kernel from resource-family declarations, enforcement mechanisms, and project-local lifecycle adapters. It
also distinguishes cooperative exclusion from enforced containment and durable crash recovery.

The proposal is not yet suitable as an amoebius implementation contract. Three classes of work remain:

1. A direct conflict with the authoritative seed non-dependency rule must be resolved.
2. The new host journal must be composed with existing amoebius reservation and host-ledger authorities.
3. Several protocol-critical races, transition gaps, and identity claims need exact operational semantics.

The appropriate present status is therefore **Reference only**. The design is promising, but the neutral core
should not be frozen and no implementation claim should be derived from the current prose.

## 2. Summary of the proposed architecture

The protocol has five cooperating ownership surfaces.

### 2.1 Operator-installed host catalog

A human operator installs a signed catalog beneath one fixed machine-wide root. The catalog declares finite
admission slots, base cells, turn cells, physical resource identities, reserves, supported family and
mechanism revisions, and bounded protocol storage.

Every participating implementation opens the same permanent lock and journal objects. Repository-local or
version-specific roots are forbidden because they would allow two implementations to believe they held the
same logical cell while actually locking different objects.

### 2.2 Interoperability kernel

The neutral kernel owns the facts that every participant must interpret identically:

- canonical identifiers and encoding;
- catalog and epoch identity;
- permanent object grammar;
- acquisition order and lock modes;
- bounded journal pages and receipt windows;
- lease and quarantine transitions; and
- compatibility and saturation refusals.

During the seed period, participating seeds would pin a neutral Haskell release or implement a bounded
compatibility port. Amoebius would re-derive an independent implementation instead of importing the neutral
package.

### 2.3 Resource-family declarations

A resource family projects physical capacity into the core algebra. Examples include CPU, memory, storage,
CUDA, Metal, and future accelerator families. The declaration owns stable physical identities, capacity
dimensions, aliases, parent-child relationships, conflicts, and invalidators.

This layer is metadata about physical resources. It is not the product-local substrate taxonomy and does not
own a workload lifecycle.

### 2.4 Mechanism-profile declarations

A mechanism profile describes how one resource family is excluded, contained, observed, or partitioned on a
particular kernel backend. Examples include Linux control groups, Windows Job Objects, filesystem quotas,
whole-device locks, hardware partitions, and reactive Apple supervision.

Mechanism strength is resource-indexed. Exclusive ownership of a device does not imply a scalar memory
ceiling, and a reactive observer does not imply prevention.

### 2.5 Project-local adapters and anchors

Each project retains the conversion from its own validated workload meaning into a normalized requirement.
It also retains closed launch vocabulary, lifecycle transitions, recovery logic, cleanup, and terminal result
semantics.

A foreground operation retains its locks in the invoking process. A persistent effect uses a project-local
anchor whose shared responsibility is limited to lock and enforcement-domain custody. The anchor does not
become a cross-project scheduler or generic lifecycle reconciler.

## 3. Where the proposal fits amoebius well

### 3.1 Honest progressive assurance

The distinction between
[`CooperativeCellLease`, `EnforcedCellLease`, and `RecoverableExecutionAuthority`](./shared_host_resource_protocol.md#53-progressive-assurance)
is one of the proposal's strongest features. It prevents a file lock from
being described as a memory wall and prevents a successfully applied wall from being described as crash-safe
recovery.

The [resource-indexed mechanism strengths](./shared_host_resource_protocol.md#54-resource-indexed-mechanism-strength)
provide the same honesty at a finer grain. `AdmissionOnly`, `Exclusive`, `Reactive`, `HardCeiling`,
`HardwarePartitioned`, and `BoundedShared` state materially different
claims and are not collapsed into one misleading strength ladder.

### 3.2 Failure-closed crash handling

Unexpected process exit or reboot releases kernel locks but does not prove that a persistent external effect
is gone. The protocol correctly treats that event as permission to recover or quarantine, never as permission
to reuse capacity immediately.

Delayed provider operations also receive the right treatment. Object absence is insufficient when an earlier
request may still complete. A monotonic provider fence, a terminal or cancelled operation result, or a drain
barrier is required before capacity becomes reusable.

### 3.3 Base and turn separation

Separating long-lived base capacity from short accelerator or build turns fits amoebius and the machine
learning seeds particularly well. A persistent cluster need not monopolize a graphics processing unit (GPU),
and a later GPU acquisition cannot become arbitrary unplanned growth.

The capacity law also correctly joins base offers, turn offers, the host reserve, aliases, and retained
storage stock. Apple unified memory is charged once, while durable bytes remain charged after compute ends.

### 3.4 Extension-compatible structure

The core, family, mechanism, and adapter separation is compatible with amoebius's broader extension direction.
A new physical family does not need to duplicate the host lifecycle. A project still maps its own substrate
and workload vocabulary into the generic projection once.

This is compatible in principle with finite link-time registries and private constructors. It does not
authorize runtime plugin loading, wildcard decoding, or stringly fallback behavior.

### 3.5 Tracked-source and evidence discipline

The proposal keeps canonical declarations, laws, and vectors in Haskell. Serialized vectors and rendered
protocol artifacts remain lazy materializations beneath `.build/**`. That matches the repository's
tracked-source boundary.

The document also correctly refuses to treat matching Markdown, self-reported digests, local receipts, or a
green component command as conformance or phase-promotion authority.

## 4. Principal findings

### 4.1 Blocker: the cutover conflicts with seed non-dependency

The proposed
[ownership cutover](./shared_host_resource_protocol.md#166-amoebius-ownership-cutover) permits a seed that
remains independently runnable after workflow lift to acquire a deliberate runtime dependency on the
amoebius-owned surface. The authoritative lift doctrine instead states that no seed
depends on amoebius and that amoebius does not become seed infrastructure.

The time qualification in the proposal does not resolve the contradiction. The lift doctrine's rule is not
limited to the seed period and explicitly says that no amoebius phase asks a seed to adopt an amoebius
interface.

One of two policies must become explicit:

- independently runnable seeds remain pinned to the final neutral compatibility release indefinitely; or
- the lift doctrine receives a reviewed post-lift exception for an explicit runtime migration.

Until that decision is made in the authoritative owner, the protocol cannot define the cutover.

### 4.2 Blocker: the numerical plan does not own the protocol

The Phase-0 registration record explicitly says the proposal changed the governed documentation inventory but
amended no phase contract or predecessor edge. That is an accurate status statement, but it leaves every
implementation and validation obligation unassigned.

The proposal spans pure capacity arithmetic, formal state, extension declarations, authority construction,
native locks, durable journals, three operating-system backends, retained storage, persistent anchors, and
cross-project evidence. Treating all of this as an unnamed later-phase responsibility would create a parallel
architecture outside the plan.

The plan must assign the work as one coherent change before implementation starts. The assignment must also
respect the Phase-49 hardware-free promotion barrier and the prohibition on hardware-bearing validation before
its predecessors are approved.

### 4.3 Critical: catalog verification races epoch migration

The [admission sequence](./shared_host_resource_protocol.md#9-admission-and-acquisition) verifies the signed
catalog before it acquires the shared epoch lock. The
[migration sequence](./shared_host_resource_protocol.md#145-offline-upgrade) acquires that lock exclusively
and then publishes a fresh catalog epoch.

The following interleaving is therefore not excluded by the prose:

1. A client reads and verifies the old catalog.
2. The client is preempted before acquiring the shared epoch lock.
3. A migrator takes the epoch lock exclusively, publishes the new catalog, and releases the lock.
4. The client acquires the shared lock and continues with old verified bytes or new unverified bytes.

The permanent epoch object can be opened without trusting the catalog. The safe order is to validate the
fixed root and epoch-object identity, acquire the epoch lock shared, and only then read, verify, decode, and
bind the catalog while retaining that lock.

### 4.4 Critical: the recoverable effect transaction is incomplete

The admission algorithm publishes `Prepared`, applies mechanisms, reads them back, and then mints authority.
The separately described
[recovery machine](./shared_host_resource_protocol.md#112-recoverable-authority-records) also contains
`Applied`, `Running`, `Releasing`, and `Recovering`,
but the algorithm does not say when those durable transitions occur.

The missing crash prefixes include:

- an enforcement domain created only partially;
- one wall applied before another fails;
- effective-value readback failing after mutation;
- launch succeeding before `Running` is durable;
- launch outcome becoming unknown after a lost response;
- cleanup succeeding before a terminal record is durable; and
- the terminal record becoming durable before every retained output is settled.

Each external operation needs an exact sequence of durable intent, effect, readback, and durable transition.
Every failure branch must identify whether it cleans up to a verified free state, enters recovery, or
quarantines.

### 4.5 High: artifact identity is not grounded in a trusted observer

The [participating-project enrollment](./shared_host_resource_protocol.md#51-participating-projects) binds a
project identifier and operating-system principal to an exact artifact digest or trusted build provenance
policy. A pathname, argument vector, or self-reported digest is correctly rejected as
artifact identity.

The missing part is the observer. The neutral kernel is linked into the process being admitted and has no
independent privilege boundary. The proposal does not explain how it verifies its enclosing executable rather
than accepting a process-local assertion.

The claim must be weakened to cooperative provenance unless a backend supplies a trusted code-identity
observation. If exact artifact enforcement is retained, each operating-system backend needs a concrete,
externally grounded identity procedure and negative evidence for stale or substituted binaries.

### 4.6 High: shared cell pages cannot establish writer identity as specified

Under the [protocol permissions](./shared_host_resource_protocol.md#83-permissions), all enrolled principals
need bounded write access to shared cell pages because there is no broker. Later readers are expected to
reject a writer-identity mismatch.

A shared file records bytes, not the principal that authored each completed write. An embedded claimed writer
identifier can be substituted by any principal with write permission. The current layout therefore detects
invalid bytes and semantic mismatches, but it does not by itself authenticate the historical writer.

The protocol needs one of the following:

- a project-specific record signature with a defensible key-custody boundary;
- a platform mechanism that records authenticated writer identity per update; or
- an explicit statement that writer identity is cooperative and corruption yields quarantine only.

This choice also determines the availability threat. A buggy enrolled project can corrupt shared pages and
force indefinite quarantine across overlapping cells. That may be an acceptable safety-over-availability
trade, but it must be stated as an operational consequence.

### 4.7 High: base-plus-turn acquisition has no complete algorithm

The [turn-cell rule](./shared_host_resource_protocol.md#64-turn-cells) permits the same anchor to retain a base
lease and acquire a turn atomically. The generic acquisition algorithm, however, starts by taking the
admission-slot lock and then takes cell and domain locks in global order.

A live base holder already owns the slot lock and some domain locks. The protocol does not specify:

- whether the turn uses the base attempt or a child attempt;
- whether slot locking is reentrant and how that is portable;
- how new locks are ordered relative to retained base locks;
- which journal owns the in-flight turn transition;
- how partial turn acquisition rolls back without releasing the base; or
- how anchor death during turn acquisition or release is recovered.

This needs a separate `AcquireTurn` and `ReleaseTurn` state machine. The generic fresh-base acquisition
algorithm is not sufficient.

### 4.8 High: core version compatibility is ambiguous

The [versioning model](./shared_host_resource_protocol.md#141-core-and-family-versions-are-separate) pins one
`CoreMajor` at the host root, while a core release also has a content digest. The proposal does not say whether
two implementations with the same major but different release digests may operate concurrently.

If every release under one major must be semantically identical, almost any safety bug fix forces an offline
major migration. If patch releases may change behavior, exact-major matching does not ensure that participants
interpret the same record and transition semantics.

The protocol should distinguish:

- an exact protocol-semantic revision;
- an implementation release digest;
- a reviewed compatibility relation between implementation releases; and
- a minimum accepted release for security or correctness fixes.

The phrase "Haskell application binary interface" is also misleading. The cross-project boundary is the
encoding, permanent-object grammar, transitions, and refusal semantics. It is not the unstable binary package
interface produced by a particular compiler.

### 4.9 Medium: an isolation certificate proves only declared separation

The [unknown-family rule](./shared_host_resource_protocol.md#71-unknown-families-and-mechanisms) permits an old
core to accept a cell-local refusal when a signed isolation certificate says the unknown domains share no
ancestor, alias, conflict edge, or capacity dimension with eligible known cells.

The old core can prove that the supplied generic graph is internally disjoint. It cannot prove that the graph
truthfully represents physical aliasing. The signer authenticates the projection; signing does not turn a
hardware assertion into an observation.

The certificate should therefore be described as a signed separation claim joined with current stable
physical identities and independent observation. The core-readable projection envelope for an otherwise
unknown family also needs an exact schema.

### 4.10 Medium: participating-project scope is ambiguous

The project doctrine names five seeds: `hostbootstrap`, `prodbox`, `jitML`, `infernix`, and
`mattandjames`. The protocol repeatedly refers to four seeds and lists only the first four in its
[adoption table](./shared_host_resource_protocol.md#15-project-adoption-boundaries).

Excluding `mattandjames` may be correct because it is not presently a shared-host workload owner. The protocol
should state that exclusion and its rationale. Otherwise readers cannot tell whether the fifth seed was
deliberately out of scope or accidentally omitted.

### 4.11 Medium: the neutral kernel is conceptually narrow but operationally large

The shared boundary excludes project lifecycle and scheduling policy, which is good. Its remaining surface is
still substantial: cryptographic catalog verification, filesystem hardening, cross-platform locks, bounded
journals, crash recovery, migration, native containment, code identity, and quarantine administration.

Calling it small is defensible only in relation to the project lifecycles it excludes. It is still a
safety-critical cross-platform subsystem with a demanding release and governance burden. The first release
should freeze only semantics already backed by a complete transition model and conformance design.

## 5. Amoebius ownership and ledger integration

### 5.1 The host protocol and cluster scheduler have different scopes

The daemonless rule does not inherently conflict with the amoebius capacity scheduler. The protocol forbids a
cross-project host-global daemon that owns every project's policy and lifecycle. The amoebius scheduler is an
in-cluster role that binds Pods within one amoebius deployment.

Those roles can coexist only when their accounting relationship is explicit:

```text
shared-host base or turn cell
  -> physical-host capacity authority
  -> amoebius host reservation and placement supply
  -> in-cluster reservation ledger
  -> Pod binding
```

The shared-host lease must be the unique debit against physical host capacity. The inner scheduler may divide
that admitted supply among Pods, but it must not independently spend the same raw host capacity.

### 5.2 Phase 59 already owns an inner reservation machine

Phase 59 describes `Reserved`, `BindingInFlight`, `Bound`, `Terminating`, and `TerminalRetained` records. It
also preserves ambiguous or absent-Pod debits until cleanup evidence and a whole-root compare-and-swap (CAS)
transition succeed.

The shared-host cell machine must not duplicate those child transitions. It should treat the entire amoebius
cluster or host-worker envelope as one project-local effect. The project adapter then projects the inner
ledger's terminal and retained-state evidence into the outer cell transition.

### 5.3 Phase 89 already describes a host-ledger root

Phase 89 describes racing supervisor starts, crash points around reservation and launch, process-identity
repair, retained cache and log extents, and a host-ledger CAS root. That is materially the same ownership seam
as the proposed shared journal for the Apple host worker.

The plan should make Phase 89's host ledger either:

- the amoebius implementation of the shared protocol's cell and project records; or
- an inner project ledger with an exact one-to-one reference to the outer cell record.

Two independent roots that both claim to authorize host launch would recreate the double-spend problem inside
amoebius.

### 5.4 The project adapter is the correct join point

The adapter should own one total conversion from a fully provisioned amoebius workload into the generic host
requirement. It should preserve physical identities, aliases, mechanism strengths, retained storage, and
failure cases.

The reverse conversion should join the outer resource receipt with the inner lifecycle receipt. Neither
receipt alone should be accepted as the amoebius terminal result.

## 6. Threat-model and assurance assessment

### 6.1 What the cooperative profile can honestly claim

The cooperative profile can prevent conforming participating processes from acquiring the same permanent cell
or exclusive domain simultaneously. It can also retain conservative capacity arithmetic and quarantine stale
or uncertain state.

It cannot contain memory, CPU, device-memory, or storage growth. It also cannot constrain a foreign process,
an administrator, or a hostile process running as an enrolled principal.

### 6.2 What the enforced profile adds

The enforced profile adds empty-domain creation, wall application, and effective-value readback before work
starts. Its authority should be indexed by the exact set of resource-specific strengths established.

This profile still does not recover a persistent effect after holder death. A finite foreground operation may
quarantine on uncertainty without claiming durable reconciliation.

### 6.3 What recoverable authority must add

Recoverable authority requires a closed workload, durable intent, stable operation identities, delayed-effect
fencing, restart reconciliation, terminal cleanup evidence, and quarantine for every unresolved outcome.

For amoebius, a persistent cluster, virtual machine (VM), service, mount, restartable container, retained turn,
or provider-mediated host effect belongs only in this profile. A persistent effect cannot be admitted through
the cooperative profile merely because its launcher began in the foreground.

### 6.4 Whole-host claims remain exceptional

An open workstation cannot establish whole-host authority when foreign demand can grow without a wall. A
reserve can conservatively charge known unmanaged demand, but it cannot turn unbounded foreign growth into a
contained claimant.

The likely practical claim for shared developer hosts is participating-project coordination with explicit
foreign-process residue. Whole-host authority should remain reserved for fully contained or physically
partitioned environments.

## 7. Required protocol corrections

The following changes are prerequisites to a first core freeze.

### 7.1 Correct the epoch and catalog transaction

The client sequence should be:

1. Resolve and validate the fixed root without consulting mutable catalog semantics.
2. Open and validate the permanent epoch object.
3. Acquire it shared.
4. Read one catalog and signature snapshot.
5. Verify canonical encoding, signature, release compatibility, root identity, and enrollment.
6. Decode and bind the same verified bytes.
7. Retain the epoch lock for the complete lease.

Migration must take the same object exclusively before reading the old catalog or publishing any new epoch.

### 7.2 Publish a complete transition table

Every state transition should name:

- the locks that must be held;
- the required prior durable state;
- the external effect, if any;
- the readback that qualifies the result;
- the next durable state;
- the crash outcome before and after each boundary; and
- the only cleanup, recovery, or quarantine branches.

The table must cover both the minimal `Held` machine and the recoverable machine. The narrative arrow diagram
is useful orientation but is not yet an executable transition specification.

### 7.3 Define base and turn record ownership

A turn needs a child identity subordinate to a live base lease, a fixed record location, and a bounded attempt
generation. Its legal lock set must be derived before the base starts so no arbitrary growth enters later.

The core must define how a turn is acquired while base locks remain held and how the anchor recovers every
in-flight turn state after restart.

### 7.4 Separate protocol revision from implementation release

The catalog should pin the exact semantic protocol revision. Enrollment should additionally constrain the
accepted implementation release or compatibility verdict.

A bug-fixed implementation may coexist only when an explicit compatibility claim says that its observable
encoding, locking, transitions, and refusals remain identical for the pinned protocol revision.

### 7.5 Make identity claims backend-specific and observable

The core should define an abstract artifact-identity observation. Each backend must either provide an
externally grounded implementation or advertise that exact artifact enforcement is unsupported.

Record-writer authentication needs the same treatment. If no backend can establish historical writer identity
without a broker, the core should not claim that it can.

### 7.6 State the availability cost of quarantine

Quarantine intentionally favors safety over availability. The operator model should state that an enrolled
bug, damaged journal, failed disk, missing recovery provider, or malicious same-principal process may block a
cell indefinitely.

The privileged clear operation must require exact absence or controlled reprovisioning evidence and leave an
audited record. It must never become a force-unlock command based on elapsed time.

## 8. Recommended plan integration

The phase mapping below is an analysis recommendation, not an amendment to the development plan.

| Existing phase area | Protocol responsibility to reconcile |
|---|---|
| Phases 9 and 19 | Base/turn capacity epochs, aliases, reserve arithmetic, storage stock-flow, and modeled reservation behavior |
| Phases 11–16 | Cell and recovery model, explicit-state and symbolic checks, refinement, compile-fail authority cases, and deterministic crash schedules |
| Phases 20–24 | Resource-family and mechanism declarations, finite registries, laws, compatibility refusals, and conformance-plan derivation |
| Phases 29–32 | Accelerator family projection, mechanism satisfaction, project demand conversion, sealed provision, and execution-authority construction |
| Phase 48 | Closed workload and test-workflow integration, including foreground versus persistent classification |
| Phase 51 | Hardware-free fake boundary for roots, locks, journal pages, catalog verification, failures, and typed host operations |
| Phases 52–54 | Live Linux, Darwin, and Windows lock, containment, identity, readback, cleanup, and changed-subject evidence |
| Phases 55–59 | Persistent cluster anchor integration and the exact outer-cell to inner-scheduler reservation mapping |
| Phase 60 | Retained storage stock, terminal settlement, saturation, and quarantine interaction |
| Phase 89 | Apple host anchor, reactive Metal mechanism, turn custody, host-ledger replacement or mapping, and restart recovery |
| Phases 91–94 | Seed workflow re-derivation, adapter retirement, cross-project compatibility evidence, and any accepted ownership cutover |

The neutral repository is an external governance prerequisite rather than an amoebius implementation phase.
Its existence cannot be inferred from this repository, and an amoebius phase must not claim to create or
validate another repository's release.

The first admissible implementation target should be the cooperative profile with a complete pure model and
fake boundary. Live host mutations and hardware observations remain numerically later. Persistent recovery
should not be frozen into the first operational profile before the simpler machine is closed.

## 9. Recommended disposition

The proposal should remain in the engineering corpus because it identifies an important cross-project seam
and offers a credible architecture for it. Its assurance taxonomy, quarantine discipline, delayed-effect
handling, family/mechanism split, and base/turn model are valuable design inputs.

The proposal should not yet become authoritative doctrine or a release specification. Before adoption, one
integrated amendment should:

1. resolve the seed-dependency contradiction;
2. assign every obligation to the numerical plan;
3. define the outer-host and inner-amoebius ledger relationship;
4. correct the catalog and epoch locking order;
5. complete all effect and recovery transitions;
6. make artifact and writer identity claims enforceable or explicitly cooperative;
7. specify turn acquisition and recovery independently; and
8. replace `CoreMajor` ambiguity with an exact compatibility model.

After those decisions, the protocol can progress from a useful architecture proposal into a falsifiable
implementation contract. Until then, unsupported or unobserved claims should continue to fail closed and no
phase status should change because this analysis exists.

## Related Documents

- [Shared Host Resource Protocol](./shared_host_resource_protocol.md) — the proposal assessed by this analysis
