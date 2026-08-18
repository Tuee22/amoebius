let clean = ../../fixture/dhall/test_topology_dsl/failover.dhall
in clean with allocations = [ { id = "backing-without-api-binding", testOwned = True, durableBytes = 1073741824 } ]
