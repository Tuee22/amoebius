{-# LANGUAGE OverloadedStrings #-}
-- | Supplied boundaries exercise the actual shipped decoder, not a copied Core.
module OracleTranscripts (oracleTranscriptRows) where
import Amoebius.Validation.Runner
import OracleTranscriptInputs (transcriptInputs)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import System.Directory (createDirectoryIfMissing)
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
oracleTranscriptRows :: FilePath -> IO ()
oracleTranscriptRows output = do
 createDirectoryIfMissing True output
 TIO.writeFile (output </> "oracle-transcripts.data") (T.pack (show (map observeInput transcriptInputs)))
 where
  observeInput (name,mode,challenge,names,primary,absence,exit,unavailable,stdout,stderr) =
   let kind=case (mode,primary) of ("normal",_)->OrdinaryTranscript names;("inventory",_)->InventoryTranscript;("probe",Just path)->MissingInputTranscript path absence;_->error "invalid supplied transcript input"
       run=ObservedRun {runExecutable="supplied-oracle",runArgv=[],runCwd="supplied-root",runEnvironment=[],runEnvironmentPolicy="supplied-only;no-native-authority",runExit=if exit==0 then ExitSuccess else ExitFailure exit,runStdout=stdout,runStderr=stderr,runSpawnFailure=unavailable}
   in (name,inspectOracleTranscript kind challenge run)
