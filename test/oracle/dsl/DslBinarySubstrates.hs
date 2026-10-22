{-# LANGUAGE OverloadedStrings #-}

-- | The runner's rke2 challenge, interpreted independently from its authored
-- input. No product decoder, classifier, placement, or recipe code is linked.
module DslBinarySubstrates (BinaryTopology (..), binaryTopology, binarySubstrateRows, normal, field, textAt, listAt, one, unionTag, unionPayload, naturalAt, textOf) where

import Control.Monad (guard)
import Data.ByteString qualified as ByteString
import Data.Char (isDigit)
import Data.Foldable (toList)
import Data.List (sort)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Void (Void)
import Dhall.Core qualified as Core
import Dhall.Map qualified as Map
import Dhall.Parser qualified as Parser
import Dhall.TypeCheck qualified as TypeCheck
import DslParse
import DslStages (View (..), stageRows, fakeTranscriptRows)
import DslTables
import System.FilePath ((</>))

type Expr = Core.Expr Void Void

data BinaryTopology = KindInput | Rke2Input
  deriving (Eq, Show)

-- The schema mentions both alternatives. Select the authored value's active
-- constructor, never a field name occurring in its type or an unused binding.
binaryTopology :: Text -> Maybe BinaryTopology
binaryTopology source = do
  root <- normal source
  cluster <- listAt "rootClusters" root >>= one
  topology <- field "clusterTopology" cluster
  case (unionPayload "KindTopology" topology, unionPayload "Rke2Topology" topology) of
    (Just _, Nothing) -> Just KindInput
    (Nothing, Just _) -> Just Rke2Input
    _ -> Nothing

-- | Parse and typecheck without an import resolver. Any import, including an
-- unused or fallback import, refuses before normalisation.
normal :: Text -> Maybe Expr
normal source = do
  parsed <- either (const Nothing) Just (Parser.exprFromText "binary-input" ("(" <> source <> ") : " <> schemaLiteral))
  closed <- traverse (const Nothing) (Core.denote parsed)
  _ <- either (const Nothing) Just (TypeCheck.typeOf closed)
  pure (Core.normalize closed)

field :: Text -> Expr -> Maybe Expr
field name (Core.RecordLit fields) = Core.recordFieldValue <$> Map.lookup name fields
field _ _ = Nothing

textOf :: Expr -> Maybe Text
textOf (Core.TextLit (Core.Chunks [] value)) = Just value
textOf _ = Nothing

listOf :: Expr -> Maybe [Expr]
listOf (Core.ListLit _ values) = Just (toList values)
listOf _ = Nothing

textAt :: Text -> Expr -> Maybe Text
textAt key value = field key value >>= textOf

listAt :: Text -> Expr -> Maybe [Expr]
listAt key value = field key value >>= listOf

one :: [a] -> Maybe a
one [value] = Just value
one _ = Nothing

naturalAt :: Text -> Expr -> Maybe Integer
naturalAt key value = do
  Core.NaturalLit number <- field key value
  pure (toInteger number)

unionPayload :: Text -> Expr -> Maybe Expr
unionPayload tag (Core.App (Core.Field (Core.Union _) selection) payload)
  | Core.fieldSelectionLabel selection == tag = Just payload
unionPayload _ _ = Nothing

unionTag :: Text -> Expr -> Bool
unionTag tag (Core.Field (Core.Union _) selection) = Core.fieldSelectionLabel selection == tag
unionTag _ _ = False

-- | Read every varying fact from input; check all remaining authored fields
-- against this challenge's independent contract. In particular the oracle does
-- not infer a host's taints or the expected placement from a producer dump.
challenge :: Text -> Maybe (Text, Params)
challenge source = do
  root <- normal source
  cluster <- listAt "rootClusters" root >>= one
  guard (textAt "clusterName" cluster == Just "rke2-a")
  topology <- field "clusterTopology" cluster >>= unionPayload "Rke2Topology"
  quorum <- field "rke2Servers" topology >>= unionPayload "Three"
  servers <- traverse (`textAt` quorum) ["server1", "server2", "server3"]
  guard (servers == ["server-a", "server-b", "server-c"])
  agents <- listAt "rke2Agents" topology >>= traverse textOf
  guard (agents == ["agent-a", "agent-b"])
  hosts <- listAt "clusterHosts" cluster >>= traverse host
  guard (sort (map hostPName hosts) == sort (servers <> agents))
  ordered <- traverse (\name -> one [value | value <- hosts, hostPName value == name]) (servers <> agents)
  guard ([hostPName value | value <- ordered, hostPTaints value == ["maintenance"]] == ["agent-b"])
  guard (all (\value -> hostPTaints value == if hostPName value == "agent-b" then ["maintenance"] else []) ordered)
  available <- one [hostPName value | value <- ordered, hostPName value `elem` agents, null (hostPTaints value)]
  app <- listAt "rootApps" root >>= one
  appName <- textAt "appName" app
  nonce <- Text.stripPrefix "notes-" appName
  guard (Text.length nonce == 32 && Text.all (\c -> isDigit c || c >= 'a' && c <= 'f') nonce)
  need <- listAt "needs" app >>= one
  guard (textAt "needName" need == Just ("assets-" <> nonce))
  guard (maybe False (unionTag "ObjectStore") (field "needCapability" need))
  workload <- field "workload" app
  requests <- field "workloadRequests" workload
  limits <- field "workloadLimits" workload
  guard (traverse (`naturalAt` requests) ["podCpu", "podMemory", "podEphemeral"] == Just [1, 2, 4])
  guard (traverse (`naturalAt` limits) ["podCpu", "podMemory", "podEphemeral"] == Just [2, 4, 8])
  case field "workloadHeadroom" workload of
    Just (Core.App Core.None _) -> pure ()
    _ -> Nothing
  deployment <- listAt "rootDeployments" root >>= one
  guard (textAt "deploymentOf" deployment == Just appName)
  distribution <- field "distribution" deployment
  guard (naturalAt "replicas" distribution == Just 1)
  binding <- listAt "bindings" deployment >>= one
  guard (textAt "bindingNeed" binding == Just ("assets-" <> nonce))
  guard (textAt "bindingProvider" binding == Just "Canonical")
  guard (maybe False (unionTag "SingleNode") (field "bindingShape" binding))
  pure (nonce, baselineParams
    { paramApp = appName
    , paramNeeds = [NeedP ObjectStoreArm ("assets-" <> nonce) Single]
    , paramNodes = 5
    , paramRke2 = ordered
    , paramNodeOf = const available
    })
 where
  host value = do
    name <- textAt "hostName" value
    guard (textAt "hostOs" value == Just "linux" && textAt "hostArch" value == Just "amd64")
    guard (field "hostGpu" value == Just (Core.BoolLit False))
    guard (traverse (`naturalAt` value) ["hostCpu", "hostMemory", "hostEphemeral", "hostPods"] == Just [16, 64, 500, 110])
    taints <- listAt "hostTaints" value >>= traverse textOf
    pure (HostP name "linux-cpu" "amd64" ["linux-cpu/amd64"] taints)

binarySubstrateRows :: FilePath -> IO [Row]
binarySubstrateRows suite = do
  let root = suite </> "binary"
      compiled = root </> "compiled"
      applied = root </> "applied"
      files = map (Text.unpack . snd) stageFiles <> ["images/cpu-amd64.Dockerfile"]
  input <- readText (root </> "input" </> "root.dhall")
  frozen <- readText (compiled </> "frozen.dhall")
  manifest <- readBytes (compiled </> "manifest.json")
  appliedManifest <- readBytes (applied </> "manifest.json")
  fakeStdin <- readBytes (applied </> "fake" </> "stdin.combined")
  digest <- readText (applied </> "fake" </> "applied.sha256")
  outputs <- mapM (readText . (compiled </>)) files
  appliedOutputs <- mapM (readText . (applied </>)) files
  let expected = input >>= challenge
      sourceNormal = input >>= normal
      frozenNormal = frozen >>= normal
      inputText = fromMaybe "" input
      inputRow = check "binary.input-contract" (maybe False (const True) expected) "the source does not describe the nonce-bearing, three-server/two-agent taint challenge"
  case expected of
    Nothing -> pure [inputRow]
    Just (nonce, params) -> do
      stages <- stageRows (View compiled params (\family what -> "binary." <> family <> "." <> what))
      fake <- fakeTranscriptRows "binary.fake" (applied </> "fake") (maybe [] splitPayloads manifest)
      pure ([ inputRow
        , check "binary.input-carries-nonce" (Text.count nonce inputText == 4) "the input does not carry four nonce occurrences"
        , check "binary.freeze-equivalent" (sourceNormal /= Nothing && sourceNormal == frozenNormal) "the frozen artefact does not normalise to the perturbed input"
        , check "binary.sentinel-absent" (not (sentinel `Text.isInfixOf` inputText) && all (maybe False (not . Text.isInfixOf sentinel)) (outputs <> appliedOutputs)) "the sentinel survived or an output is absent"
        , check "binary.nonce-in-outputs" (all (maybe False (nonce `Text.isInfixOf`)) (take 5 outputs) && all (maybe False (ByteString.isInfixOf (Encoding.encodeUtf8 nonce))) [manifest, fakeStdin]) "the nonce is absent from a prefix artefact, the recipe, the catalog, the manifest, or stdin"
        , check "binary.applied-equals-compiled" (manifest /= Nothing && manifest == appliedManifest && outputs == appliedOutputs && all (/= Nothing) outputs) "compile and apply differ or an output is absent"
        , check "binary.manifest-equals-stdin" (manifest /= Nothing && manifest == fakeStdin) "the fake stdin differs from the compile output"
        , check "binary.digest" (fmap ((<> "\n") . sha256Hex) manifest == digest && digest /= Nothing) "the fake digest differs from the compiled bytes"
        ] <> stages <> fake)
