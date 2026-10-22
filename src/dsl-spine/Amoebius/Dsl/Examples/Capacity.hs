{-# LANGUAGE OverloadedStrings #-}

-- | The Phase-4 corpus: the Phase-3 corpus and the examples that distinguish what the
-- witnesses add to the wire. Placement across two nodes, capacity on the boundary, a
-- second capability with a distributed shape, and an application needing two
-- capabilities. Inputs only: what each must produce is the oracle's.
module Amoebius.Dsl.Examples.Capacity
  ( Example (..)
  , sentinel
  , corpus
  , phaseThreeCorpus
  , exampleNamed
  , renderExampleFiles
  , Build (..)
  , baselineBuild
  , buildRoot
  ) where

import Amoebius.Capability.Types (CapabilityProvider (CanonicalProvider), ServiceShape (..))
import Amoebius.Dsl.Decode (rootSchema)
import Amoebius.Dsl.Encode (encodeRoot)
import Amoebius.Dsl.Examples.Spine (Example (..), helperFiles, sentinel)
import Amoebius.Dsl.Examples.Spine qualified as Spine
import Amoebius.Dsl.Spec
import Amoebius.Vocabulary (Architecture (Amd64), linuxCpuDetected, CapabilityArm (..), Quantity (..))
import Data.List.NonEmpty (NonEmpty (..))
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

-- | The choices an example makes over the baseline: how many kind nodes, what each node
-- holds, and which capabilities the application needs, each in what shape.
data Build = Build
  { buildNodes :: Natural
  , buildHost :: HostResources
  , buildNeeds :: [(CapabilityArm, Text, ServiceShape)]
  }

-- | The Phase-3 baseline: one node holding sixteen processors, an application needing one
-- object store bound single-node.
baselineBuild :: Build
baselineBuild = Build 1 (HostResources (Quantity 16) 64 500 110) [(ObjectStore, "assets-" <> sentinel, SingleNode)]

-- | The root a build describes: one kind cluster, one application needing every named
-- capability, one deployment binding each to the canonical provider.
buildRoot :: Build -> Either SpecError RootInForceSpec
buildRoot build = do
  clusterLabel <- mkClusterName "kind-a"
  hostLabel <- mkHostName "kind-host"
  kindReplicas <- mkKindReplicas (buildNodes build)
  cluster <- mkClusterSpec clusterLabel "kind-host" kindReplicas (HostSpec hostLabel (buildHost build) (linuxCpuDetected Amd64) Set.empty :| [])
  application <- mkAppName ("notes-" <> sentinel)
  needs <- mapM (\(arm, label, _) -> mkNeedLabelled arm label) (buildNeeds build)
  workload <- mkWorkloadSpec (PodResources 1 2 4) (PodResources 2 4 8) Nothing
  app <- mkAppSpec application needs workload
  replicas <- mkReplicas 1
  bindings <- mapM (\(_, label, shape) -> (\name -> BindingSpec name CanonicalProvider shape) <$> mkNeedName label) (buildNeeds build)
  deployment <- mkDeploymentRules application bindings (DistributionRule replicas)
  mkRootInForceSpec [cluster] [app] [deployment]
 where
  mkNeedLabelled arm label = mkNeedName label >>= mkNeedSpec arm

rendered :: Build -> Text
rendered = either (const "") encodeRoot . buildRoot

-- | The examples the Phase-4 gate adds to the Phase-3 corpus.
capacityExamples :: [Example]
capacityExamples =
  [ Example "kind-two-nodes" (rendered baselineBuild {buildNodes = 2, buildHost = HostResources 3 8 16 10})
  , Example "exact-fit-sibling" (rendered baselineBuild {buildNodes = 3, buildHost = HostResources 16 64 8 110})
  , Example "one-short-twin" (rendered baselineBuild {buildNodes = 3, buildHost = HostResources 16 64 7 110})
  , Example "over-capacity-twin" (rendered baselineBuild {buildNodes = 4, buildHost = HostResources 16 64 3 110})
  , Example "kind-sql-distributed3" (rendered baselineBuild {buildNeeds = [(Sql, "ledger-" <> sentinel, Distributed 3)]})
  , Example "kind-two-needs" (rendered baselineBuild {buildNeeds = [(ObjectStore, "assets-" <> sentinel, SingleNode), (Sql, "ledger-" <> sentinel, SingleNode)]})
  ]

-- | The corpus Phase 3 gated, unchanged.
phaseThreeCorpus :: [Example]
phaseThreeCorpus = Spine.corpus

-- | The Phase-3 corpus and the Phase-4 additions.
corpus :: [Example]
corpus = phaseThreeCorpus <> capacityExamples

exampleNamed :: Text -> Maybe Example
exampleNamed name = case [example | example <- corpus, exampleName example == name] of
  example : _ -> Just example
  [] -> Nothing

-- | Every file the corpus renders, relative to the output directory.
renderExampleFiles :: [(FilePath, Text)]
renderExampleFiles =
  [("examples/" <> Text.unpack (exampleName example) <> ".dhall", exampleText example <> "\n") | example <- corpus]
    <> [("examples/" <> path, contents) | (path, contents) <- helperFiles]
    <> [("schema.dhall", rootSchema <> "\n")]
