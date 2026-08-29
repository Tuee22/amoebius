{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Evidence
  ( CandidateEvidence
  , CandidateProvenance (..)
  , EvidenceRow
  , candidateBytes
  , candidateDigest
  , candidateFromChecks
  , evidenceGateResult
  , evidenceContractDigest
  , evidenceHarnessDigest
  , evidenceObserverDigest
  , evidenceOracleDigest
  , evidencePhase
  , evidencePredecessorDigest
  , evidenceQualificationDigest
  , evidenceResidue
  , evidenceRowFindings
  , evidenceRowName
  , evidenceRowObservations
  , evidenceRowStatus
  , evidenceRows
  , evidenceSchema
  , evidenceSourceDigest
  , evidenceSubjectDigest
  , writeCandidateEvidence
  ) where

import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.Types
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (ToJSON (toJSON), Value, encode, object, (.=))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (intToDigit)
import Data.List (group, sort)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Control.Monad (foldM, unless, when)
import System.Directory
  ( canonicalizePath
  , createDirectory
  , doesDirectoryExist
  , doesPathExist
  , makeAbsolute
  , pathIsSymbolicLink
  )
import System.FilePath ((</>), isAbsolute, makeRelative, normalise, splitDirectories)

data EvidenceRow = EvidenceRow
  { evidenceRowName :: Text
  , evidenceRowStatus :: Text
  , evidenceRowObservations :: [Observation]
  , evidenceRowFindings :: [Finding]
  }
  deriving (Eq, Show)

data CandidateEvidence = CandidateEvidence
  { evidenceSchema :: Text
  , evidencePhase :: Text
  , evidenceSourceDigest :: Text
  , evidenceContractDigest :: Text
  , evidenceSubjectDigest :: Text
  , evidenceOracleDigest :: Text
  , evidenceHarnessDigest :: Text
  , evidenceObserverDigest :: Text
  , evidenceQualificationDigest :: Text
  , evidencePredecessorDigest :: Text
  , evidenceRows :: [EvidenceRow]
  , evidenceResidue :: [Text]
  , evidenceGateResult :: Text
  }
  deriving (Eq, Show)

data CandidateProvenance = CandidateProvenance
  { provenanceSourceDigest :: Text
  , provenanceContractDigest :: Text
  , provenanceSubjectDigest :: Text
  , provenanceOracleDigest :: Text
  , provenanceHarnessDigest :: Text
  , provenanceObserverDigest :: Text
  , provenanceQualificationDigest :: Text
  , provenancePredecessorDigest :: Text
  , provenanceExpectedRows :: Set Text
  }
  deriving (Eq, Show)

instance ToJSON EvidenceRow where
  toJSON row =
    object
      [ "name" .= evidenceRowName row
      , "status" .= evidenceRowStatus row
      , "observations" .= fmap observationJson (evidenceRowObservations row)
      , "findings" .= fmap findingJson (evidenceRowFindings row)
      ]

instance ToJSON CandidateEvidence where
  toJSON evidence =
    object
      [ "schema" .= evidenceSchema evidence
      , "phase" .= evidencePhase evidence
      , "sourceDigest" .= evidenceSourceDigest evidence
      , "contractDigest" .= evidenceContractDigest evidence
      , "subjectDigest" .= evidenceSubjectDigest evidence
      , "oracleDigest" .= evidenceOracleDigest evidence
      , "harnessDigest" .= evidenceHarnessDigest evidence
      , "observerDigest" .= evidenceObserverDigest evidence
      , "qualificationDigest" .= evidenceQualificationDigest evidence
      , "predecessorDigest" .= evidencePredecessorDigest evidence
      , "rows" .= evidenceRows evidence
      , "residue" .= evidenceResidue evidence
      , "gateResult" .= evidenceGateResult evidence
      ]

candidateFromChecks :: CandidateProvenance -> [Text] -> [CheckResult] -> Either [Finding] CandidateEvidence
candidateFromChecks provenance residue checks =
  -- Caller-constructed checks and digest-shaped strings are not acquired
  -- evidence. Until Dispatch owns execution, hashing, input closure, observer
  -- binding, and the fixed row inventory, this seam must be incapable of
  -- constructing even a candidate-shaped value.
  case captureFindings <> structuralFindings <> concatMap checkFindings checks of
    [] ->
      Right
        CandidateEvidence
          { evidenceSchema = "amoebius-validation-candidate-v1"
          , evidencePhase = "00"
          , evidenceSourceDigest = provenanceSourceDigest provenance
          , evidenceContractDigest = provenanceContractDigest provenance
          , evidenceSubjectDigest = provenanceSubjectDigest provenance
          , evidenceOracleDigest = provenanceOracleDigest provenance
          , evidenceHarnessDigest = provenanceHarnessDigest provenance
          , evidenceObserverDigest = provenanceObserverDigest provenance
          , evidenceQualificationDigest = provenanceQualificationDigest provenance
          , evidencePredecessorDigest = provenancePredecessorDigest provenance
          , evidenceRows = fmap row checks
          , evidenceResidue = residue
          , evidenceGateResult = "candidate-only; complete qualified gate required"
          }
    blockers -> Left blockers
 where
  names = fmap checkName checks
  suppliedNames = Set.fromList names
  captureFindings =
    [ finding
        "EVIDENCE-CAPTURE-UNINTEGRATED"
        "Amoebius.Validation.Dispatch"
        "caller-supplied provenance and CheckResult values are not execution-derived evidence"
    ]
  structuralFindings =
    [ finding "EVIDENCE-ROWS-EMPTY" "phase-00" "candidate evidence must contain the complete non-empty row set"
    | null checks
    ]
      <> [ finding "EVIDENCE-ROW-DUPLICATE" (Text.unpack name) "candidate evidence contains a duplicate row"
         | name <- duplicates names
         ]
      <> [ finding "EVIDENCE-ROW-MISSING" (Text.unpack name) "required candidate row is absent"
         | name <- Set.toAscList (provenanceExpectedRows provenance Set.\\ suppliedNames)
         ]
      <> [ finding "EVIDENCE-ROW-UNEXPECTED" (Text.unpack name) "candidate evidence contains an undeclared row"
         | name <- Set.toAscList (suppliedNames Set.\\ provenanceExpectedRows provenance)
         ]
      <> [ finding "EVIDENCE-ROW-NAME-EMPTY" "phase-00" "candidate row names must be non-empty"
         | any (Text.null . Text.strip) (Set.toList (provenanceExpectedRows provenance) <> names)
         ]
      <> [ finding "EVIDENCE-OBSERVATIONS-EMPTY" (Text.unpack (checkName result)) "candidate row contains no raw observation"
         | result <- checks
         , null (checkObservations result)
         ]
      <> [ finding "EVIDENCE-OBSERVATION-MALFORMED" (Text.unpack (checkName result)) "raw observation keys and values must be non-empty"
         | result <- checks
         , item <- checkObservations result
         , Text.null (Text.strip (observationKey item)) || Text.null (Text.strip (observationValue item))
         ]
      <> [ finding "EVIDENCE-OBSERVATION-DUPLICATE" (Text.unpack (checkName result)) ("duplicate raw observation key: " <> key)
         | result <- checks
         , key <- duplicates (fmap observationKey (checkObservations result))
         ]
      <> [ finding "EVIDENCE-PROVENANCE" (Text.unpack label) "provenance digest must be a lowercase SHA-256 value"
         | (label, value) <- provenanceDigests provenance
         , not (sha256Text value)
         ]
      <> [ finding "EVIDENCE-PREDECESSOR" "predecessor" "predecessor must be genesis or a lowercase SHA-256 value"
         | let predecessor = provenancePredecessorDigest provenance
         , predecessor /= "genesis" && not (sha256Text predecessor)
         ]
      <> [ finding "EVIDENCE-RESIDUE-MISSING" "residue" "candidate evidence must contain explicit UNVERIFIED residue"
         | null residue
         ]
      <> [ finding "EVIDENCE-RESIDUE-EMPTY" "residue" "UNVERIFIED residue entries must be non-empty and explicit"
         | any Text.null (fmap Text.strip residue)
         ]
      <> [ finding "EVIDENCE-RESIDUE-DUPLICATE" "residue" ("duplicate UNVERIFIED residue: " <> item)
         | item <- duplicates residue
         ]
      <> [ finding "EVIDENCE-RESIDUE-FORMAT" "residue" "every residue entry must begin with 'UNVERIFIED:'"
         | any (not . Text.isPrefixOf "UNVERIFIED:" . Text.strip) residue
         ]
  row result =
    EvidenceRow
      { evidenceRowName = checkName result
      , evidenceRowStatus = "green"
      , evidenceRowObservations = checkObservations result
      , evidenceRowFindings = checkFindings result
      }

provenanceDigests :: CandidateProvenance -> [(Text, Text)]
provenanceDigests provenance =
  [ ("source", provenanceSourceDigest provenance)
  , ("contract", provenanceContractDigest provenance)
  , ("subject", provenanceSubjectDigest provenance)
  , ("oracle", provenanceOracleDigest provenance)
  , ("harness", provenanceHarnessDigest provenance)
  , ("observer", provenanceObserverDigest provenance)
  , ("qualification", provenanceQualificationDigest provenance)
  ]

sha256Text :: Text -> Bool
sha256Text value =
  Text.length value == 64
    && Text.all (\character -> character >= '0' && character <= '9' || character >= 'a' && character <= 'f') value

duplicates :: Ord value => [value] -> [value]
duplicates = foldr repeated [] . group . sort
 where
  repeated (value : _ : _) rest = value : rest
  repeated _ rest = rest

observationJson :: Observation -> Value
observationJson item = object ["key" .= observationKey item, "value" .= observationValue item]

findingJson :: Finding -> Value
findingJson item =
  object
    [ "code" .= findingCode item
    , "subject" .= findingSubject item
    , "detail" .= findingDetail item
    ]

candidateBytes :: CandidateEvidence -> ByteString
candidateBytes = LazyByteString.toStrict . encode

candidateDigest :: CandidateEvidence -> Text
candidateDigest = hex . SHA256.hash . candidateBytes

writeCandidateEvidence :: FilePath -> CandidateEvidence -> IO FilePath
writeCandidateEvidence repositoryRoot evidence = do
  absoluteRoot <- makeAbsolute repositoryRoot >>= canonicalizePath
  directory <- ensureDirectoryChain absoluteRoot [canonicalGeneratedRoot, "runs", "phase-00", "candidates"]
  let encoded = candidateBytes evidence
      destination = directory </> Text.unpack (candidateDigest evidence) <> ".json"
  if not (isAbsolute directory) || not (isContained absoluteRoot directory)
    then fail "candidate-output-escaped-repository-build-root"
    else do
      present <- doesPathExist destination
      if present
        then do
          linked <- pathIsSymbolicLink destination
          when linked (fail "candidate-output-is-symbolic-link")
          existing <- ByteString.readFile destination
          unless (existing == encoded) (fail "candidate-content-address-collision")
          pure destination
        else do
          ByteString.writeFile destination encoded
          pure destination

ensureDirectoryChain :: FilePath -> [FilePath] -> IO FilePath
ensureDirectoryChain root = foldM ensure root
 where
  ensure parent component = do
    let candidate = normalise (parent </> component)
    present <- doesPathExist candidate
    if present
      then do
        linked <- pathIsSymbolicLink candidate
        when linked (fail "candidate-output-directory-is-symbolic-link")
        directory <- doesDirectoryExist candidate
        unless directory (fail "candidate-output-component-is-not-directory")
      else createDirectory candidate
    canonical <- canonicalizePath candidate
    unless (isContained root canonical || canonical == normalise (root </> canonicalGeneratedRoot))
      (fail "candidate-output-directory-escaped-repository")
    pure canonical

isContained :: FilePath -> FilePath -> Bool
isContained root path =
  case splitDirectories (makeRelative (normalise root) (normalise path)) of
    generatedRoot : "runs" : _ | generatedRoot == canonicalGeneratedRoot -> True
    _ -> False

canonicalGeneratedRoot :: FilePath
canonicalGeneratedRoot =
  Policy.generationRootPath
    (Policy.generationRoot (Policy.generationContract Policy.canonicalPolicyContract))

hex :: ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value = [intToDigit (fromIntegral value `div` 16), intToDigit (fromIntegral value `mod` 16)]
