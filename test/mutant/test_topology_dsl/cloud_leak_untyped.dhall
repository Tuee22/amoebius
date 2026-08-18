let clean = ../../fixture/dhall/test_topology_dsl/failover.dhall
in clean with allocations = clean.allocations # [ { id = "untagged-aws-volume", testOwned = False, durableBytes = 1 } ]
