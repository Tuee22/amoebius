-- Phase-26 independent build-admission oracle.  It is authored against the
-- arithmetic `deriveBuildTransition` must produce, not against the catalog: the
-- stage names below are the oracle's own, so a catalog that renamed or merged a
-- stage cannot make this file agree with it by construction.
--
-- Re-sized on 2026-08-14 with the monocontainer amendment.  The 96 GiB scratch
-- and 64 GiB cache provisions were sized for a build whose base was
-- `nvidia/cuda:...-devel-ubuntu24.04` and whose every step unpacked another
-- public image; both are gone, and both exceeded the free space on the substrate
-- the linux-cpu lane actually runs on, so the previous envelope could only ever
-- have been admitted by a host nobody had.  CPU and memory are unchanged: the
-- builder's cgroup envelope is bound to those two peaks and the seeded
-- unbounded-worker mutant reads them.
{ fingerprint = "phase25-host-snapshot-v1"
, architectureConcurrency = 2
, stageConcurrency = 2
, stages =
  [ { name = "resolve-sources", dependencies = [] : List Text, cpuReservationMillis = 500, cpuCeilingMillis = 1000, memoryReservationBytes = 536870912, memoryCeilingBytes = 1073741824, intermediateBytes = 2147483648, cacheWriteBytes = 1073741824 }
  , { name = "service-assets", dependencies = [ "resolve-sources" ], cpuReservationMillis = 1000, cpuCeilingMillis = 1500, memoryReservationBytes = 1073741824, memoryCeilingBytes = 1610612736, intermediateBytes = 4294967296, cacheWriteBytes = 2147483648 }
  , { name = "resolver-build", dependencies = [ "resolve-sources" ], cpuReservationMillis = 1500, cpuCeilingMillis = 2000, memoryReservationBytes = 1073741824, memoryCeilingBytes = 2147483648, intermediateBytes = 3221225472, cacheWriteBytes = 2147483648 }
  , { name = "assemble-image", dependencies = [ "service-assets", "resolver-build" ], cpuReservationMillis = 1000, cpuCeilingMillis = 1500, memoryReservationBytes = 1073741824, memoryCeilingBytes = 1610612736, intermediateBytes = 6442450944, cacheWriteBytes = 3221225472 }
  ]
, scratchBacking = "base-image-registry-build-scratch"
, scratchCapacityBytes = 21474836480
, cacheBacking = "base-image-registry-build-cache"
, cacheCapacityBytes = 12884901888
, observedCacheResidentBytes = 2147483648
, residualCpuMillis = 8000
, residualMemoryBytes = 12884901888
, expectedCpuPeakMillis = 7000
, expectedMemoryPeakBytes = 7516192768
, expectedScratchPeakBytes = 21474836480
, expectedCacheWritePeakBytes = 10737418240
, expectedCacheTransitionBytes = 12884901888
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
