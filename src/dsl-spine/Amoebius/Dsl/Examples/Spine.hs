{-# LANGUAGE OverloadedStrings #-}

-- | The example corpus: three distinguishing pairs and the refused set, as inputs only.
-- Each example is rendered from a typed value, or from a deliberately illegal authored
-- value, or by one textual edit of the rendered baseline. What each must produce is the
-- oracle's; nothing here states an expectation.
module Amoebius.Dsl.Examples.Spine
  ( sentinel
  , Example (..)
  , corpus
  , exampleNamed
  , variant
  , helperFiles
  , renderExampleFiles
  , baselineRoot
  ) where

import Amoebius.Capability.Types (CapabilityProvider (CanonicalProvider), ServiceShape (..))
import Amoebius.Dsl.Decode (rootSchema)
import Amoebius.Dsl.Encode (encodeRaw, encodeRoot, rawOf)
import Amoebius.Dsl.Raw qualified as Raw
import Amoebius.Dsl.Spec
import Amoebius.Vocabulary (CapabilityArm (..), Quantity (..))
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

-- | The placeholder the runner rewrites into a fresh nonce after the run starts.
sentinel :: Text
sentinel = "0b5e17e11a0c0ffee0de1e9a7e5ba5ed"

data Example = Example
  { exampleName :: Text
  , exampleText :: Text
  }

-- | The baseline: one kind cluster on one host, one application needing one object
-- store, bound single-node to the canonical provider, one replica.
baselineRoot :: Either SpecError RootInForceSpec
baselineRoot = variant 16 SingleNode 1

-- | The baseline with the host's processors, the binding's shape, and the replica count
-- chosen by the caller.
variant :: Natural -> ServiceShape -> Natural -> Either SpecError RootInForceSpec
variant processors shape count = do
  clusterLabel <- mkClusterName "kind-a"
  hostLabel <- mkHostName "kind-host"
  kindReplicas <- mkKindReplicas 1
  cluster <- mkClusterSpec clusterLabel "kind-host"
    kindReplicas (HostSpec hostLabel (HostResources (Quantity processors) 64 500 110) :| [])
  application <- mkAppName ("notes-" <> sentinel)
  needLabel <- mkNeedName ("assets-" <> sentinel)
  need <- mkNeedSpec ObjectStore needLabel
  workload <- mkWorkloadSpec (PodResources 1 2 4) (PodResources 2 4 8) Nothing
  app <- mkAppSpec application [need] workload
  replicas <- mkReplicas count
  deployment <- mkDeploymentRules application
    [BindingSpec needLabel CanonicalProvider shape] (DistributionRule replicas)
  mkRootInForceSpec [cluster] [app] [deployment]

rendered :: Either SpecError RootInForceSpec -> Text
rendered = either (const "") encodeRoot

rawBaseline :: Raw.RawRoot
rawBaseline = either (const emptyRaw) rawOf baselineRoot
 where
  emptyRaw = Raw.RawRoot [] [] []

-- | Replace the first occurrence of a needle.
replaceFirst :: Text -> Text -> Text -> Text
replaceFirst needle replacement haystack = case Text.breakOn needle haystack of
  (before, after)
    | Text.null after -> haystack
    | otherwise -> before <> replacement <> Text.drop (Text.length needle) after

appNameLiteral :: Text
appNameLiteral = "\"notes-" <> sentinel <> "\""

withAppName :: Text -> Text
withAppName import' = replaceFirst appNameLiteral import' (rendered baselineRoot)

mapApp :: (Raw.RawApp -> Raw.RawApp) -> Raw.RawRoot
mapApp change = rawBaseline {Raw.rootApps = map change (Raw.rootApps rawBaseline)}

mapDeployment :: (Raw.RawDeployment -> Raw.RawDeployment) -> Raw.RawRoot
mapDeployment change = rawBaseline {Raw.rootDeployments = map change (Raw.rootDeployments rawBaseline)}

corpus :: [Example]
corpus =
  [ Example "kind-single-objectstore" (rendered baselineRoot)
  , Example "shape-swap-sibling" (rendered (variant 16 (Distributed 3) 1))
  , Example "replicas-3-sibling" (rendered (variant 16 SingleNode 3))
  , Example "local-import-twin" (withAppName "./local-import-name.dhall")
  , Example "unbound-need" (encodeRaw (mapApp (\app -> app {Raw.needs = Raw.needs app <> [Raw.RawNeed Raw.ObjectStore ("cache-" <> sentinel)]})))
  , Example "dangling-binding" (encodeRaw (mapDeployment (\deployment ->
      deployment {Raw.bindings = Raw.bindings deployment <> [Raw.RawBinding "ghost" "Canonical" Raw.SingleNode]})))
  , Example "unknown-deployment" (encodeRaw (mapDeployment (\deployment -> deployment {Raw.deploymentOf = "ghost-app"})))
  , Example "forbidden-env" (withAppName "env:SPINE_UNSET_VARIABLE")
  , Example "forbidden-remote" (withAppName "https://example.invalid/name.dhall")
  , Example "forbidden-alternative" (withAppName "./missing-name.dhall ? https://example.invalid/name.dhall")
  , Example "forbidden-transitive" (withAppName "./forbidden-transitive-inner.dhall")
  , Example "forbidden-absolute" (withAppName "/etc/spine-absolute.dhall")
  , Example "forbidden-home" (withAppName "~/spine-home.dhall")
  , Example "non-code-import" (withAppName "./local-import-name.dhall as Text")
  , Example "parse-failure" "{ rootClusters = [\n"
  , Example "requests-above-limits" (encodeRaw (mapApp (\app -> app {Raw.workload = (Raw.workload app) {Raw.workloadRequests = Raw.RawPod 3 2 4}})))
  , Example "empty-needs" (encodeRaw (mapApp (\app -> app {Raw.needs = []})))
  , Example "zero-replicas" (encodeRaw (mapDeployment (\deployment -> deployment {Raw.distribution = Raw.RawDistribution 0})))
  , Example "headroom-all-zero" (encodeRaw (mapApp (\app -> app {Raw.workload = (Raw.workload app) {Raw.workloadHeadroom = Just (Raw.RawPod 0 0 0)}})))
  , Example "ill-typed-alternative" (replaceFirst ".ObjectStore" ".MinIO" (rendered baselineRoot))
  , Example "host-short" (rendered (variant 1 SingleNode 1))
  , Example "replicas-over-capacity" (rendered (variant 16 SingleNode 1000))
  , Example "product-named-in-app" (replaceFirst ">.ObjectStore" "| MinIO >.MinIO" (rendered baselineRoot))
  , Example "shape-in-app" (replaceFirst "{ needCapability =" "{ shape = 3, needCapability =" (rendered baselineRoot))
  ]

-- | The example of a name, when the corpus has one.
exampleNamed :: Text -> Maybe Example
exampleNamed name = case [example | example <- corpus, exampleName example == name] of
  example : _ -> Just example
  [] -> Nothing

-- | The two files the import examples read, beside the examples.
helperFiles :: [(FilePath, Text)]
helperFiles =
  [ ("local-import-name.dhall", appNameLiteral <> "\n")
  , ("forbidden-transitive-inner.dhall", "env:SPINE_UNSET_VARIABLE\n")
  ]

-- | Every file the corpus renders, relative to the output directory.
renderExampleFiles :: [(FilePath, Text)]
renderExampleFiles =
  [("examples/" <> Text.unpack (exampleName example) <> ".dhall", exampleText example <> "\n") | example <- corpus]
    <> [("examples/" <> path, contents) | (path, contents) <- helperFiles]
    <> [("schema.dhall", rootSchema <> "\n")]
