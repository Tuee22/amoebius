let clean = ../../fixture/dhall/test_topology_dsl/failover.dhall
in clean with expectations = [ { invariant = "StandbyTakesOver", witness = Some "broker-stats" }, { invariant = "CrossZoneContinuity", witness = Some "hardcoded-tested" } ]
