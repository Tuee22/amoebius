# Amoebius Documentation

> **Purpose**: Top-level index of the amoebius documentation — the three doctrine families
> ([`engineering/`](./engineering/README.md), [`illegal_state/`](./illegal_state/illegal_state_catalog.md),
> and the extension contract) and the shared [documentation standards](./documentation_standards.md).
> **Read this if**: the shape of the documentation corpus is unfamiliar and the question is which family owns what.

This index routes to the three doctrine families and the shared standards; it owns no doctrine of its own and
states no rule. Sequence, rather than subject grouping, is owned by
[reading_order.md](./reading_order.md), and phase order and status by
[`../DEVELOPMENT_PLAN/README.md`](../DEVELOPMENT_PLAN/README.md). Nothing here presumes prior knowledge of
amoebius.

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, README.md, documents/engineering/README.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_catalog.md
**Generated sections**: none

</details>

---

## Start here

Use the reading order for a first pass and the glossary to locate a term's owner. The doctrine families
below group reference material by subject. Their descriptions state intended architecture, not achieved certification.

- [`reading_order.md`](./reading_order.md) — the sequence in which this corpus is read for the first time, in
  eight stops, each naming where to stop reading.
- [`glossary.md`](./glossary.md) — the routing table from every amoebius term and acronym to the section that
  owns it, including the accepted baseline, certification generation, evidence custody, and current compatibility.
- [`../DEVELOPMENT_PLAN/README.md`](../DEVELOPMENT_PLAN/README.md) — the current certification frontier and dated audit; consult it before treating a design description as an implementation claim.

## The three doctrine families

- **[`engineering/`](./engineering/README.md)** — the engineering & architecture doctrine set: the DSL, the
  formal-model docs, platform & cluster, runtime, security, and lifecycle doctrine. See
  [`engineering/README.md`](./engineering/README.md) for the full index.
- **[`illegal_state/`](./illegal_state/README.md)** — the illegal-state catalog family.
  Its [family router](./illegal_state/README.md) locates the thematic slices. The authoritative
  [index](./illegal_state/illegal_state_catalog.md) maps states a valid `InForceSpec` is required to foreclose.
  Its nine themed sub-catalogs cover storage, topology, capacity, security, tenancy, messaging, ML assets,
  multiple clusters, and lifecycle. The [techniques doc](./illegal_state/illegal_state_techniques.md)
  maps enforcement technique, foreclosure layer, and validation locus.
- **The extension contract** — the open-core half: the hub
  [`engineering/extension_conformance_doctrine.md`](./engineering/extension_conformance_doctrine.md) with its
  three slices ([laws](./engineering/extension_conformance_laws.md) L1–L5 and C1–C7,
  [security](./engineering/extension_conformance_security.md) S1–S6,
  [transactions](./engineering/extension_conformance_transactions.md) P1–P6), stating what a domain or hardware
  extension must establish to join the algebra. The composition laws state further obligations; their
  presence in the index does not certify an extension or prove arbitrary implementation composition.

## Shared standards

- **[`documentation_standards.md`](./documentation_standards.md)** — the house rules every doc follows: the
  header block, SSoT / no-duplication, the proven/tested/assumed honesty discipline, the third-person tone, and
  the `§N` anchor-link conventions.
- **[`engineering/repository_layout_doctrine.md`](./engineering/repository_layout_doctrine.md)** — the complete
  tracked-tree grammar: every behavioral source is `.hs`, Python under `pb/**` is the sole language exception,
  every external-language artifact is generated lazily under `.build/**`, and operator inputs stay untracked.
  It also owns the closed `.build`/`.data`/`.test_data` roots and ignore/context rules.
- **[Accepted baseline and certification generation](../DEVELOPMENT_PLAN/development_plan_gate_integrity.md#m0-accepted-baseline-and-certification-generation)** — required acceptance authority, separately qualified contract revisions, and protected custody after the certification reset.

## Where status, progress, and phase order live

The [plan tracker](../DEVELOPMENT_PLAN/README.md) owns phase order, current status, and dated implementation
progress. Each linked phase document owns its acceptance contract. The
[gate-integrity standard](../DEVELOPMENT_PLAN/development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass)
owns evidence and compatibility requirements; these indexes supply none of that evidence.

The doctrine states target design and routes current-state questions to the plan. Historical implementation
observations remain diagnostic. A reset notice or revised contract does not implement its Haskell enforcement
or certify the retained source.

## Related Documents
- [`engineering/README.md`](./engineering/README.md) — the engineering doctrine index.
- [`illegal_state/illegal_state_catalog.md`](./illegal_state/illegal_state_catalog.md) — the illegal-state catalog index.
- [`documentation_standards.md`](./documentation_standards.md) — the documentation standards.
- [`../DEVELOPMENT_PLAN/README.md`](../DEVELOPMENT_PLAN/README.md) — phase order, status, and gates.
