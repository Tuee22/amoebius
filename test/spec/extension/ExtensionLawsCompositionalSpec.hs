{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main (main) where

import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Extension.Declaration
  ( declarationDigest
  )
import Amoebius.Extension.Laws.Compositional
  ( CompositeDeclaration
  , ArtifactAddressObservation (..)
  , CompositionFailure (..)
  , CompositionObservations (..)
  , CompositionVerdict (..)
  , PartObservation (PartObservation)
  , compositePartNames
  , compositeResource
  , composeComposites
  , compositionLawPassed
  , compositionLawTag
  , emptyComposite
  , evaluateCompositionLaws
  , singletonComposite
  )
import Amoebius.Extension.Laws.PerExtension (LawObservations)
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Control.Monad (forM, forM_, unless)
import Data.ByteString.Char8 qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)
import System.Directory (createDirectoryIfMissing, getCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))

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
import ExtensionCompositionMutants
  ( breakAssociativity
  , breakLeftIdentity
  , collideArtifactAddresses
  , interfereWithPart
  , omitCompositeClaim
  , replaceAdditiveBudget
  , widenCrossScope
  )

data CompositionCase = CompositionCase
  { caseName :: Text
  , caseLeft :: Text
  , caseRight :: Text
  , caseThird :: Text
  , caseParts :: [Text]
  , caseResource :: ResourceVector
  }
  deriving stock (Eq, Show)

data ExpectedVerdict = ExpectedVerdict
  { expectedSubject :: Text
  , expectedLaws :: [Text]
  }
  deriving stock (Eq, Show)

main :: IO ()
main = do
  arguments <- getArgs
  root <- getCurrentDirectory
  cases <- loadCompositionCases root
  expected <- loadExpectedVerdicts root
  withFixtureSet $ \fixtures -> do
    case arguments of
      [argument] | "--mutant=" `prefixOf` argument ->
        runMutant fixtures (dropPrefix "--mutant=" argument)
      [] -> runSuite root fixtures cases expected
      _arguments -> die "expected no arguments or --mutant=<name>"

runSuite :: FilePath -> FixtureSet scope -> [CompositionCase] -> [ExpectedVerdict] -> IO ()
runSuite root fixtures cases expected = do
  assertEqual "composition case count" 7 (length cases)
  forM_ cases $ \entry -> do
    left <- compositeFor fixtures (caseLeft entry)
    right <- compositeFor fixtures (caseRight entry)
    third <- compositeFor fixtures (caseThird entry)
    observations <- buildObservations fixtures False left right third (caseLeft entry) (caseRight entry)
    let composite = composeComposites left right
        verdicts = evaluateCompositionLaws left right third observations
    assertEqual (label entry "parts") (caseParts entry) (compositePartNames composite)
    assertEqual (label entry "resource") (caseResource entry) (compositeResource composite)
    assertEqual (label entry "C1-C7") [True, True, True, True, True, True, True]
      (fmap (compositionLawPassed . snd) verdicts)

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
    pure (ExpectedVerdict subject (fmap (renderVerdict . snd) (evaluateCompositionLaws left right third observations)))
  assertEqual "authored C-law verdict table" expected actual
  case actual of
    _standard : sharedResult : _rest ->
      assertEqual "lawful shared-content address reuse" (replicate 7 "PASS") (expectedLaws sharedResult)
    _other -> die "authored verdict result omitted shared-content control"
  writeResults root standard shared
  putStrLn "extension-laws-compositional-spec: PASS (7 composition cases, 63 authored verdicts, 7 exact mutants)"

buildObservations
  :: FixtureSet scope
  -> Bool
  -> CompositeDeclaration scope
  -> CompositeDeclaration scope
  -> CompositeDeclaration scope
  -> Text
  -> Text
  -> IO (CompositionObservations scope)
buildObservations fixtures shared left right third leftLabel rightLabel = do
  leftLaws <- lawsFor leftLabel
  rightLaws <- lawsFor rightLabel
  let adjust = if shared then shareArtifactContent else id
      adjustedLeft = adjust leftLaws
      adjustedRight = adjust rightLaws
      combined = mergeLawObservations adjustedLeft adjustedRight
      pair = composeComposites left right
      parts = partRows fixtures leftLabel adjustedLeft <> partRows fixtures rightLabel adjustedRight
  pure
    CompositionObservations
      { compositeLawObservations = combined
      , partObservations = parts
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

runMutant :: FixtureSet scope -> String -> IO ()
runMutant fixtures mutant = do
  left <- compositeFor fixtures "infernix"
  right <- compositeFor fixtures "jitml"
  third <- compositeFor fixtures "infernix"
  baseline <- buildObservations fixtures False left right third "infernix" "jitml"
  interference <- interfereWithPart baseline
  let (propertyName, wanted, mutated) = case mutant of
        "claim-omitted" -> ("Closure", ["C1"], omitCompositeClaim baseline)
        "left-identity-broken" -> ("Identity", ["C2"], breakLeftIdentity emptyComposite baseline)
        "associativity-regrouped" -> ("Associativity", ["C3"], breakAssociativity left baseline)
        "shared-state-interference" -> ("NonInterference", ["C4"], interference)
        "budget-max-not-sum" -> ("BudgetAdditivity", ["C5"], replaceAdditiveBudget baseline)
        "cross-scope-widened" -> ("ScopeConjunction", ["C1", "C4", "C6"], widenCrossScope baseline)
        "artifact-address-collision" -> ("NameDisjointness", ["C7"], collideArtifactAddresses baseline)
        _unknown -> ("unknown", [], baseline)
      failed =
        [ Text.unpack (compositionLawTag law)
        | (law, verdict) <- evaluateCompositionLaws left right third mutated
        , not (compositionLawPassed verdict)
        ]
  if failed == wanted
    then do
      putStrLn ("extension-composition-mutant: RED " <> mutant <> " " <> propertyName)
      exitFailure
    else die ("mutant did not redden exact laws: expected " <> show wanted <> ", got " <> show failed)

renderVerdict :: CompositionVerdict -> Text
renderVerdict verdict = case verdict of
  CompositionLawPassed -> "PASS"
  CompositionLawFailed (failure : _rest) -> "FAIL:" <> failureTag failure
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

loadCompositionCases :: FilePath -> IO [CompositionCase]
loadCompositionCases root = do
  rows <- rowsOf (root </> "test/oracle/extension_laws/composition_cases.tsv")
  case rows of
    header : body -> do
      assertEqual "composition table header"
        ["case", "left", "right", "third", "parts", "cpu", "memory", "ephemeral", "pods"] header
      forM body $ \row -> case row of
        [name, left, right, third, parts, cpu, memory, ephemeral, pods] ->
          pure
            CompositionCase
              { caseName = name
              , caseLeft = left
              , caseRight = right
              , caseThird = third
              , caseParts = if parts == "-" then [] else Text.splitOn "," parts
              , caseResource = ResourceVector (number cpu) (number memory) (number ephemeral) (number pods)
              }
        _row -> die ("invalid composition row: " <> show row)
    [] -> die "empty composition case oracle"

loadExpectedVerdicts :: FilePath -> IO [ExpectedVerdict]
loadExpectedVerdicts root = do
  rows <- rowsOf (root </> "test/oracle/extension_laws/composition_law_verdicts.tsv")
  case rows of
    header : body -> do
      assertEqual "composition verdict header" ["subject", "C1", "C2", "C3", "C4", "C5", "C6", "C7"] header
      forM body $ \row -> case row of
        subject : laws | length laws == 7 -> pure (ExpectedVerdict subject laws)
        _row -> die ("invalid composition verdict row: " <> show row)
    [] -> die "empty composition verdict oracle"

number :: Text -> Natural
number = read . Text.unpack

writeResults :: FilePath -> CompositionObservations scope -> CompositionObservations scope -> IO ()
writeResults root standard shared = do
  let output = root </> ".build/dsl/extension-composition-laws"
      metrics =
        [ ("composition-cases", "7/7-exact")
        , ("pair-law-verdicts", "49/49-green")
        , ("subject-verdicts", "63/63-authored")
        , ("lawful-controls", "14/14-green")
        , ("identity-equalities", "14/14-by-value")
        , ("associativity-equalities", "7/7-by-value")
        , ("budget-folds", "7/7-exact-additive")
        , ("address-controls", "distinct-and-shared-green/collision-red")
        , ("mutants", "7/7-red-exactly")
        , ("runtime", "UNVERIFIED")
        ]
  createDirectoryIfMissing True output
  writeFile (output </> "phase-results.tsv")
    ("metric\tresult\n" <> concat [key <> "\t" <> value <> "\n" | (key, value) <- metrics])
  writeFile (output </> "addresses.tsv")
    ("variant\tartifact\tcontent\taddress\n" <> rows "distinct" standard <> rows "shared" shared)
 where
  rows variant observations = concat
    [ variant <> "\t" <> Text.unpack artifactName <> "\t" <> ByteString.unpack bytes <> "\t" <> Text.unpack address <> "\n"
    | ArtifactAddressObservation artifactName address bytes <- observedArtifactAddresses observations
    ]

withFixtureSet :: (forall scope. FixtureSet scope -> IO value) -> IO value
withFixtureSet continuation = do
  tenant <- either (die . show) pure (trustedTenant "composition-law-tenant")
  subject <- either (die . show) pure (trustedSubject tenant "composition-law-subject")
  membership <- either (die . show) pure (activeMembership tenant subject)
  nested <- either (die . show) pure $ withRequestScope tenant subject membership $ \scope ->
    continuation <$> fixtureSet scope
  either (die . show) id nested

rowsOf :: FilePath -> IO [[Text]]
rowsOf path = map (Text.splitOn "\t") . filter (not . Text.null) . Text.lines . Text.pack <$> readFile path

label :: CompositionCase -> String -> String
label entry suffix = Text.unpack (caseName entry) <> " " <> suffix

prefixOf :: String -> String -> Bool
prefixOf prefix value = take (length prefix) value == prefix

dropPrefix :: String -> String -> String
dropPrefix prefix value = drop (length prefix) value

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual labelValue expected actual =
  unless (expected == actual) (die (labelValue <> ": expected " <> show expected <> ", got " <> show actual))

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
