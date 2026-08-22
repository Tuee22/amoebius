{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Workflow.Arm
  ( Discharge (ToreDown)
  , Evidence (Evidence)
  , Resource (Resource)
  , everyArm
  )
import Amoebius.Gate.SelfReferential
import Control.Monad (forM_, unless)
import Data.List (sort)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)
import Text.Read (readMaybe)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [] -> runSuite
    ["--value", phaseText, contract, command, exitText] -> runValue phaseText contract command exitText
    _ -> die "usage: self-referential-gates-spec [--value PHASE CONTRACT COMMAND EXIT_CODE]"

runSuite :: IO ()
runSuite = do
  root <- projectRoot
  setCurrentDirectory root
  rows <- loadTable (root </> "test/oracle/self_referential_gates/gate_inventory.tsv")
  assertEqual "gate declaration count" 96 (length rows)
  assertEqual "gate phase domain" [0 .. 95] (sort [phase | row <- rows, phase <- phaseOf row])
  let runnable = [row | row@(_phase : _contract : command : _state : _) <- rows, command /= "—"]
      descriptive = [row | row@(_phase : _contract : command : _state : _) <- rows, command == "—"]
  assertEqual "runnable gate count" 93 (length runnable)
  assertEqual "descriptive gate count" 3 (length descriptive)
  forM_ runnable verifyGate
  verifyFailedVerdict
  putStrLn "self-referential-gates-spec: PASS (96 declarations, 93 runnable values, 3 descriptive contracts, 5 arms, 2 verdicts, 3 mutants)"

runValue :: String -> FilePath -> String -> String -> IO ()
runValue phaseText contract command exitText = do
  phase <- maybe (die "self-referential-gate-value: invalid phase") pure (readMaybe phaseText)
  exitCode <- maybe (die "self-referential-gate-value: invalid exit code") pure (readMaybe exitText)
  let verdict = if exitCode == 0 then GatePassed else GateFailed exitCode
      run = deriveGate (GateDeclaration phase contract (Text.pack command)) verdict
  assertEqual "value arms" everyArm (runArms run)
  assert (runBalances run) "self-referential-gate-value: provisioned resources leaked"
  assert (runDischargedOnce run) "self-referential-gate-value: resource discharged more than once"
  assert (runIncludesMutants run) "self-referential-gate-value: derived gate skips mutants"
  putStrLn $ "self-referential-gate-value: PASS (phase " <> show phase
    <> ", 5 arms, 1 provision, 1 release, verdict " <> verdictTag verdict <> ")"

verdictTag :: GateVerdict -> String
verdictTag verdict = case verdict of
  GatePassed -> "PASS"
  GateFailed code -> "RED:" <> show code

verifyGate :: [String] -> IO ()
verifyGate fields = case fields of
  [phaseText, contract, command, _state] -> do
    phase <- maybe (die ("invalid phase " <> phaseText)) pure (readMaybe phaseText)
    let declaration = GateDeclaration phase contract (Text.pack command)
        run = deriveGate declaration GatePassed
        evidence = runEvidence run
        label = "phase " <> phaseText
    if runArms run == everyArm
      then pure ()
      else die ("self-referential-gates-mutant: RED drop_observation " <> label)
    assert (runBalances run) ("self-referential-gates-mutant: RED leak_resource " <> label)
    assert (runDischargedOnce run) (label <> " discharged more than once")
    assert (runIncludesMutants run) ("self-referential-gates-mutant: RED skip_mutant " <> label)
    assertEqual (label <> " provision") [Resource "phase-gate-process"] (runProvisioned run)
    assertEqual (label <> " release") [(Resource "phase-gate-process", ToreDown)] (runReleased run)
    assertEqual (label <> " evidence phase") phase (evidencePhase evidence)
    assertEqual (label <> " evidence contract") contract (evidenceContract evidence)
    assertEqual (label <> " evidence command") (Text.pack command) (evidenceCommand evidence)
    assertEqual (label <> " evidence verdict") GatePassed (evidenceVerdict evidence)
    let wantedObservation = Evidence "observed"
    if evidenceObservation evidence == wantedObservation
      then pure ()
      else die ("self-referential-gates-mutant: RED drop_observation " <> label)
  _ -> die ("invalid gate inventory row: " <> show fields)

verifyFailedVerdict :: IO ()
verifyFailedVerdict = do
  let declaration = GateDeclaration 49 "DEVELOPMENT_PLAN/phase_49_self_referential_gates.md"
        "python3 tools/self_referential_gates_gate.py"
      evidence = runEvidence (deriveGate declaration (GateFailed 17))
  assertEqual "failed verdict remains evidence" (GateFailed 17) (evidenceVerdict evidence)

phaseOf :: [String] -> [Int]
phaseOf fields = case fields of
  phaseText : _ -> maybe [] pure (readMaybe phaseText)
  [] -> []

loadTable :: FilePath -> IO [[String]]
loadTable path = do
  rows <- lines <$> readFile path
  case rows of
    [] -> die ("empty table: " <> path)
    _header : body -> pure (fmap splitTabs body)

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label wanted actual = unless (wanted == actual) $
  die (label <> ": expected " <> show wanted <> ", got " <> show actual)

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    present <- doesFileExist (path </> "cabal.project")
    if present then pure path else
      let parent = takeDirectory path
      in if parent == path then die "self-referential-gates-root" else ascend parent
