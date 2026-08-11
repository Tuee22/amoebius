# Amoebius Documentation

> **Purpose**: Top-level index of the amoebius documentation — the two doctrine families
> ([`engineering/`](./engineering/README.md) and [`illegal_state/`](./illegal_state/illegal_state_catalog.md))
> and the shared [documentation standards](./documentation_standards.md).
> **Read this if**: the shape of the documentation corpus is unfamiliar and the question is which family owns what.

This index routes to the two doctrine families and the shared standards; it owns no doctrine of its own and
states no rule. Sequence, rather than subject grouping, is owned by
[reading_order.md](./reading_order.md), and phase order and status by
[`../DEVELOPMENT_PLAN/README.md`](../DEVELOPMENT_PLAN/README.md). Nothing here presumes prior knowledge of
amoebius.

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, README.md, documents/engineering/README.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_catalog.md
**Generated sections**: none

</details>

---

## Start here

The two indexes below group documents by subject. Subject order is not reading order, and neither index says
which document to open first.

- [`reading_order.md`](./reading_order.md) — the sequence in which this corpus is read for the first time, in
  seven stops, each naming where to stop reading.
- [`glossary.md`](./glossary.md) — the routing table from every amoebius term and acronym to the section that
  owns it. Worth keeping open alongside any other document here.

## The two doctrine families

- **[`engineering/`](./engineering/README.md)** — the engineering & architecture doctrine set: the DSL, the
  formal-model docs, platform & cluster, runtime, security, and lifecycle doctrine. See
  [`engineering/README.md`](./engineering/README.md) for the full index.
- **[`illegal_state/`](./illegal_state/README.md)** — the illegal-state catalog family: its
  [family router](./illegal_state/README.md) and authoritative
  [index](./illegal_state/illegal_state_catalog.md) (the themed map of *which* states a valid `InForceSpec` cannot represent), eight themed sub-catalogs (storage · topology · capacity · security · capability-messaging · ml-asset · multi-cluster · lifecycle), and the [techniques doc](./illegal_state/illegal_state_techniques.md),
  which maps enforcement technique, foreclosure layer, and validation locus.

## Shared standards

- **[`documentation_standards.md`](./documentation_standards.md)** — the house rules every doc follows: the
  header block, SSoT / no-duplication, the proven/tested/assumed honesty discipline, the third-person tone, and
  the `§N` anchor-link conventions.
- **[`engineering/repository_layout_doctrine.md`](./engineering/repository_layout_doctrine.md)** — the complete
  authored/generated repository tree and the ignore, dependency-resolution, and evidence-retention rules.

## Where status, progress, and phase order live

Phase order, current status, dated implementation progress, and validation gates live **only** in
[`../DEVELOPMENT_PLAN/README.md`](../DEVELOPMENT_PLAN/README.md). The documents here state the target design and
link back there for state; historical implementation observations are diagnostic and never restate a current
phase status.

## Related Documents
- [`engineering/README.md`](./engineering/README.md) — the engineering doctrine index.
- [`illegal_state/illegal_state_catalog.md`](./illegal_state/illegal_state_catalog.md) — the illegal-state catalog index.
- [`documentation_standards.md`](./documentation_standards.md) — the documentation standards.
- [`../DEVELOPMENT_PLAN/README.md`](../DEVELOPMENT_PLAN/README.md) — phase order, status, and gates.
