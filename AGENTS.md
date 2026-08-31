# Amoebius Repository Agent Instructions

> **Purpose**: Define the repository-local constraints that every automated coding agent must obey.
> **Read this if**: an agent will inspect, change, diagnose, or validate anything in this repository.

This file owns agent conduct only. Architecture, source classification, phase order, and validation design
remain owned by the linked doctrine and development-plan standards.

`CLAUDE.md` must remain the exact one-line mechanical import `@AGENTS.md` with one trailing newline. It must
not duplicate, summarize, qualify, or override this file; the documentation checker compares its exact bytes.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: CLAUDE.md, README.md, documents/glossary.md
**Generated sections**: none

</details>

## Git Restrictions

LLMs must not run `git add`, `git commit`, or `git push`.

Staging, committing, and pushing changes are reserved solely for the human user.

## Development Compiler Serialization

LLMs must serialize all development work that can invoke a compiler or linker. This includes Cabal builds,
tests, and runs; direct GHC invocations; compile-negative checks; component and mutation matrices; and every
generated harness row that performs any of those operations.

- Start at most one compiler- or linker-bearing command at a time and wait for it to finish before starting
  another. Do not overlap compile-only work with full-link work.
- Pass `--jobs=1` or `-j1` to every Cabal command that can build. Do not pass GHC an unbounded `-j` or a
  parallelism value greater than one.
- Execute compiler-bearing matrix and harness rows one at a time. Do not use `xargs -P` above one, GNU
  `parallel`, background jobs, concurrent subprocess pools, parallel tool calls, or subagents to run compiler-
  or linker-bearing work.
- A generated development harness must encode serial execution as a fixed invariant and must not expose an
  environment variable, argument, detected CPU count, or other override that can raise compiler or linker
  concurrency.

Only the human user may run compiler- or linker-bearing development work with concurrency above one. An LLM
must not infer permission to raise concurrency from available memory, CPU count, elapsed time, prior success,
or the absence of other observed compiler processes.

## Tracked Source Boundary

There must be **no version-controlled behavioral source code that is not Haskell (`.hs`)**, except for the
single bounded Python bootstrap under `pb/**`. This covers product, runtime, test, gate, generator, checker,
fixture, oracle, fake, and mutant source regardless of filename, extension, executable bit, or claimed data
role. The complete
closed classification is owned by the
[repository-layout doctrine](documents/engineering/repository_layout_doctrine.md#1-classification-rule);
documentation and narrowly defined repository/build
metadata are non-source inputs, not additional language exceptions.

Markdown may be checked for documentation structure, links, and status syntax, but it must never be parsed
into product behaviour, a semantic test expectation, a coverage registry, a generator input, or a validation
verdict. Those executable declarations and their independent expectations are Haskell.

`pb` may make only the minimal platform distinction needed to establish the pinned toolchain beneath
`.build/**`, build the source-bound Haskell binary, and replace itself with that exact binary via `exec` while
forwarding every user argument unchanged. Haskell owns host-floor decisions, help, version, validation, and
every public command. Python must not implement product behavior, dispatch a user command, decide or
interpret a validation result, or serve as an independent oracle. Dhall, PureScript, JavaScript, Python
outside `pb/**`, shell, Proto, Pulumi, Dockerfiles,
SQL, TLA+, CSS/HTML, serialized behavioral fixtures/oracles, and materialized mutants are generated lazily from Haskell into
ignored `.build/**` paths. Operator values are external or untracked inputs; they are not repository source.

## Validation Outcome and Ordering

A complete qualified phase-gate pass is sufficient to mark that phase and its sprints Done.
Recording the result is a mechanical status-only update after the exact current gate passes. Missing independent
oracles, paired negatives, changed-production-subject mutants, complete discovery, required external
observation, explicit residue, or the immediate predecessor's gate pass must make the gate fail rather than be
represented as a pass. A smaller component check, fixture count, digest, or partial run is not the phase gate.
The [development-plan standards](DEVELOPMENT_PLAN/development_plan_standards.md#c-status-vocabulary) own the
status procedure.

Within one phase, a sprint's `Blocked by` edge declares implementation order, not a request for intermediate
user confirmation. Agents continue through implementation-ready sprint seams. After the complete integrated
phase gate passes, an agent may apply the mechanical status-only update and continue into the next numerically
ordered phase in the same run. A component diagnostic or partial candidate must never trigger the Done update.

Four ordering barriers are named by role, never by ordinal. `DSL_BARRIER` is the hardware-free end-to-end DSL
gate; `BOOTSTRAP_HANDOFF` validates the bounded `pb`-to-Haskell handoff; `HOST_ENSURE` is the hardware-free
Haskell host-ensure gate against fake boundaries; `FIRST_HARDWARE` is the first hardware-bearing validation
phase, in that order. Each resolves to an ordinal through the compiled phase-identity table, which maps a
capability to the position it currently occupies. An ordinal literal in this file would be a second authority
that a plan rebalance silently falsifies, so this file names the role and the table supplies the number.

No hardware discovery, container-engine bring-up, cluster creation, image execution, or other live validation
may begin until the development plan records a passing `DSL_BARRIER` gate and passing results for
all of its predecessors. That barrier requires every source-migration query—including the bounded
`pb` role—to be zero. Before `BOOTSTRAP_HANDOFF` passes, `pb` is not an admissible validation transport: every
phase up to and including `DSL_BARRIER` builds and invokes the exact source-bound Haskell executable directly
from an authenticated,
network-independent toolchain input. Their `pb validate phase NN` spelling is the future public target, not
evidence that the unvalidated bootstrap ran correctly.

`BOOTSTRAP_HANDOFF` alone validates the already source-bounded runtime ensure/build/identity-argv/exec handoff
and owns no source migration. Its candidate starts the exact source-bound Haskell OS supervisor directly; that
supervisor invokes `pb` as the observed child subject, so the future public spelling cannot supervise or
validate its own handoff. `HOST_ENSURE` remains a hardware-free Haskell host-ensure gate against fake
boundaries; `FIRST_HARDWARE` is the first hardware-bearing validation phase.

Validation must follow numeric phase order and fail closed when a predecessor gate result or any required test
boundary is absent. Batch completion means repeated validate-and-record steps in one agent run; it never means
skipping a phase, sharing one candidate across phases, or treating a later result as evidence for an earlier one.

## Registry Provider

The only admitted cluster registry implementation is the Distribution image `registry:2`. Do not introduce
another registry product as a dependency, option, fallback, migration target, or reference design. Provider
selection is owned by the
[service-capability doctrine](documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific).

## Image Rebuild Prompt

The four `amoebius-base-{cpu,cuda}-{amd64,arm64}` tags are published artefacts, and a
consumer pulls them rather than rebuilding them. Their names are fixed rather than derived
from the recipe's content, so when the rendered image recipe or the bake catalog it
projects changes, the published tags no longer match the repository and nothing reports
that: a stale pull succeeds. So when a change touches the recipe or the catalog, prompt the
user to rebuild and repush all four tags before treating the change as landed.

Only the user runs the rebuild. An LLM may not push an image for the same reason it may
not push a commit — publication is an outward-facing act reserved to the human user.

This obligation is a consequence of the fixed names, not of publication itself, and it
retires when a tag becomes the recipe's content address: a changed recipe would then have
an address the registry does not hold, so a consumer rebuilds instead of pulling something
stale. That target is stated in
[`image_build_doctrine.md` §2.1](documents/engineering/image_build_doctrine.md#21-a-published-tag-is-a-cache-warm-up-and-its-name-is-the-content-address);
until a phase delivers it, the prompt above stands unchanged.
