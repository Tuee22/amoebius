{-# LANGUAGE OverloadedStrings #-}

-- | Reads of the tracked source that cross-check the structure the spine claims: who may
-- assemble a bound deployment, where each closed vocabulary is defined, which subcommands
-- the binary has, and what the control-plane endpoint calls. They are weaker than a run and
-- are labelled as such.
module DslScan
  ( scanRows
  ) where

import Control.Exception (SomeException, try)
import Control.Monad (filterM, forM)
import Data.List (isSuffixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import DslParse (Row, check)
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath ((</>))

scanRows :: IO [Row]
scanRows = do
  sources <- sourceFiles
  contents <- forM sources (\path -> (,) path <$> readSource path)
  cabalText <- readSource "amoebius.cabal"
  foreignFiles <- concat <$> mapM walkAll ["src", "app", "test", "probe", "tools", "pb", "documents", "DEVELOPMENT_PLAN"]
  let importersOfAssemble = sort [path | (path, text) <- contents, any (isImportOf "Amoebius.Capability.Assemble") (Text.lines text)]
      definitions name = sort [path | (path, text) <- contents, any (defines name) (Text.lines text)]
      mainText = maybe "" id (lookup "app/amoebius/Main.hs" contents)
      endpointText = maybe "" id (lookup "app/amoebius/Amoebius/Entry/ControlPlane.hs" contents)
  pure
    ( [ check "scan.no-tracked-proto" (null [path | path <- foreignFiles, ".proto" `isSuffixOf` path]) "a wire schema is tracked"
      , check "scan.no-tracked-dhall" (null [path | path <- foreignFiles, ".dhall" `isSuffixOf` path]) "a Dhall projection is tracked"
      , check "scan.front-half-absent" (not (any (`Text.isInfixOf` cabalText) retiredLibraries) && not (any (`elem` map Text.strip (Text.lines cabalText)) retiredModules)) "the package description names a retired front-half library or module"
      , check "scan.assemble-importers" (importersOfAssemble == ["src/dsl-spine/Amoebius/Dsl/Lower.hs"]) (Text.pack (show importersOfAssemble))
      ]
        <> [ check ("scan.single-definition." <> name) (definitions name == [home]) (Text.pack (show (definitions name)))
           | (name, home) <- closedAxes
           ]
        <> [ check ("scan.subcommand." <> name) (("\"" <> name <> "\"") `Text.isInfixOf` mainText) "the subcommand is not dispatched"
           | name <- ["render-examples", "compile", "apply", "toolchain-report", "layout-report"]
           ]
        <> [ check "scan.endpoint-uses-pipeline" (any (isImportOf "Amoebius.Dsl.Pipeline") (Text.lines endpointText)) "the endpoint does not import the pipeline"
           , check "scan.endpoint-drops-demand" (not ("deployDemand" `Text.isInfixOf` endpointText || "desiredObjects" `Text.isInfixOf` endpointText)) "the endpoint still defines a constant demand"
           ]
    )

-- | The libraries and modules of the retired front half: the structural node tree, the toy decoder, the
-- hand-written schema strings, the covering fixtures, the barrier checker, and the step with a function slot.
retiredLibraries :: [Text]
retiredLibraries = ["gadt-decode-ir", "illegal-state-covering", "dhall-schema-generation", "dsl-barrier", "self-referential-gates"]

retiredModules :: [Text]
retiredModules = ["Amoebius.Dsl.Types", "Amoebius.Dsl.SmartConstructors", "Amoebius.Kernel.Chain", "Amoebius.Kernel.Descent", "Amoebius.Kernel.Plan", "Amoebius.Cli"]

-- | Each closed axis and the one file that defines it.
closedAxes :: [(Text, FilePath)]
closedAxes = [(name, "src/vocabulary/Amoebius/Vocabulary.hs") | name <- ["Substrate", "Architecture", "Detected", "Lane", "ComputeEngine", "EngineRuntime", "CapabilityArm", "ExtensionId", "Quantity"]] <> [("ResourceVector", "src/capacity-topology/Amoebius/Capacity/Vector.hs")]

isImportOf :: Text -> Text -> Bool
isImportOf moduleName line = case Text.words line of
  "import" : "qualified" : name : _ -> name == moduleName
  "import" : name : _ -> name == moduleName
  _ -> False

-- | A line that begins a data, newtype, or type declaration of exactly this name.
defines :: Text -> Text -> Bool
defines name line = case Text.words line of
  keyword : declared : _ -> keyword `elem` ["data", "newtype", "type"] && declared == name
  _ -> False

readSource :: FilePath -> IO Text
readSource path = do
  outcome <- try (TextIO.readFile path) :: IO (Either SomeException Text)
  pure (either (const "") id outcome)

sourceFiles :: IO [FilePath]
sourceFiles = concat <$> mapM walk ["src", "app"]

walk :: FilePath -> IO [FilePath]
walk directory = do
  present <- doesDirectoryExist directory
  if not present
    then pure []
    else do
      entries <- listDirectory directory
      let paths = map (directory </>) (sort entries)
      directories <- filterM doesDirectoryExist paths
      nested <- mapM walk directories
      pure ([path | path <- paths, ".hs" `isSuffixOf` path] <> concat nested)

-- | Every file beneath a directory, whatever its extension.
walkAll :: FilePath -> IO [FilePath]
walkAll directory = do
  present <- doesDirectoryExist directory
  if not present
    then pure []
    else do
      entries <- listDirectory directory
      let paths = map (directory </>) (sort entries)
      directories <- filterM doesDirectoryExist paths
      nested <- mapM walkAll directories
      pure ([path | path <- paths, path `notElem` directories] <> concat nested)
