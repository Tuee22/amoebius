{-# LANGUAGE OverloadedStrings #-}

-- | The independent oracle of the typed spine. It reads the bytes the suite wrote and the
-- bytes the runner's own commands wrote, judges them against literals typed in
-- "DslTables", and prints one row per judgement. It depends on no library of this
-- repository; it does not run the product and does not parse the plan.
module Main (main) where

import Data.ByteString qualified as ByteString
import Data.Char (isDigit)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import DslCapacity (capacityRows)
import DslFamilies
import DslParse
import DslScan (scanRows)
import DslStages
import DslTables
import DslTwins (twinRows)
import System.Directory (doesDirectoryExist)
import System.Environment (getArgs)
import System.Exit (ExitCode (ExitFailure, ExitSuccess), exitWith)
import System.FilePath ((</>))

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [suite] -> do
      rows <- allRows suite
      mapM_ (putStrLn . renderRow) rows
      exitWith (if not (null rows) && all rowGreen rows then ExitSuccess else ExitFailure 1)
    _ -> putStrLn "oracle.usage\tred\texpected one suite directory" >> exitWith (ExitFailure 2)

-- | The examples the suite compiles that render, with what each was given.
renderedExamples :: [(Text, Params)]
renderedExamples =
  [ ("kind-single-objectstore", baselineParams)
  , ("shape-swap-sibling", baselineParams {paramNeeds = [NeedP ObjectStoreArm ("assets-" <> sentinel) Spread]})
  , ("replicas-3-sibling", baselineParams {paramReplicas = 3})
  , ("local-import-twin", baselineParams)
  , ("kind-two-nodes", baselineParams {paramNodes = 2, paramHost = (3, 8, 16, 10), paramNodeOf = appOnSecondNode})
  , ("exact-fit-sibling", baselineParams {paramNodes = 3, paramHost = (16, 64, 8, 110), paramNodeOf = appOnSecondNode})
  , ("kind-sql-distributed3", baselineParams {paramNeeds = [NeedP SqlArm ("ledger-" <> sentinel) Spread]})
  , ("kind-two-needs", baselineParams {paramNeeds = [NeedP ObjectStoreArm ("assets-" <> sentinel) Single, NeedP SqlArm ("ledger-" <> sentinel) Single]})
  ]
 where
  -- The heaviest workload fills the first node, so the application lands on the second.
  appOnSecondNode unit = if "app/" `Text.isPrefixOf` unit then "kind-host-2" else "kind-host-1"

allRows :: FilePath -> IO [Row]
allRows suite = do
  sections <- sectionRows suite
  vocab <- vocabRows suite
  spec <- specRows suite
  freeze <- freezeRows suite
  decode <- decodeRows suite
  lower <- lowerRows suite
  stages <- concat <$> mapM (\(example, params) -> stageRows (corpusView suite example params)) renderedExamples
  refusals <- refusalRows suite
  endpoint <- endpointRows suite
  consume <- consumeRows suite
  corpus <- corpusRows suite
  chainTableRow <- chainTableRows suite
  interpret <- interpretRows suite
  wire <- wireRows suite
  diffs <- diffRows suite
  binary <- binaryRows suite
  twins <- twinRows suite
  capacity <- capacityRows suite
  scans <- scanRows
  let detail = concat [sections, vocab, spec, freeze, decode, lower, stages, refusals, endpoint, consume, corpus, chainTableRow, interpret, wire, diffs, binary, twins, scans, capacity]
  pure (detail <> caseRows (not (null binary)) detail)

-- | What separates the siblings from the baseline, and the twin from it.
diffRows :: FilePath -> IO [Row]
diffRows suite = do
  baseline <- entries "kind-single-objectstore"
  spread <- entries "shape-swap-sibling"
  counted <- entries "replicas-3-sibling"
  placed <- entries "kind-two-nodes"
  twin <- readBytes (suite </> "stages" </> "local-import-twin" </> "manifest.json")
  original <- readBytes (suite </> "stages" </> "kind-single-objectstore" </> "manifest.json")
  let shared identity = identity `elem` map fst3 baseline
      sharedPrefix (identity, _, _) = any (`Text.isPrefixOf` identity) ["app/", "global/"]
      identical = and [bytes == other | (identity, bytes, _) <- filter sharedPrefix baseline, (identity', other, _) <- spread, identity' == identity]
      paths = concat [differingPaths (mValue object) (mValue other) | (identity, _, object) <- baseline, (identity', _, other) <- counted, identity' == identity]
      placementPaths = concat [differingPaths (mValue object) (mValue other) | (identity, _, object) <- baseline, (identity', _, other) <- placed, identity' == identity]
  pure
    [ check "render.diff.shapeswap" (identical && length baseline == 11 && length spread == 17 && all shared [identity | (identity, _, _) <- filter sharedPrefix spread]) (Text.pack (show (length baseline, length spread)))
    , check "render.diff.replicas3" (paths == [".spec.contents[1].podReplicas"] && map fst3 baseline == map fst3 counted) (Text.pack (show paths))
    , check "render.twin-equals-baseline" (twin /= Nothing && twin == original) "the local-import twin rendered different bytes"
    , check "render.diff.placement" (map fst3 baseline == map fst3 placed && placementPaths == [".spec.contents[1].podNodeName"]) (Text.pack (show placementPaths))
    ]
 where
  entries example = manifestEntries <$> readBytes (suite </> "stages" </> Text.unpack example </> "manifest.json")
  fst3 (first, _, _) = first

-- | The runner's own perturbed run, when the suite directory carries it.
binaryRows :: FilePath -> IO [Row]
binaryRows suite = do
  present <- doesDirectoryExist (suite </> "binary")
  if not present then pure [] else do
    let compiled = suite </> "binary" </> "compiled"
        applied = suite </> "binary" </> "applied"
    decoded <- readText (compiled </> "decoded.dump")
    input <- readText (suite </> "binary" </> "input" </> "root.dhall")
    manifest <- readBytes (compiled </> "manifest.json")
    appliedManifest <- readBytes (applied </> "manifest.json")
    frozen <- readText (compiled </> "frozen.dhall")
    outputs <- mapM (readText . (compiled </>)) (map (Text.unpack . snd) stageFiles)
    appliedOutputs <- mapM (readText . (applied </>)) (map (Text.unpack . snd) stageFiles)
    fakeStdin <- readBytes (applied </> "fake" </> "stdin.combined")
    appliedDigest <- readText (applied </> "fake" </> "applied.sha256")
    let nonce = nonceOf decoded
        inputText = fromMaybe "" input
        number key = numberAfter (key <> " = ") inputText
        hostCpu = number "hostCpu"
        -- Every number the stages are judged against is read from the input the runner authored.
        params =
          baselineParams
            { paramApp = "notes-" <> nonce
            , paramNeeds = [NeedP ObjectStoreArm ("assets-" <> nonce) Single]
            , paramReplicas = number "distribution.replicas"
            , paramNodes = number "kindReplicas"
            , paramHost = (hostCpu, number "hostMemory", number "hostEphemeral", number "hostPods")
            , paramNodeOf = placedOn hostCpu
            }
        namer family what = "binary." <> family <> "." <> what
        everything = Text.concat (map (fromMaybe "") (outputs <> appliedOutputs))
    stage <- stageRows (View compiled params namer)
    fake <- fakeTranscriptRows "binary.fake" (applied </> "fake") (maybe [] splitPayloads manifest)
    sourceHash <- maybe (pure Nothing) (independentHash (suite </> "binary" </> "input")) input
    frozenHash <- maybe (pure Nothing) (independentHash (suite </> "binary" </> "input")) frozen
    pure $
      [ check "binary.nonce-shape" (Text.length nonce == 32 && Text.all (\c -> isDigit c || (c >= 'a' && c <= 'f')) nonce) "the nonce is not thirty-two lowercase hexadecimal characters"
      , check "binary.input-carries-nonce" (("notes-" <> nonce) `Text.isInfixOf` inputText && ("assets-" <> nonce) `Text.isInfixOf` inputText && Text.count nonce inputText == 4) "the perturbed input does not carry the nonce where the sentinel was"
      , check "binary.freeze-equivalent" (frozenHash /= Nothing && frozenHash == sourceHash) "the frozen artefact does not normalise to the perturbed input"
      , check "binary.input-numbers" (all (> 0) [paramNodes params, paramReplicas params, hostCpu, number "hostMemory", number "hostEphemeral", number "hostPods"]) "the perturbed input does not carry the nodes, replicas, and host capacity the stages are judged against"
      , check "binary.sentinel-absent" (not (sentinel `Text.isInfixOf` inputText) && not (sentinel `Text.isInfixOf` everything)) "the sentinel survived into the input or an output"
      , check "binary.nonce-in-outputs" (all (maybe False (nonce `Text.isInfixOf`)) (take 5 outputs) && maybe False (ByteString.isInfixOf (Encoding.encodeUtf8 nonce)) manifest && maybe False (ByteString.isInfixOf (Encoding.encodeUtf8 nonce)) fakeStdin) "the nonce is missing from a stage artefact, the manifest, or the fake's stdin"
      , check "binary.applied-equals-compiled" (manifest /= Nothing && manifest == appliedManifest && outputs == appliedOutputs) "the apply command compiled different bytes from the compile command"
      , check "binary.manifest-equals-stdin" (manifest /= Nothing && manifest == fakeStdin) "the fake's stdin differs from the compile output"
      , check "binary.digest" (fmap sha256Hex manifest /= Nothing && fmap (\digest -> digest <> "\n") (fmap sha256Hex manifest) == appliedDigest) "the fake's applied digest differs from the digest of the compile output"
      ]
        <> stage
        <> fake
 where
  numberAfter key text = case Text.breakOn key text of
    (_, rest) | not (Text.null rest), digits <- Text.takeWhile isDigit (Text.drop (Text.length key) rest), not (Text.null digits) -> fromIntegral (Text.foldl' (\acc c -> acc * 10 + toInteger (fromEnum c - 48)) (0 :: Integer) digits)
    _ -> 0
  -- The heaviest workload, the provider's member, fills the first node; the application joins it
  -- only when that node's processors cover the member's two and the application's own limit of two.
  placedOn hostCpu unit
    | "app/" `Text.isPrefixOf` unit && hostCpu < 2 + 2 = "kind-host-2"
    | otherwise = "kind-host-1"
  nonceOf decoded = case [Text.drop (Text.length "app.0.name\tnotes-") line | line <- maybe [] Text.lines decoded, "app.0.name\tnotes-" `Text.isPrefixOf` line] of
    candidate : _ -> candidate
    [] -> ""

-- | The gate's cases: each names the rows that, together, are the claim it makes.
caseRows :: Bool -> [Row] -> [Row]
caseRows binary detail = [caseRow name required | (name, required) <- cases]
 where
  caseRow name required =
    let judged = [(wanted, [verdict | Row rowName verdict _ <- detail, rowName == wanted]) | wanted <- required]
        missing = [wanted | (wanted, verdicts) <- judged, verdicts /= [True]]
     in check name (null missing) ("rows absent or red: " <> Text.intercalate "," (take 4 missing))
  cases = positiveCases <> negativeCases <> [("case:shipped-binary", binaryRowsNamed) | binary]
  stageNames example =
    [ "freeze." <> example <> ".equivalent", "decode." <> example <> ".dump", "lower." <> example <> ".dump", "plan." <> example <> ".dump"
    , "provision." <> example <> ".dump", "render." <> example <> ".objects", "render." <> example <> ".app-deployment", "render." <> example <> ".app-namespace-service"
    , "place." <> example <> ".nodes", "claims." <> example <> ".volumes"
    , "chain." <> example <> ".dump", "chain." <> example <> ".manifest", "chain." <> example <> ".format", "dry-run." <> example <> ".dump", "pipeline." <> example <> ".artefacts", "pipeline." <> example <> ".no-refusal", "endpoint." <> example
    ]
  positiveCases =
    [ ("case:kind-single-objectstore", stageNames "kind-single-objectstore")
    , ("case:shape-swap-sibling", stageNames "shape-swap-sibling" <> ["render.diff.shapeswap"])
    , ("case:replicas-3-sibling", stageNames "replicas-3-sibling" <> ["render.diff.replicas3"])
    , ("case:local-import-twin", stageNames "local-import-twin" <> ["freeze.hash.twin", "render.twin-equals-baseline"])
    , ("case:kind-two-nodes", stageNames "kind-two-nodes" <> ["render.diff.placement"])
    , ("case:exact-fit-sibling", stageNames "exact-fit-sibling")
    , ("case:kind-sql-distributed3", stageNames "kind-sql-distributed3")
    , ("case:kind-two-needs", stageNames "kind-two-needs")
    , ("case:fits-total", ["fits.count", "fits.grid", "fits.verdicts", "fits.admitted-count", "fits.exact-fit", "fits.axis-order", "fits.headroom", "fits.sum", "fits.zero"])
    , ("case:volume-witness", ["volume.table", "volume.injective", "volume.size-explicit"])
    , ("case:statefulset-claims", ["claims.statefulset", "claims.claim-body", "claims.bare-statefulset"])
    , ("case:lanes-of", ["vocab.host-grid", "vocab.detect", "vocab.labels", "vocab.extensions"])
    , ("case:round-trip", ["decode.roundtrip.kind-single-objectstore", "decode.roundtrip.shape-swap-sibling", "decode.roundtrip.replicas-3-sibling", "decode.schema.equals-literal", "decode.schema.no-product", "decode.schema.names", "decode.typecheck.kind-single-objectstore", "decode.typecheck.shape-swap-sibling", "decode.typecheck.replicas-3-sibling", "decode.typecheck.local-import-twin"])
    , ("case:step-sequence", ["chain.table", "chain.kind-single-objectstore.dump", "chain.shape-swap-sibling.dump", "chain.replicas-3-sibling.dump"])
    , ("case:dry-run-zero", ["dry-run.kind-single-objectstore.dump", "dry-run.fake-directory", "dry-run.planned", "dry-run.unsupported", "dry-run.no-fake", "dry-run.same-dump"])
    , ("case:fake-relay", concat [[prefix <> suffix | suffix <- [".count", ".argv", ".environment", ".stdin", ".combined", ".digest"]] | prefix <- ["fake-apply.transcript.full", "fake-apply.transcript.from-cutover", "fake-apply.transcript.from-managed", "fake-apply.transcript.fail-at-3", "fake-apply.transcript.hostile-path"]] <> ["fake-apply.decoy-not-run", "fake-apply.fail-at-3.result", "fake-apply.full.result", "fake-apply.real-executor.exit"])
    , ("case:endpoint-digest", ["endpoint.kind-single-objectstore", "endpoint.shape-swap-sibling", "endpoint.replicas-3-sibling", "endpoint.local-import-twin"])
    , ("case:fields-consumed", ["consume." <> leaf | (leaf, _) <- differentialGrid] <> ["consume.complete"])
    , ("case:corpus-discovery", ["corpus.inventory", "corpus.tsv", "corpus.stages"])
    ]
  negativeCases =
    [ ("case:AppleNeedsArm64", ["vocab.apple-needs-arm64"])
    , ("case:WindowsNeedsAmd64", ["vocab.windows-needs-amd64"])
    ]
      <> [("case:" <> label, ["freeze.refusal." <> example, "pipeline.refusal." <> example]) | (label, example) <- freezeCases]
      <> [("case:" <> label, ["decode.example." <> example, "pipeline.refusal." <> example]) | (label, example) <- decodeCases]
      <> [("case:" <> label, ["lower.example." <> example, "lower.refusal-detail." <> example, "pipeline.refusal." <> example]) | (label, example) <- lowerCases]
      <> [ ("case:HostShort", ["pipeline.refusal.host-short"])
         , ("case:ReplicasOverCapacity", ["pipeline.refusal.replicas-over-capacity"])
         , ("case:DetectedAppleAmd64", ["twin.detected-apple-amd64"])
         , ("case:BoundDeploymentOutsideLower", ["twin.bound-deployment-outside-lower", "twin.bound-deployment-internal-hidden", "scan.assemble-importers"])
         , ("case:StepCarriesIO", ["twin.step-carries-io"])
         , ("case:TwoServerQuorum", ["twin.two-server-quorum"])
         , ("case:OneShort", ["pipeline.refusal.one-short-twin"])
         , ("case:OverCapacity", ["pipeline.refusal.over-capacity-twin"])
         , ("case:UnitMismatch", ["twin.unit-mismatch"])
         , ("case:RenderWithoutWitness", ["twin.render-without-witness"])
         , ("case:PlacedOutsideFold", ["twin.placed-outside-fold"])
         , ("case:PvcWithoutStatefulSet", ["claims.pvc-without-statefulset", "twin.claim-outside-statefulset"])
         , ("case:VolumeOutsideWitness", ["twin.volume-outside-witness"])
         ]
  freezeCases =
    [ ("ForbiddenImportEnv", "forbidden-env"), ("ForbiddenImportRemote", "forbidden-remote"), ("ForbiddenImportAlternative", "forbidden-alternative")
    , ("ForbiddenImportTransitive", "forbidden-transitive"), ("AbsoluteImport", "forbidden-absolute"), ("HomeImport", "forbidden-home")
    , ("NonCodeImport", "non-code-import"), ("ParseFailure", "parse-failure"), ("IllTypedAlternative", "ill-typed-alternative")
    ]
  decodeCases =
    [ ("RequestsAboveLimits", "requests-above-limits"), ("EmptyNeeds", "empty-needs"), ("ZeroReplicas", "zero-replicas")
    , ("HeadroomAllZero", "headroom-all-zero"), ("ProductNamedInApp", "product-named-in-app"), ("ShapeInApp", "shape-in-app")
    ]
  lowerCases = [("UnboundNeed", "unbound-need"), ("DanglingBinding", "dangling-binding"), ("UnknownDeployment", "unknown-deployment")]
  binaryRowsNamed = [rowNamed row | row <- detail, "binary." `Text.isPrefixOf` rowNamed row]
