{-# LANGUAGE OverloadedStrings #-}

-- | Exercise the product generator across a separate process boundary, including
-- incomplete output and refusal to reuse a previous generation directory.
module Main (main) where

import Amoebius.Pulsar.Wire (renderProtocol)
import Amoebius.Pulsar.Wire.Descriptor (protocolDescriptorSet, protocolPluginRequest)
import Amoebius.Pulsar.Wire.Generate
import Amoebius.Pulsar.Wire.Plugin (decodePluginResponse)
import Amoebius.Internal.Process.FileInput (tryRunFileInput)
import Control.Exception (bracket)
import Control.Monad (forM_, unless, when)
import Data.Bits ((.&.), (.|.), shiftR)
import Data.ByteString qualified as ByteString
import Data.List (isInfixOf, isPrefixOf, isSuffixOf)
import Data.Text qualified as T
import Data.Text.IO qualified as Text
import System.Directory (createDirectory, createDirectoryIfMissing, doesFileExist, getTemporaryDirectory, makeAbsolute, removeFile, removePathForcibly)
import System.Environment (getArgs, getExecutablePath, lookupEnv, setEnv, unsetEnv)
import System.Exit (exitFailure)
import System.FilePath (takeDirectory, (</>))
import System.IO (hClose, hSetBinaryMode, openTempFile, stdin, stdout, stderr)

main :: IO ()
main = do
  args <- getArgs
  fakePluginMode <- lookupEnv "AMOEBIUS_TEST_WIRE_PLUGIN"
  case (fakePluginMode, args) of
    (Just mode, []) -> fakePlugin mode
    _ -> dispatch args

dispatch :: [String] -> IO ()
dispatch args = case args of
    ["--schema", output] -> Text.writeFile output renderProtocol
    ["--descriptor", output] -> either (fail . T.unpack) (ByteString.writeFile output) protocolDescriptorSet
    ["--plugin-request", output] -> either (fail . T.unpack) (ByteString.writeFile output) protocolPluginRequest
    ["--plugin-response", input, output] -> do
      raw <- ByteString.readFile input
      files <- either (fail . T.unpack) pure (decodePluginResponse raw)
      forM_ files $ \(path, body) -> do
        createDirectoryIfMissing True (takeDirectory (output </> path))
        ByteString.writeFile (output </> path) body
    _ | any ("--plugin=protoc-gen-haskell=" `isPrefixOf`) args -> fakeCompiler args
      | otherwise -> checks

checks :: IO ()
checks = bracket temporary removePathForcibly $ \root -> do
  require (case decodePluginResponse ByteString.empty of Left _ -> True; Right _ -> False) "empty plugin response refusal"
  require (case decodePluginResponse (ByteString.pack [0x7a, 0x04, 0x0a]) of Left _ -> True; Right _ -> False) "truncated plugin response refusal"
  require (case decodePluginResponse (ByteString.pack [0x0a, 0x03, 0x62, 0x61, 0x64]) of Left _ -> True; Right _ -> False) "plugin error refusal"
  executable <- getExecutablePath
  let input = root </> "stream-input"; output = root </> "stream-output"; errors = root </> "stream-errors"
  ByteString.writeFile input "preserved"
  ByteString.writeFile output "output-preserved"
  collisions <- sequence [tryRunFileInput root executable [] Nothing input input errors, tryRunFileInput root executable [] Nothing input output input, tryRunFileInput root executable [] Nothing input output output]
  content <- ByteString.readFile input
  outputContent <- ByteString.readFile output
  require (all (either (const True) (const False)) collisions && content == "preserved" && outputContent == "output-preserved") "colliding stream paths refused before opening output"
  generated <- generateWireBindings executable "good" (root </> "good")
  case generated of
    Right result -> do
      schema <- Text.readFile (wireSchemaPath result)
      files <- mapM doesFileExist (wireGeneratedFiles result)
      require (schema == renderProtocol && files == [True, True]) "fresh generation"
      let forkSource = root </> "repository" </> "src" </> "vendor" </> "Pulsar" </> "Protocol"
          forkModules = ["Pulsar.Protocol.Commands", "Pulsar.Protocol.Encoder"]
      createDirectoryIfMissing True forkSource
      writeFile (forkSource </> "Commands.hs") "module Pulsar.Protocol.Commands where\n"
      writeFile (forkSource </> "Encoder.hs") "module Pulsar.Protocol.Encoder where\n"
      invalid <- materializeForkProject (root </> "repository") "0.0.3\nexecutable injected" forkModules result
      require (case invalid of Left (WireGenerationIO detail) -> "invalid fork identity" `isInfixOf` detail; _ -> False) "invalid project metadata refusal"
      duplicate <- materializeForkProject (root </> "repository") "0.0.3" (forkModules <> forkModules) result
      require (case duplicate of Left (WireGenerationIO detail) -> "invalid fork identity" `isInfixOf` detail; _ -> False) "duplicate module refusal"
      missingObserverModule <- materializeForkProject (root </> "repository") "0.0.3" ["Pulsar.Protocol.Commands"] result
      require (case missingObserverModule of Left (WireGenerationIO detail) -> "invalid fork identity" `isInfixOf` detail; _ -> False) "observer dependency refusal"
      project <- materializeForkProject (root </> "repository") "0.0.3" forkModules result
      case project of
        Left problem -> fail (show problem)
        Right path -> do
          source <- readFile (path </> "src" </> "Pulsar" </> "Protocol" </> "Commands.hs")
          metadata <- Text.readFile (path </> "supernova.cabal")
          copied <- mapM doesFileExist [path </> "generated" </> "Proto" </> "PulsarApi.hs", path </> "generated" </> "Proto" </> "PulsarApi_Fields.hs", path </> "wire-observer" </> "Main.hs", path </> "wire-observer" </> "fork-wire-observer.cabal"]
          require (source == "module Pulsar.Protocol.Commands where\n" && "exposed-modules: Pulsar.Protocol.Commands, Pulsar.Protocol.Encoder" `T.isInfixOf` metadata && all id copied) "fork project source, bindings, and observer"
      repeatedProject <- materializeForkProject (root </> "repository") "0.0.3" forkModules result
      require (case repeatedProject of Left (WireGenerationIO _) -> True; _ -> False) "existing fork project refusal"
      let repository = root </> "repository"
      writeFile (repository </> "amoebius.cabal") "authored metadata\n"
      createDirectoryIfMissing True (repository </> "src" </> "Amoebius" </> "Pulsar")
      createDirectoryIfMissing True (repository </> "src" </> "vocabulary")
      writeFile (repository </> "src" </> "Amoebius" </> "Pulsar" </> "Client.hs") "native client\n"
      writeFile (repository </> "src" </> "vocabulary" </> "Vocabulary.hs") "vocabulary\n"
      native <- materializeNativeProject repository result
      case native of
        Left problem -> fail (show problem)
        Right path -> do
          contents <- readFile (path </> "amoebius.cabal")
          copied <- mapM doesFileExist [path </> "src" </> "Proto" </> "PulsarApi.hs", path </> "src" </> "Proto" </> "PulsarApi_Fields.hs", path </> "src" </> "Amoebius" </> "Pulsar" </> "Client.hs", path </> "src" </> "vocabulary" </> "Vocabulary.hs", path </> "wire-observer" </> "Main.hs", path </> "wire-observer" </> "native-wire-observer.cabal"]
          require (contents == "authored metadata\n" && all id copied) "native project source, bindings, and observer"
      repeatedNative <- materializeNativeProject repository result
      require (case repeatedNative of Left (WireGenerationIO _) -> True; _ -> False) "existing native project refusal"
    Left problem -> fail (show problem)
  repeated <- generateWireBindings executable "good" (root </> "good")
  require (case repeated of Left (WireGenerationIO _) -> True; _ -> False) "existing directory refusal"
  omitted <- generateWireBindings executable "omit" (root </> "omit")
  require (case omitted of Left (WireOutputsMissing [_]) -> True; _ -> False) "missing generated file refusal"
  failed <- generateWireBindings executable "fail" (root </> "fail")
  require (case failed of Left (WireCompilerFailed _ _) -> True; _ -> False) "failed compiler refusal"
  absent <- generateWireBindings (root </> "nonexistent") "good" (root </> "absent")
  require (case absent of Left (WireGenerationIO _) -> True; _ -> False) "absent compiler refusal"
  pluginBoundary executable root
  splitBoundary root
 where
  temporary = do
    parent <- getTemporaryDirectory
    (path, handle) <- openTempFile parent "amoebius-wire-"
    hClose handle
    removeFile path
    createDirectory path
    pure path
  require condition label = unless condition (fail label)

-- The split path uses the same request and response handling as direct generation.
splitBoundary :: FilePath -> IO ()
splitBoundary root = do
  let owner = root </> "split"
      obstructed = root </> "split-obstructed"
  (schema, request) <- beginWireBindings owner >>= either (fail . show) pure
  expectedSchema <- makeAbsolute (owner </> "PulsarApi.proto")
  expected <- either (fail . T.unpack) pure protocolPluginRequest
  actual <- ByteString.readFile request
  unless (schema == expectedSchema && actual == expected) (fail "split request differs")
  response <- ByteString.readFile (root </> "plugin-clean" </> "plugin.response")
  ByteString.writeFile (owner </> "plugin.response") response
  generated <- finishWireBindings owner >>= either (fail . show) pure
  bodies <- mapM ByteString.readFile (wireGeneratedFiles generated)
  unless (bodies == ["api source\n", "fields source\n"]) (fail "split response differs")
  repeated <- finishWireBindings owner
  unless (case repeated of Left (WireGenerationIO _) -> True; _ -> False) (fail "split output reuse accepted")
  _ <- beginWireBindings obstructed >>= either (fail . show) pure
  missing <- finishWireBindings obstructed
  unless (case missing of Left (WireGenerationIO _) -> True; _ -> False) (fail "missing split response accepted")
  ByteString.writeFile (obstructed </> "plugin.response") response
  ByteString.writeFile (obstructed </> "generated" </> "sentinel") "keep\n"
  blocked <- finishWireBindings obstructed
  sentinel <- ByteString.readFile (obstructed </> "generated" </> "sentinel")
  unless (case blocked of Left (WireGenerationIO _) -> sentinel == "keep\n"; _ -> False) (fail "nonempty split output accepted")
  forM_ ["plugin.request", "PulsarApi.proto"] $ \name -> do
    let changed = root </> ("split-changed-" <> name)
    _ <- beginWireBindings changed >>= either (fail . show) pure
    ByteString.writeFile (changed </> "plugin.response") response
    original <- ByteString.readFile (changed </> name)
    ByteString.writeFile (changed </> name) (ByteString.snoc original 0)
    refused <- finishWireBindings changed
    written <- mapM (doesFileExist . ((changed </> "generated") </>)) ["Proto/PulsarApi.hs", "Proto/PulsarApi_Fields.hs"]
    unless (case refused of Left (WireGenerationIO _) -> written == [False, False]; _ -> False) (fail "changed split input accepted")

-- The fake is the test executable itself. It consumes the real request and
-- supplies controlled protobuf responses through the same process boundary as
-- the real plugin, without needing another installed tool.
pluginBoundary :: FilePath -> FilePath -> IO ()
pluginBoundary executable root = bracket (lookupEnv variable) restore $ \_ -> do
  clean <- run "clean"
  case clean of
    Right result -> do
      contents <- mapM ByteString.readFile (wireGeneratedFiles result)
      unless (contents == ["api source\n", "fields source\n"]) (fail "direct plugin bytes")
      retained <- ByteString.readFile (root </> "plugin-clean" </> "plugin.request")
      received <- ByteString.readFile (root </> "plugin-clean" </> "plugin.stderr")
      expected <- either (fail . T.unpack) pure protocolPluginRequest
      unless (retained == expected && received == retained) (fail "retained plugin request differs from the process input")
    Left problem -> fail (show problem)
  forM_ ["empty", "truncated", "error", "missing", "duplicate", "foreign", "insertion", "empty-content", "exit"] $ \mode -> do
    outcome <- run mode
    case outcome of
      Right _ -> fail ("direct plugin accepted " <> mode)
      Left _ -> do
        let output = root </> ("plugin-" <> mode) </> "generated" </> "Proto"
        written <- mapM (doesFileExist . (output </>)) ["PulsarApi.hs", "PulsarApi_Fields.hs"]
        unless (written == [False, False]) (fail ("direct plugin wrote rejected " <> mode))
 where
  variable = "AMOEBIUS_TEST_WIRE_PLUGIN"
  restore Nothing = unsetEnv variable
  restore (Just value) = setEnv variable value
  run mode = setEnv variable mode >> generateWireBindingsFromPlugin executable (root </> ("plugin-" <> mode))

fakePlugin :: String -> IO ()
fakePlugin mode = do
  mapM_ (`hSetBinaryMode` True) [stdin, stdout, stderr]
  request <- ByteString.hGetContents stdin
  unless (not (ByteString.null request)) exitFailure
  when (mode == "clean") (ByteString.hPut stderr request)
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
  varint number
    | number < 128 = ByteString.singleton (fromIntegral number)
    | otherwise = ByteString.cons (fromIntegral (number .&. 127) .|. 128) (varint (number `shiftR` 7))

fakeCompiler :: [String] -> IO ()
fakeCompiler args = case ([drop (length ("--haskell_out=" :: String)) a | a <- args, "--haskell_out=" `isPrefixOf` a],
                          [a | a <- args, "--plugin=protoc-gen-haskell=" `isPrefixOf` a]) of
  ([output], [plugin])
    | "fail" `isSuffixOf` plugin -> exitFailure
    | otherwise -> do
        createDirectory (output </> "Proto")
        writeFile (output </> "Proto" </> "PulsarApi.hs") "generated\n"
        unless ("omit" `isSuffixOf` plugin) (writeFile (output </> "Proto" </> "PulsarApi_Fields.hs") "generated\n")
  _ -> exitFailure
