{-# LANGUAGE OverloadedStrings #-}

-- | The independent judge of the typed-spine legacy bindings. It reads the observation table
-- the shipped suite wrote, compares every row with a literal typed here, and recounts the
-- shipped tree itself for the source-scan bindings. It imports no product module.
module DslLegacy (legacyRows, legacyKeys) where

import Control.Exception (SomeException, try)
import Control.Monad (forM)
import Data.ByteString qualified as ByteString
import Data.List (intercalate, isSuffixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import DslParse (Row (..), check)
import DslWireSchema (expectedWireSchema)
import DslWireDescriptor (descriptorMatchesLedgerNumber, requestMatchesLedgerNumber, pluginResponseMatchesGenerated)
import System.Directory (doesDirectoryExist, doesPathExist, getCurrentDirectory, listDirectory)
import System.FilePath (splitDirectories, (</>))

-- | The analyzer keys this judge owns.
legacyKeys :: [Text]
legacyKeys = ["dhall-source", "wire-schema", "endpoint-consumption", "typed-root", "spine-handoffs", "semantic-inputs"]

-- | Every (case, role, expected value) of one analyzer, typed from the binding's contract.
expected :: Text -> [(Text, Text, Text)]
expected key = case key of
  "dhall-source" ->
    [ ("tracked-dhall", "positive", "0"), ("tracked-dhall", "negative", "1")
    , ("tracked-dhall-registry", "positive", "0"), ("tracked-dhall-registry", "negative", "1")
    , ("roundtrip-changed", "positive", "equal"), ("roundtrip-changed", "negative", "differ") ]
  "wire-schema" ->
    [ ("tracked-proto", "positive", "0"), ("tracked-proto", "negative", "1")
    , ("field-number-changed", "positive", "True"), ("field-number-changed", "negative", "False")
    , ("vendor-attribution-duplicated", "positive", "True"), ("vendor-attribution-duplicated", "negative", "False") ]
  "endpoint-consumption" ->
    [ ("constant-demand", "positive", "same"), ("constant-demand", "negative", "differ")
    , ("noop-renderer", "positive", "True"), ("noop-renderer", "negative", "differ") ]
  "typed-root" ->
    [ ("two-server-quorum", "positive", "decoded"), ("two-server-quorum", "negative", "frozen:IllTyped")
    , ("empty-needs", "positive", "decoded"), ("empty-needs", "negative", "decoded:EmptyNeeds")
    , ("text-tree-authority", "positive", "equal"), ("text-tree-authority", "negative", "decoded:DhallFailure,decoded:DhallFailure") ]
  "spine-handoffs" ->
    [ (name, role, value) | name <- ["hand-built-stage", "noop-stage", "render-omitted", "executed-argv-diverged"], (role, value) <- [("positive", "True"), ("negative", "False")] ]
  "semantic-inputs" ->
    [ ("markdown-behavior-consumer", "positive", "0"), ("markdown-behavior-consumer", "negative", "1")
    , ("serialized-registry-consumer", "positive", "0"), ("serialized-registry-consumer", "negative", "1") ]
  _ -> []

readText :: FilePath -> IO (Maybe Text)
readText path = do
  attempt <- try (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  pure (either (const Nothing) (either (const Nothing) Just . Encoding.decodeUtf8') attempt)

readBytes :: FilePath -> IO (Maybe ByteString.ByteString)
readBytes path = do
  attempt <- try (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  pure (either (const Nothing) Just attempt)

-- | Check the controlled process stimuli, its observed input, and all written files.
fakePluginChecks :: FilePath -> Maybe ByteString.ByteString -> IO Bool
fakePluginChecks directory expectedRequest = do
  summary <- readText (directory </> "wire-fake-plugin.tsv")
  results <- forM cases $ \(mode, expectedResponse, expectedStatus) -> do
    let root = directory </> "fake-plugin" </> Text.unpack mode
        output = root </> "generated"
    request <- readBytes (root </> "plugin.request")
    response <- readBytes (root </> "plugin.response")
    received <- readBytes (root </> "plugin.stderr")
    exists <- doesDirectoryExist output
    files <- if exists then sort . map (intercalate "/" . splitDirectories) <$> filesUnder output else pure []
    escaped <- doesPathExist (root </> "other.hs")
    apiBody <- readBytes (output </> "Proto/PulsarApi.hs")
    fieldsBody <- readBytes (output </> "Proto/PulsarApi_Fields.hs")
    let clean = mode == "clean"
        expectedFiles = if clean then ["Proto/PulsarApi.hs", "Proto/PulsarApi_Fields.hs"] else []
        bodies = if clean then apiBody == Just "api source\n" && fieldsBody == Just "fields source\n" else apiBody == Nothing && fieldsBody == Nothing
    pure (request == expectedRequest && maybe False (requestMatchesLedgerNumber 1) request
      && response == Just expectedResponse && exists && files == expectedFiles && bodies && not escaped
      && received == request, [mode, expectedStatus, if clean then "[True,True]" else "[False,False]"])
  pure (all fst results && summary == Just (Text.unlines [Text.intercalate "\t" row | (_, row) <- results]))
 where
  api = ByteString.concat [ByteString.pack [122,33,10,18], "Proto/PulsarApi.hs", ByteString.pack [122,11], "api source\n"]
  fields = ByteString.concat [ByteString.pack [122,43,10,25], "Proto/PulsarApi_Fields.hs", ByteString.pack [122,14], "fields source\n"]
  foreignFile = ByteString.concat [ByteString.pack [122,23,10,11], "../other.hs", ByteString.pack [122,8], "foreign\n"]
  insertion = ByteString.concat [ByteString.pack [122,43,10,18], "Proto/PulsarApi.hs", ByteString.pack [18,8], "fragment", ByteString.pack [122,11], "api source\n"]
  emptyFile = ByteString.concat [ByteString.pack [122,22,10,18], "Proto/PulsarApi.hs", ByteString.pack [122,0]]
  cases = [("clean", api <> fields, "success"), ("empty", "", "response-refused"),
    ("truncated", ByteString.pack [122,4,10], "response-refused"),
    ("error", ByteString.pack [10,3] <> "bad" <> api <> fields, "response-refused"),
    ("missing", api, "response-refused"), ("duplicate", api <> api <> fields, "response-refused"),
    ("foreign", api <> foreignFile, "response-refused"), ("insertion", insertion <> fields, "response-refused"),
    ("empty-content", emptyFile <> fields, "response-refused"), ("exit", "", "compiler-failed:1")]

filesUnder :: FilePath -> IO [FilePath]
filesUnder root = do
  names <- listDirectory root
  nested <- forM (sort names) $ \name -> do
    let path = root </> name
    isDirectory <- doesDirectoryExist path
    if name `elem` [".build", ".git", "dist-newstyle", ".data", ".test_data"] then pure []
      else if isDirectory then map (name </>) <$> filesUnder path else pure [name]
  pure (concat nested)

-- | What this judge itself finds in the shipped tree, for the bindings that scan it.
independentChecks :: Text -> FilePath -> IO Bool
independentChecks key directory = do
  files <- getCurrentDirectory >>= filesUnder
  case key of
    "dhall-source" -> pure (null [f | f <- files, ".dhall" `isSuffixOf` f] && not (null files))
    "wire-schema" -> do
      positive <- readText (directory </> "wire-positive.proto")
      changed <- readText (directory </> "wire-number-changed.proto")
      positiveDescriptor <- try (ByteString.readFile (directory </> "wire-positive.desc")) :: IO (Either SomeException ByteString.ByteString)
      changedDescriptor <- try (ByteString.readFile (directory </> "wire-number-changed.desc")) :: IO (Either SomeException ByteString.ByteString)
      positiveRequest <- try (ByteString.readFile (directory </> "wire-positive.request")) :: IO (Either SomeException ByteString.ByteString)
      changedRequest <- try (ByteString.readFile (directory </> "wire-number-changed.request")) :: IO (Either SomeException ByteString.ByteString)
      preparedRequest <- try (ByteString.readFile (".build" </> "proto" </> "current" </> "plugin.request")) :: IO (Either SomeException ByteString.ByteString)
      preparedResponse <- try (ByteString.readFile (".build" </> "proto" </> "current" </> "plugin.response")) :: IO (Either SomeException ByteString.ByteString)
      generated <- traverse (\path -> try (ByteString.readFile (".build" </> "proto" </> "current" </> "generated" </> path)) :: IO (Either SomeException ByteString.ByteString)) ["Proto/PulsarApi.hs", "Proto/PulsarApi_Fields.hs"]
      fakeComplete <- fakePluginChecks directory (either (const Nothing) Just positiveRequest)
      attribution <- readText (directory </> "wire-attribution.tsv")
      let twin = directory </> "ownership-source"
      twinExists <- doesDirectoryExist twin
      twinFiles <- if twinExists then map (intercalate "/" . splitDirectories) <$> filesUnder twin else pure []
      twinBodies <- mapM (readText . (twin </>)) twinFiles
      let expectedOwners =
            [ "proto/PulsarApi.proto\twire-schema"
            , "src/vendor/PulsarApi.proto\tvendor-source"
            , "vendor/supernova/PulsarApi.proto\tvendor-source"
            ]
          expectedAttribution = Text.unlines
            (map ("positive\t" <>) expectedOwners <> map ("negative\t" <>) expectedOwners
              <> ["negative\tvendor/supernova/PulsarApi.proto\twire-schema"])
      pure (null [f | f <- files, ".proto" `isSuffixOf` f] && not (null files)
        && positive == Just expectedWireSchema
        && changed == Just (Text.replace "ledgerId = 1;" "ledgerId = 99;" expectedWireSchema)
        && either (const False) (descriptorMatchesLedgerNumber 1) positiveDescriptor
        && either (const False) (descriptorMatchesLedgerNumber 99) changedDescriptor
        && (case (positiveDescriptor, changedDescriptor) of (Right original, Right twin) -> original /= twin; _ -> False)
        && either (const False) (requestMatchesLedgerNumber 1) positiveRequest
        && either (const False) (requestMatchesLedgerNumber 99) changedRequest
        && (case (positiveRequest, changedRequest) of (Right original, Right twin) -> original /= twin; _ -> False)
        && either (const False) (requestMatchesLedgerNumber 1) preparedRequest
        && (case (positiveRequest, preparedRequest) of (Right original, Right actual) -> original == actual; _ -> False)
        && (case (preparedResponse, sequence generated) of (Right response, Right [api, fields']) -> pluginResponseMatchesGenerated response [("Proto/PulsarApi.hs", api), ("Proto/PulsarApi_Fields.hs", fields')]; _ -> False)
        && fakeComplete
        && attribution == Just expectedAttribution
        && sort twinFiles == ["proto/PulsarApi.proto", "src/vendor/PulsarApi.proto", "vendor/supernova/PulsarApi.proto"]
        && all (== Just "planted\n") twinBodies
        && changed /= positive)
    "semantic-inputs" -> do
      here <- getCurrentDirectory
      let allowed f = any (`Text.isPrefixOf` Text.pack f) ["src/doc-check/", "src/validation-kernel/", "src/Amoebius/Layout/"]
          shipped = [f | f <- files, ".hs" `isSuffixOf` f, any (`Text.isPrefixOf` Text.pack f) ["src/", "app/"], not (allowed f)]
      bodies <- mapM (\f -> maybe "" id <$> readText (here </> f)) shipped
      let reads body = any (`Text.isInfixOf` body) ["readFile"]
          markdown body = reads body && any (`Text.isInfixOf` body) [".md\"", "markdown\""]
          registry body = reads body && any (`Text.isInfixOf` body) ["registry.json", "registry.tsv", "registry.yaml"]
      pure (not (null shipped) && not (any markdown bodies) && not (any registry bodies))
    _ -> pure True

-- | The ledger rows for one analyzer and one suite directory.
legacyRows :: Text -> FilePath -> IO [Row]
legacyRows key directory = do
  table <- readText (directory </> Text.unpack key <> ".tsv")
  independent <- independentChecks key directory
  let rows = maybe [] (map (Text.splitOn "\t") . Text.lines) table
      wanted = expected key
      observed name role = [value | [n, r, value] <- rows, n == name, r == role]
      inventory = sort [(name, role) | (name, role, _) <- wanted]
      reported = sort [(name, role) | [name, role, _] <- rows, name /= "control"]
      stem = key <> "."
  pure $
    check (stem <> "discovery") (not (null wanted) && inventory == reported && all ((== 3) . length) rows) "the closed case inventory"
      : [ check (stem <> name <> "." <> role) (observed name role == [value]) (Text.pack (show (observed name role))) | (name, role, value) <- wanted ]
      <> [ check (stem <> "control.complete") (observed "control" "inventory" == ["True"] && independent) "the subject observed a nonempty inventory and the judge's own scan agrees" ]
