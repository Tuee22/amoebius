{-# LANGUAGE OverloadedStrings #-}

module ChainBoundaryOracle
  ( expectedCases
  , expectedPlanRows
  , expectedCalculusProjection
  , expectedBoundaryArgv
  , expectedBoundaryManifest
  , expectedAstNegatives
  , expectedSanctionedModules
  , expectedSanctionedEffects
  , expectedValidationLoci
  , expectedMutants
  ) where

import Data.ByteString.Lazy (ByteString)
import Data.Text (Text)

-- This module is the independent Phase-34 oracle.  It imports no production,
-- fixture, executor, or renderer module.
expectedCases :: [(Text, Text, Text, Int)]
expectedCases =
  [ ("minimal", "objectstore", "SingleNode", 1)
  , ("multi", "sql", "Distributed", 3)
  ]

expectedPlanRows :: [(Text, Int, Text, Text, Text, Text)]
expectedPlanRows =
  [ row "minimal" 1 "global/bootstrap-addon-cutover" "AfterBootstrapAddonCutoverFrame"
  , row "minimal" 2 "global/capacity-scheduler" "BootstrapSchedulerFrame"
  , row "minimal" 3 "global/managed-capacity-admission" "AfterManagedCapacityReadyFrame"
  , row "minimal" 4 "global/namespace" "ImmediateFrame"
  , row "minimal" 5 "objectstore/assets/config" "ImmediateFrame"
  , row "minimal" 6 "objectstore/assets/member-0" "AfterBootstrapAddonCutoverFrame"
  , row "minimal" 7 "objectstore/assets/service" "AfterBootstrapAddonCutoverFrame"
  , row "multi" 1 "global/bootstrap-addon-cutover" "AfterBootstrapAddonCutoverFrame"
  , row "multi" 2 "global/capacity-scheduler" "BootstrapSchedulerFrame"
  , row "multi" 3 "global/managed-capacity-admission" "AfterManagedCapacityReadyFrame"
  , row "multi" 4 "global/namespace" "ImmediateFrame"
  , row "multi" 5 "sql/database/config" "ImmediateFrame"
  , row "multi" 6 "sql/database/discovery" "AfterManagedCapacityReadyFrame"
  , row "multi" 7 "sql/database/member-0" "AfterBootstrapAddonCutoverFrame"
  , row "multi" 8 "sql/database/member-1" "AfterBootstrapAddonCutoverFrame"
  , row "multi" 9 "sql/database/member-2" "AfterBootstrapAddonCutoverFrame"
  , row "multi" 10 "sql/database/quorum-policy" "AfterManagedCapacityReadyFrame"
  , row "multi" 11 "sql/database/schema-bootstrap" "AfterBootstrapAddonCutoverFrame"
  , row "multi" 12 "sql/database/service" "AfterBootstrapAddonCutoverFrame"
  ]
 where
  row caseId position label frame = (caseId, position, label, frame, "ApplyObjects", label)

expectedCalculusProjection :: [(Text, Text)]
expectedCalculusProjection =
  [ ("calculus-kinds", "artifact,budget,lift,workflow,evidence")
  , ("component-names", "semantic-plan-rows,boundary-transcripts,ast-negatives,kernel-properties,mutant-evidence")
  , ("projection-counts", "19,4,6,2,7")
  , ("resource-vector", "5,38,0,0")
  ]

expectedBoundaryArgv :: [(FilePath, [String])]
expectedBoundaryArgv =
  [ ("kubectl.1.argv", ["apply", "--server-side=true", "-f", "-"])
  , ("docker.1.argv", ["build", "--pull=false", "."])
  , ("docker.2.argv", ["push", "amoebius:test"])
  , ("pulumi.1.argv", ["up", "--yes", "--skip-preview"])
  ]

expectedBoundaryManifest :: ByteString
expectedBoundaryManifest =
  "{\"apiVersion\":\"v1\",\"data\":{\"phase\":\"34\",\"purpose\":\"exact-boundary-byte-relay\"},\"kind\":\"ConfigMap\",\"metadata\":{\"name\":\"amoebius-boundary-fixture\",\"namespace\":\"amoebius-system\"}}\n"

expectedAstNegatives :: [(FilePath, Text, Int, Int)]
expectedAstNegatives =
  [ ("negative_import.hs", "UnsanctionedImport", 2, 1)
  , ("negative_raw_io.hs", "RawIO", 2, 7)
  , ("negative_foreign.hs", "ForeignCall", 2, 1)
  , ("negative_unsafe.hs", "UnsafeOperation", 2, 9)
  , ("negative_template_haskell.hs", "TemplateHaskell", 2, 9)
  , ("negative_orphan.hs", "OrphanInstance", 2, 1)
  ]

expectedSanctionedModules, expectedSanctionedEffects :: [Text]
expectedSanctionedModules = ["Amoebius.Kernel.Step", "Amoebius.Manifest.K8sObject"]
expectedSanctionedEffects = ["ApplyManifest", "BuildImage", "PushImage", "UpdateInfrastructure"]

expectedValidationLoci :: [Text]
expectedValidationLoci =
  [ "minimal_case", "multi_case", "boundary_corpus", "positive_basic", "positive_manifest"
  , "negative_import", "negative_raw_io", "negative_foreign", "negative_unsafe"
  , "negative_template_haskell", "negative_orphan", "checked_ctor_illegal", "sanctioned_api"
  , "m1_cfg_drop_service", "m2_descent_inframe", "mB1_argv", "mB2_byte", "mB3_path_resolve"
  , "astcheck-allow-rawio", "astcheck-export-ctor"
  ]

expectedMutants :: [(Text, Text, Text)]
expectedMutants =
  [ ("m1_cfg_drop_service", "chain-drop-service-mutant", "semantic plan projection drifted")
  , ("m2_descent_inframe", "chain-descent-inframe-mutant", "semantic plan projection drifted")
  , ("mB1_argv", "boundary-argv-mutant", "argv-transcript")
  , ("mB2_byte", "boundary-byte-mutant", "applied-bytes")
  , ("mB3_path_resolve", "boundary-path-resolve-mutant", "hostile-path")
  , ("astcheck-allow-rawio", "astcheck-allow-rawio-mutant", "negative_raw_io.hs unexpectedly accepted")
  , ("astcheck-export-ctor", "astcheck-export-ctor-mutant", "link-seal-exported")
  ]
