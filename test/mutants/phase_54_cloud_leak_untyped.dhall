let clean = ../dhall/phase_54_failover.dhall
in clean with allocations = clean.allocations # [ { id = "untagged-aws-volume", testOwned = False, durableBytes = 1 } ]
