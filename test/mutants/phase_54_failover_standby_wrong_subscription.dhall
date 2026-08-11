let clean = ../dhall/phase_54_failover.dhall
in clean with chaosSchedule = [ { kind = "KillWorker", target = "worker-a", subscription = "wrong-subscription" } ]
