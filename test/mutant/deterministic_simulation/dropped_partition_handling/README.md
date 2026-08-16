# Dropped-partition-handling mutant

`DroppedPartitionMutant.droppedPartitionReconcile` treats an empty consume during a partition as an
authoritative absence and applies stale state without waiting for the modeled link to heal. The Phase-15 gate
requires the `partition-heal` fixture to change from `Upheld` under the reference reconciler to
`Violated "NoActOnStaleRead"` under this mutant.
