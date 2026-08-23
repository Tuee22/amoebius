{-# LANGUAGE OverloadedStrings #-}

module LegacyOracle
  ( runLegacyOracle
  ) where

-- Component diagnostics only. Expected values are stated independently of
-- production enumeration and rendering. This is not harness qualification,
-- human correspondence review, phase validation, or promotion evidence.

import Amoebius.Validation.Legacy
import Amoebius.Validation.PolicyContract (PhaseOrdinal, mkPhaseOrdinal, phaseOrdinalNumber)
import Amoebius.Validation.SourceClosure
import Amoebius.Validation.Types (CheckResult (..), Finding (..))
import Control.Monad (unless)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.List (nub)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

runLegacyOracle :: IO ()
runLegacyOracle =
  finishDiagnostics
    "LegacyOracle"
    ( inventoryProblems
        <> dispatchProblems
        <> malformedBindingProblems
        <> sourceBindingProblems
        <> registerProblems
        <> markdownInertnessProblems
    )

data ExpectedBinding = ExpectedBinding
  { expectedId :: LegacyId
  , expectedEncoding :: Text
  , expectedOwner :: Int
  , expectedAnalyzer :: LegacyAnalyzer
  , expectedObservation :: LegacyObservationRule
  , expectedClosure :: LegacyClosureRule
  , expectedReintroduction :: NonEmpty LegacyReintroductionCase
  }
  deriving (Eq, Show)

expectedBindings :: [ExpectedBinding]
expectedBindings =
  [ expected LtdSrc000 "LTD-SRC-000" 0 AnalyzeCompleteSourceGrammar ObserveCompleteSourceSnapshot CloseCompleteSourceGrammar RejectDisguisedOrConcealedSource
  , expected LtdSrc001 "LTD-SRC-001" 47 (AnalyzeSourceFamily SourceTools) (ObserveExactSourceFamily SourceTools) (CloseSourceFamily SourceTools) RejectTrackedToolsSource
  , expected LtdSrc002 "LTD-SRC-002" 25 (AnalyzeSourceFamily SourceDhall) (ObserveExactSourceFamily SourceDhall) (CloseSourceFamily SourceDhall) RejectTrackedDhallOrTsv
  , expected LtdSrc003 "LTD-SRC-003" 26 (AnalyzeSourceFamily SourceProto) (ObserveExactSourceFamily SourceProto) (CloseSourceFamily SourceProto) RejectTrackedProto
  , expected LtdSrc004 "LTD-SRC-004" 46 (AnalyzeSourceFamily SourceUi) (ObserveExactSourceFamily SourceUi) (CloseSourceFamily SourceUi) RejectTrackedUiSource
  , expected LtdSrc005 "LTD-SRC-005" 47 (AnalyzeSourceFamily SourcePulumi) (ObserveExactSourceFamily SourcePulumi) (CloseSourceFamily SourcePulumi) RejectTrackedPulumiSource
  , expected LtdSrc006 "LTD-SRC-006" 47 (AnalyzeSourceFamily SourceTest) (ObserveExactSourceFamily SourceTest) (CloseSourceFamily SourceTest) RejectTrackedBehavioralTestInput
  , expected LtdSrc007 "LTD-SRC-007" 1 (AnalyzeSourceFamily SourceProbe) (ObserveExactSourceFamily SourceProbe) (CloseSourceFamily SourceProbe) RejectTrackedProbeDebt
  , expected LtdSrc008 "LTD-SRC-008" 0 (AnalyzeSourceFamily SourcePb) (ObserveExactSourceFamily SourcePb) (CloseSourceFamily SourcePb) RejectWidenedPbBehavior
  , expected LtdSrc009 "LTD-SRC-009" 1 (AnalyzeSourceFamily SourceVendor) (ObserveExactSourceFamily SourceVendor) (CloseSourceFamily SourceVendor) RejectTopLevelVendorDebt
  , expected LtdMeta001 "LTD-META-001" 2 AnalyzeRetiredIgnoreRules ObserveParsedIgnoreGrammars CloseRetiredIgnoreRules RejectRetiredIgnoreRule
  , expected LtdVal001 "LTD-VAL-001" 0 AnalyzeValidationProtocol ObserveValidationAuthorityGraph CloseValidationProtocol RejectNonHaskellValidationAuthority
  , expected LtdVal002 "LTD-VAL-002" 0 AnalyzePhaseContracts ObserveTypedPhaseContractCustody ClosePhaseContracts RejectUnboundPhaseContract
  , expected LtdVal003 "LTD-VAL-003" 0 AnalyzeStatusEvidence ObserveStatusEvidenceProjection CloseStatusEvidence RejectForgedStatusEvidence
  , expected LtdVal004 "LTD-VAL-004" 0 AnalyzeHumanPromotion ObservePromotionTrustRoot CloseHumanPromotion RejectAutomatedPromotion
  , expected LtdVal005 "LTD-VAL-005" 49 AnalyzeHardwareFreeDsl ObserveHardwareFreeDslTrace CloseHardwareFreeDsl RejectHardwareBeforeDslPromotion
  , expected LtdVal006 "LTD-VAL-006" 47 AnalyzeRunInputClosure ObserveRunInputProvenance CloseRunInputClosure RejectAmbientOrStaleRunInput
  , expected LtdDoc001 "LTD-DOC-001" 27 AnalyzeBehavioralDocumentConsumers ObserveDocumentConsumerGraph CloseBehavioralDocumentConsumers RejectBehavioralMarkdownConsumer
  , expected LtdName001 "LTD-NAME-001" 2 AnalyzePhaseOrdinalNames ObserveRuntimeIdentityGraph ClosePhaseOrdinalNames RejectRuntimePhaseOrdinal
  , expected LtdHost001 "LTD-HOST-001" 51 AnalyzeHostEnsure ObserveHostEnsureCallGraph CloseHostEnsure RejectBypassedHostEnsure
  , expected LtdHost002 "LTD-HOST-002" 51 AnalyzeAmbientHostPaths ObserveHostPathEffectGraph CloseAmbientHostPaths RejectAmbientHostPath
  , expected LtdImg001 "LTD-IMG-001" 56 AnalyzeNaturalArchitectureImages ObserveImagePlanAndBinfmt CloseNaturalArchitectureImages RejectCrossArchitectureImagePlan
  , expected LtdRun001 "LTD-RUN-001" 55 AnalyzeExecutableIdentity ObserveCabalExecutableGraph CloseExecutableIdentity RejectSecondExecutableIdentity
  , expected LtdSeed001 "LTD-SEED-001" 91 AnalyzeInfernixSeedDependency ObserveInfernixDependencyGraph CloseInfernixSeedDependency RejectInfernixSeedDependency
  , expected LtdSeed002 "LTD-SEED-002" 93 AnalyzeJitMlSeedDependency ObserveJitMlDependencyGraph CloseJitMlSeedDependency RejectJitMlSeedDependency
  ]
 where
  expected identifier encoding owner analyzer observed closed reintroduced =
    ExpectedBinding identifier encoding owner analyzer observed closed (reintroduced :| [])

inventoryProblems :: [String]
inventoryProblems =
  concat
    [ expectEqual "closed LegacyId constructor universe" expectedIds ([minBound .. maxBound] :: [LegacyId])
    , expectEqual "canonical allLegacyIds projection" expectedIds allLegacyIds
    , expectEqual "stable encodings are unique" (length expectedEncodings) (length (nub (map renderLegacyId expectedIds)))
    , concatMap checkBinding expectedBindings
    ]
 where
  expectedIds = map expectedId expectedBindings
  expectedEncodings = map expectedEncoding expectedBindings
  checkBinding item =
    let identifier = expectedId item
        encoding = expectedEncoding item
        binding = legacyBinding identifier
     in concat
          [ expectEqual (label item "stable encoding") encoding (renderLegacyId identifier)
          , expectEqual (label item "parse roundtrip") (Just identifier) (parseLegacyId encoding)
          , expectEqual (label item "owner") (expectedOwner item) (phaseOrdinalNumber (legacyIdOwner identifier))
          , expectEqual (label item "disposition") LegacyActive (legacyIdDisposition identifier)
          , expectEqual (label item "analyzer") (expectedAnalyzer item) (legacyIdAnalyzer identifier)
          , expectEqual (label item "observation") (expectedObservation item) (legacyIdObservationRule identifier)
          , expectEqual (label item "closure") (expectedClosure item) (legacyIdClosureRule identifier)
          , expectEqual (label item "reintroduction") (expectedReintroduction item) (legacyIdReintroductionCases identifier)
          , expectEqual (label item "record ID") identifier (legacyBindingId binding)
          , expectEqual (label item "record disposition") LegacyActive (legacyBindingDisposition binding)
          , expectEqual (label item "record owner") (BindingPresent (legacyIdOwner identifier)) (legacyBindingOwner binding)
          , expectEqual (label item "record analyzer") (BindingPresent (expectedAnalyzer item)) (legacyBindingAnalyzer binding)
          , expectEqual (label item "record observation") (BindingPresent (expectedObservation item)) (legacyBindingObservation binding)
          , expectEqual (label item "record closure") (BindingPresent (expectedClosure item)) (legacyBindingClosure binding)
          , expectEqual (label item "record reintroduction") (BindingPresent (expectedReintroduction item)) (legacyBindingReintroduction binding)
          ]

dispatchProblems :: [String]
dispatchProblems = concatMap checkDispatch expectedBindings
 where
  checkDispatch item =
    let identifier = expectedId item
        owner = expectedOwner item
        analyzer = expectedAnalyzer item
        binding = legacyBinding identifier
        before = applyLegacyObservedState (owner - 1) binding (LegacyObserverUnavailable analyzer)
        atOwner = applyLegacyObservedState owner binding (LegacyObserverUnavailable analyzer)
        activeZero = applyLegacyObservedState (owner - 1) binding LegacyObservedZero
        retired = binding {legacyBindingDisposition = LegacyRetired}
        retiredZero = applyLegacyObservedState owner retired LegacyObservedZero
        retiredOpen = applyLegacyObservedState owner retired (LegacyObservedOpen 1 "independent-reintroduction-digest")
        expectedUnavailableDetail =
          expectedEncoding item
            <> " requires "
            <> Text.pack (show analyzer)
            <> " at owner Phase "
            <> Text.pack (show owner)
            <> "; no typed raw observation was supplied"
     in concat
          [ expectNoCodeAt (label item "before-owner unavailable is accounted debt") "LEGACY-ANALYZER-UNAVAILABLE" (subject item) before
          , expectExactFinding (label item "owner unavailable refuses") "LEGACY-ANALYZER-UNAVAILABLE" (subject item) expectedUnavailableDetail atOwner
          , expectCodeAt (label item "Active zero needs transition") "LEGACY-ACTIVE-TRANSITION-UNRECORDED" (subject item) activeZero
          , expectEqual (label item "Retired zero has no finding") [] (checkFindings retiredZero)
          , expectCodeAt (label item "Retired open is reintroduced") "LEGACY-REINTRODUCED" (subject item) retiredOpen
          ]

malformedBindingProblems :: [String]
malformedBindingProblems =
  concat
    [ malformed "missing owner" "LEGACY-OWNER-BINDING-MISSING" (base {legacyBindingOwner = BindingMissing})
    , malformed "redirected owner" "LEGACY-OWNER-BINDING-MISMATCH" (base {legacyBindingOwner = BindingPresent phaseOne})
    , malformed "missing analyzer" "LEGACY-ANALYZER-BINDING-MISSING" (base {legacyBindingAnalyzer = BindingMissing})
    , malformed "redirected analyzer" "LEGACY-ANALYZER-BINDING-MISMATCH" (base {legacyBindingAnalyzer = BindingPresent AnalyzeHumanPromotion})
    , malformed "missing observation" "LEGACY-OBSERVATION-BINDING-MISSING" (base {legacyBindingObservation = BindingMissing})
    , malformed "redirected observation" "LEGACY-OBSERVATION-BINDING-MISMATCH" (base {legacyBindingObservation = BindingPresent ObservePromotionTrustRoot})
    , malformed "missing closure" "LEGACY-CLOSURE-BINDING-MISSING" (base {legacyBindingClosure = BindingMissing})
    , malformed "redirected closure" "LEGACY-CLOSURE-BINDING-MISMATCH" (base {legacyBindingClosure = BindingPresent CloseHumanPromotion})
    , malformed "missing reintroduction" "LEGACY-REINTRODUCTION-BINDING-MISSING" (base {legacyBindingReintroduction = BindingMissing})
    , malformed
        "redirected reintroduction"
        "LEGACY-REINTRODUCTION-BINDING-MISMATCH"
        (base {legacyBindingReintroduction = BindingPresent (RejectAutomatedPromotion :| [])})
    ]
 where
  base = legacyBinding LtdVal001
  phaseOne = requirePhase 1
  malformed caseLabel code binding =
    expectCodeAt caseLabel code "Amoebius.Validation.Legacy/LTD-VAL-001" (applyLegacyObservedState 0 binding (LegacyObserverUnavailable AnalyzeValidationProtocol))

expectedSourceCases :: [(LegacyId, SourceDebtId, Int, Text)]
expectedSourceCases =
  [ (LtdSrc001, SourceTools, 237, "b756b203049bb59e62bd9795b5a36e37840e8599b28b01c2bf3aa8c41cf3e534")
  , (LtdSrc002, SourceDhall, 279, "633e2198ba565cab862fad019fc9de2e7cbe784d7c781468e911322b4d0bed31")
  , (LtdSrc003, SourceProto, 1, "ad6293590c8d79e1fe385497bd891d2d7351a46f8f34907e12cef4b46eafca1e")
  , (LtdSrc004, SourceUi, 16, "d5c12f81a7f91385b460824539aabd94c0c3e1885ef8ddf2ec9190ee12d5d05d")
  , (LtdSrc005, SourcePulumi, 1, "b5e5b10785f0d371b3cfa9ff4d9e5dd25360677c3c5d8415475ba61c50855982")
  , (LtdSrc006, SourceTest, 890, "1080ced8d4adc45eb3368cd61e4bdb84a68ddd4b2c24179c6975f085672c3899")
  , (LtdSrc007, SourceProbe, 7, "233dfc3539480eacc10e4e5c284d69893c31c93975fc7945670424751d961800")
  , (LtdSrc008, SourcePb, 15, "116e1cb2adf61ebd20ea70c3f384f5b1bbe6916aec04239c13224e3cd1ddfa3c")
  , (LtdSrc009, SourceVendor, 28, "fe32b81f2231b370fe28959f49661861f4644d774b1058cca827818a04439acd")
  ]

sourceBindingProblems :: [String]
sourceBindingProblems =
  concatMap checkSource expectedSourceCases
    <> expectEqual "source framework is not a SourceDebtId" Nothing (parseSourceDebtId LtdSrc000)
    <> expectEqual
      "a changed tools fingerprint cannot be mislabeled as accounted later-owned debt"
      Set.empty
      (laterOwnedSourceIds 0 toolsClosure)
    <> expectCodeAt "changed source fingerprint refuses" "LEGACY-OBSERVATION-REFUSED" "Amoebius.Validation.Legacy/LTD-SRC-001" (qualifySourceClosure 0 toolsClosure)
    <> expectCodeAt "Phase 49 inspects evaluated LTD-SRC states" "LEGACY-DSL-BARRIER-SOURCE-OPEN" legacySubject (qualifySourceClosure 49 toolsClosure)
    <> expectNoCodeAt "clean universe has no inventory omission" "LEGACY-ID-INVENTORY" legacySubject (qualifySourceClosure 0 toolsClosure)
    <> expectNoCodeAt "clean universe has unique encodings" "LEGACY-ID-ENCODING" legacySubject (qualifySourceClosure 0 toolsClosure)
    <> expectNoCodeAt "SourceClosure encodings match Legacy ownership" "LEGACY-SOURCE-ENCODING" legacySubject (qualifySourceClosure 0 toolsClosure)
 where
  toolsClosure = classifySnapshot (snapshot [trackedText "tools/legacy.py" "print('legacy')\n"])
  checkSource (legacyIdentifier, sourceIdentifier, count, digest) =
    concat
      [ expectEqual (show sourceIdentifier <> " LegacyId mapping") legacyIdentifier (sourceDebtLegacyId sourceIdentifier)
      , expectEqual (show sourceIdentifier <> " reverse mapping") (Just sourceIdentifier) (parseSourceDebtId legacyIdentifier)
      , expectEqual (show sourceIdentifier <> " frozen baseline") (count, digest) (sourceBaseline sourceIdentifier)
      ]

registerProblems :: [String]
registerProblems =
  concat
    [ expectEqual "canonical register path" (Right canonicalPath) (activeRegisterPath <$> parseActiveRegister "# reader prose\n")
    , expectEqual "non-UTF8 register" (Left [RegisterNotUtf8 canonicalPath]) (parseActiveRegister (ByteString.pack [255]))
    , expectEqual "missing register" (Left [ActiveRegisterMissing canonicalPath]) (activeRegisterFromSnapshot (snapshot []))
    , expectProblem
        "duplicate canonical register"
        (== MultipleActiveRegisters canonicalPath 2)
        (activeRegisterFromSnapshot (snapshot [registerEntry "# one\n", registerEntry "# two\n"]))
    , expectProblem
        "same register basename elsewhere"
        (== AdditionalActiveRegisterTracked "other/legacy_tracking_for_deletion.md")
        (activeRegisterFromSnapshot (snapshot [registerEntry "# one\n", trackedText "other/legacy_tracking_for_deletion.md" "# alias\n"]))
    , expectProblem
        "archive register forbidden"
        (== ArchiveRegisterTracked "DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md")
        (activeRegisterFromSnapshot (snapshot [registerEntry "# one\n", trackedText "DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md" "# archive\n"]))
    , expectCodeAt
        "structural register failure cannot suppress semantics"
        "LEGACY-ANALYZER-UNAVAILABLE"
        "Amoebius.Validation.Legacy/LTD-SRC-000"
        (legacyCheck 0 (snapshot []))
    ]

markdownInertnessProblems :: [String]
markdownInertnessProblems =
  concat
    [ expectEqual "row/cell/ID/owner/count/prose decoy leaves observations unchanged" (checkObservations baseline) (checkObservations decoy)
    , expectEqual "row/cell/ID/owner/count/prose decoy leaves findings unchanged" (checkFindings baseline) (checkFindings decoy)
    , expectNoCodeAt "UTF-8 prose is not a structural finding" "LEGACY-REGISTER" canonicalPath baseline
    ]
 where
  baseline =
    legacyCheck
      0
      (snapshot [registerEntry "| `LTD-SRC-001` | open | Phase 47 | close |\n", trackedText "tools/legacy.py" "legacy\n"])
  decoy =
    legacyCheck
      0
      ( snapshot
          [ registerEntry
              ( "| `SEMANTIC-DECOY-999` | status: done; Harbor prose | Phase 1 validated | pass |\n"
                  <> "| changed-id | duplicate | changed-owner | predicate-shaped text |\n"
              )
          , trackedText "tools/legacy.py" "legacy\n"
          ]
      )

label :: ExpectedBinding -> String -> String
label item suffix = Text.unpack (expectedEncoding item) <> " " <> suffix

subject :: ExpectedBinding -> FilePath
subject item = "Amoebius.Validation.Legacy/" <> Text.unpack (expectedEncoding item)

snapshot :: [TrackedEntry] -> SourceSnapshot
snapshot entries = SourceSnapshot "/immutable/legacy-oracle" (Text.replicate 64 "e") entries

trackedText :: FilePath -> ByteString -> TrackedEntry
trackedText path bytes =
  TrackedEntry
    { trackedIndex = IndexEntry path RegularFile (Text.replicate 40 "f")
    , trackedBytes = bytes
    }

registerEntry :: ByteString -> TrackedEntry
registerEntry = trackedText canonicalPath

expectProblem :: (Show success, Show problem) => String -> (problem -> Bool) -> Either [problem] success -> [String]
expectProblem _ predicate (Left problems) | any predicate problems = []
expectProblem caseLabel _ (Left problems) = [caseLabel <> ": expected problem absent from " <> show problems]
expectProblem caseLabel _ (Right accepted) = [caseLabel <> ": malformed input accepted as " <> show accepted]

expectCodeAt :: String -> Text -> FilePath -> CheckResult -> [String]
expectCodeAt caseLabel code locus result =
  [caseLabel <> ": expected " <> Text.unpack code <> " at " <> locus <> ", observed " <> show (checkFindings result) | not (hasCodeAt code locus result)]

expectNoCodeAt :: String -> Text -> FilePath -> CheckResult -> [String]
expectNoCodeAt caseLabel code locus result =
  [caseLabel <> ": unexpected " <> Text.unpack code <> " at " <> locus <> " in " <> show (checkFindings result) | hasCodeAt code locus result]

expectExactFinding :: String -> Text -> FilePath -> Text -> CheckResult -> [String]
expectExactFinding caseLabel code locus detail result =
  [ caseLabel <> ": exact finding absent from " <> show (checkFindings result)
  | Finding code locus detail `notElem` checkFindings result
  ]

hasCodeAt :: Text -> FilePath -> CheckResult -> Bool
hasCodeAt code locus = any (\item -> findingCode item == code && findingSubject item == locus) . checkFindings

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual caseLabel expectedValue observed
  | expectedValue == observed = []
  | otherwise = [caseLabel <> ": expected " <> show expectedValue <> ", observed " <> show observed]

requirePhase :: Int -> PhaseOrdinal
requirePhase value = case mkPhaseOrdinal value of
  Just ordinal -> ordinal
  Nothing -> error "LegacyOracle: invalid static phase ordinal"

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless
    (null problems)
    (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack problems))))

canonicalPath :: FilePath
canonicalPath = "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"

legacySubject :: FilePath
legacySubject = "Amoebius.Validation.Legacy"
