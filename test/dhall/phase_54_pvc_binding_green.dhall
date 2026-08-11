let binding = { pvc = "phase54-claim", pv = "phase54-volume" }
let _ = assert : binding.pv === "phase54-volume"
in binding
