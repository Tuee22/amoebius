{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE KindSignatures #-}

module Main (main) where

import Amoebius.Calculus.Budget.Admission
  ( Demand (Demand)
  , admit
  , openBudget
  )
import Amoebius.Calculus.Budget.Grant
  ( Bytes (Bytes)
  , Location (Location)
  , Purpose (ArtifactStore)
  , Slots (Slots)
  , allowance
  , issue
  , pool
  )
import Amoebius.Calculus.Budget.Retention
  ( Reaper (EvictionPolicy)
  , reaperTag
  , retain
  , retentionReaper
  )
import Amoebius.Calculus.Evidence.Claim qualified as Evidence
import Amoebius.Calculus.Evidence.Fixture
  ( FixtureKind (Oracle)
  , Strength (SatisfiesAuthoredPredicate)
  , fixture
  , fixturePath
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Extension.Declaration
  ( DeclarationError
  , ExtensionDeclaration
  )
import Amoebius.Extension.Laws.PerExtension
import Amoebius.Scope.Index
  ( RequestScope
  , activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Control.Exception (SomeException, evaluate, try)
import Control.Monad (forM, unless)
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as ByteString.Char8
import Data.List (sort)
import Data.Kind (Type)
import Data.Text (Text)
import Data.Text qualified as Text
import ExtensionLawsPerExtensionOracle qualified as Oracle
import LawFixtures
  ( infernixDeclaration
  , jitmlDeclaration
  , lawfulOperation
  , lawfulRender
  )
import System.Directory (createDirectoryIfMissing)
import System.Environment (getArgs, getEnvironment, getExecutablePath, lookupEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.Process (CreateProcess (env), proc, readCreateProcess)

data FixtureConfig = FixtureConfig
  Text
  Text
  Text
  Text
  Text
  (forall (scope :: Type). RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope))

configExtension :: FixtureConfig -> Text
configExtension (FixtureConfig value _ _ _ _ _) = value

configArtifact :: FixtureConfig -> Text
configArtifact (FixtureConfig _ value _ _ _ _) = value

configBudget :: FixtureConfig -> Text
configBudget (FixtureConfig _ _ value _ _ _) = value

configWorkflow :: FixtureConfig -> Text
configWorkflow (FixtureConfig _ _ _ value _ _) = value

configEvidence :: FixtureConfig -> Text
configEvidence (FixtureConfig _ _ _ _ value _) = value

data OperationCase = OperationCase
  { caseExtension :: Text
  , caseInput :: Text
  , caseExpected :: Text
  }

data Subject = Subject
  { subjectName :: Text
  , subjectConfig :: FixtureConfig
  , subjectObservations :: LawObservations
  }

data ExpectedVerdict = ExpectedVerdict
  { expectedSubject :: Text
  , expectedExtension :: Text
  , expectedLaws :: [Text]
  }
  deriving stock (Eq, Ord, Show)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--render", extension, _seed] -> ByteString.Char8.putStr (lawfulRender (Text.pack extension) "declared-input")
    ["--render-mutant", extension, _seed] -> ambientRender (Text.pack extension) "declared-input" >>= ByteString.Char8.putStr
    [] -> runGreen
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: IO ()
runGreen = do
  let operationCases = [OperationCase extension input expected | Oracle.OracleOperationCase extension input expected <- Oracle.operationCases]
  executable <- getExecutablePath
  subjects <- buildSubjects executable operationCases
  let expected = [ExpectedVerdict subject extension laws | Oracle.OracleVerdict subject extension laws <- Oracle.expectedVerdicts]
  actual <- forM subjects evaluateSubject
  assertEqual "seven law subjects" 7 (length subjects)
  mapM_ (checkExpected actual) expected
  assertEqual "authored per-law verdict table" (sort expected) (sort actual)
  assertEqual "two lawful subjects" 2 (length (filter (all (== "PASS") . expectedLaws) actual))
  assertEqual "five single-law defects" 5 (length (filter singleFailure actual))
  output <- maybe ".build/dsl/extension-laws" id <$> lookupEnv "AMOEBIUS_EXTENSION_LAWS_OUTPUT"
  writeResults output
  putStrLn "extension-laws-per-extension-spec: PASS (7 subjects, 35 verdicts, 6 generated inputs, 5 single-law defects)"

configs :: [FixtureConfig]
configs =
  [ FixtureConfig "infernix" "infernix-image" "inference-budget" "inference-workflow" "inference-evidence" infernixDeclaration
  , FixtureConfig "jitml" "jitml-model" "training-budget" "training-workflow" "training-evidence" jitmlDeclaration
  ]

buildSubjects :: FilePath -> [OperationCase] -> IO [Subject]
buildSubjects executable cases = do
  baselines <- forM configs $ \config -> do
    observations <- baselineObservations executable cases config
    pure (config, observations)
  infernix <- lookupBaseline "infernix" baselines
  jitml <- lookupBaseline "jitml" baselines
  partial <- l1Partial (fst infernix) (snd infernix)
  ambient <- l2Ambient executable (fst infernix) (snd infernix)
  pure
    [ Subject "infernix-lawful" (fst infernix) (snd infernix)
    , Subject "jitml-lawful" (fst jitml) (snd jitml)
    , Subject "l1-partial" (fst infernix) partial
    , Subject "l2-ambient-render" (fst infernix) ambient
    , Subject "l3-reaper-omitted" (fst infernix) (l3ReaperOmitted (snd infernix))
    , Subject "l4-scope-widened" (fst infernix) (l4ScopeWidened (snd infernix))
    , Subject "l5-fixture-omitted" (fst infernix) (l5FixtureOmitted (snd infernix))
    ]

lookupBaseline :: Text -> [(FixtureConfig, LawObservations)] -> IO (FixtureConfig, LawObservations)
lookupBaseline wanted values = case filter ((== wanted) . configExtension . fst) values of
  [found] -> pure found
  _ -> die ("missing or duplicate baseline " <> Text.unpack wanted)

baselineObservations :: FilePath -> [OperationCase] -> FixtureConfig -> IO LawObservations
baselineObservations executable cases config = do
  operations <- forM (filter ((== configExtension config) . caseExtension) cases) $ \entry -> do
    outcome <- observeOperation (lawfulOperation (configExtension config) (caseInput entry))
    assertEqual ("operation oracle " <> Text.unpack (caseExtension entry) <> "/" <> Text.unpack (caseInput entry))
      (OperationReturned (caseExpected entry)) outcome
    pure (OperationObservation (configWorkflow config) (caseInput entry) outcome)
  first <- seededRender executable "--render" (configExtension config) "seed-a"
  second <- seededRender executable "--render" (configExtension config) "seed-b"
  budget <- actualBudgetObservation config
  claimObservation <- actualClaimObservation config
  pure
    LawObservations
      { observedOperations = operations
      , observedArtifacts = [ArtifactObservation (configArtifact config) first second]
      , observedBudgets = [budget]
      , observedFlows = [FlowObservation (configWorkflow config) RequestFlow RequestFlow]
      , observedClaims = [claimObservation]
      }

observeOperation :: OperationOutcome -> IO OperationOutcome
observeOperation outcome = do
  result <- try (evaluate (forceOutcome outcome))
  case result of
    Left problem -> pure (OperationEscaped (Text.pack (show (problem :: SomeException))))
    Right value -> pure value

forceOutcome :: OperationOutcome -> OperationOutcome
forceOutcome outcome = case outcome of
  OperationReturned value -> Text.length value `seq` outcome
  OperationRefused value -> Text.length value `seq` outcome
  OperationEscaped value -> Text.length value `seq` outcome

seededRender :: FilePath -> String -> Text -> String -> IO ByteString
seededRender executable mode extension seed = do
  inherited <- getEnvironment
  let seeded = ("AMOEBIUS_EXTENSION_LAW_SEED", seed) : filter ((/= "AMOEBIUS_EXTENSION_LAW_SEED") . fst) inherited
      command = (proc executable [mode, Text.unpack extension, seed]) {env = Just seeded}
  ByteString.Char8.pack <$> readCreateProcess command ""

actualBudgetObservation :: FixtureConfig -> IO BudgetObservation
actualBudgetObservation config = do
  let location = Location (configExtension config <> "-store")
      bound = allowance (Bytes 4) (Slots 2) (Bytes 2)
      source = pool location (Bytes 4) (Slots 2)
      demand = Demand location ArtifactStore (Bytes 2)
  (grant, _reduced) <- either (die . show) pure (issue source ArtifactStore bound)
  (_firstReservation, afterFirst) <- either (die . show) pure (admit (openBudget grant) demand)
  (_secondReservation, afterSecond) <- either (die . show) pure (admit afterFirst demand)
  exhaustion <- case admit afterSecond demand of
    Left _ -> pure RefusedBeforeMaterialization
    Right _ -> pure MaterializedBeforeRefusal
  retained <- either (die . show) pure (retain grant (Bytes 2) (EvictionPolicy "law-fixture"))
  pure
    BudgetObservation
      { budgetArtifact = configArtifact config
      , budgetComponent = configBudget config
      , budgetExhaustion = exhaustion
      , budgetRetention = RetainedWithReaper (reaperTag (retentionReaper retained))
      }

actualClaimObservation :: FixtureConfig -> IO ClaimObservation
actualClaimObservation config = do
  discharge <- maybe (die "oracle fixture path was refused") pure
    (fixture Oracle "test/spec/extension/ExtensionLawsPerExtensionOracle.hs" PureRegister)
  bound <- either (die . show) pure
    (Evidence.claim (configEvidence config) discharge SatisfiesAuthoredPredicate)
  pure
    ClaimObservation
      { claimName = configEvidence config
      , claimFixture = FixturePassedAtPinnedReason (fixturePath (Evidence.claimFixture bound))
      }

l1Partial :: FixtureConfig -> LawObservations -> IO LawObservations
l1Partial config baseline = do
  outcome <- observeOperation (partialOperation "panic")
  pure baseline
    { observedOperations =
        [ if operationInput row == "panic"
            then OperationObservation (configWorkflow config) "panic" outcome
            else row
        | row <- observedOperations baseline
        ]
    }

l2Ambient :: FilePath -> FixtureConfig -> LawObservations -> IO LawObservations
l2Ambient executable config baseline = do
  first <- seededRender executable "--render-mutant" (configExtension config) "seed-a"
  second <- seededRender executable "--render-mutant" (configExtension config) "seed-b"
  pure baseline {observedArtifacts = [ArtifactObservation (configArtifact config) first second]}

partialOperation :: Text -> OperationOutcome
partialOperation input
  | input == "panic" = error "partial extension operation"
  | otherwise = OperationReturned input

ambientRender :: Text -> Text -> IO ByteString
ambientRender extension input = do
  seed <- lookupEnv "AMOEBIUS_EXTENSION_LAW_SEED"
  pure (ByteString.Char8.pack (Text.unpack (extension <> ":artifact:" <> input <> ":" <> Text.pack (show seed))))

l3ReaperOmitted :: LawObservations -> LawObservations
l3ReaperOmitted baseline = baseline
  { observedBudgets =
      [budget {budgetRetention = RetainedWithoutReaper} | budget <- observedBudgets baseline]
  }

l4ScopeWidened :: LawObservations -> LawObservations
l4ScopeWidened baseline = baseline
  { observedFlows =
      [flow {flowSink = TenantFlow} | flow <- observedFlows baseline]
  }

l5FixtureOmitted :: LawObservations -> LawObservations
l5FixtureOmitted baseline = baseline
  { observedClaims =
      [claimObservation {claimFixture = FixtureMissing} | claimObservation <- observedClaims baseline]
  }

evaluateSubject :: Subject -> IO ExpectedVerdict
evaluateSubject subject = do
  verdicts <- withDeclaration (subjectConfig subject) $ \declaration ->
    evaluateLaws declaration (subjectObservations subject)
  pure
    ExpectedVerdict
      { expectedSubject = subjectName subject
      , expectedExtension = configExtension (subjectConfig subject)
      , expectedLaws = fmap (renderVerdict . snd) verdicts
      }

withDeclaration
  :: FixtureConfig
  -> (forall (scope :: Type). ExtensionDeclaration scope -> value)
  -> IO value
withDeclaration (FixtureConfig extension _artifact _budget _workflow _evidence build) continuation = do
  tenant <- either (die . show) pure (trustedTenant (extension <> "-law-tenant"))
  subject <- either (die . show) pure (trustedSubject tenant (extension <> "-law-subject"))
  membership <- either (die . show) pure (activeMembership tenant subject)
  nested <- either (die . show) pure $ withRequestScope tenant subject membership $ \scope ->
    continuation <$> build scope
  either (die . show) pure nested

renderVerdict :: LawVerdict -> Text
renderVerdict verdict = case verdict of
  LawPassed -> "PASS"
  LawFailed (failure : _rest) -> "FAIL:" <> failureTag failure
  LawFailed [] -> "FAIL:EmptyFailure"

failureTag :: LawFailure -> Text
failureTag failure = case failure of
  OperationCoverageMismatch {} -> "OperationCoverageMismatch"
  OperationEscapedFailure {} -> "OperationEscaped"
  ArtifactCoverageMismatch {} -> "ArtifactCoverageMismatch"
  ArtifactBytesDiffer {} -> "ArtifactBytesDiffer"
  BudgetCoverageMismatch {} -> "BudgetCoverageMismatch"
  UnknownBudgetComponent {} -> "UnknownBudgetComponent"
  ExhaustionDidNotRefuseBeforeMaterialization {} -> "ExhaustionDidNotRefuseBeforeMaterialization"
  RetainedOutputHasNoReaper {} -> "RetainedOutputHasNoReaper"
  FlowCoverageMismatch {} -> "FlowCoverageMismatch"
  ScopeWasWidened {} -> "ScopeWasWidened"
  ClaimCoverageMismatch {} -> "ClaimCoverageMismatch"
  ClaimHasNoFixture {} -> "ClaimHasNoFixture"
  ClaimFixtureMissedPinnedReason {} -> "ClaimFixtureMissedPinnedReason"

checkExpected :: [ExpectedVerdict] -> ExpectedVerdict -> IO ()
checkExpected actual expected = case filter ((== expectedSubject expected) . expectedSubject) actual of
  [observed] -> unless (expected == observed) $ do
    let mismatches = [property | (wanted, got, property) <- zip3 (expectedLaws expected) (expectedLaws observed) lawProperties, wanted /= got]
    die (Text.unpack (Text.intercalate "," mismatches) <> ": expected " <> show expected <> ", got " <> show observed)
  _ -> die ("LawSubjectDiscovery: missing or duplicate " <> Text.unpack (expectedSubject expected))
 where lawProperties = ["Totality", "Determinism", "BudgetHonesty", "ScopePropagation", "EvidenceBinding"]

writeResults :: FilePath -> IO ()
writeResults output = do
  let metrics =
        [ ("subjects", "7/7-exact")
        , ("law-verdicts", "35/35-authored")
        , ("lawful-verdicts", "10/10-green")
        , ("single-law-defects", "5/5-exact")
        , ("generated-operation-inputs", "6/6-total")
        , ("independent-process-renders", "2/2-byte-identical")
        , ("budget-protocols", "2/2-refuse-before-materialization-with-reaper")
        , ("evidence-values", "2/2-claim-fixture-bound")
        , ("runtime", "UNVERIFIED")
        ]
  createDirectoryIfMissing True output
  writeFile (output </> "phase-results.tsv")
    ("metric\tresult\n" <> concat [key <> "\t" <> value <> "\n" | (key, value) <- metrics])

singleFailure :: ExpectedVerdict -> Bool
singleFailure verdict = length (filter (/= "PASS") (expectedLaws verdict)) == 1

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
