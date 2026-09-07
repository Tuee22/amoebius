{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Gate.SelfReferential
import Amoebius.Validation.DslBarrier
import Control.Monad (unless)
import Data.List (nub)
import Data.Text (Text)
import Data.Text qualified as Text
import DslBarrierOracle
import System.Environment (getArgs, getExecutablePath)
import System.Exit (ExitCode (ExitSuccess), die)
import System.IO (BufferMode (LineBuffering), hFlush, hGetLine, hPutStrLn, hSetBuffering, stdout)
import System.Process
  ( CreateProcess (std_in, std_out)
  , StdStream (CreatePipe)
  , createProcess
  , proc
  , waitForProcess
  )

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--fake"] -> runFake
    [] -> runSuite "phase-49-default-challenge"
    ["--challenge", value] | validChallenge (Text.pack value) -> runSuite (Text.pack value)
    _ -> die "usage: self-referential-gates-spec [--challenge TOKEN | --fake]"

runSuite :: Text -> IO ()
runSuite challenge = do
  executable <- getExecutablePath
  fake <- observeFake executable challenge
  checkOracleIndependence
  let observations = zipWith (\stage digest -> StageObservation stage digest True) [minBound .. maxBound] expectedStageDigests
      gateRun = cleanGate
  expectRight "clean barrier" (validateDslBarrier observations (BarrierChallenge challenge) fake gateRun)
  checkNegatives observations challenge fake gateRun
  putStrLn "dsl-barrier-oracle: PASS (9 stages, 12 paired negatives, 12 changed-production mutants)"
  putStrLn "self-referential-gates-spec: PASS (9 stages, 5 workflow arms, external fake observation, teardown balanced)"

cleanGate :: GateRun
cleanGate =
  deriveGate
    (GateDeclaration 49 "DEVELOPMENT_PLAN/phase_49_self_referential_gates.md" "amoebius validate phase 49")
    GatePassed

observeFake :: FilePath -> Text -> IO FakeBoundaryObservation
observeFake executable challenge = do
  (Just input, Just output, Nothing, process) <-
    createProcess (proc executable ["--fake"]) {std_in = CreatePipe, std_out = CreatePipe}
  ready <- hGetLine output
  unless (ready == "READY") (die "fake boundary did not announce readiness")
  hPutStrLn input (Text.unpack challenge)
  hFlush input
  observed <- hGetLine output
  exitCode <- waitForProcess process
  let expected = "phase-49:" <> challenge
      recovered = Text.pack observed
  pure
    FakeBoundaryObservation
    { fakeExecutable = executable
    , fakeArgv = expectedFakeArgv
    , fakeRequestBytes = recovered
    , fakeRecoveredChallenge = Text.drop (Text.length ("phase-49:" :: Text)) recovered
    , fakeEffectStage = FakeApply
    , fakeExternallyObserved = recovered == expected
    , fakeTeardownObserved = exitCode == ExitSuccess
    }

runFake :: IO ()
runFake = do
  hSetBuffering stdout LineBuffering
  putStrLn "READY"
  challenge <- getLine
  let value = Text.pack challenge
  unless (validChallenge value) (die "fake boundary received an invalid challenge")
  putStrLn ("phase-49:" <> challenge)

checkNegatives :: [StageObservation] -> Text -> FakeBoundaryObservation -> GateRun -> IO ()
checkNegatives observations challenge fake gateRun = do
  let paired =
        [ ("decode-failure", setStage Decode (\row -> row {observedStagePassed = False}) observations, fake, StageFailed Decode)
        , ("stage-inventory", drop 1 observations, fake, StageInventoryMismatch (map observedStage (drop 1 observations)))
        , ("demand-digest", setStage PlanResolve (\row -> row {observedStageDigest = "short"}) observations, fake, StageDigestMalformed PlanResolve)
        , ("provision-identity", duplicateDigest Provision Decode observations, fake, StageDigestCollision)
        ]
  mapM_ (\(label, rows, observedFake, wanted) -> expectLeft label wanted (validateDslBarrier rows (BarrierChallenge challenge) observedFake gateRun)) paired
  expectLeft "fake-argv" FakeArgvMismatch (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeArgv = ["apply"]}) gateRun)
  expectLeft "fake-request" FakeRequestMismatch (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeRequestBytes = "forged"}) gateRun)
  expectLeft "challenge" FakeChallengeMismatch (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeRecoveredChallenge = "stale"}) gateRun)
  expectLeft "dry-run-effect" EffectBeforeFakeApply (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeEffectStage = DryRun}) gateRun)
  expectLeft "self-observer" SelfObservation (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeExternallyObserved = False}) gateRun)
  expectLeft "teardown" FakeTeardownMissing (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeTeardownObserved = False}) gateRun)
  let failedGate = deriveGate (GateDeclaration 49 "phase-49" "amoebius validate phase 49") (GateFailed 9)
  expectLeft "workflow-evidence" WorkflowEvidenceMismatch (validateDslBarrier observations (BarrierChallenge challenge) fake failedGate)
  expectLeft "workflow-balance" WorkflowResourceLeak (validateDslBarrier observations (BarrierChallenge challenge) fake (gateRun {runBalances = False}))
  unless (length expectedNegativeLabels == 12 && length expectedMutantLabels == 12) (die "dsl-barrier-oracle inventory drift")
  unless (length expectedStages == 9 && length (nub expectedStageDigests) == 9) (die "dsl-barrier-oracle stage drift")

setStage :: BarrierStage -> (StageObservation -> StageObservation) -> [StageObservation] -> [StageObservation]
setStage target change = map (\row -> if observedStage row == target then change row else row)

duplicateDigest :: BarrierStage -> BarrierStage -> [StageObservation] -> [StageObservation]
duplicateDigest target source observations = case [observedStageDigest row | row <- observations, observedStage row == source] of
  [digest] -> setStage target (\row -> row {observedStageDigest = digest}) observations
  _ -> observations

expectRight :: String -> Either BarrierProblem () -> IO ()
expectRight label outcome = case outcome of
  Right () -> pure ()
  Left problem -> die ("self-referential-gates-mutant: RED " <> label <> " " <> show problem)

expectLeft :: Text -> BarrierProblem -> Either BarrierProblem () -> IO ()
expectLeft label wanted outcome = case outcome of
  Left actual | actual == wanted -> pure ()
  _ -> die ("self-referential-gates-mutant: RED " <> Text.unpack label <> " expected=" <> show wanted <> " actual=" <> show outcome)

checkOracleIndependence :: IO ()
checkOracleIndependence =
  unless (map show expectedStages == map ("Oracle" <>) (map show ([minBound .. maxBound] :: [BarrierStage])))
    (die "dsl-barrier oracle/subject stage correspondence drift")

validChallenge :: Text -> Bool
validChallenge value =
  Text.length value >= 16
    && Text.all (\character -> character >= '0' && character <= '9' || character >= 'a' && character <= 'z' || character == '-') value
