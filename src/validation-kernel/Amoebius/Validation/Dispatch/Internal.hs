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
  ( AcquiredCompilerSourceGraph
  , acquiredCompilerSourceCheck
  , analyzeAcquiredCompilerSourceGraph
  )
import Amoebius.Validation.Documentation.Internal (checkDocuments)
import Amoebius.Validation.Legacy.Internal (legacyCheck, legacyCheckAcquired)
import Amoebius.Validation.PhaseContract.Internal (checkPhaseContracts)
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (indexPath)
  , SnapshotProblem (..)
  , SourceClosure
  , SourceSnapshot (snapshotEntries)
  , TrackedEntry (trackedBytes, trackedIndex)
  , acquiredSourceSnapshot
  , classifySnapshot
  , loadGitSnapshot
  , mkGitExecutable
  , renderSnapshotProblem
  , sourceClosureCheck
  , sourceClosureCheckAcquired
  )
import Amoebius.Validation.SourceConsumerGraph.Internal
  ( analyzeSourceConsumerGraph
  , sourceConsumerGraphCheck
  )
import Amoebius.Validation.SourceDebtBaseline.Internal
  ( analyzeAcquiredSourceDebt
  , sourceDebtClosureDiagnosticCheck
  , sourceDebtEvidenceCheck
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
import System.Environment (getExecutablePath)
import System.Exit (ExitCode (ExitFailure))
import System.FilePath ((</>), isAbsolute, takeDirectory, takeExtension)
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
-- custody, predecessor approval, component execution, or harness
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
      <> dispatchSourceCustodyFindings analysis
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

dispatchSourceCustodyFindings :: DispatchRawAnalysis -> [Finding]
#if defined(VALIDATION_DISPATCH_SOURCE_CUSTODY_RESIDUE_DROP_MUTANT)
dispatchSourceCustodyFindings _ = []
#else
dispatchSourceCustodyFindings analysis =
  [ finding
      "DISPATCH-SOURCE-CUSTODY-UNAVAILABLE"
      "<caller-supplied-dispatch-input>"
      ("no authenticated atomic source acquisition is attached" <> dispatchCommitmentDetail analysis)
  ]
#endif

dispatchPredecessorFindings :: DispatchRawAnalysis -> [Finding]
#if defined(VALIDATION_DISPATCH_PREDECESSOR_RESIDUE_DROP_MUTANT)
dispatchPredecessorFindings _ = []
#else
dispatchPredecessorFindings analysis =
  [ finding
      "DISPATCH-PREDECESSOR-APPROVAL-UNAVAILABLE"
      "phase-order"
      ("no externally authenticated predecessor approval is attached" <> dispatchCommitmentDetail analysis)
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
            ("every later phase requires its immediate predecessor's external human approval" <> dispatchCommitmentDetail analysis)
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
  DispatchPhaseRange _ -> grammar "DISPATCH-PHASE-RANGE" "<requested-phase>" "expected a phase in the closed range 00 through 95"
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

-- | Run the public validation argv. No current path owns authenticated source
-- custody, so every result is diagnostic and exits with a refusal. A future
-- candidate entry point must replace this rule only together with an external,
-- atomic acquisition authority.
runValidateCommand :: [String] -> IO ExitCode
runValidateCommand arguments =
  case arguments of
    ["phase", ordinal]
      | Just phase <- parseOrdinal ordinal -> do
          acquisition <- acquireRepository
          case acquisition of
            Left detail -> emitResult (acquisitionFailure detail)
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

-- | Diagnostic acquisition seam. Git and the repository root are explicit so
-- a test or caller cannot silently substitute PATH lookup or the current
-- working directory, but caller selection authenticates neither value and can
-- never mint candidate authority.
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
  | phase /= policyDomainLower =
      pure
        CheckResult
          { checkName = "validation-phase-dispatch"
          , checkObservations = [observation "validation.requested-phase" (formatOrdinal phase)]
          , checkFindings =
              [ finding
                  "DISPATCH-PHASE-BLOCKED"
                  ("phase-" <> Text.unpack (formatOrdinal phase))
                  "only Phase 0 is active; every later phase requires its immediate predecessor's external human approval"
              ]
          }
  | otherwise =
      case mkGitExecutable gitPath of
        Left problem -> pure (snapshotFailure [problem])
        Right git -> do
          snapshotResult <- loadGitSnapshot git root
          case snapshotResult of
            Left problems -> pure (snapshotFailure problems)
            Right acquired -> checkAcquiredPhaseZeroSnapshot acquired

-- | Pure diagnostic seam. A caller-constructed snapshot can exercise
-- composition, but always carries an explicit refusal and can never represent
-- candidate acquisition authority.
checkPhaseZeroSnapshot :: SourceSnapshot -> CheckResult
checkPhaseZeroSnapshot snapshot =
  mergeChecks
    "phase-0"
    [ checkPhaseZeroSnapshotCore snapshot
    , syntheticSnapshotRefusal
    ]

checkAcquiredPhaseZeroSnapshot :: AcquiredSourceSnapshot -> IO CheckResult
checkAcquiredPhaseZeroSnapshot acquired = do
  compilerEvidence <- analyzeAcquiredCompilerSourceGraph acquired
  pure (checkAcquiredPhaseZeroSnapshotCore acquired compilerEvidence)

checkAcquiredPhaseZeroSnapshotCore
  :: AcquiredSourceSnapshot
  -> AcquiredCompilerSourceGraph
  -> CheckResult
checkAcquiredPhaseZeroSnapshotCore acquired compilerEvidence =
  case snapshotDocuments snapshot of
    Left decodeFindings ->
      mergeChecks
        "phase-0"
        ( acquiredSourceChecks
            <> [ legacyCheckAcquired (Policy.phaseDomainLower policyOrdering) acquired compilerEvidence debtEvidence
               , Policy.checkPolicyContract Policy.canonicalPolicyContract
               , CheckResult "documentation-snapshot" [] decodeFindings
               , unavailablePhaseContractCheck decodeFindings
               , phaseZeroReadinessBlockers
               ]
        )
    Right documents ->
      mergeChecks
        "phase-0"
        ( acquiredSourceChecks
            <> [ legacyCheckAcquired (Policy.phaseDomainLower policyOrdering) acquired compilerEvidence debtEvidence
               , Policy.checkPolicyContract Policy.canonicalPolicyContract
               , checkDocuments documents
               , checkPhaseContracts documents
               , phaseZeroReadinessBlockers
               ]
        )
 where
  snapshot = acquiredSourceSnapshot acquired
  debtEvidence = analyzeAcquiredSourceDebt acquired
  acquiredSourceChecks =
    [ sourceClosureCheckAcquired acquired
    , sourceDebtEvidenceCheck acquired debtEvidence
    , acquiredCompilerSourceCheck compilerEvidence
    , acquiredCompilerDispatchQualificationResidue
    ]

checkPhaseZeroSnapshotCore :: SourceSnapshot -> CheckResult
checkPhaseZeroSnapshotCore snapshot =
  mergeChecks
    "phase-0"
    ( map (rawPhaseZeroComponentCheck snapshot closure decodedDocuments) rawPhaseZeroComponentUniverse
        <> [phaseZeroReadinessBlockers]
    )
 where
  closure = classifySnapshot snapshot
  decodedDocuments = snapshotDocuments snapshot

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
    Left decodeFindings -> unavailablePhaseContractCheck decodeFindings
    Right documents -> checkPhaseContracts documents

unavailablePhaseContractCheck :: [Finding] -> CheckResult
unavailablePhaseContractCheck decodeFindings =
  CheckResult
    { checkName = "phase-contract-snapshot"
    , checkObservations =
        [ observation
            "phase-contract.snapshot-input"
            "unavailable because the tracked Markdown snapshot did not decode"
        ]
    , checkFindings =
        [ finding
            "PHASE-CONTRACT-SNAPSHOT-UNAVAILABLE"
            "DEVELOPMENT_PLAN/"
            ( "phase-contract analysis did not run because "
                <> Text.pack (show (length decodeFindings))
                <> " tracked Markdown document(s) failed UTF-8 decoding"
            )
        ]
    }

acquiredCompilerDispatchQualificationResidue :: CheckResult
acquiredCompilerDispatchQualificationResidue =
  CheckResult
    { checkName = "acquired-compiler-dispatch-qualification"
    , checkObservations =
        [ observation
            "compiler-dispatch.acquired-authority"
            "absent; caller-selected Git cannot establish authenticated atomic custody"
        ]
    , checkFindings =
        [ finding
            "ACQUIRED-COMPILER-DISPATCH-UNQUALIFIED"
            "Amoebius.Validation.Dispatch"
            "no authenticated atomic source authority can mint the acquired snapshot wrapper, so the acquired compiler-dispatch branch is explicit residue rather than candidate evidence"
        ]
    }

syntheticSnapshotRefusal :: CheckResult
syntheticSnapshotRefusal =
  CheckResult
    { checkName = "source-snapshot-authority"
    , checkObservations =
        [ observation
            "source.snapshot-authority"
            "caller-supplied diagnostic input; acquisition authority absent"
        ]
    , checkFindings = syntheticSnapshotFindings
    }

syntheticSnapshotFindings :: [Finding]
syntheticSnapshotFindings =
  [ finding
      "SOURCE-SNAPSHOT-DIAGNOSTIC-ONLY"
      "<caller-supplied-snapshot>"
      "a pure SourceSnapshot has not crossed the opaque Git/index/worktree acquisition boundary and cannot be candidate evidence"
  ]

-- These are deliberate, executable refusal rows.  They prevent structural
-- component checks from being mislabeled as a qualified Phase-0 candidate.
-- Each row retires only when its separately reviewed implementation supplies
-- the raw evidence named here; no caller flag can turn it green.  In
-- particular, Gate.checkQualificationReportDiagnostic is a pure consistency check over
-- caller-supplied values and cannot retire the execution blocker.
phaseZeroReadinessBlockers :: CheckResult
phaseZeroReadinessBlockers =
  CheckResult
    { checkName = "phase-0-readiness"
    , checkObservations =
        [ observation "readiness.harness-qualification" "report consistency checker present; execution not implemented"
        , observation "readiness.policy-contract" "typed contract is integrated; changed-subject qualification and human prose-correspondence review are absent"
        , observation "readiness.pb-source-grammar" "the static source-bound grammar is integrated; acquired one-file tracked-snapshot closure, changed-subject qualification, and independent review are absent"
        , observation "readiness.phase-contract-semantics" "the closed typed registry and structural joins are integrated; all 1,728 semantic slots and 385 resource slots remain gaps, with no reviewed payload or custody"
        , observation "readiness.legacy-owner-analyzers" "closed typed inventory and fail-closed dispatch are integrated; LTD-SRC-000 and LTD-SRC-008 source analyzers are present but unqualified, while LTD-VAL-001 through LTD-VAL-004 owner analyzers remain unavailable"
        , observation "readiness.independent-review" "reviewer and custody receipt absent"
        , observation "readiness.cleanroom-residue" "external observer absent"
        , observation "readiness.candidate-integration" "evidence writer not connected to dispatcher"
        , observation "readiness.evidence-schema" "command, toolchain, substrate, run, and cleanup fields are not represented by a closed typed schema"
        , observation "readiness.git-acquisition" "PATH-selected Git is not externally authenticated"
        ]
    , checkFindings =
        [ finding
            "QUALIFICATION-NOT-EXECUTED"
            "Amoebius.Validation.Gate"
            "the fixed sabotage corpus has not been executed against the exact dispatcher/harness build"
        , finding
            "POLICY-CONTRACT-UNQUALIFIED"
            "Amoebius.Validation.PolicyContract"
            "the typed cross-cutting contract is integrated, but its Registry-provider, owner-map, and pb-transport changed-subject mutants have not been qualified and no human has reviewed prose correspondence"
        , finding
            "PB-GRAMMAR-UNQUALIFIED"
            "Amoebius.Validation.PbBootstrapGrammar"
            "the versioned static AST/import/resolved-call/control-flow/potential-effect analyzer is integrated, but no acquired one-file tracked snapshot, applied changed-subject qualification, or independent review binds it; Phase 51 alone owns external runtime handoff observation"
        , finding
            "PHASE-CONTRACT-SEMANTICS-UNREVIEWED"
            "Amoebius.Validation.PhaseContract"
            "the closed typed 96-phase registry and structural joins are integrated, but all 1,728 semantic slots and 385 resource slots remain gaps, with no reviewed payload or independent human custody"
        , finding
            "LEGACY-VALIDATION-ANALYZERS-MISSING"
            "Amoebius.Validation.Legacy"
            "the closed legacy inventory dispatches every ID and the LTD-SRC-000 and LTD-SRC-008 source analyzers are integrated but unqualified; the LTD-VAL-001 through LTD-VAL-004 owner analyzers and their independently authored reintroduction executions remain unavailable"
        , finding
            "INDEPENDENT-REVIEW-MISSING"
            "phase-0-oracles"
            "component diagnostics have no independent human reviewer or custody receipt"
        , finding
            "CLEANROOM-OBSERVER-MISSING"
            "phase-0-cleanroom"
            "fresh-run input closure and external residue have no implemented independent observer"
        , finding
            "EVIDENCE-INTEGRATION-MISSING"
            "Amoebius.Validation.Dispatch"
            "the dispatcher cannot emit candidate evidence until qualification and cleanroom checks are connected"
        , finding
            "EVIDENCE-SCHEMA-INCOMPLETE"
            "Amoebius.Validation.Evidence"
            "the candidate schema does not yet require typed exact-command, toolchain, substrate/lane/architecture, run-identity, or cleanup observations"
        , finding
            "GIT-ACQUISITION-UNAUTHENTICATED"
            "Amoebius.Validation.Dispatch"
            "the Git executable is selected from PATH and has no externally established tool identity"
        ]
    }

snapshotDocuments :: SourceSnapshot -> Either [Finding] [(FilePath, Text)]
snapshotDocuments snapshot =
  if null problems then Right documents else Left problems
 where
  markdownEntries =
    [ entry
    | entry <- snapshotEntries snapshot
    , takeExtension (indexPath (trackedIndex entry)) == ".md"
    ]
  decoded = fmap decodeEntry markdownEntries
  documents = [document | Right document <- decoded]
  problems = [problem | Left problem <- decoded]
  decodeEntry entry =
    let path = indexPath (trackedIndex entry)
     in case TextEncoding.decodeUtf8' (trackedBytes entry) of
          Left _ -> Left (finding "DOC-SNAPSHOT-UTF8" path "tracked Markdown blob is not UTF-8")
          Right contents -> Right (path, contents)

snapshotFailure :: [SnapshotProblem] -> CheckResult
snapshotFailure problems =
  CheckResult
    { checkName = "source-snapshot-acquisition"
    , checkObservations = [observation "source.snapshot" "refused before classification"]
    , checkFindings = map snapshotProblemFinding problems
    }

snapshotProblemFinding :: SnapshotProblem -> Finding
snapshotProblemFinding problem = case problem of
  CallerSelectedGitDiagnosticOnly _ ->
    finding
      "GIT-ACQUISITION-UNAUTHENTICATED"
      "Amoebius.Validation.Dispatch"
      (renderSnapshotProblem problem)
  SourceSnapshotAtomicityRequiresExternalObserver ->
    finding
      "SOURCE-SNAPSHOT-ATOMIC-CUSTODY-MISSING"
      "Amoebius.Validation.Dispatch"
      (renderSnapshotProblem problem)
  _ -> finding "SRC-SNAPSHOT" "<git-index>" (renderSnapshotProblem problem)

acquisitionFailure :: Text -> CheckResult
acquisitionFailure detail =
  CheckResult
    { checkName = "validation-acquisition"
    , checkObservations = [observation "validation.acquisition" "refused"]
    , checkFindings = [finding "DISPATCH-ACQUISITION" "repository" detail]
    }

emitResult :: CheckResult -> IO ExitCode
emitResult result = do
  TextIO.putStrLn ("validation " <> checkName result <> ": " <> verdict)
  mapM_ emitObservation (checkObservations result)
  mapM_ (TextIO.putStrLn . ("REFUSAL\t" <>) . renderFinding) (checkFindings result)
  TextIO.putStrLn "status\tNOT VALIDATED"
  pure (ExitFailure 1)
 where
  verdict = if checkPassed result then "DIAGNOSTIC CHECKS PASSED; AUTHORITY ABSENT" else "REFUSED"
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
