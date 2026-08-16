{ objects =
  [ { digest = "sha256:1111111111111111111111111111111111111111111111111111111111111111", kind = "layer", storedBytes = 1048576 }
  , { digest = "sha256:2222222222222222222222222222222222222222222222222222222222222222", kind = "config-amd64", storedBytes = 4096 }
  , { digest = "sha256:3333333333333333333333333333333333333333333333333333333333333333", kind = "manifest-amd64", storedBytes = 8192 }
  , { digest = "sha256:4444444444444444444444444444444444444444444444444444444444444444", kind = "config-arm64", storedBytes = 4096 }
  , { digest = "sha256:5555555555555555555555555555555555555555555555555555555555555555", kind = "manifest-arm64", storedBytes = 8192 }
  , { digest = "sha256:6666666666666666666666666666666666666666666666666666666666666666", kind = "index", storedBytes = 2048 }
  ]
, residentObjects =
  [ { digest = "sha256:1111111111111111111111111111111111111111111111111111111111111111", storedBytes = 1048576 }
  , { digest = "sha256:7777777777777777777777777777777777777777777777777777777777777777", storedBytes = 524288 }
  ]
, uploadConcurrency = 2
, uploadWorkspaceBytesPerUpload = 2097152
, failedUploadsPerWindow = 3
, partialBytesPerFailedUpload = 1048576
, gcHorizonSeconds = 3600
, expectedResidentUnionBytes = 1599488
, expectedNewObjectBytes = 26624
, expectedWorkspaceBytes = 4194304
, expectedFailedResidueBytes = 3145728
, expectedTransitionBytes = 8939520
, expectedConflictTag = "RegistryDigestSizeConflict"
, expectedOneByteUnderTag = "RegistryStorageExceeded"
}
