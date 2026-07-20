# Amoebius Illegal-State Catalog Family

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: documents/README.md
**Generated sections**: none

> **Purpose**: Router for the illegal-state catalog family — the authoritative index is
> [`illegal_state_catalog.md`](./illegal_state_catalog.md); this file gives the folder a conventional entry
> point and defers to that index rather than restating it.

The catalog family enumerates the cluster states a valid `InForceSpec` cannot represent, and the typing
techniques that foreclose them. It has three parts:

- **[`illegal_state_catalog.md`](./illegal_state_catalog.md)** — the authoritative index: the themed map of
  *which* states are foreclosed, the honest limit (a type-check proves the spec composes, not that a running
  cluster enforces it), and links into the eight themed sub-catalogs.
- **The eight themed sub-catalogs** — the deep, numbered `§3.N` entries, each carrying an `Owner`,
  `Technique`, `Layer`, and `Validation-locus`:
  [storage](./illegal_state_storage.md) ·
  [topology](./illegal_state_topology.md) ·
  [capacity](./illegal_state_capacity.md) ·
  [security](./illegal_state_security.md) ·
  [capability-messaging](./illegal_state_capability_messaging.md) ·
  [ml-asset](./illegal_state_ml_asset.md) ·
  [multi-cluster](./illegal_state_multicluster.md) ·
  [lifecycle](./illegal_state_lifecycle.md).
- **[`illegal_state_techniques.md`](./illegal_state_techniques.md)** — the seven typing techniques, the
  coverage matrix (one row per entry), the three foreclosure layers, and the validation-locus axis.

Phase order, status, and validation gates live **only** in
[`../../DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md); the entries here state the target
design and never restate a phase status.

## Cross-references

- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the authoritative catalog index.
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — the typing techniques and coverage matrix.
- [`../README.md`](../README.md) — the top-level documentation index.
- [`../engineering/README.md`](../engineering/README.md) — the sibling engineering doctrine family.
