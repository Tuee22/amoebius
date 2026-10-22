{-# LANGUAGE OverloadedStrings #-}

-- | Independently authored substrate expectations. These rows precede the
-- implementation and import no product declarations, codecs, or constants.
module DslSubstrates (substrateRows) where

import Data.Text (Text)
import Data.Text qualified as Text
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Aeson (object, (.=))
import DslParse
import DslTables
import DslStages (View (..), stageRows, fakeTranscriptRows)
import DslRecipe (recipeRows)
import System.Directory (listDirectory, doesDirectoryExist)
import System.FilePath ((</>))

substrateRows :: FilePath -> IO [Row]
substrateRows suite = do
  quorum <- readTable (suite </> "substrates" </> "quorum.tsv")
  taints <- readTable (suite </> "substrates" </> "taints.tsv")
  detections <- readTable (suite </> "substrates" </> "detection.tsv")
  profiles <- readTable (suite </> "substrates" </> "profiles.tsv")
  let directory = suite </> "substrates"
  stages <- concat <$> mapM (judgeExample directory) linuxExamples
  apple <- judgeApple directory
  negative <- concat <$> mapM (judgeNegative directory) [("duplicate-host-id", "DuplicateHostId", "lower"), ("tainted-only-host", "TaintedOnlyHost", "provision")]
  inventory <- readTable (directory </> "corpus.tsv")
  let names = map fst linuxExamples <> ["apple-lima-rke2-arm64", "duplicate-host-id", "tainted-only-host"]
      files = corpusInventory <> ["examples/" <> name <> ".dhall" | name <- names]
  actual <- listFiles (directory </> "corpus" </> "examples")
  pure
    ([ expectEqual "quorum.payloads" quorumRows quorum
    , expectEqual "taints.placement" taintRows taints
    , expectEqual "lanes.detection" detectionRows detections
    , expectEqual "lanes.profiles" profileRows profiles
    , expectEqual "substrates.corpus.inventory" (sort (map pure files)) (sort <$> inventory)
    , check "substrates.corpus.files" (sort actual == sort [Text.drop (Text.length "examples/") file | file <- files, "examples/" `Text.isPrefixOf` file]) "rendered files differ from the independent inventory"
    ] <> stages <> apple <> negative)

linuxExamples :: [(Text, Params)]
linuxExamples =
  [("rke2-three-agent", rke2Params ["agent-a"] [] "agent-a"), ("untainted-sibling", rke2Params ["agent-a", "agent-b"] [] "agent-a"), ("tainted-first-agent", rke2Params ["agent-a", "agent-b"] ["agent-a"] "agent-b"), ("tainted-second-agent", rke2Params ["agent-a", "agent-b"] ["agent-b"] "agent-a"), ("rke2-cuda-three-agent", (rke2Params ["agent-a"] [] "agent-a") {paramRke2 = [HostP name "linux-cuda" "amd64" ["linux-cpu/amd64", "linux-cuda/amd64"] [] | name <- ["server-a", "server-b", "server-c", "agent-a"]]})]

rke2Params :: [Text] -> [Text] -> Text -> Params
rke2Params agents tainted placed = baselineParams
  { paramNodes = fromIntegral (3 + length agents)
  , paramNodeOf = const placed
  , paramRke2 = [HostP name "linux-cpu" "amd64" ["linux-cpu/amd64"] (if name `elem` tainted then ["maintenance"] else []) | name <- ["server-a", "server-b", "server-c"] <> agents]
  }

judgeExample :: FilePath -> (Text, Params) -> IO [Row]
judgeExample directory (name, params) = do
  let compiled = directory </> "stages" </> Text.unpack name
      applied = directory </> "applied" </> Text.unpack name
  stages <- stageRows (View compiled params (\family what -> family <> ".substrates." <> name <> "." <> what))
  manifest <- readBytes (compiled </> "manifest.json")
  appliedManifest <- readBytes (applied </> "manifest.json")
  stdin <- readBytes (applied </> "fake" </> "stdin.combined")
  fake <- fakeTranscriptRows ("fake-apply.substrates." <> name) (applied </> "fake") (maybe [] splitPayloads manifest)
  let nodes = [value | payload <- maybe [] splitPayloads manifest, Just value <- [parseObject payload], mKind value == "Node"]
      expectedNode host =
        let role = if "server-" `Text.isPrefixOf` hostPName host then "Rke2Server" else "Rke2Agent"
            taints = sort ((if role == "Rke2Server" then ["node-role.kubernetes.io/control-plane"] else []) <> hostPTaints host)
            labels = Map.fromList
              ([("amoebius.io/owner", "deployment-global"), ("app.kubernetes.io/managed-by", "amoebius"), ("amoebius.io/epoch", "generation-1"),
                ("amoebius.io/scope", attestedScopeLabel "core/ObjectStore" (paramApp params) (paramNeed params)),
                ("amoebius.io/substrate", hostPSubstrate host), ("kubernetes.io/arch", hostPArchitecture host)] <> [("amoebius.io/lane-" <> Text.replace "/" "-" lane, "true") | lane <- hostPLanes host])
            specification = object ["tag" .= ("GlobalControlSpec" :: Text), "contents" .= Map.fromList [("role" :: Text, role), ("taints", Text.intercalate "," taints)]]
        in (hostPName host, labels, specification)
      matches (nodeName, labels, specification) = length [() | value <- nodes, mName value == nodeName, mNamespace value == Nothing, mLabels value == labels, mSpec value == specification] == 1
  pure (stages <> fake <>
    [check ("fake-apply.substrates." <> name <> ".bytes") (manifest /= Nothing && manifest == appliedManifest && manifest == stdin) "compile, apply, and fake stdin differ"
    , check ("lanes.substrates." <> name <> ".nodes") (length nodes == length (paramRke2 params) && all (matches . expectedNode) (paramRke2 params)) "node identities, roles, taints, substrate, architecture, or lane labels differ"])

judgeApple :: FilePath -> IO [Row]
judgeApple directory = do
  let output = directory </> "stages" </> "apple-lima-rke2-arm64"
      params = (rke2Params ["agent-a"] [] "agent-a") {paramRke2 = [HostP name "apple" "arm64" ["linux-cpu/arm64", "apple-metal"] [] | name <- ["server-a", "server-b", "server-c", "agent-a"]]}
  decoded <- readText (output </> "decoded.dump")
  lowered <- readText (output </> "lowered.dump")
  files <- listFiles output
  applied <- doesDirectoryExist (directory </> "applied" </> "apple-lima-rke2-arm64")
  recipes <- recipeRows output "substrates.apple" (paramApp params) True [("linux-cpu/arm64", "amoebius-base-cpu-arm64", "ubuntu:24.04")]
  pure ([expectEqual "decode.substrates.apple" (expectedDecoded params) (Text.lines <$> decoded), expectEqual "lower.substrates.apple" (expectedLowered params) (Text.lines <$> lowered), check "substrates.apple.prefix-only" (sort files == sort ["frozen.dhall", "decoded.dump", "lowered.dump", "image-recipe.tsv", "bake-catalog.tsv", "image-build-arguments.tsv", "images"] && not applied) "Apple was provisioned or fake-applied"] <> recipes)

judgeNegative :: FilePath -> (Text, Text, Text) -> IO [Row]
judgeNegative directory (name, tag, stage) = do
  let output = directory </> "stages" </> Text.unpack name
  refusal <- readText (output </> "refusal.tsv")
  files <- listFiles output
  stdin <- exists (directory </> "applied" </> Text.unpack name </> "fake" </> "stdin.combined")
  pure [check (stage <> ".substrates." <> name) (maybe False ((== [tag, stage]) . take 2 . Text.splitOn "\t") refusal && sort files == sort ("refusal.tsv" : refusalStageFiles stage) && not stdin) "refusal tag, stage, completed prefix, or fake boundary differs"]

listFiles :: FilePath -> IO [Text]
listFiles path = do
  present <- doesDirectoryExist path
  if present then map Text.pack <$> listDirectory path else pure []

quorumRows :: [[Text]]
quorumRows =
  [ ["single", "server-a", "server-a"]
  , ["three", "server-a,server-b,server-c", "server-a,server-b,server-c,agent-a"]
  , ["five", "server-a,server-b,server-c,server-d,server-e", "server-a,server-b,server-c,server-d,server-e,agent-a"]
  , ["duplicate-server", "DuplicateHostId"]
  , ["duplicate-agent", "DuplicateHostId"]
  , ["server-is-agent", "DuplicateHostId"]
  ]

taintRows :: [[Text]]
taintRows =
  [ ["untainted", "host-a"]
  , ["tainted-first", "host-b"]
  , ["tainted-second", "host-a"]
  , ["tainted-only", "TaintedOnlyHost"]
  , ["tolerated", "host-a"]
  ]

detectionRows :: [[Text]]
detectionRows =
  [ ["linux", "x86_64", "absent", "linux-cpu", "amd64", "linux-cpu/amd64"]
  , ["linux", "aarch64", "absent", "linux-cpu", "arm64", "linux-cpu/arm64"]
  , ["linux", "x86_64", "present", "linux-cuda", "amd64", "linux-cpu/amd64,linux-cuda/amd64"]
  , ["linux", "aarch64", "present", "linux-cuda", "arm64", "linux-cpu/arm64,linux-cuda/arm64"]
  , ["darwin", "arm64", "absent", "apple", "arm64", "linux-cpu/arm64,apple-metal"]
  , ["windows", "amd64", "absent", "windows", "amd64", "linux-cpu/amd64"]
  , ["darwin", "amd64", "absent", "apple-arm64-only"]
  , ["windows", "arm64", "absent", "windows-natural-architecture-only"]
  , ["freebsd", "amd64", "absent", "unknown-os"]
  , ["linux", "sparc", "absent", "unknown-arch"]
  ]

-- The complete catalog/architecture product, including both illegal pairs.
profileRows :: [[Text]]
profileRows =
  [ ["linux-cpu", "amd64", "observed", "native-linux", "linux-cpu/amd64"]
  , ["linux-cpu", "arm64", "observed", "native-linux", "linux-cpu/arm64"]
  , ["linux-cuda", "amd64", "observed", "native-linux", "linux-cpu/amd64,linux-cuda/amd64"]
  , ["linux-cuda", "arm64", "observed", "native-linux", "linux-cpu/arm64,linux-cuda/arm64"]
  , ["apple", "amd64", "arm64", "lima-guest", "apple-arm64-only"]
  , ["apple", "arm64", "arm64", "lima-guest", "linux-cpu/arm64,apple-metal"]
  , ["windows", "amd64", "amd64", "wsl2-guest", "linux-cpu/amd64"]
  , ["windows", "arm64", "amd64", "wsl2-guest", "windows-natural-architecture-only"]
  ]
