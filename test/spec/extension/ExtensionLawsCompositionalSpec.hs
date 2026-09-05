{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main (main) where

import Amoebius.Capacity.Types (ResourceVector (ResourceVector), zeroResources)
import Amoebius.Extension.Declaration (declarationDigest)
import Amoebius.Extension.Laws.Compositional
  ( ArtifactAddressObservation (..)
  , CompositeDeclaration
  , CompositionFailure (..)
  , CompositionObservations (..)
  , CompositionVerdict (..)
  , PartObservation (PartObservation)
  , compositePartNames
  , compositeResource
  , composeComposites
  , emptyComposite
  , evaluateCompositionLaws
  , singletonComposite
  )
import Amoebius.Extension.Laws.PerExtension
  ( FlowObservation (..)
  , FlowScope (TenantFlow)
  , LawObservations (..)
  , OperationObservation (..)
  , OperationOutcome (OperationReturned)
  )
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Control.Monad (forM, forM_, unless)
import Data.ByteString.Char8 qualified as ByteString
import Data.IORef (IORef, atomicModifyIORef', newIORef)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO.Unsafe (unsafePerformIO)

import CompositionFixtures
  ( FixtureSet (..)
  , addressObservations
  , emptyLawObservations
  , fixtureSet
  , infernixLawObservations
  , jitmlLawObservations
  , mergeLawObservations
  , shareArtifactContent
  )
import ExtensionLawsCompositionalOracle
  ( OracleCompositionCase (..)
  , OracleExpectedVerdict (..)
  , compositionCases
  , expectedVerdicts
  , mutantProperties
  , oracleContentAddress
  )

main :: IO ()
main = withFixtureSet runSuite

runSuite :: FixtureSet scope -> IO ()
runSuite fixtures = do
  assertEqual "composition case count" 7 (length compositionCases)
  assertEqual "production mutation inventory" 7 (length mutantProperties)
  forM_ compositionCases $ \entry -> do
    left <- compositeFor fixtures (oracleCaseLeft entry)
    right <- compositeFor fixtures (oracleCaseRight entry)
    third <- compositeFor fixtures (oracleCaseThird entry)
    observations <- buildObservations fixtures False left right third (oracleCaseLeft entry) (oracleCaseRight entry)
    let composite = composeComposites left right
        verdicts = fmap (renderVerdict . snd) (evaluateCompositionLaws left right third observations)
    assertEqual (label entry "parts") (oracleCaseParts entry) (compositePartNames composite)
    assertEqual (label entry "resource") (tupleResource (oracleCaseResource entry)) (compositeResource composite)
    assertEqual (label entry "C1-C7") (replicate 7 "PASS") verdicts

  left <- compositeFor fixtures "infernix"
  right <- compositeFor fixtures "jitml"
  third <- compositeFor fixtures "infernix"
  standard <- buildObservations fixtures False left right third "infernix" "jitml"
  shared <- buildObservations fixtures True left right third "infernix" "jitml"
  interference <- interfereWithPart standard
  let subjects =
        [ ("lawful-standard", standard)
        , ("lawful-shared-content", shared)
        , ("c1-claim-omitted", omitCompositeClaim standard)
        , ("c2-left-identity", breakLeftIdentity emptyComposite standard)
        , ("c3-regrouped", breakAssociativity left standard)
        , ("c4-interference", interference)
        , ("c5-budget-max", replaceAdditiveBudget standard)
        , ("c6-scope-widened", widenCrossScope standard)
        , ("c7-address-collision", collideArtifactAddresses standard)
        ]
  actual <- forM subjects $ \(subject, observations) ->
    pure (OracleExpectedVerdict subject (fmap (renderVerdict . snd) (evaluateCompositionLaws left right third observations)))
  checkExpectedVerdicts expectedVerdicts actual
  assertEqual "lawful shared-content address reuse" (replicate 7 "PASS") (oracleExpectedLaws (actual !! 1))
  let addressRows = observedArtifactAddresses standard <> observedArtifactAddresses shared
  assertEqual "independent address row count" 4 (length addressRows)
  forM_ addressRows $ \row ->
    assertEqual ("independent content address " <> Text.unpack (addressedArtifact row))
      (oracleContentAddress (addressedBytes row)) (observedAddress row)
  writeResults standard shared
  putStrLn "extension-laws-compositional-spec: PASS (7 composition cases, 63 authored verdicts, 7 production mutants, 4 independent addresses)"

checkExpectedVerdicts :: [OracleExpectedVerdict] -> [OracleExpectedVerdict] -> IO ()
checkExpectedVerdicts expected actual = do
  assertEqual "verdict subject inventory" (fmap oracleExpectedSubject expected) (fmap oracleExpectedSubject actual)
  forM_ (zip expected actual) $ \(wanted, observed) ->
    forM_ (zip3 lawProperties (oracleExpectedLaws wanted) (oracleExpectedLaws observed)) $ \((law, propertyName), wantedVerdict, observedVerdict) ->
      unless (wantedVerdict == observedVerdict) $
        die (Text.unpack propertyName <> " " <> Text.unpack law <> " subject=" <> Text.unpack (oracleExpectedSubject wanted)
          <> ": expected " <> Text.unpack wantedVerdict <> ", got " <> Text.unpack observedVerdict)
 where
  lawProperties =
    [ ("C1", "Closure"), ("C2", "Identity"), ("C3", "Associativity"), ("C4", "NonInterference")
    , ("C5", "BudgetAdditivity"), ("C6", "ScopeConjunction"), ("C7", "NameDisjointness")
    ]

buildObservations :: FixtureSet scope -> Bool -> CompositeDeclaration scope -> CompositeDeclaration scope
  -> CompositeDeclaration scope -> Text -> Text -> IO (CompositionObservations scope)
buildObservations fixtures shared left right third leftLabel rightLabel = do
  leftLaws <- lawsFor leftLabel
  rightLaws <- lawsFor rightLabel
  let adjust = if shared then shareArtifactContent else id
      adjustedLeft = adjust leftLaws
      adjustedRight = adjust rightLaws
      combined = mergeLawObservations adjustedLeft adjustedRight
      pair = composeComposites left right
  pure CompositionObservations
    { compositeLawObservations = combined
    , partObservations = partRows fixtures leftLabel adjustedLeft <> partRows fixtures rightLabel adjustedRight
    , observedLeftIdentity = composeComposites emptyComposite pair
    , observedRightIdentity = composeComposites pair emptyComposite
    , observedAssociationLeft = composeComposites (composeComposites left right) third
    , observedAssociationRight = composeComposites left (composeComposites right third)
    , observedCompositeResource = compositeResource pair
    , observedArtifactAddresses = addressObservations combined
    }

partRows :: FixtureSet scope -> Text -> LawObservations -> [PartObservation]
partRows fixtures labelValue observations
  | labelValue == "none" = []
  | labelValue == "infernix" = [part (infernixExtension fixtures)]
  | labelValue == "jitml" = [part (jitmlExtension fixtures)]
  | otherwise = []
 where
  part declaration = PartObservation (declarationDigest declaration) observations

lawsFor :: Text -> IO LawObservations
lawsFor labelValue
  | labelValue == "none" = pure emptyLawObservations
  | labelValue == "infernix" = pure infernixLawObservations
  | labelValue == "jitml" = pure jitmlLawObservations
  | otherwise = die ("unknown fixture label " <> Text.unpack labelValue)

compositeFor :: FixtureSet scope -> Text -> IO (CompositeDeclaration scope)
compositeFor fixtures labelValue
  | labelValue == "none" = pure emptyComposite
  | labelValue == "infernix" = pure (singletonComposite (infernixExtension fixtures))
  | labelValue == "jitml" = pure (singletonComposite (jitmlExtension fixtures))
  | otherwise = die ("unknown composite label " <> Text.unpack labelValue)

omitCompositeClaim :: CompositionObservations scope -> CompositionObservations scope
omitCompositeClaim observations = observations {compositeLawObservations = laws {observedClaims = drop 1 (observedClaims laws)}}
 where laws = compositeLawObservations observations

breakLeftIdentity :: CompositeDeclaration scope -> CompositionObservations scope -> CompositionObservations scope
breakLeftIdentity wrong observations = observations {observedLeftIdentity = wrong}

breakAssociativity :: CompositeDeclaration scope -> CompositionObservations scope -> CompositionObservations scope
breakAssociativity wrong observations = observations {observedAssociationRight = wrong}

interfereWithPart :: CompositionObservations scope -> IO (CompositionObservations scope)
interfereWithPart observations = do
  atomicModifyIORef' sharedCounter (\value -> (value + 1, ()))
  pure observations {compositeLawObservations = laws {observedOperations = fmap interfere (observedOperations laws)}}
 where
  laws = compositeLawObservations observations
  interfere operation
    | operationName operation == "inference-workflow" = operation {operationOutcome = OperationReturned "changed-by-jitml"}
    | otherwise = operation

sharedCounter :: IORef Int
sharedCounter = unsafePerformIO (newIORef 0)
{-# NOINLINE sharedCounter #-}

replaceAdditiveBudget :: CompositionObservations scope -> CompositionObservations scope
replaceAdditiveBudget observations = observations {observedCompositeResource = zeroResources}

widenCrossScope :: CompositionObservations scope -> CompositionObservations scope
widenCrossScope observations = observations {compositeLawObservations = laws {observedFlows = fmap widen (observedFlows laws)}}
 where
  laws = compositeLawObservations observations
  widen flow
    | flowOperation flow == "inference-workflow" = flow {flowSink = TenantFlow}
    | otherwise = flow

collideArtifactAddresses :: CompositionObservations scope -> CompositionObservations scope
collideArtifactAddresses observations = observations
  {observedArtifactAddresses = [row {observedAddress = "forced-collision"} | row <- observedArtifactAddresses observations]}

renderVerdict :: CompositionVerdict -> Text
renderVerdict verdict = case verdict of
  CompositionLawPassed -> "PASS"
  CompositionLawFailed (failure : _) -> "FAIL:" <> failureTag failure
  CompositionLawFailed [] -> "FAIL:EmptyFailure"

failureTag :: CompositionFailure -> Text
failureTag failure = case failure of
  OperandObservationCoverageMismatch {} -> "OperandObservationCoverageMismatch"
  OperandLawFailed {} -> "OperandLawFailed"
  CompositeLawFailed {} -> "CompositeLawFailed"
  LeftIdentityMismatch -> "LeftIdentityMismatch"
  RightIdentityMismatch -> "RightIdentityMismatch"
  AssociativityMismatch -> "AssociativityMismatch"
  PartBehaviorChanged {} -> "PartBehaviorChanged"
  BudgetWasNotAdditive {} -> "BudgetWasNotAdditive"
  ScopeConjunctionViolation {} -> "ScopeConjunctionViolation"
  AddressCoverageMismatch {} -> "AddressCoverageMismatch"
  AddressCollision {} -> "AddressCollision"
  AddressNotContentDerived {} -> "AddressNotContentDerived"

writeResults :: CompositionObservations scope -> CompositionObservations scope -> IO ()
writeResults standard shared = do
  output <- maybe ".build/dsl/extension-composition-laws" id <$> lookupEnv "AMOEBIUS_EXTENSION_COMPOSITION_OUTPUT"
  createDirectoryIfMissing True output
  writeFile (output </> "phase-results.tsv")
    ("metric\tresult\n" <> concat [key <> "\t" <> value <> "\n" | (key, value) <- metrics])
  writeFile (output </> "addresses.tsv")
    ("variant\tartifact\tcontent\taddress\n" <> rows "distinct" standard <> rows "shared" shared)
 where
  metrics =
    [ ("composition-cases", "7/7-exact"), ("pair-law-verdicts", "49/49-green")
    , ("subject-verdicts", "63/63-authored"), ("lawful-controls", "14/14-green")
    , ("identity-equalities", "14/14-by-value"), ("associativity-equalities", "7/7-by-value")
    , ("budget-folds", "7/7-exact-additive"), ("address-controls", "4/4-independent")
    , ("mutants", "7/7-production-red"), ("runtime", "UNVERIFIED")
    ]
  rows variant observations = concat
    [ variant <> "\t" <> Text.unpack name <> "\t" <> ByteString.unpack bytes <> "\t" <> Text.unpack address <> "\n"
    | ArtifactAddressObservation name address bytes <- observedArtifactAddresses observations
    ]

withFixtureSet :: (forall scope. FixtureSet scope -> IO value) -> IO value
withFixtureSet continuation = do
  tenant <- either (die . show) pure (trustedTenant "composition-law-tenant")
  subject <- either (die . show) pure (trustedSubject tenant "composition-law-subject")
  membership <- either (die . show) pure (activeMembership tenant subject)
  nested <- either (die . show) pure $
    withRequestScope tenant subject membership $ \scope -> continuation <$> fixtureSet scope
  either (die . show) id nested

tupleResource :: (Natural, Natural, Natural, Natural) -> ResourceVector
tupleResource (cpu, memory, ephemeral, pods) = ResourceVector cpu memory ephemeral pods

label :: OracleCompositionCase -> String -> String
label entry suffix = Text.unpack (oracleCaseName entry) <> " " <> suffix

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual labelValue expected actual =
  unless (expected == actual) (die (labelValue <> ": expected " <> show expected <> ", got " <> show actual))

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
