# `pb` — pre-binary Haskell handoff

> **Purpose**: Describe the sole bounded non-Haskell source exception without assigning it product or
> validation authority.
> **Read this if**: the bootstrap package changes or a bare checkout must reach the Haskell executable.

This file is reference-only. The source boundary is owned by
[`repository_layout_doctrine.md` §2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure),
the handoff contract by
[`validation_frame_doctrine.md` §2](../documents/engineering/validation_frame_doctrine.md#2-the-bootstrap-boundary),
and its validation plan by [Phase 50](../DEVELOPMENT_PLAN/phase_50_host_assert_cli.md). Nothing here is an
executable oracle or evidence that the current package conforms.

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

</details>

## Bounded role

`pb/**` is the only version-controlled behavioral source permitted to be non-Haskell. Its Python may only:

1. make the minimal platform distinction needed to select the toolchain-establishment adapter;
2. establish the pinned Haskell toolchain beneath `.build/**`;
3. build the single source-bound Haskell executable beneath `.build/**`; and
4. replace itself with that exact executable while forwarding every user argument byte-for-byte.

The final item includes empty argv, `--help`, `--version`, `bootstrap`, `validate phase NN`, unknown verbs,
and every future public command. Python does not parse or dispatch that surface. Haskell owns host-floor
decisions, help, version, validation, product behavior, evidence, exit meaning, and every user-facing verb.

The accepted Python syntax, import, resolved-call, control-flow, and potential-effect surface is exact,
non-empty, and deny-by-default. Phase 0 must close `LTD-SRC-008` with that static Haskell-owned proof before
the no-hardware DSL barrier can be considered. Phase 0 through Phase 49 invoke the exact source-built Haskell
binary directly; `pb` is not validation transport. Phase 50 alone validates the runtime handoff; it does not
widen the exception or own a source migration.

## Development and generated material

There is no Python validation stack. Tests, source-policy checks, semantic expectations, oracles, and mutant
operators are Haskell source. Any Python environment, cache, rendered test input, copied source snapshot,
mutant materialization, process trace, or report is created lazily beneath `.build/**` and remains untracked.

The current package is an observed migration footprint, **NOT VALIDATED**. Do not infer conformance from a
command succeeding, a Python test passing, or a file being present.

## Related Documents

- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Validation-frame doctrine](../documents/engineering/validation_frame_doctrine.md)
- [Phase 0 documentation and policy reset](../DEVELOPMENT_PLAN/phase_00_documentation_suite.md)
- [Phase 49 no-hardware DSL barrier](../DEVELOPMENT_PLAN/phase_49_self_referential_gates.md)
- [Phase 50 bounded handoff validation](../DEVELOPMENT_PLAN/phase_50_host_assert_cli.md)
- [Single active legacy register](../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md)
