# Branching error: November 2–4, 2026

This note explains why the work saved on this branch diverges from the intended linear
development history. It records the investigation and recovery performed on November 4,
2026. It is historical context, not an architecture decision, phase tracker, or validation
result.

## What happened

Development on this machine continued from `3979a26`, the August 16, 2026 commit, without
first bringing the local `master` branch up to date with work published from the other
machine. Two local commits were made on that stale base:

| Commit | Local timestamp | Description |
|---|---|---|
| `ddf01e1` | November 2, 2026, 14:21:17 EST | Containment inventory, physically reserved build backings, private engine lifecycle, and associated image gate changes |
| `c615aca` | November 4, 2026, 10:07:55 EST | Image, reconciler, scheduler, retained-storage and Vault updates, plus substantial capacity, S3 and ZooKeeper backbone work |

Meanwhile, the published line advanced by 47 commits to `848986e`, dated October 30,
2026. Neither local commit was pushed to `origin/master`, and neither has a
patch-equivalent commit in the incoming history. Semantic overlap was not ruled out.

Both sides were individually linear. The divergence was two independent continuations
of the same August commit, rather than an accidental merge commit.

## What the reflog established

The remote-tracking reflog records `origin/master` advancing from `3979a26` to `848986e`
at **14:21:30 EST on November 2**, with the message `pull: fast-forward`. This was
13 seconds after the first local commit.

That entry records the update to the remote-tracking reference. It does not establish
that local `master` advanced. The local HEAD reflog contains the two local commits
without an intervening merge or rebase. Incoming history was therefore fetched after
the first local commit, but the local branch remained on its separate line.

The original pull's terminal output was not available during the investigation, so the
reason it did not reconcile the local branch is not established.

## Why a routine merge was unsuitable

The local commits changed 172 paths. A merge preview using Git 2.43.0 reported
60 conflicted paths: 20 content conflicts, 33 modify/delete conflicts, and seven
file-location conflicts. The preview did not merge either branch into the working tree.

The conflicts included changes to the development model itself:

- Incoming development re-sequenced the plan into phases `0..9` and `50..95`.
- Incoming rules require Haskell behavioral source, except for the bounded Python
  bootstrap under `pb/**`. The local work still contains Python gates, Java adapters,
  authored Dhall, and serialized behavioral oracles from the older model.
- Incoming status transitions belong to the verifier's `accept` and `reset` procedures.
  Its tracker records phases 0–1 Done and phase 2 Active. Local completion claims for
  the old phases 25–29 do not establish completion under the incoming contracts.
- Source layout, module ownership, build wiring, and validation evidence also changed.

Choosing conflict sides by date, or retaining all locally added files, would not resolve
those contract differences. Any future reuse needs a capability-level review against the
retained development plan, including `DEVELOPMENT_PLAN/development_plan_standards.md`
and its reconciliation and gate-integrity rules.

## Recovery performed

The initial idea was to set aside the November work and resume at the October 30 tip.
The subsequent instruction was to undo the unpushed commits while retaining their work
as uncommitted local changes. The recovery followed that instruction:

1. Created `archive/nov-02-04-2026` at `c615aca`, preserving both original local commits.
2. Ran a mixed reset of local `master` to the shared base, `3979a26`.
3. Verified that the contents and modes of all 172 affected paths were unchanged and
   that nothing was staged.

Immediately after the reset, the November work consisted of 63 unstaged tracked paths
(including one deletion) and 109 untracked files. Those counts precede this note and any
subsequent edits. Previously committed additions became untracked because the August
base does not contain them; their files were preserved.

**The reset did not move local `master` to October 30.** It returned it to the August
base so the local diff represented the November work alone. The 47 incoming commits
remained unapplied. Resetting directly to the October tip while preserving the old
working tree would also have represented incoming changes as local differences.

No staging, committing, or pushing was performed by the assistant.

## Purpose of the saved branch

The user intends to create a branch from this restored state and commit the preserved
work together with this explanation. At the time this note was written, that save
commit had not been made; `archive/nov-02-04-2026` already preserved the original two
commits.

The saved branch is an archive of work developed against the older contracts. It is not
a request to merge the work into the incoming line, and it does not make its phase
completion claims current. Committing it for preservation creates no obligation to port
every change or add abandoned work to the retained plan's migration backlog.

After the work is safely committed on its preservation branch, normal development can
resume from `848986e` or a newer published tip. Useful fixes may later be extracted in
bounded changes under the current source, ownership, and validation contracts.

Historical statements that a gate ran remain statements about that older source and
contract. The investigation and reset did not reproduce those runs or qualify them
against the incoming development model.
