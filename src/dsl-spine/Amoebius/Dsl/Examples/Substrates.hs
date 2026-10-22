{-# LANGUAGE OverloadedStrings #-}

-- | The cumulative corpus plus supplied substrate observations and rke2 host
-- payloads. Expectations belong to the independent oracle.
module Amoebius.Dsl.Examples.Substrates
  ( Example (..), corpus, exampleNamed, renderExampleFiles ) where

import Amoebius.Dsl.Decode (rootSchema)
import Amoebius.Dsl.Encode (encodeRaw, encodeRoot, rawOf)
import Amoebius.Dsl.Examples.Capacity qualified as Capacity
import Amoebius.Dsl.Examples.Spine (Example (..), baselineRoot, helperFiles)
import Amoebius.Dsl.Raw qualified as Raw
import Amoebius.Dsl.Spec
import Amoebius.Substrate.Classify (Reads (..), classify)
import Amoebius.Topology.Rke2 (Rke2Quorum (..))
import Amoebius.Vocabulary
import Data.Bifunctor (first)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

rootFor :: Reads -> [Text] -> [Text] -> Either SpecError RootInForceSpec
rootFor reads agentNames tainted = do
  base <- baselineRoot
  detected <- first InvalidDetection (classify reads)
  name <- mkClusterName "rke2-a"
  let host label = do
        identity <- mkHostName label
        pure (HostSpec identity (HostResources 16 64 500 110) detected (if label `elem` tainted then Set.singleton "maintenance" else Set.empty))
  a <- host "server-a"
  b <- host "server-b"
  c <- host "server-c"
  agents <- traverse host agentNames
  let cluster = mkRke2ClusterSpec name (Three a b c) agents
  mkRootInForceSpec [cluster] (rootApps base) (rootDeployments base)

linuxReads :: Reads
linuxReads = Reads (OsName "linux") (RawArch "x86_64") GpuAbsent

rendered :: Either SpecError RootInForceSpec -> Text
rendered = either (const "") encodeRoot

duplicate :: Text
duplicate = either (const "") (encodeRaw . change . rawOf) (rootFor linuxReads ["agent-a"] [])
 where
  change root = root {Raw.rootClusters = map one (Raw.rootClusters root)}
  one cluster = cluster {Raw.clusterTopology = Raw.Rke2Topology (Raw.RawRke2 (Raw.Three (Raw.RawThree "server-a" "server-b" "server-c")) ["server-a", "agent-a"])}

corpus :: [Example]
corpus = Capacity.corpus <>
  [ Example "rke2-three-agent" (rendered (rootFor linuxReads ["agent-a"] []))
  , Example "rke2-cuda-three-agent" (rendered (rootFor (Reads (OsName "linux") (RawArch "x86_64") GpuPresent) ["agent-a"] []))
  , Example "apple-lima-rke2-arm64" (rendered (rootFor (Reads (OsName "darwin") (RawArch "arm64") GpuAbsent) ["agent-a"] []))
  , Example "untainted-sibling" (rendered (rootFor linuxReads ["agent-a", "agent-b"] []))
  , Example "tainted-first-agent" (rendered (rootFor linuxReads ["agent-a", "agent-b"] ["agent-a"]))
  , Example "tainted-second-agent" (rendered (rootFor linuxReads ["agent-a", "agent-b"] ["agent-b"]))
  , Example "tainted-only-host" (rendered (rootFor linuxReads ["agent-a"] ["agent-a"]))
  , Example "duplicate-host-id" duplicate
  ]

exampleNamed :: Text -> Maybe Example
exampleNamed name = case [example | example <- corpus, exampleName example == name] of
  example : _ -> Just example
  [] -> Nothing

renderExampleFiles :: [(FilePath, Text)]
renderExampleFiles =
  [("examples/" <> Text.unpack (exampleName example) <> ".dhall", exampleText example <> "\n") | example <- corpus]
    <> [("examples/" <> path, contents) | (path, contents) <- helperFiles]
    <> [("schema.dhall", rootSchema <> "\n")]
