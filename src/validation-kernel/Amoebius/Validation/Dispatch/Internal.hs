{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Dispatch.Internal
  ( dispatchDiagnostic
  , checkPhaseZeroSnapshot
  , discoverRepositoryRoot
  , phaseZeroReadinessBlockers
  , runValidateCommand
  , validatePhase
  ) where

import Amoebius.Validation.CompilerSourceGraph.Internal
  ( acquireCompilerSourceGraph
  )
import Amoebius.Validation.Documentation.Internal (checkDocuments)
import Amoebius.Validation.Evidence.Internal
  ( PublishedCandidateEvidence
  , acquiredCandidateDigest
  , acquiredCandidateLegacyClosureCheck
  , acquiredCandidatePassCriterionCheck
  , captureDispatchCandidateEvidence
  , captureFinalizedDispatchCandidateEvidence
  , publishedCandidatePath
  , writeAcquiredCandidateEvidence
  )
import Amoebius.Validation.GatePass.Internal (verifyPublishedGatePass)
import Amoebius.Validation.Gate.Internal qualified as Gate
import Amoebius.Validation.Legacy.Internal (legacyCheck)
import Amoebius.Validation.PhaseContract.Internal (checkPhaseContracts)
import Amoebius.Validation.PhaseRunner.Internal
  ( PhaseRunner (DocumentationSuiteRunner)
  , selectPhaseRunner
  )
import Amoebius.Validation.PhaseZeroRun.Internal
  ( AcquiredPhaseZeroRun
  , acquiredPhaseZeroRunCheck
  , assembleAcquiredPhaseZeroRun
  , phaseZeroQualificationAuthorityCheck
  , phaseZeroReadinessBlockers
  , phaseZeroSnapshotDocuments
  , phaseZeroUnavailablePhaseContractCheck
  )
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , GitExecutable
  , SnapshotProblem (..)
  , SourceClosure
  , SourceSnapshot (snapshotIdentity)
  , acquiredSourceSnapshot
  , classifySnapshot
  , loadGitSnapshot
  , mkGitExecutable
  , renderSnapshotProblem
  , sourceClosureCheck
  )
import Amoebius.Validation.SourceConsumerGraph.Internal
  ( analyzeSourceConsumerGraph
  , sourceConsumerGraphCheck
  )
import Amoebius.Validation.SourceDebtBaseline.Internal
  ( analyzeAcquiredSourceDebt
  , sourceDebtClosureDiagnosticCheck
  )
import Amoebius.Validation.StatusProjection.Internal
  ( ProposedStatusProjection
  , applyAuthorizedStatusProjection
  , authorizeStatusProjection
  , prepareStatusProjection
  , projectionDigest
  , projectionPostimageDigest
  , recoverPendingStatusProjections
  , withStatusProjectionLock
  )
import Amoebius.Validation.Types
import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Char (ord)
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory
  ( canonicalizePath
  , doesFileExist
  , doesPathExist
  , findExecutable
  , getCurrentDirectory
  )
import System.Environment (getArgs, getExecutablePath)
import System.Exit (ExitCode (ExitFailure, ExitSuccess))
import System.FilePath ((</>), isAbsolute, takeDirectory)
import Text.Read (readMaybe)

maximumDispatchPhaseBytes, maximumDispatchComponents :: Int
maximumDispatchPhaseBytes = 2
maximumDispatchComponents = 7

maximumDispatchRoleBytes, maximumDispatchDigestBytes, maximumDispatchAggregateBytes :: Int
maximumDispatchRoleBytes = 32
maximumDispatchDigestBytes = 64
maximumDispatchAggregateBytes = 640

data DispatchPrefix value
  = DispatchPrefixWithin [value]
  | DispatchPrefixExceeded Int [value]

data DispatchRawProblem
  = DispatchPhaseByteLimit Int Int
  | DispatchComponentLimit Int Int
  | DispatchRoleByteLimit Int Int Int
  | DispatchDigestByteLimit Int Int Int
  | DispatchAggregateByteLimit Int Int
  | DispatchResourceGuardUnavailable Text
  | DispatchPhaseWidth Text
  | DispatchPhaseAlphabet Text
  | DispatchPhaseRange Text
  | DispatchComponentCardinality Int Int
  | DispatchComponentDuplicate Text
  | DispatchComponentUnknown Text
  | DispatchComponentOrder [Text]
  | DispatchDigestWidth Int Text
  | DispatchDigestAlphabet Int Text
  deriving (Eq, Show)

-- | Bounded refusal-only diagnostic over caller-claimed dispatch component
-- identities.  A coherent wire remains incapable of establishing source
-- binding, predecessor gate pass, component execution, or harness
-- qualification.  No Git, filesystem, process, pb, network, hardware, or
-- container action occurs here.
dispatchDiagnostic :: Text -> [(Text, Text)] -> CheckResult
dispatchDiagnostic requestedPhase claimedComponents =
  CheckResult
    { checkName = "dispatch-diagnostic"
    , checkObservations =
        [ observation "dispatch.input-commitment.kind" commitmentKind
        , observation "dispatch.input-commitment.sha256" commitmentDigest
        , observation "dispatch.input.requested-phase" safePhase
        , observation "dispatch.input.component-count" componentCount
        , observation "dispatch.derived.selected-component-count" (Text.pack (show (length selectedComponents)))
        , observation "dispatch.diagnostic-status" "refused"
        ]
          <> selectedObservations
    , checkFindings = mandatoryFindings <> problemFindings <> selectedFindings <> phaseFindings
    }
 where
  analysis = analyzeDispatchRawInput requestedPhase claimedComponents
  commitmentKind = dispatchCommitmentKind analysis
  commitmentDigest = dispatchCommitmentDigest analysis
  safePhase = dispatchSafePhase analysis
  componentCount = dispatchSafeComponentCount analysis
  problems = dispatchProblems analysis
  selectedComponents = selectedRawPhaseZeroComponents
  selectedObservations =
    [ observation
        ("dispatch.component." <> Text.pack (show ordinal) <> ".role")
        (renderRawPhaseZeroComponent component)
    | (ordinal, component) <- zip [(1 :: Int) ..] selectedComponents
    ]
  selectedFindings =
    [ finding
        "DISPATCH-COMPONENT-EXECUTION-UNAVAILABLE"
        (Text.unpack (renderRawPhaseZeroComponent component))
        ( "caller-declared component identities cannot establish execution of the package-hidden Phase-0 composition"
            <> dispatchCommitmentDetail analysis
        )
    | component <- selectedComponents
    ]
  mandatoryFindings =
    dispatchDiagnosticOnlyFindings analysis
      <> dispatchSourceBindingFindings analysis
      <> dispatchPredecessorFindings analysis
      <> dispatchQualificationFindings analysis
  problemFindings = map (dispatchRawProblemFinding analysis) problems
  phaseFindings = dispatchPhaseRouteFindings analysis

data DispatchRawAnalysis = DispatchRawAnalysis
  { dispatchCommitmentKind :: Text
  , dispatchCommitmentDigest :: Text
  , dispatchSafePhase :: Text
  , dispatchSafeComponentCount :: Text
  , dispatchProblems :: [DispatchRawProblem]
  }

analyzeDispatchRawInput :: Text -> [(Text, Text)] -> DispatchRawAnalysis
analyzeDispatchRawInput requestedPhase components =
  case boundedDispatchText maximumDispatchPhaseBytes requestedPhase of
    DispatchPrefixExceeded observed _ ->
      dispatchResourceFailure
        requestedPhase
        components
        "<over-limit>"
        "unavailable"
        ( dispatchGuardedResourceProblem
            "phase-byte-limit"
            (dispatchPhaseByteLimitExceeded observed)
            (DispatchPhaseByteLimit maximumDispatchPhaseBytes observed)
        )
    _ -> case boundedDispatchPrefix maximumDispatchComponents components of
      DispatchPrefixExceeded observed _ ->
        dispatchResourceFailure
          requestedPhase
          components
          requestedPhase
          (Text.pack (show observed) <> "+")
          ( dispatchGuardedResourceProblem
              "component-limit"
              (dispatchComponentLimitExceeded observed)
              (DispatchComponentLimit maximumDispatchComponents observed)
          )
      DispatchPrefixWithin bounded -> analyzeDispatchBounded requestedPhase bounded

analyzeDispatchBounded :: Text -> [(Text, Text)] -> DispatchRawAnalysis
analyzeDispatchBounded requestedPhase components =
  case firstDispatchResourceProblem components of
    Just problem ->
      dispatchResourceFailure
        requestedPhase
        components
        requestedPhase
        (Text.pack (show (length components)))
        problem
    Nothing ->
      DispatchRawAnalysis
        { dispatchCommitmentKind = "complete-input"
        , dispatchCommitmentDigest = dispatchCompleteDigest requestedPhase components
        , dispatchSafePhase = requestedPhase
        , dispatchSafeComponentCount = Text.pack (show (length components))
        , dispatchProblems = dispatchGrammarProblems requestedPhase components
        }

dispatchResourceFailure
  :: Text
  -> [(Text, Text)]
  -> Text
  -> Text
  -> DispatchRawProblem
  -> DispatchRawAnalysis
dispatchResourceFailure requestedPhase components safePhase componentCount problem =
  DispatchRawAnalysis
    { dispatchCommitmentKind = "bounded-preflight-refusal"
    , dispatchCommitmentDigest = dispatchBoundedDigest requestedPhase components problem
    , dispatchSafePhase = safePhase
    , dispatchSafeComponentCount = componentCount
    , dispatchProblems = [problem]
    }

firstDispatchResourceProblem :: [(Text, Text)] -> Maybe DispatchRawProblem
firstDispatchResourceProblem = go 1 0
 where
  go ordinal aggregate remaining = case remaining of
    [] -> Nothing
    (role, digest) : rest ->
      case boundedDispatchText maximumDispatchRoleBytes role of
        DispatchPrefixExceeded observed _ ->
          Just
            ( dispatchGuardedResourceProblem
                "role-byte-limit"
                (dispatchRoleByteLimitExceeded observed)
                (DispatchRoleByteLimit ordinal maximumDispatchRoleBytes observed)
            )
        _ -> case boundedDispatchText maximumDispatchDigestBytes digest of
          DispatchPrefixExceeded observed _ ->
            Just
              ( dispatchGuardedResourceProblem
                  "digest-byte-limit"
                  (dispatchDigestByteLimitExceeded observed)
                  (DispatchDigestByteLimit ordinal maximumDispatchDigestBytes observed)
              )
          _ ->
            let next = aggregate + dispatchTextBytes role + dispatchTextBytes digest
             in if next > maximumDispatchAggregateBytes
                  then
                    Just
                      ( dispatchGuardedResourceProblem
                          "aggregate-byte-limit"
                          (dispatchAggregateByteLimitExceeded next)
                          (DispatchAggregateByteLimit maximumDispatchAggregateBytes next)
                      )
                  else go (ordinal + 1) next rest

dispatchGuardedResourceProblem :: Text -> Bool -> DispatchRawProblem -> DispatchRawProblem
dispatchGuardedResourceProblem label predicate specific
  | predicate = specific
  | otherwise = DispatchResourceGuardUnavailable label

dispatchGrammarProblems :: Text -> [(Text, Text)] -> [DispatchRawProblem]
dispatchGrammarProblems requestedPhase components =
  phaseProblems <> componentProblems
 where
  phaseProblems
    | not (dispatchPhaseWidthValid requestedPhase) = [DispatchPhaseWidth requestedPhase]
    | not (dispatchPhaseAlphabetValid requestedPhase) = [DispatchPhaseAlphabet requestedPhase]
    | not (dispatchPhaseRangeValid requestedPhase) = [DispatchPhaseRange requestedPhase]
    | otherwise = []
  roles = map fst components
  componentProblems
    | not (dispatchComponentCardinalityValid roles) = [DispatchComponentCardinality maximumDispatchComponents (length roles)]
    | Just duplicate <- firstDispatchDuplicate roles = [DispatchComponentDuplicate duplicate]
    | Just unknown <- firstDispatchUnknown roles = [DispatchComponentUnknown unknown]
    | not (dispatchComponentOrderValid roles) = [DispatchComponentOrder roles]
    | Just problem <- firstDispatchDigestProblem components = [problem]
    | otherwise = []

firstDispatchDigestProblem :: [(Text, Text)] -> Maybe DispatchRawProblem
firstDispatchDigestProblem = go 1
 where
  go ordinal remaining = case remaining of
    [] -> Nothing
    (_, digest) : rest
      | not (dispatchDigestWidthValid digest) -> Just (DispatchDigestWidth ordinal digest)
      | not (dispatchDigestAlphabetValid digest) -> Just (DispatchDigestAlphabet ordinal digest)
      | otherwise -> go (ordinal + 1) rest

dispatchDiagnosticOnlyFindings :: DispatchRawAnalysis -> [Finding]
#if defined(VALIDATION_DISPATCH_DIAGNOSTIC_ONLY_DROP_MUTANT)
dispatchDiagnosticOnlyFindings _ = []
#else
dispatchDiagnosticOnlyFindings analysis =
  [ finding
      "DISPATCH-DIAGNOSTIC-ONLY"
      "Amoebius.Validation.Dispatch.dispatchDiagnostic"
      ("caller-supplied dispatch wire cannot mint candidate evidence" <> dispatchCommitmentDetail analysis)
  ]
#endif

dispatchSourceBindingFindings :: DispatchRawAnalysis -> [Finding]
#if defined(VALIDATION_DISPATCH_SOURCE_BINDING_RESIDUE_DROP_MUTANT)
dispatchSourceBindingFindings _ = []
#else
dispatchSourceBindingFindings analysis =
  [ finding
      "DISPATCH-SOURCE-BINDING-UNAVAILABLE"
      "<caller-supplied-dispatch-input>"
      ("no exact local source snapshot is attached" <> dispatchCommitmentDetail analysis)
  ]
#endif

dispatchPredecessorFindings :: DispatchRawAnalysis -> [Finding]
#if defined(VALIDATION_DISPATCH_PREDECESSOR_RESIDUE_DROP_MUTANT)
dispatchPredecessorFindings _ = []
#else
dispatchPredecessorFindings analysis =
  [ finding
      "DISPATCH-PREDECESSOR-PASS-UNAVAILABLE"
      "phase-order"
      ("no predecessor gate pass result is attached" <> dispatchCommitmentDetail analysis)
  ]
#endif

dispatchQualificationFindings :: DispatchRawAnalysis -> [Finding]
#if defined(VALIDATION_DISPATCH_QUALIFICATION_RESIDUE_DROP_MUTANT)
dispatchQualificationFindings _ = []
#else
dispatchQualificationFindings analysis =
  [ finding
      "DISPATCH-QUALIFICATION-UNAVAILABLE"
      "Amoebius.Validation.Gate"
      ("the fixed sabotage corpus has not executed against this exact dispatcher subject" <> dispatchCommitmentDetail analysis)
  ]
#endif

dispatchPhaseRouteFindings :: DispatchRawAnalysis -> [Finding]
dispatchPhaseRouteFindings analysis = case dispatchProblems analysis of
  []
    | dispatchSafePhase analysis == "00" -> []
    | dispatchLaterPhaseBlocked ->
        [ finding
            "DISPATCH-PHASE-BLOCKED"
            ("phase-" <> Text.unpack (dispatchSafePhase analysis))
            ("every later phase requires its immediate predecessor's gate pass" <> dispatchCommitmentDetail analysis)
        ]
    | otherwise -> []
  _ -> []

dispatchLaterPhaseBlocked :: Bool
#if defined(VALIDATION_DISPATCH_LATER_PHASE_BLOCK_BYPASS_MUTANT)
dispatchLaterPhaseBlocked = False
#else
dispatchLaterPhaseBlocked = True
#endif

dispatchRawProblemFinding :: DispatchRawAnalysis -> DispatchRawProblem -> Finding
dispatchRawProblemFinding analysis problem = case problem of
  DispatchPhaseByteLimit maximumValue observed -> resource "DISPATCH-PHASE-BYTE-LIMIT" "<requested-phase>" maximumValue observed
  DispatchComponentLimit maximumValue observed -> resource "DISPATCH-COMPONENT-LIMIT" "<components>" maximumValue observed
  DispatchRoleByteLimit ordinal maximumValue observed -> resource "DISPATCH-ROLE-BYTE-LIMIT" (dispatchOrdinalSubject ordinal) maximumValue observed
  DispatchDigestByteLimit ordinal maximumValue observed -> resource "DISPATCH-DIGEST-BYTE-LIMIT" (dispatchOrdinalSubject ordinal) maximumValue observed
  DispatchAggregateByteLimit maximumValue observed -> resource "DISPATCH-AGGREGATE-BYTE-LIMIT" "<components>" maximumValue observed
  DispatchResourceGuardUnavailable label ->
    grammar
      "DISPATCH-RESOURCE-GUARD-UNAVAILABLE"
      "<dispatch-input>"
      ("the changed subject suppressed the bound-specific predicate; the outer preflight envelope still refused before traversal; guard=" <> label)
  DispatchPhaseWidth _ -> grammar "DISPATCH-PHASE-WIDTH" "<requested-phase>" "expected exactly two ASCII decimal characters"
  DispatchPhaseAlphabet _ -> grammar "DISPATCH-PHASE-ALPHABET" "<requested-phase>" "expected ASCII decimal characters only"
  DispatchPhaseRange _ -> grammar "DISPATCH-PHASE-RANGE" "<requested-phase>" ("expected a phase in the closed range " <> policyDomainLabel)
  DispatchComponentCardinality expected observed -> grammar "DISPATCH-COMPONENT-CARDINALITY" "<components>" ("expected=" <> Text.pack (show expected) <> "; observed=" <> Text.pack (show observed))
  DispatchComponentDuplicate role -> grammar "DISPATCH-COMPONENT-DUPLICATE" (Text.unpack role) "component role occurs more than once"
  DispatchComponentUnknown role -> grammar "DISPATCH-COMPONENT-UNKNOWN" (Text.unpack role) "component role is outside the closed Phase-0 raw composition"
  DispatchComponentOrder roles -> grammar "DISPATCH-COMPONENT-ORDER" "<components>" ("observed=" <> Text.pack (show roles))
  DispatchDigestWidth ordinal _ -> grammar "DISPATCH-DIGEST-WIDTH" (dispatchOrdinalSubject ordinal) "expected exactly 64 lowercase ASCII hexadecimal characters"
  DispatchDigestAlphabet ordinal _ -> grammar "DISPATCH-DIGEST-ALPHABET" (dispatchOrdinalSubject ordinal) "expected exactly 64 lowercase ASCII hexadecimal characters"
 where
  resource code subject maximumValue observed =
    finding code subject ("maximum=" <> Text.pack (show maximumValue) <> "; observed-at-least=" <> Text.pack (show observed) <> dispatchCommitmentDetail analysis)
  grammar code subject detail = finding code subject (detail <> dispatchCommitmentDetail analysis)

dispatchCommitmentDetail :: DispatchRawAnalysis -> Text
dispatchCommitmentDetail analysis =
  "; input-commitment-kind="
    <> dispatchCommitmentKind analysis
    <> "; input-sha256="
    <> dispatchCommitmentDigest analysis

dispatchCompleteDigest :: Text -> [(Text, Text)] -> Text
dispatchCompleteDigest requestedPhase components =
  dispatchSha256
    ( ByteString.concat
        ( "amoebius-dispatch-input-v1\0"
            : dispatchLengthText requestedPhase
            : concatMap (\(role, digest) -> [dispatchLengthText role, dispatchLengthText digest]) components
        )
    )

dispatchBoundedDigest :: Text -> [(Text, Text)] -> DispatchRawProblem -> Text
dispatchBoundedDigest requestedPhase components problem =
  dispatchSha256
    ( ByteString.concat
        ( "amoebius-dispatch-bounded-refusal-v1\0"
            : dispatchBoundedTextCommitment maximumDispatchPhaseBytes requestedPhase
            : dispatchLengthText componentState
            : concatMap dispatchBoundedComponentCommitment boundedComponents
              <> [dispatchLengthText (dispatchRawProblemCommitmentTag problem)]
        )
    )
 where
  componentPrefix = boundedDispatchPrefix maximumDispatchComponents components
  boundedComponents = case componentPrefix of
    DispatchPrefixWithin values -> values
    DispatchPrefixExceeded _ values -> values
  componentState = case componentPrefix of
    DispatchPrefixWithin values -> "within:" <> Text.pack (show (length values))
    DispatchPrefixExceeded observed _ -> "exceeded-at-least:" <> Text.pack (show observed)

dispatchBoundedComponentCommitment :: (Text, Text) -> [ByteString]
dispatchBoundedComponentCommitment (role, digest) =
  [ dispatchBoundedTextCommitment maximumDispatchRoleBytes role
  , dispatchBoundedTextCommitment maximumDispatchDigestBytes digest
  ]

dispatchBoundedTextCommitment :: Int -> Text -> ByteString
dispatchBoundedTextCommitment limit value =
  case boundedDispatchText limit value of
    DispatchPrefixWithin characters ->
      dispatchLengthText ("within:" <> Text.pack characters)
    DispatchPrefixExceeded observed characters ->
      dispatchLengthText
        ( "exceeded-at-least:"
            <> Text.pack (show observed)
            <> ":"
            <> Text.pack characters
        )

dispatchRawProblemCommitmentTag :: DispatchRawProblem -> Text
dispatchRawProblemCommitmentTag problem = case problem of
  DispatchPhaseByteLimit maximumValue observed -> numeric "phase-byte-limit" [maximumValue, observed]
  DispatchComponentLimit maximumValue observed -> numeric "component-limit" [maximumValue, observed]
  DispatchRoleByteLimit ordinal maximumValue observed -> numeric "role-byte-limit" [ordinal, maximumValue, observed]
  DispatchDigestByteLimit ordinal maximumValue observed -> numeric "digest-byte-limit" [ordinal, maximumValue, observed]
  DispatchAggregateByteLimit maximumValue observed -> numeric "aggregate-byte-limit" [maximumValue, observed]
  DispatchResourceGuardUnavailable label -> "resource-guard-unavailable:" <> label
  DispatchPhaseWidth _ -> "phase-width"
  DispatchPhaseAlphabet _ -> "phase-alphabet"
  DispatchPhaseRange _ -> "phase-range"
  DispatchComponentCardinality expected observed -> numeric "component-cardinality" [expected, observed]
  DispatchComponentDuplicate _ -> "component-duplicate"
  DispatchComponentUnknown _ -> "component-unknown"
  DispatchComponentOrder _ -> "component-order"
  DispatchDigestWidth ordinal _ -> numeric "digest-width" [ordinal]
  DispatchDigestAlphabet ordinal _ -> numeric "digest-alphabet" [ordinal]
 where
  numeric label values = label <> ":" <> Text.intercalate ":" (map (Text.pack . show) values)

dispatchLengthText :: Text -> ByteString
dispatchLengthText value =
  let bytes = TextEncoding.encodeUtf8 value
   in ByteString8.pack (show (ByteString.length bytes)) <> ":" <> bytes

dispatchSha256 :: ByteString -> Text
dispatchSha256 = Text.pack . show . Crypto.hashWith Crypto.SHA256

boundedDispatchPrefix :: Int -> [value] -> DispatchPrefix value
boundedDispatchPrefix limit = go 0 []
 where
  go count reversed remaining = case remaining of
    [] -> DispatchPrefixWithin (reverse reversed)
    value : rest
      | count == limit -> DispatchPrefixExceeded (limit + 1) (reverse reversed)
      | otherwise -> go (count + 1) (value : reversed) rest

boundedDispatchText :: Int -> Text -> DispatchPrefix Char
boundedDispatchText limit = boundedDispatchCharacters limit . Text.unpack

boundedDispatchCharacters :: Int -> [Char] -> DispatchPrefix Char
boundedDispatchCharacters limit = go 0 []
 where
  go count reversed characters = case characters of
    [] -> DispatchPrefixWithin (reverse reversed)
    character : rest ->
      let next = count + dispatchUtf8CharacterBytes character
       in if next > limit
            then DispatchPrefixExceeded next (reverse reversed)
            else go next (character : reversed) rest

dispatchUtf8CharacterBytes :: Char -> Int
dispatchUtf8CharacterBytes character
  | code <= 0x7f = 1
  | code <= 0x7ff = 2
  | code <= 0xffff = 3
  | otherwise = 4
 where
  code = ord character

dispatchTextBytes :: Text -> Int
dispatchTextBytes = ByteString.length . TextEncoding.encodeUtf8

dispatchPhaseByteLimitExceeded, dispatchComponentLimitExceeded :: Int -> Bool
#if defined(VALIDATION_DISPATCH_PHASE_BYTE_LIMIT_BYPASS_MUTANT)
dispatchPhaseByteLimitExceeded _ = False
#else
dispatchPhaseByteLimitExceeded observed = observed > maximumDispatchPhaseBytes
#endif
#if defined(VALIDATION_DISPATCH_COMPONENT_LIMIT_BYPASS_MUTANT)
dispatchComponentLimitExceeded _ = False
#else
dispatchComponentLimitExceeded observed = observed > maximumDispatchComponents
#endif

dispatchRoleByteLimitExceeded, dispatchDigestByteLimitExceeded, dispatchAggregateByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_DISPATCH_ROLE_BYTE_LIMIT_BYPASS_MUTANT)
dispatchRoleByteLimitExceeded _ = False
#else
dispatchRoleByteLimitExceeded observed = observed > maximumDispatchRoleBytes
#endif
#if defined(VALIDATION_DISPATCH_DIGEST_BYTE_LIMIT_BYPASS_MUTANT)
dispatchDigestByteLimitExceeded _ = False
#else
dispatchDigestByteLimitExceeded observed = observed > maximumDispatchDigestBytes
#endif
#if defined(VALIDATION_DISPATCH_AGGREGATE_BYTE_LIMIT_BYPASS_MUTANT)
dispatchAggregateByteLimitExceeded _ = False
#else
dispatchAggregateByteLimitExceeded observed = observed > maximumDispatchAggregateBytes
#endif

dispatchPhaseWidthValid, dispatchPhaseAlphabetValid, dispatchPhaseRangeValid :: Text -> Bool
#if defined(VALIDATION_DISPATCH_PHASE_WIDTH_BYPASS_MUTANT)
dispatchPhaseWidthValid _ = True
#else
dispatchPhaseWidthValid value = Text.length value == 2
#endif
#if defined(VALIDATION_DISPATCH_PHASE_ALPHABET_BYPASS_MUTANT)
dispatchPhaseAlphabetValid _ = True
#else
dispatchPhaseAlphabetValid = Text.all (\character -> character >= '0' && character <= '9')
#endif
#if defined(VALIDATION_DISPATCH_PHASE_RANGE_BYPASS_MUTANT)
dispatchPhaseRangeValid _ = True
#else
dispatchPhaseRangeValid value = value >= "00" && value <= "95"
#endif

dispatchComponentCardinalityValid :: [Text] -> Bool
#if defined(VALIDATION_DISPATCH_COMPONENT_CARDINALITY_BYPASS_MUTANT)
dispatchComponentCardinalityValid _ = True
#else
dispatchComponentCardinalityValid roles = length roles == maximumDispatchComponents
#endif

dispatchComponentOrderValid :: [Text] -> Bool
#if defined(VALIDATION_DISPATCH_COMPONENT_ORDER_BYPASS_MUTANT)
dispatchComponentOrderValid _ = True
#else
dispatchComponentOrderValid roles = roles == map renderRawPhaseZeroComponent rawPhaseZeroComponentUniverse
#endif

dispatchDigestWidthValid, dispatchDigestAlphabetValid :: Text -> Bool
#if defined(VALIDATION_DISPATCH_DIGEST_WIDTH_BYPASS_MUTANT)
dispatchDigestWidthValid _ = True
#else
dispatchDigestWidthValid value = Text.length value == 64
#endif
#if defined(VALIDATION_DISPATCH_DIGEST_ALPHABET_BYPASS_MUTANT)
dispatchDigestAlphabetValid _ = True
#else
dispatchDigestAlphabetValid = Text.all (\character -> character >= '0' && character <= '9' || character >= 'a' && character <= 'f')
#endif

firstDispatchDuplicate :: [Text] -> Maybe Text
firstDispatchDuplicate values = go [] values
 where
  go seen remaining = case remaining of
    [] -> Nothing
    value : rest
      | dispatchDuplicateRejected value seen -> Just value
      | otherwise -> go (value : seen) rest

dispatchDuplicateRejected :: Text -> [Text] -> Bool
#if defined(VALIDATION_DISPATCH_COMPONENT_DUPLICATE_BYPASS_MUTANT)
dispatchDuplicateRejected _ _ = False
#else
dispatchDuplicateRejected value seen = value `elem` seen
#endif

firstDispatchUnknown :: [Text] -> Maybe Text
firstDispatchUnknown values = case filter (dispatchUnknownRejected canonical) values of
  [] -> Nothing
  value : _ -> Just value
 where
  canonical = map renderRawPhaseZeroComponent rawPhaseZeroComponentUniverse

dispatchUnknownRejected :: [Text] -> Text -> Bool
#if defined(VALIDATION_DISPATCH_COMPONENT_UNKNOWN_BYPASS_MUTANT)
dispatchUnknownRejected _ _ = False
#else
dispatchUnknownRejected canonical value = value `notElem` canonical
#endif

dispatchOrdinalSubject :: Int -> FilePath
dispatchOrdinalSubject ordinal = "<component-" <> show ordinal <> ">"

-- | Run the public validation argv against an exact local source capture.
runValidateCommand :: [String] -> IO ExitCode
runValidateCommand arguments =
  case arguments of
    ["phase", ordinal]
      | Just phase <- parseOrdinal ordinal -> do
          capture <- acquireRepository
          case capture of
            Left detail -> emitResult (captureFailure detail)
            Right (git, root) -> validatePhase git root phase >>= emitResult
    _ ->
      emitResult
        CheckResult
          { checkName = "validation-dispatch"
          , checkObservations = [observation "validation.argv" (Text.pack (show arguments))]
          , checkFindings =
              [ finding
                  "DISPATCH-ARGV"
                  "amoebius validate"
                  ("expected exactly: validate phase NN, with a two-digit phase ordinal from " <> policyDomainLabel)
              ]
          }

-- | Git and the repository root are explicit so a test or caller cannot
-- silently substitute PATH lookup or the current working directory.
validatePhase :: FilePath -> FilePath -> Int -> IO CheckResult
validatePhase gitPath root phase
  | phase < policyDomainLower || phase > policyDomainUpper =
      pure
        CheckResult
          { checkName = "validation-phase-dispatch"
          , checkObservations = [observation "validation.requested-phase" (Text.pack (show phase))]
          , checkFindings =
              [ finding
                  "DISPATCH-PHASE-INVALID"
                  ("phase-" <> show phase)
                  ("the phase ordinal must be in the closed repository range " <> policyDomainLabel)
              ]
          }
  | otherwise =
      case mkGitExecutable gitPath of
        Left problem -> pure (snapshotFailure [problem])
        Right git -> do
          locked <- withStatusProjectionLock root (validatePhaseLocked git root phase)
          pure $ case locked of
            Left problems -> statusLifecycleFailure phase problems
            Right result -> result

validatePhaseLocked :: GitExecutable -> FilePath -> Int -> IO CheckResult
validatePhaseLocked git root phase = do
  recoveryResult <- recoverPendingStatusProjections git root
  case recoveryResult of
    Left problems -> pure (statusLifecycleFailure phase problems)
    Right recovered -> do
      snapshotResult <- loadGitSnapshot git root
      case snapshotResult of
        Left problems -> pure (snapshotFailure problems)
        Right acquired -> do
          compilerAttempt <- acquireCompilerSourceGraph acquired
          qualificationAuthority <- Gate.acquireQualifiedValidationProtocol acquired compilerAttempt
          let projectionResult = prepareStatusProjection phase acquired
              debtEvidence = analyzeAcquiredSourceDebt acquired
              phaseZeroRun = assembleAcquiredPhaseZeroRun acquired compilerAttempt qualificationAuthority debtEvidence
              result = checkAcquiredPhaseChain phaseZeroRun phase
          finalSnapshot <- loadGitSnapshot git root
          completed <-
            finishGateLifecycle
              git
              root
              phase
              acquired
              phaseZeroRun
              finalSnapshot
              projectionResult
              (bindFinalSourceSnapshot acquired finalSnapshot result)
          pure
            completed
              { checkObservations =
                  [ observation
                      "status.projection.recovered"
                      (Text.pack (show recovered))
                  ]
                    <> checkObservations completed
              }

statusLifecycleFailure :: Int -> [Finding] -> CheckResult
statusLifecycleFailure phase problems =
  CheckResult
    { checkName = "validation-phase-status-lifecycle"
    , checkObservations =
        [ observation
            "validation.requested-phase"
            (formatOrdinal phase)
        ]
    , checkFindings = problems
    }

finishGateLifecycle
  :: GitExecutable
  -> FilePath
  -> Int
  -> AcquiredSourceSnapshot
  -> AcquiredPhaseZeroRun
  -> Either [SnapshotProblem] AcquiredSourceSnapshot
  -> Either [Finding] ProposedStatusProjection
  -> CheckResult
  -> IO CheckResult
finishGateLifecycle git root phase opening phaseZeroRun closing projectionResult gateResult = do
  executablePath <- getExecutablePath
  processArgv <- map Text.pack <$> getArgs
  executableDigestResult <- try (ByteString.readFile executablePath) :: IO (Either IOException ByteString)
  let executableDigest = either (const Nothing) (Just . dispatchSha256) executableDigestResult
      openingDigest = snapshotIdentity (acquiredSourceSnapshot opening)
      projectionFindings = either id (const []) projectionResult
      subjectResult =
        gateResult
          { checkFindings = checkFindings gateResult <> projectionFindings
          }
      candidate =
        if phase == policyDomainLower
          then
            captureFinalizedDispatchCandidateEvidence
              phaseZeroRun
              closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath
              executableDigest
              processArgv
          else
            captureDispatchCandidateEvidence
              phase
              openingDigest
              (case closing of
                Left _ -> ""
                Right acquired -> snapshotIdentity (acquiredSourceSnapshot acquired))
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath
              executableDigest
              processArgv
              subjectResult
      lifecycleResult =
        mergeChecks
          (checkName subjectResult)
          [ subjectResult
          , acquiredCandidateLegacyClosureCheck candidate
          , acquiredCandidatePassCriterionCheck candidate
          ]
  writeResult <- try (writeAcquiredCandidateEvidence root candidate) :: IO (Either IOException PublishedCandidateEvidence)
  case writeResult of
    Left problem ->
      pure
        lifecycleResult
          { checkFindings =
              checkFindings lifecycleResult
                <> [ finding
                       "EVIDENCE-CANDIDATE-WRITE"
                       "<candidate-evidence>"
                       (Text.pack (show problem))
                   ]
          }
    Right published -> do
      let writeObservations =
            [ observation "evidence.candidate.path" (Text.pack (publishedCandidatePath published))
            , observation "evidence.candidate.sha256" (acquiredCandidateDigest candidate)
            ]
      passResult <- verifyPublishedGatePass published
      case passResult of
        Left passFindings ->
          pure
            lifecycleResult
              { checkObservations = checkObservations lifecycleResult <> writeObservations
              , checkFindings = checkFindings lifecycleResult <> passFindings
              }
        Right verified -> case projectionResult of
          Left problems ->
            pure
              lifecycleResult
                { checkObservations = checkObservations lifecycleResult <> writeObservations
                , checkFindings = checkFindings lifecycleResult <> problems
                }
          Right projection -> case authorizeStatusProjection verified projection of
            Left problems ->
              pure
                lifecycleResult
                  { checkObservations = checkObservations lifecycleResult <> writeObservations
                  , checkFindings = checkFindings lifecycleResult <> problems
                  }
            Right authorized -> do
              applied <- applyAuthorizedStatusProjection git authorized
              pure $ case applied of
                Left problems ->
                  lifecycleResult
                    { checkObservations = checkObservations lifecycleResult <> writeObservations
                    , checkFindings = checkFindings lifecycleResult <> problems
                    }
                Right _ ->
                  lifecycleResult
                    { checkObservations =
                        checkObservations lifecycleResult
                          <> writeObservations
                          <> [observation "status.projection" "applied and confirmed against a fresh whole-source postimage"]
                    , checkFindings = checkFindings lifecycleResult
                    }

-- | Pure diagnostic seam. A caller-constructed snapshot can exercise
-- composition, but always carries an explicit refusal and can never represent
-- candidate local-capture evidence.
checkPhaseZeroSnapshot :: SourceSnapshot -> CheckResult
checkPhaseZeroSnapshot snapshot =
  mergeChecks
    "phase-00"
    [ checkPhaseZeroSnapshotCore snapshot
    , syntheticSnapshotRefusal
    ]

-- | Gate N is the conjunction of gates 0..N re-derived at the current
-- snapshot.
--
-- Nothing durable is stored, so a predecessor result cannot be replayed from
-- a receipt, cache, or Markdown status marker, and work done for a later
-- phase that weakens an earlier phase's subject reddens that earlier phase
-- inside this same run.  The compiler source graph is analyzed once and
-- shared, because every phase in the chain observes the one snapshot.
checkAcquiredPhaseChain
  :: AcquiredPhaseZeroRun
  -> Int
  -> CheckResult
checkAcquiredPhaseChain phaseZeroRun target =
  mergeChecks
    ("phase-" <> formatOrdinal target)
    [ checkAcquiredPhaseInChain phaseZeroRun ordinal
    | ordinal <- [policyDomainLower .. target]
    ]

checkAcquiredPhaseInChain
  :: AcquiredPhaseZeroRun
  -> Int
  -> CheckResult
checkAcquiredPhaseInChain phaseZeroRun ordinal
  = case selectPhaseRunner ordinal of
      Right DocumentationSuiteRunner ->
        acquiredPhaseZeroRunCheck phaseZeroRun
      Left problem ->
        CheckResult
          { checkName = "phase-" <> formatOrdinal ordinal
          , checkObservations =
              [ observation "phase.ordinal" (formatOrdinal ordinal)
              , observation "phase.runner" "absent or ambiguous"
              ]
          , checkFindings = [problem]
          }

-- | A phase whose production subject has not been implemented.  This is an
-- observed absence at the current snapshot, not a policy statement that the
-- phase may never run: it retires when the phase's subject and oracle exist.
bindFinalSourceSnapshot
  :: AcquiredSourceSnapshot
  -> Either [SnapshotProblem] AcquiredSourceSnapshot
  -> CheckResult
  -> CheckResult
bindFinalSourceSnapshot initial final result = case final of
  Left problems ->
    result
      { checkFindings =
          checkFindings result
            <> map snapshotProblemFinding problems
      }
  Right observed
    | snapshotIdentity (acquiredSourceSnapshot initial)
        == snapshotIdentity (acquiredSourceSnapshot observed) ->
        result
          { checkObservations =
              checkObservations result
                <> [observation "source.snapshot.final" (snapshotIdentity (acquiredSourceSnapshot observed))]
          }
    | otherwise ->
        result
          { checkFindings =
              checkFindings result
                <> [ finding
                       "SOURCE-SNAPSHOT-CHANGED-DURING-GATE"
                       "<local-source-snapshot>"
                       "the authored source bytes changed between the opening and closing gate captures"
                   ]
          }

checkPhaseZeroSnapshotCore :: SourceSnapshot -> CheckResult
checkPhaseZeroSnapshotCore snapshot =
  mergeChecks
    "phase-00"
    ( map (rawPhaseZeroComponentCheck snapshot closure decodedDocuments) rawPhaseZeroComponentUniverse
        <> [phaseZeroQualificationAuthorityCheck Gate.currentQualifiedValidationProtocol, phaseZeroReadinessBlockers]
    )
 where
  closure = classifySnapshot snapshot
  decodedDocuments = phaseZeroSnapshotDocuments snapshot

-- | The raw diagnostic composition has one closed selection locus. Every
-- component occurs exactly once here, and each omission mutant changes only
-- one selection decision rather than changing a component or its oracle.
data RawPhaseZeroComponent
  = RawSourceClosure
  | RawSourceDebtBaseline
  | RawSourceConsumerGraph
  | RawLegacy
  | RawPolicyContract
  | RawDocumentation
  | RawPhaseContract
  deriving (Eq, Ord, Enum, Bounded, Show)

rawPhaseZeroComponentUniverse :: [RawPhaseZeroComponent]
rawPhaseZeroComponentUniverse =
  [ RawSourceClosure
  , RawSourceDebtBaseline
  , RawSourceConsumerGraph
  , RawLegacy
  , RawPolicyContract
  , RawDocumentation
  , RawPhaseContract
  ]

renderRawPhaseZeroComponent :: RawPhaseZeroComponent -> Text
renderRawPhaseZeroComponent component = case component of
  RawSourceClosure -> "source-closure"
  RawSourceDebtBaseline -> "source-debt-baseline"
  RawSourceConsumerGraph -> "source-consumer-graph"
  RawLegacy -> "legacy"
  RawPolicyContract -> "policy-contract"
  RawDocumentation -> "documentation"
  RawPhaseContract -> "phase-contract"

selectedRawPhaseZeroComponents :: [RawPhaseZeroComponent]
selectedRawPhaseZeroComponents = filter rawPhaseZeroComponentSelected rawPhaseZeroComponentUniverse

rawPhaseZeroComponentSelected :: RawPhaseZeroComponent -> Bool
rawPhaseZeroComponentSelected component = case component of
  RawSourceClosure ->
#if defined(VALIDATION_DISPATCH_OMIT_SOURCE_CLOSURE_MUTANT)
    False
#else
    True
#endif
  RawSourceDebtBaseline ->
#if defined(VALIDATION_DISPATCH_OMIT_SOURCE_DEBT_BASELINE_MUTANT)
    False
#else
    True
#endif
  RawSourceConsumerGraph ->
#if defined(VALIDATION_DISPATCH_OMIT_SOURCE_CONSUMER_GRAPH_MUTANT)
    False
#else
    True
#endif
  RawLegacy ->
#if defined(VALIDATION_DISPATCH_OMIT_LEGACY_MUTANT)
    False
#else
    True
#endif
  RawPolicyContract ->
#if defined(VALIDATION_DISPATCH_OMIT_POLICY_CONTRACT_MUTANT)
    False
#else
    True
#endif
  RawDocumentation ->
#if defined(VALIDATION_DISPATCH_OMIT_DOCUMENTATION_MUTANT)
    False
#else
    True
#endif
  RawPhaseContract ->
#if defined(VALIDATION_DISPATCH_OMIT_PHASE_CONTRACT_MUTANT)
    False
#else
    True
#endif

rawPhaseZeroComponentCheck
  :: SourceSnapshot
  -> SourceClosure
  -> Either [Finding] [(FilePath, Text)]
  -> RawPhaseZeroComponent
  -> CheckResult
rawPhaseZeroComponentCheck snapshot closure decodedDocuments component = case component of
  RawSourceClosure -> sourceClosureCheck closure
  RawSourceDebtBaseline -> sourceDebtClosureDiagnosticCheck closure
  RawSourceConsumerGraph -> sourceConsumerGraphCheck (analyzeSourceConsumerGraph snapshot)
  RawLegacy -> legacyCheck (Policy.phaseDomainLower policyOrdering) snapshot
  RawPolicyContract -> Policy.checkPolicyContract Policy.canonicalPolicyContract
  RawDocumentation -> case decodedDocuments of
    Left decodeFindings -> CheckResult "documentation-snapshot" [] decodeFindings
    Right documents -> checkDocuments documents
  RawPhaseContract -> case decodedDocuments of
    Left decodeFindings -> phaseZeroUnavailablePhaseContractCheck decodeFindings
    Right documents -> checkPhaseContracts documents

syntheticSnapshotRefusal :: CheckResult
syntheticSnapshotRefusal =
  CheckResult
    { checkName = "source-snapshot-diagnostic"
    , checkObservations =
        [ observation
            "source.snapshot.local-capture"
            "caller-supplied diagnostic input; package-hidden local capture absent"
        ]
    , checkFindings = syntheticSnapshotFindings
    }

syntheticSnapshotFindings :: [Finding]
syntheticSnapshotFindings =
  [ finding
      "SOURCE-SNAPSHOT-DIAGNOSTIC-ONLY"
      "<caller-supplied-snapshot>"
      "a pure SourceSnapshot has not crossed the package-hidden local capture boundary and cannot be candidate evidence"
  ]

snapshotFailure :: [SnapshotProblem] -> CheckResult
snapshotFailure problems =
  CheckResult
    { checkName = "source-snapshot-capture"
    , checkObservations = [observation "source.snapshot" "refused before classification"]
    , checkFindings = map snapshotProblemFinding problems
    }

snapshotProblemFinding :: SnapshotProblem -> Finding
snapshotProblemFinding problem = case problem of
  CallerSelectedGitDiagnosticOnly _ ->
    finding
      "GIT-CAPTURE-TOOL-INVALID"
      "Amoebius.Validation.Dispatch"
      (renderSnapshotProblem problem)
  SourceSnapshotAtomicityRequiresExternalObserver ->
    finding
      "SOURCE-SNAPSHOT-LOCAL-CAPTURE-INCOMPLETE"
      "Amoebius.Validation.Dispatch"
      (renderSnapshotProblem problem)
  _ -> finding "SRC-SNAPSHOT" "<git-index>" (renderSnapshotProblem problem)

captureFailure :: Text -> CheckResult
captureFailure detail =
  CheckResult
    { checkName = "validation-capture"
    , checkObservations = [observation "validation.capture" "refused"]
    , checkFindings = [finding "DISPATCH-CAPTURE" "repository" detail]
    }

emitResult :: CheckResult -> IO ExitCode
emitResult result = do
  TextIO.putStrLn ("validation " <> checkName result <> ": " <> verdict)
  mapM_ emitObservation (checkObservations result)
  mapM_ (TextIO.putStrLn . ("REFUSAL\t" <>) . renderFinding) (checkFindings result)
  TextIO.putStrLn ("status\t" <> if checkPassed result then "PASS" else "NOT VALIDATED")
  pure (if checkPassed result then ExitSuccess else ExitFailure 1)
 where
  verdict = if checkPassed result then "PASS" else "REFUSED"
  emitObservation item =
    TextIO.putStrLn ("OBSERVATION\t" <> observationKey item <> "\t" <> observationValue item)

acquireRepository :: IO (Either Text (FilePath, FilePath))
acquireRepository = do
  gitCandidate <- findExecutable "git"
  case gitCandidate of
    Nothing -> pure (Left "Git is absent from the irreducible host floor")
    Just git -> do
      gitResult <- canonicalize git
      rootResult <- discoverRepositoryRoot
      pure ((,) <$> gitResult <*> rootResult)

discoverRepositoryRoot :: IO (Either Text FilePath)
discoverRepositoryRoot = do
  current <- getCurrentDirectory
  executable <- getExecutablePath
  startsResult <- traverse canonicalize [current, takeDirectory executable]
  case sequence startsResult of
    Left detail -> pure (Left detail)
    Right starts -> do
      candidates <- fmap (sort . nub . concat) (traverse repositoryAncestors starts)
      pure $ case candidates of
        [root] -> Right root
        [] -> Left "no ancestor contains both .git and amoebius.cabal"
        roots -> Left ("repository root is ambiguous: " <> Text.intercalate ", " (fmap Text.pack roots))

repositoryAncestors :: FilePath -> IO [FilePath]
repositoryAncestors start = filterM isRepository (ancestors start)
 where
  isRepository candidate = do
    git <- doesPathExist (candidate </> ".git")
    package <- doesFileExist (candidate </> "amoebius.cabal")
    pure (git && package)

ancestors :: FilePath -> [FilePath]
ancestors path = path : if parent == path then [] else ancestors parent
 where
  parent = takeDirectory path

canonicalize :: FilePath -> IO (Either Text FilePath)
canonicalize path = do
  result <- try (canonicalizePath path) :: IO (Either IOException FilePath)
  pure $ case result of
    Left problem -> Left ("cannot canonicalize " <> Text.pack path <> ": " <> Text.pack (show problem))
    Right absolute
      | isAbsolute absolute -> Right absolute
      | otherwise -> Left ("canonical path is not absolute: " <> Text.pack absolute)

parseOrdinal :: String -> Maybe Int
parseOrdinal value
  | length value == 2 && all asciiDigit value = do
      phase <- readMaybe value
      if phase >= policyDomainLower && phase <= policyDomainUpper then Just phase else Nothing
  | otherwise = Nothing
 where
  asciiDigit character = character >= '0' && character <= '9'

formatOrdinal :: Int -> Text
formatOrdinal phase
  | phase >= 0 && phase < 10 = "0" <> Text.pack (show phase)
  | otherwise = Text.pack (show phase)

policyOrdering :: Policy.OrderingContract
policyOrdering = Policy.orderingContract Policy.canonicalPolicyContract

policyDomainLower :: Int
policyDomainLower = Policy.phaseOrdinalNumber (Policy.phaseDomainLower policyOrdering)

policyDomainUpper :: Int
policyDomainUpper = Policy.phaseOrdinalNumber (Policy.phaseDomainUpper policyOrdering)

policyDomainLabel :: Text
policyDomainLabel = formatOrdinal policyDomainLower <> " through " <> formatOrdinal policyDomainUpper
