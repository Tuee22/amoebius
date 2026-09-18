{-# LANGUAGE OverloadedStrings #-}

-- | The verifier executable (gate_runner_doctrine.md section 6; DL-0013). It owns
-- no product command. Every command is agent-run: @preview@ mints nothing,
-- @accept@ records one phase, @replay@ re-derives recorded receipts, @reset@ and
-- @demo@ record their receipts. The documentation checker and its rendered
-- negatives are exposed for component diagnostics.
module Main (main) where

import Amoebius.Doc.Check (checkTree, discoverDocuments)
import Amoebius.Doc.Render (Negative (..), negativeCatalogue, renderNegative, writeCorpus)
import Amoebius.Doc.Types (CheckResult (..), Finding (..), Observation (..))
import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.Custody
import Amoebius.Validation.Runner qualified as Runner
import Amoebius.Validation.Custody.Store (Store (..))
import Amoebius.Validation.GateSpec (GateRole (..), mkGateSpec, renderGateSpec, renderSpecRefusal)
import Amoebius.Validation.GateSpec.Registry (specInputFor)
import Control.Monad (forM, unless)
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, removePathForcibly)
import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitFailure, exitWith)
import System.FilePath ((</>))
import Text.Read (readMaybe)

main :: IO ()
main = do
  arguments <- getArgs
  let (options, positional) = splitOptions arguments
      config =
        (defaultCustodyConfig (option "root" "." options))
          { custodyStore = Store (option "store" ".build/certification" options)
          , custodyMutantLimit = readMaybe =<< lookup "mutant-limit" options
          , custodyCabal = lookup "cabal" options
          , custodyCompiler = lookup "ghc" options
          }
  case positional of
    ["doc-check"] -> docCheck (option "root" "." options) (option "out" ".build/docs" options)
    ["doc-negatives"] -> docNegatives (option "root" "." options) (option "out" ".build/docs" options)
    ["preview", "phase", ordinal] | Just phase <- readMaybe ordinal -> previewPhase config phase >>= finish
    ["phase", ordinal] | Just phase <- readMaybe ordinal -> previewPhase config phase >>= finish
    ["spec", "phase", ordinal] | Just phase <- readMaybe ordinal -> renderSpec phase
    ["accept"] | Just phase <- readMaybe =<< lookup "phase" options -> acceptPhase config phase >>= finish
    ["reset"] | Just decision <- lookup "decision" options, Just gap <- lookup "product-gap" options -> resetGeneration config (Text.pack decision) (Text.pack (option "validator-gap" "gates measured the harness" options)) (Text.pack gap) >>= finish
    ["demo"] | Just file <- lookup "file" options -> demoFile config file >>= finish
    ["replay"] -> replayThrough config (readMaybe =<< lookup "through" options) >>= finish
    _ -> do
      mapM_ putStrLn usage
      exitFailure
 where
  option name fallback options = maybe fallback id (lookup name options)

usage :: [String]
usage =
  [ "usage: amoebius-validate <command> [--root DIR] [--store DIR] [--cabal PATH] [--ghc PATH]"
  , "  preview phase NN                      run the complete gate; mint nothing (agent)"
  , "  accept --phase NN                     run the gate, record the receipt, apply one phase's status patch"
  , "  replay [--through NN]                 re-derive every Done phase's receipt for this verifier"
  , "  reset --decision DL-NNNN --product-gap LTD-XXX-NNN [--validator-gap TEXT]"
  , "  demo --file PATH                      record the digest of an operator-authored input"
  , "  doc-check | doc-negatives [--out DIR] the documentation checker and its rendered negatives"
  , "  spec phase NN                         print the registered specification's rendering (the gate-spec block)"
  ]

-- | Print the rendering a phase document must carry in its fenced gate-spec block.
renderSpec :: Int -> IO ()
renderSpec phase = case PhaseIdentity.lookupPhaseIdentity phase of
  Nothing -> putStrLn "PHASE-ABSENT" >> exitFailure
  Just row -> case specInputFor (PhaseIdentity.phaseIdentityCapability row) of
    Nothing -> putStrLn "SPEC-ABSENT" >> exitFailure
    Just input -> case mkGateSpec (roleOf phase) input of
      Left refusals -> mapM_ (TextIO.putStrLn . renderSpecRefusal) refusals >> exitFailure
      Right spec -> TextIO.putStr (renderGateSpec spec)
 where
  roleOf ordinal
    | ordinal == PhaseIdentity.phaseDomainLowerOrdinal = SeedGate
    | Just ordinal == PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier = BarrierGate
    | maybe False (ordinal >=) (PhaseIdentity.roleOrdinal PhaseIdentity.FirstHardware) = HardwareGate
    | otherwise = OrdinaryGate

-- | @--name value@ pairs and the remaining positional words.
splitOptions :: [String] -> ([(String, String)], [String])
splitOptions arguments = case arguments of
  [] -> ([], [])
  (('-' : '-' : name) : value : rest) | not ("--" `isPrefixOfString` value) -> let (options, positional) = splitOptions rest in ((name, value) : options, positional)
  (word : rest) -> let (options, positional) = splitOptions rest in (options, word : positional)
 where
  isPrefixOfString prefix word = take (length prefix) word == prefix

finish :: CommandOutcome -> IO ()
finish outcome = do
  mapM_ TextIO.putStrLn (outcomeLines outcome)
  exitWith (outcomeExit outcome)

docCheck :: FilePath -> FilePath -> IO ()
docCheck root out = do
  compiled <- compiledBlocks root
  result <- checkTree compiled root
  createDirectoryIfMissing True out
  TextIO.writeFile (out </> "findings.tsv") (renderLedger result)
  mapM_ (TextIO.putStrLn . renderFinding) (checkFindings result)
  putStrLn ("doc-check: " <> show (length (checkFindings result)) <> " finding(s); ledger " <> (out </> "findings.tsv"))
  unless (null (checkFindings result)) exitFailure

docNegatives :: FilePath -> FilePath -> IO ()
docNegatives root out = do
  (documents, _, _) <- discoverDocuments root
  compiled <- compiledBlocks root
  let negativesRoot = out </> "negatives"
  removePathForcibly negativesRoot
  rows <- forM negativeCatalogue $ \negative -> do
    let name = Text.unpack (negativeName negative)
        target = negativesRoot </> name
    case renderNegative negative documents of
      Left problem -> pure (negative, ["RENDER-FAILED"], problem)
      Right corpus -> do
        writeCorpus target corpus
        result <- checkTree compiled target
        let codes = sort (nub (map findingCode (checkFindings result)))
        pure (negative, codes, "")
  createDirectoryIfMissing True out
  let rendered =
        [ Text.intercalate "\t" [negativeName negative, negativeCode negative, Text.intercalate "," codes, if negativeCode negative `elem` codes then "named-finding-observed" else "named-finding-absent" <> (if Text.null problem then "" else ": " <> problem)]
        | (negative, codes, problem) <- rows
        ]
  TextIO.writeFile (out </> "negatives.tsv") (Text.unlines rendered)
  mapM_ TextIO.putStrLn rendered
  unless (and [negativeCode negative `elem` codes | (negative, codes, _) <- rows]) exitFailure

-- | The compiled gate-specification blocks: every registered specification's
-- rendering. A phase document's fenced block must equal it.
compiledBlocks :: FilePath -> IO [(Int, Text)]
compiledBlocks _ = pure Runner.compiledBlocks

renderLedger :: CheckResult -> Text
renderLedger result =
  Text.unlines
    ( [Text.intercalate "\t" ["finding", findingCode item, Text.pack (findingSubject item), findingDetail item] | item <- checkFindings result]
        <> [Text.intercalate "\t" ["observation", observationKey item, observationValue item] | item <- checkObservations result]
    )

renderFinding :: Finding -> Text
renderFinding item = findingCode item <> "\t" <> Text.pack (findingSubject item) <> "\t" <> findingDetail item
