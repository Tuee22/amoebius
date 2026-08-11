let clean = ../dhall/phase_54_failover.dhall
in clean with expectations = [ { invariant = "StandbyTakesOver", witness = Some "broker-stats" }, { invariant = "CrossZoneContinuity", witness = Some "hardcoded-tested" } ]
