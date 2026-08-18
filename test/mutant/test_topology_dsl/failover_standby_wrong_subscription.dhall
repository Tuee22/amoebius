let clean = ../../fixture/dhall/test_topology_dsl/failover.dhall
in clean with chaosSchedule = [ { kind = "KillWorker", target = "worker-a", subscription = "wrong-subscription" } ]
