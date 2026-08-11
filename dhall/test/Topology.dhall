let Substrate = < linux-cpu | linux-cuda | apple | windows >
let TestCredential = { secretRef : Text, testSimulation : Bool }
let Allocation = { id : Text, testOwned : Bool, durableBytes : Natural }
let Fault = { kind : Text, target : Text, subscription : Text }
let Expectation = { invariant : Text, witness : Optional Text }
let Resources =
      { cpuMillis : Natural
      , memoryBytes : Natural
      , ephemeralBytes : Natural
      , durableBytes : Natural
      , cacheBytes : Natural
      , podSlots : Natural
      , ipSlots : Natural
      , csiSlots : Natural
      , providerQuota : Natural
      , accelerator : Optional Text
      }
in  { substrate : Substrate
    , credential : TestCredential
    , allocations : List Allocation
    , chaosSchedule : List Fault
    , expectations : List Expectation
    , teardown : Bool
    , resources : Resources
    }
