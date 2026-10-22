{-# LANGUAGE OverloadedStrings #-}

-- | Observations only. The independent oracle owns expected cardinalities,
-- duplicate refusals, placements, and the table of lanes.
module SpineSubstrates (substrateSection) where

import Amoebius.Capacity.Types
import Amoebius.Capacity.Vector (ResourceVector (..))
import Amoebius.Dsl.Topology (NodeSupply (..), Topology, TopologyError (..), mkRke2Topology, mkTopology, topologySupply)
import Amoebius.Dsl.Examples.Capacity qualified as Capacity
import Amoebius.Dsl.Examples.Substrates qualified as Examples
import Amoebius.Dsl.Pipeline (applyToDirectory, compileToDirectory, lowerToDirectory)
import Amoebius.Placement.Witness (place, placedNode)
import Amoebius.Substrate.Classify (Reads (..), classify)
import Amoebius.Topology.Lanes (laneLabels)
import Amoebius.Topology.Rke2 (Rke2Quorum (..), rke2Servers)
import Amoebius.Vocabulary
import Amoebius.Vocabulary.Frame (frameName)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Control.Monad (void)
import SpineRecipeControls (recipeControls)
import System.Directory (createDirectoryIfMissing)
import System.Environment (getExecutablePath)
import System.FilePath (takeDirectory, (</>))

substrateSection :: FilePath -> IO ()
substrateSection suite = do
  let directory = suite </> "substrates"
  createDirectoryIfMissing True directory
  writeRows (directory </> "quorum.tsv") quorumRows
  writeRows (directory </> "taints.tsv") taintRows
  writeRows (directory </> "detection.tsv") detectionRows
  writeRows (directory </> "profiles.tsv") profileRows
  recipeControls suite
  image <- getExecutablePath
  mapM_ (\(path, contents) -> do
    let target = directory </> "corpus" </> path
    createDirectoryIfMissing True (takeDirectory target)
    TextIO.writeFile target contents) Examples.renderExampleFiles
  writeRows (directory </> "corpus.tsv") [[Text.pack path] | (path, _) <- Examples.renderExampleFiles]
  mapM_ (observeExample image directory) (drop (length Capacity.corpus) Examples.corpus)

observeExample :: FilePath -> FilePath -> Examples.Example -> IO ()
observeExample image directory example = do
  let name = Text.unpack (Examples.exampleName example)
      input = directory </> "corpus" </> "examples" </> (name <> ".dhall")
      output = directory </> "stages" </> name
  if name == "apple-lima-rke2-arm64"
    then void (lowerToDirectory input output)
    else do
      void (compileToDirectory input output)
      void (applyToDirectory False image input (directory </> "applied" </> name))

writeRows :: FilePath -> [[Text]] -> IO ()
writeRows path = TextIO.writeFile path . Text.unlines . map (Text.intercalate "\t")

node :: Text -> Node
node name = Node name name NativeLinux (NodeCapacity (ResourceVector 16 64 500 110) NoCpuOvercommit Map.empty) Set.empty (linuxCpuDetected Amd64) Rke2Agent

quorumRows :: [[Text]]
quorumRows =
  [ positive "single" (Single a) []
  , positive "three" (Three a b c) [agent]
  , positive "five" (Five a b c d e) [agent]
  , negative "duplicate-server" (Three a a c) []
  , negative "duplicate-agent" (Single a) [agent, agent]
  , negative "server-is-agent" (Three a b c) [b]
  ]
 where
  a = node "server-a"
  b = node "server-b"
  c = node "server-c"
  d = node "server-d"
  e = node "server-e"
  agent = node "agent-a"
  positive name quorum agents = [name, commas (map nodeHostId (rke2Servers quorum)), either (Text.pack . show) (commas . map nodeHostId . nodes) (mkRke2Topology quorum agents)]
  negative name quorum agents = [name, case mkRke2Topology quorum agents of
    Left (DuplicateHostId _) -> "DuplicateHostId"
    Left problem -> Text.pack (show problem)
    Right _ -> "accepted"]
  nodes :: Topology -> [Node]
  nodes topology = case topologySupply topology of
    FixedSupply members -> NonEmpty.toList members
    ElasticSupply {} -> []

taintRows :: [[Text]]
taintRows =
  [ observation "untainted" a b Set.empty
  , observation "tainted-first" taintedA b Set.empty
  , observation "tainted-second" a taintedB Set.empty
  , observation "tainted-only" taintedA taintedB Set.empty
  , observation "tolerated" taintedA b (Set.singleton "maintenance")
  ]
 where
  a = node "host-a"
  b = node "host-b"
  taintedA = a {nodeTaints = Set.singleton "maintenance"}
  taintedB = b {nodeTaints = Set.singleton "maintenance"}
  observation name first second tolerations = [name, placementOf (mkTopology KindEngine (FixedSupply (first :| [second]))) tolerations]
  placementOf topology tolerations = case topology of
    Left problem -> Text.pack (show problem)
    Right value -> case place value [Workload "work" (exactResourceEnvelope (ResourceVector 1 1 1 1)) emptyStorageDemand [] tolerations Nothing] of
      Left (TaintedOnlyHost _) -> "TaintedOnlyHost"
      Left problem -> Text.pack (show problem)
      Right placed -> maybe "missing" id (placedNode placed "work")

detectionRows :: [[Text]]
detectionRows = map observed inputs
 where
  inputs = [("linux", "x86_64", False), ("linux", "aarch64", False), ("linux", "x86_64", True), ("linux", "aarch64", True), ("darwin", "arm64", False), ("windows", "amd64", False), ("darwin", "amd64", False), ("windows", "arm64", False), ("freebsd", "amd64", False), ("linux", "sparc", False)]
  observed (operatingSystem, architecture, gpu) =
    map Text.pack [operatingSystem, architecture, if gpu then "present" else "absent"] <>
      case classify (Reads (OsName operatingSystem) (RawArch architecture) (if gpu then GpuPresent else GpuAbsent)) of
        Left problem -> [Text.pack (hostRefusalTag problem)]
        Right detected -> [Text.pack (substrateName (detectedSubstrate detected)), Text.pack (architectureName (detectedArchitecture detected)), commas (laneLabels detected)]

commas :: [Text] -> Text
commas = Text.intercalate ","

profileRows :: [[Text]]
profileRows =
  [ [Text.pack (substrateName substrate), Text.pack (architectureName architecture)
    , maybe "observed" (Text.pack . architectureName) (profileRequiredArchitecture profile)
    , Text.pack (frameName (profileFrame profile))
    , either (Text.pack . hostRefusalTag) (commas . laneLabels) (mkDetected substrate architecture)]
  | substrate <- [minBound .. maxBound]
  , architecture <- [minBound .. maxBound]
  , let profile = substrateProfile substrate
  ]
