{-# LANGUAGE OverloadedStrings #-}

-- | Observations behind the typed-spine legacy bindings other than @decoded-lowering@. Each
-- analyzer writes @<analyzer>.tsv@ of @key, role, value@ rows describing what the shipped
-- stages did; the independent oracle owns every expected value. Positive rows observe the
-- shipped tree or stage; negative rows observe a planted or perturbed twin of it.
module SpineLegacy (fakeWirePlugin, legacySection) where

import Amoebius.Dsl.Decode (decodeFrozen, decodeRefusalTag, decodeRoot)
import Amoebius.Dsl.Encode (encodeRoot)
import Amoebius.Dsl.Examples.Capacity (Example (..), corpus, renderExampleFiles)
import Amoebius.Dsl.Examples.Substrates qualified as Substrates
import Amoebius.Dsl.Examples.Spine (baselineRoot, sentinel, variant)
import Amoebius.Dsl.Import (freezeText, importRefusalTag)
import Amoebius.Dsl.Pipeline (EndpointOutcome (..), compileText, compiledFiles, compiledManifest, compiledSteps, endpointOutcome)
import Amoebius.Dsl.Examples.Spine qualified as Spine
import Amoebius.Kernel.Step (stepLabel)
import Amoebius.Capability.Types (ServiceShape (..))
import Amoebius.Pulsar.Wire (ProtocolField (..), ProtocolMessage (..), protocolDeclarations, renderProtocol, renderProtocolFrom)
import Amoebius.Pulsar.Wire.Descriptor (protocolDescriptorSetFrom, protocolPluginRequestFrom)
import Amoebius.Pulsar.Wire.Generate (WireGenerationError (..), generateWireBindingsFromPlugin)
import Amoebius.Toolchain.SourceOwnership (ProtoSourceOwner (..), protoSourceAttribution, protoSourceExamples)
import Control.Exception (SomeException, bracket, try)
import Control.Monad (forM, forM_, unless)
import Data.Bits ((.&.), (.|.), shiftR)
import Data.ByteString qualified as ByteString
import Data.List (intercalate, isPrefixOf, isSuffixOf, nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, getCurrentDirectory, listDirectory, removePathForcibly)
import System.Environment (getExecutablePath, lookupEnv, setEnv, unsetEnv)
import System.Exit (exitFailure)
import System.FilePath (splitDirectories, takeDirectory, (</>))
import System.IO (hSetBinaryMode, stdin, stdout, stderr)

-- | Dispatch one analyzer; an unknown key writes nothing, so the oracle's discovery row is red.
legacySection :: Text -> FilePath -> IO ()
legacySection analyzer suite = case analyzer of
  "dhall-source" -> dhallSource suite
  "wire-schema" -> wireSchema suite
  "endpoint-consumption" -> endpointConsumption suite
  "typed-root" -> typedRoot suite
  "spine-handoffs" -> spineHandoffs suite
  "semantic-inputs" -> semanticInputs suite
  _ -> pure ()

tabs :: [Text] -> Text
tabs = Text.intercalate "\t"

boolean :: Bool -> Text
boolean = Text.pack . show

writeRows :: FilePath -> FilePath -> [[Text]] -> IO ()
writeRows suite name rows = do
  createDirectoryIfMissing True (takeDirectory (suite </> name))
  ByteString.writeFile (suite </> name) (Encoding.encodeUtf8 (Text.unlines (map tabs rows)))

-- | Every file beneath a directory, skipping state roots.
filesUnder :: FilePath -> IO [FilePath]
filesUnder root = do
  names <- listDirectory root
  nested <- forM (sort names) $ \name -> do
    let path = root </> name
    directory <- doesDirectoryExist path
    if name `elem` [".build", ".git", "dist-newstyle", ".data", ".test_data"] then pure []
      else if directory then map (name </>) <$> filesUnder path else pure [name]
  pure (concat nested)

-- | The planted twin of a tree: one file the rule forbids, in a fresh directory.
planted :: FilePath -> FilePath -> IO [FilePath]
planted suite file = do
  let root = suite </> "planted"
  removePathForcibly root
  createDirectoryIfMissing True (takeDirectory (root </> file))
  ByteString.writeFile (root </> file) "planted\n"
  files <- filesUnder root
  removePathForcibly root
  pure files

hasDhall, hasRegistry :: FilePath -> Bool
hasDhall path = ".dhall" `isSuffixOf` path
hasRegistry path = "registry" `Text.isInfixOf` Text.toLower (Text.pack path) && ("dhall" `Text.isInfixOf` Text.toLower (Text.pack path))

-- | LTD-SRC-002: no Dhall is tracked, and a typed root survives encode, freeze, decode.
dhallSource :: FilePath -> IO ()
dhallSource suite = do
  here <- getCurrentDirectory >>= filesUnder
  twinDhall <- planted suite "examples/baseline.dhall"
  twinRegistry <- planted suite "dhall-registry/index.txt"
  createDirectoryIfMissing True (suite </> "examples")
  equal <- roundTrip suite baselineRoot
  changed <- roundTripText suite baselineRoot (Text.replace sentinel "5eed5eed5eed5eed5eed5eed5eed5eed")
  writeRows suite "dhall-source.tsv"
    [ ["tracked-dhall", "positive", Text.pack (show (length (filter hasDhall here)))]
    , ["tracked-dhall", "negative", Text.pack (show (length (filter hasDhall twinDhall)))]
    , ["tracked-dhall-registry", "positive", Text.pack (show (length (filter hasRegistry here)))]
    , ["tracked-dhall-registry", "negative", Text.pack (show (length (filter hasRegistry twinRegistry)))]
    , ["roundtrip-changed", "positive", equal]
    , ["roundtrip-changed", "negative", changed]
    , ["control", "inventory", boolean (not (null here))]
    ]

roundTrip :: FilePath -> Either e a -> IO Text
roundTrip _ (Left _) = pure "unbuilt"
roundTrip suite built = roundTripText suite built id

-- | Encode a typed root, optionally rewrite its text, freeze and decode it, and compare with the original.
roundTripText :: FilePath -> Either e a -> (Text -> Text) -> IO Text
roundTripText _ (Left _) _ = pure "unbuilt"
roundTripText suite (Right _) rewrite = do
  let original = either (const Nothing) Just baselineRoot
  case original of
    Nothing -> pure "unbuilt"
    Just value -> do
      frozen <- freezeText (suite </> "examples") (rewrite (encodeRoot value))
      pure $ case frozen of
        Left refusal -> "frozen:" <> importRefusalTag refusal
        Right ready -> case decodeRoot ready of
          Left refusal -> "decoded:" <> decodeRefusalTag refusal
          Right decoded -> if decoded == value then "equal" else "differ"

-- | LTD-SRC-003: no Proto is tracked, field numbers are stable, and the
-- vendor and wire source migrations partition the observed Proto paths.
wireSchema :: FilePath -> IO ()
wireSchema suite = do
  here <- getCurrentDirectory >>= filesUnder
  twin <- planted suite "proto/Vendor.proto"
  createDirectoryIfMissing True suite
  let targets = [protocolFieldNumber field | message <- protocolDeclarations, protocolMessageName message == "MessageIdData", field <- protocolMessageFields message, protocolFieldName field == "ledgerId"]
      changeMessage message | protocolMessageName message == "MessageIdData" = message {protocolMessageFields = map changeField (protocolMessageFields message)}
                            | otherwise = message
      changeField field | protocolFieldName field == "ledgerId" = field {protocolFieldNumber = 99}
                        | otherwise = field
      changedDeclarations = map changeMessage protocolDeclarations
      changedProtocol = renderProtocolFrom changedDeclarations
  ByteString.writeFile (suite </> "wire-positive.proto") (Encoding.encodeUtf8 renderProtocol)
  ByteString.writeFile (suite </> "wire-number-changed.proto") (Encoding.encodeUtf8 changedProtocol)
  either (fail . Text.unpack) (ByteString.writeFile (suite </> "wire-positive.desc")) (protocolDescriptorSetFrom protocolDeclarations)
  either (fail . Text.unpack) (ByteString.writeFile (suite </> "wire-number-changed.desc")) (protocolDescriptorSetFrom changedDeclarations)
  either (fail . Text.unpack) (ByteString.writeFile (suite </> "wire-positive.request")) (protocolPluginRequestFrom protocolDeclarations)
  either (fail . Text.unpack) (ByteString.writeFile (suite </> "wire-number-changed.request")) (protocolPluginRequestFrom changedDeclarations)
  fakeWireCases suite
  let sourceTwin = suite </> "ownership-source"
  removePathForcibly sourceTwin
  forM_ protoSourceExamples $ \path -> do
    createDirectoryIfMissing True (takeDirectory (sourceTwin </> path))
    ByteString.writeFile (sourceTwin </> path) "planted\n"
  discoveredTwin <- map (intercalate "/" . splitDirectories) <$> filesUnder sourceTwin
  let numbersOf text = [Text.takeWhile (`elem` ['0'..'9']) digits | line <- Text.lines text, label : _type : _name : "=" : digits : _ <- [Text.words line], label `elem` ["optional", "required", "repeated"]]
      declared = [Text.pack (show (protocolFieldNumber field)) | message <- protocolDeclarations, field <- protocolMessageFields message]
      rendered = numbersOf renderProtocol
      perturbed = numbersOf changedProtocol
      paths = sort (nub (filter (".proto" `isSuffixOf`) here <> discoveredTwin))
      attribution = protoSourceAttribution paths
      duplicated = attribution <> [(path, WireSchemaSource) | path <- discoveredTwin, "vendor/" `isPrefixOf` path]
      complete rows = sort (map fst rows) == paths
      ownerLabel owner = case owner of WireSchemaSource -> "wire-schema"; VendorSchemaSource -> "vendor-source"
  writeRows suite "wire-attribution.tsv"
    [[role, Text.pack path, ownerLabel owner] | (role, rows) <- [("positive", attribution), ("negative", duplicated)], (path, owner) <- rows]
  writeRows suite "wire-schema.tsv"
    [ ["tracked-proto", "positive", Text.pack (show (length (filter (".proto" `isSuffixOf`) here)))]
    , ["tracked-proto", "negative", Text.pack (show (length (filter (".proto" `isSuffixOf`) twin)))]
    , ["field-number-changed", "positive", boolean (rendered == declared)]
    , ["field-number-changed", "negative", boolean (perturbed == declared)]
    , ["vendor-attribution-duplicated", "positive", boolean (complete attribution)]
    , ["vendor-attribution-duplicated", "negative", boolean (complete duplicated)]
    , ["control", "inventory", boolean (not (null here) && not (null declared) && targets == [1] && changedProtocol /= renderProtocol)]
    ]

-- | Exercise the shipped generator against controlled plugin process responses.
fakeWireCases :: FilePath -> IO ()
fakeWireCases suite = bracket (lookupEnv variable) restore $ \_ -> do
  executable <- getExecutablePath
  rows <- forM modes $ \mode -> do
    setEnv variable mode
    let root = suite </> "fake-plugin" </> mode
    result <- generateWireBindingsFromPlugin executable root
    present <- mapM (doesFileExist . (root </>) . ("generated" </>)) ["Proto/PulsarApi.hs", "Proto/PulsarApi_Fields.hs"]
    let status = case result of
          Right _ -> "success"
          Left (WireCompilerFailed code _) -> "compiler-failed:" <> Text.pack (show code)
          Left (WirePluginResponse _) -> "response-refused"
          Left problem -> "other:" <> Text.pack (show problem)
    pure [Text.pack mode, status, Text.pack (show present)]
  writeRows suite "wire-fake-plugin.tsv" rows
 where
  variable = "AMOEBIUS_SPINE_WIRE_PLUGIN"
  modes = ["clean", "empty", "truncated", "error", "missing", "duplicate", "foreign", "insertion", "empty-content", "exit"]
  restore Nothing = unsetEnv variable
  restore (Just value) = setEnv variable value

-- | A subprocess boundary, with fixed responses owned by the suite fixture.
fakeWirePlugin :: String -> IO ()
fakeWirePlugin mode = do
  mapM_ (`hSetBinaryMode` True) [stdin, stdout, stderr]
  request <- ByteString.hGetContents stdin
  unless (not (ByteString.null request)) exitFailure
  ByteString.hPut stderr request
  let api = file "Proto/PulsarApi.hs" "api source\n" Nothing
      fields = file "Proto/PulsarApi_Fields.hs" "fields source\n" Nothing
      response = case mode of
        "clean" -> api <> fields
        "empty" -> ByteString.empty
        "truncated" -> ByteString.pack [0x7a, 0x04, 0x0a]
        "error" -> blob 1 "bad" <> api <> fields
        "missing" -> api
        "duplicate" -> api <> api <> fields
        "foreign" -> api <> file "../other.hs" "foreign\n" Nothing
        "insertion" -> file "Proto/PulsarApi.hs" "api source\n" (Just "fragment") <> fields
        "empty-content" -> file "Proto/PulsarApi.hs" "" Nothing <> fields
        _ -> ByteString.empty
  if mode == "exit" then exitFailure else ByteString.hPut stdout response
 where
  file :: ByteString.ByteString -> ByteString.ByteString -> Maybe ByteString.ByteString -> ByteString.ByteString
  file path content insertion = blob 15 (blob 1 path <> maybe ByteString.empty (blob 2) insertion <> blob 15 content)
  blob :: Int -> ByteString.ByteString -> ByteString.ByteString
  blob field content = varint (field * 8 + 2) <> varint (ByteString.length content) <> content
  varint :: Int -> ByteString.ByteString
  varint number | number < 128 = ByteString.singleton (fromIntegral number)
                | otherwise = ByteString.cons (fromIntegral (number .&. 127) .|. 128) (varint (number `shiftR` 7))

-- | LTD-DSL-009: the endpoint's answer is a function of what was authored.
endpointConsumption :: FilePath -> IO ()
endpointConsumption suite = do
  mapM_ (\(path, contents) -> do
    createDirectoryIfMissing True (takeDirectory (suite </> path))
    ByteString.writeFile (suite </> path) (Encoding.encodeUtf8 contents)) renderExampleFiles
  let examples = suite </> "examples"
      authored name = case [exampleText example | example <- corpus, exampleName example == name] of
        text : _ -> text
        [] -> ""
      digest name = endpointOutcome examples (authored name)
      describe outcome = case outcome of
        EndpointRendered value -> value
        EndpointRefused tag stage -> "refused:" <> tag <> ":" <> stage
  baseline <- digest "kind-single-objectstore"
  again <- digest "kind-single-objectstore"
  replicas <- digest "replicas-3-sibling"
  shape <- digest "shape-swap-sibling"
  let rendered outcome = case outcome of EndpointRendered _ -> True; _ -> False
      same left right = if rendered left && describe left == describe right then "same" else "differ"
  writeRows suite "endpoint-consumption.tsv"
    [ ["constant-demand", "positive", same baseline again]
    , ["constant-demand", "negative", same baseline replicas]
    , ["noop-renderer", "positive", boolean (rendered baseline)]
    , ["noop-renderer", "negative", same baseline shape]
    , ["control", "inventory", boolean (all rendered [baseline, again, replicas, shape])]
    ]

-- | LTD-DSL-002: the typed root is the authority; an illegal root is refused as a value.
typedRoot :: FilePath -> IO ()
typedRoot suite = do
  mapM_ (\(path, contents) -> do
    createDirectoryIfMissing True (takeDirectory (suite </> path))
    ByteString.writeFile (suite </> path) (Encoding.encodeUtf8 contents)) renderExampleFiles
  let outcomeOf name = do
        decoded <- decodeFrozen (suite </> "examples" </> (Text.unpack name <> ".dhall"))
        pure $ case decoded of
          Left (Left refusal) -> "frozen:" <> importRefusalTag refusal
          Left (Right refusal) -> "decoded:" <> decodeRefusalTag refusal
          Right _ -> "decoded"
  baseline <- outcomeOf "kind-single-objectstore"
  empty <- outcomeOf "empty-needs"
  product <- outcomeOf "product-named-in-app"
  shape <- outcomeOf "shape-in-app"
  typed <- roundTripText suite baselineRoot id
  let rke2 = Text.unlines [exampleText e | e <- Substrates.corpus, exampleName e == "rke2-three-agent"]
      twoServers = Text.unlines [line | line <- Text.lines rke2, not ("server3 = " `Text.isInfixOf` line)]
      outcomeText text = do
        frozen <- freezeText (suite </> "examples") text
        pure $ case frozen of
          Left refusal -> "frozen:" <> importRefusalTag refusal
          Right ready -> either (("decoded:" <>) . decodeRefusalTag) (const "decoded") (decodeRoot ready)
  threeServers <- outcomeText rke2
  twoServerOutcome <- outcomeText twoServers
  writeRows suite "typed-root.tsv"
    [ ["two-server-quorum", "positive", threeServers]
    , ["two-server-quorum", "negative", twoServerOutcome]
    , ["empty-needs", "positive", baseline]
    , ["empty-needs", "negative", empty]
    , ["text-tree-authority", "positive", typed]
    , ["text-tree-authority", "negative", product <> "," <> shape]
    , ["control", "inventory", boolean (baseline == "decoded")]
    ]
 where
  _unused = (try :: IO () -> IO (Either SomeException ()), variant, Distributed, SingleNode)

-- | LTD-VAL-005: every stage consumes what the stage before it produced.
spineHandoffs :: FilePath -> IO ()
spineHandoffs suite = do
  mapM_ (\(path, contents) -> do
    createDirectoryIfMissing True (takeDirectory (suite </> path))
    ByteString.writeFile (suite </> path) (Encoding.encodeUtf8 contents)) renderExampleFiles
  let examples = suite </> "examples"
      authored name = case [exampleText example | example <- corpus, exampleName example == name] of
        text : _ -> text
        [] -> ""
      nonce = "5eed5eed5eed5eed5eed5eed5eed5eed"
      stageFiles = ["decoded.dump", "lowered.dump", "plan.dump", "provisioned.dump", "manifest.json", "chain.dump", "dry-run.dump"]
      text bytes = either (const "") id (Encoding.decodeUtf8' bytes)
      artefact compiled name = maybe "" text (lookup name (compiledFiles compiled))
      present compiled name = maybe False (not . ByteString.null) (lookup name (compiledFiles compiled))
  perturbed <- compileText examples (Text.replace Spine.sentinel nonce (authored "kind-single-objectstore"))
  plain <- compileText examples (authored "kind-single-objectstore")
  refused <- compileText examples (authored "unbound-need")
  let carries compiled = all (\name -> nonce `Text.isInfixOf` artefact compiled name) ["decoded.dump", "lowered.dump", "manifest.json"]
      labels = map stepLabel (compiledSteps perturbed)
      listed name = all (`Text.isInfixOf` artefact perturbed name) labels
  writeRows suite "spine-handoffs.tsv"
    [ ["hand-built-stage", "positive", boolean (carries perturbed)]
    , ["hand-built-stage", "negative", boolean (carries plain)]
    , ["noop-stage", "positive", boolean (all (present perturbed) stageFiles)]
    , ["noop-stage", "negative", boolean (all (present refused) stageFiles)]
    , ["render-omitted", "positive", boolean (not (ByteString.null (compiledManifest perturbed)) && present perturbed "manifest.json")]
    , ["render-omitted", "negative", boolean (not (ByteString.null (compiledManifest refused)))]
    , ["executed-argv-diverged", "positive", boolean (not (null labels) && listed "chain.dump" && listed "dry-run.dump")]
    , ["executed-argv-diverged", "negative", boolean ("ghost-step" `Text.isInfixOf` artefact perturbed "chain.dump")]
    , ["control", "inventory", boolean (not (null labels))]
    ]

-- | LTD-DOC-001: no shipped source reads Markdown or a serialized registry as behaviour. The
-- scan is over the source copy this process runs in; its twins are planted text.
semanticInputs :: FilePath -> IO ()
semanticInputs suite = do
  here <- getCurrentDirectory
  files <- filesUnder here
  let structural path = any (`Text.isPrefixOf` Text.pack path) ["src/doc-check/", "src/validation-kernel/", "src/Amoebius/Layout/"]
      sources = [path | path <- files, ".hs" `isSuffixOf` path, any (`Text.isPrefixOf` Text.pack path) ["src/", "app/"], not (structural path)]
  bodies <- forM sources $ \path -> do
    attempt <- try (ByteString.readFile (here </> path)) :: IO (Either SomeException ByteString.ByteString)
    pure (either (const "") (either (const "") id . Encoding.decodeUtf8') attempt)
  let markdownReader body = any (`Text.isInfixOf` body) [".md\"", ".md\\\"", "markdown\""] && any (`Text.isInfixOf` body) ["readFile", "ByteString.readFile", "TextIO.readFile"]
      registryReader body = any (`Text.isInfixOf` body) ["registry.json", "registry.tsv", "registry.yaml"] && any (`Text.isInfixOf` body) ["readFile", "decodeFileStrict"]
      count predicate items = length (filter predicate items)
      twinMarkdown = "module Twin where\nmain = readFile \"phase.md\" >>= putStr\n"
      twinRegistry = "module Twin where\nmain = readFile \"registry.json\" >>= putStr\n"
  writeRows suite "semantic-inputs.tsv"
    [ ["markdown-behavior-consumer", "positive", Text.pack (show (count markdownReader bodies))]
    , ["markdown-behavior-consumer", "negative", Text.pack (show (count markdownReader [twinMarkdown]))]
    , ["serialized-registry-consumer", "positive", Text.pack (show (count registryReader bodies))]
    , ["serialized-registry-consumer", "negative", Text.pack (show (count registryReader [twinRegistry]))]
    , ["control", "inventory", boolean (not (null sources))]
    ]
