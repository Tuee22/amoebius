{ schemaVersion = "amoebius.phase37.round-trip-failover.v1"
, substrate = "linux-cpu"
, register = 3
, experimentNamespaces = [ "run-a", "run-b" ]
, orchestrator = "orchestrator"
, workers = [ "worker-a", "worker-b", "worker-c" ]
, subscription = "workflow-failover"
, contentGateway = "content-gateway"
, collector = "completion-collector"
, accelerator = None Text
}
