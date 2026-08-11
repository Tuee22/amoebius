let TestTopology = ../../dhall/test/Topology.dhall
let Substrate = < linux-cpu | linux-cuda | apple | windows >
in  { substrate = Substrate.linux-cpu
    , credential = { secretRef = "vault/test/phase54", testSimulation = True }
    , allocations = [ { id = "phase54-retained", testOwned = True, durableBytes = 1073741824 } ]
    , chaosSchedule =
        [ { kind = "KillWorker", target = "worker-a", subscription = "phase54-failover" } ]
    , expectations =
        [ { invariant = "StandbyTakesOver", witness = Some "broker-stats" }
        , { invariant = "CrossZoneContinuity", witness = None Text }
        ]
    , teardown = True
    , resources =
        { cpuMillis = 3000
        , memoryBytes = 3221225472
        , ephemeralBytes = 8589934592
        , durableBytes = 1073741824
        , cacheBytes = 536870912
        , podSlots = 4
        , ipSlots = 4
        , csiSlots = 0
        , providerQuota = 0
        , accelerator = None Text
        }
    } : TestTopology
