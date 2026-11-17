{-# LANGUAGE OverloadedStrings #-}

-- | Generate fresh bindings from the product's wire declarations. The caller supplies
-- both tools and a new run directory; an existing directory is never reused as evidence.
module Amoebius.Pulsar.Wire.Generate
  ( WireGenerationError (..)
  , WireGeneration (..)
  , generateWireBindings
  , generateWireBindingsFromPlugin
  , beginWireBindings
  , finishWireBindings
  , materializeForkProject
  , materializeNativeProject
  ) where

import Amoebius.Pulsar.Wire (renderProtocol)
import Amoebius.Pulsar.Wire.Descriptor (protocolPluginRequest)
import Amoebius.Pulsar.Wire.Plugin (decodePluginResponse)
import Amoebius.Internal.Process.FileInput (tryRunFileInput)
import Control.Exception (IOException, try)
import Control.Monad (forM, forM_, unless)
import Data.ByteString qualified as ByteString
import Data.Char (isAlphaNum, isAscii, isDigit, isUpper)
import Data.List (nub)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.Encoding.Error (lenientDecode)
import System.Directory (canonicalizePath, copyFile, createDirectory, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, getCurrentDirectory, getFileSize, listDirectory, makeAbsolute, pathIsSymbolicLink)
import System.Exit (ExitCode (..))
import System.FilePath (equalFilePath, takeDirectory, takeExtension, (</>))
import System.Process (proc, readCreateProcessWithExitCode)

data WireGenerationError
  = WireGenerationIO String
  | WireCompilerFailed Int String
  | WireOutputsMissing [FilePath]
  | WirePluginResponse Text
  deriving stock (Eq, Show)

data WireGeneration = WireGeneration
  { wireSchemaPath :: FilePath
  , wireGeneratedFiles :: [FilePath]
  } deriving stock (Eq, Show)

-- | The generated directory is created exclusively. A failed invocation leaves its
-- owned directory for diagnosis and cannot be mistaken for a later successful run.
generateWireBindings :: FilePath -> FilePath -> FilePath -> IO (Either WireGenerationError WireGeneration)
generateWireBindings protoc plugin directory = do
  outcome <- try action :: IO (Either IOException (Either WireGenerationError WireGeneration))
  pure (either (Left . WireGenerationIO . show) id outcome)
 where
  action = do
    root <- makeAbsolute directory
    compiler <- makeAbsolute protoc
    generator <- makeAbsolute plugin
    createDirectoryIfMissing True (takeDirectory root)
    createDirectory root
    let schema = root </> "PulsarApi.proto"
        output = root </> "generated"
        files = [output </> "Proto" </> "PulsarApi.hs", output </> "Proto" </> "PulsarApi_Fields.hs"]
    createDirectory output
    ByteString.writeFile schema (Encoding.encodeUtf8 renderProtocol)
    (exit, _, err) <- readCreateProcessWithExitCode
      (proc compiler ["--plugin=protoc-gen-haskell=" <> generator, "--haskell_out=" <> output, "-I", root, "PulsarApi.proto"]) ""
    case exit of
      ExitFailure code -> pure (Left (WireCompilerFailed code err))
      ExitSuccess -> do
        present <- forM files $ \path -> do
          exists <- doesFileExist path
          if exists then (> 0) <$> getFileSize path else pure False
        let missing = [path | (path, False) <- zip files present]
        pure $ if null missing then Right (WireGeneration schema files) else Left (WireOutputsMissing missing)

-- | Use the proto-lens plugin directly with the descriptor projected from the
-- Haskell schema. No host protobuf compiler or prepared source file is needed.
generateWireBindingsFromPlugin :: FilePath -> FilePath -> IO (Either WireGenerationError WireGeneration)
generateWireBindingsFromPlugin plugin directory = do
  prepared <- beginWireBindings directory
  case prepared of
    Left problem -> pure (Left problem)
    Right (_, requestPath) -> do
      attempted <- try (runPlugin requestPath) :: IO (Either IOException (Either WireGenerationError WireGeneration))
      pure (either (Left . WireGenerationIO . show) id attempted)
 where
  runPlugin requestPath = do
    let root = takeDirectory requestPath
        response = root </> "plugin.response"
        errors = root </> "plugin.stderr"
    executable <- makeAbsolute plugin
    workingDirectory <- getCurrentDirectory
    exit <- tryRunFileInput workingDirectory executable [] Nothing requestPath response errors >>= either ioError pure
    case exit of
      ExitFailure code -> do
        detail <- Encoding.decodeUtf8With lenientDecode <$> ByteString.readFile errors
        pure (Left (WireCompilerFailed code (Text.unpack detail)))
      ExitSuccess -> finishWireBindings root

-- | Create the exclusive owner and retain the exact plugin request.
beginWireBindings :: FilePath -> IO (Either WireGenerationError (FilePath, FilePath))
beginWireBindings directory = do
  outcome <- try action :: IO (Either IOException (Either WireGenerationError (FilePath, FilePath)))
  pure (either (Left . WireGenerationIO . show) id outcome)
 where
  action = case protocolPluginRequest of
    Left problem -> pure (Left (WirePluginResponse problem))
    Right request -> do
      root <- makeAbsolute directory
      createDirectoryIfMissing True (takeDirectory root)
      createDirectory root
      let schema = root </> "PulsarApi.proto"
          output = root </> "generated"
          requestPath = root </> "plugin.request"
      createDirectory output
      ByteString.writeFile schema (Encoding.encodeUtf8 renderProtocol)
      ByteString.writeFile requestPath request
      pure (Right (schema, requestPath))

-- | Materialize a response only in a physical, still-empty preparation owner.
finishWireBindings :: FilePath -> IO (Either WireGenerationError WireGeneration)
finishWireBindings directory = do
  outcome <- try action :: IO (Either IOException (Either WireGenerationError WireGeneration))
  pure (either (Left . WireGenerationIO . show) id outcome)
 where
  action = do
    requested <- makeAbsolute directory
    linkedRoot <- pathIsSymbolicLink requested
    root <- canonicalizePath requested
    unless (not linkedRoot) (ioError (userError "wire preparation owner redirected"))
    let schema = root </> "PulsarApi.proto"
        request = root </> "plugin.request"
        response = root </> "plugin.response"
        output = root </> "generated"
    forM_ [root, schema, request, response, output] $ \path -> do
      linked <- pathIsSymbolicLink path
      physical <- canonicalizePath path
      unless (not linked && equalFilePath physical path) (ioError (userError "wire preparation path redirected"))
    filesPresent <- mapM doesFileExist [schema, request, response]
    directoriesPresent <- mapM doesDirectoryExist [root, output]
    unless (and filesPresent && and directoriesPresent) (ioError (userError "wire preparation inputs are incomplete"))
    expectedRequest <- either (ioError . userError . Text.unpack) pure protocolPluginRequest
    retainedRequest <- ByteString.readFile request
    retainedSchema <- ByteString.readFile schema
    unless (retainedRequest == expectedRequest && retainedSchema == Encoding.encodeUtf8 renderProtocol) (ioError (userError "wire preparation inputs changed"))
    entries <- listDirectory output
    unless (null entries) (ioError (userError "wire generation output is not empty"))
    raw <- ByteString.readFile response
    case decodePluginResponse raw of
      Left problem -> pure (Left (WirePluginResponse problem))
      Right files -> do
        paths <- forM files $ \(relative, body) -> do
          let path = output </> relative
          createDirectoryIfMissing True (takeDirectory path)
          ByteString.writeFile path body
          pure path
        let ordered = [output </> "Proto/PulsarApi.hs", output </> "Proto/PulsarApi_Fields.hs"]
        pure $ if all (`elem` paths) ordered then Right (WireGeneration schema ordered)
          else Left (WireOutputsMissing [path | path <- ordered, path `notElem` paths])

-- | Materialize a buildable fork project beside a just-generated schema. The
-- caller provides the maintained module inventory, rather than a second list.
-- Its source and bindings are copied into the run-local project before build.
materializeForkProject :: FilePath -> Text -> [Text] -> WireGeneration -> IO (Either WireGenerationError FilePath)
materializeForkProject repository version modules generation = do
  outcome <- try action :: IO (Either IOException FilePath)
  pure (either (Left . WireGenerationIO . show) Right outcome)
 where
  action = do
    unless (not (null modules) && all validModule modules && length modules == length (nub modules)
      && all (`elem` modules) ["Pulsar.Protocol.Commands", "Pulsar.Protocol.Encoder"]
      && all (\part -> not (Text.null part) && Text.all (\c -> isAscii c && isDigit c) part) (Text.splitOn "." version)) (ioError (userError "invalid fork identity or module inventory"))
    let root = takeDirectory (wireSchemaPath generation) </> "compatibility"
        source = root </> "src"
        generated = root </> "generated" </> "Proto"
        relative name = Text.unpack (Text.replace "." "/" name) <> ".hs"
    createDirectory root
    createDirectoryIfMissing True generated
    forM_ modules $ \name -> do
      let path = relative name
          destination = source </> path
      createDirectoryIfMissing True (takeDirectory destination)
      copyFile (repository </> "src" </> "vendor" </> path) destination
    case wireGeneratedFiles generation of
      [api, fields] -> do
        copyFile api (generated </> "PulsarApi.hs")
        copyFile fields (generated </> "PulsarApi_Fields.hs")
      _ -> ioError (userError "invalid generated binding inventory")
    Text.writeFile (root </> "supernova.cabal") (forkPackage version modules)
    let observer = root </> "wire-observer"
    createDirectory observer
    Text.writeFile (observer </> "fork-wire-observer.cabal") forkObserverPackage
    Text.writeFile (observer </> "Main.hs") forkObserverMain
    Text.writeFile (root </> "cabal.project") "packages: ./supernova.cabal ./wire-observer\noptimization: False\ntests: False\njobs: 1\n"
    pure root
  validModule name = all validPart (Text.splitOn "." name)
  validPart part = not (Text.null part) && isAscii (Text.head part) && isUpper (Text.head part) && Text.all (\c -> isAscii c && (isAlphaNum c || c == '_')) part

forkPackage :: Text -> [Text] -> Text
forkPackage version modules = Text.unlines
  [ "cabal-version: 3.12"
  , "name: supernova"
  , "version: " <> version
  , "build-type: Simple"
  , "license: Apache-2.0"
  , "library"
  , "  exposed-modules: " <> Text.intercalate ", " modules
  , "  other-modules: Paths_supernova, Proto.PulsarApi, Proto.PulsarApi_Fields"
  , "  autogen-modules: Paths_supernova"
  , "  hs-source-dirs: src, generated"
  , "  default-language: Haskell2010"
  , "  build-depends: base >=4.21 && <4.22, async >=2.2 && <2.3, binary >=0.8 && <0.9, bytestring >=0.12 && <0.13, crc32c ==0.2.2, exceptions >=0.10 && <0.11, lens-family-core >=2.1 && <2.2, logging >=3 && <3.1, managed >=1 && <1.1, mtl >=2.3 && <2.4, network >=3.1 && <3.2, proto-lens >=0.7 && <0.8, proto-lens-runtime >=0.7 && <0.8, text >=2.1 && <2.2, unagi-chan >=0.4 && <0.5"
  ]

forkObserverPackage :: Text
forkObserverPackage = Text.unlines
  [ "cabal-version: 3.12"
  , "name: amoebius-fork-wire-observer"
  , "version: 0.1.0.0"
  , "build-type: Simple"
  , "executable amoebius-fork-wire-observer"
  , "  main-is: Main.hs"
  , "  default-language: GHC2024"
  , "  build-depends: base >=4.21 && <4.22, bytestring >=0.12 && <0.13, supernova"
  ]

forkObserverMain :: Text
forkObserverMain = Text.unlines
  [ "module Main (main) where"
  , "import Data.ByteString.Lazy qualified as ByteString"
  , "import Numeric (showHex)"
  , "import Pulsar.Protocol.Commands qualified as Commands"
  , "import Pulsar.Protocol.Encoder (encodeBaseCommand)"
  , "main :: IO ()"
  , "main = mapM_ write [(\"ping\", encodeBaseCommand Nothing Nothing Commands.ping), (\"flow\", encodeBaseCommand Nothing Nothing (Commands.flow 7 11)), (\"send\", encodeBaseCommand Nothing Nothing (Commands.send 7 11))]"
  , "  where write (name, bytes) = putStrLn (name <> \"\\t\" <> concatMap hex (ByteString.unpack bytes))"
  , "        hex byte = case showHex byte \"\" of [digit] -> ['0', digit]; digits -> digits"
  ]

-- | Stage the native client with the exact authored Cabal description and
-- fresh generated modules. Cabal selects the client and its vocabulary
-- dependency from that description; no second module inventory is authored here.
materializeNativeProject :: FilePath -> WireGeneration -> IO (Either WireGenerationError FilePath)
materializeNativeProject repository generation = do
  outcome <- try action :: IO (Either IOException FilePath)
  pure (either (Left . WireGenerationIO . show) Right outcome)
 where
  action = do
    let root = takeDirectory (wireSchemaPath generation) </> "native"
        proto = root </> "src" </> "Proto"
    createDirectory root
    copyFile (repository </> "amoebius.cabal") (root </> "amoebius.cabal")
    copyTree (repository </> "src" </> "Amoebius" </> "Pulsar") (root </> "src" </> "Amoebius" </> "Pulsar")
    copyTree (repository </> "src" </> "vocabulary") (root </> "src" </> "vocabulary")
    createDirectoryIfMissing True proto
    case wireGeneratedFiles generation of
      [api, fields] -> do
        copyFile api (proto </> "PulsarApi.hs")
        copyFile fields (proto </> "PulsarApi_Fields.hs")
      _ -> ioError (userError "invalid generated binding inventory")
    let observer = root </> "wire-observer"
    createDirectory observer
    Text.writeFile (observer </> "native-wire-observer.cabal") nativeObserverPackage
    Text.writeFile (observer </> "Main.hs") nativeObserverMain
    Text.writeFile (root </> "cabal.project") "packages: ./amoebius.cabal ./wire-observer\noptimization: False\ntests: False\njobs: 1\n"
    pure root
  copyTree source destination = do
    linked <- pathIsSymbolicLink source
    unless (not linked) (ioError (userError "native source symlink refused"))
    directory <- doesDirectoryExist source
    if directory then do
      createDirectoryIfMissing True destination
      names <- listDirectory source
      forM_ names (\name -> copyTree (source </> name) (destination </> name))
    else do
      file <- doesFileExist source
      unless (file && takeExtension source == ".hs") (ioError (userError "unexpected native source entry"))
      copyFile source destination

nativeObserverPackage :: Text
nativeObserverPackage = Text.unlines
  [ "cabal-version: 3.12"
  , "name: amoebius-native-wire-observer"
  , "version: 0.1.0.0"
  , "build-type: Simple"
  , "executable amoebius-native-wire-observer"
  , "  main-is: Main.hs"
  , "  default-language: GHC2024"
  , "  build-depends: base >=4.21 && <4.22, text >=2.1 && <2.2, amoebius:pulsar-client"
  ]

nativeObserverMain :: Text
nativeObserverMain = Text.unlines
  [ "module Main (main) where"
  , "import Amoebius.Pulsar.Diagnostics (connectWireObservation)"
  , "import Data.Text.IO qualified as Text"
  , "import System.Exit (die)"
  , "main :: IO ()"
  , "main = either (die . show) Text.putStr connectWireObservation"
  ]
