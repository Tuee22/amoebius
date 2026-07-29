# Example Doctrine

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_01_example.md, documents/engineering/README.md
**Generated sections**: none

> **Purpose**: One sentence describing the example doctrine.

Status and sequencing live in [the plan](../../DEVELOPMENT_PLAN/README.md).
House rules are in [the standards](../documentation_standards.md).

## 1. The rule

amoebius binds the shape before it renders.
The bound form is described by [§2](#2-the-unbound-shape).

## 2. The bound shape

A bound shape carries the identity, the revision and the ceiling that the provisioning fold consumes before it renders.

```haskell
data BoundShape = BoundShape
  { shapeIdentity :: Identity
  , shapeRevision :: Revision
  }
```
