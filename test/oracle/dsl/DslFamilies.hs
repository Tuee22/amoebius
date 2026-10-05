{-# LANGUAGE OverloadedStrings #-}

-- | The families that are not stage artefacts of one run: the vocabulary, the boundaries of
-- the typed specification, the freeze, the decoder and its schema, lowering, the endpoint,
-- the differential, the corpus inventory, the step algebra's table, and the interpreter's.
module DslFamilies
  ( sectionRows
  , vocabRows
  , specRows
  , freezeRows
  , decodeRows
  , lowerRows
  , refusalRows
  , endpointRows
  , consumeRows
  , corpusRows
  , chainTableRows
  , interpretRows
  , independentHash
  , wireRows
  ) where

import Control.Exception (SomeException, try)
import Control.Monad (forM)
import Data.Char (isHexDigit)
import Data.List (sort)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Void (Void)
import Dhall qualified
import Dhall.Core qualified as Core
import Dhall.Import qualified as DhallImport
import Dhall.Src (Src)
import DslParse
import DslStages (fakeTranscriptRows)
import DslTables
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory, withCurrentDirectory)
import System.FilePath ((</>))

-- | A section that failed or overran leaves a marker; the row it becomes belongs to the
-- family of the stage that section exercised.
sectionRows :: FilePath -> IO [Row]
sectionRows suite = do
  complete <- exists (suite </> "complete.marker")
  markers <- forM sections $ \(section, family) -> do
    failed <- exists (suite </> "sections" </> (section <> ".failed"))
    pure (check (family <> ".section") (not failed) ("the " <> Text.pack section <> " section failed or overran"))
  pure (check "suite.complete" complete "the suite ended before it wrote its marker" : markers)
 where
  sections =
    [ ("corpus", "corpus")
    , ("stages", "pipeline")
    , ("vocab", "vocab")
    , ("spec", "spec")
    , ("freeze", "freeze")
    , ("decode", "decode")
    , ("differential", "consume")
    , ("chain", "chain")
    , ("interpret", "fake-apply")
    , ("endpoint", "endpoint")
    ]

tableWhere :: Text -> Maybe [[Text]] -> [[Text]]
tableWhere key table = [row | row <- fromMaybe [] table, take 1 row == [key]]

vocabRows :: FilePath -> IO [Row]
vocabRows suite = do
  table <- readTable (suite </> "vocabulary.tsv")
  let hosts = tableWhere "host" table
      refusedAt os arch = [row | row <- hosts, take 3 row == ["host", os, arch], "refused:NotNaturalArchitecture" `Text.isPrefixOf` (row !! 4)]
  pure
    [ check "vocab.host-grid" (sort hosts == sort hostGrid && not (null hosts)) (Text.pack (show (length hosts, length hostGrid)))
    , check "vocab.detect" (tableWhere "detect" table == detectGrid) "the detections that exist differ from the closed catalogue"
    , check "vocab.labels" (tableWhere "label" table == labelGrid) "the label boundaries drifted"
    , check "vocab.extensions" (tableWhere "extension" table == extensionGrid) "the extension identities drifted"
    , check "vocab.apple-needs-arm64" (length (refusedAt "darwin" "x86_64") == 2 && length (refusedAt "darwin" "amd64") == 2) "an Apple host on amd64 was not refused"
    , check "vocab.windows-needs-amd64" (length (refusedAt "windows" "aarch64") == 2 && length (refusedAt "mingw32" "arm64") == 2) "a Windows host on arm64 was not refused"
    ]

specRows :: FilePath -> IO [Row]
specRows suite = do
  table <- readTable (suite </> "spec.tsv")
  let found = fromMaybe [] table
  pure
    ( [ check ("spec." <> name) (row `elem` found) ("the boundary " <> name <> " answered differently")
      | row@(name : _) <- specGrid
      ]
        <> [check "spec.complete" (length found == length specGrid) (Text.pack (show (length found, length specGrid)))]
    )

-- | The freeze's hashes and refusals, and the independent re-freeze of each artefact.
freezeRows :: FilePath -> IO [Row]
freezeRows suite = do
  table <- readTable (suite </> "freeze.tsv")
  let results = [(name, result) | name : result : _ <- fromMaybe [] table]
      lookupResult name = lookup name results
      hashOf name = case lookupResult name of
        Just result | Just hash <- Text.stripPrefix "frozen:" result -> Just hash
        _ -> Nothing
  baselineText <- readText (suite </> "examples" </> "kind-single-objectstore.dhall")
  oneHash <- independentHash (suite </> "examples") "1\n"
  baselineHash <- maybe (pure Nothing) (independentHash (suite </> "examples")) baselineText
  equivalents <- forM positiveExamples $ \example -> do
    frozen <- readText (suite </> "stages" </> Text.unpack example </> "frozen.dhall")
    source <- readText (suite </> "examples" </> (Text.unpack example <> ".dhall"))
    fromFrozen <- maybe (pure Nothing) (independentHash (suite </> "examples")) frozen
    fromSource <- maybe (pure Nothing) (independentHash (suite </> "examples")) source
    pure (check ("freeze." <> example <> ".equivalent") (fromFrozen /= Nothing && fromFrozen == fromSource) "the frozen artefact does not normalise to the authored example")
  pure $
    [ check "freeze.hash.format" (maybe False wellFormed (hashOf "baseline")) "the baseline hash is not a sha256 code"
    , check "freeze.hash.independent" (baselineHash /= Nothing && baselineHash == hashOf "baseline") "the baseline hash differs from the independently computed one"
    , check "freeze.hash.stable" (hashOf "baseline" /= Nothing && hashOf "baseline" == hashOf "baseline-again" && hashOf "baseline" == hashOf "baseline-file") "freezing the same text twice, or through a file, gave different hashes"
    , check "freeze.hash.twin" (hashOf "local-twin" /= Nothing && hashOf "local-twin" == hashOf "baseline") "the local-import twin does not freeze to the baseline"
    , check "freeze.hash.siblings" (distinct [hashOf "baseline", hashOf "shape-swap", hashOf "replicas-3"]) "the siblings do not freeze to three different hashes"
    , check "freeze.inline-one" (oneHash /= Nothing && oneHash == hashOf "inline-one") "the literal one differs from the independently computed hash"
    , check "freeze.nested" (hashOf "nested" /= Nothing && hashOf "nested" == hashOf "inline-one") "a nested local import does not freeze to the value it names"
    , check "freeze.parent" (hashOf "parent" /= Nothing && hashOf "parent" == hashOf "inline-one") "a parent-directory import does not freeze to the value it names"
    , check "freeze.missing-file" (lookupResult "missing-file" == Just "refused:ResolutionFailure") "a missing file was not a resolution failure"
    , check "freeze.cycle" (lookupResult "cycle" == Just "refused:ResolutionFailure") "a cyclic import was not a resolution failure"
    , check "freeze.fallback-forbidden" (lookupResult "fallback-forbidden" == Just "refused:ForbiddenImport") "an environment fallback behind a local import was not refused"
    ]
      <> [check ("freeze.refusal." <> name) (lookupResult name == Just ("refused:" <> tag)) ("the freeze answered " <> Text.pack (show (lookupResult name))) | (name, tag) <- freezeRefusals]
      <> equivalents
 where
  wellFormed hash = case Text.stripPrefix "sha256:" hash of
    Just digits -> Text.length digits == 64 && Text.all (\c -> isHexDigit c && (c < 'A' || c > 'F')) digits
    Nothing -> False
  distinct hashes = all (/= Nothing) hashes && length (nubTexts [h | Just h <- hashes]) == length hashes
  nubTexts items = case items of
    [] -> []
    item : rest -> item : nubTexts (filter (/= item) rest)

-- | The hash the dhall library gives the normal form of a text, computed in a fixed directory.
independentHash :: FilePath -> Text -> IO (Maybe Text)
independentHash directory text = do
  outcome <- try (withCurrentDirectory directory (Dhall.inputExpr text)) :: IO (Either SomeException (Core.Expr Src Void))
  pure $ case outcome of
    Left _ -> Nothing
    Right expression -> Just (DhallImport.hashExpressionToCode (Core.normalize (Core.denote expression) :: Core.Expr Void Void))

-- | The decoder: its dumps, its round trips, its answers to illegal authored values, and the
-- schema it derives.
decodeRows :: FilePath -> IO [Row]
decodeRows suite = do
  table <- readTable (suite </> "decode.tsv")
  schema <- readText (suite </> "schema.dhall")
  examples <- forM (positiveExamples <> ["product-named-in-app", "shape-in-app"]) $ \example -> do
    source <- readText (suite </> "examples" </> (Text.unpack example <> ".dhall"))
    typed <- maybe (pure Nothing) (typechecksAgainst (suite </> "examples")) source
    pure (example, typed)
  schemaNormal <- maybe (pure Nothing) (normalFormOf (suite </> "examples")) schema
  literalNormal <- normalFormOf (suite </> "examples") schemaLiteral
  let found = fromMaybe [] table
      valueOf key = case [value | key' : value : _ <- found, key' == key] of
        value : _ -> Just value
        [] -> Nothing
      schemaText = fromMaybe "" schema
  pure $
    [ check ("decode.roundtrip." <> example) (valueOf ("roundtrip." <> example) == Just "equal:dump-equal") ("the round trip answered " <> Text.pack (show (valueOf ("roundtrip." <> example)))) | example <- ["kind-single-objectstore", "shape-swap-sibling", "replicas-3-sibling"]]
      <> [check ("decode.raw." <> name) (valueOf ("raw." <> name) == Just tag) ("the decoder answered " <> Text.pack (show (valueOf ("raw." <> name)))) | (name, tag) <- decodeRawGrid]
      <> [ check ("decode.example." <> example) (valueOf ("example." <> example) == Just (exampleAnswer example tag)) ("the decoder answered " <> Text.pack (show (valueOf ("example." <> example)))) | (example, tag) <- exampleDecodeTags]
      <> [ check "decode.schema.equals-literal" (schemaNormal /= Nothing && schemaNormal == literalNormal) "the derived schema is not the contract's schema"
         , check "decode.schema.no-product" (not (any (`Text.isInfixOf` schemaText) ["MinIO", "Url", "Download", "shape"])) "the schema names a product, a download, or a shape in the application"
         , check "decode.schema.names" (all (`Text.isInfixOf` schemaText) ["ObjectStore", "SingleNode", "Distributed", "replicas"]) "the schema omits a name it must carry"
         ]
      <> [check ("decode.typecheck." <> example) (typed == Just True) "the example does not typecheck against the contract's schema" | (example, typed) <- examples, example `elem` positiveExamples]
      <> [check ("decode.typecheck-refused." <> example) (typed == Just False) "an illegal example typechecked against the contract's schema" | (example, typed) <- examples, example `notElem` positiveExamples]
 where
  exampleAnswer example tag
    | example `elem` map fst freezeRefusals = "frozen:refused:" <> tag
    | tag == "ok" = "ok"
    | otherwise = "refused:" <> tag

-- | Does the example typecheck against the contract's schema, resolved beside the examples?
typechecksAgainst :: FilePath -> Text -> IO (Maybe Bool)
typechecksAgainst directory source = do
  outcome <- try (withCurrentDirectory directory (Dhall.inputExpr ("(" <> source <> ") : " <> schemaLiteral))) :: IO (Either SomeException (Core.Expr Src Void))
  pure (Just (either (const False) (const True) outcome))

-- | The normal form of a text, with its source positions removed, for comparison.
normalFormOf :: FilePath -> Text -> IO (Maybe (Core.Expr Void Void))
normalFormOf directory source = do
  outcome <- try (withCurrentDirectory directory (Dhall.inputExpr source)) :: IO (Either SomeException (Core.Expr Src Void))
  pure (either (const Nothing) (Just . Core.normalize . Core.denote) outcome)

-- | The lowering's answers, and what its refusals name.
lowerRows :: FilePath -> IO [Row]
lowerRows suite = do
  table <- readTable (suite </> "lower.tsv")
  let found = fromMaybe [] table
      valueOf key = case [value | key' : value : _ <- found, key' == key] of
        value : _ -> Just value
        [] -> Nothing
  details <- forM [("unbound-need", "cache-" <> sentinel), ("dangling-binding", "ghost"), ("unknown-deployment", "ghost-app")] $ \(example, offender) -> do
    refusal <- readText (suite </> "stages" </> Text.unpack example </> "refusal.tsv")
    pure (check ("lower.refusal-detail." <> example) (maybe False (offender `Text.isInfixOf`) refusal) "the refusal does not name the offending identifier")
  pure ([check ("lower.example." <> example) (valueOf example == Just tag) ("lowering answered " <> Text.pack (show (valueOf example))) | (example, tag) <- exampleLowerTags] <> details)

-- | The pipeline's answer to every refused example: its tag, its stage, a detail, and
-- exactly the artefacts of the stages before the one that refused.
refusalRows :: FilePath -> IO [Row]
refusalRows suite = forM pipelineRefusals $ \(example, (tag, stage)) -> do
  let directory = suite </> "stages" </> Text.unpack example
  record <- readTable (directory </> "refusal.tsv")
  present <- directoryFiles directory
  let wantedFiles = sort (refusalStageFiles stage <> ["refusal.tsv"])
      recordOk = case record of
        Just [[tag', stage', detail]] -> tag' == tag && stage' == stage && not (Text.null detail)
        _ -> False
  pure (check ("pipeline.refusal." <> example) (recordOk && sort present == wantedFiles) (Text.pack (show (record, present))))
 where
  directoryFiles directory = do
    present <- doesDirectoryExist directory
    if present then map Text.pack <$> listDirectory directory else pure []

-- | The endpoint answers each example with the digest of its manifest, recomputed here, or
-- with the tag and stage of its refusal.
endpointRows :: FilePath -> IO [Row]
endpointRows suite = do
  table <- readTable (suite </> "endpoint.tsv")
  let found = fromMaybe [] table
      valueOf key = case [value | key' : value : _ <- found, key' == key] of
        value : _ -> Just value
        [] -> Nothing
  positives <- forM positiveExamples $ \example -> do
    manifest <- readBytes (suite </> "stages" </> Text.unpack example </> "manifest.json")
    pure (check ("endpoint." <> example) (manifest /= Nothing && valueOf example == fmap (\bytes -> "rendered:" <> sha256Hex bytes) manifest) ("the endpoint answered " <> Text.pack (show (valueOf example))))
  pure (positives <> [check ("endpoint." <> example) (valueOf example == Just ("refused:" <> tag <> ":" <> stage)) ("the endpoint answered " <> Text.pack (show (valueOf example))) | (example, (tag, stage)) <- pipelineRefusals])

-- | The differential: each authored leaf, changed alone, must change the artefacts it
-- feeds or be refused at the stage that owns it.
consumeRows :: FilePath -> IO [Row]
consumeRows suite = do
  table <- readTable (suite </> "differential.tsv")
  let found = [(leaf, (refusal, filter (not . Text.null) (Text.splitOn "," changed), envelope)) | [leaf, refusal, changed, envelope] <- fromMaybe [] table]
  pure
    ( [ check ("consume." <> leaf) (verdict leaf (lookup leaf found) expectation) ("the leaf answered " <> Text.pack (show (lookup leaf found)))
      | (leaf, expectation) <- differentialGrid
      ]
        <> [check "consume.complete" (length found == length differentialGrid) (Text.pack (show (length found)))]
    )
 where
  baselineEnvelope = "requests=1,2,4,1;limits=2,4,8,1;headroom=0,0,0,0"
  verdict leaf observed expectation = case (observed, expectation) of
    (Just (refusal, _, _), Left (tag, stage)) -> refusal == tag <> ":" <> stage
    (Just (refusal, changed, envelope), Right required) -> refusal == "-" && all (`elem` changed) required && envelope == fromMaybe baselineEnvelope (lookup leaf differentialEnvelopes)
    _ -> False

-- | The corpus: the files rendered are exactly the contract's inventory, in both directions.
corpusRows :: FilePath -> IO [Row]
corpusRows suite = do
  listed <- readTable (suite </> "corpus.tsv")
  examplesPresent <- doesDirectoryExist (suite </> "examples")
  files <- if examplesPresent then listDirectory (suite </> "examples") else pure []
  schemaPresent <- doesFileExist (suite </> "schema.dhall")
  stagesPresent <- doesDirectoryExist (suite </> "stages")
  stages <- if stagesPresent then listDirectory (suite </> "stages") else pure []
  let onDisk = sort (map (\file -> "examples/" <> Text.pack file) files <> ["schema.dhall" | schemaPresent])
      declared = sort [Text.concat row | row <- fromMaybe [] listed]
  pure
    [ check "corpus.inventory" (onDisk == sort corpusInventory) (Text.pack (show (length onDisk, length corpusInventory)))
    , check "corpus.tsv" (declared == sort corpusInventory) (Text.pack (show (length declared, length corpusInventory)))
    , check "corpus.stages" (sort (map Text.pack stages) == sort (positiveExamples <> refusedExamples)) (Text.pack (show (length stages)))
    ]

chainTableRows :: FilePath -> IO [Row]
chainTableRows suite = do
  table <- readTable (suite </> "chain.tsv")
  pure [check "chain.table" (fromMaybe [] table == chainTable) "the step algebra's table drifted"]

-- | The interpreter's table, and the scenario whose answer names a step.
interpretRows :: FilePath -> IO [Row]
interpretRows suite = do
  table <- readTable (suite </> "interpret.tsv")
  manifest <- readBytes (suite </> "stages" </> "kind-single-objectstore" </> "manifest.json")
  let found = fromMaybe [] table
      payloads = maybe [] splitPayloads manifest
      order = chainOrder (expectedObjects baselineParams)
      thirdLabel = case drop 2 order of
        item : _ -> expectedIdentity item
        [] -> ""
      tableRow row@(key : _) = check (rowName key) (row `elem` found) ("the interpreter answered differently for " <> key)
      tableRow [] = check "fake-apply.empty" False "an empty expectation"
      rowName key = if "dry-run." `Text.isPrefixOf` key then key else "fake-apply." <> key
  scenarios <- forM
    [ ("full", drop 0 payloads)
    , ("from-cutover", drop 4 payloads)
    , ("from-managed", drop 8 payloads)
    , ("hostile-path", drop 8 payloads)
    , ("fail-at-3", take 2 payloads)
    , ("single-step", take 1 payloads)
    , ("from-boundary", [])
    , ("unsupported-kind", [])
    ]
    (\(scenario, expected) -> fakeTranscriptRows ("fake-apply.transcript." <> scenario) (suite </> "fake" </> Text.unpack scenario) expected)
  applied <- fakeTranscriptRows "fake-apply.transcript.apply-full" (suite </> "applied-suite" </> "fake") payloads
  decoyRan <- doesFileExist (suite </> "decoy" </> "ran")
  dryFake <- doesDirectoryExist (suite </> "dry" </> "fake")
  dryDump <- readText (suite </> "dry" </> "dry-run.dump")
  stagesDump <- readText (suite </> "stages" </> "kind-single-objectstore" </> "dry-run.dump")
  pure
    ( map tableRow interpretTable
        <> [ check "fake-apply.fail-at-3.result" (lookup "fail-at-3.result" [(key, value) | key : value : _ <- found] == Just ("ExecutorFailed:" <> thirdLabel <> ":1")) "the scripted failure was not reported at the third step"
           , check "fake-apply.decoy-not-run" (not decoyRan) "a program on the search path ran in place of the executor"
           , check "dry-run.no-fake" (not dryFake) "a dry run created a fake"
           , check "dry-run.same-dump" (dryDump /= Nothing && dryDump == stagesDump) "the dry run's plan differs from the compile's"
           , check "fake-apply.manifest-available" (not (null payloads)) "the baseline manifest is absent"
           ]
        <> concat scenarios
        <> applied
    )

-- | The wire schema: the declarations and the schema rendered from them agree with the
-- contract's messages and field numbers; a changed number or name is a red row.
wireRows :: FilePath -> IO [Row]
wireRows suite = do
  declared <- readTable (suite </> "wire.tsv")
  rendered <- readText (suite </> "proto" </> "PulsarApi.proto")
  let fromDeclared = [(name, [(field, number) | entry <- entries, [field, digits] <- [Text.splitOn ":" entry], Just number <- [digitsOf digits]]) | name : entries <- fromMaybe [] declared]
      text = fromMaybe "" rendered
      fromSchema = messagesOf (Text.lines text)
  pure
    [ check "wire.declarations" (fromDeclared == wireMessages) (Text.pack (show fromDeclared))
    , check "wire.schema" (fromSchema == wireMessages && take 2 (Text.lines text) == ["syntax = \"proto2\";", "package amoebius.pulsar.proto;"]) (Text.pack (show fromSchema))
    ]
 where
  digitsOf digits = case reads (Text.unpack digits) of
    [(number, "")] -> Just number
    _ -> Nothing
  messagesOf rows = case dropWhile (not . Text.isPrefixOf "message ") rows of
    [] -> []
    header : rest ->
      let (body, remaining) = break (== "}") rest
          name = Text.takeWhile (/= ' ') (Text.drop (Text.length "message ") header)
          fields = [(field, number) | row <- body, ["optional", "bytes", field, "=", digits] <- [Text.words (Text.filter (/= ';') row)], Just number <- [digitsOf digits]]
       in (name, fields) : messagesOf (drop 1 remaining)
