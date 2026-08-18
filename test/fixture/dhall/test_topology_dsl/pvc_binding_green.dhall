let binding = { pvc = "test-topology-dsl-claim", pv = "test-topology-dsl-volume" }
let _ = assert : binding.pv === "test-topology-dsl-volume"
in binding
