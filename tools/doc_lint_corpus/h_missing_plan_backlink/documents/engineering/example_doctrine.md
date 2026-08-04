# Example Doctrine

>
**Purpose**: One sentence describing the example doctrine.
>
**Read this if**: a bound shape has to be rendered.

This fixture doctrine owns the bound shape.
House rules belong to [the standards](../documentation_standards.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_01_example.md, documents/engineering/README.md
**Generated sections**: none

</details>

Status and sequencing live in the plan.
House rules are in [the standards](../documentation_standards.md).

## 1. The rule

amoebius binds the shape before it renders. The bound form is described by [§2](#2-the-bound-shape).

## 2. The bound shape

A bound shape carries the identity, the revision and the ceiling that the provisioning fold consumes before it renders.

```haskell
data BoundShape = BoundShape
  { shapeIdentity :: Identity
  , shapeRevision :: Revision
  }
```

## Related Documents

- [the standards](../documentation_standards.md)
