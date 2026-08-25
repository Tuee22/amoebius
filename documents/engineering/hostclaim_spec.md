# Host Claim Ledger

> **Purpose**: Define the frozen on-disk ledger through which independently built programs sharing one
> machine refuse to spend the same host capacity twice.
> **Read this if**: you are implementing a participant, adding a resource family, or auditing a claim on a
> shared development host.

This document is the whole shared surface. Everything a participant must agree on is here; everything else —
how demand is derived, how a limit is enforced, how a workload recovers — stays inside the participating
program and is never coordinated. The ledger is host configuration owned by the machine's operator, in the
same category as an `/etc` file or a port assignment. amoebius is a participant in it, not its author, and no
program acquires a dependency on another by implementing it.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/host_resource_research.md
**Generated sections**: none

</details>

## Contents

- [1. What this establishes](#1-what-this-establishes)
- [2. The root](#2-the-root)
- [3. The objects](#3-the-objects)
- [4. The claim record](#4-the-claim-record)
- [5. Dimensions and domains](#5-dimensions-and-domains)
- [6. Admission](#6-admission)
- [7. Claim kinds and release](#7-claim-kinds-and-release)
- [8. Extension](#8-extension)
- [9. Conformance](#9-conformance)
- [Related Documents](#related-documents)

## 1. What this establishes

Two programs that each observe free memory, then each start a cluster, both observed correctly and still
overcommit the machine. Repository-local locks cannot arbitrate between them because they name different
objects. The ledger gives them one object to name.

~~~mermaid
flowchart TB
  %% register: orientation
    A["Participant A"] -->|"try-lock, scan, write"| L["admission.lock"]
    B["Participant B"] -->|"try-lock, scan, write"| L
    L -->|"serializes"| R["claims/*/*.claim"]
    R -->|"charges"| D["frozen dimensions"]
    R -->|"holds"| X["opaque domains"]
    D -->|"compared against"| G["budget"]
    X -->|"prefix conflict"| X
~~~
*Orientation.* Every participant meets at one lock and one set of records; nothing else is shared.

What a granted claim establishes: no other conforming participant holds a conflicting domain, and the sum of
declared charges plus the reserve fits the budget. That is a statement about *declarations*, not about
behaviour — a participant that claims four gibibytes and then allocates twelve is not detected here.

What it does not establish: no limit is applied, no accelerator is fenced, and nothing constrains a program
that does not participate. The ledger is advisory between cooperating programs on one machine. It offers no
defence against a hostile process running as the same operating-system user, and it holds no secret.

The dominant real failure on a shared development host — two programs each starting a cluster — is a
collision between declarations, which is exactly what this catches.

## 2. The root

Every participant resolves one fixed path and no other:

~~~text
Linux, Darwin: $HOME/.hostclaim
Windows:       %UserProfile%\.hostclaim
~~~

The path is never repository-relative, never version-suffixed, never selected by an environment variable, and
never searched for. Two participants that resolve different paths silently fail to coordinate, which is the
one failure the ledger exists to prevent, so the resolution rule admits no configuration.

Installation is `mkdir -p` and writing `budget`. There is no privileged installer, no signing ceremony, and
no key custody. Enrolling a participant is creating one directory named after it.

A process inside a container or virtual machine participates only by bind-mounting the host's root at the
same path inside the guest. A guest-local file at that path is a different object and coordinates nothing; a
participant that cannot mount the host root does not participate, and says so rather than claiming it did.

## 3. The objects

~~~text
$HOME/.hostclaim/
  spec-version                    text: the revision this root implements
  budget                          text: one dimension per line, plus reserve
  admission.lock                  the single serializing lock
  claims/<participant>/<slot>.claim   4096 bytes, fixed size
  claims/<participant>/<slot>.live    zero bytes, a lock file
~~~

`spec-version` holds one decimal integer. A participant implementing a different revision refuses every
operation and names the mismatch. This is the only compatibility mechanism; there is no negotiation.

`budget` holds `<dimension> = <amount>` lines and one `reserve` line per dimension, edited by the operator.
It is not signed. The threat being addressed is accident, and a signature does not distinguish two programs
run by the same person.

`admission.lock` and each `.live` file are exclusive advisory locks taken non-blocking. On POSIX they are
whole-file locks; on Windows they are the equivalent native lock. A participant never creates a lock path at
runtime.

**A participant writes only beneath `claims/<its own name>/`.** Nothing in this specification lets one
participant write another's record. This is what bounds corruption: every record has one writer, so a torn
write is the only way it can become unreadable, and an unreadable record costs its own participant one slot
rather than removing capacity from everyone.

## 4. The claim record

A record is exactly 4096 bytes: an ASCII payload, a newline, then NUL padding. The first field is the CRC-32
of the remaining bytes of the payload, in lowercase hexadecimal.

~~~text
<crc32> FREE
<crc32> HELD <participant> <slot> <kind> <pid> <boot-id> <domains> <charges> <note>
~~~

`domains` is a comma-separated list, possibly empty. `charges` is a comma-separated list of
`<dimension>=<amount>`. `note` is free text with no interpretation, carried so an operator reading the file
learns who to ask.

Decoding is total. A reader classifies every possible 4096 bytes into exactly one of:

| Bytes | Meaning |
|---|---|
| A valid `FREE` payload | the slot is free |
| A valid `HELD` payload | the slot is claimed as described |
| Anything else | **the slot is claimed, by an unknown holder, charging nothing** |

The third row is the load-bearing one. **Free is a positive value that a writer must deliberately produce.**
A torn write, a truncated file, an unfamiliar revision, and a corrupted byte are all *occupied*, so no
failure of the encoding can release capacity. There is no repair path and no quarantine state to administer:
an unreadable record stays occupied until its own writer replaces it, which is the same operation as any
other release.

An unknown-holder record charges nothing against the budget because its charges cannot be read. Its
participant directory still names who owns it.

## 5. Dimensions and domains

Two kinds of resource, deliberately different in how they extend.

**Dimensions are frozen.** Adding one is a `spec-version` revision. The set is:

| Dimension | Unit |
|---|---|
| `ram.bytes` | bytes of host memory |
| `cpu.millicores` | thousandths of one core |
| `disk.bytes@<filesystem-id>` | bytes on one filesystem |
| `devmem.bytes@<domain>` | bytes of memory private to one domain |

Memory physically shared with the host is charged to `ram.bytes` and never to `devmem.bytes`. An integrated
accelerator on a unified-memory machine therefore charges host memory, which is what it actually consumes.
Only memory the host cannot otherwise use gets its own dimension. This replaces an aliasing graph with a
choice of dimension.

**Domains are open.** A domain is an opaque identifier:

~~~text
<family>:<stable-id>[/<child>]*
~~~

Adding a family requires no revision and no agreement, because a participant never interprets a domain. It
performs exactly two operations on it, both frozen:

1. **Equality and prefix.** Two domains conflict when either is a prefix of the other at a segment boundary.
   A whole device and one of its partitions therefore conflict without either participant knowing what a
   partition is.
2. **Charge.** The declared charges are read and subtracted, whatever the domain means.

A participant that has never heard of a family still refuses to double-book its domains and still accounts
for its consumption. This is what lets hardware nobody supports yet be accounted for correctly, and it is
why no participant needs to refuse a ledger containing families it does not recognise.

The stable identifier must survive a reboot and must name the same physical thing to every participant. A
device serial or hardware universally unique identifier qualifies; an enumeration index does not.

## 6. Admission

~~~text
try-lock admission.lock, non-blocking          -- on failure: retry with backoff, or report Busy
  release my own stale claims                  -- see the release rules below
  read every claims/*/*.claim
  refuse if any live claim holds a domain conflicting with a requested domain
  refuse if reserve + sum of live charges + requested charges exceeds budget, in any dimension
  take my .live lock if the claim is Transient
  write my .claim, then flush it to disk
release admission.lock
~~~

The lock is held for the duration of that sequence and never across a workload. Because every claim is
created inside it, participants never hold a partial set of objects and never acquire objects in different
orders, so no acquisition ordering rule is needed and no deadlock is reachable.

Refusals are distinct and must stay distinct in whatever a participant reports: `Busy` (the admission lock or
a domain is momentarily contended, retry may succeed), `Insufficient` (the budget cannot fit this request,
retry will not help until something is released), and `Unsupported` (this participant cannot satisfy the
request at all). Collapsing them produces retry loops that never terminate and terminal failures that should
have been retried.

Growing a live claim is not an operation. A participant that needs more takes a second claim, which is an
independent record and passes through admission on its own terms.

## 7. Claim kinds and release

Every claim declares one of two kinds, and the kind is a statement about what the holder's death proves.

**`Transient`** — *the holder's death proves the resources are gone.* Admissible only when the operating
system reclaims everything charged: process memory, processor time, descriptors. The holder keeps its `.live`
lock open for the claim's life.

**`Persistent`** — *the holder's death proves nothing.* Required for anything that outlives a process: a
container, a cluster, a virtual machine, a mount, a service, retained bytes on disk, or a request to an
external system that may still complete. `.live` is not consulted.

Releasing means writing `FREE`, and only the owning participant does it:

- A participant releases its own claim when its work is done and it has established that what it created is
  gone. What counts as established is that participant's business, not the ledger's.
- A participant releases its own `Transient` claim whose `.live` lock is free — the holder died, and the kind
  is the holder's own declaration that this is safe. It does this for its own claims at the start of every
  admission, which is why a killed build recovers without an operator.
- **No participant ever releases another's claim.** A stale `Persistent` claim is reported, never reclaimed.

The consequence, stated plainly: a participant that dies holding a `Persistent` claim keeps that capacity
until it runs again and settles it. A wedged claim is a 4096-byte text file the operator may edit
deliberately. That is the intended escape hatch, and it is preferred here to an automatic one because no
automatic rule can know whether the cluster is still running.

## 8. Extension

| Change | Cost |
|---|---|
| Enrolling a participant | one directory |
| Adding a resource family and its domains | nothing; no revision, no rebuild |
| Adding a mechanism that enforces a limit | nothing here; it is not shared |
| Adding a dimension, or changing the record encoding | a `spec-version` revision and a reinstall |

The asymmetry is the design. Families change often and must be free; the encoding is what every participant
depends on and must be rare.

A participating program's own substrate vocabulary is separate from this and stays separate. amoebius names
four substrates and pays a real cost to add one, as
[substrate_doctrine.md](./substrate_doctrine.md) sets out. The ledger's families are not that enumeration and
must not be tied to it, or hardware no participant supports yet could not be accounted for.

## 9. Conformance

Conformance is behavioural. Two independently built programs contending on one real root either coordinate or
do not, and nothing else settles it: matching prose, matching digests, and two builds of one implementation
are not evidence.

A reader is conformant when, against a root containing a valid `FREE` record, a live `Persistent` claim, a
stale `Transient` claim whose `.live` is unlocked, a record with a corrupted checksum, and a claim holding a
domain from an unrecognised family with a `ram.bytes` charge, it reports the same occupancy and the same
totals as another independently written reader. Disagreement is a defect in this document before it is a
defect in either reader, and the remedy is to make the specification smaller.

This document establishes no implementation status for amoebius or for any other program. Status is owned by
the [Development Plan](../../DEVELOPMENT_PLAN/README.md), and no participation may be claimed here.

## Related Documents

- [Host Resource Research](./host_resource_research.md) — the unfrozen material: enforcement, coverage, and
  recovery
- [Engineering Doctrine Index](./README.md) — surrounding architecture ownership
- [Development Plan](../../DEVELOPMENT_PLAN/README.md) — phase order, implementation status, and promotion
- [Substrate Doctrine](./substrate_doctrine.md) — the amoebius substrate catalog and its extension cost
