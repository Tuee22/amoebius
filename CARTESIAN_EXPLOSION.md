# Cartesian Configuration Explosion and Linux OOM — 2026-08-31

> **Purpose**: Preserve the causal description, recurrence risk, and repair requirements for the compiler-subject
> registry's Cartesian configuration explosion and the resulting Linux out-of-memory event.
> **Read this if**: investigating the 2026-08-31 session loss, changing compiler-subject configuration handling,
> or designing resource containment for development executables.

This report owns the operational reconstruction of this incident and the observed working-tree defect that
caused it. It is historical evidence, not architectural doctrine, phase status, validation authority, or an
executable test specification. Any repair, limit, expectation, or regression case must remain source-bound in
Haskell; this Markdown report is never a behavioral input.

**Observed placement status — 2026-08-31:** this explicitly requested root file is untracked and auxiliary to
the governed documentation set. Its uppercase name is a user-requested exception to the current `snake_case.md`
rule. Admitting it to the tracked source and governed-document inventories requires separate Haskell inventory
and oracle changes.

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: N/A
**Generated sections**: none

</details>

## Contents

- [Executive conclusion](#executive-conclusion)
- [1. Impact](#1-impact)
- [2. Incident timeline](#2-incident-timeline)
- [3. Trigger and production reachability](#3-trigger-and-production-reachability)
- [4. Algorithmic cause](#4-algorithmic-cause)
- [5. Why the 4,096 limit did not limit work](#5-why-the-4096-limit-did-not-limit-work)
- [6. Memory amplifiers](#6-memory-amplifiers)
- [7. Why existing tests missed the defect](#7-why-existing-tests-missed-the-defect)
- [8. Host and session containment failure](#8-host-and-session-containment-failure)
- [9. Recurrence risk](#9-recurrence-risk)
- [10. Required prevention](#10-required-prevention)
- [11. Changes that do not solve the problem](#11-changes-that-do-not-solve-the-problem)
- [12. Evidence locations](#12-evidence-locations)
- [13. Residual uncertainty](#13-residual-uncertainty)

---

All times in this report are America/Toronto EDT (UTC-04:00). The affected host was a Linux workstation with
approximately 124 GiB of physical memory and 8 GiB of swap. The reconstruction used the kernel journal,
systemd journal, Codex session record, local inspector artifacts, current source, and read-only host
resource-control inspection.

## Executive conclusion

The previous Codex session ended because a local untracked Haskell inspector exhausted essentially all available
host memory while deriving the live compiler-subject registry. Linux selected the inspector as the global
out-of-memory (OOM) victim at 18:05:42. Systemd then stopped the inspector's containing terminal scope and
killed its shell 90 seconds later, truncating the Codex transcript.

The allocation defect is a Cartesian expansion in
[`CompilerSubjectRegistry/Internal.hs`](src/validation-kernel/Amoebius/Validation/CompilerSubjectRegistry/Internal.hs).
The implementation treats every sibling Cabal condition as an independent true-or-false choice and enumerates
their complete product. The `validation-kernel` component contained 5,845 sibling conditions during the
incident, so the implementation described a theoretical `2^5845` leaf set.

The registry declares a 4,096-configuration ceiling, but it constructs and deduplicates the complete leaf
stream before checking that ceiling. The ceiling therefore describes a diagnostic after allocation rather
than an admission boundary before allocation.

This was not compiler concurrency. The inspector compiled and linked with `-j1`; the runaway began after the
linked executable started. The repository's compiler-serialization rule does not contain a single runtime
process that allocates without a hard bound.

> **Causal finding — high confidence:** the current compiler-subject registry implementation forced an
> exponentially large Cabal configuration product. The inspector reached approximately 116.5 GiB of anonymous
> resident memory, exhausted all swap, triggered a global OOM kill, and indirectly caused the terminal scope
> containing Codex to be terminated.

## 1. Impact

- `.build/inspect-registry/inspect-v2` was killed before producing registry output.
- `.build/inspect-registry/output-v2.txt` remained empty.
- The active Codex transcript ended during a tool-session poll and contains no completed result or final reply.
- The terminal shell was killed when systemd's stop operation timed out after the OOM event.
- The host did not reboot, and the kernel reclaimed the inspector's memory.
- No lingering inspector, GHC, Cabal, linker, or compiler process was found afterward.
- No Git index lock, staged change, or repository corruption attributable to the OOM was found.

## 2. Incident timeline

| Time | Observed event |
|---|---|
| 18:02:53 | `inspect-v2` finished linking with `-j1` and began inspecting the live repository snapshot. Its standard output was redirected to `output-v2.txt`. |
| 18:03:28–18:05:13 | Codex polled the still-running tool session. No output appeared because the inspector had not completed and its output was redirected. |
| 18:05:42 | Linux entered a global OOM condition and selected PID 2591841, `inspect-v2`, for termination. |
| 18:05:42 | The kernel recorded 122,147,468 kB anonymous RSS, 1,073,844,556 kB virtual memory, and no free swap. |
| 18:05:47 | The OOM reaper finished reclaiming the inspector's resident memory. |
| 18:07:12 | Systemd timed out while stopping the OOM-failed tmux scope and sent `SIGKILL` to its remaining shell. |

The inspector ran for approximately 169 seconds between the completed link and the OOM kill. A timeout alone
would therefore have required an aggressively short threshold to protect the host, and could still have
allowed substantial allocation before expiry.

## 3. Trigger and production reachability

The immediate subject was the local development inspector at
`.build/inspect-registry/Main.hs`. It loaded the live Git snapshot and forced
`deriveCompilerSubjectRegistry`. It then intended to print registry findings, observations, assignments,
branch bindings, and the acquired compiler-subject contract.

The defect is not confined to that local diagnostic. The observed working-tree validation path is:

```text
app/amoebius/Main.hs
  -> runValidateCommand
  -> validatePhaseLocked
  -> loadGitSnapshot
  -> acquireCompilerSourceGraph
  -> prepareAcquiredCompilerSourceGraph
  -> deriveCompilerSubjectRegistry
```

The dispatch entry is implemented in
[`Dispatch/Internal.hs`](src/validation-kernel/Amoebius/Validation/Dispatch/Internal.hs), and the acquired
compiler-source join is implemented in
[`CompilerSourceGraph/Internal.hs`](src/validation-kernel/Amoebius/Validation/CompilerSourceGraph/Internal.hs).
Registry acquisition occurs before selection of an individual phase runner.

Every valid phase ordinal therefore reaches this derivation when the validator contains the affected
working-tree implementation. This includes a direct source-bound `amoebius validate phase NN` and any
repository-backed public transport that builds and executes those bytes. Invalid phase arguments and
non-validation commands do not reach this path.

`prepareAcquiredCompilerSourceGraph` also requests the registry twice: once for the registry check and once
inside `acquireCompilerSubjectContract`. The first derivation was sufficient to cause the OOM, so the duplicate
derivation was not the initiating cause. A repair should nevertheless derive one bounded value and share it.

## 4. Algorithmic cause

**Observed implementation — 2026-08-31 working tree.** `declarationsFromTree` calls `conditionalLeaves` for
each Cabal conditional tree. `conditionalLeaves` begins with one configuration and folds over the node's
sibling branches.

For each incoming configuration, a branch produces:

- one leaf with the predicate recorded as true; and
- one leaf with the predicate recorded as false.

An `if` without an `else` still has two configurations. Its false configuration inherits the component value
that existed before the branch. Folding the next sibling over the complete current list doubles that list
again.

For `n` independent sibling conditions, the leaf count is:

```text
leaves(0) = 1
leaves(n + 1) = 2 * leaves(n)
leaves(n) = 2^n
```

The `library validation-kernel` stanza in [`amoebius.cabal`](amoebius.cabal) contained 5,845 direct sibling
`if` declarations at investigation time. One was an operating-system condition and 5,844 were mutation-flag
conditions. The mutation-flag cardinality is also stated independently in
[`MutationCoverageOracle.hs`](test/validation-kernel/MutationCoverageOracle.hs).

The affected representation therefore attempted to describe `2^5845` complete leaves. This number has 1,760
decimal digits. It is not a materializable registry.

The failure is both algorithmic and representational. The registry asks for every Boolean valuation of the
condition universe, even though a useful compiler contract needs a finite authenticated configuration or a
symbolic account of guarded ownership.

## 5. Why the 4,096 limit did not limit work

The registry declares:

```text
maximumComponentConfigurations = 4096
```

The relevant derivation order is nevertheless:

```text
rawDeclarations
  -> Set.fromList rawDeclarations
  -> Set.toAscList
  -> countProblem "component-configurations" 4096 parsedDeclarations
```

`Set.fromList` must consume the complete declaration stream before it can provide the deduplicated, ordered
set. The subsequent `countProblem` examines only `limit + 1` values, but its input has already been forced by
the set construction. Its locally bounded `take` cannot recover the allocation already performed.

The threshold makes the ordering defect especially clear:

| Sibling binary conditions | Leaf configurations | Required result |
|---:|---:|---|
| 12 | 4,096 | At the declared maximum |
| 13 | 8,192 | Refuse after observing at least 4,097 |
| 5,845 | `2^5845` | Refuse before leaf construction |

Input-byte and source-entry bounds do not contain this problem. The live Cabal file fits within its raw byte
budget, and the tracked snapshot fits within the acquired-entry budget. A small admitted input can still
describe an exponentially larger derived value.

## 6. Memory amplifiers

The Cartesian leaf count is the primary defect. Several representation choices increase the cost of every
leaf that is reached:

- `decisions <> [(condition, selected)]` copies an increasingly long decision prefix at every branch.
- Every complete leaf retains a decision for every condition on its path.
- `renderBranchIdentity` renders that full path into text.
- `Set.fromList` retains values for deduplication and ordering while continuing to consume the stream.
- Component values are repeatedly combined while configurations expand.

The approximately 1 TiB virtual-memory size was not itself the exhausted physical resource. The decisive
measurement was approximately 116.5 GiB of anonymous resident memory. File-backed RSS was only 268 kB, and
the host's full 8 GiB swap area had no free space.

The expansion did not need to approach its theoretical completion to fail. It only needed to allocate faster
than the host could reclaim or swap memory.

## 7. Why existing tests missed the defect

The focused registry oracle in
[`CompilerSubjectRegistryOracle.hs`](test/validation-kernel/CompilerSubjectRegistryOracle.hs) contains one
conditional Cabal fixture. That fixture verifies the true-or-false branch identity for one condition, but it
does not exercise a sibling product.

The oracle has no case for:

- two or three sibling conditions;
- nested and sibling condition interaction;
- exactly 4,096 configurations;
- the first configuration beyond the declared limit;
- refusal before identity rendering and set construction; or
- a repository-scale condition tree.

A separate compiler-component-plan diagnostic has boundary cases for its own configuration model. Those cases
do not call this registry implementation and cannot detect a late bound in `CompilerSubjectRegistry`.

The small oracle therefore passed while the live repository join remained unsafe. Correctness on one branch
did not establish resource safety across thousands of siblings.

## 8. Host and session containment failure

**Post-incident observation — 2026-08-31.** The inspector inherited the same tmux scope as the shell and Codex.
That scope and its ancestors had no effective memory boundary:

```text
MemoryHigh=infinity
MemoryMax=infinity
MemorySwapMax=infinity
RLIMIT_DATA=unlimited
RLIMIT_RSS=unlimited
RLIMIT_AS=unlimited
```

The scope's `OOMPolicy=stop` did not prevent allocation. It instructed systemd to stop the containing unit
after one of its processes was killed by the OOM killer. This policy converted the inspector failure into a
terminal-scope failure and ultimately removed the Codex shell.

The kernel classified the event as `global_oom`, not a cgroup-local memory-limit event. The kernel selected
`inspect-v2` as the OOM victim. Codex was not the selected memory victim; its transcript was lost later because
its shell shared the failed scope.

`systemd-oomd` was active but recorded no intervention during this event. Pressure-reactive monitoring was not
a substitute for a hard child-process memory ceiling.

## 9. Recurrence risk

**Observed status — 2026-08-31:** the source path and triggering input remained present after the incident.
The local `.build/inspect-registry/inspect-v2` executable also remained present. No algorithmic or host
containment change had been made when this report was written.

The recurrence assessment is therefore:

| Action | Risk |
|---|---|
| Rerun the existing `inspect-v2` executable | Near-certain repeat of runaway allocation and OOM without an external limit |
| Build the affected working tree and run a valid live phase validation | Directly reaches the same registry derivation |
| Run the small synthetic one-condition oracle | Does not reproduce the scale defect and is not evidence of safety |
| Edit or inspect repository files without forcing the live registry | Does not trigger the allocation |
| Run a validator built from older, unaffected source | Depends on the exact executable identity and is not evidence about the current tree |

Do not rerun the existing inspector or a live validator containing this implementation until an early bound
and external process containment are both present.

## 10. Required prevention

The following properties were proposed by the investigation. They were not implemented or validated by this
report.

### 10.1 Fail before leaf allocation

The registry must calculate configuration cardinality before constructing leaves, rendering identities, or
creating a `Set`. The calculation should use strict, saturating addition and multiplication capped at
`maximumComponentConfigurations + 1`.

On the first observation of 4,097, derivation should return the existing named resource refusal:

```text
RegistryResourceLimit "component-configurations" 4096 4097
```

One global budget must cover all admitted Cabal files and components. A partial declaration list must not be
presented as a complete registry after exhaustion.

### 10.2 Replace the complete Boolean universe

An early bound makes this incident safe, but it causes the current live input to refuse after the thirteenth
binary condition. A usable final model must avoid materializing every Boolean valuation.

Candidate representations include:

- retaining the Cabal condition tree as a bounded symbolic directed acyclic graph; or
- evaluating guarded declarations against one concrete, independently authenticated flag configuration.

The chosen representation must preserve branch-sensitive ownership without treating thousands of mutation
flags as a materialized cross-product. The architectural choice remains unresolved by this report.

### 10.3 Bound every retained dimension

Configuration cardinality is not the only derived dimension that needs admission control. A repair should
bound Cabal-file count before parsing and separately bound:

- Cabal input bytes;
- condition-node count;
- predicate bytes;
- branch depth;
- rendered branch-identity bytes;
- guarded declarations;
- subject assignments; and
- aggregate registry output.

Decision paths should be accumulated without repeated append-based prefix copying. The registry check and
contract acquisition should consume one shared bounded derivation.

### 10.4 Add independent Haskell regressions

The independently authored Haskell oracle should cover:

- two sibling conditions producing four configurations;
- three sibling conditions producing eight configurations;
- nested conditions and missing-`else` inheritance;
- twelve binary siblings admitting exactly 4,096 configurations;
- thirteen binary siblings refusing at an observed minimum of 4,097;
- a Haskell-generated 5,845-sibling adversarial input that refuses with bounded work; and
- changed-production mutants that bypass, delay, widen, overflow, or continue after the early bound.

The large regression should execute in an independently memory-capped child. A future regression must become
a bounded test failure rather than a host-wide incident. Test fixtures and semantic expectations remain
Haskell; no checker may parse this report into a verdict.

### 10.5 Isolate generated executables

Every risky generated inspector or harness should execute in a child cgroup that does not contain Codex or the
calling shell. The child should have hard memory, swap, time, and output ceilings, and resource termination
should become a named refusal.

An investigation-time starting envelope for this 124 GiB host was:

```text
MemoryHigh=12G
MemoryMax=16G
MemorySwapMax=1G
OOMPolicy=kill
```

These values are a machine-specific starting point, not portable policy. Successful bounded runs must measure
`MemoryPeak` before final limits are selected. A Haskell runtime-system heap ceiling near 8 GiB can provide a
secondary guard, with cgroup headroom retained for native allocations, mappings, page cache, and descendants.

The cgroup boundary is primary because an RTS heap ceiling covers only Haskell-managed heap. A tracked
repository-owned supervisor must obey the Haskell source boundary; any generated launcher materialization
belongs beneath `.build/**`.

### 10.6 Retain an outer backstop

A broader terminal-scope or user-slice ceiling can protect the host from other uncontained processes. It is a
last line of defense rather than the primary boundary. A limit on the entire terminal scope can still select
or kill Codex, while a dedicated child cgroup confines the risky subject.

## 11. Changes that do not solve the problem

The following changes are insufficient:

- Changing `foldl` to `foldl'` changes evaluation order but not exponential cardinality.
- Raising the 4,096 ceiling increases the amount of work admitted before refusal.
- Applying `take 4097` after path rendering still constructs thousands of very long identities.
- Adding swap delays termination and increases thrashing; it does not bound allocation.
- A wall-clock timeout alone permits large allocations before expiry.
- Compiler serialization does not bound a linked runtime process.
- `OOMPolicy=stop` reacts after a kill and can remove the whole terminal scope.
- A low `ulimit -v` or `RLIMIT_AS` can reject healthy GHC-produced programs because their virtual address
  reservations are much larger than their resident memory.
- Monitoring without a hard enforcement boundary reports pressure but does not guarantee containment.

## 12. Evidence locations

The following locations were present during the investigation. The journal, Codex session record, and ignored
`.build/**` artifacts are mutable and may rotate, disappear, or be overwritten. No immutable copies or hashes
were recorded, so this report preserves the observed facts rather than the exact evidence bytes.

### 12.1 Kernel and systemd journal

The kernel recorded:

```text
oom-kill: ... global_oom ... task=inspect-v2,pid=2591841,uid=1000
Out of memory: Killed process 2591841 (inspect-v2)
total-vm:1073844556kB anon-rss:122147468kB file-rss:268kB
Free swap  = 0kB
Total swap = 8388604kB
```

The affected transient unit was:

```text
tmux-spawn-8d8ffd62-3eac-40b5-9890-f53c673ec87d.scope
```

Systemd recorded that the unit suffered an OOM kill at 18:05:42. At 18:07:12 it recorded a stopping timeout,
sent `SIGKILL` to the remaining Bash process, and marked the scope failed with result `oom-kill`.

### 12.2 Codex session record

The truncated session was located at:

```text
/home/matt/.codex/sessions/2026/08/30/
  rollout-2026-08-30T21-05-13-01a05559-5878-7b43-a74a-25305a2175a4.jsonl
```

The record contains the serialized `-j1` build, launch of `inspect-v2`, tool-session identifier `70450`, and
repeated incomplete polls. It ends without the run result that the killed shell could no longer return.

### 12.3 Local artifacts

The ignored local artifacts remained beneath `.build/inspect-registry/` after the incident:

| Artifact | Observed size | Role |
|---|---:|---|
| `Main.hs` | 2,571 bytes | Local untracked Haskell inspector source |
| `inspect-v2` | 23,705,536 bytes | Killed executable |
| `output-v2.txt` | 0 bytes | Redirected output, never populated |

These local files are diagnostic evidence, not version-controlled source.

### 12.4 Repository sources inspected

- [`CompilerSubjectRegistry/Internal.hs`](src/validation-kernel/Amoebius/Validation/CompilerSubjectRegistry/Internal.hs)
  contains the late resource check and Cartesian leaf enumeration.
- [`CompilerSourceGraph/Internal.hs`](src/validation-kernel/Amoebius/Validation/CompilerSourceGraph/Internal.hs)
  places registry derivation on the acquired live-source path.
- [`Dispatch/Internal.hs`](src/validation-kernel/Amoebius/Validation/Dispatch/Internal.hs) places acquired
  compiler-source analysis on every valid live phase validation.
- [`CompilerSubjectRegistryOracle.hs`](test/validation-kernel/CompilerSubjectRegistryOracle.hs) contains the
  single-condition control and lacks a sibling-scale resource boundary.
- [`amoebius.cabal`](amoebius.cabal) contains the sibling conditional population that exposed the defect.

## 13. Residual uncertainty

The exact allocation shape inside the Haskell heap was not captured with an RTS heap profile. The kernel's
resident-memory accounting and the source-level Cartesian expansion are sufficient to identify the failure
class, but they do not assign bytes to individual constructors.

The investigation did not establish the healthy peak-memory requirement of a corrected live registry. The
proposed cgroup and RTS limits therefore require calibration from safe successful runs.

The final semantic representation of Cabal conditions remains a design decision. A saturating preflight is
required for safety, but symbolic retention and concrete authenticated evaluation have different downstream
contracts.

No algorithmic fix, test change, cgroup setting, RTS setting, or systemd policy change was made as part of this
report.
