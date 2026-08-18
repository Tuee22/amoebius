let binding = { pvc = "test-topology-dsl-claim", pv = "" }
let PvcMustBindPv = assert : binding.pv === "test-topology-dsl-volume"
in binding
