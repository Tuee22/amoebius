{-# LANGUAGE OverloadedStrings #-}

module IllegalStateCoveringOracle
  ( expectedCatalogSha256
  , expectedCatalogCount
  , expectedReachedCount
  , expectedPhaseTwentySevenCount
  , expectedPhaseNineRows
  , expectedStructuralRows
  , expectedDecodeRows
  , CompileCase (..)
  , compileCases
  ) where

import Data.Text (Text)

expectedCatalogSha256 :: Text
expectedCatalogSha256 = "333d380eab90df92707128ea411fbf23741aa59144343d2fc17668565329d2e9"

expectedCatalogCount, expectedReachedCount, expectedPhaseTwentySevenCount :: Int
expectedCatalogCount = 121
expectedReachedCount = 43
expectedPhaseTwentySevenCount = 26

expectedPhaseNineRows :: [(Text, Text)]
expectedPhaseNineRows =
  [ ("3.5", "schedulability")
  , ("3.13", "engine-union")
  , ("3.27", "placement-witness")
  , ("3.29", "host-demand-fit")
  , ("3.31", "single-topology-index")
  , ("3.35", "remote-networking-field")
  , ("3.36", "control-plane-reach")
  , ("3.37", "managed-hybrid-arm")
  , ("3.38", "host-worker-reach")
  , ("3.39", "site-index")
  , ("3.73", "padded-reservation-fit")
  ]

expectedStructuralRows :: [(Text, Text, Text)]
expectedStructuralRows =
  [ ("3.7", "closed-ingress-shape", "Backdoor")
  , ("3.14", "unsupported-bare-substrate", "WindowsBare")
  , ("3.16", "fixed-node-cardinality", "host")
  , ("3.17", "daemonset-both-positive", "maxSurge")
  , ("3.17", "statefulset-unsupported-feature", "PodManagementPolicy")
  , ("3.17", "statefulset-nonzero-partition", "NativeSerialPartitionZero")
  , ("3.17", "job-missing-terminal-retention", "terminalRetention")
  ]

expectedDecodeRows :: [(Text, Text, Text)]
expectedDecodeRows =
  [ ("3.16", "distinct-hosts", "DistinctHosts")
  , ("3.17", "rolling-progress", "UnspellableCombination")
  , ("3.17", "deployment-host-resource", "ControllerResourceMismatch")
  , ("3.17", "statefulset-once", "StatefulSetRequiresRolling")
  , ("3.17", "statefulset-host-resource", "ControllerResourceMismatch")
  , ("3.17", "daemonset-host-resource", "ControllerResourceMismatch")
  , ("3.17", "job-host-resource", "ControllerResourceMismatch")
  , ("3.17", "hostprocess-pod-resource", "ControllerResourceMismatch")
  , ("3.17", "cuda-rolling", "CudaRequiresOnce")
  , ("3.17", "metal-deployment-policy", "MetalRequiresHostProcess")
  , ("3.23", "consume-codec", "MalformedCbor")
  , ("3.72", "headroom-over-limit", "HeadroomOverLimit")
  , ("3.72", "headroom-all-zero", "HeadroomAllZero")
  ]

data CompileCase = CompileCase
  { compileCaseName :: Text
  , compileCaseEntries :: [(Text, Text)]
  , compileCaseLocus :: Text
  , compileCaseLegal :: Text
  , compileCaseIllegal :: Text
  }

compileCases :: [CompileCase]
compileCases =
  [ compile "tenant-index" [("3.8", "tenant-index"), ("3.10", "owner-index")] "TenantB"
      "acceptTenantRef (Ref :: Ref 'TenantA 'TenantA)"
      "acceptTenantRef (Ref :: Ref 'TenantA 'TenantB)"
  , compile "pv-pvc-index" [("3.2", "pv-pvc-index")] "OtherVolume"
      "bindVolume (Pv :: Pv 'DataVolume) (Pvc :: Pvc 'DataVolume)"
      "bindVolume (Pv :: Pv 'DataVolume) (Pvc :: Pvc 'OtherVolume)"
  , compile "endpoint-kind-index" [("3.7", "endpoint-kind-index")] "PlainEndpoint"
      "acceptTlsEndpoint (Endpoint :: Endpoint 'TlsEndpoint)"
      "acceptTlsEndpoint (Endpoint :: Endpoint 'PlainEndpoint)"
  , compile "live-service-route-index" [("3.3", "live-service-route-index")] "MissingService"
      "buildRoute (ServiceHandle :: ServiceHandle 'LiveService)"
      "buildRoute (ServiceHandle :: ServiceHandle 'MissingService)"
  , compile "produce-codec" [("3.23", "produce-codec")] "Raw"
      "producePayload (Payload :: Payload 'Cbor)"
      "producePayload (Payload :: Payload 'Raw)"
  ]
 where
  compile = CompileCase
