module Main (main) where

import SpineFake (fakeImage)
import SpineSuite (runBase, guarded)
import SpineExtensionAst (extensionAstSection)
import SpineExtensionCodec (extensionCodecSection)
import SpineExtensionRegistry (extensionRegistrySection)
import SpineExtensionLower (extensionLowerSection)
import SpineExtensionConformance (extensionConformanceSection)
import SpineExtensionRuntime (extensionRuntimeSection)
import SpineAdmissionTransport (admissionTransportFromBuild)
import Amoebius.Dsl.Examples.Extensions.SourceInputs (conformanceRoleInputs, closedApiInputs)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory (createDirectoryIfMissing, exeExtension)
import System.Directory (makeAbsolute)
import System.Environment (getArgs, getProgName)
import System.Exit (die)
import System.FilePath ((</>))

main :: IO ()
main = do
  name <- getProgName
  if name `elem` ["kubectl", "kubectl" <> exeExtension] then fakeImage else do
    arguments <- getArgs
    case arguments of
      ["--astcheck", directory] -> makeAbsolute directory >>= extensionAstSection
      ["--registry", directory] -> makeAbsolute directory >>= extensionRegistrySection
      [directory] -> do
        suite <- makeAbsolute directory
        runBase suite
        guarded suite "extension-ast" (extensionAstSection (suite </> "extensions/ast"))
        guarded suite "extension-codec" (extensionCodecSection (suite </> "extensions/codec"))
        guarded suite "extension-registry" (extensionRegistrySection (suite </> "extensions/registry"))
        guarded suite "extension-lower" (extensionLowerSection (suite </> "extensions/lower"))
        guarded suite "extension-conformance" (extensionConformanceSection (suite </> "extensions/conformance"))
        guarded suite "extension-runtime" (extensionRuntimeSection (suite </> "extensions/runtime"))
        guarded suite "extension-transport" (admissionTransportFromBuild (suite </> "extensions/transport"))
        createDirectoryIfMissing True (suite </> "extensions/types")
        mapM_ (\(name, legal, illegal) -> do
          Text.writeFile (suite </> "extensions/types" </> Text.unpack name <> "-same-index.hs") legal
          Text.writeFile (suite </> "extensions/types" </> Text.unpack name <> "-retag.hs") illegal) conformanceRoleInputs
        createDirectoryIfMissing True (suite </> "extensions/closed-api")
        mapM_ (\(name, legal, illegal) -> do
          Text.writeFile (suite </> "extensions/closed-api" </> Text.unpack name <> "-legal.hs") legal
          Text.writeFile (suite </> "extensions/closed-api" </> Text.unpack name <> "-illegal.hs") illegal) closedApiInputs
        writeFile (suite </> "extensions.marker") "extensions\n"
        writeFile (suite </> "complete.marker") "complete\n"
      _ -> die "usage: extensions-suite SUITE-DIRECTORY | --registry OUTPUT-DIRECTORY | --astcheck OUTPUT-DIRECTORY"
