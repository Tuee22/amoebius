{-# LANGUAGE OverloadedStrings #-}

module DispatchOracle
  ( dispatchSelectorNames
  , runDispatchOracle
  , runDispatchSelectorOracle
  ) where

-- Hardware-free component diagnostic only.  Every expected CheckResult below
-- is constructed from oracle-owned literals and an independently implemented
-- wire commitment.  No production component, private dispatch symbol, Git,
-- filesystem, process, pb, network, hardware, or container seam is invoked.

import Amoebius.Validation.Dispatch (dispatchDiagnostic)
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

maximumPhaseBytes, maximumComponents, maximumRoleBytes, maximumDigestBytes, maximumAggregateBytes :: Int
maximumPhaseBytes = 2
maximumComponents = 7
maximumRoleBytes = 32
maximumDigestBytes = 64
maximumAggregateBytes = 640

data ExactCase = ExactCase
  { exactCaseLabel :: String
  , exactCasePhase :: Text
  , exactCaseComponents :: [(Text, Text)]
  , exactCaseExpected :: CheckResult
  }

data LiteralProblem = LiteralProblem
  { literalProblemCode :: Text
  , literalProblemSubject :: FilePath
  , literalProblemDetail :: Text
  }

data LiteralCommitment
  = CompleteCommitment
  | BoundedCommitment Text

-- Selector identity, independently named atomic requirement, and the single
-- exact case assigned to make that changed-production subject observable.
dispatchSelectorIntents :: [(String, String, String)]
dispatchSelectorIntents =
  [ ("VALIDATION_DISPATCH_OMIT_SOURCE_CLOSURE_MUTANT", "select source-closure component", "canonical phase zero")
  , ("VALIDATION_DISPATCH_OMIT_SOURCE_DEBT_BASELINE_MUTANT", "select source-debt-baseline component", "canonical phase zero")
  , ("VALIDATION_DISPATCH_OMIT_SOURCE_CONSUMER_GRAPH_MUTANT", "select source-consumer-graph component", "canonical phase zero")
  , ("VALIDATION_DISPATCH_OMIT_LEGACY_MUTANT", "select legacy component", "canonical phase zero")
  , ("VALIDATION_DISPATCH_OMIT_POLICY_CONTRACT_MUTANT", "select policy-contract component", "canonical phase zero")
  , ("VALIDATION_DISPATCH_OMIT_DOCUMENTATION_MUTANT", "select documentation component", "canonical phase zero")
  , ("VALIDATION_DISPATCH_OMIT_PHASE_CONTRACT_MUTANT", "select phase-contract component", "canonical phase zero")
  , ("VALIDATION_DISPATCH_DIAGNOSTIC_ONLY_DROP_MUTANT", "retain diagnostic-only refusal", "canonical phase zero")
  , ("VALIDATION_DISPATCH_SOURCE_CUSTODY_RESIDUE_DROP_MUTANT", "retain source-custody refusal", "canonical phase zero")
  , ("VALIDATION_DISPATCH_PREDECESSOR_RESIDUE_DROP_MUTANT", "retain predecessor refusal", "canonical phase zero")
  , ("VALIDATION_DISPATCH_QUALIFICATION_RESIDUE_DROP_MUTANT", "retain qualification refusal", "canonical phase zero")
  , ("VALIDATION_DISPATCH_LATER_PHASE_BLOCK_BYPASS_MUTANT", "block a later phase", "later phase route")
  , ("VALIDATION_DISPATCH_PHASE_BYTE_LIMIT_BYPASS_MUTANT", "enforce requested-phase byte bound", "requested-phase bytes maximum plus one")
  , ("VALIDATION_DISPATCH_COMPONENT_LIMIT_BYPASS_MUTANT", "enforce component-count bound", "component count maximum plus one")
  , ("VALIDATION_DISPATCH_ROLE_BYTE_LIMIT_BYPASS_MUTANT", "enforce role byte bound", "role bytes maximum plus one")
  , ("VALIDATION_DISPATCH_DIGEST_BYTE_LIMIT_BYPASS_MUTANT", "enforce digest byte bound", "digest bytes maximum plus one")
  , ("VALIDATION_DISPATCH_AGGREGATE_BYTE_LIMIT_BYPASS_MUTANT", "enforce aggregate byte bound", "aggregate bytes maximum plus one")
  , ("VALIDATION_DISPATCH_PHASE_WIDTH_BYPASS_MUTANT", "enforce requested-phase width", "requested-phase width negative")
  , ("VALIDATION_DISPATCH_PHASE_ALPHABET_BYPASS_MUTANT", "enforce requested-phase alphabet", "requested-phase alphabet negative")
  , ("VALIDATION_DISPATCH_PHASE_RANGE_BYPASS_MUTANT", "enforce requested-phase range", "requested-phase range maximum plus one")
  , ("VALIDATION_DISPATCH_COMPONENT_CARDINALITY_BYPASS_MUTANT", "enforce exact component cardinality", "component cardinality negative")
  , ("VALIDATION_DISPATCH_COMPONENT_DUPLICATE_BYPASS_MUTANT", "reject a duplicate component role", "component duplicate negative")
  , ("VALIDATION_DISPATCH_COMPONENT_UNKNOWN_BYPASS_MUTANT", "reject an unknown component role", "component unknown negative")
  , ("VALIDATION_DISPATCH_COMPONENT_ORDER_BYPASS_MUTANT", "enforce component order", "component order negative")
  , ("VALIDATION_DISPATCH_DIGEST_WIDTH_BYPASS_MUTANT", "enforce digest width", "digest width negative")
  , ("VALIDATION_DISPATCH_DIGEST_ALPHABET_BYPASS_MUTANT", "enforce digest alphabet", "digest alphabet negative")
  ]

dispatchSelectorNames :: [String]
dispatchSelectorNames = [selector | (selector, _, _) <- dispatchSelectorIntents]

runDispatchOracle :: IO ()
runDispatchOracle = do
  caseProblems <- case literalIntegrityProblems of
    [] -> firstFailingCase exactCases
    _ -> pure []
  let problems = literalIntegrityProblems <> caseProblems
  unless
    (null problems)
    (fail (unlines ("DispatchOracle component diagnostics failed:" : map ("  " <>) problems)))

runDispatchSelectorOracle :: String -> IO ()
runDispatchSelectorOracle selector = do
  caseProblems <- case literalIntegrityProblems of
    [] -> case selectorExactCases selector of
      [candidate] -> runExactCase candidate
      candidates ->
        pure
          [ "selector intent is not exactly resolvable: selector="
              <> selector
              <> "; exact-case-count="
              <> show (length candidates)
          ]
    _ -> pure []
  let problems = literalIntegrityProblems <> caseProblems
  unless
    (null problems)
    (fail (unlines ("DispatchOracle selector diagnostics failed:" : map ("  " <>) problems)))

selectorExactCases :: String -> [ExactCase]
selectorExactCases selector =
  [ candidate
  | (candidateSelector, _, target) <- dispatchSelectorIntents
  , candidateSelector == selector
  , candidate <- exactCases
  , exactCaseLabel candidate == target
  ]

firstFailingCase :: [ExactCase] -> IO [String]
firstFailingCase cases = case cases of
  [] -> pure []
  candidate : remaining -> do
    problems <- runExactCase candidate
    if null problems then firstFailingCase remaining else pure problems

runExactCase :: ExactCase -> IO [String]
runExactCase candidate =
  pure
    [ exactCaseLabel candidate
        <> " changed:\nexpected="
        <> show (exactCaseExpected candidate)
        <> "\nactual="
        <> show actual
    | actual /= exactCaseExpected candidate
    ]
 where
  actual = dispatchDiagnostic (exactCasePhase candidate) (exactCaseComponents candidate)

literalIntegrityProblems :: [String]
literalIntegrityProblems =
  [ "selector intent cardinality changed: expected=26; observed=" <> show (length dispatchSelectorIntents)
  | length dispatchSelectorIntents /= 26
  ]
    <> ["duplicate selector intent: " <> selector | selector <- duplicateStrings dispatchSelectorNames]
    <> ["duplicate atomic requirement: " <> requirement | requirement <- duplicateStrings atomicRequirements]
    <> ["duplicate exact-case label: " <> label | label <- duplicateStrings exactCaseLabels]
    <> [ "selector target must occur exactly once: selector="
           <> selector
           <> "; target="
           <> target
           <> "; observed="
           <> show (occurrenceCount target exactCaseLabels)
       | (selector, _, target) <- dispatchSelectorIntents
       , occurrenceCount target exactCaseLabels /= 1
       ]
    <> ["zero digest byte boundary changed" | textBytes zeroDigest /= maximumDigestBytes]
    <> ["role maximum fixture changed" | textBytes maximumRole /= maximumRoleBytes]
    <> ["role maximum-plus-one fixture changed" | textBytes excessiveRole /= maximumRoleBytes + 1]
    <> ["digest maximum-plus-one fixture changed" | textBytes excessiveDigest /= maximumDigestBytes + 1]
    <> ["aggregate maximum fixture changed" | aggregateBytes aggregateMaximumComponents /= maximumAggregateBytes]
    <> ["aggregate maximum-plus-one fixture changed" | aggregateBytes aggregateExcessComponents /= maximumAggregateBytes + 1]
 where
  atomicRequirements = [requirement | (_, requirement, _) <- dispatchSelectorIntents]

exactCaseLabels :: [String]
exactCaseLabels = map exactCaseLabel exactCases

duplicateStrings :: [String] -> [String]
duplicateStrings = Set.toAscList . snd . foldl remember (Set.empty, Set.empty)
 where
  remember :: (Set String, Set String) -> String -> (Set String, Set String)
  remember (seen, repeated) value
    | Set.member value seen = (seen, Set.insert value repeated)
    | otherwise = (Set.insert value seen, repeated)

occurrenceCount :: String -> [String] -> Int
occurrenceCount expected = go 0
 where
  go count values = case values of
    [] -> count
    value : remaining -> go (if value == expected then count + 1 else count) remaining

exactCases :: [ExactCase]
exactCases =
  [ completeCase "canonical phase zero" "00" canonicalComponents Nothing False
  , completeCase "later phase route" "01" canonicalComponents Nothing True
  , completeCase "requested-phase bytes maximum" "00" canonicalComponents Nothing False
  , resourceCase
      "requested-phase bytes maximum plus one"
      "000"
      canonicalComponents
      "<over-limit>"
      "unavailable"
      "phase-byte-limit:2:3"
      (literalResource "DISPATCH-PHASE-BYTE-LIMIT" "<requested-phase>" 2 3)
  , completeCase "component count maximum" "00" canonicalComponents Nothing False
  , resourceCase
      "component count maximum plus one"
      "00"
      excessiveComponentCount
      "00"
      "8+"
      "component-limit:7:8"
      (literalResource "DISPATCH-COMPONENT-LIMIT" "<components>" 7 8)
  , completeCase
      "role bytes maximum"
      "00"
      maximumRoleComponents
      (Just (literalGrammar "DISPATCH-COMPONENT-UNKNOWN" (Text.unpack maximumRole) "component role is outside the closed Phase-0 raw composition"))
      False
  , resourceCase
      "role bytes maximum plus one"
      "00"
      excessiveRoleComponents
      "00"
      "7"
      "role-byte-limit:1:32:33"
      (literalResource "DISPATCH-ROLE-BYTE-LIMIT" "<component-1>" 32 33)
  , completeCase "digest bytes maximum" "00" canonicalComponents Nothing False
  , resourceCase
      "digest bytes maximum plus one"
      "00"
      excessiveDigestComponents
      "00"
      "7"
      "digest-byte-limit:1:64:65"
      (literalResource "DISPATCH-DIGEST-BYTE-LIMIT" "<component-1>" 64 65)
  , completeCase
      "aggregate bytes maximum"
      "00"
      aggregateMaximumComponents
      (Just (literalGrammar "DISPATCH-COMPONENT-DUPLICATE" (Text.unpack maximumRole) "component role occurs more than once"))
      False
  , resourceCase
      "aggregate bytes maximum plus one"
      "00"
      aggregateExcessComponents
      "00"
      "7"
      "aggregate-byte-limit:640:641"
      (literalResource "DISPATCH-AGGREGATE-BYTE-LIMIT" "<components>" 640 641)
  , completeCase
      "requested-phase width negative"
      "0"
      canonicalComponents
      (Just (literalGrammar "DISPATCH-PHASE-WIDTH" "<requested-phase>" "expected exactly two ASCII decimal characters"))
      False
  , completeCase
      "requested-phase alphabet negative"
      "0a"
      canonicalComponents
      (Just (literalGrammar "DISPATCH-PHASE-ALPHABET" "<requested-phase>" "expected ASCII decimal characters only"))
      False
  , completeCase "requested-phase range maximum" "95" canonicalComponents Nothing True
  , completeCase
      "requested-phase range maximum plus one"
      "96"
      canonicalComponents
      (Just (literalGrammar "DISPATCH-PHASE-RANGE" "<requested-phase>" "expected a phase in the closed range 00 through 95"))
      False
  , completeCase
      "component cardinality negative"
      "00"
      sixComponents
      (Just (literalGrammar "DISPATCH-COMPONENT-CARDINALITY" "<components>" "expected=7; observed=6"))
      False
  , completeCase
      "component duplicate negative"
      "00"
      duplicateComponents
      (Just (literalGrammar "DISPATCH-COMPONENT-DUPLICATE" "source-closure" "component role occurs more than once"))
      False
  , completeCase
      "component unknown negative"
      "00"
      unknownComponents
      (Just (literalGrammar "DISPATCH-COMPONENT-UNKNOWN" "phase-contracz" "component role is outside the closed Phase-0 raw composition"))
      False
  , completeCase
      "component order negative"
      "00"
      outOfOrderComponents
      (Just (literalGrammar "DISPATCH-COMPONENT-ORDER" "<components>" ("observed=" <> Text.pack (show (map fst outOfOrderComponents)))))
      False
  , completeCase
      "digest width negative"
      "00"
      narrowDigestComponents
      (Just (literalGrammar "DISPATCH-DIGEST-WIDTH" "<component-1>" "expected exactly 64 lowercase ASCII hexadecimal characters"))
      False
  , completeCase
      "digest alphabet negative"
      "00"
      invalidDigestComponents
      (Just (literalGrammar "DISPATCH-DIGEST-ALPHABET" "<component-1>" "expected exactly 64 lowercase ASCII hexadecimal characters"))
      False
  ]

completeCase :: String -> Text -> [(Text, Text)] -> Maybe LiteralProblem -> Bool -> ExactCase
completeCase label phase components problem phaseBlocked =
  ExactCase
    label
    phase
    components
    ( literalExpectedResult
        phase
        components
        phase
        (Text.pack (show (length components)))
        CompleteCommitment
        canonicalRoles
        problem
        phaseBlocked
    )

resourceCase
  :: String
  -> Text
  -> [(Text, Text)]
  -> Text
  -> Text
  -> Text
  -> LiteralProblem
  -> ExactCase
resourceCase label phase components safePhase safeCount problemTag problem =
  ExactCase
    label
    phase
    components
    ( literalExpectedResult
        phase
        components
        safePhase
        safeCount
        (BoundedCommitment problemTag)
        canonicalRoles
        (Just problem)
        False
    )

literalExpectedResult
  :: Text
  -> [(Text, Text)]
  -> Text
  -> Text
  -> LiteralCommitment
  -> [Text]
  -> Maybe LiteralProblem
  -> Bool
  -> CheckResult
literalExpectedResult phase components safePhase safeCount commitment selectedRoles problem phaseBlocked =
  CheckResult
    { checkName = "dispatch-diagnostic"
    , checkObservations =
        [ Observation "dispatch.input-commitment.kind" commitmentKind
        , Observation "dispatch.input-commitment.sha256" commitmentDigest
        , Observation "dispatch.input.requested-phase" safePhase
        , Observation "dispatch.input.component-count" safeCount
        , Observation "dispatch.derived.selected-component-count" (Text.pack (show (length selectedRoles)))
        , Observation "dispatch.diagnostic-status" "refused"
        ]
          <> [ Observation
                 ("dispatch.component." <> Text.pack (show ordinal) <> ".role")
                 role
             | (ordinal, role) <- zip [(1 :: Int) ..] selectedRoles
             ]
    , checkFindings =
        literalMandatoryFindings commitmentDetail
          <> maybe [] (pure . literalProblemFinding commitmentDetail) problem
          <> [ Finding
                 "DISPATCH-COMPONENT-EXECUTION-UNAVAILABLE"
                 (Text.unpack role)
                 ("caller-declared component identities cannot establish execution of the package-hidden Phase-0 composition" <> commitmentDetail)
             | role <- selectedRoles
             ]
          <> [ Finding
                 "DISPATCH-PHASE-BLOCKED"
                 ("phase-" <> Text.unpack safePhase)
                 ("every later phase requires its immediate predecessor's external reviewer approval" <> commitmentDetail)
             | phaseBlocked
             ]
    }
 where
  (commitmentKind, commitmentDigest) = case commitment of
    CompleteCommitment -> ("complete-input", literalCompleteDigest phase components)
    BoundedCommitment problemTag -> ("bounded-preflight-refusal", literalBoundedDigest phase components problemTag)
  commitmentDetail = "; input-commitment-kind=" <> commitmentKind <> "; input-sha256=" <> commitmentDigest

literalMandatoryFindings :: Text -> [Finding]
literalMandatoryFindings commitmentDetail =
  [ Finding
      "DISPATCH-DIAGNOSTIC-ONLY"
      "Amoebius.Validation.Dispatch.dispatchDiagnostic"
      ("caller-supplied dispatch wire cannot mint candidate evidence" <> commitmentDetail)
  , Finding
      "DISPATCH-SOURCE-CUSTODY-UNAVAILABLE"
      "<caller-supplied-dispatch-input>"
      ("no authenticated atomic source acquisition is attached" <> commitmentDetail)
  , Finding
      "DISPATCH-PREDECESSOR-APPROVAL-UNAVAILABLE"
      "phase-order"
      ("no externally authenticated predecessor approval is attached" <> commitmentDetail)
  , Finding
      "DISPATCH-QUALIFICATION-UNAVAILABLE"
      "Amoebius.Validation.Gate"
      ("the fixed sabotage corpus has not executed against this exact dispatcher subject" <> commitmentDetail)
  ]

literalProblemFinding :: Text -> LiteralProblem -> Finding
literalProblemFinding commitmentDetail problem =
  Finding
    (literalProblemCode problem)
    (literalProblemSubject problem)
    (literalProblemDetail problem <> commitmentDetail)

literalResource :: Text -> FilePath -> Int -> Int -> LiteralProblem
literalResource code subject maximumValue observed =
  LiteralProblem
    code
    subject
    ("maximum=" <> Text.pack (show maximumValue) <> "; observed-at-least=" <> Text.pack (show observed))

literalGrammar :: Text -> FilePath -> Text -> LiteralProblem
literalGrammar = LiteralProblem

canonicalRoles :: [Text]
canonicalRoles =
  [ "source-closure"
  , "source-debt-baseline"
  , "source-consumer-graph"
  , "legacy"
  , "policy-contract"
  , "documentation"
  , "phase-contract"
  ]

zeroDigest, excessiveDigest, narrowDigest, invalidDigest, maximumRole, excessiveRole :: Text
zeroDigest = Text.replicate 64 "0"
excessiveDigest = Text.replicate 65 "0"
narrowDigest = Text.replicate 63 "0"
invalidDigest = Text.replicate 63 "0" <> "g"
maximumRole = Text.replicate 32 "r"
excessiveRole = Text.replicate 33 "r"

canonicalComponents :: [(Text, Text)]
canonicalComponents = componentRows canonicalRoles

excessiveComponentCount :: [(Text, Text)]
excessiveComponentCount = canonicalComponents <> [("extra", zeroDigest)]

maximumRoleComponents, excessiveRoleComponents, excessiveDigestComponents :: [(Text, Text)]
maximumRoleComponents = (maximumRole, zeroDigest) : remainingCanonicalComponents
excessiveRoleComponents = (excessiveRole, zeroDigest) : remainingCanonicalComponents
excessiveDigestComponents = ("source-closure", excessiveDigest) : remainingCanonicalComponents

aggregateMaximumComponents, aggregateExcessComponents :: [(Text, Text)]
aggregateMaximumComponents =
  [ (maximumRole, zeroDigest)
  , (maximumRole, zeroDigest)
  , (maximumRole, zeroDigest)
  , (maximumRole, zeroDigest)
  , (maximumRole, zeroDigest)
  , (maximumRole, zeroDigest)
  , ("", zeroDigest)
  ]
aggregateExcessComponents =
  [ (maximumRole, zeroDigest)
  , (maximumRole, zeroDigest)
  , (maximumRole, zeroDigest)
  , (maximumRole, zeroDigest)
  , (maximumRole, zeroDigest)
  , (maximumRole, zeroDigest)
  , ("r", zeroDigest)
  ]

sixComponents, duplicateComponents, unknownComponents, outOfOrderComponents :: [(Text, Text)]
sixComponents =
  componentRows
    [ "source-closure"
    , "source-debt-baseline"
    , "source-consumer-graph"
    , "legacy"
    , "policy-contract"
    , "documentation"
    ]
duplicateComponents =
  componentRows
    [ "source-closure"
    , "source-debt-baseline"
    , "source-consumer-graph"
    , "legacy"
    , "policy-contract"
    , "documentation"
    , "source-closure"
    ]
unknownComponents =
  componentRows
    [ "source-closure"
    , "source-debt-baseline"
    , "source-consumer-graph"
    , "legacy"
    , "policy-contract"
    , "documentation"
    , "phase-contracz"
    ]
outOfOrderComponents =
  componentRows
    [ "source-debt-baseline"
    , "source-closure"
    , "source-consumer-graph"
    , "legacy"
    , "policy-contract"
    , "documentation"
    , "phase-contract"
    ]

narrowDigestComponents, invalidDigestComponents :: [(Text, Text)]
narrowDigestComponents = ("source-closure", narrowDigest) : remainingCanonicalComponents
invalidDigestComponents = ("source-closure", invalidDigest) : remainingCanonicalComponents

remainingCanonicalComponents :: [(Text, Text)]
remainingCanonicalComponents =
  componentRows
    [ "source-debt-baseline"
    , "source-consumer-graph"
    , "legacy"
    , "policy-contract"
    , "documentation"
    , "phase-contract"
    ]

componentRows :: [Text] -> [(Text, Text)]
componentRows = map (\role -> (role, zeroDigest))

aggregateBytes :: [(Text, Text)] -> Int
aggregateBytes = sum . map (\(role, digest) -> textBytes role + textBytes digest)

textBytes :: Text -> Int
textBytes = ByteString.length . TextEncoding.encodeUtf8

literalCompleteDigest :: Text -> [(Text, Text)] -> Text
literalCompleteDigest phase components =
  sha256Hex
    ( ByteString.concat
        ( "amoebius-dispatch-input-v1\0"
            : literalLengthText phase
            : concatMap (\(role, digest) -> [literalLengthText role, literalLengthText digest]) components
        )
    )

literalBoundedDigest :: Text -> [(Text, Text)] -> Text -> Text
literalBoundedDigest phase components problemTag =
  sha256Hex
    ( ByteString.concat
        ( "amoebius-dispatch-bounded-refusal-v1\0"
            : literalBoundedText maximumPhaseBytes phase
            : literalLengthText componentState
            : concatMap literalBoundedComponent boundedComponents
              <> [literalLengthText problemTag]
        )
    )
 where
  (componentState, boundedComponents) = literalBoundedComponents maximumComponents components

literalBoundedComponents :: Int -> [value] -> (Text, [value])
literalBoundedComponents limit = go 0 []
 where
  go count reversed values = case values of
    [] -> ("within:" <> Text.pack (show count), reverse reversed)
    value : remaining
      | count == limit -> ("exceeded-at-least:" <> Text.pack (show (limit + 1)), reverse reversed)
      | otherwise -> go (count + 1) (value : reversed) remaining

literalBoundedComponent :: (Text, Text) -> [ByteString]
literalBoundedComponent (role, digest) =
  [literalBoundedText maximumRoleBytes role, literalBoundedText maximumDigestBytes digest]

literalBoundedText :: Int -> Text -> ByteString
literalBoundedText limit value = literalLengthText (go 0 "" value)
 where
  go count prefix remaining = case Text.uncons remaining of
    Nothing -> "within:" <> prefix
    Just (character, rest) ->
      let next = count + textBytes (Text.singleton character)
       in if next > limit
            then "exceeded-at-least:" <> Text.pack (show next) <> ":" <> prefix
            else go next (Text.snoc prefix character) rest

literalLengthText :: Text -> ByteString
literalLengthText value =
  let bytes = TextEncoding.encodeUtf8 value
   in ByteString8.pack (show (ByteString.length bytes)) <> ":" <> bytes

sha256Hex :: ByteString -> Text
sha256Hex = Text.pack . show . Crypto.hashWith Crypto.SHA256
