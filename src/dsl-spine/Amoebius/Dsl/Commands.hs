{-# LANGUAGE OverloadedStrings #-}

-- | The three product subcommands that drive the spine: render the example corpus, compile
-- a specification, and apply what it compiles to. Each parses its arguments and prints; every
-- decision it reports was made by the pipeline. Exit 0 succeeded, 1 a stage refused, 2 usage.
module Amoebius.Dsl.Commands
  ( runRenderExamples
  , runCompile
  , runApply
  ) where

import Amoebius.Dsl.Examples.Capacity (Example (..), exampleNamed, renderExampleFiles)
import Amoebius.Dsl.Pipeline
  ( ApplyOutcome (..)
  , PipelineError
  , applyToDirectory
  , compileToDirectory
  , pipelineErrorStage
  , pipelineErrorTag
  , renderPipelineError
  )
import Amoebius.Kernel.Interpret (sha256Hex)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
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
  ["--input", input, "--out", output] -> do
    outcome <- compileToDirectory input output
    case outcome of
      Right steps -> putStrLn ("compiled\t" <> show (length steps))
      Left problem -> refused problem
  _ -> usage "compile --input FILE --out DIR"

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
