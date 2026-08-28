{-# LANGUAGE CPP #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

-- | A deliberately small, closed parser and static-admission proof for the
-- pre-binary Python handoff.  This module does not execute Python and its proof
-- does not claim that any effect happened; Phase 50 owns that observation.
module Amoebius.Validation.PbBootstrapGrammar
  ( pbBootstrapGrammarDiagnostic
  ) where

import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , Observation
  , finding
  , observation
  )
import Control.Monad (foldM, unless, when)
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Char (isAsciiLower, isAsciiUpper, isDigit)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word8)

-- The only public value is an always-refusing diagnostic.  The tuple is raw
-- observed source input: path, Git mode spelling, and exact blob bytes.  It is
-- deliberately not an expectation or an admission witness.  All expected
-- inventory, byte, digest, grammar, and runtime-residue declarations remain
-- private to this module.
pbBootstrapGrammarDiagnostic
  :: [(FilePath, Text, ByteString)]
  -> CheckResult
pbBootstrapGrammarDiagnostic rawInventory =
  case preflightRawInventory rawInventory of
    Left preflight -> diagnosticResult (preflightObservations rawInventory) preflight
    Right (inventory, identityFindings) ->
      case analyzePbBootstrap inventory of
        Left problems ->
          diagnosticResult
            (inventoryObservations inventory)
            (projectIdentityFindings identityFindings <> projectProblemFindings problems)
        Right proof ->
          CheckResult
            { checkName = diagnosticCheckName
            , checkObservations = orderProofObservations (proofObservations proof)
            , checkFindings = assembleSuccessFindings identityFindings
            }

diagnosticCheckName, diagnosticSubject :: Text
#if defined(VALIDATION_PB_GRAMMAR_CHECK_NAME_MAPPING_MUTANT)
diagnosticCheckName = "pb-bootstrap-grammar-diagnostic-mutant"
#else
diagnosticCheckName = "pb-bootstrap-grammar-diagnostic"
#endif
diagnosticSubject = "Amoebius.Validation.PbBootstrapGrammar.pbBootstrapGrammarDiagnostic"

diagnosticResult :: [Observation] -> [Finding] -> CheckResult
diagnosticResult observations findings =
  CheckResult
    { checkName = diagnosticCheckName
    , checkObservations = retainDiagnosticObservations observations
    , checkFindings = assembleDiagnosticFindings findings
    }

retainDiagnosticObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_PB_GRAMMAR_DIAGNOSTIC_OBSERVATIONS_RETENTION_DROP_MUTANT)
retainDiagnosticObservations _ = []
#else
retainDiagnosticObservations observations = observations
#endif

assembleDiagnosticFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_PB_GRAMMAR_DIAGNOSTIC_FINDINGS_ORDER_MUTANT)
assembleDiagnosticFindings findings = findings <> diagnosticOnlyFindings
#else
assembleDiagnosticFindings findings = diagnosticOnlyFindings <> findings
#endif

assembleSuccessFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_PB_GRAMMAR_SUCCESS_FINDINGS_ORDER_MUTANT)
assembleSuccessFindings identityFindings = phase50ResidueFindings <> projectIdentityFindings identityFindings <> diagnosticOnlyFindings
#else
assembleSuccessFindings identityFindings = diagnosticOnlyFindings <> projectIdentityFindings identityFindings <> phase50ResidueFindings
#endif

orderProofObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_PB_GRAMMAR_PROOF_OBSERVATION_ORDER_MUTANT)
orderProofObservations = reverse
#else
orderProofObservations = id
#endif

projectIdentityFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_PB_GRAMMAR_IDENTITY_FINDINGS_RETENTION_DROP_MUTANT)
projectIdentityFindings _ = []
#else
projectIdentityFindings findings = findings
#endif

projectProblemFindings :: [PbProblem] -> [Finding]
projectProblemFindings problems = retainProblemFindings (orderProblemFindings (map pbProblemFinding problems))

retainProblemFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_FINDINGS_RETENTION_DROP_MUTANT)
retainProblemFindings _ = []
#else
retainProblemFindings findings = findings
#endif

orderProblemFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_FINDINGS_ORDER_MUTANT)
orderProblemFindings = reverse
#else
orderProblemFindings = id
#endif

diagnosticOnlyFindings :: [Finding]
#if defined(VALIDATION_PB_GRAMMAR_DIAGNOSTIC_ONLY_BYPASS_MUTANT)
diagnosticOnlyFindings = diagnosticOnlyCode `seq` diagnosticOnlySubject `seq` diagnosticOnlyDetail `seq` []
#else
diagnosticOnlyFindings =
  [ finding
      diagnosticOnlyCode
      (Text.unpack diagnosticOnlySubject)
      diagnosticOnlyDetail
  ]
#endif

diagnosticOnlyCode, diagnosticOnlySubject, diagnosticOnlyDetail :: Text
#if defined(VALIDATION_PB_GRAMMAR_DIAGNOSTIC_ONLY_CODE_MAPPING_MUTANT)
diagnosticOnlyCode = "PB-GRAMMAR-DIAGNOSTIC-ONLY-MUTANT"
#else
diagnosticOnlyCode = "PB-GRAMMAR-DIAGNOSTIC-ONLY"
#endif
#if defined(VALIDATION_PB_GRAMMAR_DIAGNOSTIC_ONLY_SUBJECT_MAPPING_MUTANT)
diagnosticOnlySubject = diagnosticSubject <> ".mutant"
#else
diagnosticOnlySubject = diagnosticSubject
#endif
#if defined(VALIDATION_PB_GRAMMAR_DIAGNOSTIC_ONLY_DETAIL_MAPPING_MUTANT)
diagnosticOnlyDetail = "mutated diagnostic-only detail"
#else
diagnosticOnlyDetail = "caller-supplied pb bytes are diagnostic input and cannot establish source custody or Phase-50 runtime truth"
#endif

data PbTrackedMode
  = PbRegularNonExecutable
  | PbRegularExecutable
  | PbSymbolicLink
  | PbOtherMode
  deriving (Eq, Ord, Show)

data PbTrackedFile = PbTrackedFile
  { pbTrackedPath :: FilePath
  , pbTrackedMode :: PbTrackedMode
  , pbTrackedBytes :: ByteString
  }
  deriving (Eq, Ord, Show)

data PbResourceMetrics = PbResourceMetrics
  { resourceSourceBytes :: Int
  , resourcePhysicalLines :: Int
  , resourceAstNodes :: Int
  , resourceLexicalUnits :: Int
  , resourceSyntaxDepth :: Int
  , resourceCallMarkers :: Int
  , resourceEffectMarkers :: Int
  , resourceControlFlowMarkers :: Int
  , resourceProblemMarkers :: Int
  }
  deriving (Eq, Ord, Show)

maximumInputFiles, exactBootstrapBytes, maximumSourceBytes :: Int
#if defined(VALIDATION_PB_GRAMMAR_WIDEN_INVENTORY_MUTANT)
maximumInputFiles = 2
#else
maximumInputFiles = 1
#endif

maximumPathCharacters, maximumModeCharacters :: Int
#if defined(VALIDATION_PB_GRAMMAR_PATH_LIMIT_WIDEN_MUTANT)
maximumPathCharacters = 1025
#else
maximumPathCharacters = 1024
#endif
#if defined(VALIDATION_PB_GRAMMAR_MODE_LIMIT_WIDEN_MUTANT)
maximumModeCharacters = 7
#else
maximumModeCharacters = 6
#endif
exactBootstrapBytes = 4770
#if defined(VALIDATION_PB_GRAMMAR_SOURCE_BYTE_LIMIT_WIDEN_MUTANT)
maximumSourceBytes = 4771
#else
maximumSourceBytes = 4770
#endif

maximumPhysicalLines, maximumAstNodes, maximumLexicalUnits, maximumSyntaxDepth :: Int
#if defined(VALIDATION_PB_GRAMMAR_PHYSICAL_LINE_LIMIT_WIDEN_MUTANT)
maximumPhysicalLines = 129
#else
maximumPhysicalLines = 128
#endif
#if defined(VALIDATION_PB_GRAMMAR_AST_LIMIT_WIDEN_MUTANT)
maximumAstNodes = 513
#else
maximumAstNodes = 512
#endif
#if defined(VALIDATION_PB_GRAMMAR_TOKEN_LIMIT_WIDEN_MUTANT)
maximumLexicalUnits = 1025
#else
maximumLexicalUnits = 1024
#endif
#if defined(VALIDATION_PB_GRAMMAR_DEPTH_LIMIT_WIDEN_MUTANT)
maximumSyntaxDepth = 17
#else
maximumSyntaxDepth = 16
#endif

maximumCallMarkers, maximumEffectMarkers, maximumControlFlowMarkers :: Int
#if defined(VALIDATION_PB_GRAMMAR_CALL_LIMIT_WIDEN_MUTANT)
maximumCallMarkers = 129
#else
maximumCallMarkers = 128
#endif
#if defined(VALIDATION_PB_GRAMMAR_EFFECT_LIMIT_WIDEN_MUTANT)
maximumEffectMarkers = 65
#else
maximumEffectMarkers = 64
#endif
#if defined(VALIDATION_PB_GRAMMAR_CONTROL_FLOW_LIMIT_WIDEN_MUTANT)
maximumControlFlowMarkers = 33
#else
maximumControlFlowMarkers = 32
#endif

maximumProblemMarkers, maximumDiagnosticProblems :: Int
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_MARKER_LIMIT_WIDEN_MUTANT)
maximumProblemMarkers = 65
#else
maximumProblemMarkers = 64
#endif
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_LIMIT_WIDEN_MUTANT)
maximumDiagnosticProblems = 65
#else
maximumDiagnosticProblems = 64
#endif

expectedBootstrapSha256 :: Text
expectedBootstrapSha256 =
  "e210494d3ad4bcaad716daed5bb89cb5611107547e83eb018a6369e134cd5418"

preflightRawInventory
  :: [(FilePath, Text, ByteString)]
  -> Either [Finding] ([PbTrackedFile], [Finding])
preflightRawInventory rawInventory =
  case boundedLength (maximumInputFiles + 1) rawInventory of
    observedCount
      | observedCount > maximumInputFiles ->
          Left
            [ preflightFinding
                "PB-GRAMMAR-RESOURCE-LIMIT"
                ( "input-files exceeds the "
                    <> decimal maximumInputFiles
                    <> "-entry bound; observed at least "
                    <> decimal observedCount
                )
            ]
      | observedCount /= 1 ->
#if defined(VALIDATION_PB_GRAMMAR_EXACT_INVENTORY_BYPASS_MUTANT)
          Right ([], [])
#else
          Left
            [ preflightFinding
                "PB-GRAMMAR-INVENTORY-EXACT"
                ("expected exactly one tracked pb file; observed " <> decimal observedCount)
            ]
#endif
    _ -> case rawInventory of
      [(path, mode, bytes)] ->
        case preflightSingleHard path mode bytes of
          [] ->
            Right
              ( [PbTrackedFile path (trackedMode mode) bytes]
              , preflightIdentityProblems bytes
              )
          problems -> Left problems
      _ ->
        Left
          [ preflightFinding
              "PB-GRAMMAR-INVENTORY-EXACT"
              "bounded inventory traversal did not retain exactly one item"
          ]

preflightSingleHard :: FilePath -> Text -> ByteString -> [Finding]
preflightSingleHard path mode bytes =
  pathResourceProblems
    <> modeResourceProblems
    <> pathProblems
    <> modeProblems
    <> byteResourceProblems
    <> metricProblems
    <> byteCountProblems
 where
  metrics = scanResourceMetrics bytes
  pathCharacterCount = boundedLength (maximumPathCharacters + 1) path
  pathResourceProblems =
    [ resourceFinding "path-characters" maximumPathCharacters pathCharacterCount
    | pathCharacterCount > maximumPathCharacters
    ]
  modeResourceProblems =
    [ resourceFinding "mode-characters" maximumModeCharacters (Text.length mode)
    | Text.length mode > maximumModeCharacters
    ]
  pathProblems =
#if defined(VALIDATION_PB_GRAMMAR_PATH_BYPASS_MUTANT)
    []
#else
    [ preflightFinding
        "PB-GRAMMAR-PATH-EXACT"
        ("expected pb/__main__.py; observed " <> Text.pack (show path))
    | null pathResourceProblems
    , path /= "pb/__main__.py"
    ]
#endif
  modeProblems =
#if defined(VALIDATION_PB_GRAMMAR_MODE_BYPASS_MUTANT)
    []
#else
    [ preflightFinding
        "PB-GRAMMAR-MODE-EXACT"
        ("expected Git mode 100644; observed " <> Text.pack (show mode))
    | null modeResourceProblems
    , mode /= "100644"
    ]
#endif
  byteResourceProblems =
    [ resourceFinding "source-bytes" maximumSourceBytes (ByteString.length bytes)
    | ByteString.length bytes > maximumSourceBytes
    ]
  metricProblems
    | not (null byteResourceProblems) = []
    | otherwise = resourceMetricProblems metrics
  byteCountProblems =
#if defined(VALIDATION_PB_GRAMMAR_EXACT_BYTE_COUNT_BYPASS_MUTANT)
    exactBootstrapBytes `seq` []
#else
    [ preflightFinding
        "PB-GRAMMAR-BYTE-COUNT-EXACT"
        ( "expected exactly 4770 bytes; observed "
            <> decimal (ByteString.length bytes)
        )
    | ByteString.length bytes /= exactBootstrapBytes
    ]
#endif


preflightIdentityProblems :: ByteString -> [Finding]
preflightIdentityProblems bytes = digestProblems <> exactBytesProblems
 where
  observedDigest = sha256Text bytes
  digestProblems =
#if defined(VALIDATION_PB_GRAMMAR_DIGEST_BYPASS_MUTANT)
    observedDigest `seq` []
#else
    [ preflightFinding
        "PB-GRAMMAR-DIGEST-EXACT"
        ( "expected independently frozen SHA-256 "
            <> expectedBootstrapSha256
            <> "; observed "
            <> observedDigest
        )
    | observedDigest /= expectedBootstrapSha256
    ]
#endif
  exactBytesProblems =
#if defined(VALIDATION_PB_GRAMMAR_SKIP_CANONICAL_BYTES_MUTANT)
    canonicalBootstrapBytes `seq` []
#else
    [ preflightFinding
        "PB-GRAMMAR-BYTES-EXACT"
        "the digest-bound subject differs from the private canonical byte declaration"
    | bytes /= canonicalBootstrapBytes
    ]
#endif

trackedMode :: Text -> PbTrackedMode
trackedMode "100644" = PbRegularNonExecutable
trackedMode "100755" = PbRegularExecutable
trackedMode "120000" = PbSymbolicLink
trackedMode _ = PbOtherMode

preflightFinding :: Text -> Text -> Finding
preflightFinding code detail =
  finding
    (mapPreflightFindingCode code)
    (Text.unpack preflightFindingSubject)
    (mapPreflightFindingDetail detail)

mapPreflightFindingCode :: Text -> Text
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_FINDING_CODE_MAPPING_MUTANT)
mapPreflightFindingCode code = code <> "-MUTANT"
#else
mapPreflightFindingCode code = code
#endif

preflightFindingSubject :: Text
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_FINDING_SUBJECT_MAPPING_MUTANT)
preflightFindingSubject = diagnosticSubject <> ".mutant"
#else
preflightFindingSubject = diagnosticSubject
#endif

mapPreflightFindingDetail :: Text -> Text
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_FINDING_DETAIL_MAPPING_MUTANT)
mapPreflightFindingDetail detail = detail <> "-mutant"
#else
mapPreflightFindingDetail detail = detail
#endif

resourceFinding :: Text -> Int -> Int -> Finding
resourceFinding resourceName limit observed =
  preflightFinding
    resourceFindingCode
    ( mapResourceFindingName resourceName
        <> " exceeds the "
        <> decimal (mapResourceFindingLimit limit)
        <> " bound; observed "
        <> decimal (mapResourceFindingObserved observed)
    )

resourceFindingCode :: Text
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_FINDING_CODE_MAPPING_MUTANT)
resourceFindingCode = "PB-GRAMMAR-RESOURCE-LIMIT-MUTANT"
#else
resourceFindingCode = "PB-GRAMMAR-RESOURCE-LIMIT"
#endif

mapResourceFindingName :: Text -> Text
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_FINDING_NAME_MAPPING_MUTANT)
mapResourceFindingName name = name <> "-mutant"
#else
mapResourceFindingName name = name
#endif

mapResourceFindingLimit :: Int -> Int
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_FINDING_LIMIT_MAPPING_MUTANT)
mapResourceFindingLimit limit = limit + 1
#else
mapResourceFindingLimit limit = limit
#endif

mapResourceFindingObserved :: Int -> Int
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_FINDING_OBSERVED_MAPPING_MUTANT)
mapResourceFindingObserved observed = observed + 1
#else
mapResourceFindingObserved observed = observed
#endif

resourceMetricProblems :: PbResourceMetrics -> [Finding]
resourceMetricProblems metrics =
  concat
    [ over "physical-lines" maximumPhysicalLines (resourcePhysicalLines metrics)
    , over "ast-nodes" maximumAstNodes (resourceAstNodes metrics)
    , over "lexical-tokens" maximumLexicalUnits (resourceLexicalUnits metrics)
    , over "syntax-depth" maximumSyntaxDepth (resourceSyntaxDepth metrics)
    , over "resolved-call-markers" maximumCallMarkers (resourceCallMarkers metrics)
    , over "potential-effect-markers" maximumEffectMarkers (resourceEffectMarkers metrics)
    , over "control-flow-markers" maximumControlFlowMarkers (resourceControlFlowMarkers metrics)
    , over "problem-markers" maximumProblemMarkers (resourceProblemMarkers metrics)
    ]
 where
  over name limit observed = [resourceFinding name limit observed | observed > limit]

scanResourceMetrics :: ByteString -> PbResourceMetrics
scanResourceMetrics bytes =
  PbResourceMetrics
    { resourceSourceBytes = ByteString.length bytes
    , resourcePhysicalLines = countByte 10 bytes
    , resourceAstNodes = astNodeMarkers bytes
    , resourceLexicalUnits = lexicalTokenCount bytes
    , resourceSyntaxDepth =
        max (maximumSyntaxNesting bytes) (maximumIndentationDepth bytes)
    , resourceCallMarkers = countByte 40 bytes
    , resourceEffectMarkers =
        sum (map (`countSubstring` bytes) effectMarkers)
    , resourceControlFlowMarkers =
        sum (map (`countSubstring` bytes) controlFlowMarkers)
    , resourceProblemMarkers =
        ByteString.foldl'
          (\count byte -> if byte == 0 || byte == 9 || byte == 13 || byte > 126 then count + 1 else count)
          0
          bytes
    }

countByte :: Word8 -> ByteString -> Int
countByte byte = ByteString.foldl' (\count found -> if found == byte then count + 1 else count) 0

astNodeMarkers :: ByteString -> Int
astNodeMarkers bytes =
  countByte 10 bytes
    + sum [countByte marker bytes | marker <- [40, 91, 123, 61, 43, 47, 44]]

lexicalTokenCount :: ByteString -> Int
lexicalTokenCount = snd . ByteString.foldl' step (0 :: Int, 0 :: Int)
 where
  step (3, count) 34 = (0, count)
  step state@(3, _) _ = state
  step (1, count) byte
    | nameContinueByte byte = (1, count)
    | otherwise = start count byte
  step (2, count) byte
    | digitByte byte = (2, count)
    | otherwise = start count byte
  step (_, count) byte = start count byte
  start count byte
    | byte == 32 || byte == 10 || byte == 9 || byte == 13 = (0, count)
    | byte == 34 = (3, count + 1)
    | nameStartByte byte = (1, count + 1)
    | digitByte byte = (2, count + 1)
    | otherwise = (0, count + 1)
  nameStartByte byte =
    byte == 95
      || (byte >= 65 && byte <= 90)
      || (byte >= 97 && byte <= 122)
  nameContinueByte byte = nameStartByte byte || digitByte byte
  digitByte byte = byte >= 48 && byte <= 57

countSubstring :: ByteString -> ByteString -> Int
countSubstring needle = go 0
 where
  go count haystack
    | ByteString.null needle = count
    | otherwise =
        let (_, found) = ByteString.breakSubstring needle haystack
         in if ByteString.null found
              then count
              else go (count + 1) (ByteString.drop (ByteString.length needle) found)

effectMarkers :: [ByteString]
effectMarkers =
  [ ".is_file("
  , ".read_bytes("
  , ".mkdir("
  , "urlopen("
  , ".write_bytes("
  , ".chmod("
  , "subprocess.run("
  , "os.execv("
  , "platform.system("
  , "platform.machine("
  , ".repository_root("
  , ".platform("
  , ".ensure_ghcup("
  , ".environment("
  , ".run("
  , ".capture("
  , ".handoff("
  ]

controlFlowMarkers :: [ByteString]
controlFlowMarkers = ["\ndef ", "\n    def ", "\nif ", "\n    if ", "\n        if ", "\nreturn ", "\n    return ", "\n        return ", "\nraise ", "\n    raise ", "\n        raise ", "\nclass "]

maximumSyntaxNesting :: ByteString -> Int
maximumSyntaxNesting = snd . ByteString.foldl' step (0, 0)
 where
  step (depth, greatest) byte
    | byte `elem` [40, 91, 123] =
        let next = depth + 1 in (next, max greatest next)
    | byte `elem` [41, 93, 125] = (max 0 (depth - 1), greatest)
    | otherwise = (depth, greatest)

maximumIndentationDepth :: ByteString -> Int
maximumIndentationDepth bytes = greatest finalState
 where
  finalState = ByteString.foldl' step (True, 0 :: Int, 0 :: Int) bytes
  greatest (_, _, value) = value
  step (_, _, found) 10 = (True, 0, found)
  step (True, spaces, found) 32 = (True, spaces + 1, found)
  step (True, spaces, found) _ = (False, spaces, max found (spaces `div` 4))
  step state _ = state

preflightObservations :: [(FilePath, Text, ByteString)] -> [Observation]
preflightObservations rawInventory =
  orderPreflightObservations
    ( retained retainPreflightInputFileCountObservation
        [observation "input.file-count" (decimal (boundedLength 2 rawInventory))]
        <> retained retainPreflightLimitInputFilesObservation
          [observation "limit.input-files" (decimal maximumInputFiles)]
        <> retained retainPreflightExpectedPathObservation
          [observation "expected.path" "pb/__main__.py"]
        <> retained retainPreflightExpectedModeObservation
          [observation "expected.mode" "100644"]
        <> retained retainPreflightExpectedBytesObservation
          [observation "expected.bytes" "4770"]
        <> retained retainPreflightExpectedSha256Observation
          [observation "expected.sha256" expectedBootstrapSha256]
        <> case (boundedLength 2 rawInventory, take 1 rawInventory) of
          (1, [(path, mode, bytes)]) ->
            retained retainPreflightInputPathCharactersObservation
              [observation "input.path-characters" (decimal (boundedLength 1025 path))]
              <> retained retainPreflightInputModeCharactersObservation
                [observation "input.mode-characters" (decimal (Text.length mode))]
              <> retained retainPreflightInputBytesObservation
                [observation "input.bytes" (decimal (ByteString.length bytes))]
              <> retained retainPreflightInputPathObservation
                [observation "input.path" (Text.pack path) | boundedLength 1025 path <= 1024]
              <> retained retainPreflightInputModeObservation
                [observation "input.mode" mode | Text.length mode <= 6]
              <> if ByteString.length bytes <= maximumSourceBytes
                then
                  retained retainPreflightInputSha256Observation
                    [observation "input.sha256" (sha256Text bytes)]
                    <> resourceMetricObservations (scanResourceMetrics bytes)
                else []
          _ -> []
    )

inventoryObservations :: [PbTrackedFile] -> [Observation]
inventoryObservations inventory =
  preflightObservations
    [ (pbTrackedPath item, renderTrackedMode (pbTrackedMode item), pbTrackedBytes item)
    | item <- inventory
    ]

renderTrackedMode :: PbTrackedMode -> Text
renderTrackedMode PbRegularNonExecutable = "100644"
renderTrackedMode PbRegularExecutable = "100755"
renderTrackedMode PbSymbolicLink = "120000"
renderTrackedMode PbOtherMode = "other"

resourceMetricObservations :: PbResourceMetrics -> [Observation]
resourceMetricObservations metrics =
  orderResourceMetricObservations
    ( retained retainResourceSourceBytesObservation
    [observation "resource.source-bytes" (decimal (resourceSourceBytes metrics))]
    <> retained retainResourcePhysicalLinesObservation
      [observation "resource.physical-lines" (decimal (resourcePhysicalLines metrics))]
    <> retained retainResourceAstNodesObservation
      [observation "resource.ast-nodes" (decimal (resourceAstNodes metrics))]
    <> retained retainResourceLexicalTokensObservation
      [observation "resource.lexical-tokens" (decimal (resourceLexicalUnits metrics))]
    <> retained retainResourceSyntaxDepthObservation
      [observation "resource.syntax-depth" (decimal (resourceSyntaxDepth metrics))]
    <> retained retainResourceCallMarkersObservation
      [observation "resource.call-markers" (decimal (resourceCallMarkers metrics))]
    <> retained retainResourceEffectMarkersObservation
      [observation "resource.effect-markers" (decimal (resourceEffectMarkers metrics))]
    <> retained retainResourceControlFlowMarkersObservation
      [observation "resource.control-flow-markers" (decimal (resourceControlFlowMarkers metrics))]
    <> retained retainResourceProblemMarkersObservation
      [observation "resource.problem-markers" (decimal (resourceProblemMarkers metrics))]
    <> retained retainLimitSourceBytesObservation
      [observation "limit.source-bytes" (decimal maximumSourceBytes)]
    <> retained retainLimitPathCharactersObservation
      [observation "limit.path-characters" (decimal maximumPathCharacters)]
    <> retained retainLimitModeCharactersObservation
      [observation "limit.mode-characters" (decimal maximumModeCharacters)]
    <> retained retainLimitPhysicalLinesObservation
      [observation "limit.physical-lines" (decimal maximumPhysicalLines)]
    <> retained retainLimitAstNodesObservation
      [observation "limit.ast-nodes" (decimal maximumAstNodes)]
    <> retained retainLimitLexicalTokensObservation
      [observation "limit.lexical-tokens" (decimal maximumLexicalUnits)]
    <> retained retainLimitSyntaxDepthObservation
      [observation "limit.syntax-depth" (decimal maximumSyntaxDepth)]
    <> retained retainLimitCallMarkersObservation
      [observation "limit.call-markers" (decimal maximumCallMarkers)]
    <> retained retainLimitEffectMarkersObservation
      [observation "limit.effect-markers" (decimal maximumEffectMarkers)]
    <> retained retainLimitControlFlowMarkersObservation
      [observation "limit.control-flow-markers" (decimal maximumControlFlowMarkers)]
    <> retained retainLimitProblemMarkersObservation
      [observation "limit.problem-markers" (decimal maximumProblemMarkers)]
    <> retained retainLimitProblemsObservation
      [observation "limit.problems" (decimal maximumDiagnosticProblems)]
    )

boundedLength :: Int -> [value] -> Int
boundedLength limit = go 0
 where
  go count _ | count >= limit = count
  go count [] = count
  go count (_ : rest) = go (count + 1) rest

decimal :: Int -> Text
decimal = Text.pack . show

sha256Text :: ByteString -> Text
sha256Text bytes = Text.pack (show (Crypto.hash bytes :: Crypto.Digest Crypto.SHA256))

data PyBinaryOperator
  = PyAdd
  | PyPathJoin
  | PyEqual
  | PyNotEqual
  | PyAnd
  deriving (Eq, Ord, Show)

data PyArgument
  = PyPositional PyExpr
  | PyKeyword Text PyExpr
  deriving (Eq, Ord, Show)

data PyExpr
  = PyName Text
  | PyString Text
  | PyInteger Integer
  | PyBoolean Bool
  | PyEmptyDictionary
  | PyTuple [PyExpr]
  | PyList [PyExpr]
  | PyAttribute PyExpr Text
  | PyIndex PyExpr PyExpr
  | PySlice (Maybe PyExpr) (Maybe PyExpr)
  | PyCall PyExpr [PyArgument]
  | PyBinary PyBinaryOperator PyExpr PyExpr
  deriving (Eq, Ord, Show)

data PyStmt
  = PyImport [Text]
  | PyFromImport [Text] Text
  | PyAssign PyExpr PyExpr
  | PyClass Text [PyStmt]
  | PyFunction Text [Text] [PyStmt]
  | PyIf PyExpr [PyStmt]
  | PyReturn PyExpr
  | PyRaise PyExpr
  | PyExpression PyExpr
  deriving (Eq, Ord, Show)

newtype BootstrapAst = BootstrapAst
  { bootstrapStatements :: [PyStmt]
  }
  deriving (Eq, Ord, Show)

data ImportBinding = ImportBinding
  { importBoundName :: Text
  , importQualifiedName :: Text
  }
  deriving (Eq, Ord, Show)

data BindingKind
  = ImportedModuleBinding Text
  | ImportedNameBinding Text
  | ConstantBinding
  | ClassBinding
  | FunctionBinding
  | ParameterBinding
  | LocalValueBinding
  deriving (Eq, Ord, Show)

data Binding = Binding
  { bindingScope :: Text
  , bindingName :: Text
  , bindingKind :: BindingKind
  }
  deriving (Eq, Ord, Show)

data ResolvedTarget
  = ResolvedBuiltin Text
  | ResolvedStandardLibrary Text
  | ResolvedBootstrapConstructor
  | ResolvedBootstrapFunction Text
  | ResolvedAdapterMethod Text
  | ResolvedValueMethod Text
  deriving (Eq, Ord, Show)

data ResolvedCall = ResolvedCall
  { resolvedCaller :: Text
  , resolvedSyntax :: Text
  , resolvedTarget :: ResolvedTarget
  }
  deriving (Eq, Ord, Show)

data EffectOrigin
  = InterpreterImportStartup
  | ApplicationRequested
  deriving (Eq, Ord, Show)

data EffectRoute
  = InterpreterStartupRoute
  | BootstrapAdapterRoute Text
  | BootstrapAdapterInvocationRoute Text Text
  deriving (Eq, Ord, Show)

data PotentialEffectKind
  = ImportStartupEffect
  | RepositoryObservationEffect
  | PlatformObservationEffect
  | NetworkAcquireEffect
  | DirectoryCreateEffect
  | FileWriteEffect
  | FileObservationEffect
  | PermissionChangeEffect
  | EnvironmentObservationEffect
  | ChildProcessEffect
  | ProcessReplacementEffect
  deriving (Eq, Ord, Show)

data PotentialEffect = PotentialEffect
  { potentialEffectOrigin :: EffectOrigin
  , potentialEffectKind :: PotentialEffectKind
  , potentialEffectCall :: Text
  , potentialEffectRoute :: EffectRoute
  }
  deriving (Eq, Ord, Show)

data CfgNodeKind
  = CfgEntry
  | CfgStatement
  | CfgBranch
  | CfgReturn
  | CfgRaise
  | CfgHandoffRequest
  deriving (Eq, Ord, Show)

data CfgNode = CfgNode
  { cfgNodeId :: Int
  , cfgNodeKind :: CfgNodeKind
  , cfgNodeLabel :: Text
  }
  deriving (Eq, Ord, Show)

data CfgEdgeKind
  = CfgSequential
  | CfgBranchTrue
  | CfgBranchFalse
  deriving (Eq, Ord, Show)

data CfgEdge = CfgEdge
  { cfgEdgeFrom :: Int
  , cfgEdgeTo :: Int
  , cfgEdgeKind :: CfgEdgeKind
  }
  deriving (Eq, Ord, Show)

data FunctionControlFlow = FunctionControlFlow
  { cfgFunction :: Text
  , cfgEntryNode :: Int
  , cfgNodes :: [CfgNode]
  , cfgEdges :: [CfgEdge]
  , cfgFallsThrough :: Bool
  }
  deriving (Eq, Ord, Show)

newtype ControlFlowGraph = ControlFlowGraph
  { cfgFunctions :: [FunctionControlFlow]
  }
  deriving (Eq, Ord, Show)

data PlatformAdapter
  = LinuxAmd64Adapter
  | LinuxArm64Adapter
  | DarwinArm64Adapter
  | WindowsAmd64Adapter
  deriving (Eq, Ord, Enum, Bounded, Show)

data PlatformArtifact = PlatformArtifact
  { artifactAdapter :: PlatformAdapter
  , artifactSystem :: Text
  , artifactMachine :: Text
  , artifactLabel :: Text
  , artifactUrl :: Text
  , artifactSha256 :: Text
  , artifactExecutableName :: Text
  , artifactManagedExecutableSuffix :: Text
  }
  deriving (Eq, Ord, Show)

data PlatformLimitation
  = WindowsAmd64RuntimeFidelityDeferredToPhase50
  | AllOtherPlatformsRefused
  deriving (Eq, Ord, Show)

data ArgvProvenance
  = OpaqueUserArgvTail
      { argvSourceExpression :: Text
      , argvInjectionParameter :: Text
      , argvExecutableSlot :: Text
      }
  deriving (Eq, Ord, Show)

data BinaryProvenance = BinaryProvenance
  { binaryBuildTarget :: Text
  , binaryGhcupVersion :: Text
  , binaryCompilerVersion :: Text
  , binaryCabalVersion :: Text
  , binaryLocator :: Text
  , binaryHandoff :: Text
  }
  deriving (Eq, Ord, Show)

data RuntimeBoundary
  = RuntimeTruthDeferredToPhase50
  deriving (Eq, Ord, Show)

data RuntimeResidue
  = AuthenticatedPythonInterpreterResidue
  | PythonIsolationFlagsOrderResidue
  | AbsolutePythonDirectorySubjectResidue
  | StdlibImportStartupResidue
  | StandardLibraryNativeTransitiveSemanticsResidue
  | AmbientInterpreterEnvironmentResidue
  | NetworkProxyEnvironmentResidue
  | ChildToolDefaultSearchPathResidue
  | NetworkTransportAndCertificateResidue
  | SymlinkAndToctouResidue
  | AtomicArtifactPublicationResidue
  | ExecutableModeObservationResidue
  | GhcupManagedToolRuntimeResidue
  | CabalListBinPathObservationResidue
  | SourceAndBinaryPathIdentityResidue
  | WindowsGhcupRuntimeResidue
  | FakeAdapterObservationResidue
  | ConcreteAdapterEffectObservationResidue
  | UnchangedArgumentTailResidue
  | ExecReplacementResidue
  | HandoffExitPropagationResidue
  deriving (Eq, Ord, Show)

data InjectionSeamProof = InjectionSeamProof
  { seamFunctionName :: Text
  , seamAdapterParameter :: Text
  , seamArgumentsParameter :: Text
  , seamConcreteConstructionScope :: Text
  , seamMainGuardExpression :: Text
  }
  deriving (Eq, Ord, Show)

-- | Declarative Phase-50 caller requirement.  Static source admission carries
-- this contract forward but does not claim that an interpreter used it.
data Phase50InvocationContract
  = RequiredPhase50PythonDirectoryInvocation
      { requiredInterpreterIdentity :: Text
      , requiredIsolationFlagsInOrder :: [Text]
      , requiredAbsoluteDirectorySubject :: Text
      , requiredOpaqueArgumentTail :: Text
      }
  deriving (Eq, Ord, Show)

-- | Proof about the explicit mapping passed to child processes only.  Ambient
-- interpreter, proxy, and transitive default-search behaviour remains residue.
data ClosedEnvironmentProof = ClosedEnvironmentProof
  { environmentStartsEmpty :: Bool
  , environmentExactKeys :: [Text]
  , environmentContainedPathKeys :: [Text]
  , childEnvironmentMappingExact :: Bool
  }
  deriving (Eq, Ord, Show)

data GhcupEnsureProof = GhcupEnsureProof
  { ensureMatchingExistingReturnsBeforeMutation :: Bool
  , ensureMismatchedExistingFailsClosed :: Bool
  , ensureAbsentArtifactVerifiedBeforeWrite :: Bool
  }
  deriving (Eq, Ord, Show)

data ToolchainExecutableProof = ToolchainExecutableProof
  { toolchainRootProvenance :: Text
  , ghcupExecutableProvenance :: Text
  , ghcExecutableProvenance :: Text
  , cabalExecutableProvenance :: Text
  , childArgvZeroProvenance :: Text
  }
  deriving (Eq, Ord, Show)

-- | Private, digest-bound projection of the transient AST analysis.  No AST,
-- parser result, or success branch survives this boundary.  Every field is
-- projected into the returned CheckResult, so a retained value cannot become
-- an unobserved source of authority.
data PbBootstrapProof = PbBootstrapProof
  { proofSubjectPath :: FilePath
  , proofSubjectMode :: Text
  , proofSubjectBytes :: Int
  , proofSubjectSha256 :: Text
  , proofExpectedSha256 :: Text
  , proofResourceMetrics :: PbResourceMetrics
  , proofImportClosure :: [Text]
  , proofResolvedCallCount :: Int
  , proofPotentialEffectCount :: Int
  , proofControlFlowSummary :: [(Text, Int, Int, Bool, Int)]
  , proofPlatformLabels :: [Text]
  , proofStaticClaims :: [Text]
  , proofRuntimeResidue :: [RuntimeResidue]
  }
  deriving (Eq, Show)

proofObservations :: PbBootstrapProof -> [Observation]
proofObservations proof =
  retained retainSubjectProjection
    ( orderProofSubjectObservations
        ( retained retainProofSubjectPathObservation
        [observation "proof.subject.path" (Text.pack (proofSubjectPath proof))]
        <> retained retainProofSubjectModeObservation
          [observation "proof.subject.mode" (proofSubjectMode proof)]
        <> retained retainProofSubjectBytesObservation
          [observation "proof.subject.bytes" (decimal (proofSubjectBytes proof))]
        <> retained retainProofSubjectSha256Observation
          [observation "proof.subject.sha256" (proofSubjectSha256 proof)]
        <> retained retainProofExpectedSha256Observation
          [observation "proof.expected.sha256" (proofExpectedSha256 proof)]
        )
    )
    <> retained retainResourceProjection
      (resourceMetricObservations (proofResourceMetrics proof))
    <> retained retainImportProjection
      [ observation
          "proof.import-closure"
          (Text.intercalate importMemberSeparator (orderProofImportMembers (filter retainProofImportMember (proofImportClosure proof))))
      ]
    <> retained retainCallProjection
      [observation "proof.resolved-call-count" (decimal (proofResolvedCallCount proof))]
    <> retained retainEffectProjection
      [observation "proof.potential-effect-count" (decimal (proofPotentialEffectCount proof))]
    <> retained retainControlFlowProjection
      [ observation
          "proof.control-flow"
          (renderControlFlowSummary (orderProofControlFlowEntries (filter retainProofControlFlowEntry (proofControlFlowSummary proof))))
      ]
    <> retained retainPlatformProjection
      [ observation
          "proof.platform-labels"
          (Text.intercalate platformLabelSeparator (orderProofPlatformLabels (filter retainProofPlatformLabel (proofPlatformLabels proof))))
      ]
    <> retained retainStaticClaimProjection
      [ observation
          "proof.static-claims"
          (Text.intercalate staticClaimSeparator (orderProofStaticClaims (filter retainProofStaticClaim (proofStaticClaims proof))))
      ]
    <> retained retainRuntimeProjection
      [ observation
          "proof.runtime-residue"
          (Text.intercalate runtimeResidueSeparator (map (Text.pack . show) (orderProofRuntimeResidues (proofRuntimeResidue proof))))
      ]

retained :: Bool -> [value] -> [value]
retained True values = values
retained False _ = []

orderPreflightObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_OBSERVATION_ORDER_MUTANT)
orderPreflightObservations = reverse
#else
orderPreflightObservations = id
#endif

orderResourceMetricObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_OBSERVATION_ORDER_MUTANT)
orderResourceMetricObservations = reverse
#else
orderResourceMetricObservations = id
#endif

orderProofSubjectObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_PB_GRAMMAR_PROOF_SUBJECT_OBSERVATION_ORDER_MUTANT)
orderProofSubjectObservations = reverse
#else
orderProofSubjectObservations = id
#endif

orderProofImportMembers :: [Text] -> [Text]
#if defined(VALIDATION_PB_GRAMMAR_PROOF_IMPORT_MEMBER_ORDER_MUTANT)
orderProofImportMembers = reverse
#else
orderProofImportMembers = id
#endif

orderProofControlFlowEntries :: [(Text, Int, Int, Bool, Int)] -> [(Text, Int, Int, Bool, Int)]
#if defined(VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_ENTRY_ORDER_MUTANT)
orderProofControlFlowEntries = reverse
#else
orderProofControlFlowEntries = id
#endif

orderProofPlatformLabels :: [Text] -> [Text]
#if defined(VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_LABEL_ORDER_MUTANT)
orderProofPlatformLabels = reverse
#else
orderProofPlatformLabels = id
#endif

orderProofStaticClaims :: [Text] -> [Text]
#if defined(VALIDATION_PB_GRAMMAR_PROOF_STATIC_CLAIM_ORDER_MUTANT)
orderProofStaticClaims = reverse
#else
orderProofStaticClaims = id
#endif

orderProofRuntimeResidues :: [RuntimeResidue] -> [RuntimeResidue]
#if defined(VALIDATION_PB_GRAMMAR_PROOF_RUNTIME_RESIDUE_ORDER_MUTANT)
orderProofRuntimeResidues = reverse
#else
orderProofRuntimeResidues = id
#endif

importMemberSeparator, platformLabelSeparator, staticClaimSeparator, runtimeResidueSeparator :: Text
#if defined(VALIDATION_PB_GRAMMAR_PROOF_IMPORT_MEMBER_SEPARATOR_MUTANT)
importMemberSeparator = ";"
#else
importMemberSeparator = ","
#endif
#if defined(VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_LABEL_SEPARATOR_MUTANT)
platformLabelSeparator = ";"
#else
platformLabelSeparator = ","
#endif
#if defined(VALIDATION_PB_GRAMMAR_PROOF_STATIC_CLAIM_SEPARATOR_MUTANT)
staticClaimSeparator = ";"
#else
staticClaimSeparator = "\n"
#endif
#if defined(VALIDATION_PB_GRAMMAR_PROOF_RUNTIME_RESIDUE_SEPARATOR_MUTANT)
runtimeResidueSeparator = ";"
#else
runtimeResidueSeparator = ","
#endif

retainProofImportMember :: Text -> Bool
retainProofImportMember value = case value of
  "hashlib=hashlib" -> retainProofImportHashlib
  "os=os" -> retainProofImportOs
  "platform=platform" -> retainProofImportPlatform
  "subprocess=subprocess" -> retainProofImportSubprocess
  "sys=sys" -> retainProofImportSys
  "urllib=urllib.request" -> retainProofImportUrllibRequest
  "Path=pathlib.Path" -> retainProofImportPathlibPath
  _ -> True

retainProofPlatformLabel :: Text -> Bool
retainProofPlatformLabel value = case value of
  "linux-amd64" -> retainProofPlatformLinuxAmd64
  "linux-arm64" -> retainProofPlatformLinuxArm64
  "darwin-arm64" -> retainProofPlatformDarwinArm64
  "windows-amd64" -> retainProofPlatformWindowsAmd64
  _ -> True

retainProofStaticClaim :: Text -> Bool
retainProofStaticClaim value
  | "argv|" `Text.isPrefixOf` value = retainProofStaticArgvClaim
  | "binary|" `Text.isPrefixOf` value = retainProofStaticBinaryClaim
  | "injection|" `Text.isPrefixOf` value = retainProofStaticInjectionClaim
  | "phase50-invocation|" `Text.isPrefixOf` value = retainProofStaticPhase50InvocationClaim
  | "ensure|" `Text.isPrefixOf` value = retainProofStaticEnsureClaim
  | "environment|" `Text.isPrefixOf` value = retainProofStaticEnvironmentClaim
  | "executables|" `Text.isPrefixOf` value = retainProofStaticExecutablesClaim
  | "platform-limitations|" `Text.isPrefixOf` value = retainProofStaticPlatformLimitationsClaim
  | "runtime-boundary|" `Text.isPrefixOf` value = retainProofStaticRuntimeBoundaryClaim
  | otherwise = True

retainProofControlFlowEntry :: (Text, Int, Int, Bool, Int) -> Bool
retainProofControlFlowEntry (name, _, _, _, _) = case name of
  "select_artifact" -> retainProofControlSelectArtifact
  "BootstrapAdapter.repository_root" -> retainProofControlRepositoryRoot
  "BootstrapAdapter.platform" -> retainProofControlPlatform
  "BootstrapAdapter.ensure_ghcup" -> retainProofControlEnsureGhcup
  "BootstrapAdapter.environment" -> retainProofControlEnvironment
  "BootstrapAdapter.run" -> retainProofControlRun
  "BootstrapAdapter.capture" -> retainProofControlCapture
  "BootstrapAdapter.handoff" -> retainProofControlHandoff
  "bootstrap" -> retainProofControlBootstrap
  "main" -> retainProofControlMain
  _ -> True

retainProofImportHashlib :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_IMPORT_HASHLIB_MEMBER_DROP_MUTANT)
retainProofImportHashlib = False
#else
retainProofImportHashlib = True
#endif

retainProofImportOs :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_IMPORT_OS_MEMBER_DROP_MUTANT)
retainProofImportOs = False
#else
retainProofImportOs = True
#endif

retainProofImportPlatform :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_IMPORT_PLATFORM_MEMBER_DROP_MUTANT)
retainProofImportPlatform = False
#else
retainProofImportPlatform = True
#endif

retainProofImportSubprocess :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_IMPORT_SUBPROCESS_MEMBER_DROP_MUTANT)
retainProofImportSubprocess = False
#else
retainProofImportSubprocess = True
#endif

retainProofImportSys :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_IMPORT_SYS_MEMBER_DROP_MUTANT)
retainProofImportSys = False
#else
retainProofImportSys = True
#endif

retainProofImportUrllibRequest :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_IMPORT_URLLIB_REQUEST_MEMBER_DROP_MUTANT)
retainProofImportUrllibRequest = False
#else
retainProofImportUrllibRequest = True
#endif

retainProofImportPathlibPath :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_IMPORT_PATHLIB_PATH_MEMBER_DROP_MUTANT)
retainProofImportPathlibPath = False
#else
retainProofImportPathlibPath = True
#endif

retainProofPlatformLinuxAmd64 :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_LINUX_AMD64_LABEL_DROP_MUTANT)
retainProofPlatformLinuxAmd64 = False
#else
retainProofPlatformLinuxAmd64 = True
#endif

retainProofPlatformLinuxArm64 :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_LINUX_ARM64_LABEL_DROP_MUTANT)
retainProofPlatformLinuxArm64 = False
#else
retainProofPlatformLinuxArm64 = True
#endif

retainProofPlatformDarwinArm64 :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_DARWIN_ARM64_LABEL_DROP_MUTANT)
retainProofPlatformDarwinArm64 = False
#else
retainProofPlatformDarwinArm64 = True
#endif

retainProofPlatformWindowsAmd64 :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_WINDOWS_AMD64_LABEL_DROP_MUTANT)
retainProofPlatformWindowsAmd64 = False
#else
retainProofPlatformWindowsAmd64 = True
#endif

retainProofStaticArgvClaim :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_STATIC_ARGV_CLAIM_DROP_MUTANT)
retainProofStaticArgvClaim = False
#else
retainProofStaticArgvClaim = True
#endif

retainProofStaticBinaryClaim :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_STATIC_BINARY_CLAIM_DROP_MUTANT)
retainProofStaticBinaryClaim = False
#else
retainProofStaticBinaryClaim = True
#endif

retainProofStaticInjectionClaim :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_STATIC_INJECTION_CLAIM_DROP_MUTANT)
retainProofStaticInjectionClaim = False
#else
retainProofStaticInjectionClaim = True
#endif

retainProofStaticPhase50InvocationClaim :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_STATIC_PHASE50_INVOCATION_CLAIM_DROP_MUTANT)
retainProofStaticPhase50InvocationClaim = False
#else
retainProofStaticPhase50InvocationClaim = True
#endif

retainProofStaticEnsureClaim :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_STATIC_ENSURE_CLAIM_DROP_MUTANT)
retainProofStaticEnsureClaim = False
#else
retainProofStaticEnsureClaim = True
#endif

retainProofStaticEnvironmentClaim :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_STATIC_ENVIRONMENT_CLAIM_DROP_MUTANT)
retainProofStaticEnvironmentClaim = False
#else
retainProofStaticEnvironmentClaim = True
#endif

retainProofStaticExecutablesClaim :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_STATIC_EXECUTABLES_CLAIM_DROP_MUTANT)
retainProofStaticExecutablesClaim = False
#else
retainProofStaticExecutablesClaim = True
#endif

retainProofStaticPlatformLimitationsClaim :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_STATIC_PLATFORM_LIMITATIONS_CLAIM_DROP_MUTANT)
retainProofStaticPlatformLimitationsClaim = False
#else
retainProofStaticPlatformLimitationsClaim = True
#endif

retainProofStaticRuntimeBoundaryClaim :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_STATIC_RUNTIME_BOUNDARY_CLAIM_DROP_MUTANT)
retainProofStaticRuntimeBoundaryClaim = False
#else
retainProofStaticRuntimeBoundaryClaim = True
#endif

retainProofControlSelectArtifact :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_SELECT_ARTIFACT_ENTRY_DROP_MUTANT)
retainProofControlSelectArtifact = False
#else
retainProofControlSelectArtifact = True
#endif

retainProofControlRepositoryRoot :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_REPOSITORY_ROOT_ENTRY_DROP_MUTANT)
retainProofControlRepositoryRoot = False
#else
retainProofControlRepositoryRoot = True
#endif

retainProofControlPlatform :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_PLATFORM_ENTRY_DROP_MUTANT)
retainProofControlPlatform = False
#else
retainProofControlPlatform = True
#endif

retainProofControlEnsureGhcup :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_ENSURE_GHCUP_ENTRY_DROP_MUTANT)
retainProofControlEnsureGhcup = False
#else
retainProofControlEnsureGhcup = True
#endif

retainProofControlEnvironment :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_ENVIRONMENT_ENTRY_DROP_MUTANT)
retainProofControlEnvironment = False
#else
retainProofControlEnvironment = True
#endif

retainProofControlRun :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_RUN_ENTRY_DROP_MUTANT)
retainProofControlRun = False
#else
retainProofControlRun = True
#endif

retainProofControlCapture :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_CAPTURE_ENTRY_DROP_MUTANT)
retainProofControlCapture = False
#else
retainProofControlCapture = True
#endif

retainProofControlHandoff :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_HANDOFF_ENTRY_DROP_MUTANT)
retainProofControlHandoff = False
#else
retainProofControlHandoff = True
#endif

retainProofControlBootstrap :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_BOOTSTRAP_ENTRY_DROP_MUTANT)
retainProofControlBootstrap = False
#else
retainProofControlBootstrap = True
#endif

retainProofControlMain :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_MAIN_ENTRY_DROP_MUTANT)
retainProofControlMain = False
#else
retainProofControlMain = True
#endif

retainPreflightInputFileCountObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_FILE_COUNT_OBSERVATION_DROP_MUTANT)
retainPreflightInputFileCountObservation = False
#else
retainPreflightInputFileCountObservation = True
#endif

retainPreflightLimitInputFilesObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_LIMIT_INPUT_FILES_OBSERVATION_DROP_MUTANT)
retainPreflightLimitInputFilesObservation = False
#else
retainPreflightLimitInputFilesObservation = True
#endif

retainPreflightExpectedPathObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_EXPECTED_PATH_OBSERVATION_DROP_MUTANT)
retainPreflightExpectedPathObservation = False
#else
retainPreflightExpectedPathObservation = True
#endif

retainPreflightExpectedModeObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_EXPECTED_MODE_OBSERVATION_DROP_MUTANT)
retainPreflightExpectedModeObservation = False
#else
retainPreflightExpectedModeObservation = True
#endif

retainPreflightExpectedBytesObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_EXPECTED_BYTES_OBSERVATION_DROP_MUTANT)
retainPreflightExpectedBytesObservation = False
#else
retainPreflightExpectedBytesObservation = True
#endif

retainPreflightExpectedSha256Observation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_EXPECTED_SHA256_OBSERVATION_DROP_MUTANT)
retainPreflightExpectedSha256Observation = False
#else
retainPreflightExpectedSha256Observation = True
#endif

retainPreflightInputPathCharactersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_PATH_CHARACTERS_OBSERVATION_DROP_MUTANT)
retainPreflightInputPathCharactersObservation = False
#else
retainPreflightInputPathCharactersObservation = True
#endif

retainPreflightInputModeCharactersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_MODE_CHARACTERS_OBSERVATION_DROP_MUTANT)
retainPreflightInputModeCharactersObservation = False
#else
retainPreflightInputModeCharactersObservation = True
#endif

retainPreflightInputBytesObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_BYTES_OBSERVATION_DROP_MUTANT)
retainPreflightInputBytesObservation = False
#else
retainPreflightInputBytesObservation = True
#endif

retainPreflightInputPathObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_PATH_OBSERVATION_DROP_MUTANT)
retainPreflightInputPathObservation = False
#else
retainPreflightInputPathObservation = True
#endif

retainPreflightInputModeObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_MODE_OBSERVATION_DROP_MUTANT)
retainPreflightInputModeObservation = False
#else
retainPreflightInputModeObservation = True
#endif

retainPreflightInputSha256Observation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_SHA256_OBSERVATION_DROP_MUTANT)
retainPreflightInputSha256Observation = False
#else
retainPreflightInputSha256Observation = True
#endif

retainResourceSourceBytesObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_SOURCE_BYTES_OBSERVATION_DROP_MUTANT)
retainResourceSourceBytesObservation = False
#else
retainResourceSourceBytesObservation = True
#endif

retainResourcePhysicalLinesObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_PHYSICAL_LINES_OBSERVATION_DROP_MUTANT)
retainResourcePhysicalLinesObservation = False
#else
retainResourcePhysicalLinesObservation = True
#endif

retainResourceAstNodesObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_AST_NODES_OBSERVATION_DROP_MUTANT)
retainResourceAstNodesObservation = False
#else
retainResourceAstNodesObservation = True
#endif

retainResourceLexicalTokensObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_LEXICAL_TOKENS_OBSERVATION_DROP_MUTANT)
retainResourceLexicalTokensObservation = False
#else
retainResourceLexicalTokensObservation = True
#endif

retainResourceSyntaxDepthObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_SYNTAX_DEPTH_OBSERVATION_DROP_MUTANT)
retainResourceSyntaxDepthObservation = False
#else
retainResourceSyntaxDepthObservation = True
#endif

retainResourceCallMarkersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_CALL_MARKERS_OBSERVATION_DROP_MUTANT)
retainResourceCallMarkersObservation = False
#else
retainResourceCallMarkersObservation = True
#endif

retainResourceEffectMarkersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_EFFECT_MARKERS_OBSERVATION_DROP_MUTANT)
retainResourceEffectMarkersObservation = False
#else
retainResourceEffectMarkersObservation = True
#endif

retainResourceControlFlowMarkersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_CONTROL_FLOW_MARKERS_OBSERVATION_DROP_MUTANT)
retainResourceControlFlowMarkersObservation = False
#else
retainResourceControlFlowMarkersObservation = True
#endif

retainResourceProblemMarkersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_PROBLEM_MARKERS_OBSERVATION_DROP_MUTANT)
retainResourceProblemMarkersObservation = False
#else
retainResourceProblemMarkersObservation = True
#endif

retainLimitSourceBytesObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_SOURCE_BYTES_OBSERVATION_DROP_MUTANT)
retainLimitSourceBytesObservation = False
#else
retainLimitSourceBytesObservation = True
#endif

retainLimitPathCharactersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_PATH_CHARACTERS_OBSERVATION_DROP_MUTANT)
retainLimitPathCharactersObservation = False
#else
retainLimitPathCharactersObservation = True
#endif

retainLimitModeCharactersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_MODE_CHARACTERS_OBSERVATION_DROP_MUTANT)
retainLimitModeCharactersObservation = False
#else
retainLimitModeCharactersObservation = True
#endif

retainLimitPhysicalLinesObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_PHYSICAL_LINES_OBSERVATION_DROP_MUTANT)
retainLimitPhysicalLinesObservation = False
#else
retainLimitPhysicalLinesObservation = True
#endif

retainLimitAstNodesObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_AST_NODES_OBSERVATION_DROP_MUTANT)
retainLimitAstNodesObservation = False
#else
retainLimitAstNodesObservation = True
#endif

retainLimitLexicalTokensObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_LEXICAL_TOKENS_OBSERVATION_DROP_MUTANT)
retainLimitLexicalTokensObservation = False
#else
retainLimitLexicalTokensObservation = True
#endif

retainLimitSyntaxDepthObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_SYNTAX_DEPTH_OBSERVATION_DROP_MUTANT)
retainLimitSyntaxDepthObservation = False
#else
retainLimitSyntaxDepthObservation = True
#endif

retainLimitCallMarkersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_CALL_MARKERS_OBSERVATION_DROP_MUTANT)
retainLimitCallMarkersObservation = False
#else
retainLimitCallMarkersObservation = True
#endif

retainLimitEffectMarkersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_EFFECT_MARKERS_OBSERVATION_DROP_MUTANT)
retainLimitEffectMarkersObservation = False
#else
retainLimitEffectMarkersObservation = True
#endif

retainLimitControlFlowMarkersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_CONTROL_FLOW_MARKERS_OBSERVATION_DROP_MUTANT)
retainLimitControlFlowMarkersObservation = False
#else
retainLimitControlFlowMarkersObservation = True
#endif

retainLimitProblemMarkersObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_PROBLEM_MARKERS_OBSERVATION_DROP_MUTANT)
retainLimitProblemMarkersObservation = False
#else
retainLimitProblemMarkersObservation = True
#endif

retainLimitProblemsObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_LIMIT_PROBLEMS_OBSERVATION_DROP_MUTANT)
retainLimitProblemsObservation = False
#else
retainLimitProblemsObservation = True
#endif

retainProofSubjectPathObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_SUBJECT_PATH_OBSERVATION_DROP_MUTANT)
retainProofSubjectPathObservation = False
#else
retainProofSubjectPathObservation = True
#endif

retainProofSubjectModeObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_SUBJECT_MODE_OBSERVATION_DROP_MUTANT)
retainProofSubjectModeObservation = False
#else
retainProofSubjectModeObservation = True
#endif

retainProofSubjectBytesObservation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_SUBJECT_BYTES_OBSERVATION_DROP_MUTANT)
retainProofSubjectBytesObservation = False
#else
retainProofSubjectBytesObservation = True
#endif

retainProofSubjectSha256Observation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_SUBJECT_SHA256_OBSERVATION_DROP_MUTANT)
retainProofSubjectSha256Observation = False
#else
retainProofSubjectSha256Observation = True
#endif

retainProofExpectedSha256Observation :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROOF_EXPECTED_SHA256_OBSERVATION_DROP_MUTANT)
retainProofExpectedSha256Observation = False
#else
retainProofExpectedSha256Observation = True
#endif

retainSubjectProjection, retainResourceProjection, retainImportProjection :: Bool
#if defined(VALIDATION_PB_GRAMMAR_SUBJECT_RETENTION_DROP_MUTANT)
retainSubjectProjection = False
#else
retainSubjectProjection = True
#endif
#if defined(VALIDATION_PB_GRAMMAR_RESOURCE_RETENTION_DROP_MUTANT)
retainResourceProjection = False
#else
retainResourceProjection = True
#endif
#if defined(VALIDATION_PB_GRAMMAR_IMPORT_RETENTION_DROP_MUTANT)
retainImportProjection = False
#else
retainImportProjection = True
#endif

retainCallProjection, retainEffectProjection, retainControlFlowProjection :: Bool
#if defined(VALIDATION_PB_GRAMMAR_CALL_RETENTION_DROP_MUTANT)
retainCallProjection = False
#else
retainCallProjection = True
#endif
#if defined(VALIDATION_PB_GRAMMAR_EFFECT_RETENTION_DROP_MUTANT)
retainEffectProjection = False
#else
retainEffectProjection = True
#endif
#if defined(VALIDATION_PB_GRAMMAR_CONTROL_FLOW_RETENTION_DROP_MUTANT)
retainControlFlowProjection = False
#else
retainControlFlowProjection = True
#endif

retainPlatformProjection, retainStaticClaimProjection, retainRuntimeProjection :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PLATFORM_RETENTION_DROP_MUTANT)
retainPlatformProjection = False
#else
retainPlatformProjection = True
#endif
#if defined(VALIDATION_PB_GRAMMAR_STATIC_CLAIM_RETENTION_DROP_MUTANT)
retainStaticClaimProjection = False
#else
retainStaticClaimProjection = True
#endif
#if defined(VALIDATION_PB_GRAMMAR_RUNTIME_RETENTION_DROP_MUTANT)
retainRuntimeProjection = False
#else
retainRuntimeProjection = True
#endif

runtimeResidue :: [RuntimeResidue]
runtimeResidue =
  [ residue
  | (keepResidue, residue) <- runtimeResidueRetentionTable
  , keepResidue
  ]

runtimeResidueRetentionTable :: [(Bool, RuntimeResidue)]
runtimeResidueRetentionTable =
  [ (retainAuthenticatedInterpreterResidue, AuthenticatedPythonInterpreterResidue)
  , (retainIsolationFlagsOrderResidue, PythonIsolationFlagsOrderResidue)
  , (retainAbsoluteDirectorySubjectResidue, AbsolutePythonDirectorySubjectResidue)
  , (retainStdlibStartupResidue, StdlibImportStartupResidue)
  , (retainStdlibTransitiveResidue, StandardLibraryNativeTransitiveSemanticsResidue)
  , (retainAmbientInterpreterEnvironmentResidue, AmbientInterpreterEnvironmentResidue)
  , (retainNetworkProxyEnvironmentResidue, NetworkProxyEnvironmentResidue)
  , (retainChildToolSearchPathResidue, ChildToolDefaultSearchPathResidue)
  , (retainNetworkTransportCertificateResidue, NetworkTransportAndCertificateResidue)
  , (retainSymlinkToctouResidue, SymlinkAndToctouResidue)
  , (retainAtomicArtifactPublicationResidue, AtomicArtifactPublicationResidue)
  , (retainExecutableModeObservationResidue, ExecutableModeObservationResidue)
  , (retainGhcupToolRuntimeResidue, GhcupManagedToolRuntimeResidue)
  , (retainCabalListBinPathResidue, CabalListBinPathObservationResidue)
  , (retainSourceBinaryPathIdentityResidue, SourceAndBinaryPathIdentityResidue)
  , (retainWindowsGhcupRuntimeResidue, WindowsGhcupRuntimeResidue)
  , (retainFakeAdapterObservationResidue, FakeAdapterObservationResidue)
  , (retainConcreteAdapterEffectResidue, ConcreteAdapterEffectObservationResidue)
  , (retainUnchangedArgumentTailResidue, UnchangedArgumentTailResidue)
  , (retainExecReplacementResidue, ExecReplacementResidue)
  , (retainHandoffExitPropagationResidue, HandoffExitPropagationResidue)
  ]

retainAuthenticatedInterpreterResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_AUTHENTICATED_INTERPRETER_RESIDUE_DROP_MUTANT)
retainAuthenticatedInterpreterResidue = False
#else
retainAuthenticatedInterpreterResidue = True
#endif

retainIsolationFlagsOrderResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_ISOLATION_FLAGS_ORDER_RESIDUE_DROP_MUTANT)
retainIsolationFlagsOrderResidue = False
#else
retainIsolationFlagsOrderResidue = True
#endif

retainAbsoluteDirectorySubjectResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_ABSOLUTE_DIRECTORY_SUBJECT_RESIDUE_DROP_MUTANT)
retainAbsoluteDirectorySubjectResidue = False
#else
retainAbsoluteDirectorySubjectResidue = True
#endif

retainStdlibStartupResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_STDLIB_STARTUP_RESIDUE_DROP_MUTANT)
retainStdlibStartupResidue = False
#else
retainStdlibStartupResidue = True
#endif

retainStdlibTransitiveResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_STDLIB_TRANSITIVE_RESIDUE_DROP_MUTANT)
retainStdlibTransitiveResidue = False
#else
retainStdlibTransitiveResidue = True
#endif

retainAmbientInterpreterEnvironmentResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_AMBIENT_INTERPRETER_ENV_RESIDUE_DROP_MUTANT)
retainAmbientInterpreterEnvironmentResidue = False
#else
retainAmbientInterpreterEnvironmentResidue = True
#endif

retainNetworkProxyEnvironmentResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_NETWORK_PROXY_ENV_RESIDUE_DROP_MUTANT)
retainNetworkProxyEnvironmentResidue = False
#else
retainNetworkProxyEnvironmentResidue = True
#endif

retainChildToolSearchPathResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_CHILD_TOOL_SEARCH_PATH_RESIDUE_DROP_MUTANT)
retainChildToolSearchPathResidue = False
#else
retainChildToolSearchPathResidue = True
#endif

retainNetworkTransportCertificateResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_NETWORK_TRANSPORT_CERTIFICATE_RESIDUE_DROP_MUTANT)
retainNetworkTransportCertificateResidue = False
#else
retainNetworkTransportCertificateResidue = True
#endif

retainSymlinkToctouResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_SYMLINK_TOCTOU_RESIDUE_DROP_MUTANT)
retainSymlinkToctouResidue = False
#else
retainSymlinkToctouResidue = True
#endif

retainAtomicArtifactPublicationResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_ATOMIC_ARTIFACT_PUBLICATION_RESIDUE_DROP_MUTANT)
retainAtomicArtifactPublicationResidue = False
#else
retainAtomicArtifactPublicationResidue = True
#endif

retainExecutableModeObservationResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_EXECUTABLE_MODE_OBSERVATION_RESIDUE_DROP_MUTANT)
retainExecutableModeObservationResidue = False
#else
retainExecutableModeObservationResidue = True
#endif

retainGhcupToolRuntimeResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_GHCUP_TOOL_RUNTIME_RESIDUE_DROP_MUTANT)
retainGhcupToolRuntimeResidue = False
#else
retainGhcupToolRuntimeResidue = True
#endif

retainCabalListBinPathResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_CABAL_LIST_BIN_PATH_RESIDUE_DROP_MUTANT)
retainCabalListBinPathResidue = False
#else
retainCabalListBinPathResidue = True
#endif

retainSourceBinaryPathIdentityResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_SOURCE_BINARY_PATH_IDENTITY_RESIDUE_DROP_MUTANT)
retainSourceBinaryPathIdentityResidue = False
#else
retainSourceBinaryPathIdentityResidue = True
#endif

retainWindowsGhcupRuntimeResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_WINDOWS_GHCUP_RUNTIME_RESIDUE_DROP_MUTANT)
retainWindowsGhcupRuntimeResidue = False
#else
retainWindowsGhcupRuntimeResidue = True
#endif

retainFakeAdapterObservationResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_FAKE_ADAPTER_OBSERVATION_RESIDUE_DROP_MUTANT)
retainFakeAdapterObservationResidue = False
#else
retainFakeAdapterObservationResidue = True
#endif

retainConcreteAdapterEffectResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_CONCRETE_ADAPTER_EFFECT_RESIDUE_DROP_MUTANT)
retainConcreteAdapterEffectResidue = False
#else
retainConcreteAdapterEffectResidue = True
#endif

retainUnchangedArgumentTailResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_UNCHANGED_ARGUMENT_TAIL_RESIDUE_DROP_MUTANT)
retainUnchangedArgumentTailResidue = False
#else
retainUnchangedArgumentTailResidue = True
#endif

retainExecReplacementResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_EXEC_REPLACEMENT_RESIDUE_DROP_MUTANT)
retainExecReplacementResidue = False
#else
retainExecReplacementResidue = True
#endif

retainHandoffExitPropagationResidue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_HANDOFF_EXIT_PROPAGATION_RESIDUE_DROP_MUTANT)
retainHandoffExitPropagationResidue = False
#else
retainHandoffExitPropagationResidue = True
#endif

phase50ResidueFindings :: [Finding]
phase50ResidueFindings =
  retainPhase50ResidueFindings
    [ finding
        phase50ResidueCode
        (phase50ResidueSubject residue)
        phase50ResidueDetail
    | residue <- orderPhase50Residues runtimeResidue
    ]

retainPhase50ResidueFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_PB_GRAMMAR_PHASE50_FINDINGS_RETENTION_DROP_MUTANT)
retainPhase50ResidueFindings _ = []
#else
retainPhase50ResidueFindings findings = findings
#endif

orderPhase50Residues :: [RuntimeResidue] -> [RuntimeResidue]
#if defined(VALIDATION_PB_GRAMMAR_PHASE50_FINDINGS_ORDER_MUTANT)
orderPhase50Residues = reverse
#else
orderPhase50Residues = id
#endif

phase50ResidueCode :: Text
#if defined(VALIDATION_PB_GRAMMAR_PHASE50_FINDING_CODE_MAPPING_MUTANT)
phase50ResidueCode = "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE-MUTANT"
#else
phase50ResidueCode = "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#endif

phase50ResidueSubject :: RuntimeResidue -> String
#if defined(VALIDATION_PB_GRAMMAR_PHASE50_FINDING_SUBJECT_MAPPING_MUTANT)
phase50ResidueSubject residue = show residue <> "-mutant"
#else
phase50ResidueSubject = show
#endif

phase50ResidueDetail :: Text
#if defined(VALIDATION_PB_GRAMMAR_PHASE50_FINDING_DETAIL_MAPPING_MUTANT)
phase50ResidueDetail = "mutated Phase-50 residue detail"
#else
phase50ResidueDetail = "static source grammar cannot establish this runtime property; Phase 50 must observe the pb child from the source-bound Haskell supervisor"
#endif

renderImportBinding :: ImportBinding -> Text
renderImportBinding binding =
  importBoundName binding <> "=" <> importQualifiedName binding

controlFlowSummary :: ControlFlowGraph -> [(Text, Int, Int, Bool, Int)]
controlFlowSummary (ControlFlowGraph functions) =
  [ ( cfgFunction graph
    , length (cfgNodes graph)
    , length (cfgEdges graph)
    , cfgFallsThrough graph
    , length [() | node <- cfgNodes graph, cfgNodeKind node == CfgHandoffRequest]
    )
  | graph <- functions
  ]

renderControlFlowSummary :: [(Text, Int, Int, Bool, Int)] -> Text
renderControlFlowSummary =
  Text.intercalate controlFlowRowSeparator . map renderRow
 where
  renderRow (name, nodes, edges, fallsThrough, handoffs) =
    Text.intercalate
      controlFlowFieldSeparator
      [ mapControlFlowName name
      , decimal (mapControlFlowNodes nodes)
      , decimal (mapControlFlowEdges edges)
      , renderControlFlowFallthrough fallsThrough
      , decimal (mapControlFlowHandoffs handoffs)
      ]

controlFlowRowSeparator, controlFlowFieldSeparator :: Text
#if defined(VALIDATION_PB_GRAMMAR_CONTROL_FLOW_ROW_SEPARATOR_MUTANT)
controlFlowRowSeparator = ","
#else
controlFlowRowSeparator = ";"
#endif
#if defined(VALIDATION_PB_GRAMMAR_CONTROL_FLOW_FIELD_SEPARATOR_MUTANT)
controlFlowFieldSeparator = ","
#else
controlFlowFieldSeparator = "|"
#endif

mapControlFlowName :: Text -> Text
#if defined(VALIDATION_PB_GRAMMAR_CONTROL_FLOW_NAME_FIELD_MAPPING_MUTANT)
mapControlFlowName name = name <> "-mutant"
#else
mapControlFlowName name = name
#endif

mapControlFlowNodes, mapControlFlowEdges, mapControlFlowHandoffs :: Int -> Int
#if defined(VALIDATION_PB_GRAMMAR_CONTROL_FLOW_NODES_FIELD_MAPPING_MUTANT)
mapControlFlowNodes value = value + 1
#else
mapControlFlowNodes value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_CONTROL_FLOW_EDGES_FIELD_MAPPING_MUTANT)
mapControlFlowEdges value = value + 1
#else
mapControlFlowEdges value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_CONTROL_FLOW_HANDOFFS_FIELD_MAPPING_MUTANT)
mapControlFlowHandoffs value = value + 1
#else
mapControlFlowHandoffs value = value
#endif

renderControlFlowFallthrough :: Bool -> Text
#if defined(VALIDATION_PB_GRAMMAR_CONTROL_FLOW_FALLTHROUGH_FIELD_MAPPING_MUTANT)
renderControlFlowFallthrough fallsThrough = if fallsThrough then "terminal" else "may-return"
#else
renderControlFlowFallthrough fallsThrough = if fallsThrough then "may-return" else "terminal"
#endif

renderArgvClaim :: ArgvProvenance -> Text
renderArgvClaim (OpaqueUserArgvTail source parameter executable) =
  Text.intercalate
    claimFieldSeparator
    [ mapArgvClaimTag "argv"
    , mapArgvSourceField source
    , mapArgvParameterField parameter
    , mapArgvExecutableField executable
    ]

renderBinaryClaim :: BinaryProvenance -> Text
renderBinaryClaim proof =
  Text.intercalate
    claimFieldSeparator
    [ mapBinaryClaimTag "binary"
    , mapBinaryTargetField (binaryBuildTarget proof)
    , mapBinaryGhcupField (binaryGhcupVersion proof)
    , mapBinaryCompilerField (binaryCompilerVersion proof)
    , mapBinaryCabalField (binaryCabalVersion proof)
    , mapBinaryLocatorField (binaryLocator proof)
    , mapBinaryHandoffField (binaryHandoff proof)
    ]

renderInjectionClaim :: InjectionSeamProof -> Text
renderInjectionClaim proof =
  Text.intercalate
    claimFieldSeparator
    [ mapInjectionClaimTag "injection"
    , mapInjectionFunctionField (seamFunctionName proof)
    , mapInjectionAdapterField (seamAdapterParameter proof)
    , mapInjectionArgumentsField (seamArgumentsParameter proof)
    , mapInjectionConstructionField (seamConcreteConstructionScope proof)
    , mapInjectionGuardField (seamMainGuardExpression proof)
    ]

renderPhase50InvocationClaim :: Phase50InvocationContract -> Text
renderPhase50InvocationClaim
  (RequiredPhase50PythonDirectoryInvocation interpreter flags subject arguments) =
    Text.intercalate
      claimFieldSeparator
      [ mapPhase50ClaimTag "phase50-invocation"
      , mapPhase50InterpreterField interpreter
      , Text.intercalate phase50FlagSeparator (mapPhase50FlagsField flags)
      , mapPhase50SubjectField subject
      , mapPhase50ArgumentsField arguments
      ]

renderEnsureClaim :: GhcupEnsureProof -> Text
renderEnsureClaim proof =
  Text.intercalate
    claimFieldSeparator
    [ mapEnsureClaimTag "ensure"
    , truth (mapEnsureMatchingField (ensureMatchingExistingReturnsBeforeMutation proof))
    , truth (mapEnsureMismatchedField (ensureMismatchedExistingFailsClosed proof))
    , truth (mapEnsureAbsentField (ensureAbsentArtifactVerifiedBeforeWrite proof))
    ]

renderEnvironmentClaim :: ClosedEnvironmentProof -> Text
renderEnvironmentClaim proof =
  Text.intercalate
    claimFieldSeparator
    [ mapEnvironmentClaimTag "environment"
    , truth (mapEnvironmentStartsEmptyField (environmentStartsEmpty proof))
    , Text.intercalate "," (mapEnvironmentExactKeysField (environmentExactKeys proof))
    , Text.intercalate "," (mapEnvironmentContainedKeysField (environmentContainedPathKeys proof))
    , truth (mapEnvironmentChildMappingField (childEnvironmentMappingExact proof))
    ]

renderExecutableClaim :: ToolchainExecutableProof -> Text
renderExecutableClaim proof =
  Text.intercalate
    claimFieldSeparator
    [ mapExecutableClaimTag "executables"
    , mapExecutableRootField (toolchainRootProvenance proof)
    , mapExecutableGhcupField (ghcupExecutableProvenance proof)
    , mapExecutableGhcField (ghcExecutableProvenance proof)
    , mapExecutableCabalField (cabalExecutableProvenance proof)
    , mapExecutableArgvZeroField (childArgvZeroProvenance proof)
    ]

renderPlatformLimitationsClaim :: [PlatformLimitation] -> Text
renderPlatformLimitationsClaim limitations =
  Text.intercalate
    claimFieldSeparator
    [ mapPlatformLimitationsClaimTag "platform-limitations"
    , Text.intercalate
        platformLimitationSeparator
        (map renderPlatformLimitation (orderPlatformLimitations limitations))
    ]

renderRuntimeBoundaryClaim :: RuntimeBoundary -> Text
renderRuntimeBoundaryClaim boundary =
  Text.intercalate
    claimFieldSeparator
    [ mapRuntimeBoundaryClaimTag "runtime-boundary"
    , renderRuntimeBoundary boundary
    ]

claimFieldSeparator, phase50FlagSeparator, platformLimitationSeparator :: Text
#if defined(VALIDATION_PB_GRAMMAR_CLAIM_FIELD_SEPARATOR_MUTANT)
claimFieldSeparator = "~"
#else
claimFieldSeparator = "|"
#endif
#if defined(VALIDATION_PB_GRAMMAR_PHASE50_FLAGS_SEPARATOR_MUTANT)
phase50FlagSeparator = ";"
#else
phase50FlagSeparator = ","
#endif
#if defined(VALIDATION_PB_GRAMMAR_PLATFORM_LIMITATION_SEPARATOR_MUTANT)
platformLimitationSeparator = ";"
#else
platformLimitationSeparator = ","
#endif

mapArgvClaimTag, mapBinaryClaimTag, mapInjectionClaimTag, mapPhase50ClaimTag :: Text -> Text
mapEnsureClaimTag, mapEnvironmentClaimTag, mapExecutableClaimTag :: Text -> Text
mapPlatformLimitationsClaimTag, mapRuntimeBoundaryClaimTag :: Text -> Text
#if defined(VALIDATION_PB_GRAMMAR_ARGV_CLAIM_TAG_MAPPING_MUTANT)
mapArgvClaimTag value = value <> "-mutant"
#else
mapArgvClaimTag value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_BINARY_CLAIM_TAG_MAPPING_MUTANT)
mapBinaryClaimTag value = value <> "-mutant"
#else
mapBinaryClaimTag value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_INJECTION_CLAIM_TAG_MAPPING_MUTANT)
mapInjectionClaimTag value = value <> "-mutant"
#else
mapInjectionClaimTag value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_PHASE50_CLAIM_TAG_MAPPING_MUTANT)
mapPhase50ClaimTag value = value <> "-mutant"
#else
mapPhase50ClaimTag value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_ENSURE_CLAIM_TAG_MAPPING_MUTANT)
mapEnsureClaimTag value = value <> "-mutant"
#else
mapEnsureClaimTag value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_ENVIRONMENT_CLAIM_TAG_MAPPING_MUTANT)
mapEnvironmentClaimTag value = value <> "-mutant"
#else
mapEnvironmentClaimTag value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_EXECUTABLE_CLAIM_TAG_MAPPING_MUTANT)
mapExecutableClaimTag value = value <> "-mutant"
#else
mapExecutableClaimTag value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_PLATFORM_LIMITATIONS_CLAIM_TAG_MAPPING_MUTANT)
mapPlatformLimitationsClaimTag value = value <> "-mutant"
#else
mapPlatformLimitationsClaimTag value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_RUNTIME_BOUNDARY_CLAIM_TAG_MAPPING_MUTANT)
mapRuntimeBoundaryClaimTag value = value <> "-mutant"
#else
mapRuntimeBoundaryClaimTag value = value
#endif

mapArgvSourceField, mapArgvParameterField, mapArgvExecutableField :: Text -> Text
#if defined(VALIDATION_PB_GRAMMAR_ARGV_SOURCE_FIELD_MAPPING_MUTANT)
mapArgvSourceField value = value <> "-mutant"
#else
mapArgvSourceField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_ARGV_PARAMETER_FIELD_MAPPING_MUTANT)
mapArgvParameterField value = value <> "-mutant"
#else
mapArgvParameterField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_ARGV_EXECUTABLE_FIELD_MAPPING_MUTANT)
mapArgvExecutableField value = value <> "-mutant"
#else
mapArgvExecutableField value = value
#endif

mapBinaryTargetField, mapBinaryGhcupField, mapBinaryCompilerField :: Text -> Text
mapBinaryCabalField, mapBinaryLocatorField, mapBinaryHandoffField :: Text -> Text
#if defined(VALIDATION_PB_GRAMMAR_BINARY_TARGET_FIELD_MAPPING_MUTANT)
mapBinaryTargetField value = value <> "-mutant"
#else
mapBinaryTargetField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_BINARY_GHCUP_FIELD_MAPPING_MUTANT)
mapBinaryGhcupField value = value <> "-mutant"
#else
mapBinaryGhcupField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_BINARY_COMPILER_FIELD_MAPPING_MUTANT)
mapBinaryCompilerField value = value <> "-mutant"
#else
mapBinaryCompilerField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_BINARY_CABAL_FIELD_MAPPING_MUTANT)
mapBinaryCabalField value = value <> "-mutant"
#else
mapBinaryCabalField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_BINARY_LOCATOR_FIELD_MAPPING_MUTANT)
mapBinaryLocatorField value = value <> "-mutant"
#else
mapBinaryLocatorField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_BINARY_HANDOFF_FIELD_MAPPING_MUTANT)
mapBinaryHandoffField value = value <> "-mutant"
#else
mapBinaryHandoffField value = value
#endif

mapInjectionFunctionField, mapInjectionAdapterField, mapInjectionArgumentsField :: Text -> Text
mapInjectionConstructionField, mapInjectionGuardField :: Text -> Text
#if defined(VALIDATION_PB_GRAMMAR_INJECTION_FUNCTION_FIELD_MAPPING_MUTANT)
mapInjectionFunctionField value = value <> "-mutant"
#else
mapInjectionFunctionField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_INJECTION_ADAPTER_FIELD_MAPPING_MUTANT)
mapInjectionAdapterField value = value <> "-mutant"
#else
mapInjectionAdapterField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_INJECTION_ARGUMENTS_FIELD_MAPPING_MUTANT)
mapInjectionArgumentsField value = value <> "-mutant"
#else
mapInjectionArgumentsField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_INJECTION_CONSTRUCTION_FIELD_MAPPING_MUTANT)
mapInjectionConstructionField value = value <> "-mutant"
#else
mapInjectionConstructionField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_INJECTION_GUARD_FIELD_MAPPING_MUTANT)
mapInjectionGuardField value = value <> "-mutant"
#else
mapInjectionGuardField value = value
#endif

mapPhase50InterpreterField, mapPhase50SubjectField, mapPhase50ArgumentsField :: Text -> Text
#if defined(VALIDATION_PB_GRAMMAR_PHASE50_INTERPRETER_FIELD_MAPPING_MUTANT)
mapPhase50InterpreterField value = value <> "-mutant"
#else
mapPhase50InterpreterField value = value
#endif
mapPhase50FlagsField :: [Text] -> [Text]
#if defined(VALIDATION_PB_GRAMMAR_PHASE50_FLAGS_FIELD_MAPPING_MUTANT)
mapPhase50FlagsField = reverse
#else
mapPhase50FlagsField = id
#endif
#if defined(VALIDATION_PB_GRAMMAR_PHASE50_SUBJECT_FIELD_MAPPING_MUTANT)
mapPhase50SubjectField value = value <> "-mutant"
#else
mapPhase50SubjectField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_PHASE50_ARGUMENTS_FIELD_MAPPING_MUTANT)
mapPhase50ArgumentsField value = value <> "-mutant"
#else
mapPhase50ArgumentsField value = value
#endif

mapEnsureMatchingField, mapEnsureMismatchedField, mapEnsureAbsentField :: Bool -> Bool
#if defined(VALIDATION_PB_GRAMMAR_ENSURE_MATCHING_FIELD_MAPPING_MUTANT)
mapEnsureMatchingField = not
#else
mapEnsureMatchingField = id
#endif
#if defined(VALIDATION_PB_GRAMMAR_ENSURE_MISMATCHED_FIELD_MAPPING_MUTANT)
mapEnsureMismatchedField = not
#else
mapEnsureMismatchedField = id
#endif
#if defined(VALIDATION_PB_GRAMMAR_ENSURE_ABSENT_FIELD_MAPPING_MUTANT)
mapEnsureAbsentField = not
#else
mapEnsureAbsentField = id
#endif

mapEnvironmentStartsEmptyField, mapEnvironmentChildMappingField :: Bool -> Bool
#if defined(VALIDATION_PB_GRAMMAR_ENVIRONMENT_STARTS_EMPTY_FIELD_MAPPING_MUTANT)
mapEnvironmentStartsEmptyField = not
#else
mapEnvironmentStartsEmptyField = id
#endif
mapEnvironmentExactKeysField, mapEnvironmentContainedKeysField :: [Text] -> [Text]
#if defined(VALIDATION_PB_GRAMMAR_ENVIRONMENT_EXACT_KEYS_FIELD_MAPPING_MUTANT)
mapEnvironmentExactKeysField = reverse
#else
mapEnvironmentExactKeysField = id
#endif
#if defined(VALIDATION_PB_GRAMMAR_ENVIRONMENT_CONTAINED_KEYS_FIELD_MAPPING_MUTANT)
mapEnvironmentContainedKeysField = reverse
#else
mapEnvironmentContainedKeysField = id
#endif
#if defined(VALIDATION_PB_GRAMMAR_ENVIRONMENT_CHILD_MAPPING_FIELD_MAPPING_MUTANT)
mapEnvironmentChildMappingField = not
#else
mapEnvironmentChildMappingField = id
#endif

mapExecutableRootField, mapExecutableGhcupField, mapExecutableGhcField :: Text -> Text
mapExecutableCabalField, mapExecutableArgvZeroField :: Text -> Text
#if defined(VALIDATION_PB_GRAMMAR_EXECUTABLE_ROOT_FIELD_MAPPING_MUTANT)
mapExecutableRootField value = value <> "-mutant"
#else
mapExecutableRootField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_EXECUTABLE_GHCUP_FIELD_MAPPING_MUTANT)
mapExecutableGhcupField value = value <> "-mutant"
#else
mapExecutableGhcupField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_EXECUTABLE_GHC_FIELD_MAPPING_MUTANT)
mapExecutableGhcField value = value <> "-mutant"
#else
mapExecutableGhcField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_EXECUTABLE_CABAL_FIELD_MAPPING_MUTANT)
mapExecutableCabalField value = value <> "-mutant"
#else
mapExecutableCabalField value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_EXECUTABLE_ARGV_ZERO_FIELD_MAPPING_MUTANT)
mapExecutableArgvZeroField value = value <> "-mutant"
#else
mapExecutableArgvZeroField value = value
#endif

orderPlatformLimitations :: [PlatformLimitation] -> [PlatformLimitation]
#if defined(VALIDATION_PB_GRAMMAR_PLATFORM_LIMITATION_ORDER_MUTANT)
orderPlatformLimitations = reverse
#else
orderPlatformLimitations = id
#endif

renderPlatformLimitation :: PlatformLimitation -> Text
renderPlatformLimitation limitation = case limitation of
  WindowsAmd64RuntimeFidelityDeferredToPhase50 -> mapWindowsPlatformLimitation "WindowsAmd64RuntimeFidelityDeferredToPhase50"
  AllOtherPlatformsRefused -> mapOtherPlatformLimitation "AllOtherPlatformsRefused"

mapWindowsPlatformLimitation, mapOtherPlatformLimitation :: Text -> Text
#if defined(VALIDATION_PB_GRAMMAR_WINDOWS_PLATFORM_LIMITATION_MAPPING_MUTANT)
mapWindowsPlatformLimitation value = value <> "-mutant"
#else
mapWindowsPlatformLimitation value = value
#endif
#if defined(VALIDATION_PB_GRAMMAR_OTHER_PLATFORM_LIMITATION_MAPPING_MUTANT)
mapOtherPlatformLimitation value = value <> "-mutant"
#else
mapOtherPlatformLimitation value = value
#endif

renderRuntimeBoundary :: RuntimeBoundary -> Text
renderRuntimeBoundary boundary = case boundary of
#if defined(VALIDATION_PB_GRAMMAR_RUNTIME_BOUNDARY_MAPPING_MUTANT)
  RuntimeTruthDeferredToPhase50 -> "RuntimeTruthDeferredToPhase50-mutant"
#else
  RuntimeTruthDeferredToPhase50 -> "RuntimeTruthDeferredToPhase50"
#endif

truth :: Bool -> Text
truth True = "true"
truth False = "false"

data PbProblem
  = PbInvalidUtf8 FilePath
  | PbLineDiscipline FilePath Text
  | PbLexicalProblem FilePath Int Int Text
  | PbParseProblem FilePath Int Int Text
  | PbUnsupportedImport Text
  | PbNestedImport Text Text
  | PbBindingConflict Text Text
  | PbMonkeypatchAssignment Text Text
  | PbDynamicImport Text
  | PbReflectionForbidden Text
  | PbHookForbidden Text
  | PbUnresolvedCall Text Text
  | PbDirectEffect Text Text
  | PbAdapterConstructionCount Int
  | PbSignatureProblem Text
  | PbPinProblem Text
  | PbArgvProvenanceProblem Text
  | PbInjectionSeamProblem Text
  | PbHandoffControlFlowProblem Text
  | PbBinaryProvenanceProblem Text
  | PbGhcupEnsureProblem Text
  | PbClosedEnvironmentProblem Text
  | PbToolchainExecutableProblem Text
  | PbPlatformProofProblem Text
  | PbProblemLimitExceeded Int Int
  deriving (Eq, Ord, Show)

pbProblemFinding :: PbProblem -> Finding
pbProblemFinding problem =
  finding
    (pbProblemCode problem)
    (Text.unpack (pbProblemSubject problem))
    (pbProblemDetail problem)

pbProblemSubject :: PbProblem -> Text
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_SUBJECT_MAPPING_MUTANT)
pbProblemSubject _ = diagnosticSubject <> ".mutant"
#else
pbProblemSubject _ = diagnosticSubject
#endif

pbProblemDetail :: PbProblem -> Text
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_DETAIL_MAPPING_MUTANT)
pbProblemDetail problem = Text.pack (show problem) <> "-mutant"
#else
pbProblemDetail problem = Text.pack (show problem)
#endif

selectPbProblemCode :: PbProblem -> Text -> Text
selectPbProblemCode problem code = case problem of
  PbInvalidUtf8 {} -> selected retainPbInvalidUtf8Code
  PbLineDiscipline {} -> selected retainPbLineDisciplineCode
  PbLexicalProblem {} -> selected retainPbLexicalCode
  PbParseProblem {} -> selected retainPbParseCode
  PbUnsupportedImport {} -> selected retainPbUnsupportedImportCode
  PbNestedImport {} -> selected retainPbNestedImportCode
  PbBindingConflict {} -> selected retainPbBindingConflictCode
  PbMonkeypatchAssignment {} -> selected retainPbMonkeypatchCode
  PbDynamicImport {} -> selected retainPbDynamicImportCode
  PbReflectionForbidden {} -> selected retainPbReflectionCode
  PbHookForbidden {} -> selected retainPbHookCode
  PbUnresolvedCall {} -> selected retainPbUnresolvedCallCode
  PbDirectEffect {} -> selected retainPbDirectEffectCode
  PbAdapterConstructionCount {} -> selected retainPbAdapterCountCode
  PbSignatureProblem {} -> selected retainPbSignatureCode
  PbPinProblem {} -> selected retainPbPinCode
  PbArgvProvenanceProblem {} -> selected retainPbArgvCode
  PbInjectionSeamProblem {} -> selected retainPbInjectionCode
  PbHandoffControlFlowProblem {} -> selected retainPbControlFlowCode
  PbBinaryProvenanceProblem {} -> selected retainPbBinaryCode
  PbGhcupEnsureProblem {} -> selected retainPbGhcupEnsureCode
  PbClosedEnvironmentProblem {} -> selected retainPbEnvironmentCode
  PbToolchainExecutableProblem {} -> selected retainPbToolchainCode
  PbPlatformProofProblem {} -> selected retainPbPlatformCode
  PbProblemLimitExceeded {} -> selected retainPbProblemLimitCode
 where
  selected True = code
  selected False = "PB-GRAMMAR-CODE-MUTANT"

retainPbInvalidUtf8Code :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_INVALID_UTF8_CODE_MAPPING_MUTANT)
retainPbInvalidUtf8Code = False
#else
retainPbInvalidUtf8Code = True
#endif

retainPbLineDisciplineCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_LINE_DISCIPLINE_CODE_MAPPING_MUTANT)
retainPbLineDisciplineCode = False
#else
retainPbLineDisciplineCode = True
#endif

retainPbLexicalCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_LEXICAL_CODE_MAPPING_MUTANT)
retainPbLexicalCode = False
#else
retainPbLexicalCode = True
#endif

retainPbParseCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_PARSE_CODE_MAPPING_MUTANT)
retainPbParseCode = False
#else
retainPbParseCode = True
#endif

retainPbUnsupportedImportCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_UNSUPPORTED_IMPORT_CODE_MAPPING_MUTANT)
retainPbUnsupportedImportCode = False
#else
retainPbUnsupportedImportCode = True
#endif

retainPbNestedImportCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_NESTED_IMPORT_CODE_MAPPING_MUTANT)
retainPbNestedImportCode = False
#else
retainPbNestedImportCode = True
#endif

retainPbBindingConflictCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_BINDING_CONFLICT_CODE_MAPPING_MUTANT)
retainPbBindingConflictCode = False
#else
retainPbBindingConflictCode = True
#endif

retainPbMonkeypatchCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_MONKEYPATCH_CODE_MAPPING_MUTANT)
retainPbMonkeypatchCode = False
#else
retainPbMonkeypatchCode = True
#endif

retainPbDynamicImportCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_DYNAMIC_IMPORT_CODE_MAPPING_MUTANT)
retainPbDynamicImportCode = False
#else
retainPbDynamicImportCode = True
#endif

retainPbReflectionCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_REFLECTION_CODE_MAPPING_MUTANT)
retainPbReflectionCode = False
#else
retainPbReflectionCode = True
#endif

retainPbHookCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_HOOK_CODE_MAPPING_MUTANT)
retainPbHookCode = False
#else
retainPbHookCode = True
#endif

retainPbUnresolvedCallCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_UNRESOLVED_CALL_CODE_MAPPING_MUTANT)
retainPbUnresolvedCallCode = False
#else
retainPbUnresolvedCallCode = True
#endif

retainPbDirectEffectCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_DIRECT_EFFECT_CODE_MAPPING_MUTANT)
retainPbDirectEffectCode = False
#else
retainPbDirectEffectCode = True
#endif

retainPbAdapterCountCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_ADAPTER_COUNT_CODE_MAPPING_MUTANT)
retainPbAdapterCountCode = False
#else
retainPbAdapterCountCode = True
#endif

retainPbSignatureCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_SIGNATURE_CODE_MAPPING_MUTANT)
retainPbSignatureCode = False
#else
retainPbSignatureCode = True
#endif

retainPbPinCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_PIN_CODE_MAPPING_MUTANT)
retainPbPinCode = False
#else
retainPbPinCode = True
#endif

retainPbArgvCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_ARGV_CODE_MAPPING_MUTANT)
retainPbArgvCode = False
#else
retainPbArgvCode = True
#endif

retainPbInjectionCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_INJECTION_CODE_MAPPING_MUTANT)
retainPbInjectionCode = False
#else
retainPbInjectionCode = True
#endif

retainPbControlFlowCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_CONTROL_FLOW_CODE_MAPPING_MUTANT)
retainPbControlFlowCode = False
#else
retainPbControlFlowCode = True
#endif

retainPbBinaryCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_BINARY_CODE_MAPPING_MUTANT)
retainPbBinaryCode = False
#else
retainPbBinaryCode = True
#endif

retainPbGhcupEnsureCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_GHCUP_ENSURE_CODE_MAPPING_MUTANT)
retainPbGhcupEnsureCode = False
#else
retainPbGhcupEnsureCode = True
#endif

retainPbEnvironmentCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_ENVIRONMENT_CODE_MAPPING_MUTANT)
retainPbEnvironmentCode = False
#else
retainPbEnvironmentCode = True
#endif

retainPbToolchainCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_TOOLCHAIN_CODE_MAPPING_MUTANT)
retainPbToolchainCode = False
#else
retainPbToolchainCode = True
#endif

retainPbPlatformCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_PLATFORM_CODE_MAPPING_MUTANT)
retainPbPlatformCode = False
#else
retainPbPlatformCode = True
#endif

retainPbProblemLimitCode :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PROBLEM_LIMIT_CODE_MAPPING_MUTANT)
retainPbProblemLimitCode = False
#else
retainPbProblemLimitCode = True
#endif


pbProblemCode :: PbProblem -> Text
pbProblemCode problem = selectPbProblemCode problem (case problem of
  PbInvalidUtf8 {} -> "PB-GRAMMAR-UTF8"
  PbLineDiscipline {} -> "PB-GRAMMAR-LINE-DISCIPLINE"
  PbLexicalProblem {} -> "PB-GRAMMAR-LEXICAL"
  PbParseProblem {} -> "PB-GRAMMAR-PARSE"
  PbUnsupportedImport {} -> "PB-GRAMMAR-IMPORT"
  PbNestedImport {} -> "PB-GRAMMAR-NESTED-IMPORT"
  PbBindingConflict {} -> "PB-GRAMMAR-BINDING-CONFLICT"
  PbMonkeypatchAssignment {} -> "PB-GRAMMAR-MONKEYPATCH"
  PbDynamicImport {} -> "PB-GRAMMAR-DYNAMIC-IMPORT"
  PbReflectionForbidden {} -> "PB-GRAMMAR-REFLECTION"
  PbHookForbidden {} -> "PB-GRAMMAR-HOOK"
  PbUnresolvedCall {} -> "PB-GRAMMAR-UNRESOLVED-CALL"
  PbDirectEffect {} -> "PB-GRAMMAR-DIRECT-EFFECT"
  PbAdapterConstructionCount {} -> "PB-GRAMMAR-ADAPTER-COUNT"
  PbSignatureProblem {} -> "PB-GRAMMAR-SIGNATURE"
  PbPinProblem {} -> "PB-GRAMMAR-PIN"
  PbArgvProvenanceProblem {} -> "PB-GRAMMAR-ARGV"
  PbInjectionSeamProblem {} -> "PB-GRAMMAR-INJECTION"
  PbHandoffControlFlowProblem {} -> "PB-GRAMMAR-CONTROL-FLOW"
  PbBinaryProvenanceProblem {} -> "PB-GRAMMAR-BINARY"
  PbGhcupEnsureProblem {} -> "PB-GRAMMAR-GHCUP-ENSURE"
  PbClosedEnvironmentProblem {} -> "PB-GRAMMAR-ENVIRONMENT"
  PbToolchainExecutableProblem {} -> "PB-GRAMMAR-TOOLCHAIN"
  PbPlatformProofProblem {} -> "PB-GRAMMAR-PLATFORM"
  PbProblemLimitExceeded {} -> "PB-GRAMMAR-PROBLEM-LIMIT"
  )

boundProblemList :: [PbProblem] -> [PbProblem]
boundProblemList problems =
  case boundedLength (maximumDiagnosticProblems + 1) problems of
    observed
      | observed > maximumDiagnosticProblems ->
          [PbProblemLimitExceeded maximumDiagnosticProblems observed]
    _ -> problems

canonicalBootstrapBytes :: ByteString
canonicalBootstrapBytes =
  ByteString8.unlines
    [ "import hashlib"
    , "import os"
    , "import platform"
    , "import subprocess"
    , "import sys"
    , "import urllib.request"
    , "from pathlib import Path"
    , "GHCUP_VERSION = \"0.2.6.2\""
    , "GHC_VERSION = \"9.12.4\""
    , "CABAL_VERSION = \"3.16.1.0\""
    , "BUILD_TARGET = \"exe:amoebius\""
    , "def select_artifact(system, machine):"
    , "    if system == \"Linux\" and machine == \"x86_64\":"
    , "        return (\"https://downloads.haskell.org/~ghcup/0.2.6.2/x86_64-linux-ghcup-0.2.6.2\", \"9ed5da5449b48043a0d17e767c05d2ef585e25a639bb934329496c6d2fad9cf8\", \"linux-amd64\", \"ghcup\", \"\")"
    , "    if system == \"Linux\" and machine == \"aarch64\":"
    , "        return (\"https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-linux-ghcup-0.2.6.2\", \"65a5f05120288ee4f1a81d28825374b6af317456a351a586adfce90c6dc29e3b\", \"linux-arm64\", \"ghcup\", \"\")"
    , "    if system == \"Darwin\" and machine == \"arm64\":"
    , "        return (\"https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-apple-darwin-ghcup-0.2.6.2\", \"4e521e008fe0813db6db4b91cfeebd0c44c80c68afb458ea32a1c94cf5c7cc1d\", \"darwin-arm64\", \"ghcup\", \"\")"
    , "    if system == \"Windows\" and machine == \"AMD64\":"
    , "        return (\"https://downloads.haskell.org/~ghcup/0.2.6.2/x86_64-mingw64-ghcup-0.2.6.2.exe\", \"94da902a2853b1de1df509d04da900a05258480759efdb4f654e66956b6f30db\", \"windows-amd64\", \"ghcup.exe\", \".exe\")"
    , "    raise RuntimeError(\"unsupported-platform\")"
    , "class BootstrapAdapter:"
    , "    def repository_root(self):"
    , "        return Path(__file__).resolve().parents[1]"
    , "    def platform(self):"
    , "        return (platform.system(), platform.machine())"
    , "    def ensure_ghcup(self, url, digest, target):"
    , "        if target.is_file():"
    , "            existing_payload = target.read_bytes()"
    , "            existing_hash_value = hashlib.sha256(existing_payload)"
    , "            existing_digest = existing_hash_value.hexdigest()"
    , "            if existing_digest == digest:"
    , "                return target"
    , "            raise RuntimeError(\"ghcup-existing-sha256\")"
    , "        target.parent.mkdir(parents=True, exist_ok=True)"
    , "        response = urllib.request.urlopen(url)"
    , "        payload = response.read()"
    , "        hash_value = hashlib.sha256(payload)"
    , "        observed = hash_value.hexdigest()"
    , "        if observed != digest:"
    , "            raise RuntimeError(\"ghcup-sha256\")"
    , "        target.write_bytes(payload)"
    , "        target.chmod(448)"
    , "        return target"
    , "    def environment(self, toolchain):"
    , "        home = toolchain / \"home\""
    , "        cache = toolchain / \"cache\""
    , "        temporary = toolchain / \"tmp\""
    , "        home.mkdir(parents=True, exist_ok=True)"
    , "        cache.mkdir(parents=True, exist_ok=True)"
    , "        temporary.mkdir(parents=True, exist_ok=True)"
    , "        environment = {}"
    , "        environment[\"GHCUP_INSTALL_BASE_PREFIX\"] = str(toolchain)"
    , "        environment[\"GHCUP_SKIP_UPDATE_CHECK\"] = \"yes\""
    , "        environment[\"HOME\"] = str(home)"
    , "        environment[\"XDG_CACHE_HOME\"] = str(cache)"
    , "        environment[\"TMPDIR\"] = str(temporary)"
    , "        environment[\"TEMP\"] = str(temporary)"
    , "        environment[\"TMP\"] = str(temporary)"
    , "        return environment"
    , "    def run(self, root, arguments, environment):"
    , "        subprocess.run(arguments, cwd=root, env=environment, check=True, shell=False)"
    , "    def capture(self, root, arguments, environment):"
    , "        return subprocess.run(arguments, cwd=root, env=environment, check=True, shell=False, stdout=subprocess.PIPE).stdout"
    , "    def handoff(self, binary, arguments):"
    , "        os.execv(binary, arguments)"
    , "def bootstrap(adapter, arguments):"
    , "    root = adapter.repository_root()"
    , "    observed_platform = adapter.platform()"
    , "    artifact = select_artifact(observed_platform[0], observed_platform[1])"
    , "    toolchain = root / \".build\" / \"toolchain\" / artifact[2]"
    , "    ghcup_target = toolchain / \"bootstrap\" / artifact[3]"
    , "    ghcup = adapter.ensure_ghcup(artifact[0], artifact[1], ghcup_target)"
    , "    environment = adapter.environment(toolchain)"
    , "    adapter.run(root, [str(ghcup), \"install\", \"ghc\", GHC_VERSION, \"--set\"], environment)"
    , "    adapter.run(root, [str(ghcup), \"install\", \"cabal\", CABAL_VERSION, \"--set\"], environment)"
    , "    ghc = toolchain / \".ghcup\" / \"ghc\" / GHC_VERSION / \"bin\" / (\"ghc\" + artifact[4])"
    , "    cabal = toolchain / \".ghcup\" / \"bin\" / (\"cabal\" + artifact[4])"
    , "    builddir = toolchain / \"dist-newstyle\""
    , "    store = toolchain / \"cabal-store\""
    , "    adapter.run(root, [str(cabal), \"--store-dir=\" + str(store), \"build\", \"--builddir=\" + str(builddir), \"--with-compiler=\" + str(ghc), BUILD_TARGET], environment)"
    , "    binary_bytes = adapter.capture(root, [str(cabal), \"--store-dir=\" + str(store), \"list-bin\", \"--builddir=\" + str(builddir), \"--with-compiler=\" + str(ghc), BUILD_TARGET], environment)"
    , "    binary_text = binary_bytes.decode(\"utf-8\")"
    , "    binary = binary_text.strip()"
#if defined(VALIDATION_PB_GRAMMAR_WEAK_HANDOFF_PROVENANCE_MUTANT)
    , "    adapter.handoff(binary, [binary])"
#else
    , "    adapter.handoff(binary, [binary] + arguments)"
#endif
    , "def main():"
    , "    adapter = BootstrapAdapter()"
    , "    bootstrap(adapter, sys.argv[1:])"
    , "if __name__ == \"__main__\":"
    , "    main()"
    ]

canonicalArtifacts :: [PlatformArtifact]
canonicalArtifacts =
  [ PlatformArtifact
      LinuxAmd64Adapter
      "Linux"
      "x86_64"
      "linux-amd64"
      "https://downloads.haskell.org/~ghcup/0.2.6.2/x86_64-linux-ghcup-0.2.6.2"
      "9ed5da5449b48043a0d17e767c05d2ef585e25a639bb934329496c6d2fad9cf8"
      "ghcup"
      ""
  , PlatformArtifact
      LinuxArm64Adapter
      "Linux"
      "aarch64"
      "linux-arm64"
      "https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-linux-ghcup-0.2.6.2"
      "65a5f05120288ee4f1a81d28825374b6af317456a351a586adfce90c6dc29e3b"
      "ghcup"
      ""
  , PlatformArtifact
      DarwinArm64Adapter
      "Darwin"
      "arm64"
      "darwin-arm64"
      "https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-apple-darwin-ghcup-0.2.6.2"
      "4e521e008fe0813db6db4b91cfeebd0c44c80c68afb458ea32a1c94cf5c7cc1d"
      "ghcup"
      ""
  , PlatformArtifact
      WindowsAmd64Adapter
      "Windows"
      "AMD64"
      "windows-amd64"
      "https://downloads.haskell.org/~ghcup/0.2.6.2/x86_64-mingw64-ghcup-0.2.6.2.exe"
      "94da902a2853b1de1df509d04da900a05258480759efdb4f654e66956b6f30db"
      "ghcup.exe"
      ".exe"
  ]

analyzePbBootstrap :: [PbTrackedFile] -> Either [PbProblem] PbBootstrapProof
analyzePbBootstrap inventory =
  case allProblems of
    [] -> case (astResult, resolvedResult, argvResult, binaryResult, injectionResult, ensureResult, environmentResult, executableResult, platformResult) of
      (Right ast, Right resolved, Right argvProof, Right binaryProof, Right injectionProof, Right ensureProof, Right environmentProof, Right executableProof, Right adapters) ->
        case bootstrapSubject of
          Just subject ->
            let bytes = pbTrackedBytes subject
                subjectPath = pbTrackedPath subject
                subjectMode = renderTrackedMode (pbTrackedMode subject)
                effects = collectPotentialEffects ast resolved
                controlFlow = buildControlFlow ast
                phase50Contract =
                  RequiredPhase50PythonDirectoryInvocation
                    "<authenticated-absolute-python>"
                    ["-I", "-S", "-B"]
                    "/abs/repo/pb"
                    "<argv...>"
             in Right
                  PbBootstrapProof
                    { proofSubjectPath = subjectPath
                    , proofSubjectMode = subjectMode
                    , proofSubjectBytes = ByteString.length bytes
                    , proofSubjectSha256 = sha256Text bytes
                    , proofExpectedSha256 = expectedBootstrapSha256
                    , proofResourceMetrics = scanResourceMetrics bytes
                    , proofImportClosure = map renderImportBinding (collectImports ast)
                    , proofResolvedCallCount = length resolved
                    , proofPotentialEffectCount = length effects
                    , proofControlFlowSummary = controlFlowSummary controlFlow
                    , proofPlatformLabels = map artifactLabel adapters
                    , proofStaticClaims =
                        [ renderArgvClaim argvProof
                        , renderBinaryClaim binaryProof
                        , renderInjectionClaim injectionProof
                        , renderPhase50InvocationClaim phase50Contract
                        , renderEnsureClaim ensureProof
                        , renderEnvironmentClaim environmentProof
                        , renderExecutableClaim executableProof
                        , renderPlatformLimitationsClaim (derivePlatformLimitations adapters)
                        , renderRuntimeBoundaryClaim RuntimeTruthDeferredToPhase50
                        ]
                    , proofRuntimeResidue = runtimeResidue
                    }
          Nothing -> Left [PbParseProblem "pb/__main__.py" 1 1 "preflight lost the exact bootstrap subject"]
      _ -> Left [PbParseProblem "pb/__main__.py" 1 1 "internal proof construction did not close"]
    problems -> Left problems
 where
  byPath = Map.fromList [(pbTrackedPath item, item) | item <- inventory]
  bootstrapSubject = Map.lookup "pb/__main__.py" byPath
  bootstrapBytes = pbTrackedBytes <$> bootstrapSubject
  rawAstResult = maybe (Left (PbParseProblem "pb/__main__.py" 1 1 "preflight lost the exact bootstrap subject")) parseBootstrapAst bootstrapBytes
  astResult = mutateAstRefusal rawAstResult
  resolvedResult = astResult >>= resolveAllCalls
  semanticProblems = either pure (mutateProgramProblems . validateProgram) astResult
#if defined(VALIDATION_PB_GRAMMAR_RESOLUTION_BYPASS_MUTANT)
  resolutionProblems = []
#else
  resolutionProblems = either pure (const []) resolvedResult
#endif
  argvResult = astResult >>= proveArgvForBuild
  argvProblems = mutateArgvProblems (either pure (const []) argvResult)
  binaryResult = astResult >>= proveBinary
  binaryProblems = mutateBinaryProblems (either pure (const []) binaryResult)
  injectionResult = astResult >>= proveInjectionSeamForBuild
  injectionProblems = mutateInjectionProblems (either pure (const []) injectionResult)
  ensureResult = astResult >>= proveGhcupEnsure
  ensureProblems = mutateEnsureProblems (either pure (const []) ensureResult)
  environmentResult = astResult >>= proveClosedEnvironment
  environmentProblems = mutateEnvironmentProblems (either pure (const []) environmentResult)
  executableResult = astResult >>= proveToolchainExecutables
  executableProblems = mutateExecutableProblems (either pure (const []) executableResult)
  platformResult = astResult >>= provePlatformArtifacts
  platformProofProblems = mutatePlatformProblems (either pure (const []) platformResult)
  terminalProblems = mutateTerminalProblems (either pure validateHandoffControlFlowForBuild astResult)
  allProblems =
    boundProblemList
      (stableNub
      ( either pure (const []) astResult
          <> semanticProblems
          <> resolutionProblems
          <> argvProblems
          <> binaryProblems
          <> injectionProblems
          <> ensureProblems
          <> environmentProblems
          <> executableProblems
          <> platformProofProblems
          <> terminalProblems
      ))

-- Lexer ---------------------------------------------------------------------

data Token
  = TokName Text
  | TokString Text
  | TokInteger Integer
  | TokLParen
  | TokRParen
  | TokLBracket
  | TokRBracket
  | TokLBrace
  | TokRBrace
  | TokComma
  | TokColon
  | TokDot
  | TokAssign
  | TokEqual
  | TokNotEqual
  | TokPlus
  | TokSlash
  | TokNewline
  | TokIndent
  | TokDedent
  | TokEof
  deriving (Eq, Ord, Show)

data LocatedToken = LocatedToken
  { locatedPath :: FilePath
  , locatedLine :: Int
  , locatedColumn :: Int
  , locatedToken :: Token
  }
  deriving (Eq, Ord, Show)

strictTextLines :: FilePath -> ByteString -> Either PbProblem [Text]
strictTextLines path bytes = do
  decoded <- case TextEncoding.decodeUtf8' bytes of
    Left _ -> Left (PbInvalidUtf8 path)
    Right value -> Right value
  when (Text.isPrefixOf "\xfeff" decoded) (Left (PbLineDiscipline path "UTF-8 BOM is forbidden"))
  when (Text.any (== '\r') decoded) (Left (PbLineDiscipline path "CR and CRLF are forbidden"))
  when (Text.any (== '\t') decoded) (Left (PbLineDiscipline path "tabs are forbidden"))
  when (Text.any (== '\NUL') decoded) (Left (PbLineDiscipline path "NUL is forbidden"))
  unless (Text.isSuffixOf "\n" decoded) (Left (PbLineDiscipline path "exact final LF is required"))
  when (Text.isSuffixOf "\n\n" decoded) (Left (PbLineDiscipline path "trailing blank lines are forbidden"))
  let segments = Text.splitOn "\n" decoded
      contentLines = case reverse segments of
        "" : reversed -> reverse reversed
        _ -> segments
  when (null contentLines) (Left (PbLineDiscipline path "file must contain a line"))
  when (any (Text.null . Text.strip) contentLines) (Left (PbLineDiscipline path "blank lines are outside the grammar"))
  pure contentLines

lexBootstrap :: ByteString -> Either PbProblem [LocatedToken]
lexBootstrap bytes = do
  linesOfSource <- strictTextLines bootstrapPath bytes
  (tokens, indentation) <- foldM lexOne ([], [0]) (zip [1 ..] linesOfSource)
  let finalLine = length linesOfSource + 1
      dedents = replicate (length indentation - 1) (LocatedToken bootstrapPath finalLine 1 TokDedent)
  pure (tokens <> dedents <> [LocatedToken bootstrapPath finalLine 1 TokEof])
 where
  bootstrapPath = "pb/__main__.py"
  lexOne (prior, stack) (lineNumber, sourceLine) = do
    let indentation = Text.length (Text.takeWhile (== ' ') sourceLine)
        content = Text.drop indentation sourceLine
    when (indentation `mod` 4 /= 0) (Left (PbLexicalProblem bootstrapPath lineNumber 1 "indentation must be a multiple of four spaces"))
    (indentTokens, nextStack) <- indentationTokens bootstrapPath lineNumber indentation stack
    lineTokens <- lexLine bootstrapPath lineNumber (indentation + 1) content
    pure (prior <> indentTokens <> lineTokens <> [LocatedToken bootstrapPath lineNumber (Text.length sourceLine + 1) TokNewline], nextStack)

indentationTokens
  :: FilePath
  -> Int
  -> Int
  -> [Int]
  -> Either PbProblem ([LocatedToken], [Int])
indentationTokens path lineNumber indentation stack =
  case stack of
    [] -> Left (PbLexicalProblem path lineNumber 1 "internal empty indentation stack")
    current : _
      | indentation == current -> Right ([], stack)
      | indentation == current + 4 -> Right ([at TokIndent], indentation : stack)
      | indentation > current -> Left (PbLexicalProblem path lineNumber 1 "indentation may increase by exactly four spaces")
      | otherwise -> dedent stack []
 where
  at token = LocatedToken path lineNumber 1 token
  dedent [] _ = Left (PbLexicalProblem path lineNumber 1 "dedent has no matching indentation level")
  dedent remaining@(current : rest) found
    | indentation == current = Right (reverse found, remaining)
    | indentation < current = dedent rest (at TokDedent : found)
    | otherwise = Left (PbLexicalProblem path lineNumber 1 "dedent has no matching indentation level")

lexLine :: FilePath -> Int -> Int -> Text -> Either PbProblem [LocatedToken]
lexLine path lineNumber initialColumn source = go initialColumn (Text.unpack source)
 where
  located column token = LocatedToken path lineNumber column token
  go _ [] = Right []
  go column characters@(character : rest)
    | character == ' ' = go (column + 1) rest
    | nameStart character =
        let (nameCharacters, remaining) = span nameContinue characters
            width = length nameCharacters
         in fmap (located column (TokName (Text.pack nameCharacters)) :) (go (column + width) remaining)
    | isDigit character =
        let (digits, remaining) = span isDigit characters
            width = length digits
         in fmap (located column (TokInteger (decimalInteger digits)) :) (go (column + width) remaining)
    | character == '"' = do
        (value, remaining, width) <- stringLiteral column rest
        fmap (located column (TokString value) :) (go (column + width) remaining)
    | otherwise = case characters of
        '=' : '=' : remaining -> cons 2 TokEqual remaining
        '!' : '=' : remaining -> cons 2 TokNotEqual remaining
        '(' : remaining -> cons 1 TokLParen remaining
        ')' : remaining -> cons 1 TokRParen remaining
        '[' : remaining -> cons 1 TokLBracket remaining
        ']' : remaining -> cons 1 TokRBracket remaining
        '{' : remaining -> cons 1 TokLBrace remaining
        '}' : remaining -> cons 1 TokRBrace remaining
        ',' : remaining -> cons 1 TokComma remaining
        ':' : remaining -> cons 1 TokColon remaining
        '.' : remaining -> cons 1 TokDot remaining
        '=' : remaining -> cons 1 TokAssign remaining
        '+' : remaining -> cons 1 TokPlus remaining
        '/' : remaining -> cons 1 TokSlash remaining
        _ -> Left (PbLexicalProblem path lineNumber column ("unsupported character " <> Text.singleton character))
   where
    cons width token remaining = fmap (located column token :) (go (column + width) remaining)
  stringLiteral column = collect [] 1
   where
    collect _ _ [] = Left (PbLexicalProblem path lineNumber column "unterminated string literal")
    collect reversed width (character : remaining)
      | character == '"' = Right (Text.pack (reverse reversed), remaining, width + 1)
      | character == '\\' = Left (PbLexicalProblem path lineNumber (column + width) "string escapes are outside the grammar")
      | character < ' ' || character == '\DEL' = Left (PbLexicalProblem path lineNumber (column + width) "control character in string literal")
      | otherwise = collect (character : reversed) (width + 1) remaining
  nameStart character = character == '_' || isAsciiLower character || isAsciiUpper character
  nameContinue character = nameStart character || isDigit character

  -- The lexer has already isolated a non-empty decimal span, but keeping the
  -- conversion total prevents malformed future callers from turning a
  -- diagnostic parser into an exception source.
  decimalInteger = goDecimal 0
   where
    goDecimal value [] = value
    goDecimal value (digit : remaining)
      | isDigit digit =
          goDecimal
            (value * 10 + toInteger (fromEnum digit - fromEnum '0'))
            remaining
      | otherwise = value

-- Parser --------------------------------------------------------------------

admitStatementImport :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_IMPORT_MUTANT)
admitStatementImport = False
#else
admitStatementImport = True
#endif

admitStatementFromImport :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_FROM_IMPORT_MUTANT)
admitStatementFromImport = False
#else
admitStatementFromImport = True
#endif

admitStatementClass :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_CLASS_MUTANT)
admitStatementClass = False
#else
admitStatementClass = True
#endif

admitStatementFunction :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_FUNCTION_MUTANT)
admitStatementFunction = False
#else
admitStatementFunction = True
#endif

admitStatementIf :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_IF_MUTANT)
admitStatementIf = False
#else
admitStatementIf = True
#endif

admitStatementReturn :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_RETURN_MUTANT)
admitStatementReturn = False
#else
admitStatementReturn = True
#endif

admitStatementRaise :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_RAISE_MUTANT)
admitStatementRaise = False
#else
admitStatementRaise = True
#endif

admitStatementAssignment :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_ASSIGNMENT_MUTANT)
admitStatementAssignment = False
#else
admitStatementAssignment = True
#endif

admitStatementExpression :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_EXPRESSION_MUTANT)
admitStatementExpression = False
#else
admitStatementExpression = True
#endif

admitBinaryAnd :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_BINARY_AND_MUTANT)
admitBinaryAnd = False
#else
admitBinaryAnd = True
#endif

admitBinaryEqual :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_BINARY_EQUAL_MUTANT)
admitBinaryEqual = False
#else
admitBinaryEqual = True
#endif

admitBinaryNotEqual :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_BINARY_NOT_EQUAL_MUTANT)
admitBinaryNotEqual = False
#else
admitBinaryNotEqual = True
#endif

admitBinaryAdd :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_BINARY_ADD_MUTANT)
admitBinaryAdd = False
#else
admitBinaryAdd = True
#endif

admitBinaryPathJoin :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_BINARY_PATH_JOIN_MUTANT)
admitBinaryPathJoin = False
#else
admitBinaryPathJoin = True
#endif

admitExpressionAttribute :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_ATTRIBUTE_MUTANT)
admitExpressionAttribute = False
#else
admitExpressionAttribute = True
#endif

admitExpressionIndex :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_INDEX_MUTANT)
admitExpressionIndex = False
#else
admitExpressionIndex = True
#endif

admitExpressionCall :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_CALL_MUTANT)
admitExpressionCall = False
#else
admitExpressionCall = True
#endif

admitIndexLeadingSlice :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_INDEX_LEADING_SLICE_MUTANT)
admitIndexLeadingSlice = False
#else
admitIndexLeadingSlice = True
#endif

admitIndexStartedSlice :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_INDEX_STARTED_SLICE_MUTANT)
admitIndexStartedSlice = False
#else
admitIndexStartedSlice = True
#endif

admitIndexPlain :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_INDEX_PLAIN_MUTANT)
admitIndexPlain = False
#else
admitIndexPlain = True
#endif

admitExpressionTrue :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_TRUE_MUTANT)
admitExpressionTrue = False
#else
admitExpressionTrue = True
#endif

admitExpressionFalse :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_FALSE_MUTANT)
admitExpressionFalse = False
#else
admitExpressionFalse = True
#endif

admitExpressionName :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_NAME_MUTANT)
admitExpressionName = False
#else
admitExpressionName = True
#endif

admitExpressionString :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_STRING_MUTANT)
admitExpressionString = False
#else
admitExpressionString = True
#endif

admitExpressionInteger :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_INTEGER_MUTANT)
admitExpressionInteger = False
#else
admitExpressionInteger = True
#endif

admitExpressionDictionary :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_DICTIONARY_MUTANT)
admitExpressionDictionary = False
#else
admitExpressionDictionary = True
#endif

admitExpressionParenthesized :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_PARENTHESIZED_MUTANT)
admitExpressionParenthesized = False
#else
admitExpressionParenthesized = True
#endif

admitExpressionList :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_LIST_MUTANT)
admitExpressionList = False
#else
admitExpressionList = True
#endif

admitParenthesizedEmptyTuple :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_PARENTHESIZED_EMPTY_TUPLE_MUTANT)
admitParenthesizedEmptyTuple = False
#else
admitParenthesizedEmptyTuple = True
#endif

admitParenthesizedTuple :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_PARENTHESIZED_TUPLE_MUTANT)
admitParenthesizedTuple = False
#else
admitParenthesizedTuple = True
#endif

admitParenthesizedGrouped :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_PARENTHESIZED_GROUPED_MUTANT)
admitParenthesizedGrouped = False
#else
admitParenthesizedGrouped = True
#endif

admitListEmpty :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_LIST_EMPTY_MUTANT)
admitListEmpty = False
#else
admitListEmpty = True
#endif

admitListNonempty :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_LIST_NONEMPTY_MUTANT)
admitListNonempty = False
#else
admitListNonempty = True
#endif

admitArgumentKeyword :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_ARGUMENT_KEYWORD_MUTANT)
admitArgumentKeyword = False
#else
admitArgumentKeyword = True
#endif

admitArgumentPositional :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_ARGUMENT_POSITIONAL_MUTANT)
admitArgumentPositional = False
#else
admitArgumentPositional = True
#endif

admitDottedNameExtension :: Bool
#if defined(VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_DOTTED_NAME_EXTENSION_MUTANT)
admitDottedNameExtension = False
#else
admitDottedNameExtension = True
#endif

newtype Parser value = Parser
  { runParser :: [LocatedToken] -> Either PbProblem (value, [LocatedToken])
  }

instance Functor Parser where
  fmap transform parser = Parser $ \tokens -> do
    (value, rest) <- runParser parser tokens
    pure (transform value, rest)

instance Applicative Parser where
  pure value = Parser (Right . (value,))
  functionParser <*> valueParser = Parser $ \tokens -> do
    (function, afterFunction) <- runParser functionParser tokens
    (value, afterValue) <- runParser valueParser afterFunction
    pure (function value, afterValue)

instance Monad Parser where
  parser >>= next = Parser $ \tokens -> do
    (value, rest) <- runParser parser tokens
    runParser (next value) rest

parseBootstrapAst :: ByteString -> Either PbProblem BootstrapAst
parseBootstrapAst bytes = do
  tokens <- lexBootstrap bytes
  case runParser parseModule tokens of
    Left problem -> Left problem
    Right (ast, []) -> Right ast
    Right (_, token : _) -> Left (parseAt token "parser left an unconsumed token")

mutateAstRefusal
  :: Either PbProblem BootstrapAst
  -> Either PbProblem BootstrapAst
mutateAstRefusal result =
#if defined(VALIDATION_PB_GRAMMAR_UTF8_BYPASS_MUTANT)
  case result of
    Left PbInvalidUtf8 {} -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LINE_BOM_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLineDiscipline _ "UTF-8 BOM is forbidden") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LINE_CR_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLineDiscipline _ "CR and CRLF are forbidden") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LINE_TAB_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLineDiscipline _ "tabs are forbidden") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LINE_NUL_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLineDiscipline _ "NUL is forbidden") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LINE_FINAL_LF_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLineDiscipline _ "exact final LF is required") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LINE_TRAILING_BLANK_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLineDiscipline _ "trailing blank lines are forbidden") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LINE_BLANK_LINE_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLineDiscipline _ "blank lines are outside the grammar") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LEXICAL_INDENT_MULTIPLE_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLexicalProblem _ _ _ "indentation must be a multiple of four spaces") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LEXICAL_INDENT_INCREASE_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLexicalProblem _ _ _ "indentation may increase by exactly four spaces") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LEXICAL_UNSUPPORTED_CHARACTER_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLexicalProblem _ _ _ detail) | "unsupported character " `Text.isPrefixOf` detail -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LEXICAL_UNTERMINATED_STRING_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLexicalProblem _ _ _ "unterminated string literal") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LEXICAL_STRING_ESCAPE_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLexicalProblem _ _ _ "string escapes are outside the grammar") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_LEXICAL_STRING_CONTROL_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbLexicalProblem _ _ _ "control character in string literal") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_PARSE_TOP_INDENT_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbParseProblem _ _ _ "unexpected top-level indentation") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_PARSE_UNSUPPORTED_STATEMENT_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbParseProblem _ _ _ detail) | "unsupported statement " `Text.isPrefixOf` detail -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_PARSE_INVALID_ASSIGNMENT_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbParseProblem _ _ _ "invalid assignment target") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_PARSE_NONE_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbParseProblem _ _ _ "None is outside the grammar") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_PARSE_EXPECTED_EXPRESSION_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbParseProblem _ _ _ "expected expression") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_PARSE_EXPECTED_TOKEN_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbParseProblem _ _ _ detail) | "expected Tok" `Text.isPrefixOf` detail -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_PARSE_EXPECTED_KEYWORD_NAME_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbParseProblem _ _ _ detail) | "expected keyword/name " `Text.isPrefixOf` detail -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#elif defined(VALIDATION_PB_GRAMMAR_PARSE_EXPECTED_NAME_REFUSAL_BYPASS_MUTANT)
  case result of
    Left (PbParseProblem _ _ _ "expected name") -> parseBootstrapAst canonicalBootstrapBytes
    _ -> result
#else
  result
#endif

parseModule :: Parser BootstrapAst
parseModule = BootstrapAst <$> statementsUntilEof
 where
  statementsUntilEof = do
    token <- peekLocated
    case locatedToken token of
      TokEof -> consumeToken TokEof >> pure []
      TokIndent -> parserFail token "unexpected top-level indentation"
      TokDedent -> parserFail token "unexpected top-level dedent"
      _ -> (:) <$> parseStatement <*> statementsUntilEof

parseStatement :: Parser PyStmt
parseStatement = do
  token <- peekLocated
  case locatedToken token of
    TokName "import" -> requireAlternative admitStatementImport token "statement-import" parseImport
    TokName "from" -> requireAlternative admitStatementFromImport token "statement-from-import" parseFromImport
    TokName "class" -> requireAlternative admitStatementClass token "statement-class" parseClass
    TokName "def" -> requireAlternative admitStatementFunction token "statement-function" parseFunction
    TokName "if" -> requireAlternative admitStatementIf token "statement-if" parseIf
    TokName "return" -> requireAlternative admitStatementReturn token "statement-return" parseReturn
    TokName "raise" -> requireAlternative admitStatementRaise token "statement-raise" parseRaise
    TokName keyword
      | keyword `elem` unsupportedStatementKeywords -> parserFail token ("unsupported statement " <> keyword)
    _ -> parseAssignmentOrExpression
 where
  unsupportedStatementKeywords =
    [ "async", "await", "break", "continue", "del", "elif", "else", "for", "global"
    , "lambda", "nonlocal", "pass", "try", "while", "with", "yield"
    ]

parseImport :: Parser PyStmt
parseImport = do
  consumeName "import"
  qualified <- parseDottedName
  consumeToken TokNewline
  pure (PyImport qualified)

parseFromImport :: Parser PyStmt
parseFromImport = do
  consumeName "from"
  qualified <- parseDottedName
  consumeName "import"
  imported <- takeName
  consumeToken TokNewline
  pure (PyFromImport qualified imported)

parseClass :: Parser PyStmt
parseClass = do
  consumeName "class"
  name <- takeName
  body <- parseSuite
  pure (PyClass name body)

parseFunction :: Parser PyStmt
parseFunction = do
  consumeName "def"
  name <- takeName
  consumeToken TokLParen
  parameters <- commaSeparatedNames TokRParen
  consumeToken TokRParen
  body <- parseSuite
  pure (PyFunction name parameters body)

parseIf :: Parser PyStmt
parseIf = do
  consumeName "if"
  condition <- parseExpression
  body <- parseSuite
  pure (PyIf condition body)

parseReturn :: Parser PyStmt
parseReturn = do
  consumeName "return"
  value <- parseExpression
  consumeToken TokNewline
  pure (PyReturn value)

parseRaise :: Parser PyStmt
parseRaise = do
  consumeName "raise"
  value <- parseExpression
  consumeToken TokNewline
  pure (PyRaise value)

parseAssignmentOrExpression :: Parser PyStmt
parseAssignmentOrExpression = do
  left <- parseExpression
  token <- peekLocated
  case locatedToken token of
    TokAssign -> do
      requireAlternative admitStatementAssignment token "statement-assignment" (pure ())
      consumeToken TokAssign
      unless (validAssignmentTarget left) (parserFail token "invalid assignment target")
      right <- parseExpression
      consumeToken TokNewline
      pure (PyAssign left right)
    _ -> do
      requireAlternative admitStatementExpression token "statement-expression" (pure ())
      consumeToken TokNewline
      pure (PyExpression left)

validAssignmentTarget :: PyExpr -> Bool
validAssignmentTarget (PyName _) = True
validAssignmentTarget (PyIndex base _) = validAssignmentBase base
validAssignmentTarget _ = False

validAssignmentBase :: PyExpr -> Bool
validAssignmentBase (PyName _) = True
validAssignmentBase (PyAttribute parent _) = validAssignmentBase parent
validAssignmentBase _ = False

parseSuite :: Parser [PyStmt]
parseSuite = do
  consumeToken TokColon
  consumeToken TokNewline
  consumeToken TokIndent
  statements <- go []
  when (null statements) $ do
    token <- peekLocated
    parserFail token "suite must be non-empty"
  pure (reverse statements)
 where
  go found = do
    token <- peekLocated
    case locatedToken token of
      TokDedent -> consumeToken TokDedent >> pure found
      TokEof -> parserFail token "suite reached EOF before dedent"
      _ -> parseStatement >>= \statement -> go (statement : found)

parseExpression :: Parser PyExpr
parseExpression = parseAndExpression

parseAndExpression :: Parser PyExpr
parseAndExpression = chainNamed admitBinaryAnd "binary-and" "and" PyAnd parseComparison

parseComparison :: Parser PyExpr
parseComparison = do
  left <- parseAddition
  token <- peekLocated
  case locatedToken token of
    TokEqual -> do
      requireAlternative admitBinaryEqual token "binary-equal" (pure ())
      consumeToken TokEqual
      PyBinary PyEqual left <$> parseAddition
    TokNotEqual -> do
      requireAlternative admitBinaryNotEqual token "binary-not-equal" (pure ())
      consumeToken TokNotEqual
      PyBinary PyNotEqual left <$> parseAddition
    _ -> pure left

parseAddition :: Parser PyExpr
parseAddition = chainToken admitBinaryAdd "binary-add" TokPlus PyAdd parsePathJoin

parsePathJoin :: Parser PyExpr
parsePathJoin = chainToken admitBinaryPathJoin "binary-path-join" TokSlash PyPathJoin parsePostfix

chainNamed :: Bool -> Text -> Text -> PyBinaryOperator -> Parser PyExpr -> Parser PyExpr
chainNamed admitted alternativeName name operator operand = do
  initial <- operand
  go initial
 where
  go left = do
    token <- peekLocated
    case locatedToken token of
      TokName found | found == name -> do
        requireAlternative admitted token alternativeName (pure ())
        consumeName name
        operand >>= go . PyBinary operator left
      _ -> pure left

chainToken :: Bool -> Text -> Token -> PyBinaryOperator -> Parser PyExpr -> Parser PyExpr
chainToken admitted alternativeName separator operator operand = do
  initial <- operand
  go initial
 where
  go left = do
    token <- peekLocated
    if locatedToken token == separator
      then do
        requireAlternative admitted token alternativeName (pure ())
        consumeToken separator
        operand >>= go . PyBinary operator left
      else pure left

parsePostfix :: Parser PyExpr
parsePostfix = parsePrimary >>= go
 where
  go expression = do
    token <- peekLocated
    case locatedToken token of
      TokDot -> do
        requireAlternative admitExpressionAttribute token "expression-attribute" (pure ())
        consumeToken TokDot
        field <- takeName
        go (PyAttribute expression field)
      TokLBracket -> do
        requireAlternative admitExpressionIndex token "expression-index" (pure ())
        consumeToken TokLBracket
        index <- parseIndexValue
        consumeToken TokRBracket
        go (PyIndex expression index)
      TokLParen -> do
        requireAlternative admitExpressionCall token "expression-call" (pure ())
        consumeToken TokLParen
        arguments <- parseArguments
        consumeToken TokRParen
        go (PyCall expression arguments)
      _ -> pure expression

parseIndexValue :: Parser PyExpr
parseIndexValue = do
  token <- peekLocated
  case locatedToken token of
    TokColon -> do
      requireAlternative admitIndexLeadingSlice token "index-leading-slice" (pure ())
      consumeToken TokColon
      end <- optionalBefore TokRBracket parseExpression
      pure (PySlice Nothing end)
    _ -> do
      start <- parseExpression
      next <- peekLocated
      case locatedToken next of
        TokColon -> do
          requireAlternative admitIndexStartedSlice next "index-started-slice" (pure ())
          consumeToken TokColon
          end <- optionalBefore TokRBracket parseExpression
          pure (PySlice (Just start) end)
        _ -> requireAlternative admitIndexPlain next "index-plain" (pure start)

parsePrimary :: Parser PyExpr
parsePrimary = do
  token <- peekLocated
  case locatedToken token of
    TokName "True" -> requireAlternative admitExpressionTrue token "expression-true" (consumeAny >> pure (PyBoolean True))
    TokName "False" -> requireAlternative admitExpressionFalse token "expression-false" (consumeAny >> pure (PyBoolean False))
    TokName "None" -> parserFail token "None is outside the grammar"
    TokName name -> requireAlternative admitExpressionName token "expression-name" (consumeAny >> pure (PyName name))
    TokString value -> requireAlternative admitExpressionString token "expression-string" (consumeAny >> pure (PyString value))
    TokInteger value -> requireAlternative admitExpressionInteger token "expression-integer" (consumeAny >> pure (PyInteger value))
    TokLBrace -> do
      requireAlternative admitExpressionDictionary token "expression-dictionary" (pure ())
      consumeToken TokLBrace
      consumeToken TokRBrace
      pure PyEmptyDictionary
    TokLParen -> requireAlternative admitExpressionParenthesized token "expression-parenthesized" parseParenthesized
    TokLBracket -> requireAlternative admitExpressionList token "expression-list" parseList
    _ -> parserFail token "expected expression"

parseParenthesized :: Parser PyExpr
parseParenthesized = do
  consumeToken TokLParen
  token <- peekLocated
  case locatedToken token of
    TokRParen -> requireAlternative admitParenthesizedEmptyTuple token "parenthesized-empty-tuple" (consumeToken TokRParen >> pure (PyTuple []))
    _ -> do
      first <- parseExpression
      next <- peekLocated
      case locatedToken next of
        TokComma -> do
          requireAlternative admitParenthesizedTuple next "parenthesized-tuple" (pure ())
          consumeToken TokComma
          rest <- commaSeparatedExpressions TokRParen
          consumeToken TokRParen
          pure (PyTuple (first : rest))
        _ -> requireAlternative admitParenthesizedGrouped next "parenthesized-grouped" (consumeToken TokRParen >> pure first)

parseList :: Parser PyExpr
parseList = do
  consumeToken TokLBracket
  values <- commaSeparatedExpressions TokRBracket
  token <- peekLocated
  requireAlternative
    (if null values then admitListEmpty else admitListNonempty)
    token
    (if null values then "list-empty" else "list-nonempty")
    (pure ())
  consumeToken TokRBracket
  pure (PyList values)

parseArguments :: Parser [PyArgument]
parseArguments = do
  token <- peekLocated
  case locatedToken token of
    TokRParen -> pure []
    _ -> do
      first <- parseArgument
      go [first]
 where
  go reversed = do
    token <- peekLocated
    case locatedToken token of
      TokComma -> consumeToken TokComma >> parseArgument >>= \argument -> go (argument : reversed)
      _ -> pure (reverse reversed)
  parseArgument = do
    tokens <- peekTokens 2
    case map locatedToken tokens of
      [TokName name, TokAssign] -> do
        token <- peekLocated
        requireAlternative admitArgumentKeyword token "argument-keyword" (pure ())
        consumeName name
        consumeToken TokAssign
        PyKeyword name <$> parseExpression
      _ -> do
        token <- peekLocated
        requireAlternative admitArgumentPositional token "argument-positional" (pure ())
        PyPositional <$> parseExpression

commaSeparatedNames :: Token -> Parser [Text]
commaSeparatedNames end = do
  token <- peekLocated
  if locatedToken token == end
    then pure []
    else do
      first <- takeName
      go [first]
 where
  go reversed = do
    token <- peekLocated
    case locatedToken token of
      TokComma -> consumeToken TokComma >> takeName >>= \name -> go (name : reversed)
      _ -> pure (reverse reversed)

commaSeparatedExpressions :: Token -> Parser [PyExpr]
commaSeparatedExpressions end = do
  token <- peekLocated
  if locatedToken token == end
    then pure []
    else do
      first <- parseExpression
      go [first]
 where
  go reversed = do
    token <- peekLocated
    case locatedToken token of
      TokComma -> consumeToken TokComma >> parseExpression >>= \value -> go (value : reversed)
      _ -> pure (reverse reversed)

optionalBefore :: Token -> Parser value -> Parser (Maybe value)
optionalBefore end parser = do
  token <- peekLocated
  if locatedToken token == end then pure Nothing else Just <$> parser

parseDottedName :: Parser [Text]
parseDottedName = do
  first <- takeName
  go [first]
 where
  go reversed = do
    token <- peekLocated
    case locatedToken token of
      TokDot -> do
        requireAlternative admitDottedNameExtension token "dotted-name-extension" (pure ())
        consumeToken TokDot
        takeName >>= \name -> go (name : reversed)
      _ -> pure (reverse reversed)

requireAlternative :: Bool -> LocatedToken -> Text -> Parser value -> Parser value
requireAlternative admitted token name parser =
  if admitted
    then parser
    else parserFail token ("closed grammar alternative disabled by changed subject: " <> name)

peekLocated :: Parser LocatedToken
peekLocated = Parser $ \case
  [] -> Left (PbParseProblem "pb/__main__.py" 1 1 "unexpected end of token stream")
  tokens@(token : _) -> Right (token, tokens)

peekTokens :: Int -> Parser [LocatedToken]
peekTokens count = Parser $ \tokens -> Right (take count tokens, tokens)

consumeAny :: Parser LocatedToken
consumeAny = Parser $ \case
  [] -> Left (PbParseProblem "pb/__main__.py" 1 1 "unexpected end of token stream")
  token : rest -> Right (token, rest)

consumeToken :: Token -> Parser ()
consumeToken expected = do
  token <- consumeAny
  unless (locatedToken token == expected) (parserFail token ("expected " <> Text.pack (show expected)))

consumeName :: Text -> Parser ()
consumeName expected = do
  token <- consumeAny
  case locatedToken token of
    TokName actual | actual == expected -> pure ()
    _ -> parserFail token ("expected keyword/name " <> expected)

takeName :: Parser Text
takeName = do
  token <- consumeAny
  case locatedToken token of
    TokName name -> pure name
    _ -> parserFail token "expected name"

parserFail :: LocatedToken -> Text -> Parser value
parserFail token detail = Parser (const (Left (parseAt token detail)))

parseAt :: LocatedToken -> Text -> PbProblem
parseAt token = PbParseProblem (locatedPath token) (locatedLine token) (locatedColumn token)

-- Static proof --------------------------------------------------------------

validateProgram :: BootstrapAst -> [PbProblem]
validateProgram ast =
  importProblems
    <> nestedImportProblems
    <> bindingProblems
    <> monkeypatchProblems
    <> signatureProblems
    <> dangerousProblems
    <> directEffectProblems
    <> adapterProblems
 where
  actualImports = collectImports ast
  expectedImports =
    [ ImportBinding "hashlib" "hashlib"
    , ImportBinding "os" "os"
    , ImportBinding "platform" "platform"
    , ImportBinding "subprocess" "subprocess"
    , ImportBinding "sys" "sys"
    , ImportBinding "urllib" "urllib.request"
    , ImportBinding "Path" "pathlib.Path"
    ]
  importProblems =
    [ PbUnsupportedImport (importQualifiedName imported)
    | imported <- actualImports
    , imported `notElem` expectedImports
    ]
      <> [ PbUnsupportedImport ("missing:" <> importQualifiedName imported)
         | imported <- expectedImports
         , imported `notElem` actualImports
         ]
  nestedImportProblems =
    [ PbNestedImport scope (importQualifiedName imported)
    | (scope, directModuleChild, imported) <- collectScopedImports ast
    , not directModuleChild
    ]
  bindingProblems = validateBindings ast
  monkeypatchProblems = validateAssignmentTargets ast
  signatureProblems = validateSignatures ast
  calls = collectCalls ast
  dangerousProblems = concatMap dangerousCall calls
  directEffectProblems =
    [ PbDirectEffect scope syntax
    | (scope, expression) <- calls
    , let syntax = renderCallee expression
    , effectKind syntax /= Nothing
    , not ("BootstrapAdapter." `Text.isPrefixOf` scope)
    ]
  adapterCount = length [() | (_, PyCall (PyName "BootstrapAdapter") _) <- calls]
  adapterProblems = [PbAdapterConstructionCount adapterCount | adapterCount /= 1]

mutateProgramProblems :: [PbProblem] -> [PbProblem]
mutateProgramProblems =
#if defined(VALIDATION_PB_GRAMMAR_IMPORT_BYPASS_MUTANT)
  filter (\case PbUnsupportedImport {} -> False; _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_NESTED_IMPORT_BYPASS_MUTANT)
  filter (\case PbNestedImport {} -> False; _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_BINDING_BYPASS_MUTANT)
  filter (\case PbBindingConflict {} -> False; _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_MONKEYPATCH_BYPASS_MUTANT)
  filter (\case PbMonkeypatchAssignment {} -> False; _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_SIGNATURE_BYPASS_MUTANT)
  filter (\case PbSignatureProblem {} -> False; _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_DYNAMIC_IMPORT_BYPASS_MUTANT)
  filter (\case PbDynamicImport {} -> False; _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_REFLECTION_BYPASS_MUTANT)
  filter (\case PbReflectionForbidden {} -> False; _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_HOOK_BYPASS_MUTANT)
  filter (\case PbHookForbidden {} -> False; _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_DIRECT_EFFECT_BYPASS_MUTANT)
  filter (\case PbDirectEffect {} -> False; _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_ADAPTER_COUNT_BYPASS_MUTANT)
  filter (\case PbAdapterConstructionCount {} -> False; _ -> True)
#else
  id
#endif

mutateBinaryProblems :: [PbProblem] -> [PbProblem]
mutateBinaryProblems =
#if defined(VALIDATION_PB_GRAMMAR_PIN_ASSIGNMENT_COUNT_REFUSAL_BYPASS_MUTANT)
  filter (\case PbPinProblem detail -> not (" exact string assignment count is " `Text.isInfixOf` detail); _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_PIN_GHCUP_VERSION_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPinProblem "GHCUP_VERSION must be 0.2.6.2")
#elif defined(VALIDATION_PB_GRAMMAR_PIN_GHC_VERSION_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPinProblem "GHC_VERSION must be 9.12.4")
#elif defined(VALIDATION_PB_GRAMMAR_PIN_CABAL_VERSION_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPinProblem "CABAL_VERSION must be 3.16.1.0")
#elif defined(VALIDATION_PB_GRAMMAR_PIN_BUILD_TARGET_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPinProblem "BUILD_TARGET must be exe:amoebius")
#elif defined(VALIDATION_PB_GRAMMAR_BINARY_BOOTSTRAP_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbBinaryProvenanceProblem "bootstrap function is absent")
#elif defined(VALIDATION_PB_GRAMMAR_BINARY_ASSIGNMENT_COUNT_REFUSAL_BYPASS_MUTANT)
  filter (\case PbBinaryProvenanceProblem detail -> not (" assignment count is " `Text.isInfixOf` detail); _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_BINARY_LOCATOR_REFUSAL_BYPASS_MUTANT)
  filter (/= PbBinaryProvenanceProblem "binary bytes do not come from contained cabal list-bin")
#elif defined(VALIDATION_PB_GRAMMAR_BINARY_DECODE_REFUSAL_BYPASS_MUTANT)
  filter (/= PbBinaryProvenanceProblem "binary locator is not exact UTF-8")
#elif defined(VALIDATION_PB_GRAMMAR_BINARY_PATH_REFUSAL_BYPASS_MUTANT)
  filter (/= PbBinaryProvenanceProblem "binary path is not derived only from list-bin output")
#elif defined(VALIDATION_PB_GRAMMAR_BINARY_ORDER_REFUSAL_BYPASS_MUTANT)
  filter (/= PbBinaryProvenanceProblem "one exact build must precede one exact list-bin")
#else
  id
#endif

mutateArgvProblems :: [PbProblem] -> [PbProblem]
mutateArgvProblems =
#if defined(VALIDATION_PB_GRAMMAR_ARGV_MAIN_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbArgvProvenanceProblem "main function is absent")
#elif defined(VALIDATION_PB_GRAMMAR_ARGV_BOOTSTRAP_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbArgvProvenanceProblem "bootstrap function is absent")
#elif defined(VALIDATION_PB_GRAMMAR_ARGV_MAIN_BODY_REFUSAL_BYPASS_MUTANT)
  filter (/= PbArgvProvenanceProblem "main must pass sys.argv[1:] unchanged to the injected bootstrap seam")
#elif defined(VALIDATION_PB_GRAMMAR_ARGV_HANDOFF_REFUSAL_BYPASS_MUTANT)
  filter (/= PbArgvProvenanceProblem "bootstrap must hand off [binary] + arguments exactly")
#elif defined(VALIDATION_PB_GRAMMAR_ARGV_SYS_ARGV_COUNT_REFUSAL_BYPASS_MUTANT)
  filter (\case PbArgvProvenanceProblem detail -> not ("sys.argv occurrence count is " `Text.isPrefixOf` detail); _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_ARGV_ARGUMENTS_COUNT_REFUSAL_BYPASS_MUTANT)
  filter (\case PbArgvProvenanceProblem detail -> not ("bootstrap arguments occurrence count is " `Text.isPrefixOf` detail); _ -> True)
#else
  id
#endif

mutateInjectionProblems :: [PbProblem] -> [PbProblem]
mutateInjectionProblems =
#if defined(VALIDATION_PB_GRAMMAR_INJECTION_BOOTSTRAP_DEFINITION_REFUSAL_BYPASS_MUTANT)
  filter (/= PbInjectionSeamProblem "bootstrap function is absent or duplicated")
#elif defined(VALIDATION_PB_GRAMMAR_INJECTION_MAIN_DEFINITION_REFUSAL_BYPASS_MUTANT)
  filter (/= PbInjectionSeamProblem "main function is absent or duplicated")
#elif defined(VALIDATION_PB_GRAMMAR_INJECTION_BOOTSTRAP_SIGNATURE_REFUSAL_BYPASS_MUTANT)
  filter (/= PbInjectionSeamProblem "bootstrap signature must be exactly (adapter, arguments)")
#elif defined(VALIDATION_PB_GRAMMAR_INJECTION_MAIN_SIGNATURE_REFUSAL_BYPASS_MUTANT)
  filter (/= PbInjectionSeamProblem "main signature must be empty")
#elif defined(VALIDATION_PB_GRAMMAR_INJECTION_MAIN_BODY_REFUSAL_BYPASS_MUTANT)
  filter (/= PbInjectionSeamProblem "main alone must construct BootstrapAdapter and call bootstrap(adapter, sys.argv[1:])")
#elif defined(VALIDATION_PB_GRAMMAR_INJECTION_CONSTRUCTION_SCOPE_REFUSAL_BYPASS_MUTANT)
  filter (/= PbInjectionSeamProblem "the sole concrete adapter construction must occur in main")
#elif defined(VALIDATION_PB_GRAMMAR_INJECTION_MAIN_GUARD_REFUSAL_BYPASS_MUTANT)
  filter (/= PbInjectionSeamProblem "module must end in exact if __name__ == \"__main__\": main() guard")
#elif defined(VALIDATION_PB_GRAMMAR_INJECTION_MAIN_CALL_REFUSAL_BYPASS_MUTANT)
  filter (/= PbInjectionSeamProblem "main must be called exactly once by the module guard")
#else
  id
#endif

mutateEnsureProblems :: [PbProblem] -> [PbProblem]
mutateEnsureProblems =
#if defined(VALIDATION_PB_GRAMMAR_ENSURE_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbGhcupEnsureProblem "BootstrapAdapter.ensure_ghcup is absent")
#elif defined(VALIDATION_PB_GRAMMAR_ENSURE_BODY_REFUSAL_BYPASS_MUTANT)
  filter (/= PbGhcupEnsureProblem "ensure_ghcup must return a matching existing artifact, fail closed on mismatch, and verify absence acquisition before write")
#else
  id
#endif

mutateEnvironmentProblems :: [PbProblem] -> [PbProblem]
mutateEnvironmentProblems =
#if defined(VALIDATION_PB_GRAMMAR_ENVIRONMENT_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbClosedEnvironmentProblem "BootstrapAdapter.environment is absent")
#elif defined(VALIDATION_PB_GRAMMAR_ENVIRONMENT_RUN_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbClosedEnvironmentProblem "BootstrapAdapter.run is absent")
#elif defined(VALIDATION_PB_GRAMMAR_ENVIRONMENT_CAPTURE_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbClosedEnvironmentProblem "BootstrapAdapter.capture is absent")
#elif defined(VALIDATION_PB_GRAMMAR_ENVIRONMENT_BODY_REFUSAL_BYPASS_MUTANT)
  filter (/= PbClosedEnvironmentProblem "environment must start empty and expose only exact contained home/cache/temp/toolchain values")
#elif defined(VALIDATION_PB_GRAMMAR_ENVIRONMENT_RUN_BODY_REFUSAL_BYPASS_MUTANT)
  filter (/= PbClosedEnvironmentProblem "run must invoke subprocess.run with the injected argv/environment, shell=False, and no ambient lookup")
#elif defined(VALIDATION_PB_GRAMMAR_ENVIRONMENT_CAPTURE_BODY_REFUSAL_BYPASS_MUTANT)
  filter (/= PbClosedEnvironmentProblem "capture must invoke exact shell=False subprocess.run and return only stdout")
#else
  id
#endif

mutateExecutableProblems :: [PbProblem] -> [PbProblem]
mutateExecutableProblems =
#if defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_BOOTSTRAP_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "bootstrap function is absent")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_REPOSITORY_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "BootstrapAdapter.repository_root is absent")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_ASSIGNMENT_COUNT_REFUSAL_BYPASS_MUTANT)
  filter (\case PbToolchainExecutableProblem detail -> not (" assignment count is " `Text.isInfixOf` detail); _ -> True)
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_ROOT_PROVENANCE_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "repository root must come only from BootstrapAdapter.repository_root")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_REPOSITORY_SHAPE_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "repository root must be the absolute source-relative Path(__file__).resolve().parents[1]")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_PLATFORM_PROVENANCE_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "platform observation must come only through the injected adapter")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_ARTIFACT_PROVENANCE_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "platform artifact must come from the pure selector fed by adapter.platform()")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_ROOT_PATH_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "toolchain root is not the closed adapter path below the absolute repository root")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_GHCUP_TARGET_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "ghcup target is not rooted in the contained toolchain with the adapter filename")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_GHCUP_RESULT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "ghcup executable must be the verified ensure result")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_ENVIRONMENT_PROVENANCE_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "child environment must be derived only from the contained toolchain")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_EXECUTABLE_PATHS_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "GHC/Cabal executables are not exact contained versioned paths")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_BUILDDIR_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "Cabal build directory must be below the exact adapter toolchain root")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_STORE_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "Cabal store must be below the exact adapter toolchain root")
#elif defined(VALIDATION_PB_GRAMMAR_TOOLCHAIN_CHILD_CALLS_REFUSAL_BYPASS_MUTANT)
  filter (/= PbToolchainExecutableProblem "the four contained child calls, methods, and argv lists are not structurally exact or an additional child call is present")
#else
  id
#endif

mutatePlatformProblems :: [PbProblem] -> [PbProblem]
mutatePlatformProblems =
#if defined(VALIDATION_PB_GRAMMAR_PLATFORM_SELECTOR_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPlatformProofProblem "select_artifact is absent or duplicated")
#elif defined(VALIDATION_PB_GRAMMAR_PLATFORM_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPlatformProofProblem "BootstrapAdapter.platform is absent")
#elif defined(VALIDATION_PB_GRAMMAR_PLATFORM_OBSERVATION_BODY_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPlatformProofProblem "concrete platform observation must return only platform.system() and platform.machine()")
#elif defined(VALIDATION_PB_GRAMMAR_PLATFORM_TERMINAL_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPlatformProofProblem "pure platform selector must end in the exact unsupported-platform raise")
#elif defined(VALIDATION_PB_GRAMMAR_PLATFORM_BRANCH_COUNT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPlatformProofProblem "pure platform selector must contain exactly four branches")
#elif defined(VALIDATION_PB_GRAMMAR_PLATFORM_BRANCH_SHAPE_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPlatformProofProblem "platform branch is not an exact pure literal return")
#elif defined(VALIDATION_PB_GRAMMAR_PLATFORM_CONDITION_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPlatformProofProblem "platform branch condition is not exact pure system/machine equality")
#elif defined(VALIDATION_PB_GRAMMAR_PLATFORM_ARTIFACT_SET_REFUSAL_BYPASS_MUTANT)
  filter (/= PbPlatformProofProblem "platform adapter URL/SHA/system/machine/executable set is not exact")
#else
  id
#endif

mutateTerminalProblems :: [PbProblem] -> [PbProblem]
mutateTerminalProblems =
#if defined(VALIDATION_PB_GRAMMAR_CONTROL_BOOTSTRAP_END_REFUSAL_BYPASS_MUTANT)
  filter (/= PbHandoffControlFlowProblem "bootstrap must end with exact adapter.handoff(binary, [binary] + arguments)")
#elif defined(VALIDATION_PB_GRAMMAR_CONTROL_MAIN_END_REFUSAL_BYPASS_MUTANT)
  filter (/= PbHandoffControlFlowProblem "main must end with exact bootstrap(adapter, sys.argv[1:])")
#elif defined(VALIDATION_PB_GRAMMAR_CONTROL_HANDOFF_BODY_REFUSAL_BYPASS_MUTANT)
  filter (/= PbHandoffControlFlowProblem "handoff must contain exactly one final os.execv request")
#elif defined(VALIDATION_PB_GRAMMAR_CONTROL_BOOTSTRAP_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbHandoffControlFlowProblem "bootstrap function is absent")
#elif defined(VALIDATION_PB_GRAMMAR_CONTROL_MAIN_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbHandoffControlFlowProblem "main function is absent")
#elif defined(VALIDATION_PB_GRAMMAR_CONTROL_HANDOFF_ABSENT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbHandoffControlFlowProblem "BootstrapAdapter.handoff is absent")
#elif defined(VALIDATION_PB_GRAMMAR_CONTROL_HANDOFF_COUNT_REFUSAL_BYPASS_MUTANT)
  filter (/= PbHandoffControlFlowProblem "bootstrap must contain exactly one handoff request and it must be the final reachable statement")
#elif defined(VALIDATION_PB_GRAMMAR_CONTROL_BOOTSTRAP_TERMINATION_REFUSAL_BYPASS_MUTANT)
  filter (/= PbHandoffControlFlowProblem "bootstrap may not return or raise before its final handoff request")
#elif defined(VALIDATION_PB_GRAMMAR_CONTROL_HANDOFF_REACHABILITY_REFUSAL_BYPASS_MUTANT)
  filter (/= PbHandoffControlFlowProblem "bootstrap handoff request is absent, duplicated, or unreachable")
#elif defined(VALIDATION_PB_GRAMMAR_CONTROL_MODULE_TERMINATION_REFUSAL_BYPASS_MUTANT)
  filter (/= PbHandoffControlFlowProblem "module body may not return or raise before the exact main guard")
#elif defined(VALIDATION_PB_GRAMMAR_CONTROL_MODULE_SAFETY_REFUSAL_BYPASS_MUTANT)
  filter (/= PbHandoffControlFlowProblem "module body before the exact main guard may contain only direct imports, literal constants, and the closed definitions")
#elif defined(VALIDATION_PB_GRAMMAR_CONTROL_UNREACHABLE_NODE_REFUSAL_BYPASS_MUTANT)
  filter (\case PbHandoffControlFlowProblem detail -> not ("control-flow graph contains unreachable nodes in " `Text.isPrefixOf` detail); _ -> True)
#else
  id
#endif

dangerousCall :: (Text, PyExpr) -> [PbProblem]
dangerousCall (_, callExpression) =
  let syntax = renderCallee callExpression
      leaf = lastTextComponent syntax
   in [PbDynamicImport syntax | leaf == "__import__" || "importlib" `Text.isPrefixOf` syntax]
        <> [ PbReflectionForbidden syntax
           | leaf `elem` ["eval", "exec", "compile", "getattr", "setattr", "globals", "locals", "vars"]
           ]
        <> [ PbHookForbidden syntax
           | syntax `elem` ["atexit.register", "sys.setprofile", "sys.settrace"]
              || "sys.meta_path" `Text.isPrefixOf` syntax
           ]

collectImports :: BootstrapAst -> [ImportBinding]
collectImports (BootstrapAst statements) = mapMaybe importOf statements
 where
  importOf (PyImport qualified) =
    case qualified of
      [] -> Nothing
      first : _ -> Just (ImportBinding first (Text.intercalate "." qualified))
  importOf (PyFromImport qualified name) = Just (ImportBinding name (Text.intercalate "." (qualified <> [name])))
  importOf _ = Nothing

collectScopedImports :: BootstrapAst -> [(Text, Bool, ImportBinding)]
collectScopedImports (BootstrapAst statements) = concatMap (importsInStatement "<module>" True) statements
 where
  importsInStatement scope directModuleChild statement = case statement of
    PyImport qualified -> case qualified of
      [] -> []
      first : _ -> [(scope, directModuleChild, ImportBinding first (Text.intercalate "." qualified))]
    PyFromImport qualified name -> [(scope, directModuleChild, ImportBinding name (Text.intercalate "." (qualified <> [name])))]
    PyClass name body -> concatMap (importsInStatement name False) body
    PyFunction name _ body ->
      let nestedScope = if scope == "<module>" then name else scope <> "." <> name
       in concatMap (importsInStatement nestedScope False) body
    PyIf _ body -> concatMap (importsInStatement scope False) body
    _ -> []

validateBindings :: BootstrapAst -> [PbProblem]
validateBindings ast = duplicateProblems <> interpreterOwnedProblems <> shadowProblems
 where
  bindings = collectBindings ast
  grouped = Map.fromListWith (<>) [((bindingScope binding, bindingName binding), [binding]) | binding <- bindings]
  duplicateProblems =
    [ PbBindingConflict scope name
    | ((scope, name), found) <- Map.toAscList grouped
    , length found /= 1
    ]
  moduleNames = Set.fromList [bindingName binding | binding <- bindings, bindingScope binding == "<module>"]
  protectedNames = moduleNames <> Set.fromList ["RuntimeError", "str"]
  interpreterOwnedNames =
    Set.fromList
      [ "__file__"
      , "__name__"
      , "__package__"
      , "__spec__"
      , "__loader__"
      , "__builtins__"
      , "__cached__"
      , "__doc__"
      ]
  interpreterOwnedProblems =
    [ PbBindingConflict "<module>" (bindingName binding)
    | binding <- bindings
    , bindingScope binding == "<module>"
    , bindingName binding `Set.member` interpreterOwnedNames
    ]
  shadowProblems =
    [ PbBindingConflict (bindingScope binding) (bindingName binding)
    | binding <- bindings
    , bindingScope binding /= "<module>"
    , bindingScope binding /= "BootstrapAdapter"
    , bindingName binding `Set.member` protectedNames
    ]

validateAssignmentTargets :: BootstrapAst -> [PbProblem]
validateAssignmentTargets (BootstrapAst statements) = concatMap (inStatement "<module>") statements
 where
  exactEnvironmentKeys =
    Set.fromList
      [ "GHCUP_INSTALL_BASE_PREFIX"
      , "GHCUP_SKIP_UPDATE_CHECK"
      , "HOME"
      , "XDG_CACHE_HOME"
      , "TMPDIR"
      , "TEMP"
      , "TMP"
      ]
  inStatement scope statement = case statement of
    PyAssign (PyIndex (PyName "environment") (PyString key)) _
      | scope == "BootstrapAdapter.environment"
      , key `Set.member` exactEnvironmentKeys -> []
    PyAssign target@(PyIndex _ _) _ -> [PbMonkeypatchAssignment scope (renderExpressionSubject target)]
    PyClass name body -> concatMap (classAssignment name) body
    PyFunction name _ body ->
      let nestedScope = if scope == "<module>" then name else scope <> "." <> name
       in concatMap (inStatement nestedScope) body
    PyIf _ body -> concatMap (inStatement scope) body
    _ -> []
  classAssignment className member = case member of
    PyFunction name _ body -> concatMap (inStatement (className <> "." <> name)) body
    _ -> inStatement className member

renderExpressionSubject :: PyExpr -> Text
renderExpressionSubject expression = case expression of
  PyName name -> name
  PyAttribute base field -> renderExpressionSubject base <> "." <> field
  PyIndex base _ -> renderExpressionSubject base <> "[...]"
  _ -> "<dynamic-assignment>"

validateSignatures :: BootstrapAst -> [PbProblem]
validateSignatures ast =
  [ PbSignatureProblem "top-level functions/classes or their signatures are not exact"
  | topDefinitions ast /= expectedTopDefinitions || topClassNames ast /= ["BootstrapAdapter"]
  ]
    <> [ PbSignatureProblem "BootstrapAdapter method set or signatures are not exact"
       | classMethodSignatures "BootstrapAdapter" ast /= expectedMethods
       ]
    <> [ PbSignatureProblem "nested function/class definitions are forbidden"
       | containsNestedDefinition ast
       ]
 where
  expectedTopDefinitions =
    [ ("select_artifact", ["system", "machine"])
    , ("bootstrap", ["adapter", "arguments"])
    , ("main", [])
    ]
  expectedMethods =
    [ ("repository_root", ["self"])
    , ("platform", ["self"])
    , ("ensure_ghcup", ["self", "url", "digest", "target"])
    , ("environment", ["self", "toolchain"])
    , ("run", ["self", "root", "arguments", "environment"])
    , ("capture", ["self", "root", "arguments", "environment"])
    , ("handoff", ["self", "binary", "arguments"])
    ]

topDefinitions :: BootstrapAst -> [(Text, [Text])]
topDefinitions (BootstrapAst statements) =
  [(name, parameters) | PyFunction name parameters _ <- statements]

topClassNames :: BootstrapAst -> [Text]
topClassNames (BootstrapAst statements) = [name | PyClass name _ <- statements]

classMethodSignatures :: Text -> BootstrapAst -> [(Text, [Text])]
classMethodSignatures className (BootstrapAst statements) =
  case [body | PyClass found body <- statements, found == className] of
    [body] -> [(name, parameters) | PyFunction name parameters _ <- body]
    _ -> []

containsNestedDefinition :: BootstrapAst -> Bool
containsNestedDefinition (BootstrapAst statements) = any topContains statements
 where
  topContains statement = case statement of
    PyFunction _ _ body -> any nestedContains body
    PyClass _ body -> any classMemberContains body
    PyIf _ body -> any nestedContains body
    _ -> False
  classMemberContains (PyFunction _ _ body) = any nestedContains body
  classMemberContains _ = True
  nestedContains statement = case statement of
    PyFunction {} -> True
    PyClass {} -> True
    PyIf _ body -> any nestedContains body
    _ -> False

collectBindings :: BootstrapAst -> [Binding]
collectBindings (BootstrapAst statements) = concatMap (statementBindings "<module>") statements

statementBindings :: Text -> PyStmt -> [Binding]
statementBindings scope statement = case statement of
  PyImport qualified -> case qualified of
    [] -> []
    first : _ -> [Binding scope first (ImportedModuleBinding (Text.intercalate "." qualified))]
  PyFromImport qualified name -> [Binding scope name (ImportedNameBinding (Text.intercalate "." (qualified <> [name])))]
  PyAssign (PyName name) _ -> [Binding scope name (if scope == "<module>" then ConstantBinding else LocalValueBinding)]
  PyAssign _ _ -> []
  PyClass name body ->
    Binding scope name ClassBinding : concatMap (classMemberBindings name) body
  PyFunction name parameters body ->
    let functionScope = if scope == "<module>" then name else scope <> "." <> name
     in Binding scope name FunctionBinding
          : map (\parameter -> Binding functionScope parameter ParameterBinding) parameters
          <> concatMap (statementBindings functionScope) body
  PyIf _ body -> concatMap (statementBindings scope) body
  _ -> []
 where
  classMemberBindings className member = case member of
    PyFunction name parameters body ->
      let methodScope = className <> "." <> name
       in Binding className name FunctionBinding
            : map (\parameter -> Binding methodScope parameter ParameterBinding) parameters
            <> concatMap (statementBindings methodScope) body
    _ -> statementBindings className member

collectCalls :: BootstrapAst -> [(Text, PyExpr)]
collectCalls (BootstrapAst statements) = concatMap (callsInStatement "<module>") statements

callsInStatement :: Text -> PyStmt -> [(Text, PyExpr)]
callsInStatement scope statement = case statement of
  PyImport _ -> []
  PyFromImport _ _ -> []
  PyAssign left right -> callsInExpression scope left <> callsInExpression scope right
  PyClass name body -> concatMap (classCalls name) body
  PyFunction name _ body ->
    let functionScope = if scope == "<module>" then name else scope <> "." <> name
     in concatMap (callsInStatement functionScope) body
  PyIf condition body -> callsInExpression scope condition <> concatMap (callsInStatement scope) body
  PyReturn value -> callsInExpression scope value
  PyRaise value -> callsInExpression scope value
  PyExpression value -> callsInExpression scope value
 where
  classCalls className member = case member of
    PyFunction name _ body -> concatMap (callsInStatement (className <> "." <> name)) body
    _ -> callsInStatement className member

callsInExpression :: Text -> PyExpr -> [(Text, PyExpr)]
callsInExpression scope expression = case expression of
  PyCall callee arguments ->
    (scope, expression)
      : callsInExpression scope callee
      <> concatMap (callsInArgument scope) arguments
  PyAttribute base _ -> callsInExpression scope base
  PyIndex base index -> callsInExpression scope base <> callsInExpression scope index
  PySlice start end -> maybe [] (callsInExpression scope) start <> maybe [] (callsInExpression scope) end
  PyTuple values -> concatMap (callsInExpression scope) values
  PyList values -> concatMap (callsInExpression scope) values
  PyBinary _ left right -> callsInExpression scope left <> callsInExpression scope right
  _ -> []
 where
  callsInArgument caller (PyPositional value) = callsInExpression caller value
  callsInArgument caller (PyKeyword _ value) = callsInExpression caller value

resolveAllCalls :: BootstrapAst -> Either PbProblem [ResolvedCall]
resolveAllCalls ast = traverse resolveOne (collectCalls ast)
 where
  bindings = collectBindings ast
  resolveOne (scope, expression) =
    let syntax = renderCallee expression
     in case resolveTarget bindings scope syntax of
          Nothing -> Left (PbUnresolvedCall scope syntax)
          Just target -> Right (ResolvedCall scope syntax target)

resolveTarget :: [Binding] -> Text -> Text -> Maybe ResolvedTarget
resolveTarget bindings scope syntax
  | syntax == "BootstrapAdapter"
  , moduleHas "BootstrapAdapter" ClassBinding = Just ResolvedBootstrapConstructor
  | syntax `elem` ["RuntimeError", "str"]
  , visibleBinding syntax == Nothing = Just (ResolvedBuiltin syntax)
  | syntax `elem` ["bootstrap", "main", "select_artifact"]
  , moduleHas syntax FunctionBinding = Just (ResolvedBootstrapFunction syntax)
  | Just method <- Text.stripPrefix "self." syntax
  , method `elem` adapterMethods
  , visibleBinding "self" == Just ParameterBinding
  , classHasMethod method = Just (ResolvedAdapterMethod method)
  | Just method <- Text.stripPrefix "adapter." syntax
  , method `elem` adapterMethods
  , scope == "bootstrap"
  , visibleBinding "adapter" == Just ParameterBinding
  , classHasMethod method = Just (ResolvedAdapterMethod method)
  | Just importedName <- Map.lookup syntax standardLibraryCalls
  , Just () <- visibleImported importedName = Just (ResolvedStandardLibrary syntax)
  | syntax `elem` valueMethodCalls
  , Just root <- valueRoot syntax
  , visibleBinding root `elem` [Just ParameterBinding, Just LocalValueBinding] = Just (ResolvedValueMethod syntax)
  | otherwise = Nothing
 where
  adapterMethods =
    [ "capture"
    , "ensure_ghcup"
    , "environment"
    , "handoff"
    , "platform"
    , "repository_root"
    , "run"
    ]
  standardLibraryCalls =
    Map.fromList
      [ ("Path", "Path")
      , ("Path().resolve", "Path")
      , ("hashlib.sha256", "hashlib")
      , ("os.environ.copy", "os")
      , ("os.execv", "os")
      , ("platform.machine", "platform")
      , ("platform.system", "platform")
      , ("subprocess.run", "subprocess")
      , ("urllib.request.urlopen", "urllib")
      ]
  valueMethodCalls =
    [ "binary_bytes.decode"
    , "binary_text.strip"
    , "cache.mkdir"
    , "existing_hash_value.hexdigest"
    , "hash_value.hexdigest"
    , "home.mkdir"
    , "response.read"
    , "target.chmod"
    , "target.is_file"
    , "target.parent.mkdir"
    , "target.read_bytes"
    , "target.write_bytes"
    , "temporary.mkdir"
    ]
  visibleBinding name =
    case [bindingKind binding | binding <- bindings, bindingScope binding == scope, bindingName binding == name] of
      [kind] -> Just kind
      [] -> case [bindingKind binding | binding <- bindings, bindingScope binding == "<module>", bindingName binding == name] of
        [kind] -> Just kind
        _ -> Nothing
      _ -> Nothing
  moduleHas name kind = visibleModuleKind name == Just kind
  visibleModuleKind name = case [bindingKind binding | binding <- bindings, bindingScope binding == "<module>", bindingName binding == name] of
    [kind] -> Just kind
    _ -> Nothing
  visibleImported name = case visibleBinding name of
    Just (ImportedModuleBinding _) -> Just ()
    Just (ImportedNameBinding _) -> Just ()
    _ -> Nothing
  classHasMethod name =
    case [binding | binding <- bindings, bindingScope binding == "BootstrapAdapter", bindingName binding == name, bindingKind binding == FunctionBinding] of
      [_] -> True
      _ -> False
  valueRoot value = case Text.splitOn "." value of
    root : _ -> Just root
    [] -> Nothing

renderCallee :: PyExpr -> Text
renderCallee (PyCall callee _) = renderCalleeBase callee
renderCallee other = renderCalleeBase other

renderCalleeBase :: PyExpr -> Text
renderCalleeBase (PyName name) = name
renderCalleeBase (PyAttribute base field) = renderBase base <> "." <> field
renderCalleeBase _ = "<dynamic-callee>"

renderBase :: PyExpr -> Text
renderBase (PyName name) = name
renderBase (PyAttribute base field) = renderBase base <> "." <> field
renderBase (PyCall callee _) = renderCalleeBase callee <> "()"
renderBase _ = "<dynamic-base>"

lastTextComponent :: Text -> Text
lastTextComponent value = case reverse (Text.splitOn "." value) of
  [] -> value
  final : _ -> final

effectKind :: Text -> Maybe PotentialEffectKind
effectKind syntax = Map.lookup syntax effectKinds
 where
  effectKinds =
    Map.fromList
      [ ("Path().resolve", RepositoryObservationEffect)
      , ("platform.system", PlatformObservationEffect)
      , ("platform.machine", PlatformObservationEffect)
      , ("home.mkdir", DirectoryCreateEffect)
      , ("cache.mkdir", DirectoryCreateEffect)
      , ("temporary.mkdir", DirectoryCreateEffect)
      , ("target.parent.mkdir", DirectoryCreateEffect)
      , ("target.is_file", FileObservationEffect)
      , ("target.read_bytes", FileObservationEffect)
      , ("urllib.request.urlopen", NetworkAcquireEffect)
      , ("response.read", NetworkAcquireEffect)
      , ("target.write_bytes", FileWriteEffect)
      , ("target.chmod", PermissionChangeEffect)
      , ("os.environ.copy", EnvironmentObservationEffect)
      , ("subprocess.run", ChildProcessEffect)
      , ("os.execv", ProcessReplacementEffect)
      ]

collectPotentialEffects :: BootstrapAst -> [ResolvedCall] -> [PotentialEffect]
collectPotentialEffects ast resolved = startupEffects <> applicationEffects
 where
  startupEffects =
    [ PotentialEffect InterpreterImportStartup ImportStartupEffect (importQualifiedName imported) InterpreterStartupRoute
    | imported <- collectImports ast
    ]
  -- 'resolveAllCalls' walks every expression position, including assignment
  -- right-hand sides, returns, callees, and arguments.  Projecting effects from
  -- that complete list prevents an adapter invocation from disappearing merely
  -- because its result is assigned rather than used as an expression statement.
  applicationEffects = concatMap effectsOfResolvedCall resolved
  effectsOfResolvedCall call =
    [ PotentialEffect ApplicationRequested kind (resolvedSyntax call) route
    | kind <- resolvedPotentialEffectKinds call
    ]
   where
    route = case resolvedTarget call of
      ResolvedAdapterMethod method -> BootstrapAdapterInvocationRoute (resolvedCaller call) method
      _ -> BootstrapAdapterRoute (resolvedCaller call)

resolvedPotentialEffectKinds :: ResolvedCall -> [PotentialEffectKind]
resolvedPotentialEffectKinds call =
  case resolvedTarget call of
    ResolvedAdapterMethod method -> adapterInvocationPotentialEffects method
    _ -> maybe [] pure (effectKind (resolvedSyntax call))

adapterInvocationPotentialEffects :: Text -> [PotentialEffectKind]
#if defined(VALIDATION_PB_GRAMMAR_ADAPTER_EFFECT_OMISSION_MUTANT)
adapterInvocationPotentialEffects _ = []
#else
adapterInvocationPotentialEffects method = case method of
  "repository_root" -> [RepositoryObservationEffect]
  "platform" -> [PlatformObservationEffect]
  "ensure_ghcup" ->
    [ FileObservationEffect
    , DirectoryCreateEffect
    , NetworkAcquireEffect
    , FileWriteEffect
    , PermissionChangeEffect
    ]
  "environment" -> [DirectoryCreateEffect]
  "run" -> [ChildProcessEffect]
  "capture" -> [ChildProcessEffect]
  "handoff" -> [ProcessReplacementEffect]
  _ -> []
#endif

proveArgvForBuild :: BootstrapAst -> Either PbProblem ArgvProvenance
proveArgvForBuild = proveArgv

proveArgv :: BootstrapAst -> Either PbProblem ArgvProvenance
proveArgv ast = do
  mainBody <- maybe (Left (PbArgvProvenanceProblem "main function is absent")) Right (functionBody "main" ast)
  bootstrapBody <- maybe (Left (PbArgvProvenanceProblem "bootstrap function is absent")) Right (functionBody "bootstrap" ast)
  unless (mainBody == exactMainBody)
    (Left (PbArgvProvenanceProblem "main must pass sys.argv[1:] unchanged to the injected bootstrap seam"))
  unless (endsInInjectedHandoff bootstrapBody)
    (Left (PbArgvProvenanceProblem "bootstrap must hand off [binary] + arguments exactly"))
  let argvUses = expressionOccurrences isSysArgv ast
  when (argvUses /= 1) (Left (PbArgvProvenanceProblem ("sys.argv occurrence count is " <> Text.pack (show argvUses))))
  let seamArgumentUses = sum (map (statementOccurrences (== PyName "arguments")) bootstrapBody)
  when (seamArgumentUses /= 1) (Left (PbArgvProvenanceProblem ("bootstrap arguments occurrence count is " <> Text.pack (show seamArgumentUses))))
  pure (OpaqueUserArgvTail "sys.argv[1:]" "arguments" "binary")
 where
  exactMainBody =
    [ PyAssign (PyName "adapter") (PyCall (PyName "BootstrapAdapter") [])
    , PyExpression
        ( PyCall
            (PyName "bootstrap")
            [ PyPositional (PyName "adapter")
            , PyPositional (PyIndex (PyAttribute (PyName "sys") "argv") (PySlice (Just (PyInteger 1)) Nothing))
            ]
        )
    ]
  endsInInjectedHandoff body = case reverse body of
    PyExpression
      ( PyCall
          (PyAttribute (PyName "adapter") "handoff")
          [ PyPositional (PyName "binary")
          , PyPositional (PyBinary PyAdd (PyList [PyName "binary"]) (PyName "arguments"))
          ]
        ) : _ -> True
    _ -> False
  isSysArgv (PyAttribute (PyName "sys") "argv") = True
  isSysArgv _ = False

proveInjectionSeamForBuild :: BootstrapAst -> Either PbProblem InjectionSeamProof
proveInjectionSeamForBuild = proveInjectionSeam

proveInjectionSeam :: BootstrapAst -> Either PbProblem InjectionSeamProof
proveInjectionSeam ast@(BootstrapAst statements) = do
  (bootstrapParameters, _) <- maybe (Left (PbInjectionSeamProblem "bootstrap function is absent or duplicated")) Right (functionDefinition "bootstrap" ast)
  (mainParameters, mainBody) <- maybe (Left (PbInjectionSeamProblem "main function is absent or duplicated")) Right (functionDefinition "main" ast)
  unless (bootstrapParameters == ["adapter", "arguments"])
    (Left (PbInjectionSeamProblem "bootstrap signature must be exactly (adapter, arguments)"))
  unless (null mainParameters)
    (Left (PbInjectionSeamProblem "main signature must be empty"))
  unless (mainBody == exactMainBody)
    (Left (PbInjectionSeamProblem "main alone must construct BootstrapAdapter and call bootstrap(adapter, sys.argv[1:])"))
  let constructors =
        [ scope
        | (scope, PyCall (PyName "BootstrapAdapter") []) <- collectCalls ast
        ]
  unless (constructors == ["main"])
    (Left (PbInjectionSeamProblem "the sole concrete adapter construction must occur in main"))
  case reverse statements of
    PyIf
      (PyBinary PyEqual (PyName "__name__") (PyString "__main__"))
      [PyExpression (PyCall (PyName "main") [])] : _ -> pure ()
    _ -> Left (PbInjectionSeamProblem "module must end in exact if __name__ == \"__main__\": main() guard")
  let mainCalls =
        [ scope
        | (scope, PyCall (PyName "main") []) <- collectCalls ast
        ]
  unless (mainCalls == ["<module>"])
    (Left (PbInjectionSeamProblem "main must be called exactly once by the module guard"))
  pure
    InjectionSeamProof
      { seamFunctionName = "bootstrap"
      , seamAdapterParameter = "adapter"
      , seamArgumentsParameter = "arguments"
      , seamConcreteConstructionScope = "main"
      , seamMainGuardExpression = "if __name__ == \"__main__\": main()"
      }
 where
  exactMainBody =
    [ PyAssign (PyName "adapter") (PyCall (PyName "BootstrapAdapter") [])
    , PyExpression
        ( PyCall
            (PyName "bootstrap")
            [ PyPositional (PyName "adapter")
            , PyPositional (PyIndex (PyAttribute (PyName "sys") "argv") (PySlice (Just (PyInteger 1)) Nothing))
            ]
        )
    ]

proveBinary :: BootstrapAst -> Either PbProblem BinaryProvenance
proveBinary ast = do
  bootstrapBody <- maybe (Left (PbBinaryProvenanceProblem "bootstrap function is absent")) Right (functionBody "bootstrap" ast)
  ghcupVersion <- exactModuleString "GHCUP_VERSION" ast
  ghcVersion <- exactModuleString "GHC_VERSION" ast
  cabalVersion <- exactModuleString "CABAL_VERSION" ast
  buildTarget <- exactModuleString "BUILD_TARGET" ast
  unless (ghcupVersion == "0.2.6.2") (Left (PbPinProblem "GHCUP_VERSION must be 0.2.6.2"))
  unless (ghcVersion == "9.12.4") (Left (PbPinProblem "GHC_VERSION must be 9.12.4"))
  unless (cabalVersion == "3.16.1.0") (Left (PbPinProblem "CABAL_VERSION must be 3.16.1.0"))
  unless (buildTarget == "exe:amoebius") (Left (PbPinProblem "BUILD_TARGET must be exe:amoebius"))
  binaryBytes <- assignedExpression "binary_bytes" bootstrapBody
  binaryText <- assignedExpression "binary_text" bootstrapBody
  binary <- assignedExpression "binary" bootstrapBody
  unless (isCabalLocator binaryBytes) (Left (PbBinaryProvenanceProblem "binary bytes do not come from contained cabal list-bin"))
  unless (binaryText == PyCall (PyAttribute (PyName "binary_bytes") "decode") [PyPositional (PyString "utf-8")])
    (Left (PbBinaryProvenanceProblem "binary locator is not exact UTF-8"))
  unless (binary == PyCall (PyAttribute (PyName "binary_text") "strip") [])
    (Left (PbBinaryProvenanceProblem "binary path is not derived only from list-bin output"))
  let buildPositions = [position | (position, PyExpression expression) <- zip [0 :: Int ..] bootstrapBody, isCabalBuild expression]
      locatorPositions = [position | (position, PyAssign (PyName "binary_bytes") _) <- zip [0 :: Int ..] bootstrapBody]
  case (buildPositions, locatorPositions) of
    ([buildPosition], [locatorPosition])
      | buildPosition < locatorPosition -> pure ()
    _ -> Left (PbBinaryProvenanceProblem "one exact build must precede one exact list-bin")
  pure
    BinaryProvenance
      { binaryBuildTarget = "exe:amoebius"
      , binaryGhcupVersion = "0.2.6.2"
      , binaryCompilerVersion = "9.12.4"
      , binaryCabalVersion = "3.16.1.0"
      , binaryLocator = "contained cabal list-bin"
      , binaryHandoff = "os.execv through BootstrapAdapter.handoff"
      }
 where
  isCabalBuild (PyCall (PyAttribute (PyName "adapter") "run") arguments) =
    any (argumentContainsString "build") arguments
      && any (argumentContainsName "BUILD_TARGET") arguments
      && any (argumentContainsName "ghc") arguments
  isCabalBuild _ = False
  isCabalLocator (PyCall (PyAttribute (PyName "adapter") "capture") arguments) =
    any (argumentContainsString "list-bin") arguments
      && any (argumentContainsName "BUILD_TARGET") arguments
      && any (argumentContainsName "ghc") arguments
  isCabalLocator _ = False

exactModuleString :: Text -> BootstrapAst -> Either PbProblem Text
exactModuleString name (BootstrapAst statements) =
  case [value | PyAssign (PyName found) (PyString value) <- statements, found == name] of
    [value] -> Right value
    values -> Left (PbPinProblem (name <> " exact string assignment count is " <> Text.pack (show (length values))))

proveGhcupEnsure :: BootstrapAst -> Either PbProblem GhcupEnsureProof
proveGhcupEnsure ast = do
  body <- maybe (Left (PbGhcupEnsureProblem "BootstrapAdapter.ensure_ghcup is absent")) Right (methodBody "BootstrapAdapter" "ensure_ghcup" ast)
  unless (exactEnsureBody body) (Left (PbGhcupEnsureProblem "ensure_ghcup must return a matching existing artifact, fail closed on mismatch, and verify absence acquisition before write"))
  pure
    GhcupEnsureProof
      { ensureMatchingExistingReturnsBeforeMutation = True
      , ensureMismatchedExistingFailsClosed = True
      , ensureAbsentArtifactVerifiedBeforeWrite = True
      }
 where
  exactEnsureBody
    [ PyIf
        (PyCall (PyAttribute (PyName "target") "is_file") [])
        [ PyAssign (PyName "existing_payload") (PyCall (PyAttribute (PyName "target") "read_bytes") [])
          , PyAssign (PyName "existing_hash_value") (PyCall (PyAttribute (PyName "hashlib") "sha256") [PyPositional (PyName "existing_payload")])
          , PyAssign (PyName "existing_digest") (PyCall (PyAttribute (PyName "existing_hash_value") "hexdigest") [])
          , PyIf (PyBinary PyEqual (PyName "existing_digest") (PyName "digest")) [PyReturn (PyName "target")]
          , PyRaise (PyCall (PyName "RuntimeError") [PyPositional (PyString "ghcup-existing-sha256")])
          ]
      , PyExpression
          ( PyCall
              (PyAttribute (PyAttribute (PyName "target") "parent") "mkdir")
              [PyKeyword "parents" (PyBoolean True), PyKeyword "exist_ok" (PyBoolean True)]
            )
      , PyAssign (PyName "response") (PyCall (PyAttribute (PyAttribute (PyName "urllib") "request") "urlopen") [PyPositional (PyName "url")])
      , PyAssign (PyName "payload") (PyCall (PyAttribute (PyName "response") "read") [])
      , PyAssign (PyName "hash_value") (PyCall (PyAttribute (PyName "hashlib") "sha256") [PyPositional (PyName "payload")])
      , PyAssign (PyName "observed") (PyCall (PyAttribute (PyName "hash_value") "hexdigest") [])
      , PyIf
          (PyBinary PyNotEqual (PyName "observed") (PyName "digest"))
          [PyRaise (PyCall (PyName "RuntimeError") [PyPositional (PyString "ghcup-sha256")])]
      , PyExpression (PyCall (PyAttribute (PyName "target") "write_bytes") [PyPositional (PyName "payload")])
      , PyExpression (PyCall (PyAttribute (PyName "target") "chmod") [PyPositional (PyInteger 448)])
      , PyReturn (PyName "target")
      ] = True
  exactEnsureBody _ = False

proveClosedEnvironment :: BootstrapAst -> Either PbProblem ClosedEnvironmentProof
proveClosedEnvironment ast = do
  environmentBody <- maybe (Left (PbClosedEnvironmentProblem "BootstrapAdapter.environment is absent")) Right (methodBody "BootstrapAdapter" "environment" ast)
  runBody <- maybe (Left (PbClosedEnvironmentProblem "BootstrapAdapter.run is absent")) Right (methodBody "BootstrapAdapter" "run" ast)
  captureBody <- maybe (Left (PbClosedEnvironmentProblem "BootstrapAdapter.capture is absent")) Right (methodBody "BootstrapAdapter" "capture" ast)
  unless (environmentBody == exactEnvironmentBody)
    (Left (PbClosedEnvironmentProblem "environment must start empty and expose only exact contained home/cache/temp/toolchain values"))
  unless (runBody == [PyExpression exactRunCall])
    (Left (PbClosedEnvironmentProblem "run must invoke subprocess.run with the injected argv/environment, shell=False, and no ambient lookup"))
  unless (captureBody == [PyReturn (PyAttribute exactCaptureCall "stdout")])
    (Left (PbClosedEnvironmentProblem "capture must invoke exact shell=False subprocess.run and return only stdout"))
  pure
    ClosedEnvironmentProof
      { environmentStartsEmpty = True
      , environmentExactKeys = exactKeys
      , environmentContainedPathKeys = ["GHCUP_INSTALL_BASE_PREFIX", "HOME", "XDG_CACHE_HOME", "TMPDIR", "TEMP", "TMP"]
      , childEnvironmentMappingExact = True
      }
 where
  mkdir name =
    PyExpression
      ( PyCall
          (PyAttribute (PyName name) "mkdir")
          [PyKeyword "parents" (PyBoolean True), PyKeyword "exist_ok" (PyBoolean True)]
      )
  indexed key = PyIndex (PyName "environment") (PyString key)
  stringOf name = PyCall (PyName "str") [PyPositional (PyName name)]
  exactEnvironmentBody =
    [ PyAssign (PyName "home") (PyBinary PyPathJoin (PyName "toolchain") (PyString "home"))
    , PyAssign (PyName "cache") (PyBinary PyPathJoin (PyName "toolchain") (PyString "cache"))
    , PyAssign (PyName "temporary") (PyBinary PyPathJoin (PyName "toolchain") (PyString "tmp"))
    , mkdir "home"
    , mkdir "cache"
    , mkdir "temporary"
    , PyAssign (PyName "environment") PyEmptyDictionary
    , PyAssign (indexed "GHCUP_INSTALL_BASE_PREFIX") (stringOf "toolchain")
    , PyAssign (indexed "GHCUP_SKIP_UPDATE_CHECK") (PyString "yes")
    , PyAssign (indexed "HOME") (stringOf "home")
    , PyAssign (indexed "XDG_CACHE_HOME") (stringOf "cache")
    , PyAssign (indexed "TMPDIR") (stringOf "temporary")
    , PyAssign (indexed "TEMP") (stringOf "temporary")
    , PyAssign (indexed "TMP") (stringOf "temporary")
    , PyReturn (PyName "environment")
    ]
  exactKeys =
    [ "GHCUP_INSTALL_BASE_PREFIX"
    , "GHCUP_SKIP_UPDATE_CHECK"
    , "HOME"
    , "XDG_CACHE_HOME"
    , "TMPDIR"
    , "TEMP"
    , "TMP"
    ]
  subprocessCall extra =
    PyCall
      (PyAttribute (PyName "subprocess") "run")
      ( [ PyPositional (PyName "arguments")
        , PyKeyword "cwd" (PyName "root")
        , PyKeyword "env" (PyName "environment")
        , PyKeyword "check" (PyBoolean True)
        , PyKeyword "shell" (PyBoolean False)
        ]
          <> extra
      )
  exactRunCall = subprocessCall []
  exactCaptureCall = subprocessCall [PyKeyword "stdout" (PyAttribute (PyName "subprocess") "PIPE")]

proveToolchainExecutables :: BootstrapAst -> Either PbProblem ToolchainExecutableProof
proveToolchainExecutables ast = do
  body <- maybe (Left (PbToolchainExecutableProblem "bootstrap function is absent")) Right (functionBody "bootstrap" ast)
  repositoryRootBody <- maybe (Left (PbToolchainExecutableProblem "BootstrapAdapter.repository_root is absent")) Right (methodBody "BootstrapAdapter" "repository_root" ast)
  root <- assignedExpressionForTool "root" body
  observedPlatform <- assignedExpressionForTool "observed_platform" body
  artifact <- assignedExpressionForTool "artifact" body
  toolchain <- assignedExpressionForTool "toolchain" body
  ghcupTarget <- assignedExpressionForTool "ghcup_target" body
  ghcup <- assignedExpressionForTool "ghcup" body
  environment <- assignedExpressionForTool "environment" body
  ghc <- assignedExpressionForTool "ghc" body
  cabal <- assignedExpressionForTool "cabal" body
  builddir <- assignedExpressionForTool "builddir" body
  store <- assignedExpressionForTool "store" body
  unless (root == PyCall (PyAttribute (PyName "adapter") "repository_root") [])
    (Left (PbToolchainExecutableProblem "repository root must come only from BootstrapAdapter.repository_root"))
  unless (isExactRepositoryRoot repositoryRootBody)
    (Left (PbToolchainExecutableProblem "repository root must be the absolute source-relative Path(__file__).resolve().parents[1]"))
  unless (observedPlatform == PyCall (PyAttribute (PyName "adapter") "platform") [])
    (Left (PbToolchainExecutableProblem "platform observation must come only through the injected adapter"))
  unless
    ( artifact
        == PyCall
          (PyName "select_artifact")
          [ PyPositional (PyIndex (PyName "observed_platform") (PyInteger 0))
          , PyPositional (PyIndex (PyName "observed_platform") (PyInteger 1))
          ]
    )
    (Left (PbToolchainExecutableProblem "platform artifact must come from the pure selector fed by adapter.platform()"))
  unless (toolchain == pathFrom (PyName "root") [PyString ".build", PyString "toolchain", artifactIndex 2])
    (Left (PbToolchainExecutableProblem "toolchain root is not the closed adapter path below the absolute repository root"))
  unless (ghcupTarget == pathFrom (PyName "toolchain") [PyString "bootstrap", artifactIndex 3])
    (Left (PbToolchainExecutableProblem "ghcup target is not rooted in the contained toolchain with the adapter filename"))
  unless
    ( ghcup
        == PyCall
          (PyAttribute (PyName "adapter") "ensure_ghcup")
          [ PyPositional (PyIndex (PyName "artifact") (PyInteger 0))
          , PyPositional (PyIndex (PyName "artifact") (PyInteger 1))
          , PyPositional (PyName "ghcup_target")
          ]
    )
    (Left (PbToolchainExecutableProblem "ghcup executable must be the verified ensure result"))
  unless (environment == PyCall (PyAttribute (PyName "adapter") "environment") [PyPositional (PyName "toolchain")])
    (Left (PbToolchainExecutableProblem "child environment must be derived only from the contained toolchain"))
  unless (ghc == expectedGhcPath && cabal == expectedCabalPath)
    (Left (PbToolchainExecutableProblem "GHC/Cabal executables are not exact contained versioned paths"))
  unless (builddir == pathFrom (PyName "toolchain") [PyString "dist-newstyle"])
    (Left (PbToolchainExecutableProblem "Cabal build directory must be below the exact adapter toolchain root"))
  unless (store == pathFrom (PyName "toolchain") [PyString "cabal-store"])
    (Left (PbToolchainExecutableProblem "Cabal store must be below the exact adapter toolchain root"))
  let allChildInvocations =
        [ (method, arguments)
        | (scope, PyCall (PyAttribute (PyName "adapter") method) arguments) <- collectCalls ast
        , scope == "bootstrap"
        , method `elem` ["run", "capture"]
        ]
#if defined(VALIDATION_PB_GRAMMAR_CHILD_CALL_OMISSION_MUTANT)
      childInvocations = take 3 allChildInvocations
#else
      childInvocations = allChildInvocations
#endif
  unless
    ( childInvocations
        == [ expectedInvocation "run" (expectedGhcupInstall "ghc" "GHC_VERSION")
           , expectedInvocation "run" (expectedGhcupInstall "cabal" "CABAL_VERSION")
           , expectedInvocation "run" (expectedCabalCommand "build")
           , expectedInvocation "capture" (expectedCabalCommand "list-bin")
           ]
    )
    (Left (PbToolchainExecutableProblem "the four contained child calls, methods, and argv lists are not structurally exact or an additional child call is present"))
  pure
    ToolchainExecutableProof
      { toolchainRootProvenance = "Path(__file__).resolve().parents[1]/.build/toolchain/<closed-adapter>"
      , ghcupExecutableProvenance = "verified adapter artifact under contained bootstrap root"
      , ghcExecutableProvenance = "contained ghcup GHC 9.12.4 path with adapter suffix"
      , cabalExecutableProvenance = "contained ghcup Cabal 3.16.1.0 path with adapter suffix"
      , childArgvZeroProvenance = "each subprocess argv[0] is str(ghcup) or str(cabal)"
      }
 where
  isExactRepositoryRoot
    [ PyReturn
        ( PyIndex
            ( PyAttribute
                (PyCall (PyAttribute (PyCall (PyName "Path") [PyPositional (PyName "__file__")]) "resolve") [])
                "parents"
              )
            (PyInteger 1)
          )
      ] = True
  isExactRepositoryRoot _ = False
  artifactIndex index = PyIndex (PyName "artifact") (PyInteger index)
  pathFrom = foldl (PyBinary PyPathJoin)
  managedName name = PyBinary PyAdd (PyString name) (artifactIndex 4)
  expectedGhcPath =
    pathFrom
      (PyName "toolchain")
      [PyString ".ghcup", PyString "ghc", PyName "GHC_VERSION", PyString "bin", managedName "ghc"]
  expectedCabalPath =
    pathFrom
      (PyName "toolchain")
      [PyString ".ghcup", PyString "bin", managedName "cabal"]
  expectedInvocation method arguments =
    ( method
    , [ PyPositional (PyName "root")
      , PyPositional (PyList arguments)
      , PyPositional (PyName "environment")
      ]
    )
  stringOf name = PyCall (PyName "str") [PyPositional (PyName name)]
  prefixed prefix name = PyBinary PyAdd (PyString prefix) (stringOf name)
  expectedGhcupInstall tool versionName =
    [ stringOf "ghcup"
    , PyString "install"
    , PyString tool
    , PyName versionName
    , PyString "--set"
    ]
  expectedCabalCommand command =
    [ stringOf "cabal"
    , prefixed "--store-dir=" "store"
    , PyString command
    , prefixed "--builddir=" "builddir"
    , prefixed "--with-compiler=" "ghc"
    , PyName "BUILD_TARGET"
    ]

assignedExpressionForTool :: Text -> [PyStmt] -> Either PbProblem PyExpr
assignedExpressionForTool name statements =
  case [value | PyAssign (PyName found) value <- statements, found == name] of
    [value] -> Right value
    values -> Left (PbToolchainExecutableProblem (name <> " assignment count is " <> Text.pack (show (length values))))

argumentContainsString :: Text -> PyArgument -> Bool
argumentContainsString expected = expressionContains (== PyString expected) . argumentExpression

argumentContainsName :: Text -> PyArgument -> Bool
argumentContainsName expected = expressionContains (== PyName expected) . argumentExpression

argumentExpression :: PyArgument -> PyExpr
argumentExpression (PyPositional value) = value
argumentExpression (PyKeyword _ value) = value

assignedExpression :: Text -> [PyStmt] -> Either PbProblem PyExpr
assignedExpression name statements =
  case [value | PyAssign (PyName found) value <- statements, found == name] of
    [value] -> Right value
    values -> Left (PbBinaryProvenanceProblem (name <> " assignment count is " <> Text.pack (show (length values))))

validateHandoffControlFlow :: BootstrapAst -> [PbProblem]
validateHandoffControlFlow ast =
  shapeProblems
    <> bootstrapTerminationProblems
    <> moduleTerminationProblems
    <> moduleSafetyProblems
    <> unreachableProblems
 where
  shapeProblems =
    case (functionBody "bootstrap" ast, functionBody "main" ast, methodBody "BootstrapAdapter" "handoff" ast) of
      (Just bootstrapBody, Just mainBody, Just handoffBody) ->
        [PbHandoffControlFlowProblem "bootstrap must end with exact adapter.handoff(binary, [binary] + arguments)" | not (endsInExactAdapterHandoff bootstrapBody)]
          <> [PbHandoffControlFlowProblem "main must end with exact bootstrap(adapter, sys.argv[1:])" | not (endsInExactBootstrapCall mainBody)]
          <> [PbHandoffControlFlowProblem "handoff must contain exactly one final os.execv request" | not (isExactExecBody handoffBody)]
      (Nothing, _, _) -> [PbHandoffControlFlowProblem "bootstrap function is absent"]
      (_, Nothing, _) -> [PbHandoffControlFlowProblem "main function is absent"]
      (_, _, Nothing) -> [PbHandoffControlFlowProblem "BootstrapAdapter.handoff is absent"]
  bootstrapTerminationProblems = case functionBody "bootstrap" ast of
    Nothing -> []
    Just body ->
      [ PbHandoffControlFlowProblem "bootstrap must contain exactly one handoff request and it must be the final reachable statement"
      | sum (map (statementOccurrences isAnyAdapterHandoff) body) /= 1
          || sum (map (statementOccurrences isExactAdapterHandoff) body) /= 1
      ]
        <> [ PbHandoffControlFlowProblem "bootstrap may not return or raise before its final handoff request"
           | any containsReturnOrRaise body
           ]
        <> case [graph | graph <- cfgFunctions (buildControlFlow ast), cfgFunction graph == "bootstrap"] of
          [graph] ->
            let reachable = reachableCfgNodeIds graph
                requestIds = [cfgNodeId node | node <- cfgNodes graph, cfgNodeKind node == CfgHandoffRequest]
             in [ PbHandoffControlFlowProblem "bootstrap handoff request is absent, duplicated, or unreachable"
                | case requestIds of
                    [requestId] -> requestId `Set.notMember` reachable
                    _ -> True
                ]
          _ -> []
  moduleTerminationProblems =
    [ PbHandoffControlFlowProblem "module body may not return or raise before the exact main guard"
    | any moduleExecutedTermination (moduleStatementsBeforeGuard ast)
    ]
  moduleSafetyProblems =
    [ PbHandoffControlFlowProblem "module body before the exact main guard may contain only direct imports, literal constants, and the closed definitions"
    | any (not . safeModuleStatement) (moduleStatementsBeforeGuard ast)
    ]
  unreachableProblems =
    [ PbHandoffControlFlowProblem
        ( "control-flow graph contains unreachable nodes in "
            <> cfgFunction graph
            <> ": "
            <> Text.intercalate "," (map (Text.pack . show) unreachable)
        )
    | graph <- cfgFunctions (buildControlFlow ast)
    , let reachable = reachableCfgNodeIds graph
          unreachable = [cfgNodeId node | node <- cfgNodes graph, cfgNodeId node `Set.notMember` reachable]
    , not (null unreachable)
    ]
  endsInExactAdapterHandoff body = case reverse body of
    PyExpression
      ( PyCall
          (PyAttribute (PyName "adapter") "handoff")
          [ PyPositional (PyName "binary")
          , PyPositional (PyBinary PyAdd (PyList [PyName "binary"]) (PyName "arguments"))
          ]
        ) : _ -> True
    _ -> False
  endsInExactBootstrapCall body = case reverse body of
    PyExpression
      ( PyCall
          (PyName "bootstrap")
          [ PyPositional (PyName "adapter")
          , PyPositional (PyIndex (PyAttribute (PyName "sys") "argv") (PySlice (Just (PyInteger 1)) Nothing))
          ]
        ) : _ -> True
    _ -> False
  isExactExecBody [PyExpression (PyCall (PyAttribute (PyName "os") "execv") [PyPositional (PyName "binary"), PyPositional (PyName "arguments")])] = True
  isExactExecBody _ = False
  isExactAdapterHandoff
    ( PyCall
        (PyAttribute (PyName "adapter") "handoff")
        [ PyPositional (PyName "binary")
        , PyPositional (PyBinary PyAdd (PyList [PyName "binary"]) (PyName "arguments"))
        ]
      ) = True
  isExactAdapterHandoff _ = False
  isAnyAdapterHandoff (PyCall (PyAttribute (PyName "adapter") "handoff") _) = True
  isAnyAdapterHandoff _ = False

containsReturnOrRaise :: PyStmt -> Bool
containsReturnOrRaise statement = case statement of
  PyReturn _ -> True
  PyRaise _ -> True
  PyIf _ body -> any containsReturnOrRaise body
  PyClass _ body -> any containsReturnOrRaise body
  PyFunction _ _ body -> any containsReturnOrRaise body
  _ -> False

moduleStatementsBeforeGuard :: BootstrapAst -> [PyStmt]
moduleStatementsBeforeGuard (BootstrapAst statements) = case reverse statements of
  _guard : before -> reverse before
  [] -> []

moduleExecutedTermination :: PyStmt -> Bool
moduleExecutedTermination statement = case statement of
  PyReturn _ -> True
  PyRaise _ -> True
  PyIf _ body -> any moduleExecutedTermination body
  PyClass _ body -> any moduleExecutedTermination body
  PyFunction {} -> False
  _ -> False

safeModuleStatement :: PyStmt -> Bool
safeModuleStatement statement = case statement of
  PyImport _ -> True
  PyFromImport _ _ -> True
  PyAssign (PyName _) value -> literalModuleValue value
  PyClass _ _ -> True
  PyFunction {} -> True
  _ -> False

literalModuleValue :: PyExpr -> Bool
literalModuleValue expression = case expression of
  PyString _ -> True
  PyInteger _ -> True
  PyBoolean _ -> True
  PyEmptyDictionary -> True
  PyTuple values -> all literalModuleValue values
  PyList values -> all literalModuleValue values
  _ -> False

reachableCfgNodeIds :: FunctionControlFlow -> Set.Set Int
reachableCfgNodeIds graph = visit Set.empty [cfgEntryNode graph]
 where
  visit seen [] = seen
  visit seen (node : pending)
    | node `Set.member` seen = visit seen pending
    | otherwise =
        let successors = [cfgEdgeTo edge | edge <- cfgEdges graph, cfgEdgeFrom edge == node]
         in visit (Set.insert node seen) (successors <> pending)

validateHandoffControlFlowForBuild :: BootstrapAst -> [PbProblem]
validateHandoffControlFlowForBuild = validateHandoffControlFlow

provePlatformArtifacts :: BootstrapAst -> Either PbProblem [PlatformArtifact]
provePlatformArtifacts ast = do
  (_, selectorBody) <- maybe (Left (PbPlatformProofProblem "select_artifact is absent or duplicated")) Right (functionDefinition "select_artifact" ast)
  platformBody <- maybe (Left (PbPlatformProofProblem "BootstrapAdapter.platform is absent")) Right (methodBody "BootstrapAdapter" "platform" ast)
  unless (platformBody == exactPlatformBody)
    (Left (PbPlatformProofProblem "concrete platform observation must return only platform.system() and platform.machine()"))
  (branches, terminal) <- case reverse selectorBody of
    finalStatement : reversedBranches -> Right (reverse reversedBranches, finalStatement)
    [] -> Left (PbPlatformProofProblem "pure platform selector body is empty")
  unless (terminal == PyRaise (PyCall (PyName "RuntimeError") [PyPositional (PyString "unsupported-platform")]))
    (Left (PbPlatformProofProblem "pure platform selector must end in the exact unsupported-platform raise"))
  unless (length branches == 4)
    (Left (PbPlatformProofProblem "pure platform selector must contain exactly four branches"))
  observed <- sequence (zipWith artifactReturn [LinuxAmd64Adapter, LinuxArm64Adapter, DarwinArm64Adapter, WindowsAmd64Adapter] branches)
  unless (observed == canonicalArtifacts)
    (Left (PbPlatformProofProblem "platform adapter URL/SHA/system/machine/executable set is not exact"))
  pure observed
 where
  exactPlatformBody =
    [ PyReturn
        ( PyTuple
            [ PyCall (PyAttribute (PyName "platform") "system") []
            , PyCall (PyAttribute (PyName "platform") "machine") []
            ]
        )
    ]
  artifactReturn adapterKind (PyIf condition [PyReturn (PyTuple [PyString url, PyString digest, PyString label, PyString executableName, PyString managedSuffix])]) = do
    (system, machine) <- platformCondition condition
    Right
      PlatformArtifact
        { artifactAdapter = adapterKind
        , artifactSystem = system
        , artifactMachine = machine
        , artifactLabel = label
        , artifactUrl = url
        , artifactSha256 = digest
        , artifactExecutableName = executableName
        , artifactManagedExecutableSuffix = managedSuffix
        }
  artifactReturn _ _ = Left (PbPlatformProofProblem "platform branch is not an exact pure literal return")
  platformCondition
    ( PyBinary
        PyAnd
        (PyBinary PyEqual (PyName "system") (PyString system))
        (PyBinary PyEqual (PyName "machine") (PyString machine))
      ) = Right (system, machine)
  platformCondition _ = Left (PbPlatformProofProblem "platform branch condition is not exact pure system/machine equality")

derivePlatformLimitations :: [PlatformArtifact] -> [PlatformLimitation]
derivePlatformLimitations artifacts =
  [WindowsAmd64RuntimeFidelityDeferredToPhase50 | any ((== WindowsAmd64Adapter) . artifactAdapter) artifacts]
    <> [AllOtherPlatformsRefused]

functionDefinition :: Text -> BootstrapAst -> Maybe ([Text], [PyStmt])
functionDefinition name (BootstrapAst statements) =
  case [(parameters, body) | PyFunction found parameters body <- statements, found == name] of
    [definition] -> Just definition
    _ -> Nothing

functionBody :: Text -> BootstrapAst -> Maybe [PyStmt]
functionBody name ast = snd <$> functionDefinition name ast

methodBody :: Text -> Text -> BootstrapAst -> Maybe [PyStmt]
methodBody className methodName (BootstrapAst statements) = do
  classBody <- case [body | PyClass found body <- statements, found == className] of
    [body] -> Just body
    _ -> Nothing
  case [body | PyFunction found _ body <- classBody, found == methodName] of
    [body] -> Just body
    _ -> Nothing

expressionOccurrences :: (PyExpr -> Bool) -> BootstrapAst -> Int
expressionOccurrences predicate (BootstrapAst statements) = sum (map (statementOccurrences predicate) statements)

statementOccurrences :: (PyExpr -> Bool) -> PyStmt -> Int
statementOccurrences predicate statement = case statement of
  PyImport _ -> 0
  PyFromImport _ _ -> 0
  PyAssign left right -> expressionOccurrence predicate left + expressionOccurrence predicate right
  PyClass _ body -> sum (map (statementOccurrences predicate) body)
  PyFunction _ _ body -> sum (map (statementOccurrences predicate) body)
  PyIf condition body -> expressionOccurrence predicate condition + sum (map (statementOccurrences predicate) body)
  PyReturn value -> expressionOccurrence predicate value
  PyRaise value -> expressionOccurrence predicate value
  PyExpression value -> expressionOccurrence predicate value

expressionOccurrence :: (PyExpr -> Bool) -> PyExpr -> Int
expressionOccurrence predicate expression =
  (if predicate expression then 1 else 0)
    + case expression of
      PyTuple values -> sum (map recurse values)
      PyList values -> sum (map recurse values)
      PyAttribute base _ -> recurse base
      PyIndex base index -> recurse base + recurse index
      PySlice start end -> maybe 0 recurse start + maybe 0 recurse end
      PyCall callee arguments -> recurse callee + sum (map (recurse . argumentExpression) arguments)
      PyBinary _ left right -> recurse left + recurse right
      _ -> 0
 where
  recurse = expressionOccurrence predicate

expressionContains :: (PyExpr -> Bool) -> PyExpr -> Bool
expressionContains predicate expression = expressionOccurrence predicate expression > 0

-- CFG -----------------------------------------------------------------------

buildControlFlow :: BootstrapAst -> ControlFlowGraph
buildControlFlow ast = ControlFlowGraph (map (uncurry buildFunctionControlFlow) (allFunctionBodies ast))

allFunctionBodies :: BootstrapAst -> [(Text, [PyStmt])]
allFunctionBodies (BootstrapAst statements) = concatMap top statements
 where
  top (PyFunction name _ body) = [(name, body)]
  top (PyClass className body) =
    [ (className <> "." <> methodName, methodBodyValue)
    | PyFunction methodName _ methodBodyValue <- body
    ]
  top _ = []

data PartialCfg = PartialCfg
  { partialNodes :: [CfgNode]
  , partialEdges :: [CfgEdge]
  , partialNext :: Int
  , partialEntry :: Maybe Int
  , partialExits :: [(Int, CfgEdgeKind)]
  }

buildFunctionControlFlow :: Text -> [PyStmt] -> FunctionControlFlow
buildFunctionControlFlow name body =
  let entry = CfgNode 0 CfgEntry (name <> ":entry")
      built = buildSequence name 1 body
      entryEdges = case partialEntry built of
        Nothing -> []
        Just first -> [CfgEdge 0 first CfgSequential]
   in FunctionControlFlow
        { cfgFunction = name
        , cfgEntryNode = 0
        , cfgNodes = entry : partialNodes built
        , cfgEdges = entryEdges <> partialEdges built
        , cfgFallsThrough = not (null (partialExits built))
        }

buildSequence :: Text -> Int -> [PyStmt] -> PartialCfg
buildSequence _ next [] = PartialCfg [] [] next Nothing []
buildSequence scope next (statement : rest) =
  let first = buildStatementCfg scope next statement
      following = buildSequence scope (partialNext first) rest
      joins = case partialEntry following of
        Nothing -> []
        Just target -> [CfgEdge source target kind | (source, kind) <- partialExits first]
      exits = case partialEntry following of
        Nothing -> partialExits first
        Just _
          | null (partialExits first) -> []
          | otherwise -> partialExits following
   in PartialCfg
        { partialNodes = partialNodes first <> partialNodes following
        , partialEdges = partialEdges first <> joins <> partialEdges following
        , partialNext = partialNext following
        , partialEntry = partialEntry first
        , partialExits = exits
        }

buildStatementCfg :: Text -> Int -> PyStmt -> PartialCfg
buildStatementCfg scope next statement = case statement of
  PyIf _ body ->
    let branch = CfgNode next CfgBranch (scope <> ":if")
        child = buildSequence scope (next + 1) body
        trueEdges = case partialEntry child of
          Nothing -> []
          Just target -> [CfgEdge next target CfgBranchTrue]
        exits = (next, CfgBranchFalse) : partialExits child
     in PartialCfg (branch : partialNodes child) (trueEdges <> partialEdges child) (partialNext child) (Just next) exits
  _ ->
    let kind = statementCfgKind scope statement
        node = CfgNode next kind (scope <> ":" <> statementLabel statement)
        exits = case kind of
          CfgReturn -> []
          CfgRaise -> []
#if defined(VALIDATION_PB_GRAMMAR_HANDOFF_MAY_RETURN_MUTANT)
          CfgHandoffRequest -> []
#endif
          _ -> [(next, CfgSequential)]
     in PartialCfg [node] [] (next + 1) (Just next) exits

statementCfgKind :: Text -> PyStmt -> CfgNodeKind
statementCfgKind _ (PyReturn _) = CfgReturn
statementCfgKind _ (PyRaise _) = CfgRaise
statementCfgKind "BootstrapAdapter.handoff"
  (PyExpression (PyCall (PyAttribute (PyName "os") "execv") [PyPositional (PyName "binary"), PyPositional (PyName "arguments")])) = CfgHandoffRequest
statementCfgKind "bootstrap"
  ( PyExpression
      ( PyCall
          (PyAttribute (PyName "adapter") "handoff")
          [ PyPositional (PyName "binary")
          , PyPositional (PyBinary PyAdd (PyList [PyName "binary"]) (PyName "arguments"))
          ]
        )
    ) = CfgHandoffRequest
statementCfgKind _ _ = CfgStatement

statementLabel :: PyStmt -> Text
statementLabel = \case
  PyAssign (PyName name) _ -> "assign " <> name
  PyAssign _ _ -> "assign index"
  PyReturn _ -> "return"
  PyRaise _ -> "raise"
  PyExpression expression -> "call " <> renderCallee expression
  PyImport qualified -> "import " <> Text.intercalate "." qualified
  PyFromImport qualified name -> "from " <> Text.intercalate "." qualified <> " import " <> name
  PyClass name _ -> "class " <> name
  PyFunction name _ _ -> "def " <> name
  PyIf _ _ -> "if"

stableNub :: Ord value => [value] -> [value]
stableNub = go Set.empty
 where
  go _ [] = []
  go seen (value : rest)
    | value `Set.member` seen = go seen rest
    | otherwise = value : go (Set.insert value seen) rest
