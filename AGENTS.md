# Amoebius Repository Agent Instructions

> **Purpose**: Define the repository-local constraints that every automated coding agent must obey.
> **Read this if**: an agent will inspect, change, diagnose, or validate anything in this repository.

This file owns agent conduct only. Architecture, source classification, phase order, and validation design
remain owned by the linked doctrine and development-plan standards.

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

## Validation Authority and Ordering

LLMs may implement work and report diagnostics or candidate evidence, but only the human user may mark a
phase or sprint Done or Validated. A component check, green command, self-report, fixture count, receipt,
hash, or LLM-authored gate is never promotion authority. Missing independent oracles, paired negatives,
changed-production-subject mutants, complete discovery, external observation, explicit residue, or
predecessor approval must refuse a candidate rather than be represented as a pass.
The [development-plan standards](DEVELOPMENT_PLAN/development_plan_standards.md#c-status-vocabulary) own the
status procedure.

No hardware discovery, container-engine bring-up, cluster creation, image execution, or other live validation
may begin until the development plan records human approval of the Phase-49 hardware-free DSL promotion
barrier and all of its predecessors. That barrier requires every source-migration query—including the bounded
`pb` role—to be zero. Phase 50 validates the already-bounded handoff and owns no source migration. Validation
must follow numeric phase order and fail closed when predecessor evidence or any required trust boundary is
absent.

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
stale. That target is stated in `documents/engineering/image_build_doctrine.md` section
2.1; until a phase delivers it, the prompt above stands unchanged.
