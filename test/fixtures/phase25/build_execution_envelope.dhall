{ fingerprint = "phase25-host-snapshot-v1"
, architectureConcurrency = 2
, stageConcurrency = 2
, stages =
  [ { name = "resolve-sources", dependencies = [] : List Text, cpuReservationMillis = 500, cpuCeilingMillis = 1000, memoryReservationBytes = 536870912, memoryCeilingBytes = 1073741824, intermediateBytes = 8589934592, cacheWriteBytes = 2147483648 }
  , { name = "service-assets", dependencies = [ "resolve-sources" ], cpuReservationMillis = 1000, cpuCeilingMillis = 1500, memoryReservationBytes = 1073741824, memoryCeilingBytes = 1610612736, intermediateBytes = 17179869184, cacheWriteBytes = 4294967296 }
  , { name = "resolver-build", dependencies = [ "resolve-sources" ], cpuReservationMillis = 1500, cpuCeilingMillis = 2000, memoryReservationBytes = 1073741824, memoryCeilingBytes = 2147483648, intermediateBytes = 4294967296, cacheWriteBytes = 2147483648 }
  , { name = "assemble-image", dependencies = [ "service-assets", "resolver-build" ], cpuReservationMillis = 1000, cpuCeilingMillis = 1500, memoryReservationBytes = 1073741824, memoryCeilingBytes = 1610612736, intermediateBytes = 34359738368, cacheWriteBytes = 12884901888 }
  ]
, scratchBacking = "phase25-build-scratch"
, scratchCapacityBytes = 103079215104
, cacheBacking = "phase25-build-cache"
, cacheCapacityBytes = 68719476736
, observedCacheResidentBytes = 8589934592
, residualCpuMillis = 8000
, residualMemoryBytes = 12884901888
, expectedCpuPeakMillis = 7000
, expectedMemoryPeakBytes = 7516192768
, expectedScratchPeakBytes = 103079215104
, expectedCacheWritePeakBytes = 34359738368
, expectedCacheTransitionBytes = 42949672960
, rejectionTags =
  [ "BuildCpuExceeded"
  , "BuildMemoryExceeded"
  , "BuildScratchExceeded"
  , "BuildCacheExceeded"
  , "BuildArchitectureConcurrencyExceeded"
  , "BuildStageConcurrencyExceeded"
  , "BuildUnknownCommitment"
  , "BuildSnapshotChanged"
  ]
}
