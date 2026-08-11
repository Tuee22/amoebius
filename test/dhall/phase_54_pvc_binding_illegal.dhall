let binding = { pvc = "phase54-claim", pv = "" }
let PvcMustBindPv = assert : binding.pv === "phase54-volume"
in binding
