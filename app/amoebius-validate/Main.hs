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
import Amoebius.Plan.Legacy qualified as Legacy
import Amoebius.Plan.PhaseIdentity (phaseDomainLowerOrdinal)
import Amoebius.Validation.Custody
import Amoebius.Validation.Runner qualified as Runner
import Amoebius.Validation.Runner.Hygiene (captureSource)
import Amoebius.Validation.Runner.Legacy (observeLegacy, auditLegacyReports, renderLegacyReports, runLegacyProbe, qualifyLegacy, qualifiedLegacyReports, auditQualifiedLegacyReports)
import Amoebius.Validation.Custody.Store (Store (..), archivedKernelCap)
import Amoebius.Validation.GateSpec (renderGateSpec)
import Amoebius.Validation.GateSpec.Registry (registeredSpecInputs)
import Amoebius.Validation.Runner.Spec (resolveSpec)
import Control.Monad (forM, unless)
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, removePathForcibly)
import System.Environment (getArgs)
import System.Exit (exitFailure, exitWith)
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
    ["legacy-audit"] | Just phase <- readMaybe =<< lookup "phase" options -> legacyAuditDiagnostic (custodyRoot config) phase
    ["kernel-observe"] | Just input <- lookup "input" options -> runLegacyProbe Legacy.LtdKrn001 input >>= TextIO.putStrLn
    ["mutation-observe"] | Just input <- lookup "input" options -> runLegacyProbe Legacy.LtdKrn002 input >>= TextIO.putStrLn
    ["solver-observe"] | Just input <- lookup "input" options -> runLegacyProbe Legacy.LtdKrn003 input >>= TextIO.putStrLn
    ["bootstrap-observe"] | Just input <- lookup "input" options -> runLegacyProbe Legacy.LtdSrc008 input >>= TextIO.putStrLn
    ["legacy-qualify"] | Just phase <- readMaybe =<< lookup "phase" options -> legacyQualifyDiagnostic config phase (option "analyzer" "kernel" options) (option "out" ".build/legacy-qualification" options)
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
  , "  legacy-audit --phase NN              print untrusted reports and prequalification refusals; mint nothing"
  , "  legacy-qualify --phase NN [--analyzer kernel|mutation|solver|bootstrap|correspondence|custody|status|authority|fresh|admission|probe-source|vendor-source|test-source|tool-source|pulumi-source|runtime-identity|ignore-context|source-graph|bootstrap-source] [--out DIR] mint no phase evidence"
  , "  spec phase NN                         print the registered specification's rendering (the gate-spec block)"
  ]

legacyAuditDiagnostic :: FilePath -> Int -> IO ()
legacyAuditDiagnostic root phase = do
  captured <- captureSource root >>= either (\problem -> TextIO.putStrLn problem >> exitFailure) pure
  cap <- archivedKernelCap root >>= either (\problem -> TextIO.putStrLn problem >> exitFailure) pure
  let reports = observeLegacy phase captured cap
      refusals = auditLegacyReports phase captured reports
  TextIO.putStrLn "component-diagnostic\tno-phase-evidence"
  TextIO.putStr (renderLegacyReports reports)
  mapM_ (TextIO.putStrLn . ("legacy-refusal\t" <>)) refusals
  unless (null refusals) exitFailure

legacyQualifyDiagnostic :: CustodyConfig -> Int -> String -> FilePath -> IO ()
legacyQualifyDiagnostic config phase analyzer output = do
  source <- captureSource (custodyRoot config) >>= either (\problem -> TextIO.putStrLn problem >> exitFailure) pure
  qualify <- case analyzer of
    "kernel" -> pure (qualifyLegacy Legacy.LtdKrn001)
    "mutation" -> pure (qualifyLegacy Legacy.LtdKrn002)
    "solver" -> pure (qualifyLegacy Legacy.LtdKrn003)
    "bootstrap" | phase == phaseDomainLowerOrdinal -> pure (qualifyLegacy Legacy.LtdSrc008)
    "bootstrap" -> TextIO.putStrLn "LegacyQualificationWrongOwner" >> exitFailure
    "bootstrap-source" | Legacy.legacyOwnerOrdinal Legacy.LtdSrc008 == Just phase -> pure (qualifyLegacy Legacy.LtdSrc008)
    "bootstrap-source" -> TextIO.putStrLn "LegacyQualificationWrongOwner" >> exitFailure
    "correspondence" -> pure (qualifyLegacy Legacy.LtdVal002)
    "custody" -> pure (qualifyLegacy Legacy.LtdVal003)
    "status" -> pure (qualifyLegacy Legacy.LtdVal004)
    "authority" -> pure (qualifyLegacy Legacy.LtdVal001)
    "fresh" -> pure (qualifyLegacy Legacy.LtdVal006)
    "admission" -> pure (qualifyLegacy Legacy.LtdBoot001)
    "probe-source" -> pure (qualifyLegacy Legacy.LtdSrc007)
    "source-graph" -> pure (qualifyLegacy Legacy.LtdSrc000)
    "ignore-context" -> pure (qualifyLegacy Legacy.LtdMeta001)
    "runtime-identity" -> pure (qualifyLegacy Legacy.LtdName001)
    "pulumi-source" -> pure (qualifyLegacy Legacy.LtdSrc005)
    "tool-source" -> pure (qualifyLegacy Legacy.LtdSrc001)
    "test-source" -> pure (qualifyLegacy Legacy.LtdSrc006)
    "vendor-source" -> pure (qualifyLegacy Legacy.LtdSrc009)
    _ -> TextIO.putStrLn "LegacyQualificationAnalyzerUnknown" >> exitFailure
  result <- qualify (custodyRoot config) output phase (custodyCabal config) (custodyCompiler config) source
  case result of
    Left problem -> TextIO.putStrLn problem >> exitFailure
    Right qualification -> do
      TextIO.putStrLn ("component-diagnostic\tqualified-" <> Text.pack analyzer <> "-query\tno-phase-evidence")
      let refusals = auditQualifiedLegacyReports phase source [qualification] (qualifiedLegacyReports phase source [qualification])
      mapM_ (TextIO.putStrLn . ("legacy-refusal\t" <>)) refusals
      unless (null refusals) exitFailure

-- | Print the rendering a phase document must carry in its fenced gate-spec block.
renderSpec :: Int -> IO ()
renderSpec phase = case resolveSpec registeredSpecInputs phase of
  Left refusals -> mapM_ TextIO.putStrLn refusals >> exitFailure
  Right (_, spec) -> TextIO.putStr (renderGateSpec spec)

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
compiledBlocks _ = either (fail . Text.unpack . Text.unlines) pure (Runner.compiledBlocks registeredSpecInputs)

renderLedger :: CheckResult -> Text
renderLedger result =
  Text.unlines
    ( [Text.intercalate "\t" ["finding", findingCode item, Text.pack (findingSubject item), findingDetail item] | item <- checkFindings result]
        <> [Text.intercalate "\t" ["observation", observationKey item, observationValue item] | item <- checkObservations result]
    )

renderFinding :: Finding -> Text
renderFinding item = findingCode item <> "\t" <> Text.pack (findingSubject item) <> "\t" <> findingDetail item
