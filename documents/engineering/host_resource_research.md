# Host Resource Research

> **Purpose**: Record what a five-project review of shared-host coordination established, which of its
> findings the ledger settles by construction, and which remain open work for the amoebius calculus.
> **Read this if**: you are extending the ledger, designing host enforcement, or scheduling this work into a
> phase.

This document owns no protocol semantics, no implementation status, and no validation result. The frozen
shared surface is [hostclaim_spec.md](./hostclaim_spec.md); everything here is either background for it or
work that has deliberately not been frozen. It supersedes a longer cross-project proposal and the five
project-specific critiques written against it, and it carries forward the findings those critiques produced so
none is lost.

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/hostclaim_spec.md
**Generated sections**: none

</details>

## Contents

- [1. Why this document exists](#1-why-this-document-exists)
- [2. What the review established](#2-what-the-review-established)
- [3. Findings the ledger settles by construction](#3-findings-the-ledger-settles-by-construction)
- [4. Findings that remain open](#4-findings-that-remain-open)
- [5. Mechanism coverage](#5-mechanism-coverage)
- [6. Composing with a participant's own capacity arithmetic](#6-composing-with-a-participants-own-capacity-arithmetic)
- [7. Authority-gated launch](#7-authority-gated-launch)
- [8. What amoebius must settle before participating](#8-what-amoebius-must-settle-before-participating)
- [9. Where this work lands](#9-where-this-work-lands)
- [Related Documents](#related-documents)

## 1. Why this document exists

A proposal circulated to amoebius and four other repositories described a shared-host protocol built from a
neutral Haskell package, signed static catalogs, predeclared capacity cells, nested base and turn leases, a
six-state recovery machine, and one persistent custody process per participating project. Each repository
produced an independent critique. The critiques agreed on the architecture and disagreed with the shape.

The shape had three compounding problems. It avoided a dependency between projects by creating a sixth
product — release keys, an installer, three operating-system backends, migration tooling — so every project
was blocked on something that did not exist. It expressed custody as a retained kernel lock, which forces any
effect outliving a command into a new persistent process in every project, which is the coordinating service
the design set out to avoid, federated rather than removed. And it froze a large implementation while leaving
open the details that actually determine whether two programs interoperate.

The ledger is the response: freeze the small thing, implement it independently everywhere, and leave the
large interesting thing where it can still change. This document holds the large interesting thing.

~~~mermaid
flowchart TB
  %% register: orientation
    L["Ledger: names, encoding, arithmetic"] -->|"frozen, shared by all"| P["Participants"]
    N["Naming: observed hardware to domains"] -->|"rules and fixtures, no shared code"| P
    E["Enforcement: limits, coverage, residue"] -->|"never shared"| P
    C["Lifecycle: demand, launch, recovery"] -->|"never shared"| P
    E -->|"lifted per workflow"| A["amoebius calculus"]
    C -->|"lifted per workflow"| A
~~~
*Orientation.* Only the top two layers are agreed between programs; the bottom two are absorbed by lifting.

## 2. What the review established

Five reviewers, working separately, kept the same ideas. They are the durable content of the proposal and
should survive into the calculus:

- **Assurance is not one ladder.** Cooperative exclusion, an applied and read-back limit, and durable
  recovery after holder failure are three different claims, and collapsing them lets a file lock be described
  as a memory wall.
- **A resource family is not an enforcement mechanism.** Memory and an accelerator are resources; a control
  group, a job object, a quota, and a partition are mechanisms. Device presence implies no ceiling.
- **Persistent capacity and short bursts have different lifetimes.** A long-lived cluster should not hold an
  accelerator for its whole life.
- **Retained bytes are stock, not flow.** Ending computation does not release the disk a checkpoint occupies.
- **Process death is not absence evidence.** A released lock says nothing about a container, a mount, a
  service, a device context, or a request that may still complete.
- **The generic layer must never infer another program's desired state.** It may report and refuse; it may
  not reconcile.

The reviewers also agreed on where the proposal failed, and the ten findings below are the union of what all
five raised. The ledger settles four of them by construction. The rest are real and unfinished.

## 3. Findings the ledger settles by construction

**Writer authentication.** The proposal gave every enrolled participant write access to shared records and
then asked readers to reject a writer-identity mismatch. A file records bytes, not who wrote them, so any
participant could corrupt a shared record and remove capacity from everyone indefinitely. Confining every
writer to its own directory removes the shared record entirely: one writer per file, so a torn write is the
only reachable corruption and its cost falls on its own author.

**Artifact identity as an enforcement boundary.** Binding a participant to an exact executable digest cannot
be enforced when every participant runs as one operating-system user, and a design that excludes a hostile
same-user process has already conceded this. The ledger claims cooperation between conforming programs and
nothing more, so no enrolment machinery, signing key, or attestation procedure is required to hold up a claim
it never makes.

**Nested acquisition ordering.** Retaining a persistent lease while acquiring a second one raised questions
the proposal could not answer portably: whether a slot lock is re-entrant, how new objects order against
retained ones, and how a partial acquisition rolls back without dropping what is held. Creating every claim
inside one short critical section removes the question — participants never hold a partial set and never
order objects differently, so there is nothing to specify and nothing to deadlock.

**Quarantine as an administered state.** A separate terminal state that only a privileged operation clears
turns an ordinary interruption on a development machine into an outage. Making free a positive value folds
quarantine into the encoding: anything unreadable is occupied, and the ordinary release path is also the
repair path.

## 4. Findings that remain open

These are unfinished rather than answered, and each belongs to a participant rather than to the shared
surface.

**The multi-record transaction.** The proposal defined durable pages without defining the order in which
related records commit or what a reader should conclude from each crash prefix. The ledger sidesteps this by
having one record per claim and no cross-record pointers. Any participant that adds its own durable state
alongside a claim reintroduces the problem and must answer it locally: which record commits first, what an
unmatched pair means, and whether the mismatch converges or refuses.

**Recovery of persistent effects.** The proposal's six-state machine could never act, because every reviewer
also required that the generic layer never reconcile another program's resources. States that authorise no
decision are description, so the ledger keeps one declared bit and leaves recovery where the knowledge is.
Each participant still owes its own recovery interpreter, and the ledger's refusal to release is only
correct if that interpreter exists.

**Delayed external effects.** Observing an object absent is insufficient while an earlier asynchronous
request may still complete. A participant needs a monotonic fence, a queryable terminal result, or a drain
barrier before it releases; otherwise it should keep holding. The ledger cannot check this, and a participant
that releases too early is wrong in a way nothing here detects.

**Whole-machine claims.** Coordinating participants is not controlling a machine. Any process outside the
ledger may start and grow at any moment, so an honest claim covers conforming participants and the specific
limits a participant applied to itself. Nothing available on an open workstation makes a stronger claim true.

**Compatibility vocabulary.** The proposal called its shared surface an application binary interface, which
invited confusion with a compiler's calling convention. The interoperable surface is a wire, object, and lock
protocol. Whatever succeeds `spec-version` should keep that distinction in its wording.

**A minimal broker.** One reviewer noted that rejecting a coordinating service was asserted rather than
demonstrated, since the proposal already required a privileged installer and one custody process per project.
The strongest argument for a broker was that it removes multi-writer records. Single-writer records remove
them at no cost, which leaves a broker offering little except a new dependency on its availability. That
answer holds only while records stay single-writer.

## 5. Mechanism coverage

The most valuable correction the review produced, and the one that must reach the calculus intact.

A single resource can be governed jointly by several mechanisms with different strengths over different parts
of it. A worked example from one reviewer: host memory bounded by a data-segment limit installed before the
first instruction, which covers private writable mappings and cannot be raised by the process it binds, *plus*
a sampling observer over the shared and pinned memory that limit does not charge. Calling the result a hard
ceiling overstates it. Calling it reactive discards a real preventive guarantee. Treating them as
alternatives is simply wrong, because both are required.

A scalar strength label cannot express this. What is needed instead:

- a closed set of charged fields per resource, so coverage is stated over parts rather than over a name;
- conjunction, so several mechanisms can jointly cover one resource;
- a check that the union of coverage meets the requirement;
- **explicit residue** naming what remains uncovered when the union is intentionally incomplete;
- evidence that an observer is running before work depending on it starts; and
- coverage identities carried into whatever the operation returns, so a later reader can still tell what was
  actually established.

This is enforcement, so it is not in the ledger and is never coordinated between participants. It is
extension work in the sense that
[extension_conformance_doctrine.md](./extension_conformance_doctrine.md) uses the term: a declaration with
laws, not a directory of code.

## 6. Composing with a participant's own capacity arithmetic

A participant that already computes what it needs must not compute it a second time to charge the ledger.
The charge is derived from the existing figure by one total conversion, and the reverse direction joins the
ledger's outcome with the participant's own result. Neither substitutes for the other: a granted claim is not
a completed workload, and a completed workload is not evidence the claim was released.

Two failure modes seen in the reviewed projects are worth naming because they recur. A physical-capacity
figure silently reinterpreted as an allocation lets an inner scheduler reason about more machine than the
outer claim permits. And a figure that omits work outside the inner system — build processes, caches,
retained output, the participant's own overhead — under-charges by exactly the amount that causes trouble.
Every source of growth is either charged or explicitly refused.

For amoebius specifically, the arithmetic is already owned. What
[resource_capacity_doctrine.md](./resource_capacity_doctrine.md) does not own is stated in that document: the
model stops at single-cluster placement, and shared physical supply folds through machinery owned elsewhere.
This is that machinery. The honesty constraint that doctrine imposes travels with it — a capacity check is a
checked refusal at a named locus, not a statement about which values can exist, and describing it as the
latter is a defect regardless of how convenient the phrasing is.

## 7. Authority-gated launch

A claim that a program does not consult is decoration. Two patterns from the review are worth stating
generally.

**Visibility is not allocation.** Exposing every accelerator on a machine to a container and then selecting
one inside it means two programs can hold different claims and use the same device. The identifier in the
claim, the device exposed to the workload, the device observed from inside it, and the device named in
whatever the run reports must all be the same, and a workload rendered without a specific device does not
satisfy this however carefully it was scheduled.

**A capability the caller can skip is not a gate.** When a device entry point takes only a request and probes
whether hardware is present, every internal caller bypasses admission by construction, and checking in one
command does not help. The launch boundary itself takes the capability. Raw access may survive for testing
mechanisms if it cannot be reached from ordinary paths.

Both are local corrections. They are worth making in a participant whether or not it ever joins a ledger,
which is a useful property: nothing here has to wait for agreement.

## 8. What amoebius must settle before participating

Three things, none of which is a detail.

**The host-global state rule needs an explicit narrow exception.** amoebius forbids falling back to system
temporary directories, a user home, or host-global engine state, and
[cluster_lifecycle_doctrine.md](./cluster_lifecycle_doctrine.md) states that rule for cluster lifecycles. The
distinction that has to be written down is that the ban covers amoebius state escaping into the machine,
while the ledger is operator-owned state that amoebius reads and appends one record to. It holds no amoebius
bytes and survives amoebius being deleted. The exception must be stated deliberately, not assumed, and it
must not widen into a general permission.

**Participation must be a declared seam.** Two components interacting through an undeclared file path are
outside the composition argument that
[extension_conformance_doctrine.md](./extension_conformance_doctrine.md) makes, and an undeclared side
channel is an illegal state rather than an untidy one. Reading the ledger incidentally would be exactly that.
It enters through the declared resource index or it does not enter.

**One root, not two.** A later phase already describes a host-resident ledger with its own compare-and-swap
root for a host compute daemon, and another describes an in-cluster reservation ledger. Two roots that both
authorise a host launch recreate double-spending inside one program. The inner ledger references the outer
claim; it does not compete with it.

The seed relationship is unaffected, and this is deliberate.
[lift_and_compose_doctrine.md](./lift_and_compose_doctrine.md) commits that no seed depends on amoebius and
that no seed is asked to adopt an amoebius interface. A ledger on the machine is not an interface amoebius
publishes: it is host configuration that amoebius also reads. When a workflow is eventually lifted, the
participant's own ledger code is deleted along with the workflow it served, so no ownership transfer is
scheduled and no exception to that commitment is needed.

## 9. Where this work lands

Nothing here amends the plan, and no status changes because this document exists. Recorded so the work is
visible when it is scheduled:

| Work | Nature |
|---|---|
| Naming rules from observed hardware to domains, and their fixtures | hardware-free |
| Ledger encoding, total decoding, and admission arithmetic | hardware-free |
| Coverage algebra, residue, and observer readiness | hardware-free model, hardware-bearing evidence |
| Charge derivation from the existing capacity arithmetic | hardware-free |
| Reading and writing real records against a real root | hardware-bearing |
| Contention between independently built participants | hardware-bearing |

The first four are model work and can proceed under the hardware-free barrier the
[Development Plan](../../DEVELOPMENT_PLAN/README.md) records. The last two are host work and are ordered by
that plan like any other host work, behind the barriers it names. No participation, conformance, or
validation may be claimed from this document.

## Related Documents

- [Host Claim Ledger](./hostclaim_spec.md) — the frozen shared surface this document surrounds
- [Engineering Doctrine Index](./README.md) — surrounding architecture ownership
- [Development Plan](../../DEVELOPMENT_PLAN/README.md) — phase order, implementation status, and promotion
- [Lift and Compose Doctrine](./lift_and_compose_doctrine.md) — seed and amoebius independence
- [Resource Capacity Doctrine](./resource_capacity_doctrine.md) — the capacity arithmetic and its limits
- [Substrate Doctrine](./substrate_doctrine.md) — substrate ownership and extension cost
- [Extension Conformance Doctrine](./extension_conformance_doctrine.md) — declarations, laws, and declared seams
- [Cluster Lifecycle Doctrine](./cluster_lifecycle_doctrine.md) — the contained-state rule needing an exception
