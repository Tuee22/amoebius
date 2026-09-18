# Conformance Harness Doctrine

> **Purpose**: Redirect readers of the retired pre-cluster conformance harness to the gate-runner doctrine that supersedes it.
> **Read this if**: a link led here; the current owner of every rule this document once carried is named below.

This document is superseded by the [gate-runner doctrine](./gate_runner_doctrine.md), which owns the validator's
mechanics under certification generation 2
([DL-0007](../decision_log.md#dl-0007--certification-generation-2-replaces-the-validation-kernel)). It keeps
its former section anchors so that inbound links resolve; it owns nothing.

<details>
<summary>Link-graph metadata</summary>

**Status**: Deprecated
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/gate_runner_doctrine.md
**Generated sections**: none

</details>

<a id="1-why-this-doctrine-exists"></a>
<a id="2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation"></a>
<a id="3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure"></a>
<a id="4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply"></a>
<a id="5-the-pre-hardware-gate-barrier"></a>
<a id="6-honesty-what-the-harness-does-and-does-not-establish"></a>
<a id="7-planning-ownership"></a>

The registers are owned by [`testing_doctrine.md` §2](./testing_doctrine.md#2-the-registers-of-amoebius-testing).
The spine and the pre-hardware barrier are owned by
[Phase 3](../../DEVELOPMENT_PLAN/phase_03_typed_spine.md) and
[Phase 9](../../DEVELOPMENT_PLAN/phase_09_dsl_barrier.md), and the rule that hardware consumes the barrier by
[`gate_runner_doctrine.md` §7](./gate_runner_doctrine.md#7-the-example-corpus-and-the-hardware-rule).

## Related Documents

- [Gate-runner doctrine](./gate_runner_doctrine.md) — the superseding document
- [Testing doctrine](./testing_doctrine.md) — the registers
