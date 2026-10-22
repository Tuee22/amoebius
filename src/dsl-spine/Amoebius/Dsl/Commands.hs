{-# LANGUAGE OverloadedStrings #-}

-- | The three product subcommands that drive the spine: render the example corpus, compile
-- a specification, and apply what it compiles to. Each parses its arguments and prints; every
-- decision it reports was made by the pipeline. Exit 0 succeeded, 1 a stage refused, 2 usage.
module Amoebius.Dsl.Commands
  ( runRenderExamples
  , runCompile
  , runApply
  , runAstcheck
  ) where

import Amoebius.Dsl.Examples.Extensions (Example (..), exampleNamed, renderExampleFiles)
import Amoebius.Dsl.Decode (decodeRoot)
import Amoebius.Dsl.Import (freezeText)
import Amoebius.Dsl.Lower (lowerDeployment, loweredProofs)
import Amoebius.Extension.AstCheck (checkedSourceFiles, checkedSourceModules)
import Amoebius.Extension.Linked qualified as Linked
import Amoebius.Extension.SourceClosure (readContributionClosure, renderContributionRefusal)
import Amoebius.Extension.Spec (extSourceSeal)
import Amoebius.Scope.Attested (attest, bindingAttestation, scopeIssuer, scopeApplication, scopeNeed, scopeLabel)
import Amoebius.Dsl.Pipeline
  ( ApplyOutcome (..)
  , PipelineError
  , applyToDirectory
  , compileToDirectory
  , lowerToDirectory
  , pipelineErrorStage
  , pipelineErrorTag
  , renderPipelineError
  )
import Amoebius.Kernel.Interpret (sha256Hex)
import Data.ByteString qualified as ByteString
import Data.Bifunctor (first)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.IO qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.Environment (getExecutablePath)
import System.Exit (ExitCode (ExitFailure), exitWith)
import System.FilePath (takeDirectory, (</>))
import System.IO (hPutStrLn, stderr)

usage :: String -> IO ()
usage grammar = hPutStrLn stderr ("usage: amoebius " <> grammar) >> exitWith (ExitFailure 2)

-- | @render-examples --out DIR@ writes the whole corpus; @render-examples --example NAME
-- --output FILE@ writes one example. Each file written is reported with its digest.
runRenderExamples :: [String] -> IO ()
runRenderExamples options = case options of
  ["--out", output] -> mapM_ (\(path, contents) -> writeReported (output </> path) contents) renderExampleFiles
  ["--example", name, "--output", path] -> case exampleNamed (Text.pack name) of
    Just example -> writeReported path (exampleText example <> "\n")
    Nothing -> hPutStrLn stderr ("unknown example: " <> name) >> exitWith (ExitFailure 2)
  _ -> usage "render-examples (--out DIR | --example NAME --output FILE)"

writeReported :: FilePath -> Text -> IO ()
writeReported path contents = do
  createDirectoryIfMissing True (takeDirectory path)
  let bytes = Encoding.encodeUtf8 contents
  ByteString.writeFile path bytes
  putStrLn (Text.unpack (sha256Hex bytes) <> "  " <> path)

-- | @compile --input FILE --out DIR@ freezes, decodes, lowers, plans, provisions, renders,
-- and chains the input, writing the artefact of every stage that completed.
runCompile :: [String] -> IO ()
runCompile options = case options of
  ["--input", input, "--out", output, "--through", "lower"] -> do
    outcome <- lowerToDirectory input output
    either refused (const (putStrLn "lowered")) outcome
  ["--input", input, "--out", output] -> do
    outcome <- compileToDirectory input output
    case outcome of
      Right steps -> putStrLn ("compiled\t" <> show (length steps))
      Left problem -> refused problem
  _ -> usage "compile --input FILE --out DIR [--through lower]"

-- | @apply --executor fake --input FILE --out DIR [--dry-run]@ compiles, then applies every
-- step through the fake executor, or stops at the dry run.
runApply :: [String] -> IO ()
runApply options = case options of
  ["--executor", executor, "--input", input, "--out", output] -> apply executor False input output
  ["--executor", executor, "--input", input, "--out", output, "--dry-run"] -> apply executor True input output
  _ -> usage "apply --executor fake --input FILE --out DIR [--dry-run]"

apply :: String -> Bool -> FilePath -> FilePath -> IO ()
apply executor dry input output
  | executor /= "fake" = hPutStrLn stderr "ExecutorNotAdmitted" >> exitWith (ExitFailure 2)
  | otherwise = do
      image <- getExecutablePath
      outcome <- applyToDirectory dry image input output
      case outcome of
        ApplyRefused problem -> refused problem
        ApplyDryRun -> putStrLn "dry-run"
        ApplyFailed problem -> hPutStrLn stderr ("apply-failed\t" <> show problem) >> exitWith (ExitFailure 1)
        Applied count -> putStrLn ("applied\t" <> show count)

refused :: PipelineError -> IO ()
refused problem = do
  hPutStrLn stderr ("refused\t" <> Text.unpack (pipelineErrorTag problem) <> "\t" <> Text.unpack (pipelineErrorStage problem) <> "\t" <> Text.unpack (Text.strip (renderPipelineError problem)))
  exitWith (ExitFailure 1)

-- | The observed source closure must be the one the executable admitted at
-- link time. Its owner comes from the independently decoded operator value
-- and an actual linked binding; text fields alone cannot introduce a scope.
runAstcheck :: [String] -> IO ()
runAstcheck options = case options of
  ["--source-root", root, "--owner-input", input, "--out", output] -> do
    createDirectoryIfMissing True (takeDirectory output)
    checked <- readContributionClosure root
    case checked of
      Left problem -> reject output (renderContributionRefusal problem)
      Right seal -> do
        source <- Text.readFile input
        frozen <- freezeText (takeDirectory input) source
        case frozen of
          Left problem -> reject output (Text.pack (show problem))
          Right value -> case first (Text.pack . show) (decodeRoot value) >>= first (Text.pack . show) . lowerDeployment of
            Left problem -> reject output (Text.pack (show problem))
            Right lowered -> case Linked.linkedExtensionSet of
              Left problem -> reject output (Text.pack (show problem))
              Right links -> case Linked.extensionsIn links of
                [] -> reject output "UnboundCapability"
                specification : _
                  | checkedSourceFiles seal /= checkedSourceFiles (extSourceSeal specification) -> reject output "AdmittedSourceMismatch"
                  | otherwise -> case [proof | proof <- Map.elems (loweredProofs lowered), Linked.bindingIssuer proof == "extension/infernix"] of
                      proof : _ -> case attest (bindingAttestation proof) (\scope ->
                        [("issuer", scopeIssuer scope), ("application", scopeApplication scope),
                         ("need", scopeNeed scope), ("scope-label", scopeLabel scope)]) of
                        Left problem -> reject output (Text.pack (show problem))
                        Right owner -> do
                          Text.writeFile output (Text.unlines
                            (["extension-astcheck\taccepted"] <>
                             [key <> "\t" <> field | (key, field) <- owner] <>
                             ["source\t" <> Text.pack path <> "\t" <> name | (path, name) <- NonEmpty.toList (checkedSourceModules seal)]))
                          putStrLn "admitted"
                      [] -> reject output "UnboundCapability"
  _ -> usage "astcheck --source-root DIR --owner-input FILE --out FILE"
 where
  reject output problem = do
    Text.writeFile output ("extension-astcheck\trefused\n" <> problem <> "\n")
    hPutStrLn stderr ("AstEvasion\textension-astcheck\t" <> Text.unpack problem)
    exitWith (ExitFailure 1)
